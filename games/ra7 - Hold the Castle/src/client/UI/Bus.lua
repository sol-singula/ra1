-- UI requests between controllers (so they don't require each other): open a panel, enter build mode, etc.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Signal)

return {
	Open = Signal.new("Bus.Open"), -- (panelName, arg?) "shop" | "tasks" | "friends" | "settings" | "jobs" | "picker"
	Close = Signal.new("Bus.Close"), -- ()
	BuildMode = Signal.new("Bus.BuildMode"), -- (on) build mode toggled (InputController / BuildController)
	Shake = Signal.new("Bus.Shake"), -- (strength, seconds) a screen shake (FxController)
	Flash = Signal.new("Bus.Flash"), -- (color, seconds) a full-screen flash (HudController)
	Tap = Signal.new("Bus.Tap"), -- (buttonName) a button was tapped (AnalyticsController counts them)
}
