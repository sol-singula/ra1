--[[
The Block Party sunflower on the client (Game Artist build-spec/03-sunflower.md, GA-03). When Workspace.Street.Sunflower
streams in it builds the 38 art parts under the server's Model (Models/Sunflower.buildArt; the server's Stem and its
Water prompt stay as they are) and drives them from the Model's attributes, one lerp driver on Heartbeat:

  Stage change      tween to the stage's pose over 0.6 s, Back Out; to bloom over 1.5 s, Back Out, with the bloom
                    VFX (Weather picks the column colour) and a 0.2 s camera shake within 60 studs (never reducedFx)
  Phase "wilt"      a Linear lerp from bloom into drooping over BlockParty.wiltSec (by WiltEndsAt)
  Phase "open" with Waters < Goal   the thirsty icon over the head, bobbing
  beyond 160 studs  the pose freezes, the seed dots and every other petal hide, the VFX stop

  SunflowerController.model() / params() / fx()   (tests)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Clock = require(ReplicatedStorage.Shared.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local Sunflower = require(ReplicatedStorage.Shared.Models.Sunflower)
local Visuals = require(ReplicatedStorage.Shared.Visuals)

local SunflowerController = {}

local SV = Config.SunflowerVisuals

local model -- the streamed Workspace.Street.Sunflower
local current -- the pose params on the parts now
local tween -- { from, to, t, sec }
local seenStage, seenPhase
local fx, fxT -- the bloom VFX handle and its age
local shakeT -- seconds left of the camera shake
local far = false
local bobT = 0

function SunflowerController.model()
	return model
end

function SunflowerController.params()
	return current
end

function SunflowerController.fx()
	return fx
end

-- Back Out (Enum.EasingStyle.Back, Out)
local function backOut(x)
	local s = 1.70158
	return 1 + (s + 1) * (x - 1) ^ 3 + s * (x - 1) ^ 2
end

local function find()
	local street = workspace:FindFirstChild("Street")
	return street and street:FindFirstChild("Sunflower")
end

local function cameraPosition()
	local ok, cf = pcall(function()
		return workspace.CurrentCamera.CFrame
	end)
	return ok and cf and cf.Position or nil
end

local function humanoid()
	local character = Players.LocalPlayer and Players.LocalPlayer.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function setCameraOffset(offset)
	local h = humanoid()
	if h then
		pcall(function()
			h.CameraOffset = offset
		end)
	end
end

-- the wilt's pose: how far into BlockParty.wiltSec we are
local function wiltPose()
	local sec = Config.BlockParty.wiltSec
	local ends = model:GetAttribute("WiltEndsAt")
	local alpha = if ends then 1 - (ends - Clock.now()) / sec else 0
	return Sunflower.wiltPose(alpha)
end

local function target()
	if model:GetAttribute("Phase") == "wilt" then
		return wiltPose()
	end
	return Sunflower.pose(model:GetAttribute("Stage") or "drooping")
end

local function stopFx()
	if fx then
		Sunflower.clearFx(model)
		fx, fxT = nil, nil
	end
end

local function bloomed(distance)
	if far then
		return
	end
	fx = Sunflower.bloomFx(model, model:GetAttribute("Weather"), { reduced = Visuals.reducedFx })
	fxT = 0
	if not Visuals.reducedFx and distance and distance <= SV.bloom.shakeStuds then
		shakeT = SV.bloom.shakeSec
	end
end

local function attach(m)
	model = m
	Sunflower.buildArt(m)
	Sunflower.thirsty(m)
	current = target()
	Sunflower.apply(m, current)
	seenStage, seenPhase = m:GetAttribute("Stage"), m:GetAttribute("Phase")
	tween, fx, fxT, shakeT, far = nil, nil, nil, nil, false
end

function SunflowerController.step(dt)
	if not model or not model.Parent then
		local m = find()
		if not m or not m:GetAttribute("Origin") then
			model = nil
			return
		end
		attach(m)
	end
	local stage, phase = model:GetAttribute("Stage"), model:GetAttribute("Phase")
	local pivot = Sunflower.parts(model).HeadPivot
	local eye = cameraPosition()
	local distance = eye and (pivot.Position - eye).Magnitude
	local isFar = distance ~= nil and distance > SV.lod.studs
	if isFar ~= far then
		far = isFar
		Sunflower.setFar(model, far)
		if far then
			stopFx()
		end
	end
	-- a new stage (or the end of the wilt): tween from wherever the parts are
	if phase ~= "wilt" and (stage ~= seenStage or (seenPhase == "wilt" and phase ~= "wilt")) then
		local toBloom = stage == "bloom" and seenStage ~= "bloom"
		tween = {
			from = current,
			to = Sunflower.pose(stage or "drooping"),
			t = 0,
			sec = if toBloom then SV.bloom.sec else SV.tween.sec,
		}
		if toBloom then
			bloomed(distance)
		end
	end
	seenStage, seenPhase = stage, phase
	local moved = false
	if phase == "wilt" then
		tween = nil
		current = wiltPose()
		moved = true
	elseif tween then
		tween.t += dt
		local x = math.clamp(tween.t / tween.sec, 0, 1)
		current = Sunflower.mix(tween.from, tween.to, backOut(x))
		if x >= 1 then
			current = tween.to
			tween = nil
		end
		moved = true
	end
	if moved and not far then
		Sunflower.apply(model, current)
	end
	if fx then
		fxT += dt
		Sunflower.stepFx(fx, fxT)
		if fxT >= SV.fx.sec then
			stopFx()
		end
	end
	if shakeT then
		shakeT -= dt
		if shakeT > 0 then
			local a = SV.bloom.shakeAmp * shakeT / SV.bloom.shakeSec
			setCameraOffset(Vector3.new((math.random() * 2 - 1) * a, (math.random() * 2 - 1) * a, 0))
		else
			shakeT = nil
			setCameraOffset(Vector3.zero)
		end
	end
	local gui = pivot:FindFirstChild("Thirsty")
	if gui then
		local waters, goal = model:GetAttribute("Waters") or 0, model:GetAttribute("Goal") or 0
		gui.Enabled = phase == "open" and waters < goal
		if gui.Enabled then
			bobT += dt
			local t = SV.thirsty
			local mid, half = (t.bob[1] + t.bob[2]) / 2, (t.bob[2] - t.bob[1]) / 2
			gui.StudsOffset = Vector3.new(0, mid - half * math.cos(math.pi * bobT / t.bobSec), 0)
		end
	end
end

function SunflowerController:Start()
	RunService.Heartbeat:Connect(function(dt)
		SunflowerController.step(dt)
	end)
end

return SunflowerController
