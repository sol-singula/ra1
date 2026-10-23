local Assert = require("./mock/Assert")
local Farm = require("./mock/Farm")

local test, eq = Assert.test, Assert.eq

test("selling 12 tomatoes at the stand gives 1320 coins and empties the basket", function()
	local ctx = Farm.setup()
	local player = Farm.join(ctx, 1)
	local profile = ctx.Data.get(player)
	profile.basket.tomato = 12
	eq({ Farm.call(ctx, player, "Basket", "sellAll", {}) }, { false, "too_far" })
	Farm.standAtStand(ctx, player)
	eq(Farm.call(ctx, player, "Basket", "sellAll", {}), true)
	eq(profile.coins, 50 + 1320)
	eq(profile.lifetimeCoins, 1320)
	eq(profile.basket, {})
	eq({ Farm.call(ctx, player, "Basket", "sellAll", {}) }, { false, "empty" })
end)

test("a mixed basket, and 2x Sell Cash", function()
	local ctx = Farm.setup()
	local player = Farm.join(ctx, 1)
	local profile = ctx.Data.get(player)
	profile.basket = { carrot = 3, corn = 2 }
	profile.passes.doubleCash = true
	Farm.standAtStand(ctx, player)
	eq(Farm.call(ctx, player, "Basket", "sellAll", {}), true)
	eq(profile.coins, 50 + (3 * 10 + 2 * 330) * 2)
end)

test("Auto-Sell at plot level 1 is refused; level 2 allows it", function()
	local ctx = Farm.setup()
	local player = Farm.join(ctx, 1)
	local profile = ctx.Data.get(player)
	eq({ Farm.call(ctx, player, "Basket", "setAutoSell", { on = true }) }, { false, "locked" })
	eq(profile.autoSell, false)
	profile.plotLevel = 2
	eq(Farm.call(ctx, player, "Basket", "setAutoSell", { on = true }), true)
	eq(profile.autoSell, true)
	eq(Farm.call(ctx, player, "Basket", "setAutoSell", { on = false }), true)
	eq(profile.autoSell, false)
end)

test("the doc timeline: 3 carrots at 0:05 ripe at 0:35, Sell All 30, Expand for 100 makes 4x5", function()
	local ctx = Farm.setup()
	local player = Farm.join(ctx, 1)
	local profile = ctx.Data.get(player)
	ctx.engine:advance(5)
	Farm.standAtTile(ctx, player, player, "10")
	for _, id in { "1", "2", "3" } do
		eq(Farm.call(ctx, player, "Plot", "plant", { tile = id, seed = "carrot" }), true)
	end
	ctx.engine:advance(30.5) -- planted a few calls after 0:05
	for _, id in { "1", "2", "3" } do
		eq(Farm.call(ctx, player, "Plot", "harvest", { tile = id }), true)
	end
	Farm.standAtStand(ctx, player)
	eq(Farm.call(ctx, player, "Basket", "sellAll", {}), true)
	eq(profile.coins, 80)
	profile.coins += 20 -- the doc's 100 for Expand
	eq(Farm.call(ctx, player, "Upgrade", "buy", { kind = "plot" }), true)
	eq(#ctx.engine:require(ctx.engine:module("Shared/Tiles")).activeTiles(profile.plotLevel, false), 20)
end)
