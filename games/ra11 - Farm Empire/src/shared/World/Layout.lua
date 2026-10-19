--[[
Where everything is (master plan §4). Twelve territories in two rows of six along an avenue, with the shared town
square in the middle of the avenue. Every territory is laid out in its own local frame (x across, z forward; the
front edge at z = -DEPTH/2 on the avenue) and turned to face the avenue, so one builder makes every farm.

Zones in a territory (local studs, 200 across by 180 deep):
  front yard       the business on the avenue (x 0), the spawn and the farmhouse at the left, the gate sign at
                   the right, the trucks' lane down the right edge
  the fields       three field blocks in a row behind the business (starter, East, West), the North field behind
                   them; wide paths between
  equipment zone   the machine shed at the right, between the fields and the lane
  logistics zone   the warehouse and its docks at the back right, the docks on the lane
  scenic edges     the orchard and the pond at the back left, trees all round, a fence

  Layout.territory(i)        { index, cx, cz, rotation, row, col }
  Layout.toWorld(i, x, z, y) local -> world Vector3
  Layout.toLocal(i, pos)
  Layout.cframe(i, x, z, y, yaw)
  Layout.FIELDS[key]         { x, z, cols, rows, tiles }: the tile grid of a field (pitch Layout.PITCH)
  Layout.tilePos(key, n)     local centre of tile n of a field
  Layout.tileId(key, n) / Layout.parseTile(id)
  Layout.SPOTS               named local points
  Layout.MAP                 the whole map's extent (the base plate, the edge)
]]
local Layout = {}

Layout.WIDTH = 200 -- x
Layout.DEPTH = 180 -- z
Layout.AVENUE = 40 -- the road between the rows
Layout.TOWN = 180 -- the square's side
Layout.PITCH = 5 -- tile pitch (4 x 4 tiles, a 1-stud path)
Layout.TILE = 4
Layout.GROUND_Y = 0

-- the territories: south row faces north (rotation 0), north row faces south (rotation 180)
local HALF_TOWN = Layout.TOWN / 2
local COLS = {}
for k = 1, 3 do
	local x = HALF_TOWN + Layout.WIDTH * (k - 0.5)
	COLS[4 - k] = -x
	COLS[3 + k] = x
end
local ROW_Z = Layout.AVENUE / 2 + Layout.DEPTH / 2

local territories = {}
for i = 1, 12 do
	local row = i <= 6 and 1 or 2 -- 1 south, 2 north
	local col = ((i - 1) % 6) + 1
	local cz = row == 1 and -ROW_Z or ROW_Z
	territories[i] = {
		index = i,
		cx = COLS[col],
		cz = cz,
		rotation = row == 1 and 0 or math.pi,
		row = row,
		col = col,
	}
end

-- the map: from the outermost farm's far edge, plus a margin of land, to the back of each row
Layout.MAP = {
	halfWidth = HALF_TOWN + Layout.WIDTH * 3 + 80,
	halfDepth = ROW_Z + Layout.DEPTH / 2 + 80,
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

-- A CFrame at a local point, facing local +z (or an angle on top)
function Layout.cframe(i, x, z, y, yaw)
	local t = territories[i]
	local p = Layout.toWorld(i, x, z, y)
	return CFrame.new(p) * CFrame.Angles(0, t.rotation + (yaw or 0), 0)
end

-- Which territory a world position is in (nil: the avenue or the town)
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
-- (three blocks in a row at z -38..-13, the North field behind at z 2..12)
Layout.FIELDS = {
	field1 = { x = -72, z = -38, cols = 4, rows = 6, tiles = 24 },
	field2 = { x = -40, z = -38, cols = 5, rows = 6, tiles = 30 },
	field3 = { x = -3, z = -38, cols = 5, rows = 6, tiles = 30 },
	field4 = { x = -72, z = 2, cols = 10, rows = 3, tiles = 30 },
}
Layout.FIELD_LIST = { "field1", "field2", "field3", "field4" }
Layout.FIELD_NAMES = { field1 = "HOME FIELD", field2 = "EAST FIELD", field3 = "WEST FIELD", field4 = "NORTH FIELD" }

-- the rectangle a field block covers (local), with a margin for its edge path
function Layout.fieldRect(key)
	local f = Layout.FIELDS[key]
	local w = f.cols * Layout.PITCH
	local d = f.rows * Layout.PITCH
	local cx = f.x + (f.cols - 1) * Layout.PITCH / 2
	local cz = f.z + (f.rows - 1) * Layout.PITCH / 2
	return cx, cz, w, d
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
	stand = { x = 0, z = -68 }, -- the business building (its back wall toward the fields)
	spawn = { x = -34, z = -74 },
	house = { x = -70, z = -66 }, -- the farmhouse (cosmetic, grows with the stage)
	lane = { x = 88, z = 0 }, -- the trucks' lane runs along the right edge from the avenue to the back
	shed = { x = 60, z = -22 }, -- the machine shed
	warehouse = { x = 36, z = 48 }, -- the warehouse (its docks on the +x side, on the lane)
	dock = { x = 76, z = 48 },
	parking = { x = 70, z = -70 },
	gate = { x = 0, z = -90 },
	sign = { x = 30, z = -84 },
	orchard = { x = -70, z = 56 }, -- the golden apple trees (cosmetic, with the orchard upgrade)
	pond = { x = -20, z = 62 },
	silo = { x = 10, z = 20 },
}

-- The town square at the origin
Layout.TOWN_SPOTS = {
	board = { x = -60, z = -30 }, -- the market hall
	meter = { x = 0, z = 50 }, -- the boost tower
	boards = { x = 60, z = -30 }, -- the leaderboard wall
	fountain = { x = 0, z = 0 },
	spawn = { x = 0, z = -60 },
	arch = { x = 0, z = -88 },
}

return Layout
