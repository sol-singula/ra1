-- Order generation (menu + modifications), serve validation and settlement (GDD §27.8.3, canon C11.3-C11.4).
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Recipes = require(ReplicatedStorage.Shared.Data.Recipes)
local Modifications = require(ReplicatedStorage.Shared.Data.Modifications)

local OrderService = {
	Name = "OrderService",
	Dependencies = { "PlayerDataService", "EconomyService", "ProgressionService", "RestaurantService", "RepairService" },
}

local data, economy, progression, restaurantSvc, repair

local EXTRA_ITEM_CHANCE = 0.4 -- [C4.3] main + 40 % chance of a drink or side
local XP_PER_ITEM = 10 -- ≈ 75 % of XPRate(1) = 900/h at ~50 customers/h × 1.4 items [C5.1]
local XP_DELIGHTED_BONUS = 5

function OrderService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	progression = registry.ProgressionService
	restaurantSvc = registry.RestaurantService
	repair = registry.RepairService
end

local function pickMod(recipe, rng)
	if recipe.drink then
		return nil, {}
	end
	for _, mod in Modifications.list do
		if rng:NextNumber() < mod.chance then
			local omit = {}
			for _, part in recipe.parts do
				if table.find(mod.omit, part[1]) and not table.find(recipe.core, part[1]) then
					table.insert(omit, part[1])
				end
			end
			if #omit > 0 then
				table.sort(omit)
				return mod, omit
			end
		end
	end
	return nil, {}
end

-- Build an order for a customer: { items = { { recipeId, modId?, omit = {...}, served = false } } }.
function OrderService:Generate(player, personality, rng)
	local menu = restaurantSvc:MenuRecipes(player)
	local mains, extras = {}, {}
	for _, recipe in menu do
		table.insert(recipe.course == "main" and mains or extras, recipe)
	end
	if #mains == 0 then
		mains = menu
	end
	local count = personality.items[1]
	for _ = personality.items[1] + 1, personality.items[2] do
		if rng:NextNumber() < EXTRA_ITEM_CHANCE then
			count += 1
		end
	end
	local items = {}
	for i = 1, count do
		local pool = (i == 1 or #extras == 0) and mains or (rng:NextNumber() < 0.75 and extras or mains)
		local recipe = pool[rng:NextInteger(1, #pool)]
		local mod, omit = pickMod(recipe, rng)
		table.insert(items, { recipeId = recipe.id, modId = mod and mod.id, omit = omit, served = false })
	end
	return { items = items }
end

-- Compact JSON for the customer proxy, read by clients for the ticket rail and speech bubble.
function OrderService:Describe(order)
	local view = {}
	for _, item in order.items do
		local mod = item.modId and Modifications.byId[item.modId]
		table.insert(view, {
			name = Recipes.byId[item.recipeId].name,
			mod = mod and mod.text or nil,
			served = item.served,
		})
	end
	return HttpService:JSONEncode(view)
end

-- Which unserved order line (if any) this dish satisfies, and how accurately.
function OrderService:Match(order, dish)
	local bestIndex, bestA
	for i, item in order.items do
		if not item.served then
			local recipe = Recipes.byId[item.recipeId]
			local a
			if dish.drink then
				a = dish.recipeId == item.recipeId and 1 or nil
			else
				local ok, omitted = Formulas.matchRecipe(recipe, dish.contents)
				a = ok and Formulas.accuracy(omitted, item.omit) or nil
			end
			if a and (not bestA or a > bestA) then
				bestIndex, bestA = i, a
			end
		end
	end
	return bestIndex, bestA
end

local function priceSum(order)
	local price, cost = 0, 0
	for _, item in order.items do
		local recipe = Recipes.byId[item.recipeId]
		price += recipe.price
		cost += recipe.cost
	end
	return price, cost
end

-- Settle a fully served customer. Returns the summary sent to the owner.
function OrderService:Settle(player, c)
	local r = restaurantSvc:Get(player)
	local p = c.personality
	local A, Q, C = {}, {}, {}
	local lastServe = c.orderTakenAt
	for _, item in c.order.items do
		table.insert(A, item.accuracy or 0)
		table.insert(Q, item.quality or 0)
		table.insert(C, item.cook or 1)
		lastServe = math.max(lastServe, item.servedAt or lastServe)
	end
	local f = {
		A = Formulas.mean(A),
		Q = Formulas.mean(Q),
		C = Formulas.mean(C),
		W = Formulas.waitFactor(lastServe - c.orderTakenAt, c.patience),
		K = math.max(0, 1 - 0.1 * repair:DamagedCount(r)),
		M = restaurantSvc:Atmosphere(player) / 100,
	}
	local s = Formulas.satisfaction(f, p)
	local price, cost = priceSum(c.order)
	local luck = progression:Stat(player, "LUCK")
	local pay, tip, jackpot = Formulas.payment(price, s, p.tip, luck, c.rng:NextNumber(), r.tierIndex)
	local ingredientCost = Formulas.round(cost * Formulas.ingredientCostMult(progression:Stat(player, "EFFICIENCY")))
	local net = math.max(0, pay + tip - ingredientCost)
	economy:Grant(player, "MB", net, "customer")
	local xp = XP_PER_ITEM * #c.order.items + (s >= 90 and XP_DELIGHTED_BONUS or 0)
	progression:AddXp(player, xp)
	restaurantSvc:RecordCustomer(player, s, false)
	local profile = data:Get(player)
	if profile then
		profile.lifetime.served += 1
	end
	local summary = {
		name = p.name,
		satisfaction = math.floor(s + 0.5),
		mood = Formulas.mood(s, p.thresholds),
		pay = pay,
		tip = tip,
		cost = ingredientCost,
		net = net,
		jackpot = jackpot,
		xp = xp,
	}
	Net.fire(player, "Served", summary)
	return summary
end

-- [C11.4] A hostile customer calmed by combat pays 40 % of the order, no tip.
function OrderService:Apology(player, c)
	local price = priceSum(c.order)
	local pay = Formulas.round(price * 0.4)
	economy:Grant(player, "MB", pay, "apology")
	progression:AddXp(player, 3)
	restaurantSvc:RecordCustomer(player, 30, false)
	return pay
end

function OrderService:StormOut(player)
	restaurantSvc:RecordCustomer(player, 0, true)
end

return OrderService
