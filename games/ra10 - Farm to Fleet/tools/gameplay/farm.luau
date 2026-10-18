--[[
Farm to Fleet, the way a player sees it: the real server and client boot on the mock engine, two players on the
street (one just started, one with all of stage 1 bought and a field of ripe crops), and the street from above, a
new farm, a finished stage-1 farm and the first minute (the guide's arrow and path, the PLANT button) are caught.

  luaurun tools/gameplay/farm.luau <outDir>
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
UIS.TouchEnabled, UIS.KeyboardEnabled = true, false
Engine.runScript(tree.server.Main)
Engine.advance(0.3)
local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Farm = service("FarmService")
local Upg = service("UpgradeService")
local Economy = service("EconomyService")
local Data = service("PlayerDataService")
local Plots = service("PlotService")
local Upgrades = Engine.require(tree.shared.Data.Upgrades)
local PlotLayout = Engine.require(tree.shared.World.PlotLayout)

-- Ben: everything up to stage 3 (the shed, its vans and machines), a field of crops (ripe and growing)
local ben = Engine.addPlayer("Ben", 902)
Engine.advance(1)
local pb = Data:Get(ben)
pb.cash = 10 ^ 9
for _, key in Upgrades.LIST do
	Economy:AddXP(ben, 400, "render")
	Upg:Buy(ben, key)
end
local Animal = service("AnimalService")
for _, key in { "chicken", "pig", "sheep", "cow" } do
	for _ = 1, ({ chicken = 9, pig = 6, sheep = 4, cow = 2 })[key] do
		Animal:Upgrade(ben, key)
	end
	pb.animals[key].fedAt = Engine.workspace:GetServerTimeNow()
end
for n = 1, 39 do
	local key = n % 3 == 0 and "corn" or (n % 3 == 1 and "strawberry" or "carrot")
	pb.soil[tostring(n)] = nil
	Farm:Plant(ben, n, key)
end
Engine.advance(40)
for _ = 1, 3 do
	Engine.advance(2)
end

-- Ava: just arrived (the local player)
local player = Engine.addPlayer("Ava", 501)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.runScript(tree.client.Main)
Engine.advance(2)
Engine.require(tree.client.UI.Bus).Panel:Fire(nil) -- (the day's reward opened its panel by itself: the shots want the farm)
local mine = Plots:Plot(player).index
local theirs = Plots:Plot(ben).index

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
	return PlotLayout.toWorld(i, x, z, y)
end

-- the first minute: behind the player at the spawn, the guide's arrow over the soil
shot("farm_first_minute", at(mine, -44, -122, 14), at(mine, -30, -78, 0), false)
-- standing by the soil: the PLANT button
Engine.moveTo(player, at(mine, -28, -86, 3), at(mine, -28, -78, 3))
Engine.advance(0.5)
shot("farm_plant_button", at(mine, -30, -100, 12), at(mine, -26, -76, 0), false)
-- Ben's finished stage-1 farm
shot("farm_stage1_done", at(theirs, 30, -130, 40), at(theirs, -36, -70, 0), true)
shot("farm_field_close", at(theirs, -8, -96, 10), at(theirs, -22, -74, 1), true)
-- Ben's stage 2: the barn, the fields, the machines, the pens
shot("farm_stage2_overview", at(theirs, 60, -120, 70), at(theirs, -40, 10, 0), true)
shot("farm_barn", at(theirs, -10, -62, 14), at(theirs, -44, -18, 6), true)
shot("farm_pens", at(theirs, -41, 12, 18), at(theirs, -41, 70, 0), true)
shot("farm_cows_close", at(theirs, -41, 64, 9), at(theirs, -22, 84, 1), true)
-- Ben's stage 3: the packing shed, its yard and board, a van backed up to the loading door, the other parked
do
	local van = Plots:Plot(ben).items.van:FindFirstChild("Vehicle")
	van:SetAttribute("TripStart", Engine.workspace:GetServerTimeNow() - 0.26 * 20)
	van:SetAttribute("TripLength", 20)
	Engine.advance(2.2)
	van:SetAttribute("TripStart", Engine.workspace:GetServerTimeNow() - 0.26 * 20)
	Engine.advance(0.1)
end
shot("farm_shed_overview", at(theirs, -20, -150, 40), at(theirs, 40, -66, 0), true)
shot("farm_shed_door", at(theirs, 18, -100, 9), at(theirs, 44, -74, 4), true)
shot("farm_order_board", at(theirs, 10, -96, 7), at(theirs, 8, -80, 5), true)
shot("farm_shed_machines", at(theirs, 90, -100, 22), at(theirs, 50, -60, 2), true)
-- Ben's stage 4: the warehouse full of pallets, forklifts on their loops, a truck at the door, the rest in the lot
do
	local pb2 = Data:Get(ben)
	pb2.flow = pb2.flow or {}
	pb2.flow.racked = 150
	pb2.flow.staged = 4
	pb2.flow.inbound = 5000
	local items = Plots:Plot(ben).items
	local t = Engine.workspace:GetServerTimeNow()
	for _, d in items:GetDescendants() do
		if d.Name == "Vehicle" and d:GetAttribute("Kind") == "truck" and d:GetAttribute("Park") == 1 then
			pb2.flow.trucks = { ["1"] = { at = t - 0.33 * 45, length = 45, pallets = 6 } }
			d:SetAttribute("TripStart", t - 0.33 * 45)
			d:SetAttribute("TripLength", 45)
		end
	end
	Engine.advance(3)
end
shot("warehouse_exterior", at(theirs, 96, -96, 46), at(theirs, 36, -24, 4), true)
shot("warehouse_ops", at(theirs, 42, -45, 5), at(theirs, 42, -36, 9), true)
Engine.advance(0.2)
shot("warehouse_inside", at(theirs, 40, -33, 17), at(theirs, 36, 8, 0), true)
Engine.advance(0.2)
shot("warehouse_racks", at(theirs, 64, -6, 6), at(theirs, 20, -6, 4), true)
shot("warehouse_lot", at(theirs, 90, 70, 30), at(theirs, 50, 30, 2), true)
shot("farm_operation_overview", at(theirs, -70, -170, 120), at(theirs, 10, -10, 0), true)
-- Ben's stage 5: the hub has taken over the front: the hall, the tower, the solar roof, the market, the docks
shot("hub_overview", at(theirs, -95, -195, 150), at(theirs, 5, -25, 0), true)
shot("hub_facade", at(theirs, 28, -104, 13), at(theirs, 36, -74, 9), true)
Engine.advance(0.2)
shot("hall_inside", at(theirs, 26, -71, 15), at(theirs, 50, -50, 2), true)
shot("market_front", at(theirs, -15, -130, 12), at(theirs, -15, -100, 6), true)
Engine.advance(0.2)
shot("market_inside", at(theirs, -32, -105, 8), at(theirs, -4, -92, 2), true)
-- two semis: one backed up to its dock, one coming up the lane
do
	local pb3 = Data:Get(ben)
	local t = Engine.workspace:GetServerTimeNow()
	pb3.flow.trucks.s1 = { at = t - 0.6 * 102, length = 102, pallets = 24 }
	pb3.flow.trucks.s2 = { at = t - 0.33 * 102, length = 102, pallets = 24 }
	local wh = service("WarehouseService")
	for _, key in { "warehouse" } do
		Upg.Applied:Fire(ben, Upgrades[key])
	end
	_ = wh
	Engine.advance(2.2)
end
shot("hub_docks", at(theirs, 92, 96, 32), at(theirs, 40, 30, 4), true)
shot("hub_semis", at(theirs, 2, 70, 22), at(theirs, 26, 36, 4), true)
-- the street from above
shot("farm_street", V3.new(0, 160, 300), V3.new(0, 0, 0), true)
-- Ava, later: her own shed, the orders panel and today's contracts on screen, standing at PACK ORDERS
do
	local pa = Data:Get(player)
	pa.cash = 10 ^ 6
	for _, key in Upgrades.LIST do
		Economy:AddXP(player, 400, "render")
		Upg:Buy(player, key)
		if key == "orderBoard" then
			break
		end
	end
	pa.guide.step = 999
	Engine.advance(2)
	local order = service("OrderService")
	local first = order:Slots(player)[1]
	for key, n in first.items do
		first.packed[key] = math.floor(n / 2)
	end
	pa.stats.harvested = (pa.stats.harvested or 0) + 40
	order:Push(player)
	local pad = order:PackPad(player)
	Engine.moveTo(player, pad.Position + V3.new(0, 3, -6), pad.Position + V3.new(0, 3, 0))
	Engine.advance(1)
	service("SpecialService"):Spawn(player)
	Engine.advance(9)
	shot("farm_orders_panel", at(mine, 16, -100, 12), at(mine, 22, -72, 2), false)
	shot("special_express", at(mine, 10, -100, 9), at(mine, -10, -116, 3), true)
end
-- the street watching itself: the STREET gantry, a billboard over Ben's gate, the Hall of Fame
do
	local Street = service("StreetService")
	Economy:Add(ben, 250000, "pallets")
	Economy:Add(ben, 180000, "special")
	Economy:Add(player, 42000, "order")
	Street:Like(player, theirs)
	service("LeaderboardService"):Refresh()
	service("LeaderboardService").page = 1
	service("LeaderboardService"):Paint()
	Engine.advance(Street.TICK + 0.5)
	Engine.require(tree.client.UI.Bus).Panel:Fire(nil)
	Engine.advance(0.2)
	shot("street_board", V3.new(-150, 24, 6), V3.new(-82, 31, 0), true)
	shot("street_billboard", at(theirs, 40, -150, 26), at(theirs, 40, -104, 32), true)
	shot("hall_of_fame", V3.new(150, 24, -6), V3.new(82, 31, 0), true)
end
-- the menu's panels and the welcome-back card
do
	local Bus = Engine.require(tree.client.UI.Bus)
	local Net = Engine.require(tree.shared.Net)
	local Daily = service("DailyService")
	local pa = Data:Get(player)
	pa.calendar = { day = 3, streak = 3, claimedDay = Engine.require(tree.shared.Data.Daily).day() - 1 }
	pa.goldenSeeds = 3
	Daily:Push(player)
	Engine.advance(0.5)
	Bus.Panel:Fire("calendar")
	Engine.advance(0.5)
	shot("panel_daily", at(mine, -44, -122, 14), at(mine, -30, -78, 0), false)
	Bus.Panel:Fire("street")
	Engine.advance(0.5)
	shot("panel_street", at(mine, -44, -122, 14), at(mine, -30, -78, 0), false)
	Bus.Panel:Fire("shop")
	Engine.advance(0.5)
	shot("panel_shop", at(mine, -44, -122, 14), at(mine, -30, -78, 0), false)
	Bus.Panel:Fire(nil)
	Net.fire(player, "Away", {
		seconds = 5 * 3600,
		earned = 184250,
		capped = true,
		hours = 4,
		ripe = 12,
		special = true,
		calendar = { day = 4 },
	})
	Engine.advance(1.5)
	shot("away_card", at(mine, -44, -122, 14), at(mine, -30, -78, 0), false)
	Engine.require(tree.client.Controllers.AwayController).refs.card.Visible = false
end
-- Ben franchises: the FRANCHISE panel (on Ava's screen, as hers would look), then his new farm in Tropical Coast
do
	local Fr = service("FranchiseService")
	local Bus = Engine.require(tree.client.UI.Bus)
	local pa = Data:Get(player)
	pa.owned.marketHall = 1
	pa.stats.earned = 3.6e8
	pa.franchise.stars = 7
	Fr:Push(player)
	Bus.Panel:Fire("franchise")
	Engine.advance(0.5)
	shot("panel_franchise", at(mine, -44, -122, 14), at(mine, -30, -78, 0), false)
	Bus.Panel:Fire(nil)
	pa.owned.marketHall = nil
	Engine.require(tree.client.Controllers.MenuController).show("franchise", false)
	pb.stats.earned = 9e8
	Fr:Sell(ben)
	Engine.advance(2)
	shot("franchise_region", at(theirs, 60, -150, 70), at(theirs, -10, 40, 0), true)
end
local http = Engine.game:GetService("HttpService")
writeFile(outDir .. "/index.json", http:JSONEncode(shots))
print("shots", #shots)
