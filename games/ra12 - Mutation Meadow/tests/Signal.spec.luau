local Assert = require("./mock/Assert")
local Engine = require("./mock/Engine")

local test, eq = Assert.test, Assert.eq

local function setup()
	local engine = Engine.new()
	return engine, engine:require(engine:module("Shared/Signal"))
end

test("Fire passes arguments to every listener", function()
	local _, Signal = setup()
	local s = Signal.new()
	local got = {}
	s:Connect(function(a, b)
		table.insert(got, { a, b })
	end)
	s:Connect(function(a, b)
		table.insert(got, { b, a })
	end)
	s:Fire(1, "x")
	eq(got, { { 1, "x" }, { "x", 1 } })
end)

test("connecting while firing waits for the next Fire", function()
	local _, Signal = setup()
	local s = Signal.new()
	local calls = 0
	s:Connect(function()
		calls += 1
		s:Connect(function()
			calls += 100
		end)
	end)
	s:Fire()
	eq(calls, 1)
	s:Fire()
	eq(calls, 1 + 1 + 100)
end)

test("disconnecting inside a handler", function()
	local _, Signal = setup()
	local s = Signal.new()
	local log = {}
	local second
	local first
	first = s:Connect(function()
		table.insert(log, "first")
		first:Disconnect()
		second:Disconnect()
	end)
	second = s:Connect(function()
		table.insert(log, "second")
	end)
	s:Fire()
	s:Fire()
	eq(log, { "first" })
	eq(first.Connected, false)
end)

test("Once fires exactly once", function()
	local _, Signal = setup()
	local s = Signal.new()
	local n = 0
	s:Once(function()
		n += 1
		s:Fire() -- re-entrant fire must not run it again
	end)
	s:Fire()
	s:Fire()
	eq(n, 1)
end)

test("Wait returns the fired arguments", function()
	local engine, Signal = setup()
	local s = Signal.new()
	local got
	engine.task.spawn(function()
		got = table.pack(s:Wait())
	end)
	Assert.truthy(got == nil, "still waiting")
	engine.task.delay(2, function()
		s:Fire("a", 2, nil, true)
	end)
	engine:advance(3)
	eq(got.n, 4)
	eq({ got[1], got[2], got[3], got[4] }, { "a", 2, nil, true })
end)

test("DisconnectAll", function()
	local _, Signal = setup()
	local s = Signal.new()
	local n = 0
	local c = s:Connect(function()
		n += 1
	end)
	s:DisconnectAll()
	s:Fire()
	eq(n, 0)
	eq(c.Connected, false)
end)
