--[[
Where everything is (master plan §4). Twelve territories in two rows of six along an avenue, with the shared town
square in the middle of the avenue. Every territory is laid out in its own local frame (x across, z forward; the
front edge at z = -DEPTH/2 on the avenue) and turned to face the avenue, so one builder makes every farm.

Zones in a territory (local studs):
  front entrance   the business building on the avenue, the spawn beside it, trucks' lane on the right
  starter field    "field1" 24 tiles (4 across, 6 deep) right behind the stand
  expansion fields "field2" east, "field3" west, "field4" north: 30 tiles each
  equipment zone   the machine shed on the right, behind the lane
  logistics zone   the warehouse and its docks at the back right
  scenic edges     trees, a fence all round

  Layout.territory(i)        { index, cx, cz, rotation, front }
  Layout.toWorld(i, x, z, y) local -> world Vector3
  Layout.toLocal(i, pos)
  Layout.FIELDS[key]         { x, z, cols, rows }: the tile grid of a field block (tile pitch Layout.PITCH)
  Layout.tilePos(key, n)     local centre of tile n of a field
  Layout.tileId(key, n) / Layout.parseTile(id)
  Layout.SPOTS               named local points: stand, spawn, lane, shed, warehouse, dock, parking
]]
local Layout = {}

Layout.WIDTH = 130 -- x
Layout.DEPTH = 120 -- z
Layout.AVENUE = 36 -- the road between the rows
Layout.TOWN = 150 -- the square's side
Layout.PITCH = 5 -- tile pitch (4 x 4 tiles, a 1-stud path)
Layout.TILE = 4
Layout.GROUND_Y = 0

-- the territories: south row faces north (rotation 0), north row faces south (rotation 180)

local COLS = { -400, -270, -140, 140, 270, 400 }
local ROW_Z = Layout.AVENUE / 2 + Layout.DEPTH / 2 -- 78

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
Layout.FIELDS = {
	field1 = { x = -7.5, z = -28, cols = 4, rows = 6, tiles = 24 },
	field2 = { x = 20, z = -28, cols = 5, rows = 6, tiles = 30 },
	field3 = { x = -42.5, z = -28, cols = 5, rows = 6, tiles = 30 },
	field4 = { x = -42.5, z = 12, cols = 10, rows = 3, tiles = 30 },
}
Layout.FIELD_LIST = { "field1", "field2", "field3", "field4" }

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
	stand = { x = 0, z = -50 }, -- the business building (its back wall toward the fields)
	spawn = { x = -22, z = -52 },
	lane = { x = 48, z = -30 }, -- the trucks' lane runs along the right edge from the avenue
	shed = { x = 48, z = 8 }, -- the machine shed
	warehouse = { x = 20, z = 36 }, -- the warehouse and docks (stage C+) at the back right
	dock = { x = 50, z = 36 },
	parking = { x = 48, z = -46 },
	gate = { x = 0, z = -60 },
	sign = { x = 24, z = -56 },
}

-- The town square at the origin: the market board, the boost meter, the leaderboards, the spawn for visitors
Layout.TOWN_SPOTS = {
	board = { x = -40, z = 0 },
	meter = { x = 0, z = 30 },
	boards = { x = 40, z = 0 },
	fountain = { x = 0, z = 0 },
}

return Layout
