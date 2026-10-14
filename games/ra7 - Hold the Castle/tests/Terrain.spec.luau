-- The map's land (TerrainBuilder): the terrain the server writes has to match the heights the game uses
-- (MapLayout.groundY, where NPCs walk and pieces stand), keep the cave and tunnels open, hold the creek's water
-- and look like the plan (materials, clouds, water).
--   luaurun tests/Terrain.spec.luau      (from the game folder)
local Engine = loadModule("tests/mock/Engine.luau")
local Vector3 = Engine.Vector3
local Random = Engine.globals.Random
local tree = Engine.mountProject(".")
local MapLayout = Engine.require(tree.shared.World.MapLayout)
local MapBuilder = Engine.require(tree.server.World.MapBuilder)
local TerrainBuilder = Engine.require(tree.server.World.TerrainBuilder)
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
for _, name in { "Grass", "LeafyGrass", "Ground", "Rock", "Slate", "Sand", "Sandstone", "Snow", "Water", "Cobblestone" } do
	check("the land uses " .. name, inPalette[name])
end
check("no ground parts left under the valley", ws.Map:FindFirstChild("Valley") == nil)

local function top(x, z, from)
	return Engine.terrainTop(x, z, from or 120)
end
local function material(x, y, z)
	return (Engine.terrainVoxelAt(Vector3.new(x, y, z)))
end

-- Heights the game relies on -------------------------------------------------------------------------------------
local worst = 0
for k = 0, 23 do
	local a, r = k / 24 * math.pi * 2, 6 + (k % 6) * 15
	local h = top(MapLayout.HILL.center.X + math.cos(a) * r, MapLayout.HILL.center.Y + math.sin(a) * r)
	worst = math.max(worst, math.abs(h - MapLayout.HILL.height))
end
check("the hill top is level at the castle's height", worst < 0.3, worst)

worst = 0
for _, ramp in MapLayout.HILL.ramps do
	for along = MapLayout.HILL.top + 4, MapLayout.HILL.foot - 4, 6 do
		local x = MapLayout.HILL.center.X + ramp.dir.X * along
		local z = MapLayout.HILL.center.Y + ramp.dir.Y * along
		worst = math.max(worst, math.abs(top(x, z) - MapLayout.groundY(x, z)))
	end
end
check("the ramps slope the way NPCs walk them", worst < 0.8, worst)

-- the valley floor (rolls included) against groundY, away from the creek, the bridges and the hill's cliffs
local rng = Random.new(11)
local samples, worstAt = 0, nil
worst = 0
while samples < 300 do
	local x, z = rng:NextNumber(-600, -40), rng:NextNumber(-190, 190)
	local hill = math.sqrt((x - MapLayout.HILL.center.X) ^ 2 + (z - MapLayout.HILL.center.Y) ^ 2)
	local creek = math.abs(x - MapLayout.CREEK.x)
	local rampSide = MapLayout.rampAt(x, z, 20) ~= nil
	if
		MapLayout.walkable(x, z)
		and creek > 14
		and (hill < MapLayout.HILL.top - 2 or hill > MapLayout.HILL.top + 8)
		and not rampSide
	then
		samples += 1
		local d = math.abs(top(x, z) - MapLayout.groundY(x, z))
		if d > worst then
			worst, worstAt = d, `{math.floor(x)}, {math.floor(z)}`
		end
	end
end
check("the valley floor is where NPCs walk", worst < 0.8, `{worst} at {worstAt}`)
local rolls = 0
for _ = 1, 200 do
	local x, z = rng:NextNumber(-460, -300), rng:NextNumber(-180, 180)
	if math.abs(MapLayout.roll(x, z)) > 0.5 then
		rolls += 1
	end
end
check("the valley rolls a little", rolls > 10, rolls)

worst = 0
for x = 80, 186, 8 do
	for z = -48, 48, 12 do
		worst = math.max(worst, math.abs(top(x, z) - 0))
	end
end
check("the canyon's build zone is flat", worst < 0.3, worst)
worst = 0
for k = 0, 11 do
	local a = k / 12 * math.pi * 2
	local x, z = MapLayout.CAVE.center.X + math.cos(a) * 40, MapLayout.CAVE.center.Y + math.sin(a) * 40
	worst = math.max(worst, math.abs(top(x, z, 6) - 0))
end
check("the cave's floor is flat", worst < 0.3, worst)

-- the cave and tunnels are open, with rock overhead
local cv = MapLayout.CAVE
check(
	"the cave is hollow",
	material(cv.center.X, 2, cv.center.Y) == "Air" and material(cv.center.X, 40, cv.center.Y) == "Air"
)
check("the cave has a roof", material(cv.center.X, cv.ceiling + 14, cv.center.Y) ~= "Air")
check("the cave has a floor", material(cv.center.X, -2, cv.center.Y) ~= "Air")
for _, t in { cv.mainTunnel, cv.sideTunnel } do
	local z = (t.minZ + t.maxZ) / 2
	local open = true
	for x = t.minX + 2, t.maxX - 4, 8 do
		for y = 2, t.height - 6, 4 do
			if material(x, y, z) ~= "Air" then
				open = false
			end
		end
	end
	check(`the tunnel at z={z} goes through`, open)
	check(`the tunnel at z={z} has rock above it`, material((t.minX + t.maxX) / 2, t.height + 10, z) ~= "Air")
end
check("the mountain's face rises over the tunnels", top(238, 24, 200) > 50, top(238, 24, 200))

-- the creek holds water and NPCs wade it; the bridges carry them over
local cr = MapLayout.CREEK
check("the creek holds water", material(cr.x + 1, cr.water - 1, 60) == "Water")
check("the creek's bed is under the water", top(cr.x + 1, 60) < cr.water - 1, top(cr.x + 1, 60))
check("NPCs wade the creek", MapLayout.groundY(cr.x, 60) == cr.wade)
for _, b in MapLayout.bridges do
	check(`NPCs cross the {b.key} bridge on its deck`, MapLayout.groundY(b.x, b.z) == b.y)
end

-- the hangout's deck sits on its plateau; the ridges and mountains close the valley in
local D = MapLayout.hangout.deck
check(
	"the hangout's plateau is level with the deck",
	math.abs(top((D.minX + D.maxX) / 2, (D.minZ + D.maxZ) / 2, 120) - MapLayout.RIDGE_TOP) < 0.3
)
check("no grass under the hangout's planks", material(-200, MapLayout.RIDGE_TOP - 1, 270) == "Ground")
check("the ridges rise past the valley", top(-300, MapLayout.RIDGE_Z + 50, 200) > 30)
check("the canyon's walls are tall", top(110, MapLayout.CANYON.halfWidth + 12, 200) > 50)
local snowy = false
for x = 300, 560, 20 do
	for z = -200, 200, 20 do
		if material(x, top(x, z, 200) - 1, z) == "Snow" then
			snowy = true
		end
	end
end
check("the mountain has snow on top", snowy)

-- everything that stands on the ground stands on the terrain
worst = 0
for _, n in MapLayout.nodes do
	if n.pos.X < MapLayout.CANYON.maxX then
		worst = math.max(worst, math.abs(top(n.pos.X, n.pos.Z) - n.pos.Y))
	end
end
check("resource nodes sit on the land", worst < 0.8, worst)
local offMap = {}
for _, n in MapLayout.nodes do
	if not MapLayout.walkable(n.pos.X, n.pos.Z) then
		table.insert(offMap, n.id)
	end
end
check("every resource node can be walked to", #offMap == 0, table.concat(offMap, ", "))
for i = 1, 3 do
	local p = MapLayout.dwarfSpawn(i, 1)
	check(`dwarves spawn above the ground at shrine {i}`, p.Y > top(p.X, p.Z, p.Y) + 1)
end
local mp = MapLayout.monsterSpawn(0, 1)
check("monsters spawn above the ground", mp.Y > top(mp.X, mp.Z) + 1)
check("surfaceY agrees with the voxels", math.abs(TerrainBuilder.surfaceY(-420, 120) - top(-420, 120)) < 0.6)

-- the look: materials where the plan has them, clouds, water, grass blades
check("the shrine stands on a cobbled plaza", material(-196, MapLayout.HILL.height - 1, 4) == "Cobblestone")
check("the ramps are cobbled", material(-80, MapLayout.groundY(-80, 0) - 0.5, 0) == "Cobblestone")
check(
	"the canyon floor is sand and sandstone",
	({ Sand = true, Sandstone = true, Ground = true })[material(150, -1, -20)]
)
check("the cave floor is stone", ({ Slate = true, Cobblestone = true, Ground = true })[material(380, -2, 30)])
local terrain = ws:FindFirstChildOfClass("Terrain")
check("clouds in the sky", terrain:FindFirstChildOfClass("Clouds") ~= nil)
check("Roblox's grass decoration is on", rawget(terrain, "_props").Decoration == true)
check("the water is tinted", rawget(terrain, "_props").WaterColor ~= nil)
check("the grass has its colour", T.colors.Grass ~= nil)
check("the hill's cliff edge keeps monsters to the ramps", #ws.Map.Hill:GetChildren() > 80)

print(`{passed} passed, {failed} failed`)
if failed > 0 then
	error("terrain tests failed")
end
