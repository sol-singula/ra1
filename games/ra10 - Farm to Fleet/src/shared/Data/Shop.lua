--[[
The shop (master plan §14 I): Robux for Gems, the Starter Pack, Instant Harvest and four game passes; Gems for
skips and boosts. Nothing is pay-to-win against other players: everything speeds up your own farm.

Robux (ids in Constants.PRODUCTS / Constants.PASSES; an id still 0 is free in Studio and "coming soon" live):
  products   gems100 / gems550 / gems1200 (Gem packs), starter (once: Gems, golden seeds and Cash for your level),
             skipGrow (Instant Harvest: everything planted is ripe now)
  passes     doubleCash (x2 everything shipped), longNap (12 h away instead of 4), extraOrder (one more order on the
             board), vip (+10% on everything shipped, +10 Gems with each day's calendar reward, a VIP tag)

Gems (Net "Shop" "gems", key):
  ripen      every crop ripe now
  feed       every animal fed (a full boost) now
  seeds      ten golden seeds
  boost      x2 everything shipped for BOOST_SECONDS (stacks up to BOOST_MAX)
  special    a Special Order now (once the packing shed stands)

  Shop.PRODUCTS[key] / Shop.PASSES[key] / Shop.GEMS[key]   { key, name, text, robux | gems, ... }
  Shop.cashMult(profile, t)   the passes and the boost on everything shipped
  Shop.starter(level)         what the Starter Pack gives
]]
local Shop = {}

Shop.BOOST_SECONDS = 15 * 60
Shop.BOOST_MAX = 2 * 3600

-- stylua: ignore start
Shop.PRODUCT_ORDER = { "starter", "gems100", "gems550", "gems1200", "skipGrow" }
Shop.PRODUCTS = {
	starter  = { key = "starter",  name = "Starter Pack",   robux = 99,  text = "150 Gems, 10 golden seeds and a pile of Cash. Once only!", once = true },
	gems100  = { key = "gems100",  name = "Bag of Gems",    robux = 49,  text = "100 Gems", gems = 100 },
	gems550  = { key = "gems550",  name = "Chest of Gems",  robux = 199, text = "550 Gems (10% extra)", gems = 550 },
	gems1200 = { key = "gems1200", name = "Vault of Gems",  robux = 399, text = "1200 Gems (20% extra)", gems = 1200 },
	skipGrow = { key = "skipGrow", name = "Instant Harvest", robux = 25, text = "Every crop on your farm ripe, right now" },
}
Shop.PASS_ORDER = { "doubleCash", "vip", "extraOrder", "longNap" }
Shop.PASSES = {
	doubleCash = { key = "doubleCash", name = "2x Cash",      robux = 299, text = "Double Cash for everything you ship. Forever." },
	vip        = { key = "vip",        name = "VIP Farmer",   robux = 399, text = "+10% on everything, +10 Gems a day, a VIP tag" },
	extraOrder = { key = "extraOrder", name = "Extra Order",  robux = 199, text = "One more order on your board" },
	longNap    = { key = "longNap",    name = "Long Nap",     robux = 149, text = "Your farm earns for 12 h while you're away (not 4)" },
}
Shop.GEM_ORDER = { "ripen", "feed", "seeds", "boost", "special" }
Shop.GEMS = {
	ripen   = { key = "ripen",   name = "Ripen Everything", gems = 5,  text = "Every crop ripe now" },
	feed    = { key = "feed",    name = "Feed Everyone",    gems = 5,  text = "Every animal fed: a full boost" },
	seeds   = { key = "seeds",   name = "Golden Seeds x10", gems = 25, text = "The next 10 plantings come up golden" },
	boost   = { key = "boost",   name = "Cash Rush",        gems = 40, text = "x2 everything shipped for 15 minutes" },
	special = { key = "special", name = "Special Order",    gems = 30, text = "Call a Special Order now (needs the shed)" },
}
-- stylua: ignore end

function Shop.starter(level)
	return { gems = 150, seeds = 10, cash = 2000 * math.max(1, level or 1) }
end

function Shop.cashMult(p, t)
	local passes = p.passes or {}
	local m = 1
	if passes.doubleCash then
		m *= 2
	end
	if passes.vip then
		m *= 1.1
	end
	if (p.boostUntil or 0) > (t or os.time()) then
		m *= 2
	end
	return m
end

return Shop
