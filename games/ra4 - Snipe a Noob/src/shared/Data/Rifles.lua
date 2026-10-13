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
		fov = 28,
		bolt = 1.2,
		shots = 1,
		tracer = true,
		desc = "The classic. Steady and fair.",
		color = rgb(70, 75, 95),
		accent = rgb(255, 200, 40),
		barrel = 4.2,
	},
	{
		key = "SWIFT",
		name = "Swift",
		level = 5,
		price = 5000,
		fov = 42,
		bolt = 0.8,
		shots = 1,
		tracer = true,
		desc = "Fast bolt, small zoom. For close fights.",
		color = rgb(40, 160, 230),
		accent = rgb(255, 255, 255),
		barrel = 3.4,
	},
	{
		key = "EAGLE",
		name = "Eagle",
		level = 12,
		price = 15000,
		fov = 16,
		bolt = 1.6,
		shots = 1,
		tracer = true,
		desc = "Huge zoom, slow bolt. For far away.",
		color = rgb(120, 80, 50),
		accent = rgb(255, 215, 60),
		barrel = 5.4,
	},
	{
		key = "GHOST",
		name = "Ghost",
		level = 20,
		price = 30000,
		fov = 28,
		bolt = 1.35,
		shots = 1,
		tracer = false,
		desc = "No tracer line. Nobody sees where you are.",
		color = rgb(230, 235, 245),
		accent = rgb(120, 220, 255),
		barrel = 4.4,
	},
	{
		key = "TWIN",
		name = "Twin",
		level = 30,
		price = 60000,
		fov = 32,
		bolt = 2.2,
		shots = 2,
		gap = 0.35,
		tracer = true,
		desc = "Two quick shots, then a long reload.",
		color = rgb(200, 60, 70),
		accent = rgb(40, 40, 50),
		barrel = 4,
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
