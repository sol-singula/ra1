-- Game passes and developer products. IDs are 0 until a setup run creates them; with an ID of 0 the item is
-- granted for free in Studio so everything can be tested. Nothing here makes a rifle shoot better.
local Shop = {}

Shop.Passes = {
	{ key = "VIP", name = "VIP", price = 399, id = 2032340276, desc = "+20% coins, gold name, VIP podium pose" },
	{ key = "COINS2", name = "2x Coins", price = 299, id = 2033060264, desc = "Double coins from every pop" },
	{
		key = "LOADOUT",
		name = "Extra Loadout",
		price = 199,
		id = 2033348269,
		desc = "Swap between 2 rifles in a round",
	},
}

Shop.Products = {
	{ key = "KEYS_1", name = "1 Crate Key", price = 49, id = 3718282363, keys = 1, desc = "1 key to open a Key Crate" },
	{
		key = "KEYS_5",
		name = "5 Crate Keys",
		price = 199,
		id = 3718282366,
		keys = 5,
		desc = "5 keys to open Key Crates",
	},
	{
		key = "KEYS_15",
		name = "15 Crate Keys",
		price = 499,
		id = 3718282370,
		keys = 15,
		desc = "15 keys to open Key Crates",
	},
	{
		key = "CALLOUT",
		name = "Round Callout",
		price = 99,
		id = 3718282374,
		desc = "Your name in gold when the next round starts",
	},
	{
		key = "SEASON",
		name = "Season Pass",
		price = 399,
		id = 3718282377,
		desc = "This season's pass rewards (2 weeks)",
	},
	{ key = "REVIVE", name = "Revive Now", price = 9, id = 3718282382, desc = "Skip the respawn wait, once" },
}

Shop.passById, Shop.productById = {}, {}
Shop.byKey = {}
for _, p in Shop.Passes do
	Shop.passById[p.id] = p
	Shop.byKey[p.key] = p
end
for _, p in Shop.Products do
	Shop.productById[p.id] = p
	Shop.byKey[p.key] = p
end

return Shop
