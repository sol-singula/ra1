-- The mock engine itself: the clock, the DataStore rules and the recorded services later specs rely on
local Assert = require("./mock/Assert")
local Engine = require("./mock/Engine")

local test, eq = Assert.test, Assert.eq

test("task.wait and task.delay follow the virtual clock", function()
	local engine = Engine.new({ now = 100 })
	local log = {}
	engine:run(function()
		engine.task.delay(5, function()
			table.insert(log, "delay " .. engine.now)
		end)
		local waited = engine.task.wait(2)
		table.insert(log, "wait " .. waited)
	end)
	eq(log, {})
	engine:advance(10)
	eq(log, { "wait 2", "delay 105" })
	eq(engine.os.time(), 110)
end)

test("DataStore: same-key cooldown, UpdateAsync, injected errors, budget", function()
	local engine = Engine.new()
	local DSS = engine.game:GetService("DataStoreService")
	local store = DSS:GetDataStore("S")
	store:SetAsync("k", { a = 1 })
	Assert.throws(function()
		store:SetAsync("k", { a = 2 })
	end, "cooldown")
	store:SetAsync("other", 1) -- another key is fine
	engine:advance(6)
	eq(
		store:UpdateAsync("k", function(old)
			old.a += 1
			return old
		end),
		{ a = 2 }
	)
	engine:advance(6)
	eq(
		store:UpdateAsync("k", function()
			return nil
		end),
		nil
	)
	eq(store:GetAsync("k"), { a = 2 }, "a cancelled update writes nothing")
	local copy = store:GetAsync("k")
	copy.a = 99
	eq(store:GetAsync("k"), { a = 2 }, "reads are copies")
	engine.dataStores._failNext("S", "GetAsync", "503: down")
	Assert.throws(function()
		store:GetAsync("k")
	end, "503")
	eq(store:GetAsync("k"), { a = 2 })
	local before = DSS:GetRequestBudgetForRequestType(engine.Enum.DataStoreRequestType.GetAsync)
	store:GetAsync("k")
	eq(DSS:GetRequestBudgetForRequestType(engine.Enum.DataStoreRequestType.GetAsync), before - 1)
end)

test("OrderedDataStore sorts and pages", function()
	local engine = Engine.new()
	local ods = engine.game:GetService("DataStoreService"):GetOrderedDataStore("Top")
	for i = 1, 5 do
		ods:SetAsync("u" .. i, i * 10)
	end
	local pages = ods:GetSortedAsync(false, 2)
	eq(pages:GetCurrentPage(), { { key = "u5", value = 50 }, { key = "u4", value = 40 } })
	pages:AdvanceToNextPageAsync()
	eq(pages:GetCurrentPage()[1], { key = "u3", value = 30 })
end)

test("recorded services and deterministic Random", function()
	local engine = Engine.new()
	engine.game:GetService("AnalyticsService"):LogCustomEvent("p", "x", 1)
	eq(engine.analytics[1].method, "LogCustomEvent")
	local http = engine.game:GetService("HttpService")
	Assert.truthy(http:GenerateGUID(false) ~= http:GenerateGUID(false))
	eq(http:JSONDecode(http:JSONEncode({ a = 1 })), { a = 1 })
	local a, b = engine.Random.new(7), engine.Random.new(7)
	eq(a:NextInteger(1, 1000), b:NextInteger(1, 1000))
end)
