local Assert = require("./mock/Assert")
local Server = require("./mock/Server")

local test, eq = Assert.test, Assert.eq

local TOO_NEW = "New update ready! Rejoin to get it. Your farm is saved."

-- every key of the template exists in p (recursing, except into maps filled whole)
local function hasEveryKey(p, template, skip, path)
	for k, v in template do
		Assert.truthy(p[k] ~= nil, `{path}.{k} missing`)
		if type(v) == "table" and not (skip and skip[k]) then
			hasEveryKey(p[k], v, nil, path .. "." .. k)
		end
	end
end

test("a v0 profile reaches v1 with every template key, existing values untouched", function()
	local engine, DataService = Server.boot()
	engine.dataStores._put("MM_Profiles_v1", "u_6", {
		coins = 999,
		seeds = { tomato = 2 },
		plotLevel = 3,
		settings = { music = false },
		meta = { created = 12 },
	})
	local player = Server.join(engine, 6)
	local p = DataService.get(player)
	Assert.truthy(p, "loaded")
	eq(p.v, 1)
	hasEveryKey(p, DataService.TEMPLATE, DataService.RECONCILE_SKIP, "profile")
	eq(p.coins, 999)
	eq(p.seeds, { tomato = 2 }, "seeds are not merged with the starting carrots")
	eq(p.plotLevel, 3)
	eq(p.settings.music, false)
	eq(p.settings.patchAlerts, true)
	eq(p.meta.created, 12)
	eq(Server.raw(engine, 6).v, 1)
end)

test("a profile from a newer version kicks and is never written", function()
	local engine, DataService = Server.boot()
	engine.dataStores._put("MM_Profiles_v1", "u_6", { v = 2, coins = 5 })
	local player = Server.join(engine, 6)
	eq(DataService.get(player), nil)
	eq(Server.kicksFor(engine, 6), { TOO_NEW })
	eq(#engine.dataStores._writes("MM_Profiles_v1", "u_6"), 0)
	eq(Server.raw(engine, 6), { v = 2, coins = 5 })
	engine:advance(60)
	eq(engine.dataStores._calls("MM_Profiles_v1", "u_6", "UpdateAsync"), 1, "no retries")
end)

test("migrate stops at a missing step", function()
	local _, DataService = Server.boot()
	local p, err = DataService.migrate({ v = -1 })
	eq(p, nil)
	Assert.truthy(err:find("v%-1"), err)
end)
