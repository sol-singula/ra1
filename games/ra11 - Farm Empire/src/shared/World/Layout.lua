--[[
Where everything is (master plan §4). The city sits in the middle of the map; the avenue runs east-west through
it; twelve farms line the avenue in two rows of six, three each side of the city, every one with its FRONT on the
avenue. Each farm is laid out in its own local frame (x across, z from the front edge on the avenue at
z = -DEPTH/2 to the back at +DEPTH/2) and turned so its front faces the road, so one builder makes every farm.

A farm, front to back (local studs, 400 across by 360 deep; every zone below has its own rectangle, see ZONES,
and tests/LayoutSmoke checks none of them overlap):
  the front        the business right on the avenue: one building that grows where it stands, a fruit stand, a
                   shop, then a warehouse (and a distribution centre) with big doors at the back onto the farm; the
                   pallet yard on its left (stock spills out onto pallets there when the building is full), the
                   truck yard on its right (the docks); the build yard and the gate further left, the animal pens
                   further right
  the fields       right behind the business (seen through its back doors): the home field, the East and West
                   fields either side, the long North field behind them; paths between
  machines         the shed at the right, beside the West field
  the back         the farmhouse, the orchard, the pond, the windmill, the silos; trees all round

  Layout.territory(i)        { index, cx, cz, rotation, row, col }
  Layout.toWorld(i, x, z, y) local -> world Vector3
  Layout.toLocal(i, pos)
  Layout.cframe(i, x, z, y, yaw)
  Layout.FIELDS[key], Layout.tilePos(key, n), Layout.tileId(key, n), Layout.parseTile(id), Layout.fieldRect(key)
  Layout.SPOTS               named local points
  Layout.PADS                the eight pads' centres, nearest the spawn first
  Layout.ZONES               { name = { cx, cz, w, d } } the rectangles that must not overlap
  Layout.MAP                 the whole map's extent
  Layout.CITY                the city's extent
]]
local Layout = {}

Layout.WIDTH = 400 -- x
Layout.DEPTH = 360 -- z
Layout.AVENUE = 40 -- the road between the rows, sidewalks included
Layout.ROAD = 28 -- the asphalt in the middle of it
Layout.GAP = 12 -- the tree strip between two farms
Layout.PITCH = 5 -- tile pitch (4 x 4 tiles, a 1-stud path)
Layout.TILE = 4
Layout.GROUND_Y = 0
Layout.FENCE = { x = 198.5, z = 178.5 } -- the fence's line, inside the farm's edge
Layout.PAD = 6.4 -- the part of a pad you step on

-- The city: the middle of the map, as deep as the rows
Layout.CITY = { half = 96, depth = Layout.AVENUE / 2 + Layout.DEPTH, court = 62 }
Layout.TOWN = Layout.CITY.court * 2 -- (the courtyard's side)

-- The farms: three each side of the city in each row. The south row (cz < 0) is turned half round so its front
-- (local -z) faces north, onto the avenue; the north row faces south.
local COLS = {}
for k = 1, 3 do
	local x = Layout.CITY.half + Layout.GAP + (Layout.WIDTH + Layout.GAP) * (k - 1) + Layout.WIDTH / 2
	COLS[4 - k] = -x
	COLS[3 + k] = x
end
local ROW_Z = Layout.AVENUE / 2 + Layout.DEPTH / 2
Layout.COLS = COLS

local territories = {}
for i = 1, 12 do
	local row = i <= 6 and 1 or 2 -- 1 south, 2 north
	local col = ((i - 1) % 6) + 1
	territories[i] = {
		index = i,
		cx = COLS[col],
		cz = row == 1 and -ROW_Z or ROW_Z,
		rotation = row == 1 and math.pi or 0,
		row = row,
		col = col,
	}
end

Layout.MAP = {
	halfWidth = Layout.CITY.half + (Layout.GAP + Layout.WIDTH) * 3 + 80,
	halfDepth = Layout.AVENUE / 2 + Layout.DEPTH + 80,
}

function Layout.territory(i)
	return territories[i]
end

function Layout.toWorld(i, x, z, y)
	local t = territories[i]
	local c, s = math.cos(t.rotation), math.sin(t.rotation)
	return Vector3.new(t.cx + x * c - z * s, (y or 0) + Layout.GROUND_Y, t.cz + x * s + z * c)
end

function Layout.toLocal(i, pos)
	local t = territories[i]
	local dx, dz = pos.X - t.cx, pos.Z - t.cz
	local c, s = math.cos(-t.rotation), math.sin(-t.rotation)
	return dx * c - dz * s, dx * s + dz * c
end

-- A CFrame at a local point, its front (-z) facing the farm's front (the avenue), plus a turn on top
function Layout.cframe(i, x, z, y, yaw)
	local t = territories[i]
	local p = Layout.toWorld(i, x, z, y)
	return CFrame.new(p) * CFrame.Angles(0, t.rotation + (yaw or 0), 0)
end

-- Which territory a world position is in (nil: the avenue, the city, a gap)
function Layout.territoryAt(pos)
	for i = 1, 12 do
		local x, z = Layout.toLocal(i, pos)
		if math.abs(x) <= Layout.WIDTH / 2 and math.abs(z) <= Layout.DEPTH / 2 then
			return i
		end
	end
	return nil
end

-- The fields: the tile grids (local x, z of the first tile's centre; cols across, rows deep)
Layout.FIELDS = {
	field1 = { x = -27.5, z = -57.5, cols = 12, rows = 8, tiles = 96 },
	field2 = { x = -112.5, z = -57.5, cols = 14, rows = 10, tiles = 140 },
	field3 = { x = 47.5, z = -57.5, cols = 14, rows = 10, tiles = 140 },
	field4 = { x = -72.5, z = 7.5, cols = 30, rows = 6, tiles = 180 },
}
Layout.FIELD_LIST = { "field1", "field2", "field3", "field4" }
Layout.FIELD_NAMES = { field1 = "HOME FIELD", field2 = "EAST FIELD", field3 = "WEST FIELD", field4 = "NORTH FIELD" }

-- the rectangle a field's tiles cover: centre x, z, width, depth
function Layout.fieldRect(key)
	local f = Layout.FIELDS[key]
	local w = f.cols * Layout.PITCH
	local d = f.rows * Layout.PITCH
	return f.x + (f.cols - 1) * Layout.PITCH / 2, f.z + (f.rows - 1) * Layout.PITCH / 2, w, d
end

function Layout.tilePos(key, n)
	local f = Layout.FIELDS[key]
	local c = (n - 1) % f.cols
	local r = (n - 1) // f.cols
	return f.x + c * Layout.PITCH, f.z + r * Layout.PITCH
end

function Layout.tileId(key, n)
	return key .. ":" .. n
end

function Layout.parseTile(id)
	local key, n = string.match(id, "^(field%d):(%d+)$")
	return key, tonumber(n)
end

-- The business building: one building at the front that grows where it stands, its front wall on FRONT_Z (facing
-- the avenue), reaching back toward the fields. Each stage's footprint:
Layout.FRONT_Z = -152
Layout.BUILDING = {
	stand = { w = 22, d = 18, h = 8 },
	shop = { w = 40, d = 26, h = 10 },
	warehouse = { w = 100, d = 70, h = 18 },
	center = { w = 120, d = 80, h = 22 },
}
-- the building's middle (local x, z) at a stage
function Layout.building(stage)
	local b = Layout.BUILDING[stage] or Layout.BUILDING.stand
	return 0, Layout.FRONT_Z + b.d / 2, b
end

-- Named points
Layout.SPOTS = {
	stand = { x = 0, z = -143 }, -- the stand's middle (its counter faces the avenue; customers queue in front)
	gate = { x = -130, z = -178.5 }, -- the farm gate, between its two pillars
	spawn = { x = -130, z = -110 }, -- inside the gate, behind the build yard
	yard = { x = -130, z = -140 }, -- the build yard's middle
	lane = { x = 81, z = -125 }, -- the truck yard (the trucks come in from the avenue to the docks)
	dock = { x = 64, z = -110 }, -- the docks' middle (on the building's right wall, warehouse and up)
	stock = { x = -79, z = -112 }, -- the pallet yard (outside the building's left wall)
	warehouse = { x = 0, z = -117 }, -- the warehouse's middle
	center = { x = 0, z = -112 }, -- the distribution centre's middle
	shed = { x = 155, z = -35 }, -- the machine shed
	machine2 = { x = 155, z = -6 }, -- where the fleet's second machine parks
	hay = { x = 155, z = -60 },
	silo = { x = 70, z = 80 },
	house = { x = -150, z = 110 },
	orchard = { x = -150, z = 150 },
	pond = { x = -70, z = 120 },
	windmill = { x = -100, z = 160 },
	scarecrow = { x = -130, z = -30 },
	pens = { x = 152, z = -118 }, -- the animal pens' middle
	region = { x = 0, z = 110 }, -- where the new-region preview stands
}

-- The pads: two rows of four in the build yard, the ones nearest the spawn first (a few steps apart)
Layout.PADS = {}
for k = 1, 8 do
	local row = (k - 1) // 4 -- 0 the back row (nearer the spawn), 1 the front row
	local col = (k - 1) % 4
	Layout.PADS[k] = { x = -109 - col * 14, z = -128 - row * 18 }
end

-- The animals: four pens in a row right of the truck yard, each with its upgrade pad and a feed plate in front
Layout.ANIMALS = { "chicken", "pig", "cow", "sheep" }
Layout.PEN = { w = 22, d = 24, z = -118 } -- each pen's size and middle (z)
Layout.PENS = {}
for k, key in Layout.ANIMALS do
	local x = 108 + Layout.PEN.w * (k - 0.5)
	Layout.PENS[key] = {
		x = x,
		z = Layout.PEN.z,
		pad = { x = x - 5, z = -145 }, -- the upgrade pad (6.4 across)
		feed = { x = x + 6, z = -145 }, -- the feed plate (4 across)
	}
end
Layout.FEED = 4 -- the feed plate's size

-- Where pad slot k stands: 1..8 in the build yard, 8 + n at animal n's pen
Layout.PAD_SLOTS = 8 + #Layout.ANIMALS
function Layout.padAt(k)
	if k <= 8 then
		return Layout.PADS[k]
	end
	local key = Layout.ANIMALS[k - 8]
	return key and Layout.PENS[key].pad or nil
end

-- The racks inside the warehouse and the centre: rows across the building behind the storefront (local z of each
-- row, the x range, and the levels); StockController fills them, then the pallet yard
Layout.PALLET = 3.4 -- a pallet stack's footprint
function Layout.racks(stage)
	local b = Layout.BUILDING[stage]
	if stage ~= "warehouse" and stage ~= "center" then
		return {}
	end
	local _, cz = Layout.building(stage)
	local rows = stage == "center" and 5 or 4
	local out = {}
	local back = cz + b.d / 2 - 8
	for r = 0, rows - 1 do
		table.insert(out, { z = back - r * 9, x0 = -b.w / 2 + 8, x1 = b.w / 2 - 8, levels = 3 })
	end
	return out
end

-- Every slot stock is shown in at a stage, in fill order: { x, z, y, size }. The stand: crates behind the counter;
-- the shop: crates on the back shelves; the warehouse and the centre: the racks inside, then the pallet yard.
function Layout.stockSlots(stage)
	local out = {}
	local function add(x, z, y, size)
		table.insert(out, { x = x, z = z, y = y, size = size })
	end
	if stage == "stand" or stage == nil then
		for layer = 0, 1 do
			for row = 0, 1 do
				for col = 0, 5 do
					add(-5.5 + col * 2.2, -137.5 + row * 2.2, 0.3 + layer * 1.8, 1.8)
				end
			end
		end
	elseif stage == "shop" then
		-- (the shelves either side of the back doors)
		local _, cz, b = Layout.building("shop")
		for layer = 0, 1 do
			for row = 0, 1 do
				for _, side in { -1, 1 } do
					for col = 0, 4 do
						add(side * (7.9 + col * 2.2), cz + b.d / 2 - 2.2 - row * 2.4, 0.6 + layer * 2.2, 1.8)
					end
				end
			end
		end
	else
		for _, r in Layout.racks(stage) do
			for level = 0, r.levels - 1 do
				for x = r.x0, r.x1, 4.4 do
					add(x, r.z, 0.6 + level * 4.2, Layout.PALLET)
				end
			end
		end
		local z = Layout.ZONES.palletYard
		for layer = 0, 1 do
			for row = 0, 12 do
				for col = 0, 5 do
					add(z.cx - 12.5 + col * 5, z.cz - 33 + row * 5.5, 0.2 + layer * 3.2, Layout.PALLET)
				end
			end
		end
	end
	return out
end

-- The zones that must not overlap (tests/LayoutSmoke): centre x, z, width, depth, local
local function rect(cx, cz, w, d)
	return { cx = cx, cz = cz, w = w, d = d }
end
Layout.ZONES = {
	business = rect(0, -112, 120, 80), -- the biggest building's footprint (the centre); smaller stages fit inside
	frontage = rect(0, -165, 40, 25), -- in front of the counter: the customers' line, open to the avenue
	palletYard = rect(-79, -112, 34, 80), -- left of the building: pallets of stock when the building is full
	truckYard = rect(81, -125, 38, 106), -- right of the building: the docks and the trucks' turning space
	yard = rect(-130, -140, 56, 40), -- the build pads
	spawn = rect(-130, -110, 8, 8),
	field1 = rect(0, -40, 61.7, 41.7),
	field2 = rect(-80, -35, 71.7, 51.7),
	field3 = rect(80, -35, 71.7, 51.7),
	field4 = rect(0, 20, 151.7, 31.7),
	shed = rect(155, -35, 30, 24),
	hay = rect(155, -60, 10, 4),
	pens = rect(152, -118, 88, 24),
	penFront = rect(152, -145, 88, 14),
	silo = rect(73.5, 80, 14, 6),
	house = rect(-150, 108, 34, 28),
	orchard = rect(-150, 150, 40, 22),
	pond = rect(-70, 120, 30, 30),
	windmill = rect(-100, 160, 6, 6),
	scarecrow = rect(-130, -30, 4, 2),
}

-- The city's courtyard
Layout.TOWN_SPOTS = {
	fountain = { x = 0, z = 0 },
	boards = { x = 0, z = 52 }, -- the leaderboard wall (north side, facing the fountain)
	store = { x = -50, z = 38 }, -- the store (north-west, facing east)
	board = { x = 50, z = 38 }, -- the market hall (north-east, facing west)
	meter = { x = 0, z = -46 }, -- the boost tower (south)
	spawn = { x = -28, z = -44 },
}

return Layout
