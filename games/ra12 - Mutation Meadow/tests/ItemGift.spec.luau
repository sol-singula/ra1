local Assert = require("./mock/Assert")
local Farm = require("./mock/Farm")
local Server = require("./mock/Server")

local test, eq = Assert.test, Assert.eq

local function setup()
	local ctx = Farm.setup()
	local a = Farm.join(ctx, 1)
	local b = Farm.join(ctx, 2)
	ctx.engine:advance(8) -- past the join writes' cooldown
	local ItemModel = ctx.engine:require(ctx.engine:module("Server/Items/ItemModel"))
	local guid = ItemModel.mint(ctx.Data.get(a), 1, "pumpkin", { golden = true })
	return ctx, a, b, guid, ItemModel
end

local function offer(ctx, from, payload)
	return { Farm.call(ctx, from, "Gift", "offer", payload, 8) }
end

local function lastOffer(ctx, to)
	local events = ctx.engine:clientEvents("GiftOffer", to.UserId)
	return events[#events] and events[#events][1]
end

test("an accepted item gift moves it: the receiver is saved first; item_gifted is logged", function()
	local ctx, a, b, guid = setup()
	local pa, pb = ctx.Data.get(a), ctx.Data.get(b)
	eq(offer(ctx, a, { targetId = 2, item = guid }), { true })
	eq(pa.items[guid].locked, true)
	local o = lastOffer(ctx, b)
	eq({ o.fromId, o.seed, o.muts.golden }, { 1, "pumpkin", true })
	eq(Server.raw(ctx.engine, 1).outbox[o.giftId].guid, guid, "the outbox is saved")
	eq({ Farm.call(ctx, b, "Gift", "respond", { giftId = o.giftId, accept = true }, 8) }, { true })
	eq(pa.items[guid], nil)
	eq(pb.items[guid].owner, 2)
	eq(pa.outbox, {})
	eq(pa.social.itemGifts, 1)
	eq(Server.raw(ctx.engine, 2).items[guid].owner, 2, "the receiver's save landed")
end)

test("a crash after the receiver's save leaves exactly one owner", function()
	local ctx, a, b, guid = setup()
	eq(offer(ctx, a, { targetId = 2, item = guid }), { true })
	local o = lastOffer(ctx, b)
	local giverBefore = Server.deepCopy(Server.raw(ctx.engine, 1)) -- the giver as saved with the open offer
	eq({ Farm.call(ctx, b, "Gift", "respond", { giftId = o.giftId, accept = true }, 8) }, { true })
	-- the giver's server dies before its write: their stored copy is the one with the outbox
	ctx.engine:removePlayer(a)
	ctx.engine:advance(8)
	giverBefore.lock = nil
	ctx.engine.dataStores._raw("MM_Profiles_v1")["u_1"] = giverBefore
	local again = Farm.join(ctx, 1)
	ctx.engine:advance(15)
	local pa = ctx.Data.get(again)
	eq(pa.items[guid], nil, "settled from the receiver's stored profile")
	eq(pa.outbox, {})
	eq(ctx.Data.get(b).items[guid].owner, 2)
end)

test("an open offer whose receiver never got it unlocks on the giver's next load", function()
	local ctx, a, b, guid = setup()
	eq(offer(ctx, a, { targetId = 2, item = guid }), { true })
	local giverBefore = Server.deepCopy(Server.raw(ctx.engine, 1))
	ctx.engine:removePlayer(a)
	ctx.engine:advance(8)
	giverBefore.lock = nil
	ctx.engine.dataStores._raw("MM_Profiles_v1")["u_1"] = giverBefore
	local again = Farm.join(ctx, 1)
	ctx.engine:advance(15)
	local pa = ctx.Data.get(again)
	eq(pa.items[guid].locked, false)
	eq(pa.outbox, {})
	local _ = b
end)

test("an expired offer unlocks and logs gift_declined; a declined one too", function()
	local ctx, a, b, guid = setup()
	local pa = ctx.Data.get(a)
	eq(offer(ctx, a, { targetId = 2, item = guid }), { true })
	ctx.engine:advance(31)
	eq(pa.items[guid].locked, false)
	eq(pa.outbox, {})
	local Telemetry = ctx.engine:require(ctx.engine:module("Server/Telemetry"))
	local declined = 0
	for _, e in Telemetry.events do
		if e.name == "gift_declined" then
			declined += 1
			eq(e.data.reason, "expired")
		end
	end
	eq(declined, 1)
	eq(offer(ctx, a, { targetId = 2, item = guid }), { true })
	local o = lastOffer(ctx, b)
	eq({ Farm.call(ctx, b, "Gift", "respond", { giftId = o.giftId, accept = false }, 2) }, { true })
	eq(pa.items[guid].locked, false)
	eq({ Farm.call(ctx, b, "Gift", "respond", { giftId = o.giftId, accept = true }) }, { false, "no_offer" })
end)

test("the 21st gift of the day is refused", function()
	local ctx, a, _, guid = setup()
	local pa = ctx.Data.get(a)
	pa.social.day = ctx.engine:require(ctx.engine:module("Shared/Clock")).utcDay(ctx.engine.now)
	pa.social.itemGifts = 20
	eq(offer(ctx, a, { targetId = 2, item = guid }), { false, "gift_cap" })
	eq(pa.items[guid].locked, false)
end)

test("a full receiver Backpack is refused; so are a locked item and someone not here", function()
	local ctx, a, b, guid, ItemModel = setup()
	local pa, pb = ctx.Data.get(a), ctx.Data.get(b)
	for _ = 1, ctx.Inv.backpackCap(pb) do
		ItemModel.mint(pb, 2, "carrot", { wet = true })
	end
	eq(offer(ctx, a, { targetId = 2, item = guid }), { false, "receiver_full" })
	eq(offer(ctx, a, { targetId = 9, item = guid }), { false, "no_target" })
	pa.items[guid].locked = true
	eq(offer(ctx, a, { targetId = 2, item = guid }), { false, "ownership" })
end)

test("crops: basket to basket on accept; refused when short or the receiver's basket is full", function()
	local ctx, a, b = setup()
	local pa, pb = ctx.Data.get(a), ctx.Data.get(b)
	pa.basket = { corn = 5 }
	eq(offer(ctx, a, { targetId = 2, crop = "corn", qty = 6 }), { false, "not_enough" })
	eq(offer(ctx, a, { targetId = 2, crop = "corn", qty = 3 }), { true })
	eq(pa.basket.corn, 2, "held while the offer is open")
	local o = lastOffer(ctx, b)
	eq(o.qty, 3)
	eq({ Farm.call(ctx, b, "Gift", "respond", { giftId = o.giftId, accept = true }, 8) }, { true })
	eq(pb.basket.corn, 3)
	pb.basket = { carrot = 200 }
	eq(offer(ctx, a, { targetId = 2, crop = "corn", qty = 1 }), { false, "receiver_full" })
	eq(offer(ctx, a, { targetId = 2, crop = "corn", qty = 2 }), { false, "receiver_full" })
	eq(pa.basket.corn, 2)
end)
