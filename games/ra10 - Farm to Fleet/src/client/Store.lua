--[[
What the client knows, from the server's events: your profile (Cash, Gems, level, stage), your plot and the street,
the farm's soil, the guide's step, the animals, the order board and the calendar. Controllers read it and listen to
Store.Changed(partial).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local Store = { Changed = Signal.new("Store.Changed") }

local state = {
	profile = nil,
	plot = nil,
	farm = nil,
	guide = nil,
	animals = nil,
	orders = nil,
	daily = nil,
}

function Store.get(key)
	return state[key]
end

function Store.set(key, value)
	state[key] = value
	Store.Changed:Fire({ [key] = value })
end

-- Merge fields into a table entry (the server may send partial updates).
function Store.merge(key, fields)
	local t = state[key] or {}
	for k, v in fields do
		t[k] = v
	end
	state[key] = t
	Store.Changed:Fire({ [key] = t })
end

local EVENTS = { -- Net event -> the Store key it fills
	Profile = "profile",
	Plot = "plot",
	Farm = "farm",
	Guide = "guide",
	Animal = "animals",
	Orders = "orders",
	Daily = "daily",
}

function Store.init()
	for event, key in EVENTS do
		Net.listen(event, function(v)
			if (key == "profile" or key == "plot") and type(v) == "table" and type(state[key]) == "table" then
				Store.merge(key, v)
			else
				Store.set(key, v)
			end
		end)
	end
end

return Store
