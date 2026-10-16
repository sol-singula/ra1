--[[
Lite mode for phones and low graphics settings, so the game stays smooth (master plan §11: mobile first). On this
device only (nothing changes for anyone else):
  * pure decoration the server tagged "Detail" (flowers, ferns, pebbles) is left out, including any that appears later
  * the heavier screen effects (bloom, sun rays, depth of field) are turned off
  * particle effects make half as many particles
  * monsters are drawn to a shorter distance and far ones animate less often (CreatureController reads .lite), and
    effects use fewer particles (FxController)
  * no shadows, no light sources (a lamp's bulb still glows), flat water, no clouds
  * other rafts hold still and yours bobs every other frame (RaftMotionController), the far islands slide every few
    frames (SailingController)
AnalyticsController sends PerformanceController.lite with each frame-rate sample, so the dashboard can tell
whether it helps.
]]
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local PerformanceController = { Name = "PerformanceController", Order = 1, lite = false }

local HEAVY_EFFECTS = { SunRaysEffect = true, BloomEffect = true, DepthOfFieldEffect = true }

-- A phone or tablet (touch and no keyboard), or graphics turned down to 1-4 of 10 (0 = automatic).
function PerformanceController.shouldBeLite()
	local quality
	pcall(function()
		quality = UserSettings().GameSettings.SavedQualityLevel.Value
	end)
	if type(quality) == "number" and quality >= 1 and quality <= 4 then
		return true
	end
	return UserInputService.TouchEnabled == true and UserInputService.KeyboardEnabled ~= true
end

local function dropDetail(part)
	part.Parent = nil
end

local LIGHTS = { PointLight = true, SpotLight = true, SurfaceLight = true }

local function lighten(inst)
	if HEAVY_EFFECTS[inst.ClassName] then
		inst.Enabled = false
	elseif LIGHTS[inst.ClassName] and inst.Name ~= "HeldLight" then
		inst.Enabled = false -- (light sources cost the most on phones; neon bulbs still look lit)
	elseif inst:IsA("ParticleEmitter") and not inst:GetAttribute("LiteDone") then
		inst:SetAttribute("LiteDone", true)
		inst.Rate = inst.Rate * 0.5
	end
end

function PerformanceController:init()
	if PerformanceController.shouldBeLite() then
		PerformanceController.enable()
	end
end

-- Everything already in the world, lightened (what arrives later is caught as it comes).
function PerformanceController.sweep()
	for _, inst in workspace:GetDescendants() do
		if inst:IsA("ParticleEmitter") or LIGHTS[inst.ClassName] then
			lighten(inst)
		end
	end
end

-- Lite mode on (phones; tests turn it on by hand).
function PerformanceController.enable()
	if PerformanceController.enabled then
		return
	end
	PerformanceController.enabled = true
	PerformanceController.lite = true
	for _, part in CollectionService:GetTagged("Detail") do
		dropDetail(part)
	end
	CollectionService:GetInstanceAddedSignal("Detail"):Connect(dropDetail)
	for _, inst in Lighting:GetChildren() do
		lighten(inst)
	end
	Lighting.ChildAdded:Connect(lighten)
	pcall(function()
		local LightingPresets = require(ReplicatedStorage.Shared.World.LightingPresets)
		LightingPresets.lite = true
	end)
	Lighting.GlobalShadows = false
	pcall(function()
		local terrain = workspace.Terrain
		terrain.WaterWaveSize = 0
		terrain.WaterReflectance = 0
		local clouds = terrain:FindFirstChildOfClass("Clouds")
		if clouds then
			clouds.Enabled = false
		end
	end)
	PerformanceController.sweep()
	pcall(function()
		workspace.DescendantAdded:Connect(function(inst)
			if inst:IsA("ParticleEmitter") or LIGHTS[inst.ClassName] then
				lighten(inst)
			end
		end)
	end)
end

return PerformanceController
