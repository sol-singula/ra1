--[[
The forest's land as Roblox smooth terrain (master plan §11), built once at start-up with Terrain:WriteVoxels from
MapLayout.floorY, so every slope matches what the monsters walk on (MapLayout.groundY):

  the forest floor   grass and leafy grass with dark ground under the thick stands, mud by the water, moss-green
                     slopes; Roblox's grass blades on the grass
  the camp           a trodden dirt clearing round the fire, grass at its edge
  trails             dirt trails from the gates and the ring trail (readable at night: §11)
  the creek, pond    sand and mud beds with wading-deep water
  outcrops           rock hills with mossy tops
  the boundary       steep wooded hills, rock where it's steep

  TerrainBuilder.build()          writes the terrain (replacing any)
  TerrainBuilder.surfaceY(x, z)   the top of the land at (x, z)
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

-- The terrain's box (studs, on the 4-stud voxel grid)
local R = MapLayout.EDGE_RADIUS
TerrainBuilder.EXTENT = { minX = -R, maxX = R, minZ = -R, maxZ = R, minY = -16, maxY = 160 }
local E = TerrainBuilder.EXTENT
local CHUNK = 32

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
TerrainBuilder.COLORS = {
	Grass = rgb(94, 150, 54),
	LeafyGrass = rgb(62, 108, 44),
	Ground = rgb(98, 76, 54),
	Mud = rgb(86, 70, 54),
	Sand = rgb(196, 176, 132),
	Rock = rgb(124, 120, 112),
	Slate = rgb(92, 94, 100),
}
TerrainBuilder.WATER = {
	WaterColor = rgb(36, 112, 118),
	WaterTransparency = 0.55,
	WaterReflectance = 0.4,
	WaterWaveSize = 0.06,
	WaterWaveSpeed = 6,
}

function TerrainBuilder.surfaceY(x, z)
	return MapLayout.floorY(x, z)
end

-- What the top of a column is made of.
local function surfaceMaterial(x, z, _h, slope)
	local r = sqrt(x * x + z * z)
	local C = MapLayout.CREEK
	-- water's edge
	local cd = MapLayout.creekDistance(x, z)
	if cd < C.width / 2 + 1 then
		return noise(x / 9, z / 9, 1.1) > 0.15 and M.Sand or M.Mud, M.Mud
	end
	local P = MapLayout.POND
	local pd = sqrt((x - P.x) ^ 2 + (z - P.z) ^ 2)
	if pd < P.radius + 2 then
		return noise(x / 9, z / 9, 2.3) > 0 and M.Sand or M.Mud, M.Mud
	end
	-- rock where it's steep: the outcrops' sides, the boundary hills
	if slope > 1.35 or (slope > 1 and noise(x / 14, z / 14, 5.5) > 0.1) then
		return noise(x / 20, z / 20, 7.7) > 0.25 and M.Slate or M.Rock, M.Rock
	end
	local oh = MapLayout.outcropHeight(x, z)
	if oh > 2.5 then
		return noise(x / 11, z / 11, 3.9) > 0.2 and M.LeafyGrass or M.Rock, M.Rock
	end
	-- the camp: trodden dirt round the fire, patchy at the edge
	if r < MapLayout.CAMP.flat then
		local edge = r - (MapLayout.CAMP.radius - 8) + noise(x / 8, z / 8, 0.7) * 6
		if edge < 0 then
			return M.Ground, M.Ground
		end
		return edge < 6 and M.Ground or M.Grass, M.Ground
	end
	-- trails
	local td = MapLayout.trailDistance(x, z)
	local half = MapLayout.TRAIL_HALF + noise(x / 7, z / 7, 4.1) * 0.9
	if td < half then
		return td < half - 1.6 and M.Ground or (noise(x / 3, z / 3, 6.2) > 0 and M.Ground or M.Grass), M.Ground
	end
	-- mud near the water
	if cd < C.width / 2 + 7 and noise(x / 6, z / 6, 8.2) > -0.2 then
		return M.Mud, M.Ground
	end
	-- the forest floor: leafy grass and dark ground (leaf litter) under the trees, meadow grass with its blades
	-- in the glades and the clearings
	local shade = noise(x / 110, z / 110, 9.9) + (MapLayout.zoneAt(x, z) == "deep" and 0.3 or 0)
	local patch = noise(x / 24, z / 24, 2.8)
	local glade = noise(x / 70, z / 70, 13.3) - shade * 0.6
	if r < MapLayout.CAMP.clear + 8 or glade > 0.32 then
		return patch < -0.4 and M.LeafyGrass or M.Grass, M.Ground
	end
	if patch > 0.22 or shade > 0.35 and patch > -0.1 then
		return M.Ground, M.Ground
	end
	return M.LeafyGrass, M.Ground
end

local function deepMaterial(x, y, z)
	local n = noise(x / 30, y / 18, z / 30)
	return n > 0.3 and M.Slate or M.Rock
end

local function writeChunk(terrain, gx, gz, nx, nz)
	local x0, z0 = E.minX + gx * 4, E.minZ + gz * 4
	local H = {}
	local maxH = -math.huge
	for i = 0, nx + 1 do
		local row = table.create(nz + 2, 0)
		H[i] = row
		for j = 0, nz + 1 do
			local h = MapLayout.floorY(x0 + (i - 1) * 4 + 2, z0 + (j - 1) * 4 + 2)
			row[j + 1] = h
			if i >= 1 and i <= nx and j >= 1 and j <= nz and h > maxH then
				maxH = h
			end
		end
	end
	local waterTop = MapLayout.CREEK.water
	local ny = math.min(math.ceil((math.max(maxH, waterTop) - E.minY) / 4) + 1, (E.maxY - E.minY) / 4)
	local mats, occs = table.create(nx), table.create(nx)
	local C, P = MapLayout.CREEK, MapLayout.POND
	for i = 1, nx do
		local x = x0 + (i - 1) * 4 + 2
		local row, hl, hr = H[i], H[i - 1], H[i + 1]
		local cols = table.create(nz)
		for j = 1, nz do
			local z = z0 + (j - 1) * 4 + 2
			local h = row[j + 1]
			local slope = math.max(abs(hr[j + 1] - hl[j + 1]), abs(row[j + 2] - row[j])) / 8
			local top, sub = surfaceMaterial(x, z, h, slope)
			local wet = MapLayout.creekDistance(x, z) < C.width / 2 + 3
				or (x - P.x) ^ 2 + (z - P.z) ^ 2 < (P.radius + 6) ^ 2
			cols[j] = { h = h, top = top, sub = sub, wet = wet, z = z }
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
				local occ = clamp((c.h - y0) / 4, 0, 1)
				local mat = M.Air
				if occ > 0 then
					local depth = c.h - yc
					if depth < 2.5 then
						mat = c.top
					elseif depth < 8 then
						mat = c.sub
					else
						mat = deepMaterial(x, yc, c.z)
					end
				end
				if c.wet and occ < 0.5 and y0 < waterTop then
					mat, occ = M.Water, clamp((waterTop - y0) / 4, 0, 1)
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
		terrain.Decoration = true
	end)
	local cols, rows = (E.maxX - E.minX) / 4, (E.maxZ - E.minZ) / 4
	for gx = 0, cols - 1, CHUNK do
		for gz = 0, rows - 1, CHUNK do
			-- skip chunks wholly outside the round world (the corners of the box)
			local cx = E.minX + (gx + CHUNK / 2) * 4
			local cz = E.minZ + (gz + CHUNK / 2) * 4
			if sqrt(cx * cx + cz * cz) < R + CHUNK * 3 then
				writeChunk(terrain, gx, gz, math.min(CHUNK, cols - gx), math.min(CHUNK, rows - gz))
			end
		end
	end
	local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.45
	clouds.Density = 0.6
	clouds.Color = rgb(255, 255, 255)
	clouds.Parent = terrain
	return terrain
end

return TerrainBuilder
