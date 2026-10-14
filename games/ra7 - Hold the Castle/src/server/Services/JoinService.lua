-- Friends, full servers, private matches and rejoining (master plan §19: an easy "Join Friend" button; public
-- matches and private matches with friends).
--   * The FRIENDS panel: the client lists its friends online in this game (GetFriendsOnline only works on the client)
--     and asks how each one's match is doing ("Friends"). Every server keeps a small status card in a MemoryStore
--     map under its JobId (phase, players, the shrine being fought over; for a private match, its access code,
--     which never leaves the servers), refreshed every STATUS_SECONDS and gone a minute after the server closes.
--   * JoinFriend(userId): you must be friends; we find their server (GetPlayerPlaceInstanceAsync), check it has
--     room, and teleport you to that exact server. Never to a random one.
--   * Server Full: the client offers Wait for a Spot (we try again every FRIEND_RETRY_SECONDS, up to
--     FRIEND_RETRY_TRIES times: a retry, honestly, not a queue position), Join Another Friend, or Start a Private
--     Match (a fresh server of your own: friends can still join it from their FRIENDS panel, because its status
--     card carries its access code).
--   * Rejoin: dropped out of a match that's still going (within REJOIN_SECONDS)? You're offered to go back, if it
--     has room.
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local JoinService = {
	Name = "JoinService",
	Dependencies = { "PlayerDataService", "MatchService" },
	Attempted = Signal.new("JoinService.Attempted"), -- (player, kind) "friend" | "retry" | "private" | "rejoin"
	Result = Signal.new("JoinService.Result"), -- (player, kind, detail) "teleporting" | "full" | "failed" | "gone" | "here"
}

local STATUS_SECONDS = 15
local STATUS_TTL = 60
local REJOIN_SECONDS = 900

local data, match
local map -- the MemoryStore sorted map (nil when unavailable, e.g. in Studio)
local pending = {} -- [player] = { userId, name, jobId, tries, waiting, nextAt }
local rejoinOffer = {} -- [player] = { jobId, access }
local accessCode -- this server's access code, if it's a private match we created
local statusCache = {} -- [jobId] = { at, status }

local function isPrivate()
	return game.PrivateServerId ~= nil and game.PrivateServerId ~= "" and (game.PrivateServerOwnerId or 0) == 0
end

local function jobId()
	return game.JobId ~= "" and game.JobId or "studio"
end

-- This server's card.
function JoinService:MyStatus()
	local view = match:View()
	return {
		phase = view.phase,
		shrine = view.active,
		held = math.floor(match:FightSeconds()),
		number = view.number,
		crew = #Players:GetPlayers(),
		max = Constants.MAX_PLAYERS,
		exp = view.id,
		access = accessCode,
		private = isPrivate(),
		at = os.time(),
	}
end

function JoinService:_publish()
	if not map then
		return
	end
	local status = self:MyStatus()
	pcall(map.SetAsync, map, jobId(), status, STATUS_TTL)
end

-- Another server's card (cached a few seconds), or nil.
function JoinService:Status(job)
	if type(job) ~= "string" or job == "" then
		return nil
	end
	if job == jobId() then
		return self:MyStatus()
	end
	local c = statusCache[job]
	if c and os.clock() - c.at < 5 then
		return c.status
	end
	local status
	if map then
		local ok, value = pcall(map.GetAsync, map, job)
		status = ok and type(value) == "table" and value or nil
	end
	statusCache[job] = { at = os.clock(), status = status }
	return status
end

-- What the FRIENDS panel shows for one friend's match (never the access code).
local function public(status, userId, here)
	if here then
		return { userId = userId, here = true }
	end
	if not status then
		return { userId = userId, unknown = true }
	end
	return {
		userId = userId,
		phase = status.phase,
		shrine = status.shrine,
		held = status.held,
		crew = status.crew,
		max = status.max,
		full = (status.crew or 0) >= (status.max or Constants.MAX_PLAYERS),
		private = status.private == true,
	}
end

function JoinService:FriendsView(_player, list)
	local out = {}
	if type(list) ~= "table" then
		return out
	end
	for i, f in list do
		if i > 40 then
			break
		end
		local userId = type(f) == "table" and tonumber(f.userId)
		if userId then
			local here = Players:GetPlayerByUserId(userId) ~= nil
			local job = type(f.jobId) == "string" and string.sub(f.jobId, 1, 64) or nil
			table.insert(out, public(not here and self:Status(job) or nil, userId, here))
		end
	end
	return out
end

local function cleanName(name)
	return type(name) == "string" and string.sub(name, 1, 32) or "your friend"
end

function JoinService:_result(player, kind, fields)
	fields = fields or {}
	fields.kind = kind
	Net.fire(player, "FriendResult", fields)
	self.Result:Fire(player, kind, fields)
end

function JoinService:_teleport(player, job, status, ctx)
	local ok = pcall(function()
		local options = Instance.new("TeleportOptions")
		if status and status.access then
			options.ReservedServerAccessCode = status.access
		else
			options.ServerInstanceId = job
		end
		options:SetTeleportData({ from = ctx.kind, friend = ctx.userId })
		self:_result(player, "teleporting", { name = ctx.name, userId = ctx.userId })
		TeleportService:TeleportAsync(game.PlaceId, { player }, options)
	end)
	if not ok then
		self:_result(
			player,
			"failed",
			{ name = ctx.name, userId = ctx.userId, text = "Couldn't reach that match. Try again in a moment." }
		)
	end
	return ok
end

function JoinService:_full(player, ctx)
	ctx.waiting = false
	self:_result(player, "full", {
		name = ctx.name,
		userId = ctx.userId,
		max = Constants.FRIEND_RETRY_TRIES,
		every = Constants.FRIEND_RETRY_SECONDS,
	})
end

function JoinService:Join(player, userId, name)
	userId = tonumber(userId)
	if not userId or userId == player.UserId then
		return false
	end
	name = cleanName(name)
	self.Attempted:Fire(player, "friend")
	local okF, isFriend = pcall(player.IsFriendsWith, player, userId)
	if not okF or not isFriend then
		self:_result(
			player,
			"failed",
			{ name = name, userId = userId, text = "You can only join your friends' matches." }
		)
		return false
	end
	local friend = Players:GetPlayerByUserId(userId)
	if friend then
		self:_result(player, "here", { name = friend.DisplayName, userId = userId, team = friend:GetAttribute("Team") })
		return true
	end
	local okP, _, _, placeId, job = pcall(function()
		return TeleportService:GetPlayerPlaceInstanceAsync(userId)
	end)
	if not okP or not job or job == "" or placeId ~= game.PlaceId then
		self:_result(player, "gone", { name = name, userId = userId })
		return false
	end
	local ctx = { kind = "friend", userId = userId, name = name, jobId = job, tries = 0 }
	pending[player] = ctx
	local status = self:Status(job)
	if status and (status.crew or 0) >= (status.max or Constants.MAX_PLAYERS) then
		self:_full(player, ctx)
		return false
	end
	return self:_teleport(player, job, status, ctx)
end

-- A private match of your own (friends can join it from their FRIENDS panel).
function JoinService:PrivateMatch(player)
	self.Attempted:Fire(player, "private")
	pending[player] = nil
	local ok = pcall(function()
		local code = TeleportService:ReserveServer(game.PlaceId)
		local options = Instance.new("TeleportOptions")
		options.ReservedServerAccessCode = code
		options:SetTeleportData({ from = "private", access = code })
		self:_result(player, "teleporting", { name = "your private match", new = true })
		TeleportService:TeleportAsync(game.PlaceId, { player }, options)
	end)
	if not ok then
		self:_result(player, "failed", { text = "Couldn't start a private match right now. Try again in a moment." })
	end
	return ok
end

function JoinService:Action(player, action)
	local ctx = pending[player]
	if action == "retry" and ctx then
		self.Attempted:Fire(player, "retry")
		ctx.waiting = true
		ctx.tries = 0
		ctx.nextAt = os.clock() + Constants.FRIEND_RETRY_SECONDS
		self:_result(player, "waiting", {
			name = ctx.name,
			userId = ctx.userId,
			tries = 0,
			max = Constants.FRIEND_RETRY_TRIES,
			wait = Constants.FRIEND_RETRY_SECONDS,
		})
	elseif action == "cancel" then
		pending[player] = nil
		rejoinOffer[player] = nil
	elseif action == "private" then
		self:PrivateMatch(player)
	elseif action == "rejoin" and rejoinOffer[player] then
		local offer = rejoinOffer[player]
		rejoinOffer[player] = nil
		self.Attempted:Fire(player, "rejoin")
		local status = self:Status(offer.jobId)
		if not status or status.exp ~= offer.exp or status.phase == "ended" then
			self:_result(player, "gone", { name = "your match" })
			return
		end
		if (status.crew or 0) >= (status.max or Constants.MAX_PLAYERS) then
			pending[player] = { kind = "rejoin", name = "your match", jobId = offer.jobId, tries = 0 }
			self:_full(player, pending[player])
			return
		end
		self:_teleport(player, offer.jobId, status, { kind = "rejoin", name = "your match" })
	end
end

-- Waiting for a spot: one more try.
function JoinService:_retry(player, ctx)
	ctx.tries += 1
	statusCache[ctx.jobId] = nil
	local status = self:Status(ctx.jobId)
	if map and not status then
		pending[player] = nil
		self:_result(player, "gone", { name = ctx.name, userId = ctx.userId })
		return
	end
	if status and (status.crew or 0) < (status.max or Constants.MAX_PLAYERS) then
		ctx.waiting = false
		self:_teleport(player, ctx.jobId, status, ctx)
		return
	end
	if ctx.tries >= Constants.FRIEND_RETRY_TRIES then
		ctx.waiting = false
		self:_result(player, "failed", {
			name = ctx.name,
			userId = ctx.userId,
			stillFull = true,
			text = `{ctx.name}'s server is still full. Join another friend, or start a private match?`,
		})
		return
	end
	ctx.nextAt = os.clock() + Constants.FRIEND_RETRY_SECONDS
	self:_result(player, "waiting", {
		name = ctx.name,
		userId = ctx.userId,
		tries = ctx.tries,
		max = Constants.FRIEND_RETRY_TRIES,
		wait = Constants.FRIEND_RETRY_SECONDS,
	})
end

function JoinService:Init(registry)
	data = registry.PlayerDataService
	match = registry.MatchService
	local ok, m = pcall(function()
		return MemoryStoreService:GetSortedMap("HC_Matches")
	end)
	map = ok and m or nil
	Net.on("Friends", function(player, list)
		Net.fire(player, "Friends", self:FriendsView(player, list))
	end)
	Net.on("JoinFriend", function(player, userId, name)
		if type(userId) == "number" then
			self:Join(player, userId, name)
		end
	end)
	Net.on("FriendAction", function(player, action)
		if type(action) == "string" then
			self:Action(player, action)
		end
	end)
	pcall(function()
		TeleportService.TeleportInitFailed:Connect(function(player, result, message)
			local ctx = pending[player]
			local name = ctx and ctx.name or "that match"
			if result == Enum.TeleportResult.GameFull then
				if ctx then
					self:_full(player, ctx)
				else
					self:_result(
						player,
						"full",
						{ name = name, max = Constants.FRIEND_RETRY_TRIES, every = Constants.FRIEND_RETRY_SECONDS }
					)
				end
			elseif
				result == Enum.TeleportResult.GameEnded
				or result == Enum.TeleportResult.GameNotFound
				or result == Enum.TeleportResult.Unauthorized
			then
				pending[player] = nil
				self:_result(player, "gone", { name = name, userId = ctx and ctx.userId })
			else
				self:_result(player, "failed", {
					name = name,
					userId = ctx and ctx.userId,
					text = `Couldn't reach {name}: {tostring(message or "teleport failed")}`,
				})
			end
		end)
	end)
	-- a private match someone started: remember its access code so friends can join it
	Players.PlayerAdded:Connect(function(player)
		if isPrivate() and not accessCode then
			pcall(function()
				local td = player:GetJoinData().TeleportData
				if type(td) == "table" and type(td.access) == "string" then
					accessCode = td.access
				end
			end)
		end
	end)
	match.Started:Connect(function()
		for _, p in Players:GetPlayers() do
			local profile = data:Get(p)
			if profile then
				profile.lastMatch = { job = jobId(), exp = match:State().id, at = os.time() }
			end
		end
	end)
end

function JoinService:OnPlayerReady(player, profile)
	local last = profile.lastMatch
	profile.lastMatch = { job = jobId(), exp = match:State().id, at = os.time() }
	-- back from a dropped connection? Offer the match you were in, if it's still going and has room.
	if type(last) == "table" and last.job and last.job ~= jobId() and os.time() - (last.at or 0) < REJOIN_SECONDS then
		task.spawn(function()
			local status = self:Status(last.job)
			if
				status
				and status.exp == last.exp
				and status.phase ~= "ended"
				and status.phase ~= "intermission"
				and (status.crew or 0) < (status.max or Constants.MAX_PLAYERS)
			then
				rejoinOffer[player] = { jobId = last.job, exp = last.exp }
				data:WhenClientReady(player, function()
					self:_result(
						player,
						"rejoin",
						{ shrine = status.shrine, phase = status.phase, crew = status.crew, max = status.max }
					)
				end)
			end
		end)
	end
end

function JoinService:OnPlayerLeaving(player, profile)
	pending[player] = nil
	rejoinOffer[player] = nil
	if profile and match:InMatch() then
		profile.lastMatch = { job = jobId(), exp = match:State().id, at = os.time() }
	end
end

function JoinService:Start()
	local acc = STATUS_SECONDS
	while true do
		task.wait(1)
		acc += 1
		if acc >= STATUS_SECONDS then
			acc = 0
			task.spawn(self._publish, self)
		end
		for player, ctx in pending do
			if ctx.waiting and ctx.nextAt and os.clock() >= ctx.nextAt then
				ctx.nextAt = nil
				task.spawn(self._retry, self, player, ctx)
			end
		end
	end
end

-- (tests)
function JoinService:_pending(player)
	return pending[player]
end

return JoinService
