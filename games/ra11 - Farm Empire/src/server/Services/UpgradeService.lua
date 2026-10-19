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
local Crops = require(ReplicatedStorage.Shared.Data.Crops)
local Layout = require(ReplicatedStorage.Shared.World.Layout)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Upgrades = require(ReplicatedStorage.Shared.Data.Upgrades)

local UpgradeService = {
	Name = "UpgradeService",
	Dependencies = { "PlayerDataService", "EconomyService", "BusinessService" },
	Applied = Signal.new("UpgradeService.Applied"),
}

local data, economy, business, analytics, crops, automation
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
	if u.effect.crop then
		p.chosen = u.effect.crop -- (a new crop is planted next: the dearer one, until they pick another)
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

-- The value of an upgrade's next level: the $ a minute it adds, estimated from the business's numbers
-- (master plan §2: the highest-value affordable upgrade; never more production when selling is the limit).
-- Units a minute: the field grows `prod`, the hands or the machine clear at most `clear`, the counter moves `sell`,
-- the docks `dispatch`; what's really sold is the smallest link. An upgrade's gain is how much that grows.
UpgradeService.HAND_RATE = 36 -- tiles a minute a player clears by hand, about
UpgradeService.MACHINE_BONUS = 40 -- the first machine is a phase change (§5): worth more than its numbers
function UpgradeService:Gain(player, key)
	local p = data:Get(player)
	local u = Upgrades[key]
	local e = u.effect
	local n = business:Numbers(player)
	local f = crops:Summary(player)
	local tier = Upgrades.machine(p.owned)
	local clear = tier > 0 and automation:Rate(player) or self.HAND_RATE
	local prod = math.min(f.perMinute, clear)
	local avg = f.perMinute > 0 and f.valuePerMinute / f.perMinute or Crops[p.chosen or "strawberry"].value
	local out = math.min(n.demand, n.service) + n.dispatch * (n.bulkPrice or 1)
	local moved = math.min(out, prod)
	local function flow(prod2, demand2, service2, dispatch2, avg2)
		local out2 = math.min(demand2, service2) + dispatch2 * (n.bulkPrice or 1)
		return math.min(out2, prod2) * avg2 - moved * avg
	end
	local gain = 0
	if e.demand then
		gain = flow(prod, n.demand + e.demand, n.service, n.dispatch, avg)
	elseif e.service then
		gain = flow(prod, n.demand, n.service + e.service, n.dispatch, avg)
	elseif e.tiles or e.field then
		local add = e.tiles or Layout.FIELDS[e.field].tiles
		local perTile = f.tiles > 0 and f.perMinute / f.tiles or 60 / Crops[p.chosen or "strawberry"].grow
		gain = flow(math.min(f.perMinute + add * perTile, clear), n.demand, n.service, n.dispatch, avg)
	elseif e.crop then
		local c = Crops[e.crop]
		local mult = crops:GrowthMult(player)
		local prod2 = math.min(f.tiles * 60 / c.grow * mult, clear)
		gain = flow(prod2, n.demand, n.service, n.dispatch, c.value)
	elseif e.growth then
		gain = flow(
			math.min(f.perMinute * (1 + e.growth / crops:GrowthMult(player)), clear),
			n.demand,
			n.service,
			n.dispatch,
			avg
		)
	elseif e.machine then
		local rate = automation.RATES[e.machine]
		gain = flow(math.min(f.perMinute, rate), n.demand, n.service, n.dispatch, avg)
		if tier == 0 then
			gain += self.MACHINE_BONUS
		end
	elseif e.seeder then
		gain = 12 -- (no more replanting: a convenience worth a little of everything)
	elseif e.business then
		local b = Business[e.business]
		gain = flow(
			prod,
			b.demand + Upgrades.stat(p.owned, "demand", 0),
			b.service + Upgrades.stat(p.owned, "service", 0),
			(b.dispatch or 0) + Upgrades.stat(p.owned, "dispatch", 0),
			avg
		) + 10
	elseif e.dispatch then
		gain = flow(prod, n.demand, n.service, n.dispatch + e.dispatch, avg)
	elseif e.bulkPrice then
		gain = math.min(n.dispatch, math.max(0, prod - math.min(n.demand, n.service))) * avg * e.bulkPrice
	elseif e.storage then
		gain = 1 -- (room to breathe while away; never the fix for a flow)
	elseif e.prestige then
		gain = moved * avg * self.PRESTIGE_GAIN
	end
	return math.max(gain, 0.5)
end
UpgradeService.PRESTIGE_GAIN = 0.25

-- The recommendation: the best gain for the money among what's affordable; else what to save for (the best
-- gain for the money within reach: its cost under the cash plus a quarter hour of income), else the cheapest.
function UpgradeService:Recommend(player)
	local p = data:Get(player)
	if not p then
		return nil
	end
	local reach = p.cash + economy:Income(player) * 15
	local best, bestScore, save, saveScore, cheapest, cheapCost = nil, -1, nil, -1, nil, math.huge
	for _, key in Upgrades.LIST do
		local ok, why = Upgrades.can(p, key)
		if ok or why == "cash" then
			local cost = Upgrades.cost(key, p.owned[key] or 0)
			local score = self:Gain(player, key) / cost
			if ok and score > bestScore then
				best, bestScore = key, score
			end
			if not ok and cost <= reach and score > saveScore then
				save, saveScore = key, score
			end
			if cost < cheapCost then
				cheapest, cheapCost = key, cost
			end
		end
	end
	-- (a cheap trifle now, or the one that really moves things, soon: the latter, when it's clearly better)
	if best and save and saveScore > bestScore * 2 and self:Gain(player, save) > self:Gain(player, best) * 3 then
		return save, Upgrades[save].fixes, false
	end
	local key = best or save or cheapest
	if not key then
		return nil
	end
	return key, Upgrades[key].fixes, best ~= nil
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
	crops = registry.CropService -- (they depend on this service; the registry holds them before their Init)
	automation = registry.AutomationService
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
