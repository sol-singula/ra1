local Assert = require("./mock/Assert")
local Client = require("./mock/Client")

local test, eq = Assert.test, Assert.eq

local roblox = require("@lune/roblox")
local SIZES = { roblox.Vector2.new(1920, 1080), roblox.Vector2.new(390, 844) } -- desktop and a phone

local function atEachSize(c, fn)
	for _, size in SIZES do
		c.engine.workspace.CurrentCamera.ViewportSize = size
		c.engine:advance(0.3)
		fn(size)
	end
	eq(c.engine.errors, {})
end

test("the HUD shows coins, level and basket; Auto-Sell appears at level 2", function()
	local c = Client.boot()
	local hud = c.gui("Hud")
	Assert.truthy(hud, "Hud")
	eq(Client.find(hud, "Coins").Text, "🪙 50")
	eq(Client.find(hud, "Level").Text, "Plot 1")
	eq(Client.find(hud, "Basket").Text, "🧺 0/200")
	eq(Client.find(hud, "AutoSell").Visible, false)
	c.state.apply({
		{ path = { "plotLevel" }, value = 2 },
		{ path = { "coins" }, value = 12345 },
		{ path = { "basket" }, value = { carrot = 3 } },
	})
	eq(Client.find(hud, "AutoSell").Visible, true)
	eq(Client.find(hud, "Coins").Text, "🪙 12,345")
	eq(Client.find(hud, "Basket").Text, "🧺 3/200")
	Client.press(Client.find(hud, "AutoSell"))
	eq(Client.sent(c, "Basket")[1][1], "setAutoSell")
	eq(Client.sent(c, "Basket")[1][2].on, true)
	atEachSize(c, function()
		Assert.truthy(hud.UIScale.Scale > 0, "scaled")
	end)
end)

test("every screen opens and closes at 1920x1080 and on a phone", function()
	local c = Client.boot(function(p)
		p.basket = { carrot = 2 }
	end)
	local ctrl = c.controllers
	atEachSize(c, function(size)
		for _, entry in
			{
				{ ctrl.UpgradeController, "Upgrades" },
				{ ctrl.SellController, "SellStand" },
			}
		do
			entry[1].open()
			eq(c.gui(entry[2]).Enabled, true, `{entry[2]} at {size.X}`)
			entry[1].close()
			eq(c.gui(entry[2]).Enabled, false)
		end
		ctrl.TileController.open(c.plot, "1")
		eq(c.gui("TilePopup").Enabled, true)
		ctrl.TileController.close()
		eq(c.gui("TilePopup").Enabled, false)
		ctrl.WelcomeBackController.show({ awaySec = 8100, ripe = 3 })
		eq(c.gui("WelcomeBack").Enabled, true)
		Client.press(Client.find(c.gui("WelcomeBack"), "Close"))
		eq(c.gui("WelcomeBack").Enabled, false)
	end)
	eq(c.gui("Upgrades").UIScale.Scale < 1, true, "a phone scales down")
end)

test("the tile popup: empty, growing, ripe and someone else's crop", function()
	local c = Client.boot()
	local tile = c.plot.Tiles["1"]
	tile:SetAttribute("Active", true)
	c.controllers.TileController.tap(c.plot, "1")
	local popup = c.gui("TilePopup")
	local seedButton = Client.find(popup, "Seed_carrot")
	Assert.truthy(seedButton, "the seeds you own")
	eq(seedButton.Text, "Carrot x3")
	Client.press(seedButton)
	eq(Client.sent(c, "Plot")[1][1], "plant")
	eq(Client.sent(c, "Plot")[1][2].seed, "carrot")
	eq(popup.Enabled, false, "closes after a choice")

	local now = c.engine.workspace:GetServerTimeNow()
	for k, v in { Seed = "carrot", Grown = 10, At = now, Rate = 1.25, GrowSec = 30, Ripe = false, CanUsed = false } do
		tile:SetAttribute(k, v)
	end
	c.controllers.TileController.tap(c.plot, "1")
	eq(Client.find(popup, "TimeLeft").Text, "Ready in 16s")
	eq(Client.find(popup, "Boosts").Text, "Growing x1.25")
	Client.press(Client.find(popup, "Water"))
	eq(Client.sent(c, "Plot")[2], { "water", { tile = "1", reqId = 2 } })

	tile:SetAttribute("Ripe", true)
	c.controllers.TileController.tap(c.plot, "1")
	Client.press(Client.find(popup, "Harvest"))
	eq(Client.sent(c, "Plot")[3][1], "harvest")

	local other = c.engine.workspace.Street.Plots.Plot2
	other:SetAttribute("OwnerId", 99)
	local theirs = other.Tiles["5"]
	for k, v in { Active = true, Seed = "corn", Grown = 0, At = now, Rate = 1, GrowSec = 360, Ripe = false } do
		theirs:SetAttribute(k, v)
	end
	c.controllers.TileController.tap(other, "5")
	Client.press(Client.find(popup, "Help"))
	eq(Client.sent(c, "Plot")[4], { "water", { tile = "5", ownerId = 99, reqId = 4 } })
	eq(c.engine.errors, {})
end)

test("crops draw from the tile attributes and grow between updates", function()
	local c = Client.boot()
	local tile = c.plot.Tiles["2"]
	local now = c.engine.workspace:GetServerTimeNow()
	for k, v in { Active = true, Seed = "tomato", Grown = 0, At = now, Rate = 1, GrowSec = 180, Ripe = false } do
		tile:SetAttribute(k, v)
	end
	c.engine:advance(0.5)
	local crop = c.engine.workspace.ClientCrops:FindFirstChild("Plot1_2")
	Assert.truthy(crop, "drawn")
	local small = crop.Size.X
	c.engine:advance(90)
	Assert.truthy(crop.Size.X > small, "grew on its own")
	tile:SetAttribute("Seed", nil)
	c.engine:advance(0.5)
	eq(c.engine.workspace.ClientCrops:FindFirstChild("Plot1_2"), nil, "harvested crops go away")
end)

test("Upgrades: buy and place mode; Sell stand: Sell All; Welcome back: Harvest all ripe", function()
	local c = Client.boot(function(p)
		p.coins = 2000
		p.sprinklers.basic = 1
		p.basket = { tomato = 12 }
	end)
	local up = c.controllers.UpgradeController
	up.open()
	local gui = c.gui("Upgrades")
	eq(Client.find(gui, "PlotInfo").Text, "Plot level 2: 4 x 5")
	eq(Client.find(gui, "Unlocks").Text, "Unlocks Tomato, Corn")
	Client.press(Client.find(gui, "BuyPlot"))
	eq(Client.sent(c, "Upgrade")[1][2].kind, "plot")
	Client.press(Client.find(Client.find(gui, "Row_basic"), "Place"))
	eq(c.controllers.TileController.placing(), "basic")
	eq(gui.Enabled, false)
	c.plot.Tiles["10"]:SetAttribute("Active", true)
	c.controllers.TileController.tap(c.plot, "10")
	eq(Client.sent(c, "Plot")[1], { "sprinkler", { kind = "basic", tile = "10", reqId = 2 } })

	c.controllers.SellController.open()
	local sell = c.gui("SellStand")
	eq(Client.find(sell, "SellAll").Text, "Sell All: 🪙 1,320")
	Client.press(Client.find(sell, "SellAll"))
	eq(Client.sent(c, "Basket")[1][1], "sellAll")
	Client.press(Client.find(sell, "ItemsTab"))
	Assert.truthy(Client.find(sell, "ItemsSoon"), "items tab")

	c.remotes.Toast.OnClientEvent:Fire({
		kind = "welcomeBack",
		text = "Welcome back!",
		data = { awaySec = 5400, ripe = 2 },
	})
	local wb = c.gui("WelcomeBack")
	eq(wb.Enabled, true)
	eq(Client.find(wb, "Away").Text, "You were away 1h 30m")
	eq(Client.find(wb, "Ripe").Text, "2 crops are ripe")
	Client.press(Client.find(wb, "HarvestAll"))
	eq(Client.sent(c, "Plot")[2][1], "harvestAll")
	eq(wb.Enabled, false)
	eq(c.engine.errors, {})
end)

test("prompts on your own plot open Upgrades and the sell stand; someone else's don't", function()
	local c = Client.boot()
	local pps = c.engine.game:GetService("ProximityPromptService")
	pps.PromptTriggered:Fire(c.plot.Sign.Expand)
	eq(c.gui("Upgrades").Enabled, true)
	c.controllers.UpgradeController.close()
	pps.PromptTriggered:Fire(c.plot.SellStand.Sell)
	eq(c.gui("SellStand").Enabled, true)
	c.controllers.SellController.close()
	pps.PromptTriggered:Fire(c.engine.workspace.Street.Plots.Plot2.Sign.Expand)
	eq(c.gui("Upgrades").Enabled, false)
end)
