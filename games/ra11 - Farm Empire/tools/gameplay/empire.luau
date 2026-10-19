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
shot("first_minute", at(mine, -40, -205, 34), at(mine, -40, -110, 0), false)
Crops:Plant(player, Crops:Tiles(player)[1])
Engine.advance(11)
shot("first_crop", at(mine, -30, -78, 12), at(mine, -20, -52, 1), false)
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
	shot("build_pads", at(mine, -130, -188, 18), at(mine, -130, -138, 1), false)
	-- the stock yard filling up (the crates are the local player's own)
	pa.stock.strawberry = 26
	pa.stock.tomato = 10
	Engine.advance(2.5)
	shot("stock_yard", at(mine, 14, -164, 10), at(mine, 0, -138, 2), false)
end

-- the player's own farm is only ever theirs: the others' farms are seen as a visitor would
-- Cal's shop and its line, the crops up close
Engine.advance(6)
shot("fruit_shop", at(cals, 28, -190, 18), at(cals, 0, -140, 4), true)
shot("shop_line", at(cals, -16, -176, 7), at(cals, 2, -150, 3), true)
shot("fields_growing", at(cals, 60, -90, 30), at(cals, -30, -30, 0), true)
Crops:PlantAll(cal)
Engine.advance(10)
shot("crops_close", at(cals, -20, -70, 9), at(cals, -10, -48, 0), true)

-- Ben's empire: the centre and its docks, the fleet in the fields, an overview
shot("warehouse_docks", at(theirs, 120, -195, 30), at(theirs, 60, -115, 4), true)
shot("distribution_centre", at(theirs, -40, -230, 50), at(theirs, 0, -115, 6), true)
shot("animal_pens", at(theirs, 152, -190, 24), at(theirs, 152, -120, 2), true)
shot("machines_at_work", at(theirs, 110, -80, 26), at(theirs, 20, -30, 1), true)
shot("empire_overview", at(theirs, 0, -400, 280), at(theirs, 0, -20, 0), true)

-- the city: the courtyard, the leaderboards, the store and the market hall, the boost tower, the streets, the map
shot("city_courtyard", V3.new(-48, 30, -80), V3.new(0, 6, 18), true)
shot("leaderboards", V3.new(0, 12, 18), V3.new(0, 9, 56), true)
shot("city_store", V3.new(-14, 10, 18), V3.new(-50, 8, 38), true)
shot("market_hall", V3.new(14, 10, 18), V3.new(50, 8, 38), true)
shot("boost_tower", V3.new(22, 12, -14), V3.new(0, 12, -46), true)
shot("city_streets", V3.new(0, 100, -190), V3.new(0, 10, 10), true)
shot("map_overview", V3.new(0, 480, -760), V3.new(0, 0, 60), true)

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
	shot("panel_upgrades", at(mine, -40, -205, 34), at(mine, -40, -110, 0), false)
	Bus.Panel:Fire("shop")
	Engine.advance(0.5)
	shot("panel_shop", at(mine, -40, -205, 34), at(mine, -40, -110, 0), false)
	Bus.Panel:Fire("boost")
	Engine.advance(0.5)
	shot("panel_boost", at(mine, -40, -205, 34), at(mine, -40, -110, 0), false)
	Bus.Panel:Fire(nil)
	Net.fire(
		player,
		"Away",
		{ seconds = 5 * 3600, counted = 4 * 3600, earned = 18250, ripe = 24, capped = true, hours = 4 }
	)
	Engine.advance(1)
	shot("away_card", at(mine, -40, -205, 34), at(mine, -40, -110, 0), false)
	Engine.require(tree.client.Controllers.AwayController).refs.card.Visible = false
end
-- Ava's own warehouse (the stock is drawn for the local player): the racks full, pallets spilling into the yard
do
	local pa = Data:Get(player)
	for _, key in { "shop", "warehouse", "racks", "racks", "dock" } do
		pa.cash = 10 ^ 12
		Upg:Buy(player, key)
	end
	pa.cash = 0
	local cap = Business:Capacity(player)
	pa.stock = { corn = math.floor(cap * 0.5), pumpkin = math.floor(cap * 0.35) }
	Engine.advance(3)
	CameraC.skip()
	Engine.advance(0.2)
	shot("warehouse_inside", at(mine, 0, -40, 22), at(mine, 0, -105, 6), false)
	shot("pallet_yard", at(mine, -50, -180, 24), at(mine, -79, -112, 2), false)
	shot("warehouse_front", at(mine, 30, -215, 30), at(mine, 0, -125, 8), false)
end
_ = Business
local http = Engine.game:GetService("HttpService")
writeFile(outDir .. "/index.json", http:JSONEncode(shots))
print("shots", #shots)
