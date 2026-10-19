--[[
What the client knows, from the server's events: your profile (cash, lifetime), your territory, the tiles, the
business's numbers, the upgrades, the task, the town's boost, the shop, the market. Controllers read it and listen
to Store.Changed(partial).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local Store = { Changed = Signal.new("Store.Changed") }

local state = {}

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
	Territory = "territory",
	Crops = "crops",
	Business = "business",
	Machines = "machines",
	Upgrades = "upgrades",
	Task = "task",
	Boost = "boost",
	Shop = "shop",
	Market = "market",
	Leaderboards = "leaderboards",
	Town = "town",
}
local MERGED = { profile = true, territory = true }

function Store.init()
	for event, key in EVENTS do
		Net.listen(event, function(v)
			if MERGED[key] and type(v) == "table" and type(state[key]) == "table" then
				Store.merge(key, v)
			else
				Store.set(key, v)
			end
		end)
	end
end

return Store
