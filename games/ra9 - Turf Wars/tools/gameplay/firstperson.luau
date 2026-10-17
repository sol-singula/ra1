--[[
First-person frames (the viewmodel and the HUD, the way a player sees them): the real server and client boot on the
mock engine, a fight is staged on Castle Clash, and the bow is caught at rest, half drawn, at full draw, the TNT at
rest, wound up and just thrown, the blade at rest and mid-slash, the build tray, plus a frame of each touch layout.
For checking the animation and as references for the store art.

  luaurun tools/gameplay/firstperson.luau <outDir>
  node tools/gameplay/render.js <outDir> <pngDir> --modules <node_modules> --chromium <chrome>
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Capture = loadModule("tools/gameplay/Capture.luau")
local V3, CF = Engine.Vector3, Engine.CFrame
local Vector2 = Engine.globals.Vector2
local outDir = ARGS[1]
local tree = Engine.mountProject(".")
Engine.require(tree.shared.Constants).AFK_SECONDS = 0 -- (test players stand still: tests/ServerSmoke checks the AFK limbo on its own)
Engine.require(tree.shared.Constants).MIN_SIDE = 1 -- (the old minimum: these checks count the bots themselves; BotSmoke checks 2 v 2)
Engine.require(tree.shared.Constants).TUTORIAL = false -- (the players here know the game: tests/TutorialSmoke is the tutorial's)
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
Engine.advance(1)
local team = Teams:Team(player)
local s = team == "red" and -1 or 1
local Weapon = Engine.require(tree.client.Controllers.WeaponController)
local Bus = Engine.require(tree.client.UI.Bus)
local cam = ws.CurrentCamera
local eye = V3.new(s * 6, 4.6, 30)
local look = V3.new(-s * 40, 3.5, 26)
-- everyone where the frames want them (again once the fight starts: the fight puts people back at their spawns)
local function stage()
	Engine.moveTo(player, V3.new(s * 6, 3, 30), look)
	for i, f in foes do
		if Teams:Team(f) ~= team then
			Engine.moveTo(f, V3.new(-s * (14 + i * 8), 3, 22 + i * 3), eye)
		else
			Engine.moveTo(f, V3.new(s * (20 + i * 4), 3, 6 + i * 4), look)
		end
	end
end
stage()
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
	local snap = Capture.snapshot(
		Engine,
		{ pos = { eye.X, eye.Y, eye.Z }, target = { look.X, look.Y, look.Z }, fov = cam.FieldOfView or 70 }
	)
	snap.title = name
	snap.cinematic = false
	snap.viewport = { w = 1600, h = 900, dpr = 1 }
	Capture.save(Engine, snap, outDir, name)
	table.insert(shots, name)
end
-- the build phase: the tray, a wall picked
local BuildC = Engine.require(tree.client.Controllers.BuildController)
BuildC.pick("wall")
Engine.advance(0.2)
shot("fp_build_tray")
BuildC.pick(nil)
Engine.advance(Constants.BUILD_SECONDS + Constants.SPAWN_PROTECT)
stage()
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
Weapon.equip("tnt")
Engine.advance(1)
shot("fp_tnt")
Bus.Fire:Fire(true)
Engine.advance(0.9)
shot("fp_tnt_windup")
Bus.Fire:Fire(false)
Engine.advance(0.12)
shot("fp_tnt_thrown")
Engine.advance(4)
Constants.CHARGE_SECONDS = 1e6 -- (the blade only comes out in the CHARGE)
Engine.advance(0.5)
Weapon.equip("blade")
Engine.advance(1)
shot("fp_blade")
Bus.Fire:Fire(true)
Engine.advance(0.1)
shot("fp_blade_slash")
Bus.Fire:Fire(false)
Engine.advance(1)
local Device = Engine.require(tree.client.UI.Device)
Device.set("touch")
ws.CurrentCamera.ViewportSize = Vector2.new(1600, 740)
Engine.advance(0.2)
shot("fp_touch")
local http = Engine.game:GetService("HttpService")
writeFile(outDir .. "/index.json", http:JSONEncode(shots))
print("shots", #shots)
