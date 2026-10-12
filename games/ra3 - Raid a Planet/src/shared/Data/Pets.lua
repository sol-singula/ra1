-- Pets: little space critters that float next to you. Each adds a bit of damage and forge luck. They come from
-- eggs (bought with gems at the Egg Machine in the Hub; every egg shows its odds) and from raids.
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local Pets = {}

-- shape: "ball" | "box" | "star"; dmg and luck are bonuses (0.05 = +5%)
Pets.list = {
	{
		id = "MOONPUP",
		name = "Moon Pup",
		rarity = "Common",
		shape = "ball",
		color = rgb(220, 225, 240),
		dmg = 0.03,
		luck = 0.02,
	},
	{
		id = "DUSTBUN",
		name = "Dust Bun",
		rarity = "Common",
		shape = "ball",
		color = rgb(215, 170, 110),
		dmg = 0.03,
		luck = 0.02,
	},
	{
		id = "BLIP",
		name = "Blip",
		rarity = "Common",
		shape = "box",
		color = rgb(120, 220, 255),
		dmg = 0.04,
		luck = 0.01,
	},
	{
		id = "ZIPPY",
		name = "Zippy",
		rarity = "Common",
		shape = "star",
		color = rgb(255, 230, 120),
		dmg = 0.02,
		luck = 0.03,
	},
	{
		id = "FROSTKIT",
		name = "Frost Kit",
		rarity = "Rare",
		shape = "ball",
		color = rgb(160, 225, 255),
		dmg = 0.06,
		luck = 0.04,
	},
	{
		id = "LAVAPUP",
		name = "Lava Pup",
		rarity = "Rare",
		shape = "ball",
		color = rgb(255, 110, 40),
		dmg = 0.08,
		luck = 0.02,
	},
	{
		id = "LEAFLING",
		name = "Leafling",
		rarity = "Rare",
		shape = "box",
		color = rgb(90, 200, 90),
		dmg = 0.05,
		luck = 0.05,
	},
	{
		id = "SPARKBOT",
		name = "Spark Bot",
		rarity = "Rare",
		shape = "box",
		color = rgb(200, 210, 255),
		dmg = 0.07,
		luck = 0.03,
	},
	{
		id = "PRISMCAT",
		name = "Prism Cat",
		rarity = "Epic",
		shape = "star",
		color = rgb(230, 130, 255),
		dmg = 0.10,
		luck = 0.08,
	},
	{
		id = "STORMOWL",
		name = "Storm Owl",
		rarity = "Epic",
		shape = "ball",
		color = rgb(120, 140, 255),
		dmg = 0.12,
		luck = 0.06,
	},
	{
		id = "VOIDBAT",
		name = "Void Bat",
		rarity = "Epic",
		shape = "box",
		color = rgb(110, 70, 160),
		dmg = 0.14,
		luck = 0.04,
	},
	{
		id = "SUNFOX",
		name = "Sun Fox",
		rarity = "Legend",
		shape = "star",
		color = rgb(255, 225, 70),
		dmg = 0.20,
		luck = 0.12,
	},
	{
		id = "COMETDOG",
		name = "Comet Dog",
		rarity = "Legend",
		shape = "ball",
		color = rgb(255, 255, 255),
		dmg = 0.22,
		luck = 0.10,
	},
	{
		id = "NEBULAWHALE",
		name = "Nebula Whale",
		rarity = "Legend",
		shape = "box",
		color = rgb(190, 120, 255),
		dmg = 0.18,
		luck = 0.16,
	},
	{
		id = "GALAXYDRAGON",
		name = "Galaxy Dragon",
		rarity = "Secret",
		shape = "star",
		color = rgb(255, 80, 160),
		dmg = 0.35,
		luck = 0.25,
	},
	{
		id = "STARCHILD",
		name = "Star Child",
		rarity = "Secret",
		shape = "star",
		color = rgb(255, 250, 200),
		dmg = 0.30,
		luck = 0.30,
	},
}
Pets.byId = {}
for _, p in Pets.list do
	Pets.byId[p.id] = p
end

Pets.RarityColor = {
	Common = rgb(190, 190, 200),
	Rare = rgb(70, 170, 255),
	Epic = rgb(190, 90, 255),
	Legend = rgb(255, 180, 40),
	Secret = rgb(255, 80, 160),
}

-- Eggs: gem price and the odds per rarity (percent, adding to 100). Which pet of that rarity is random.
Pets.Eggs = {
	{
		key = "STAR",
		name = "Star Egg",
		gems = 25,
		emoji = "🥚",
		odds = { { "Common", 75 }, { "Rare", 22 }, { "Epic", 3 } },
	},
	{
		key = "NOVA",
		name = "Nova Egg",
		gems = 100,
		emoji = "🌟",
		odds = { { "Common", 30 }, { "Rare", 45 }, { "Epic", 20 }, { "Legend", 5 } },
	},
	{
		key = "GALAXY",
		name = "Galaxy Egg",
		gems = 400,
		emoji = "🌌",
		odds = { { "Rare", 30 }, { "Epic", 45 }, { "Legend", 22 }, { "Secret", 3 } },
	},
}
Pets.eggByKey = {}
for _, e in Pets.Eggs do
	Pets.eggByKey[e.key] = e
end

return Pets
