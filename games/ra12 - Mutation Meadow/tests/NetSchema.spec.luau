local Assert = require("./mock/Assert")
local Engine = require("./mock/Engine")

local test, eq = Assert.test, Assert.eq

local engine = Engine.new()
local S = engine:require(engine:module("Shared/NetSchema"))

local function ok(validator, value)
	return (validator.check(value)) == true
end

test("int: range, NaN, ±inf, 1e309, fractions, strings", function()
	local v = S.int(1, 10)
	eq({ ok(v, 1), ok(v, 10), ok(v, 5) }, { true, true, true })
	eq(
		{ ok(v, 0), ok(v, 11), ok(v, 1.5), ok(v, 0 / 0), ok(v, math.huge), ok(v, -math.huge) },
		{ false, false, false, false, false, false }
	)
	eq(ok(S.int(-math.huge, math.huge), 1e309), false, "1e309 is inf")
	eq(ok(v, "5"), false)
	eq(ok(v, nil), false)
end)

test("num and bool", function()
	eq(
		{ ok(S.num(), 1.5), ok(S.num(), -3), ok(S.num(), 0 / 0), ok(S.num(), 1e309), ok(S.num(0, 1), 2) },
		{ true, true, false, false, false }
	)
	eq(
		{ ok(S.bool, true), ok(S.bool, false), ok(S.bool, "true"), ok(S.bool, 1), ok(S.bool, nil) },
		{ true, true, false, false, false }
	)
end)

test("str: length in characters, invalid UTF-8, a 2 KB string", function()
	local v = S.str(5)
	eq({ ok(v, ""), ok(v, "abcde"), ok(v, "🌻🌻🌻🌻🌻") }, { true, true, true })
	eq({ ok(v, "abcdef"), ok(v, "\255\254"), ok(v, 5) }, { false, false, false })
	eq(ok(S.str(64), string.rep("x", 2048)), false)
end)

test("pattern, enum, guid, tileId", function()
	local date = S.pattern("^%d%d%d%d%-%d%d%-%d%d$")
	eq(
		{ ok(date, "2026-10-24"), ok(date, "2026-1-24"), ok(date, "\255"), ok(date, 20261024) },
		{ true, false, false, false }
	)
	local e = S.enum({ "a", 5 })
	eq({ ok(e, "a"), ok(e, 5), ok(e, "b"), ok(e, 0 / 0), ok(e, "5") }, { true, true, false, false, false })
	eq(ok(S.guid, "0123ABCD-0000-0000-0000-000000000001"), true)
	eq(ok(S.guid, "0123abcd-0000-0000-0000-00000000000g"), false)
	eq(ok(S.guid, "{0123ABCD-0000-0000-0000-000000000001}"), false)
	for _, t in { "1", "9", "10", "64", "extra1", "extra8" } do
		eq(ok(S.tileId, t), true, t)
	end
	for _, t in { "0", "65", "01", "extra0", "extra9", "extra", "1 ", 1, "-1", "6.5" } do
		eq(ok(S.tileId, t), false, tostring(t))
	end
end)

test("opt, struct (strict), array, oneOf", function()
	local s = S.struct({ a = S.int(1, 2), b = S.opt(S.bool) })
	eq({ ok(s, { a = 1 }), ok(s, { a = 2, b = true }) }, { true, true })
	eq(
		{ ok(s, {}), ok(s, { a = 1, c = 1 }), ok(s, { a = 1, b = 1 }), ok(s, { 1 }), ok(s, "x") },
		{ false, false, false, false, false }
	)
	local a = S.array(S.str(3), 2)
	eq({ ok(a, {}), ok(a, { "x", "y" }) }, { true, true })
	eq(
		{ ok(a, { "x", "y", "z" }), ok(a, { [2] = "x" }), ok(a, { x = "y" }), ok(a, { 1 }) },
		{ false, false, false, false }
	)
	local o = S.oneOf(S.struct({ x = S.bool }), S.struct({ y = S.bool }))
	eq(
		{ ok(o, { x = true }), ok(o, { y = false }), ok(o, { x = true, y = true }), ok(o, {}) },
		{ true, true, false, false }
	)
end)

test("global rules: plain tables, no Instances, 16 keys, depth 3, 1 KB", function()
	eq(S.checkGlobal({ a = 1, b = { c = { d = 1 } } }), true)
	eq(S.checkGlobal(setmetatable({}, {})), false, "metatable")
	eq(S.checkGlobal({ inner = setmetatable({}, {}) }), false, "nested metatable")
	eq(S.checkGlobal({ part = engine.Instance.new("Part") }), false, "Instance value")
	eq(S.checkGlobal(engine.Instance.new("Part")), false, "Instance payload")
	eq(S.checkGlobal({ f = print }), false, "function")
	eq(S.checkGlobal({ a = { b = { c = { d = 1 } } } }), false, "depth 4")
	local many = {}
	for i = 1, 17 do
		many["k" .. i] = i
	end
	eq(S.checkGlobal(many), false, "17 keys")
	eq(S.checkGlobal({ s = string.rep("x", 2048) }), false, "2 KB")
	eq(S.checkGlobal("x"), false)
	eq(S.checkGlobal(nil), false)
end)

test("validate: actions, reqId, extra keys", function()
	local okv, body, reqId = S.validate("Shop", "buySeed", { seed = "corn", qty = 1, reqId = 7 })
	eq({ okv, body, reqId }, { true, { seed = "corn", qty = 1 }, 7 })
	eq({ S.validate("Shop", "buySeed", { seed = "corn", qty = 1, reqId = 0 }) }, { false, "schema", "reqId" })
	eq({ S.validate("Shop", "buySeed", { seed = "corn", qty = 1, reqId = 2 ^ 31 + 1 }) }, { false, "schema", "reqId" })
	eq((S.validate("Shop", "buySeed", { seed = "corn", qty = 1, extra = true })), false)
	eq({ S.validate("Shop", "rob", {}) }, { false, "unknown_action" })
	eq({ S.validate("Nope", "x", {}) }, { false, "unknown_action" })
	eq({ S.validate("Shop", 5, {}) }, { false, "unknown_action" })
end)

test("the GUID pattern is the one ItemModel uses", function()
	local ItemModel = engine:require(engine:module("Server/Items/ItemModel"))
	eq(ItemModel.GUID_PATTERN, S.GUID_PATTERN)
end)
