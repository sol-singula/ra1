--[[
The warehouse's flow (master plan §13.2): from stage 4 the farm is four stations in a row, and the slowest one sets
the pace. Every rate is Cash a minute of produce (what it'd fetch at the stand), so the four compare directly.

  Grow   the fields: what the tiles bring in a minute with the crop being planted, the boosts and the tractor
  Pack   the packing lines: produce boxed a minute (PACK_PER_LINE each, faster with the robot packer and the hub's
         front hall and solar roof)
  Store  the forklifts: pallets put on the racks a minute (one each FORK_CYCLE seconds), times PALLET; and the racks
         hold SLOTS_PER_ROW pallets a row: full racks make Store the bottleneck whatever its rate
  Ship   the box trucks: TRUCK_TRIP seconds a trip (less with the loading dock and the back dock doors), truckCap
         pallets each; and the semis (stage 5): SEMI_CAP pallets in SEMI_TRIP seconds each

The produce itself: the conveyor brings the basket in (inbound), the lines box it, every PALLET of boxes is a
pallet waiting on the floor (staged, up to STAGE_MAX: then packing stops), the forklifts rack the pallets, the
trucks take them away, and each pallet pays PALLET x SHIP_MULT (more with the sorter and the wrapper) when its truck
gets back.

  Flow.rates(profile, now) -> { grow, pack, store, ship, slots, bottleneck, full }
  Flow.lines(owned) / Flow.forklifts(owned) / Flow.rows(owned) / Flow.trucks(owned) / Flow.truckCap(owned)
  Flow.cycle(owned) (a forklift's seconds a pallet) / Flow.trip(owned) (a truck's seconds)
  Flow.size(profile)   Operation Size: one number for how big the whole operation is (§13.1)
  Flow.STATIONS        { key, name, track } x 4, in flow order
]]
local Animals = require(script.Parent.Animals)
local Crops = require(script.Parent.Crops)
local Upgrades = require(script.Parent.Upgrades)

local Flow = {}

Flow.PALLET = 1000
Flow.PACK_PER_LINE = 1500
Flow.FORK_CYCLE = 30
Flow.TRUCK_TRIP = 60
Flow.SLOTS_PER_ROW = 24 -- (8 along a row, 3 high: World/PlotLayout.rackSlot)
Flow.STAGE_MAX = 6
Flow.INBOUND_MAX = 8 -- pallets' worth of crates waiting at the lines before the conveyor stops bringing more
Flow.SHIP_MULT = 2
Flow.SEMI_CAP = 24 -- pallets a semi takes
Flow.SEMI_TRIP = 120 -- a semi's seconds: in from the road, at the dock, away

Flow.STATIONS = {
	{ key = "grow", name = "GROW", track = "grow" },
	{ key = "pack", name = "PACK", track = "pack" },
	{ key = "store", name = "STORE", track = "store" },
	{ key = "ship", name = "SHIP", track = "ship" },
}

local function stat(owned, kind, default)
	return Upgrades.stat(owned or {}, kind, default)
end

function Flow.lines(owned)
	return stat(owned, "packLines", 1)
end
function Flow.forklifts(owned)
	return stat(owned, "forklifts", 1)
end
function Flow.rows(owned)
	return stat(owned, "racks", 1)
end
function Flow.trucks(owned)
	return stat(owned, "trucks", 1)
end
function Flow.truckCap(owned)
	return stat(owned, "truckCap", 4)
end
function Flow.semis(owned)
	return stat(owned, "semis", 0)
end
function Flow.semiTrip(owned)
	return Flow.SEMI_TRIP * (1 - stat(owned, "docks", 0))
end
function Flow.cycle(owned)
	return Flow.FORK_CYCLE / (1 + stat(owned, "forkSpeed", 0))
end
function Flow.trip(owned)
	return Flow.TRUCK_TRIP * (1 - stat(owned, "tripCut", 0)) * (1 - stat(owned, "docks", 0))
end

-- What the fields bring in a minute: every tile growing the crop they plant, round and round with the tractor
local function growRate(p, now)
	local owned = p.owned or {}
	local key = p.settings and p.settings.crop
	if not (key and Crops[key] and Crops[key].level <= (p.level or 1)) then
		key = Crops.best(p.level or 1)
	end
	local c = Crops[key]
	local speed = 1
		+ Animals.boost(p, "grow", now)
		+ (c.type == "fruit" and Animals.boost(p, "fruitGrow", now) or 0)
		+ stat(owned, "grow", 0)
	local need = c.grow * (stat(owned, "sprinkler", 0) > 0 and Crops.WATER_CUT or 1) / speed
	local tractor = stat(owned, "autoharvest", nil)
	local wait = tractor and tractor / (1 + Animals.boost(p, "machine", now)) / 2 or 10
	local each = c.value * (c.type == "veg" and 1 + Animals.boost(p, "vegPrice", now) or 1)
	local tiles = stat(owned, "soil", Upgrades.START_SOIL)
	return tiles * each * 60 / (need + wait)
end

function Flow.rates(p, now)
	local owned = p.owned or {}
	local r = {
		grow = math.floor(growRate(p, now) + 0.5),
		pack = math.floor(
			Flow.lines(owned) * Flow.PACK_PER_LINE * (1 + stat(owned, "packSpeed", 0) + stat(owned, "hall", 0)) + 0.5
		),
		store = math.floor(Flow.forklifts(owned) * Flow.PALLET * 60 / Flow.cycle(owned) + 0.5),
		ship = math.floor(
			(
				Flow.trucks(owned) * Flow.truckCap(owned) / Flow.trip(owned)
				+ Flow.semis(owned) * Flow.SEMI_CAP / Flow.semiTrip(owned)
			)
					* Flow.PALLET
					* 60
				+ 0.5
		),
		slots = Flow.rows(owned) * Flow.SLOTS_PER_ROW,
	}
	local racked = p.flow and p.flow.racked or 0
	if racked >= r.slots then
		r.bottleneck, r.full = "store", true
	else
		local best
		for _, s in Flow.STATIONS do
			if not best or r[s.key] < r[best] then
				best = s.key
			end
		end
		r.bottleneck = best
	end
	return r
end

function Flow.size(p)
	local n = 0
	for key in p.owned or {} do
		local u = Upgrades[key]
		if u then
			n += 5 * u.stage
		end
	end
	for _, st in p.animals or {} do
		n += 2 * (st.level or 1)
	end
	return n + (p.flow and p.flow.racked or 0)
end

return Flow
