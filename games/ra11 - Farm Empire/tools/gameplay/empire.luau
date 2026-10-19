--[[
Farm Empire, the way a player sees it: the real server and client boot on the mock engine with two farmers (one
just arrived, one with a distribution centre), and the moments that matter are caught: the first minute, a
fruit shop with its line, a warehouse with trucks at the docks, the machines in a full field, the town square,
the whole map from above, and the UI panels.

  luaurun tools/gameplay/empire.luau <outDir>
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
Engine.runScript(tree.server.Main)
Engine.advance(0.3)
local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Data = service("PlayerDataService")
local Crops = service("CropService")
local Upg = service("UpgradeService")
local Territory = service("TerritoryService")
local Business = service("BusinessService")
local Upgrades = Engine.require(tree.shared.Data.Upgrades)
local Layout = Engine.require(tree.shared.World.Layout)

-- Ben: a distribution centre, every field, the fleet
local ben = Engine.addPlayer("Ben", 902)
Engine.advance(1)
local pb = Data:Get(ben)
for _, key in Upgrades.LIST do
	if key ~= "region" then
		pb.cash = 10 ^ 9
		Upg:Buy(ben, key)
	end
end
pb.chosen = "corn"
Crops:PlantAll(ben)
pb.stock.corn = 3000
Engine.advance(35)
local theirs = Territory:Territory(ben).index

-- Cal: a fruit shop with a long line
local cal = Engine.addPlayer("Cal", 903)
Engine.advance(1)
local pc = Data:Get(cal)
for _, key in
	{ "tiles", "tiles", "counter", "seeder", "tomato", "sign", "wheat", "field2", "harvester", "corn", "shop" }
do
	pc.cash = 10 ^ 7
	Upg:Buy(cal, key)
end
pc.chosen = "wheat"
Crops:PlantAll(cal)
pc.stock.wheat = 300
local cals = Territory:Territory(cal).index

-- Ava: just arrived (the local player)
local player = Engine.addPlayer("Ava", 901)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.runScript(tree.client.Main)
Engine.advance(2)
local mine = Territory:Territory(player).index
local CameraC = Engine.require(tree.client.Controllers.CameraController)
CameraC.skip()
Engine.advance(0.2)

local cam = ws.CurrentCamera
local shots = {}
local function shot(name, eye, look, hideMe)
	cam.CFrame = CF.lookAt(eye, look)
	Engine.advance(0.016)
	if hideMe and player.Character then
		for _, d in player.Character:GetDescendants() do
			if d:IsA("BasePart") then
				d.Transparency = 1
			end
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
local function at(i, x, z, y)
	return Layout.toWorld(i, x, z, y)
end

-- the first minute: the stand, the four tiles, the task card and the arrow
shot("first_minute", at(mine, -26, -78, 14), at(mine, -6, -40, 0), false)
Crops:Plant(player, Crops:Tiles(player)[1])
Engine.advance(11)
shot("first_crop", at(mine, -16, -44, 7), at(mine, -6, -28, 1), false)

-- the player's own farm is only ever theirs: the others' farms are seen as a visitor would
-- Cal's shop and its line
Engine.advance(6)
shot("fruit_shop", at(cals, 26, -84, 12), at(cals, 0, -50, 4), true)
shot("shop_line", at(cals, -14, -78, 6), at(cals, 2, -56, 3), true)
shot("fields_growing", at(cals, 30, -20, 16), at(cals, -5, 0, 0), true)

-- Ben's empire: the centre and its docks, the fleet in the fields, an overview
shot("warehouse_docks", at(theirs, 90, 10, 22), at(theirs, 30, 36, 4), true)
shot("distribution_centre", at(theirs, -30, -90, 40), at(theirs, 15, 30, 4), true)
shot("machines_at_work", at(theirs, 60, 30, 14), at(theirs, 0, -10, 1), true)
shot("empire_overview", at(theirs, 0, -170, 110), at(theirs, 0, 10, 0), true)

-- the town square and the whole map
shot("town_square", V3.new(-70, 30, -110), V3.new(0, 4, 0), true)
shot("map_overview", V3.new(0, 420, -520), V3.new(0, 0, 0), true)

-- the UI: the upgrades panel, the shop, the boost panel, the welcome-back card
do
	local Bus = Engine.require(tree.client.UI.Bus)
	local Net = Engine.require(tree.shared.Net)
	local pa = Data:Get(player)
	pa.cash = 400
	Upg:Push(player)
	Engine.advance(0.5)
	Bus.Panel:Fire("upgrades")
	Engine.advance(0.5)
	shot("panel_upgrades", at(mine, -26, -78, 14), at(mine, -6, -40, 0), false)
	Bus.Panel:Fire("shop")
	Engine.advance(0.5)
	shot("panel_shop", at(mine, -26, -78, 14), at(mine, -6, -40, 0), false)
	Bus.Panel:Fire("boost")
	Engine.advance(0.5)
	shot("panel_boost", at(mine, -26, -78, 14), at(mine, -6, -40, 0), false)
	Bus.Panel:Fire(nil)
	Net.fire(
		player,
		"Away",
		{ seconds = 5 * 3600, counted = 4 * 3600, earned = 18250, ripe = 24, capped = true, hours = 4 }
	)
	Engine.advance(1)
	shot("away_card", at(mine, -26, -78, 14), at(mine, -6, -40, 0), false)
	Engine.require(tree.client.Controllers.AwayController).refs.card.Visible = false
end
_ = Business
local http = Engine.game:GetService("HttpService")
writeFile(outDir .. "/index.json", http:JSONEncode(shots))
print("shots", #shots)
