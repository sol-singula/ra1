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
pb.cash = 10 ^ 6
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
	shot("farm_orders_panel", at(mine, 16, -100, 12), at(mine, 22, -72, 2), false)
end
local http = Engine.game:GetService("HttpService")
writeFile(outDir .. "/index.json", http:JSONEncode(shots))
print("shots", #shots)
