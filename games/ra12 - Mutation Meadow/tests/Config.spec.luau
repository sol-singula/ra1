local Assert = require("./mock/Assert")
local Engine = require("./mock/Engine")

local engine = Engine.new()
local Config = engine:require(engine:module("Shared/Config"))
local test, eq = Assert.test, Assert.eq

local TIER_ORDER =
	{ "carrot", "strawberry", "blueberry", "tomato", "corn", "pumpkin", "watermelon", "dragonfruit", "moonmelon" }

test("has every table", function()
	for _, name in
		{
			"Seeds",
			"Start",
			"Restock",
			"BlockParty",
			"Weather",
			"Mutations",
			"Upgrades",
			"Inventory",
			"Collection",
			"Daily",
			"Quests",
			"Playtime",
			"Social",
			"Weekly",
			"Leaderboard",
			"Badges",
			"Catalog",
			"Patch",
			"Save",
			"Net",
			"Capture",
			"CropVisuals",
		}
	do
		Assert.truthy(type(Config[name]) == "table", `Config.{name}`)
	end
	Assert.truthy(type(Config.AdminUserIds) == "table", "AdminUserIds (its values: tests/Release.spec.luau)")
end)

test("is deep-frozen", function()
	Assert.truthy(table.isfrozen(Config), "Config")
	Assert.truthy(table.isfrozen(Config.Seeds.carrot), "Seeds.carrot")
	Assert.truthy(table.isfrozen(Config.Catalog.passes.starterBundle.substitutes), "substitutes")
	Assert.throws(function()
		(Config :: any).Seeds.carrot.buy = 1
	end)
end)

test("seeds: the nine in tier order with the design numbers", function()
	-- stylua: ignore start
	local rows = {
		{ "carrot",      "Carrot",       1, 5,      30,    10,    1 },
		{ "strawberry",  "Strawberry",   2, 25,     45,    14,    5 },
		{ "blueberry",   "Blueberry",    3, 80,     90,    36,    5 },
		{ "tomato",      "Tomato",       4, 300,    180,   110,   5 },
		{ "corn",        "Corn",         5, 1000,   360,   330,   5 },
		{ "pumpkin",     "Pumpkin",      6, 4000,   720,   4350,  1 },
		{ "watermelon",  "Watermelon",   7, 12000,  1800,  3250,  6 },
		{ "dragonfruit", "Dragon Fruit", 8, 50000,  3600,  9750,  8 },
		{ "moonmelon",   "Moon Melon",   9, 200000, 10800, 35000, 10 },
	}
	-- stylua: ignore end
	local count = 0
	for _ in Config.Seeds do
		count += 1
	end
	eq(count, 9, "seed count")
	local sorted = {}
	for key, s in Config.Seeds do
		table.insert(sorted, { key = key, tier = s.tier })
	end
	table.sort(sorted, function(a, b)
		return a.tier < b.tier
	end)
	for i, r in rows do
		local s = Config.Seeds[r[1]]
		eq(sorted[i].key, r[1], "tier order")
		eq({ s.key, s.name, s.tier, s.buy, s.growSec, s.sell, s.harvests }, r, r[1])
	end
	eq(Config.Seeds.carrot.gate, { start = true })
	eq(Config.Seeds.strawberry.gate, { start = true })
	eq(Config.Seeds.blueberry.gate, { lifetimeCoins = 300 })
	eq(Config.Seeds.tomato.gate, { plotLevel = 2 })
	eq(Config.Seeds.corn.gate, { plotLevel = 2 })
	eq(Config.Seeds.pumpkin.gate, { plotLevel = 3 })
	eq(Config.Seeds.watermelon.gate, { plotLevel = 3 })
	eq(Config.Seeds.dragonfruit.gate, { plotLevel = 4 })
	eq(Config.Seeds.moonmelon.gate, { plotLevel = 4, eventOnly = true })
end)

test("start and restock", function()
	eq(Config.Start, { coins = 50, seeds = { carrot = 3 } })
	eq(Config.Restock.intervalSec, 300)
	eq(Config.Restock.order, TIER_ORDER)
	eq(Config.Restock.stock, {
		carrot = { chance = 1, qty = 20 },
		strawberry = { chance = 1, qty = 15 },
		blueberry = { chance = 0.8, qty = 8 },
		tomato = { chance = 0.6, qty = 6 },
		corn = { chance = 0.4, qty = 5 },
		pumpkin = { chance = 0.2, qty = 3 },
		watermelon = { chance = 0.1, qty = 2 },
		dragonfruit = { chance = 0.04, qty = 1 },
		moonmelon = { chance = 0.05, qty = 1, eventOnly = true },
	})
end)

test("block party, weather, mutations", function()
	eq(Config.BlockParty, {
		windowSec = 600,
		goalPerPlayer = 10,
		goalMin = 20,
		waterEverySec = 2,
		rangeStuds = 15,
		stages = { perking = 0.33, standing = 0.66, bloom = 1.0 },
		wiltSec = 60,
		reward = { minWaters = 5, coinsPerLevelSq = 100 },
		privateServer = { goalMin = 2, goalPerPlayer = 1, minWaters = 1 },
		sunflowerFriendAt = 10,
	})
	eq(Config.Weather, {
		durationSec = 300,
		pick = { rain = 0.8, goldenHour = 0.2 },
		rainGrowthMult = 1.5,
		welcomeShower = {
			atSessionSec = 240,
			deferIfWeatherSec = 10,
			durationSec = 60,
			ownPlotOnly = true,
			guaranteeWet = 1,
			guaranteeWetAtSec = 10,
			calendarAfterShowerSec = 150,
		},
	})
	eq(Config.Mutations, {
		wet = { mult = 2, chance = { rain = 0.25, welcomeShower = 0.25 } },
		golden = { mult = 20, chance = { goldenHour = 0.08 } },
		stackMult = 40,
	})
end)

test("upgrades, inventory, collection", function()
	eq(Config.Upgrades, {
		plotCost = { 0, 100, 4000, 50000, 500000 },
		plotSize = { { 3, 4 }, { 4, 5 }, { 5, 6 }, { 6, 8 }, { 8, 8 } },
		cans = {
			tin = { cost = 0, growSpeedBonus = 0.05 },
			copper = { cost = 1000, growSpeedBonus = 0.10 },
			silver = { cost = 12000, growSpeedBonus = 0.15 },
		},
		canOrder = { "tin", "copper", "silver" },
		sprinklers = {
			basic = { cost = 1500, growthMult = 1.25 },
			advanced = { cost = 15000, growthMult = 1.5 },
			area = 3,
			maxEach = 4,
		},
		offlineCapSec = 28800,
		welcomeBackSec = 1800,
		growTickSec = 1,
	})
	eq(Config.Inventory, {
		backpackByPlotLevel = { 60, 60, 90, 90, 120 },
		basketCap = 200,
		pedestalsByPlotLevel = { 2, 3, 4, 5, 6 },
		collectionPedestalAt = 18,
		pedestalMax = 7,
		itemGiftsPerDay = 20,
		autoSellPlotLevel = 2,
	})
	eq(Config.Collection, {
		firstFind = { wet = 100, golden = 1000, wetgolden = 5000 },
		milestones = { [5] = "tag_collector", [10] = "deco_lantern", [18] = "pedestal_plus1", [27] = "title_master" },
	})
end)

test("daily, quests, playtime", function()
	eq(Config.Daily, {
		resetUtcHour = 0,
		missedDay = "pause",
		days = {
			{ coins = 100 },
			{ seeds = { pumpkin = 1 } },
			{ coins = 500 },
			{ seeds = { corn = 3 } },
			{ coins = 1500 },
			{ seeds = { watermelon = 2 } },
			{ seeds = { pumpkin = 5 }, firstCycle = "trail_petals", repeatCoins = 2500 },
		},
	})
	eq(Config.Quests, {
		starter = {
			{ key = "harvest5", n = 5, reward = { coins = 50 } },
			{ key = "plot2", n = 2, reward = { coins = 100 } },
			{ key = "keepMut", n = 1, reward = { seeds = { tomato = 2 } } },
			{ key = "pedestal", n = 1, reward = { coins = 300 } },
			{ key = "help1", n = 1, reward = { coins = 75 } },
		},
		daily = { { key = "harvest30", n = 30 }, { key = "help3", n = 3 }, { key = "sunflower5", n = 5 } },
		dailyCoinsPerLevelSq = 300,
	})
	eq(Config.Playtime, {
		{ atSec = 300, coinsPerLevelSq = 100 },
		{ atSec = 600, topTierSeeds = 2 },
		{ atSec = 1200, coinsPerLevelSq = 300, topTierSeeds = 1 },
	})
end)

test("social, weekly, leaderboard", function()
	eq(Config.Social, {
		helpCut = 0.10,
		helpCoinsPerLevel = 25,
		helpsPerDay = 20,
		helpSameCropSec = 600,
		friendBoostEach = 0.10,
		friendBoostMax = 0.30,
		likesPerFarmPerDay = 1,
		itemGiftsPerDay = 20,
		giftOfferSec = 30,
		visitOffsetStuds = 6,
		visitStreamSec = 2,
		gardenNameFallback = "%s's Garden",
	})
	eq(
		Config.Lounge,
		{ deck = { x = 40, z = 30 }, centre = { x = 0, z = -60 }, pushStuds = 6, checkSec = 1, ceilingStuds = 20 }
	)
	eq(Config.Weekly, {
		dayOfWeek = 7,
		mountainHour = 10,
		utcHourDst = 16,
		utcHourStd = 17,
		gift = { coinsPerLevelSq = 1000, topTierSeeds = 3 },
		eventWeekMaxDay = 7,
	})
	eq(Config.Leaderboard, {
		serverRefreshSec = 10,
		globalWriteSec = 120,
		globalReadSec = 300,
		globalTop = 100,
		storePrefix = "MM_Top_",
		prize = "tag_weekly_top100",
	})
end)

test("badges: renamed copy", function()
	local B = Config.Badges
	eq({ B.first_golden.name, B.first_golden.desc }, { "Struck Gold!", "Keep your first Golden crop, worth 20x." })
	eq({ B.first_wetgolden.name, B.first_wetgolden.desc }, { "40x Legend", "Keep a Wet + Golden crop, worth 40x." })
	eq({ B.week_of_sprouts.name, B.week_of_sprouts.desc }, { "7-Day Gardener", "Claim 7 days on the daily calendar." })
	eq({ B.full_meadow.name, B.full_meadow.desc }, { "Full Meadow", "Upgrade your meadow plot to level 5." })
	eq(
		{ B.sunflower_friend.name, B.sunflower_friend.desc },
		{ "Sunflower Friend", "Help the Block Party sunflower bloom 10 times." }
	)
	eq(Config.BlockParty.sunflowerFriendAt, 10)
	eq(#Config.Upgrades.plotCost, 5, "level 5 is the top plot level")
end)

test("badges: the ten (their ids: tests/Release.spec.luau)", function()
	local keys = {}
	for key, b in Config.Badges do
		table.insert(keys, key)
		Assert.truthy(type(b.name) == "string" and #b.name > 0, key .. " name")
		Assert.truthy(type(b.id) == "number", key .. " id")
	end
	table.sort(keys)
	eq(keys, {
		"first_golden",
		"first_harvest",
		"first_splash",
		"first_wetgolden",
		"full_meadow",
		"master_gardener",
		"moonstruck",
		"sunflower_friend",
		"week_of_sprouts",
		"welcome",
	})
end)

test("catalog: prices, fields and gifts", function()
	local C = Config.Catalog
	local function row(t)
		return { t.name, t.robux, t.id }
	end
	eq(row(C.passes.extraRow), { "Extra Plot Row", 199, 2052953294 })
	eq(C.passes.extraRow.tiles, 8)
	eq(row(C.passes.vip), { "VIP Gardener", 249, 2053169320 })
	eq(row(C.passes.gnome), { "Auto-Harvest Gnome", 299, 2052035337 })
	eq({ C.passes.gnome.radius, C.passes.gnome.everySec }, { 12, 2 })
	eq(row(C.passes.doubleCash), { "2x Sell Cash", 349, 2053025309 })
	local b = C.passes.starterBundle
	eq(row(b), { "Starter Bundle", 249, 2052647253 })
	eq(b.grants, { "extraRow", "can_pumpkin", "tag_sprout" })
	eq({ b.valueRobux, b.hideIfOwns, b.giftable }, { 327, "extraRow", false })
	eq(
		b.substitutes,
		{ "tag_star", "trail_leaf", "can_crystal", "trail_firefly", "theme_cherry", "theme_candy", "theme_starry" }
	)
	eq(C.extraRowCard, { robux = 199, showWhenPlotFull = true, minSessionSec = 600, closeHidesForSession = true })
	eq(row(C.products.instantGrow), { "Instant Grow", 19, 3721780958 })
	eq(row(C.products.growAll), { "Grow All", 99, 3721780982 })
	-- stylua: ignore start
	local cosmetics = {
		tag_sprout    = { "Sprout Buddy",         49,  "tag",   3721780987 },
		trail_leaf    = { "Leaf Swirl",           79,  "trail", 3721781001 },
		can_pumpkin   = { "Pumpkin Watering Can", 79,  "can",   3721780992 },
		tag_star      = { "Star Farmer",          99,  "tag",   3721781032 },
		can_crystal   = { "Crystal Watering Can", 99,  "can",   3721781023 },
		trail_firefly = { "Firefly Trail",        129, "trail", 3721781036 },
		theme_cherry  = { "Cherry Blossom Plot",  149, "theme", 3721781049 },
		theme_candy   = { "Candy Land Plot",      149, "theme", 3721781043 },
		theme_starry  = { "Starry Night Plot",    199, "theme", 3721781052 },
	}
	-- stylua: ignore end
	local n = 0
	for key, want in cosmetics do
		local c = C.cosmetics[key]
		eq({ c.name, c.robux, c.slot, c.id }, want, key)
		n += 1
	end
	for _ in C.cosmetics do
		n -= 1
	end
	eq(n, 0, "cosmetic count")
	-- gifts: 4 passes (not the bundle) + 9 cosmetics, same price, friends only
	local gifts = 0
	for key, g in C.gifts do
		gifts += 1
		local of = C.passes[g.of] or C.cosmetics[g.of]
		Assert.truthy(of, key .. " gifts a real item")
		eq(key, "gift_" .. g.of)
		eq(g.robux, of.robux, key .. " price")
		eq(g.friendsOnly, true)
	end
	eq(gifts, 13, "gift count")
	-- stylua: ignore start
	local giftIds = {}
	for key, g in C.gifts do
		giftIds[key] = g.id
	end
	eq(giftIds, {
		gift_tag_sprout = 3721781069, gift_can_pumpkin = 3721781074, gift_trail_leaf = 3721781076,
		gift_can_crystal = 3721781079, gift_tag_star = 3721781084, gift_trail_firefly = 3721781088,
		gift_theme_candy = 3721781093, gift_theme_cherry = 3721781118, gift_extraRow = 3721781120,
		gift_theme_starry = 3721781130, gift_vip = 3721781136, gift_gnome = 3721781138,
		gift_doubleCash = 3721781145,
	})
	-- stylua: ignore end
	for key, g in C.gifts do
		eq(C.byProductId[g.id], { group = "gifts", key = key }, key .. " by product id")
	end
	eq(C.byProductId[3721780958], { group = "products", key = "instantGrow" })
	for key, g in C.gifts do
		local of = C.passes[g.of] or C.cosmetics[g.of]
		eq(g.name, "🎁 Gift " .. of.name, key .. " name")
		Assert.truthy(utf8.len(g.name) <= 50, `{key} name is {utf8.len(g.name)} chars`)
		eq(
			g.desc,
			`Buy {of.name} for a friend. They get it right away if they're online, or the next time they join.`,
			key .. " desc"
		)
	end
	eq(string.format(C.giftToast, "Mason", "Leaf Swirl"), "🎁 Mason sent you Leaf Swirl!")
	eq(C.giftBackButton, "Gift back")
	Assert.truthy(C.gifts.gift_starterBundle == nil, "bundle is not giftable")
	eq(C.earnedCosmetics, { "trail_petals", "tag_collector", "deco_lantern", "title_master", "tag_weekly_top100" })
	eq(C.vipPerks, { "tag_vip", "border_vip", "trail_vip_sparkle" })
	eq({ C.privateServerRobux, C.subscriberPerk }, { 99, "can_brass" })
end)

test("catalog: names, banned words, byProductId", function()
	local C = Config.Catalog
	for groupName, group in { passes = C.passes, products = C.products, cosmetics = C.cosmetics, gifts = C.gifts } do
		for key, item in group do
			Assert.truthy(type(item.name) == "string" and #item.name > 0, `{groupName}.{key} name`)
			for _, word in { "golden", "rainbow", "moon" } do
				Assert.truthy(not key:lower():find(word), `{groupName}.{key} key contains {word}`)
				Assert.truthy(not item.name:lower():find(word), `{groupName}.{key} name contains {word}`)
			end
		end
	end
	for id in C.byProductId do
		Assert.truthy(id ~= 0, "byProductId has a 0 key")
	end
end)

test("patch", function()
	local P = Config.Patch
	eq(P.order, { "plant", "shopHello", "shopAgain", "restock", "rare", "shower", "mutation", "blockParty", "update" })
	eq(P.lines.plant, { text = "Plant here!", kind = "bubble", seconds = 5, flag = true, hideOn = "plant" })
	eq(
		P.lines.shopHello,
		{ text = "Hi, I'm Patch! New seeds every 5 minutes.", kind = "shopBubble", seconds = 5, flag = true }
	)
	eq(P.lines.shopAgain, { text = "Hi again! Pick some seeds.", kind = "shopBubble", seconds = 3 })
	eq(P.lines.restock, { text = "Fresh seeds are in!", kind = "bubble", seconds = 3, rangeStuds = 40 })
	eq(
		P.lines.rare,
		{ text = "%s in stock! Come see!", kind = "toast", seconds = 4, minTier = 7, setting = "patchAlerts" }
	)
	eq(P.lines.shower, { text = "Rain's coming! Wet crops sell for 2x.", kind = "toast", seconds = 5, flag = true })
	eq(
		P.lines.mutation,
		{ text = "Ooh, a %s crop! Tap it to keep it.", kind = "toast", seconds = 5, flag = true, hideOn = "harvest" }
	)
	eq(
		P.lines.blockParty,
		{ text = "Tap the sunflower to help it bloom!", kind = "toast", seconds = 5, flag = true, hideOn = "water" }
	)
	eq(
		P.lines.update,
		{ text = "New update! Grab your free gift.", kind = "toast+board", seconds = 5, flag = "weekly.lineSeen" }
	)
	for key, line in P.lines do
		Assert.truthy(#line.text <= P.maxChars, key .. " fits maxChars")
	end
	eq({ P.queueGapSec, P.maxChars, P.tapToHide, P.serverRange }, { 2, 60, true, 12 })
	eq(P.prompt, { actionText = "Shop", objectText = "Patch's Seed Shop", maxDistance = 10, hold = 0 })
end)

test("save, net, capture", function()
	eq(Config.Save, {
		profileStore = "MM_Profiles_v1",
		giftStore = "MM_Gifts_v1",
		keyPrefix = "u_",
		schemaVersion = 1,
		autosaveSec = 90,
		lockStaleSec = 300,
		loadRetrySec = { 1, 2, 4, 8, 16 },
		receiptsKeep = 50,
		writeBackoffSec = { 1, 3, 7 },
		writeCooldownSec = 6,
		closeBudgetSec = 25,
		giftsInKeep = 100,
		giftQueueMax = 100,
	})
	eq(Config.Net, {
		bucket = { burst = 20, perSec = 10 },
		plotBucket = { burst = 20, perSec = 20 },
		abuseDrops = 300,
		abuseWindowSec = 60,
		maxKeys = 16,
		maxDepth = 3,
		maxBytes = 1024,
		giftOfferSec = 30,
		tileRangeStuds = 24,
		standRangeStuds = 16,
		gardenNameMax = 20,
		sunflowerRangeStuds = 15,
		patchRangeStuds = 12,
		warnEverySec = 60,
		resultTimeoutSec = 10,
	})
	eq(Config.Capture, { thumb = { 1920, 1080 }, icon = { 1024, 1024 }, safeBottom = 0.15 })
end)
