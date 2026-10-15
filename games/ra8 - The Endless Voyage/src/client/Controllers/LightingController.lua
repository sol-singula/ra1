--[[
The sky over the ocean (master plan §1: a beautiful, open sea; §10: travel is an activity you watch). The time of
day follows the server's clock (Formulas.clockTime: the sun crosses the sky by day, the moon by night) and the look
blends into the next preset over a few seconds: a storm darkens everything and brings rain and lightning, Mist
Hollow's fog closes in, the Trench turns the water black.
]]
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Voyages = require(ReplicatedStorage.Shared.Data.Voyages)
local LightingPresets = require(ReplicatedStorage.Shared.World.LightingPresets)
local Store = require(script.Parent.Parent.Store)
local Bus = require(script.Parent.Parent.UI.Bus)

local LightingController = { Name = "LightingController", Order = 4 }

local BLEND_SECONDS = 5
local current -- the preset table on screen
local target = "day"
local from, blendStart
local weather -- { part, rain, spray }
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
	rain.SpreadAngle = Vector2.new(6, 6)
	rain.Size = NumberSequence.new(0.12)
	rain.Transparency = NumberSequence.new(0.45)
	rain.Color = ColorSequence.new(Color3.fromRGB(190, 210, 240))
	rain.Orientation = Enum.ParticleOrientation.VelocityParallel
	rain.Parent = part
	local spray = Instance.new("ParticleEmitter")
	spray.Name = "Spray"
	spray.Rate = 0
	spray.Lifetime = NumberRange.new(1.5, 2.5)
	spray.Speed = NumberRange.new(2, 6)
	spray.SpreadAngle = Vector2.new(180, 180)
	spray.EmissionDirection = Enum.NormalId.Top
	spray.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1.2),
	})
	spray.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	spray.Color = ColorSequence.new(Color3.fromRGB(220, 235, 245))
	spray.Parent = part
	weather = { part = part, rain = rain, spray = spray }
	return weather
end

function LightingController.target()
	return target
end

-- The waters the plot is in: the destination's template while a voyage is at its island (or in its last stretch).
local function waters()
	local v = Store.get("voyage")
	if v and (v.state == "island" or v.state == "sailing") and v.dest then
		local d = Voyages.get(v.dest)
		if d and v.state == "island" then
			return d.template
		end
	end
	return "home"
end

local function step()
	local phase = Store.phase()
	local storm = Store.storm()
	local want = LightingPresets.forPhase(phase, storm, waters())
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
	-- the time of day from the server's clock
	local progress, length = Store.phaseProgress()
	local clock = length > 0 and Formulas.clockTime(phase, progress * length) or nil
	LightingPresets.apply(preset, clock)
	-- weather round the camera
	local cam = workspace.CurrentCamera
	local w = weatherPart()
	if cam then
		w.part.CFrame = CFrame.new(cam.CFrame.Position + Vector3.new(0, 30, 0))
	end
	w.rain.Rate = storm and 600 or 0
	w.spray.Rate = storm and 12 or 0
	-- lightning in the storm: a flash, a shake, thunder
	if storm and now >= nextBolt then
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
