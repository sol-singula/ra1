--[[
The game's event log. Services log here; TelemetryService (M10) ships the buffer to AnalyticsService.

  Telemetry.log(player, name, data?)
  Telemetry.events              { { userId, name, data, at } } since the last take()
  Telemetry.take()              returns and clears the buffer
  Telemetry.Logged(player, name, data)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Clock = require(ReplicatedStorage.Shared.Clock)
local Signal = require(ReplicatedStorage.Shared.Signal)

local Telemetry = {
	events = {},
	Logged = Signal.new(),
}

local MAX = 5000 -- the buffer never grows past this (oldest dropped)

function Telemetry.log(player, name, data)
	table.insert(Telemetry.events, { userId = player and player.UserId, name = name, data = data, at = Clock.now() })
	if #Telemetry.events > MAX then
		table.remove(Telemetry.events, 1)
	end
	Telemetry.Logged:Fire(player, name, data)
end

function Telemetry.take()
	local out = Telemetry.events
	Telemetry.events = {}
	return out
end

return Telemetry
