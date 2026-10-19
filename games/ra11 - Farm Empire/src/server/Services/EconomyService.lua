--[[
Cash (master plan §7): one currency. Every sale, every purchase goes through here, so the HUD's cash, the income
a minute and the lifetime earnings are always right. Income a minute is the real one: what came in over the last
sixty seconds.

  EconomyService:Add(player, amount, why, at)   pays; at = a Vector3 the coins fly from (the client's effect)
  EconomyService:Spend(player, amount, why)     false if they can't afford it
  EconomyService:Income(player)                 $ a minute over the last minute
  EconomyService:Multiplier(player)             prestige and the Golden Market boost
  EconomyService.Changed (player, "cash")
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local EconomyService = {
	Name = "EconomyService",
	Dependencies = { "PlayerDataService" },
	Changed = Signal.new("EconomyService.Changed"),
	PRESTIGE_BONUS = 0.25,
}

local data, boosts, analytics
local history = {} -- [player] = { { t, amount }, ... } the last minute's earnings
local pushDue = {} -- [player] = true: a Profile push is owed (batched to a few a second)

local function now()
	return workspace:GetServerTimeNow()
end

function EconomyService:Multiplier(player)
	local p = data:Get(player)
	local m = 1 + (p and p.prestige and p.prestige.level or 0) * self.PRESTIGE_BONUS
	if boosts and boosts:Active("goldenMarket") then
		m *= 1.5
	end
	return m
end

function EconomyService:Income(player)
	local list = history[player]
	if not list then
		return 0
	end
	local t, sum = now(), 0
	for i = #list, 1, -1 do
		if t - list[i][1] > 60 then
			table.remove(list, i)
		else
			sum += list[i][2]
		end
	end
	return sum
end

function EconomyService:Add(player, amount, why, at)
	local p = data:Get(player)
	if not p or amount <= 0 then
		return 0
	end
	amount = math.floor(amount + 0.5)
	p.cash += amount
	p.stats.earned = (p.stats.earned or 0) + amount
	local list = history[player] or {}
	history[player] = list
	table.insert(list, { now(), amount })
	pushDue[player] = true
	if at or why == "goal" or why == "away" then
		Net.fire(player, "Earned", { amount = amount, why = why, at = at and { at.X, at.Y, at.Z } or nil })
	end
	self.Changed:Fire(player, "cash")
	return amount
end

function EconomyService:Spend(player, amount, why)
	local p = data:Get(player)
	if not p or (p.cash or 0) < amount then
		return false
	end
	p.cash -= amount
	pushDue[player] = true
	if analytics then
		pcall(analytics.event, player, "spend", { amount = amount, why = why })
	end
	self.Changed:Fire(player, "cash")
	return true
end

function EconomyService:Push(player)
	local p = data:Get(player)
	if not p then
		return
	end
	data:Push(player, {
		cash = math.floor(p.cash),
		earned = math.floor(p.stats.earned or 0),
		income = math.floor(self:Income(player)),
		stage = p.stage,
		prestige = p.prestige and p.prestige.level or 0,
		multiplier = self:Multiplier(player),
	})
end

function EconomyService:Init(registry)
	data = registry.PlayerDataService
	boosts = registry.BoostService
	analytics = registry.AnalyticsService
	Players.PlayerRemoving:Connect(function(player)
		history[player] = nil
		pushDue[player] = nil
	end)
end

function EconomyService:OnPlayerReady(player)
	data:WhenClientReady(player, function()
		self:Push(player)
	end)
end

function EconomyService:Start()
	while true do
		task.wait(0.5)
		for _, player in Players:GetPlayers() do
			if pushDue[player] then
				pushDue[player] = nil
				pcall(self.Push, self, player)
			end
		end
	end
end

return EconomyService
