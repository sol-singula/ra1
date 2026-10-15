-- UI requests between controllers (so they don't require each other): open a panel, a screen shake, a flash.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Signal)

return {
	Open = Signal.new("Bus.Open"), -- (panelName, arg?) "build" | "inventory" | "craft" | "storage" | "map" | "raft" |
	--                               "journal" | "progress" | "boards" | "friends" | "visit" | "settings"
	Close = Signal.new("Bus.Close"), -- ()
	Shake = Signal.new("Bus.Shake"), -- (strength, seconds) a screen shake (FxController)
	Flash = Signal.new("Bus.Flash"), -- (color, seconds) a full-screen flash (HudController)
	Tap = Signal.new("Bus.Tap"), -- (name) a button or a named action (AnalyticsController counts them)
	Swing = Signal.new("Bus.Swing"), -- (itemKey, mode, target?) your own action, right away (AnimController)
	Place = Signal.new("Bus.Place"), -- (pieceKey) the build panel picked a piece: BuildController shows the spots
	Menu = Signal.new("Bus.Menu"), -- (kind?) the start menu: open it, or go "world" / "online" (MenuController)
	Quick = Signal.new("Bus.Quick"), -- ("start", how) | ("place") | ("stop"): the QUICK button is held, ticks, let go
	--                                 (BuildController builds the recommended piece where you look)
}
