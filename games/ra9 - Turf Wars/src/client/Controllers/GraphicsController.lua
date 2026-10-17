--[[
Better light on machines that can take it, drawn on each client only (the server's map lighting stays the base):

  high   a PC or console on a high graphics level (8+, or Automatic): soft bloom on the neon (the frontline, the
         team lights), faint sun rays, a little haze in the far distance, crisper shadows and shinier surfaces
  mid    graphics level 4-7: a lighter bloom and the shinier surfaces, nothing else
  low    phones and tablets, and levels 1-3: nothing added (the plain look, the best frame rate)

The tier follows the player's graphics slider live, and is put back after every map load (the server resets the
lighting for each map). The bloom's threshold is high, so the white world stays white and only the neon glows.

  GraphicsController.tier()       "high" | "mid" | "low"
  GraphicsController.apply(tier)  (tests, or a settings toggle) forces a tier
]]
local Lighting = game:GetService("Lighting")

local Device = require(script.Parent.Parent.UI.Device)

local GraphicsController = { Name = "GraphicsController", Order = 6 }

local current = "low"
local forced

local function quality()
	local ok, level = pcall(function()
		local s = UserSettings():GetService("UserGameSettings")
		return s.SavedQualityLevel
	end)
	if not ok or level == nil then
		return nil
	end
	if level == Enum.SavedQualitySetting.Automatic then
		return 0 -- (Roblox picks: count it as able)
	end
	return tonumber(string.match(tostring(level), "(%d+)$"))
end

local function pick()
	if forced then
		return forced
	end
	if Device.isTouch() then
		return "low"
	end
	local q = quality()
	if q == nil or q == 0 or q >= 8 then
		return "high"
	elseif q >= 4 then
		return "mid"
	end
	return "low"
end

local function effect(class, name, props)
	local e = Lighting:FindFirstChild(name)
	if not e then
		e = Instance.new(class)
		e.Name = name
	end
	for k, v in props do
		e[k] = v
	end
	e.Parent = Lighting
	return e
end

local function drop(name)
	local e = Lighting:FindFirstChild(name)
	if e then
		e:Destroy()
	end
end

local TIERS = {
	high = {
		bloom = { Intensity = 0.45, Size = 30, Threshold = 1.9 },
		rays = true,
		dof = true,
		specular = 0.5,
		diffuse = 0.85,
		soft = 0.3,
	},
	mid = { bloom = { Intensity = 0.25, Size = 22, Threshold = 2.1 }, specular = 0.35, diffuse = 0.7 },
	low = {},
}

function GraphicsController.apply(tier)
	forced = tier
	GraphicsController.refresh()
end

function GraphicsController.refresh()
	current = pick()
	local t = TIERS[current] or TIERS.low
	pcall(function()
		if t.bloom then
			effect("BloomEffect", "TW_Bloom", t.bloom)
		else
			drop("TW_Bloom")
		end
		if t.rays then
			effect("SunRaysEffect", "TW_Rays", { Intensity = 0.035, Spread = 0.55 })
		else
			drop("TW_Rays")
		end
		if t.dof then
			-- (only the far distance: the fight up close stays sharp)
			effect("DepthOfFieldEffect", "TW_Depth", {
				FarIntensity = 0.1,
				FocusDistance = 80,
				InFocusRadius = 120,
				NearIntensity = 0,
			})
		else
			drop("TW_Depth")
		end
		if t.specular then
			Lighting.EnvironmentSpecularScale = t.specular
			Lighting.EnvironmentDiffuseScale = t.diffuse
		end
		if t.soft then
			Lighting.ShadowSoftness = t.soft
		end
	end)
	return current
end

function GraphicsController.tier()
	return current
end

function GraphicsController:init()
	GraphicsController.refresh()
	Device.Changed:Connect(function()
		GraphicsController.refresh()
	end)
	pcall(function()
		local s = UserSettings():GetService("UserGameSettings")
		s:GetPropertyChangedSignal("SavedQualityLevel"):Connect(function()
			GraphicsController.refresh()
		end)
	end)
	-- (each map load resets the lighting on the server; put ours back on top)
	workspace:GetAttributeChangedSignal("MapKey"):Connect(function()
		task.delay(0.2, GraphicsController.refresh)
	end)
end

return GraphicsController
