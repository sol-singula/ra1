local Assert = require("./mock/Assert")
local Farm = require("./mock/Farm")

local test, eq = Assert.test, Assert.eq

test("planting needs a seed, your own active tile, an empty one, and being near", function()
	local ctx = Farm.setup()
	local player = Farm.join(ctx, 1)
	local other = Farm.join(ctx, 2)
	Farm.standAtTile(ctx, player, player, "1")
	eq({ Farm.call(ctx, player, "Plot", "plant", { tile = "1", seed = "strawberry" }) }, { false, "no_seed" })
	eq({ Farm.call(ctx, player, "Plot", "plant", { tile = "4", seed = "carrot" }) }, { false, "ownership" }, "inactive")
	eq(Farm.call(ctx, player, "Plot", "plant", { tile = "1", seed = "carrot" }), true)
	eq(ctx.Data.get(player).seeds.carrot, 2)
	eq({ Farm.call(ctx, player, "Plot", "plant", { tile = "1", seed = "carrot" }) }, { false, "occupied" })
	Farm.standAtTile(ctx, player, other, "1")
	eq({ Farm.call(ctx, player, "Plot", "plant", { tile = "2", seed = "carrot" }) }, { false, "too_far" })
	local t = ctx.Data.get(player).tiles["1"]
	eq({ t.seed, t.grown, t.harvestsLeft, t.canUsed }, { "carrot", 0, 1, false })
	eq(t.muts, {})
end)

test("5 strawberry harvests: 4 regrow, the 5th clears the tile", function()
	local ctx = Farm.setup()
	local player = Farm.join(ctx, 1)
	local profile = ctx.Data.get(player)
	profile.seeds.strawberry = 1
	eq(Farm.call(ctx, player, "Plot", "plant", { tile = "1", seed = "strawberry" }), true)
	for i = 1, 5 do
		eq({ Farm.call(ctx, player, "Plot", "harvest", { tile = "1" }) }, { false, "not_ripe" })
		ctx.engine:advance(46)
		eq(Farm.call(ctx, player, "Plot", "harvest", { tile = "1" }), true, "harvest " .. i)
		local tile = profile.tiles["1"]
		if i < 5 then
			eq({ tile.harvestsLeft, tile.canUsed }, { 5 - i, false }, "regrew " .. i)
			Assert.truthy(tile.grown < 1, "grown starts over")
		else
			eq(tile, nil, "cleared")
		end
	end
	eq(profile.basket, { strawberry = 5 })
	eq(profile.seeds.strawberry, nil)
end)

test("Auto-Sell coins a carrot for 10 (and counts lifetime coins)", function()
	local ctx = Farm.setup()
	local player = Farm.join(ctx, 1)
	local profile = ctx.Data.get(player)
	profile.plotLevel = 2
	eq(Farm.call(ctx, player, "Basket", "setAutoSell", { on = true }), true)
	eq(Farm.call(ctx, player, "Plot", "plant", { tile = "1", seed = "carrot" }), true)
	Farm.ripen(ctx, player, "1")
	eq(Farm.call(ctx, player, "Plot", "harvest", { tile = "1" }), true)
	eq({ profile.coins, profile.lifetimeCoins }, { 60, 10 })
	eq(profile.basket, {})
	profile.passes.doubleCash = true
	eq(Farm.call(ctx, player, "Plot", "plant", { tile = "2", seed = "carrot" }), true)
	Farm.ripen(ctx, player, "2")
	eq(Farm.call(ctx, player, "Plot", "harvest", { tile = "2" }), true)
	eq(profile.coins, 80, "2x Sell Cash")
end)

test("a full basket refuses (toast), unless the player chose to sell that one", function()
	local ctx = Farm.setup()
	local player = Farm.join(ctx, 1)
	local profile = ctx.Data.get(player)
	profile.basket.corn = 200
	eq(Farm.call(ctx, player, "Plot", "plant", { tile = "1", seed = "carrot" }), true)
	Farm.ripen(ctx, player, "1")
	eq({ Farm.call(ctx, player, "Plot", "harvest", { tile = "1" }) }, { false, "basket_full" })
	Assert.truthy(table.find(Farm.toastTexts(ctx, player), "Basket full! Sell at the stand."), "toast")
	Assert.truthy(profile.tiles["1"], "the crop stays")
	eq(Farm.call(ctx, player, "Plot", "harvest", { tile = "1", onFull = "sell" }), true)
	eq(profile.coins, 60)
	eq(profile.basket, { corn = 200 })
end)

test("crossing 300 lifetime coins toasts Blueberry unlocked!", function()
	local ctx = Farm.setup()
	local player = Farm.join(ctx, 1)
	ctx.engine:run(function()
		ctx.Inv.addCoins(player, 299, "test")
	end)
	eq(table.find(Farm.toastTexts(ctx, player), "Blueberry unlocked!"), nil)
	ctx.engine:run(function()
		ctx.Inv.addCoins(player, 1, "test")
		ctx.Inv.addCoins(player, 50, "test")
	end)
	local n = 0
	for _, text in Farm.toastTexts(ctx, player) do
		if text == "Blueberry unlocked!" then
			n += 1
		end
	end
	eq(n, 1)
end)

test("harvestAll takes the normal ripe crops; mutated ones wait for a tap", function()
	local ctx = Farm.setup()
	local player = Farm.join(ctx, 1)
	local profile = ctx.Data.get(player)
	profile.seeds.carrot = 5
	for _, id in { "1", "2", "3" } do
		eq(Farm.call(ctx, player, "Plot", "plant", { tile = id, seed = "carrot" }), true)
	end
	Farm.ripen(ctx, player, "1")
	Farm.ripen(ctx, player, "2")
	profile.tiles["2"].muts.wet = true
	eq(Farm.call(ctx, player, "Plot", "harvestAll", {}), true)
	eq(profile.basket, { carrot = 1 })
	Assert.truthy(profile.tiles["2"] and profile.tiles["3"], "mutated and unripe stay")
	eq(profile.tiles["1"], nil)
	eq({ Farm.call(ctx, player, "Plot", "harvestAll", {}) }, { false, "nothing_ripe" })
end)

test("coins and seeds go through InventoryService (Economy fires)", function()
	local ctx = Farm.setup()
	local player = Farm.join(ctx, 1)
	local log = {}
	ctx.Inv.Economy:Connect(function(_, kind, delta, reason)
		table.insert(log, `{kind} {delta} {reason}`)
	end)
	eq(Farm.call(ctx, player, "Plot", "plant", { tile = "1", seed = "carrot" }), true)
	eq(log, { "seed:carrot -1 plant" })
end)
