local Assert = require("./mock/Assert")
local Engine = require("./mock/Engine")
local Farm = require("./mock/Farm")

local test, eq = Assert.test, Assert.eq

local function shopIn(engine)
	return engine:require(engine:module("Server/Services/ShopService"))
end

test("two servers produce the same stock for the same slot", function()
	local a, b = Farm.setup({ now = 1_760_000_123 }), Farm.setup({ now = 1_760_000_123, jobId = "job-2" })
	eq(a.Shop.current(), b.Shop.current())
	for slot = 5_000_000, 5_000_200 do
		eq(a.Shop.stockFor(slot, true), b.Shop.stockFor(slot, true), "slot " .. slot)
	end
	local Schedule = a.engine:require(a.engine:module("Shared/Schedule"))
	eq(a.Shop.current().slot, Schedule.restockSlot(1_760_000_123))
	eq(a.Shop.current().endsAt, Schedule.slotEndsAt(a.Shop.current().slot))
end)

test("over 100,000 slots every seed hits within 1% of its chance; carrot always 20", function()
	local engine = Engine.new()
	local Shop = shopIn(engine)
	local Config = engine:require(engine:module("Shared/Config"))
	local hits, dragon = {}, 0
	local N = 100000
	for slot = 1, N do
		local stock = Shop.stockFor(slot, true)
		eq(stock.carrot, 20)
		for seed, qty in stock do
			if qty > 0 then
				hits[seed] = (hits[seed] or 0) + 1
				eq(qty, Config.Restock.stock[seed].qty)
			end
		end
		dragon += stock.dragonfruit
	end
	for _, seed in Config.Restock.order do
		local rate = (hits[seed] or 0) / N
		Assert.truthy(math.abs(rate - Config.Restock.stock[seed].chance) <= 0.01, `{seed}: {rate}`)
	end
	local perHour = dragon / (N / 12)
	Assert.truthy(math.abs(perHour - 0.48) <= 0.03, `dragon fruit {perHour} an hour`)
end)

test("Moon Melon: 0 outside event weeks, about 5% of the slots in them; the other rolls don't move", function()
	local engine = Engine.new()
	local Shop = shopIn(engine)
	local start = 1_767_225_600 // 300 -- 2026-01-01
	local inEvent, eventSlots, outside = 0, 0, 0
	for slot = start, start + 365 * 288 - 1, 3 do -- a year, every third slot
		local event = Shop.isEventSlot(slot)
		local stock = Shop.stockFor(slot, event)
		if event then
			eventSlots += 1
			if stock.moonmelon > 0 then
				inEvent += 1
			end
		elseif stock.moonmelon > 0 then
			outside += 1
		end
	end
	eq(outside, 0)
	Assert.truthy(eventSlots > 5000, "event weeks seen")
	Assert.truthy(math.abs(inEvent / eventSlots - 0.05) <= 0.015, `{inEvent / eventSlots}`)
	local a, b = Shop.stockFor(12345, true), Shop.stockFor(12345, false)
	b.moonmelon = a.moonmelon
	eq(a, b, "only Moon Melon differs")
end)

test(
	"a new slot broadcasts Restock; Patch tells players near him or in the shop; the rare line needs alerts",
	function()
		local ctx = Farm.setup({ now = (1_760_000_000 // 300 + 1) * 300 - 30, studio = true })
		local near = Farm.join(ctx, 1)
		local far = Farm.join(ctx, 2)
		local off = Farm.join(ctx, 3)
		Farm.standAtPatch(ctx, near)
		Farm.standAtPatch(ctx, off)
		ctx.Data.get(off).settings.patchAlerts = false
		local before = ctx.Shop.current().slot
		ctx.engine:advance(31)
		eq(ctx.Shop.current().slot, before + 1)
		local r = ctx.engine:clientEvents("Restock", 2)
		eq(r[#r][1].slot, before + 1)
		Assert.truthy(table.find(Farm.lines(ctx, near), "restock"), "near Patch")
		Assert.truthy(not table.find(Farm.lines(ctx, far), "restock"), "far away")
		-- a forced tier 7 restock (gated)
		eq(Farm.call(ctx, near, "DevCommand", "run", { cmd = "restock", args = { "force", "watermelon" } }), true)
		eq(ctx.Shop.current().stock.watermelon, 2)
		Assert.truthy(table.find(Farm.lines(ctx, far), "rare"), "alerts on, anywhere")
		Assert.truthy(not table.find(Farm.lines(ctx, off), "rare"), "alerts off")
		local rare
		for _, args in ctx.engine:clientEvents("PatchLine", 2) do
			if args[1].id == "rare" then
				rare = args[1]
			end
		end
		eq(rare.text, "Watermelon in stock! Come see!")
		eq(
			{ Farm.call(ctx, near, "DevCommand", "run", { cmd = "restock", args = { "force", "nope" } }) },
			{ false, "usage: restock force <seed>" }
		)
	end
)
