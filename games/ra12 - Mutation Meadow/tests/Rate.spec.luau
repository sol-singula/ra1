local Assert = require("./mock/Assert")
local NetHelp = require("./mock/NetHelp")
local Server = require("./mock/Server")

local test, eq = Assert.test, Assert.eq

local BUY = { seed = "carrot", qty = 1 }

local function count(calls, remote)
	local n = 0
	for _, c in calls do
		if c.remote == remote then
			n += 1
		end
	end
	return n
end

test("Shop: 21 instant calls run 20 and drop 1; after 1s, 10 more run", function()
	local engine, NetService, _, player, calls = NetHelp.setup()
	for _ = 1, 21 do
		engine:fireServer(player, "Shop", "buySeed", BUY)
	end
	eq(count(calls, "Shop"), 20)
	eq(NetService.dropStats().byReason.rate, 1)
	eq(engine:clientEvents("Result", 10), {}, "dropped silently")
	engine:advance(1)
	for _ = 1, 15 do
		engine:fireServer(player, "Shop", "buySeed", BUY)
	end
	eq(count(calls, "Shop"), 30)
end)

test("buckets are per remote; Plot refills 20 in 1s", function()
	local engine, _, _, player, calls = NetHelp.setup()
	for _ = 1, 25 do
		engine:fireServer(player, "Plot", "plant", { tile = "1", seed = "carrot" })
	end
	eq(count(calls, "Plot"), 20)
	for _ = 1, 5 do
		engine:fireServer(player, "Basket", "sellAll", {})
	end
	eq(count(calls, "Basket"), 5, "a full Plot bucket doesn't touch Basket")
	engine:advance(1)
	for _ = 1, 25 do
		engine:fireServer(player, "Plot", "plant", { tile = "1", seed = "carrot" })
	end
	eq(count(calls, "Plot"), 40)
end)

test("more than 300 drops in 60s kicks", function()
	local engine, NetService, _, player = NetHelp.setup()
	for _ = 1, 300 do
		engine:fireServer(player, "Shop", "rob", {})
	end
	eq(#Server.kicksFor(engine, 10), 0, "300 is still fine")
	engine:fireServer(player, "Shop", "rob", {})
	eq(Server.kicksFor(engine, 10), { "Connection issue. Your farm is saved, please rejoin." })
	eq(NetService.dropStats().abuseKicks, 1)
	local logged = false
	for _, line in engine.output do
		logged = logged or line:find("net_abuse") ~= nil
	end
	Assert.truthy(logged, "net_abuse logged")
end)

test("drops spread past the window don't kick", function()
	local engine, _, _, player = NetHelp.setup()
	for _ = 1, 400 do
		engine:fireServer(player, "Shop", "rob", {})
		engine:advance(0.25, 0.25)
	end
	eq(#Server.kicksFor(engine, 10), 0)
end)
