local fs = require("@lune/fs")

local Assert = require("./mock/Assert")
local Farm = require("./mock/Farm")
local Store = require("./mock/Store")

local test, eq = Assert.test, Assert.eq

local roblox = require("@lune/roblox")

local SECTION_10 = {
	"mutation_found",
	"item_kept",
	"item_sold",
	"item_displayed",
	"item_gifted",
	"gift_declined",
	"collection_claim",
	"milestone_claim",
	"backpack_full",
	"basket_full",
	"blockparty_water",
	"blockparty_bloom",
	"blockparty_reward",
	"weather_start",
	"daily_claim",
	"quest_complete",
	"playtime_claim",
	"weekly_gift_claim",
	"shop_open",
	"lounge_enter",
	"purchase",
	"patch_line_shown",
	"patch_line_dismissed",
	"session_end",
	"d1_return",
	"first_purchase",
	"net_drop",
}

local function calls(ctx, method, player)
	local out = {}
	for _, c in ctx.engine.analytics do
		if c.method == method and (player == nil or c.args[1] == player) then
			table.insert(out, c.args)
		end
	end
	return out
end

local function plant(ctx, p, tile, seed)
	Farm.standAtTile(ctx, p, p, tile)
	eq(Farm.call(ctx, p, "Plot", "plant", { tile = tile, seed = seed or "carrot" }), true, "plant " .. tile)
	ctx.engine:advance(2)
end

local function harvest(ctx, p, tile)
	Farm.standAtTile(ctx, p, p, tile)
	eq(Farm.call(ctx, p, "Plot", "harvest", { tile = tile }), true, "harvest " .. tile)
	ctx.engine:advance(1)
end

local function sell(ctx, p)
	ctx.engine:advance(5)
	Farm.standAtStand(ctx, p)
	eq(Farm.call(ctx, p, "Basket", "sellAll", {}), true)
end

-- the FTUE script: plant, harvest, sell, shop, plot 2, the shower's Wet kept, a pedestal, ten minutes
local function ftue(ctx, p)
	local start = ctx.engine.now
	for _, tile in { "1", "2", "3" } do
		plant(ctx, p, tile)
	end
	Farm.at(ctx, start + 36)
	for _, tile in { "1", "2", "3" } do
		harvest(ctx, p, tile)
	end
	sell(ctx, p)
	Farm.openShop(ctx, p)
	eq(Farm.call(ctx, p, "Shop", "buySeed", { seed = "carrot", qty = 1 }), true)
	eq(Farm.call(ctx, p, "Shop", "buySeed", { seed = "carrot", qty = 1 }), true)
	eq(Farm.call(ctx, p, "Shop", "close", {}), true)
	local planted = ctx.engine.now
	plant(ctx, p, "1")
	plant(ctx, p, "2")
	Farm.at(ctx, planted + 34)
	harvest(ctx, p, "1")
	harvest(ctx, p, "2")
	sell(ctx, p)
	eq(Farm.call(ctx, p, "Upgrade", "buy", { kind = "plot" }), true)
	Farm.crop(ctx, p, "4", "carrot", true) -- ripe: the shower's guaranteed Wet lands here
	Farm.at(ctx, start + 262)
	local profile = ctx.Data.get(p)
	Assert.truthy(profile.tiles["4"] and profile.tiles["4"].muts.wet, "the guaranteed Wet")
	harvest(ctx, p, "4")
	local guid = next(profile.items)
	eq(Farm.call(ctx, p, "Inventory", "display", { id = guid, pedestal = 1 }), true)
	Farm.at(ctx, start + 610)
	return profile
end

test("the FTUE script logs funnel steps 1-10 in order, once each", function()
	local ctx = Store.setup()
	ctx.Weather.rng = Farm.fixedRng(0.99)
	local p = Farm.join(ctx, 1)
	ftue(ctx, p)
	local steps, names = {}, {}
	for _, args in calls(ctx, "LogOnboardingFunnelStepEvent", p) do
		table.insert(steps, args[2])
		table.insert(names, args[3])
		eq(args[4].CustomField01, "organic")
	end
	eq(steps, { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 })
	eq(names[10], "ten_minutes")
	-- a later session logs no funnel steps
	ctx.engine:removePlayer(p)
	ctx.engine:advance(7)
	local again = Farm.join(ctx, 1)
	ctx.engine:advance(15)
	Farm.crop(ctx, again, "1", "carrot", true)
	harvest(ctx, again, "1")
	eq(#calls(ctx, "LogOnboardingFunnelStepEvent", again), 0)
end)

test("the economy events: every coin change, the ending balance, and sources - sinks = the coin delta", function()
	local ctx = Store.setup()
	ctx.Weather.rng = Farm.fixedRng(0.99)
	local p = Farm.join(ctx, 1)
	local before = ctx.Data.get(p).coins
	local profile = ftue(ctx, p)
	eq(Farm.call(ctx, p, "Daily", "claim", {}), true)
	eq(Farm.call(ctx, p, "Playtime", "claim", { index = 1 }), true)
	local net, kinds = 0, {}
	for _, args in calls(ctx, "LogEconomyEvent", p) do
		eq(args[3], "Coins")
		local amount = if args[2].Name == "Source" then args[4] else -args[4]
		net += amount
		kinds[args[7]] = args[6]
		Assert.truthy(args[8].CustomField01 and args[8].CustomField02 and args[8].CustomField03, "custom fields")
	end
	eq(net, profile.coins - before)
	eq(kinds.sell_normal, "Gameplay")
	eq(kinds.seed, "Shop")
	eq(kinds.upgrade, "Gameplay")
	eq(kinds.quest, "Onboarding", "the starter quest rewards")
	eq(kinds.daily, "Gameplay")
	local last = calls(ctx, "LogEconomyEvent", p)
	eq(last[#last][5], profile.coins, "the ending balance")
end)

test("every §10 event fires at least once, each with CustomField01..03", function()
	local ctx = Store.setup()
	ctx.Weather.rng = Farm.fixedRng(0.99)
	ctx.engine.launchData[1] = '{"src":"ad","c":"spring"}'
	local p = Farm.join(ctx, 1)
	local b = Farm.join(ctx, 2)
	local profile = ftue(ctx, p)
	local ItemModel = ctx.engine:require(ctx.engine:module("Server/Items/ItemModel"))

	-- item_sold, item_gifted, gift_declined
	local sellMe = ItemModel.mint(profile, 1, "corn", { wet = true })
	eq(Farm.call(ctx, p, "Inventory", "sellItem", { id = sellMe }), true)
	local gift = ItemModel.mint(profile, 1, "corn", { golden = true })
	ctx.engine:advance(8)
	eq(Farm.call(ctx, p, "Gift", "offer", { targetId = 2, item = gift }, 8), true)
	local offers = ctx.engine:clientEvents("GiftOffer", 2)
	eq(Farm.call(ctx, b, "Gift", "respond", { giftId = offers[#offers][1].giftId, accept = false }, 2), true)
	eq(Farm.call(ctx, p, "Gift", "offer", { targetId = 2, item = gift }, 8), true)
	offers = ctx.engine:clientEvents("GiftOffer", 2)
	eq(Farm.call(ctx, b, "Gift", "respond", { giftId = offers[#offers][1].giftId, accept = true }, 8), true)

	-- collection_claim, milestone_claim
	eq(Farm.call(ctx, p, "Collection", "claim", { entry = "carrot:wet" }), true)
	for i = 1, 5 do
		profile.collection.found[ctx.Collection.ENTRIES[i]] = { at = 1, n = 1 }
	end
	eq(Farm.call(ctx, p, "Collection", "claim", { milestone = 5 }), true)

	-- backpack_full, basket_full
	for _ = 1, ctx.Inv.backpackCap(profile) do
		ItemModel.mint(profile, 1, "carrot", { wet = true })
	end
	Farm.crop(ctx, p, "4", "carrot", true).muts = { golden = true }
	Farm.standAtTile(ctx, p, p, "4")
	eq({ Farm.call(ctx, p, "Plot", "harvest", { tile = "4" }) }, { false, "backpack_full" })
	profile.basket = { carrot = 200 }
	Farm.crop(ctx, p, "3", "carrot", true)
	Farm.standAtTile(ctx, p, p, "3")
	eq({ Farm.call(ctx, p, "Plot", "harvest", { tile = "3" }) }, { false, "basket_full" })
	profile.basket = {}

	-- blockparty_water, blockparty_bloom, blockparty_reward, weather_start (event)
	ctx.engine:run(function()
		ctx.BP.open(ctx.engine.now, true)
	end)
	Farm.standAtSunflower(ctx, p)
	for _ = 1, 5 do
		eq(Farm.call(ctx, p, "BlockParty", "water", {}), true)
		ctx.engine:advance(2)
	end
	ctx.engine:run(function()
		ctx.BP.bloom(ctx.engine.now)
	end)

	-- daily, playtime, weekly, lounge, a purchase, patch dismissed
	eq(Farm.call(ctx, p, "Daily", "claim", {}), true)
	eq(Farm.call(ctx, p, "Playtime", "claim", { index = 1 }), true)
	eq(Farm.call(ctx, p, "Weekly", "claim", { updateId = ctx.Weekly.current().updateId }), true)
	profile.passes.vip = true
	eq(Farm.call(ctx, p, "Lounge", "enter", {}), true)
	Store.buy(ctx, p, "tag_star")
	eq(Farm.call(ctx, p, "Settings", "patchAck", { id = "plant", how = "tap" }), true)

	-- net_drop and session_end on leave, then d1_return the next UTC day
	ctx.engine:fireServer(p, "Plot", "plant", { tile = "nope", seed = 5 })
	ctx.engine:advance(0.2)
	ctx.engine:removePlayer(p)
	ctx.engine:advance(8)
	ctx.engine.workspace:SetAttribute("ClockOffset", 86400)
	local again = Farm.join(ctx, 1)
	ctx.engine:advance(15)

	local seen = {}
	for _, args in calls(ctx, "LogCustomEvent") do
		local who = args[1]
		if who == p or who == again then
			local base = args[2]:match("^[^:]+")
			seen[base] = (seen[base] or 0) + 1
			eq(args[4].CustomField01, "ad", args[2])
			eq(args[4].CustomField02, "spring", args[2])
			Assert.truthy(args[4].CustomField03 == "payer" or args[4].CustomField03 == "nonpayer", args[2])
			Assert.truthy(type(args[3]) == "number", "a numeric value")
		end
	end
	for _, name in SECTION_10 do
		Assert.truthy(seen[name], `{name} never fired`)
	end
	-- and only §10's names
	local Telemetry = ctx.engine:require(ctx.engine:module("Server/Services/TelemetryService"))
	for name in seen do
		Assert.truthy(Telemetry.EVENTS[name], `{name} is not a §10 event`)
	end
	eq(seen.first_purchase, 1)
	eq(seen.d1_return, 1)
	local suffixed = {}
	for _, args in calls(ctx, "LogCustomEvent", p) do
		suffixed[args[2]] = args[3]
	end
	Assert.truthy(
		suffixed["weather_start:welcomeShower"]
			and (suffixed["weather_start:rain"] or suffixed["weather_start:goldenHour"]),
		"kinds suffixed"
	)
	Assert.truthy(suffixed["mutation_found:wet"], "mutation suffixed")
	eq(suffixed["purchase:tag_star"], 99, "robux in value")
	eq(suffixed["daily_claim"], 1, "the day in value")
	local last = calls(ctx, "LogCustomEvent", p)
	local payerAfter = last[#last][4].CustomField03
	eq(payerAfter, "payer", "a receipt makes a payer")
end)

test("nothing outside TelemetryService calls AnalyticsService", function()
	local function walk(dir, out)
		for _, name in fs.readDir(dir) do
			local path = dir .. "/" .. name
			if fs.isDir(path) then
				walk(path, out)
			elseif name:match("%.luau?$") then
				table.insert(out, path)
			end
		end
		return out
	end
	local hits = {}
	for _, path in walk("src", {}) do
		local code = fs.readFile(path):gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
		if code:find("AnalyticsService") and not path:match("TelemetryService%.lua$") then
			table.insert(hits, path)
		end
	end
	eq(hits, {})
end)
