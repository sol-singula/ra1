-- UI requests between controllers (so they don't require each other): open a panel, a screen shake, a flash.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Signal)

return {
	Open = Signal.new("Bus.Open"), -- (panelName, arg?) "inventory" | "craft" | "storage" | "camp" | "progress" |
	--                               "bestiary" | "collection" | "achievements" | "boards" | "friends" | "settings"
	Close = Signal.new("Bus.Close"), -- ()
	Shake = Signal.new("Bus.Shake"), -- (strength, seconds) a screen shake (FxController)
	Flash = Signal.new("Bus.Flash"), -- (color, seconds) a full-screen flash (HudController)
	Tap = Signal.new("Bus.Tap"), -- (name) a button or a named action (AnalyticsController counts them)
	Swing = Signal.new("Bus.Swing"), -- (itemKey, mode) your own swing, right away (AnimController)
}
