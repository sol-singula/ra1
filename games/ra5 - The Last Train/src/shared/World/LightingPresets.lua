-- The look of each place: time of day, ambient light, atmosphere (fog), colour grading, bloom. The server applies
-- the preset of wherever the train is (workspace attribute "LightPreset"); a player who was left behind sees the
-- "recovery" night locally until they're back. Tuned for Lighting.Technology = Future.
local Lighting = game:GetService("Lighting")

local LightingPresets = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

LightingPresets.list = {
	station = {
		clock = 19.2,
		brightness = 1.1,
		ambient = rgb(46, 38, 34),
		outdoor = rgb(70, 62, 74),
		exposure = 0.1,
		atmosphere = {
			density = 0.22,
			offset = 0.1,
			color = rgb(210, 176, 140),
			decay = rgb(96, 64, 52),
			glare = 0,
			haze = 1,
		},
		grade = { brightness = 0.02, contrast = 0.14, saturation = 0.06, tint = rgb(255, 240, 224) },
		bloom = { intensity = 0.7, size = 28, threshold = 1.5 },
		sky = { top = rgb(40, 34, 52), horizon = rgb(160, 110, 80) },
	},
	travel = {
		clock = 20.6,
		brightness = 0.5,
		ambient = rgb(30, 30, 40),
		outdoor = rgb(44, 50, 74),
		exposure = 0,
		atmosphere = {
			density = 0.45,
			offset = 0.05,
			color = rgb(86, 98, 130),
			decay = rgb(36, 42, 66),
			glare = 0,
			haze = 2,
		},
		grade = { brightness = 0, contrast = 0.16, saturation = -0.05, tint = rgb(222, 232, 255) },
		bloom = { intensity = 0.8, size = 30, threshold = 1.4 },
		sky = { top = rgb(14, 18, 34), horizon = rgb(56, 64, 96) },
	},
	-- two more moods for the line, so trips don't all look the same (ExpeditionService cycles them)
	travelGold = {
		clock = 17.6,
		brightness = 2.1,
		ambient = rgb(54, 44, 40),
		outdoor = rgb(130, 108, 88),
		exposure = 0.1,
		atmosphere = {
			density = 0.3,
			offset = 0.1,
			color = rgb(236, 186, 126),
			decay = rgb(130, 84, 60),
			glare = 0.5,
			haze = 1.4,
		},
		grade = { brightness = 0.02, contrast = 0.14, saturation = 0.12, tint = rgb(255, 234, 206) },
		bloom = { intensity = 0.6, size = 26, threshold = 1.6 },
		sunrays = 0.1,
		sky = { top = rgb(84, 96, 140), horizon = rgb(246, 176, 108) },
	},
	travelMist = {
		clock = 8.4,
		brightness = 1.3,
		ambient = rgb(56, 62, 64),
		outdoor = rgb(118, 128, 128),
		exposure = 0.05,
		atmosphere = {
			density = 0.5,
			offset = 0.06,
			color = rgb(196, 206, 204),
			decay = rgb(118, 130, 132),
			glare = 0,
			haze = 2.4,
		},
		grade = { brightness = 0.02, contrast = 0.1, saturation = -0.08, tint = rgb(236, 246, 255) },
		bloom = { intensity = 0.5, size = 24, threshold = 1.7 },
		sky = { top = rgb(150, 166, 176), horizon = rgb(206, 214, 212) },
	},
	dusk = {
		clock = 18.15,
		brightness = 2,
		ambient = rgb(52, 42, 42),
		outdoor = rgb(124, 102, 92),
		exposure = 0.1,
		atmosphere = {
			density = 0.34,
			offset = 0.12,
			color = rgb(232, 172, 122),
			decay = rgb(120, 70, 62),
			glare = 0.4,
			haze = 1.6,
		},
		grade = { brightness = 0.02, contrast = 0.14, saturation = 0.1, tint = rgb(255, 236, 214) },
		bloom = { intensity = 0.6, size = 26, threshold = 1.6 },
		sunrays = 0.08,
		sky = { top = rgb(70, 74, 120), horizon = rgb(240, 158, 96) },
	},
	overcast = {
		clock = 15.5,
		brightness = 1.4,
		ambient = rgb(56, 58, 60),
		outdoor = rgb(122, 126, 126),
		exposure = 0,
		atmosphere = {
			density = 0.42,
			offset = 0.08,
			color = rgb(192, 198, 198),
			decay = rgb(112, 118, 122),
			glare = 0,
			haze = 2.2,
		},
		grade = { brightness = 0, contrast = 0.12, saturation = -0.12, tint = rgb(240, 246, 250) },
		bloom = { intensity = 0.4, size = 24, threshold = 1.8 },
		sky = { top = rgb(120, 128, 136), horizon = rgb(190, 196, 196) },
	},
	bluehour = {
		clock = 19.65,
		brightness = 0.9,
		ambient = rgb(40, 44, 62),
		outdoor = rgb(72, 82, 122),
		exposure = 0.15,
		atmosphere = {
			density = 0.36,
			offset = 0.06,
			color = rgb(112, 132, 192),
			decay = rgb(60, 70, 122),
			glare = 0,
			haze = 1.4,
		},
		grade = { brightness = 0.02, contrast = 0.16, saturation = 0.02, tint = rgb(226, 232, 255) },
		bloom = { intensity = 0.9, size = 30, threshold = 1.3 },
		sky = { top = rgb(26, 34, 76), horizon = rgb(120, 120, 180) },
	},
	greenfog = {
		clock = 6.4,
		brightness = 1,
		ambient = rgb(44, 54, 44),
		outdoor = rgb(92, 112, 92),
		exposure = 0.05,
		atmosphere = {
			density = 0.5,
			offset = 0.1,
			color = rgb(152, 182, 142),
			decay = rgb(70, 96, 72),
			glare = 0,
			haze = 2.6,
		},
		grade = { brightness = 0.01, contrast = 0.12, saturation = -0.06, tint = rgb(230, 250, 226) },
		bloom = { intensity = 0.6, size = 26, threshold = 1.5 },
		sky = { top = rgb(96, 120, 104), horizon = rgb(176, 200, 168) },
	},
	recovery = {
		clock = 0.6,
		brightness = 0.3,
		ambient = rgb(26, 28, 40),
		outdoor = rgb(42, 48, 82),
		exposure = 0.2,
		atmosphere = {
			density = 0.46,
			offset = 0.04,
			color = rgb(62, 72, 112),
			decay = rgb(22, 26, 52),
			glare = 0,
			haze = 1.8,
		},
		grade = { brightness = 0.02, contrast = 0.18, saturation = -0.1, tint = rgb(214, 224, 255) },
		bloom = { intensity = 1, size = 30, threshold = 1.2 },
		sky = { top = rgb(8, 10, 24), horizon = rgb(36, 44, 80) },
	},
}

local function child(className, name)
	local inst = Lighting:FindFirstChild(name)
	if not inst then
		inst = Instance.new(className)
		inst.Name = name
		inst.Parent = Lighting
	end
	return inst
end

-- Apply a preset to Lighting (server: for everyone; client: just for this player).
function LightingPresets.apply(name)
	local p = LightingPresets.list[name] or LightingPresets.list.station
	Lighting.ClockTime = p.clock
	Lighting.Brightness = p.brightness
	Lighting.Ambient = p.ambient
	Lighting.OutdoorAmbient = p.outdoor
	Lighting.ExposureCompensation = p.exposure
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
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
	local s = child("SunRaysEffect", "SunRays")
	s.Intensity = p.sunrays or 0
	s.Spread = 0.6
	return p
end

return LightingPresets
