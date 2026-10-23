local Assert = require("./mock/Assert")
local Client = require("./mock/Client")

local test, eq = Assert.test, Assert.eq

local roblox = require("@lune/roblox")
local SIZES = { roblox.Vector2.new(1920, 1080), roblox.Vector2.new(390, 844) }

local function stock(over)
	local s = {
		carrot = 20,
		strawberry = 15,
		blueberry = 8,
		tomato = 6,
		corn = 3,
		pumpkin = 0,
		watermelon = 0,
		dragonfruit = 0,
		moonmelon = 0,
	}
	for k, v in over or {} do
		s[k] = v
	end
	return s
end

test("the Seed Shop: 9 cards, stock left, lock reasons, Buy 5 off under 5, countdown, Odds", function()
	local c = Client.boot(function(p)
		p.restock = { slot = 100, bought = { carrot = 17 } }
	end)
	local now = c.engine.workspace:GetServerTimeNow()
	c.remotes.Restock.OnClientEvent:Fire({
		slot = 100,
		endsAt = now + 192,
		stock = stock(),
		bought = { carrot = 17 },
		open = true,
	})
	local gui = c.gui("SeedShop")
	eq(gui.Enabled, true)
	local cards = 0
	for _, d in gui:GetDescendants() do
		if d.Name:match("^Card_") then
			cards += 1
		end
	end
	eq(cards, 9)
	local carrot = Client.find(gui, "Card_carrot")
	eq(Client.find(carrot, "Stock").Text, "3 left this restock")
	eq(Client.find(carrot, "Buy5").Active, false)
	eq(Client.find(carrot, "Buy1").Active, true)
	eq(Client.find(Client.find(gui, "Card_blueberry"), "Stock").Text, "🔒 Earn 300 coins in total")
	eq(Client.find(Client.find(gui, "Card_corn"), "Stock").Text, "🔒 Plot level 2")
	eq(Client.find(Client.find(gui, "Card_moonmelon"), "Stock").Text, "🔒 Plot level 4")
	eq(Client.find(Client.find(gui, "Card_strawberry"), "Price").Text, "🪙 25 · grows 45s")
	eq(Client.find(gui, "Countdown").Text, "New seeds in 3m 12s")
	Client.press(Client.find(Client.find(gui, "Card_strawberry"), "Buy5"))
	eq(Client.sent(c, "Shop")[1], { "buySeed", { seed = "strawberry", qty = 5, reqId = 1 } })
	Client.press(Client.find(carrot, "Buy5"))
	eq(#Client.sent(c, "Shop"), 1, "Buy 5 is off")
	Client.press(Client.find(gui, "Odds"))
	eq(c.gui("Odds").Enabled, true)
	c.controllers.OddsController.close()
	Client.press(Client.find(gui, "Close"))
	eq(gui.Enabled, false)
	eq(Client.sent(c, "Shop")[2][1], "close")
	eq(Client.find(c.gui("Hud"), "Restock").Text, "")
	c.engine:advance(1.1)
	Assert.truthy(Client.find(c.gui("Hud"), "Restock").Text:find("^🌱 New seeds in 3m"), "HUD countdown")
end)

test("every M7 screen opens and closes on desktop and a phone", function()
	local c = Client.boot()
	local now = c.engine.workspace:GetServerTimeNow()
	for _, size in SIZES do
		c.engine.workspace.CurrentCamera.ViewportSize = size
		c.engine:advance(0.3)
		c.controllers.ShopController.open({ slot = 1, endsAt = now + 100, stock = stock() })
		eq(c.gui("SeedShop").Enabled, true)
		c.controllers.ShopController.close()
		c.controllers.OddsController.open()
		eq(c.gui("Odds").Enabled, true)
		c.controllers.OddsController.close()
		c.controllers.HudController.openSettings()
		eq(c.gui("Settings").Enabled, true)
		Client.press(Client.find(c.gui("Settings"), "Close"))
	end
	eq(c.engine.errors, {})
end)

test("the Odds panel renders exactly the Config rows; Settings toggles and opens the Odds", function()
	local c = Client.boot()
	local Odds = c.engine:require(c.engine:module("Shared/Odds"))
	local Config = c.engine:require(c.engine:module("Shared/Config"))
	c.controllers.OddsController.open()
	local rows = Odds.rows(Config)
	for i, row in rows do
		eq(Client.find(c.gui("Odds"), "Row" .. i).Text, row.text)
	end
	eq(Client.find(c.gui("Odds"), "Row" .. (#rows + 1)), nil)
	c.controllers.OddsController.close()
	c.controllers.HudController.openSettings()
	local settings = c.gui("Settings")
	eq(Client.find(settings, "Set_patchAlerts").Text, "Patch alerts: ON")
	Client.press(Client.find(settings, "Set_patchAlerts"))
	eq(Client.sent(c, "Settings")[1], { "set", { key = "patchAlerts", value = false, reqId = 1 } })
	Client.press(Client.find(settings, "Odds"))
	eq(c.gui("Odds").Enabled, true)
end)

test("Patch's lines: one at a time, 2s apart; tap, timeout and action hide them and ack", function()
	local c = Client.boot()
	local pc = c.controllers.PatchController
	local fire = c.remotes.PatchLine.OnClientEvent
	fire:Fire({ id = "shower", text = "Rain's coming! Wet crops sell for 2x.", display = "toast", hideSec = 5 })
	fire:Fire({ id = "restock", text = "Fresh seeds are in!", display = "bubble", hideSec = 3 })
	fire:Fire({ id = "shopAgain", text = "Hi again! Pick some seeds.", display = "shopBubble", hideSec = 3 })
	eq(pc.showing().id, "shower")
	eq(c.gui("PatchToast").Toast.Visible, true)
	c.engine:advance(30)
	local h = pc.history()
	eq(#h, 3)
	for i = 2, 3 do
		Assert.near(h[i].shownAt - h[i - 1].hiddenAt, 2, 0.15, "2s apart")
	end
	Assert.near(h[1].hiddenAt - h[1].shownAt, 5, 0.15, "hideSec")
	eq({ h[1].how, h[2].how, h[3].how }, { "timeout", "timeout", "timeout" })
	fire:Fire({ id = "rare", text = "Watermelon in stock! Come see!", display = "toast", hideSec = 4 })
	Client.press(c.gui("PatchToast").Toast)
	eq(pc.showing(), nil)
	eq(h[4].how, "tap")
	c.engine:advance(2.5)
	fire:Fire({ id = "plant", text = "Plant here!", display = "bubble", hideSec = 5, hideOn = "plant" })
	eq(c.gui("PatchBubble").Bubble.Visible, true)
	local Net = c.engine:require(c.engine:module("Shared/Net"))
	Net.request("Plot", "plant", { tile = "1", seed = "carrot" })
	eq(pc.showing(), nil)
	eq(h[5].how, "action")
	local acks = {}
	for _, s in Client.sent(c, "Settings") do
		table.insert(acks, s[2].id .. ":" .. s[2].how)
	end
	eq(acks, { "shower:timeout", "restock:timeout", "shopAgain:timeout", "rare:tap", "plant:action" })
	eq(c.engine.errors, {})
end)
