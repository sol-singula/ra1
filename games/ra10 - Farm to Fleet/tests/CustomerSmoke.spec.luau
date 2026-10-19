--[[
The Chicken Farm loop on the mock engine, server and client together: the field grows random crops, the customers
are the one bottleneck. Customers come at a rate and buy out of the barn; a shop upgrade brings more; a full barn
makes the guide point at the next shop upgrade; the HUD says how the shop's doing and a shopper walks up to the
stand on the client; the daily contracts live in the DAILY panel; the vans take loads out of the barn and pay 3x;
everything saves.

  luaurun tests/CustomerSmoke.spec.luau
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Vector3 = Engine.Vector3
local Vector2 = Engine.globals.Vector2
local typeof = Engine.globals.typeof

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
local Plots = service("PlotService")
local Farm = service("FarmService")
local Upg = service("UpgradeService")
local Data = service("PlayerDataService")
local Economy = service("EconomyService")
local Customer = service("CustomerService")
local Delivery = service("DeliveryService")
local DailyS = service("DailyService")
local Upgrades = Engine.require(tree.shared.Data.Upgrades)
local Customers = Engine.require(tree.shared.Data.Customers)
local Crops = Engine.require(tree.shared.Data.Crops)
local PlotLayout = Engine.require(tree.shared.World.PlotLayout)

local function now()
	return Engine.workspace:GetServerTimeNow()
end

-- The data ----------------------------------------------------------------------------------------------------------------
do
	local p = { owned = {}, stats = {}, animals = {} }
	check("customers come from the first minute", Customers.rate(p, 0) == Customers.BASE)
	p.owned.sign = 1
	check("...a shop upgrade brings more", Customers.rate(p, 0) == Customers.BASE + Upgrades.sign.value)
	check("...one crop each until the helper", Customers.basket(p.owned) == 1)
	p.owned.shopkeeper = 1
	check(
		"...the helper: two at a time",
		Customers.basket(p.owned) == 2 and Customers.sellRate(p, 0) == (Customers.BASE + Upgrades.sign.value) * 2
	)
	local kinds = {}
	for _, key in Upgrades.LIST do
		kinds[Upgrades[key].kind] = true
	end
	check("no order upgrades are left", not kinds.orders and not kinds.autopack and not kinds.orderPrice)
end

-- A farmer with a barn -----------------------------------------------------------------------------------------------------
local player = Engine.addPlayer("Ava", 901)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.runScript(tree.client.Main)
Engine.advance(1.5)
local p = Data:Get(player)
local plot = Plots:Plot(player)
local GuideC = Engine.require(tree.client.Controllers.GuideController)
local HudC = Engine.require(tree.client.Controllers.HudController)
local CustomerC = Engine.require(tree.client.Controllers.CustomerController)
local function buy(key)
	p.cash = math.max(p.cash, Upgrades[key].cost + 10)
	while (p.level or 1) < Upgrades[key].level do
		Economy:AddXP(player, 400, "test")
	end
	return Upg:Buy(player, key)
end
local function away()
	Engine.moveTo(player, PlotLayout.toWorld(plot.index, 60, -104) + Vector3.new(0, 3, 0))
	Engine.advance(0.6)
end
away()
for _, key in Upgrades.LIST do
	if Upgrades[key].stage == 1 then
		buy(key)
	end
end
check("buy the barn", buy("barn") and buy("sign"))
p.owned.tractor = nil -- (the field stays still: only what this test puts in the barn is there)
p.soil = {}
table.clear(p.storage)
table.clear(p.stock)
p.guide.step = 999

-- Random crops ------------------------------------------------------------------------------------------------------------
do
	Economy:AddXP(player, 2000, "test")
	local seen = {}
	for _ = 1, 60 do
		seen[Farm:Chosen(player)] = true
	end
	local n = 0
	for _ in seen do
		n += 1
	end
	check("the field grows random crops (several kinds in 60 picks)", n >= 2, n)
	check(
		"...only ones they've unlocked",
		(function()
			for key in seen do
				if Crops[key].level > p.level then
					return false
				end
			end
			return true
		end)()
	)
end

-- Customers buy out of the barn ---------------------------------------------------------------------------------------------
p.stock.carrot = 30
Farm:Push(player)
local cash0, sold0 = p.cash, p.stats.sold or 0
local rate = Customer:Rate(player)
check("customers a minute, from the shop's upgrades", rate > Customers.BASE, rate)
Engine.advance(61)
local bought = (p.stats.sold or 0) - sold0
check(
	"in a minute they buy about the rate's worth",
	bought >= math.floor(rate * 0.8) and bought <= math.ceil(rate * 1.3),
	`{bought} of {rate}`
)
check("...and pay the stand's price", p.cash > cash0, p.cash - cash0)
check("...counted as customers", (p.stats.customers or 0) >= math.floor(rate * 0.8), p.stats.customers)
check("a shopper walks up to the stand on the client", CustomerC.walking() >= 1, CustomerC.walking())
Engine.advance(0.5)
check(
	"the HUD says how the shop's doing",
	HudC.refs.shop.Visible and HudC.refs.shop.Text:find("SHOP") ~= nil,
	HudC.refs.shop.Text
)
local cu = Engine.require(tree.client.Store).get("customers")
check("...with the numbers", cu and cu.rate == rate and cu.basket == 1, cu and cu.rate)
check(
	"an empty barn: nobody queues",
	(function()
		table.clear(p.stock)
		Engine.advance(20)
		p.stock.carrot = 1
		local s = p.stats.sold
		Engine.advance(2)
		return p.stats.sold - s <= 1
	end)()
)

-- The one bottleneck: a full barn ----------------------------------------------------------------------------------------------
for _, key in { "sign", "field1", "chickenCoop", "tractor", "field2" } do
	buy(key)
end
p.owned.tractor = nil
p.cash = 1e6
table.clear(p.stock)
p.stock.strawberry = Farm:Keeps(player)
Farm:Push(player)
Customer:Push(player)
Engine.advance(1.5)
check("the HUD: BARN FULL, upgrade the shop", HudC.refs.shop.Text:find("BARN FULL") ~= nil, HudC.refs.shop.Text)
check(
	"the guide points at the next shop upgrade",
	string.sub(GuideC.state().key, 1, 5) == "shop:" and GuideC.state().text:find("barn is full") ~= nil,
	GuideC.state().key
)
check("...on a pad", typeof(GuideC.state().target) == "Vector3")
check("buy it: the Shop Helper", buy("shopkeeper") and Customers.basket(p.owned) == 2)
table.clear(p.stock)

-- Contracts in the DAILY panel -------------------------------------------------------------------------------------------------
do
	local list = DailyS:Contracts(player)
	check("three contracts a day", #list == 3 and list[1].stat ~= nil, #list)
	local DailyC = Engine.require(tree.client.Controllers.DailyController)
	DailyS:Push(player)
	Engine.advance(0.3)
	check(
		"...in the DAILY panel",
		DailyC.refs.contracts[1].Text:find(list[1].text, 1, true) ~= nil,
		DailyC.refs.contracts[1].Text
	)
	local gems = p.gems
	p.stats[list[1].stat] = (p.stats[list[1].stat] or 0) + list[1].n
	Engine.advance(DailyS.TICK + 0.5)
	check("a contract done pays a Gem", DailyS:Contracts(player)[1].done and p.gems > gems)
end

-- Deliveries: vans take loads and pay 3x -------------------------------------------------------------------------------------
away()
for _, key in Upgrades.LIST do
	if Upgrades[key].stage == 2 then
		buy(key)
	end
end
p.owned.tractor = nil
p.soil = {}
check("the shed and the van", buy("shed") and buy("van") and Delivery:Vans(player) == 1)
table.clear(p.stock)
table.clear(p.storage)
p.stock.corn = 100
local worth = Farm:Worth(player, { corn = Delivery:Load(player) })
local cash1 = p.cash
Engine.advance(Delivery.TICK + 0.5)
local trip = p.delivery.trips["1"]
check("a van takes a load out of the barn", trip ~= nil and trip.n == Delivery:Load(player), trip and trip.n)
check("...the barn has less", (p.stock.corn or 0) <= 100 - Delivery:Load(player), p.stock.corn)
local van = plot.items.van:FindFirstChild("Vehicle")
check("...the van's on its trip", van and van:GetAttribute("TripStart") == trip.at)
Engine.advance(trip.length + 1.5)
check(
	"back: it pays 3x the stand",
	p.cash - cash1 >= worth * Delivery.MULT * 0.99,
	`{p.cash - cash1} vs {worth * Delivery.MULT}`
)
check("...counted", (p.stats.deliveries or 0) >= 1)
check(
	"the guide's chapter 3 names deliveries",
	(function()
		local Guide = Engine.require(tree.shared.Data.Guide)
		return Guide.byKey.deliver1 ~= nil and Guide.byKey.pack1 == nil
	end)()
)

-- Leaving and coming back ------------------------------------------------------------------------------------------------------
p.stock.corn = 100
Engine.advance(Delivery.TICK + 0.5)
local out = p.delivery.trips["1"]
check("a van out when they leave", out ~= nil)
Engine.removePlayer(player)
Engine.advance(0.5)
local again = Engine.addPlayer("Ava", 901)
Engine.advance(2)
local p2 = Data:Get(again)
check("...is still out when they're back", p2.delivery and p2.delivery.trips["1"] ~= nil)
check("...the shop's rate kept", Customer:Rate(again) == Customers.rate(p2, now()))

do
	local bad = {}
	for _, w in Engine.warnings do
		if
			tostring(w):find("save failed")
			or tostring(w):find("tick failed")
			or tostring(w):find("failed to start")
		then
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
print(`CustomerSmoke: {passed} passed, {failed} failed`)
if failed > 0 then
	error(`{failed} failed`)
end
