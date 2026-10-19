--[[
The crops (master plan §7): each has a reason to exist. Cheap ones grow fast and keep the shelves full; premium
ones take longer and earn more per tile. Four readable growth stages (§9): seedling, growing, nearly ripe, ready.
The plants themselves are World/CropModels (each crop its own plant: strawberry rosettes, staked tomato vines,
wheat with golden ears, corn with cobs, pumpkins and melons on sprawling vines, blueberry bushes, apple trees).

  Crops.LIST            in unlock order
  Crops[key]            { name, icon, grow (seconds), value ($ a unit), color (the fruit), leaf, model, unlock }
  Crops.stage(elapsed, grow)   1..4
  Crops.perMinute(key)  $ a minute one tile of it earns
]]
local rgb = Color3.fromRGB

local Crops = {}

Crops.LIST = { "strawberry", "tomato", "wheat", "corn", "pumpkin", "blueberry", "melon", "goldenApple" }

-- stylua: ignore start
Crops.strawberry  = { name = "Strawberry",   icon = "🍓", grow = 6,   value = 8,    color = rgb(228, 40, 56),  leaf = rgb(60, 160, 70),  model = "strawberry" }
Crops.tomato      = { name = "Tomato",       icon = "🍅", grow = 10,  value = 18,   color = rgb(232, 64, 40),  leaf = rgb(56, 150, 64),  model = "tomato",  unlock = "tomato" }
Crops.wheat       = { name = "Wheat",        icon = "🌾", grow = 14,  value = 30,   color = rgb(232, 196, 90), leaf = rgb(150, 180, 70), model = "wheat",   unlock = "wheat" }
Crops.corn        = { name = "Corn",         icon = "🌽", grow = 20,  value = 50,   color = rgb(250, 210, 60), leaf = rgb(70, 160, 70),  model = "corn",    unlock = "corn" }
Crops.pumpkin     = { name = "Pumpkin",      icon = "🎃", grow = 30,  value = 90,   color = rgb(244, 132, 36), leaf = rgb(70, 150, 60),  model = "pumpkin", unlock = "pumpkin" }
Crops.blueberry   = { name = "Blueberry",    icon = "🫐", grow = 28,  value = 100,  color = rgb(70, 86, 200),  leaf = rgb(60, 140, 80),  model = "bush",    unlock = "blueberry" }
Crops.melon       = { name = "Melon",        icon = "🍉", grow = 40,  value = 160,  color = rgb(60, 150, 70),  leaf = rgb(70, 160, 70),  model = "melon",   unlock = "melon" }
Crops.goldenApple = { name = "Golden Apple", icon = "🍎", grow = 70,  value = 420,  color = rgb(255, 196, 40), leaf = rgb(60, 150, 70),  model = "tree",    unlock = "orchard" }
-- stylua: ignore end

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
