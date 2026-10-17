--[[
Which way you're playing: "touch" (a phone or tablet), "gamepad" (a console, or a pad on a PC) or "keyboard" (mouse
and keyboard). Worked out at the start from what the device has, then followed live: pick up a pad, tap the screen
of a touch laptop, and the controls on screen follow (Device.Changed). The server hears it too (the Device
attribute: the anti-cheat and the stats read it).

  Device.kind()                "touch" | "gamepad" | "keyboard"
  Device.isTouch()
  Device.Changed:Connect(fn(kind))
  Device.set(kind)             (tests)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Signal = require(ReplicatedStorage.Shared.Signal)

local Device = { Changed = Signal.new("Device.Changed") }

local function initial()
	local touch = UserInputService.TouchEnabled == true
	local keys = UserInputService.KeyboardEnabled == true
	local pad = UserInputService.GamepadEnabled == true
	if touch and not keys then
		return "touch"
	elseif pad and not keys then
		return "gamepad" -- (a console)
	end
	return "keyboard"
end

local current = initial()

local FROM_INPUT = {
	Touch = "touch",
	Keyboard = "keyboard",
	MouseButton1 = "keyboard",
	MouseButton2 = "keyboard",
	MouseMovement = "keyboard",
	MouseWheel = "keyboard",
}

function Device.kind()
	return current
end

function Device.isTouch()
	return current == "touch"
end

function Device.set(kind)
	if kind ~= current and (kind == "touch" or kind == "gamepad" or kind == "keyboard") then
		current = kind
		Device.Changed:Fire(kind)
	end
end

pcall(function()
	UserInputService.LastInputTypeChanged:Connect(function(t)
		local name = t and t.Name or ""
		local kind = FROM_INPUT[name] or (string.find(name, "^Gamepad") and "gamepad" or nil)
		if kind then
			Device.set(kind)
		end
	end)
end)

return Device
