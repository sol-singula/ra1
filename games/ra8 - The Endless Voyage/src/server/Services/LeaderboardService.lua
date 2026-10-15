--[[
The leaderboards (master plan §9: friend-first leaderboards, the eight categories in Data/Progression.BOARDS).

  * Your records live in your profile (ProgressService keeps them). When one changes it goes to that category's
    OrderedDataStore (BOARD_STORE_PREFIX .. key) and to a small public card (PUBLIC_STORE: your name, level, title
    and all eight records) that friends in other servers can read. Only changed values are written, at most once
    a minute per player, at the end of a run and when you leave (profile.boards remembers what's there already).
  * FRIENDS FIRST: the server reads your friends list (Players:GetFriendsAsync, up to BOARD_FRIENDS_MAX) when you
    join, then each friend's public card, slowly (one read a second for the whole server, shared by everyone here,
    kept for CARD_TTL), so the DataStore budget never runs dry. Friends in this server are read live.
  * EVERYONE: the top BOARD_TOP of each category, refreshed one category at a time every BOARD_REFRESH seconds.
  * "Board" (client -> server: a category key) answers with
      { category, friends = rows, global = rows, you = row, loading = friends still being read }
    where a row is { userId, name, value, rank, you?, here?, friend? }.
Without DataStores (Studio) the friends board still works for friends in this server.
]]
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Progression = require(ReplicatedStorage.Shared.Data.Progression)
local Signal = require(ReplicatedStorage.Shared.Signal)

local LeaderboardService = {
	Name = "LeaderboardService",
	Dependencies = { "PlayerDataService", "ProgressService" },
	Written = Signal.new("LeaderboardService.Written"), -- (player, boardKeys) records went to the stores
	Refreshed = Signal.new("LeaderboardService.Refreshed"), -- (boardKey) a global top list was read
}

local WRITE_EVERY = 60
local CARD_TTL = 600
local READ_EVERY = 1
local PUSH_EVERY = 3

local data, progress
local publicStore
local stores = {} -- [boardKey] = OrderedDataStore
local cards = {} -- [userId] = { at, name, records, level, title } | { at, none = true }
local friendIds = {} -- [player] = { userId, ... }
local friendSet = {} -- [player] = { [userId] = true }
local queue, queued = {}, {} -- friends' cards waiting to be read
local dirty = {} -- [player] = true: a record changed since the last write
local lastWrite = {} -- [player] = os.clock()
local global = {} -- [boardKey] = { at, rows }
local names = {} -- [userId] = name
local wanted = {} -- [player] = the category they last asked for
local stale = {} -- [player] = true: a friend's card arrived since their last push

local function value(board, records)
	local v = type(records) == "table" and records[board.record]
	if type(v) ~= "number" or v ~= v or v <= 0 then
		return nil
	end
	return math.floor(v)
end

local function better(board, a, b)
	if board.ascending then
		return a < b
	end
	return a > b
end

local function sortRows(board, rows)
	table.sort(rows, function(a, b)
		if a.value and b.value then
			if a.value ~= b.value then
				return better(board, a.value, b.value)
			end
		elseif a.value or b.value then
			return a.value ~= nil
		end
		return (a.name or "") < (b.name or "")
	end)
	local rank = 0
	for _, r in rows do
		if r.value then
			rank += 1
			r.rank = rank
		end
	end
end

local function nameOf(userId)
	local p = Players:GetPlayerByUserId(userId)
	if p then
		return p.DisplayName
	end
	local c = cards[userId]
	if c and c.name then
		return c.name
	end
	if names[userId] then
		return names[userId]
	end
	local ok, n = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = ok and n or ("Player " .. userId)
	return names[userId]
end

-- The card friends in other servers read.
function LeaderboardService:Card(player, profile)
	local records = {}
	for _, board in Progression.BOARDS do
		records[board.record] = profile.records[board.record]
	end
	return {
		name = player.DisplayName,
		level = (Formulas.level(profile.xp)),
		title = profile.titles and profile.titles.equipped or nil,
		records = records,
		at = os.time(),
	}
end

-- Write what changed (profile passed in: it can run while the player is leaving).
function LeaderboardService:Write(player, profile)
	profile = profile or data:Get(player)
	if not profile then
		return {}
	end
	dirty[player] = nil
	lastWrite[player] = os.clock()
	profile.boards = profile.boards or {}
	local changed = {}
	for _, board in Progression.BOARDS do
		local v = value(board, profile.records)
		local store = stores[board.key]
		if v and store and profile.boards[board.record] ~= v then
			local ok = pcall(store.SetAsync, store, tostring(player.UserId), v)
			if ok then
				profile.boards[board.record] = v
				table.insert(changed, board.key)
			end
		end
	end
	if #changed > 0 and publicStore then
		pcall(publicStore.SetAsync, publicStore, tostring(player.UserId), self:Card(player, profile))
	end
	if #changed > 0 then
		self.Written:Fire(player, changed)
	end
	return changed
end

function LeaderboardService:_queue(userId)
	if queued[userId] or Players:GetPlayerByUserId(userId) then
		return
	end
	local c = cards[userId]
	if c and os.clock() - c.at < CARD_TTL then
		return
	end
	queued[userId] = true
	table.insert(queue, userId)
end

-- One friend's card from the public store.
function LeaderboardService:_readNext()
	local userId = table.remove(queue, 1)
	if not userId then
		return false
	end
	queued[userId] = nil
	if not publicStore or Players:GetPlayerByUserId(userId) then
		return true
	end
	local ok, card = pcall(publicStore.GetAsync, publicStore, tostring(userId))
	if not ok then
		return true
	end
	if type(card) == "table" and type(card.records) == "table" then
		cards[userId] = {
			at = os.clock(),
			name = type(card.name) == "string" and string.sub(card.name, 1, 40) or names[userId],
			records = card.records,
			level = tonumber(card.level),
			title = card.title,
		}
	else
		cards[userId] = { at = os.clock(), none = true, name = names[userId] }
	end
	for player, set in friendSet do
		if set[userId] then
			stale[player] = true
		end
	end
	return true
end

function LeaderboardService:_loadFriends(player)
	local ids, set = {}, {}
	local ok, pages = pcall(Players.GetFriendsAsync, Players, player.UserId)
	if ok and pages then
		while #ids < Constants.BOARD_FRIENDS_MAX do
			local okPage, page = pcall(pages.GetCurrentPage, pages)
			if not okPage or type(page) ~= "table" then
				break
			end
			for _, f in page do
				local id = tonumber(f.Id)
				if id and not set[id] and #ids < Constants.BOARD_FRIENDS_MAX then
					set[id] = true
					table.insert(ids, id)
					if type(f.DisplayName) == "string" then
						names[id] = f.DisplayName
					end
				end
			end
			if pages.IsFinished or #ids >= Constants.BOARD_FRIENDS_MAX then
				break
			end
			if not pcall(pages.AdvanceToNextPageAsync, pages) then
				break
			end
		end
	end
	if not player.Parent then
		return
	end
	for _, id in friendIds[player] or {} do
		if not set[id] then
			set[id] = true
			table.insert(ids, id)
		end
	end
	friendIds[player] = ids
	friendSet[player] = set
	for _, id in ids do
		self:_queue(id)
	end
end

function LeaderboardService:FriendRows(player, board)
	local rows, seen = {}, {}
	local function add(userId, name, v, extra)
		if seen[userId] then
			return
		end
		seen[userId] = true
		local row = { userId = userId, name = name, value = v }
		for k, x in extra do
			row[k] = x
		end
		table.insert(rows, row)
	end
	local profile = data:Get(player)
	add(player.UserId, player.DisplayName, profile and value(board, profile.records), { you = true })
	for _, id in friendIds[player] or {} do
		local here = Players:GetPlayerByUserId(id)
		if here then
			local p = data:Get(here)
			local v = p and value(board, p.records)
			if v then
				add(id, here.DisplayName, v, { here = true })
			end
		else
			local c = cards[id]
			local v = c and not c.none and value(board, c.records)
			if v then
				add(id, c.name or nameOf(id), v, {})
			end
		end
	end
	sortRows(board, rows)
	return rows
end

function LeaderboardService:_refreshGlobal(board)
	local store = stores[board.key]
	if not store then
		return false
	end
	local ok, pages = pcall(store.GetSortedAsync, store, board.ascending == true, Constants.BOARD_TOP)
	if not ok or not pages then
		return false
	end
	local okPage, page = pcall(pages.GetCurrentPage, pages)
	if not okPage or type(page) ~= "table" then
		return false
	end
	local rows = {}
	for _, entry in page do
		local id = tonumber(entry.key)
		if id and type(entry.value) == "number" and entry.value > 0 then
			table.insert(rows, { userId = id, name = nameOf(id), value = entry.value })
		end
	end
	for i, r in rows do
		r.rank = i
	end
	global[board.key] = { at = os.time(), rows = rows }
	self.Refreshed:Fire(board.key)
	return true
end

function LeaderboardService:View(player, key)
	local board = Progression.boardByKey[key]
	if not board then
		return nil
	end
	local friends = self:FriendRows(player, board)
	local you
	for _, r in friends do
		if r.you then
			you = r
		end
	end
	local set = friendSet[player] or {}
	local top = {}
	local g = global[key]
	for _, r in g and g.rows or {} do
		table.insert(top, {
			userId = r.userId,
			name = r.name,
			value = r.value,
			rank = r.rank,
			you = r.userId == player.UserId or nil,
			friend = set[r.userId] or nil,
		})
	end
	local loading = 0
	for _, id in friendIds[player] or {} do
		if not cards[id] and queued[id] then
			loading += 1
		end
	end
	return {
		category = key,
		friends = friends,
		global = top,
		you = you,
		friendCount = #(friendIds[player] or {}),
		loading = loading > 0 and loading or nil,
		at = g and g.at or nil,
	}
end

function LeaderboardService:Push(player, key)
	local view = self:View(player, key or wanted[player] or Progression.BOARDS[1].key)
	if view then
		stale[player] = nil
		Net.fire(player, "Board", view)
	end
end

function LeaderboardService:Init(registry)
	data = registry.PlayerDataService
	progress = registry.ProgressService
	local okP, ps = pcall(DataStoreService.GetDataStore, DataStoreService, Constants.PUBLIC_STORE)
	publicStore = okP and ps or nil
	for _, board in Progression.BOARDS do
		local ok, store =
			pcall(DataStoreService.GetOrderedDataStore, DataStoreService, Constants.BOARD_STORE_PREFIX .. board.key)
		stores[board.key] = ok and store or nil
	end
	Net.on("Board", function(player, key)
		if type(key) == "string" and Progression.boardByKey[key] then
			wanted[player] = key
			self:Push(player, key)
		end
	end)
	progress.RecordsChanged:Connect(function(player)
		dirty[player] = true
	end)
	progress.Rewarded:Connect(function(player)
		-- the end of a run: write now (the next run may be someone's last)
		task.spawn(self.Write, self, player)
	end)
	pcall(function()
		game:BindToClose(function()
			for _, player in Players:GetPlayers() do
				if dirty[player] then
					self:Write(player)
				end
			end
		end)
	end)
end

-- Friends in this server always count (the friends list read on joining stops at BOARD_FRIENDS_MAX).
function LeaderboardService:_linkHere(player)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local ok, yes = pcall(player.IsFriendsWith, player, other.UserId)
			if ok and yes then
				for _, pair in { { player, other }, { other, player } } do
					local a, b = pair[1], pair[2]
					friendSet[a] = friendSet[a] or {}
					friendIds[a] = friendIds[a] or {}
					if not friendSet[a][b.UserId] then
						friendSet[a][b.UserId] = true
						table.insert(friendIds[a], b.UserId)
					end
				end
			end
		end
	end
end

function LeaderboardService:OnPlayerReady(player)
	task.spawn(function()
		self:_loadFriends(player)
		self:_linkHere(player)
	end)
end

function LeaderboardService:OnPlayerLeaving(player, profile)
	if profile and dirty[player] then
		task.spawn(self.Write, self, player, profile)
	end
	friendIds[player] = nil
	friendSet[player] = nil
	dirty[player] = nil
	lastWrite[player] = nil
	wanted[player] = nil
	stale[player] = nil
end

function LeaderboardService:Start()
	local nextBoard = 1
	local refreshEvery = math.max(5, Constants.BOARD_REFRESH / #Progression.BOARDS)
	local refreshAcc, readAcc, pushAcc = refreshEvery, 0, 0
	while true do
		task.wait(1)
		readAcc += 1
		if readAcc >= READ_EVERY then
			readAcc = 0
			self:_readNext()
		end
		refreshAcc += 1
		if refreshAcc >= refreshEvery and #Players:GetPlayers() > 0 then
			refreshAcc = 0
			task.spawn(self._refreshGlobal, self, Progression.BOARDS[nextBoard])
			nextBoard = nextBoard % #Progression.BOARDS + 1
		end
		for player in dirty do
			if os.clock() - (lastWrite[player] or -math.huge) >= WRITE_EVERY then
				task.spawn(self.Write, self, player)
			end
		end
		pushAcc += 1
		if pushAcc >= PUSH_EVERY then
			pushAcc = 0
			for player in stale do
				if wanted[player] then
					self:Push(player)
				else
					stale[player] = nil
				end
			end
		end
	end
end

-- (tests)
function LeaderboardService:_cards()
	return cards, queue
end

return LeaderboardService
