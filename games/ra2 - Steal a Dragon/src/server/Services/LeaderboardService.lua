-- The three lobby leaderboards: TOP COINS (lifetime coins earned), TOP THIEVES (steals) and BEST DRAGONS
-- (best coins per second). Global boards use OrderedDataStores; if those are unavailable (Studio without API
-- access) the boards show the players in this server instead.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Format = require(ReplicatedStorage.Shared.Format)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local LeaderboardService = {
	Name = "LeaderboardService",
	Dependencies = { "PlayerDataService" },
}

local BOARDS = {
	{ key = "coins", store = "SAD_LB_Earned_v1", field = "earned", fmt = Format.num },
	{
		key = "steals",
		store = "SAD_LB_Steals_v1",
		field = "steals",
		fmt = function(v)
			return Format.commas(v)
		end,
	},
	{
		key = "income",
		store = "SAD_LB_Income_v1",
		field = "bestIncome",
		fmt = function(v)
			return Format.num(v) .. "/s"
		end,
	},
}

local data
local stores = {} -- [key] = OrderedDataStore or false
local names = {} -- [userId] = name
local lastRefresh = -math.huge

function LeaderboardService:Init(registry)
	data = registry.PlayerDataService
	for _, b in BOARDS do
		local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, b.store)
		stores[b.key] = ok and store or false
	end
end

local function nameOf(userId)
	local p = Players:GetPlayerByUserId(userId)
	if p then
		names[userId] = p.DisplayName
		return p.DisplayName
	end
	if names[userId] then
		return names[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = ok and name or ("Player " .. userId)
	return names[userId]
end

function LeaderboardService:Write(player)
	local profile = data:Get(player)
	if not profile or profile._noSave then
		return
	end
	for _, b in BOARDS do
		local store = stores[b.key]
		if store then
			local value = math.floor(profile[b.field] or 0)
			pcall(store.SetAsync, store, "u_" .. player.UserId, value)
		end
	end
end

local function draw(board, rows, sub)
	local view = WorldBuilder.layout.boards[board.key]
	view.sub.Text = sub
	for i, row in view.rows do
		local r = rows[i]
		row.name.Text = r and r.name or ""
		row.value.Text = r and board.fmt(r.value) or ""
	end
end

-- Merge the global rows with the live numbers of everyone in this server (the store only updates every few
-- minutes, and is empty in a brand-new game), keeping each player's highest value.
local function withServerPlayers(board, rows)
	local byId = {}
	for _, r in rows do
		byId[r.id] = r
	end
	for _, p in Players:GetPlayers() do
		local profile = data:Get(p)
		if profile then
			local value = math.floor(profile[board.field] or 0)
			local r = byId[p.UserId]
			if r then
				r.value = math.max(r.value, value)
				r.name = p.DisplayName
			else
				byId[p.UserId] = { id = p.UserId, name = p.DisplayName, value = value }
			end
		end
	end
	local out = {}
	for _, r in byId do
		table.insert(out, r)
	end
	table.sort(out, function(a, b)
		return a.value > b.value
	end)
	return out
end

function LeaderboardService:Refresh()
	lastRefresh = os.clock()
	for _, board in BOARDS do
		local store = stores[board.key]
		local ok, rows = false, nil
		if store then
			ok, rows = pcall(function()
				local pages = store:GetSortedAsync(false, Constants.LEADERBOARD_SIZE)
				local out = {}
				for _, entry in pages:GetCurrentPage() do
					local id = tonumber(string.match(entry.key, "^u_(%d+)$"))
					if id then
						table.insert(out, { id = id, name = nameOf(id), value = entry.value })
					end
				end
				return out
			end)
		end
		if ok and rows then
			draw(board, withServerPlayers(board, rows), "All players · updates every minute")
		else
			draw(board, withServerPlayers(board, {}), "This server (turn on API access to go global)")
		end
	end
end

function LeaderboardService:OnPlayerReady()
	if os.clock() - lastRefresh > 15 then -- stay inside the DataStore read budget
		task.defer(function()
			self:Refresh()
		end)
	end
end

function LeaderboardService:OnPlayerLeaving(player)
	self:Write(player)
end

function LeaderboardService:Start()
	self:Refresh()
	local sinceWrite = 0
	while true do
		task.wait(Constants.LEADERBOARD_READ_SECONDS)
		sinceWrite += Constants.LEADERBOARD_READ_SECONDS
		if sinceWrite >= Constants.LEADERBOARD_WRITE_SECONDS then
			sinceWrite = 0
			for _, p in Players:GetPlayers() do
				self:Write(p)
			end
		end
		self:Refresh()
	end
end

return LeaderboardService
