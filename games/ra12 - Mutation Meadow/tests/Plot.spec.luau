local Assert = require("./mock/Assert")
local Farm = require("./mock/Farm")
local Server = require("./mock/Server")

local test, eq = Assert.test, Assert.eq

test("8 joins fill plots 1-8; leaving frees a plot for the next join", function()
	local ctx = Farm.setup()
	local players = {}
	for id = 1, 8 do
		players[id] = Server.join(ctx.engine, id, 0.1)
	end
	local plots = ctx.Plot.plots()
	eq(#plots, 8)
	for i, plot in plots do
		eq(plot.Name, "Plot" .. i)
		eq(plot:GetAttribute("OwnerId"), i)
		eq(ctx.Plot.plotOf(players[i]), plot)
	end
	eq(ctx.engine.game.Players.MaxPlayers, 8, "a 9th player can't join a full server")
	ctx.engine:removePlayer(players[3])
	ctx.engine:advance(1)
	eq(plots[3]:GetAttribute("OwnerId"), nil, "freed")
	local nextPlayer = Server.join(ctx.engine, 9)
	eq(ctx.Plot.plotOf(nextPlayer), plots[3])
	eq(plots[3]:GetAttribute("OwnerId"), 9)
end)

test("a 9th player (if one got in) gets no plot and no error", function()
	local ctx = Farm.setup()
	for id = 1, 9 do
		Server.join(ctx.engine, id, 0.1)
	end
	eq(ctx.Plot.plotOf(ctx.engine.game.Players:GetPlayerByUserId(9)), nil)
	eq(ctx.engine.errors, {})
end)

test("only the active tiles show; the Extra Plot Row stays hidden", function()
	local ctx = Farm.setup()
	local player = Farm.join(ctx, 1)
	local plot = ctx.Plot.plotOf(player)
	local active = 0
	for _, tile in plot.Tiles:GetChildren() do
		if tile:GetAttribute("Active") then
			active += 1
		end
	end
	eq(active, 12)
	eq(#plot.Tiles:GetChildren(), 64)
	eq(plot.Tiles["1"]:GetAttribute("Active"), true)
	eq(plot.Tiles["4"]:GetAttribute("Active"), false)
	eq(plot.ExtraRow.Bed.Transparency, 1)
	eq(plot.ExtraRow.extra1:GetAttribute("Active"), false)
	eq(plot.Mailbox:GetAttribute("GardenName"), "Player1")
	Assert.truthy(plot.Sign:FindFirstChild("Expand") and plot.SellStand:FindFirstChild("Sell"), "prompts")
	eq(#plot.Pedestals:GetChildren(), 7)
end)

test("saved crops and sprinklers render on load; leaving clears the plot", function()
	local ctx = Farm.setup()
	ctx.engine.dataStores._put("MM_Profiles_v1", "u_1", {
		v = 1,
		tiles = { ["2"] = { seed = "corn", plantedAt = 0, grown = 10, harvestsLeft = 5, muts = {}, canUsed = false } },
		sprinklers = { basic = 1, advanced = 0, placed = { ["9"] = "basic" } },
		meta = { created = 1 },
	})
	local player = Farm.join(ctx, 1)
	local plot = ctx.Plot.plotOf(player)
	eq(plot.Tiles["2"]:GetAttribute("Seed"), "corn")
	eq(plot.Tiles["2"]:GetAttribute("Rate"), 1.25, "covered by the sprinkler on 9")
	eq(plot.Tiles["9"]:GetAttribute("Sprinkler"), "basic")
	ctx.engine:removePlayer(player)
	ctx.engine:advance(1)
	eq(plot.Tiles["2"]:GetAttribute("Seed"), nil)
	eq(plot.Tiles["9"]:GetAttribute("Sprinkler"), nil)
	eq(plot.Tiles["1"]:GetAttribute("Active"), false)
end)
