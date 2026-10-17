--[[
The first-person camera (master plan §6): locked first person, a steady field of view that widens a little when
you sprint and tightens as you draw (a light zoom for aiming), small shakes (hits, the horn) that the player can
turn off, and the sensitivity setting. Other controllers add their own offsets through CameraController.offset
(the front flip's roll, the slide's dip), applied after Roblox's camera each frame.

The mouse: hidden in play (the HUD draws the crosshair), shown and free while a menu needs it: the panel (shop,
pass, locker, goals), a question card, the results card (once it closes, the wait for the next game is free running
about, so the mouse goes back to the camera). CameraController.mouseFree() says which; the bow and the build
tray don't fire while it's true, so a click in the shop is only a click in the shop. Once a menu closes the lock is
put back every frame (Roblox can show the cursor again on its own), and a Modal button left inside a closed panel
stops being Modal (a Modal button keeps the cursor out even when its panel is hidden) until the panel is back.

Cinematics (the tutorial): CameraController.takeover(fn) hands the camera to fn(camera, dt), called every frame
instead of the first-person lock (the camera goes Scriptable; shakes still play on top). CameraController.release(look)
gives it back: Custom again, on your character, locked first person, looking along `look` (or where you face).

  CameraController.takeover(fn)   CameraController.release(look?)   CameraController.takenOver() -> bool
  CameraController.parked()       { [button] = true }: Modal buttons switched off while their panel is hidden
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Bus = require(script.Parent.Parent.UI.Bus)
local Layout = require(script.Parent.Parent.UI.Layout)
local Store = require(script.Parent.Parent.Store)

local CameraController = { Name = "CameraController", Order = 5 }

local player = Players.LocalPlayer
local BASE_FOV = 80
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
	local f = BASE_FOV
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

function CameraController.mouseFree()
	return Layout.panel() or Layout.modalOpen() or (Store.phase() == "victory" and Layout.resultsOpen == true)
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
	local ok = pcall(function()
		RunService:BindToRenderStep("TWCamera", Enum.RenderPriority.Camera.Value + 1, step)
	end)
	if not ok then
		RunService.RenderStepped:Connect(step)
	end
end

return CameraController
