local Assert = require("./mock/Assert")
local Engine = require("./mock/Engine")
local Server = require("./mock/Server")

local test, eq = Assert.test, Assert.eq

local G = {
	good = "0123ABCD-0000-0000-0000-000000000001",
	shelf = "0123ABCD-0000-0000-0000-000000000002",
	other = "0123ABCD-0000-0000-0000-000000000003",
	dupe = "0123ABCD-0000-0000-0000-000000000004",
	seed = "0123ABCD-0000-0000-0000-000000000005",
}

local function item(owner, seed, locked)
	return {
		seed = seed or "carrot",
		muts = { wet = true },
		foundAt = 1,
		foundBy = owner,
		owner = owner,
		locked = locked,
	}
end

local function profile(items, pedestals)
	return { items = items, pedestals = pedestals or {} }
end

test("load drops a bad GUID, a wrong owner, a bad seed and a duplicate", function()
	local engine = Engine.new()
	local ItemModel = engine:require(engine:module("Server/Items/ItemModel"))
	ItemModel.registry[G.dupe] = 2 -- player 2 is online with this item
	local p = profile({
		[G.good] = item(1, "carrot", true), -- locked from a pending gift: unlocked on load
		["not-a-guid"] = item(1),
		[G.other] = item(2),
		[G.dupe] = item(1),
		[G.seed] = item(1, "banana"),
	})
	local dropped = ItemModel.validate(p, 1)
	local reasons = {}
	for _, d in dropped do
		reasons[d.guid] = d.reason
	end
	eq(
		reasons,
		{ ["not-a-guid"] = "bad_guid", [G.other] = "wrong_owner", [G.dupe] = "dupe_guid", [G.seed] = "bad_seed" }
	)
	eq(p.items[G.good].locked, false)
	local n = 0
	for _ in p.items do
		n += 1
	end
	eq(n, 1)
end)

test("a dead pedestal ref is cleared; a pedestal item stays locked", function()
	local engine = Engine.new()
	local ItemModel = engine:require(engine:module("Server/Items/ItemModel"))
	local p = profile({ [G.shelf] = item(1, "corn", false) }, { ["1"] = G.shelf, ["2"] = G.good })
	ItemModel.validate(p, 1)
	eq(p.pedestals, { ["1"] = G.shelf })
	eq(p.items[G.shelf].locked, true)
end)

test("mint makes a server GUID owned and found by the player", function()
	local engine = Engine.new({ now = 500 })
	local ItemModel = engine:require(engine:module("Server/Items/ItemModel"))
	local p = profile({})
	local guid, it = ItemModel.mint(p, 1, "tomato", { golden = true })
	Assert.truthy(guid:match(ItemModel.GUID_PATTERN), guid)
	eq(it, { seed = "tomato", muts = { golden = true }, foundAt = 500, foundBy = 1, owner = 1, locked = false })
	eq(p.items[guid], it)
	eq(ItemModel.registry[guid], 1)
	Assert.throws(function()
		ItemModel.mint(p, 1, "banana")
	end, "unknown seed")
	local client = Engine.new({ client = true })
	local ClientItems = client:require(client:module("Server/Items/ItemModel"))
	Assert.throws(function()
		ClientItems.mint(profile({}), 1, "carrot")
	end, "server%-only")
end)

test("a transfer leaves the item in exactly one profile", function()
	local engine = Engine.new()
	local ItemModel = engine:require(engine:module("Server/Items/ItemModel"))
	local a, b = profile({}), profile({})
	local guid = ItemModel.mint(a, 1, "corn")
	eq(ItemModel.transfer(a, b, guid, 2, 1), true)
	eq(a.items[guid], nil)
	eq(b.items[guid].owner, 2)
	eq(b.items[guid].giftedBy, 1)
	eq(ItemModel.registry[guid], 2)
	eq({ ItemModel.transfer(a, b, guid, 2, 1) }, { false, "missing" }, "can't send it twice")
	local guid2 = ItemModel.mint(a, 1, "corn")
	eq({ ItemModel.transfer(a, b, guid2, 2, 3) }, { false, "wrong_owner" })
	a.items[guid2].locked = true
	eq({ ItemModel.transfer(a, b, guid2, 2, 1) }, { false, "locked" })
	eq(b.items[guid2], nil)
end)

test("on load: the second player with a duplicated GUID loses it", function()
	local engine, DataService = Server.boot()
	local function fixture(userId)
		engine.dataStores._put("MM_Profiles_v1", "u_" .. userId, {
			v = 1,
			items = { [G.good] = item(userId) },
			pedestals = { ["1"] = G.good },
			meta = { created = 1 },
		})
	end
	fixture(1)
	fixture(2)
	local p1 = Server.join(engine, 1)
	local p2 = Server.join(engine, 2)
	Assert.truthy(DataService.get(p1).items[G.good], "first keeps it")
	eq(DataService.get(p1).items[G.good].locked, true)
	eq(DataService.get(p2).items[G.good], nil, "the dupe is dropped")
	eq(DataService.get(p2).pedestals, {}, "and its pedestal cleared")
end)
