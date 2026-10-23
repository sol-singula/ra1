local Assert = require("./mock/Assert")
local Engine = require("./mock/Engine")
local Farm = require("./mock/Farm")

local test, eq, near = Assert.test, Assert.eq, Assert.near

local engine = Engine.new()
local Growth = engine:require(engine:module("Shared/Growth"))

-- whole seconds until ripe, ticking every 1s
local function ripeAt(tile, rate, startAt)
	local t = startAt or 0
	while not Growth.ripe(tile) do
		Growth.tick(tile, 1, rate)
		t += 1
		assert(t < 100000, "never ripe")
	end
	return t
end

test("a carrot is ripe at 30s", function()
	local tile = Growth.newTile("carrot", 0)
	for _ = 1, 29 do
		Growth.tick(tile, 1, 1)
	end
	eq(Growth.ripe(tile), false)
	Growth.tick(tile, 1, 1)
	eq(Growth.ripe(tile), true)
end)

test("with a basic sprinkler, at 24s", function()
	local rate = Growth.rate(Growth.sprinklerMult({ ["10"] = "basic" }, "1"), 0, 1)
	eq(rate, 1.25)
	eq(ripeAt(Growth.newTile("carrot", 0), rate), 24)
end)

test("advanced + 3 friends + Rain: 30 / 2.925 = 10.26s", function()
	local rate = Growth.rate(
		Growth.sprinklerMult({ ["1"] = "advanced" }, "1"),
		Growth.friendBoost(3),
		Growth.weatherMult({ rain = true })
	)
	near(rate, 2.925, 1e-9)
	local tile = Growth.newTile("carrot", 0)
	near(Growth.timeLeft(tile, rate), 30 / 2.925, 1e-9)
	near(Growth.timeLeft(tile, rate), 10.26, 0.01)
	eq(ripeAt(tile, rate), 11, "on whole-second ticks")
end)

test("boosts: the best sprinkler wins, the friend boost caps, the shower counts", function()
	eq(Growth.sprinklerMult({ ["1"] = "basic", ["2"] = "advanced" }, "10"), 1.5)
	eq(Growth.sprinklerMult({ ["1"] = "advanced" }, "17"), 1, "two rows away")
	eq(Growth.sprinklerMult({ ["1"] = "advanced" }, "extra1"), 1)
	eq({ Growth.friendBoost(0), Growth.friendBoost(1), Growth.friendBoost(4) }, { 0, 0.1, 0.3 })
	eq({ Growth.weatherMult(nil), Growth.weatherMult({ shower = true }) }, { 1, 1.5 })
end)

test("a tin can at t=10 ripens it at 29s; a second use is refused", function()
	local tile = Growth.newTile("carrot", 0)
	for _ = 1, 10 do
		Growth.tick(tile, 1, 1)
	end
	eq(Growth.useCan(tile, 0.05), true)
	eq(tile.grown, 11)
	eq({ Growth.useCan(tile, 0.05) }, { false, "can_used" })
	eq(ripeAt(tile, 1, 10), 29)
	eq({ Growth.useCan(Growth.newTile("carrot", 0), 0.05) }, { true })
	local ripe = Growth.newTile("carrot", 0)
	ripe.grown = 30
	eq({ Growth.useCan(ripe, 0.05) }, { false, "ripe" })
end)

test("on the server: a planted carrot is ripe after 30s, not before", function()
	local ctx = Farm.setup()
	local player = Farm.join(ctx, 1)
	eq(Farm.call(ctx, player, "Plot", "plant", { tile = "1", seed = "carrot" }), true)
	local tile = ctx.Data.get(player).tiles["1"]
	local part = ctx.Plot.tilePart(player, "1")
	eq(part:GetAttribute("Seed"), "carrot")
	ctx.engine:advance(28)
	eq(Growth.ripe(tile), false)
	eq(part:GetAttribute("Ripe"), false)
	ctx.engine:advance(3)
	eq(Growth.ripe(tile), true)
	eq(part:GetAttribute("Ripe"), true)
	-- the can through the remote: once per growth
	eq(Farm.call(ctx, player, "Plot", "plant", { tile = "2", seed = "carrot" }), true)
	eq(Farm.call(ctx, player, "Plot", "water", { tile = "2" }), true)
	eq(ctx.Data.get(player).tiles["2"].canUsed, true)
	eq({ Farm.call(ctx, player, "Plot", "water", { tile = "2" }) }, { false, "can_used" })
end)
