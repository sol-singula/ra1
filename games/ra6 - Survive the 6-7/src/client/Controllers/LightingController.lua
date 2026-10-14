--[[
The sky over the run (master plan §11: warm firelight against cool moonlight; darkness for tension, never too dark to
see). The time of day follows the stage's clock (Formulas.clockTime: the sun crosses the sky by day, sets at dusk,
the moon rides through the night) and the look blends smoothly into the next stage's preset over a few seconds.
Night events change the night: fog rolls in, fireflies drift round you, the blood moon turns everything red, the
storm brings rain and lightning.
]]
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Formulas = require(ReplicatedStorage.Shared.Formulas)
local LightingPresets = require(ReplicatedStorage.Shared.World.LightingPresets)
local Store = require(script.Parent.Parent.Store)
local Bus = require(script.Parent.Parent.UI.Bus)

local LightingController = { Name = "LightingController", Order = 4 }

local BLEND_SECONDS = 5
local current -- the preset table on screen
local target = "day"
local from, blendStart
local weather -- { part, rain, fireflies }
local nextBolt = 0

local function weatherPart()
	if weather then
		return weather
	end
	local part = Instance.new("Part")
	part.Name = "Weather"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(90, 1, 90)
	part.Parent = workspace
	local rain = Instance.new("ParticleEmitter")
	rain.Name = "Rain"
	rain.Rate = 0
	rain.Lifetime = NumberRange.new(0.9, 1.2)
	rain.Speed = NumberRange.new(70, 80)
	rain.EmissionDirection = Enum.NormalId.Bottom
	rain.SpreadAngle = Vector2.new(4, 4)
	rain.Size = NumberSequence.new(0.12)
	rain.Transparency = NumberSequence.new(0.45)
	rain.Color = ColorSequence.new(Color3.fromRGB(190, 210, 240))
	rain.Orientation = Enum.ParticleOrientation.VelocityParallel
	rain.Parent = part
	local flies = Instance.new("ParticleEmitter")
	flies.Name = "Fireflies"
	flies.Rate = 0
	flies.Lifetime = NumberRange.new(3, 5)
	flies.Speed = NumberRange.new(0.5, 2)
	flies.SpreadAngle = Vector2.new(180, 180)
	flies.EmissionDirection = Enum.NormalId.Bottom
	flies.LightEmission = 1
	flies.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0.3),
		NumberSequenceKeypoint.new(1, 0),
	})
	flies.Color = ColorSequence.new(Color3.fromRGB(220, 255, 120))
	flies.Parent = part
	weather = { part = part, rain = rain, fireflies = flies }
	return weather
end

function LightingController.target()
	return target
end

local function step()
	local phase = Store.phase()
	local event = workspace:GetAttribute("Event")
	local want = LightingPresets.forPhase(phase, event ~= "" and event or nil)
	local now = os.clock()
	if want ~= target then
		from = current or LightingPresets.list[target]
		target = want
		blendStart = now
	end
	local f = blendStart and math.clamp((now - blendStart) / BLEND_SECONDS, 0, 1) or 1
	local preset = (f < 1 and from) and LightingPresets.blend(from, target, f)
		or LightingPresets.blend(target, target, 1)
	current = preset
	-- the time of day from the stage's clock
	local progress, length = Store.phaseProgress()
	local clock
	if phase == "day" or phase == "dusk" or phase == "night" or phase == "boss" or phase == "dawn" then
		clock = Formulas.clockTime(phase, progress * length, length)
	end
	LightingPresets.apply(preset, clock)
	-- weather round the camera
	local cam = workspace.CurrentCamera
	local w = weatherPart()
	if cam then
		w.part.CFrame = CFrame.new(cam.CFrame.Position + Vector3.new(0, 30, 0))
	end
	local night = phase == "night"
	w.rain.Rate = (night and event == "storm") and 600 or 0
	w.fireflies.Rate = (night and event == "fireflies") and 30 or 0
	-- lightning in the storm: a flash, a shake, thunder
	if night and event == "storm" and now >= nextBolt then
		nextBolt = now + 6 + math.random() * 8
		local was = Lighting.Brightness
		Lighting.Brightness = was + 4
		Bus.Flash:Fire(Color3.fromRGB(230, 236, 255), 0.15)
		task.delay(0.12, function()
			Lighting.Brightness = was
		end)
		Bus.Shake:Fire(0.25, 0.4)
	end
end

function LightingController:init()
	local acc = 1
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if acc >= 0.1 then
			acc = 0
			step()
		end
	end)
end

return LightingController
