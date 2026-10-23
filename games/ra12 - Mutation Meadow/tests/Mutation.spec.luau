local Assert = require("./mock/Assert")
local Farm = require("./mock/Farm")

local test, eq = Assert.test, Assert.eq

test("over 10,000 crops: Wet 25% +-1.5, Golden 8% +-1", function()
	local ctx = Farm.setup()
	local Growth = ctx.engine:require(ctx.engine:module("Shared/Growth"))
	local rng = ctx.engine.Random.new(7)
	local wet, golden = 0, 0
	for _ = 1, 10000 do
		local tile = Growth.newTile("corn", 0)
		if ctx.Mut.tryRoll(tile, "wet", 0.25, rng) then
			wet += 1
		end
		if ctx.Mut.tryRoll(tile, "golden", 0.08, rng) then
			golden += 1
		end
	end
	Assert.truthy(math.abs(wet / 10000 - 0.25) <= 0.015, `wet {wet / 100}%`)
	Assert.truthy(math.abs(golden / 10000 - 0.08) <= 0.01, `golden {golden / 100}%`)
end)

test("a Wet crop in a later Golden Hour becomes Wet + Golden (x40); Golden never rolls Golden again", function()
	local ctx = Farm.setup()
	local p = Farm.join(ctx, 1)
	local MutationMath = ctx.engine:require(ctx.engine:module("Shared/MutationMath"))
	local tile = Farm.crop(ctx, p, "1", "pumpkin")
	local yes = Farm.fixedRng(0)
	ctx.engine:run(function()
		eq(ctx.Mut.roll(p, "1", "wet", 0.25, yes), true)
		eq(ctx.Mut.roll(p, "1", "wet", 0.25, yes), false, "Wet once")
		eq(ctx.Mut.roll(p, "1", "golden", 0.08, yes), true)
		eq(ctx.Mut.roll(p, "1", "golden", 0.08, yes), false, "Golden once")
	end)
	eq(tile.muts, { wet = true, golden = true })
	eq(MutationMath.mult(tile.muts), 40)
	eq({ MutationMath.mult({ wet = true }), MutationMath.mult({ golden = true }), MutationMath.mult({}) }, { 2, 20, 1 })
	eq(MutationMath.value("pumpkin", tile.muts), 174000)
	eq(ctx.Plot.tilePart(p, "1"):GetAttribute("Muts"), "wetgolden")
end)

test("the owner gets Mutation { tile, mut, value, newEntry } and Mutated fires", function()
	local ctx = Farm.setup()
	local p = Farm.join(ctx, 1)
	Farm.crop(ctx, p, "2", "pumpkin")
	local fired = {}
	ctx.Mut.Mutated:Connect(function(player, seed, key)
		table.insert(fired, { player.UserId, seed, key })
	end)
	ctx.engine:run(function()
		ctx.Mut.roll(p, "2", "golden", 0.08, Farm.fixedRng(0))
	end)
	eq(ctx.engine:clientEvents("Mutation", 1)[1][1], { tile = "2", mut = "golden", value = 87000, newEntry = true })
	eq(fired, { { 1, "pumpkin", "golden" } })
	ctx.Data.get(p).collection.found["carrot:wet"] = { at = 1, n = 1 }
	Farm.crop(ctx, p, "3", "carrot")
	ctx.engine:run(function()
		ctx.Mut.roll(p, "3", "wet", 0.25, Farm.fixedRng(0))
	end)
	eq(ctx.engine:clientEvents("Mutation", 1)[2][1].newEntry, false)
end)

test("Auto-Sell and harvestAll never touch mutated crops", function()
	local ctx = Farm.setup()
	local p = Farm.join(ctx, 1)
	local profile = ctx.Data.get(p)
	profile.plotLevel = 2
	profile.autoSell = true
	Farm.crop(ctx, p, "1", "carrot", true).muts.wet = true
	Farm.crop(ctx, p, "2", "carrot", true)
	eq(Farm.call(ctx, p, "Plot", "harvestAll", {}), true)
	Assert.truthy(profile.tiles["1"], "the mutated one waits")
	eq(profile.coins, 60, "the normal one auto-sold")
	eq(Farm.call(ctx, p, "Plot", "harvest", { tile = "1" }), true)
	eq(profile.coins, 60, "a tap keeps it instead of selling")
	local n = 0
	for _, item in profile.items do
		n += 1
		eq(item.muts, { wet = true })
	end
	eq(n, 1)
end)
