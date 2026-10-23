local Assert = require("./mock/Assert")
local Farm = require("./mock/Farm")

local test, eq = Assert.test, Assert.eq

local function starterToasts(ctx, p)
	local out = {}
	for _, t in Farm.toasts(ctx, p) do
		if t.kind == "quest" then
			table.insert(out, t.text)
		end
	end
	return out
end

local function harvestCarrot(ctx, p)
	Farm.crop(ctx, p, "1", "carrot", true)
	eq(Farm.call(ctx, p, "Plot", "harvest", { tile = "1" }), true)
	ctx.Data.get(p).tiles["1"] = nil
end

local function finishStarters(profile)
	for _, key in { "harvest5", "plot2", "keepMut", "pedestal", "help1" } do
		profile.quests.starter[key] = { n = 1, claimed = true }
	end
end

test("FTUE path: Starter 1 at the 5th harvest, Starter 2 at level 2 refunds the 100", function()
	local ctx = Farm.setup()
	local p = Farm.join(ctx, 1)
	local profile = ctx.Data.get(p)
	for i = 1, 4 do
		harvestCarrot(ctx, p)
		eq(starterToasts(ctx, p), {}, `nothing at harvest {i}`)
	end
	local coins = profile.coins
	harvestCarrot(ctx, p)
	eq(starterToasts(ctx, p), { "Starter 1 done: 50 coins" })
	eq(profile.coins, coins + 50)
	eq(profile.quests.starter.harvest5, { n = 5, claimed = true })
	profile.coins = 100
	eq(Farm.call(ctx, p, "Upgrade", "buy", { kind = "plot" }), true)
	eq(starterToasts(ctx, p)[2], "Starter 2 done: 100 coins")
	eq(profile.coins, 100, "the upgrade paid for itself")
	eq({ Farm.call(ctx, p, "Quest", "claim", { questId = "harvest5" }) }, { false, "auto" })
end)

test("daily quests stay locked until all 5 starters are done", function()
	local ctx = Farm.setup()
	local p = Farm.join(ctx, 1)
	local profile = ctx.Data.get(p)
	for _ = 1, 3 do
		harvestCarrot(ctx, p)
	end
	eq(profile.quests.daily.progress.harvest30, nil, "no progress while locked")
	eq({ Farm.call(ctx, p, "Quest", "claim", { questId = "harvest30" }) }, { false, "locked" })
	finishStarters(profile)
	harvestCarrot(ctx, p)
	eq(profile.quests.daily.progress.harvest30, 1)
	eq({ Farm.call(ctx, p, "Quest", "claim", { questId = "harvest30" }) }, { false, "not_done" })
end)

test("sunflower5 counts waters and pays 300 x L^2 once; the dailies reset at 00:00 UTC", function()
	local ctx = Farm.setup()
	local p = Farm.join(ctx, 1)
	local profile = ctx.Data.get(p)
	finishStarters(profile)
	profile.plotLevel = 2
	ctx.engine:run(function()
		ctx.BP.open(ctx.engine.now, true)
	end)
	Farm.standAtSunflower(ctx, p)
	for i = 1, 5 do
		eq(Farm.call(ctx, p, "BlockParty", "water", {}), true, "water " .. i)
		ctx.engine:advance(2)
	end
	eq(profile.quests.daily.progress.sunflower5, 5)
	local coins = profile.coins
	eq(Farm.call(ctx, p, "Quest", "claim", { questId = "sunflower5" }), true)
	eq(profile.coins, coins + 1200)
	eq({ Farm.call(ctx, p, "Quest", "claim", { questId = "sunflower5" }) }, { false, "claimed" })
	ctx.engine.workspace:SetAttribute("ClockOffset", 86400)
	eq({ Farm.call(ctx, p, "Quest", "claim", { questId = "sunflower5" }) }, { false, "not_done" }, "a new day")
	eq(profile.quests.daily.progress, {})
end)

test("playtime: gift 1 at level 2 pays 400, gift 2 gives 2 corn; once a day; not before its time", function()
	local ctx = Farm.setup()
	local p = Farm.join(ctx, 1)
	local profile = ctx.Data.get(p)
	profile.plotLevel = 2
	eq({ Farm.call(ctx, p, "Playtime", "claim", { index = 1 }) }, { false, "not_yet" })
	ctx.engine:advance(301)
	local coins = profile.coins
	eq(Farm.call(ctx, p, "Playtime", "claim", { index = 1 }), true)
	eq(profile.coins, coins + 400)
	eq({ Farm.call(ctx, p, "Playtime", "claim", { index = 1 }) }, { false, "claimed" })
	eq({ Farm.call(ctx, p, "Playtime", "claim", { index = 2 }) }, { false, "not_yet" })
	ctx.engine:advance(300)
	local corn = profile.seeds.corn or 0
	eq(Farm.call(ctx, p, "Playtime", "claim", { index = 2 }), true)
	eq(profile.seeds.corn, corn + 2, "corn is the top tier at level 2")
	eq({ Farm.call(ctx, p, "Playtime", "claim", { index = 2 }) }, { false, "claimed" })
	eq(ctx.Reward.topTierSeed(profile), "corn")
	profile.plotLevel = 4
	eq(ctx.Reward.topTierSeed(profile), "dragonfruit", "never the event-only Moon Melon")
end)
