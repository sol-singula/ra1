-- Fill the first servers first: Roblox spreads new players over servers, but a full server is more fun. Every
-- server keeps a row in a shared MemoryStore map (its number, how many players, room left, game version), so
-- each one knows about the others. When a player joins a server and a lower-numbered server of the same version
-- has room, they're sent there before their save loads (so nothing is lost and nothing is locked).
-- Never moved: players who followed a friend or came in on an invite, friends of someone already here, players
-- who were just moved (no ping-pong), private servers, Studio.
--
-- The server's number (1, 2, 3...) is the smallest one no live server is using; the Discord log shows it.
-- The BUSY SERVER PORTAL in the lobby sends anyone who walks in to the busiest server with room (UsePortal).
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local ServerFillService = {
	Name = "ServerFillService",
	Dependencies = { "DragonService" },
	number = nil, -- this server's number once claimed
	servers = {}, -- the other live servers: { jobId, n, players, max, version }
}

local MAP_NAME = "ServerFill_v1"
local HEARTBEAT = 5 -- seconds between updates
local EXPIRY = 30 -- a server that stops updating drops out after this long
local KEEP_FREE = 1 -- leave this many slots free on the target (two servers sending at once)

local map
local arrivedByMove = {} -- [player] = true: came here because we moved them (never move again)

local function enabled()
	if ServerFillService.testMode then
		return true
	end
	return map ~= nil and not RunService:IsStudio() and game.PrivateServerId == "" and game.JobId ~= ""
end

local function maxPlayers()
	return Players.MaxPlayers > 0 and Players.MaxPlayers or 8
end

-- Read every live server and claim or keep our number; write our own row.
function ServerFillService:_beat()
	local ok, rows = pcall(function()
		return map:GetRangeAsync(Enum.SortDirection.Ascending, 100)
	end)
	if not ok then
		return
	end
	local others, used = {}, {}
	for _, row in rows do
		local v = row.value
		if row.key ~= game.JobId and type(v) == "table" then
			table.insert(others, {
				jobId = row.key,
				n = v.n,
				players = v.players or 0,
				max = v.max or maxPlayers(),
				version = v.version,
			})
			if v.n then
				used[v.n] = true
			end
		end
	end
	if not self.number or used[self.number] then
		local n = 1
		while used[n] do
			n += 1
		end
		self.number = n
	end
	table.sort(others, function(a, b)
		return (a.n or math.huge) < (b.n or math.huge)
	end)
	self.servers = others
	pcall(function()
		map:SetAsync(game.JobId, {
			n = self.number,
			players = #Players:GetPlayers(),
			max = maxPlayers(),
			version = game.PlaceVersion,
		}, EXPIRY)
	end)
end

-- Where to send a player who just joined, or nil to keep them. Instant (uses the last heartbeat).
function ServerFillService:TargetFor(player)
	if not enabled() or not self.number or arrivedByMove[player] then
		return nil
	end
	local ok, joinData = pcall(player.GetJoinData, player)
	local td = ok and joinData and joinData.TeleportData
	if type(td) == "table" and td.fill then
		arrivedByMove[player] = true
		return nil
	end
	if (player.FollowUserId or 0) ~= 0 or (ok and joinData and (joinData.ReferredByPlayerId or 0) ~= 0) then
		return nil
	end
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local fok, friends = pcall(player.IsFriendsWith, player, other.UserId)
			if fok and friends then
				return nil
			end
		end
	end
	for _, s in self.servers do
		if s.n and s.n < self.number and s.version == game.PlaceVersion and s.players + KEEP_FREE < s.max then
			return s
		end
	end
	return nil
end

-- The BUSY SERVER PORTAL: the server (same game version) with the most players that still has room, and more
-- players than this one. Nil if this is already the busiest.
function ServerFillService:Busiest()
	local here = #Players:GetPlayers()
	local best
	for _, s in self.servers do
		if s.version == game.PlaceVersion and s.players + KEEP_FREE < s.max and s.players > here then
			if not best or s.players > best.players then
				best = s
			end
		end
	end
	return best
end

local portalAt = {} -- [player] = os.clock() of their last portal use
function ServerFillService:UsePortal(player, carrying)
	if (portalAt[player] or -99) > os.clock() - 8 or player:GetAttribute("FillMove") then
		return false
	end
	portalAt[player] = os.clock()
	if carrying then
		Net.fire(player, "Toast", "Take your dragon home first, then use the portal! 🐉", "info")
		return false
	end
	local target = self:Busiest()
	if not target then
		Net.fire(player, "Toast", "You're already in the busiest server! 🎉", "good")
		return false
	end
	Net.fire(player, "Toast", `🌀 Off to a server with {target.players} players...`, "good")
	if not self:Move(player, target) then
		Net.fire(player, "Toast", "The portal fizzled. Try again in a moment!", "info")
	end
	return true -- (found a busier server and tried)
end

-- The BONK ARENA portal: to the arena place (30 players) once Constants.ARENA_PLACE_ID is set; until then to a
-- reserved arena server of this place, filling one up before opening another (the ARENA_MAP map).
function ServerFillService:UseArena(player, carrying)
	if (portalAt[player] or -99) > os.clock() - 8 or player:GetAttribute("FillMove") then
		return false
	end
	portalAt[player] = os.clock()
	if carrying then
		Net.fire(player, "Toast", "Take your dragon home first, then go to the arena! 🐉", "info")
		return false
	end
	Net.fire(player, "Toast", "⚔️ Off to the Bonk Arena...", "good")
	player:SetAttribute("FillMove", -1)
	local ok = pcall(function()
		local options = Instance.new("TeleportOptions")
		options:SetTeleportData({ arena = true })
		if Constants.ARENA_PLACE_ID ~= 0 then
			TeleportService:TeleportAsync(Constants.ARENA_PLACE_ID, { player }, options)
			return
		end
		local arenas = MemoryStoreService:GetSortedMap(Constants.ARENA_MAP)
		local code
		for _, row in arenas:GetRangeAsync(Enum.SortDirection.Ascending, 50) do
			local v = row.value
			if type(v) == "table" and v.code and (v.players or 0) + 1 < maxPlayers() then
				code = v.code
				break
			end
		end
		if not code then
			local newCode, serverId = TeleportService:ReserveServer(game.PlaceId)
			arenas:SetAsync(serverId, { code = newCode, players = 0 }, 3600)
			code = newCode
		end
		options.ReservedServerAccessCode = code
		TeleportService:TeleportAsync(game.PlaceId, { player }, options)
	end)
	if not ok then
		player:SetAttribute("FillMove", nil)
		Net.fire(player, "Toast", "The arena portal fizzled. Try again in a moment!", "info")
	end
	return ok
end

-- Send the player to that server. Returns true if the teleport started.
function ServerFillService:Move(player, target)
	player:SetAttribute("FillMove", target.n)
	local ok = pcall(function()
		local options = Instance.new("TeleportOptions")
		options.ServerInstanceId = target.jobId
		options:SetTeleportData({ fill = true, from = self.number })
		TeleportService:TeleportAsync(game.PlaceId, { player }, options)
	end)
	if not ok then
		player:SetAttribute("FillMove", nil)
	end
	target.players += ok and 1 or 0
	return ok
end

function ServerFillService:Init(registry)
	pcall(function()
		map = MemoryStoreService:GetSortedMap(MAP_NAME)
	end)
	-- a move that fails (the server filled up or closed): they just stay here and play
	pcall(function()
		TeleportService.TeleportInitFailed:Connect(function(player)
			player:SetAttribute("FillMove", nil)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		arrivedByMove[player] = nil
		portalAt[player] = nil
	end)
	-- walking into the portal
	local portal = WorldBuilder.layout and WorldBuilder.layout.portal
	if portal then
		local dragons = registry.DragonService
		local arenaPortal = WorldBuilder.layout.arenaPortal
		pcall(function()
			arenaPortal.Touched:Connect(function(hit)
				local player = hit.Parent and Players:GetPlayerFromCharacter(hit.Parent)
				if player then
					self:UseArena(player, dragons:Carrying(player) ~= nil)
				end
			end)
		end)
		pcall(function() -- (no Touched in the test engine)
			portal.Touched:Connect(function(hit)
				local player = hit.Parent and Players:GetPlayerFromCharacter(hit.Parent)
				if player then
					self:UsePortal(player, dragons:Carrying(player) ~= nil)
				end
			end)
		end)
	end
end

function ServerFillService:Start()
	if not map then
		return
	end
	task.spawn(function()
		while true do
			self:_beat()
			task.wait(HEARTBEAT)
		end
	end)
	pcall(function()
		game:BindToClose(function()
			pcall(function()
				map:RemoveAsync(game.JobId)
			end)
		end)
	end)
end

return ServerFillService
