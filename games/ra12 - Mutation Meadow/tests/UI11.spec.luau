local Assert = require("./mock/Assert")
local Client = require("./mock/Client")
local Layout = require("./mock/Layout")

local test, eq = Assert.test, Assert.eq

local roblox = require("@lune/roblox")

-- the Studio device emulator's four (landscape, in points)
local DEVICES = {
	{ "iPhone SE", roblox.Vector2.new(667, 375) },
	{ "iPhone 14 Pro Max", roblox.Vector2.new(932, 430) },
	{ "iPad", roblox.Vector2.new(1024, 768) },
	{ "1080p desktop", roblox.Vector2.new(1920, 1080) },
}

local GUID = "0000000A-0000-0000-0000-00000000000A"

-- a client with something on every screen, and every screen opened once
local function everything()
	local c = Client.boot(function(p)
		p.items[GUID] =
			{ seed = "pumpkin", muts = { golden = true }, foundAt = 0, foundBy = 10, owner = 10, locked = false }
		p.collection.found["carrot:wet"] = { at = 1, n = 1 }
		for i = 1, 5 do
			p.collection.found["corn:" .. ({ "wet", "golden", "wetgolden" })[i % 3 + 1] .. i] = { at = 1, n = 1 }
		end
		p.cosmetics.owned = { trail_leaf = true, tag_star = true }
		p.basket = { carrot = 4 }
	end)
	local me = c.engine.game.Players.LocalPlayer
	me:SetAttribute("Pass_gnome", true)
	me:SetAttribute("BundleOffer", '{"grants":["extraRow","can_pumpkin","tag_sprout"],"value":327}')
	c.engine.friends["10:20"] = true
	c.engine:addPlayer(20, "Pal")
	local now = c.engine.workspace:GetServerTimeNow()
	local ctl = c.controllers
	ctl.ShopController.open({
		slot = 1,
		endsAt = now + 100,
		stock = {
			carrot = 20,
			strawberry = 15,
			blueberry = 8,
			tomato = 6,
			corn = 3,
			pumpkin = 0,
			watermelon = 0,
			dragonfruit = 0,
			moonmelon = 0,
		},
	})
	for _, name in
		{
			"OddsController",
			"UpgradeController",
			"SellController",
			"BackpackController",
			"CollectionController",
			"DailyController",
			"QuestController",
			"PlaytimeController",
			"UpdateBoardController",
			"WardrobeController",
			"VisitController",
			"SettingsController",
			"PedestalController",
		}
	do
		ctl[name].open()
	end
	for _, tab in { "Passes", "Boosts", "Cosmetics" } do
		ctl.StoreController.open(tab)
	end
	ctl.GiftController.pick({ item = GUID })
	ctl.GiftController.offer({
		giftId = "g",
		fromId = 20,
		fromName = "Pal",
		seed = "corn",
		qty = 2,
		expiresAt = now + 30,
	})
	ctl.WelcomeBackController.show({ awaySec = 600, ripe = 3 })
	c.remotes.Toast.OnClientEvent:Fire({
		kind = "vipGate",
		text = "VIP",
		data = { key = "vip", name = "VIP Gardener", perks = { "a" }, robux = 249 },
	})
	c.remotes.Mutation.OnClientEvent:Fire({ tile = "1", mut = "wet", value = 20, newEntry = true })
	c.remotes.BlockPartyState.OnClientEvent:Fire({
		phase = "open",
		stage = "drooping",
		waters = 1,
		goal = 20,
		yourWaters = 1,
		endsAt = now + 300,
	})
	c.remotes.PatchLine.OnClientEvent:Fire({
		id = "plant",
		text = "Tap a tile to plant!",
		display = "toast",
		hideSec = 5,
	})
	c.engine:advance(0.3)
	return c
end

local function guis(c)
	local out = {}
	for _, g in c.engine.game.Players.LocalPlayer.PlayerGui:GetChildren() do
		table.insert(out, g)
	end
	return out
end

test("every ScreenGui scales with the viewport and keeps to CoreUISafeInsets", function()
	local c = everything()
	local n = 0
	for _, g in guis(c) do
		if g.ClassName == "ScreenGui" and not g.Name:match("^Capture") then -- the capture tool frames the whole shot
			n += 1
			eq(Layout.prop(g, "ScreenInsets", nil), c.engine.Enum.ScreenInsets.CoreUISafeInsets, g.Name)
			Assert.truthy(g:FindFirstChildOfClass("UIScale"), g.Name .. " has a UIScale")
		end
	end
	Assert.truthy(n >= 25, `{n} screens`)
end)

test("every tap target is at least 48 x 48 px at 1x", function()
	local c = everything()
	local vp = roblox.Vector2.new(1280, 720) -- UIScale 1
	local small = {}
	for _, g in guis(c) do
		for _, d in g:GetDescendants() do
			if d.ClassName == "TextButton" or d.ClassName == "ImageButton" then
				local size = Layout.size(d, vp)
				if size and (size.X < 48 - 0.01 or size.Y < 48 - 0.01) then
					table.insert(small, `{g.Name}/{d.Name} {math.floor(size.X)}x{math.floor(size.Y)}`)
				end
			end
		end
	end
	table.sort(small)
	if #small > 0 then
		print(table.concat(small, "\n"))
	end
	eq(small, {})
end)

-- the always-there and the pop-up pieces of the HUD that must never cover one another
local HUD = {
	{ "Hud", "Bar" },
	{ "Hud", "Buttons" },
	{ "Hud", "Rewards" },
	{ "Hud", "Toasts" },
	{ "BlockParty", "Meter" },
	{ "WeatherBanner", "Banner" },
	{ "PatchToast", "Toast" },
	{ "PatchBubble", "Bubble" },
	{ "PlaceBanner", "Banner" },
}

test("the HUD fits 4:3, 16:9 and 19.5:9 with no overlap; Patch's toast sits at the top, clear of the Basket", function()
	local c = everything()
	for _, device in DEVICES do
		local vp = device[2]
		local rects = {}
		for _, h in HUD do
			local g = c.gui(h[1])
			local obj = g and g:FindFirstChild(h[2])
			Assert.truthy(obj, `{h[1]}.{h[2]} exists`)
			local r = Layout.rect(obj, vp)
			Assert.truthy(
				r.x >= 0 and r.y >= 0 and r.x + r.w <= r.canvas.X + 0.01 and r.y + r.h <= r.canvas.Y + 0.01,
				`{device[1]}: {h[1]}.{h[2]} on screen`
			)
			table.insert(rects, { name = h[1] .. "." .. h[2], r = r })
		end
		for i = 1, #rects do
			for j = i + 1, #rects do
				Assert.truthy(
					not Layout.overlap(rects[i].r, rects[j].r),
					`{device[1]}: {rects[i].name} overlaps {rects[j].name}`
				)
			end
		end
		local toast = Layout.rect(c.gui("PatchToast").Toast, vp)
		Assert.truthy(toast.y <= 12.01, `{device[1]}: Patch's toast at the top`)
	end
end)

test("a plot streaming out and back in never errors on the client", function()
	local c = everything()
	local plots = c.engine.workspace.Street.Plots
	local other = plots.Plot2
	other:SetAttribute("OwnerId", 20)
	c.engine:advance(1)
	other.Parent = nil -- streamed out
	c.engine:advance(2)
	other.Parent = plots -- back in
	c.engine:advance(2)
	for _, plot in plots:GetChildren() do
		if plot.Name ~= "Plot1" then
			plot.Parent = nil
		end
	end
	c.engine:advance(2)
	eq(c.engine.errors, {})
end)
