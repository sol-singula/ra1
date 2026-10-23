local Assert = require("./mock/Assert")
local Engine = require("./mock/Engine")

local test, eq = Assert.test, Assert.eq

local function setup(opts)
	local engine = Engine.new({ now = 1000 })
	local SaveQueue = engine:require(engine:module("Server/Save/SaveQueue"))
	local DSS = engine.game:GetService("DataStoreService")
	local store = DSS:GetDataStore("Q")
	local live = { n = 0 }
	local lost = 0
	opts = opts or {}
	SaveQueue.track("k", {
		store = if opts.memory then nil else store,
		snapshot = function()
			return live
		end,
		transform = opts.transform or function(_, copy)
			return copy
		end,
		onLockLost = function()
			lost += 1
		end,
		budget = function()
			return DSS:GetRequestBudgetForRequestType(engine.Enum.DataStoreRequestType.UpdateAsync)
		end,
	})
	return engine, SaveQueue, live, function()
		return lost
	end
end

local function writes(engine)
	return engine.dataStores._writes("Q", "k")
end

test("10 requests in 1s make 2 writes; every waiter resolves true; the latest state lands", function()
	local engine, SaveQueue, live = setup()
	local promises = {}
	engine:run(function()
		for i = 1, 10 do
			live.n = i
			table.insert(promises, SaveQueue.request("k", "t"))
			engine.task.wait(0.1)
		end
	end)
	engine:advance(10)
	local w = writes(engine)
	eq(#w, 2)
	eq(w[1].at, 1000)
	eq(w[2].at, 1006)
	for i, p in promises do
		eq(p.value, true, "waiter " .. i)
	end
	eq(engine.dataStores._raw("Q").k.n, 10, "copied at write time")
end)

test("no two writes to a key are less than 6s apart", function()
	local engine, SaveQueue, live = setup()
	local rng = engine.Random.new(3)
	engine:run(function()
		for i = 1, 60 do
			live.n = i
			SaveQueue.request("k", "t")
			engine.task.wait(rng:NextNumber(0, 2))
		end
	end)
	engine:advance(200)
	local w = writes(engine)
	Assert.truthy(#w >= 5, "several writes")
	for i = 2, #w do
		Assert.truthy(w[i].at - w[i - 1].at >= 6, `writes {i - 1} and {i} are {w[i].at - w[i - 1].at}s apart`)
	end
	eq(engine.dataStores._raw("Q").k.n, 60)
end)

test("3 failures then success cost exactly 4 attempts (+1, +3, +7)", function()
	local engine, SaveQueue = setup()
	engine.dataStores._failNext("Q", "UpdateAsync", "500: busy", 3)
	local p = SaveQueue.request("k", "t")
	engine:advance(20)
	eq(p.value, true)
	eq(engine.dataStores._calls("Q", "k", "UpdateAsync"), 4)
	local at = {}
	for _, c in engine.dataCalls do
		table.insert(at, c.at - 1000)
	end
	eq(at, { 0, 1, 4, 11 })
	eq(SaveQueue.state("k").attempts, 4)
end)

test("4 failures resolve false after 4 attempts", function()
	local engine, SaveQueue = setup()
	engine.dataStores._failNext("Q", "UpdateAsync", "500: busy", 10)
	local p = SaveQueue.request("k", "t")
	engine:advance(30)
	eq(p.value, false)
	eq(engine.dataStores._calls("Q", "k", "UpdateAsync"), 4)
end)

test("a lost lock never retries and stops the queue", function()
	local engine, SaveQueue, _, lost = setup({
		transform = function()
			return nil
		end,
	})
	local p = SaveQueue.request("k", "t")
	engine:advance(30)
	eq(p.value, false)
	eq(lost(), 1)
	eq(engine.dataStores._calls("Q", "k", "UpdateAsync"), 1)
	local later = SaveQueue.request("k", "t")
	eq(later.done and later.value, false)
	engine:advance(30)
	eq(engine.dataStores._calls("Q", "k", "UpdateAsync"), 1)
end)

test("an empty budget waits 1s at a time", function()
	local engine, SaveQueue = setup()
	engine.dataStores._setBudget("UpdateAsync", 0)
	local p = SaveQueue.request("k", "t")
	engine:advance(3)
	eq(engine.dataStores._calls("Q"), 0)
	engine.dataStores._setBudget("UpdateAsync", 10)
	engine:advance(1.2)
	eq(p.value, true)
	eq(#writes(engine), 1)
end)

test("memory-only resolves true and never writes", function()
	local engine, SaveQueue = setup({ memory = true })
	eq(SaveQueue.request("k", "t").value, true)
	eq(#engine.dataCalls, 0)
end)
