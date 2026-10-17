--[[
The first-person camera (master plan §6): locked first person, a steady field of view that widens a little when
you sprint and tightens as you draw (a light zoom for aiming; on a phone the view is a little wider and the zoom a
little deeper, so you see more round you on a small screen and aim as tightly as on a monitor), small shakes (hits, the horn) that the player can
turn off, and the sensitivity setting. Other controllers add their own offsets through CameraController.offset
(the slide's dip), applied after Roblox's camera each frame.

The mouse: hidden in play (the HUD draws the crosshair), shown and free while a menu needs it: the panel (shop,
pass, locker, goals), a question card, the results card (once it closes, the wait for the next game is free running
about, so the mouse goes back to the camera), and any time you press Alt (Alt again: back to aiming).
CameraController.mouseFree() says which; the bow and the build
tray don't fire while it's true, so a click in the shop is only a click in the shop. Once a menu closes the lock is
put back every frame (Roblox can show the cursor again on its own), and a Modal button left inside a closed panel
stops being Modal (a Modal button keeps the cursor out even when its panel is hidden) until the panel is back.

Cinematics (the tutorial): CameraController.takeover(fn) hands the camera to fn(camera, dt), called every frame
instead of the first-person lock (the camera goes Scriptable; shakes still play on top). CameraController.release(look)
gives it back: Custom again, on your character, locked first person, looking along `look` (or where you face).

  CameraController.takeover(fn)   CameraController.release(look?)   CameraController.takenOver() -> bool
  CameraController.parked()       { [button] = true }: Modal buttons switched off while their panel is hidden
  CameraController.cursorMode()   CameraController.setCursorMode(on)   Alt: the mouse free to click anything
  CameraController.turn(dx, dy)   turn the view by a thumb's drag in points (the touch FIRE button: Bus.Look)
  CameraController.lookUp(rad, ceiling?)   tilt the view up (or down) a little (the win's fireworks)
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Net = require(game:GetService("ReplicatedStorage").Shared.Net)
local Bus = require(script.Parent.Parent.UI.Bus)
local Device = require(script.Parent.Parent.UI.Device)
local Layout = require(script.Parent.Parent.UI.Layout)
local Store = require(script.Parent.Parent.Store)

local CameraController = { Name = "CameraController", Order = 5 }

local player = Players.LocalPlayer
local BASE_FOV = 80
CameraController.PHONE_FOV = 6 -- (degrees wider on a phone: Device.isPhone)
local fov = BASE_FOV
local shakeUntil, shakeStrength = 0, 0
local offsets = {} -- [name] = CFrame applied after the camera

local fovs = {} -- [name] = degrees added (the draw tightens, sprinting widens)

function CameraController.offset(name, cf)
	offsets[name] = cf
end

function CameraController.setFov(name, delta)
	fovs[name] = delta
end

function CameraController.targetFov()
	local f = BASE_FOV + (Device.isPhone() and CameraController.PHONE_FOV or 0)
	for _, d in fovs do
		f += d
	end
	return f
end

function CameraController.shake(strength, seconds)
	local profile = Store.get("profile")
	if profile and profile.settings and profile.settings.shake == false then
		return
	end
	shakeStrength = math.max(shakeStrength, strength)
	shakeUntil = math.max(shakeUntil, os.clock() + seconds)
end

-- Alt frees the mouse any time (to click the chat, the admin panel, a button), Alt again goes back to aiming
local cursorMode = false

function CameraController.cursorMode()
	return cursorMode
end

function CameraController.setCursorMode(on)
	cursorMode = on == true
	Bus.CursorMode:Fire(cursorMode)
end

function CameraController.mouseFree()
	-- (the results card after a win doesn't free it: you stay in play, free to run about; Tab opens the menu)
	return cursorMode or Layout.panel() or Layout.modalOpen()
end

local mouseShown
local function setMouse(free)
	pcall(function()
		if UserInputService.MouseIconEnabled ~= free then
			UserInputService.MouseIconEnabled = free
		end
		-- (a Modal button frees it too; this keeps it free even if Roblox's camera tries to lock it again)
		UserInputService.MouseBehavior = free and Enum.MouseBehavior.Default or Enum.MouseBehavior.LockCenter
	end)
	mouseShown = free
end

-- Modal buttons inside something hidden: not Modal while hidden, Modal again once shown
local parked = {} -- [button] = true
local nextScan = 0

local function shown(gui)
	local g = gui
	while g and g:IsA("GuiObject") do
		if g.Visible == false then
			return false
		end
		g = g.Parent
	end
	return not (g and g:IsA("ScreenGui") and g.Enabled == false)
end

local function parkModals(force)
	local t = os.clock()
	if not force and t < nextScan then
		return
	end
	nextScan = t + 0.25
	local pg = player:FindFirstChild("PlayerGui")
	if not pg then
		return
	end
	for b in parked do
		if not b.Parent then
			parked[b] = nil
		elseif shown(b) then
			b.Modal = true
			parked[b] = nil
		end
	end
	for _, d in pg:GetDescendants() do
		if d:IsA("GuiButton") and d.Modal and not shown(d) then
			d.Modal = false
			parked[d] = true
		end
	end
end

function CameraController.parked()
	return parked
end

-- Cinematics ---------------------------------------------------------------------------------------------------
local driver -- fn(cam, dt) while a cinematic has the camera

function CameraController.takeover(fn)
	driver = fn
	local cam = workspace.CurrentCamera
	if cam then
		pcall(function()
			cam.CameraType = Enum.CameraType.Scriptable
		end)
	end
end

function CameraController.takenOver()
	return driver ~= nil
end

function CameraController.release(look)
	driver = nil
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local c = player.Character
	local head = c and c:FindFirstChild("Head")
	local root = c and c:FindFirstChild("HumanoidRootPart")
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	pcall(function()
		cam.CameraType = Enum.CameraType.Custom
		if hum then
			cam.CameraSubject = hum
		end
		player.CameraMode = Enum.CameraMode.LockFirstPerson
	end)
	-- (Roblox's camera carries on from where this one looks: straight back into your eyes)
	local eye = head and head.Position or (root and root.Position + Vector3.new(0, 1.5, 0))
	if eye then
		local dir = look or (root and root.CFrame.LookVector) or cam.CFrame.LookVector
		if dir.Magnitude < 0.01 then
			dir = Vector3.new(0, 0, -1)
		end
		cam.CFrame = CFrame.lookAt(eye, eye + dir.Unit)
	end
	fov = cam.FieldOfView or fov -- (eases back from the cinematic's lens)
end

-- A thumb dragged on the FIRE button aims while it draws (the button eats the touch, so Roblox's own camera never
-- sees it): degrees per point, times the sensitivity setting; never past looking straight up or down
local TURN_PER_POINT = 0.3
local PITCH_MAX = math.rad(80)

function CameraController.turn(dx, dy)
	local cam = workspace.CurrentCamera
	if not cam or driver or CameraController.mouseFree() then
		return
	end
	local profile = Store.get("profile")
	local sens = profile and profile.settings and tonumber(profile.settings.sensitivity) or 1
	local k = math.rad(TURN_PER_POINT * sens)
	local look = cam.CFrame.LookVector
	local yaw = math.atan2(-look.X, -look.Z) - dx * k
	local pitch = math.clamp(math.asin(math.clamp(look.Y, -1, 1)) - dy * k, -PITCH_MAX, PITCH_MAX)
	local dir = Vector3.new(-math.sin(yaw) * math.cos(pitch), math.sin(pitch), -math.cos(yaw) * math.cos(pitch))
	local at = cam.CFrame.Position
	cam.CFrame = CFrame.lookAt(at, at + dir) -- (Roblox's camera carries on from where this one looks)
end

-- A gentle look up by `rad` (down when negative), never higher than `ceiling` (the win's fireworks: an eye to the
-- sky); not while a cinematic has the camera or a menu has the mouse. Returns how far it actually turned.
function CameraController.lookUp(rad, ceiling)
	local cam = workspace.CurrentCamera
	if not cam or driver or CameraController.mouseFree() or rad == 0 then
		return 0
	end
	local look = cam.CFrame.LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	local pitch = math.asin(math.clamp(look.Y, -1, 1))
	local top = math.max(pitch, math.min(ceiling or PITCH_MAX, PITCH_MAX)) -- (already higher: no further)
	local to = math.clamp(pitch + rad, -PITCH_MAX, rad > 0 and top or PITCH_MAX)
	if math.abs(to - pitch) < 1e-5 then
		return 0
	end
	local dir = Vector3.new(-math.sin(yaw) * math.cos(to), math.sin(to), -math.cos(yaw) * math.cos(to))
	local at = cam.CFrame.Position
	cam.CFrame = CFrame.lookAt(at, at + dir)
	return to - pitch
end

local function shakeNow()
	local t = os.clock()
	if t < shakeUntil then
		local s = shakeStrength * ((shakeUntil - t) / 0.4)
		return CFrame.Angles(math.rad((math.random() - 0.5) * s * 4), math.rad((math.random() - 0.5) * s * 4), 0)
	end
	shakeStrength = 0
	return nil
end

local function step(dt)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	if driver then
		local free = CameraController.mouseFree()
		parkModals(mouseShown ~= free)
		setMouse(free)
		local fn = driver
		local ok, err = pcall(fn, cam, dt)
		if not ok then
			warn("[CameraController] cinematic failed: " .. tostring(err))
			CameraController.release()
			return
		end
		local s = shakeNow()
		if s then
			cam.CFrame = cam.CFrame * s
		end
		return
	end
	pcall(function()
		player.CameraMode = Enum.CameraMode.LockFirstPerson
	end)
	local free = CameraController.mouseFree()
	parkModals(mouseShown ~= free)
	setMouse(free)
	fov += (CameraController.targetFov() - fov) * math.min(1, dt * 10)
	cam.FieldOfView = fov
	local extra = CFrame.new()
	for _, cf in offsets do
		extra *= cf
	end
	local s = shakeNow()
	if s then
		extra *= s
	end
	if extra ~= CFrame.new() then
		cam.CFrame = cam.CFrame * extra
	end
end

function CameraController:init()
	setMouse(false) -- (the HUD draws the crosshair)
	UserInputService.InputBegan:Connect(function(input, processed)
		local k = input.KeyCode
		if (k == Enum.KeyCode.LeftAlt or k == Enum.KeyCode.RightAlt) and not processed then
			CameraController.setCursorMode(not cursorMode)
		end
	end)
	Bus.Look:Connect(function(dx, dy)
		CameraController.turn(dx or 0, dy or 0)
	end)
	Bus.Shake:Connect(function(strength, seconds)
		CameraController.shake(strength or 0.3, seconds or 0.25)
	end)
	Store.Changed:Connect(function(partial)
		local p = partial.profile
		if p and p.settings and p.settings.sensitivity then
			pcall(function()
				UserInputService.MouseDeltaSensitivity = p.settings.sensitivity
			end)
		end
	end)
	-- any input tells the server you're here (at most every 10 s): only someone who touches nothing is "AFK"
	local lastActive = -math.huge
	local function activity()
		local t = os.clock()
		if t - lastActive >= 10 then
			lastActive = t
			pcall(Net.send, "Active")
		end
	end
	UserInputService.InputBegan:Connect(activity)
	UserInputService.InputChanged:Connect(function(input)
		local kind = input.UserInputType
		if
			kind == Enum.UserInputType.MouseMovement
			or kind == Enum.UserInputType.Touch
			or kind == Enum.UserInputType.Gamepad1
		then
			activity()
		end
	end)
	-- a new body faces the line: so does the camera (first person turns the body to the camera, so an old look
	-- left over from the last life would turn them round)
	player.CharacterAdded:Connect(function(c)
		task.spawn(function()
			local root = c:WaitForChild("HumanoidRootPart", 5)
			for _ = 1, 3 do
				task.wait(0.05)
				local cam = workspace.CurrentCamera
				if not root or not cam or driver or player.Character ~= c then
					return
				end
				local eye = root.Position + Vector3.new(0, 1.5, 0)
				local dir = root.CFrame.LookVector
				cam.CFrame = CFrame.lookAt(eye, eye + Vector3.new(dir.X, 0, dir.Z))
			end
		end)
	end)
	local ok = pcall(function()
		RunService:BindToRenderStep("TWCamera", Enum.RenderPriority.Camera.Value + 1, step)
	end)
	if not ok then
		RunService.RenderStepped:Connect(step)
	end
end

return CameraController
