--[[
A quick look at the world while building it: the map, every resource node, the starter castle (finished), a few
NPC dwarves and monsters posed, from a handful of cameras. No game logic runs.

  luaurun tools/gameplay/preview.luau <outDir> [only]
  node tools/gameplay/render.js <outDir> <renderDir> --modules <node_modules>
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Capture = loadModule("tools/gameplay/Capture.luau")
local V3, CF = Engine.Vector3, Engine.CFrame
local Vector2 = Engine.globals.Vector2
local outDir = ARGS[1] or "preview"
local only = ARGS[2]

local tree = Engine.mountProject(".")
Engine.workspace.CurrentCamera.ViewportSize = Vector2.new(1600, 900)
local MapBuilder = Engine.require(tree.server.World.MapBuilder)
local MapLayout = Engine.require(tree.shared.World.MapLayout)
local PieceModels = Engine.require(tree.shared.World.PieceModels)
local Pieces = Engine.require(tree.shared.Data.Pieces)
local Costumes = Engine.require(tree.shared.World.Costumes)
local LightingPresets = Engine.require(tree.shared.World.LightingPresets)
local Looks = Engine.require(tree.shared.Data.Looks)
MapBuilder.build()
for _, n in MapLayout.nodes do
	MapBuilder.nodeModel(n, Engine.workspace.Nodes)
end
-- the starter castle, finished, plus a few extra pieces
local function place(key, i, j, rot, opts)
	local piece = Pieces.byKey[key]
	local w, d = Pieces.cells(piece, rot)
	local cx, cz = MapLayout.cellCenter(i, j)
	local gy = MapLayout.groundY((i + w / 2) * 4, (j + d / 2) * 4)
	_ = cx
	_ = cz
	return PieceModels.build(key, PieceModels.frame(piece, i, j, rot, gy), opts or { parent = Engine.workspace.Castle })
end
for _, b in MapLayout.starter do
	place(b.key, b.i, b.j, b.rot)
end
place("tower", -41, 9, 0, { parent = Engine.workspace.Castle, upgraded = true, flag = Looks.byKey.lion })
place("forge", -46, -6, 0)
place("kitchen", -46, 4, 0)
place("potionTable", -44, -1, 0)
place("healStation", -47, 0, 0)
place("fixStation", -49, 6, 0)
place("spikes", -64, -1, 0)
place("spikes", -64, 0, 0)
place("pit", -65, 3, 0)
place("oilPot", -59, -6, 0)
place("flag", -59, 6, 0, { parent = Engine.workspace.Castle, flag = Looks.byKey.crown })
place("shrineWard", -48, -3, 0)
place("stairs", -60, 3, 1)
place("woodWall", -66, -14, 0)
place("quickWall", -70, 8, 1)
place("stoneWall", -55, 10, 0, { parent = Engine.workspace.Castle, upgraded = true })
place("gate", -50, 10, 0, { parent = Engine.workspace.Castle, upgraded = true })
place("tower", -62, -11, 0, { parent = Engine.workspace.Castle, ghost = Engine.globals.Color3.fromRGB(96, 204, 255) })

-- some NPCs
local npcs = Engine.workspace:FindFirstChild("Npcs") or Engine.Instance.new("Folder", Engine.workspace)
npcs.Name = "Npcs"
local function npc(kind, pos, look, pose, facing)
	local n = Costumes.npc(kind, look, npcs)
	local root = CF.lookAt(pos, pos + (facing or V3.new(1, 0, 0)))
	Costumes.place(n, root, pose)
	return n
end
local y = MapLayout.HILL.height
npc(
	"dwarf",
	V3.new(-232, y, -8),
	{ armor = Looks.byKey.royal, beard = Looks.byKey.ginger, job = "fighter", shirt = Costumes.DWARF_SHIRTS[2] },
	{ swing = 0.4 },
	V3.new(-1, 0, 0)
)
npc(
	"dwarf",
	V3.new(-228, y, 6),
	{ armor = Looks.byKey.iron, beard = Looks.byKey.brown, job = "builder" },
	{ walk = 1, stride = 1 },
	V3.new(-1, 0, 0)
)
npc(
	"dwarf",
	V3.new(-225, y, -16),
	{ armor = Looks.byKey.golden, beard = Looks.byKey.snow, job = "archer", shirt = Costumes.DWARF_SHIRTS[3] },
	{},
	V3.new(-1, 0, 0)
)
npc(
	"dwarf",
	V3.new(-220, y, 14),
	{ armor = Looks.byKey.emerald, beard = Looks.byKey.rainbow, job = "healer", shirt = Costumes.DWARF_SHIRTS[5] },
	{ cheer = 0.3 },
	V3.new(-1, 0, 0)
)
npc(
	"dwarf",
	V3.new(-218, y, -2),
	{ armor = Looks.byKey.copper, beard = Looks.byKey.black, job = "miner", shirt = Costumes.DWARF_SHIRTS[4] },
	{ carry = true },
	V3.new(-1, 0, 0)
)
local kinds = { "grunt", "brute", "spitter", "witch", "breaker", "imp", "scout", "grunt", "grunt", "brute" }
for k, kind in kinds do
	local pos = V3.new(-262 - (k % 4) * 6, 0, -14 + k * 3.2)
	pos = V3.new(pos.X, MapLayout.groundY(pos.X, pos.Z), pos.Z)
	npc(
		kind,
		pos,
		{ skin = k == 8 and Looks.byKey.frost or (k == 9 and Looks.byKey.lava or nil) },
		{ walk = k, stride = 1 },
		V3.new(1, 0, 0)
	)
end

local viewer = Engine.addPlayer("Viewer", 4242)
Engine.Players.LocalPlayer = viewer
Engine.localPlayer = viewer

local shots = {}
local function shot(name, camPos, camTarget, fov, preset)
	if only and not string.find(name, only, 1, true) then
		return
	end
	LightingPresets.apply(preset or "build")
	local snap = Capture.snapshot(Engine, {
		pos = { camPos.X, camPos.Y, camPos.Z },
		target = { camTarget.X, camTarget.Y, camTarget.Z },
		fov = fov or 50,
	})
	snap.title = name
	snap.hideGui = true
	snap.viewport = { w = 1600, h = 900, dpr = 1 }
	Capture.save(Engine, snap, outDir, name)
	table.insert(shots, name)
	print("shot", name, #snap.parts, "parts")
end

shot("01_valley_overview", V3.new(-470, 150, -260), V3.new(-220, 0, 0), 55)
shot("02_castle_west", V3.new(-300, 40, -40), V3.new(-226, 10, 0), 50)
shot("03_castle_close", V3.new(-250, 18, -26), V3.new(-232, 12, 4), 55)
shot("04_canyon", V3.new(-40, 50, -20), V3.new(110, 0, 0), 55, "fight")
shot("05_cave", V3.new(350, 14, 10), V3.new(400, 6, 0), 70, "laststand")
shot("06_forest_rift", V3.new(-470, 24, 40), V3.new(-545, 10, 0), 55, "plague")
shot("07_hangout", V3.new(-200, 62, 236), V3.new(-200, 52, 286), 60, "hangout")
shot("08_mountain_far", V3.new(-40, 96, -20), V3.new(330, 60, 0), 50, "fight")
shot("09_pieces", V3.new(-186, 22, -6), V3.new(-196, 10, 4), 60)
shot("10_monsters", V3.new(-240, 14, 16), V3.new(-268, 4, 4), 50)
shot("11_top", V3.new(-200, 520, 1), V3.new(-200, 0, 0), 60)
writeFile(outDir .. "/index.json", Engine.game:GetService("HttpService"):JSONEncode(shots))
