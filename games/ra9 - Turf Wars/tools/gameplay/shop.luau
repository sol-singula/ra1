--[[
The shop panel's frames (the way a player sees them over the game): the real server and client boot on the mock
engine, a player with some Shards, a few tiers into the Turf Pass and a few things owned opens the panel, and the
shop tab, its first-time tour, a confirm dialog, a celebration, the pass tab and the locker are caught.

  luaurun tools/gameplay/shop.luau <outDir>
  node tools/gameplay/render.js <outDir> <pngDir> --modules <node_modules> --chromium <chrome>
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Capture = loadModule("tools/gameplay/Capture.luau")
local V3, CF = Engine.Vector3, Engine.CFrame
local Vector2 = Engine.globals.Vector2
local outDir = ARGS[1]
local tree = Engine.mountProject(".")
Engine.require(tree.shared.Constants).TUTORIAL = false -- (the players here know the game)
-- (a real date: 9 days and a bit into season 1, so the timers read like they would)
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
local Match = service("MatchService")
local Teams = service("TeamService")
local foe = Engine.addPlayer("Foe", 901)
Engine.advance(0.3)
Engine.fireServer(foe, "Ready")
local player = Engine.addPlayer("Ava", 501)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.runScript(tree.client.Main)
Engine.advance(1.5)
Match:NewMatch("castle")
Engine.advance(1)
local team = Teams:Team(player)
local s = team == "red" and -1 or 1
local eye = V3.new(s * 6, 4.6, 30)
local look = V3.new(-s * 40, 3.5, 26)
Engine.moveTo(player, V3.new(s * 6, 3, 30), look)

-- a player some way in: Shards, a few tiers, a few things owned and worn
local Data = service("PlayerDataService")
local Economy = service("EconomyService")
local p = Data:Get(player)
Economy:Add(player, 1240)
service("SeasonService"):AddXP(player, 800 * 3 + 320)
for _, key in { "shop_inkline", "shop_graphite", "shop_confetti", "shop_diamond", "shop_t_sniper" } do
	Economy:Give(player, key)
end
p.equipped.trail = "shop_inkline"
service("ProgressService"):Push(player)
Engine.advance(0.5)

local Panel = Engine.require(tree.client.Controllers.PanelController)
local pr = Panel.refs
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

-- the first time: the tour
Panel.open("shop")
Engine.advance(0.5)
shot("shop_tour")
Panel.tourStep(2)
Engine.advance(0.5)
shot("shop_tour2")
Panel.finishTour()
Engine.advance(0.3)
shot("shop")
pr.body.CanvasPosition = Vector2.new(0, pr.packsY - 6)
shot("shop_packs")
pr.body.CanvasPosition = Vector2.new(0, pr.packsY + 214)
shot("shop_pass_cards")
pr.body.CanvasPosition = Vector2.new(0, pr.todayY - 30)
Engine.advance(0.1)
-- a price tapped: the confirm dialog (the first item you don't have)
for i = 1, 4 do
	local c = pr.body:FindFirstChild("Item" .. i)
	if c and c.Buy:FindFirstChild("Price") then
		c.Buy.Activated:Fire()
		break
	end
end
Engine.advance(0.5)
shot("shop_confirm")
-- (the mock's tweens don't run: with Reduced Motion the confetti snaps out to where it flies, for the picture)
local GuiService = Engine.game:GetService("GuiService")
GuiService.ReducedMotionEnabled = true
pr.confirm.Yes.Activated:Fire()
Engine.advance(0.3)
shot("shop_bought")
GuiService.ReducedMotionEnabled = false
Panel.closeDialog()
-- not enough
Panel.open("shop")
pr.body.Featured.BuyBundle.Activated:Fire()
Engine.advance(0.5)
shot("shop_notenough")
Panel.closeDialog()
Panel.open("pass")
Engine.advance(0.5)
shot("pass")
Panel.open("locker")
Engine.advance(0.5)
shot("locker")
local http = Engine.game:GetService("HttpService")
writeFile(outDir .. "/index.json", http:JSONEncode(shots))
print("shots", #shots)
