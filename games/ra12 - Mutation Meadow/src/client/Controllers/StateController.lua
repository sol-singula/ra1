-- Keeps ClientState in step with the server: a Snapshot first (and after any gap), then State deltas.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local ClientState = require(script.Parent.Parent.ClientState)

local StateController = {}

function StateController:Start()
	Net.onState(function(changes, snapshot)
		if snapshot then
			ClientState.load(snapshot)
		else
			ClientState.apply(changes)
		end
	end)
end

return StateController
