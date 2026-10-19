--[[
Buying upgrades (master plan §14: the server checks the price, the balance, the prerequisites and the outcome).
An upgrade is bought from the UPGRADES panel, the recommended-upgrade card on the HUD, or the preview of the next
building in the world; all three send Net "Buy". Also the recommendation (§2): the highest-value affordable upgrade
for the current bottleneck, or when nothing is affordable the cheapest one that fixes it (so the task says what
to save for).

  UpgradeService:Buy(player, key)    ok, why
  UpgradeService:Recommend(player)   key, why (the bottleneck it fixes)
  UpgradeService:Push(player)
  UpgradeService.Applied (player, key, level)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Business = require(ReplicatedStorage.Shared.Data.Business)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Upgrades = require(ReplicatedStorage.Shared.Data.Upgrades)

local UpgradeService = {
	Name = "UpgradeService",
	Dependencies = { "PlayerDataService", "EconomyService", "BusinessService" },
	Applied = Signal.new("UpgradeService.Applied"),
}

local data, economy, business, analytics
local pushDue = {}

function UpgradeService:Buy(player, key)
	local p = data:Get(player)
	if not p then
		return false, "no profile"
	end
	local ok, why = Upgrades.can(p, key)
	if not ok then
		if why == "cash" then
			Net.fire(
				player,
				"Toast",
				`Not enough cash: {Upgrades[key].name} is {Format.cash(Upgrades.cost(key, p.owned[key] or 0))}`,
				"bad"
			)
		end
		return false, why
	end
	local u = Upgrades[key]
	local level = p.owned[key] or 0
	local cost = Upgrades.cost(key, level)
	if not economy:Spend(player, cost, "upgrade:" .. key) then
		return false, "cash"
	end
	p.owned[key] = level + 1
	if u.effect.business then
		business:SetStage(player, u.effect.business)
	end
	if u.effect.prestige then
		-- (PrestigeService takes it from here)
		self.Applied:Fire(player, key, level + 1)
		return true
	end
	local firsts = (function()
		local n = 0
		for _ in p.owned do
			n += 1
		end
		return n
	end)()
	if analytics then
		pcall(analytics.event, player, "buy", { key = key, level = level + 1, cost = cost })
		if firsts == 1 then
			pcall(analytics.event, player, "first_upgrade_purchased", { key = key })
		end
		if u.effect.machine == 1 then
			pcall(analytics.event, player, "automation_unlocked", {})
		elseif u.effect.business == "shop" then
			pcall(analytics.event, player, "first_store_unlocked", {})
		elseif u.effect.business == "warehouse" then
			pcall(analytics.event, player, "warehouse_unlocked", {})
		end
	end
	Net.fire(player, "Toast", `{u.name}: bought!`, "good")
	pushDue[player] = true
	self.Applied:Fire(player, key, level + 1)
	return true
end

-- score an upgrade for the bottleneck: fixes it = 3, else 1; levels of a maxed one don't count
function UpgradeService:Recommend(player)
	local p = data:Get(player)
	if not p then
		return nil
	end
	local bottleneck = business:Bottleneck(player)
	local bestAffordable, bestCost = nil, -1
	local cheapestFix, cheapCost = nil, math.huge
	local cheapestAny, anyCost = nil, math.huge
	for _, key in Upgrades.LIST do
		local ok, why = Upgrades.can(p, key)
		if ok or why == "cash" then
			local u = Upgrades[key]
			local cost = Upgrades.cost(key, p.owned[key] or 0)
			local fixes = u.fixes == bottleneck or (bottleneck == "land" and u.fixes == "production")
			if ok and fixes and cost > bestCost then
				bestAffordable, bestCost = key, cost
			end
			if fixes and cost < cheapCost then
				cheapestFix, cheapCost = key, cost
			end
			if cost < anyCost then
				cheapestAny, anyCost = key, cost
			end
		end
	end
	if bestAffordable then
		return bestAffordable, bottleneck, true
	end
	-- nothing affordable fixes it: the cheapest fix to save for, or the cheapest thing at all
	if cheapestFix then
		return cheapestFix, bottleneck, false
	end
	-- (nothing fixes this bottleneck at this stage: the next building does)
	local nxt = Business.next(p.stage)
	if nxt and Upgrades[nxt.key] then
		return nxt.key, bottleneck, Upgrades.can(p, nxt.key)
	end
	return cheapestAny, bottleneck, cheapestAny and Upgrades.can(p, cheapestAny) or false
end

function UpgradeService:Push(player)
	local p = data:Get(player)
	if not p then
		return
	end
	local list = {}
	for _, key in Upgrades.LIST do
		local ok, why = Upgrades.can(p, key)
		if ok or why == "cash" or why == "maxed" then
			table.insert(list, {
				key = key,
				level = p.owned[key] or 0,
				cost = why ~= "maxed" and Upgrades.cost(key, p.owned[key] or 0) or nil,
				can = ok,
				why = why,
			})
		end
	end
	local rec, bottleneck, affordable = self:Recommend(player)
	Net.fire(player, "Upgrades", {
		owned = p.owned,
		list = list,
		recommended = rec,
		bottleneck = bottleneck,
		affordable = affordable,
		stage = p.stage,
	})
end

function UpgradeService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	business = registry.BusinessService
	analytics = registry.AnalyticsService
	Net.on("Buy", function(player, key)
		if type(key) == "string" then
			self:Buy(player, key)
		end
	end)
	economy.Changed:Connect(function(player)
		pushDue[player] = true
	end)
	Players.PlayerRemoving:Connect(function(player)
		pushDue[player] = nil
	end)
end

function UpgradeService:OnPlayerReady(player)
	data:WhenClientReady(player, function()
		self:Push(player)
	end)
end

function UpgradeService:Start()
	while true do
		task.wait(1)
		for _, player in Players:GetPlayers() do
			if pushDue[player] then
				pushDue[player] = nil
				pcall(self.Push, self, player)
			end
		end
	end
end

return UpgradeService
