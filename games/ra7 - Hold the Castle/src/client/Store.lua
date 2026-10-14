-- The client's copy of what the server tells it, plus a change signal:
--   state.profile     coins, level, looks, titles, tasks, gift, settings ("Profile")
--   state.match       the match view ("Match": phase, ends, fightEnds, fallen, active, number, result)
--   state.me          this player in this match ("Me": team, job, level, gear, food, potions, stats...)
--   state.bag         { stone, wood, gold, cap } ("Bag")
--   state.shrines     { { health, state, dwarves, monsters, rate, wards, stage }, ... } ("Shrines")
--   state.board       the longest holds ("Leaderboard")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local Store = {
	state = {
		profile = nil,
		match = nil,
		me = { team = false },
		bag = { stone = 0, wood = 0, gold = 0, cap = 24 },
		shrines = {},
		board = { rows = {} },
		settings = { fx = true, shake = true, music = true },
	},
	Changed = Signal.new("Store.Changed"), -- (partial)
}

local function set(key, value)
	Store.state[key] = value
	Store.Changed:Fire({ [key] = value })
end

function Store.init()
	Net.listen("Profile", function(view)
		Store.state.profile = view
		if view.settings then
			Store.state.settings = view.settings
		end
		Store.Changed:Fire({ profile = view })
	end)
	Net.listen("Match", function(view)
		view.receivedAt = workspace:GetServerTimeNow()
		set("match", view)
	end)
	Net.listen("Me", function(view)
		set("me", view)
	end)
	Net.listen("Bag", function(bag)
		set("bag", bag)
	end)
	Net.listen("Shrines", function(list)
		set("shrines", list)
	end)
	Net.listen("Leaderboard", function(board)
		set("board", board)
	end)
end

function Store.get(key)
	return Store.state[key]
end

function Store.phase()
	return workspace:GetAttribute("Phase") or (Store.state.match and Store.state.match.phase) or "intermission"
end

-- Seconds left in the current phase (the fight's clock during the fight and the last stand), or nil.
function Store.timeLeft()
	local phase = Store.phase()
	local ends = (phase == "fight" or phase == "laststand") and workspace:GetAttribute("FightEnds")
		or workspace:GetAttribute("PhaseEnds")
	if type(ends) ~= "number" or ends <= 0 then
		return nil
	end
	return math.max(0, ends - workspace:GetServerTimeNow())
end

function Store.team()
	local me = Store.state.me
	return me and me.team or nil
end

function Store.inMatch()
	local p = Store.phase()
	return p == "build" or p == "plague" or p == "fight" or p == "laststand"
end

return Store
