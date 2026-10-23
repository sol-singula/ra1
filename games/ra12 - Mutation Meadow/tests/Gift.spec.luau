local Assert = require("./mock/Assert")
local Server = require("./mock/Server")

local test, eq = Assert.test, Assert.eq

local T0 = 1_760_000_000

-- count GiftQueue.apply calls in an engine
local function countApplies(engine, counter)
	local GiftQueue = engine:require(engine:module("Server/Save/GiftQueue"))
	local real = GiftQueue.apply
	GiftQueue.apply = function(...)
		counter.n += 1
		return real(...)
	end
end

test("a crash between the save and the queue cleanup grants exactly once; the queue ends empty", function()
	local counter = { n = 0 }
	local a, dsA = Server.boot({ now = T0, jobId = "job-A" }, function(e)
		countApplies(e, counter)
		e.dataStores._put("MM_Gifts_v1", "u_5", { gifts = { { purchaseId = "G1", key = "vip", fromId = 9, at = T0 } } })
		e.dataStores._failNext("MM_Gifts_v1", "UpdateAsync", "500: server crashed", 1) -- step 4 never lands
	end)
	local player = Server.join(a, 5)
	a:advance(10)
	local profile = dsA.get(player)
	eq(profile.passes.vip, true)
	eq(profile.giftsIn, { "G1" })
	eq(counter.n, 1)
	eq(#a.dataStores._raw("MM_Gifts_v1").u_5.gifts, 1, "still queued after the crash")
	eq(Server.raw(a, 5).giftsIn, { "G1" }, "the grant was saved")
	-- A dies here. The player rejoins on B once A's lock is stale.
	local b, dsB = Server.boot({ now = T0 + 400, jobId = "job-B", shareDataWith = a }, function(e)
		countApplies(e, counter)
	end)
	local again = Server.join(b, 5)
	b:advance(10)
	eq(counter.n, 1, "no second grant")
	eq(dsB.get(again).passes.vip, true)
	eq(b.dataStores._raw("MM_Gifts_v1").u_5.gifts, {}, "queue empty")
end)

test("a gift queued while offline arrives on the next join", function()
	local engine, DataService = Server.boot()
	local GiftQueue = engine:require(engine:module("Server/Save/GiftQueue"))
	engine:run(GiftQueue.enqueue, 8, { purchaseId = "G2", key = "tag_star", fromId = 1, at = 0 })
	local player = Server.join(engine, 8)
	engine:advance(10)
	local profile = DataService.get(player)
	eq(profile.cosmetics.owned.tag_star, true)
	eq(profile.giftsIn, { "G2" })
	eq(engine.dataStores._raw("MM_Gifts_v1").u_8.gifts, {})
end)

test("apply: passes and cosmetics; unknown keys grant nothing", function()
	local engine, DataService = Server.boot()
	local GiftQueue = engine:require(engine:module("Server/Save/GiftQueue"))
	local p = Server.deepCopy(DataService.TEMPLATE)
	eq(GiftQueue.apply(p, "gnome"), true)
	eq(GiftQueue.apply(p, "theme_candy"), true)
	eq(GiftQueue.apply(p, "golden_hoe"), false)
	eq(p.passes, { gnome = true })
	eq(p.cosmetics.owned, { theme_candy = true })
end)

test("giftsIn keeps the last 100", function()
	local engine, DataService = Server.boot()
	local GiftQueue = engine:require(engine:module("Server/Save/GiftQueue"))
	local gifts = {}
	for i = 1, 100 do
		table.insert(gifts, { purchaseId = "G" .. i, key = "vip", fromId = 1, at = 0 })
	end
	engine.dataStores._put("MM_Gifts_v1", "u_4", { gifts = gifts })
	engine.dataStores._put("MM_Profiles_v1", "u_4", { v = 1, giftsIn = { "OLD" } })
	local player = Server.join(engine, 4)
	engine:advance(10)
	local giftsIn = DataService.get(player).giftsIn
	eq(#giftsIn, 100)
	eq(giftsIn[1], "G1", "the oldest id fell off")
	local _ = GiftQueue
end)
