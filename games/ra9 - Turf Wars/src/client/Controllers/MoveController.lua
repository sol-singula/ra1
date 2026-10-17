--[[
Movement (master plan §6): sprint, slide, the front flip, and the knockback you take.

  * Sprint: hold Shift (or the left stick in, or the touch SPRINT toggle): faster, the view a little wider. Drawing
    a bow slows you to DRAW_SPEED whatever you're doing. On touch, pushing the thumbstick all the way forward runs
    by itself (auto-run), until you ease off it.
  * Crouch: hold C or Ctrl (or the touch CROUCH toggle, or B on a gamepad): lower and slower, a smaller target, the
    bow steadier in your hands. Everyone sees you crouch (MoveService lowers you on the server too).
  * Slide: crouch while sprinting (or the touch SLIDE button): a short burst forward, low to the ground, on a
    cooldown. The camera dips with it, and if you're still holding crouch you stay down at the end.
  * Front flip: every FLIP_EVERY-th jump is a flip jump. Your camera is never touched (no spin, no dip, no zoom):
    your view stays exactly as it is. Cosmetic only (your direction and speed don't change), and off in the settings.
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
local Device = require(script.Parent.Parent.UI.Device)
local Store = require(script.Parent.Parent.Store)
local CameraController = require(script.Parent.CameraController)
local WeaponController = require(script.Parent.WeaponController)

local MoveController = { Name = "MoveController", Order = 25 }

local player = Players.LocalPlayer
local sprinting = false
local held, autoRun = false, false -- (sprint asked for: Shift, the stick, the RUN toggle; or the thumbstick pushed)
-- auto-run: the thumbstick pushed this far, mostly forward, starts it; easing off under STOP ends it
local AUTO_RUN = { start = 0.92, stop = 0.6, forward = 0.7 }
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

local function applySprint()
	local on = held or autoRun
	if on ~= sprinting then
		sprinting = on
		Net.send("Sprint", sprinting)
	end
end

function MoveController.setSprint(on)
	held = on == true
	applySprint()
end

function MoveController.autoRunning()
	return autoRun
end

-- Roblox's own touch thumbstick: how far it's pushed (its move vector, -Z forward), or nil without one
local controls, nextLook = nil, 0
local function stick()
	if not controls and os.clock() >= nextLook then
		nextLook = os.clock() + 2 -- (the PlayerModule may not be there yet: look again in a bit)
		pcall(function()
			local scripts = player:FindFirstChild("PlayerScripts")
			local pm = scripts and scripts:FindFirstChild("PlayerModule")
			controls = pm and require(pm):GetControls() or nil
		end)
	end
	if not controls then
		return nil
	end
	local ok, v = pcall(function()
		return controls:GetMoveVector()
	end)
	return ok and typeof(v) == "Vector3" and v or nil
end

-- Auto-run (touch only): from the thumbstick's move vector v (nil: none), on or off; the hysteresis keeps a thumb
-- resting near the edge from flickering it
function MoveController.autoRunFrom(v)
	local on = false
	if v and Device.isTouch() then
		local push = math.min(1, Vector2.new(v.X, v.Z).Magnitude)
		local forward = -v.Z
		if autoRun then
			on = push >= AUTO_RUN.stop and forward > 0
		else
			on = push >= AUTO_RUN.start and forward >= AUTO_RUN.forward * push
		end
	end
	if on ~= autoRun then
		autoRun = on
		applySprint()
	end
	return autoRun
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
	if Device.isTouch() or autoRun then
		MoveController.autoRunFrom(stick())
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
	if player:GetAttribute("Flag") then
		speed *= Constants.CTF.CARRY_SPEED -- (Capture the Flag: the flag on your back slows you a little)
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
	-- the flip jump: the camera is left alone (no dip, no zoom, no spin)
	if flipStart and os.clock() - flipStart >= FLIP_SECONDS then
		flipStart = nil
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
