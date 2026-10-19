--[[
The town's systems: the market board's daily orders (none for a stand, three for a shop, delivered out of stock
for a bonus, once a day), the leaderboards from the shared stores, and a new region (prestige: the farm starts
over with a permanent bonus, the onboarding not repeated, a star on the gate).

  luaurun tests/TownSmoke.spec.luau
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
local Upg = service("UpgradeService")
local Market = service("MarketService")
local Boards = service("LeaderboardService")
local Territory = service("TerritoryService")
local Economy = service("EconomyService")
local Upgrades = Engine.require(tree.shared.Data.Upgrades)
local Crops = Engine.require(tree.shared.Data.Crops)

local player = Engine.addPlayer("Dee", 904)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.runScript(tree.client.Main)
Engine.advance(2)
local p = Data:Get(player)
local function buy(key)
	p.cash = math.max(p.cash, Upgrades.cost(key, p.owned[key] or 0) + 1)
	return Upg:Buy(player, key)
end

-- The market ----------------------------------------------------------------------------------------------------------------
check("no orders for a stand", #Market:Orders(player) == 0)
for _, key in
	{ "tiles", "counter", "seeder", "tomato", "sign", "wheat", "field2", "harvester", "corn", "tractor", "shop" }
do
	buy(key)
end
local orders = Market:Orders(player)
check("three orders for a shop", #orders == 3, #orders)
check(
	"...of crops they've unlocked, with a bonus",
	Crops[orders[1].crop] ~= nil and orders[1].bonus > 1 and orders[1].pays > 0
)
check("can't deliver without the stock", select(2, Market:Deliver(player, orders[1].id)) == "stock")
p.stock[orders[1].crop] = orders[1].n
local cash0 = p.cash
check("delivered out of stock", Market:Deliver(player, orders[1].id) and (p.stock[orders[1].crop] or 0) == 0)
check("...paid the bonus", p.cash - cash0 == orders[1].pays, p.cash - cash0)
check("...once a day", select(2, Market:Deliver(player, orders[1].id)) == "done" and Market:Orders(player)[1].done)
check("...counted toward the goal", (p.stats.orders or 0) == 1)
Engine.advance(0.5)
local MarketC = Engine.require(tree.client.Controllers.MarketController)
Engine.require(tree.client.UI.Bus).Panel:Fire("market")
Engine.advance(0.5)
check(
	"the panel lists them",
	MarketC.refs.rows[1] and MarketC.refs.rows[1].Visible and MarketC.refs.rows[1].Deliver.Text == "DONE",
	MarketC.refs.rows[1] and MarketC.refs.rows[1].Deliver.Text
)
Engine.require(tree.client.UI.Bus).Panel:Fire(nil)

-- Leaderboards -------------------------------------------------------------------------------------------------------------------
Economy:Add(player, 50000, "test")
Boards:Write()
Boards:Refresh()
Engine.advance(0.5)
check(
	"the earned board has them",
	Boards.boards.earned and Boards.boards.earned[1] and Boards.boards.earned[1].userId == 904,
	Boards.boards.earned and #Boards.boards.earned
)
check("...painted on the town's boards", Engine.require(tree.client.Controllers.TownController).painted() >= 1)

-- A new region ---------------------------------------------------------------------------------------------------------------------
for _, key in { "warehouse", "center" } do
	buy(key)
end
Engine.advance(3) -- (the goals that $50,000 completes pay out first)
local earned = p.stats.earned
check("open a new region", buy("region"))
Engine.advance(1)
p = Data:Get(player)
check("...the farm starts over", p.stage == "stand" and next(p.owned) == nil and p.cash == 0 and next(p.tiles) == nil)
check("...with the bonus", p.prestige.level == 1 and Economy:Multiplier(player) == 1.25)
check("...the stats kept, the onboarding not repeated", p.stats.earned == earned and p.task.done)
Engine.advance(1)
local t = Territory:Territory(player)
check(
	"...the world rebuilt as a stand with a star on the gate",
	t.model.Buildings.Business:FindFirstChild("Counter") ~= nil
		and (function()
			for _, d in t.model.Ground.GateSign:GetDescendants() do
				if d:IsA("TextLabel") and d.Text:find("★") then
					return true
				end
			end
			return false
		end)()
)
check(
	"a sale pays 25% more",
	(function()
		p.stock.strawberry = 10
		local c = p.cash
		Engine.advance(8)
		return p.cash - c >= math.floor(3 * 1.25)
	end)()
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
print(`TownSmoke: {passed} passed, {failed} failed`)
if failed > 0 then
	error(`{failed} failed`)
end
