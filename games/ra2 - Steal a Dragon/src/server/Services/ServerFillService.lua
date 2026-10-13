-- Fill the first servers first: Roblox spreads new players over servers, but a full server is more fun. Every
-- server keeps a row in a shared MemoryStore map (its number, how many players, room left, game version), so
-- each one knows about the others. When a player joins a server and a lower-numbered server of the same version
-- has room, they're sent there before their save loads (so nothing is lost and nothing is locked).
-- Never moved: players who followed a friend or came in on an invite, friends of someone already here, players
-- who were just moved (no ping-pong), private servers, Studio.
--
-- The server's number (1, 2, 3...) is the smallest one no live server is using; the Discord log shows it.
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local ServerFillService = {
	Name = "ServerFillService",
	Dependencies = {},
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

function ServerFillService:Init()
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
	end)
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
