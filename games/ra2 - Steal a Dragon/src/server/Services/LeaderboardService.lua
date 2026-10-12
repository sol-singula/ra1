-- The four lobby leaderboards:
--   TOP COINS            coins each player has right now
--   TODAY'S TOP EARNERS  coins earned since the last 7pm Eastern; #1 when it resets wins the Ultra prize dragon
--   BEST DRAGONS         the coins per second of each player's best dragon right now (lose it, lose the spot)
--   TOP THIEVES          lifetime steals
-- Global rows come from OrderedDataStores (read every minute, written every two); on top of those, the players in
-- this server always show their live numbers, redrawn every couple of seconds. Without DataStores (Studio
-- without API access) the boards show this server only.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Dragons = require(ReplicatedStorage.Shared.Data.Dragons)
local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local LeaderboardService = {
	Name = "LeaderboardService",
	Dependencies = { "PlayerDataService", "EconomyService", "DragonService" },
	PrizeWon = Signal.new("LeaderboardService.PrizeWon"), -- (player, period) won the daily TOP EARNER prize
}

local data, economy, dragons

-- The best dragon a profile owns right now: its coins per second and its record.
local function bestDragon(profile)
	local best, bestRec = 0, nil
	local now = os.time()
	for _, rec in profile.dragons do
		local cps = Formulas.dragonIncome(rec, now)
		if cps > best then
			best, bestRec = cps, rec
		end
	end
	return best, bestRec
end

local BOARDS = {
	{
		key = "coins",
		store = "SAD_LB_Coins_v1",
		value = function(profile)
			return profile.coins
		end,
		fmt = Format.num,
		sub = "Coins right now",
	},
	{
		key = "daily",
		store = "SAD_LB_Daily_v1_", -- + the period number: a fresh board every day
		daily = true,
		value = function(profile)
			return economy.dailyEarned(profile)
		end,
		fmt = Format.num,
		sub = "Coins earned today",
	},
	{
		key = "income",
		store = "SAD_LB_BestDragon_v1",
		value = function(profile)
			return (bestDragon(profile))
		end,
		label = function(player, profile)
			local _, rec = bestDragon(profile)
			return rec and `{player.DisplayName} · {Dragons.byId[rec.id].name}` or player.DisplayName
		end,
		fmt = function(v)
			return Format.num(v) .. "/s"
		end,
		sub = "Best dragon each player owns right now",
	},
	{
		key = "steals",
		store = "SAD_LB_Steals_v1",
		value = function(profile)
			return profile.steals
		end,
		fmt = function(v)
			return Format.commas(v)
		end,
		sub = "Dragons stolen, all time",
	},
}

local stores = {} -- [key] = OrderedDataStore or false (the daily store is opened per period)
local globalRows = {} -- [key] = rows from the last global read
local globalOk = {} -- [key] = true if the last read worked
local names = {} -- [userId] = name
local lastRefresh = -math.huge
local period = 0 -- the daily period the boards are showing
local liveDaily = {} -- this server's daily rows at the last redraw (to pick a winner without DataStores)
local topThree = {} -- [boardKey] = { [rank] = userId } at the last redraw, to announce new top-3 players
local onBoard = {} -- [boardKey] = { [userId] = rank } everyone on the board at the last redraw
local BOARD_NAMES =
	{ coins = "TOP COINS", daily = "TODAY'S TOP EARNERS", income = "BEST DRAGONS", steals = "TOP THIEVES" }

local function store(board)
	if board.daily then
		local ok, s = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, board.store .. period)
		return ok and s or false
	end
	return stores[board.key]
end

function LeaderboardService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	dragons = registry.DragonService
	for _, b in BOARDS do
		if not b.daily then
			local ok, s = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, b.store)
			stores[b.key] = ok and s or false
		end
		globalRows[b.key] = {}
	end
	period = Formulas.dailyPeriod(os.time())
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
		local s = store(b)
		if s then
			pcall(s.SetAsync, s, "u_" .. player.UserId, math.floor(b.value(profile)))
		end
	end
end

-- The global rows with everyone in this server replaced by their live number (coins can go down, a best dragon
-- can be stolen, so the live number wins even when it's lower).
local function merged(board)
	local byId = {}
	for _, r in globalRows[board.key] do
		byId[r.id] = { id = r.id, name = r.name, value = r.value }
	end
	for _, p in Players:GetPlayers() do
		local profile = data:Get(p)
		if profile then
			byId[p.UserId] = {
				id = p.UserId,
				name = board.label and board.label(p, profile) or p.DisplayName,
				value = math.floor(board.value(profile)),
			}
		end
	end
	local out = {}
	for _, r in byId do
		if r.value > 0 or board.key ~= "daily" then
			table.insert(out, r)
		end
	end
	table.sort(out, function(a, b)
		return a.value > b.value
	end)
	return out
end

-- Redraw every board from the cached global rows and the live numbers here (no DataStore calls).
function LeaderboardService:Redraw()
	local now = os.time()
	local newPeriod, endsAt = Formulas.dailyPeriod(now)
	if newPeriod ~= period then
		self:_rollover(period)
		period = newPeriod
		globalRows.daily = {}
	end
	for _, board in BOARDS do
		local view = WorldBuilder.layout.boards[board.key]
		local rows = merged(board)
		if board.daily then
			liveDaily = rows
		end
		view.sub.Text = board.sub .. (globalOk[board.key] and " · all players" or " · this server")
		self:_announceTop(board, rows)
		for i, row in view.rows do
			local r = rows[i]
			row.name.Text = r and r.name or ""
			row.value.Text = r and board.fmt(r.value) or ""
		end
	end
	local timer = WorldBuilder.layout.boards.daily.timer
	if timer then
		timer.Text = "⏰ Ends in " .. Format.time(math.max(0, endsAt - now))
	end
end

-- Someone in this server just took #1, #2 or #3 on a board (and has something on it): tell everyone.
-- Also: someone in this server just made the board at all (into the top 10 from off it).
function LeaderboardService:_announceTop(board, rows)
	local before = topThree[board.key]
	local now3 = {}
	for rank = 1, 3 do
		local r = rows[rank]
		now3[rank] = r and r.value > 0 and r.id or nil
	end
	topThree[board.key] = now3
	local beforeOn = onBoard[board.key]
	local nowOn = {}
	for rank = 1, Constants.LEADERBOARD_SIZE do
		local r = rows[rank]
		if r and r.value > 0 then
			nowOn[r.id] = rank
		end
	end
	onBoard[board.key] = nowOn
	if not before then
		return -- the first draw: nothing has changed yet
	end
	for id, rank in nowOn do
		local p = rank > 3 and not beforeOn[id] and Players:GetPlayerByUserId(id)
		if p then
			Net.fireAll(
				"Announce",
				`📋 {p.DisplayName} made the {BOARD_NAMES[board.key]} board! (#{rank})`,
				Color3.fromRGB(120, 220, 255)
			)
		end
	end
	for rank = 1, 3 do
		local id = now3[rank]
		local wasRank
		for k = 1, 3 do
			if before[k] == id then
				wasRank = k
			end
		end
		local p = id and Players:GetPlayerByUserId(id)
		if p and (not wasRank or rank < wasRank) then
			local medal = ({ "🥇", "🥈", "🥉" })[rank]
			Net.fireAll(
				"Announce",
				`{medal} {p.DisplayName} is now #{rank} on {BOARD_NAMES[board.key]}!`,
				({ Color3.fromRGB(255, 205, 60), Color3.fromRGB(210, 215, 230), Color3.fromRGB(225, 150, 90) })[rank]
			)
		end
	end
end

-- Read the global rows (every minute), then redraw.
function LeaderboardService:Refresh()
	lastRefresh = os.clock()
	for _, board in BOARDS do
		local s = store(board)
		local ok, rows = false, nil
		if s then
			ok, rows = pcall(function()
				local pages = s:GetSortedAsync(false, Constants.LEADERBOARD_SIZE)
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
		globalOk[board.key] = ok and rows ~= nil
		if ok and rows then
			globalRows[board.key] = rows
		end
	end
	self:Redraw()
end

-- Daily prize ---------------------------------------------------------------------------------------------------
-- Give the Ultra prize dragon to the winner of a period (once per period, even across servers and rejoins).
function LeaderboardService:GivePrize(player, forPeriod)
	local profile = data:Get(player)
	local key = tostring(forPeriod)
	if not profile or profile.prizes[key] then
		return false
	end
	profile.prizes[key] = true
	dragons:Grant(player, Dragons.PRIZE)
	self.PrizeWon:Fire(player, forPeriod)
	local d = Dragons.byId[Dragons.PRIZE]
	Net.fireAll(
		"Alert",
		`👑 {player.DisplayName} was today's TOP EARNER and won {d.name} (ULTRA)!`,
		Dragons.RarityColor.Ultra
	)
	return true
end

-- The user id at #1 of a finished period: from the global store, or from this server's last live rows.
function LeaderboardService:WinnerOf(forPeriod)
	local daily
	for _, b in BOARDS do
		if b.daily then
			daily = b
		end
	end
	local ok, s = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, daily.store .. forPeriod)
	if ok and s then
		local okRead, top = pcall(function()
			local entries = s:GetSortedAsync(false, 1):GetCurrentPage()
			return entries[1] and tonumber(string.match(entries[1].key, "^u_(%d+)$"))
		end)
		if okRead and top then
			return top
		end
	end
	if forPeriod == period and liveDaily[1] and liveDaily[1].value > 0 then
		return liveDaily[1].id
	end
	return nil
end

-- A period just ended: save everyone's final numbers, then crown the winner if they're in this server.
function LeaderboardService:_rollover(ended)
	for _, p in Players:GetPlayers() do
		local profile = data:Get(p)
		if profile and not profile._noSave then
			local ok, s = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, "SAD_LB_Daily_v1_" .. ended)
			if ok and s then
				-- the period is over, so this is the coins earned in it (dailyEarned resets on the next coin)
				local earned = profile.dailyPeriod == ended and profile.dailyEarned or 0
				pcall(s.SetAsync, s, "u_" .. p.UserId, math.floor(earned))
			end
		end
	end
	local winner = self:WinnerOf(ended)
	local p = winner and Players:GetPlayerByUserId(winner)
	if p then
		self:GivePrize(p, ended)
	end
end

function LeaderboardService:OnPlayerReady(player)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			Net.fire(other, "Announce", `👋 {player.DisplayName} joined the game!`, Color3.fromRGB(120, 220, 255))
		end
	end
	-- won yesterday's board while away? (one store read)
	task.defer(function()
		local last = period - 1
		if self:WinnerOf(last) == player.UserId then
			self:GivePrize(player, last)
		end
	end)
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
	local sinceWrite, sinceRead = 0, 0
	while true do
		task.wait(Constants.LEADERBOARD_LIVE_SECONDS)
		sinceWrite += Constants.LEADERBOARD_LIVE_SECONDS
		sinceRead += Constants.LEADERBOARD_LIVE_SECONDS
		if sinceWrite >= Constants.LEADERBOARD_WRITE_SECONDS then
			sinceWrite = 0
			for _, p in Players:GetPlayers() do
				self:Write(p)
			end
		end
		if sinceRead >= Constants.LEADERBOARD_READ_SECONDS then
			sinceRead = 0
			self:Refresh()
		else
			self:Redraw()
		end
	end
end

return LeaderboardService
