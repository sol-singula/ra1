local Assert = require("./mock/Assert")
local Farm = require("./mock/Farm")

local test, eq = Assert.test, Assert.eq

test("streaming is on (min 64, target 256); the street and its shared pieces are Persistent, plots Atomic", function()
	local ctx = Farm.setup()
	local ws = ctx.engine.workspace
	eq({ ws.StreamingEnabled, ws.StreamingMinRadius, ws.StreamingTargetRadius }, { true, 64, 256 })
	local street = ws.Street
	local Enum = ctx.engine.Enum
	eq(street.ModelStreamingMode, Enum.ModelStreamingMode.Persistent)
	for _, name in { "Sunflower", "Boards", "Lounge", "Patch" } do
		eq(street[name].ModelStreamingMode, Enum.ModelStreamingMode.Persistent, name)
	end
	for _, plot in street.Plots:GetChildren() do
		eq(plot.ModelStreamingMode, Enum.ModelStreamingMode.Atomic, plot.Name)
	end
	Assert.truthy(street.Boards.UpdateBoard and street.Boards.ServerBoard and street.Boards.GlobalBoard, "boards")
end)

test("your own plot is PersistentPerPlayer for you, and only while you own it", function()
	local ctx = Farm.setup()
	local a = Farm.join(ctx, 1)
	local b = Farm.join(ctx, 2)
	local plotA, plotB = ctx.Plot.plotOf(a), ctx.Plot.plotOf(b)
	eq(plotA._persistentPlayers(), { 1 })
	eq(plotB._persistentPlayers(), { 2 })
	ctx.engine:removePlayer(a)
	ctx.engine:advance(1)
	eq(plotA._persistentPlayers(), {})
end)

test("a visit streams the friend's plot in before the character lands", function()
	local ctx = Farm.setup()
	ctx.engine.friends["1:2"] = true
	local a = Farm.join(ctx, 1)
	local b = Farm.join(ctx, 2)
	eq(Farm.call(ctx, a, "Social", "visit", { friendId = 2 }), true)
	local req = ctx.engine.streamRequests[1]
	eq(req.userId, 1)
	eq(req.timeout, 2)
	Assert.truthy((req.position - ctx.Plot.signPart(b).Position).Magnitude < 10, "around their plot")
end)
