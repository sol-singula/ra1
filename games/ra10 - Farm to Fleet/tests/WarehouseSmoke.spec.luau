--[[
Phase E on the mock engine, server and client together: stage 4 (the Warehouse) and the four-station flow (master
plan §13.1, §13.2). The warehouse takes the place of its site: two slices built, the rest a steel skeleton; station
pads and the Operations screen out front; empty racks, the staging floor, the first forklift and box truck. The
conveyor brings the basket in, the lines pack it into pallets, the forklifts rack them, the trucks drive them away
(on every client) and pay when they're back; every pallet racked is a pallet on a slot. The slowest station is red
on the screen, the HUD and its pad, the guide points at its fix, and buying it counts a fix. Full racks make Store
the bottleneck. Bays add slices and rows, bigger trucks rebuild the trucks, the forklifts work their loops on the
client, the roof lifts off when the camera's inside, every track can be bought out, the hub's deed opens stage 5,
and the stock and a truck's trip come back after a rejoin.

  luaurun tests/WarehouseSmoke.spec.luau
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Vector3 = Engine.Vector3
local CFrame = Engine.CFrame
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
local Ware = service("WarehouseService")
local Data = service("PlayerDataService")
local Economy = service("EconomyService")
local Upgrades = Engine.require(tree.shared.Data.Upgrades)
local Flow = Engine.require(tree.shared.Data.Flow)
local GuideData = Engine.require(tree.shared.Data.Guide)
local PlotLayout = Engine.require(tree.shared.World.PlotLayout)
local FarmBuilder = Engine.require(tree.shared.World.FarmBuilder)
local Trips = Engine.require(tree.shared.World.Trips)

local function now()
	return Engine.workspace:GetServerTimeNow()
end
local function stand(pl, pos)
	Engine.moveTo(pl, pos + Vector3.new(0, 3, 0))
	Engine.advance(0.6)
end

-- Flow on its own ------------------------------------------------------------------------------------------------------
do
	local p = { owned = { warehouse = 1, soil39 = 1 }, level = 17, flow = { racked = 0 } }
	local r = Flow.rates(p, 0)
	check("one of each station: pack 1500/min", r.pack == Flow.PACK_PER_LINE, r.pack)
	check("...store: one forklift's pallets", r.store == math.floor(Flow.PALLET * 60 / Flow.FORK_CYCLE + 0.5), r.store)
	check("...ship: one truck of 4", r.ship == math.floor(4 * Flow.PALLET * 60 / Flow.TRUCK_TRIP + 0.5), r.ship)
	check("...one rack row", r.slots == Flow.SLOTS_PER_ROW)
	local slowest = "grow"
	for _, k in { "pack", "store", "ship" } do
		if r[k] < r[slowest] then
			slowest = k
		end
	end
	check("the bottleneck is the slowest station", r.bottleneck == slowest, r.bottleneck)
	p.owned.packLine2, p.owned.forklift2, p.owned.irrigation = 1, 1, 1
	local r2 = Flow.rates(p, 0)
	check("a packing line adds a line's worth", r2.pack == 2 * Flow.PACK_PER_LINE)
	check("a forklift doubles the racking", r2.store == 2 * r.store)
	check("irrigation grows more", r2.grow > r.grow)
	p.flow.racked = r2.slots
	check("full racks: Store is the bottleneck", Flow.rates(p, 0).bottleneck == "store" and Flow.rates(p, 0).full)
	local seen = {}
	for _, key in Upgrades.LIST do
		local u = Upgrades[key]
		if u.track then
			seen[u.track] = (seen[u.track] or 0) + 1
		end
	end
	check(
		"every station has its track of fixes",
		seen.grow >= 3 and seen.pack >= 3 and seen.store >= 8 and seen.ship >= 3
	)
	local missing = {}
	for _, key in Upgrades.LIST do
		if Upgrades[key].stage == 4 and Upgrades[key].kind ~= "stage" and not FarmBuilder.BUILD[key] then
			table.insert(missing, key)
		end
	end
	check("every stage-4 buy builds something you can see", #missing == 0, table.concat(missing, ","))
	local t0 = Trips.local_("truck", 0, PlotLayout.SPOTS.lot[1])
	local t1 = Trips.local_("truck", 1, PlotLayout.SPOTS.lot[1])
	check(
		"a truck's trip starts and ends in its lot spot",
		(t0 - PlotLayout.SPOTS.lot[1]).Magnitude < 0.01 and (t1 - PlotLayout.SPOTS.lot[1]).Magnitude < 0.01
	)
	local atDoor, look = Trips.local_("truck", 0.35, PlotLayout.SPOTS.lot[1])
	check(
		"...backs up to the truck door",
		(atDoor - PlotLayout.SPOTS.truckDoor).Magnitude < 8 and look.Z < -0.9,
		(atDoor - PlotLayout.SPOTS.truckDoor).Magnitude
	)
end

-- A farm at the end of stage 3 ---------------------------------------------------------------------------------------------
local player = Engine.addPlayer("Ava", 901)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.runScript(tree.client.Main)
Engine.advance(1.5)
local p = Data:Get(player)
local plot = Plots:Plot(player)
local GuideC = Engine.require(tree.client.Controllers.GuideController)
local OpsC = Engine.require(tree.client.Controllers.OpsController)
local WareC = Engine.require(tree.client.Controllers.WarehouseController)
local VehicleC = Engine.require(tree.client.Controllers.VehicleController)
local function buy(key)
	p.cash = math.max(p.cash, Upgrades[key].cost + 10)
	while (p.level or 1) < Upgrades[key].level do
		Economy:AddXP(player, 2000, "test")
	end
	return Upg:Buy(player, key)
end
local function away()
	stand(player, PlotLayout.toWorld(plot.index, -40, -104))
end
local function at(x, z, y)
	return PlotLayout.toWorld(plot.index, x, z, y)
end
away()
for _, key in Upgrades.LIST do
	if Upgrades[key].stage <= 3 then
		buy(key)
	end
end
check("stage 3 done: stage 4", p.stage == 4)
p.guide.step = GuideData.byKey.warehouseBuild.index
Engine.advance(1.2)
check(
	"the guide: build the warehouse (or earn it first)",
	GuideC.state().key == "warehouseBuild" or string.find(GuideC.state().key, "^earn:warehouse:") ~= nil,
	GuideC.state().key
)
check("no Operations strip before it", not OpsC.refs.panel.Visible)
local size0 = Flow.size(p)

-- The warehouse ------------------------------------------------------------------------------------------------------------
check("buy The Warehouse", buy("warehouse"))
local wh = plot.items:FindFirstChild("warehouse")
check("...where its site was", wh ~= nil and plot.items:FindFirstChild("warehouseDeed") == nil)
local function count(name, root, cls)
	local n = 0
	for _, d in (root or plot.items):GetDescendants() do
		if d.Name == name and (not cls or d:IsA(cls)) then
			n += 1
		end
	end
	return n
end
local function shownPallets(name)
	local n = 0
	for _, d in plot.items:GetDescendants() do
		if d.Name == name and d:IsA("Model") then
			local base = d:FindFirstChild("Boxes")
			if base and base.Transparency < 0.5 then
				n += 1
			end
		end
	end
	return n
end
check("...the rest stands as steel skeleton", count("Skeleton", wh, "Folder") == 3)
local back1, back2 = 0, 0
for _, d in wh:GetDescendants() do
	if d.Name == "BackWall" then
		if d:GetAttribute("Slice") == 1 then
			back1 += 1
		elseif d:GetAttribute("Slice") == 2 then
			back2 += 1
		end
	end
end
check("...open inside between its slices, closed at the back", back1 == 0 and back2 > 0, `{back1} {back2}`)
check("...a roof that knows its plot", count("Roof", wh) == 2)
check("...four station pads", count("StationPad", wh) == 4 and Upg:Stations(player).ship ~= nil)
check("...the Operations screen", count("OpsScreen", wh) == 1)
check(
	"...one rack row of empty slots",
	count("RackPallet", wh, "Model") == Flow.SLOTS_PER_ROW and shownPallets("RackPallet") == 0
)
check("...the staging floor, empty", count("Staged", wh, "Model") == 6 and shownPallets("Staged") == 0)
check("...a forklift", count("Forklift", wh, "Model") == 1)
local truck1 = nil
for _, d in wh:GetDescendants() do
	if d.Name == "Vehicle" and d:GetAttribute("Kind") == "truck" then
		truck1 = d
	end
end
check("...and a box truck", truck1 ~= nil)
do
	local out = 0
	for _, d in wh:GetDescendants() do
		if d:IsA("BasePart") then
			local l = plot.cf:PointToObjectSpace(d.Position)
			if math.abs(l.X) > 81 or math.abs(l.Z) > 111 then
				out += 1
			end
		end
	end
	check("...all of it on the plot", out == 0, out)
end
check(
	"the stand's pads don't offer the stations' fixes",
	(function()
		for _, o in Upg:Offer(player) do
			if o.upgrade.track then
				return false
			end
		end
		return true
	end)()
)
Engine.advance(1.5)
local lot = at(PlotLayout.SPOTS.lot[1].X, PlotLayout.SPOTS.lot[1].Z)
check(
	"the truck waits in the lot",
	(truck1:GetPivot().Position - lot).Magnitude < 1,
	(truck1:GetPivot().Position - lot).Magnitude
)
check(
	"the Operations strip shows the four stations",
	OpsC.refs.panel.Visible and OpsC.refs.rows[4].rate.Text:find("/min") ~= nil
)
local b = Ware:Bottleneck(player)
local redRow = table.find({ "grow", "pack", "store", "ship" }, b)
check(
	"...the bottleneck in red",
	b ~= nil and OpsC.refs.rows[redRow].name.TextColor3 ~= Engine.globals.Color3.fromRGB(255, 255, 255),
	b
)
check("...the screen says it", wh:FindFirstChild("OpsScreen", true).Ops.Line.Text == "BOTTLENECK: " .. string.upper(b))
local pads = Upg:Stations(player)
check("...its pad is red", pads[b]:GetAttribute("Bottleneck") == true and pads[b].Over.Line.Text ~= "")
check("the guide: the first pallet", GuideC.state().key == "pallet1", GuideC.state().key)
check("...pointing at the lines", typeof(GuideC.state().target) == "Vector3")

-- The flow: intake, pack, store, ship ----------------------------------------------------------------------------------------
p.orders.live = {}
table.clear(p.storage)
p.storage.pumpkin = 30 -- 14,400 at the stand: a pumpkin and more
local took = Ware:Intake(player)
check(
	"the conveyor's load goes into the warehouse",
	took and p.flow.inbound > 0 and (p.storage.pumpkin or 0) < 30,
	p.flow.inbound
)
local inbound0 = p.flow.inbound
Engine.advance(1)
check("...crates wait at the lines", count("Inbound", wh) > 0 and (function()
	for _, d in wh:GetDescendants() do
		if d.Name == "Inbound" and d.Transparency < 0.5 then
			return true
		end
	end
	return false
end)())
Engine.advance(45)
check("the lines pack them into pallets", (p.stats.pallets or 0) >= 1 and p.flow.inbound < inbound0, p.stats.pallets)
check("the forklift racks them", (p.stats.racked or 0) >= 1, p.stats.racked)
check(
	"every pallet racked is a pallet on a slot",
	shownPallets("RackPallet") == p.flow.racked and shownPallets("Staged") == p.flow.staged,
	`{shownPallets("RackPallet")} vs {p.flow.racked}, {shownPallets("Staged")} vs {p.flow.staged}`
)
Engine.advance(1.2)
check(
	"the guide moves along the flow",
	GuideC.state().key == "shipped1" or GuideC.state().key == "racked1",
	GuideC.state().key
)
-- trucks go with a full load, or after waiting a while
Engine.advance(Ware.WAIT + 1)
local trip = p.flow.trucks["1"]
check("a truck takes the pallets away", trip and trip.pallets >= 1, trip and trip.pallets)
check("...on its trip", truck1:GetAttribute("TripStart") == (trip and trip.at))
Engine.advance(0.5)
check("...the client drives it", VehicleC.moving() >= 1)
local length = trip and trip.length or Flow.TRUCK_TRIP
local cash0 = p.cash
local pallets = trip and trip.pallets or 0
Engine.advance(math.max(0.1, (trip and trip.at or now()) + length + 1 - now()))
local bonus = Upgrades.stat(p.owned, "orderPrice", 0)
check(
	"back: it pays for every pallet",
	p.cash - cash0 >= math.floor(pallets * Flow.PALLET * Flow.SHIP_MULT * (1 + bonus)),
	p.cash - cash0
)
check("...counted", (p.stats.palletsShipped or 0) >= pallets and p.stats.biggestShipment > 0)
-- the next load: watch it back up to the door
p.flow.racked = math.max(p.flow.racked, 4)
Engine.advance(0.6)
local trip2 = p.flow.trucks["1"]
check("a full load goes at once", trip2 and trip2.pallets == 4)
Engine.advance(math.max(0.1, trip2.at + trip2.length * 0.35 - now()))
local door = at(PlotLayout.SPOTS.truckDoor.X, PlotLayout.SPOTS.truckDoor.Z)
check(
	"...backed up to the truck door",
	(truck1:GetPivot().Position - door).Magnitude < 9,
	(truck1:GetPivot().Position - door).Magnitude
)
Engine.advance(trip2.length)
Engine.advance(1.5)
check("...parked again", truck1:GetAttribute("TripStart") == nil or p.flow.trucks["1"])
check("the guide: fix the bottleneck", GuideC.state().key == "fix1", GuideC.state().key)
b = Ware:Bottleneck(player)
check("...pointing at the red pad", (GuideC.state().target - Upg:Stations(player)[b].Position).Magnitude < 0.1)

-- The forklifts work, the roof lifts --------------------------------------------------------------------------------------------
p.flow.staged = 3
Engine.advance(0.6)
local fork = nil
for _, d in wh:GetDescendants() do
	if d.Name == "Forklift" then
		fork = d
	end
end
check("busy: the forklift works its loop (on the client)", fork:GetAttribute("Busy") == true and WareC.working() >= 1)
local from = fork:GetPivot().Position
Engine.advance(1.5)
check("...it moves", (fork:GetPivot().Position - from).Magnitude > 1)
local inside = at(30, -10, 8)
Engine.workspace.CurrentCamera.CFrame = CFrame.lookAt(inside, at(30, 10, 0))
Engine.advance(0.2)
check("the roof lifts while the camera's inside", WareC.roofHidden() > 0)
Engine.workspace.CurrentCamera.CFrame = CFrame.lookAt(at(30, -150, 60), at(30, 0, 0))
Engine.advance(0.2)
check("...and comes back when it's out", WareC.roofHidden() == 0)

-- Fixing bottlenecks --------------------------------------------------------------------------------------------------------
local fixes = 0
for _ = 1, 3 do
	local bn = Ware:Bottleneck(player)
	local u = Upgrades.trackNext(p.owned, bn)
	if u then
		local before = Flow.rates(p, now())[bn]
		buy(u.key)
		local after = Flow.rates(p, now())[bn]
		if after > before or u.kind == "racks" then
			fixes += 1
		end
		Engine.advance(0.6)
	end
end
check("buying the bottleneck's fix makes that station faster", fixes == 3, fixes)
check("...counted as fixes", (p.stats.fixes or 0) == 3, p.stats.fixes)
Engine.advance(1.2)
check(
	"the guide: after three fixes, the street's steps (the calendar first)",
	GuideC.state().key == "calendar1",
	GuideC.state().key
)
-- (past the scripted steps: the generated goals)
p.guide.step = 1e3
service("GuideService"):Check(player)
Engine.advance(1.2)
check(
	"the guide: past its steps, it follows the bottleneck",
	GuideC.state().generated and string.sub(GuideC.state().key, 1, 4) == "fix:",
	GuideC.state().key
)

-- Full racks ------------------------------------------------------------------------------------------------------------------
local slots = Flow.rates(p, now()).slots
p.flow.racked = slots
for n = 1, Flow.trucks(p.owned) do
	p.flow.trucks[tostring(n)] = { at = now(), length = 999, pallets = 1 }
end
Engine.advance(1)
check("full racks: STORE is red", Ware:Bottleneck(player) == "store")
check("...every slot shows a pallet", shownPallets("RackPallet") == slots, shownPallets("RackPallet"))
check(
	"...the screen and the strip say so",
	wh:FindFirstChild("OpsScreen", true).Ops.Line.Text == "RACKS FULL!"
		and OpsC.refs.alert.Text:find("RACKS FULL") ~= nil
)
for n = 1, Flow.trucks(p.owned) do
	p.flow.trucks[tostring(n)] = false
end
p.flow.racked = 2

-- More warehouse: bays, rows, bigger trucks -------------------------------------------------------------------------------------
check(
	"buy every fix there is, track by track",
	(function()
		for _, key in Upgrades.LIST do
			local u = Upgrades[key]
			if u.track and u.stage == 4 and not p.owned[key] then
				if not buy(key) then
					return false
				end
			end
		end
		return true
	end)()
)
Engine.advance(1)
check(
	"eight rack rows, all their slots",
	count("RackPallet", nil, "Model") == 8 * Flow.SLOTS_PER_ROW,
	count("RackPallet", nil, "Model")
)
check("the whole building: no skeleton, one back wall", count("Skeleton", nil, "Folder") == 0 and (function()
	local slices = {}
	for _, d in plot.items:GetDescendants() do
		if d.Name == "BackWall" then
			slices[d:GetAttribute("Slice")] = true
		end
	end
	local n = 0
	for _ in slices do
		n += 1
	end
	return n == 1 and slices[#PlotLayout.SLICES - 1]
end)())
check("five forklifts, four box trucks", count("Forklift", nil, "Model") == 5 and (function()
	local n = 0
	for _, d in plot.items:GetDescendants() do
		if d.Name == "Vehicle" and d:GetAttribute("Kind") == "truck" then
			n += 1
		end
	end
	return n == 4
end)())
check(
	"bigger trucks: every truck rebuilt longer",
	(function()
		for _, d in plot.items:GetDescendants() do
			if d.Name == "Vehicle" and d:GetAttribute("Kind") == "truck" then
				local box = d:FindFirstChild("TruckBox")
				if not box or box.Size.Z < 10 then
					return false
				end
			end
		end
		return true
	end)()
)
check(
	"every station pad: all built",
	(function()
		for _, pad in Upg:Stations(player) do
			local track = pad:GetAttribute("Track")
			local nxt = Upgrades.trackNext(p.owned, track)
			if nxt and nxt.stage == 4 then
				return false
			end
			if not nxt and pad.Over.Line.Text ~= "ALL BUILT" and not pad:GetAttribute("Bottleneck") then
				return false
			end
		end
		return true
	end)()
)
check("the operation's size has grown", Flow.size(p) > size0 + 100, Flow.size(p) - size0)

-- Stock and trips come back after a rejoin --------------------------------------------------------------------------------------
p.flow.racked = 30
p.flow.trucks["1"] = { at = now(), length = 120, pallets = 4 }
Engine.advance(0.6)
local racked = p.flow.racked
local ships = p.stats.palletsShipped
Engine.removePlayer(player)
Engine.advance(1)
local again = Engine.addPlayer("Ava", 901)
Engine.advance(2)
local p2 = Data:Get(again)
check(
	"back: the racks hold what they held",
	p2.flow.racked >= racked - 4 and shownPallets("RackPallet") == p2.flow.racked,
	`{p2.flow.racked} / {shownPallets("RackPallet")}`
)
local t1 = nil
for _, d in Plots:Plot(again).items:GetDescendants() do
	if d.Name == "Vehicle" and d:GetAttribute("Park") == 1 and d:GetAttribute("Kind") == "truck" then
		t1 = d
	end
end
check("...the truck out on its trip shows it again", t1 and t1:GetAttribute("TripStart") == p2.flow.trucks["1"].at)
Engine.advance(125)
check("...and pays when it's back", p2.stats.palletsShipped >= ships + 4, p2.stats.palletsShipped - ships)

-- The hub's deed ---------------------------------------------------------------------------------------------------------------
p = p2
player = again
check("the hub's deed: stage 5", buy("hubDeed") and p.stage == 5)

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
print(`WarehouseSmoke: {passed} passed, {failed} failed`)
if failed > 0 then
	error(`{failed} failed`)
end
