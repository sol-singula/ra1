--[[
The crops (master plan §7): each has a reason to exist. Cheap ones grow fast and keep the shelves full; premium
ones take longer and earn more per tile. Four readable growth stages (§9): seedling, growing, nearly ripe, ready.

  Crops.LIST            in unlock order
  Crops[key]            { name, icon, grow (seconds), value ($ a unit), color, shape, unlock (upgrade key or nil) }
  Crops.stage(elapsed, grow)   1..4
  Crops.perMinute(key)  $ a minute one tile of it earns
]]
local rgb = Color3.fromRGB

local Crops = {}

Crops.LIST = { "strawberry", "tomato", "wheat", "corn", "pumpkin", "blueberry", "melon", "goldenApple" }

Crops.strawberry =
	{ name = "Strawberry", icon = "🍓", grow = 10, value = 3, color = rgb(230, 50, 60), shape = "bush" }
Crops.tomato = {
	name = "Tomato",
	icon = "🍅",
	grow = 15,
	value = 6,
	color = rgb(236, 72, 48),
	shape = "vine",
	unlock = "tomato",
}
Crops.wheat = {
	name = "Wheat",
	icon = "🌾",
	grow = 20,
	value = 10,
	color = rgb(236, 200, 90),
	shape = "stalk",
	unlock = "wheat",
}
Crops.corn =
	{ name = "Corn", icon = "🌽", grow = 30, value = 18, color = rgb(250, 212, 60), shape = "tall", unlock = "corn" }
Crops.pumpkin = {
	name = "Pumpkin",
	icon = "🎃",
	grow = 45,
	value = 32,
	color = rgb(246, 140, 40),
	shape = "gourd",
	unlock = "pumpkin",
}
Crops.blueberry = {
	name = "Blueberry",
	icon = "🫐",
	grow = 40,
	value = 36,
	color = rgb(80, 90, 200),
	shape = "bush",
	unlock = "blueberry",
}
Crops.melon = {
	name = "Melon",
	icon = "🍉",
	grow = 60,
	value = 55,
	color = rgb(70, 170, 80),
	shape = "gourd",
	unlock = "melon",
}
Crops.goldenApple = {
	name = "Golden Apple",
	icon = "🍎",
	grow = 120,
	value = 150,
	color = rgb(255, 200, 40),
	shape = "tree",
	unlock = "orchard",
}

for _, key in Crops.LIST do
	Crops[key].key = key
end

Crops.STAGES = 4

function Crops.stage(elapsed, grow)
	local k = elapsed / math.max(grow, 1)
	if k >= 1 then
		return 4
	elseif k >= 0.55 then
		return 3
	elseif k >= 0.25 then
		return 2
	end
	return 1
end

function Crops.perMinute(key)
	local c = Crops[key]
	return c and (60 / c.grow) * c.value or 0
end

return Crops
