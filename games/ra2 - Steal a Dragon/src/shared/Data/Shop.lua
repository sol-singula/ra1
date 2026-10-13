-- Game passes and developer products.
-- Create each one on the Creator Dashboard (Monetization) and paste its ID here. While an ID is 0, buying it in
-- Studio grants it for free so you can test, and in a live game the button says "Soon".
local Shop = {}

Shop.Passes = {
	{
		key = "DOUBLE",
		name = "2x Coins",
		text = "All your dragons make 2x coins!",
		price = 129,
		id = 2026119064,
		icon = "💰",
	},
	{
		key = "VIP",
		name = "VIP",
		text = "+50% coins, Dragon Wings (fly!), longer lock, gold name.",
		price = 449,
		id = 2025453129,
		icon = "👑",
	},
	{
		key = "FAST",
		name = "Fast Feet",
		text = "Run 25% faster with a dragon.",
		price = 199,
		id = 2027091079,
		icon = "👟",
	},
	{
		key = "NESTS",
		name = "Extra Nests",
		text = "+4 nests for more dragons.",
		price = 249,
		id = 2026011065,
		icon = "🪺",
	},
	{
		key = "AUTO",
		name = "Auto Collect",
		text = "Coins go right to you.",
		price = 149,
		id = 2026125121,
		icon = "🧲",
	},
	{
		key = "LONGLOCK",
		name = "Long Lock",
		text = "Your door locks for 2 minutes.",
		price = 199,
		id = 2025645123,
		icon = "🔒",
	},
	{
		key = "MEGABONK",
		name = "Mega Bonk",
		text = "Swap the bat for a big hammer: bonked thieves are stuck longer.",
		price = 149,
		id = 2028350681,
		icon = "🔨",
	},
	{
		key = "WINGS",
		name = "Dragon Wings",
		text = "Wings in your hotbar: jump high and glide over the map!",
		price = 299,
		id = 2026479096,
		icon = "🪽",
		hidden = true, -- wings are part of VIP now
	},
}

-- Products can be bought again and again. Hidden ones are bought from the world (a dragon, the egg, a panel).
Shop.Products = {
	{
		key = "LUCK",
		name = "Server Luck",
		text = "15 min of rare dragons for EVERYONE here!",
		price = 99,
		id = 3718093772,
		icon = "🍀",
	},
	{
		key = "LOCKNOW",
		name = "Lock Now",
		text = "Lock your door from anywhere.",
		price = 19,
		id = 3718093778,
		icon = "🔐",
	},
	{
		key = "LOCK30",
		name = "30-Minute Lock",
		text = "Lock your door for 30 minutes!",
		price = 49,
		id = 3718093781,
		icon = "⏱️",
	},
	{
		key = "LEVELALL",
		name = "+5 Levels for ALL",
		text = "Every dragon in your nests gets 5 levels!",
		price = 99,
		id = 3718101840,
		icon = "⬆️",
	},
	{
		key = "POTIONS",
		name = "5 Speed Potions",
		text = "Drink one to run 50% faster for 30 seconds!",
		price = 29,
		id = 3718103709,
		icon = "🧪",
	},
	{
		key = "COINS_S",
		name = "Coin Bag",
		text = "10 minutes of coins (at least 1,000).",
		price = 49,
		id = 3718093782,
		icon = "🪙",
	},
	{
		key = "COINS_L",
		name = "Coin Chest",
		text = "2 hours of coins (at least 25,000).",
		price = 299,
		id = 3718093785,
		icon = "💎",
	},
	{ key = "DEAL", name = "Daily Deal", text = "Today's dragon, cheap!", price = 25, id = 3718093790, icon = "🎁" },
	{
		key = "GROW",
		name = "+10 Levels",
		text = "Level a dragon up 10 times.",
		price = 39,
		id = 3718093793,
		icon = "🌱",
		hidden = true,
	},
	{
		key = "HATCH",
		name = "Hatch Now",
		text = "Hatch your egg right now.",
		price = 49,
		id = 3718093797,
		icon = "🥚",
		hidden = true,
	},
	{
		key = "BUYNOW",
		name = "Buy Now",
		text = "Take this road dragon right now.",
		price = 199,
		id = 3718093801,
		icon = "⚡",
		hidden = true,
	},
	{
		key = "STARTER",
		name = "Starter Pack",
		text = "An Epic dragon, 5 speed potions and coins! One time only.",
		price = 49,
		id = 3718303202,
		icon = "🎒",
		hidden = true,
	},
	{
		key = "MYSTERY",
		name = "Mystery Box",
		text = "A random Legend or better dragon! Legend 85%, Secret 14%, Ultra 1%.",
		price = 99,
		id = 3718312731,
		icon = "🎁",
		hidden = true,
	},
	{
		key = "OFFLINE2X",
		name = "Double It",
		text = "Double your away coins.",
		price = 25,
		id = 3718093804,
		icon = "✖️",
		hidden = true,
	},
	-- Robux skins (Data/Skins.lua), bought from the Skins tab
	{
		key = "SKIN_LAVA",
		name = "Lava Skin",
		text = "Glowing lava wings for all your dragons.",
		price = 99,
		id = 3718093808,
		icon = "🌋",
		hidden = true,
	},
	{
		key = "SKIN_ROYAL",
		name = "Royal Gold Skin",
		text = "Shiny gold wings for all your dragons.",
		price = 149,
		id = 3718093811,
		icon = "👑",
		hidden = true,
	},
	{
		key = "SKIN_NEON",
		name = "Neon Skin",
		text = "Glowing cyan wings for all your dragons.",
		price = 199,
		id = 3718093814,
		icon = "⚡",
		hidden = true,
	},
}

Shop.passByKey, Shop.passById, Shop.productByKey, Shop.productById = {}, {}, {}, {}
for _, p in Shop.Passes do
	Shop.passByKey[p.key] = p
	if p.id ~= 0 then
		Shop.passById[p.id] = p
	end
end
for _, p in Shop.Products do
	Shop.productByKey[p.key] = p
	if p.id ~= 0 then
		Shop.productById[p.id] = p
	end
end

return Shop
