--[[
Phase D on the mock engine, server and client together: stage 3 (the Packing Shed). The shed takes the place of its
site with its packing table's pad and the order board; customers fill the board's slots; the conveyor leaves what
the orders need; standing at PACK ORDERS packs the basket into boxes; a packed order leaves on the buyer's pickup
(every client drives it along the trip) and pays when it's back; orders run out (the boxes come back) or are
skipped; the van ships faster, the second van ships two at once, the loading dock cuts the trip, the sorter and the
wrapper make orders pay more, a BIG order pays Gems, the box line packs by itself; three daily contracts pay as
they're reached (and all three pay Gems) and change with the day; the guide's chapter 3 leads all the way to the
warehouse's deed; a trip under way while they're gone pays when they're back.

  luaurun tests/OrderSmoke.spec.luau
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Vector3 = Engine.Vector3
local Vector2 = Engine.globals.Vector2
local typeof = Engine.globals.typeof
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
-- (no Special Orders breaking in here: they have their own suite)
service("SpecialService").FIRST = 1e9
service("SpecialService").DAILY = false
local Plots = service("PlotService")
local Farm = service("FarmService")
local Upg = service("UpgradeService")
local Order = service("OrderService")
local Data = service("PlayerDataService")
local Economy = service("EconomyService")
local Upgrades = Engine.require(tree.shared.Data.Upgrades)
local Orders = Engine.require(tree.shared.Data.Orders)
local Crops = Engine.require(tree.shared.Data.Crops)
local GuideData = Engine.require(tree.shared.Data.Guide)
local PlotLayout = Engine.require(tree.shared.World.PlotLayout)
local Trips = Engine.require(tree.shared.World.Trips)

local function now()
	return Engine.workspace:GetServerTimeNow()
end
local function stand(pl, pos)
	Engine.moveTo(pl, pos + Vector3.new(0, 3, 0))
	Engine.advance(0.6)
end

-- Orders.make and Trips, on their own -------------------------------------------------------------------------------
do
	local a = Orders.make(12, Random.new(7))
	local b = Orders.make(12, Random.new(7))
	local same, ok, count = true, true, 0
	for key, n in a.items do
		count += 1
		same = same and b.items[key] == n
		ok = ok and Crops[key] ~= nil and Crops[key].level <= 12 and Crops[key].grow <= Orders.MAX_GROW and n >= 4
	end
	check("an order: the same seed, the same order", same and a.who == b.who)
	check("...1 to 3 crops the level has, quick ones, 4 or more each", ok and count >= 1 and count <= 3)
	check(
		"...worth about the level's target",
		a.value > Orders.target(12) * 0.4 and a.value < Orders.target(12) * 4,
		a.value
	)
	local cash = Orders.reward(a, 0)
	check("...it pays MULT times the stand", cash == math.floor(a.value * Orders.MULT + 0.5), cash)
	check("...more with a bonus", Orders.reward(a, 0.3) > cash)
	local big = 0
	for s = 1, 600 do
		if Orders.make(12, Random.new(s)).big then
			big += 1
		end
	end
	check("...about one in six is BIG", big > 60 and big < 150, big)
	local d1, d2 = Orders.daily(20000, 901, 12), Orders.daily(20001, 901, 12)
	local diff = false
	for i = 1, 3 do
		diff = diff or d1[i].key ~= d2[i].key
	end
	check("contracts: three a day, a new three tomorrow", #d1 == 3 and diff)
	local park = PlotLayout.SPOTS.parks[1]
	local at0 = Trips.local_("van", 0, park)
	local at1 = Trips.local_("van", 1, park)
	check("a van's trip starts and ends in its spot", (at0 - park).Magnitude < 0.01 and (at1 - park).Magnitude < 0.01)
	local door = PlotLayout.SPOTS.door
	local atDoor = Trips.local_("van", 0.25, park)
	check("...backs up to the loading door", (atDoor - door).Magnitude < 9, (atDoor - door).Magnitude)
	local _, look = Trips.local_("van", 0.25, park)
	check("...its back to the door", look.Z < -0.9, look)
	local _, _, seen = Trips.local_("van", 0.65, park)
	check("...and is gone down the road for a while", seen == false)
	local up = Trips.local_("pickup", 0.55)
	check("the pickup noses in to the door", (up - door).Magnitude < 8)
end

-- A farm at the end of stage 2 ---------------------------------------------------------------------------------------
local player = Engine.addPlayer("Ava", 901)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.runScript(tree.client.Main)
Engine.advance(1.5)
local p = Data:Get(player)
local plot = Plots:Plot(player)
local GuideC = Engine.require(tree.client.Controllers.GuideController)
local OrderC = Engine.require(tree.client.Controllers.OrderController)
local VehicleC = Engine.require(tree.client.Controllers.VehicleController)
local function buy(key)
	p.cash = math.max(p.cash, Upgrades[key].cost + 10)
	while (p.level or 1) < Upgrades[key].level do
		Economy:AddXP(player, 400, "test")
	end
	return Upg:Buy(player, key)
end
local function away()
	stand(player, PlotLayout.toWorld(plot.index, -40, -104))
end
away()
for _, key in Upgrades.LIST do
	if Upgrades[key].stage <= 2 then
		buy(key)
	end
end
check("stage 2 done: stage 3", p.stage == 3)
p.guide.step = GuideData.byKey.shedBuild.index
Engine.advance(1.2)
check(
	"the guide: build the shed (or earn it first)",
	GuideC.state().key == "shedBuild" or string.find(GuideC.state().key, "^earn:shed:") ~= nil,
	GuideC.state().key
)
check("no orders before the shed", #Order:Slots(player) == 0 and not OrderC.refs.panel.Visible)

-- The shed ---------------------------------------------------------------------------------------------------------------
check("buy The Packing Shed", buy("shed"))
check(
	"...it stands where its site was",
	plot.items:FindFirstChild("shed") ~= nil and plot.items:FindFirstChild("shedDeed") == nil
)
local pad = Order:PackPad(player)
check("...with its PACK ORDERS pad", pad ~= nil)
local slots = {}
for _, d in plot.items.shed:GetChildren() do
	if d.Name == "BoardSlot" then
		slots[d:GetAttribute("Slot")] = d
	end
end
check("...and the order board's three slots", slots[1] and slots[2] and slots[3])
do
	local out = 0
	for _, d in plot.items.shed:GetDescendants() do
		if d:IsA("BasePart") then
			local l = plot.cf:PointToObjectSpace(d.Position)
			if l.X < 4 - 13 or l.X > 80 or l.Z < -110 then
				out += 1
			end
		end
	end
	check("...all of it on the plot's industry side", out == 0, out)
end
Engine.advance(1.2)
local live = Order:Slots(player)
check("two customers on the board", #live == 2 and live[1].state == "open" and live[2].state == "open", #live)
check("...the board shows them", slots[1].Board.Title.Text:find(live[1].who, 1, true) ~= nil, slots[1].Board.Title.Text)
check("...the third slot is locked", slots[3].Board.Title.Text == "LOCKED")
check(
	"the orders panel shows them",
	OrderC.refs.panel.Visible and OrderC.refs.rows[1].who.Text:find(live[1].who, 1, true) ~= nil
)
check("...with what to pack", OrderC.refs.rows[1].items.Text:find("0/") ~= nil, OrderC.refs.rows[1].items.Text)
check("...and the time left", OrderC.refs.rows[1].status.Text:find("left") ~= nil, OrderC.refs.rows[1].status.Text)
check("...today's three contracts", #OrderC.state().contracts == 3 and OrderC.refs.contracts[3].Visible)
check("the guide: pack an order", GuideC.state().key == "pack1", GuideC.state().key)
check(
	"...pointing at the order board (packing is automatic)",
	GuideC.state().target ~= nil and (GuideC.state().target - pad.Position).Magnitude > 0.1
)

-- The conveyor leaves what the orders need ---------------------------------------------------------------------------------
local first = live[1]
local key1 = next(first.items)
table.clear(p.storage)
p.storage[key1] = 3
p.storage.goldpumpkin = nil
local other = key1 == "strawberry" and "carrot" or "strawberry"
local needsOther = (Order:Needs(player)[other] or 0) > 0
p.storage[other] = 5
Farm:Sell(player, true)
check("the conveyor keeps what the orders need", p.storage[key1] == 3, p.storage[key1])
check("...and sells the rest", needsOther or p.storage[other] == nil)

-- Packing ------------------------------------------------------------------------------------------------------------------
table.clear(p.storage)
p.storage[key1] = 2
stand(player, pad.Position)
check("standing at PACK ORDERS packs the basket", (first.packed[key1] or 0) == 2 and p.storage[key1] == nil)
check("...counted", p.stats.packed == 2)
Engine.advance(1.2)
check("the guide: a whole order", GuideC.state().key == "packFull", GuideC.state().key)
check("...the panel shows it", OrderC.refs.rows[1].items.Text:find("2/") ~= nil, OrderC.refs.rows[1].items.Text)
away()
for key, n in first.items do
	p.storage[key] = n
end
stand(player, pad.Position)
Engine.advance(0.6)
check("a whole order packed: it leaves", first.state == "shipping", first.state)
check("...on the buyer's pickup (no van yet)", first.vehicle == "pickup")
check("...in PICKUP_TRIP seconds", math.abs(first.length - Orders.PICKUP_TRIP) < 0.01)
local pickup
for _, d in plot.items:GetChildren() do
	if d.Name == "Vehicle" and d:GetAttribute("Kind") == "pickup" then
		pickup = d
	end
end
check("...the pickup is on the map, with its trip", pickup ~= nil and pickup:GetAttribute("TripStart") == first.at)
Engine.advance(1.2)
check("the guide: watch it go", GuideC.state().key == "ship1", GuideC.state().key)
check("the client drives it", VehicleC.moving() >= 1, VehicleC.moving())
Engine.advance(Orders.PICKUP_TRIP * 0.55 - 2)
local door = PlotLayout.toWorld(plot.index, PlotLayout.SPOTS.door.X, PlotLayout.SPOTS.door.Z)
check(
	"...up to the loading door",
	pickup and (pickup:GetPivot().Position - door).Magnitude < 9,
	pickup and (pickup:GetPivot().Position - door).Magnitude
)
local cash0 = p.cash
local reward = Orders.reward(first, Upgrades.stat(p.owned, "orderPrice", 0) + 0)
Engine.advance(Orders.PICKUP_TRIP * 0.5)
check("back: the order pays", p.cash >= cash0 + reward * 0.9, p.cash - cash0)
check("...one shipment", p.stats.shipments == 1)
check("...the pickup's gone", pickup.Parent == nil)
check("...the slot waits for the next customer", live[1].state == "wait")
check(
	"the guide moves on",
	GuideC.state().key == "van" or string.find(GuideC.state().key, "^earn:van:") ~= nil,
	GuideC.state().key
)
Engine.advance(Orders.REFRESH + 1)
check("...and the next customer comes", Order:Slots(player)[1].state == "open")

-- Running out, skipping -------------------------------------------------------------------------------------------------
local o2 = Order:Slots(player)[2]
local k2 = next(o2.items)
table.clear(p.storage)
o2.packed[k2] = 3
o2.ends = now() - 1
Engine.advance(0.6)
check("an order that runs out: the slot waits", Order:Slots(player)[2].state == "wait")
check("...its boxes come back to the basket", p.storage[k2] == 3, p.storage[k2])
local o1 = Order:Slots(player)[1]
check("skip an order", Order:Skip(player, 1) and Order:Slots(player)[1].state == "wait")
check("...a packed one can't be skipped", not Order:Skip(player, 1))

-- The van, the board, the box line ----------------------------------------------------------------------------------------
_ = o1
check("the shed came with its paved yard", plot.items:FindFirstChild("Yard", true) ~= nil)
check("buy the Delivery Van", buy("van"))
local van = plot.items.van:FindFirstChild("Vehicle")
check("...it waits in its spot", van ~= nil)
Engine.advance(1)
local park = PlotLayout.toWorld(plot.index, PlotLayout.SPOTS.parks[1].X, PlotLayout.SPOTS.parks[1].Z)
check("...parked", (van:GetPivot().Position - park).Magnitude < 0.5)
check("buy the Big Order Board", buy("orderBoard"))
Engine.advance(Orders.REFRESH + 2)
live = Order:Slots(player)
check("three orders at once", #live == 3 and live[3].state == "open", #live)
local function fill(slot)
	local o = Order:Slots(player)[slot]
	for key, n in o.items do
		o.packed[key] = n
	end
	o.state = "ready"
	return o
end
local a = fill(1)
Engine.advance(0.6)
check("a packed order leaves in the van", a.state == "shipping" and a.vehicle == 1)
check("...in the van's time", math.abs(a.length - 20) < 0.01, a.length)
check("...the van's on its trip", van:GetAttribute("TripStart") == a.at)
local b = fill(2)
Engine.advance(0.6)
check("one van: the next waits for it", b.state == "ready")
Engine.advance(21)
check("...the van's back: it goes", a.state ~= "shipping" and b.state == "shipping" and b.vehicle == 1)
Engine.advance(21)
check("buy the Box Line", buy("boxLine"))
Engine.advance(Orders.REFRESH + 2)
local o3
for _ = 1, 20 do
	for _, o in Order:Slots(player) do
		if o.state == "open" and o.items then
			o3 = o
		end
	end
	if o3 then
		break
	end
	Engine.advance(Orders.REFRESH / 2)
end
local k3 = next(o3.items)
table.clear(p.storage)
p.storage[k3] = 1
away()
Engine.advance(7)
check("the box line packs by itself", (o3.packed[k3] or 0) >= 1, `{k3} {o3.packed[k3]} {p.storage[k3]} {o3.state}`)

-- More pay, quicker trips, two vans, a BIG order --------------------------------------------------------------------------
local before = Orders.reward(o3, Upgrades.stat(p.owned, "orderPrice", 0))
check("buy the Sorting Machine", buy("sorter"))
check("buy the Loading Dock", buy("loadingDock"))
check("buy the Pallet Wrapper", buy("wrapper"))
check("...orders pay +30%", Upgrades.stat(p.owned, "orderPrice", 0) > 0.29)
check("...more than before", Orders.reward(o3, Upgrades.stat(p.owned, "orderPrice", 0)) > before)
check("buy a Second Van", buy("van2"))
Engine.advance(1)
for slot = 1, 3 do
	local o = Order:Slots(player)[slot]
	if o.state == "wait" then
		o.at = 0
	end
end
Engine.advance(1)
local x, y = fill(1), fill(2)
x.big = true
local gems0 = p.gems
Engine.advance(0.6)
check("two vans: two on the road at once", x.state == "shipping" and y.state == "shipping" and x.vehicle ~= y.vehicle)
check("...the loading dock cuts the trip", math.abs(x.length - 15) < 0.01, x.length)
Engine.advance(16)
check("a BIG order pays Gems", p.gems >= gems0 + Orders.BIG_GEMS and p.stats.bigOrders == 1, p.gems - gems0)

-- Daily contracts --------------------------------------------------------------------------------------------------------
local list = Order:Contracts(player)
local gems1, cash1 = p.gems, p.cash
local c1 = list[1]
p.stats[c1.stat] = (p.stats[c1.stat] or 0) + c1.n
Engine.advance(0.6)
list = Order:Contracts(player)
check("a contract done: it pays", list[1].done and p.cash >= cash1 + c1.cash and p.gems >= gems1 + 1)
check("...and stays done", Order:Contracts(player)[1].done)
local gems2 = p.gems
local pending = 0 -- (the farm runs itself now: one may be done already)
for i = 2, 3 do
	if not list[i].done then
		pending += 1
	end
	p.stats[list[i].stat] = (p.stats[list[i].stat] or 0) + list[i].n
end
Engine.advance(0.6)
check(
	"all three: Gems on top",
	p.gems >= gems2 + pending + Orders.ALL_GEMS,
	`{p.gems - gems2} {list[1].stat} {list[2].stat} {list[3].stat} {tostring(Order:Contracts(player)[2].done)} {tostring(
		Order:Contracts(player)[3].done
	)}`
)
check("...the panel ticks them", OrderC.refs.contracts[1].Text:find("✔") ~= nil, OrderC.refs.contracts[1].Text)
p.orders.daily.day -= 1
local fresh = Order:Contracts(player)
check("a new day: three new contracts, none done", #fresh == 3 and not fresh[1].done and not fresh[3].done)

-- The guide's chapter 3, to the warehouse ---------------------------------------------------------------------------------
p.guide.step = GuideData.byKey.warehouse.index
check("the warehouse's deed", buy("warehouseDeed"))
check("...stage 4", p.stage == 4)
check("...its site staked out", plot.items:FindFirstChild("warehouseDeed") ~= nil)
Engine.advance(1.2)
check("the guide's chapter 3 is done", p.guide.step > GuideData.byKey.warehouse.index)
do
	local keys, missing = {}, {}
	for _, s in GuideData.STEPS do
		local target = s.target
		if string.sub(target, 1, 4) == "pad:" then
			if not Upgrades[string.sub(target, 5)] then
				table.insert(missing, s.key)
			end
		end
		keys[s.key] = true
	end
	check("every guide step's pad is a real upgrade", #missing == 0, table.concat(missing, ","))
	local covered = {}
	for _, s in GuideData.STEPS do
		if s.done.kind == "owned" then
			covered[s.done.key] = true
		end
	end
	local uncovered = {}
	for _, key in Upgrades.LIST do
		if Upgrades[key].stage == 3 and not covered[key] and key ~= "warehouseDeed" then
			table.insert(uncovered, key)
		end
	end
	check("the guide walks through every stage-3 upgrade", #uncovered == 0, table.concat(uncovered, ","))
end

-- Away mid-trip: it pays when they're back ----------------------------------------------------------------------------------
for slot = 1, 3 do
	local o = Order:Slots(player)[slot]
	if o.state == "wait" then
		o.at = 0
	end
end
Engine.advance(1)
local z = fill(3)
Engine.advance(0.6)
check("an order on the road", z.state == "shipping")
local ships = p.stats.shipments
Engine.removePlayer(player)
Engine.advance(30)
local again = Engine.addPlayer("Ava", 901)
Engine.advance(2)
local p2 = Data:Get(again)
check("back after the trip: it paid", p2.stats.shipments == ships + 1, p2.stats.shipments)
check(
	"...the shed and the vans rebuilt",
	Order:PackPad(again) ~= nil and Plots:Plot(again).items:FindFirstChild("van2") ~= nil
)

do
	local bad = {}
	for _, w in Engine.warnings do
		if tostring(w):find("save failed") then
			table.insert(bad, tostring(w))
		end
	end
	check("the profile saves (orders, contracts and all)", #bad == 0, bad[1])
end

if #Engine.errors > 0 then
	for _, e in Engine.errors do
		print("ERROR " .. tostring(e))
	end
	failed += #Engine.errors
end
print(`OrderSmoke: {passed} passed, {failed} failed`)
if failed > 0 then
	error(`{failed} failed`)
end
