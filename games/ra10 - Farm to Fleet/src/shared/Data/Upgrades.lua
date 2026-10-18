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

  Upgrades.LIST              every upgrade, in order
  Upgrades[key]              { key, name, stage, cost, kind, value, level }
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
			else
				v = math.max(v or 0, u.value)
			end
		end
	end
	return v
end

return Upgrades
