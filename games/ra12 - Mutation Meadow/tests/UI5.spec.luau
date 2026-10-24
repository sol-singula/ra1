local Assert = require("./mock/Assert")
local Client = require("./mock/Client")

local test, eq = Assert.test, Assert.eq

local roblox = require("@lune/roblox")
local SIZES = { roblox.Vector2.new(1920, 1080), roblox.Vector2.new(390, 844) }

local G1 = "0123ABCD-0000-0000-0000-000000000001"
local G2 = "0123ABCD-0000-0000-0000-000000000002"
local G3 = "0123ABCD-0000-0000-0000-000000000003"

local function withItems(p)
	p.items[G1] = { seed = "pumpkin", muts = { golden = true }, foundAt = 0, foundBy = 10, owner = 10, locked = false }
	p.items[G2] = { seed = "corn", muts = { wet = true }, foundAt = 0, foundBy = 77, owner = 10, locked = false }
	p.items[G3] =
		{ seed = "pumpkin", muts = { wet = true, golden = true }, foundAt = 0, foundBy = 10, owner = 10, locked = true }
	p.pedestals["1"] = G3
end

local function each(c, fn)
	for _, size in SIZES do
		c.engine.workspace.CurrentCamera.ViewportSize = size
		c.engine:advance(0.3)
		fn(size)
	end
	eq(c.engine.errors, {})
end

test("the Block Party meter: stage, waters/goal, time left, your waters; hidden after the bloom", function()
	local c = Client.boot()
	local now = c.engine.workspace:GetServerTimeNow()
	c.remotes.BlockPartyState.OnClientEvent:Fire({
		phase = "open",
		stage = "perking",
		waters = 12,
		goal = 30,
		yourWaters = 3,
		endsAt = now + 372,
	})
	local gui = c.gui("BlockParty")
	each(c, function()
		eq(gui.Meter.Visible, true)
	end)
	eq(Client.find(gui, "Stage").Text, "🌻 It's perking up!")
	eq(Client.find(gui, "Count").Text, "12 / 30 waters")
	eq(Client.find(gui, "Yours").Text, "Your waters: 3 (5 needed)")
	Assert.truthy(Client.find(gui, "TimeLeft").Text:find("left"), "time left")
	Assert.near(Client.find(gui, "Fill").Size.X.Scale, 0.4, 1e-6)
	Client.press(Client.find(gui, "Water"))
	eq(Client.sent(c, "BlockParty")[1][1], "water")
	local hud = c.gui("Hud")
	c.engine:advance(1.1)
	eq(Client.find(hud, "Party").Text, "🌻 Block Party now!")
	c.remotes.BlockPartyState.OnClientEvent:Fire({
		phase = "weather",
		stage = "bloom",
		waters = 30,
		goal = 30,
		yourWaters = 5,
		endsAt = now + 300,
	})
	eq(gui.Meter.Visible, false)
	c.engine:advance(1.1)
	Assert.truthy(
		Client.find(hud, "Party").Text:find("^🌻 Block Party %d+:%d%d [AP]M %(in "),
		Client.find(hud, "Party").Text
	)
end)

test("the weather banner: Rain or Golden Hour, a countdown, what it rolls", function()
	local c = Client.boot()
	local now = c.engine.workspace:GetServerTimeNow()
	local gui = c.gui("WeatherBanner")
	eq(gui.Banner.Visible, false)
	c.remotes.Weather.OnClientEvent:Fire({ kind = "rain", scope = "server", startsAt = now, endsAt = now + 300 })
	c.engine:advance(0.6)
	each(c, function()
		eq(gui.Banner.Visible, true)
	end)
	eq(Client.find(gui, "Title").Text, "🌧 Rain! Crops grow 1.5x")
	eq(Client.find(gui, "Rolls").Text, "25% chance a crop turns Wet (2x)")
	Assert.truthy(Client.find(gui, "Countdown").Text:find("^4m"), Client.find(gui, "Countdown").Text)
	c.remotes.Weather.OnClientEvent:Fire({ kind = "goldenHour", scope = "server", startsAt = now, endsAt = now + 300 })
	eq(Client.find(gui, "Rolls").Text, "8% chance a crop turns Golden (20x)")
	c.remotes.Weather.OnClientEvent:Fire({ kind = nil, scope = "server" })
	eq(gui.Banner.Visible, false)
	c.remotes.Weather.OnClientEvent:Fire({ kind = "rain", scope = "ownPlot", startsAt = now, endsAt = now + 60 })
	eq(Client.find(gui, "Title").Text, "🌧 Welcome Shower on your plot")
end)

test("a mutation toast: crop, mutation, value and New entry", function()
	local c = Client.boot(function(p)
		p.tiles["2"] =
			{ seed = "pumpkin", plantedAt = 0, grown = 0, harvestsLeft = 1, muts = { golden = true }, canUsed = false }
	end)
	c.remotes.Mutation.OnClientEvent:Fire({ tile = "2", mut = "golden", value = 87000, newEntry = true })
	local found = false
	for _, d in c.gui("Hud").Toasts:GetChildren() do
		if d:IsA("TextLabel") and d.Text == "✨ Golden Pumpkin! Worth 87,000 · NEW ENTRY" then
			found = true
		end
	end
	Assert.truthy(found, "toast")
end)

test("the Backpack: grid, filters, slots, actions; the sell confirm copy is exact", function()
	local c = Client.boot(withItems)
	local bp = c.controllers.BackpackController
	each(c, function()
		bp.open()
		eq(c.gui("Backpack").Enabled, true)
		bp.close()
		eq(c.gui("Backpack").Enabled, false)
	end)
	bp.open()
	local gui = c.gui("Backpack")
	eq(Client.find(gui, "Slots").Text, "Slots 3/60")
	local card = Client.find(gui, "Item_" .. G1)
	eq(Client.find(card, "Name").Text, "Golden Pumpkin")
	eq(Client.find(card, "Value").Text, "🪙 87,000")
	Assert.truthy(Client.find(card, "Finder").Text:find("^Found by you"), "finder")
	eq(Client.find(Client.find(gui, "Item_" .. G2), "Finder").Text:match("^Found by (%S+)"), "Player77")
	Assert.truthy(Client.find(Client.find(gui, "Item_" .. G3), "OnDisplay"), "a displayed item shows On display")
	Assert.truthy(Client.find(Client.find(gui, "Item_" .. G3), "Sell") == nil, "and can't be sold")
	bp.setFilter("wet")
	Assert.truthy(Client.find(gui, "Item_" .. G2) and not Client.find(gui, "Item_" .. G1), "Wet filter")
	bp.setFilter("all")
	Client.press(Client.find(Client.find(gui, "Item_" .. G1), "Sell"))
	local confirm = c.gui("SellConfirm")
	eq(confirm.Enabled, true)
	eq(Client.find(confirm, "Text").Text, "Sell Golden Pumpkin for 87,000 coins? This can't be undone.")
	Client.press(Client.find(confirm, "Cancel"))
	eq(confirm.Enabled, false)
	eq(#Client.sent(c, "Inventory"), 0)
	Client.press(Client.find(Client.find(gui, "Item_" .. G1), "Sell"))
	Client.press(Client.find(confirm, "Confirm"))
	eq(Client.sent(c, "Inventory")[1], { "sellItem", { id = G1, reqId = 1 } })
	Client.press(Client.find(Client.find(gui, "Item_" .. G2), "Display"))
	eq(#Client.sent(c, "Inventory"), 1, "no unlocked pedestal yet: the picker opens instead")
	eq(c.gui("Pedestals").Enabled, true)
	c.controllers.PedestalController.close()
	c.plot.Pedestals.P1:SetAttribute("Unlocked", true)
	c.plot.Pedestals.P2:SetAttribute("Unlocked", true)
	Client.press(Client.find(Client.find(gui, "Item_" .. G2), "Display"))
	eq(
		Client.sent(c, "Inventory")[2],
		{ "display", { id = G2, pedestal = 2, reqId = 2 } },
		"the first free one (P1 is taken)"
	)
end)

test("the Backpack-full prompt: Sell now (coins) or Leave on plot", function()
	local c = Client.boot()
	local tile = c.plot.Tiles["1"]
	for k, v in { Active = true, Seed = "pumpkin", Muts = "wetgolden", Ripe = true, GrowSec = 720, Grown = 720 } do
		tile:SetAttribute(k, v)
	end
	each(c, function()
		c.controllers.BackpackController.fullPrompt(c.plot, "1")
		eq(c.gui("BackpackFull").Enabled, true)
		Client.press(Client.find(c.gui("BackpackFull"), "Close"))
	end)
	c.controllers.BackpackController.fullPrompt(c.plot, "1")
	local gui = c.gui("BackpackFull")
	eq(Client.find(gui, "SellNow").Text, "Sell now (🪙 174,000)")
	Client.press(Client.find(gui, "Leave"))
	eq(Client.sent(c, "Plot")[1][2].onFull, "leave")
	c.controllers.BackpackController.fullPrompt(c.plot, "1")
	Client.press(Client.find(gui, "SellNow"))
	eq(Client.sent(c, "Plot")[2][2].onFull, "sell")
end)

test("the pedestal picker: slots, item list, Remove; pedestals show the item with its label", function()
	local c = Client.boot(withItems)
	local ped = c.controllers.PedestalController
	for i, unlocked in { true, true, false } do
		c.plot.Pedestals["P" .. i]:SetAttribute("Unlocked", unlocked)
	end
	c.plot.Pedestals.P1:SetAttribute("ItemSeed", "pumpkin")
	c.plot.Pedestals.P1:SetAttribute("ItemMuts", "wetgolden")
	c.plot.Pedestals.P1:SetAttribute("ItemLabel", "Wet + Golden Pumpkin\nfound by you")
	each(c, function()
		ped.open()
		eq(c.gui("Pedestals").Enabled, true)
		ped.close()
	end)
	ped.open()
	local gui = c.gui("Pedestals")
	eq(Client.find(Client.find(gui, "Slot1"), "Label").Text, "P1: Wet + Golden Pumpkin")
	eq(Client.find(Client.find(gui, "Slot2"), "Label").Text, "P2: Empty")
	eq(Client.find(Client.find(gui, "Slot3"), "Label").Text, "P3: Locked")
	Client.press(Client.find(Client.find(gui, "Slot1"), "Remove"))
	eq(Client.sent(c, "Inventory")[1], { "undisplay", { pedestal = 1, reqId = 1 } })
	Client.press(Client.find(Client.find(gui, "Slot2"), "Choose"))
	Assert.truthy(Client.find(gui, "Pick_" .. G1) and not Client.find(gui, "Pick_" .. G3), "only free items")
	Client.press(Client.find(gui, "Pick_" .. G1))
	eq(Client.sent(c, "Inventory")[2], { "display", { id = G1, pedestal = 2, reqId = 2 } })
	ped.draw()
	local shownItem = Client.find(c.engine.workspace, "ShownItem")
	Assert.truthy(shownItem, "the item on the pedestal")
	local CropModel = c.engine:require(c.engine:module("Shared/Models/Crop"))
	eq(CropModel.fxHost(shownItem).MutFx:GetAttribute("Key"), "wetgolden")
	eq(CropModel.fxHost(shownItem).MutDripAt.MutDrops:GetAttribute("Mode"), "drip")
	eq(shownItem:GetAttribute("Stage"), "item", "the kept crop: the fruit on its own")
	eq(shownItem.Label.Text.Text, "Wet + Golden Pumpkin\nfound by you")
	eq(c.engine.errors, {})
end)

test("mutated crops sparkle in the world", function()
	local c = Client.boot()
	local tile = c.plot.Tiles["2"]
	local now = c.engine.workspace:GetServerTimeNow()
	for k, v in
		{ Active = true, Seed = "corn", Grown = 360, At = now, Rate = 1, GrowSec = 360, Ripe = true, Muts = "wet" }
	do
		tile:SetAttribute(k, v)
	end
	c.engine:advance(0.5)
	local CropModel = c.engine:require(c.engine:module("Shared/Models/Crop"))
	local crop = c.engine.workspace.ClientCrops:FindFirstChild("Plot1_2")
	eq(CropModel.fxHost(crop).MutDripAt.MutFx:GetAttribute("Mode"), "drip", "Wet: the drip")
	Assert.truthy(crop.MutBead1, "Wet droplet beads")
	tile:SetAttribute("Muts", nil)
	c.engine:advance(0.5)
	eq(CropModel.fxHost(crop), nil, "cleared: no Fx host")
	eq(crop:FindFirstChild("MutBead1"), nil)
end)

test(
	"a crop turning Golden on a live tile plays the reveal; one light, star glints; Wet joining reveals Wet+Golden",
	function()
		local c = Client.boot()
		local CropModel = c.engine:require(c.engine:module("Shared/Models/Crop"))
		local Visuals = c.engine:require(c.engine:module("Shared/Visuals"))
		local tile = c.plot.Tiles["2"]
		local now = c.engine.workspace:GetServerTimeNow()
		for k, v in { Active = true, Seed = "pumpkin", Grown = 720, At = now, Rate = 1, GrowSec = 720, Ripe = true } do
			tile:SetAttribute(k, v)
		end
		c.engine:advance(0.5)
		local crop = c.engine.workspace.ClientCrops:FindFirstChild("Plot1_2")
		eq({ crop:GetAttribute("Stage"), crop:GetAttribute("Revealed") }, { "ripe", nil })
		tile:SetAttribute("Muts", "golden")
		c.engine:advance(0.3)
		local main = CropModel.main(crop)
		eq({ crop:GetAttribute("Revealed"), crop:GetAttribute("RevealKey") }, { 1, "golden" }, "the reveal")
		c.engine:advance(3)
		eq(main.Color, Visuals.GOLD)
		eq(CropModel.fxHost(crop).MutFx.Texture, Visuals.SPARKLE)
		local lights = 0
		for _, d in crop:GetDescendants() do
			if d.ClassName == "PointLight" then
				lights += 1
			end
		end
		eq(lights, 1)
		tile:SetAttribute("Muts", "wetgolden")
		c.engine:advance(0.5)
		eq(
			{ crop:GetAttribute("Revealed"), crop:GetAttribute("RevealKey") },
			{ 2, "wetgolden" },
			"Wet joins: a Wet+Golden reveal"
		)
		eq(c.engine.errors, {})
	end
)
