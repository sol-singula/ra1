--[[
Robux (master plan §11): the game is complete without spending. Four kinds: temporary boosts (shared by the whole
server, lit from the town's meter), convenience, cosmetics and cash. Ids live in Constants (0 = not made yet:
free in Studio, "coming soon" live).

  Shop.BOOSTS[key]    { name, desc, robux, effect, seconds } the shared boosts (also lit with Cash from the meter)
  Shop.PRODUCTS[key]  one-off purchases (cash packs)
  Shop.PASSES[key]    game passes
]]
local Shop = {}

Shop.BOOSTS = {
	harvestRush = {
		name = "Harvest Rush",
		desc = "Machines clear twice as fast for 10 minutes, for everyone.",
		robux = 39,
		icon = "🚜",
		color = Color3.fromRGB(86, 192, 96),
	},
	customerRush = {
		name = "Customer Rush",
		desc = "Twice the customers for 10 minutes, for everyone.",
		robux = 49,
		icon = "🛒",
		color = Color3.fromRGB(60, 150, 240),
	},
	goldenMarket = {
		name = "Golden Market",
		desc = "Every sale pays 50% more for 10 minutes, for everyone.",
		robux = 79,
		icon = "✨",
		color = Color3.fromRGB(255, 198, 40),
	},
}
Shop.BOOST_LIST = { "harvestRush", "customerRush", "goldenMarket" }

Shop.PRODUCTS = {
	cashSmall = {
		name = "Cash Crate",
		desc = "30 minutes of your income, right now.",
		robux = 99,
		minutes = 30,
		icon = "💵",
	},
	cashBig = {
		name = "Cash Vault",
		desc = "3 hours of your income, right now.",
		robux = 399,
		minutes = 180,
		icon = "💰",
	},
}
Shop.PRODUCT_LIST = { "cashSmall", "cashBig" }

Shop.PASSES = {
	nightShift = {
		name = "Night Shift",
		desc = "Your farm works 8 hours while you're away (not 4).",
		robux = 199,
		icon = "🌙",
	},
	fastMachines = {
		name = "Turbo Machines",
		desc = "Every harvester, forklift and truck runs 25% faster.",
		robux = 149,
		icon = "⚡",
	},
	tractorPaint = {
		name = "Paint Shop",
		desc = "Pick a colour for your machines and trucks.",
		robux = 99,
		icon = "🎨",
	},
	premiumBundle = {
		name = "Premium Bundle",
		desc = "Every cosmetic: a stone farmhouse, gold fences, truck liveries.",
		robux = 399,
		icon = "👑",
	},
}
Shop.PASS_LIST = { "nightShift", "fastMachines", "tractorPaint", "premiumBundle" }

return Shop
