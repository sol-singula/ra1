--[[
The first-person camera (master plan §6): locked first person, a steady field of view that widens a little when
you sprint and tightens as you draw (a light zoom for aiming), small shakes (hits, the horn) that the player can
turn off, and the sensitivity setting. Other controllers add their own offsets through CameraController.offset
(the front flip's roll, the slide's dip), applied after Roblox's camera each frame.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Bus = require(script.Parent.Parent.UI.Bus)
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

local function step(dt)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	pcall(function()
		player.CameraMode = Enum.CameraMode.LockFirstPerson
	end)
	fov += (CameraController.targetFov() - fov) * math.min(1, dt * 10)
	cam.FieldOfView = fov
	local extra = CFrame.new()
	for _, cf in offsets do
		extra *= cf
	end
	local t = os.clock()
	if t < shakeUntil then
		local s = shakeStrength * ((shakeUntil - t) / 0.4)
		extra *= CFrame.Angles(math.rad((math.random() - 0.5) * s * 4), math.rad((math.random() - 0.5) * s * 4), 0)
	else
		shakeStrength = 0
	end
	if extra ~= CFrame.new() then
		cam.CFrame = cam.CFrame * extra
	end
end

function CameraController:init()
	pcall(function()
		UserInputService.MouseIconEnabled = false -- (the HUD draws the crosshair)
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
	local ok = pcall(function()
		RunService:BindToRenderStep("TWCamera", Enum.RenderPriority.Camera.Value + 1, step)
	end)
	if not ok then
		RunService.RenderStepped:Connect(step)
	end
end

return CameraController
