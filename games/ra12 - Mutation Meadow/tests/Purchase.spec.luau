local Assert = require("./mock/Assert")
local Farm = require("./mock/Farm")
local Server = require("./mock/Server")
local Store = require("./mock/Store")

local test, eq = Assert.test, Assert.eq

local function prompt(ctx, p, payload)
	return { Farm.call(ctx, p, "Purchase", "prompt", payload, if payload.friendId then 8 else nil) }
end

local function decisions(ctx)
	local D = ctx.engine.Enum.ProductPurchaseDecision
	return D.PurchaseGranted, D.NotProcessedYet
end

test("Instant Grow: refused with nothing growing; falls back to the longest crop; a credit when none", function()
	local ctx = Store.setup()
	local p = Farm.join(ctx, 1)
	local profile = ctx.Data.get(p)
	local GRANTED = decisions(ctx)
	eq(prompt(ctx, p, { key = "instantGrow" }), { false, "nothing_growing" })
	Farm.crop(ctx, p, "1", "carrot")
	Farm.crop(ctx, p, "2", "corn")
	Farm.crop(ctx, p, "3", "tomato")
	eq(prompt(ctx, p, { key = "instantGrow", tile = "1" }), { true })
	eq(ctx.engine.prompts[#ctx.engine.prompts].id, Store.id(ctx, "instantGrow"))
	Farm.ripen(ctx, p, "1") -- it ripened while the prompt was up
	eq(Store.buy(ctx, p, "instantGrow"), GRANTED)
	eq(profile.tiles["2"].grown, 360, "the corn had the longest left")
	Assert.truthy(profile.tiles["3"].grown < 180, "the tomato still grows")
	for id in profile.tiles do
		profile.tiles[id] = nil
	end
	eq(Store.buy(ctx, p, "instantGrow"), GRANTED)
	eq(profile.meta.growCredits, 1, "nothing growing at receipt time: a credit")
	Farm.crop(ctx, p, "5", "corn")
	local before = #ctx.engine.prompts
	eq(prompt(ctx, p, { key = "instantGrow", tile = "5" }), { true, "credit" })
	eq(#ctx.engine.prompts, before, "the credit is spent instead of charging")
	eq({ profile.tiles["5"].grown, profile.meta.growCredits }, { 360, 0 })
end)

test("Instant Grow ripens the held tile while it still grows", function()
	local ctx = Store.setup()
	local p = Farm.join(ctx, 1)
	local profile = ctx.Data.get(p)
	Farm.crop(ctx, p, "1", "carrot")
	Farm.crop(ctx, p, "2", "corn")
	eq(prompt(ctx, p, { key = "instantGrow", tile = "1" }), { true })
	Store.buy(ctx, p, "instantGrow")
	eq(profile.tiles["1"].grown, 30)
	Assert.truthy(profile.tiles["2"].grown < 360, "the corn waits")
	local muts = {}
	for _, tile in profile.tiles do
		table.insert(muts, next(tile.muts) == nil)
	end
	eq(muts, { true, true }, "no mutation rolls")
end)

test("Grow All ripens 20 tiles", function()
	local ctx = Store.setup()
	local p = Farm.join(ctx, 1)
	local profile = ctx.Data.get(p)
	profile.plotLevel = 2
	local n = 0
	for id = 1, 64 do
		local tid = tostring(id)
		if ctx.engine:require(ctx.engine:module("Shared/Tiles")).isActive(tid, 2, false) then
			Farm.crop(ctx, p, tid, "corn")
			n += 1
		end
	end
	eq(n, 20)
	eq(prompt(ctx, p, { key = "growAll" }), { true })
	Store.buy(ctx, p, "growAll")
	local ripe = 0
	for _, tile in profile.tiles do
		if tile.grown >= 360 then
			ripe += 1
		end
	end
	eq(ripe, 20)
end)

test("a gift to an offline friend lands through the queue exactly once", function()
	local ctx = Store.setup()
	ctx.engine.friends["1:2"] = true
	local p = Farm.join(ctx, 1)
	local GRANTED = decisions(ctx)
	eq(prompt(ctx, p, { key = "gift_tag_star", friendId = 3 }), { false, "not_friend" })
	eq(prompt(ctx, p, { key = "gift_tag_star", friendId = 2 }), { true })
	eq(Server.raw(ctx.engine, 1).meta.pendingGift.friendId, 2, "saved before the prompt")
	eq(Store.buy(ctx, p, "gift_tag_star", "G1"), GRANTED)
	eq(Store.buy(ctx, p, "gift_tag_star", "G1"), GRANTED, "a re-sent receipt")
	local queue = ctx.engine.dataStores._raw("MM_Gifts_v1")["u_2"].gifts
	eq(#queue, 1)
	eq({ queue[1].key, queue[1].fromId, queue[1].purchaseId }, { "tag_star", 1, "G1" })
	eq(ctx.Data.get(p).meta.pendingGift, nil)
	local friend = Farm.join(ctx, 2)
	ctx.engine:advance(10)
	local fp = ctx.Data.get(friend)
	eq(fp.cosmetics.owned.tag_star, true)
	eq(fp.giftsIn, { "G1" })
	eq(#ctx.engine.dataStores._raw("MM_Gifts_v1")["u_2"].gifts, 0, "the queue empties")
	local toast
	for _, t in Farm.toasts(ctx, friend) do
		if t.kind == "gift" then
			toast = t
		end
	end
	eq(toast.text, "🎁 Player1 sent you Star Farmer!")
	eq(toast.data.button, "Gift back")
	eq(#Store.events(ctx, "purchase", 1), 1, "logged once")
end)

test("a gift to a friend in this server lands now; one who owns it already is refused", function()
	local ctx = Store.setup()
	ctx.engine.friends["1:2"] = true
	local p = Farm.join(ctx, 1)
	local friend = Farm.join(ctx, 2)
	eq(prompt(ctx, p, { key = "gift_extraRow", friendId = 2 }), { true })
	Store.buy(ctx, p, "gift_extraRow")
	eq(ctx.Purchase.owns(friend, "extraRow"), true)
	eq(ctx.Plot.plotOf(friend).ExtraRow.extra1:GetAttribute("Active"), true)
	eq(Server.raw(ctx.engine, 2).passes.extraRow, true, "saved")
	eq(prompt(ctx, p, { key = "gift_extraRow", friendId = 2 }), { false, "owned" })
end)

test("a re-sent receipt doesn't double-grant", function()
	local ctx = Store.setup()
	local p = Farm.join(ctx, 1)
	local profile = ctx.Data.get(p)
	Store.buy(ctx, p, "instantGrow", "R1")
	Store.buy(ctx, p, "instantGrow", "R1")
	eq(profile.meta.growCredits, 1)
	Store.buy(ctx, p, "theme_starry", "R2")
	Store.buy(ctx, p, "theme_starry", "R2")
	eq(profile.cosmetics.owned.theme_starry, true)
	eq(#Store.events(ctx, "purchase", 1), 2)
	eq(ctx.Config.Catalog.cosmetics.theme_starry.name, "Starry Night Plot")
	eq(ctx.Config.Catalog.cosmetics.theme_starry.robux, 199)
end)

test("a throwing handler rolls back and asks again", function()
	local ctx = Store.setup()
	local p = Farm.join(ctx, 1)
	local profile = ctx.Data.get(p)
	local _, NOT_YET = decisions(ctx)
	local real = ctx.PurchaseService.HANDLERS.growAll
	ctx.PurchaseService.HANDLERS.growAll = function(player, prof)
		prof.coins += 1000
		prof.meta.growCredits = 9
		error("boom")
	end
	local coins = profile.coins
	eq(Store.buy(ctx, p, "growAll"), NOT_YET)
	eq({ profile.coins, profile.meta.growCredits }, { coins, 0 })
	ctx.PurchaseService.HANDLERS.growAll = real
	eq(Store.buy(ctx, p, "gift_tag_star"), NOT_YET, "a gift with no saved target never grants")
	eq(#profile.receipts, 0)
end)

test("a cosmetic you own can't be prompted; one with no id yet can't either", function()
	local ctx = Store.setup()
	local p = Farm.join(ctx, 1)
	ctx.Data.get(p).cosmetics.owned.trail_leaf = true
	eq(prompt(ctx, p, { key = "trail_leaf" }), { false, "owned" })
	local plain = Farm.setup()
	local q = Farm.join(plain, 1)
	eq({ Farm.call(plain, q, "Purchase", "prompt", { key = "vip" }) }, { false, "not_created" })
end)
