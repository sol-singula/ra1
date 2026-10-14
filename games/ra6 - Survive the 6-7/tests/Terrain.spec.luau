-- The forest's land (TerrainBuilder): the terrain the server writes has to match the heights the game uses
-- (MapLayout.groundY: where monsters walk, crates sit and survivors spawn), hold the creek's and the pond's water,
-- keep the camp flat and look like the plan (forest floor materials, trails, rocky outcrops, boundary hills).
--   luaurun tests/Terrain.spec.luau      (from the game folder)
local Engine = loadModule("tests/mock/Engine.luau")
local Vector3 = Engine.Vector3
local Random = Engine.globals.Random
local tree = Engine.mountProject(".")
local MapLayout = Engine.require(tree.shared.World.MapLayout)
local MapBuilder = Engine.require(tree.server.World.MapBuilder)
local ws = Engine.workspace

local passed, failed = 0, 0
local function check(name, cond, detail)
	if cond then
		passed += 1
	else
		failed += 1
		print("FAIL " .. name .. (detail ~= nil and (": " .. tostring(detail)) or ""))
	end
end

MapBuilder.build()
local T = Engine.terrain
local voxels = 0
for _, c in T.voxels do
	voxels += c.nx * c.ny * c.nz
end
check("the land is terrain voxels", #T.voxels > 0 and voxels > 1e6, voxels)
local inPalette = {}
for _, name in T.palette do
	inPalette[name] = true
end
for _, name in { "Grass", "LeafyGrass", "Ground", "Rock", "Mud", "Sand", "Water" } do
	check("the land uses " .. name, inPalette[name])
end

local function top(x, z, from)
	return Engine.terrainTop(x, z, from or 120)
end
local function material(x, y, z)
	return (Engine.terrainVoxelAt(Vector3.new(x, y, z)))
end
local function surface(x, z)
	local h = top(x, z)
	return h and material(x, h - 1, z)
end

-- Heights the game relies on ------------------------------------------------------------------------------------------
local worst = 0
for k = 0, 23 do
	local a, r = k / 24 * math.pi * 2, 4 + (k % 6) * 7
	worst = math.max(worst, math.abs(top(math.cos(a) * r, math.sin(a) * r) - MapLayout.CAMP.y))
end
check("the camp is level", worst < 0.5, worst)

local rng = Random.new(7)
local samples, worstAt = 0, nil
worst = 0
while samples < 400 do
	local x, z = rng:NextNumber(-500, 500), rng:NextNumber(-500, 500)
	if
		MapLayout.radius(x, z) < MapLayout.WORLD_RADIUS - 20
		and MapLayout.walkable(x, z)
		and MapLayout.creekDistance(x, z) > MapLayout.CREEK.width
		and MapLayout.outcropHeight(x, z) < 0.5
	then
		samples += 1
		local d = math.abs(top(x, z) - MapLayout.groundY(x, z))
		if d > worst then
			worst, worstAt = d, `{math.floor(x)}, {math.floor(z)}`
		end
	end
end
check("the forest floor is where monsters walk", worst < 1, `{worst} at {worstAt}`)

-- the forest rolls
local lo, hi = math.huge, -math.huge
for _ = 1, 300 do
	local x, z = rng:NextNumber(-450, 450), rng:NextNumber(-450, 450)
	if MapLayout.radius(x, z) > 120 and MapLayout.radius(x, z) < 480 and MapLayout.walkable(x, z) then
		local h = MapLayout.floorY(x, z)
		lo, hi = math.min(lo, h), math.max(hi, h)
	end
end
check("the forest floor rolls (not a flat plate)", hi - lo > 4, hi - lo)
check("but stays walkable (gentle)", hi - lo < 40, hi - lo)

-- Water --------------------------------------------------------------------------------------------------------------------
local cp = MapLayout.creek[math.floor(#MapLayout.creek / 2)]
local found = false
for dx = -6, 6, 2 do
	for dz = -6, 6, 2 do
		local x, z = cp.X + dx, cp.Z + dz
		if MapLayout.creekDistance(x, z) < 2 and material(x, MapLayout.CREEK.water - 1, z) == "Water" then
			found = true
		end
	end
end
check("the creek holds water", found)
local P = MapLayout.POND
check("the pond holds water", material(P.x, P.water - 1, P.z) == "Water")
check(
	"the creek's banks are mud or sand",
	(function()
		local n, ok = 0, 0
		for i = 1, #MapLayout.creek, 7 do
			local c = MapLayout.creek[i]
			local x, z = c.X, c.Z + MapLayout.CREEK.width / 2 + 0.5
			local m = surface(x, z)
			if m then
				n += 1
				if m == "Mud" or m == "Sand" then
					ok += 1
				end
			end
		end
		return n > 0 and ok / n > 0.4, ok .. "/" .. n
	end)()
)
check("wading depth: you can cross the creek", MapLayout.groundY(cp.X, cp.Z) >= MapLayout.CREEK.wade - 0.01)
check(
	"bridges stand over the creek",
	ws.Map:FindFirstChild("Bridges") and #ws.Map.Bridges:GetChildren() == #MapLayout.bridges
)

-- What the land is made of ------------------------------------------------------------------------------------------------
check("the camp is trodden dirt", surface(5, 5) == "Ground")
check(
	"the trails are dirt paths",
	(function()
		local dirt, n = 0, 0
		for _, tr in MapLayout.trails do
			for i = 1, #tr.points, 3 do
				local p = tr.points[i]
				n += 1
				if surface(p.X, p.Z) == "Ground" then
					dirt += 1
				end
			end
		end
		return dirt / n > 0.8, dirt .. "/" .. n
	end)()
)
check(
	"the forest floor is mostly green",
	(function()
		local green, n = 0, 0
		for _ = 1, 200 do
			local x, z = rng:NextNumber(-450, 450), rng:NextNumber(-450, 450)
			local r = MapLayout.radius(x, z)
			if r > 100 and r < 460 and MapLayout.trailDistance(x, z) > 8 and MapLayout.creekDistance(x, z) > 20 then
				local m = surface(x, z)
				n += 1
				if m == "Grass" or m == "LeafyGrass" or m == "Ground" then
					green += 1
				end
			end
		end
		return green / n > 0.8, green .. "/" .. n
	end)()
)
check(
	"rocky outcrops",
	(function()
		local o = MapLayout.OUTCROPS[1]
		return MapLayout.floorY(o.x, o.z) > MapLayout.floorY(o.x + o.r * 2.5, o.z) + 2
	end)()
)
check(
	"the edge of the world is a wall of hills",
	MapLayout.floorY(MapLayout.EDGE_RADIUS - 20, 0) > MapLayout.floorY(MapLayout.WORLD_RADIUS - 60, 0) + 10
)
check("clouds", ws.Terrain:FindFirstChildOfClass("Clouds") ~= nil)

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
	error("terrain tests failed")
end
