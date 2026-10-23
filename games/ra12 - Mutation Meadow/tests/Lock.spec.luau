local Assert = require("./mock/Assert")
local Server = require("./mock/Server")

local test, eq, near = Assert.test, Assert.eq, Assert.near

local T0 = 1_760_000_000
local LOCK_HELD = "Your farm is safe! It's still open on another server. Rejoin in a minute."
local LOCK_LOST = "Your farm was opened on another server. Your progress is saved."

local function fixture(engine, userId, lock, extra)
	local p = { v = 1, coins = 123, lock = lock, meta = { created = 1, lastSeen = 1, sessionStart = 1 } }
	for k, v in extra or {} do
		p[k] = v
	end
	engine.dataStores._put("MM_Profiles_v1", "u_" .. userId, p)
end

test("a fresh foreign lock blocks the load and kicks after exactly 5 retries (31s)", function()
	local engine, DataService = Server.boot({ now = T0 })
	fixture(engine, 9, { jobId = "other", at = T0 })
	local player = Server.join(engine, 9, 0.1)
	eq(DataService.get(player), nil)
	eq({ DataService.check(player) }, { false, "not_loaded" })
	engine:advance(30.8) -- t = 30.9: attempts at 0, 1, 3, 7, 15
	eq(engine.dataStores._calls("MM_Profiles_v1", "u_9", "UpdateAsync"), 5)
	eq(#Server.kicksFor(engine, 9), 0)
	engine:advance(0.3) -- t = 31.2: the 6th attempt (5th retry), then the kick
	eq(engine.dataStores._calls("MM_Profiles_v1", "u_9", "UpdateAsync"), 6)
	eq(Server.kicksFor(engine, 9), { LOCK_HELD })
	eq(#engine.dataStores._writes("MM_Profiles_v1", "u_9"), 0)
	eq(Server.raw(engine, 9).lock, { jobId = "other", at = T0 })
end)

test("a stale lock (now - 301) is taken over", function()
	local engine, DataService = Server.boot({ now = T0 })
	fixture(engine, 9, { jobId = "other", at = T0 - 301 })
	local player = Server.join(engine, 9)
	local profile = DataService.get(player)
	Assert.truthy(profile, "loaded")
	eq(profile.coins, 123)
	eq(Server.raw(engine, 9).lock, { jobId = "job-1", at = T0 })
	eq(#Server.kicksFor(engine, 9), 0)
end)

test("the same JobId reloads", function()
	local engine, DataService = Server.boot({ now = T0 })
	fixture(engine, 9, { jobId = "job-1", at = T0 - 5 })
	local player = Server.join(engine, 9)
	Assert.truthy(DataService.get(player), "loaded")
	eq(DataService.check(player), true)
end)

test("autosaves are 90s apart, offset by userId % 90, and refresh the lock (heartbeat)", function()
	local engine = Server.boot({ now = T0 })
	Server.join(engine, 7)
	Server.join(engine, 95, 0)
	engine:advance(200)
	local w7 = engine.dataStores._writes("MM_Profiles_v1", "u_7")
	eq(#w7, 3, "load + 2 autosaves")
	near(w7[2].at - w7[1].at, 90 + 7, 1, "first autosave")
	near(w7[3].at - w7[2].at, 90, 1, "then every 90s")
	local w95 = engine.dataStores._writes("MM_Profiles_v1", "u_95")
	near(w95[2].at - w95[1].at, 90 + 5, 1, "95 % 90 = 5")
	local raw = Server.raw(engine, 7)
	eq(raw.lock.jobId, "job-1")
	eq(raw.lock.at, w7[3].at)
	eq(raw.meta.lastSeen, w7[3].at)
end)

test("a stolen lock kicks within one autosave and nothing is written after", function()
	local engine, DataService = Server.boot({ now = T0 })
	local player = Server.join(engine, 8)
	engine:advance(10)
	local raw = Server.raw(engine, 8)
	raw.lock = { jobId = "other", at = engine.now }
	raw.coins = 777
	local writesBefore = #engine.dataStores._writes("MM_Profiles_v1", "u_8")
	engine:advance(90)
	eq(Server.kicksFor(engine, 8), { LOCK_LOST })
	eq(DataService.get(player), nil)
	engine:advance(300)
	eq(#engine.dataStores._writes("MM_Profiles_v1", "u_8"), writesBefore)
	eq(Server.raw(engine, 8).coins, 777)
	eq(Server.raw(engine, 8).lock.jobId, "other")
end)

test("two servers: the second retries, then loads once the first releases; the item is never in both", function()
	local a, dsA = Server.boot({ now = T0, jobId = "job-A" })
	local playerA = Server.join(a, 3)
	local ItemModelA = a:require(a:module("Server/Items/ItemModel"))
	local guid = ItemModelA.mint(dsA.get(playerA), 3, "carrot", { wet = true })
	a:advance(10)

	local b, dsB = Server.boot({ now = T0 + 10, jobId = "job-B", shareDataWith = a })
	local playerB = Server.join(b, 3, 0.1)
	eq(dsB.get(playerB), nil, "held by A")
	b:advance(2)
	a:removePlayer(playerA) -- A's final save releases the lock
	a:advance(1)
	eq(Server.raw(a, 3).lock, nil)
	b:advance(30)
	local profile = dsB.get(playerB)
	Assert.truthy(profile, "B loaded after A released")
	eq(#Server.kicksFor(b, 3), 0)
	Assert.truthy(profile.items[guid], "the item moved with the farm")
	eq(ItemModelA.registry[guid], nil, "and A forgot it")
end)

test("after a server dies, a rejoin is refused until the lock is stale (300s), then loads", function()
	local a = Server.boot({ now = T0, jobId = "job-A" })
	Server.join(a, 4)
	a:advance(5) -- A dies here: no final save

	local b, dsB = Server.boot({ now = T0 + 200, jobId = "job-B", shareDataWith = a })
	Server.join(b, 4, 0.1)
	b:advance(32)
	eq(Server.kicksFor(b, 4), { LOCK_HELD })

	local c, dsC = Server.boot({ now = T0 + 301, jobId = "job-C", shareDataWith = a })
	local player = Server.join(c, 4)
	Assert.truthy(dsC.get(player), "loads once the lock is stale")
	eq(Server.raw(c, 4).lock.jobId, "job-C")
	local _ = dsB
end)
