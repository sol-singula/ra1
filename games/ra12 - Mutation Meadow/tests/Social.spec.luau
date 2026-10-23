local Assert = require("./mock/Assert")
local Farm = require("./mock/Farm")

local test, eq = Assert.test, Assert.eq

local function setup()
	local ctx = Farm.setup()
	local helper = Farm.join(ctx, 1)
	local owner = Farm.join(ctx, 2)
	local Growth = ctx.engine:require(ctx.engine:module("Shared/Growth"))
	local function plant(id, seed)
		ctx.Data.get(owner).tiles[id] = Growth.newTile(seed or "dragonfruit", ctx.engine.now)
	end
	local function help(id)
		Farm.standAtTile(ctx, helper, owner, id)
		local out
		ctx.engine:run(function()
			out = table.pack(ctx.Social.helpWater(helper, 2, id))
		end)
		return out[1], out[2]
	end
	return ctx, helper, owner, plant, help
end

test("a help on a carrot at t=0 gives grown = 3; both sides get 25 x their level", function()
	local ctx, helper, owner, plant, help = setup()
	ctx.Data.get(owner).plotLevel = 3
	plant("1", "carrot")
	eq(help("1"), true)
	local tile = ctx.Data.get(owner).tiles["1"]
	eq(tile.grown, 3)
	eq(tile.canUsed, false, "the owner's can is untouched")
	eq(ctx.Data.get(helper).coins, 50 + 25 + 75, "plus Starter 5 (1 help-water)")
	eq(ctx.Data.get(owner).coins, 50 + 75)
	eq(ctx.Data.get(helper).social.helps, 1)
end)

test("through the remote, with the Helped event", function()
	local ctx, helper, owner, plant = setup()
	plant("2", "dragonfruit")
	local helped = {}
	ctx.Social.Helped:Connect(function(h, o, id)
		table.insert(helped, { h.UserId, o.UserId, id })
	end)
	Farm.standAtTile(ctx, helper, owner, "2")
	eq(Farm.call(ctx, helper, "Plot", "water", { tile = "2", ownerId = 2 }), true)
	eq(helped, { { 1, 2, "2" } })
	Assert.truthy(ctx.Data.get(owner).tiles["2"].grown >= 360, "a tenth of 3600")
	Farm.standAtTile(ctx, helper, helper, "1")
	eq({ Farm.call(ctx, helper, "Plot", "water", { tile = "3", ownerId = 2 }) }, { false, "not_growing" })
	eq({ Farm.call(ctx, helper, "Plot", "water", { tile = "2", ownerId = 2 }) }, { false, "too_far" })
end)

test("the 21st help in a day is refused; a new UTC day resets", function()
	local ctx, helper, owner, plant, help = setup()
	ctx.Data.get(owner).plotLevel = 5
	local ids = {
		"1",
		"2",
		"3",
		"4",
		"5",
		"6",
		"7",
		"9",
		"10",
		"11",
		"12",
		"13",
		"14",
		"15",
		"17",
		"18",
		"19",
		"20",
		"21",
		"22",
		"23",
	}
	for _, id in ids do
		plant(id)
	end
	for i = 1, 20 do
		eq({ help(ids[i]) }, { true }, "help " .. i)
	end
	eq({ help(ids[21]) }, { false, "help_cap" })
	ctx.Data.get(helper).social.day -= 1 -- as if the last help was yesterday (UTC)
	eq(help(ids[21]), true)
	eq(ctx.Data.get(helper).social.helps, 1)
end)

test("the same crop within 600s is refused", function()
	local ctx, _, _, plant, help = setup()
	plant("1")
	eq(help("1"), true)
	eq({ help("1") }, { false, "help_cooldown" })
	ctx.engine:advance(599)
	eq({ help("1") }, { false, "help_cooldown" })
	ctx.engine:advance(2)
	eq(help("1"), true)
end)

test("you can't help yourself, a ripe crop, or someone not here", function()
	local ctx, helper, owner, plant, help = setup()
	plant("1", "carrot")
	ctx.Data.get(owner).tiles["1"].grown = 30
	eq({ help("1") }, { false, "not_growing" })
	local out
	ctx.engine:run(function()
		out = table.pack(ctx.Social.helpWater(helper, 1, "1"))
	end)
	eq({ out[1], out[2] }, { false, "no_owner" })
	ctx.engine:run(function()
		out = table.pack(ctx.Social.helpWater(helper, 77, "1"))
	end)
	eq({ out[1], out[2] }, { false, "no_owner" })
end)

test("friend boost: +10% per friend in the server, 4 friends -> 0.30", function()
	local ctx = Farm.setup()
	for id = 2, 5 do
		ctx.engine.friends["1:" .. id] = true
	end
	local me = Farm.join(ctx, 1)
	local others = {}
	for id = 2, 5 do
		others[id] = Farm.join(ctx, id)
	end
	eq(ctx.Social.friendsInServer(me), 4)
	eq(ctx.Social.friendBoost(me), 0.3)
	eq(ctx.Social.friendBoost(others[2]), 0.1)
	ctx.engine:removePlayer(others[2])
	ctx.engine:removePlayer(others[3])
	ctx.engine:advance(1)
	eq(ctx.Social.friendsInServer(me), 2)
	Assert.near(ctx.Social.friendBoost(me), 0.2, 1e-9)
	eq(ctx.FarmS.rateFor(me, ctx.Data.get(me), "1"), 1.2)
end)
