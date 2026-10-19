--[[
Buying upgrades (master plan §14: the server checks the price, the balance, the prerequisites and the outcome).
An upgrade is bought from the UPGRADES panel, the recommended-upgrade card on the HUD, or the preview of the next
building in the world; all three send Net "Buy". Also the recommendation (§2): the highest-value affordable upgrade
for the current bottleneck, or when nothing is affordable the cheapest one that fixes it (so the task says what
to save for).

  UpgradeService:Buy(player, key)    ok, why
  UpgradeService:Recommend(player)   key, the bottleneck, affordable
  UpgradeService:Push(player)
  UpgradeService.Applied (player, key, level)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animals = require(ReplicatedStorage.Shared.Data.Animals)
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

-- The value of an upgrade's next level: the $ a minute it adds, estimated from the business's numbers.
-- Units a minute: the field grows `prod`, the hands or the machine clear at most `clear`, the counter sells `sell`
-- (customers come as fast as it serves), the docks `dispatch`; what's really sold is the smallest link, at `avg`
-- a unit. An upgrade's gain is how much `moved x avg` grows.
UpgradeService.HAND_RATE = 36 -- tiles a minute a player clears by hand, about
function UpgradeService:Gain(player, key)
	local p = data:Get(player)
	local u = Upgrades[key]
	local e = u.effect
	local n = business:Numbers(player)
	local f = crops:Summary(player)
	local tier = Upgrades.machine(p.owned)
	local clear = tier > 0 and automation:Rate(player) or self.HAND_RATE
	local prod = math.min(f.perMinute, clear)
	local mult = Upgrades.priceMult(p.owned) * (1 + Animals.boost(p, "price", os.time()))
	local avg = (f.perMinute > 0 and f.valuePerMinute / f.perMinute or Crops[p.chosen or "strawberry"].value) * mult
	local bulk = n.bulkPrice or 1
	local function out(service, dispatch)
		return service + dispatch * bulk
	end
	local moved = math.min(out(n.service, n.dispatch), prod)
	local now = moved * avg
	local function flow(prod2, service2, dispatch2, avg2)
		return math.min(out(service2, dispatch2), prod2) * (avg2 or avg) - now
	end
	local gain = 0
	if e.service then
		gain = flow(prod, n.service + e.service, n.dispatch)
	elseif e.tiles or e.field then
		local add = e.tiles or Layout.FIELDS[e.field].tiles
		local perTile = f.tiles > 0 and f.perMinute / f.tiles or 60 / Crops[p.chosen or "strawberry"].grow
		gain = flow(math.min(f.perMinute + add * perTile, clear), n.service, n.dispatch)
	elseif e.crop then
		local c = Crops[e.crop]
		local prod2 = math.min(f.tiles * 60 / c.grow * crops:GrowthMult(player), clear)
		gain = flow(prod2, n.service, n.dispatch, c.value * mult)
	elseif e.priceMult then
		gain = now * (e.priceMult - 1)
	elseif e.growth then
		gain = flow(math.min(f.perMinute * (1 + e.growth / crops:GrowthMult(player)), clear), n.service, n.dispatch)
	elseif e.machine then
		gain = flow(math.min(f.perMinute, automation.RATES[e.machine]), n.service, n.dispatch)
		if tier == 0 then
			gain += now * 0.5 + 20 -- (the first machine is a phase change: no more tapping)
		end
	elseif e.seeder then
		gain = now * 0.2 + 10 -- (no more replanting)
	elseif e.animal then
		local a = Animals[e.animal]
		local per = a.boost.per
		if a.boost.kind == "price" then
			gain = now * per
		elseif a.boost.kind == "service" then
			gain = flow(prod, n.service * (1 + per), n.dispatch)
		elseif a.boost.kind == "grow" then
			gain = flow(math.min(f.perMinute * (1 + per), clear), n.service, n.dispatch)
		elseif a.boost.kind == "machine" then
			gain = flow(math.min(f.perMinute, clear * (1 + per)), n.service, n.dispatch)
		end
		gain = math.max(gain, now * per * 0.5) -- (a boost to the farm is always worth something)
	elseif e.business then
		local b = Business[e.business]
		gain = flow(
			prod,
			b.service + Upgrades.stat(p.owned, "service", 0),
			(b.dispatch or 0) + Upgrades.stat(p.owned, "dispatch", 0)
		) + now * 0.3
	elseif e.dispatch then
		gain = flow(prod, n.service, n.dispatch + e.dispatch)
	elseif e.bulkPrice then
		gain = math.min(n.dispatch, math.max(0, prod - n.service)) * avg * e.bulkPrice
	elseif e.storage then
		gain = 1 -- (room to breathe while away; never the fix for a flow)
	elseif e.prestige then
		gain = now * economy.PRESTIGE_BONUS
	end
	return math.max(gain, 0.5)
end

-- What fixes each bottleneck (BusinessService:Bottleneck)
UpgradeService.FIXES = {
	harvest = { harvest = true },
	production = { production = true, land = true, value = true },
	service = { service = true },
	dispatch = { dispatch = true },
}

-- The recommendation: an upgrade that fixes the bottleneck (BusinessService), the best $ a minute for the money
-- among those you can buy now; if none, the one of them to save for (the soonest paid back). When nothing fixes
-- it, the best value overall. Returns key, the bottleneck, affordable.
function UpgradeService:Recommend(player)
	local p = data:Get(player)
	if not p then
		return nil
	end
	local b = business:Bottleneck(player)
	local fixes = self.FIXES[b] or {}
	local best, bestScore, save, saveScore, any, anyScore = nil, -1, nil, -1, nil, -1
	for _, key in Upgrades.LIST do
		local u = Upgrades[key]
		local ok, why = Upgrades.can(p, key)
		if (ok or why == "cash") and not u.effect.prestige then
			local cost = Upgrades.cost(key, p.owned[key] or 0)
			local score = self:Gain(player, key) / cost
			-- (what raises the price of every unit always helps, whatever the bottleneck: a new crop, premium
			-- produce, the pigs; and so does the next building, unless the crops are left in the field)
			local value = u.effect.crop ~= nil or u.effect.priceMult ~= nil or u.fixes == "value"
			local fits = fixes[u.fixes] or value or (u.effect.business ~= nil and b ~= "harvest")
			if fits and ok and score > bestScore then
				best, bestScore = key, score
			end
			if fits and not ok and score > saveScore then
				save, saveScore = key, score
			end
			if score > anyScore then
				any, anyScore = key, score
			end
		end
	end
	local key = best or save or any
	if not key then
		return nil
	end
	local can = Upgrades.can(p, key)
	return key, b, can == true
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
