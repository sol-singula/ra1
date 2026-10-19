--[[
The town's leaderboards: all-time cash earned, regions opened, units sold, from OrderedDataStores shared across
every server. Written every minute for the players here, read every two, pushed to everyone (Net "Leaderboards").

  LeaderboardService:Refresh()   read the boards now (tests)
  LeaderboardService.boards      { earned = { {name, userId, value}, ... }, ... }
]]
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)

local LeaderboardService = {
	Name = "LeaderboardService",
	Dependencies = { "PlayerDataService" },
	BOARDS = { "earned", "regions", "sold" },
	TOP = 10,
	boards = {},
}

local data
local stores = {}
local names = {} -- [userId] = name (the players we've seen)

local function statOf(p, board)
	if board == "earned" then
		return math.floor(p.stats.earned or 0)
	elseif board == "regions" then
		return p.prestige and p.prestige.level or 0
	end
	return math.floor(p.stats.sold or 0)
end

function LeaderboardService:Write()
	for _, player in Players:GetPlayers() do
		local p = data:Get(player)
		if p and not p._noSave then
			names[player.UserId] = player.DisplayName or player.Name
			for _, board in self.BOARDS do
				local store = stores[board]
				if store then
					pcall(store.SetAsync, store, tostring(player.UserId), statOf(p, board))
				end
			end
		end
	end
end

function LeaderboardService:Refresh()
	for _, board in self.BOARDS do
		local store = stores[board]
		if store then
			local ok, pages = pcall(store.GetSortedAsync, store, false, self.TOP)
			if ok and pages then
				local ok2, page = pcall(pages.GetCurrentPage, pages)
				if ok2 and page then
					local list = {}
					for _, row in page do
						local userId = tonumber(row.key)
						table.insert(list, { userId = userId, value = row.value, name = names[userId] })
					end
					self.boards[board] = list
				end
			end
		end
	end
	-- names for the ones not here
	local missing = {}
	for _, list in self.boards do
		for _, row in list do
			if not row.name and row.userId then
				table.insert(missing, row.userId)
			end
		end
	end
	if #missing > 0 then
		pcall(function()
			local infos = game:GetService("UserService"):GetUserInfosByUserIdsAsync(missing)
			for _, info in infos do
				names[info.Id] = info.DisplayName or info.Username
			end
			for _, list in self.boards do
				for _, row in list do
					row.name = row.name or names[row.userId] or "?"
				end
			end
		end)
	end
	Net.fireAll("Leaderboards", self.boards)
end

function LeaderboardService:Init(registry)
	data = registry.PlayerDataService
	for _, board in self.BOARDS do
		local ok, s = pcall(function()
			return DataStoreService:GetOrderedDataStore(string.format(Constants.LEADERBOARD_STORE, board))
		end)
		stores[board] = ok and s or nil
	end
end

function LeaderboardService:OnPlayerReady(player)
	data:WhenClientReady(player, function()
		Net.fire(player, "Leaderboards", self.boards)
	end)
end

function LeaderboardService:Start()
	task.wait(5)
	self:Write()
	self:Refresh()
	local w, r = 0, 0
	while true do
		task.wait(5)
		w += 5
		r += 5
		if w >= Constants.LEADERBOARD_WRITE_SECONDS then
			w = 0
			pcall(self.Write, self)
		end
		if r >= Constants.LEADERBOARD_REFRESH_SECONDS then
			r = 0
			pcall(self.Refresh, self)
		end
	end
end

return LeaderboardService
