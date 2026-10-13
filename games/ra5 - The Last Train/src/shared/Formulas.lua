-- Pure game math (tests/Formulas.spec.luau checks every function here).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CabinItems = require(ReplicatedStorage.Shared.Data.CabinItems)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Resources = require(ReplicatedStorage.Shared.Data.Resources)
local Stops = require(ReplicatedStorage.Shared.Data.Stops)
local TrainUpgrades = require(ReplicatedStorage.Shared.Data.TrainUpgrades)

local Formulas = {}

local function round1(x)
	return math.floor(x * 10 + 0.5) / 10
end
Formulas.round1 = round1

-- Fuel for the next trip: the engine stage sets the base, and it grows 15% for every 10 km already travelled.
function Formulas.fuelCost(engineStage, distanceKm)
	local base = Constants.FUEL_COST[math.clamp(engineStage, 0, #Constants.FUEL_COST - 1) + 1]
	local steps = math.floor((distanceKm or 0) / Constants.MILESTONE_KM)
	return round1(base * (1 + steps * Constants.FUEL_COST_GROWTH))
end

-- How long the doors stay open.
function Formulas.scavengeSeconds(lampStage)
	return Constants.SCAVENGE_SECONDS + ((lampStage or 0) >= 1 and Constants.SEARCHLIGHT_BONUS or 0)
end

-- Fuel cans at a stop for this many players.
function Formulas.fuelCans(players)
	return math.clamp(
		Constants.FUEL_CANS_MIN + math.floor((players or 1) / 3),
		Constants.FUEL_CANS_MIN,
		Constants.FUEL_CANS_MAX
	)
end

-- Milestones passed at this distance (10 km = 1).
function Formulas.milestones(distanceKm)
	return math.floor((distanceKm or 0) / Constants.MILESTONE_KM + 1e-6)
end

function Formulas.nextMilestone(distanceKm)
	return (Formulas.milestones(distanceKm) + 1) * Constants.MILESTONE_KM
end

-- Field bag size from what's built in the cabin.
function Formulas.bagCapacity(built)
	built = built or {}
	return Constants.BAG_BASE + (built.crate and 2 or 0) + (built.locker and 2 or 0)
end

function Formulas.collectHold(built)
	return (built and built.toolrack) and Constants.TOOLRACK_HOLD or Constants.COLLECT_HOLD
end

-- Does storage hold at least `cost`?
function Formulas.canAfford(storage, cost)
	for key, n in cost do
		if (storage[key] or 0) < n then
			return false
		end
	end
	return true
end

-- Can this cabin item be built now? Returns ok, reason ("built" | "needs" | "plans" | "materials").
function Formulas.canBuild(item, built, storage, blueprints)
	built, storage, blueprints = built or {}, storage or {}, blueprints or {}
	if built[item.key] and not item.variants then
		return false, "built"
	end
	if item.needs and not built[item.needs] then
		return false, "needs"
	end
	if not built[item.key] then
		if item.plans and (blueprints[item.plans] or 0) < 1 then
			return false, "plans"
		end
		if not Formulas.canAfford(storage, item.cost) then
			return false, "materials"
		end
	end
	return true, nil
end

-- The item the build board recommends: the lowest-numbered one not built yet whose "needs" is met.
function Formulas.nextCabinItem(built)
	built = built or {}
	for _, item in CabinItems.list do
		if not built[item.key] and (not item.needs or built[item.needs]) then
			return item
		end
	end
	return nil
end

function Formulas.cabinCount(built)
	local n = 0
	for _, item in CabinItems.list do
		if built and built[item.key] then
			n += 1
		end
	end
	return n
end

-- A train upgrade stage's remaining needs: { resource = amount still missing } (empty when complete).
function Formulas.stageMissing(stage, given)
	local missing = {}
	for key, n in stage.cost do
		local left = n - ((given and given[key]) or 0)
		if left > 0 then
			missing[key] = left
		end
	end
	if stage.plans and not (given and given.plans) then
		missing.plans = 1
	end
	return missing
end

function Formulas.stageDone(stage, given)
	return next(Formulas.stageMissing(stage, given)) == nil
end

-- 0..1 progress through a stage (materials and plans together).
function Formulas.stageProgress(stage, given)
	local total, have = 0, 0
	for key, n in stage.cost do
		total += n
		have += math.min(n, (given and given[key]) or 0)
	end
	if stage.plans then
		total += 1
		have += (given and given.plans) and 1 or 0
	end
	return total > 0 and have / total or 1
end

-- The next stop: one the crew can reach at this distance, not the one it just left. `roll` is 0..1.
function Formulas.pickStop(distanceKm, lastKey, roll)
	local options = {}
	for _, s in Stops.available(distanceKm) do
		if s.key ~= lastKey then
			table.insert(options, s)
		end
	end
	if #options == 0 then
		options = Stops.available(distanceKm)
	end
	local i = math.clamp(math.floor((roll or 0) * #options) + 1, 1, #options)
	return options[i]
end

-- Which blueprint a player finds at a stop: the first one in the stop's list they don't have yet (cabin plans they
-- haven't used, or train plans), else the first in the list.
function Formulas.blueprintFor(stop, blueprints, built)
	blueprints, built = blueprints or {}, built or {}
	for _, key in stop.plans do
		local info = Resources.BLUEPRINTS[key]
		local usedFor = (key == "map" and built.mapboard) or (key == "specialist" and built.specialist)
		if info and (blueprints[key] or 0) == 0 and not usedFor then
			return key
		end
	end
	return stop.plans[1]
end

-- Is a crew member a full member of the record crew?
function Formulas.crewEligible(stops, seconds)
	return (stops or 0) >= Constants.CREW_MIN_STOPS or (seconds or 0) >= Constants.CREW_MIN_SECONDS
end

-- Total materials in a bag or storage table.
function Formulas.count(t)
	local n = 0
	for _, v in t or {} do
		n += v
	end
	return n
end

-- Upgrade stage index helpers
function Formulas.upgradeStage(upgradeKey, stages)
	return (stages and stages[upgradeKey]) or 0
end

function Formulas.upgradeInfo(upgradeKey)
	return TrainUpgrades.byKey[upgradeKey]
end

return Formulas
