--[[
The monster line-up: every rig in a few of its poses, in a camp clearing by day (to check how they look).

  luaurun tools/gameplay/rigs.luau <outDir>
  node tools/gameplay/render.js <outDir> <renderDir> --modules <node_modules> --textures <pbr dir>
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Capture = loadModule("tools/gameplay/Capture.luau")
local V3 = Engine.Vector3
local CF = Engine.CFrame
local Vector2 = Engine.globals.Vector2
local outDir = ARGS[1] or "rigs"

local tree = Engine.mountProject(".")
Engine.workspace.CurrentCamera.ViewportSize = Vector2.new(1600, 900)
local MapBuilder = Engine.require(tree.server.World.MapBuilder)
local MapLayout = Engine.require(tree.shared.World.MapLayout)
local LightingPresets = Engine.require(tree.shared.World.LightingPresets)
local Rigs = Engine.require(tree.shared.World.Rigs)
MapBuilder.build()
local viewer = Engine.addPlayer("Viewer", 4242)
Engine.Players.LocalPlayer = viewer
Engine.localPlayer = viewer

local folder = Engine.globals.Instance.new("Folder")
folder.Name = "Monsters"
folder.Parent = Engine.workspace

-- a row in the camp, facing the camera (+Z): rotate 180 so their faces (-Z) look at us
local function put(kind, x, z, pose, opts)
	local rig = Rigs.build(kind, opts, folder)
	local y = MapLayout.floorY(x, z)
	Rigs.place(rig, CF.new(x, y, z) * Engine.globals.CFrame.Angles(0, math.pi, 0), pose)
	return rig
end

local cx, cz = 18, 26
put("kermy", cx - 12, cz, { state = "tell", tell = "sixseven", t = 0.3 })
put("kermy", cx - 4, cz - 2, { state = "attack", t = 0 })
put("snapcap", cx + 3, cz + 1, { state = "idle" })
put("snapcap", cx + 6, cz + 2, { state = "tell", t = 0.1 })
put("grinwolf", cx + 11, cz, { state = "idle", walk = 1, stride = 0.3 })
put("grinwolf", cx + 16, cz - 1, { state = "tell", f = 0.3, t = 0.2 }, { elite = true })
put("pelter", cx - 8, cz + 6, { state = "tell" })
put("stumpy", cx + 2, cz - 6, { state = "tell", t = 0 })
put("mimic", cx + 9, cz + 7, { state = "tell" })
put("mimic", cx + 13, cz + 6, { state = "flee", t = 0.3, walk = 0.6, stride = 1 })

local function shot(name, camPos, camTarget, fov, preset)
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
	print("shot", name, #snap.parts, "parts")
	return name
end
local y0 = MapLayout.floorY(cx, cz)
local shots = {}
table.insert(shots, shot("01_lineup", V3.new(cx + 1, y0 + 7, cz + 26), V3.new(cx + 1, y0 + 2.5, cz), 50))
table.insert(shots, shot("02_kermy", V3.new(cx - 9, y0 + 5, cz + 11), V3.new(cx - 8, y0 + 4, cz - 1), 45))
table.insert(shots, shot("02b_stumpy", V3.new(cx + 6, y0 + 4, cz + 2), V3.new(cx + 2, y0 + 2.5, cz - 6), 50))
-- Mega Kermy by the Ancient Pines
local pine = MapLayout.ancientPines[3]
local out = V3.new(pine.pos.X, 0, pine.pos.Z).Unit
local bossAt = pine.pos + out * 22
local boss = Rigs.build("mega_kermy", {}, folder)
Rigs.place(
	boss,
	CF.new(bossAt.X, MapLayout.floorY(bossAt.X, bossAt.Z), bossAt.Z)
		* Engine.globals.CFrame.Angles(0, math.atan2(out.X, out.Z), 0),
	{ state = "tell", tell = "sixseven", t = 0.4 }
)
Rigs.setWeak(boss, true, 0.2)
local side = V3.new(-out.Z, 0, out.X)
local cam = bossAt - out * 26 + side * 34 + V3.new(0, 10, 0)
table.insert(shots, shot("03_mega", cam, bossAt + V3.new(0, 14, 0), 60))
table.insert(shots, shot("04_mega_night", cam, bossAt + V3.new(0, 14, 0), 60, "boss"))
writeFile(outDir .. "/index.json", Engine.game:GetService("HttpService"):JSONEncode(shots))
