local Assert = require("./mock/Assert")
local Farm = require("./mock/Farm")

local test, eq = Assert.test, Assert.eq

local function joinWith(launch, userId)
	local ctx = Farm.setup()
	ctx.engine.launchData[userId or 1] = launch
	local p = Farm.join(ctx, userId or 1)
	return ctx, p, ctx.Data.get(p)
end

local function fields(ctx, p)
	for _, call in ctx.engine.analytics do
		if call.args[1] == p and call.method == "LogCustomEvent" then
			return call.args[4]
		end
	end
	return nil
end

test("a valid ad blob is tagged, and every event carries it", function()
	local _, _, profile = joinWith('{"src":"ad","c":"spring_test-1"}')
	eq({ profile.meta.source, profile.meta.campaign }, { "ad", "spring_test-1" })
	local ctx, p = joinWith('{"src":"ad","c":"tiktok_a"}', 2)
	local f = fields(ctx, p)
	eq(f, { CustomField01 = "ad", CustomField02 = "tiktok_a", CustomField03 = "nonpayer" })
end)

test("a 201-char blob, bad JSON, c = 'a b', a long campaign or a non-ad src are organic", function()
	local long = '{"src":"ad","c":"x","pad":"' .. string.rep("p", 201) .. '"}'
	for _, raw in
		{
			long,
			"{not json",
			'{"src":"ad","c":"a b"}',
			'{"src":"ad","c":"' .. string.rep("c", 33) .. '"}',
			'{"src":"friend","c":"abc"}',
			'{"src":"ad"}',
			'"ad"',
			"",
		}
	do
		local _, _, profile = joinWith(raw)
		eq({ profile.meta.source, profile.meta.campaign }, { "organic", nil }, raw:sub(1, 40))
	end
	local _, _, none = joinWith(nil)
	eq(none.meta.source, "organic", "no LaunchData")
	local ctx = Farm.setup()
	local Telemetry = ctx.engine:require(ctx.engine:module("Server/Services/TelemetryService"))
	eq({ Telemetry.parseLaunch('{"src":"ad","c":"' .. string.rep("c", 32) .. '"}') }, { "ad", string.rep("c", 32) })
	eq(#long > 200, true)
end)

test("a second join with different LaunchData keeps the first tag", function()
	local ctx, p = joinWith('{"src":"ad","c":"first"}')
	ctx.engine:removePlayer(p)
	ctx.engine:advance(7)
	ctx.engine.launchData[1] = '{"src":"ad","c":"second"}'
	local again = Farm.join(ctx, 1)
	ctx.engine:advance(15)
	local profile = ctx.Data.get(again)
	eq({ profile.meta.source, profile.meta.campaign }, { "ad", "first" })
	local organic = Farm.setup()
	local q = Farm.join(organic, 5)
	organic.engine:removePlayer(q)
	organic.engine:advance(7)
	organic.engine.launchData[5] = '{"src":"ad","c":"late"}'
	local q2 = Farm.join(organic, 5)
	organic.engine:advance(15)
	eq(organic.Data.get(q2).meta.source, "organic", "an organic farm stays organic")
end)
