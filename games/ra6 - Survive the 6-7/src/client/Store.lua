--[[
The client's copy of what the server tells it, plus a change signal (Store.Changed fires { key = value }):
  profile    level, XP, perks, kits, mastery, bestiary, collection, achievements, looks, titles, records ("Profile")
  run        the run: phase, day, night, phase times, difficulty, event, roster, votes ("Run")
  me         this survivor: status, hp, stamina, buffs, armor, bleedUntil, respawnAt ("Me")
  inv        the inventory: slots, selected, capacity ("Inv")
  team       everyone in the run: hp, status, position ("Team", twice a second)
  camp       the camp: tier, fuel, structures, next tier, storage ("Camp")
  objective  { primary, optional, markers } ("Objective")
  boss       Mega Kermy's bar, or false ("Boss")
  tutorial   the guide's step, or false ("Tutorial")
  board      the leaderboard on screen ("Board")
  friends    friends' runs ("Friends")
  results    the end of the last run ("Results")
  storage    the camp chest's contents while you're at it ("Storage")
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local Store = {
	state = {
		profile = nil,
		run = { phase = "idle" },
		me = { status = "none", hp = 100, maxHp = 100, stamina = 100, staminaMax = 100, buffs = {} },
		inv = { slots = {}, selected = 1, capacity = 12, hotbar = 6 },
		team = {},
		camp = { tier = 1, structures = {} },
		objective = nil,
		boss = false,
		tutorial = false,
		board = nil,
		friends = {},
		results = nil,
		storage = {},
		settings = { music = true, shake = true, fx = true },
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
	for _, key in
		{
			"Run",
			"Me",
			"Inv",
			"Team",
			"Camp",
			"Objective",
			"Boss",
			"Tutorial",
			"Board",
			"Friends",
			"Results",
			"Storage",
		}
	do
		local field = string.lower(string.sub(key, 1, 1)) .. string.sub(key, 2)
		Net.listen(key, function(value)
			if key == "Camp" and value and value.storage then
				Store.state.storage = value.storage
			end
			set(field, value)
		end)
	end
end

function Store.get(key)
	return Store.state[key]
end

function Store.phase()
	return workspace:GetAttribute("Phase") or (Store.state.run and Store.state.run.phase) or "idle"
end

function Store.isNight()
	local p = Store.phase()
	return p == "night" or p == "boss"
end

-- Seconds left in the current phase, or nil.
function Store.timeLeft()
	local ends = workspace:GetAttribute("PhaseEnds")
	if type(ends) ~= "number" or ends <= 0 then
		return nil
	end
	return math.max(0, ends - workspace:GetServerTimeNow())
end

-- How far through the current phase (0..1), for the sky.
function Store.phaseProgress()
	local start, ends = workspace:GetAttribute("PhaseStart"), workspace:GetAttribute("PhaseEnds")
	if type(start) ~= "number" or type(ends) ~= "number" or ends <= start then
		return 0, 0
	end
	local t = workspace:GetServerTimeNow() - start
	return math.clamp(t / (ends - start), 0, 1), ends - start
end

function Store.status()
	local me = Store.state.me
	return me and me.status or "none"
end

function Store.alive()
	return Store.status() == "alive"
end

-- In this run's roster (not waiting for the next one).
function Store.inRun()
	local run = Store.state.run
	if not run or not run.roster then
		return false
	end
	for _, r in run.roster do
		if r.userId == Players.LocalPlayer.UserId and r.active then
			return true
		end
	end
	return false
end

-- The selected hotbar slot's contents: slotId, { key, n }.
function Store.held()
	local inv = Store.state.inv
	local id = "h" .. tostring(inv.selected or 1)
	return id, inv.slots[id]
end

return Store
