--[[
A quick look at the world while building it: the forest, the camp (every structure built), a few findings and
monsters posed, from a handful of cameras. No game logic runs.

  luaurun tools/gameplay/preview.luau <outDir> [only]
  node tools/gameplay/render.js <outDir> <renderDir> --modules <node_modules> --textures <pbr dir>
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Capture = loadModule("tools/gameplay/Capture.luau")
local V3 = Engine.Vector3
local Vector2 = Engine.globals.Vector2
local outDir = ARGS[1] or "preview"
local only = ARGS[2]

local tree = Engine.mountProject(".")
Engine.workspace.CurrentCamera.ViewportSize = Vector2.new(1600, 900)
local MapBuilder = Engine.require(tree.server.World.MapBuilder)
local MapLayout = Engine.require(tree.shared.World.MapLayout)
local LightingPresets = Engine.require(tree.shared.World.LightingPresets)
local CampModels = Engine.require(tree.shared.World.CampModels)
MapBuilder.build()

-- the camp, fully built (the preview of a Stronghold)
local structures = Engine.workspace.Structures
for _, s in MapLayout.campSlots do
	local key = s.key
	local upgraded = key == "wall" or key == "gate"
	CampModels.build(key, s.cf, { parent = structures, width = s.width, upgraded = upgraded and s.index % 2 == 0 })
end

local viewer = Engine.addPlayer("Viewer", 4242)
Engine.Players.LocalPlayer = viewer
Engine.localPlayer = viewer

local shots = {}
local function shot(name, camPos, camTarget, fov, preset)
	if only and not string.find(name, only, 1, true) then
		return
	end
	LightingPresets.apply(preset or "day")
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

local function at(x, z, up)
	return V3.new(x, MapLayout.floorY(x, z) + (up or 0), z)
end

shot("01_camp_aerial", V3.new(70, 60, 90), V3.new(0, 4, 0), 55)
shot("02_camp_ground", at(-30, 34, 6), at(4, -6, 4), 60)
shot("03_forest_floor", at(130, 60, 6), at(170, 90, 8), 60)
shot("04_deep_forest", at(380, -60, 7), at(420, -30, 10), 60)
shot("05_creek_bridge", at(-30, -168, 10), at(-4, -188, 2), 55)
shot("06_overview", V3.new(-330, 260, 420), V3.new(0, 0, 0), 50)
shot("07_camp_night", V3.new(60, 30, 70), V3.new(0, 3, 0), 55, "night")
shot("08_top", V3.new(0, 900, 1), V3.new(0, 0, 0), 70)
writeFile(outDir .. "/index.json", Engine.game:GetService("HttpService"):JSONEncode(shots))
