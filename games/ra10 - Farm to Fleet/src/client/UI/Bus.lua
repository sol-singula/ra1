-- Signals between client controllers (so they don't require each other).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Signal)

return {
	Flash = Signal.new("Bus.Flash"), -- (color, seconds) a full-screen flash (HudController)
	Tap = Signal.new("Bus.Tap"), -- (name) a button or a named action (analytics)
	Panel = Signal.new("Bus.Panel"), -- (name | nil) open one menu panel (calendar, shop, street, franchise), close the rest
}
