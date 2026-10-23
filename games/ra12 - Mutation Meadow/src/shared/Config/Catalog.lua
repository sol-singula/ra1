--[[
Everything sold for Robux. Ids of 0 are not created yet. Rule: no paid key or name may contain golden, rainbow or
moon (the mutations and the event seed own those words).

  passes / products / cosmetics / gifts   [key] = { name, robux, id, ... }
  byProductId                             [id] = { group, key } for products and gifts with a real id
]]
-- TODO: create on Mason's account
local Catalog = {}

-- stylua: ignore start
Catalog.passes = {
	extraRow      = { name = "Extra Plot Row",     robux = 199, id = 0, tiles = 8 },
	vip           = { name = "VIP Gardener",       robux = 249, id = 0 },
	gnome         = { name = "Auto-Harvest Gnome", robux = 299, id = 0, radius = 12, everySec = 2 },
	doubleCash    = { name = "2x Sell Cash",       robux = 349, id = 0, mult = 2 },
	starterBundle = {
		name = "Starter Bundle",
		robux = 249,
		id = 0,
		grants = { "extraRow", "can_pumpkin", "tag_sprout" },
		valueRobux = 327,
		hideIfOwns = "extraRow",
		giftable = false,
		substitutes = { "tag_star", "trail_leaf", "can_crystal", "trail_firefly", "theme_cherry", "theme_candy", "theme_starry" },
	},
}

Catalog.extraRowCard = { robux = 199, showWhenPlotFull = true, minSessionSec = 600, closeHidesForSession = true }

Catalog.products = {
	instantGrow = { name = "Instant Grow", robux = 19, id = 0 },
	growAll     = { name = "Grow All",     robux = 99, id = 0 },
}

Catalog.cosmetics = {
	tag_sprout    = { name = "Sprout Buddy",         robux = 49,  id = 0, slot = "tag" },
	trail_leaf    = { name = "Leaf Swirl",           robux = 79,  id = 0, slot = "trail" },
	can_pumpkin   = { name = "Pumpkin Watering Can", robux = 79,  id = 0, slot = "can" },
	tag_star      = { name = "Star Farmer",          robux = 99,  id = 0, slot = "tag" },
	can_crystal   = { name = "Crystal Watering Can", robux = 99,  id = 0, slot = "can" },
	trail_firefly = { name = "Firefly Trail",        robux = 129, id = 0, slot = "trail" },
	theme_cherry  = { name = "Cherry Blossom Plot",  robux = 149, id = 0, slot = "theme" },
	theme_candy   = { name = "Candy Land Plot",      robux = 149, id = 0, slot = "theme" },
	theme_starry  = { name = "Starry Night Plot",    robux = 199, id = 0, slot = "theme" },
}
-- stylua: ignore end

-- A gift dev product for every pass but the bundle and for every cosmetic, same price, friends only.
-- Product names stay within Roblox's 50 characters. Gifting an item the friend already owns is hidden (Gifting.lua).
Catalog.gifts = {}
for _, group in { Catalog.passes, Catalog.cosmetics } do
	for key, item in group do
		if item.giftable ~= false then
			Catalog.gifts["gift_" .. key] = {
				name = "🎁 Gift " .. item.name,
				desc = `Buy {item.name} for a friend. They get it right away if they're online, or the next time they join.`,
				robux = item.robux,
				id = 0,
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
Catalog.privateServerRobux = 150
Catalog.subscriberPerk = "can_brass"

Catalog.byProductId = {}
for groupName, group in { products = Catalog.products, gifts = Catalog.gifts } do
	for key, item in group do
		if item.id ~= 0 then
			Catalog.byProductId[item.id] = { group = groupName, key = key }
		end
	end
end

return Catalog
