-- The shared train's upgrades (TrainService). Anyone can give materials from their own storage; a stage finishes by
-- itself the moment everything it needs is in, and everyone aboard sees what changed. Upgrades belong to this
-- expedition's train: the next expedition starts with a fresh train (and the Hall of Records remembers how each
-- record train looked).
local TrainUpgrades = {}

TrainUpgrades.list = {
	{
		key = "engine",
		name = "Engine Overhaul",
		icon = "🔥",
		text = "Every trip burns less fuel, so the crew gets farther.",
		stages = {
			{ name = "Overhaul I", cost = { scrap = 10, parts = 4 }, effect = "Trips cost 1.6 fuel instead of 2." },
			{
				name = "Overhaul II",
				cost = { scrap = 16, parts = 8, cloth = 4 },
				plans = "engine",
				effect = "Trips cost 1.3 fuel.",
			},
			{
				name = "Overhaul III",
				cost = { scrap = 24, parts = 12, wood = 10 },
				plans = "engine",
				effect = "Trips cost 1 fuel. The engine glows gold.",
			},
		},
	},
	{
		key = "lamp",
		name = "Scout Lamp",
		icon = "🔦",
		text = "See what's ahead, and get stranded crew back faster.",
		stages = {
			{
				name = "Searchlight",
				cost = { scrap = 8, parts = 3, cloth = 3 },
				effect = "See the next stop before you arrive. +15 seconds at every stop.",
			},
			{
				name = "Radio Mast",
				cost = { scrap = 12, parts = 6, wood = 6 },
				plans = "radio",
				effect = "Left-behind crew are picked up right away. Blueprints glow from far.",
			},
		},
	},
}

TrainUpgrades.byKey = {}
for _, u in TrainUpgrades.list do
	TrainUpgrades.byKey[u.key] = u
end

return TrainUpgrades
