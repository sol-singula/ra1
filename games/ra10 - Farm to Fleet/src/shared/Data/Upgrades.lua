--[[
Everything a plot buys (master plan §4), stage by stage, in the order the buy-pads offer them: the next PADS not
owned yet whose level is reached. Each one is visible on the plot (World/FarmBuilder builds it) and does one thing:

  kind "soil"     soil tiles: the plot has `value` tiles once it's bought
  kind "water"    the well: WATER takes Crops.WATER_CUT off what's left to grow
  kind "sprinkler" every crop planted starts watered
  kind "carry"    you can carry `value` crops before selling
  kind "price"    the stand pays `value` times as much
  kind "golden"   + `value` to the golden-harvest chance
  kind "decor"    looks only (and XP: every buy pays XP)
  kind "stage"    the next stage opens (`value`)
  kind "animal"   a pen for that animal (`value`: Data/Animals' key); AnimalService looks after it
  kind "autoharvest" the tractor: every `value` seconds it harvests what's ripe and plants again
  kind "autosell" the conveyor: every `value` seconds it carries the basket to the stand and sells it

  Upgrades.LIST              every upgrade, in order
  Upgrades[key]              { key, name, stage, cost, kind, value, level, replaces? (the piece it takes down: a
                             site sign) }
  Upgrades.next(owned, level, n)   the next n on offer (the buy-pads)
  Upgrades.stat(owned, kind, default)   the value the plot has for a kind (the highest owned; "price" and
                             "golden" add up)
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
	{ key = "well",       name = "Water Well",      stage = 1, cost = 30,  kind = "water",     value = 1,  level = 1 },
	{ key = "soil6",      name = "More Soil",       stage = 1, cost = 45,  kind = "soil",      value = 6,  level = 2 },
	{ key = "wheelbarrow", name = "Wheelbarrow",    stage = 1, cost = 70,  kind = "carry",     value = 60, level = 2 },
	{ key = "fence",      name = "Picket Fence",    stage = 1, cost = 90,  kind = "decor",     value = 0,  level = 2 },
	{ key = "soil7",      name = "More Soil",       stage = 1, cost = 110, kind = "soil",      value = 7,  level = 3 },
	{ key = "soil8",      name = "More Soil",       stage = 1, cost = 140, kind = "soil",      value = 8,  level = 3 },
	{ key = "soil9",      name = "More Soil",       stage = 1, cost = 180, kind = "soil",      value = 9,  level = 3 },
	{ key = "sprinkler",  name = "Sprinklers",      stage = 1, cost = 250, kind = "sprinkler", value = 1,  level = 4 },
	{ key = "awning",     name = "Stand Awning",    stage = 1, cost = 300, kind = "price",     value = 0.25, level = 4 },
	{ key = "soil10",     name = "More Soil",       stage = 1, cost = 350, kind = "soil",      value = 10, level = 4 },
	{ key = "soil11",     name = "More Soil",       stage = 1, cost = 420, kind = "soil",      value = 11, level = 5 },
	{ key = "soil12",     name = "More Soil",       stage = 1, cost = 500, kind = "soil",      value = 12, level = 5 },
	{ key = "scarecrow",  name = "Scarecrow",       stage = 1, cost = 600, kind = "golden",    value = 0.03, level = 5 },
	{ key = "barnDeed",   name = "Build the Barn!", stage = 1, cost = 900, kind = "stage",     value = 2,  level = 5 },
	-- Stage 2: the Farm
	{ key = "barn",       name = "The Big Barn",    stage = 2, cost = 1500,  kind = "carry",     value = 150, level = 5, replaces = "barnDeed" },
	{ key = "field1",     name = "Corn Field",      stage = 2, cost = 2500,  kind = "soil",      value = 21,  level = 5 },
	{ key = "chickenCoop", name = "Chicken Coop",   stage = 2, cost = 3000,  kind = "animal",    value = "chicken", level = 5 },
	{ key = "tractor",    name = "Tractor",         stage = 2, cost = 4000,  kind = "autoharvest", value = 8, level = 6 },
	{ key = "field2",     name = "Big Field",       stage = 2, cost = 5000,  kind = "soil",      value = 30,  level = 6 },
	{ key = "conveyor",   name = "Conveyor Belt",   stage = 2, cost = 6000,  kind = "autosell",  value = 12,  level = 7 },
	{ key = "pigPen",     name = "Pig Pen",         stage = 2, cost = 7000,  kind = "animal",    value = "pig", level = 7 },
	{ key = "silo",       name = "Grain Silo",      stage = 2, cost = 8000,  kind = "carry",     value = 300, level = 8 },
	{ key = "field3",     name = "Huge Field",      stage = 2, cost = 9000,  kind = "soil",      value = 39,  level = 8 },
	{ key = "sheepPen",   name = "Sheep Pasture",   stage = 2, cost = 10000, kind = "animal",    value = "sheep", level = 9 },
	{ key = "windmill",   name = "Windmill",        stage = 2, cost = 4000,  kind = "decor",     value = 0,   level = 9 },
	{ key = "cowBarn",    name = "Cow Pasture",     stage = 2, cost = 12000, kind = "animal",    value = "cow", level = 10 },
	{ key = "shedDeed",   name = "Build the Packing Shed!", stage = 2, cost = 15000, kind = "stage", value = 3, level = 11 },
}
-- stylua: ignore end

Upgrades.LIST = {}
for i, u in LIST do
	u.index = i
	Upgrades[u.key] = u
	table.insert(Upgrades.LIST, u.key)
end

function Upgrades.next(owned, level, n)
	local out = {}
	for _, key in Upgrades.LIST do
		local u = Upgrades[key]
		if not owned[key] then
			if u.level > level then
				break -- (in order: nothing after a locked one shows yet)
			end
			table.insert(out, u)
			if #out >= (n or Upgrades.PADS) then
				break
			end
		end
	end
	return out
end

-- The next one not owned (shown even when its level isn't reached: the guide points at it)
function Upgrades.upcoming(owned)
	for _, key in Upgrades.LIST do
		if not owned[key] then
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
			if kind == "price" or kind == "golden" then
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
