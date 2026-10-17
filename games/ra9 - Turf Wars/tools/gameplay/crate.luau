--[[
The Crate and the sword skins, the way a player sees them: the real server and client boot on the mock engine in
lobby mode, and the crate on its stand, the rack beside it (the sword shelf up close), the crate's panel, the reel
mid-spin, the result card, and the locker and the shop on the sword skins are caught.

  luaurun tools/gameplay/crate.luau <outDir>
  node tools/gameplay/render.js <outDir> <pngDir> --modules <node_modules> --chromium <chrome>
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Capture = loadModule("tools/gameplay/Capture.luau")
local V3, CF = Engine.Vector3, Engine.CFrame
local Vector2 = Engine.globals.Vector2
local outDir = ARGS[1]
local tree = Engine.mountProject(".")
local Constants = Engine.require(tree.shared.Constants)
Constants.TUTORIAL = false
Constants.applyMode("lobby")
Engine.serverTimeOffset = Engine.require(tree.shared.Data.Season).EPOCH + 9 * 86400 + 14 * 3600
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
local foe = Engine.addPlayer("Foe", 901)
Engine.advance(0.3)
Engine.fireServer(foe, "Ready")
local player = Engine.addPlayer("Ava", 501)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.runScript(tree.client.Main)
Engine.advance(1.5)

local Crate = Engine.require(tree.shared.Data.Crate)
local Cosmetics = Engine.require(tree.shared.Data.Cosmetics)
local Data = service("PlayerDataService")
local Economy = service("EconomyService")
local p = Data:Get(player)
Economy:Add(player, 1240)
for _, key in { "shop_inkline", "shop_frostedge", "shop_gladius", "shop_confetti" } do
	Economy:Give(player, key)
end
p.equipped.sword = "shop_frostedge"
service("ProgressService"):Push(player)
Engine.advance(0.5)

local a = Crate.ANCHOR
local eye, look = V3.new(a.X - 10, 9, a.Z + 12), V3.new(a.X + 14, 1.5, a.Z - 10)
Engine.moveTo(player, V3.new(a.X - 4, 3, a.Z + 6), V3.new(a.X, 3, a.Z))
local cam = ws.CurrentCamera
local shots = {}
local function shot(name)
	cam.CFrame = CF.lookAt(eye, look)
	Engine.advance(0.016)
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

-- the crate on its stand, the rack beside it
shot("crate_overview")
-- along the sword shelf
eye, look = V3.new(a.X + 2, 3.2, a.Z - 3.5), V3.new(a.X + 16, 1.6, a.Z - 7.5)
shot("crate_rack_swords")
-- the bows and the trails, from the walkway between the shelves
eye, look = V3.new(a.X + 4, 3, a.Z - 15), V3.new(a.X + 18, 1.8, a.Z - 11)
shot("crate_rack_bows")
-- the panel: the offer, the reel mid-spin, the result
eye, look = V3.new(a.X - 6, 5, a.Z + 8), V3.new(a.X, 3, a.Z)
local CrateC = Engine.require(tree.client.Controllers.CrateController)
CrateC.open()
Engine.advance(0.3)
shot("crate_panel")
CrateC.refs.spinShards.Activated:Fire()
Engine.advance(2.2)
shot("crate_reel")
Engine.advance(2.6)
shot("crate_result")
CrateC.close()
-- the locker on the sword skins, and the shop's ALL SWORD SKINS
local Panel = Engine.require(tree.client.Controllers.PanelController)
local pr = Panel.refs
Panel.open("locker")
Engine.advance(0.3)
pr.body.Chip_sword.Activated:Fire()
Engine.advance(0.4)
shot("locker_swords")
Panel.open("shop")
Engine.advance(0.4)
local section = pr.body:FindFirstChild("All_sword")
if section then
	pr.body.CanvasPosition = Vector2.new(0, section.Position.Y.Offset - 6)
end
Engine.advance(0.2)
shot("shop_swords")
Panel.close()
local http = Engine.game:GetService("HttpService")
writeFile(outDir .. "/index.json", http:JSONEncode(shots))
print("shots", #shots, #Cosmetics.list)
