--[[
Where everything is (master plan §10). The main road runs along X through the middle of the world; three plots
face it from each side, a fence apart, so neighbours see each other grow. Each plot is WIDTH x DEPTH studs of land
reserved from the start (meadow until it's built on) and has its own frame: local -Z is its front, at the road;
+X is the right hand of someone in the plot looking out at the road. One layout serves all six.

The plot's zones (local coordinates), filled stage by stage:
  front strip   z -110..-86     the stand, the driveway, later the truck court's entrance
  farm (left)   x -80..-4       the shack and soil (stage 1), fields and the barn (2)
  animals       x -80..-4, z 20..110   the pens (2)
  industry      x 4..80         the packing shed and its yard (3), the warehouse and its dock doors (4, 5)
  the road      z -110..-150    two lanes (centres z -125 and -135 in a plot's frame): vehicles come and go here

  PlotLayout.frame(i)          plot i's CFrame (1-3 north of the road, 4-6 south)
  PlotLayout.toWorld(i, x, z, y?)
  PlotLayout.SPOTS             the named local spots (spawn, shack, stand, pads, soil origin...)
  PlotLayout.soilTile(n)       tile n's local centre (1..12 the shack's field, 13..39 the stage-2 fields)
]]
local PlotLayout = {}

PlotLayout.WIDTH = 160
PlotLayout.DEPTH = 220
PlotLayout.GAP = 4 -- the fence between neighbours
PlotLayout.ROAD = 40 -- the main road's width, kerb to kerb (two lanes and the verges)
PlotLayout.COLUMNS = { -(160 + 4), 0, 160 + 4 } -- the plots' X along the road

function PlotLayout.frame(i)
	local north = i <= 3
	local x = PlotLayout.COLUMNS[(i - 1) % 3 + 1]
	local z = (PlotLayout.ROAD / 2 + PlotLayout.DEPTH / 2) * (north and -1 or 1)
	local centre = Vector3.new(x, 0, z)
	-- (the front faces the road: north plots look +Z, south plots look -Z)
	return CFrame.lookAt(centre, centre + Vector3.new(0, 0, north and 1 or -1))
end

function PlotLayout.toWorld(i, x, z, y)
	return PlotLayout.frame(i) * Vector3.new(x, y or 0, z)
end

PlotLayout.SPOTS = {
	spawn = Vector3.new(-40, 3, -104),
	shack = Vector3.new(-58, 0, -70),
	stand = Vector3.new(-30, 0, -100),
	pads = { Vector3.new(-6, 0, -98), Vector3.new(4, 0, -98), Vector3.new(14, 0, -98) },
	soil = Vector3.new(-32, 0, -82), -- the first tile's centre
	well = Vector3.new(-72, 0, -54),
	wheelbarrow = Vector3.new(-46, 0, -62),
	scarecrow = Vector3.new(-6, 0, -60),
	barnSite = Vector3.new(-42, 0, -20), -- the barn: 28 x 20 here (stage 2)
	field = Vector3.new(-74, 0, -1), -- the stage-2 fields' first tile (tiles 13..39, 9 to a row)
	tractor = Vector3.new(-14, 0, -24),
	silo = Vector3.new(-72, 0, -34),
	windmill = Vector3.new(-12, 0, -40),
	path = Vector3.new(-41, 0, 22), -- the dirt path down the middle of the pens
	-- the pens: a 2 x 2 block behind the fields, a path between; each PEN wide, its pad at its front
	pens = {
		chicken = Vector3.new(-60, 0, 44),
		pig = Vector3.new(-22, 0, 44),
		sheep = Vector3.new(-60, 0, 86),
		cow = Vector3.new(-22, 0, 86),
	},
	-- stage 3: the packing shed (36 x 28, its front wall at z -74), its yard and the drive to the road
	shed = Vector3.new(34, 0, -60),
	packPad = Vector3.new(24, 0, -79), -- the packing table's pad, outside the shed's side door
	board = Vector3.new(6, 0, -80), -- the order board
	door = Vector3.new(42, 0, -74), -- the loading door, in the shed's front wall
	boxLine = Vector3.new(4, 0, -62), -- where the box line's belt starts, outside the west wall
	sorter = Vector3.new(64, 0, -54),
	wrapper = Vector3.new(64, 0, -66),
	parks = { Vector3.new(64, 0, -80), Vector3.new(74, 0, -80) }, -- where the vans wait
	warehouseSite = Vector3.new(42, 0, -2),
	mailbox = Vector3.new(-50, 0, -106),
	sign = Vector3.new(-74, 0, -106),
}
PlotLayout.TILE = 6 -- a soil tile's size
PlotLayout.TILE_GAP = 1.6
PlotLayout.TILE_COLUMNS = 4

PlotLayout.SHED = Vector3.new(36, 14, 28) -- the shed's size
PlotLayout.LANES = { -125, -135 } -- the road's lanes in a plot's frame (near, far)
PlotLayout.FIELD_COLUMNS = 9
PlotLayout.PEN = Vector3.new(34, 0, 38) -- a pen's size (x, z)
-- the conveyor's route: from the barn's west side round to the stand (stage 2)
PlotLayout.CONVEYOR = {
	Vector3.new(-56, 0, -22),
	Vector3.new(-78, 0, -22),
	Vector3.new(-78, 0, -92),
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
