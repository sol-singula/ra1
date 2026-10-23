local Assert = require("./mock/Assert")
local Engine = require("./mock/Engine")

local test, eq = Assert.test, Assert.eq

local function client()
	local engine = Engine.new({ client = true })
	local folder = engine.Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in { "Shop", "Result", "State" } do
		engine.Instance.new("RemoteEvent", folder).Name = name
	end
	engine.Instance.new("RemoteFunction", folder).Name = "Snapshot"
	folder.Parent = engine.game.ReplicatedStorage
	return engine, engine:require(engine:module("Shared/Net")), folder
end

test("request adds a reqId and resolves on the matching Result", function()
	local engine, Net, folder = client()
	local p = Net.request("Shop", "buySeed", { seed = "corn", qty = 1 })
	local sent = engine.remoteLog[1]
	eq({ sent.remote, sent.args[1], sent.args[2] }, { "Shop", "buySeed", { seed = "corn", qty = 1, reqId = 1 } })
	folder.Result.OnClientEvent:Fire({ reqId = 99, ok = true })
	eq(p.done, false, "another request's Result")
	folder.Result.OnClientEvent:Fire({ reqId = 1, ok = false, code = "not_implemented" })
	eq(p.value, { ok = false, code = "not_implemented" })
end)

test("request times out, and checks the schema before sending", function()
	local engine, Net = client()
	local p = Net.request("Shop", "close")
	engine:advance(10.5)
	eq(p.value, { ok = false, code = "timeout" })
	local bad = Net.request("Shop", "buySeed", { seed = "corn", qty = 3 })
	eq(bad.value, { ok = false, code = "schema" })
	eq(#engine.remoteLog, 1, "the bad one was never sent")
end)
