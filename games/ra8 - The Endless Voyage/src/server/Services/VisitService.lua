--[[
Visiting (like visiting a base in Clash of Clans): look at anyone's raft, but never touch it. The VISIT panel lists
the players in this server, your friends and the top of the leaderboards; pick one and the server sends a copy of
their raft (from the live raft if they're here, else from their save, even when they're offline). Your client shows
it on its own patch of sea with a camera you can swing round, and you come back with BACK. Nothing is built in the
world, so a visitor can't collect, build or break anything, and you never sail up to another raft.
]]
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Pieces = require(ReplicatedStorage.Shared.Data.Pieces)
local Signal = require(ReplicatedStorage.Shared.Signal)

local VisitService = {
	Name = "VisitService",
	Dependencies = { "PlayerDataService", "RaftService", "PlayerService" },
	Visited = Signal.new("VisitService.Visited"), -- (player, hostUserId, hostPlayer?) someone looked at a raft
}

local data, rafts, registry
local names = {} -- [userId] = name (cache)
local seen = {} -- [player] = { [hostUserId] = true } this session (a host counts each visitor once)

local function nameOf(userId)
	if names[userId] then
		return names[userId]
	end
	local p = Players:GetPlayerByUserId(userId)
	if p then
		names[userId] = p.DisplayName
		return p.DisplayName
	end
	local ok, n = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = ok and n or ("Sailor " .. tostring(userId))
	return names[userId]
end

local function cleanPieces(list)
	local out = {}
	for _, p in type(list) == "table" and list or {} do
		if type(p) == "table" and Pieces.get(p.key) and type(p.gx) == "number" and type(p.gz) == "number" then
			table.insert(out, { key = p.key, gx = p.gx, gz = p.gz, level = p.level == 2 and 2 or 1, rot = p.rot or 0 })
		end
	end
	return out
end

-- A copy of someone's raft to look at: { userId, name, tier, tierName, tiles, pieces, colours } or nil, reason.
function VisitService:Snapshot(userId)
	userId = tonumber(userId)
	if not userId then
		return nil, "Nobody there."
	end
	local here = Players:GetPlayerByUserId(userId)
	local raft = here and rafts:RaftOf(here)
	if raft then
		local list = {}
		for _, p in raft.pieces do
			table.insert(list, { key = p.key, gx = p.gx, gz = p.gz, level = p.level, rot = p.rot })
		end
		local t = Pieces.TIERS[raft.tier]
		return {
			userId = userId,
			name = here.DisplayName,
			tier = raft.tier,
			tierName = t and t.name or "",
			tiles = raft.summary.tiles,
			pieces = list,
			colours = raft.colours,
		}
	end
	-- not here: their save (read only)
	local profile
	local ok = pcall(function()
		local st = DataStoreService:GetDataStore(Constants.PROFILE_STORE)
		profile = st:GetAsync("u_" .. userId)
	end)
	if not ok or type(profile) ~= "table" or type(profile.raft) ~= "table" then
		return nil, "Couldn't find that raft right now."
	end
	local list = cleanPieces(profile.raft.pieces)
	local tiles = 0
	for _, p in list do
		if Pieces.get(p.key).structural and p.level == 1 then
			tiles += 1
		end
	end
	local tier = profile.records and tonumber(profile.records.tier) or 1
	local t = Pieces.TIERS[tier]
	return {
		userId = userId,
		name = nameOf(userId),
		tier = tier,
		tierName = t and t.name or "",
		tiles = tiles,
		pieces = list,
		colours = type(profile.raft.colours) == "table" and profile.raft.colours or {},
	}
end

function VisitService:Visit(player, userId)
	userId = tonumber(userId)
	if not userId then
		return false
	end
	if userId == player.UserId then
		Net.fire(player, "Toast", "That's your own raft! Look around you 😄", "info")
		return false
	end
	local snap, why = self:Snapshot(userId)
	if not snap then
		Net.fire(player, "Toast", `🔍 {why}`, "bad")
		return false
	end
	Net.fire(player, "Visiting", snap)
	seen[player] = seen[player] or {}
	local first = not seen[player][userId]
	seen[player][userId] = true
	local host = Players:GetPlayerByUserId(userId)
	if first then
		local mine = data:Get(player)
		if mine then
			mine.stats.visits += 1
		end
		if host then
			local theirs = data:Get(host)
			if theirs then
				theirs.stats.visitors += 1
			end
			Net.fire(host, "Toast", `👀 {player.DisplayName} is looking at your raft!`, "info")
		end
	end
	self.Visited:Fire(player, userId, host)
	return true
end

-- The players in this server (with rafts), for the VISIT panel and the FRIENDS panel.
function VisitService:Rafts(player)
	local out = {}
	for _, other in Players:GetPlayers() do
		local raft = rafts:RaftOf(other)
		if raft and other ~= player then
			local okF, friend = pcall(player.IsFriendsWith, player, other.UserId)
			table.insert(out, {
				userId = other.UserId,
				name = other.DisplayName,
				tier = raft.tier,
				tiles = raft.summary.tiles,
				friend = okF and friend or false,
			})
		end
	end
	table.sort(out, function(a, b)
		return a.name < b.name
	end)
	return out
end

-- Your friends (online or not) for the VISIT panel.
function VisitService:Friends(player)
	local out = {}
	local ok, pages = pcall(Players.GetFriendsAsync, Players, player.UserId)
	if not ok or not pages then
		return out
	end
	pcall(function()
		for _ = 1, 3 do
			for _, f in pages:GetCurrentPage() do
				names[f.Id] = f.DisplayName or f.Username
				table.insert(out, { userId = f.Id, name = f.DisplayName or f.Username, online = f.IsOnline or nil })
			end
			if pages.IsFinished or #out >= 100 then
				break
			end
			pages:AdvanceToNextPageAsync()
		end
	end)
	return out
end

-- The top of a leaderboard (the biggest rafts by default).
function VisitService:Top(player, board)
	local lb = registry.LeaderboardService
	local view = lb and lb:View(player, board or "tiles")
	local out = {}
	for _, r in view and view.global or {} do
		if r.userId and r.userId > 0 then
			table.insert(out, { userId = r.userId, name = r.name, value = r.value, rank = r.rank })
		end
	end
	return out
end

function VisitService:List(player, kind)
	local rows
	if kind == "friends" then
		rows = self:Friends(player)
	elseif kind == "top" then
		rows = self:Top(player, "tiles")
	else
		kind = "here"
		rows = self:Rafts(player)
	end
	Net.fire(player, "VisitList", { kind = kind, rows = rows })
	return rows
end

function VisitService:Init(reg)
	registry = reg
	data = reg.PlayerDataService
	rafts = reg.RaftService
	Net.on("Visit", function(player, userId)
		self:Visit(player, userId)
	end)
	Net.on("VisitList", function(player, kind)
		self:List(player, kind)
	end)
	Players.PlayerRemoving:Connect(function(player)
		seen[player] = nil
	end)
end

return VisitService
