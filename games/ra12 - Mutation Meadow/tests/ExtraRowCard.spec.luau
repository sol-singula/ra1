local Assert = require("./mock/Assert")
local Client = require("./mock/Client")

local test, eq = Assert.test, Assert.eq

-- a client whose every active main tile (plot level 1) has a crop
local function fullPlot(edit)
	return Client.boot(function(p)
		for row = 1, 8 do
			for col = 1, 8 do
				local id = tostring((row - 1) * 8 + col)
				p.tiles[id] =
					{ seed = "carrot", plantedAt = 0, grown = 0, muts = {}, harvestsLeft = 1, canUsed = false }
			end
		end
		if edit then
			edit(p)
		end
	end)
end

local function card(c)
	return c.gui("ExtraRowCard")
end

test("hidden at 9:59 with a full plot, shown at 10:00", function()
	local c = fullPlot()
	eq(card(c).Enabled, false, "before the first session's 10:00")
	c.state.apply({ { path = { "firstSession", "playedSec" }, value = 599 } })
	eq(card(c).Enabled, false)
	c.state.apply({
		{ path = { "firstSession", "playedSec" }, value = 600 },
		{ path = { "firstSession", "extraRowEligible" }, value = true },
	})
	eq(card(c).Enabled, true)
	eq(card(c).Adornee, c.plot.Sign, "beside the Expand sign")
	eq(Client.find(card(c), "Text").Text, "+8 tiles in a bed in front of your plot")
	eq(Client.find(card(c), "Buy").Text, "Extra Row 199 R$")
end)

test("a later session shows it; Close hides it for the session", function()
	local c = fullPlot(function(p)
		p.firstSession.done = true
	end)
	eq(card(c).Enabled, true)
	Client.press(Client.find(card(c), "Close"))
	eq(card(c).Enabled, false)
	c.state.apply({ { path = { "coins" }, value = 999 } })
	eq(card(c).Enabled, false, "stays closed")
end)

test("hidden when one tile is empty, and again when a tile frees up", function()
	local c = fullPlot(function(p)
		p.firstSession.done = true
		p.tiles["3"] = nil
	end)
	eq(card(c).Enabled, false)
	c.state.apply({
		{
			path = { "tiles", "3" },
			value = { seed = "carrot", plantedAt = 0, grown = 0, muts = {}, harvestsLeft = 1, canUsed = false },
		},
	})
	eq(card(c).Enabled, true)
	c.state.apply({ { path = { "tiles", "2" }, value = nil } })
	eq(card(c).Enabled, false, "a harvest freed a tile")
end)

test("owning Extra Plot Row or the bundle hides it", function()
	local c = fullPlot(function(p)
		p.firstSession.done = true
	end)
	local me = c.engine.game.Players.LocalPlayer
	me:SetAttribute("Pass_starterBundle", true)
	eq(card(c).Enabled, false)
	me:SetAttribute("Pass_starterBundle", nil)
	eq(card(c).Enabled, true)
	me:SetAttribute("Pass_extraRow", true)
	eq(card(c).Enabled, false)
end)

test("no prompt call ever happens without a tap", function()
	local c = fullPlot()
	c.state.apply({ { path = { "firstSession", "extraRowEligible" }, value = true } })
	c.engine:advance(120)
	c.state.apply({ { path = { "coins" }, value = 5000 } })
	eq(#Client.sent(c, "Purchase"), 0)
	Client.press(Client.find(card(c), "Buy"))
	eq(Client.sent(c, "Purchase"), { { "prompt", { key = "extraRow", reqId = 1 } } })
end)
