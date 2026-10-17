--[[
The leaderboards (the 🏆 TOP panel: LeaderboardController). Four boards, from what the profile already keeps:

  wins     qualifying wins (profile.wins)        kills    stats.kills
  mvps     stats.mvps                            streak   the best win streak (profile.best)

All time: one OrderedDataStore per board (Constants.LEADERBOARD_STORE: TW_Top_wins_v1 ..., key = the UserId,
value = the number). A player's numbers are written when they join, after each match and when they leave, at most
once a minute each (LEADERBOARD_WRITE_SECONDS), only the boards that changed, and only while the DataStore budget
allows; what has to wait is kept and written later, even after they've gone (and at shutdown). Every
LEADERBOARD_REFRESH_SECONDS the top 50 of each board is read again; a read that fails keeps the last good copy.
Names come from Roblox (UserService, cached; the people here by their display names).

This server: worked out live from the people here (MatchService:People(): no bots, no spectating admins).

Never written: bots, spectating admins, Studio's test players (a UserId of 0 or less). Every call is in a pcall.

The client asks with Net "Top" () and gets Net "Leaderboards":
  { boards = { [board] = { { rank, userId, name, value } } },   the all-time top 50 (the last good read)
    server = { [board] = { { rank, userId, name, value } } },   everyone here, best first
    you = { [board] = { value, rank?, serverRank } },           rank: in the all-time top 50, if you are
    ok, at, every }                                              ok: the all-time boards were read; at: when (os.time)
Everyone who has asked gets it again after each refresh and each match.

  LeaderboardService:Write(player)    queue this player's numbers (written when the throttle allows)
  LeaderboardService:Flush(force?)    write what's due (force: all of it, the budget permitting)
  LeaderboardService:Refresh()        read the top of every board
  LeaderboardService:Payload(player)  what Net "Leaderboards" carries for them
  LeaderboardService.BOARDS
]]
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Admins = require(script.Parent.Parent.Admins)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)

-- (MatchService isn't a dependency: in the lobby place there's no match, and "this server" is everyone here)
local LeaderboardService = {
	Name = "LeaderboardService",
	Dependencies = { "PlayerDataService" },
}

local function int(n)
	return math.max(0, math.floor(tonumber(n) or 0))
end

local BOARDS = {
	{
		key = "wins",
		name = "WINS",
		read = function(p)
			return int(p.wins)
		end,
	},
	{
		key = "kills",
		name = "KILLS",
		read = function(p)
			return int(p.stats and p.stats.kills)
		end,
	},
	{
		key = "mvps",
		name = "MVPS",
		read = function(p)
			return int(p.stats and p.stats.mvps)
		end,
	},
	{
		key = "streak",
		name = "BEST STREAK",
		read = function(p)
			return int(p.best)
		end,
	},
}
LeaderboardService.BOARDS = BOARDS
LeaderboardService.FLUSH_SECONDS = 5 -- how often what's waiting is looked at

local data, match
local stores = {} -- [board key] = the OrderedDataStore (asked for again until it works)
local top = {} -- [board key] = { { userId, value } } the last good read, best first
local readAt = 0 -- os.time() of the last read that worked (0: none yet)
local names = {} -- [userId] = the name to show
local written = {} -- [userId] = { at = os.clock(), values = { [board] = n } } what the boards have
local pending = {} -- [userId] = { [board] = n } numbers waiting to be written
local watchers = {} -- [player] = true: asked once, so they get the refreshes too
local flushing = false

-- Who goes on the all-time boards: a real Player (a bot is a table), not Studio's test players, not watching unseen
local function counts(player)
	return typeof(player) == "Instance" and player:IsA("Player") and player.UserId > 0 and not Admins.spectating(player)
end

local function store(board)
	if stores[board] then
		return stores[board]
	end
	local ok, s = pcall(function()
		return DataStoreService:GetOrderedDataStore(string.format(Constants.LEADERBOARD_STORE, board))
	end)
	stores[board] = ok and s or nil
	return stores[board]
end

-- How many requests of a kind may go now (unknown: as many as we like; the pcalls catch the rest)
local function budget(kind)
	local ok, n = pcall(function()
		return DataStoreService:GetRequestBudgetForRequestType(kind)
	end)
	return (ok and type(n) == "number") and n or math.huge
end

local function valuesOf(player)
	local p = data:Get(player)
	if not p then
		return nil
	end
	local out = {}
	for _, b in BOARDS do
		out[b.key] = b.read(p)
	end
	return out
end

-- Writing ----------------------------------------------------------------------------------------------------
function LeaderboardService:Write(player)
	if not counts(player) then
		return false
	end
	local values = valuesOf(player)
	if not values then
		return false
	end
	names[player.UserId] = player.DisplayName
	pending[player.UserId] = values
	task.spawn(self.Flush, self)
	return true
end

function LeaderboardService:Flush(force)
	if flushing then
		return
	end
	flushing = true
	local now = os.clock()
	for userId, values in pending do
		local w = written[userId]
		if w and not force and now - w.at < Constants.LEADERBOARD_WRITE_SECONDS then
			continue -- (written a moment ago: this waits its turn)
		end
		local changed = {}
		for _, b in BOARDS do
			local v = values[b.key]
			if v > 0 and v ~= (w and w.values[b.key]) then
				table.insert(changed, b.key)
			end
		end
		if #changed == 0 then
			pending[userId] = nil
			continue
		end
		if budget(Enum.DataStoreRequestType.SetIncrementSortedAsync) < #changed then
			break -- (out of budget: everything left waits for the next look)
		end
		w = w or { values = {} }
		w.at = now
		written[userId] = w
		local failed = false
		for _, key in changed do
			local s = store(key)
			local ok = s ~= nil and pcall(function()
				s:SetAsync(tostring(userId), values[key])
			end)
			if ok then
				w.values[key] = values[key]
			else
				failed = true
			end
		end
		if not failed and pending[userId] == values then
			pending[userId] = nil -- (newer numbers that came in meanwhile stay for next time)
		end
	end
	flushing = false
end

-- Reading ----------------------------------------------------------------------------------------------------
-- Names for the ids on the boards that we don't know yet: one batch from UserService, then a few one by one
local function learnNames()
	local missing = {}
	for _, rows in top do
		for _, r in rows do
			if not names[r.userId] and not table.find(missing, r.userId) then
				table.insert(missing, r.userId)
			end
		end
	end
	if #missing == 0 then
		return
	end
	pcall(function()
		local infos = game:GetService("UserService"):GetUserInfosByUserIdsAsync(missing)
		for _, info in infos do
			names[info.Id] = info.DisplayName or info.Username
		end
	end)
	local asked = 0
	for _, id in missing do
		if not names[id] and asked < 10 then
			asked += 1
			local ok, name = pcall(function()
				return Players:GetNameFromUserIdAsync(id)
			end)
			if ok and type(name) == "string" then
				names[id] = name
			end
		end
	end
end

function LeaderboardService:Refresh()
	local any = false
	for _, b in BOARDS do
		local s = store(b.key)
		if s and budget(Enum.DataStoreRequestType.GetSortedAsync) >= 1 then
			local ok, page = pcall(function()
				return s:GetSortedAsync(false, Constants.LEADERBOARD_SIZE):GetCurrentPage()
			end)
			if ok and type(page) == "table" then
				local rows = {}
				for _, entry in page do
					local id = tonumber(entry.key)
					if id and #rows < Constants.LEADERBOARD_SIZE then
						table.insert(rows, { userId = id, value = int(entry.value) })
					end
				end
				top[b.key] = rows
				any = true
			end
		end
	end
	if any then
		readAt = os.time()
		learnNames()
	end
	return any
end

-- What the client gets -----------------------------------------------------------------------------------------
local function nameOf(userId)
	return names[userId] or ("Player " .. tostring(userId))
end

-- Who "this server" is: the match's people (no bots, no spectating admins), or in the lobby everyone here
local function people()
	if match then
		return match:People()
	end
	local out = {}
	for _, p in Players:GetPlayers() do
		if counts(p) then
			table.insert(out, p)
		end
	end
	return out
end

local function serverRows(board)
	local rows = {}
	for _, p in people() do
		local prof = data:Get(p)
		if prof then
			table.insert(rows, { userId = p.UserId, name = p.DisplayName, value = board.read(prof) })
		end
	end
	table.sort(rows, function(a, b)
		if a.value == b.value then
			return a.name < b.name
		end
		return a.value > b.value
	end)
	for i, r in rows do
		r.rank = i
	end
	return rows
end

function LeaderboardService:Payload(player)
	local out = { boards = {}, server = {}, you = {}, ok = readAt > 0, at = readAt }
	out.every = Constants.LEADERBOARD_REFRESH_SECONDS
	local mine = typeof(player) == "Instance" and valuesOf(player) or nil
	for _, b in BOARDS do
		local rows = {}
		local you = { value = mine and mine[b.key] or 0 }
		for i, r in top[b.key] or {} do
			table.insert(rows, { rank = i, userId = r.userId, name = nameOf(r.userId), value = r.value })
			if player and r.userId == player.UserId then
				you.rank = i
			end
		end
		out.boards[b.key] = rows
		out.server[b.key] = serverRows(b)
		for _, r in out.server[b.key] do
			if player and r.userId == player.UserId then
				you.serverRank = r.rank
			end
		end
		out.you[b.key] = you
	end
	return out
end

function LeaderboardService:Push(player)
	Net.fire(player, "Leaderboards", self:Payload(player))
end

function LeaderboardService:PushWatchers()
	for p in watchers do
		if p.Parent then
			self:Push(p)
		else
			watchers[p] = nil
		end
	end
end

-- Hooks --------------------------------------------------------------------------------------------------------
function LeaderboardService:Init(registry)
	data = registry.PlayerDataService
	match = registry.MatchService -- (nil in the lobby place)
	Net.on("Top", function(player)
		watchers[player] = true
		self:Push(player)
	end)
	-- after each match (ProgressService has already counted it): everyone's new numbers
	if match then
		match.Ended:Connect(function()
			for _, p in match:People() do
				self:Write(p)
			end
			self:PushWatchers()
		end)
	end
	pcall(function()
		game:BindToClose(function()
			self:Flush(true)
		end)
	end)
end

function LeaderboardService:OnPlayerReady(player)
	names[player.UserId] = player.DisplayName
	self:Write(player) -- (puts someone who played before the boards existed on them)
end

function LeaderboardService:OnPlayerLeaving(player)
	watchers[player] = nil
	self:Write(player) -- (their numbers are kept: written when the throttle allows, after they've gone)
end

function LeaderboardService:Start()
	local nextRead = 0
	while true do
		if os.clock() >= nextRead then
			nextRead = os.clock() + Constants.LEADERBOARD_REFRESH_SECONDS
			self:Refresh()
			self:PushWatchers()
		end
		self:Flush()
		task.wait(self.FLUSH_SECONDS)
	end
end

return LeaderboardService
