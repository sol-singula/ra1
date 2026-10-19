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
	{ "tiles", "tiles", "counter", "seeder", "tomato", "chicken", "wheat", "field2", "harvester", "corn", "shop" }
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

-- the first minute: from the avenue, the gate, the build yard, the stand and the home field; the arrow on a tile
shot("first_minute", at(mine, -12, -122, 24), at(mine, -18, -56, 0), false)
Crops:Plant(player, Crops:Tiles(player)[1])
Engine.advance(11)
shot("first_crop", at(mine, -16, -62, 8), at(mine, 0, -40, 1), false)
-- the build pads, the guide pointing at the one to step on
do
	local pa = Data:Get(player)
	local TasksData = Engine.require(tree.shared.Data.Tasks)
	for k, st in TasksData.ONBOARDING do
		if st.key == "tiles1" then
			pa.task.step = k
		end
	end
	pa.cash = 200
	service("EconomyService"):Add(player, 1, "test")
	service("TaskService"):Push(player)
	Engine.advance(3)
	shot("build_pads", at(mine, -30, -104, 14), at(mine, -38, -70, 1), false)
	-- the stock yard filling up (the crates are the local player's own)
	pa.stock.strawberry = 26
	pa.stock.tomato = 10
	Engine.advance(2.5)
	shot("stock_yard", at(mine, 12, -94, 12), at(mine, 25, -68, 2), false)
end

-- the player's own farm is only ever theirs: the others' farms are seen as a visitor would
-- Cal's shop and its line, the crops up close
Engine.advance(6)
shot("fruit_shop", at(cals, 22, -118, 16), at(cals, 0, -70, 4), true)
shot("shop_line", at(cals, -14, -106, 6), at(cals, 2, -80, 3), true)
shot("fields_growing", at(cals, 44, -72, 22), at(cals, -20, -32, 0), true)
Crops:PlantAll(cal)
Engine.advance(10)
shot("crops_close", at(cals, -32, -62, 8), at(cals, -32, -40, 0), true)

-- Ben's empire: the centre and its docks, the fleet in the fields, an overview
shot("warehouse_docks", at(theirs, 96, -4, 26), at(theirs, 45, 50, 4), true)
shot("distribution_centre", at(theirs, -24, -14, 44), at(theirs, 31, 50, 4), true)
shot("animal_pens", at(theirs, 50, -100, 16), at(theirs, 50, -68, 2), true)
shot("machines_at_work", at(theirs, 52, -14, 16), at(theirs, 0, -36, 1), true)
shot("empire_overview", at(theirs, 0, -250, 150), at(theirs, 0, 0, 0), true)

-- the city: the courtyard, the leaderboards, the store and the market hall, the boost tower, the streets, the map
shot("city_courtyard", V3.new(-48, 30, -80), V3.new(0, 6, 18), true)
shot("leaderboards", V3.new(0, 12, 18), V3.new(0, 9, 56), true)
shot("city_store", V3.new(-14, 10, 18), V3.new(-50, 8, 38), true)
shot("market_hall", V3.new(14, 10, 18), V3.new(50, 8, 38), true)
shot("boost_tower", V3.new(22, 12, -14), V3.new(0, 12, -46), true)
shot("city_streets", V3.new(0, 100, -190), V3.new(0, 10, 10), true)
shot("map_overview", V3.new(0, 260, -380), V3.new(0, 0, 60), true)

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
	shot("panel_upgrades", at(mine, -12, -122, 24), at(mine, -18, -56, 0), false)
	Bus.Panel:Fire("shop")
	Engine.advance(0.5)
	shot("panel_shop", at(mine, -12, -122, 24), at(mine, -18, -56, 0), false)
	Bus.Panel:Fire("boost")
	Engine.advance(0.5)
	shot("panel_boost", at(mine, -12, -122, 24), at(mine, -18, -56, 0), false)
	Bus.Panel:Fire(nil)
	Net.fire(
		player,
		"Away",
		{ seconds = 5 * 3600, counted = 4 * 3600, earned = 18250, ripe = 24, capped = true, hours = 4 }
	)
	Engine.advance(1)
	shot("away_card", at(mine, -12, -122, 24), at(mine, -18, -56, 0), false)
	Engine.require(tree.client.Controllers.AwayController).refs.card.Visible = false
end
_ = Business
local http = Engine.game:GetService("HttpService")
writeFile(outDir .. "/index.json", http:JSONEncode(shots))
print("shots", #shots)
