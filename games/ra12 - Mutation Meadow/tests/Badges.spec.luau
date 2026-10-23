local Assert = require("./mock/Assert")
local Farm = require("./mock/Farm")
local Server = require("./mock/Server")

local test, eq = Assert.test, Assert.eq

local KEYS = {
	"welcome",
	"first_harvest",
	"first_splash",
	"first_golden",
	"first_wetgolden",
	"master_gardener",
	"week_of_sprouts",
	"full_meadow",
	"moonstruck",
	"sunflower_friend",
}

local function withIds()
	return Farm.setup(nil, function(engine)
		Server.patchConfig(engine, function(Config)
			for i, key in KEYS do
				Config.Badges[key].id = 100 + i
			end
		end)
	end)
end

local function awardsFor(ctx, userId)
	local out = {}
	for _, a in ctx.engine.badgesAwarded do
		if a.userId == userId then
			out[a.id] = (out[a.id] or 0) + 1
		end
	end
	return out
end

-- one of every trigger, twice where it can repeat
local function playEverything(ctx, p)
	local profile = ctx.Data.get(p)
	-- first_harvest, moonstruck
	for _, seed in { "carrot", "carrot", "moonmelon", "moonmelon" } do
		Farm.crop(ctx, p, "1", seed, true)
		eq(Farm.call(ctx, p, "Plot", "harvest", { tile = "1" }), true, "harvest " .. seed)
		profile.tiles["1"] = nil
		profile.basket = {}
	end
	-- first_splash, first_golden, first_wetgolden: keeping mutated crops
	for _, muts in { { wet = true }, { golden = true }, { wet = true, golden = true }, { wet = true, golden = true } } do
		Farm.crop(ctx, p, "2", "pumpkin", true).muts = muts
		eq(Farm.call(ctx, p, "Plot", "harvest", { tile = "2" }), true, "keep")
		profile.tiles["2"] = nil
	end
	-- full_meadow: plot level 5
	for _ = 2, 5 do
		profile.coins = 10 ^ 7
		eq(Farm.call(ctx, p, "Upgrade", "buy", { kind = "plot" }), true)
	end
	-- master_gardener: the 27th find, then the 27 milestone
	for i = 1, 26 do
		profile.collection.found[ctx.Collection.ENTRIES[i]] = { at = 1, n = 1 }
	end
	ctx.engine:run(function()
		ctx.Collection.record(p, "moonmelon", "wetgolden")
	end)
	eq(Farm.call(ctx, p, "Collection", "claim", { milestone = 27 }), true)
	-- week_of_sprouts: Day 7, twice
	for cycle = 1, 2 do
		profile.daily = { day = 7, lastClaimDay = 0, streak = 6, cycle = cycle }
		eq(Farm.call(ctx, p, "Daily", "claim", {}), true)
	end
	-- sunflower_friend: the 10th Block Party reward
	ctx.engine:run(function()
		local window = ctx.BP.open(ctx.engine.now, true)
		profile.blockParty = { window = window.hour, waters = 5, rewarded = false, rewardsTotal = 9 }
		ctx.BP.bloom(ctx.engine.now)
	end)
	eq(profile.blockParty.rewardsTotal, 10)
	for _, key in KEYS do
		eq(profile.badges[key], true, key .. " from its trigger")
	end
	ctx.engine:run(function()
		for _, key in KEYS do
			ctx.Reward.award(p, key) -- a repeat never calls AwardBadge again
		end
	end)
end

test("exactly 1 AwardBadge call per badge per profile", function()
	local ctx = withIds()
	local p = Farm.join(ctx, 1)
	playEverything(ctx, p)
	local awards = awardsFor(ctx, 1)
	for i, key in KEYS do
		eq(awards[100 + i], 1, key)
		eq(ctx.Data.get(p).badges[key], true, key .. " flag")
	end
end)

test("the flag is set before the call; a badge with id 0 warns and skips, leaving no flag", function()
	local ctx = withIds()
	local p = Farm.join(ctx, 2)
	local profile = ctx.Data.get(p)
	eq(profile.badges.welcome, true, "welcome on the first join")
	local BadgeService = ctx.engine.game:GetService("BadgeService")
	local seen
	local real = BadgeService.AwardBadge
	BadgeService.AwardBadge = function(self, userId, id)
		seen = profile.badges.first_harvest
		return real(self, userId, id)
	end
	ctx.engine:run(function()
		ctx.Reward.award(p, "first_harvest")
	end)
	eq(seen, true, "flag first")
	BadgeService.AwardBadge = real

	local plain = Farm.setup()
	local q = Farm.join(plain, 3)
	eq(plain.Data.get(q).badges.welcome, nil, "id 0: no flag")
	eq(#plain.engine.badgesAwarded, 0)
end)
