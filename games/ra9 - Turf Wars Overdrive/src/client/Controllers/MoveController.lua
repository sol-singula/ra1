--[[
Movement (master plan §6): sprint, slide, the front flip, and the knockback you take.

  * Sprint: hold Shift (or the left stick in, or the touch SPRINT toggle): faster, the view a little wider. Drawing
    a bow slows you to DRAW_SPEED whatever you're doing.
  * Slide: C or Ctrl while running (or the touch SLIDE button): a short burst forward, low to the ground, on a
    cooldown. The camera dips with it.
  * Front flip: every FLIP_EVERY-th jump the camera rolls a full turn forward through the jump. Cosmetic only (your
    direction and speed don't change), and off in the settings if you don't like it.
  * Knockback: the server's Hurt carries a push; your client owns your body, so it applies it here.

Movement runs on your client (Roblox's way: the client owns its character); the server only checks the outcome.
]]
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Bus = require(script.Parent.Parent.UI.Bus)
local Store = require(script.Parent.Parent.Store)
local CameraController = require(script.Parent.CameraController)
local WeaponController = require(script.Parent.WeaponController)

local MoveController = { Name = "MoveController", Order = 25 }

local player = Players.LocalPlayer
local sprinting = false
local slideUntil, slideReady = 0, 0
local slideDir
local jumps = 0
local flipStart
local FLIP_SECONDS = 0.5

local function humanoid()
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid"), c and c:FindFirstChild("HumanoidRootPart")
end

function MoveController.sprinting()
	return sprinting
end

function MoveController.setSprint(on)
	sprinting = on == true
	Net.send("Sprint", sprinting)
end

function MoveController.slide()
	local hum, root = humanoid()
	if not hum or not root or os.clock() < slideReady then
		return false
	end
	local move = hum.MoveDirection or Vector3.zero
	if move.Magnitude < 0.1 then
		local look = workspace.CurrentCamera and workspace.CurrentCamera.CFrame.LookVector or Vector3.new(0, 0, -1)
		move = Vector3.new(look.X, 0, look.Z)
	end
	if move.Magnitude < 0.01 then
		return false
	end
	slideDir = move.Unit
	slideUntil = os.clock() + Constants.SLIDE_SECONDS
	slideReady = os.clock() + Constants.SLIDE_COOLDOWN
	Net.send("Slide")
	Bus.Tap:Fire("slide")
	return true
end

function MoveController.sliding()
	return os.clock() < slideUntil
end

-- Called for every jump; the FLIP_EVERY-th one flips.
function MoveController.jumped()
	jumps += 1
	local profile = Store.get("profile")
	local on = not (profile and profile.settings and profile.settings.flips == false)
	if on and jumps % Constants.FLIP_EVERY == 0 then
		flipStart = os.clock()
		return true
	end
	return false
end

function MoveController.flipping()
	return flipStart ~= nil and os.clock() - flipStart < FLIP_SECONDS
end

local function step()
	local hum, root = humanoid()
	if not hum then
		return
	end
	local speed = Constants.WALK_SPEED
	if sprinting then
		speed = Constants.SPRINT_SPEED
	end
	if WeaponController.drawing() then
		speed = Constants.DRAW_SPEED
	end
	if MoveController.sliding() and root and slideDir then
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity =
			Vector3.new(slideDir.X * Constants.SLIDE_SPEED, v.Y, slideDir.Z * Constants.SLIDE_SPEED)
		hum.CameraOffset = Vector3.new(0, -1.6, 0)
	else
		hum.CameraOffset = Vector3.new(0, 0, 0)
	end
	hum.WalkSpeed = speed
	CameraController.setFov("sprint", (sprinting and (hum.MoveDirection or Vector3.zero).Magnitude > 0.1) and 8 or nil)
	-- the flip: a full forward roll of the view through the jump
	if flipStart then
		local f = (os.clock() - flipStart) / FLIP_SECONDS
		if f >= 1 then
			flipStart = nil
			CameraController.offset("flip", nil)
		else
			local eased = f < 0.5 and 2 * f * f or 1 - (-2 * f + 2) ^ 2 / 2
			CameraController.offset("flip", CFrame.Angles(-eased * math.pi * 2, 0, 0))
		end
	end
end

local function hookCharacter(c)
	local hum = c:WaitForChild("Humanoid", 5)
	if not hum then
		return
	end
	jumps = 0
	hum.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Jumping then
			MoveController.jumped()
		end
	end)
end

function MoveController:init()
	ContextActionService:BindAction("TW_Sprint", function(_, state)
		if state == Enum.UserInputState.Begin then
			MoveController.setSprint(true)
		elseif state == Enum.UserInputState.End then
			MoveController.setSprint(false)
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
	ContextActionService:BindAction("TW_Slide", function(_, state)
		if state == Enum.UserInputState.Begin then
			MoveController.slide()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.C, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonB)
	Bus.Sprint:Connect(function(on)
		MoveController.setSprint(on)
	end)
	Bus.Slide:Connect(function()
		MoveController.slide()
	end)
	Net.listen("Hurt", function(h)
		local _, root = humanoid()
		if root and typeof(h.knock) == "Vector3" then
			root.AssemblyLinearVelocity += h.knock
		end
		CameraController.shake(h.head and 0.5 or 0.3, 0.25)
	end)
	if player.Character then
		task.spawn(hookCharacter, player.Character)
	end
	player.CharacterAdded:Connect(hookCharacter)
	RunService.RenderStepped:Connect(step)
end

return MoveController
