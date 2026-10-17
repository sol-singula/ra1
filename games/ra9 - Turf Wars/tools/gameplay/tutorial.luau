--[[
Tutorial frames (the first-minute guide, the way a new player sees it): the real server and client boot on the mock
engine with one new player alone with the bot, and the intro and the guide are caught at a few moments: the sweep
over the arena (BLUE), skimming the line (THIS IS YOUR TURF), the build step's glowing spot (PLACE IT), and the line
jumping forward after the first knockout (THE LINE MOVED!).

  luaurun tools/gameplay/tutorial.luau <outDir>
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
local Bots = service("BotService")
local Constants = Engine.require(tree.shared.Constants)
local Formulas = Engine.require(tree.shared.Formulas)
local player = Engine.addPlayer("Newbie", 601)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.runScript(tree.client.Main)
Engine.advance(0.3)
local Tut = Engine.require(tree.client.Controllers.TutorialController)
local Bus = Engine.require(tree.client.UI.Bus)
local cam = ws.CurrentCamera
local shots = {}

local function hideMe()
	for _, d in player.Character:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = 1
		end
	end
end

local function shot(name, firstPerson)
	if firstPerson then
		hideMe()
	end
	local cf = cam.CFrame
	local p, t = cf.Position, cf.Position + cf.LookVector * 50
	local snap =
		Capture.snapshot(Engine, { pos = { p.X, p.Y, p.Z }, target = { t.X, t.Y, t.Z }, fov = cam.FieldOfView or 70 })
	snap.title = name
	snap.cinematic = false
	snap.viewport = { w = 1600, h = 900, dpr = 1 }
	Capture.save(Engine, snap, outDir, name)
	table.insert(shots, name)
end

-- the intro
local t = 0
while not Tut.state().intro and t < 3 do
	Engine.advance(0.05)
	t += 0.05
end
Engine.advance(1.62)
shot("tutorial_intro_blue")
Engine.advance(4.45 - 1.62)
shot("tutorial_intro_turf")
Engine.advance(4)
-- the build step: pick the wall, walk toward the spot
Engine.advance(1)
local Hud = Engine.require(tree.client.Controllers.HudController)
Hud.refs.trayButtons.wall.Activated:Fire()
Engine.advance(1.5)
local slab = ws.TutorialFx:FindFirstChild("SpotSlab")
local team = Teams:Team(player)
local fwd = Formulas.forward(team)
if slab then
	local c = slab.Position
	local stand = V3.new(c.X - fwd * 22, 3, c.Z + 9)
	Engine.moveTo(player, stand, c)
	cam.CFrame = CF.lookAt(stand + V3.new(0, 1.6, 0), c + V3.new(fwd * 4, 2, -4))
	Engine.advance(0.4)
	cam.CFrame = CF.lookAt(stand + V3.new(0, 1.6, 0), c + V3.new(fwd * 4, 2, -4))
	Engine.advance(0.016)
	shot("tutorial_place_it", true)
end
-- the fight: knock the bot out, catch the line moving
Bots.Think = function() end
while Match:Phase() ~= "fight" do
	Engine.advance(0.5)
end
local bot = Bots:List()[1]
Engine.moveTo(player, V3.new(Match:Frontline() - fwd * 6, 3, 10), V3.new(Match:Frontline() + fwd * 10, 3, 10))
Engine.moveTo(bot, V3.new(Match:Frontline() + fwd * 10, 3, 10), V3.new(Match:Frontline() - fwd * 6, 3, 10))
Engine.advance(Constants.SPAWN_PROTECT + 1.5)
local head = player.Character.Head.Position
cam.CFrame = CF.lookAt(head, bot.Character.HumanoidRootPart.Position + V3.new(0, 0.6, 0))
Bus.Fire:Fire(true)
Engine.advance(1)
cam.CFrame = CF.lookAt(head, bot.Character.HumanoidRootPart.Position + V3.new(0, 0.6, 0))
Bus.Fire:Fire(false)
local w = 0
while Tut.state().step ~= "push" and not Tut.state().cinema and w < 6 do
	Engine.advance(0.05)
	w += 0.05
end
-- (inside the knockout's cinematic: wait for the title)
w = 0
while Tut.refs.title.Text ~= "THE LINE MOVED!" and w < 4 do
	Engine.advance(0.05)
	w += 0.05
end
Engine.advance(0.45)
shot("tutorial_line_moved")
local http = Engine.game:GetService("HttpService")
writeFile(outDir .. "/index.json", http:JSONEncode(shots))
print("shots", #shots, table.concat(shots, " "))
