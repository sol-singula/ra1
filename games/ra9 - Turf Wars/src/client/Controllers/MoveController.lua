--[[
Movement (master plan §6): sprint, slide, the front flip, and the knockback you take.

  * Sprint: hold Shift (or the left stick in, or the touch SPRINT toggle): faster, the view a little wider. Drawing
    a bow slows you to DRAW_SPEED whatever you're doing.
  * Crouch: hold C or Ctrl (or the touch CROUCH toggle, or B on a gamepad): lower and slower, a smaller target, the
    bow steadier in your hands. Everyone sees you crouch (MoveService lowers you on the server too).
  * Slide: crouch while sprinting (or the touch SLIDE button): a short burst forward, low to the ground, on a
    cooldown. The camera dips with it, and if you're still holding crouch you stay down at the end.
  * Front flip: every FLIP_EVERY-th jump is a flip jump. Your view stays level (no spinning camera): it only gives a
    small forward dip and a wider view through the jump, so it feels quick without making anyone dizzy. Cosmetic
    only (your direction and speed don't change), and off in the settings if you don't like it.
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
local crouching = false
local camY = 0 -- (the view's height offset, eased)
local baseHip
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

function MoveController.crouching()
	return crouching
end

local function applyHip()
	local hum = humanoid()
	if not hum then
		return
	end
	baseHip = baseHip or hum.HipHeight
	hum.HipHeight = crouching and math.max(0.2, baseHip - Constants.CROUCH_DROP) or baseHip
end

-- Crouch on or off; crouching while you sprint (and move) is a slide.
function MoveController.setCrouch(on)
	on = on == true
	if on == crouching then
		return
	end
	local hum = humanoid()
	if on and sprinting and hum and (hum.MoveDirection or Vector3.zero).Magnitude > 0.1 then
		MoveController.slide()
	end
	crouching = on
	applyHip()
	Net.send("Crouch", crouching)
	Bus.Tap:Fire(on and "crouch" or "stand")
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

local function step(dt)
	local hum, root = humanoid()
	if not hum then
		return
	end
	local speed = Constants.WALK_SPEED
	if sprinting and not crouching then
		speed = Constants.SPRINT_SPEED
	elseif crouching then
		speed = Constants.CROUCH_SPEED
	end
	if WeaponController.drawing() then
		speed = Constants.DRAW_SPEED
	end
	if MoveController.sliding() and root and slideDir then
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity =
			Vector3.new(slideDir.X * Constants.SLIDE_SPEED, v.Y, slideDir.Z * Constants.SLIDE_SPEED)
	end
	-- the view's height: down for a slide, a little down crouched (the body sinks too), eased
	local want = MoveController.sliding() and -1.6 or (crouching and -0.5 or 0)
	camY += (want - camY) * math.min(1, (dt or 1 / 60) * 14)
	hum.CameraOffset = Vector3.new(0, camY, 0)
	hum.WalkSpeed = speed
	CameraController.setFov("sprint", (sprinting and (hum.MoveDirection or Vector3.zero).Magnitude > 0.1) and 8 or nil)
	-- the flip jump: a small forward dip of the view and a wider view, then back (never a full spin)
	if flipStart then
		local f = (os.clock() - flipStart) / FLIP_SECONDS
		if f >= 1 then
			flipStart = nil
			CameraController.offset("flip", nil)
			CameraController.setFov("flip", nil)
		else
			local k = math.sin(f * math.pi)
			CameraController.offset("flip", CFrame.Angles(-math.rad(9) * k, 0, 0))
			CameraController.setFov("flip", 7 * k)
		end
	end
end

local function hookCharacter(c)
	local hum = c:WaitForChild("Humanoid", 5)
	if not hum then
		return
	end
	jumps = 0
	baseHip, crouching, camY = hum.HipHeight, false, 0
	hum.StateChanged:Connect(function(old, new)
		if new == Enum.HumanoidStateType.Jumping then
			MoveController.jumped()
		elseif new == Enum.HumanoidStateType.Landed then
			WeaponController.landed(old == Enum.HumanoidStateType.Freefall)
		end
	end)
end

function MoveController:init()
	WeaponController.bindMovement(MoveController.sprinting, MoveController.crouching, MoveController.sliding)
	ContextActionService:BindAction("TW_Sprint", function(_, state)
		if state == Enum.UserInputState.Begin then
			MoveController.setSprint(true)
		elseif state == Enum.UserInputState.End then
			MoveController.setSprint(false)
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
	ContextActionService:BindAction("TW_Crouch", function(_, state)
		if state == Enum.UserInputState.Begin then
			MoveController.setCrouch(true)
		elseif state == Enum.UserInputState.End then
			MoveController.setCrouch(false)
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.C, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonB)
	Bus.Crouch:Connect(function(on)
		MoveController.setCrouch(on)
	end)
	Bus.Jump:Connect(function()
		local hum = humanoid()
		if hum then
			hum.Jump = true
		end
	end)
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
