-- Unit tests for src/shared/Formulas.lua, Format.lua and the data tables (the pure game math).
--   luaurun tests/Formulas.spec.luau      (from the game folder)
local Engine = loadModule("tests/mock/Engine.luau")
local tree = Engine.mountProject(".")
local Formulas = Engine.require(tree.shared.Formulas)
local Format = Engine.require(tree.shared.Format)
local Constants = Engine.require(tree.shared.Constants)
local CabinItems = Engine.require(tree.shared.Data.CabinItems)
local Resources = Engine.require(tree.shared.Data.Resources)
local Stops = Engine.require(tree.shared.Data.Stops)
local TrainUpgrades = Engine.require(tree.shared.Data.TrainUpgrades)

local passed, failed = 0, 0
local function check(name, cond, detail)
	if cond then
		passed += 1
	else
		failed += 1
		print("FAIL " .. name .. (detail ~= nil and (": " .. tostring(detail)) or ""))
	end
end

-- Fuel ---------------------------------------------------------------------------------------------------------
check("trip fuel: 2 with a plain engine", Formulas.fuelCost(0, 0) == 2)
check(
	"each overhaul burns less",
	Formulas.fuelCost(1, 0) == 1.6 and Formulas.fuelCost(2, 0) == 1.3 and Formulas.fuelCost(3, 0) == 1
)
check("fuel cost grows 15% every 10 km", Formulas.fuelCost(0, 10) == 2.3 and Formulas.fuelCost(0, 25) == 2.6)
check("engine stage is clamped", Formulas.fuelCost(9, 0) == 1 and Formulas.fuelCost(-1, 0) == 2)
check("the starting tank covers the first trip and a bit", Constants.START_FUEL >= Formulas.fuelCost(0, 0) * 2)
check(
	"fuel cans: 3 for a few players, more for a crowd, at most 9",
	Formulas.fuelCans(1) == 3 and Formulas.fuelCans(6) == 5 and Formulas.fuelCans(20) == 9
)

-- Time at a stop and milestones --------------------------------------------------------------------------------
check("doors open 2.5 minutes", Formulas.scavengeSeconds(0) == 150)
check("the searchlight adds time", Formulas.scavengeSeconds(1) == 165 and Formulas.scavengeSeconds(2) == 165)
check(
	"warnings fit inside the window",
	Constants.WARNING_AT < Constants.SCAVENGE_SECONDS and Constants.FINAL_AT < Constants.WARNING_AT
)
check("doors shut before the train leaves", Constants.DOORS_SHUT_AT < Constants.DOORS_SECONDS)
check("travel within the plan's 30-60 s", Constants.TRAVEL_SECONDS >= 30 and Constants.TRAVEL_SECONDS <= 60)
check(
	"milestones every 10 km",
	Formulas.milestones(9.9) == 0 and Formulas.milestones(10) == 1 and Formulas.milestones(25) == 2
)
check(
	"next milestone",
	Formulas.nextMilestone(0) == 10 and Formulas.nextMilestone(10) == 20 and Formulas.nextMilestone(12.5) == 20
)
check("a trip is 2.5 km: 4 trips to a milestone", Constants.MILESTONE_KM / Constants.SEGMENT_KM == 4)
check("round1", Formulas.round1(1.25) == 1.3 and Formulas.round1(2) == 2)

-- The bag ----------------------------------------------------------------------------------------------------------
check("bag holds 12", Formulas.bagCapacity({}) == 12 and Formulas.bagCapacity(nil) == 12)
check(
	"crate and locker add 2 each",
	Formulas.bagCapacity({ crate = true }) == 14 and Formulas.bagCapacity({ crate = true, locker = true }) == 16
)
check("tool rack: faster collecting", Formulas.collectHold({ toolrack = true }) < Formulas.collectHold({}))
check("count", Formulas.count({ wood = 2, scrap = 3 }) == 5 and Formulas.count(nil) == 0)

-- Cabin items -------------------------------------------------------------------------------------------------
check("15 cabin upgrades", #CabinItems.list == 15)
local keys, chainOk = {}, true
for i, item in CabinItems.list do
	keys[item.key] = i
	if item.needs and not keys[item.needs] then
		chainOk = false -- a step may only need one that comes before it
	end
end
check("every upgrade's requirement comes before it", chainOk)
local distinct = {}
for _, item in CabinItems.list do
	local sig = {}
	for _, k in Resources.MATERIALS do
		table.insert(sig, tostring(item.cost[k] or 0))
	end
	distinct[table.concat(sig, ",")] = true
end
local nDistinct = 0
for _ in distinct do
	nDistinct += 1
end
check("upgrades need different mixes of materials", nDistinct >= 12, nDistinct)
for _, item in CabinItems.list do
	check(
		`{item.key}: has a name, kind and benefit`,
		item.name and item.short and item.kind and item.benefit and next(item.cost) ~= nil
	)
	for k in item.cost do
		check(`{item.key}: costs a real material ({k})`, Resources.isMaterial(k))
	end
end
check("6 cabin colours", #CabinItems.COLORS == 6 and CabinItems.colorByKey.teal ~= nil)
local bunk, lamp = CabinItems.byKey.bunk, CabinItems.byKey.lamp
check("can build the bunk with 4 scrap and 2 cloth", Formulas.canBuild(bunk, {}, { scrap = 4, cloth = 2 }, {}) == true)
local ok, why = Formulas.canBuild(bunk, {}, { scrap = 3, cloth = 2 }, {})
check("not enough materials", ok == false and why == "materials")
ok, why = Formulas.canBuild(lamp, {}, { scrap = 9, parts = 9 }, {})
check("the lamp needs the bunk first", ok == false and why == "needs")
ok, why = Formulas.canBuild(bunk, { bunk = true }, { scrap = 9, cloth = 9 }, {})
check("can't build the bunk twice", ok == false and why == "built")
local map = CabinItems.byKey.mapboard
local all = { bunk = true, lamp = true, crate = true, bench = true, worksurface = true, workbench = true }
ok, why = Formulas.canBuild(map, all, { wood = 9, cloth = 9 }, {})
check("the map board needs its plans", ok == false and why == "plans")
check("with the plans it can be built", Formulas.canBuild(map, all, { wood = 9, cloth = 9 }, { map = 1 }) == true)
check(
	"a built item with looks can be restyled",
	Formulas.canBuild(CabinItems.byKey.finish, { finish = true, workbench = true }, {}, {}) == true
)
check("the first recommended upgrade is the bunk", Formulas.nextCabinItem({}).key == "bunk")
check("then the lamp", Formulas.nextCabinItem({ bunk = true }).key == "lamp")
check("after the workbench: insulation", Formulas.nextCabinItem(all).key == "insulation")
local everything = {}
for _, item in CabinItems.list do
	everything[item.key] = true
end
check(
	"nothing left when it's all built",
	Formulas.nextCabinItem(everything) == nil and Formulas.cabinCount(everything) == 15
)
check("cabin count", Formulas.cabinCount({ bunk = true, lamp = true }) == 2 and Formulas.cabinCount(nil) == 0)
check(
	"the starter kit isn't a free bunk",
	not Formulas.canAfford({ wood = 0, scrap = 2, parts = 0, cloth = 1 }, bunk.cost)
)

-- Train upgrades ---------------------------------------------------------------------------------------------------
check("two shared upgrades", #TrainUpgrades.list == 2 and TrainUpgrades.byKey.engine and TrainUpgrades.byKey.lamp)
check("engine: 3 stages, lamp: 2", #TrainUpgrades.byKey.engine.stages == 3 and #TrainUpgrades.byKey.lamp.stages == 2)
local s1 = TrainUpgrades.byKey.engine.stages[1]
check(
	"missing: everything at first",
	Formulas.stageMissing(s1, nil).scrap == 10 and Formulas.stageMissing(s1, {}).parts == 4
)
check("missing after some given", Formulas.stageMissing(s1, { scrap = 6 }).scrap == 4)
check(
	"done when all given",
	Formulas.stageDone(s1, { scrap = 10, parts = 4 }) and not Formulas.stageDone(s1, { scrap = 10 })
)
check("progress", math.abs(Formulas.stageProgress(s1, { scrap = 7 }) - 0.5) < 1e-9)
local s2 = TrainUpgrades.byKey.engine.stages[2]
check("plans count as a need", Formulas.stageMissing(s2, { scrap = 16, parts = 8, cloth = 4 }).plans == 1)
check("plans given: done", Formulas.stageDone(s2, { scrap = 16, parts = 8, cloth = 4, plans = true }))
check("overgiving can't go past 100%", Formulas.stageProgress(s1, { scrap = 99, parts = 99 }) == 1)

-- Stops and blueprints -------------------------------------------------------------------------------------------
check("4 stops in the first region", #Stops.list == 4 and Stops.REGION == "Overgrown Line")
check(
	"two stops from the start, more as you go",
	#Stops.available(0) == 2 and #Stops.available(5) == 3 and #Stops.available(15) == 4
)
check(
	"the next stop isn't the one you left",
	Formulas.pickStop(0, "ranger", 0).key == "timber" and Formulas.pickStop(0, "timber", 0.99).key == "ranger"
)
local picks = {}
for i = 0, 9 do
	picks[Formulas.pickStop(20, nil, i / 10).key] = true
end
check("far out, every stop can come up", picks.ranger and picks.timber and picks.signal and picks.platform)
for _, s in Stops.list do
	check(`{s.name}: plans, rich materials, light`, #s.plans > 0 and #s.rich > 0 and s.light ~= nil)
	for _, p in s.plans do
		check(`{s.name}: real plans ({p})`, Resources.BLUEPRINTS[p] ~= nil)
	end
end
local ranger = Stops.byKey.ranger
check("blueprint: the first one you don't have", Formulas.blueprintFor(ranger, {}, {}) == "map")
check("then the next", Formulas.blueprintFor(ranger, { map = 1 }, {}) == "specialist")
check("a used cabin plan isn't found again", Formulas.blueprintFor(ranger, {}, { mapboard = true }) == "specialist")
check("all found: the first again", Formulas.blueprintFor(ranger, { map = 1, specialist = 1 }, {}) == "map")
-- every blueprint can be found somewhere, and every train upgrade's plans exist
local findable = {}
for _, s in Stops.list do
	for _, p in s.plans do
		findable[p] = true
	end
end
for key in Resources.BLUEPRINTS do
	check(`blueprint {key} can be found at a stop`, findable[key] == true)
end
for _, u in TrainUpgrades.list do
	for _, st in u.stages do
		if st.plans then
			check(`{st.name}'s plans exist`, Resources.BLUEPRINTS[st.plans] ~= nil)
		end
	end
end

-- Crew eligibility --------------------------------------------------------------------------------------------
check("2 stops make a full crew member", Formulas.crewEligible(2, 10) and not Formulas.crewEligible(1, 10))
check("or 5 minutes aboard", Formulas.crewEligible(0, 300) and not Formulas.crewEligible(0, 299))

-- Format ---------------------------------------------------------------------------------------------------------
check("time", Format.time(95) == "1:35" and Format.time(0) == "0:00" and Format.time(3700) == "1h 1m")
check("numbers", Format.num(1234) == "1.2K" and Format.num(12) == "12")

print(`{passed} passed, {failed} failed`)
if failed > 0 then
	error("formula tests failed")
end
