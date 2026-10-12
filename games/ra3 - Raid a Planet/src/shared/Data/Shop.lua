-- Game passes and developer products. IDs are 0 until tools/setup_shop.py creates them; with an ID of 0 the
-- item is granted for free in Studio so everything can be tested.
local Shop = {}

Shop.Passes = {
	{ key = "AUTO", name = "Auto Blast", price = 249, id = 0, desc = "Fires at the nearest bug by itself" },
	{ key = "TRIPLE", name = "Triple Forge", price = 449, id = 0, desc = "3 blasters cooking at once" },
	{ key = "GEMS2", name = "2x Gems", price = 299, id = 0, desc = "Double gems from raids and quests" },
	{ key = "VIP", name = "VIP", price = 449, id = 0, desc = "+25% damage, gold name" },
	{
		key = "BOOTHRANK",
		name = "Booth Rank",
		price = 199,
		id = 0,
		desc = "Your booth goes to the front of the street",
	},
	{ key = "PETSLOT", name = "Pet Slot +1", price = 199, id = 0, desc = "Two pets out at once" },
}

Shop.Products = {
	{ key = "LUCK", name = "Luck Elixir", price = 49, id = 0, desc = "15 min of better rolls" },
	{ key = "CALLOUT", name = "Raid Callout", price = 149, id = 0, desc = "Your name in gold when the raid starts" },
	{ key = "GEMS_S", name = "Gems x50", price = 99, id = 0, gems = 50 },
	{ key = "GEMS_M", name = "Gems x300", price = 499, id = 0, gems = 300 },
	{ key = "GEMS_L", name = "Gems x1500", price = 1999, id = 0, gems = 1500 },
}
-- Finish Forge Now: one product per price step (Roblox products have fixed prices)
Shop.FinishNow = {}
for _, price in { 9, 19, 29, 49, 79, 99, 149 } do
	table.insert(Shop.FinishNow, { key = "FINISH_" .. price, name = "Finish Forge Now", price = price, id = 0 })
end

Shop.passById, Shop.productById = {}, {}
Shop.byKey = {}
for _, p in Shop.Passes do
	Shop.passById[p.id] = p
	Shop.byKey[p.key] = p
end
for _, list in { Shop.Products, Shop.FinishNow } do
	for _, p in list do
		Shop.productById[p.id] = p
		Shop.byKey[p.key] = p
	end
end

return Shop
