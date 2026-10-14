--[[
Where everything is (the map is mostly forest, besides the camp and the random findings). One height function for
the land (floorY) is shared by the terrain writer (TerrainBuilder), the monsters (groundY) and the tests, so every
monster walks on the ground you see.

  the camp        a flat clearing at the centre: the fire, the stations, the wall ring with four gates, the
                  Ancient Pines round its edge (the night 7 arena)
  the forest      rolling ground out to WORLD_RADIUS: inner (near camp), middle and deep (the best loot, the
                  worst monsters), thousands of trees, ferns, logs and rocks
  trails          four dirt trails from the gates out into the forest, joined by a ring trail: readable paths at
                  night (§11)
  the creek       wading-deep, crossed by log bridges where the trails meet it; the Still Pond
  outcrops        rocky hills that stick out above the trees (landmarks)
  sites           clearings where each run scatters its findings (Data/Findings, WorldService)
  the boundary    the land rises into steep wooded hills; invisible walls keep everyone in

Coordinates: studs, the camp fire at (0, 0, 0), -Z is north.
]]
local MapLayout = {}

local noise = math.noise
local sqrt = math.sqrt
local clamp = math.clamp
local abs = math.abs
local V3 = Vector3.new

local function smooth(e0, e1, v)
	local t = clamp((v - e0) / (e1 - e0), 0, 1)
	return t * t * (3 - 2 * t)
end
MapLayout.smooth = smooth

MapLayout.WORLD_RADIUS = 505 -- the walkable forest
MapLayout.WALL_RADIUS = 512 -- the invisible walls
MapLayout.EDGE_RADIUS = 600 -- the terrain ends here
MapLayout.ZONES = { inner = 200, middle = 340 } -- deep beyond

MapLayout.CAMP = {
	center = V3(0, 0, 0),
	y = 0,
	radius = 46, -- the camp proper (the wall ring is at Constants.WALL_RADIUS)
	flat = 54, -- the ground is level out to here
	clear = 78, -- no trees closer than this (but the Ancient Pines)
	wallRadius = 36,
	gateWidth = 10,
}

-- The creek: water level and bed (wading deep, like ra7's creek: the character never has to swim)
MapLayout.CREEK = { width = 14, bed = -4.2, water = -2, wade = -3.1 }
MapLayout.POND = { x = 185, z = 235, radius = 30, bed = -5, water = -2 }

-- Rocky hills that stand out of the trees.
MapLayout.OUTCROPS = {
	{ x = -262, z = 205, r = 40, h = 16 },
	{ x = 305, z = -300, r = 46, h = 20 },
	{ x = -385, z = -310, r = 36, h = 14 },
	{ x = 70, z = 405, r = 34, h = 12 },
	{ x = 425, z = 110, r = 40, h = 18 },
	{ x = -150, z = -360, r = 30, h = 11 },
}

-- Trails --------------------------------------------------------------------------------------------------------
-- Polylines (points every ~8 studs). Four radial trails from the gates, and a ring trail joining them.
local GATE_ANGLES = { 0, 90, 180, 270 } -- degrees: east (+X), south (+Z), west (-X), north (-Z)
MapLayout.GATE_ANGLES = GATE_ANGLES

local function radialTrail(angleDeg, seed)
	local pts = {}
	local a0 = math.rad(angleDeg)
	for r = MapLayout.CAMP.wallRadius - 2, 440, 8 do
		local wobble = noise(r / 120, seed, 0.5) * 0.55 * smooth(50, 140, r)
		local a = a0 + wobble * (60 / math.max(r, 60))
		table.insert(pts, V3(math.cos(a) * r, 0, math.sin(a) * r))
	end
	return pts
end

local function ringTrail(radius)
	local pts = {}
	local n = math.floor(2 * math.pi * radius / 8)
	for i = 0, n do
		local a = i / n * math.pi * 2
		local r = radius + noise(math.cos(a) * 2, math.sin(a) * 2, 7.3) * 26
		table.insert(pts, V3(math.cos(a) * r, 0, math.sin(a) * r))
	end
	return pts
end

MapLayout.trails = {}
for i, ang in GATE_ANGLES do
	table.insert(MapLayout.trails, { key = "radial" .. i, angle = ang, points = radialTrail(ang, i * 3.7) })
end
table.insert(MapLayout.trails, { key = "ring", points = ringTrail(245) })
MapLayout.TRAIL_HALF = 3.4

-- The creek's course: a meander across the north of the map.
local CREEK_CONTROL = {
	V3(-600, 0, -150),
	V3(-430, 0, -175),
	V3(-300, 0, -140),
	V3(-180, 0, -160),
	V3(-70, 0, -205),
	V3(40, 0, -170),
	V3(150, 0, -130),
	V3(260, 0, -175),
	V3(370, 0, -230),
	V3(470, 0, -250),
	V3(600, 0, -240),
}
local function catmull(p0, p1, p2, p3, t)
	local t2, t3 = t * t, t * t * t
	return (p1 * 2 + (p2 - p0) * t + (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t2 + (p1 * 3 - p0 - p2 * 3 + p3) * t3) * 0.5
end
MapLayout.creek = {}
for i = 1, #CREEK_CONTROL - 1 do
	local p0 = CREEK_CONTROL[math.max(1, i - 1)]
	local p1, p2 = CREEK_CONTROL[i], CREEK_CONTROL[i + 1]
	local p3 = CREEK_CONTROL[math.min(#CREEK_CONTROL, i + 2)]
	local steps = math.ceil((p2 - p1).Magnitude / 8)
	for s = 0, steps - 1 do
		table.insert(MapLayout.creek, catmull(p0, p1, p2, p3, s / steps))
	end
end
table.insert(MapLayout.creek, CREEK_CONTROL[#CREEK_CONTROL])

-- Distance helpers ---------------------------------------------------------------------------------------------
-- A coarse grid of polyline segments so distance lookups stay cheap (the terrain asks for every column).
local SEG_CELL = 32
local function segmentGrid(polylines)
	local grid = {}
	for _, pts in polylines do
		for k = 1, #pts - 1 do
			local a, b = pts[k], pts[k + 1]
			local seg = { ax = a.X, az = a.Z, bx = b.X, bz = b.Z }
			local minX, maxX = math.min(a.X, b.X), math.max(a.X, b.X)
			local minZ, maxZ = math.min(a.Z, b.Z), math.max(a.Z, b.Z)
			for cx = math.floor(minX / SEG_CELL) - 1, math.floor(maxX / SEG_CELL) + 1 do
				for cz = math.floor(minZ / SEG_CELL) - 1, math.floor(maxZ / SEG_CELL) + 1 do
					local key = cx * 100000 + cz
					grid[key] = grid[key] or {}
					table.insert(grid[key], seg)
				end
			end
		end
	end
	return grid
end

local function segDist(px, pz, s)
	local dx, dz = s.bx - s.ax, s.bz - s.az
	local len2 = dx * dx + dz * dz
	local t = len2 > 0 and clamp(((px - s.ax) * dx + (pz - s.az) * dz) / len2, 0, 1) or 0
	local qx, qz = s.ax + dx * t - px, s.az + dz * t - pz
	return sqrt(qx * qx + qz * qz)
end

-- Distance from (x, z) to the nearest segment in the grid (math.huge beyond ~2 cells).
local function nearest(grid, x, z)
	local cx, cz = math.floor(x / SEG_CELL), math.floor(z / SEG_CELL)
	local best = math.huge
	local list = grid[cx * 100000 + cz]
	if list then
		for _, s in list do
			local d = segDist(x, z, s)
			if d < best then
				best = d
			end
		end
	end
	return best
end

local trailPolys = {}
for _, t in MapLayout.trails do
	table.insert(trailPolys, t.points)
end
local trailGrid = segmentGrid(trailPolys)
local creekGrid = segmentGrid({ MapLayout.creek })

function MapLayout.trailDistance(x, z)
	return nearest(trailGrid, x, z)
end

function MapLayout.creekDistance(x, z)
	return nearest(creekGrid, x, z)
end

function MapLayout.radius(x, z)
	return sqrt(x * x + z * z)
end

function MapLayout.zoneAt(x, z)
	local r = sqrt(x * x + z * z)
	if r < MapLayout.CAMP.radius + 4 then
		return "camp"
	elseif r < MapLayout.ZONES.inner then
		return "inner"
	elseif r < MapLayout.ZONES.middle then
		return "middle"
	end
	return "deep"
end

-- Bridges: where a trail crosses the creek, a log bridge (decks are above the water, ramps onto the banks).
MapLayout.bridges = {}
do
	for _, t in MapLayout.trails do
		local pts = t.points
		for k = 1, #pts - 1 do
			-- the point along this segment closest to the creek's centre line
			local mid, best = nil, math.huge
			for f = 0, 1, 0.125 do
				local q = pts[k]:Lerp(pts[k + 1], f)
				local d = MapLayout.creekDistance(q.X, q.Z)
				if d < best then
					mid, best = q, d
				end
			end
			if best < 1.5 then
				local dir = (pts[k + 1] - pts[k]).Unit
				local dup = false
				for _, b in MapLayout.bridges do
					if (V3(b.x, 0, b.z) - mid).Magnitude < 30 then
						dup = true
					end
				end
				if not dup then
					table.insert(MapLayout.bridges, {
						x = mid.X,
						z = mid.Z,
						dir = dir,
						halfLen = 15,
						halfWidth = 3.5,
						y = 0.9,
					})
				end
			end
		end
	end
end

-- The land ---------------------------------------------------------------------------------------------------------
local function baseHeight(x, z)
	return noise(x / 150, z / 150, 0.37) * 7 + noise(x / 60, z / 60, 1.91) * 2.4 + noise(x / 23, z / 23, 4.4) * 0.7
end
MapLayout.baseHeight = baseHeight

-- The findings' clearings (filled in below; floorY flattens the ground round each one).
MapLayout.sites = {}
local siteGrid = {} -- [cell] = { site, ... } (cell 64)

local function outcropHeight(x, z)
	local best = 0
	for _, o in MapLayout.OUTCROPS do
		local dx, dz = x - o.x, z - o.z
		local d = sqrt(dx * dx + dz * dz)
		local rr = o.r * (1 + 0.25 * noise(dx / 18 + o.x, dz / 18, 3.3))
		if d < rr then
			-- a rounded top with steeper rocky sides
			local t = 1 - d / rr
			local h = o.h * (t ^ 0.55) * (0.85 + 0.25 * noise(x / 9, z / 9, 8.1))
			if h > best then
				best = h
			end
		end
	end
	return best
end
MapLayout.outcropHeight = outcropHeight

-- The ground at (x, z): the base roll, flattened at the camp and the sites, carved by the creek and the pond, raised
-- by the outcrops and the boundary hills.
function MapLayout.floorY(x, z)
	local r = sqrt(x * x + z * z)
	local h = baseHeight(x, z)
	-- the camp clearing: level, then easing back into the roll
	local camp = MapLayout.CAMP
	if r < camp.clear + 20 then
		h = MapLayout.CAMP.y + (h - camp.y) * smooth(camp.flat, camp.flat + 26, r) * 0.7
	end
	-- the sites
	local cell = math.floor(x / 64) * 1000 + math.floor(z / 64)
	local near = siteGrid[cell]
	if near then
		for _, s in near do
			local dx, dz = x - s.x, z - s.z
			local d = sqrt(dx * dx + dz * dz)
			if d < s.radius + 14 then
				h = s.y + (h - s.y) * smooth(s.radius, s.radius + 14, d)
			end
		end
	end
	-- outcrops
	h += outcropHeight(x, z)
	-- the creek: pull the land down toward it, then the channel
	local cd = MapLayout.creekDistance(x, z)
	local C = MapLayout.CREEK
	if cd < 46 then
		local pull = smooth(46, 12, cd)
		h = h + (math.min(h, 0.6) - h) * pull
		if cd < C.width / 2 + 6 then
			local bank = smooth(C.width / 2 - 1, C.width / 2 + 6, cd)
			h = C.bed + noise(x / 7, z / 7, 2.2) * 0.4 + (h - C.bed) * bank
		end
	end
	-- the pond
	local P = MapLayout.POND
	local pdx, pdz = x - P.x, z - P.z
	local pd = sqrt(pdx * pdx + pdz * pdz)
	if pd < P.radius + 30 then
		h = h + (math.min(h, 0.5) - h) * smooth(P.radius + 30, P.radius + 4, pd)
		if pd < P.radius + 6 then
			h = P.bed + (h - P.bed) * smooth(P.radius - 8, P.radius + 6, pd)
		end
	end
	-- the boundary: steep wooded hills
	if r > MapLayout.WORLD_RADIUS - 5 then
		-- wooded hills that rise steeply, then roll off (seen from the forest they read as more forest)
		local e = r - (MapLayout.WORLD_RADIUS - 5)
		h += 46 * smooth(0, 70, e) + noise(x / 40, z / 40, 6.6) * 7 * smooth(0, 40, e)
	end
	return h
end

-- Where monsters walk: the land, or a bridge's deck, and never under the creek's wading depth.
function MapLayout.groundY(x, z)
	for _, b in MapLayout.bridges do
		local dx, dz = x - b.x, z - b.z
		local along = dx * b.dir.X + dz * b.dir.Z
		local side = -dx * b.dir.Z + dz * b.dir.X
		if abs(along) <= b.halfLen and abs(side) <= b.halfWidth then
			return b.y
		end
	end
	local h = MapLayout.floorY(x, z)
	if MapLayout.creekDistance(x, z) < MapLayout.CREEK.width / 2 + 2 then
		return math.max(h, MapLayout.CREEK.wade)
	end
	local P = MapLayout.POND
	if (x - P.x) ^ 2 + (z - P.z) ^ 2 < (P.radius + 2) ^ 2 then
		return math.max(h, MapLayout.CREEK.wade)
	end
	return h
end

-- Inside the walkable forest (monsters and spawns stay here).
function MapLayout.walkable(x, z)
	local r = sqrt(x * x + z * z)
	if r > MapLayout.WORLD_RADIUS - 6 then
		return false
	end
	local P = MapLayout.POND
	if (x - P.x) ^ 2 + (z - P.z) ^ 2 < (P.radius - 6) ^ 2 then
		return false -- the deep middle of the pond
	end
	for _, o in MapLayout.OUTCROPS do
		if (x - o.x) ^ 2 + (z - o.z) ^ 2 < (o.r * 0.55) ^ 2 then
			return false -- the rocky tops are for looking from, not for monsters
		end
	end
	return true
end

-- Sites (deterministic, so the server, the tests and the render tools agree) ----------------------------------
do
	local rng = Random.new(6767)
	local camp = MapLayout.CAMP
	local tries = 0
	while tries < 6000 and #MapLayout.sites < 46 do
		tries += 1
		local a = rng:NextNumber(0, math.pi * 2)
		local r = sqrt(rng:NextNumber(125 ^ 2, 470 ^ 2))
		local x, z = math.cos(a) * r, math.sin(a) * r
		local ok = r > camp.clear + 40
		ok = ok and MapLayout.trailDistance(x, z) > 22
		ok = ok and MapLayout.creekDistance(x, z) > MapLayout.CREEK.width / 2 + 30
		local P = MapLayout.POND
		ok = ok and (x - P.x) ^ 2 + (z - P.z) ^ 2 > (P.radius + 34) ^ 2
		if ok then
			for _, o in MapLayout.OUTCROPS do
				if (x - o.x) ^ 2 + (z - o.z) ^ 2 < (o.r + 26) ^ 2 then
					ok = false
					break
				end
			end
		end
		if ok then
			for _, s in MapLayout.sites do
				if (x - s.x) ^ 2 + (z - s.z) ^ 2 < 82 ^ 2 then
					ok = false
					break
				end
			end
		end
		if ok then
			local site = { id = #MapLayout.sites + 1, x = x, z = z, radius = 24, zone = MapLayout.zoneAt(x, z) }
			site.y = baseHeight(x, z) + outcropHeight(x, z)
			table.insert(MapLayout.sites, site)
			for cx = math.floor((x - 40) / 64), math.floor((x + 40) / 64) do
				for cz = math.floor((z - 40) / 64), math.floor((z + 40) / 64) do
					local key = cx * 1000 + cz
					siteGrid[key] = siteGrid[key] or {}
					table.insert(siteGrid[key], site)
				end
			end
		end
	end
end

-- The camp's slots: where every structure stands (Data/Camp). `a` is the angle in degrees (0 = east, 90 = south).
local function polar(aDeg, r, y)
	local a = math.rad(aDeg)
	return V3(math.cos(a) * r, y or 0, math.sin(a) * r)
end
MapLayout.polar = polar

local function facingCenter(pos)
	-- a CFrame at pos looking at the fire
	return CFrame.lookAt(pos, V3(0, pos.Y, 0))
end

MapLayout.campSlots = {}
local function slot(key, index, pos, cf, extra)
	local s = { key = key, index = index, pos = pos, cf = cf or facingCenter(pos) }
	for k, v in extra or {} do
		s[k] = v
	end
	table.insert(MapLayout.campSlots, s)
	return s
end
do
	slot("workbench", 1, polar(45, 17))
	slot("storage", 1, polar(135, 17))
	slot("anvil", 1, polar(225, 17))
	slot("cookpot", 1, polar(315, 17))
	slot("repair", 1, polar(112, 25))
	slot("totem", 1, polar(200, 9))
	for i, a in { 45, 225 } do
		slot("platform", i, polar(a, 29))
		slot("catapult", i, polar(a, 29, 8.5))
	end
	for i, a in GATE_ANGLES do
		slot("lamppost", i, polar(a + 14, 29))
	end
	-- the wall ring: a gate at each trail, four wall segments between each pair of gates
	local R = MapLayout.CAMP.wallRadius
	local gateHalf = math.deg(MapLayout.CAMP.gateWidth / 2 / R)
	local w = 0
	for gi, a in GATE_ANGLES do
		local pos = polar(a, R)
		slot("gate", gi, pos, CFrame.lookAt(pos, V3(0, 0, 0)), { angle = a, width = MapLayout.CAMP.gateWidth })
		local from, to = a + gateHalf, a + 90 - gateHalf
		for k = 0, 3 do
			local a0 = from + (to - from) * k / 4
			local a1 = from + (to - from) * (k + 1) / 4
			local am = (a0 + a1) / 2
			local p0, p1 = polar(a0, R), polar(a1, R)
			w += 1
			local mid = polar(am, R)
			slot(
				"wall",
				w,
				mid,
				CFrame.lookAt(mid, V3(0, 0, 0)),
				{ angle = am, width = (p1 - p0).Magnitude + 0.6, a0 = a0, a1 = a1 }
			)
		end
	end
	-- spike traps outside the walls, in front of the gates and between them
	for i, a in { 0, 90, 180, 270, 135, 315 } do
		slot("spikes", i, polar(a, R + 7))
	end
end
MapLayout.slotsByKey = {}
for _, s in MapLayout.campSlots do
	MapLayout.slotsByKey[s.key] = MapLayout.slotsByKey[s.key] or {}
	MapLayout.slotsByKey[s.key][s.index] = s
end

-- Fixed camp props (always there): the fire, the Camp Board, the bell, the difficulty stones, tents.
MapLayout.CAMP_PROPS = {
	fire = V3(0, 0, 0),
	board = polar(18, 11),
	bell = polar(162, 11),
	stones = { polar(318, 25), polar(326, 25.5), polar(334, 26), polar(342, 26.5) },
	tents = { { pos = polar(70, 25), a = 70 }, { pos = polar(160, 26), a = 160 }, { pos = polar(292, 25), a = 292 } },
	logs = { polar(0, 7.5), polar(120, 7.5), polar(240, 7.5) }, -- seats round the fire
}

-- The Ancient Pines round the clearing (Mega Kermy charges into them on night 7).
MapLayout.ancientPines = {}
for k = 0, 7 do
	local a = 22.5 + k * 45
	local p = polar(a, 66)
	p = V3(p.X, MapLayout.floorY(p.X, p.Z), p.Z)
	table.insert(MapLayout.ancientPines, { id = k + 1, pos = p, radius = 4 })
end

-- Where survivors appear: round the fire.
function MapLayout.spawnPoint(i)
	local a = (i or 1) * 2.399
	local r = 9 + ((i or 1) % 3) * 1.5
	return V3(math.cos(a) * r, MapLayout.CAMP.y + 3, math.sin(a) * r)
end

-- Trees, rocks and plants (deterministic; built lazily: the server, the tests and the render tools ask) --------
local trees, nodes
local function treeKind(rng, zone)
	local roll = rng:NextNumber()
	if zone == "inner" then
		return roll < 0.4 and "pine" or roll < 0.55 and "spruce" or roll < 0.8 and "oak" or "birch"
	elseif zone == "middle" then
		return roll < 0.45 and "pine"
			or roll < 0.7 and "spruce"
			or roll < 0.85 and "oak"
			or roll < 0.95 and "birch"
			or "dead"
	end
	return roll < 0.3 and "pine" or roll < 0.7 and "spruce" or roll < 0.8 and "giant" or roll < 0.92 and "dead" or "oak"
end

MapLayout.TREE_KINDS = {
	pine = { h = { 22, 34 }, trunk = 0.08, hp = 40, wood = 6 },
	spruce = { h = { 28, 44 }, trunk = 0.065, hp = 45, wood = 7 },
	oak = { h = { 16, 24 }, trunk = 0.12, hp = 50, wood = 8 },
	birch = { h = { 18, 26 }, trunk = 0.055, hp = 30, wood = 5 },
	dead = { h = { 10, 16 }, trunk = 0.1, hp = 20, wood = 3 },
	giant = { h = { 52, 70 }, trunk = 0.1, hp = math.huge, wood = 0 },
	sapling = { h = { 10, 13 }, trunk = 0.09, hp = 20, wood = 4 }, -- two hits of the Rusty Axe
}

-- Young trees right at the camp (master plan §4: the first chop is seconds away, not a walk through the clearing):
-- between the props and the wall ring, clear of every slot, tent, stone and trail. { degrees, studs from the fire }
MapLayout.SAPLINGS = { { 30, 22 }, { 125, 31 }, { 148, 30 }, { 210, 22 }, { 250, 22 } }

-- Keep-clear test for trees and props: the camp, the sites, the trails, the water, the outcrop tops.
function MapLayout.clearOf(x, z, pad)
	pad = pad or 0
	local r = sqrt(x * x + z * z)
	if r < MapLayout.CAMP.clear + pad then
		return false
	end
	if MapLayout.trailDistance(x, z) < MapLayout.TRAIL_HALF + 2 + pad then
		return false
	end
	if MapLayout.creekDistance(x, z) < MapLayout.CREEK.width / 2 + 3 + pad then
		return false
	end
	local P = MapLayout.POND
	if (x - P.x) ^ 2 + (z - P.z) ^ 2 < (P.radius + 6 + pad) ^ 2 then
		return false
	end
	for _, s in MapLayout.sites do
		if (x - s.x) ^ 2 + (z - s.z) ^ 2 < (s.radius + 5 + pad) ^ 2 then
			return false
		end
	end
	for _, o in MapLayout.OUTCROPS do
		if (x - o.x) ^ 2 + (z - o.z) ^ 2 < (o.r * 0.45) ^ 2 then
			return false
		end
	end
	return true
end

-- Every tree: { id, x, y, z, kind, h, trunk (radius), seed }. Poisson-disc spacing, thinned by a density noise so
-- the forest has thick stands and little glades.
function MapLayout.trees()
	if trees then
		return trees
	end
	trees = {}
	local rng = Random.new(67)
	local minD = 11
	local cell = minD / sqrt(2)
	local R = MapLayout.EDGE_RADIUS - 14
	local n = math.ceil(2 * R / cell)
	local grid = {}
	local function key(x, z)
		return math.floor((x + R) / cell) * 10000 + math.floor((z + R) / cell)
	end
	local active, points = {}, {}
	local function add(x, z)
		local p = { x = x, z = z }
		table.insert(points, p)
		table.insert(active, p)
		grid[key(x, z)] = p
	end
	add(90, 0)
	while #active > 0 do
		local idx = rng:NextInteger(1, #active)
		local p = active[idx]
		local placed = false
		for _ = 1, 18 do
			local a = rng:NextNumber(0, math.pi * 2)
			local d = rng:NextNumber(minD, minD * 2)
			local x, z = p.x + math.cos(a) * d, p.z + math.sin(a) * d
			if x * x + z * z < R * R then
				local gx, gz = math.floor((x + R) / cell), math.floor((z + R) / cell)
				local ok = gx >= 0 and gz >= 0 and gx < n and gz < n
				if ok then
					for ix = gx - 2, gx + 2 do
						for iz = gz - 2, gz + 2 do
							local q = grid[ix * 10000 + iz]
							if q and (q.x - x) ^ 2 + (q.z - z) ^ 2 < minD * minD then
								ok = false
								break
							end
						end
						if not ok then
							break
						end
					end
				end
				if ok then
					add(x, z)
					placed = true
					break
				end
			end
		end
		if not placed then
			active[idx] = active[#active]
			active[#active] = nil
		end
	end
	local id = 0
	for _, p in points do
		local x, z = p.x, p.z
		local r = sqrt(x * x + z * z)
		local zone = MapLayout.zoneAt(x, z)
		local density = 0.66 + 0.3 * noise(x / 110, z / 110, 9.9) + (zone == "deep" and 0.12 or 0)
		if r > MapLayout.WORLD_RADIUS then
			density = 0.8 -- the boundary hills: thick forest, so the edge of the world looks like more woods
		end
		if rng:NextNumber() < density and MapLayout.clearOf(x, z) then
			local kind = r > MapLayout.WORLD_RADIUS and (rng:NextNumber() < 0.6 and "spruce" or "pine")
				or treeKind(rng, zone)
			local spec = MapLayout.TREE_KINDS[kind]
			local h = rng:NextNumber(spec.h[1], spec.h[2])
			id += 1
			table.insert(trees, {
				id = id,
				x = x,
				z = z,
				y = MapLayout.floorY(x, z),
				kind = kind,
				h = h,
				trunk = h * spec.trunk / 2,
				seed = rng:NextInteger(1, 1e6),
				reachable = r < MapLayout.WORLD_RADIUS - 4,
			})
		end
	end
	for k, sp in MapLayout.SAPLINGS do
		local p = polar(sp[1], sp[2])
		local spec = MapLayout.TREE_KINDS.sapling
		id += 1
		table.insert(trees, {
			id = id,
			x = p.X,
			z = p.Z,
			y = MapLayout.floorY(p.X, p.Z),
			kind = "sapling",
			h = spec.h[1] + (spec.h[2] - spec.h[1]) * ((k * 7) % 5) / 4,
			trunk = 0,
			seed = 6700 + k,
			reachable = true,
			sapling = true,
		})
		local t = trees[#trees]
		t.trunk = t.h * spec.trunk / 2
	end
	return trees
end

-- Resource nodes that don't move between runs: rocks, fiber plants, berry bushes, herbs, glowcaps, scrap heaps.
--   { id, kind, x, y, z, size }
MapLayout.NODE_COUNTS = { rock = 160, fiber = 140, berry = 90, herb = 40, glowcap = 26, scrap = 22 }
function MapLayout.nodes()
	if nodes then
		return nodes
	end
	nodes = {}
	local rng = Random.new(76)
	local treeList = MapLayout.trees()
	-- a coarse tree grid to keep nodes off trunks
	local tg = {}
	for _, t in treeList do
		local k = math.floor(t.x / 16) * 1000 + math.floor(t.z / 16)
		tg[k] = tg[k] or {}
		table.insert(tg[k], t)
	end
	local function nearTree(x, z, pad)
		for cx = math.floor(x / 16) - 1, math.floor(x / 16) + 1 do
			for cz = math.floor(z / 16) - 1, math.floor(z / 16) + 1 do
				for _, t in tg[cx * 1000 + cz] or {} do
					if (t.x - x) ^ 2 + (t.z - z) ^ 2 < (t.trunk + pad) ^ 2 then
						return true
					end
				end
			end
		end
		return false
	end
	local id = 0
	for kind, count in MapLayout.NODE_COUNTS do
		local made, tries = 0, 0
		while made < count and tries < count * 60 do
			tries += 1
			local a = rng:NextNumber(0, math.pi * 2)
			local minR = (kind == "herb" or kind == "glowcap") and 200 or (MapLayout.CAMP.clear + 4)
			if kind == "glowcap" then
				minR = 330
			end
			local r = sqrt(rng:NextNumber(minR ^ 2, (MapLayout.WORLD_RADIUS - 12) ^ 2))
			local x, z = math.cos(a) * r, math.sin(a) * r
			-- rocks gather round the outcrops
			if kind == "rock" and rng:NextNumber() < 0.35 then
				local o = MapLayout.OUTCROPS[rng:NextInteger(1, #MapLayout.OUTCROPS)]
				local oa = rng:NextNumber(0, math.pi * 2)
				local od = o.r * rng:NextNumber(0.9, 1.4)
				x, z = o.x + math.cos(oa) * od, o.z + math.sin(oa) * od
			end
			if MapLayout.clearOf(x, z, 1) and MapLayout.walkable(x, z) and not nearTree(x, z, 4) then
				id += 1
				made += 1
				table.insert(nodes, {
					id = id,
					kind = kind,
					x = x,
					z = z,
					y = MapLayout.floorY(x, z),
					size = kind == "rock" and rng:NextNumber(3.2, 6) or rng:NextNumber(0.8, 1.2),
					seed = rng:NextInteger(1, 1e6),
				})
			end
		end
	end
	return nodes
end

return MapLayout
