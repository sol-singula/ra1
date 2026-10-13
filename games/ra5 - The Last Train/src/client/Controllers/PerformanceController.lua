-- Lite mode for phones and low graphics settings, so the game stays smooth (most players are on phones).
-- On this device only (nothing changes for anyone else):
--   * pure decoration the server tagged "Detail" (wall stones, berries, flowers, floor tiles, tiny scenery) is
--     left out, including any that appears later
--   * the heavier screen effects (sun rays, bloom, depth of field) are turned off
--   * particle effects make half as many particles
-- AnalyticsController sends PerformanceController.lite with each frame-rate sample, so the dashboard can tell
-- whether it helps.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
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
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function dropDetail(part)
	part.Parent = nil
end

local function lighten(inst)
	if HEAVY_EFFECTS[inst.ClassName] then
		inst.Enabled = false
	elseif inst:IsA("ParticleEmitter") and not inst:GetAttribute("LiteDone") then
		inst:SetAttribute("LiteDone", true)
		inst.Rate = inst.Rate * 0.5
	end
end

function PerformanceController:init()
	self.lite = PerformanceController.shouldBeLite()
	if not self.lite then
		return
	end
	for _, part in CollectionService:GetTagged("Detail") do
		dropDetail(part)
	end
	CollectionService:GetInstanceAddedSignal("Detail"):Connect(dropDetail)
	for _, inst in Lighting:GetChildren() do
		lighten(inst)
	end
	Lighting.ChildAdded:Connect(lighten)
	for _, inst in workspace:GetDescendants() do
		if inst:IsA("ParticleEmitter") then
			lighten(inst)
		end
	end
	pcall(function()
		workspace.DescendantAdded:Connect(function(inst)
			if inst:IsA("ParticleEmitter") then
				lighten(inst)
			end
		end)
	end)
end

return PerformanceController
