--[[
The loop, on the real numbers (master plan §3, §7): a farmer plays the first stretch through the client's own
requests, planting and harvesting by tapping, buying what the task card recommends, and the pacing holds: the
first sale inside a minute, a buy affordable every little while, the store bottleneck showing up and the
recommendation answering it, the seeder and the harvester taking over, the shop transforming the front.

  luaurun tests/LoopSmoke.spec.luau
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Vector2 = Engine.globals.Vector2

local passed, failed = 0, 0
local function check(name, cond, detail)
	if cond then
		passed += 1
	else
		failed += 1
		print("FAIL " .. name .. (detail ~= nil and (": " .. tostring(detail)) or ""))
	end
end

local tree = Engine.mountProject(".")
Engine.clientEnabled = true
Engine.workspace.CurrentCamera.ViewportSize = Vector2.new(1240, 560)
Engine.runScript(tree.server.Main)
Engine.advance(0.5)
local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Data = service("PlayerDataService")
local Crops = service("CropService")
local Business = service("BusinessService")
local Upg = service("UpgradeService")
local Tasks = service("TaskService")
local Auto = service("AutomationService")
local Upgrades = Engine.require(tree.shared.Data.Upgrades)

local player = Engine.addPlayer("Ava", 901)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.runScript(tree.client.Main)
Engine.advance(2)
local p = Data:Get(player)
local Store = Engine.require(tree.client.Store)
local CropC = Engine.require(tree.client.Controllers.CropController)
local TaskC = Engine.require(tree.client.Controllers.TaskController)
local HudC = Engine.require(tree.client.Controllers.HudController)
local CustomerC = Engine.require(tree.client.Controllers.CustomerController)

-- The first minute, through the client ---------------------------------------------------------------------------------
check("the task says plant", TaskC.state().primary.key == "plant1")
check("the opening played", Engine.require(tree.client.Controllers.CameraController).playing())
local first = Crops:Tiles(player)[1]
check("a tap on the empty tile plants it", CropC.tap(first) and Engine.advance(0.3) == nil and p.tiles[first] ~= nil)
check(
	"...the task moved on",
	(function()
		Engine.advance(1.2)
		return TaskC.state().primary.key == "harvest1"
	end)()
)
check("...a plant is drawn", CropC.plants() >= 1, CropC.plants())
Engine.advance(10.5)
check("the tile is ripe", Crops:Ripe(player, first))
check("a tap harvests it", CropC.tap(first) and Engine.advance(0.3) == nil and (p.stats.harvested or 0) == 1)
Engine.advance(8)
check("a customer bought it in the first minute", (p.stats.sold or 0) >= 1 and p.cash >= 3, p.cash)
check("...the HUD shows the cash", HudC.refs.cash.Text ~= "$0", HudC.refs.cash.Text)
check("...a shopper walked up", CustomerC.walking() >= 1)
check("the task: plant everything", TaskC.state().primary.key == "plantAll", TaskC.state().primary.key)
Engine.fireServer(player, "Crop", "plantAll")
Engine.advance(1.5)
check("...PLANT ALL planted the four", Crops:Summary(player).planted == 4)
check("the task: buy tiles", TaskC.state().primary.key == "tiles1", TaskC.state().primary.key)

-- Play on: harvest by hand as things ripen, buy whatever the task says when affordable -----------------------------------
local bought = {}
local lastBuyAt = 0
local longestGap = 0
local seen = {} -- the bottlenecks the business reported
local function play(seconds)
	local t0 = Engine.now()
	while Engine.now() - t0 < seconds do
		Engine.advance(2)
		if Upgrades.machine(p.owned) == 0 then
			for _, id in Crops:RipeList(player) do
				Crops:Harvest(player, id, "hand")
			end
		end
		Crops:PlantAll(player) -- (PLANT ALL: one tap)
		seen[Business:Bottleneck(player)] = true
		local pr = Tasks:Primary(player)
		if pr and pr.kind == "upgrade" and pr.target and pr.affordable then
			if Upg:Buy(player, pr.target) then
				table.insert(bought, pr.target)
				longestGap = math.max(longestGap, Engine.now() - lastBuyAt)
				lastBuyAt = Engine.now()
			end
		end
	end
end
play(180)
check(
	"three minutes in: tiles, a counter and the seeder are bought",
	(p.owned.tiles or 0) >= 1 and (p.owned.counter or 0) >= 1 and (p.owned.seeder or 0) >= 1,
	table.concat(bought, ",")
)
check("...the onboarding is nearly done", p.task.step >= 7 or p.task.done, p.task.step)
play(420)
check(
	"ten minutes in: a second crop and a sign",
	(p.owned.tomato or 0) >= 1 and (p.owned.sign or 0) >= 1,
	table.concat(bought, ",")
)
check("...the onboarding is done, the recommendation leads", p.task.done)
check("...a buy came at least every 150 s", longestGap <= 150, longestGap)
local rec, bottleneck = Upg:Recommend(player)
check(
	"the recommendation names a bottleneck",
	rec ~= nil and bottleneck ~= nil,
	tostring(rec) .. " " .. tostring(bottleneck)
)
play(600)
check("twenty minutes in: the harvester", (p.owned.harvester or 0) >= 1, table.concat(bought, ","))
check("...the machine is working", Auto:Rate(player) > 0 and (p.stats.harvested or 0) > 100, p.stats.harvested)
check(
	"...the store fell behind at some point: a line, or the storage full",
	(p.stats.bottleneck or 0) > 0 or seen.service or seen.storage,
	(function()
		local keys = {}
		for k in seen do
			table.insert(keys, k)
		end
		return table.concat(keys, ",")
	end)()
)
play(900)
check(
	"thirty-five minutes in: the tractor and the East Field",
	(p.owned.tractor or 0) >= 1 and (p.owned.field2 or 0) >= 1,
	table.concat(bought, ",")
)
play(900)
check(
	"fifty minutes in: the Fruit Shop",
	p.stage == "shop",
	`stage {p.stage}, cash {p.cash}, bought {table.concat(bought, ",")}`
)
check(
	"...the front was rebuilt as a shop",
	(function()
		local t = service("TerritoryService"):Territory(player)
		local b = t.model.Buildings.Business
		return b:FindFirstChild("Sign") ~= nil
			and b.Sign:FindFirstChildOfClass("SurfaceGui").TextLabel.Text == "FRUIT SHOP"
	end)()
)
check("...the client knows", Store.get("business").stage == p.stage and Store.get("business").workers >= 2)
check("...income a minute is real", p.cash > 0 and service("EconomyService"):Income(player) > 0)
print(`  bought in order: {table.concat(bought, " > ")}`)
print(
	`  at 50 min: cash {math.floor(p.cash)}, earned {math.floor(p.stats.earned)}, harvested {p.stats.harvested}, sold {p.stats.sold}, stage {p.stage}`
)

do
	local bad = {}
	for _, w in Engine.warnings do
		if tostring(w):find("failed") then
			table.insert(bad, tostring(w))
		end
	end
	check("no failed saves, ticks or boots", #bad == 0, bad[1])
end
if #Engine.errors > 0 then
	for _, e in Engine.errors do
		print("ERROR " .. tostring(e))
	end
	failed += #Engine.errors
end
print(`LoopSmoke: {passed} passed, {failed} failed`)
if failed > 0 then
	error(`{failed} failed`)
end
