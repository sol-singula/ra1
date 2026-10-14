--[[
Where everything is on the first map (master plan §6): a green valley with a stone hill in the middle.

  x = -540   the monster spawn: a rift in a dark forest at the west end
  x = -360   a creek across the valley (a thin rope bridge north, a stone bridge in the middle, stepping stones south)
  x = -200   Shrine 1 on the open hill: a flat-topped stone hill (cliffs all round, four ramps up)
  x =  -24   the canyon mouth (the monsters' first wall of magic: it opens when Shrine 1 falls)
  x =  110   Shrine 2 inside a rocky canyon (a rock spine splits it into two lanes)
  x =  228   the mountain (the second wall of magic, at the two tunnel mouths)
  x =  400   Shrine 3 deep inside the mountain cave
  The hangout (between matches) is a mead hall on the north ridge, looking down on the valley.

The map runs along X; everything is shared so the server (pieces, NPCs, checks), the client (ghosts, guides) and
the render tools agree on every coordinate. NPCs aren't physical: groundY and walkable keep them on the ground and
out of the rock.
]]
local MapLayout = {}

local V3 = Vector3.new
local V2 = Vector2.new

MapLayout.CELL = 4
MapLayout.BOUNDS = { minX = -620, maxX = 560, minZ = -240, maxZ = 240 }

-- The stone hill under Shrine 1: a flat top (radius TOP, HEIGHT tall) with cliffs, and four ramps up.
MapLayout.HILL = {
	center = V2(-200, 0),
	top = 100,
	foot = 140, -- where the ramps reach the valley floor
	height = 10,
	rampWidth = 24,
	ramps = {
		{ key = "west", dir = V2(-1, 0) },
		{ key = "northwest", dir = V2(-1, 1).Unit },
		{ key = "southwest", dir = V2(-1, -1).Unit },
		{ key = "east", dir = V2(1, 0) },
	},
}
local HILL = MapLayout.HILL

-- Shrines, each with its build zone (where pieces may go).
MapLayout.shrines = {
	{
		index = 1,
		name = "Hill Shrine",
		short = "Hill",
		pos = V3(-200, HILL.height, 0),
		zone = { kind = "disc", center = V2(-200, 0), radius = 94 },
	},
	{
		index = 2,
		name = "Canyon Shrine",
		short = "Canyon",
		pos = V3(110, 0, 0),
		zone = { kind = "rect", min = V2(76, -52), max = V2(190, 52) },
	},
	{
		index = 3,
		name = "Cave Shrine",
		short = "Cave",
		pos = V3(400, 0, 0),
		zone = { kind = "disc", center = V2(400, 0), radius = 60 },
	},
}

-- The walls of magic between the shrines (block monsters only). Barrier k opens when Shrine k falls.
MapLayout.barriers = {
	{ index = 1, x = -24, minZ = -58, maxZ = 58, height = 70 },
	{ index = 2, x = 228, minZ = -58, maxZ = 58, height = 70 },
}
-- Dwarves can't go into the monster spawn (no spawn camping).
MapLayout.DWARF_BARRIER_X = -470

-- The canyon (zone 2) and the mountain cave (zone 3)
MapLayout.CANYON = { minX = -24, maxX = 232, halfWidth = 58 }
MapLayout.SPINE = { minX = 10, maxX = 70, halfWidth = 10, height = 16 } -- the rock spine in the canyon
MapLayout.CAVE = {
	center = V2(400, 0),
	radius = 72,
	ceiling = 52,
	mainTunnel = { minX = 228, maxX = 334, minZ = -12, maxZ = 12, height = 22 },
	sideTunnel = { minX = 228, maxX = 346, minZ = 32, maxZ = 48, height = 18 },
}
MapLayout.CREEK = { x = -360, width = 16 }
MapLayout.RIDGE_Z = 206 -- the valley's mountain walls (north and south), until they close in on the canyon

-- Monster spawns: the forest rift first, then each fallen shrine.
MapLayout.FOREST_SPAWN = V3(-540, 0, 0)

-- NPC lanes: for each zone (the shrine the monsters are after), the paths from that zone's spawn to the shrine.
-- Points are (x, z); NPCs walk them with a little sideways spread so the horde doesn't move single file.
MapLayout.lanes = {
	[1] = {
		{
			key = "north",
			points = {
				V2(-540, 0),
				V2(-488, 42),
				V2(-428, 96),
				V2(-362, 112),
				V2(-312, 110),
				V2(-299, 99),
				V2(-271, 71),
				V2(-234, 34),
				V2(-208, 8),
			},
		},
		{
			key = "middle",
			points = {
				V2(-540, 0),
				V2(-470, 0),
				V2(-404, -6),
				V2(-362, 0),
				V2(-340, 0),
				V2(-300, 0),
				V2(-250, 0),
				V2(-210, 0),
			},
		},
		{
			key = "south",
			points = {
				V2(-540, 0),
				V2(-488, -44),
				V2(-430, -98),
				V2(-376, -120),
				V2(-312, -110),
				V2(-299, -99),
				V2(-271, -71),
				V2(-234, -34),
				V2(-208, -8),
			},
		},
	},
	[2] = {
		{
			key = "north",
			points = {
				V2(-200, 0),
				V2(-140, 0),
				V2(-100, 0),
				V2(-60, 0),
				V2(-24, 12),
				V2(8, 34),
				V2(72, 34),
				V2(98, 16),
				V2(106, 4),
			},
		},
		{
			key = "south",
			points = {
				V2(-200, 0),
				V2(-140, 0),
				V2(-100, 0),
				V2(-60, 0),
				V2(-24, -12),
				V2(8, -34),
				V2(72, -34),
				V2(98, -16),
				V2(106, -4),
			},
		},
	},
	[3] = {
		{
			key = "tunnel",
			points = { V2(110, 0), V2(170, 0), V2(232, 0), V2(300, 0), V2(340, 0), V2(392, 0) },
		},
		{
			key = "crack",
			points = { V2(110, 0), V2(160, 22), V2(232, 40), V2(300, 40), V2(346, 40), V2(372, 22), V2(394, 6) },
		},
	},
}
-- How wide the horde spreads around a lane (studs either side), by zone.
MapLayout.LANE_SPREAD = { 6, 6, 4 }

-- Resource nodes: stone (rock piles, crystals), wood (trees, giant mushrooms), gold (veins in the mines).
-- `starter` nodes are the glowing pile right by the dwarf spawn (it comes back fast, for the first minute).
MapLayout.nodes = {
	-- zone 1: the hill and the valley
	{ kind = "stone", pos = V3(-182, 10, 24), starter = true },
	{ kind = "stone", pos = V3(-150, 10, -62) },
	{ kind = "stone", pos = V3(-146, 10, 58) },
	{ kind = "stone", pos = V3(-250, 10, -78) },
	{ kind = "stone", pos = V3(-252, 10, 76) },
	{ kind = "stone", pos = V3(-322, 0, 40) },
	{ kind = "stone", pos = V3(-318, 0, -48) },
	{ kind = "stone", pos = V3(-140, 0, 150) },
	{ kind = "stone", pos = V3(-130, 0, -150) },
	{ kind = "stone", pos = V3(-252, 0, 152) },
	{ kind = "stone", pos = V3(-262, 0, -150) },
	{ kind = "stone", pos = V3(-410, 0, 60) },
	{ kind = "stone", pos = V3(-402, 0, -62) },
	{ kind = "wood", pos = V3(-120, 0, 120) },
	{ kind = "wood", pos = V3(-98, 0, 142) },
	{ kind = "wood", pos = V3(-78, 0, 114) },
	{ kind = "wood", pos = V3(-136, 0, 170) },
	{ kind = "wood", pos = V3(-88, 0, 172) },
	{ kind = "wood", pos = V3(-120, 0, -120) },
	{ kind = "wood", pos = V3(-96, 0, -146) },
	{ kind = "wood", pos = V3(-78, 0, -112) },
	{ kind = "wood", pos = V3(-140, 0, -170) },
	{ kind = "wood", pos = V3(-92, 0, -172) },
	{ kind = "wood", pos = V3(-330, 0, 150) },
	{ kind = "wood", pos = V3(-340, 0, -162) },
	{ kind = "wood", pos = V3(-282, 0, 164) },
	{ kind = "wood", pos = V3(-292, 0, -170) },
	{ kind = "gold", pos = V3(-236, 0, 191) },
	{ kind = "gold", pos = V3(-220, 0, 193) },
	{ kind = "gold", pos = V3(-170, 0, -191) },
	{ kind = "gold", pos = V3(-154, 0, -193) },
	-- zone 2: the canyon
	{ kind = "stone", pos = V3(150, 0, 44) },
	{ kind = "stone", pos = V3(176, 0, -42) },
	{ kind = "stone", pos = V3(40, 0, 46) },
	{ kind = "stone", pos = V3(30, 0, -46) },
	{ kind = "wood", pos = V3(90, 0, 48) },
	{ kind = "wood", pos = V3(160, 0, -48) },
	{ kind = "wood", pos = V3(-6, 0, 44) },
	{ kind = "gold", pos = V3(124, 0, 52) },
	{ kind = "gold", pos = V3(60, 0, -52) },
	-- zone 3: the cave
	{ kind = "stone", pos = V3(360, 0, 52) },
	{ kind = "stone", pos = V3(446, 0, -44) },
	{ kind = "stone", pos = V3(446, 0, 48) },
	{ kind = "stone", pos = V3(352, 0, -50) },
	{ kind = "wood", pos = V3(420, 0, 60) },
	{ kind = "wood", pos = V3(374, 0, -60) },
	{ kind = "gold", pos = V3(464, 0, 10) },
	{ kind = "gold", pos = V3(400, 0, -64) },
}
for i, n in MapLayout.nodes do
	n.id = i
end
MapLayout.NODE_AMOUNT = { stone = 12, wood = 8, gold = 6 }
MapLayout.NODE_SIZE = { stone = 7, wood = 5, gold = 6 } -- studs across (for "in reach")

-- The mine entrances in the hills on the sides (the gold veins are at the mouth). pos is the doorway's foot.
MapLayout.mines = {
	{ pos = V3(-228, 0, 200), facing = -1 }, -- north ridge, opening south
	{ pos = V3(-162, 0, -200), facing = 1 }, -- south ridge, opening north
}

-- Job boards: tap one to change jobs (before the plague).
MapLayout.jobBoards = {
	{ pos = V3(-176, 10, -22), shrine = 1 },
	{ pos = V3(128, 0, -26), shrine = 2 },
	{ pos = V3(384, 0, 26), shrine = 3 },
}

-- Where dwarves spawn: inside the castle around the shrine they're holding.
function MapLayout.dwarfSpawn(shrineIndex, n)
	local s = MapLayout.shrines[shrineIndex] or MapLayout.shrines[1]
	local a = (n or 1) * 2.399 -- golden angle: spread out
	local r = 10 + (n or 1) % 4 * 1.5
	return s.pos + V3(18 + math.cos(a) * r * 0.5, 3, math.sin(a) * r)
end

-- Where monsters spawn: the forest rift, or the last shrine they took.
function MapLayout.monsterSpawnCenter(fallen)
	if fallen and fallen >= 1 then
		return MapLayout.shrines[math.min(fallen, 2)].pos
	end
	return MapLayout.FOREST_SPAWN
end

function MapLayout.monsterSpawn(fallen, n)
	local c = MapLayout.monsterSpawnCenter(fallen)
	local a = (n or 1) * 2.399
	local r = 5 + (n or 1) % 5 * 2
	return c + V3(math.cos(a) * r, 3, math.sin(a) * r)
end

-- The hangout between matches: a mead hall terrace on the north ridge (RIDGE_TOP high).
MapLayout.RIDGE_TOP = 50
MapLayout.hangout = {
	center = V3(-200, 50, 268),
	deck = { minX = -246, maxX = -154, minZ = 244, maxZ = 296 },
	podium = { V3(-200, 50, 286), V3(-212, 50, 288), V3(-188, 50, 288) }, -- 1st, 2nd, 3rd
	shop = V3(-232, 50, 284),
	board = V3(-168, 50, 284),
}
function MapLayout.hangoutSpawn(n)
	local a = (n or 1) * 2.399
	local r = 4 + (n or 1) % 5 * 2.5
	return MapLayout.hangout.center + V3(math.cos(a) * r, 3, -6 + math.sin(a) * r * 0.6)
end

-- The castle the team starts with at Shrine 1 (§7 stage 1: the camp): the west wall's plan, as glowing
-- blueprints. In grid cells (i, j) with rot 1 = along Z. The gate sits on the middle lane.
MapLayout.starter = {
	{ key = "gate", i = -61, j = -1, rot = 1 },
	{ key = "stoneWall", i = -61, j = 1, rot = 1 },
	{ key = "stoneWall", i = -61, j = 3, rot = 1 },
	{ key = "stoneWall", i = -61, j = 5, rot = 1 },
	{ key = "stoneWall", i = -61, j = 7, rot = 1 },
	{ key = "stoneWall", i = -61, j = -3, rot = 1 },
	{ key = "stoneWall", i = -61, j = -5, rot = 1 },
	{ key = "stoneWall", i = -61, j = -7, rot = 1 },
	{ key = "stoneWall", i = -61, j = -9, rot = 1 },
	{ key = "tower", i = -62, j = 9, rot = 0 },
	{ key = "tower", i = -62, j = -11, rot = 0 },
}
-- The first choice (§12, 1:00): "Build a tower?" puts one here (the first free spot).
MapLayout.towerSpots = {
	{ key = "tower", i = -41, j = 9, rot = 0 },
	{ key = "tower", i = -41, j = -11, rot = 0 },
}

-- Ground and walking ------------------------------------------------------------------------------------------
local function rampAt(x, z)
	local dx, dz = x - HILL.center.X, z - HILL.center.Y
	for _, ramp in HILL.ramps do
		local along = dx * ramp.dir.X + dz * ramp.dir.Y
		local side = -dx * ramp.dir.Y + dz * ramp.dir.X
		if math.abs(side) <= HILL.rampWidth / 2 and along >= HILL.top - 2 and along <= HILL.foot then
			return ramp, along
		end
	end
	return nil
end

-- The height of the ground at (x, z).
function MapLayout.groundY(x, z)
	local dx, dz = x - HILL.center.X, z - HILL.center.Y
	local r = math.sqrt(dx * dx + dz * dz)
	if r <= HILL.top then
		return HILL.height
	end
	local ramp, along = rampAt(x, z)
	if ramp then
		return HILL.height * math.clamp((HILL.foot - along) / (HILL.foot - HILL.top), 0, 1)
	end
	return 0
end

-- Is (x, z) open ground an NPC can stand on (not inside a cliff, the canyon walls, the mountain or the spine)?
function MapLayout.walkable(x, z)
	local B = MapLayout.BOUNDS
	if x < B.minX + 4 or x > B.maxX - 4 or z < B.minZ + 4 or z > B.maxZ - 4 then
		return false
	end
	local az = math.abs(z)
	if x <= MapLayout.CANYON.minX then
		-- the valley: the ridges close in from RIDGE_Z (west of x = -130) to the canyon's width at its mouth
		local t = math.clamp((x + 130) / (MapLayout.CANYON.minX + 130), 0, 1)
		local limit = MapLayout.RIDGE_Z + (MapLayout.CANYON.halfWidth - MapLayout.RIDGE_Z) * t
		return az <= limit
	end
	if x <= MapLayout.CANYON.maxX - 4 then
		if az > MapLayout.CANYON.halfWidth - 2 then
			return false
		end
		local S = MapLayout.SPINE
		return not (x >= S.minX and x <= S.maxX and az <= S.halfWidth)
	end
	local C = MapLayout.CAVE
	local dx, dz = x - C.center.X, z - C.center.Y
	if dx * dx + dz * dz <= (C.radius - 2) ^ 2 then
		return true
	end
	for _, t in { C.mainTunnel, C.sideTunnel } do
		if x >= t.minX - 6 and x <= t.maxX + 2 and z >= t.minZ + 1 and z <= t.maxZ - 1 then
			return true
		end
	end
	return false
end

-- Which zone (1-3: the shrine that's next in line) a point is in, by its x.
function MapLayout.zoneOf(x)
	if x <= MapLayout.barriers[1].x then
		return 1
	elseif x <= MapLayout.barriers[2].x then
		return 2
	end
	return 3
end

-- Is this point inside a shrine's build zone?
function MapLayout.inZone(shrineIndex, x, z)
	local s = MapLayout.shrines[shrineIndex]
	if not s then
		return false
	end
	local zone = s.zone
	if zone.kind == "disc" then
		local dx, dz = x - zone.center.X, z - zone.center.Y
		return dx * dx + dz * dz <= zone.radius * zone.radius
	end
	return x >= zone.min.X and x <= zone.max.X and z >= zone.min.Y and z <= zone.max.Y
end

-- The shrine whose build zone holds (x, z), or nil.
function MapLayout.buildZoneAt(x, z)
	for i = 1, #MapLayout.shrines do
		if MapLayout.inZone(i, x, z) then
			return i
		end
	end
	return nil
end

-- Grid ----------------------------------------------------------------------------------------------------------
function MapLayout.cellOf(x, z)
	return math.floor(x / MapLayout.CELL), math.floor(z / MapLayout.CELL)
end

function MapLayout.cellCenter(i, j)
	return (i + 0.5) * MapLayout.CELL, (j + 0.5) * MapLayout.CELL
end

-- A piece's footprint: the world centre (x, z) and size (sx, sz) in studs of `w` x `d` cells from cell (i, j).
function MapLayout.footprint(i, j, w, d)
	local C = MapLayout.CELL
	return (i + w / 2) * C, (j + d / 2) * C, w * C, d * C
end

-- Distance from a point to a polyline (for the horde's leash).
function MapLayout.distToLane(points, x, z)
	local best = math.huge
	for k = 1, #points - 1 do
		local a, b = points[k], points[k + 1]
		local abx, abz = b.X - a.X, b.Y - a.Y
		local len2 = abx * abx + abz * abz
		local t = len2 > 0 and math.clamp(((x - a.X) * abx + (z - a.Y) * abz) / len2, 0, 1) or 0
		local px, pz = a.X + abx * t, a.Y + abz * t
		local d = math.sqrt((x - px) ^ 2 + (z - pz) ^ 2)
		if d < best then
			best = d
		end
	end
	return best
end

return MapLayout
