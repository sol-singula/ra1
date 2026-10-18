--[[
The crops (master plan §5): what grows, how long it takes, what it sells for and the farm level that unlocks it.
Seeds are free: planting costs only the wait. A new crop unlocks every few levels and the farm plants the newest
(Crops.best) until the orders start asking for things; every harvest leaves the soil empty for the next planting. A harvest can come up golden (GOLDEN_CHANCE, more with the scarecrow and
the cow), worth GOLDEN_VALUE times as much.

  Crops.LIST          the keys in unlock order
  Crops[key]          { key, type ("fruit" | "veg": the cow and the pig boost one each), name, grow (seconds),
                       value (Cash each), xp, level, color, leaf, regrow? }
  Crops.unlocked(level) -> { keys }
  Crops.best(level)   the newest crop a level has (what the farm plants)
  Crops.nextUnlock(level) the next crop to unlock, or nil
  Crops.starter(level) -> grow, value: the new farmer's boost (crops grow STARTER_GROW times as fast and sell for
                       STARTER_VALUE times as much at level 1, fading out by STARTER_END), so the first minutes pay
]]
local Crops = {}

Crops.GOLDEN_CHANCE = 0.02
Crops.GOLDEN_VALUE = 10
Crops.WATER_CUT = 0.5 -- watering takes this share off what's left to grow
Crops.STARTER_GROW = 2
Crops.STARTER_VALUE = 2.5
Crops.STARTER_END = 7

local rgb = Color3.fromRGB
-- stylua: ignore start
local LIST = {
	{ key = "strawberry", type = "fruit", name = "Strawberry", grow = 8,     value = 8,    xp = 1,  level = 1,  color = rgb(230, 40, 60),   leaf = rgb(60, 160, 70) },
	{ key = "carrot", type = "veg",     name = "Carrot",     grow = 15,    value = 24,   xp = 3,  level = 4,  color = rgb(250, 130, 30),  leaf = rgb(80, 180, 70) },
	{ key = "corn", type = "veg",       name = "Corn",       grow = 25,    value = 60,   xp = 6,  level = 8,  color = rgb(250, 210, 50),  leaf = rgb(90, 170, 60) },
	{ key = "tomato", type = "veg",     name = "Tomato",     grow = 40,    value = 88,   xp = 8,  level = 12, color = rgb(220, 50, 40),   leaf = rgb(70, 150, 60) },
	{ key = "blueberry", type = "fruit",  name = "Blueberry",  grow = 60,    value = 200,  xp = 14, level = 16, color = rgb(70, 80, 200),   leaf = rgb(60, 140, 70) },
	{ key = "apple", type = "fruit",      name = "Apple",      grow = 90,    value = 560,  xp = 30, level = 20, color = rgb(210, 40, 40),   leaf = rgb(70, 160, 60) },
	{ key = "pumpkin", type = "veg",    name = "Pumpkin",    grow = 120,   value = 1920, xp = 70, level = 25, color = rgb(245, 130, 30),  leaf = rgb(70, 150, 60) },
	{ key = "watermelon", type = "fruit", name = "Watermelon", grow = 180,   value = 4000, xp = 120, level = 30, color = rgb(60, 160, 70),  leaf = rgb(80, 170, 70) },
	{ key = "orange", type = "fruit",     name = "Orange",     grow = 240,   value = 8800, xp = 200, level = 35, color = rgb(255, 150, 20), leaf = rgb(60, 150, 60) },
	{ key = "goldpumpkin", type = "veg", name = "Golden Pumpkin", grow = 480,   value = 80000, xp = 1000, level = 40, color = rgb(255, 200, 40), leaf = rgb(90, 170, 60) },
}
-- stylua: ignore end

Crops.LIST = {}
for i, c in LIST do
	c.index = i
	Crops[c.key] = c
	table.insert(Crops.LIST, c.key)
end

function Crops.unlocked(level)
	local out = {}
	for _, key in Crops.LIST do
		if Crops[key].level <= level then
			table.insert(out, key)
		end
	end
	return out
end

function Crops.best(level)
	-- (the newest crop a level has: what the farm plants)
	local best
	for _, key in Crops.LIST do
		local c = Crops[key]
		if c.level <= (level or 1) and (not best or c.level > best.level) then
			best = c
		end
	end
	return best and best.key or "strawberry"
end

-- The next crop to unlock after a level, or nil
function Crops.nextUnlock(level)
	for _, key in Crops.LIST do
		if Crops[key].level > (level or 1) then
			return Crops[key]
		end
	end
	return nil
end

function Crops.starter(level)
	local f = math.clamp(((Crops.STARTER_END - (level or 1)) / (Crops.STARTER_END - 1)), 0, 1)
	return 1 + (Crops.STARTER_GROW - 1) * f, 1 + (Crops.STARTER_VALUE - 1) * f
end

return Crops
