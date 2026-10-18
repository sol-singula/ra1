--[[
Where everything is (master plan §10). The main road runs along X through the middle of the world; three plots
face it from each side, a fence apart, so neighbours see each other grow. Each plot is WIDTH x DEPTH studs of land
reserved from the start (meadow until it's built on) and has its own frame: local -Z is its front, at the road;
+X is the right hand of someone in the plot looking out at the road. One layout serves all six.

The plot's zones (local coordinates), filled stage by stage:
  front strip   z -110..-86     the stand, the driveway, later the truck court's entrance
  farm (left)   x -80..-4       front to back, all on one walk: the shack and soil (stage 1), the big fields right
                                behind them, the barn (2), the coop and the pens right behind the barn
  the farm path x -1            a dirt path from the stand past the soil, the fields and the barn to the pens
  animals       x -80..-4, z 13..93   the pens (2)
  industry      x 4..80         the packing shed and its yard (3), the warehouse and its dock doors (4, 5)
  the road      z -110..-150    two lanes (centres z -125 and -135 in a plot's frame): vehicles come and go here

  PlotLayout.frame(i)          plot i's CFrame (1-3 north of the road, 4-6 south)
  PlotLayout.toWorld(i, x, z, y?)
  PlotLayout.SPOTS             the named local spots (spawn, shack, stand, pads, soil origin...)
  PlotLayout.soilTile(n)       tile n's local centre (1..12 the shack's field, 13..39 the stage-2 fields)
]]
local PlotLayout = {}

PlotLayout.WIDTH = 240
PlotLayout.DEPTH = 380 -- (big plots: the land runs far back from the road, room for the farm to grow huge)
PlotLayout.EDGE = 110 -- how far the plot's frame sits back from its front edge (the road): local z -EDGE
PlotLayout.GAP = 4 -- the fence between neighbours
PlotLayout.ROAD = 40 -- the main road's width, kerb to kerb (two lanes and the verges)
PlotLayout.COLUMNS = { -(240 + 4), 0, 240 + 4 } -- the plots' X along the road

function PlotLayout.frame(i)
	local north = i <= 3
	local x = PlotLayout.COLUMNS[(i - 1) % 3 + 1]
	local z = (PlotLayout.ROAD / 2 + PlotLayout.EDGE) * (north and -1 or 1)
	local centre = Vector3.new(x, 0, z)
	-- (the front faces the road: north plots look +Z, south plots look -Z)
	return CFrame.lookAt(centre, centre + Vector3.new(0, 0, north and 1 or -1))
end

function PlotLayout.toWorld(i, x, z, y)
	return PlotLayout.frame(i) * Vector3.new(x, y or 0, z)
end

PlotLayout.SPOTS = {
	spawn = Vector3.new(-22, 3, -109), -- between SELL and the buy-pads, facing the soil: everything a few steps away
	spawnHub = Vector3.new(-42, 3, -104), -- the spawn once the market hall stands
	shack = Vector3.new(-58, 0, -70),
	stand = Vector3.new(-30, 0, -100),
	pads = { Vector3.new(-14, 0, -105), Vector3.new(-6, 0, -105), Vector3.new(2, 0, -105) }, -- in line with SELL
	soil = Vector3.new(-32, 0, -82), -- the first tile's centre
	well = Vector3.new(-72, 0, -54),
	waterTower = Vector3.new(-75, 0, -90), -- (with the sprinklers)
	wheelbarrow = Vector3.new(-46, 0, -62),
	scarecrow = Vector3.new(-6, 0, -60),
	barnSite = Vector3.new(-42, 0, -8), -- the barn: 28 x 20 here (stage 2), its doors facing the fields
	field = Vector3.new(-74, 0, -46), -- the stage-2 fields' first tile (tiles 13..39, 9 to a row), behind the soil
	tractor = Vector3.new(-19, 0, -10),
	silo = Vector3.new(-68, 0, -20),
	windmill = Vector3.new(-70, 0, 5),
	farmPath = { z0 = -97, z1 = 93, x = -1, pens = 9 }, -- the farm path, front to back, and its branch along the pens' pads
	path = Vector3.new(-41, 0, 53), -- the dirt path down the middle of the pens
	-- the pens: a 2 x 2 block right behind the barn, a path between; each PEN wide, its pad at its front
	pens = {
		chicken = Vector3.new(-60, 0, 32),
		pig = Vector3.new(-22, 0, 32),
		sheep = Vector3.new(-60, 0, 74),
		cow = Vector3.new(-22, 0, 74),
	},
	-- stage 3: the packing shed (36 x 28, its front wall at z -74), its yard and the drive to the road
	shed = Vector3.new(34, 0, -60),
	packPad = Vector3.new(24, 0, -79), -- the packing table's pad, outside the shed's side door
	board = Vector3.new(11, 0, -80), -- the order board
	door = Vector3.new(42, 0, -74), -- the loading door, in the shed's front wall
	boxLine = Vector3.new(4, 0, -62), -- where the box line's belt starts, outside the west wall
	sorter = Vector3.new(64, 0, -58),
	wrapper = Vector3.new(64, 0, -70),
	parks = { Vector3.new(64, 0, -80), Vector3.new(54, 0, -80) }, -- where the vans wait
	-- stage 4: the warehouse (WAREHOUSE in size, its front wall at z -36), the truck lane up the plot's east edge,
	-- the box trucks' lot behind it
	warehouse = Vector3.new(38, 0, -6),
	warehouseSite = Vector3.new(38, 0, -6),
	peopleDoor = Vector3.new(24, 0, -36), -- in the warehouse's front wall (the shed's back door lines up with it)
	truckDoor = Vector3.new(64, 0, -36),
	stations = { -- the four station pads, outside the front wall: grow, pack, store, ship
		Vector3.new(30, 0, -41),
		Vector3.new(38, 0, -41),
		Vector3.new(46, 0, -41),
		Vector3.new(54, 0, -41),
	},
	lane = 76, -- the truck lane's x
	lot = { Vector3.new(64, 0, 40), Vector3.new(57, 0, 40), Vector3.new(50, 0, 40), Vector3.new(43, 0, 40) },
	greenhouses = Vector3.new(20, 0, 97),
	-- stage 5: the hub. Dock doors along the warehouse's back wall (z 24), the truck court behind it, each truck's
	-- spot in line with its dock; the front hall (z -74..-36) where the shed stood; the market hall along the road
	-- where the farm stand stood
	docks = { 64, 53.5, 43, 32.5, 22, 11.5 }, -- the dock doors' x: box truck n uses dock n, semi n dock 4 + n
	dockLot = { Vector3.new(64, 0, 76), Vector3.new(53.5, 0, 76), Vector3.new(43, 0, 76), Vector3.new(32.5, 0, 76) },
	expressStop = Vector3.new(-10, 0, -116), -- where a Special Order's express truck waits, on the road's verge
	frontHall = Vector3.new(38, 0, -55),
	market = Vector3.new(-15, 0, -97.5), -- the market hall's middle: 42 x 21 (x -36..6, z -108..-87)
	marketSell = Vector3.new(-28, 0, -100), -- the sell pad, by the market's door
	marketPads = { Vector3.new(-16, 0, -94), Vector3.new(-7, 0, -94), Vector3.new(2, 0, -94) }, -- the buy-pads move in
	mailbox = Vector3.new(-50, 0, -106),
	sign = Vector3.new(-74, 0, -106),
}
PlotLayout.TILE = 6 -- a soil tile's size
PlotLayout.TILE_GAP = 1.6
PlotLayout.TILE_COLUMNS = 4

PlotLayout.SHED = Vector3.new(36, 14, 28) -- the shed's size
PlotLayout.LANES = { -125, -135 } -- the road's lanes in a plot's frame (near, far)
PlotLayout.WAREHOUSE = Vector3.new(64, 18, 60)
-- the warehouse in slices front to back: A (z -36..-20: the packing lines, the staging floor, the office), then a
-- slice a bay: each holds a back-to-back pair of rack rows (rows 2k-1, 2k) along X with its aisle in front
PlotLayout.SLICES = { -36, -20, -9, 2, 13, 24 }
PlotLayout.RACK_X = { 8, 58 } -- a rack row runs from x 8 to 58; the cross aisle beyond it to the east wall
PlotLayout.SLOT = 5.6 -- a rack slot's length
PlotLayout.FRONT = -74 -- the front hall's front wall (where the shed's front wall was)
PlotLayout.MARKET = Vector3.new(42, 13, 21) -- the market hall's size
PlotLayout.LEVELS = 3

-- The warehouse annex (stage 5, out the back of the plot): rack rows 9-16, two to a bay of ANNEX_BAY
PlotLayout.ANNEX = Vector3.new(38, 0, 150) -- its middle; 64 wide (like the warehouse), 56 deep
PlotLayout.ANNEX_SIZE = Vector3.new(64, 18, 56)
PlotLayout.ANNEX_BAY = 13

-- A rack row's slot (n from 1, along the row then up): its local centre (where a pallet sits)
function PlotLayout.rackSlot(row, n)
	local slice = (row + 1) // 2 -- (rows 1-2 in the first bay slice, 3-4 the next...)
	local z0 = PlotLayout.SLICES[slice + 1]
	if row > 8 then
		z0 = PlotLayout.ANNEX.Z - PlotLayout.ANNEX_SIZE.Z / 2 + 3 + ((row - 9) // 2) * PlotLayout.ANNEX_BAY
	end
	local back = row % 2 == 0
	local z = z0 + (back and 9.7 or 7.1)
	local per = math.floor((PlotLayout.RACK_X[2] - PlotLayout.RACK_X[1]) / PlotLayout.SLOT)
	local i = (n - 1) % per
	local level = (n - 1) // per
	return Vector3.new(PlotLayout.RACK_X[1] + PlotLayout.SLOT * (i + 0.5), 0.55 + level * 3.2, z)
end

-- The aisle a rack row faces (its z), where the forklifts drive: a front row's own slice's, a back row's the next
-- slice's (the last back row is reached from the front)
function PlotLayout.aisle(row)
	if row > 8 then
		return PlotLayout.rackSlot(row, 1).Z + (row % 2 == 0 and 2.9 or -2.9)
	end
	local slice = (row + 1) // 2
	if row % 2 == 0 and slice + 2 <= #PlotLayout.SLICES - 1 then
		return PlotLayout.SLICES[slice + 2] + 2.9
	end
	return PlotLayout.SLICES[slice + 1] + 2.9
end
PlotLayout.FIELD_COLUMNS = 9
PlotLayout.PEN = Vector3.new(34, 0, 38) -- a pen's size (x, z)
-- the conveyor's route (stage 2): it starts at the coop, runs along the pens' gates behind the barn (collecting and
-- feeding as it goes), turns down the far side of the farm path, past the fields and the soil, and along the front to
-- the stand, where it tips into the till
PlotLayout.CONVEYOR = {
	Vector3.new(-64, 0, 4.8),
	Vector3.new(3, 0, 4.8),
	Vector3.new(3, 0, -92),
	Vector3.new(-36, 0, -92),
}

function PlotLayout.soilTile(n)
	local step = PlotLayout.TILE + PlotLayout.TILE_GAP
	if n > 12 then
		-- (the stage-2 fields)
		local m = n - 13
		local c = m % PlotLayout.FIELD_COLUMNS
		local r = m // PlotLayout.FIELD_COLUMNS
		return PlotLayout.SPOTS.field + Vector3.new(c * step, 0, r * step)
	end
	local c = (n - 1) % PlotLayout.TILE_COLUMNS
	local r = (n - 1) // PlotLayout.TILE_COLUMNS
	return PlotLayout.SPOTS.soil + Vector3.new(c * step, 0, r * step)
end

return PlotLayout
