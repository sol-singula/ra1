--[[
The land of the first map as Roblox smooth terrain (master plan §6, §14), built once at start-up with
Terrain:WriteVoxels from one height function, so every slope matches the coordinates in MapLayout:

  the valley     grass and leafy grass with dirt patches, gentle rolls, trails worn along the monster lanes
  the creek      a channel of mud and sand with wading-deep water (the bridges are parts)
  the hill       a flat grassy top with a cobbled plaza round Shrine 1 and cobbled roads to four stone ramps,
                 steep rock cliffs all round, embankments beside the ramps
  the ridges     steep grassy slopes with rock faces, a rolling top (the hangout's plateau), snowy mountains behind
  the forest     dark leafy ground and mud round the monsters' rift
  the canyon     a sandy floor with sandstone slabs, sheer banded sandstone walls, the rock spine down the middle
  the mountain   a rock face with the two tunnel mouths, a snowy peak, and the cave of Shrine 3 hollowed out inside

Materials are Roblox's own (textured, with grass decoration), tinted by SetMaterialColor. NPCs walk on
MapLayout.groundY, which is the same height function, so they stay on the ground.

  TerrainBuilder.build()          writes the terrain (replacing any)
  TerrainBuilder.surfaceY(x, z)   the top of the land at (x, z) (ignoring the cave), for placing props on it
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapLayout = require(ReplicatedStorage.Shared.World.MapLayout)

local TerrainBuilder = {}

local M = Enum.Material
local V3 = Vector3.new
local noise = math.noise
local clamp = math.clamp
local abs = math.abs
local sqrt = math.sqrt
local HILL, CANYON, SPINE, CAVE, CREEK =
	MapLayout.HILL, MapLayout.CANYON, MapLayout.SPINE, MapLayout.CAVE, MapLayout.CREEK

-- The terrain's box (studs, on the 4-stud voxel grid): well past the map's walls, so the edges are out of sight.
TerrainBuilder.EXTENT = { minX = -720, maxX = 656, minZ = -384, maxZ = 384, minY = -24, maxY = 200 }
local E = TerrainBuilder.EXTENT
local CHUNK = 32 -- voxel columns per side of one WriteVoxels call

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
-- Roblox tints its terrain textures by these: bright, but not cartoon-flat
TerrainBuilder.COLORS = {
	Grass = rgb(98, 158, 58),
	LeafyGrass = rgb(80, 138, 52),
	Ground = rgb(132, 104, 74),
	Mud = rgb(94, 76, 60),
	Sand = rgb(220, 196, 146),
	Sandstone = rgb(204, 130, 84),
	Limestone = rgb(218, 176, 132),
	Rock = rgb(132, 127, 120),
	Slate = rgb(96, 96, 104),
	Basalt = rgb(74, 66, 94),
	Cobblestone = rgb(164, 158, 148),
	Pavement = rgb(178, 172, 162),
	Snow = rgb(240, 245, 252),
	Glacier = rgb(168, 218, 244),
}
TerrainBuilder.WATER = {
	WaterColor = rgb(40, 138, 168),
	WaterTransparency = 0.62,
	WaterReflectance = 0.45,
	WaterWaveSize = 0.08,
	WaterWaveSpeed = 8,
}

local function smooth(e0, e1, v)
	local t = clamp((v - e0) / (e1 - e0), 0, 1)
	return t * t * (3 - 2 * t)
end

-- Regions (what a column of land is part of)
local VALLEY, HILLTOP, RAMP, CLIFF, CREEKBED, FOREST, RIDGE = 1, 2, 3, 4, 5, 6, 7
local CANYONFLOOR, CANYONWALL, SPINEROCK, MOUNTAIN = 8, 9, 10, 11

-- Landforms ------------------------------------------------------------------------------------------------------
-- The valley's ridges and the canyon's walls: from the edge of the walkable ground, up a slope (long and grassy in
-- the valley, sheer in the canyon) to a rolling top, then the high mountains behind. Returns the height and how
-- far past the edge (x, z) is (-inf height inside the walkable ground).
local function sideWall(x, z)
	local limit = x <= CANYON.minX and MapLayout.valleyLimit(x) or CANYON.halfWidth
	local e = abs(z) - limit
	if e <= 0 then
		return -math.huge, e
	end
	local tc = clamp((x + 130) / (CANYON.minX + 130), 0, 1) -- 0: the valley's ridges, 1: the canyon's walls
	local slopeLen = (52 + noise(x / 70, z / 70, 4.2) * 16) * (1 - tc) + (6 + noise(x / 30, 1.5, z / 30) * 3) * tc
	local top = (MapLayout.RIDGE_TOP + noise(x / 90, z / 90, 7.7) * 10) * (1 - tc)
		+ (60 + noise(x / 60, z / 60, 2.6) * 6) * tc
	-- a slope that starts gently at the foot (a grassy apron) and steepens toward the top
	local t = clamp(e / slopeLen, 0, 1)
	local h = top * (t * t * (3 - 2 * t) * (0.45 + 0.4 * tc) + t * t * (0.55 - 0.4 * tc))
	-- spurs and gullies down the slope
	h += noise(x / 26, z / 26, 5.3) * 6 * t * (1 - t) * 4 * (1 - tc)
	local back = e - slopeLen - 12
	if back > 0 then
		h += math.min(back, 60) * 0.2 * (1 + noise(x / 50, z / 50, 9.1))
		local far = back - 40
		if far > 0 then
			-- the high mountains: rising and leveling off, with ridged peaks
			local peaks = (1 - abs(noise(x / 120, z / 120, 3.3))) ^ 2
			h += 92 * (1 - math.exp(-far / 70)) + peaks * 64 * clamp(far / 70, 0, 1)
		end
	end
	return h, e
end

-- The mountains past the forest (the west end).
local function westWall(x, z)
	local e = -612 - x
	if e <= 0 then
		return -math.huge
	end
	local slopeLen = 40 + noise(z / 60, x / 60, 6.1) * 10
	local h = (56 + noise(z / 80, 2.2, x / 80) * 10) * smooth(0, slopeLen, e)
	local back = e - slopeLen - 16
	if back > 0 then
		local peaks = (1 - abs(noise(x / 120, z / 120, 8.4))) ^ 2
		h += 96 * (1 - math.exp(-back / 60)) + peaks * 56 * clamp(back / 60, 0, 1)
	end
	return h
end

-- The mountain of Shrine 3: a sheer face over the canyon's end (the tunnels open in it), up to a snowy peak.
local function mountain(x, z)
	if x < 226 then
		return -math.huge
	end
	local face = smooth(228.5, 234, x)
	local d2 = (x - 452) ^ 2 + (z * 1.05) ^ 2
	local peak = 184 * math.exp(-d2 / (2 * 150 * 150))
	local base = 76 + noise(x / 40, z / 40, 5.5) * 8
	local m = math.max(base, peak)
	m += (1 - abs(noise(x / 55, z / 55, 6.6))) * 18 * smooth(70, 130, m)
	return m * face
end

-- The rock spine down the canyon's middle: a rounded slab of rock, SPINE.height tall.
local function spine(x, z)
	local cx = (SPINE.minX + SPINE.maxX) / 2
	local u, v = (x - cx) / ((SPINE.maxX - SPINE.minX) / 2 + 1), z / (SPINE.halfWidth + 0.5)
	local s = u ^ 4 + v ^ 4
	if s >= 1 then
		return 0
	end
	return (SPINE.height + noise(x / 9, z / 9, 4.4) * 3) * smooth(0, 0.55, 1 - s)
end

-- The hill under Shrine 1: the flat top and the ramps (MapLayout.floorY), cliffs all round, embankments beside
-- the ramps. nil off the hill.
local function hill(x, z)
	local dx, dz = x - HILL.center.X, z - HILL.center.Y
	local r = sqrt(dx * dx + dz * dz)
	if r > HILL.foot + 40 then
		return nil
	end
	if r <= HILL.top then
		return HILL.height, HILLTOP
	end
	if MapLayout.rampAt(x, z) then
		return MapLayout.floorY(x, z), RAMP
	end
	local h = 0
	local w = 3.4 + noise(x / 16, z / 16, 8.8) * 1.8
	if r < HILL.top + w then
		h = HILL.height * (1 - smooth(0, w, r - HILL.top))
	end
	local ramp, along, side = MapLayout.rampAt(x, z, 16)
	if ramp then
		local rh = HILL.height * clamp((HILL.foot - along) / (HILL.foot - HILL.top), 0, 1)
		local out = abs(side) - HILL.rampWidth / 2
		h = math.max(h, rh * (1 - smooth(0, 2 + rh * 1.3, out)))
	end
	if h > 0.05 then
		return h, CLIFF
	end
	return nil
end

-- A rocky bluff round each mine's mouth, so the timber doorway leads into the hillside (nothing in front of it).
local function mineBluff(x, z)
	local best = -math.huge
	for _, mine in MapLayout.mines do
		local behind = (z - mine.pos.Z) * -mine.facing -- studs into the hill from the doorway
		local dx = x - mine.pos.X
		if behind > -1 and abs(dx) < 40 then
			local d = sqrt(dx * dx + (behind - 12) ^ 2)
			local h = (30 + noise(x / 12, z / 12, 3.9) * 4) * smooth(0, 1, 1 - d / 34) * smooth(-1, 2, behind)
			if h > best then
				best = h
			end
		end
	end
	return best
end

-- The hangout's plateau on the north ridge: level with the deck.
local function plateau(x, z, h)
	local D = MapLayout.hangout.deck
	local dx = math.max(D.minX - 18 - x, x - D.maxX - 18, 0)
	local dz = math.max(D.minZ - 6 - z, z - D.maxZ - 34, 0)
	local m = 1 - smooth(0, 24, sqrt(dx * dx + dz * dz))
	if m <= 0 then
		return h
	end
	return h + (MapLayout.RIDGE_TOP - h) * m
end

-- The height of the land at (x, z) and the region it belongs to.
local function land(x, z)
	local h, region = 0, VALLEY
	if x < CANYON.minX then
		local hh, hr = hill(x, z)
		if hh then
			h, region = hh, hr
		else
			h = MapLayout.floorY(x, z)
			if abs(x - CREEK.x) < CREEK.width / 2 + 3 then
				region = CREEKBED
			elseif x < MapLayout.DWARF_BARRIER_X then
				region = FOREST
			end
		end
	else
		region = CANYONFLOOR
		local sp = spine(x, z)
		if sp > 0 then
			h, region = sp, SPINEROCK
		end
	end
	local w = sideWall(x, z)
	if w > h then
		h, region = w, x > CANYON.minX - 12 and CANYONWALL or RIDGE
	end
	local ww = westWall(x, z)
	if ww > h then
		h, region = ww, RIDGE
	end
	if abs(z) > 170 and x > -260 and x < -130 then
		local mb = mineBluff(x, z)
		if mb > h then
			h, region = mb, RIDGE
		end
	end
	local mt = mountain(x, z)
	if mt > h then
		h, region = mt, MOUNTAIN
	end
	if z > 200 and x > -300 and x < -100 then
		h = plateau(x, z, h)
	end
	if h > 170 then -- the highest peaks round off instead of being cut flat
		h = 170 + (h - 170) / (1 + (h - 170) / 16)
	end
	return h, region
end

function TerrainBuilder.surfaceY(x, z)
	return (land(x, z))
end

-- The cave and tunnels inside the mountain -------------------------------------------------------------------------
-- Signed distance (studs, + outside) to the air of the cave (a dome) and the two tunnels (arched).
local TUNNELS = { CAVE.mainTunnel, CAVE.sideTunnel }
local function hollow(x, y, z)
	local best = math.huge
	local dx, dz = x - CAVE.center.X, z - CAVE.center.Y
	local r = sqrt(dx * dx + dz * dz)
	if r < CAVE.radius + 24 then
		local s = (r / CAVE.radius) ^ 4 + (math.max(y, 0) / CAVE.ceiling) ^ 2
		best = (s ^ 0.25 - 1) * 60
	end
	for _, t in TUNNELS do
		if x >= t.minX - 14 and x <= t.maxX + 8 then
			local zc, hz = (t.minZ + t.maxZ) / 2, (t.maxZ - t.minZ) / 2
			local hy = t.height / 2
			local rr = math.min(hz, hy) * 0.75
			local qz = abs(z - zc) - (hz - rr)
			local qy = abs(y - hy) - (hy - rr)
			local d = sqrt(math.max(qz, 0) ^ 2 + math.max(qy, 0) ^ 2) + math.min(math.max(qz, qy), 0) - rr
			d = math.max(d, t.minX - 8 - x, x - t.maxX)
			if d < best then
				best = d
			end
		end
	end
	return best
end
local HOLLOW_BOX =
	{ minX = 210, maxX = CAVE.center.X + CAVE.radius + 8, minZ = -CAVE.radius - 8, maxZ = CAVE.radius + 8 }

-- Materials -------------------------------------------------------------------------------------------------------
local function laneDistance(x, z, zone)
	local best = math.huge
	for _, l in MapLayout.lanes[zone] do
		local d = MapLayout.distToLane(l.points, x, z)
		if d < best then
			best = d
		end
	end
	return best
end

-- A ragged trail: packed dirt along a lane.
local function trail(x, z, d)
	local edge = 3.6 + noise(x / 9, z / 9, 12.1) * 1.6
	return d < edge or (d < edge + 2.8 and noise(x / 4.5, z / 4.5, 3.7) > 0.15)
end

local function rocky(x, z)
	return noise(x / 14, z / 14, 7.3) > 0.15 and M.Slate or M.Rock
end

-- The material of the top of a column (and the one just under it).
local function surfaceMaterial(x, z, h, region, slope)
	if region == HILLTOP then
		local dx, dz = x - HILL.center.X, z - HILL.center.Y
		local r = sqrt(dx * dx + dz * dz)
		if r < 15 + noise(x / 6, z / 6, 3.3) * 2 then
			return M.Cobblestone, M.Rock -- the shrine's plaza
		end
		for _, ramp in HILL.ramps do
			local along = dx * ramp.dir.X + dz * ramp.dir.Y
			local side = abs(-dx * ramp.dir.Y + dz * ramp.dir.X)
			if along > 0 and side < 4.4 + noise(x / 7, z / 7, 1.4) * 1.4 then
				return M.Cobblestone, M.Rock -- the roads out to the ramps
			end
		end
		if (V3(x, 0, z) - V3(-166, 0, 36)).Magnitude < 14 + noise(x / 5, z / 5, 2.5) * 3 then
			return M.Ground, M.Ground -- worn round the camp's tent
		end
		local p = noise(x / 30, z / 30, 6.2) + noise(x / 9, z / 9, 7.1) * 0.3
		if p > 0.36 then
			return M.LeafyGrass, M.Ground
		elseif p < -0.5 then
			return M.Ground, M.Ground
		end
		return M.Grass, M.Ground
	elseif region == RAMP then
		return M.Cobblestone, M.Rock
	elseif region == CLIFF then
		if slope > 0.7 then
			return rocky(x, z), M.Rock
		end
		return M.Grass, M.Ground
	elseif region == CREEKBED then
		if h < -2.2 then
			return noise(x / 8, z / 8, 4.1) > 0.1 and M.Mud or M.Sand, M.Ground
		elseif h < -0.6 then
			return noise(x / 6, z / 6, 5.2) > -0.2 and M.Mud or M.Ground, M.Ground
		end
		return noise(x / 7, z / 7, 6.3) > 0.2 and M.Ground or M.Grass, M.Ground
	elseif region == VALLEY or region == FOREST then
		local lane = laneDistance(x, z, 1)
		if x > HILL.center.X then
			lane = math.min(lane, laneDistance(x, z, 2))
		end
		if trail(x, z, lane) then
			return M.Ground, M.Ground
		end
		if region == FOREST then
			local sp = (V3(x, 0, z) - MapLayout.FOREST_SPAWN).Magnitude
			if sp < 26 + noise(x / 6, z / 6, 9.4) * 4 then
				return sp < 12 and M.Basalt or M.Mud, M.Ground
			end
			local p = noise(x / 30, z / 30, 5.7) + noise(x / 9, z / 9, 6.8) * 0.3
			if p > 0.25 then
				return M.Mud, M.Ground
			elseif p < -0.3 then
				return M.Ground, M.Ground
			end
			return M.LeafyGrass, M.Ground
		end
		local p = noise(x / 48, z / 48, 1.1) + noise(x / 13, z / 13, 2.2) * 0.35
		if p > 0.36 then
			return M.LeafyGrass, M.Ground
		elseif p < -0.52 then
			return M.Ground, M.Ground
		end
		return M.Grass, M.Ground
	elseif region == CANYONFLOOR then
		if trail(x, z, math.min(laneDistance(x, z, 2), laneDistance(x, z, 3))) and x < MapLayout.CANYON.maxX then
			return M.Ground, M.Sand
		end
		local p = noise(x / 22, z / 22, 2.4) + noise(x / 7, z / 7, 1.2) * 0.25
		if p > 0.32 then
			return M.Sandstone, M.Sandstone
		end
		return M.Sand, M.Sand
	elseif region == CANYONWALL then
		if slope < 0.55 then
			return noise(x / 20, z / 20, 8.1) > 0 and M.Grass or M.Ground, M.Ground
		end
		return nil, nil -- the face: banded by height (see below)
	elseif region == SPINEROCK then
		if slope < 0.45 and h > SPINE.height - 2 then
			return M.Grass, M.Ground
		end
		return rocky(x, z), M.Rock
	end
	-- the ridges and the mountains
	local snow = 128 + noise(x / 60, z / 60, 9.9) * 14
	local crag = noise(x / 18, z / 18, 2.2) * 0.25
	if h > snow and slope < 1.5 then
		return M.Snow, M.Snow
	elseif slope > 1.2 + crag then
		return rocky(x, z), M.Rock
	elseif h > snow - 24 then
		return noise(x / 16, z / 16, 4.6) > 0.25 and M.Ground or M.Rock, M.Rock
	elseif slope > 0.85 + crag then
		return noise(x / 12, z / 12, 5.9) > 0.1 and M.Ground or M.LeafyGrass, M.Ground
	end
	return noise(x / 40, z / 40, 3.9) > 0.3 and M.LeafyGrass or M.Grass, M.Ground
end

-- What's deep under the surface (shows on cliffs, walls and in the cave).
local function deepMaterial(x, y, z, region, nearHollow)
	if region == CANYONWALL or region == CANYONFLOOR then
		-- wide, wandering bands of paler stone in the sandstone
		local v = (y + noise(x / 60, z / 60, 6.3) * 7 + 2400) % 26
		if v < 7 then
			return M.Limestone
		elseif v > 23.5 and noise(x / 30, y / 30, z / 30) > 0 then
			return M.Rock
		end
		return M.Sandstone
	elseif region == MOUNTAIN then
		local n = noise(x / 22, y / 14, z / 22)
		if nearHollow then
			return n > 0.25 and M.Slate or M.Basalt
		end
		return n > 0.1 and M.Slate or M.Rock
	end
	return M.Rock
end

-- The cave's and tunnels' floor.
local function caveFloor(x, z)
	local dx, dz = x - CAVE.center.X, z - CAVE.center.Y
	if dx * dx + dz * dz < (14 + noise(x / 5, z / 5, 3.1) * 2) ^ 2 then
		return M.Cobblestone
	end
	local mt = CAVE.mainTunnel
	if x < mt.maxX and z > mt.minZ + 2 and z < mt.maxZ - 2 then
		return M.Cobblestone -- the old dwarf road in the main tunnel
	end
	local p = noise(x / 18, z / 18, 2.7)
	return p > 0.3 and M.Ground or M.Slate
end

-- Building ----------------------------------------------------------------------------------------------------------
-- One WriteVoxels chunk: CHUNK x CHUNK columns from voxel column (gx, gz), as tall as the land in it.
local function writeChunk(terrain, gx, gz, nx, nz)
	local x0, z0 = E.minX + gx * 4, E.minZ + gz * 4
	-- heights with a one-column border (for slopes)
	local H, R = {}, {}
	local maxH = -math.huge
	for i = 0, nx + 1 do
		local hrow, rrow = table.create(nz + 2, 0), table.create(nz + 2, 0)
		H[i], R[i] = hrow, rrow
		for j = 0, nz + 1 do
			local h, region = land(x0 + (i - 1) * 4 + 2, z0 + (j - 1) * 4 + 2)
			hrow[j + 1], rrow[j + 1] = h, region
			if i >= 1 and i <= nx and j >= 1 and j <= nz and h > maxH then
				maxH = h
			end
		end
	end
	local ny = math.min(math.ceil((maxH - E.minY) / 4) + 1, (E.maxY - E.minY) / 4)
	local mats, occs = table.create(nx), table.create(nx)
	for i = 1, nx do
		local x = x0 + (i - 1) * 4 + 2
		local hrow, rrow, hl, hr = H[i], R[i], H[i - 1], H[i + 1]
		-- this row of columns: height, slope, materials, water, cave
		local cols = table.create(nz)
		for j = 1, nz do
			local z = z0 + (j - 1) * 4 + 2
			local h, region = hrow[j + 1], rrow[j + 1]
			local slope = math.max(abs(hr[j + 1] - hl[j + 1]), abs(hrow[j + 2] - hrow[j])) / 8
			local top, sub = surfaceMaterial(x, z, h, region, slope)
			local wet = region == CREEKBED and abs(z) < MapLayout.valleyLimit(x)
			local carve = region == MOUNTAIN
				and x >= HOLLOW_BOX.minX
				and x <= HOLLOW_BOX.maxX
				and z >= HOLLOW_BOX.minZ
				and z <= HOLLOW_BOX.maxZ
			cols[j] = { h = h, region = region, top = top, sub = sub, wet = wet, carve = carve, z = z }
		end
		local mx, ox = table.create(ny), table.create(ny)
		mats[i], occs[i] = mx, ox
		for k = 1, ny do
			local y0 = E.minY + (k - 1) * 4
			local yc = y0 + 2
			local my, oy = table.create(nz), table.create(nz)
			mx[k], ox[k] = my, oy
			for j = 1, nz do
				local c = cols[j]
				local h = c.h
				local occ = clamp((h - y0) / 4, 0, 1)
				local mat = M.Air
				local nearHollow = false
				if c.carve and occ > 0 then
					local d = hollow(x, yc, c.z)
					nearHollow = d < 10
					local floor = clamp(-y0 / 4, 0, 1)
					occ = math.min(occ, math.max(clamp(0.5 + d / 4, 0, 1), floor))
					if nearHollow and y0 == -4 and d < 4 then
						mat = caveFloor(x, c.z)
					end
				end
				if occ > 0 then
					if mat == M.Air then
						local depth = h - yc
						if depth < 2.5 and c.top then
							mat = c.top
						elseif depth < 7 and c.sub and not nearHollow then
							mat = c.sub
						else
							mat = deepMaterial(x, yc, c.z, c.region, nearHollow)
						end
					end
				else
					occ = 0
				end
				if c.wet and occ < 0.5 and y0 < CREEK.water then
					mat, occ = M.Water, clamp((CREEK.water - y0) / 4, 0, 1)
				end
				my[j], oy[j] = mat, occ
			end
		end
	end
	local lo = V3(x0, E.minY, z0)
	terrain:WriteVoxels(Region3.new(lo, lo + V3(nx * 4, ny * 4, nz * 4)), 4, mats, occs)
end

function TerrainBuilder.build()
	local terrain = workspace:FindFirstChildOfClass("Terrain") or workspace.Terrain
	terrain:Clear()
	for name, color in TerrainBuilder.COLORS do
		terrain:SetMaterialColor(M[name], color)
	end
	for prop, v in TerrainBuilder.WATER do
		pcall(function()
			terrain[prop] = v
		end)
	end
	pcall(function()
		terrain.Decoration = true -- Roblox's swaying grass blades on the Grass material
	end)
	local cols, rows = (E.maxX - E.minX) / 4, (E.maxZ - E.minZ) / 4
	for gx = 0, cols - 1, CHUNK do
		for gz = 0, rows - 1, CHUNK do
			writeChunk(terrain, gx, gz, math.min(CHUNK, cols - gx), math.min(CHUNK, rows - gz))
		end
	end
	-- a sky of slow white clouds
	local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.52
	clouds.Density = 0.62
	clouds.Color = rgb(255, 255, 255)
	clouds.Parent = terrain
	return terrain
end

return TerrainBuilder
