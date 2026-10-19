--[[
Phase F on the mock engine, server and client together: semis on the shared road (master plan §13.1). The semis wait
for the back docks, then each comes in from the road for a big load, backs its trailer up to its own dock (on every
client), and pays when it's gone; everything saves.

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
print(`FreightSmoke: {passed} passed, {failed} failed`)
if failed > 0 then
	error(`{failed} failed`)
end
