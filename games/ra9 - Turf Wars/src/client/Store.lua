--[[
What the client knows, from the server's events: the match (phase, timer, frontline, map), you (team, health,
weapon, ammo, build budget), your profile (wins, streak, stats, settings) and, in Capture the Flag, the flags and
the scores ("ctf": Net "Ctf"). Controllers read it and listen to Store.Changed(partial).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local Store = { Changed = Signal.new("Store.Changed") }

local state = {
	match = { phase = "loading", frontline = 0, loseRed = -80, loseBlue = 80 },
	me = { alive = false, budget = 0, budgetMax = 100 },
	profile = nil,
}

function Store.get(key)
	return state[key]
end

function Store.set(key, value)
	state[key] = value
	Store.Changed:Fire({ [key] = value })
end

-- Merge fields into a table entry (the server sends partial "Me" updates).
function Store.merge(key, fields)
	local t = state[key] or {}
	for k, v in fields do
		t[k] = v
	end
	state[key] = t
	Store.Changed:Fire({ [key] = t })
end

function Store.phase()
	return state.match.phase
end

function Store.team()
	return state.me.team
end

function Store.init()
	Net.listen("Match", function(m)
		Store.set("match", m)
	end)
	Net.listen("Me", function(m)
		Store.merge("me", m)
	end)
	Net.listen("Profile", function(p)
		Store.set("profile", p)
	end)
	Net.listen("Ctf", function(c)
		Store.set("ctf", c)
	end)
end

return Store
