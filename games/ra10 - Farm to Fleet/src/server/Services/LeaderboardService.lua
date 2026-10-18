--[[
The Hall of Fame (master plan §13.4, §14 I): the best farms of every server, on the gantry over the road at the
street's east end (World/StreetBuilder) and in the STREET panel. Three boards, one OrderedDataStore each
(Constants.LEADERBOARD_STORE with the key):

  earned    MOST CASH EVER        stats.earned (all time, through every franchise)
  best      BIGGEST SHIPMENT      stats.biggestShipment
  size      BIGGEST OPERATION     Flow.size (the most it's ever been)

A farm's values go up at most once every LEADERBOARD_WRITE_SECONDS and when they leave, only when they've grown
(profile.boards remembers what's there); the top six of each are read every LEADERBOARD_REFRESH_SECONDS, and the
gantry turns from one board to the next every PAGE seconds. Without DataStores (Studio, an outage) the boards show
this server's farms.

  LeaderboardService:Write(player, profile?) -> the keys written
  LeaderboardService:Refresh()
  LeaderboardService:Top(key) -> { { rank, userId, name, value } }
]]
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Flow = require(ReplicatedStorage.Shared.Data.Flow)
local Format = require(ReplicatedStorage.Shared.Format)
local StreetBuilder = require(ReplicatedStorage.Shared.World.StreetBuilder)

local LeaderboardService = {
	Name = "LeaderboardService",
	Dependencies = { "PlayerDataService", "StreetService" },
	PAGE = 15,
	page = 1, -- the board the gantry shows
	TOP = 6,
}

-- stylua: ignore start
LeaderboardService.BOARDS = {
	{ key = "earned", title = "HALL OF FAME · MOST CASH EVER",     column = "CASH EVER" },
	{ key = "best",   title = "HALL OF FAME · BIGGEST SHIPMENT",   column = "SHIPMENT" },
	{ key = "size",   title = "HALL OF FAME · BIGGEST OPERATION",  column = "SIZE" },
}
-- stylua: ignore end

local data, street
local stores = {}
local top = {} -- [key] = rows
local names = {}
local lastWrite = {}

local function value(key, p)
	local v
	if key == "earned" then
		v = p.stats and p.stats.earned
	elseif key == "best" then
		v = p.stats and p.stats.biggestShipment
	else
		v = Flow.size(p)
	end
	if type(v) ~= "number" or v ~= v or v <= 0 then
		return nil
	end
	return math.floor(math.min(v, 2 ^ 52))
end

local function nameOf(userId)
	local here = Players:GetPlayerByUserId(userId)
	if here then
		names[userId] = here.DisplayName
		return here.DisplayName
	end
	if not names[userId] then
		local ok, n = pcall(Players.GetNameFromUserIdAsync, Players, userId)
		names[userId] = ok and n or ("Farmer " .. userId)
	end
	return names[userId]
end

function LeaderboardService:Write(player, profile)
	profile = profile or data:Get(player)
	if not profile then
		return {}
	end
	lastWrite[player] = os.clock()
	profile.boards = profile.boards or {}
	local written = {}
	for _, b in self.BOARDS do
		local v = value(b.key, profile)
		local store = stores[b.key]
		if v and store and (profile.boards[b.key] or 0) < v then
			local ok = pcall(store.SetAsync, store, tostring(player.UserId), v)
			if ok then
				profile.boards[b.key] = v
				table.insert(written, b.key)
			end
		end
	end
	return written
end

-- (this server's farms: what the boards show without DataStores, and merged in so a new record shows at once)
local function local_(key)
	local rows = {}
	for _, player in Players:GetPlayers() do
		local p = data:Get(player)
		local v = p and value(key, p)
		if v then
			table.insert(rows, { userId = player.UserId, name = player.DisplayName, value = v })
		end
	end
	return rows
end

function LeaderboardService:Refresh()
	for _, b in self.BOARDS do
		local rows = {}
		local store = stores[b.key]
		if store then
			local ok, pages = pcall(store.GetSortedAsync, store, false, self.TOP)
			if ok and pages then
				local okPage, list = pcall(pages.GetCurrentPage, pages)
				for _, e in okPage and list or {} do
					local userId = tonumber(e.key)
					if userId then
						table.insert(rows, { userId = userId, value = e.value })
					end
				end
			end
		end
		-- (merge this server's live values over the stored ones)
		local seen = {}
		for _, r in rows do
			seen[r.userId] = r
		end
		for _, r in local_(b.key) do
			if seen[r.userId] then
				seen[r.userId].value = math.max(seen[r.userId].value, r.value)
			else
				table.insert(rows, r)
			end
		end
		table.sort(rows, function(a, c)
			return a.value > c.value
		end)
		local out = {}
		for i = 1, math.min(self.TOP, #rows) do
			local r = rows[i]
			table.insert(out, { rank = i, userId = r.userId, name = r.name or nameOf(r.userId), value = r.value })
		end
		top[b.key] = out
	end
end

function LeaderboardService:Top(key)
	return top[key] or {}
end

function LeaderboardService:Paint()
	local b = self.BOARDS[self.page]
	local cells = {}
	for _, r in self:Top(b.key) do
		table.insert(cells, { tostring(r.rank), r.name, "", Format.num(r.value), "", "" })
	end
	if #cells == 0 then
		cells[1] = { "", "Nobody yet: be the first!", "", "", "", "" }
	end
	StreetBuilder.fill(
		street.hall,
		b.title,
		{ "#", "FARM", "", b.column, "", "" },
		cells,
		"Every server's best farms · grow yours to get on the board!",
		Color3.fromRGB(235, 175, 30)
	)
end

function LeaderboardService:Init(registry)
	data = registry.PlayerDataService
	street = registry.StreetService
	for _, b in self.BOARDS do
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore(string.format(Constants.LEADERBOARD_STORE, b.key))
		end)
		stores[b.key] = ok and store or nil
	end
end

function LeaderboardService:OnPlayerReady(player)
	lastWrite[player] = os.clock()
end

function LeaderboardService:OnPlayerLeaving(player, profile)
	self:Write(player, profile)
	lastWrite[player] = nil
end

function LeaderboardService:Start()
	local refresh, turn = math.huge, 0
	while true do
		refresh += 1
		turn += 1
		local ok, err = pcall(function()
			for _, player in Players:GetPlayers() do
				if os.clock() - (lastWrite[player] or 0) >= Constants.LEADERBOARD_WRITE_SECONDS then
					self:Write(player)
				end
			end
			if refresh >= Constants.LEADERBOARD_REFRESH_SECONDS then
				refresh = 0
				self:Refresh()
				self:Paint()
			end
			if turn >= self.PAGE then
				turn = 0
				self.page = self.page % #self.BOARDS + 1
				self:Paint()
			end
		end)
		if not ok then
			warn("[LeaderboardService] tick failed: " .. tostring(err))
		end
		task.wait(1)
	end
end

return LeaderboardService
