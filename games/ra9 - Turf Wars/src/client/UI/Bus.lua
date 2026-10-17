-- Signals between client controllers (so they don't require each other).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Signal)

return {
	Shake = Signal.new("Bus.Shake"), -- (strength, seconds) a camera shake (CameraController)
	Flash = Signal.new("Bus.Flash"), -- (color, seconds) a full-screen flash (HudController)
	Tap = Signal.new("Bus.Tap"), -- (name) a button or a named action (analytics)
	Fired = Signal.new("Bus.Fired"), -- (weaponKey, charge) your own shot, right away (the viewmodel's kick, the sound)
	Charge = Signal.new("Bus.Charge"), -- (charge 0..1 | nil) the bow's draw, every frame while drawing (HUD ring)
	Fire = Signal.new("Bus.Fire"), -- (down) the touch FIRE button: true pressed, false released (WeaponController)
	BuildPick = Signal.new("Bus.BuildPick"), -- (structureKey | nil) the build tray picked a piece (BuildController)
	Place = Signal.new("Bus.Place"), -- () the touch PLACE button (BuildController)
	Rotate = Signal.new("Bus.Rotate"), -- () turn the piece (BuildController)
	Weapon = Signal.new("Bus.Weapon"), -- (weaponKey) a weapon button (WeaponController)
	Slide = Signal.new("Bus.Slide"), -- () the touch SLIDE button (MoveController)
	Sprint = Signal.new("Bus.Sprint"), -- (on) the touch SPRINT toggle (MoveController)
	Crouch = Signal.new("Bus.Crouch"), -- (on) the touch CROUCH toggle (MoveController)
	Jump = Signal.new("Bus.Jump"), -- () the touch JUMP button (MoveController)
	Reload = Signal.new("Bus.Reload"), -- () the touch RELOAD button (WeaponController)
	CursorMode = Signal.new("Bus.CursorMode"), -- (on) Alt freed the mouse / went back to aiming (CameraController)
}
