--[[
Stage 5's takeover on the mock engine, server and client together (master plan §13.1): the warehouse grows until it
owns the front of the plot. The hub's deed stakes it out; the back dock doors wait for the last bay, then pave the
court and move the trucks round (they back up to their docks, on every client); the front hall swallows the packing
shed, its machines and the old front wall, and rebuilds the order board, the PACK ORDERS pad, the van's door and the
Operations screen in the hall; the control tower and the solar roof go up; the market hall takes the farm stand's
place, and the sell pad and the buy-pads move in and still work. Everything carries the detail layer (pipes, ducts,
lights), the roofs lift when the camera's inside, and it all comes back the same after a rejoin.

  luaurun tests/HubSmoke.spec.luau
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Vector3 = Engine.Vector3
local CFrame = Engine.CFrame
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
local Flow = Engine.require(tree.shared.Data.Flow)
local PlotLayout = Engine.require(tree.shared.World.PlotLayout)
local Trips = Engine.require(tree.shared.World.Trips)
local SPOTS = PlotLayout.SPOTS

local function now()
	return Engine.workspace:GetServerTimeNow()
end
local function stand(pl, pos)
	Engine.moveTo(pl, pos + Vector3.new(0, 3, 0))
	Engine.advance(0.6)
end

-- On their own ----------------------------------------------------------------------------------------------------------
do
	local owned = {}
	for _, key in Upgrades.LIST do
		if Upgrades[key].stage <= 4 and key ~= "bay4" then
			owned[key] = 1
		end
	end
	local offer = Upgrades.next(owned, 40, 3)
	check("the back docks wait for the last bay", #offer == 0, offer[1] and offer[1].key)
	owned.bay4 = 1
	offer = Upgrades.next(owned, 40, 3)
	check(
		"...then they're on offer, and the hub's expansions after",
		offer[1] and offer[1].key == "backDocks" and offer[2].key == "frontHall"
	)
	local cut = Flow.trip({ loadingDock = 1 }) - Flow.trip({ loadingDock = 1, backDocks = 1 })
	check("back docks: shorter trips", cut > 0)
	check(
		"the front hall and solar roof pack faster",
		Flow.rates({ owned = { warehouse = 1, frontHall = 1, solarRoof = 1 }, level = 30 }, 0).pack
			== Flow.PACK_PER_LINE * 1.5
	)
	local park = SPOTS.dockLot[1]
	local at, look = Trips.local_("truckBack", 0.2, park)
	check(
		"a truck backs straight up to its dock",
		math.abs(at.X - SPOTS.docks[1]) < 0.01 and at.Z < 34 and look.Z > 0.9,
		at
	)
	local p0, l0 = Trips.local_("truckBack", 0, park)
	local p1, l1 = Trips.local_("truckBack", 1, park)
	check(
		"...and parks again nose out",
		(p0 - park).Magnitude < 0.01 and (p1 - park).Magnitude < 0.01 and l0.Z > 0.9 and l1.Z > 0.9
	)
end

-- A farm with all of stage 4 -----------------------------------------------------------------------------------------------
local player = Engine.addPlayer("Ava", 901)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.runScript(tree.client.Main)
Engine.advance(1.5)
local p = Data:Get(player)
local plot = Plots:Plot(player)
local WareC = Engine.require(tree.client.Controllers.WarehouseController)
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
check("stage 5", p.stage == 5)
local function count(name, root)
	local n = 0
	for _, d in (root or plot.items):GetDescendants() do
		if d.Name == name then
			n += 1
		end
	end
	return n
end
local size0 = Flow.size(p)
local parts0 = #plot.items:GetDescendants()
check(
	"the hub's deed stakes out the front",
	plot.items:FindFirstChild("hubDeed") ~= nil and count("SiteSign", plot.items.hubDeed) == 1
)
check(
	"the warehouse already carries the detail layer",
	count("Sprinkler") >= 10 and count("Duct") >= 5 and count("LampShade") >= 40
)

-- The back docks ---------------------------------------------------------------------------------------------------------
p.flow.racked, p.flow.staged, p.flow.inbound = 0, 0, 0
Engine.advance(80) -- (every truck home)
check("buy the Back Dock Doors", buy("backDocks"))
check(
	"...four dock doors on the back wall",
	count("DockDoor") == 4
		and count("DockLight", plot.items.backDocks) == 8
		and count("Canopy", plot.items.backDocks) == 4
)
check("...the old lot paved over", count("TruckLot") == 0)
local trucks = {}
for _, d in plot.items:GetDescendants() do
	if d.Name == "Vehicle" and d:GetAttribute("Kind") == "truck" then
		trucks[d:GetAttribute("Park")] = d
	end
end
check(
	"...every truck takes the back route",
	#trucks == 4
		and trucks[1]:GetAttribute("Plan") == "truckBack"
		and trucks[4]:GetAttribute("ParkAt") == SPOTS.dockLot[4]
)
Engine.advance(1)
local lot1 = at(SPOTS.dockLot[1].X, SPOTS.dockLot[1].Z)
check(
	"...parked in the court",
	(trucks[1]:GetPivot().Position - lot1).Magnitude < 1,
	(trucks[1]:GetPivot().Position - lot1).Magnitude
)
p.flow.racked = 12
for n = 1, 4 do
	p.flow.trucks[tostring(n)] = false
end
Engine.advance(0.6)
local trip = p.flow.trucks["1"]
check("a load goes out the back", trip and trip.pallets > 0)
Engine.advance(math.max(0.1, trip.at + trip.length * 0.22 - now()))
local dock1 = at(SPOTS.docks[1], PlotLayout.SLICES[#PlotLayout.SLICES])
check(
	"...backed up to dock 1 (on the client)",
	(trucks[1]:GetPivot().Position - dock1).Magnitude < 10,
	(trucks[1]:GetPivot().Position - dock1).Magnitude
)
Engine.advance(trip.length)

-- The front hall ---------------------------------------------------------------------------------------------------------
check("buy The Front Hall", buy("frontHall"))
check(
	"...the shed and its machines are gone",
	not plot.items:FindFirstChild("shed")
		and not plot.items:FindFirstChild("sorter")
		and not plot.items:FindFirstChild("wrapper")
		and not plot.items:FindFirstChild("boxLine")
)
check("...and the old front wall", count("WarehouseSign") == 0 and count("Bridge") == 0)
check(
	"...one PACK ORDERS pad, where it was",
	count("PackPad") == 1 and (Order:PackPad(player).Position - at(SPOTS.packPad.X, SPOTS.packPad.Z)).Magnitude < 1
)
check("...the order board on the façade", count("BoardSlot") == 3)
Engine.advance(1)
local slotText = nil
for _, d in plot.items:GetDescendants() do
	if d.Name == "BoardSlot" and d:GetAttribute("Slot") == 1 then
		slotText = d.Board.Title.Text
	end
end
check("...showing the orders", slotText ~= nil and slotText ~= "", slotText)
check("...one Operations screen, inside, painted", count("OpsScreen") == 1 and count("Ops") == 1)
check("...the station pads still there", count("StationPad") == 4 and Upg:Stations(player).pack ~= nil)
check(
	"...a hall full of machines",
	count("Sorter") == 1 and count("PackTable") == 2 and count("LoopBelt") == 4 and count("Mezzanine") == 1
)
do
	local out = 0
	for _, d in plot.items.frontHall:GetDescendants() do
		if d:IsA("BasePart") then
			local l = plot.cf:PointToObjectSpace(d.Position)
			if l.X < 4 or l.X > 72.5 or l.Z < -82 or l.Z > -34 then
				out += 1
			end
		end
	end
	check("...all of it where the shed and its yard's edge were", out == 0, out)
end
-- the packing still works from the hall's pad
local o = Order:Slots(player)[1]
if o.state ~= "open" then
	o.state, o.at = "wait", 0
	Engine.advance(1)
	o = Order:Slots(player)[1]
end
local k1 = next(o.items)
table.clear(p.storage)
p.storage[k1] = 1
stand(player, Order:PackPad(player).Position)
check("packing at the hall's pad", (o.packed[k1] or 0) >= 1)
stand(player, at(-40, -104))

-- The control tower and the solar roof -------------------------------------------------------------------------------------
check("buy the Control Tower", buy("controlTower"))
local beacon = plot.items.controlTower:FindFirstChild("Beacon")
check("...a tall tower with a beacon", beacon and beacon.Position.Y > 40, beacon and beacon.Position.Y)
check("buy the Solar Roof", buy("solarRoof"))
check("...panels on every roof", count("SolarPanel") >= 60, count("SolarPanel"))

-- The market hall -------------------------------------------------------------------------------------------------------------
local sellPad = Plots:Refs(player).standPad
check("buy The Market Hall", buy("marketHall"))
check("...the farm stand is gone", count("StandSign") == 0 and count("StandRoof") == 0)
check(
	"...the sell pad is at the market's checkout",
	(sellPad.Position - at(SPOTS.marketSell.X, SPOTS.marketSell.Z)).Magnitude < 1
)
local pads = Plots:Refs(player).pads
check(
	"...the buy-pads moved in",
	(pads[1].Position - at(SPOTS.marketPads[1].X, SPOTS.marketPads[1].Z)).Magnitude < 1
		and (pads[3].Position - at(SPOTS.marketPads[3].X, SPOTS.marketPads[3].Z)).Magnitude < 1
)
check("...stalls, fridges, a checkout", count("Stall") == 2 and count("Fridge") == 3 and count("Checkout") == 1)
check("...the spawn is outside it", SPOTS.spawnHub.X < SPOTS.market.X - PlotLayout.MARKET.X / 2)
table.clear(p.storage)
p.storage.strawberry = 5
local cash = p.cash
stand(player, sellPad.Position)
check("selling at the market's checkout", p.cash > cash and not p.storage.strawberry)
stand(player, at(-40, -104))

-- Scale, detail, roofs -----------------------------------------------------------------------------------------------------------
check(
	"the operation got much bigger",
	Flow.size(p) > size0 + 100 and #plot.items:GetDescendants() > parts0 + 400,
	`{Flow.size(p) - size0}, {#plot.items:GetDescendants() - parts0} parts`
)
check(
	"pipes, ducts and lights everywhere",
	count("Sprinkler") >= 14 and count("WallPipe") >= 18 and count("HVAC") >= 6 and count("Downspout") >= 12
)
Engine.advance(2.2) -- (the client looks the street over every couple of seconds)
Engine.workspace.CurrentCamera.CFrame = CFrame.lookAt(at(40, -60, 10), at(40, -40, 0))
Engine.advance(0.2)
local hallHidden = WareC.roofHidden()
Engine.workspace.CurrentCamera.CFrame = CFrame.lookAt(at(-15, -97, 8), at(-15, -90, 0))
Engine.advance(0.2)
local marketHidden = WareC.roofHidden()
Engine.workspace.CurrentCamera.CFrame = CFrame.lookAt(at(30, -180, 80), at(30, 0, 0))
Engine.advance(0.2)
check(
	"the roofs lift when the camera's inside the hall or the market",
	hallHidden > 0 and marketHidden > 0 and WareC.roofHidden() == 0,
	`{hallHidden} {marketHidden}`
)

-- Coming back -------------------------------------------------------------------------------------------------------------------
Engine.removePlayer(player)
Engine.advance(1)
local again = Engine.addPlayer("Ava", 901)
Engine.advance(2)
plot = Plots:Plot(again)
check(
	"back: no shed, one pad, one board, one screen",
	not plot.items:FindFirstChild("shed")
		and count("PackPad") == 1
		and count("BoardSlot") == 3
		and count("OpsScreen") == 1
)
check(
	"...no farm stand; the sell pad at the market",
	count("StandSign") == 0
		and (Plots:Refs(again).standPad.Position - at(SPOTS.marketSell.X, SPOTS.marketSell.Z)).Magnitude < 1
)
check(
	"...the trucks round the back",
	(function()
		for _, d in plot.items:GetDescendants() do
			if d.Name == "Vehicle" and d:GetAttribute("Kind") == "truck" and d:GetAttribute("Plan") ~= "truckBack" then
				return false
			end
		end
		return true
	end)()
)

do
	local bad = {}
	for _, w in Engine.warnings do
		if tostring(w):find("save failed") or tostring(w):find("tick failed") then
			table.insert(bad, tostring(w))
		end
	end
	check("no failed saves or ticks", #bad == 0, bad[1])
end
if #Engine.errors > 0 then
	for _, e in Engine.errors do
		print("ERROR " .. tostring(e))
	end
	failed += #Engine.errors
end
print(`HubSmoke: {passed} passed, {failed} failed`)
if failed > 0 then
	error(`{failed} failed`)
end
