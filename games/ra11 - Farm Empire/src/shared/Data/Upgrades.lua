--[[
The upgrade tree (master plan §15): five branches. Every upgrade either adds output, adds selling capacity, eases
a bottleneck, unlocks a crop, a building or a machine, or changes what you see. Production and selling are
separate paths; the recommendation picks the one the current bottleneck needs (TaskService).

  Upgrades.LIST                   every key, in rough buy order
  Upgrades[key] = {
    name, desc, branch ("production" | "machinery" | "retail" | "logistics" | "prestige"),
    cost, max (levels; 1 if absent), mult (cost multiplier a level), stage (business stage needed: "stand"...),
    needs (another upgrade key), effect = { demand, service, storage, tiles, field, crop, seeder, machine,
    dispatch, docks, growth, bulkPrice, orchard }, fixes ("harvest" | "storage" | "service" | "demand" |
    "production" | "dispatch" | "land")
  }
  Upgrades.cost(key, level)       the cost of the next level
  Upgrades.stat(owned, effect)    the effect summed over everything owned
  Upgrades.can(profile, key)      ok, why
]]
local Business = require(script.Parent.Business)

local Upgrades = {}

local LIST = {}
local function add(key, u)
	u.key = key
	u.max = u.max or 1
	u.mult = u.mult or 1.6
	u.stage = u.stage or "stand"
	u.effect = u.effect or {}
	Upgrades[key] = u
	table.insert(LIST, key)
end

-- Stage A: the stand ----------------------------------------------------------------------------------------------
add("tiles", {
	name = "More Tiles",
	desc = "4 more crop tiles in the starter field.",
	branch = "production",
	cost = 25,
	max = 5,
	mult = 2.2,
	effect = { tiles = 4 },
	fixes = "production",
})
add("counter", {
	name = "Bigger Counter",
	desc = "The counter serves 8 more customers a minute.",
	branch = "retail",
	cost = 40,
	max = 6,
	mult = 2.4,
	effect = { service = 8 },
	fixes = "service",
})
add("seeder", {
	name = "Auto-Seeder",
	desc = "Every harvested tile is replanted by itself.",
	branch = "machinery",
	cost = 60,
	effect = { seeder = true },
	fixes = "harvest",
})
add("tomato", {
	name = "Tomato Seeds",
	desc = "Unlock tomatoes: 15 s, $6 each.",
	branch = "production",
	cost = 80,
	effect = { crop = "tomato" },
	fixes = "production",
})
add("sign", {
	name = "Road Sign",
	desc = "10 more customers a minute find the stand.",
	branch = "retail",
	cost = 90,
	max = 3,
	mult = 3,
	effect = { demand = 10 },
	fixes = "demand",
})
add("crates", {
	name = "Stock Crates",
	desc = "The stock area holds 40 more.",
	branch = "logistics",
	cost = 100,
	max = 4,
	mult = 2.5,
	effect = { storage = 40 },
	fixes = "storage",
})
add("wheat", {
	name = "Wheat Seeds",
	desc = "Unlock wheat: 20 s, $10 each.",
	branch = "production",
	cost = 250,
	needs = "tomato",
	effect = { crop = "wheat" },
	fixes = "production",
})
add("field2", {
	name = "East Field",
	desc = "Open a new section of land: 30 tiles.",
	branch = "production",
	cost = 450,
	effect = { field = "field2" },
	fixes = "land",
})
add("harvester", {
	name = "Auto-Harvester",
	desc = "A slow machine that clears every ripe tile on the farm, 20 a minute.",
	branch = "machinery",
	cost = 700,
	needs = "seeder",
	effect = { machine = 1 },
	fixes = "harvest",
})
add("adverts", {
	name = "Adverts",
	desc = "20 more customers a minute.",
	branch = "retail",
	cost = 600,
	max = 4,
	mult = 3,
	needs = "sign",
	effect = { demand = 20 },
	fixes = "demand",
})
add("corn", {
	name = "Corn Seeds",
	desc = "Unlock corn: 30 s, $18 each.",
	branch = "production",
	cost = 800,
	needs = "wheat",
	effect = { crop = "corn" },
	fixes = "production",
})
add("tractor", {
	name = "Farm Tractor",
	desc = "Clears 50 tiles a minute and carries more.",
	branch = "machinery",
	cost = 1800,
	needs = "harvester",
	effect = { machine = 2 },
	fixes = "harvest",
})
add("shop", {
	name = "Build the Fruit Shop",
	desc = "Shelves, a stockroom, two workers, a proper line. Demand, service and storage all jump.",
	branch = "retail",
	cost = Business.shop.cost,
	effect = { business = "shop" },
	fixes = "service",
})

-- Stage B: the shop --------------------------------------------------------------------------------------------------
add("shelves", {
	name = "More Shelves",
	desc = "The stockroom holds 150 more.",
	branch = "logistics",
	cost = 1200,
	max = 5,
	mult = 2.2,
	stage = "shop",
	effect = { storage = 150 },
	fixes = "storage",
})
add("checkout", {
	name = "Second Checkout",
	desc = "A worker on a second till: 20 more sales a minute.",
	branch = "retail",
	cost = 2000,
	max = 4,
	mult = 2.2,
	stage = "shop",
	effect = { service = 20 },
	fixes = "service",
})
add("field3", {
	name = "West Field",
	desc = "Open a new section of land: 30 tiles.",
	branch = "production",
	cost = 3500,
	stage = "shop",
	needs = "field2",
	effect = { field = "field3" },
	fixes = "land",
})
add("pumpkin", {
	name = "Pumpkin Seeds",
	desc = "Unlock pumpkins: 45 s, $32 each.",
	branch = "production",
	cost = 3000,
	stage = "shop",
	needs = "corn",
	effect = { crop = "pumpkin" },
	fixes = "production",
})
add("blueberry", {
	name = "Blueberry Bushes",
	desc = "Unlock blueberries: 40 s, $36 each.",
	branch = "production",
	cost = 5000,
	stage = "shop",
	needs = "pumpkin",
	effect = { crop = "blueberry" },
	fixes = "production",
})
add("billboard", {
	name = "Billboard",
	desc = "40 more customers a minute.",
	branch = "retail",
	cost = 4500,
	max = 3,
	mult = 3,
	stage = "shop",
	needs = "adverts",
	effect = { demand = 40 },
	fixes = "demand",
})
add("combine", {
	name = "Combine Harvester",
	desc = "Clears 120 tiles a minute.",
	branch = "machinery",
	cost = 9000,
	stage = "shop",
	needs = "tractor",
	effect = { machine = 3 },
	fixes = "harvest",
})
add("sprinklers", {
	name = "Sprinklers",
	desc = "Every crop grows 20% faster.",
	branch = "production",
	cost = 6000,
	max = 3,
	mult = 3,
	stage = "shop",
	effect = { growth = 0.2 },
	fixes = "production",
})
add("warehouse", {
	name = "Build the Warehouse",
	desc = "Pallets, a forklift, a loading dock and trucks that buy in bulk at 1.4x.",
	branch = "logistics",
	cost = Business.warehouse.cost,
	stage = "shop",
	effect = { business = "warehouse" },
	fixes = "storage",
})

-- Stage C: the warehouse ---------------------------------------------------------------------------------------------
add("dock", {
	name = "Loading Dock",
	desc = "Another dock and truck: 60 more units a minute dispatched.",
	branch = "logistics",
	cost = 12000,
	max = 3,
	mult = 2,
	stage = "warehouse",
	effect = { dispatch = 60, docks = 1 },
	fixes = "dispatch",
})
add("forklift", {
	name = "Forklift",
	desc = "Pallets move faster: 40 more units a minute dispatched.",
	branch = "logistics",
	cost = 8000,
	max = 4,
	mult = 2,
	stage = "warehouse",
	effect = { dispatch = 40 },
	fixes = "dispatch",
})
add("racks", {
	name = "Pallet Racks",
	desc = "The warehouse holds 1,000 more.",
	branch = "logistics",
	cost = 10000,
	max = 4,
	mult = 2,
	stage = "warehouse",
	effect = { storage = 1000 },
	fixes = "storage",
})
add("melon", {
	name = "Melon Seeds",
	desc = "Unlock melons: 60 s, $55 each.",
	branch = "production",
	cost = 20000,
	stage = "warehouse",
	needs = "blueberry",
	effect = { crop = "melon" },
	fixes = "production",
})
add("field4", {
	name = "North Field",
	desc = "Open the last section of land: 30 tiles.",
	branch = "production",
	cost = 25000,
	stage = "warehouse",
	needs = "field3",
	effect = { field = "field4" },
	fixes = "land",
})
add("fleet", {
	name = "Automated Fleet",
	desc = "Two machines on the field at once: 300 tiles a minute.",
	branch = "machinery",
	cost = 40000,
	stage = "warehouse",
	needs = "combine",
	effect = { machine = 4 },
	fixes = "harvest",
})
add("sorter", {
	name = "Sorting Line",
	desc = "Sorted pallets sell for 20% more in bulk.",
	branch = "logistics",
	cost = 30000,
	max = 2,
	mult = 2.5,
	stage = "warehouse",
	effect = { bulkPrice = 0.2 },
	fixes = "dispatch",
})
add("center", {
	name = "Build the Distribution Centre",
	desc = "Six docks, bulk contracts from the market and a fleet of trucks.",
	branch = "logistics",
	cost = Business.center.cost,
	stage = "warehouse",
	effect = { business = "center" },
	fixes = "dispatch",
})

-- Stage D: the distribution centre ----------------------------------------------------------------------------------
add("bigDock", {
	name = "Double Dock",
	desc = "Two more docks: 200 more units a minute dispatched.",
	branch = "logistics",
	cost = 90000,
	max = 3,
	mult = 2,
	stage = "center",
	effect = { dispatch = 200, docks = 2 },
	fixes = "dispatch",
})
add("conveyor", {
	name = "Conveyor Line",
	desc = "Goods ride straight to the docks: 150 more a minute dispatched.",
	branch = "logistics",
	cost = 120000,
	max = 2,
	mult = 2,
	stage = "center",
	effect = { dispatch = 150 },
	fixes = "dispatch",
})
add("orchard", {
	name = "Golden Orchard",
	desc = "Unlock golden apples: 120 s, $150 each.",
	branch = "production",
	cost = 200000,
	stage = "center",
	needs = "melon",
	effect = { crop = "goldenApple" },
	fixes = "production",
})
add("silo", {
	name = "Grain Silo",
	desc = "The centre holds 5,000 more.",
	branch = "logistics",
	cost = 80000,
	max = 3,
	mult = 2,
	stage = "center",
	effect = { storage = 5000 },
	fixes = "storage",
})
add("region", {
	name = "Open a New Region",
	desc = "Prestige: a fresh territory with a permanent +25% to every sale, and your trophies kept.",
	branch = "prestige",
	cost = 1000000,
	stage = "center",
	effect = { prestige = true },
	fixes = "land",
})

Upgrades.LIST = LIST

function Upgrades.cost(key, level)
	local u = Upgrades[key]
	level = level or 0
	return math.floor(u.cost * u.mult ^ level + 0.5)
end

-- Sum one numeric effect over everything owned (levels count).
function Upgrades.stat(owned, effect, default)
	local total = 0
	for key, level in owned or {} do
		local u = Upgrades[key]
		local v = u and u.effect[effect]
		if type(v) == "number" then
			total += v * level
		end
	end
	return total == 0 and (default or 0) or total
end

-- The highest machine tier owned (0 none)
function Upgrades.machine(owned)
	local best = 0
	for key, level in owned or {} do
		local u = Upgrades[key]
		if u and u.effect.machine and level > 0 then
			best = math.max(best, u.effect.machine)
		end
	end
	return best
end

-- Can this profile buy the next level: ok, reason ("maxed" | "stage" | "needs" | "cash")
function Upgrades.can(profile, key)
	local u = Upgrades[key]
	if not u then
		return false, "unknown"
	end
	local owned = profile.owned or {}
	local level = owned[key] or 0
	if level >= u.max then
		return false, "maxed"
	end
	if Business[u.stage].index > Business[profile.stage or "stand"].index then
		return false, "stage"
	end
	if u.needs and (owned[u.needs] or 0) == 0 then
		return false, "needs"
	end
	if (profile.cash or 0) < Upgrades.cost(key, level) then
		return false, "cash"
	end
	return true
end

-- Visible now: the stage is reached and what it needs is owned (not maxed)
function Upgrades.available(profile, key)
	local ok, why = Upgrades.can(profile, key)
	return ok or why == "cash"
end

return Upgrades
