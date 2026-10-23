local Assert = require("./mock/Assert")
local Farm = require("./mock/Farm")

local test, eq, near = Assert.test, Assert.eq, Assert.near

-- the played second of each FTUE beat and of each Wet on the player's crops
local function watch(ctx, p)
	local at = {}
	local function played()
		return ctx.Data.get(p).firstSession.playedSec
	end
	ctx.First.Beat:Connect(function(player, name)
		if player == p then
			at[name] = played()
		end
	end)
	ctx.Mut.Mutated:Connect(function(player, _, key)
		if player == p and key == "wet" and not at.wet then
			at.wet = played()
		end
	end)
	return at
end

local function newcomer(ctx, userId)
	ctx.Weather.rng = Farm.fixedRng(0.99) -- no chance rolls: only the guaranteed Wet
	local p = Farm.join(ctx, userId or 1)
	Farm.crop(ctx, p, "1", "carrot")
	return p
end

test("shower at 240, Wet at 250, calendar at 390, done at 600", function()
	local ctx = Farm.setup()
	local p = newcomer(ctx)
	local at = watch(ctx, p)
	ctx.engine:advance(610)
	local fs = ctx.Data.get(p).firstSession
	near(at.shower, 240, 1)
	near(fs.showerAt, 240, 1)
	near(at.wet, 250, 1.5)
	near(at.calendar, 390, 1)
	near(at.board, 540, 1)
	near(at.ten, 600, 1)
	eq({ fs.showerDone, fs.calendarShown, fs.extraRowEligible, fs.done }, { true, true, true, true })
	local lines = Farm.lines(ctx, p)
	eq({ lines[1], lines[2], lines[3] }, { "plant", "shower", "mutation" })
	Assert.truthy(table.find(lines, "update"), "the update line with the board beat")
	local board
	for _, t in Farm.toasts(ctx, p) do
		if t.kind == "board" then
			board = t.data
		end
	end
	eq(board.nextUpdateAt, ctx.Weekly.current().nextAt)
	Assert.truthy(board.nextPartyAt > ctx.engine.now - 70, "the next Block Party")
	local funnel = {}
	for _, e in ctx.engine:require(ctx.engine:module("Server/Telemetry")).events do
		if e.name == "funnel" and e.userId == 1 then
			table.insert(funnel, e.data.step)
		end
	end
	eq(funnel, { 0, 7, 10 })
end)

test("Block Party weather 230-530 defers it: shower 540, Wet 550, calendar 690", function()
	local ctx = Farm.setup()
	local p = newcomer(ctx)
	local at = watch(ctx, p)
	ctx.engine:advance(230)
	ctx.engine:run(function()
		ctx.Weather.startEvent("rain")
	end)
	near(ctx.Weather.current().endsAt - ctx.engine.now, 300, 0.01)
	ctx.engine:advance(470)
	near(at.shower, 540, 1.5)
	near(at.wet, 550, 2)
	near(at.calendar, 690, 1.5)
end)

test("the calendar waits for the shop to close", function()
	local ctx = Farm.setup()
	local p = newcomer(ctx)
	local at = watch(ctx, p)
	ctx.engine:advance(380)
	Farm.openShop(ctx, p)
	ctx.engine:advance(30)
	eq(at.calendar, nil, "not over the shop")
	eq(Farm.call(ctx, p, "Shop", "close", {}), true)
	ctx.engine:advance(2)
	near(at.calendar, 412, 2)
end)

test("a rejoin at 200 played seconds still showers at 240 played seconds", function()
	local ctx = Farm.setup()
	local p = newcomer(ctx)
	ctx.engine:advance(200)
	ctx.engine:removePlayer(p)
	ctx.engine:advance(7)
	local again = Farm.join(ctx, 1)
	ctx.engine:advance(15)
	local profile = ctx.Data.get(again)
	Assert.truthy(profile, "loaded again")
	near(profile.firstSession.playedSec, 200 + 15, 2)
	eq(profile.firstSession.showerAt, nil)
	local at = watch(ctx, again)
	ctx.engine:advance(30)
	near(at.shower, 240, 1.5)
	near(profile.firstSession.showerAt, 240, 1.5)
end)

test("the scripted first two minutes reach plot level 2 by 2:15", function()
	local ctx = Farm.setup()
	local p = Farm.join(ctx, 1)
	local profile = ctx.Data.get(p)
	local start = ctx.engine.now
	local function plant(tile)
		Farm.standAtTile(ctx, p, p, tile)
		eq(Farm.call(ctx, p, "Plot", "plant", { tile = tile, seed = "carrot" }), true, "plant " .. tile)
		ctx.engine:advance(2)
	end
	local function harvest(tile)
		Farm.standAtTile(ctx, p, p, tile)
		eq(Farm.call(ctx, p, "Plot", "harvest", { tile = tile }), true, "harvest " .. tile)
		ctx.engine:advance(1)
	end
	local function sell()
		ctx.engine:advance(5) -- the walk to the stand
		Farm.standAtStand(ctx, p)
		eq(Farm.call(ctx, p, "Basket", "sellAll", {}), true)
	end
	for _, tile in { "1", "2", "3" } do
		plant(tile)
	end
	Farm.at(ctx, start + 36)
	for _, tile in { "1", "2", "3" } do
		harvest(tile)
	end
	sell()
	eq(profile.coins, 80)
	ctx.engine:advance(5) -- to Patch
	Farm.openShop(ctx, p)
	eq(Farm.call(ctx, p, "Shop", "buySeed", { seed = "carrot", qty = 1 }), true)
	eq(Farm.call(ctx, p, "Shop", "buySeed", { seed = "carrot", qty = 1 }), true)
	eq(Farm.call(ctx, p, "Shop", "close", {}), true)
	ctx.engine:advance(5)
	local planted = ctx.engine.now
	plant("1")
	plant("2")
	Farm.at(ctx, planted + 34)
	harvest("1")
	harvest("2")
	eq(profile.quests.starter.harvest5.claimed, true, "Starter 1 at the 5th harvest")
	sell()
	eq(Farm.call(ctx, p, "Upgrade", "buy", { kind = "plot" }), true)
	local took = ctx.engine.now - start
	eq(profile.plotLevel, 2)
	Assert.truthy(took <= 135, `level 2 at {took}s`)
	eq(profile.quests.starter.plot2.claimed, true, "Starter 2 refunded the 100")
	eq(profile.coins, 50 + 30 - 10 + 50 + 20 - 100 + 100)
end)
