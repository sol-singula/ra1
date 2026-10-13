-- The client's copy of what the server tells it, plus a change signal:
--   state.storage / blueprints / cabin / cabinIndex / souvenirs / visited / best / records / train ...  ("Profile")
--   state.expedition   the expedition view ("Expedition": phase, distance, fuel, stop, goal...)
--   state.bag          the unbanked field bag ("Bag")
--   state.hall         the Hall of Records list ("Hall")
--   state.recovery     the left-behind objective, or false ("Recovery")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local Store = {
	state = { bag = { items = {}, plans = {}, count = 0, cap = 12 }, recovery = false },
	Changed = Signal.new("Store.Changed"), -- (partial)
}

local function set(key, value)
	Store.state[key] = value
	Store.Changed:Fire({ [key] = value })
end

function Store.init()
	Net.listen("Profile", function(partial)
		for k, v in partial do
			Store.state[k] = v
		end
		Store.Changed:Fire(partial)
	end)
	Net.listen("Expedition", function(view)
		view.receivedAt = workspace:GetServerTimeNow()
		set("expedition", view)
	end)
	Net.listen("Bag", function(bag)
		set("bag", bag)
	end)
	Net.listen("Hall", function(hall)
		set("hall", hall)
	end)
	Net.listen("Recovery", function(rec)
		set("recovery", rec)
	end)
end

function Store.get(key)
	return Store.state[key]
end

-- Seconds left in the current phase (from the server's clock), or nil.
function Store.timeLeft()
	local ends = workspace:GetAttribute("PhaseEnds")
	if type(ends) ~= "number" or ends <= 0 then
		return nil
	end
	return math.max(0, ends - workspace:GetServerTimeNow())
end

function Store.phase()
	return workspace:GetAttribute("Phase") or (Store.state.expedition and Store.state.expedition.phase) or "lobby"
end

-- The distance right now (it grows smoothly during a trip).
function Store.distance()
	local e = Store.state.expedition
	if not e then
		return 0
	end
	if e.phase == "traveling" and e.rate and e.rate > 0 and e.phaseStarted then
		local t = math.clamp(workspace:GetServerTimeNow() - e.phaseStarted, 0, Constants.TRAVEL_SECONDS)
		return (e.distance or 0) + t * e.rate
	end
	return e.distance or 0
end

return Store
