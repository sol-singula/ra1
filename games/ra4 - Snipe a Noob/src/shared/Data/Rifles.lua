-- The rifles. Every rifle pops in one hit: they are different ways to play, not stronger ones. A rifle unlocks
-- at a level, then costs coins.
--   fov: how far the scope zooms (smaller = closer)   bolt: seconds between shots   shots: shots before the bolt
--   tracer: shows a line where the shot went (Ghost doesn't)   body/barrel/stock: the look (box style)
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local Rifles = {}

Rifles.list = {
	{
		key = "BOLT",
		name = "Bolt",
		level = 1,
		price = 0,
		fov = 42,
		bolt = 1.2,
		shots = 1,
		tracer = true,
		desc = "The classic. Steady and fair.",
		color = rgb(70, 75, 95),
		accent = rgb(255, 200, 40),
		barrel = 4.2,
		look = { -- classic: a wooden stock, dark steel, brass trim
			stock = rgb(150, 95, 50),
			stockMaterial = "Wood",
			body = rgb(60, 64, 80),
			metal = rgb(40, 42, 52),
			accent = rgb(220, 170, 60),
			pattern = "wood",
			colors = { rgb(120, 70, 35) },
		},
	},
	{
		key = "SWIFT",
		name = "Swift",
		level = 5,
		price = 5000,
		fov = 52,
		bolt = 0.8,
		shots = 1,
		tracer = true,
		desc = "Fast bolt, small zoom. For close fights.",
		color = rgb(40, 160, 230),
		accent = rgb(255, 255, 255),
		barrel = 3.4,
		look = { -- racing: white and sky blue with stripes
			stock = rgb(245, 248, 255),
			body = rgb(40, 160, 230),
			metal = rgb(50, 55, 70),
			accent = rgb(255, 255, 255),
			pattern = "stripes",
			colors = { rgb(40, 160, 230), rgb(255, 80, 80) },
		},
	},
	{
		key = "EAGLE",
		name = "Eagle",
		level = 12,
		price = 15000,
		fov = 30,
		bolt = 1.6,
		shots = 1,
		tracer = true,
		desc = "Huge zoom, slow bolt. For far away.",
		color = rgb(120, 80, 50),
		accent = rgb(255, 215, 60),
		barrel = 5.4,
		look = { -- desert camo
			stock = rgb(190, 160, 110),
			body = rgb(150, 120, 80),
			metal = rgb(70, 60, 50),
			accent = rgb(255, 215, 60),
			pattern = "camo",
			colors = { rgb(120, 95, 60), rgb(220, 195, 145), rgb(90, 100, 60) },
		},
	},
	{
		key = "GHOST",
		silencer = true,
		name = "Ghost",
		level = 20,
		price = 30000,
		fov = 42,
		bolt = 1.35,
		shots = 1,
		tracer = false,
		desc = "No tracer line. Nobody sees where you are.",
		color = rgb(230, 235, 245),
		accent = rgb(120, 220, 255),
		barrel = 4.4,
		look = { -- arctic camo, with a silencer
			stock = rgb(235, 240, 248),
			body = rgb(210, 220, 235),
			metal = rgb(120, 130, 150),
			accent = rgb(120, 220, 255),
			pattern = "camo",
			colors = { rgb(180, 195, 215), rgb(150, 170, 195), rgb(255, 255, 255) },
		},
	},
	{
		key = "TWIN",
		name = "Twin",
		level = 30,
		price = 60000,
		fov = 46,
		bolt = 2.2,
		shots = 2,
		gap = 0.35,
		tracer = true,
		desc = "Two quick shots, then a long reload.",
		color = rgb(200, 60, 70),
		accent = rgb(40, 40, 50),
		barrel = 4,
		look = { -- red and black tiger
			stock = rgb(200, 50, 60),
			body = rgb(40, 40, 50),
			metal = rgb(30, 30, 36),
			accent = rgb(255, 200, 40),
			pattern = "tiger",
			colors = { rgb(30, 30, 36) },
		},
	},
}
Rifles.byKey = {}
for i, r in Rifles.list do
	r.order = i
	Rifles.byKey[r.key] = r
end

-- Seconds before the next shot after firing shot number `n` of a clip.
function Rifles.cooldown(rifle, n)
	if rifle.shots > 1 and n < rifle.shots then
		return rifle.gap
	end
	return rifle.bolt
end

return Rifles
