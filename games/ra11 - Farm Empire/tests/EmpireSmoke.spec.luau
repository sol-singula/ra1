--[[
The later game and the town: a rich farmer builds the warehouse and the centre (the world rebuilds, trucks take
loads out in bulk and pay more, the docks count), the machine clears a full field, the bottleneck turns to
dispatch, the town's boost meter lights a boost for everyone and the numbers double, the shop grants, the
welcome-back card pays with a machine, the data survives leaving and coming back, visiting works.

  luaurun tests/EmpireSmoke.spec.luau
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
local Auto = service("AutomationService")
local Boost = service("BoostService")
local Shop = service("ShopService")
local Territory = service("TerritoryService")
local Economy = service("EconomyService")
local Upgrades = Engine.require(tree.shared.Data.Upgrades)
local Layout = Engine.require(tree.shared.World.Layout)

local player = Engine.addPlayer("Ben", 902)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.runScript(tree.client.Main)
Engine.advance(2)
local p = Data:Get(player)
local function buy(key)
	p.cash = math.max(p.cash, Upgrades.cost(key, p.owned[key] or 0) + 1)
	local ok, why = Upg:Buy(player, key)
	return ok, why
end

-- Up to the warehouse ----------------------------------------------------------------------------------------------------
check("the warehouse needs the shop first", select(2, Upg:Buy(player, "warehouse")) == "stage")
for _, key in
	{ "tiles", "counter", "seeder", "tomato", "sign", "wheat", "field2", "harvester", "corn", "tractor", "shop" }
do
	check("buy " .. key, buy(key), key)
end
check("the stage is the shop", p.stage == "shop")
check(
	"the warehouse is the preview now",
	(function()
		local t = Territory:Territory(player)
		local g = t.model.Preview and t.model.Preview:FindFirstChild("Ghost")
		return g and g:GetAttribute("Upgrade") == "warehouse"
	end)()
)
check("buy the warehouse", buy("warehouse") and p.stage == "warehouse")
Engine.advance(0.5)
local t = Territory:Territory(player)
check(
	"...it stands at the back, with a dock and a truck",
	t.model.Buildings:FindFirstChild("Warehouse") ~= nil and #t.model.Buildings.Trucks:GetChildren() == 1
)
check(
	"...the shop stays at the front",
	t.model.Buildings.Business.Sign:FindFirstChildOfClass("SurfaceGui").TextLabel.Text == "FRUIT SHOP"
)
check("the client's camera got the reveal", Engine.require(tree.client.Controllers.CameraController).playing())

-- Trucks ---------------------------------------------------------------------------------------------------------------------
Crops:PlantAll(player)
local n = Business:Numbers(player)
check("the docks dispatch", n.dispatch > 0 and n.docks == 1, n.dispatch)
p.stock.corn = 1000
local cash0, trucks0 = p.cash, p.stats.trucks or 0
Engine.advance(Business.TRUCK_LOAD / n.dispatch * 60 + 3)
check("a truck took a load in bulk", (p.stats.trucks or 0) > trucks0, p.stats.trucks)
check("...and paid more than the counter", p.cash - cash0 >= Business.TRUCK_LOAD * 18 * 1.4 * 0.5, p.cash - cash0)
check("...the client drove it", Engine.require(tree.client.Controllers.LogisticsController).trips() >= 1)
check(
	"two docks after the Loading Dock",
	buy("dock") and Business:Numbers(player).docks == 2 and #t.model.Buildings.Trucks:GetChildren() == 2
)

-- The machine on a full field, and the bottleneck ------------------------------------------------------------------------------
buy("field3")
Crops:PlantAll(player)
local s = Crops:Summary(player)
check("the fields are full", s.tiles == 68 and s.planted == 68, s.tiles)
local harvested0 = p.stats.harvested
Engine.advance(120)
check("the tractor cleared a lot of corn", p.stats.harvested - harvested0 >= 100, p.stats.harvested - harvested0)
check(
	"the machine's client-side target is a tile",
	Engine.require(tree.client.Controllers.MachineController).at() ~= nil
)
p.stock.corn = Business:Capacity(player)
check(
	"a full warehouse: the bottleneck is the storage or the docks",
	Business:Bottleneck(player) == "dispatch" or Business:Bottleneck(player) == "storage",
	Business:Bottleneck(player)
)
check("...and there's a recommendation", Upg:Recommend(player) ~= nil)
p.stock.corn = 100

-- The centre -------------------------------------------------------------------------------------------------------------------
for _, key in { "combine", "melon", "racks" } do
	buy(key)
end
check("buy the centre", buy("center") and p.stage == "center")
Engine.advance(0.3)
check(
	"...the warehouse grew",
	t.model.Buildings.Warehouse.Sign:FindFirstChildOfClass("SurfaceGui").TextLabel.Text == "DISTRIBUTION CENTRE"
)
check(
	"the fleet: two machines",
	buy("fleet") and Engine.advance(0.3) == nil and t.model.Buildings.Shed:FindFirstChild("Machine2") ~= nil
)
check("the region is the last preview", t.model.Preview.Ghost:GetAttribute("Upgrade") == "region")

-- The town's boost ---------------------------------------------------------------------------------------------------------------
local other = Engine.addPlayer("Cal", 903)
Engine.advance(2)
local demand0 = Business:Numbers(other).demand
p.cash = 10 ^ 6
check("chipping in fills the meter", Boost:Contribute(player, 1000) and not Boost:Current())
check(
	"...full, it lights the next boost",
	Boost:Contribute(player, 1500) and Boost:Current() ~= nil and Boost:Current().key == "harvestRush"
)
check("...for everyone", Auto:Rate(other) == 0 and Auto:Rate(player) == Auto.RATES[4] * 2)
check("...no chipping in while one is on", not Boost:Contribute(player, 100))
Engine.advance(0.5)
local b = Engine.require(tree.client.Store).get("boost")
check("the client sees it", b and b.active == "harvestRush" and b.seconds > 500, b and b.active)
check(
	"the shop lights one at once (Studio: free)",
	Shop:Grant(player, "customerRush") and Boost:Current().key == "customerRush"
)
check("...twice the customers, for the other farmer too", Business:Numbers(other).demand == demand0 * 2)
check(
	"a cash crate pays by income",
	(function()
		local c = p.cash
		Shop:Grant(player, "cashSmall")
		return p.cash > c
	end)()
)
check("a pass is kept", Shop:Grant(player, "nightShift") and p.passes.nightShift == true)

-- Visiting ----------------------------------------------------------------------------------------------------------------------
local otherT = Territory:Territory(other)
Engine.fireServer(player, "Visit", "go", otherT.index)
Engine.advance(0.2)
local hrp = player.Character.HumanoidRootPart
check(
	"a visit puts you at their gate",
	Layout.territoryAt(hrp.Position) == otherT.index,
	Layout.territoryAt(hrp.Position)
)
Engine.fireServer(player, "Visit", "home")
Engine.advance(0.2)
check("...and home again", Layout.territoryAt(hrp.Position) == t.index)
Engine.fireServer(player, "Visit", "town")
Engine.advance(0.2)
check("...or the town", Layout.territoryAt(hrp.Position) == nil)

-- Leaving and coming back ----------------------------------------------------------------------------------------------------------
local earned = p.stats.earned
local stage, owned = p.stage, 0
for _ in p.owned do
	owned += 1
end
Engine.removePlayer(player)
Engine.advance(1)
-- (away three hours: the save's lastSeen is moved back)
local store = Engine.dataStores["FE_Profiles_v1"]
local saved = store and store["u_902"]
check("the profile saved", saved ~= nil and saved.stage == "center", saved and saved.stage)
saved.away.at = Engine.globals.os.time() - 3 * 3600
saved.away.rate = 500
local again = Engine.addPlayer("Ben", 902)
Engine.Players.LocalPlayer = again
Engine.localPlayer = again
Engine.advance(1)
Engine.fireServer(again, "Ready")
Engine.advance(3)
local p2 = Data:Get(again)
local owned2 = 0
for _ in p2.owned do
	owned2 += 1
end
check("everything is still there", p2.stage == stage and owned2 == owned and p2.stats.earned > earned)
check(
	"...the welcome-back paid three hours at half rate",
	p2.stats.earned - earned >= 500 * 0.5 * 180 * 0.99,
	p2.stats.earned - earned
)
check("...and the card went out", Engine.lastClientEvent("Away", again) ~= nil)
check(
	"the world is built again",
	Territory:Territory(again) and Territory:Territory(again).model.Buildings:FindFirstChild("Warehouse") ~= nil
)
check("income a minute is a real number", Economy:Income(again) >= 0)

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
print(`EmpireSmoke: {passed} passed, {failed} failed`)
if failed > 0 then
	error(`{failed} failed`)
end
