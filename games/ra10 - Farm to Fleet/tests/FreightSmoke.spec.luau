--[[
Phase F on the mock engine, server and client together: semis on the shared road and Special Orders (master plan
§13.2, §13.3). The semis wait for the back docks, then each comes in from the road for a big load, backs its trailer
up to its own dock (on every client), and pays when it's gone. Special Orders: the kinds and when they come (nights,
weekends), golden ones needing golden crops; one breaks in after enough play, its express truck pulling up on the
road, a gold banner on screen and the guide pointing at PACK ORDERS; packing it first, the conveyor holding back what
it needs, the truck driving off and paying Cash and Gems; one running out gives its boxes back; the day's first visit
brings one; everything saves.

  luaurun tests/FreightSmoke.spec.luau
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Vector3 = Engine.Vector3
local Vector2 = Engine.globals.Vector2
local Random = Engine.globals.Random

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
local UIS = Engine.game:GetService("UserInputService")
UIS.TouchEnabled = true
UIS.KeyboardEnabled = false
Engine.runScript(tree.server.Main)
Engine.advance(0.5)

local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Plots = service("PlotService")
local Upg = service("UpgradeService")
local Order = service("OrderService")
local Special = service("SpecialService")
local Data = service("PlayerDataService")
local Economy = service("EconomyService")
local Upgrades = Engine.require(tree.shared.Data.Upgrades)
local Flow = Engine.require(tree.shared.Data.Flow)
local Specials = Engine.require(tree.shared.Data.Specials)
local Crops = Engine.require(tree.shared.Data.Crops)
local Orders = Engine.require(tree.shared.Data.Orders)
local PlotLayout = Engine.require(tree.shared.World.PlotLayout)
local Trips = Engine.require(tree.shared.World.Trips)
local SPOTS = PlotLayout.SPOTS
Special.FIRST = 1e9
Special.DAILY = false

local function now()
	return Engine.workspace:GetServerTimeNow()
end
local function stand(pl, pos)
	Engine.moveTo(pl, pos + Vector3.new(0, 3, 0))
	Engine.advance(0.6)
end

-- On their own ----------------------------------------------------------------------------------------------------------
do
	local tueNight, thuNoon, satNoon = 1700000000, 1700136000, 1700308800
	local function has(t, key)
		for _, k in Specials.available(t) do
			if k.key == key then
				return true
			end
		end
		return false
	end
	check("Night Express only at night", has(tueNight, "night") and not has(thuNoon, "night"))
	check("the Holiday Mega Delivery only at the weekend", has(satNoon, "holiday") and not has(thuNoon, "holiday"))
	check("the others any time", has(thuNoon, "emergency") and has(thuNoon, "golden") and has(thuNoon, "chef"))
	local kinds = {}
	for seed = 1, 200 do
		local s = Specials.make(20, Random.new(seed), satNoon)
		kinds[s.kind] = (kinds[s.kind] or 0) + 1
		if s.kind == "golden" then
			local ok = true
			for key in s.items do
				ok = ok and string.sub(key, 1, 1) == "*"
			end
			check("a Golden Harvest wants golden crops", ok)
		end
	end
	check(
		"every kind comes up",
		kinds.emergency and kinds.golden and kinds.chef and kinds.night == nil and kinds.holiday
	)
	local a, b = Specials.make(20, Random.new(9), thuNoon), Specials.make(20, Random.new(9), thuNoon)
	check("the same seed, the same special", a.kind == b.kind and a.value == b.value and a.who == b.who)
	local cash = Specials.reward(a, 0)
	local normal = Orders.reward({ value = Orders.target(20) }, 0)
	check("a special pays far more than an order", cash > normal * 3, `{cash} vs {normal}`)
	local owned = { warehouse = 1, loadingDock = 1, backDocks = 1, biggerTrucks = 1 }
	local before = Flow.rates({ owned = owned, level = 30 }, 0).ship
	owned.semi1 = 1
	check("a semi ships a lot more", Flow.rates({ owned = owned, level = 30 }, 0).ship > before * 2)
	local dock = Vector3.new(SPOTS.docks[5], 0, 62)
	local at = Trips.local_("semi", 0.6, dock)
	check("a semi backs its trailer up to its dock", math.abs(at.X - SPOTS.docks[5]) < 0.01 and at.Z < 45, at)
	check(
		"...and is out on the road at both ends",
		Trips.local_("semi", 0, dock).Z < -120 and Trips.local_("semi", 1, dock).Z < -120
	)
end

-- A hub without its back docks -------------------------------------------------------------------------------------------
local player = Engine.addPlayer("Ava", 901)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.runScript(tree.client.Main)
Engine.advance(1.5)
local p = Data:Get(player)
local plot = Plots:Plot(player)
local GuideC = Engine.require(tree.client.Controllers.GuideController)
local SpecialC = Engine.require(tree.client.Controllers.SpecialController)
local VehicleC = Engine.require(tree.client.Controllers.VehicleController)
local function buy(key)
	p.cash = math.max(p.cash, Upgrades[key].cost + 10)
	while (p.level or 1) < Upgrades[key].level do
		Economy:AddXP(player, 3000, "test")
	end
	return Upg:Buy(player, key)
end
local function at(x, z, y)
	return PlotLayout.toWorld(plot.index, x, z, y)
end
stand(player, at(-40, -104))
for _, key in Upgrades.LIST do
	if Upgrades[key].stage <= 4 then
		buy(key)
	end
end
while (p.level or 1) < 31 do
	Economy:AddXP(player, 3000, "test")
end
Engine.advance(1)
check("no semi before the back docks", not buy("semi1"))
check(
	"...the SHIP pad says what it needs",
	Upg:Stations(player).ship.Over.Line.Text:find("NEEDS") ~= nil,
	Upg:Stations(player).ship.Over.Line.Text
)
check("buy the back docks", buy("backDocks"))
check("buy the First Semi", buy("semi1"))
local docks = 0
for _, d in plot.items:GetDescendants() do
	if d.Name == "DockDoor" then
		docks += 1
	end
end
check("...a fifth dock door, for the semis", docks == 5)

-- A semi's trip ------------------------------------------------------------------------------------------------------------
p.flow.racked = 40
for n = 1, 4 do
	p.flow.trucks[tostring(n)] = { at = now(), length = 9999, pallets = 1 } -- (the box trucks are all out)
end
Engine.advance(0.6)
local trip = p.flow.trucks.s1
check("a semi comes for a big load", trip and trip.pallets == Flow.SEMI_CAP, trip and trip.pallets)
local semi = nil
for _, d in plot.items:GetDescendants() do
	if d.Name == "Vehicle" and d:GetAttribute("Kind") == "semi" then
		semi = d
	end
end
check(
	"...a semi on the map, on its trip",
	semi and semi:GetAttribute("Plan") == "semi" and semi:GetAttribute("TripStart") == trip.at
)
Engine.advance(math.max(0.1, trip.at + trip.length * 0.6 - now()))
local dock5 = at(SPOTS.docks[5], PlotLayout.SLICES[#PlotLayout.SLICES] + 17)
check(
	"...backed up to its dock (on the client)",
	(semi:GetPivot().Position - dock5).Magnitude < 4,
	(semi:GetPivot().Position - dock5).Magnitude
)
check("...counted as moving", VehicleC.moving() >= 1)
local cash0 = p.cash
Engine.advance(trip.length * 0.5)
check("gone: it pays for every pallet", p.cash - cash0 >= Flow.SEMI_CAP * Flow.PALLET * Flow.SHIP_MULT, p.cash - cash0)
check("...the semi's gone from the map", semi.Parent == nil and p.stats.semis == 1)
for n = 1, 4 do
	p.flow.trucks[tostring(n)] = false
end
p.flow.racked = 0

-- Special Orders ------------------------------------------------------------------------------------------------------------
check("no special yet (the clock's far off)", Special:Current(player) == nil)
p.orders.specialIn = 2
Engine.advance(3.5)
local s = Special:Current(player)
check("after enough play, a Special Order breaks in", s ~= nil and s.state == "open")
local express = nil
for _, d in plot.items:GetDescendants() do
	if d.Name == "Vehicle" and d:GetAttribute("Kind") == "express" then
		express = d
	end
end
check("...its express truck on the road", express ~= nil)
Engine.advance(Special.ARRIVE + 1)
local stop = at(SPOTS.expressStop.X, SPOTS.expressStop.Z)
check(
	"...pulled up on the verge",
	express and (express:GetPivot().Position - stop).Magnitude < 1,
	express and (express:GetPivot().Position - stop).Magnitude
)
check("...the banner on screen", SpecialC.refs.banner.Visible and SpecialC.refs.title.Text:find(s.name, 1, true) ~= nil)
check(
	"...with its clock and pay",
	SpecialC.refs.clock.Text:find("left") ~= nil and SpecialC.refs.pay.Text:find("💎") ~= nil
)
check(
	"the guide: pack the special",
	GuideC.state().generated and string.sub(GuideC.state().key, 1, 8) == "special:",
	GuideC.state().key
)
check("...at PACK ORDERS", (GuideC.state().target - Order:PackPad(player).Position).Magnitude < 0.1)
local needs = Order:Needs(player)
local held = true
for key, n in s.items do
	held = held and (needs[key] or 0) >= n
end
check("the conveyor holds back what the special needs", held)
-- pack it
table.clear(p.storage)
for key, n in s.items do
	p.storage[key] = n
end
stand(player, Order:PackPad(player).Position)
check("packing it at the pad", s.state == "shipping")
check("...the express truck drives off", express:GetAttribute("Plan") == "expressOut")
stand(player, at(-40, -104))
local cash1, gems1 = p.cash, p.gems
local reward = Specials.reward(s, Upgrades.stat(p.owned, "orderPrice", 0))
Engine.advance(Specials.EXPRESS + 1.5)
check(
	"gone: it pays Cash and Gems",
	p.cash - cash1 >= reward and p.gems - gems1 >= s.gems,
	`{p.cash - cash1} / {reward}`
)
check("...counted, the biggest shipment", p.stats.specials == 1 and p.stats.biggestShipment >= reward)
check(
	"...the truck's gone, the next one's clock running",
	express.Parent == nil and Special:Current(player) == nil and p.orders.specialIn >= Specials.EVERY_MIN
)
check("...the banner gone", not SpecialC.refs.banner.Visible)
-- one that runs out
local s2 = Special:Spawn(player)
local k2 = next(s2.items)
s2.packed[k2] = 2
table.clear(p.storage)
s2.ends = now() - 1
Special:Step(player, p, 0)
check("a special that runs out is gone", Special:Current(player) == nil)
check("...its boxes back in the basket", (p.storage[k2] or 0) == 2, p.storage[k2])
-- a golden one only takes golden crops
local s3 = Special:Spawn(player)
s3.kind, s3.items, s3.packed = "golden", { ["*strawberry"] = 3 }, {}
table.clear(p.storage)
p.storage.strawberry = 10
p.storage["*strawberry"] = 2
Special:Pack(player)
check("a Golden Harvest takes golden crops only", s3.packed["*strawberry"] == 2 and p.storage.strawberry == 10)
s3.ends = now() - 1
Engine.advance(1.5)

-- The day's first visit brings one ---------------------------------------------------------------------------------------------
Special.DAILY = true
p.orders.specialDay = Orders.day() - 1
p.orders.specialIn = 1e6
Engine.removePlayer(player)
Engine.advance(1)
local again = Engine.addPlayer("Ava", 901)
Engine.advance(2)
check("the day's first visit: a special is waiting", Special:Current(again) ~= nil)

do
	local bad = {}
	for _, w in Engine.warnings do
		if tostring(w):find("save failed") or tostring(w):find("tick failed") then
			table.insert(bad, tostring(w))
		end
	end
	check("no failed saves or ticks", #bad == 0, bad[1])
end
_ = Crops
if #Engine.errors > 0 then
	for _, e in Engine.errors do
		print("ERROR " .. tostring(e))
	end
	failed += #Engine.errors
end
print(`FreightSmoke: {passed} passed, {failed} failed`)
if failed > 0 then
	error(`{failed} failed`)
end
