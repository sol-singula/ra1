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
local Format = Engine.require(tree.shared.Format)
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
local stageAt = {} -- [stage] = the minute it was reached
local earnedAt = {} -- [minute] = earned by then
local Animals = service("AnimalService")
local start = Engine.now()
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
		-- the things to do while the money comes in: feed and pet the animals, tap the golden crop
		for _, a in { "chicken", "pig", "cow", "sheep" } do
			if (p.owned[a] or 0) > 0 then
				local st = Animals:State(player)[a]
				if st and (not st.fed or st.petIn == 0) then
					Animals:Care(player, a)
				end
			end
		end
		local g = Crops:Golden(player)
		if g then
			Crops:TapGolden(player, g)
		end
		local minute = math.floor((Engine.now() - start) / 60)
		if not earnedAt[minute] then
			earnedAt[minute] = math.floor(p.stats.earned or 0)
		end
		seen[Business:Bottleneck(player)] = true
		stageAt[p.stage] = stageAt[p.stage] or math.floor((Engine.now() - start) / 6) / 10
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
	"three minutes in: tiles, chickens, tomatoes, a counter, premium produce",
	(p.owned.tiles or 0) >= 1
		and (p.owned.chicken or 0) >= 1
		and (p.owned.tomato or 0) >= 1
		and (p.owned.counter or 0) >= 1
		and (p.owned.premium or 0) >= 1,
	table.concat(bought, ",")
)
check("...the onboarding is done, the recommendation leads", p.task.done, p.task.step)
check("...the chickens were fed or petted", (p.stats.fed or 0) >= 1, p.stats.fed)
play(120)
check("five minutes in: about a million earned", (p.stats.earned or 0) >= 500000, p.stats.earned)
check("...the Fruit Shop came within five minutes", (stageAt.shop or 99) <= 5, stageAt.shop)
check("...a buy came at least every 150 s", longestGap <= 150, longestGap)
local rec, bottleneck = Upg:Recommend(player)
check(
	"the recommendation names a bottleneck",
	rec ~= nil and bottleneck ~= nil,
	tostring(rec) .. " " .. tostring(bottleneck)
)
play(300)
check("ten minutes in: the Warehouse", (stageAt.warehouse or 99) <= 10, stageAt.warehouse)
check("...golden crops tapped", (p.stats.golden or 0) >= 3, p.stats.golden)
check("...a farm of animals", (p.owned.pig or 0) >= 1 and (p.owned.cow or 0) >= 1, table.concat(bought, ","))
check(
	"...the store fell behind at some point: selling was the limit, or the stock full",
	(p.stats.bottleneck or 0) > 0 or seen.service,
	(function()
		local keys = {}
		for k in seen do
			table.insert(keys, k)
		end
		return table.concat(keys, ",")
	end)()
)
play(1200)
check("thirty minutes in: the East Field", (p.owned.field2 or 0) >= 1, table.concat(bought, ","))
check(
	"...the climb slows after the warehouse: the centre not before twenty minutes",
	(stageAt.center or 99) >= 20,
	stageAt.center
)
play(1200)
check(
	"fifty minutes in: the Distribution Centre",
	p.stage == "center",
	`stage {p.stage}, cash {p.cash}, bought {table.concat(bought, ",")}`
)
check(
	"...the front was rebuilt",
	(function()
		local t = service("TerritoryService"):Territory(player)
		for _, d in t.model.Buildings:GetDescendants() do
			if d:IsA("TextLabel") and (d.Text == "WAREHOUSE" or d.Text == "DISTRIBUTION CENTRE") then
				return true
			end
		end
		return false
	end)()
)
check("...the client knows", Store.get("business").stage == p.stage and Store.get("business").workers >= 2)
check("...income a minute is real", p.cash > 0 and service("EconomyService"):Income(player) > 0)
do
	local parts = {}
	for m = 0, 50, 1 do
		if earnedAt[m] and (m <= 10 or m % 5 == 0) then
			table.insert(parts, `{m}m {Format.cash(earnedAt[m])}`)
		end
	end
	print("  earned: " .. table.concat(parts, " · "))
end
print(`  stages (minute): shop {stageAt.shop}, warehouse {stageAt.warehouse}, centre {stageAt.center}`)
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
