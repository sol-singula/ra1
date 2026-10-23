--[[
Garden value boards (§6): the server board (every Config.Leaderboard.serverRefreshSec) and the global weekly top 100
(OrderedDataStore Config.Leaderboard.storePrefix .. updateId: writes keep the player's peak via UpdateAsync, at most
once per globalWriteSec each; the top globalTop are read every globalReadSec). The board rotates with the update.

Garden value = every crop on the plot at sell x (mutation mult + harvestsLeft - 1), the basket at sell x count, and
every item at sell x mult. Coins and seeds don't count, and 2x Sell Cash doesn't change it.

Prize: on join, a player in the previous update's top globalTop gets Config.Leaderboard.prize for this week; anyone
else loses it.

Clients read ReplicatedStorage.Leaderboards: attributes Server and Global (JSON lists of { userId, name, value }),
UpdateId and ResetAt.

  LeaderboardService.gardenValue(profile)
  LeaderboardService.refreshServer() / writeGlobal(player, force?) / readGlobal(updateId) / grantPrize(player)
]]
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Clock = require(ReplicatedStorage.Shared.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local MutationMath = require(ReplicatedStorage.Shared.MutationMath)
local Schedule = require(ReplicatedStorage.Shared.Schedule)

local DataService = require(script.Parent.DataService)
local NetService = require(script.Parent.NetService)
local Stores = require(script.Parent.Parent.Save.Stores)
local WeeklyService = require(script.Parent.WeeklyService)

local LeaderboardService = {}

local folder
local lastWrite = setmetatable({}, { __mode = "k" }) -- [player] = time
local topCache = {} -- [updateId] = { [userId] = rank } once read
local names = {}

function LeaderboardService.gardenValue(profile)
	local total = 0
	for _, tile in profile.tiles do
		total += Config.Seeds[tile.seed].sell * (MutationMath.mult(tile.muts) + tile.harvestsLeft - 1)
	end
	for seed, count in profile.basket do
		total += Config.Seeds[seed].sell * count
	end
	for _, item in profile.items do
		total += MutationMath.value(item.seed, item.muts)
	end
	return total
end

local function nameOf(userId)
	if names[userId] == nil then
		local ok, name = pcall(function()
			return Players:GetNameFromUserIdAsync(userId)
		end)
		names[userId] = if ok then name else ("Farmer " .. userId)
	end
	return names[userId]
end

local function publish(attr, list)
	folder:SetAttribute(attr, HttpService:JSONEncode(list))
	local update = WeeklyService.current()
	folder:SetAttribute("UpdateId", update.updateId)
	folder:SetAttribute("ResetAt", update.nextAt)
end

function LeaderboardService.refreshServer()
	local rows = {}
	for _, player in Players:GetPlayers() do
		local profile = DataService.get(player)
		if profile then
			table.insert(
				rows,
				{ userId = player.UserId, name = player.DisplayName, value = LeaderboardService.gardenValue(profile) }
			)
		end
	end
	table.sort(rows, function(a, b)
		return a.value > b.value
	end)
	publish("Server", rows)
	return rows
end

function LeaderboardService.writeGlobal(player, force)
	local profile = DataService.get(player)
	local store = Stores.weekly(WeeklyService.current().updateId)
	local now = Clock.now()
	if not profile or not store then
		return false
	end
	if not force and lastWrite[player] and now - lastWrite[player] < Config.Leaderboard.globalWriteSec then
		return false
	end
	local value = math.floor(LeaderboardService.gardenValue(profile))
	if value <= 0 then
		return false -- nothing to rank yet
	end
	lastWrite[player] = now
	local ok, err = pcall(function()
		store:UpdateAsync(tostring(player.UserId), function(old)
			if old and old >= value then
				return nil -- keep the peak
			end
			return value
		end)
	end)
	if not ok then
		warn(`[Leaderboard] write for {player.UserId} failed: {err}`)
	end
	return ok
end

function LeaderboardService.readGlobal(updateId)
	local store = Stores.weekly(updateId)
	if not store then
		return {}
	end
	local ok, page = pcall(function()
		return store:GetSortedAsync(false, Config.Leaderboard.globalTop):GetCurrentPage()
	end)
	if not ok then
		warn(`[Leaderboard] read failed: {page}`)
		return nil
	end
	local rows, ranks = {}, {}
	for i, entry in page do
		local userId = tonumber(entry.key)
		ranks[userId] = i
		table.insert(rows, { userId = userId, name = nameOf(userId), value = entry.value })
	end
	topCache[updateId] = ranks
	return rows
end

local function previousUpdateId()
	return Schedule.currentUpdate(WeeklyService.current().startsAt - 1).updateId
end

function LeaderboardService.grantPrize(player)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local prev = previousUpdateId()
	local ranks = topCache[prev]
	if not ranks then
		LeaderboardService.readGlobal(prev)
		ranks = topCache[prev] or {}
	end
	local prize = Config.Leaderboard.prize
	local owned = profile.cosmetics.owned
	if ranks[player.UserId] then
		owned[prize] = true
	elseif owned[prize] then
		owned[prize] = nil
		if profile.cosmetics.equipped.tag == prize then
			profile.cosmetics.equipped.tag = nil
		end
	end
	NetService.change(player, { "cosmetics" }, profile.cosmetics)
end

function LeaderboardService:Init()
	folder = Instance.new("Folder")
	folder.Name = "Leaderboards"
	folder.Parent = ReplicatedStorage
end

function LeaderboardService:Start()
	WeeklyService.Rolled:Connect(function()
		for _, player in Players:GetPlayers() do
			LeaderboardService.grantPrize(player)
			LeaderboardService.writeGlobal(player, true)
		end
		publish("Global", LeaderboardService.readGlobal(WeeklyService.current().updateId) or {})
	end)
	local cfg = Config.Leaderboard
	local sinceServer, sinceRead = cfg.serverRefreshSec, cfg.globalReadSec
	while true do
		if sinceServer >= cfg.serverRefreshSec then
			sinceServer = 0
			LeaderboardService.refreshServer()
			for _, player in Players:GetPlayers() do
				LeaderboardService.writeGlobal(player)
			end
		end
		if sinceRead >= cfg.globalReadSec then
			sinceRead = 0
			publish("Global", LeaderboardService.readGlobal(WeeklyService.current().updateId) or {})
		end
		task.wait(1)
		sinceServer += 1
		sinceRead += 1
	end
end

function LeaderboardService:OnPlayerLoaded(player)
	LeaderboardService.grantPrize(player)
end

return LeaderboardService
