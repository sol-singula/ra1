local Assert = require("./mock/Assert")
local Farm = require("./mock/Farm")

local test, eq = Assert.test, Assert.eq

local DAY = 86400

-- moves the virtual clock (the Studio ClockOffset) to `days` after the start
local function onDay(ctx, days)
	ctx.engine.workspace:SetAttribute("ClockOffset", days * DAY)
end

local function claim(ctx, p)
	return { Farm.call(ctx, p, "Daily", "claim", {}) }
end

test("two claims in one day give one grant", function()
	local ctx = Farm.setup()
	local p = Farm.join(ctx, 1)
	local profile = ctx.Data.get(p)
	local coins = profile.coins
	eq(claim(ctx, p), { true })
	eq(claim(ctx, p), { false, "claimed_today" })
	eq(profile.coins, coins + 100)
	eq(profile.daily.day, 2)
	eq(profile.daily.streak, 1)
end)

test("claims on days 1, 2, 5 and 9 give calendar days 1-4 (a missed day pauses)", function()
	local ctx = Farm.setup()
	local p = Farm.join(ctx, 1)
	local profile = ctx.Data.get(p)
	local coins, seeds = profile.coins, table.clone(profile.seeds)
	for _, d in { 0, 1, 4, 8 } do
		onDay(ctx, d)
		eq(claim(ctx, p), { true }, `day {d + 1}`)
	end
	eq(profile.coins, coins + 100 + 500)
	eq(profile.seeds.pumpkin, 1)
	eq(profile.seeds.corn, 3)
	eq(profile.seeds.carrot, seeds.carrot)
	eq({ profile.daily.day, profile.daily.streak, profile.daily.cycle }, { 5, 4, 1 })
end)

test("day 7: cycle 1 gives the petal trail, cycle 2 gives 2500; both restart at day 1", function()
	local ctx = Farm.setup()
	local p = Farm.join(ctx, 1)
	local profile = ctx.Data.get(p)
	profile.daily = { day = 7, lastClaimDay = 0, streak = 6, cycle = 1 }
	local coins = profile.coins
	eq(claim(ctx, p), { true })
	eq(profile.cosmetics.owned.trail_petals, true)
	eq(profile.seeds.pumpkin, 5)
	eq(profile.coins, coins)
	eq({ profile.daily.day, profile.daily.cycle }, { 1, 2 })
	profile.cosmetics.owned.trail_petals = nil
	profile.daily.day = 7
	onDay(ctx, 1)
	eq(claim(ctx, p), { true })
	eq(profile.coins, coins + 2500)
	eq(profile.seeds.pumpkin, 10)
	eq(profile.cosmetics.owned.trail_petals, nil, "the trail only on the first cycle")
	eq({ profile.daily.day, profile.daily.cycle }, { 1, 3 })
end)
