local Assert = require("./mock/Assert")
local Farm = require("./mock/Farm")

local test, eq = Assert.test, Assert.eq

local function setup()
	local ctx = Farm.setup()
	local p = Farm.join(ctx, 1)
	return ctx, p, ctx.Data.get(p)
end

local function buy(ctx, p, seed, qty)
	return Farm.call(ctx, p, "Shop", "buySeed", { seed = seed, qty = qty })
end

test("Patch's prompt opens the shop (12 studs, logged); buying needs it open", function()
	local ctx, p = setup()
	eq({ buy(ctx, p, "carrot", 1) }, { false, "shop_closed" })
	Farm.standAtTile(ctx, p, p, "1")
	ctx.engine.workspace.Street.Patch.Counter.ShopPrompt.Triggered:Fire(p)
	eq(ctx.Shop.isOpen(p), false, "too far from Patch")
	Farm.openShop(ctx, p)
	eq(ctx.Shop.isOpen(p), true)
	local r = ctx.engine:clientEvents("Restock", 1)
	eq(r[#r][1].open, true)
	eq(r[#r][1].bought, {})
	local Telemetry = ctx.engine:require(ctx.engine:module("Server/Telemetry"))
	local logged = false
	for _, e in Telemetry.events do
		logged = logged or (e.name == "shop_open" and e.data.via == "prompt")
	end
	Assert.truthy(logged, "shop_open via prompt")
	eq(Farm.call(ctx, p, "Shop", "close", {}), true)
	eq({ buy(ctx, p, "carrot", 1) }, { false, "shop_closed" })
end)

test("6 carrots + 2 strawberries cost 80; seeds land in the bag", function()
	local ctx, p, profile = setup()
	profile.coins = 200
	Farm.openShop(ctx, p)
	eq(buy(ctx, p, "carrot", 5), true)
	eq(buy(ctx, p, "carrot", 1), true)
	eq(buy(ctx, p, "strawberry", 1), true)
	eq(buy(ctx, p, "strawberry", 1), true)
	eq(profile.coins, 120)
	eq(profile.seeds, { carrot = 9, strawberry = 2 })
	eq(profile.restock.bought, { carrot = 6, strawberry = 2 })
	eq(profile.restock.slot, ctx.Shop.current().slot)
end)

test("buying 5 corn at level 1 is refused (gate); the 21st carrot in a slot is refused; a new slot resets", function()
	local ctx, p, profile = setup()
	profile.coins = 100000
	Farm.openShop(ctx, p)
	eq({ buy(ctx, p, "corn", 5) }, { false, "locked" })
	eq({ buy(ctx, p, "blueberry", 1) }, { false, "locked" }, "300 lifetime coins first")
	for _ = 1, 4 do
		eq(buy(ctx, p, "carrot", 5), true)
	end
	eq({ buy(ctx, p, "carrot", 1) }, { false, "sold_out" })
	Farm.at(ctx, ctx.Shop.current().endsAt + 0.5)
	eq(buy(ctx, p, "carrot", 1), true, "fresh stock")
	eq(profile.restock.bought, { carrot = 1 })
end)

test("gates open with lifetime coins and plot level; not enough coins is refused", function()
	local ctx, p, profile = setup()
	Farm.openShop(ctx, p)
	local stock = ctx.Shop.current().stock
	profile.lifetimeCoins = 300
	profile.plotLevel = 2
	profile.coins = 0
	eq({ buy(ctx, p, "strawberry", 1) }, { false, "coins" })
	profile.coins = 100000
	if stock.tomato >= 1 then
		eq(buy(ctx, p, "tomato", 1), true)
	else
		eq({ buy(ctx, p, "tomato", 1) }, { false, "sold_out" })
	end
	eq(ctx.Shop.gateReason(profile, "blueberry", false), nil)
	eq(ctx.Shop.gateReason(profile, "pumpkin", false), "plotLevel")
	profile.plotLevel = 4
	eq(
		{ ctx.Shop.gateReason(profile, "moonmelon", false), ctx.Shop.gateReason(profile, "moonmelon", true) },
		{ "eventOnly", nil }
	)
end)
