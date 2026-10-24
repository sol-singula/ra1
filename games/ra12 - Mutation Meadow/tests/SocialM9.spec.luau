local Assert = require("./mock/Assert")
local Farm = require("./mock/Farm")
local Store = require("./mock/Store")

local test, eq = Assert.test, Assert.eq

local roblox = require("@lune/roblox")

test("a like counts once per farm per day and shows on the owner's sign", function()
	local ctx = Store.setup()
	local a = Farm.join(ctx, 1)
	local b = Farm.join(ctx, 2)
	eq({ Farm.call(ctx, a, "Social", "like", { ownerId = 2 }) }, { true })
	eq({ Farm.call(ctx, a, "Social", "like", { ownerId = 2 }) }, { false, "liked_today" })
	eq(ctx.Data.get(b).social.likesReceived, 1)
	eq(ctx.Plot.signPart(b):GetAttribute("Likes"), 1)
	eq({ Farm.call(ctx, a, "Social", "like", { ownerId = 1 }) }, { false, "no_owner" }, "not your own")
	ctx.engine.workspace:SetAttribute("ClockOffset", 86400)
	eq({ Farm.call(ctx, a, "Social", "like", { ownerId = 2 }) }, { true }, "a new day")
end)

test("visits: a friend here moves you to their plot; one elsewhere teleports to their server", function()
	local ctx = Store.setup()
	ctx.engine.friends["1:2"] = true
	local a = Farm.join(ctx, 1)
	local b = Farm.join(ctx, 2)
	local c = Farm.join(ctx, 3)
	eq({ Farm.call(ctx, a, "Social", "visit", { friendId = 3 }) }, { false, "not_friend" })
	eq({ Farm.call(ctx, a, "Social", "visit", { friendId = 2 }) }, { true })
	local sign = ctx.Plot.signPart(b)
	Assert.truthy((a.Character.HumanoidRootPart.Position - sign.Position).Magnitude < 10, "at their plot")
	ctx.engine.friendsOnline[1] = {
		{ VisitorId = 7, PlaceId = ctx.engine.game.PlaceId, GameId = "server-7" },
		{ VisitorId = 8, PlaceId = 999, GameId = "other-game" },
	}
	eq({ Farm.call(ctx, a, "Social", "visit", { friendId = 7 }) }, { true })
	eq(ctx.engine.teleports[1], { placeId = ctx.engine.game.PlaceId, userIds = { 1 }, serverInstanceId = "server-7" })
	eq({ Farm.call(ctx, a, "Social", "visit", { friendId = 8 }) }, { false, "not_here" }, "another game")
	local _ = c
end)

test("garden names are filtered; a failed filter falls back to <DisplayName>'s Garden", function()
	local ctx = Store.setup()
	local a = Farm.join(ctx, 1)
	eq({ Farm.call(ctx, a, "Settings", "gardenName", { name = "Sunny Patch" }) }, { true })
	eq(ctx.Data.get(a).settings.gardenName, "Sunny Patch")
	eq(ctx.Plot.plotOf(a).Mailbox:GetAttribute("GardenName"), "Sunny Patch")
	ctx.engine.filterAs = "####"
	Farm.call(ctx, a, "Settings", "gardenName", { name = "rude" })
	eq(ctx.Data.get(a).settings.gardenName, "####", "the filtered text")
	ctx.engine.filterFails = true
	Farm.call(ctx, a, "Settings", "gardenName", { name = "Anything" })
	eq(ctx.Data.get(a).settings.gardenName, "Player1's Garden")
end)

test("the lounge: a non-VIP enter is refused (once-a-session card); VIP steps in; trespassers go back out", function()
	local ctx = Store.setup()
	local a = Farm.join(ctx, 1)
	local b = Farm.join(ctx, 2)
	ctx.Data.get(b).passes.vip = true
	eq({ Farm.call(ctx, a, "Lounge", "enter", {}) }, { false, "not_vip" })
	Farm.call(ctx, a, "Lounge", "enter", {})
	local cards = 0
	for _, t in Farm.toasts(ctx, a) do
		if t.kind == "vipGate" then
			cards += 1
			eq({ t.data.name, t.data.robux }, { "VIP Gardener", 249 })
		end
	end
	eq(cards, 1, "once a session")
	eq({ Farm.call(ctx, b, "Lounge", "enter", {}) }, { true })
	Assert.truthy(ctx.Lounge.inside(b), "on the deck")
	eq(#Store.events(ctx, "lounge_enter", 2), 1)
	local deck = ctx.engine.workspace.Street.Lounge.Deck
	Farm.standAt(ctx, a, deck.Position + roblox.Vector3.new(0, 3, 0))
	ctx.engine:advance(1.1)
	Assert.truthy(not ctx.Lounge.inside(a), "pushed out")
	local gate = ctx.engine.workspace.Street.Lounge.Gate
	eq(math.floor(a.Character.HumanoidRootPart.Position.Z - gate.Position.Z + 0.5), 6)
	Assert.truthy(ctx.Lounge.inside(b), "VIP stays")
	eq(deck.Size.X, 40)
	eq(deck.Size.Z, 30)
end)
