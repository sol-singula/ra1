-- The light of each part of a match (master plan §14: sunset and night light that changes as the match goes on;
-- §13: the plague turns the sky, the last stand gets redder). The client blends to the preset of the phase
-- (FxController); the server applies one at start-up so Studio and the render tools look right. Tuned for
-- Lighting.Technology = Future and a bright cartoon look: saturated, soft shadows, a little bloom.
local Lighting = game:GetService("Lighting")

local LightingPresets = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

LightingPresets.list = {
	hangout = { -- a fresh morning on the ridge
		clock = 9.6,
		brightness = 3,
		ambient = rgb(108, 104, 112),
		outdoor = rgb(150, 150, 160),
		exposure = 0.15,
		atmosphere = {
			density = 0.24,
			offset = 0.12,
			color = rgb(206, 226, 248),
			decay = rgb(118, 160, 214),
			glare = 0.2,
			haze = 0.8,
		},
		grade = { brightness = 0.02, contrast = 0.08, saturation = 0.22, tint = rgb(255, 250, 240) },
		bloom = { intensity = 0.35, size = 24, threshold = 1.6 },
		clouds = { cover = 0.46, density = 0.55, color = rgb(255, 255, 255) },
	},
	build = { -- a bright, happy afternoon
		clock = 13.6,
		brightness = 3.1,
		ambient = rgb(112, 108, 116),
		outdoor = rgb(156, 154, 162),
		exposure = 0.12,
		atmosphere = {
			density = 0.26,
			offset = 0.14,
			color = rgb(204, 226, 250),
			decay = rgb(112, 156, 214),
			glare = 0.1,
			haze = 0.7,
		},
		grade = { brightness = 0.02, contrast = 0.1, saturation = 0.24, tint = rgb(255, 250, 238) },
		bloom = { intensity = 0.35, size = 24, threshold = 1.6 },
		clouds = { cover = 0.5, density = 0.6, color = rgb(255, 255, 255) },
	},
	scare = { -- the first scare: a cloud over the sun
		clock = 15.4,
		brightness = 2.2,
		ambient = rgb(96, 92, 108),
		outdoor = rgb(126, 124, 142),
		exposure = 0.05,
		atmosphere = {
			density = 0.32,
			offset = 0.1,
			color = rgb(184, 196, 222),
			decay = rgb(100, 112, 160),
			glare = 0,
			haze = 1,
		},
		grade = { brightness = 0, contrast = 0.12, saturation = 0.12, tint = rgb(240, 240, 255) },
		bloom = { intensity = 0.4, size = 24, threshold = 1.5 },
		clouds = { cover = 0.74, density = 0.78, color = rgb(196, 200, 214) },
	},
	plague = { -- the sky turns: a sick purple-green sunset
		clock = 17.9,
		brightness = 1.6,
		ambient = rgb(92, 76, 112),
		outdoor = rgb(120, 100, 150),
		exposure = 0.05,
		atmosphere = {
			density = 0.38,
			offset = 0.08,
			color = rgb(170, 140, 206),
			decay = rgb(96, 64, 136),
			glare = 0.3,
			haze = 1.6,
		},
		grade = { brightness = 0, contrast = 0.16, saturation = 0.18, tint = rgb(228, 214, 255) },
		bloom = { intensity = 0.55, size = 28, threshold = 1.4 },
		clouds = { cover = 0.8, density = 0.82, color = rgb(176, 150, 206) },
	},
	fight = { -- the attack: an orange sunset
		clock = 18.3,
		brightness = 2,
		ambient = rgb(104, 82, 84),
		outdoor = rgb(150, 116, 110),
		exposure = 0.1,
		atmosphere = {
			density = 0.32,
			offset = 0.1,
			color = rgb(244, 172, 122),
			decay = rgb(152, 84, 78),
			glare = 0.6,
			haze = 1.4,
		},
		grade = { brightness = 0.01, contrast = 0.14, saturation = 0.2, tint = rgb(255, 228, 206) },
		bloom = { intensity = 0.5, size = 26, threshold = 1.5 },
		clouds = { cover = 0.58, density = 0.66, color = rgb(255, 214, 186) },
	},
	laststand = { -- the last stand: night, and redder
		clock = 20.6,
		brightness = 1,
		ambient = rgb(92, 52, 62),
		outdoor = rgb(120, 66, 80),
		exposure = 0.05,
		atmosphere = {
			density = 0.4,
			offset = 0.06,
			color = rgb(196, 80, 72),
			decay = rgb(96, 24, 40),
			glare = 0.4,
			haze = 1.8,
		},
		grade = { brightness = 0, contrast = 0.18, saturation = 0.16, tint = rgb(255, 196, 186) },
		bloom = { intensity = 0.7, size = 30, threshold = 1.2 },
		clouds = { cover = 0.86, density = 0.9, color = rgb(150, 72, 76) },
	},
	ended = { -- the dust settles
		clock = 19.2,
		brightness = 1.6,
		ambient = rgb(100, 86, 104),
		outdoor = rgb(136, 118, 140),
		exposure = 0.08,
		atmosphere = {
			density = 0.3,
			offset = 0.1,
			color = rgb(214, 170, 170),
			decay = rgb(126, 86, 110),
			glare = 0.3,
			haze = 1.2,
		},
		grade = { brightness = 0.01, contrast = 0.12, saturation = 0.16, tint = rgb(255, 236, 230) },
		bloom = { intensity = 0.5, size = 26, threshold = 1.4 },
		clouds = { cover = 0.55, density = 0.62, color = rgb(232, 196, 196) },
	},
}
LightingPresets.list.intermission = LightingPresets.list.hangout

-- Which preset a phase uses.
function LightingPresets.forPhase(phase, scared)
	if phase == "build" and scared then
		return "scare"
	end
	return LightingPresets.list[phase] and phase or "build"
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
	local a, b =
		LightingPresets.list[from] or LightingPresets.list.build, LightingPresets.list[to] or LightingPresets.list.build
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

-- Apply a preset (a name, or a table from blend) to Lighting.
function LightingPresets.apply(preset)
	local p = type(preset) == "table" and preset or LightingPresets.list[preset] or LightingPresets.list.build
	Lighting.ClockTime = p.clock
	Lighting.Brightness = p.brightness
	Lighting.Ambient = p.ambient
	Lighting.OutdoorAmbient = p.outdoor
	Lighting.ExposureCompensation = p.exposure
	Lighting.EnvironmentDiffuseScale = 1 -- the textured (PBR) materials want the full sky light and reflections
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
	rays.Intensity, rays.Spread = 0.05, 0.7
	-- the sky's clouds follow the match too (the terrain's Clouds; a local change on each client)
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	local clouds = terrain and terrain:FindFirstChildOfClass("Clouds")
	if clouds and p.clouds then
		clouds.Cover, clouds.Density, clouds.Color = p.clouds.cover, p.clouds.density, p.clouds.color
	end
	return p
end

return LightingPresets
