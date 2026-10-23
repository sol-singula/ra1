local Assert = require("./mock/Assert")
local NetHelp = require("./mock/NetHelp")
local Server = require("./mock/Server")

local test, eq = Assert.test, Assert.eq

test("1000 junk calls: at most one warning per reason, counters equal the calls", function()
	local engine, NetService, _, player = NetHelp.setup()
	engine.dataStores._put("MM_Profiles_v1", "u_20", { v = 1, lock = { jobId = "other", at = engine.now } })
	local waiting = Server.join(engine, 20, 0.1)
	local junk = {
		function(p)
			engine:fireServer(p, "Shop", "rob", {})
		end,
		function(p)
			engine:fireServer(p, "Plot", "plant", { tile = "0" })
		end,
		function(p)
			engine:fireServer(p, "Settings", "set", { key = "music", value = true })
		end,
		function(p)
			engine:fireServer(p, "Gift", 7, nil)
		end,
	}
	for i = 1, 1000 do
		junk[i % #junk + 1](i % 2 == 0 and player or waiting)
	end
	local stats = NetService.dropStats()
	local total = 0
	for reason, n in stats.byReason do
		total += n
		Assert.truthy(table.find(NetService.REASONS, reason), reason)
	end
	-- the loaded player's valid Settings.set calls that got through the bucket are not drops
	local valid = 1000 - total
	Assert.truthy(valid >= 0 and valid <= 20, `{valid} calls ran`)
	local perPlayer = 0
	for _, reasons in stats.byPlayer do
		for _, n in reasons do
			perPlayer += n
		end
	end
	eq(perPlayer, total)
	for reason, n in NetHelp.warnings(engine) do
		Assert.truthy(n <= 2, `{reason} warned {n} times`) -- once per player
	end
	local onlyPlayer = {}
	for _, line in engine.output do
		local reason, uid = line:match("^%[warn%] %[Net%] dropped (%S+) from (%-?%d+)")
		if reason then
			local key = reason .. uid
			Assert.truthy(not onlyPlayer[key], `second warning for {key}`)
			onlyPlayer[key] = true
		end
	end
end)

test("counters count every drop exactly", function()
	local engine, NetService, _, player = NetHelp.setup()
	for _ = 1, 1000 do
		engine:fireServer(player, "Shop", "rob", {})
	end
	local stats = NetService.dropStats()
	eq((stats.byReason.unknown_action or 0) + (stats.byReason.rate or 0), 1000)
	eq(stats.byReason.unknown_action, 20)
	eq(stats.byPlayer[10].rate, 980)
	eq(NetHelp.warnings(engine), { unknown_action = 1, rate = 1 })
end)
