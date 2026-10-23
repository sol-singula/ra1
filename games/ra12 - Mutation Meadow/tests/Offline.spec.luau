local Assert = require("./mock/Assert")
local Farm = require("./mock/Farm")

local test, eq = Assert.test, Assert.eq

local T0 = 1_760_000_000

local function fixture(ctx, seed, awaySec)
	ctx.engine.dataStores._put("MM_Profiles_v1", "u_1", {
		v = 1,
		tiles = {
			["1"] = {
				seed = seed,
				plantedAt = T0 - awaySec - 5,
				grown = 0,
				harvestsLeft = 1,
				muts = {},
				canUsed = false,
			},
		},
		meta = { created = 1, lastSeen = T0 - awaySec },
	})
end

local function welcome(ctx, player)
	for _, t in Farm.toasts(ctx, player) do
		if t.kind == "welcomeBack" then
			return t
		end
	end
	return nil
end

test("a dragon fruit away 30 minutes has grown 1800 and the card shows", function()
	local ctx = Farm.setup({ now = T0 })
	fixture(ctx, "dragonfruit", 1800)
	local player = Farm.join(ctx, 1)
	local tile = ctx.Data.get(player).tiles["1"]
	Assert.truthy(tile.grown >= 1800 and tile.grown < 1801, tostring(tile.grown))
	local card = welcome(ctx, player)
	Assert.truthy(card, "card at 1800s")
	eq(card.data, { awaySec = 1800, ripe = 0 })
end)

test("a moon melon away 10h is ripe, capped at 28800", function()
	local ctx = Farm.setup({ now = T0 })
	fixture(ctx, "moonmelon", 36000)
	local player = Farm.join(ctx, 1)
	local tile = ctx.Data.get(player).tiles["1"]
	Assert.truthy(tile.grown >= 28800 and tile.grown < 28801, tostring(tile.grown))
	eq(ctx.Plot.tilePart(player, "1"):GetAttribute("Ripe"), true)
	eq(welcome(ctx, player).data, { awaySec = 28800, ripe = 1 })
end)

test("no card at 1799s away; none for a new farm", function()
	local ctx = Farm.setup({ now = T0 })
	fixture(ctx, "corn", 1799)
	local player = Farm.join(ctx, 1)
	eq(welcome(ctx, player), nil)
	local fresh = Farm.join(ctx, 2)
	eq(welcome(ctx, fresh), nil)
end)

test("ripe crops wait offline (no regrow without a harvest)", function()
	local ctx = Farm.setup({ now = T0 })
	ctx.engine.dataStores._put("MM_Profiles_v1", "u_1", {
		v = 1,
		tiles = {
			["1"] = { seed = "strawberry", plantedAt = 0, grown = 45, harvestsLeft = 5, muts = {}, canUsed = false },
		},
		meta = { created = 1, lastSeen = T0 - 4000 },
	})
	local player = Farm.join(ctx, 1)
	local tile = ctx.Data.get(player).tiles["1"]
	eq({ tile.grown, tile.harvestsLeft }, { 45, 5 })
	eq(welcome(ctx, player).data, { awaySec = 4000, ripe = 1 })
	eq(Farm.call(ctx, player, "Plot", "harvestAll", {}), true)
	eq(ctx.Data.get(player).basket, { strawberry = 1 })
end)
