--[[
Everything sold for Robux, with the Creator Hub ids (a 0 would mean not created yet). Rule: no paid key or name may contain golden, rainbow or
moon (the mutations and the event seed own those words).

  passes / products / cosmetics / gifts   [key] = { name, robux, id, ... }
  byProductId                             [id] = { group, key } for products and gifts with a real id
]]
local Catalog = {}

-- stylua: ignore start
Catalog.passes = {
	extraRow      = { name = "Extra Plot Row",     robux = 199, id = 2052953294, tiles = 8 },
	vip           = { name = "VIP Gardener",       robux = 249, id = 2053169320 },
	gnome         = { name = "Auto-Harvest Gnome", robux = 299, id = 2052035337, radius = 12, everySec = 2 },
	doubleCash    = { name = "2x Sell Cash",       robux = 349, id = 2053025309, mult = 2 },
	starterBundle = {
		name = "Starter Bundle",
		robux = 249,
		id = 2052647253,
		grants = { "extraRow", "can_pumpkin", "tag_sprout" },
		valueRobux = 327,
		hideIfOwns = "extraRow",
		giftable = false,
		substitutes = { "tag_star", "trail_leaf", "can_crystal", "trail_firefly", "theme_cherry", "theme_candy", "theme_starry" },
	},
}

Catalog.extraRowCard = { robux = 199, showWhenPlotFull = true, minSessionSec = 600, closeHidesForSession = true }

Catalog.products = {
	instantGrow = { name = "Instant Grow", robux = 19, id = 3721780958 },
	growAll     = { name = "Grow All",     robux = 99, id = 3721780982 },
}

Catalog.cosmetics = {
	tag_sprout    = { name = "Sprout Buddy",         robux = 49,  id = 3721780987, slot = "tag" },
	trail_leaf    = { name = "Leaf Swirl",           robux = 79,  id = 3721781001, slot = "trail" },
	can_pumpkin   = { name = "Pumpkin Watering Can", robux = 79,  id = 3721780992, slot = "can" },
	tag_star      = { name = "Star Farmer",          robux = 99,  id = 3721781032, slot = "tag" },
	can_crystal   = { name = "Crystal Watering Can", robux = 99,  id = 3721781023, slot = "can" },
	trail_firefly = { name = "Firefly Trail",        robux = 129, id = 3721781036, slot = "trail" },
	theme_cherry  = { name = "Cherry Blossom Plot",  robux = 149, id = 3721781049, slot = "theme" },
	theme_candy   = { name = "Candy Land Plot",      robux = 149, id = 3721781043, slot = "theme" },
	theme_starry  = { name = "Starry Night Plot",    robux = 199, id = 3721781052, slot = "theme" },
}
-- stylua: ignore end

-- A gift dev product for every pass but the bundle and for every cosmetic, same price, friends only.
-- Product names stay within Roblox's 50 characters. Gifting an item the friend already owns is hidden (Gifting.lua).
local GIFT_IDS = {
	gift_tag_sprout = 3721781069,
	gift_can_pumpkin = 3721781074,
	gift_trail_leaf = 3721781076,
	gift_can_crystal = 3721781079,
	gift_tag_star = 3721781084,
	gift_trail_firefly = 3721781088,
	gift_theme_candy = 3721781093,
	gift_theme_cherry = 3721781118,
	gift_extraRow = 3721781120,
	gift_theme_starry = 3721781130,
	gift_vip = 3721781136,
	gift_gnome = 3721781138,
	gift_doubleCash = 3721781145,
}
Catalog.gifts = {}
for _, group in { Catalog.passes, Catalog.cosmetics } do
	for key, item in group do
		if item.giftable ~= false then
			Catalog.gifts["gift_" .. key] = {
				name = "🎁 Gift " .. item.name,
				desc = `Buy {item.name} for a friend. They get it right away if they're online, or the next time they join.`,
				robux = item.robux,
				id = GIFT_IDS["gift_" .. key] or 0,
				of = key,
				friendsOnly = true,
			}
		end
	end
end

-- The receiver's toast (wired in M9): string.format(giftToast, giverName, itemName), with a button that opens the
-- Gift tab on the giver
Catalog.giftToast = "🎁 %s sent you %s!"
Catalog.giftBackButton = "Gift back"

Catalog.earnedCosmetics = { "trail_petals", "tag_collector", "deco_lantern", "title_master", "tag_weekly_top100" }
Catalog.vipPerks = { "tag_vip", "border_vip", "trail_vip_sparkle" }
Catalog.privateServerRobux = 99
Catalog.subscriberPerk = "can_brass"

-- the Starter Bundle's share of Robux revenue (BundleReview, docs/analytics.md). From launch day startDay, over the
-- last windowDays days: above highShare, review the repeat offers (not the bundle); below lowShare, check that
-- players see the bundle at all.
Catalog.bundleReview = {
	startDay = 14,
	windowDays = 7,
	highShare = 0.50,
	lowShare = 0.10,
	repeatOffers = { "instantGrow", "growAll", "cosmetics", "gifts" },
}

Catalog.byProductId = {}
for groupName, group in { products = Catalog.products, gifts = Catalog.gifts } do
	for key, item in group do
		if item.id ~= 0 then
			Catalog.byProductId[item.id] = { group = groupName, key = key }
		end
	end
end

return Catalog
