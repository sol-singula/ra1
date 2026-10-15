--[[
The client's copy of what the server tells it, plus a change signal (Store.Changed fires { key = value }):
  profile    level, XP, title, colours, blueprints, research, achievements, journal counts, settings ("Profile")
  me         this player: hp, buffs, where (raft | water | island | visiting), plot, visiting, holding ("Me")
  inv        the inventory: slots, selected, capacity ("Inv")
  raft       the raft you're on (yours, or the one you're visiting): tier, tiles, pieces, colours, speed ("Raft")
  voyage     the plot's voyage: state, destination, progress, event ("Voyage")
  island     the island beside the plot, or false ("Island")
  weather    { phase, storm, ends, clock } ("Weather")
  tutorial   the guide's step, or false ("Tutorial")
  journal    the discovery journal ("Journal")
  fish       the rod: { state = cast | bite | caught | away | off } ("Fish")
  board      the leaderboard on screen ("Board")
  friends    friends' servers ("Friends")
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local Store = {
	state = {
		profile = nil,
		me = { hp = 100, maxHp = 100, buffs = {}, where = "raft", plot = nil, visiting = nil },
		inv = { slots = {}, selected = 1, capacity = 16, hotbar = 6 },
		raft = { tier = 1, tiles = 4, pieces = {}, colours = {}, speed = 1, cargo = 16, owner = nil },
		voyage = { state = "docked" },
		island = false,
		weather = { phase = "day", storm = false, clock = 9 },
		tutorial = false,
		journal = nil,
		fish = { state = "off" },
		board = nil,
		friends = {},
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
		{ "Me", "Inv", "Raft", "Voyage", "Island", "Weather", "Tutorial", "Journal", "Fish", "Board", "Friends" }
	do
		local field = string.lower(string.sub(key, 1, 1)) .. string.sub(key, 2)
		Net.listen(key, function(value)
			set(field, value)
		end)
	end
end

function Store.get(key)
	return Store.state[key]
end

-- The weather's phase ("day" | "night"), from the workspace (set by the server) or the last view.
function Store.phase()
	return workspace:GetAttribute("Phase") or (Store.state.weather and Store.state.weather.phase) or "day"
end

function Store.isNight()
	return Store.phase() == "night"
end

function Store.storm()
	return workspace:GetAttribute("Storm") == true or (Store.state.weather and Store.state.weather.storm) == true
end

-- Seconds left in the day or night, or nil.
function Store.timeLeft()
	local ends = workspace:GetAttribute("PhaseEnds")
	if type(ends) ~= "number" or ends <= 0 then
		return nil
	end
	return math.max(0, ends - workspace:GetServerTimeNow())
end

-- How far through the day or night (0..1), and its length.
function Store.phaseProgress()
	local start, ends = workspace:GetAttribute("PhaseStart"), workspace:GetAttribute("PhaseEnds")
	if type(start) ~= "number" or type(ends) ~= "number" or ends <= start then
		return 0, 0
	end
	local t = workspace:GetServerTimeNow() - start
	return math.clamp(t / (ends - start), 0, 1), ends - start
end

function Store.alive()
	local me = Store.state.me
	return me ~= nil and (me.hp or 0) > 0
end

-- The raft on screen is your own (not one you're visiting).
function Store.onOwnRaft()
	local raft = Store.state.raft
	return raft and raft.owner == Players.LocalPlayer.UserId
end

-- The selected hotbar slot's contents: slotId, { key, n }.
function Store.held()
	local inv = Store.state.inv
	local id = "h" .. tostring(inv.selected or 1)
	return id, inv.slots[id]
end

-- The voyage's state: "docked" | "sailing" | "island" | "home".
function Store.voyageState()
	local v = Store.state.voyage
	return v and v.state or "docked"
end

return Store
