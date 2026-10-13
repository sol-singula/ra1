-- The arenas. Each one has three sizes (MapBuilder picks the size from the crowd). Bright brick style.
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local Maps = {}

Maps.list = {
	{
		key = "TOWN",
		name = "Block Town",
		emoji = "🏘️",
		floor = rgb(150, 215, 120),
		path = rgb(240, 232, 215),
		wall = rgb(250, 245, 230),
		cover = { rgb(230, 90, 80), rgb(80, 150, 230), rgb(250, 200, 60), rgb(240, 240, 240) },
		roof = rgb(200, 70, 60),
		accent = rgb(255, 200, 40),
		props = "town",
	},
	{
		key = "CANDY",
		name = "Candy Canyon",
		emoji = "🍭",
		floor = rgb(255, 190, 220),
		path = rgb(255, 240, 200),
		wall = rgb(170, 120, 230),
		cover = { rgb(255, 120, 170), rgb(120, 220, 255), rgb(255, 230, 120), rgb(160, 240, 160) },
		roof = rgb(255, 255, 255),
		accent = rgb(255, 80, 150),
		props = "candy",
	},
	{
		key = "DOCK",
		name = "Space Dock",
		emoji = "🚀",
		floor = rgb(185, 200, 225),
		path = rgb(225, 235, 248),
		wall = rgb(160, 180, 215),
		cover = { rgb(150, 160, 190), rgb(255, 170, 40), rgb(120, 220, 255), rgb(200, 90, 255) },
		roof = rgb(120, 220, 255),
		accent = rgb(120, 220, 255),
		props = "dock",
	},
	{
		key = "CASTLE",
		name = "Castle Court",
		emoji = "🏰",
		floor = rgb(175, 225, 135),
		path = rgb(225, 218, 205),
		wall = rgb(230, 224, 212),
		cover = { rgb(230, 224, 212), rgb(150, 142, 134), rgb(140, 90, 60), rgb(200, 60, 60) },
		roof = rgb(70, 90, 170),
		accent = rgb(200, 60, 60),
		props = "castle",
	},
}
Maps.byKey = {}
for _, m in Maps.list do
	Maps.byKey[m.key] = m
end

return Maps
