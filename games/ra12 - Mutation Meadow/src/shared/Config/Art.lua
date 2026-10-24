--[[
Art numbers shared by the client effects. revealSounds are the confirmed Roblox library picks for the mutation
reveal's cues (build-spec/04-reveal.md section 2.6: wet a soft drip, golden one bright chime, wetgolden the two
layered; burst the soil puff, used only when a key has no cue of its own, never with one). reveal is
04-reveal.md's timeline as data (RevealController plays it).
]]
-- stylua: ignore start
local Art = {}

Art.revealSounds = {
	burst = "rbxassetid://9114111252",
	wet = "rbxassetid://9112872058",
	golden = "rbxassetid://9119447936",
	wetgolden = "rbxassetid://9125643080",
}

Art.reveal = {
	rangeStuds = 60, -- section 0: your plot, or a crop this close to your character
	concurrent = 2, -- section 4: the nearest two
	maxEmit = 30, -- section 4: per reveal (Wet+Golden drops the soil puff to soilPressure)
	soilPressure = 10,
	reducedEmit = 0.5, -- section 2: every Emit count halves under reducedFx
	sound = { volume = 0.6, maxDistance = 40 },
	highlight = {
		fill = { wet = "#50AAFF", golden = "#FFC300", wetgolden = "#FFC300" },
		outline = { wet = "#DFF4FF", golden = "#FFF1A8", wetgolden = "#8FD3FF" },
		fillTransparency = 0.55, outlineTransparency = 0.15,
		fadeAt = 0.80, fadeSec = 0.5, cap = 31,
	},
	punch = { fov = -4, sec = 0.3 }, -- Quad Out back to the FOV it started from
	soil = {
		at = 0, emit = 14, colours = { "#7A4E2D", "#A0784B" }, lifetime = { 0.35, 0.55 }, speed = { 2, 5 },
		spread = { 40, 40 }, acceleration = { 0, -10, 0 },
		size = { { 0, 0.25 }, { 0.4, 0.45 }, { 1, 0.1 } }, transparency = { { 0, 0.2 }, { 1, 1 } },
		lightEmission = 0, squash = 0,
	},
	burstAt = 0.05,
	burstLifeSec = 1.0, -- the burst emitters go after 1.0 s
	droplet = {
		emit = { wet = 16, wetgolden = 10 }, colours = { "#8FD3FF", "#50AAFF" }, lifetime = { 0.4, 0.7 },
		speed = { 4, 8 }, spread = { 70, 70 }, acceleration = { 0, -14, 0 },
		size = { { 0, 0.12 }, { 0.3, 0.18 }, { 1, 0.08 } }, squash = { { 0, 0.8 }, { 1, 1.4 } },
		transparency = { { 0, 0.1 }, { 0.8, 0.3 }, { 1, 1 } }, lightEmission = 0.15, orientation = "VelocityParallel",
	},
	star = {
		emit = { golden = 12, wetgolden = 8 }, colours = { "#FFC300", "#FFF1A8" }, lifetime = { 0.4, 0.6 },
		speed = { 3, 6 }, spread = { 60, 60 }, acceleration = { 0, -4, 0 },
		size = { { 0, 0.2 }, { 0.4, 0.55 }, { 1, 0 } }, squash = 0,
		transparency = { { 0, 0.05 }, { 0.7, 0.2 }, { 1, 1 } }, lightEmission = 0.5, orientation = "FacingCamera",
		rotSpeed = { -90, 90 },
	},
	ring = {
		at = 0.10, sec = 0.45, hex = "#8FD3FF", from = { 0.06, 0.4, 0.4 }, to = { 0.06, 3.2, 3.2 },
		transparency = 0.3, reflectance = 0.2,
	},
	shine = {
		at = 0.15, sec = 0.6, hex = "#FFF1A8", widthScale = 1.1, height = 0.08, depth = 0.12, travel = 0.55,
		transparency = 0.2,
	},
	cleanupAt = 1.5,
}
-- stylua: ignore end

return Art
