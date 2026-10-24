local Assert = require("./mock/Assert")
local Server = require("./mock/Server")

local test, eq = Assert.test, Assert.eq

test("a new profile is the template (plus its lock and times)", function()
	local engine, DataService = Server.boot({ now = 1000 })
	local player = Server.join(engine, 5)
	local profile = DataService.get(player)
	Assert.truthy(profile, "loaded")
	eq(profile.coins, 50)
	eq(profile.seeds.carrot, 3)
	eq(profile.meta.created, 1000)
	eq(profile.meta.sessionStart, 1000)
	eq(profile.lock, { jobId = "job-1", at = 1000 })
	eq(profile.patchTips.plant, true, "Patch's first tip fired on the first spawn")
	local copy = Server.deepCopy(profile)
	copy.patchTips.plant = false
	copy.lock = nil
	copy.meta.created, copy.meta.lastSeen, copy.meta.sessionStart = 0, 0, 0
	eq({ copy.meta.source, copy.meta.campaign }, { "organic", nil }, "the acquisition tag (M10)")
	eq(copy.meta.funnel, { ["1"] = true }, "funnel step 1: join")
	copy.meta.source, copy.meta.funnel = nil, nil
	eq(copy, DataService.TEMPLATE)
end)

test("template defaults", function()
	local _, DataService = Server.boot()
	local T = DataService.TEMPLATE
	Assert.truthy(table.isfrozen(T) and table.isfrozen(T.settings), "frozen")
	eq({ T.v, T.coins, T.plotLevel, T.can, T.gnomeOn, T.autoSell }, { 1, 50, 1, "tin", true, false })
	eq(T.seeds, { carrot = 3 })
	eq(T.daily, { day = 1, lastClaimDay = 0, streak = 0, cycle = 1 })
	eq(T.settings, { patchAlerts = true, music = true, sfx = true, reducedFx = false })
	eq(T.patchTips, { plant = false, shopHello = false, shower = false, mutation = false, blockParty = false })
	eq(T.items, {})
	eq(T.receipts, {})
	eq(T.meta.growCredits, 0)
	eq(T.meta.pendingGifts, {})
	Assert.truthy(T.lock == nil, "no lock in the template")
end)
