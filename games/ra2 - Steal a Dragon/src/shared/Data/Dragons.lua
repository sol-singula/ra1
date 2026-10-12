-- Every dragon. cps = coins per second for a Baby with no special; price = coins on the Dragon Road.
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local Dragons = {}

-- Ultra dragons never walk the road: the daily TOP EARNER wins one (LeaderboardService).
Dragons.Rarities = { "Common", "Rare", "Epic", "Legend", "Secret", "Ultra" }
Dragons.RarityRank = { Common = 1, Rare = 2, Epic = 3, Legend = 4, Secret = 5, Ultra = 6 }
Dragons.RarityColor = {
	Common = rgb(200, 205, 215),
	Rare = rgb(70, 160, 255),
	Epic = rgb(185, 90, 255),
	Legend = rgb(255, 190, 40),
	Secret = rgb(255, 70, 140),
	Ultra = rgb(120, 255, 240),
}
-- Carrying a heavier (rarer) dragon slows you down.
Dragons.CarrySpeed = { Common = 0.9, Rare = 0.85, Epic = 0.78, Legend = 0.7, Secret = 0.62, Ultra = 0.55 }

Dragons.list = {
	-- Common
	{
		id = "PUFF",
		name = "Puff",
		rarity = "Common",
		cps = 1,
		price = 25,
		weight = 40,
		body = rgb(110, 205, 95),
		belly = rgb(235, 245, 170),
		wing = rgb(70, 160, 70),
	},
	{
		id = "EMBER",
		name = "Ember",
		rarity = "Common",
		cps = 2,
		price = 55,
		weight = 30,
		body = rgb(255, 140, 60),
		belly = rgb(255, 225, 150),
		wing = rgb(220, 90, 40),
	},
	{
		id = "PEBBLE",
		name = "Pebble",
		rarity = "Common",
		cps = 3,
		price = 90,
		weight = 20,
		body = rgb(150, 150, 160),
		belly = rgb(215, 215, 220),
		wing = rgb(105, 105, 120),
	},
	{
		id = "BUBBLES",
		name = "Bubbles",
		rarity = "Common",
		cps = 4,
		price = 130,
		weight = 10,
		body = rgb(120, 205, 255),
		belly = rgb(225, 245, 255),
		wing = rgb(70, 150, 230),
	},
	-- Rare
	{
		id = "FROSTY",
		name = "Frosty",
		rarity = "Rare",
		cps = 8,
		price = 350,
		weight = 35,
		body = rgb(170, 230, 255),
		belly = rgb(250, 255, 255),
		wing = rgb(110, 190, 245),
	},
	{
		id = "SPARKY",
		name = "Sparky",
		rarity = "Rare",
		cps = 11,
		price = 520,
		weight = 28,
		body = rgb(255, 225, 60),
		belly = rgb(255, 250, 200),
		wing = rgb(240, 170, 30),
	},
	{
		id = "LEAFY",
		name = "Leafy",
		rarity = "Rare",
		cps = 14,
		price = 700,
		weight = 22,
		body = rgb(80, 220, 120),
		belly = rgb(200, 255, 190),
		wing = rgb(40, 150, 80),
	},
	{
		id = "CORAL",
		name = "Coral",
		rarity = "Rare",
		cps = 18,
		price = 950,
		weight = 15,
		body = rgb(255, 130, 160),
		belly = rgb(255, 225, 230),
		wing = rgb(230, 80, 120),
	},
	-- Epic
	{
		id = "BLAZE",
		name = "Blaze",
		rarity = "Epic",
		cps = 40,
		price = 3000,
		weight = 45,
		body = rgb(235, 50, 45),
		belly = rgb(255, 200, 90),
		wing = rgb(150, 25, 30),
	},
	{
		id = "STORM",
		name = "Storm",
		rarity = "Epic",
		cps = 55,
		price = 4500,
		weight = 33,
		body = rgb(120, 80, 220),
		belly = rgb(200, 190, 255),
		wing = rgb(70, 45, 150),
	},
	{
		id = "JELLY",
		name = "Jelly",
		rarity = "Epic",
		cps = 70,
		price = 6000,
		weight = 22,
		body = rgb(240, 80, 220),
		belly = rgb(255, 200, 250),
		wing = rgb(170, 40, 160),
	},
	-- Legend
	{
		id = "GOLDIE",
		name = "King Goldie",
		rarity = "Legend",
		cps = 250,
		price = 30000,
		weight = 45,
		body = rgb(255, 200, 40),
		belly = rgb(255, 245, 190),
		wing = rgb(220, 150, 20),
	},
	{
		id = "SHADOW",
		name = "Shadow",
		rarity = "Legend",
		cps = 360,
		price = 48000,
		weight = 33,
		body = rgb(45, 40, 60),
		belly = rgb(120, 90, 170),
		wing = rgb(130, 60, 220),
	},
	{
		id = "CRYSTAL",
		name = "Crystal",
		rarity = "Legend",
		cps = 500,
		price = 70000,
		weight = 22,
		body = rgb(225, 250, 255),
		belly = rgb(170, 240, 255),
		wing = rgb(90, 220, 255),
	},
	-- Secret
	{
		id = "REX",
		name = "Rainbow Rex",
		rarity = "Secret",
		cps = 2000,
		price = 400000,
		weight = 60,
		body = rgb(255, 90, 90),
		belly = rgb(255, 240, 120),
		wing = rgb(90, 200, 255),
	},
	{
		id = "GALAXY",
		name = "Galaxy",
		rarity = "Secret",
		cps = 3000,
		price = 650000,
		weight = 40,
		body = rgb(30, 30, 90),
		belly = rgb(120, 90, 255),
		wing = rgb(255, 120, 240),
	},
}

-- Specials: a sparkle on top that multiplies coins (and price).
Dragons.Specials = {
	FIRE = { name = "Fire", mult = 2, chance = 0.05, color = rgb(255, 120, 30) },
	ICE = { name = "Ice", mult = 2, chance = 0.03, color = rgb(150, 230, 255) },
	GOLD = { name = "Gold", mult = 3, chance = 0.015, color = rgb(255, 210, 50) },
	RAINBOW = { name = "Rainbow", mult = 5, chance = 0.004, color = rgb(255, 120, 255) },
}
Dragons.SpecialOrder = { "RAINBOW", "GOLD", "ICE", "FIRE" } -- rarest first when rolling

-- The 200 custom dragons (Data/FancyDragons.lua, made by tools/gen_dragons.py): special looks and effects. They
-- roll from their own pool (Formulas.rollDragon), so byRarity holds only the regular ones above.
for _, d in require(script.Parent.FancyDragons) do
	d.fancy = true
	table.insert(Dragons.list, d)
end

-- The daily TOP EARNER prize: every theme in one dragon (fire, ice, lightning, stars, a crown, a halo, orbs, a
-- ring, crystal wings and a unicorn horn) in shifting rainbow colours. It never comes down the road.
Dragons.PRIZE = "OMNI"
table.insert(Dragons.list, {
	id = "OMNI",
	name = "Omni Prism",
	rarity = "Ultra",
	cps = 25000,
	price = 6000000,
	weight = 0,
	fancy = true,
	ultra = true,
	theme = "omni",
	body = rgb(255, 255, 255),
	belly = rgb(255, 240, 160),
	wing = rgb(140, 220, 255),
	accent = rgb(255, 120, 240),
	mat = "Glass",
	wingMat = "Neon",
	accentMat = "Neon",
	wings = "crystal",
	horns = "unicorn",
	eyes = rgb(255, 255, 255),
	extras = { "crown", "halo", "orbs", "ring", "mane", "tailflame", "backflame", "gem", "icicles" },
	fx = { "fire", "snow", "lightning", "stars", "aura", "glow", "rainbow", "pulse", "trail" },
})

Dragons.byId = {}
Dragons.byRarity = {}
Dragons.fancyByRarity = {}
for _, d in Dragons.list do
	Dragons.byId[d.id] = d
	local pool = d.fancy and Dragons.fancyByRarity or Dragons.byRarity
	pool[d.rarity] = pool[d.rarity] or {}
	table.insert(pool[d.rarity], d)
end

return Dragons
