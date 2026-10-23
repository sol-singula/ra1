local Assert = require("./mock/Assert")
local Engine = require("./mock/Engine")
local Farm = require("./mock/Farm")

local test, eq = Assert.test, Assert.eq

local scratch = Engine.new()
local Schedule = scratch:require(scratch:module("Shared/Schedule"))

local function utc(y, m, d, h, mi, s)
	return Schedule.daysFromCivil(y, m, d) * 86400 + (h or 0) * 3600 + (mi or 0) * 60 + (s or 0)
end

local function claim(ctx, p, updateId)
	return { Farm.call(ctx, p, "Weekly", "claim", { updateId = updateId }) }
end

test("§6 vectors drive nextAt; WeeklyState goes out at the exact nextAt and re-arms", function()
	local ctx = Farm.setup({ now = utc(2026, 10, 24, 15, 59) })
	local p = Farm.join(ctx, 1)
	eq(ctx.Weekly.current().updateId, "2026-10-17")
	eq(ctx.Weekly.current().nextAt, utc(2026, 10, 24, 16))
	local first = ctx.engine:clientEvents("WeeklyState", 1)[1][1]
	eq({ first.updateId, first.nextAt, first.claimed }, { "2026-10-17", utc(2026, 10, 24, 16), false })
	Assert.truthy(first.notes and first.notes.title, "what's new rides along")
	local rolledAt
	ctx.Weekly.Rolled:Connect(function()
		rolledAt = ctx.engine.now
	end)
	ctx.engine:advance(120)
	eq(rolledAt, utc(2026, 10, 24, 16), "to the second")
	local events = ctx.engine:clientEvents("WeeklyState", 1)
	local last = events[#events][1]
	eq({ last.updateId, last.nextAt }, { "2026-10-24", utc(2026, 10, 31, 16) })
	eq(ctx.Weekly.notes("2026-10-24"), ctx.engine:require(ctx.engine:module("Shared/Config")).WeeklyNotes["2026-10-24"])

	local later = Farm.setup({ now = utc(2026, 10, 31, 16, 0, 1) })
	eq(later.Weekly.current().nextAt, utc(2026, 11, 7, 17), "the switch back to standard time")
	eq(#ctx.engine.errors, 0)
	local _ = p
end)

test("a claim at 2026-10-24 16:00:01Z succeeds; a second is refused", function()
	local ctx = Farm.setup({ now = utc(2026, 10, 24, 16, 0, 1) })
	local p = Farm.join(ctx, 1)
	local profile = ctx.Data.get(p)
	profile.plotLevel = 2
	local coins = profile.coins
	local corn = profile.seeds.corn or 0
	eq(claim(ctx, p, "2026-10-24"), { true })
	eq(profile.coins, coins + 4000, "1000 x L^2")
	eq(profile.seeds.corn, corn + 3, "3 top-tier seeds")
	eq(claim(ctx, p, "2026-10-24"), { false, "claimed" })
	eq(profile.weekly.claimed, { ["2026-10-24"] = true })
end)

test("an old updateId after the rollover is refused; claimed keeps the last 8", function()
	local ctx = Farm.setup({ now = utc(2026, 10, 24, 15, 59, 50) })
	local p = Farm.join(ctx, 1)
	local profile = ctx.Data.get(p)
	ctx.engine:advance(15)
	eq(ctx.Weekly.current().updateId, "2026-10-24")
	eq(claim(ctx, p, "2026-10-17"), { false, "old_update" })
	for i = 1, 8 do
		profile.weekly.claimed[string.format("2026-0%d-01", i)] = true
	end
	eq(claim(ctx, p, "2026-10-24"), { true })
	local n = 0
	for _ in profile.weekly.claimed do
		n += 1
	end
	eq(n, 8)
	eq(profile.weekly.claimed["2026-01-01"], nil, "the oldest dropped")
end)

test("garden value: a Golden Pumpkin item is 87,000, also with 2x Cash (no coins, no seeds)", function()
	local ctx = Farm.setup()
	local p = Farm.join(ctx, 1)
	local profile = ctx.Data.get(p)
	local ItemModel = ctx.engine:require(ctx.engine:module("Server/Items/ItemModel"))
	ItemModel.mint(profile, 1, "pumpkin", { golden = true })
	profile.coins = 10 ^ 9
	profile.seeds = { corn = 50 }
	eq(ctx.Board.gardenValue(profile), 87000)
	profile.passes.doubleCash = true
	eq(ctx.Board.gardenValue(profile), 87000)
	eq(ctx.Inv.itemPrice(p, { seed = "pumpkin", muts = { golden = true } }), 174000, "only selling doubles")
	Farm.crop(ctx, p, "1", "strawberry").muts = { wet = true }
	profile.basket = { carrot = 3 }
	-- strawberry: 14 x (2 + 5 - 1) = 84; basket 3 x 10
	eq(ctx.Board.gardenValue(profile), 87000 + 84 + 30)
end)

test("global writes keep the peak, at least 120s apart; the server board refreshes every 10s", function()
	local ctx = Farm.setup()
	local p = Farm.join(ctx, 1)
	ctx.Data.get(p).firstSession.done = true -- no Welcome Shower Wet on the corn
	Farm.crop(ctx, p, "1", "corn")
	ctx.engine:advance(600)
	local name = "MM_Top_" .. ctx.Weekly.current().updateId
	local writes = {}
	for _, c in ctx.engine.dataCalls do
		if c.store == name and c.key == "1" and c.method == "UpdateAsync" then
			table.insert(writes, c)
		end
	end
	Assert.truthy(#writes >= 4, `{#writes} writes`)
	for i = 2, #writes do
		Assert.truthy(writes[i].at - writes[i - 1].at >= 120, "120s apart")
	end
	local raw = ctx.engine.dataStores._raw(name, "ordered")
	eq(raw["1"], 330 * 5)
	ctx.Data.get(p).tiles = {}
	ctx.engine:advance(130)
	eq(ctx.engine.dataStores._raw(name, "ordered")["1"], 330 * 5, "the peak stays")
	local folder = ctx.engine.game.ReplicatedStorage.Leaderboards
	eq(folder:GetAttribute("UpdateId"), ctx.Weekly.current().updateId)
	eq(folder:GetAttribute("ResetAt"), ctx.Weekly.current().nextAt)
	Assert.truthy(folder:GetAttribute("Server"):find('"userId":1', 1, true), "the server board")
end)

test("the top-100 tag: granted from the previous update's board, removed when off it", function()
	local ctx = Farm.setup({ now = utc(2026, 10, 25, 12) }, function(engine)
		engine.dataStores._put("MM_Top_2026-10-17", "1", 5000, "ordered")
	end)
	local a = Farm.join(ctx, 1)
	eq(ctx.Data.get(a).cosmetics.owned.tag_weekly_top100, true)
	local b = Farm.join(ctx, 2)
	local pb = ctx.Data.get(b)
	pb.cosmetics.owned.tag_weekly_top100 = true
	pb.cosmetics.equipped.tag = "tag_weekly_top100"
	ctx.engine:run(function()
		ctx.Board.grantPrize(b)
	end)
	eq(pb.cosmetics.owned.tag_weekly_top100, nil)
	eq(pb.cosmetics.equipped.tag, nil)
end)

test("viewing the world update board sends Patch's update line, once per update", function()
	local ctx = Farm.setup()
	local p = Farm.join(ctx, 1)
	local prompt = ctx.engine.workspace.Street.Boards.UpdateBoard.View
	prompt.Triggered:Fire(p)
	prompt.Triggered:Fire(p)
	ctx.engine:advance(0.1)
	local n = 0
	for _, id in Farm.lines(ctx, p) do
		if id == "update" then
			n += 1
		end
	end
	eq(n, 1)
end)
