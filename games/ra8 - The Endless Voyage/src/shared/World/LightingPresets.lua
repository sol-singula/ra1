-- The light over the ocean: a bright day, a pink dawn, an orange dusk, a moonlit night, the storms, Mist Hollow's
-- fog and the Trench's green. The client blends between the presets as the day goes (LightingController) and sets
-- the time of day from the clock (Formulas.clockTime); the server applies one at start-up so Studio and the render
-- tools look right. Tuned for Lighting.Technology = Future.
local Lighting = game:GetService("Lighting")

local LightingPresets = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

LightingPresets.list = {
	day = { -- a bright open sea: high sun, light haze on the horizon
		clock = 12.5,
		brightness = 3.2,
		ambient = rgb(110, 118, 124),
		outdoor = rgb(156, 170, 180),
		exposure = 0.1,
		atmosphere = {
			density = 0.26,
			offset = 0.18,
			color = rgb(214, 232, 244),
			decay = rgb(120, 170, 200),
			glare = 0.36,
			haze = 1.3,
		},
		grade = { brightness = 0.02, contrast = 0.12, saturation = 0.2, tint = rgb(252, 250, 240) },
		bloom = { intensity = 0.3, size = 24, threshold = 1.7 },
		clouds = { cover = 0.38, density = 0.5, color = rgb(255, 255, 255) },
	},
	dawn = { -- pink light, the water flat
		clock = 6.4,
		brightness = 2.2,
		ambient = rgb(110, 96, 104),
		outdoor = rgb(170, 140, 150),
		exposure = 0.1,
		atmosphere = {
			density = 0.34,
			offset = 0.2,
			color = rgb(244, 206, 196),
			decay = rgb(160, 120, 150),
			glare = 0.3,
			haze = 1.6,
		},
		grade = { brightness = 0.02, contrast = 0.08, saturation = 0.16, tint = rgb(255, 236, 224) },
		bloom = { intensity = 0.4, size = 28, threshold = 1.5 },
		clouds = { cover = 0.3, density = 0.4, color = rgb(255, 230, 220) },
	},
	dusk = { -- the sun goes down orange over the water
		clock = 18.3,
		brightness = 1.9,
		ambient = rgb(108, 86, 90),
		outdoor = rgb(160, 112, 110),
		exposure = 0.08,
		atmosphere = {
			density = 0.36,
			offset = 0.14,
			color = rgb(250, 180, 120),
			decay = rgb(130, 90, 120),
			glare = 0.5,
			haze = 1.8,
		},
		grade = { brightness = 0.02, contrast = 0.12, saturation = 0.22, tint = rgb(255, 228, 200) },
		bloom = { intensity = 0.5, size = 30, threshold = 1.4 },
		clouds = { cover = 0.4, density = 0.5, color = rgb(255, 196, 150) },
	},
	night = { -- a moon on the water, stars, the lanterns doing the rest
		clock = 0.6,
		brightness = 0.7,
		ambient = rgb(40, 48, 72),
		outdoor = rgb(54, 66, 100),
		exposure = 0.02,
		atmosphere = {
			density = 0.32,
			offset = 0.1,
			color = rgb(70, 90, 140),
			decay = rgb(30, 40, 80),
			glare = 0.1,
			haze = 1.4,
		},
		grade = { brightness = -0.02, contrast = 0.14, saturation = -0.1, tint = rgb(200, 212, 255) },
		bloom = { intensity = 0.6, size = 36, threshold = 1.2 },
		clouds = { cover = 0.3, density = 0.5, color = rgb(120, 130, 170) },
	},
	storm = { -- black sky, grey water, the rain
		clock = 14,
		brightness = 1.1,
		ambient = rgb(62, 68, 76),
		outdoor = rgb(80, 88, 100),
		exposure = -0.05,
		atmosphere = {
			density = 0.6,
			offset = 0.3,
			color = rgb(120, 130, 140),
			decay = rgb(60, 70, 84),
			glare = 0,
			haze = 3,
		},
		grade = { brightness = -0.04, contrast = 0.18, saturation = -0.3, tint = rgb(210, 220, 236) },
		bloom = { intensity = 0.2, size = 20, threshold = 1.9 },
		clouds = { cover = 0.95, density = 0.9, color = rgb(90, 96, 110) },
	},
	fog = { -- Mist Hollow
		clock = 11,
		brightness = 1.6,
		ambient = rgb(120, 126, 130),
		outdoor = rgb(160, 168, 172),
		exposure = 0.02,
		atmosphere = {
			density = 0.62,
			offset = 0.4,
			color = rgb(200, 206, 210),
			decay = rgb(150, 160, 166),
			glare = 0,
			haze = 3.2,
		},
		grade = { brightness = 0, contrast = 0.04, saturation = -0.2, tint = rgb(236, 240, 244) },
		bloom = { intensity = 0.2, size = 20, threshold = 1.9 },
		clouds = { cover = 0.8, density = 0.7, color = rgb(220, 224, 228) },
	},
	trench = { -- the water goes black, the sky goes green
		clock = 15,
		brightness = 1.3,
		ambient = rgb(50, 70, 76),
		outdoor = rgb(70, 100, 104),
		exposure = 0,
		atmosphere = {
			density = 0.5,
			offset = 0.2,
			color = rgb(90, 130, 130),
			decay = rgb(30, 60, 70),
			glare = 0.1,
			haze = 2.4,
		},
		grade = { brightness = -0.03, contrast = 0.2, saturation = -0.1, tint = rgb(200, 236, 230) },
		bloom = { intensity = 0.5, size = 30, threshold = 1.3 },
		clouds = { cover = 0.7, density = 0.8, color = rgb(90, 120, 120) },
	},
}

-- The preset for the moment: the day or the night, a storm over it, the fog at Mist Hollow, the Trench.
function LightingPresets.forPhase(phase, storm, waters)
	if storm then
		return "storm"
	end
	if waters == "trench" then
		return "trench"
	end
	if waters == "foggy" then
		return "fog"
	end
	return phase == "night" and "night" or "day"
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function child(className, name)
	local inst = Lighting:FindFirstChild(name)
	if not inst then
		inst = Instance.new(className)
		inst.Name = name
		inst.Parent = Lighting
	end
	return inst
end

-- A preset part way between two (t = 0..1), for smooth changes.
function LightingPresets.blend(from, to, t)
	local a = type(from) == "table" and from or LightingPresets.list[from] or LightingPresets.list.day
	local b = type(to) == "table" and to or LightingPresets.list[to] or LightingPresets.list.day
	local function c3(x, y)
		return x:Lerp(y, t)
	end
	return {
		clock = lerp(a.clock, b.clock, t),
		brightness = lerp(a.brightness, b.brightness, t),
		ambient = c3(a.ambient, b.ambient),
		outdoor = c3(a.outdoor, b.outdoor),
		exposure = lerp(a.exposure, b.exposure, t),
		atmosphere = {
			density = lerp(a.atmosphere.density, b.atmosphere.density, t),
			offset = lerp(a.atmosphere.offset, b.atmosphere.offset, t),
			color = c3(a.atmosphere.color, b.atmosphere.color),
			decay = c3(a.atmosphere.decay, b.atmosphere.decay),
			glare = lerp(a.atmosphere.glare, b.atmosphere.glare, t),
			haze = lerp(a.atmosphere.haze, b.atmosphere.haze, t),
		},
		grade = {
			brightness = lerp(a.grade.brightness, b.grade.brightness, t),
			contrast = lerp(a.grade.contrast, b.grade.contrast, t),
			saturation = lerp(a.grade.saturation, b.grade.saturation, t),
			tint = c3(a.grade.tint, b.grade.tint),
		},
		bloom = {
			intensity = lerp(a.bloom.intensity, b.bloom.intensity, t),
			size = lerp(a.bloom.size, b.bloom.size, t),
			threshold = lerp(a.bloom.threshold, b.bloom.threshold, t),
		},
		clouds = {
			cover = lerp(a.clouds.cover, b.clouds.cover, t),
			density = lerp(a.clouds.density, b.clouds.density, t),
			color = c3(a.clouds.color, b.clouds.color),
		},
	}
end

-- Apply a preset (a name, or a table from blend) to Lighting. `clock` overrides the time of day.
function LightingPresets.apply(preset, clock)
	local p = type(preset) == "table" and preset or LightingPresets.list[preset] or LightingPresets.list.day
	Lighting.ClockTime = clock or p.clock
	Lighting.Brightness = p.brightness
	Lighting.Ambient = p.ambient
	Lighting.OutdoorAmbient = p.outdoor
	Lighting.ExposureCompensation = p.exposure
	-- a little less fill from the sky, so shapes keep their shading, and soft shadows
	Lighting.EnvironmentDiffuseScale = 0.55
	Lighting.EnvironmentSpecularScale = 0.75
	Lighting.GlobalShadows = true
	pcall(function()
		Lighting.ShadowSoftness = 0.3
	end)
	local a = child("Atmosphere", "Atmosphere")
	a.Density, a.Offset, a.Color, a.Decay, a.Glare, a.Haze =
		p.atmosphere.density,
		p.atmosphere.offset,
		p.atmosphere.color,
		p.atmosphere.decay,
		p.atmosphere.glare,
		p.atmosphere.haze
	local g = child("ColorCorrectionEffect", "Grade")
	g.Brightness, g.Contrast, g.Saturation, g.TintColor =
		p.grade.brightness, p.grade.contrast, p.grade.saturation, p.grade.tint
	local b = child("BloomEffect", "Bloom")
	b.Intensity, b.Size, b.Threshold = p.bloom.intensity, p.bloom.size, p.bloom.threshold
	local rays = child("SunRaysEffect", "SunRays")
	rays.Intensity, rays.Spread = 0.08, 0.8
	-- a touch of depth: the far isles soften (PerformanceController turns it off on phones)
	local dof = child("DepthOfFieldEffect", "Depth")
	dof.FarIntensity, dof.NearIntensity, dof.FocusDistance, dof.InFocusRadius = 0.12, 0, 40, 90
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	local clouds = terrain and terrain:FindFirstChildOfClass("Clouds")
	if clouds and p.clouds then
		clouds.Cover, clouds.Density, clouds.Color = p.clouds.cover, p.clouds.density, p.clouds.color
	end
	return p
end

return LightingPresets
