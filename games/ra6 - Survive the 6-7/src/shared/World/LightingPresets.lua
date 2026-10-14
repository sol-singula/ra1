-- The light of the day and the night (master plan §11: warm campfire light against cool moonlight, selective fog;
-- darkness creates tension without making the game hard to see). The client blends between the presets as the run
-- goes (LightingController) and sets the time of day from the clock (Formulas.clockTime); the server applies one
-- at start-up so Studio and the render tools look right. Tuned for Lighting.Technology = Future.
local Lighting = game:GetService("Lighting")

local LightingPresets = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

LightingPresets.list = {
	day = { -- a bright forest afternoon, a little haze between the trees
		clock = 13.2,
		brightness = 3,
		ambient = rgb(104, 104, 100),
		outdoor = rgb(150, 152, 146),
		exposure = 0.12,
		atmosphere = {
			density = 0.3,
			offset = 0.1,
			color = rgb(210, 226, 236),
			decay = rgb(128, 168, 190),
			glare = 0.15,
			haze = 1,
		},
		grade = { brightness = 0.02, contrast = 0.1, saturation = 0.2, tint = rgb(255, 250, 236) },
		bloom = { intensity = 0.3, size = 24, threshold = 1.7 },
		clouds = { cover = 0.42, density = 0.55, color = rgb(255, 255, 255) },
	},
	dusk = { -- the sun goes down orange; long shadows
		clock = 18.4,
		brightness = 1.8,
		ambient = rgb(108, 84, 84),
		outdoor = rgb(150, 112, 104),
		exposure = 0.08,
		atmosphere = {
			density = 0.36,
			offset = 0.08,
			color = rgb(246, 168, 120),
			decay = rgb(146, 82, 92),
			glare = 0.7,
			haze = 1.6,
		},
		grade = { brightness = 0.01, contrast = 0.14, saturation = 0.18, tint = rgb(255, 224, 200) },
		bloom = { intensity = 0.45, size = 26, threshold = 1.5 },
		clouds = { cover = 0.58, density = 0.66, color = rgb(255, 196, 170) },
	},
	night = { -- cool moonlight: dark enough to be tense, light enough to see
		clock = 0.5,
		brightness = 1.4,
		ambient = rgb(70, 78, 108),
		outdoor = rgb(92, 104, 142),
		exposure = 0.18,
		atmosphere = {
			density = 0.4,
			offset = 0.05,
			color = rgb(84, 104, 150),
			decay = rgb(40, 52, 96),
			glare = 0,
			haze = 1.4,
		},
		grade = { brightness = 0.02, contrast = 0.16, saturation = 0.05, tint = rgb(208, 220, 255) },
		bloom = { intensity = 0.7, size = 28, threshold = 1.15 },
		clouds = { cover = 0.5, density = 0.6, color = rgb(120, 130, 170) },
	},
	boss = { -- the seventh night: a huge green moon over the camp
		clock = 0.2,
		brightness = 1.5,
		ambient = rgb(80, 92, 96),
		outdoor = rgb(102, 128, 118),
		exposure = 0.2,
		atmosphere = {
			density = 0.42,
			offset = 0.05,
			color = rgb(110, 150, 120),
			decay = rgb(44, 82, 70),
			glare = 0.2,
			haze = 1.5,
		},
		grade = { brightness = 0.02, contrast = 0.2, saturation = 0.14, tint = rgb(220, 255, 226) },
		bloom = { intensity = 0.8, size = 30, threshold = 1.1 },
		clouds = { cover = 0.62, density = 0.7, color = rgb(120, 160, 130) },
	},
	dawn = { -- pink morning light: you made it
		clock = 6.3,
		brightness = 2.1,
		ambient = rgb(108, 96, 108),
		outdoor = rgb(156, 138, 150),
		exposure = 0.14,
		atmosphere = {
			density = 0.34,
			offset = 0.1,
			color = rgb(244, 196, 196),
			decay = rgb(160, 120, 150),
			glare = 0.5,
			haze = 1.3,
		},
		grade = { brightness = 0.02, contrast = 0.1, saturation = 0.2, tint = rgb(255, 236, 236) },
		bloom = { intensity = 0.4, size = 26, threshold = 1.5 },
		clouds = { cover = 0.45, density = 0.55, color = rgb(255, 214, 220) },
	},
	bloodmoon = { -- a red night: everything is faster
		clock = 0.5,
		brightness = 1.3,
		ambient = rgb(102, 60, 66),
		outdoor = rgb(136, 74, 82),
		exposure = 0.16,
		atmosphere = {
			density = 0.42,
			offset = 0.05,
			color = rgb(170, 70, 70),
			decay = rgb(90, 24, 34),
			glare = 0.2,
			haze = 1.6,
		},
		grade = { brightness = 0.01, contrast = 0.2, saturation = 0.16, tint = rgb(255, 200, 196) },
		bloom = { intensity = 0.8, size = 30, threshold = 1.1 },
		clouds = { cover = 0.6, density = 0.7, color = rgb(150, 70, 74) },
	},
	fog = { -- a thick fog night
		clock = 0.5,
		brightness = 1.3,
		ambient = rgb(84, 90, 108),
		outdoor = rgb(104, 112, 134),
		exposure = 0.2,
		atmosphere = {
			density = 0.62,
			offset = 0,
			color = rgb(124, 134, 156),
			decay = rgb(70, 78, 100),
			glare = 0,
			haze = 2.6,
		},
		grade = { brightness = 0.02, contrast = 0.1, saturation = 0.02, tint = rgb(220, 226, 240) },
		bloom = { intensity = 0.6, size = 28, threshold = 1.2 },
		clouds = { cover = 0.8, density = 0.8, color = rgb(120, 126, 140) },
	},
	storm = { -- rain and lightning
		clock = 0.5,
		brightness = 1.1,
		ambient = rgb(70, 74, 92),
		outdoor = rgb(86, 92, 116),
		exposure = 0.16,
		atmosphere = {
			density = 0.48,
			offset = 0.03,
			color = rgb(80, 90, 116),
			decay = rgb(40, 44, 66),
			glare = 0,
			haze = 2,
		},
		grade = { brightness = 0, contrast = 0.2, saturation = 0, tint = rgb(210, 216, 236) },
		bloom = { intensity = 0.6, size = 28, threshold = 1.2 },
		clouds = { cover = 0.92, density = 0.95, color = rgb(80, 84, 100) },
	},
	fireflies = { -- a soft warm night full of fireflies
		clock = 0.5,
		brightness = 1.5,
		ambient = rgb(76, 84, 106),
		outdoor = rgb(98, 112, 140),
		exposure = 0.2,
		atmosphere = {
			density = 0.36,
			offset = 0.05,
			color = rgb(100, 122, 150),
			decay = rgb(56, 70, 100),
			glare = 0,
			haze = 1.2,
		},
		grade = { brightness = 0.03, contrast = 0.14, saturation = 0.12, tint = rgb(226, 236, 255) },
		bloom = { intensity = 0.9, size = 30, threshold = 1.05 },
		clouds = { cover = 0.4, density = 0.5, color = rgb(120, 130, 170) },
	},
}

-- Which preset a stage uses (night events change the night).
function LightingPresets.forPhase(phase, event)
	if phase == "night" and event and LightingPresets.list[event] then
		return event
	end
	if phase == "results" or phase == "idle" then
		return "dawn"
	end
	return LightingPresets.list[phase] and phase or "day"
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

local function lerp(a, b, t)
	return a + (b - a) * t
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
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = true
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
	rays.Intensity, rays.Spread = 0.06, 0.75
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	local clouds = terrain and terrain:FindFirstChildOfClass("Clouds")
	if clouds and p.clouds then
		clouds.Cover, clouds.Density, clouds.Color = p.clouds.cover, p.clouds.density, p.clouds.color
	end
	return p
end

return LightingPresets
