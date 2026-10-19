--[[
Where everything is (master plan §4). The city sits in the middle of the map; the avenue runs east-west through
it; twelve farms line the avenue in two rows of six, three each side of the city, every one with its FRONT on the
avenue. Each farm is laid out in its own local frame (x across, z from the front edge on the avenue at
z = -DEPTH/2 to the back at +DEPTH/2) and turned so its front faces the road, so one builder makes every farm.

A farm, front to back (local studs, 200 across by 180 deep; every zone below has its own rectangle, see ZONES,
and tests/LayoutSmoke checks none of them overlap):
  the frontage     the stand (later the shop) right on the avenue, open to the road so customers walk up; the
                   farm gate at its left; the trucks' lane entrance at the right
  the build yard   just inside the gate: the spawn and the eight upgrade pads (step on one to buy it)
  the fields       the home field right behind the stand, the East and West fields either side, the North field
                   behind them; paths between
  machines         the shed at the right, by the lane
  logistics        the warehouse at the back right, its docks on the lane
  the back         the farmhouse, the orchard, the pond and the windmill at the back left; trees all round

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

Layout.WIDTH = 200 -- x
Layout.DEPTH = 180 -- z
Layout.AVENUE = 40 -- the road between the rows, sidewalks included
Layout.ROAD = 28 -- the asphalt in the middle of it
Layout.GAP = 12 -- the tree strip between two farms
Layout.PITCH = 5 -- tile pitch (4 x 4 tiles, a 1-stud path)
Layout.TILE = 4
Layout.GROUND_Y = 0
Layout.FENCE = { x = 98.5, z = 88.5 } -- the fence's line, inside the farm's edge
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
	field1 = { x = -7.5, z = -46, cols = 4, rows = 6, tiles = 24 },
	field2 = { x = -42.5, z = -46, cols = 5, rows = 6, tiles = 30 },
	field3 = { x = 21, z = -46, cols = 5, rows = 6, tiles = 30 },
	field4 = { x = -42.5, z = -8, cols = 10, rows = 3, tiles = 30 },
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

-- Named points
Layout.SPOTS = {
	stand = { x = 0, z = -72 }, -- the stand's middle; the shop stands 4 further back (its front at z -77)
	gate = { x = -40, z = -90 }, -- the farm gate, between its two pillars
	spawn = { x = -22, z = -55 }, -- inside the gate, between the build yard and the home field
	yard = { x = -38.5, z = -71.5 }, -- the build yard's middle
	lane = { x = 86, z = -5 }, -- the trucks' lane, from the avenue to the warehouse
	shed = { x = 62, z = -30 }, -- the machine shed
	machine2 = { x = 62, z = -10 }, -- where the fleet's second machine parks
	hay = { x = 60, z = -45 },
	warehouse = { x = 40, z = 50 }, -- the warehouse; its docks on the +x side, on the lane
	center = { x = 31, z = 50 }, -- the distribution centre (bigger, same dock wall)
	silo = { x = 10, z = 20 },
	house = { x = -72, z = 44 },
	orchard = { x = -72, z = 70 },
	pond = { x = -30, z = 62 },
	windmill = { x = -50, z = 79 },
	scarecrow = { x = -52, z = -20 },
	lawn = { x = 48, z = -73 }, -- the front lawn right of the stand
	region = { x = 48, z = -74 }, -- where the new-region preview stands
	dock = { x = 76, z = 50 },
}

-- The pads: two rows of four in the build yard, the ones nearest the spawn first
Layout.PADS = {}
for k = 1, 8 do
	local row = (k - 1) // 4 -- 0 the back row (nearer the spawn), 1 the front row
	local col = (k - 1) % 4
	Layout.PADS[k] = { x = -25 - col * 9, z = -67 - row * 9 }
end

-- The zones that must not overlap (tests/LayoutSmoke): centre x, z, width, depth, local
local function rect(cx, cz, w, d)
	return { cx = cx, cz = cz, w = w, d = d }
end
Layout.ZONES = {
	business = rect(0, -68, 30, 18), -- the shop's footprint (the stand is smaller)
	frontage = rect(0, -84, 36, 10), -- in front of the counter: the customers' line
	yard = rect(-38.5, -71.5, 40, 21),
	spawn = rect(-22, -55, 6, 6),
	field1 = rect(0, -33.5, 21.7, 31.7),
	field2 = rect(-32.5, -33.5, 26.7, 31.7),
	field3 = rect(31, -33.5, 26.7, 31.7),
	field4 = rect(-20, -3, 51.7, 16.7),
	shed = rect(62, -30, 20, 18),
	hay = rect(60, -45, 8, 4),
	warehouse = rect(33, 50, 78, 54), -- the centre's yard (the warehouse's is smaller)
	silo = rect(13.5, 20, 12, 5),
	lane = rect(86, -5, 14, 170),
	house = rect(-72, 43, 28, 22),
	orchard = rect(-72, 70, 30, 18),
	pond = rect(-30, 62, 26, 26),
	windmill = rect(-50, 79, 6, 6),
	scarecrow = rect(-52, -20, 4, 2),
	lawn = rect(48, -73, 56, 28),
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
