local Assert = require("./mock/Assert")
local Farm = require("./mock/Farm")

local test, eq = Assert.test, Assert.eq

local function mutate(ctx, p, tileId, mut)
	ctx.engine:run(function()
		ctx.Mut.roll(p, tileId, mut, 1, Farm.fixedRng(0))
	end)
end

local function claim(ctx, p, payload)
	return table.pack(Farm.call(ctx, p, "Collection", "claim", payload))
end

test("27 entries: 9 seeds x wet / golden / wetgolden", function()
	local ctx = Farm.setup()
	eq(#ctx.Collection.ENTRIES, 27)
	eq({ ctx.Collection.ENTRIES[1], ctx.Collection.ENTRIES[3], ctx.Collection.ENTRIES[27] }, {
		"carrot:wet",
		"carrot:wetgolden",
		"moonmelon:wetgolden",
	})
end)

test("a first find records { at, n = 1 }, later finds add to n; a double claim pays once", function()
	local ctx = Farm.setup()
	local p = Farm.join(ctx, 1)
	local profile = ctx.Data.get(p)
	Farm.crop(ctx, p, "1", "carrot")
	mutate(ctx, p, "1", "wet")
	eq(profile.collection.found["carrot:wet"], { at = ctx.engine.now, n = 1 })
	Farm.crop(ctx, p, "2", "carrot")
	mutate(ctx, p, "2", "wet")
	eq(profile.collection.found["carrot:wet"].n, 2)
	local coins = profile.coins
	eq(claim(ctx, p, { entry = "carrot:wet" })[1], true)
	eq(profile.coins, coins + 100)
	eq({ table.unpack(claim(ctx, p, { entry = "carrot:wet" }), 1, 2) }, { false, "claimed" })
	eq(profile.coins, coins + 100, "paid once")
	eq({ table.unpack(claim(ctx, p, { entry = "corn:golden" }), 1, 2) }, { false, "not_found" })
end)

test("Wet then Golden on one crop finds wetgolden (5000)", function()
	local ctx = Farm.setup()
	local p = Farm.join(ctx, 1)
	local profile = ctx.Data.get(p)
	Farm.crop(ctx, p, "1", "pumpkin")
	mutate(ctx, p, "1", "wet")
	mutate(ctx, p, "1", "golden")
	Assert.truthy(profile.collection.found["pumpkin:wet"], "wet first")
	Assert.truthy(profile.collection.found["pumpkin:wetgolden"], "then wetgolden")
	eq(profile.collection.found["pumpkin:golden"], nil, "not plain golden")
	local coins = profile.coins
	eq(claim(ctx, p, { entry = "pumpkin:wetgolden" })[1], true)
	eq(profile.coins, coins + 5000)
end)

test("milestones: 5 tag, 10 lantern, 18 a pedestal, 27 title + badge; 27 with 26 found is refused", function()
	local ctx = Farm.setup()
	local p = Farm.join(ctx, 1)
	local profile = ctx.Data.get(p)
	local function fill(n)
		for i = 1, n do
			profile.collection.found[ctx.Collection.ENTRIES[i]] = { at = 1, n = 1 }
		end
	end
	eq({ table.unpack(claim(ctx, p, { milestone = 5 }), 1, 2) }, { false, "not_yet" })
	fill(5)
	eq(claim(ctx, p, { milestone = 5 })[1], true)
	eq(profile.cosmetics.owned.tag_collector, true)
	eq({ table.unpack(claim(ctx, p, { milestone = 5 }), 1, 2) }, { false, "claimed" })
	fill(10)
	eq(claim(ctx, p, { milestone = 10 })[1], true)
	eq(profile.cosmetics.owned.deco_lantern, true)
	fill(17)
	local before = ctx.Inv.pedestalCount(profile)
	fill(18)
	eq(claim(ctx, p, { milestone = 18 })[1], true)
	eq(ctx.Inv.pedestalCount(profile), before + 1, "milestone 18 adds a pedestal")
	eq(ctx.Plot.pedestalPart(p, before + 1):GetAttribute("Unlocked"), true)
	fill(26)
	eq({ table.unpack(claim(ctx, p, { milestone = 27 }), 1, 2) }, { false, "not_yet" })
	eq(profile.cosmetics.owned.title_master, nil)
	fill(27)
	eq(claim(ctx, p, { milestone = 27 })[1], true)
	eq(profile.cosmetics.owned.title_master, true)
end)

test("the 27th find awards master_gardener", function()
	local ctx = Farm.setup()
	local p = Farm.join(ctx, 1)
	local profile = ctx.Data.get(p)
	local awarded = {}
	local real = ctx.Reward.award
	ctx.Reward.award = function(player, key)
		table.insert(awarded, key)
		return real(player, key)
	end
	for i = 1, 26 do
		profile.collection.found[ctx.Collection.ENTRIES[i]] = { at = 1, n = 1 }
	end
	ctx.engine:run(function()
		ctx.Collection.record(p, "moonmelon", "wetgolden")
	end)
	eq(ctx.Collection.foundCount(profile), 27)
	Assert.truthy(table.find(awarded, "master_gardener"), "awarded")
	ctx.Reward.award = real
end)
