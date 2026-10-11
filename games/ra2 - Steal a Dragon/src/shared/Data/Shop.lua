-- Game passes and developer products.
-- Create each one on the Creator Dashboard (Monetization) and paste its ID here. While an ID is 0, buying it in
-- Studio grants it for free so you can test, and in a live game the button says "Soon".
local Shop = {}

Shop.Passes = {
	{ key = "DOUBLE", name = "2x Coins", text = "All your dragons make 2x coins!", price = 129, id = 0, icon = "💰" },
	{ key = "VIP", name = "VIP", text = "+50% coins, longer lock, gold name.", price = 449, id = 0, icon = "👑" },
	{ key = "FAST", name = "Fast Feet", text = "Run 25% faster with a dragon.", price = 199, id = 0, icon = "👟" },
	{ key = "NESTS", name = "Extra Nests", text = "+4 nests for more dragons.", price = 249, id = 0, icon = "🪺" },
	{ key = "AUTO", name = "Auto Collect", text = "Coins go right to you.", price = 149, id = 0, icon = "🧲" },
	{
		key = "LONGLOCK",
		name = "Long Lock",
		text = "Your door locks for 2 minutes.",
		price = 199,
		id = 0,
		icon = "🔒",
	},
	{
		key = "MEGABONK",
		name = "Mega Bonk",
		text = "Bonked thieves are stuck longer.",
		price = 149,
		id = 0,
		icon = "🔨",
	},
}

-- Products can be bought again and again. Hidden ones are bought from the world (a dragon, the egg, a panel).
Shop.Products = {
	{
		key = "LUCK",
		name = "Server Luck",
		text = "15 min of rare dragons for EVERYONE here!",
		price = 99,
		id = 0,
		icon = "🍀",
	},
	{ key = "LOCKNOW", name = "Lock Now", text = "Lock your door from anywhere.", price = 19, id = 0, icon = "🔐" },
	{
		key = "COINS_S",
		name = "Coin Bag",
		text = "10 minutes of coins (at least 1,000).",
		price = 49,
		id = 0,
		icon = "🪙",
	},
	{
		key = "COINS_L",
		name = "Coin Chest",
		text = "2 hours of coins (at least 25,000).",
		price = 299,
		id = 0,
		icon = "💎",
	},
	{ key = "DEAL", name = "Daily Deal", text = "Today's dragon, cheap!", price = 25, id = 0, icon = "🎁" },
	{
		key = "GROW",
		name = "Grow Now",
		text = "Grow a dragon one size.",
		price = 39,
		id = 0,
		icon = "🌱",
		hidden = true,
	},
	{
		key = "HATCH",
		name = "Hatch Now",
		text = "Hatch your egg right now.",
		price = 49,
		id = 0,
		icon = "🥚",
		hidden = true,
	},
	{
		key = "BUYNOW",
		name = "Buy Now",
		text = "Take this road dragon right now.",
		price = 199,
		id = 0,
		icon = "⚡",
		hidden = true,
	},
	{
		key = "OFFLINE2X",
		name = "Double It",
		text = "Double your away coins.",
		price = 25,
		id = 0,
		icon = "✖️",
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
