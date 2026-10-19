--[[
Everything a plot buys (master plan §4), stage by stage, in the order the buy-pads offer them: the next PADS not
owned yet whose level is reached. Each one is visible on the plot (World/FarmBuilder builds it) and does one thing:

  kind "soil"     soil tiles: the plot has `value` tiles once it's bought
  kind "water"    the well: WATER takes Crops.WATER_CUT off what's left to grow
  kind "sprinkler" every crop planted starts watered
  kind "carry"    you can carry `value` crops before selling (before the barn)
  kind "store"    the barn: it keeps `value` crops; every harvest goes straight in (no carrying)
  kind "tractors" how many tractors drive the field
  kind "price"    the stand pays `value` times as much
  kind "golden"   + `value` to the golden-harvest chance
  kind "decor"    looks only (and XP: every buy pays XP)
  kind "stage"    the next stage opens (`value`)
  kind "animal"   a pen for that animal (`value`: Data/Animals' key); AnimalService looks after it
  kind "autoharvest" the tractor, at level `value`: it drives round the field picking `value` patches at a stop
  kind "autosell" the shop helper: every `value` seconds it sells the barn's extra crops at the stand (never what
                  the open orders still need)
  kind "customers" `value` more customers a minute (they add up); "basket" crops a customer buys (Data/Customers)
  kind "van"      a delivery van: an order's trip takes `value` seconds (the buyer's pickup takes longer)
  kind "vans"     `value` vans: that many orders on the road at once
  kind "deliveryPrice" deliveries pay + `value` (they add up); "vanLoad" a van carries x `value`; "vans" how many
  kind "tripCut"  the loading dock: trips take `value` less time
  (stage 4: the warehouse, Data/Flow) kind "warehouse" the building; and by track, one buy-pad each by the
  warehouse (master plan §13.2): "grow" (kind "grow": crops grow + `value`, they add up), "pack" ("packLines": that
  many packing lines; "packSpeed": + `value`), "store" ("forklifts", "racks": rack rows (bays come with rows 3, 5,
  7), "forkSpeed": + `value`), "ship" ("trucks": box trucks, "truckCap": pallets a truck takes)
  (stage 5: the hub) kind "docks" the back dock doors: truck trips take `value` less; kind "hall": the packing lines
  + `value` (they add up); kind "semis": that many semis on the SHIP track. `needs`: another upgrade that must be owned first (shown locked till then)

  Upgrades.LIST              every upgrade, in order
  Upgrades[key]              { key, name, stage, cost, kind, value, level, replaces? (the piece it takes down: a
                             site sign; or a list: what the hub swallows), track? ("grow" | "pack" | "store" | "ship": the warehouse's station pads) }
  Upgrades.next(owned, level, n)   the next n on offer at the stand's pads (no track's)
  Upgrades.trackNext(owned, track) the next in a track (or nil when the track is done)
  Upgrades.ready(owned, level, u)   its level reached and what it `needs` owned
  Upgrades.TRACKS            the four, in flow order
  Upgrades.stat(owned, kind, default)   the value the plot has for a kind (the highest owned; "price",
                             "golden", "deliveryPrice", "customers", "grow" and "hall" add up)
]]
local Upgrades = {}

Upgrades.PADS = 3
Upgrades.START_SOIL = 3 -- tiles before any soil is bought
Upgrades.START_CARRY = 20
Upgrades.XP_PER_BUY = 5

-- stylua: ignore start
local LIST = {
	-- Stage 1: the Shack
	{ key = "soil4",      name = "More Soil",       stage = 1, cost = 10,  kind = "soil",      value = 4,  level = 1 },
	{ key = "soil5",      name = "More Soil",       stage = 1, cost = 20,  kind = "soil",      value = 5,  level = 1 },
	{ key = "well",       name = "Water Well",      stage = 1, cost = 30,  kind = "grow",      value = 0.25, level = 1, desc = "crops grow faster" },
	{ key = "soil6",      name = "More Soil",       stage = 1, cost = 45,  kind = "soil",      value = 6,  level = 2 },
	{ key = "wheelbarrow", name = "Wheelbarrow",    stage = 1, cost = 70,  kind = "carry",     value = 60, level = 2, desc = "carry 60 crops" },
	{ key = "fence",      name = "White Fence",     stage = 1, cost = 90,  kind = "decor",     value = 0,  level = 2, desc = "a fence round your farm" },
	{ key = "soil7",      name = "More Soil",       stage = 1, cost = 110, kind = "soil",      value = 7,  level = 3 },
	{ key = "soil8",      name = "More Soil",       stage = 1, cost = 140, kind = "soil",      value = 8,  level = 3 },
	{ key = "soil9",      name = "More Soil",       stage = 1, cost = 180, kind = "soil",      value = 9,  level = 3 },
	{ key = "sprinkler",  name = "Sprinklers",      stage = 1, cost = 250, kind = "sprinkler", value = 1,  level = 4, desc = "crops grow 2x faster" },
	{ key = "awning",     name = "Stand Roof",      stage = 1, cost = 300, kind = "price",     value = 0.25, level = 4, desc = "sell for 25% more" },
	{ key = "soil10",     name = "More Soil",       stage = 1, cost = 350, kind = "soil",      value = 10, level = 4 },
	{ key = "soil11",     name = "More Soil",       stage = 1, cost = 420, kind = "soil",      value = 11, level = 5 },
	{ key = "soil12",     name = "More Soil",       stage = 1, cost = 500, kind = "soil",      value = 12, level = 5 },
	{ key = "scarecrow",  name = "Scarecrow",       stage = 1, cost = 600, kind = "golden",    value = 0.03, level = 5, desc = "more golden crops" },
	{ key = "barnDeed",   name = "Build the Barn!", stage = 1, cost = 900, kind = "stage",     value = 2,  level = 5, desc = "a barn keeps your crops" },
	-- Stage 2: the Farm (the barn keeps the crops; the tractor picks them; the shop helper sells the extra)
	{ key = "barn",       name = "The Barn",        stage = 2, cost = 1500,  kind = "store",     value = 400, level = 5, replaces = "barnDeed", desc = "keeps 400 crops: no more carrying" },
	{ key = "sign",       name = "Big Sign",        stage = 2, cost = 2000,  kind = "customers", value = 4,   level = 5, desc = "4 more customers a minute" },
	{ key = "field1",     name = "Bigger Field",    stage = 2, cost = 2500,  kind = "soil",      value = 20,  level = 5 },
	{ key = "chickenCoop", name = "Chickens",       stage = 2, cost = 3000,  kind = "animal",    value = "chicken", level = 5, desc = "crops grow faster" },
	{ key = "tractor",    name = "Tractor",         stage = 2, cost = 4000,  kind = "autoharvest", value = 1, level = 6, desc = "picks and plants for you" },
	{ key = "field2",     name = "Bigger Field",    stage = 2, cost = 5000,  kind = "soil",      value = 28,  level = 6 },
	{ key = "shopkeeper", name = "Shop Helper",     stage = 2, cost = 6000,  kind = "basket",    value = 2,   level = 7, desc = "customers buy 2 crops at a time" },
	{ key = "bell",       name = "Shop Bell",       stage = 2, cost = 6500,  kind = "customers", value = 6,   level = 7, desc = "6 more customers a minute" },
	{ key = "pigPen",     name = "Pigs",            stage = 2, cost = 7000,  kind = "animal",    value = "pig", level = 7, desc = "crops sell for more" },
	{ key = "tractor2",   name = "Bigger Tractor",  stage = 2, cost = 8000,  kind = "autoharvest", value = 2, level = 8, desc = "picks 2 patches at once" },
	{ key = "parking",    name = "Parking Lot",     stage = 2, cost = 8500,  kind = "customers", value = 8,   level = 8, desc = "8 more customers a minute" },
	{ key = "bigBarn",    name = "Bigger Barn",     stage = 2, cost = 8000,  kind = "store",     value = 1500, level = 8, desc = "keeps 1,500 crops" },
	{ key = "field3",     name = "Bigger Field",    stage = 2, cost = 9000,  kind = "soil",      value = 36,  level = 8 },
	{ key = "sheepPen",   name = "Sheep",           stage = 2, cost = 10000, kind = "animal",    value = "sheep", level = 9, desc = "machines go faster" },
	{ key = "windmill",   name = "Windmill",        stage = 2, cost = 4000,  kind = "decor",     value = 0,   level = 9, desc = "a big windmill: looks great" },
	{ key = "tractor3",   name = "Big Tractor",     stage = 2, cost = 12000, kind = "autoharvest", value = 3, level = 10, desc = "picks 3 patches at once" },
	{ key = "cowBarn",    name = "Cows",            stage = 2, cost = 12000, kind = "animal",    value = "cow", level = 10, desc = "fruit grows faster" },
	{ key = "counter2",   name = "Second Counter",  stage = 2, cost = 13000, kind = "basket",    value = 3,   level = 10, desc = "customers buy 3 crops at a time" },
	{ key = "field4",     name = "Bigger Field",    stage = 2, cost = 14000, kind = "soil",      value = 48,  level = 10 },
	{ key = "shedDeed",   name = "Build the Delivery Shed!", stage = 2, cost = 15000, kind = "stage", value = 3, level = 11, desc = "vans sell your crops for 3x" },
	-- Stage 3: the Packing Shed
	{ key = "shed",       name = "Delivery Shed",   stage = 3, cost = 18000,  kind = "delivery",  value = 1,    level = 11, replaces = "shedDeed", desc = "vans sell your crops for 3x" },
	{ key = "van",        name = "Van",             stage = 3, cost = 25000,  kind = "van",       value = 20,   level = 12, desc = "takes 40 crops a trip: pays 3x" },
	{ key = "adverts",    name = "Adverts",         stage = 3, cost = 30000,  kind = "customers", value = 12,   level = 12, desc = "12 more customers a minute" },
	{ key = "tractor4",   name = "Huge Tractor",    stage = 3, cost = 32000,  kind = "autoharvest", value = 4, level = 12, desc = "picks 4 patches at once" },
	{ key = "boxLine",    name = "Box Machine",     stage = 3, cost = 36000,  kind = "vanLoad",   value = 2,    level = 13, desc = "vans carry 2x as much" },
	{ key = "sorter",     name = "Sorter",          stage = 3, cost = 45000,  kind = "deliveryPrice", value = 0.15, level = 14, desc = "deliveries pay 15% more" },
	{ key = "loadingDock", name = "Big Door",       stage = 3, cost = 52000,  kind = "tripCut",   value = 0.25, level = 14, desc = "vans load faster: trips 25% quicker" },
	{ key = "wrapper",    name = "Wrapper",         stage = 3, cost = 60000,  kind = "deliveryPrice", value = 0.15, level = 15, desc = "wraps boxes: deliveries pay 15% more" },
	{ key = "tractor5",   name = "Mega Tractor",    stage = 3, cost = 70000,  kind = "autoharvest", value = 5, level = 15, desc = "picks 5 patches at once" },
	{ key = "van2",       name = "Second Van",      stage = 3, cost = 75000,  kind = "vans",      value = 2,    level = 16, desc = "two vans delivering" },
	{ key = "secondTractor", name = "Second Tractor", stage = 3, cost = 90000, kind = "tractors", value = 2,   level = 16, desc = "two tractors picking" },
	{ key = "warehouseDeed", name = "Build the Warehouse!", stage = 3, cost = 100000, kind = "stage", value = 4, level = 17, desc = "holds tons of crops; trucks sell them" },
	-- Stage 4: the Warehouse (the building on the stand's pads, then a track per station)
	{ key = "warehouse",  name = "Warehouse",       stage = 4, cost = 120000, kind = "warehouse", value = 1, level = 17, replaces = "warehouseDeed", desc = "holds tons of crops; trucks sell the extra" },
	{ key = "packLine2",  name = "Packing Line 2",  stage = 4, cost = 150000, kind = "packLines", value = 2, level = 17, track = "pack", desc = "packs more boxes" },
	{ key = "forklift2",  name = "Forklift 2",      stage = 4, cost = 140000, kind = "forklifts", value = 2, level = 17, track = "store", desc = "another forklift" },
	{ key = "irrigation", name = "Grow Boost 1",    stage = 4, cost = 160000, kind = "grow",     value = 0.25, level = 17, track = "grow", desc = "crops grow 25% faster" },
	{ key = "rack2",      name = "More Shelves",    stage = 4, cost = 180000, kind = "racks",     value = 2, level = 18, track = "store", desc = "room for more pallets" },
	{ key = "boxTruck2",  name = "Truck 2",         stage = 4, cost = 200000, kind = "trucks",    value = 2, level = 18, track = "ship", desc = "another truck" },
	{ key = "bay2",       name = "Bigger Warehouse", stage = 4, cost = 300000, kind = "racks",    value = 3, level = 18, track = "store", desc = "the warehouse grows" },
	{ key = "forklift3",  name = "Forklift 3",      stage = 4, cost = 350000, kind = "forklifts", value = 3, level = 19, track = "store", desc = "another forklift" },
	{ key = "packLine3",  name = "Packing Line 3",  stage = 4, cost = 400000, kind = "packLines", value = 3, level = 19, track = "pack", desc = "packs more boxes" },
	{ key = "rack4",      name = "More Shelves",    stage = 4, cost = 450000, kind = "racks",     value = 4, level = 20, track = "store", desc = "room for more pallets" },
	{ key = "fertilizer", name = "Grow Boost 2",    stage = 4, cost = 450000, kind = "grow",     value = 0.25, level = 20, track = "grow", desc = "crops grow 25% faster" },
	{ key = "biggerTrucks", name = "Bigger Trucks", stage = 4, cost = 500000, kind = "truckCap",  value = 6, level = 20, track = "ship", desc = "trucks carry more" },
	{ key = "fastForklifts", name = "Fast Forklifts", stage = 4, cost = 600000, kind = "forkSpeed", value = 0.5, level = 21, track = "store", desc = "forklifts go 2x faster" },
	{ key = "bay3",       name = "Bigger Warehouse", stage = 4, cost = 750000, kind = "racks",    value = 5, level = 21, track = "store", desc = "the warehouse grows" },
	{ key = "boxTruck3",  name = "Truck 3",         stage = 4, cost = 800000, kind = "trucks",    value = 3, level = 22, track = "ship", desc = "another truck" },
	{ key = "autoPacker", name = "Robot Packer",    stage = 4, cost = 900000, kind = "packSpeed", value = 0.5, level = 22, track = "pack", desc = "packs 2x faster" },
	{ key = "rack6",      name = "More Shelves",    stage = 4, cost = 900000, kind = "racks",    value = 6, level = 22, track = "store", desc = "room for more pallets" },
	{ key = "greenhouse", name = "Grow Boost 3",    stage = 4, cost = 1000000, kind = "grow",    value = 0.3, level = 23, track = "grow", desc = "crops grow 30% faster" },
	{ key = "forklift4",  name = "Forklift 4",      stage = 4, cost = 1100000, kind = "forklifts", value = 4, level = 23, track = "store", desc = "another forklift" },
	{ key = "bay4",       name = "Bigger Warehouse", stage = 4, cost = 1300000, kind = "racks",   value = 7, level = 23, track = "store", desc = "the warehouse grows" },
	{ key = "boxTruck4",  name = "Truck 4",         stage = 4, cost = 1400000, kind = "trucks",   value = 4, level = 24, track = "ship", desc = "another truck" },
	{ key = "packLine4",  name = "Packing Line 4",  stage = 4, cost = 1500000, kind = "packLines", value = 4, level = 24, track = "pack", desc = "packs more boxes" },
	{ key = "rack8",      name = "More Shelves",    stage = 4, cost = 1600000, kind = "racks",    value = 8, level = 24, track = "store", desc = "room for more pallets" },
	{ key = "forklift5",  name = "Forklift 5",      stage = 4, cost = 1900000, kind = "forklifts", value = 5, level = 25, track = "store", desc = "another forklift" },
	{ key = "giantField", name = "Giant Field",     stage = 4, cost = 2000000, kind = "soil",     value = 64, level = 25, desc = "+16 patches" },
	{ key = "hubDeed",    name = "Build the Hub!",  stage = 4, cost = 2500000, kind = "stage", value = 5, level = 26, desc = "the biggest farm business there is" },
	-- Stage 5: the Distribution Hub: the warehouse takes over the front of the plot (master plan §13.1)
	{ key = "backDocks",  name = "Back Doors",      stage = 5, cost = 3000000,  kind = "docks",  value = 0.15, level = 26, needs = "bay4", desc = "4 big doors for giant trucks" },
	{ key = "frontHall",  name = "Front Hall",      stage = 5, cost = 4500000,  kind = "hall",   value = 0.25, level = 27, replaces = { "shed", "sorter", "wrapper", "boxLine", "orderBoard" }, desc = "a giant packing hall" },
	{ key = "controlTower", name = "Tower",         stage = 5, cost = 6000000,  kind = "deliveryPrice", value = 0.1, level = 28, desc = "runs it all: deliveries pay 10% more" },
	{ key = "solarRoof",  name = "Solar Roof",      stage = 5, cost = 8000000,  kind = "hall",   value = 0.25, level = 29, desc = "free power: packs 25% more" },
	{ key = "marketHall", name = "Market Hall",     stage = 5, cost = 10000000, kind = "price",  value = 0.5,  level = 30, desc = "your own market: sell for 50% more" },
	-- (the SHIP station's track carries on into stage 5: semis on the shared road, once there are back docks)
	{ key = "semi1",      name = "Giant Truck",     stage = 5, cost = 15000000, kind = "semis",  value = 1,    level = 30, track = "ship", needs = "backDocks", desc = "a giant truck ships 24 pallets" },
	{ key = "semi2",      name = "Giant Truck 2",   stage = 5, cost = 25000000, kind = "semis",  value = 2,    level = 32, track = "ship", needs = "backDocks", desc = "another giant truck" },
}
-- stylua: ignore end

Upgrades.TRACKS = { "grow", "pack", "store", "ship" }

Upgrades.LIST = {}
for i, u in LIST do
	u.index = i
	Upgrades[u.key] = u
	table.insert(Upgrades.LIST, u.key)
end

function Upgrades.next(owned, level, n)
	local out = {}
	local names = {}
	for _, key in Upgrades.LIST do
		local u = Upgrades[key]
		if not owned[key] and not u.track then
			if u.level > level or (u.needs and not owned[u.needs]) then
				break -- (in order: nothing after a locked one shows yet)
			end
			-- (one of a kind at a time: never two MORE SOILs side by side; soil is bought in order, cheapest first)
			if names[u.name] then
				continue
			end
			names[u.name] = true
			table.insert(out, u)
			if #out >= (n or Upgrades.PADS) then
				break
			end
		end
	end
	return out
end

-- What a pad says it gives (one short line under the name)
function Upgrades.blurb(u)
	if u.desc then
		return u.desc -- (said plainly, for the ones a name alone doesn't explain)
	elseif u.kind == "soil" then
		-- (how many it adds: soil is bought in order, so on top of the one before it)
		local before = Upgrades.START_SOIL
		for _, key in Upgrades.LIST do
			local o = Upgrades[key]
			if o.kind == "soil" and o.value < u.value then
				before = math.max(before, o.value)
			end
		end
		local more = u.value - before
		return `+{more} {more == 1 and "patch" or "patches"}`
	elseif u.kind == "carry" then
		return `carry {u.value}`
	elseif u.kind == "price" then
		return `+{math.floor(u.value * 100 + 0.5)}% sale price`
	elseif u.kind == "golden" then
		return "more golden crops"
	elseif u.kind == "grow" then
		return `crops grow +{math.floor(u.value * 100 + 0.5)}% faster`
	elseif u.kind == "sprinkler" then
		return "auto-water"
	elseif u.kind == "stage" then
		return `unlocks stage {u.value}!`
	elseif u.kind == "animal" then
		return `a {u.value}!`
	elseif u.kind == "autoharvest" then
		return "picks and plants for you"
	elseif u.kind == "autosell" then
		return "sells your extra crops for you"
	elseif u.kind == "home" then
		return "a bigger home"
	end
	return nil
end

-- The pieces an upgrade takes down when it's built (`replaces`: a key, or a list of keys)
function Upgrades.replaced(u)
	if type(u.replaces) == "table" then
		return u.replaces
	end
	return u.replaces and { u.replaces } or {}
end

-- Can it be bought now: its level reached and what it needs owned
function Upgrades.ready(owned, level, u)
	return u.level <= level and (not u.needs or owned[u.needs] ~= nil)
end

function Upgrades.trackNext(owned, track)
	for _, key in Upgrades.LIST do
		local u = Upgrades[key]
		if u.track == track and not owned[key] then
			return u
		end
	end
	return nil
end

-- The next one not owned at the stand (shown even when its level isn't reached: the guide points at it)
function Upgrades.upcoming(owned)
	for _, key in Upgrades.LIST do
		if not owned[key] and not Upgrades[key].track then
			return Upgrades[key]
		end
	end
	return nil
end

function Upgrades.stat(owned, kind, default)
	local v = default
	for _, key in Upgrades.LIST do
		local u = Upgrades[key]
		if owned[key] and u.kind == kind then
			if
				kind == "price"
				or kind == "golden"
				or kind == "deliveryPrice"
				or kind == "grow"
				or kind == "hall"
				or kind == "customers"
			then
				v = (v or 0) + u.value
			elseif type(u.value) ~= "number" then
				v = u.value
			else
				v = math.max(v or 0, u.value)
			end
		end
	end
	return v
end

return Upgrades
