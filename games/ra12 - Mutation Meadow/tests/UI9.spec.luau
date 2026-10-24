local Assert = require("./mock/Assert")
local Client = require("./mock/Client")

local test, eq = Assert.test, Assert.eq

local roblox = require("@lune/roblox")
local SIZES = { roblox.Vector2.new(1920, 1080), roblox.Vector2.new(390, 844) }

local URGENCY = {
	"limited",
	"hurry",
	"only ",
	"left",
	"sale",
	"% off",
	"ends",
	"timer",
	"last chance",
	"today",
	"now!",
	"discount",
}

local function texts(root)
	local out = {}
	for _, d in root:GetDescendants() do
		if (d.ClassName == "TextLabel" or d.ClassName == "TextButton") and type(d.Text) == "string" then
			table.insert(out, d.Text)
		end
	end
	return out
end

local function count(root, pattern)
	local n = 0
	for _, d in root:GetDescendants() do
		if d.Name:match(pattern) then
			n += 1
		end
	end
	return n
end

local function noUrgency(root, where)
	for _, t in texts(root) do
		local low = t:lower()
		for _, word in URGENCY do
			Assert.truthy(not low:find(word, 1, true), `{where}: "{t}" reads as urgency ({word})`)
		end
	end
end

test(
	"the Store: 4 tabs; the bundle card first with its resolved items and true worth; Owned tags; Buy prompts",
	function()
		local c = Client.boot()
		local me = c.engine.game.Players.LocalPlayer
		local HttpService = c.engine.game.HttpService
		me:SetAttribute(
			"BundleOffer",
			HttpService:JSONEncode({ grants = { "extraRow", "can_pumpkin", "trail_leaf" }, value = 357 })
		)
		me:SetAttribute("Pass_vip", true)
		Client.press(Client.find(c.gui("Hud"), "Store"))
		local gui = c.gui("Store")
		eq(gui.Enabled, true)
		eq(count(gui, "^Tab_"), 4)
		local bundle = Client.find(gui, "Card_starterBundle")
		eq(bundle.LayoutOrder, 1, "first in Passes")
		eq(Client.find(bundle, "Effect").Text, "Extra Plot Row + Pumpkin Watering Can + Leaf Swirl\nWorth 357 R$")
		eq(Client.find(bundle, "Price").Text, "249 R$")
		eq(Client.find(Client.find(gui, "Card_vip"), "Owned").Text, "Owned")
		eq(Client.find(Client.find(gui, "Card_vip"), "Buy"), nil)
		local gnome = Client.find(gui, "Card_gnome")
		eq(Client.find(gnome, "Price").Text, "299 R$")
		Assert.truthy(Client.find(gnome, "Effect").Text:find("12 studs"), "the exact effect")
		Client.press(Client.find(gnome, "Buy"))
		eq(Client.sent(c, "Purchase")[1], { "prompt", { key = "gnome", reqId = 1 } })
		noUrgency(gui, "Passes")
		me:SetAttribute("BundleOffer", nil)
		eq(Client.find(gui, "Card_starterBundle"), nil, "hidden without an offer")
		Client.press(Client.find(gui, "Tab_Boosts"))
		eq(count(gui, "^Card_"), 2)
		noUrgency(gui, "Boosts")
		Client.press(Client.find(gui, "Tab_Cosmetics"))
		eq(count(gui, "^Card_"), 9)
		eq(Client.find(Client.find(gui, "Card_theme_starry"), "Name").Text, "Starry Night Plot")
		eq(Client.find(Client.find(gui, "Card_theme_starry"), "Price").Text, "199 R$")
		noUrgency(gui, "Cosmetics")
	end
)

test("Gift a friend: pick a friend here, the gifts they own are hidden, Gift sends the friendId", function()
	local c = Client.boot()
	c.engine.friends["10:20"] = true
	local friend = c.engine:addPlayer(20, "Pal")
	friend:SetAttribute("Pass_vip", true)
	friend:SetAttribute("Cosmetics", "tag_star")
	c.controllers.StoreController.open("Gift")
	local gui = c.gui("Store")
	Client.press(Client.find(gui, "Friend_20"))
	eq(Client.find(gui, "Card_gift_vip"), nil, "they own VIP")
	eq(Client.find(gui, "Card_gift_tag_star"), nil, "they own Star Farmer")
	eq(Client.find(gui, "Card_gift_starterBundle"), nil, "never giftable")
	eq(count(gui, "^Card_gift_"), 11)
	Client.press(Client.find(Client.find(gui, "Card_gift_extraRow"), "Buy"))
	eq(Client.sent(c, "Purchase")[1], { "prompt", { key = "gift_extraRow", friendId = 20, reqId = 1 } })
	noUrgency(gui, "Gift")
end)

test("the VIP gate card: the pass, its perks, 249 R$ and Close, no urgency", function()
	local c = Client.boot()
	c.remotes.Toast.OnClientEvent:Fire({
		kind = "vipGate",
		text = "VIP Gardener",
		data = { key = "vip", name = "VIP Gardener", perks = { "A", "B", "C" }, robux = 249 },
	})
	local gui = c.gui("VipGate")
	eq(gui.Enabled, true)
	eq(Client.find(gui, "Buy").Text, "249 R$")
	eq(count(gui, "^Perk%d"), 3)
	noUrgency(gui, "VIP gate")
	Client.press(Client.find(gui, "Dismiss"))
	eq(gui.Enabled, false)
	eq(#Client.sent(c, "Purchase"), 0)
end)

test("the Wardrobe: owned, earned and perk items in 4 slots; Equip / Unequip", function()
	local c = Client.boot(function(p)
		p.cosmetics.owned = { trail_leaf = true, trail_petals = true, title_master = true }
		p.cosmetics.equipped = { trail = "trail_leaf" }
	end)
	c.engine.game.Players.LocalPlayer:SetAttribute("Pass_vip", true)
	c.controllers.WardrobeController.open()
	local gui = c.gui("Wardrobe")
	eq(count(gui, "^Slot_"), 4)
	local trail = Client.find(gui, "Slot_trail")
	eq(Client.find(trail, "Title").Text, "Trail: Leaf Swirl")
	Assert.truthy(
		Client.find(trail, "Item_trail_petals") and Client.find(trail, "Item_trail_vip_sparkle"),
		"earned + perk"
	)
	Assert.truthy(Client.find(Client.find(gui, "Slot_tag"), "Item_title_master"), "titles in the tag slot")
	Client.press(Client.find(trail, "Item_trail_petals"))
	eq(Client.sent(c, "Cosmetic")[1], { "equip", { slot = "trail", key = "trail_petals", reqId = 1 } })
	Client.press(Client.find(trail, "Item_trail_leaf"))
	eq(Client.sent(c, "Cosmetic")[2], { "equip", { slot = "trail", reqId = 2 } }, "tapping the worn one takes it off")
end)

test("gifts: Backpack Gift picks someone here; an offer shows Accept / Decline; a Robux gift has Gift back", function()
	local c = Client.boot(function(p)
		p.items["0000000A-0000-0000-0000-00000000000A"] =
			{ seed = "pumpkin", muts = { golden = true }, foundAt = 0, foundBy = 10, owner = 10, locked = false }
	end)
	c.engine:addPlayer(20, "Pal")
	c.controllers.BackpackController.open()
	Client.press(Client.find(c.gui("Backpack"), "Gift"))
	Client.press(Client.find(c.gui("GiveGift"), "To_20"))
	eq(
		Client.sent(c, "Gift")[1],
		{ "offer", { targetId = 20, item = "0000000A-0000-0000-0000-00000000000A", reqId = 1 } }
	)
	local now = c.engine.workspace:GetServerTimeNow()
	c.remotes.GiftOffer.OnClientEvent:Fire({
		giftId = "g1",
		fromId = 20,
		fromName = "Pal",
		seed = "corn",
		qty = 3,
		expiresAt = now + 30,
	})
	local offer = c.gui("GiftOffer")
	eq(offer.Enabled, true)
	eq(Client.find(offer, "Text").Text, "Pal wants to give you 3 Corn")
	Client.press(Client.find(offer, "Accept"))
	eq(Client.sent(c, "Gift")[2], { "respond", { giftId = "g1", accept = true, reqId = 2 } })
	c.remotes.GiftOffer.OnClientEvent:Fire({
		giftId = "g2",
		fromId = 20,
		fromName = "Pal",
		seed = "corn",
		qty = 1,
		expiresAt = now + 5,
	})
	c.engine:advance(6)
	eq(offer.Enabled, false, "closes when it runs out")
	c.remotes.Toast.OnClientEvent:Fire({
		kind = "gift",
		text = "🎁 Pal sent you Star Farmer!",
		data = { key = "tag_star", from = "Pal", button = "Gift back" },
	})
	local back = Client.find(c.gui("Hud"), "Action")
	eq(back.Text, "Gift back")
end)

test("Visit & Like: Like every farm here, Visit friends here and in other servers", function()
	local c = Client.boot(function(p)
		p.social.liked = { ["30"] = 1 }
	end)
	c.engine.friends["10:20"] = true
	c.engine:addPlayer(20, "Pal")
	c.engine:addPlayer(30, "Other")
	c.engine.friendsOnline[10] =
		{ { VisitorId = 40, DisplayName = "Far", PlaceId = c.engine.game.PlaceId, GameId = "s4" } }
	Client.press(Client.find(c.gui("Hud"), "Visit"))
	local gui = c.gui("Visit")
	local pal = Client.find(gui, "Farm_20")
	Assert.truthy(Client.find(pal, "Visit") and Client.find(pal, "Like"), "a friend: like + visit")
	local other = Client.find(gui, "Farm_30")
	eq(Client.find(other, "Visit"), nil, "not a friend")
	eq(Client.find(other, "Liked").Text, "♥ Liked")
	Client.press(Client.find(pal, "Like"))
	eq(Client.sent(c, "Social")[1], { "like", { ownerId = 20, reqId = 1 } })
	Client.press(Client.find(Client.find(gui, "Away_40"), "Visit"))
	eq(Client.sent(c, "Social")[2], { "visit", { friendId = 40, reqId = 2 } })
end)

test("Settings: the gnome toggle (owners only, also on the HUD) and the garden name", function()
	local c = Client.boot()
	local me = c.engine.game.Players.LocalPlayer
	c.controllers.HudController.openSettings()
	local gui = c.gui("Settings")
	eq(gui.Enabled, true)
	eq(Client.find(gui, "Set_gnomeOn"), nil)
	eq(Client.find(c.gui("Hud"), "Gnome").Visible, false)
	me:SetAttribute("Pass_gnome", true)
	eq(Client.find(gui, "Set_gnomeOn").Text, "Gnome: ON")
	eq(Client.find(c.gui("Hud"), "Gnome").Visible, true)
	Client.press(Client.find(c.gui("Hud"), "Gnome"))
	eq(Client.sent(c, "Settings")[1], { "set", { key = "gnomeOn", value = false, reqId = 1 } })
	Client.find(gui, "NameBox").Text = "Sunny Patch"
	Client.press(Client.find(gui, "SaveName"))
	eq(Client.sent(c, "Settings")[2], { "gardenName", { name = "Sunny Patch", reqId = 2 } })
	Client.press(Client.find(gui, "Wardrobe"))
	eq(c.gui("Wardrobe").Enabled, true)
end)

test("every M9 screen opens and closes on desktop and a phone", function()
	local c = Client.boot()
	for _, size in SIZES do
		c.engine.workspace.CurrentCamera.ViewportSize = size
		c.engine:advance(0.3)
		for _, pair in
			{
				{ "StoreController", "Store" },
				{ "WardrobeController", "Wardrobe" },
				{ "VisitController", "Visit" },
				{ "SettingsController", "Settings" },
			}
		do
			c.controllers[pair[1]].open()
			eq(c.gui(pair[2]).Enabled, true, pair[2])
			c.controllers[pair[1]].close()
			eq(c.gui(pair[2]).Enabled, false, pair[2])
		end
	end
	eq(c.engine.errors, {})
end)
