-- Client copy of the profile view the server pushes ("Profile" partial updates) plus a change signal.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local Store = {
	state = {},
	Changed = Signal.new("Store.Changed"), -- (partial)
}

function Store.init()
	Net.listen("Profile", function(partial)
		for k, v in partial do
			Store.state[k] = v
		end
		Store.Changed:Fire(partial)
	end)
end

function Store.get(key)
	return Store.state[key]
end

return Store
