local Assert = require("./mock/Assert")
local Cases = require("./mock/NetCases")
local NetHelp = require("./mock/NetHelp")
local Server = require("./mock/Server")

local test, eq = Assert.test, Assert.eq

local function guards(engine)
	return engine:require(engine:module("Server/Net/Guards"))
end

test("tiles: another player's plot and inactive tiles are refused", function()
	local engine, DataService = Server.boot()
	local player = Server.join(engine, 1)
	Server.join(engine, 2)
	local G = guards(engine)
	eq(G.ownsTile(player, "1"), true)
	eq(G.ownsTile(player, "1", 1), true)
	eq(G.ownsTile(player, "1", 2), false, "another player's tile")
	-- level 1 is 3 x 4: columns 1-3 of rows 1-4
	eq(
		{ G.ownsTile(player, "3"), G.ownsTile(player, "4"), G.ownsTile(player, "27"), G.ownsTile(player, "33") },
		{ true, false, true, false }
	)
	eq(G.ownsTile(player, "extra1"), false, "no Extra Plot Row")
	DataService.get(player).passes.extraRow = true
	eq(G.ownsTile(player, "extra8"), true)
	DataService.get(player).plotLevel = 5
	eq(G.ownsTile(player, "64"), true)
	eq(G.ownsTile(player, "65"), false)
end)

test("items: another player's item and a locked item are refused", function()
	local engine, DataService = Server.boot()
	local player = Server.join(engine, 1)
	local other = Server.join(engine, 2)
	local G = guards(engine)
	local ItemModel = engine:require(engine:module("Server/Items/ItemModel"))
	local mine = ItemModel.mint(DataService.get(player), 1, "carrot")
	local theirs = ItemModel.mint(DataService.get(other), 2, "corn")
	eq(G.ownsItem(DataService.get(player), mine, 1), true)
	eq(G.ownsItem(DataService.get(player), theirs, 1), false, "not in my profile")
	eq(G.ownsItem(DataService.get(other), theirs, 1), false, "not my item")
	DataService.get(player).items[mine].locked = true
	eq(G.ownsItem(DataService.get(player), mine, 1), false, "locked")
	eq(G.ownsItem(DataService.get(player), Cases.GUID, 1), false, "missing")
end)

test("near, sameServer, loaded", function()
	local engine = Server.boot()
	local player = Server.join(engine, 1)
	local G = guards(engine)
	eq(G.near(player, nil, 10), false, "no character")
	local roblox = require("@lune/roblox")
	local character = engine.Instance.new("Model")
	local root = engine.Instance.new("Part", character)
	root.Name = "HumanoidRootPart"
	root.Position = roblox.Vector3.new(0, 3, 0)
	player.Character = character
	eq(G.near(player, roblox.Vector3.new(0, 3, 12), G.RANGE.patch), true)
	eq(G.near(player, roblox.Vector3.new(0, 3, 12.5), G.RANGE.patch), false)
	eq(G.RANGE, { tile = 24, stand = 16, sunflower = 15, patch = 12 })
	eq(G.sameServer(1), player)
	eq(G.sameServer(99), nil)
	eq(G.loaded(player), true)
end)

test("a non-dev DevCommand outside Studio is a no-op (dev_gate, no Result)", function()
	local engine, NetService, _, player, calls = NetHelp.setup({ studio = false })
	engine:fireServer(player, "DevCommand", "run", { cmd = "grow", args = {}, reqId = 1 })
	eq(#calls, 0)
	eq(engine:clientEvents("Result", 10), {})
	eq(NetService.dropStats().byReason.dev_gate, 1)
	local logged = false
	for _, line in engine.output do
		logged = logged or line:find("dropped dev_gate from 10") ~= nil
	end
	Assert.truthy(logged, "logged with the UserId")
end)

test("in Studio a DevCommand reaches its handler", function()
	local engine, _, _, player, calls = NetHelp.setup({ studio = true })
	engine:fireServer(player, "DevCommand", "run", { cmd = "grow", args = { "all" }, reqId = 2 })
	eq(#calls, 1)
	eq(engine:clientEvents("Result", 10), { table.pack({ reqId = 2, ok = true }) })
end)

test("a handler that refuses ownership counts as an ownership drop and still answers", function()
	local engine, NetService, _, player = NetHelp.setup()
	NetService.on("Inventory", "sellItem", nil, function()
		return false, "ownership"
	end)
	engine:fireServer(player, "Inventory", "sellItem", { id = Cases.GUID, reqId = 3 })
	eq(NetService.dropStats().byReason.ownership, 1)
	eq(engine:clientEvents("Result", 10), { table.pack({ reqId = 3, ok = false, code = "ownership" }) })
end)

test("calls before the profile loads are dropped as not_loaded", function()
	local engine, NetService = NetHelp.setup()
	engine.dataStores._put("MM_Profiles_v1", "u_20", { v = 1, lock = { jobId = "other", at = engine.now } })
	local waiting = Server.join(engine, 20, 0.1)
	engine:fireServer(waiting, "Shop", "close", {})
	eq(NetService.dropStats().byReason.not_loaded, 1)
end)
