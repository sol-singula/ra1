local Assert = require("./mock/Assert")
local Server = require("./mock/Server")

local test, eq = Assert.test, Assert.eq

test("profiles live in MM_Profiles_v1 under u_<userId>", function()
	local engine = Server.boot()
	Server.join(engine, 42)
	local raw = engine.dataStores._raw("MM_Profiles_v1")
	Assert.truthy(raw and raw.u_42, "u_42 stored")
	eq(raw.u_42.coins, 50)
	eq(engine.dataStores._writes("MM_Profiles_v1", "u_42")[1].method, "UpdateAsync")
end)

test("gifts live in MM_Gifts_v1 under u_<recipientId>", function()
	local engine = Server.boot()
	local GiftQueue = engine:require(engine:module("Server/Save/GiftQueue"))
	local results = {}
	engine:run(function()
		results[1] = GiftQueue.enqueue(77, { purchaseId = "G1", key = "vip", fromId = 3, at = 5 })
		engine.task.wait(7)
		results[2] = GiftQueue.enqueue(77, { purchaseId = "G1", key = "vip", fromId = 3, at = 5 })
	end)
	engine:advance(8)
	eq(results, { true, true })
	eq(
		engine.dataStores._raw("MM_Gifts_v1").u_77,
		{ gifts = { { purchaseId = "G1", key = "vip", fromId = 3, at = 5 } } }
	)
end)

test("the weekly board is the OrderedDataStore MM_Top_<updateId>", function()
	local engine = Server.boot()
	local Stores = engine:require(engine:module("Server/Save/Stores"))
	Stores.weekly("2026-10-24"):SetAsync("u_1", 10)
	eq(engine.dataStores._raw("MM_Top_2026-10-24", "ordered"), { u_1 = 10 })
end)

test("no DataStores: memory-only, a red error, no writes", function()
	local engine, DataService = Server.boot({ dataStoresOff = true })
	local Stores = engine:require(engine:module("Server/Save/Stores"))
	eq(Stores.memoryOnly, true)
	Assert.truthy(engine.errors[1] and engine.errors[1]:find("memory%-only"), "red error")
	local player = Server.join(engine, 1)
	local profile = DataService.get(player)
	Assert.truthy(profile, "plays with a fresh profile")
	local saved
	engine:run(function()
		saved = DataService.save(player, "test"):await()
	end)
	eq(saved, true)
	eq(#engine.dataLog, 0)
	eq(#engine.dataCalls, 0)
end)

test("Studio with API access off: memory-only", function()
	local engine = Server.boot({ studio = true }, function(e)
		e.dataStores._failNext(
			"MM_Profiles_v1",
			"GetAsync",
			"502: API Services rejected request with error. Error code: 0 Reason: Studio access to APIs is not allowed.",
			100
		)
	end)
	local Stores = engine:require(engine:module("Server/Save/Stores"))
	eq(Stores.memoryOnly, true)
	Server.join(engine, 1)
	eq(#engine.dataLog, 0)
end)
