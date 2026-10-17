--[[
First-person frames (the viewmodel and the HUD, the way a player sees them): the real server and client boot on the
mock engine, a fight is staged on Castle Clash, and the bow is caught at rest, half drawn, at full draw and on the
crossbow, plus a frame of each touch layout. For checking the animation and as references for the store art.

  luaurun tools/gameplay/firstperson.luau <outDir>
  node tools/gameplay/render.js <outDir> <pngDir> --modules <node_modules> --chromium <chrome>
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Capture = loadModule("tools/gameplay/Capture.luau")
local V3, CF = Engine.Vector3, Engine.CFrame
local Vector2 = Engine.globals.Vector2
local outDir = ARGS[1]
local tree = Engine.mountProject(".")
Engine.clientEnabled = true
local ws = Engine.workspace
ws.CurrentCamera.ViewportSize = Vector2.new(1600, 900)
local UIS = Engine.game:GetService("UserInputService")
UIS.TouchEnabled, UIS.KeyboardEnabled = false, true
Engine.runScript(tree.server.Main)
Engine.advance(0.3)
local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Match = service("MatchService")
local Teams = service("TeamService")
local Constants = Engine.require(tree.shared.Constants)
local foes = {}
for i = 1, 3 do
	local f = Engine.addPlayer("Foe" .. i, 900 + i)
	Engine.advance(0.3)
	Engine.fireServer(f, "Ready")
	table.insert(foes, f)
end
local player = Engine.addPlayer("Ava", 501)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.runScript(tree.client.Main)
Engine.advance(1.5)
Match:NewMatch("castle")
Engine.advance(Constants.BUILD_SECONDS + Constants.SPAWN_PROTECT + 1)
local team = Teams:Team(player)
local s = team == "red" and -1 or 1
local Weapon = Engine.require(tree.client.Controllers.WeaponController)
local Bus = Engine.require(tree.client.UI.Bus)
local cam = ws.CurrentCamera
local eye = V3.new(s * 6, 4.6, 30)
local look = V3.new(-s * 40, 3.5, 26)
Engine.moveTo(player, V3.new(s * 6, 3, 30), look)
for i, f in foes do
	if Teams:Team(f) ~= team then
		Engine.moveTo(f, V3.new(-s * (14 + i * 8), 3, 22 + i * 3), eye)
	else
		Engine.moveTo(f, V3.new(s * (20 + i * 4), 3, 6 + i * 4), look)
	end
end
local shots = {}
local function shot(name)
	cam.CFrame = CF.lookAt(eye, look)
	Engine.advance(0.016)
	-- (first person: your own body is hidden, as Roblox does)
	for _, d in player.Character:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = 1
		end
	end
	local snap =
		Capture.snapshot(Engine, { pos = { eye.X, eye.Y, eye.Z }, target = { look.X, look.Y, look.Z }, fov = 70 })
	snap.title = name
	snap.cinematic = false
	snap.viewport = { w = 1600, h = 900, dpr = 1 }
	Capture.save(Engine, snap, outDir, name)
	table.insert(shots, name)
end
cam.CFrame = CF.lookAt(eye, look)
Weapon.equip("bow")
Engine.advance(1)
shot("fp_rest")
Bus.Fire:Fire(true)
Engine.advance(0.45)
shot("fp_half")
Engine.advance(1.2)
shot("fp_full")
Bus.Fire:Fire(false)
Engine.advance(1)
Weapon.equip("heavy")
Engine.advance(1)
Bus.Fire:Fire(true)
Engine.advance(2)
shot("fp_heavy_full")
Bus.Fire:Fire(false)
Engine.advance(1)
Weapon.equip("crossbow")
Engine.advance(1)
shot("fp_crossbow")
local Device = Engine.require(tree.client.UI.Device)
Device.set("touch")
ws.CurrentCamera.ViewportSize = Vector2.new(1600, 740)
Engine.advance(0.2)
shot("fp_touch")
local http = Engine.game:GetService("HttpService")
writeFile(outDir .. "/index.json", http:JSONEncode(shots))
print("shots", #shots)
