local Assert = require("./mock/Assert")
local Server = require("./mock/Server")

local test, eq, near = Assert.test, Assert.eq, Assert.near

test("8 players flush in one close, each released", function()
	local engine, DataService = Server.boot()
	local players = {}
	for id = 1, 8 do
		players[id] = Server.join(engine, id, 0)
	end
	engine:advance(10)
	for id, player in players do
		DataService.get(player).coins = 1000 + id
	end
	eq(#engine.closeHandlers, 1)
	local result
	local start = engine.now
	engine:run(function()
		result = engine.closeHandlers[1]()
	end)
	engine:advance(1)
	eq(result, true)
	Assert.truthy(engine.now - start < 1.5, "fast")
	for id = 1, 8 do
		local raw = Server.raw(engine, id)
		eq(raw.coins, 1000 + id)
		eq(raw.lock, nil, `u_{id} released`)
		eq(#engine.dataStores._writes("MM_Profiles_v1", "u_" .. id), 2, "load + close")
	end
	engine:advance(300)
	eq(#engine.dataLog, 16, "no autosaves after close")
end)

test("a hung store: close returns at 25s", function()
	local engine = Server.boot()
	Server.join(engine, 1)
	Server.join(engine, 2)
	engine:advance(10)
	engine.dataStores._hang("MM_Profiles_v1")
	local result, finishedAt
	local start = engine.now
	engine:run(function()
		result = engine.closeHandlers[1]()
		finishedAt = engine.now
	end)
	engine:advance(30)
	eq(result, false)
	near(finishedAt - start, 25, 0.2)
end)

test("leaving runs the Leaving hooks, then the final save with lock = nil", function()
	local engine, DataService = Server.boot()
	local player = Server.join(engine, 3)
	local writesAtLeaving
	DataService.Leaving:Connect(function(p, profile)
		eq(p, player)
		profile.coins = 4242
		writesAtLeaving = #engine.dataStores._writes("MM_Profiles_v1", "u_3")
	end)
	engine:advance(10)
	engine:removePlayer(player)
	engine:advance(1)
	eq(writesAtLeaving, 1, "hooks ran before the final save")
	local raw = Server.raw(engine, 3)
	eq(raw.lock, nil)
	eq(raw.coins, 4242)
	eq(DataService.get(player), nil)
end)

test("coins persist across a rejoin", function()
	local engine, DataService = Server.boot()
	local player = Server.join(engine, 3)
	DataService.get(player).coins = 321
	engine:advance(10)
	engine:removePlayer(player)
	engine:advance(10)
	local again = Server.join(engine, 3)
	eq(DataService.get(again).coins, 321)
end)

test("a player who leaves mid-load gives the lock back", function()
	local engine, DataService = Server.boot()
	engine.dataStores._put("MM_Profiles_v1", "u_5", { v = 1, lock = { jobId = "other", at = engine.now - 295 } })
	local player = Server.join(engine, 5, 0.1)
	engine:advance(6) -- the lock goes stale and the retry at t = 7 would load...
	engine:removePlayer(player) -- ...but they left at t = 6.1
	engine:advance(30)
	eq(DataService.get(player), nil)
	eq(#engine.dataStores._writes("MM_Profiles_v1", "u_5"), 0, "never loaded")
end)
