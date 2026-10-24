--[[
The Store: tabs Passes, Boosts, Cosmetics and Gift a friend. Each card shows the icon, the name, exactly what it
does, the Robux price and an Owned tag; Buy sends Purchase:prompt {key}. No timers, countdowns, discounts or urgency
copy anywhere.

The Starter Bundle card comes first in Passes: the 3 items it would grant right now (with any substitutes) and
"Worth <value> R$", the true sum, from the BundleOffer player attribute the server keeps. No attribute = hidden.

Gift a friend: pick a friend (in this server, or online elsewhere), then a gift card; a gift the friend already owns
(their Pass_<key> / Cosmetics attributes) is hidden. Also the VIP gate card (Toast kind "vipGate") with the pass,
its perks, the price and Close.

  StoreController.open(tab?) / close() / isOpen() / setTab(tab) / fill()
  StoreController.owns(key, player?) -> boolean
  StoreController.EFFECTS / ICONS
  StoreController.bundleOffer() -> { grants, value } | nil
  StoreController.giftTo(userId)      opens Gift a friend with that friend picked
]]
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Gifting = require(ReplicatedStorage.Shared.Gifting)
local Net = require(ReplicatedStorage.Shared.Net)
local ClientState = require(script.Parent.Parent.ClientState)
local UI = require(script.Parent.Parent.UI)

local StoreController = {}

StoreController.TABS =
	{ { "Passes", "Passes" }, { "Boosts", "Boosts" }, { "Cosmetics", "Cosmetics" }, { "Gift", "Gift a friend" } }

StoreController.EFFECTS = {
	extraRow = "+8 tiles in a bed in front of your plot",
	vip = "VIP name tag, border and sparkle trail in brushed brass, and the VIP Lounge",
	gnome = "Harvests ripe normal crops within 12 studs of you every 2s while you stand on your plot",
	doubleCash = "Selling crops and kept items pays 2x (rewards and gifts stay the same)",
	starterBundle = "Extra Plot Row and two cosmetics",
	instantGrow = "One growing crop is ripe now",
	growAll = "Every growing crop on your plot is ripe now",
	tag_sprout = "A name tag over your head",
	tag_star = "A name tag over your head",
	trail_leaf = "A trail behind you as you walk",
	trail_firefly = "A trail behind you as you walk",
	can_pumpkin = "A new look for your watering can",
	can_crystal = "A new look for your watering can",
	theme_cherry = "Recolours your whole plot",
	theme_candy = "Recolours your whole plot",
	theme_starry = "Recolours your whole plot",
}

StoreController.ICONS = {
	extraRow = "🟫",
	vip = "🎟️",
	gnome = "🧙",
	doubleCash = "💰",
	starterBundle = "🎁",
	instantGrow = "⚡",
	growAll = "🌱",
	tag_sprout = "🌱",
	tag_star = "⭐",
	trail_leaf = "🍃",
	trail_firefly = "✨",
	can_pumpkin = "🎃",
	can_crystal = "💎",
	theme_cherry = "🌸",
	theme_candy = "🍬",
	theme_starry = "🌌",
}

local PASS_ORDER = { "starterBundle", "extraRow", "vip", "gnome", "doubleCash" }

local modal, vipCard
local tab = "Passes"
local giftFriend -- { userId, name }

local function ordered(group)
	local keys = {}
	for key in group do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		if group[a].robux ~= group[b].robux then
			return group[a].robux < group[b].robux
		end
		return a < b
	end)
	return keys
end

local function nameOf(key)
	local C = Config.Catalog
	local item = C.passes[key] or C.products[key] or C.cosmetics[key]
	return item and item.name or key
end

function StoreController.owns(key, player)
	player = player or Players.LocalPlayer
	if Config.Catalog.passes[key] then
		return player:GetAttribute("Pass_" .. key) == true
	end
	local list = player:GetAttribute("Cosmetics")
	if type(list) == "string" and table.find(string.split(list, ","), key) then
		return true
	end
	return player == Players.LocalPlayer and ClientState.get("cosmetics", "owned", key) == true
end

function StoreController.bundleOffer()
	local raw = Players.LocalPlayer:GetAttribute("BundleOffer")
	if type(raw) ~= "string" then
		return nil
	end
	local ok, offer = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	return if ok then offer else nil
end

local function buy(payload)
	Net.request("Purchase", "prompt", payload)
end

local function card(parent, key, item, order, opts)
	opts = opts or {}
	local c =
		UI.frame(parent, { Name = "Card_" .. key, LayoutOrder = order, Size = UDim2.new(1, -8, 0, opts.height or 96) })
	UI.label(c, StoreController.ICONS[key] or "🎁", {
		Name = "Icon",
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(48, 48),
	})
	UI.label(c, opts.name or item.name, {
		Name = "Name",
		Position = UDim2.fromOffset(64, 6),
		Size = UDim2.new(1, -200, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	UI.label(c, opts.effect or StoreController.EFFECTS[key] or "", {
		Name = "Effect",
		Position = UDim2.fromOffset(64, 36),
		Size = UDim2.new(1, -200, 0, opts.effectHeight or 40),
		TextWrapped = true,
		TextScaled = false,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	UI.label(c, `{item.robux} R$`, {
		Name = "Price",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 6),
		Size = UDim2.fromOffset(120, 26),
	})
	if opts.owned then
		UI.label(c, "Owned", {
			Name = "Owned",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 40),
			Size = UDim2.fromOffset(120, 40),
			TextColor3 = UI.COLORS.green,
		})
	else
		UI.button(c, opts.buyText or "Buy", function()
			buy(opts.payload or { key = key })
		end, {
			Name = "Buy",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 36),
			Size = UDim2.fromOffset(120, 48),
		})
	end
	return c
end

local function list()
	local frame = Instance.new("ScrollingFrame")
	frame.Name = "List"
	frame.BackgroundTransparency = 1
	frame.LayoutOrder = 2
	frame.Size = UDim2.new(1, 0, 1, -64)
	frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	frame.CanvasSize = UDim2.new()
	frame.Parent = modal.body
	UI.list(frame, 6)
	return frame
end

local function fillPasses(parent)
	local C = Config.Catalog
	for i, key in PASS_ORDER do
		local pass = C.passes[key]
		if key == "starterBundle" then
			local offer = StoreController.bundleOffer()
			if offer then
				local names = {}
				for _, g in offer.grants do
					table.insert(names, nameOf(g))
				end
				card(parent, key, pass, i, {
					effect = table.concat(names, " + ") .. `\nWorth {offer.value} R$`,
					height = 112,
					effectHeight = 60,
				})
			end
		else
			card(parent, key, pass, i, { owned = StoreController.owns(key) })
		end
	end
end

local function fillBoosts(parent)
	for i, key in ordered(Config.Catalog.products) do
		card(parent, key, Config.Catalog.products[key], i)
	end
end

local function fillCosmetics(parent)
	for i, key in ordered(Config.Catalog.cosmetics) do
		card(parent, key, Config.Catalog.cosmetics[key], i, { owned = StoreController.owns(key) })
	end
end

-- friends here, then friends online elsewhere in this game
local function friends()
	local out, seen = {}, {}
	local me = Players.LocalPlayer
	for _, p in Players:GetPlayers() do
		if p ~= me then
			local ok, yes = pcall(function()
				return me:IsFriendsWith(p.UserId)
			end)
			if ok and yes then
				table.insert(out, { userId = p.UserId, name = p.DisplayName, here = p })
				seen[p.UserId] = true
			end
		end
	end
	local ok, online = pcall(function()
		return me:GetFriendsOnline()
	end)
	if ok then
		for _, f in online do
			if not seen[f.VisitorId] and f.PlaceId == game.PlaceId then
				table.insert(out, { userId = f.VisitorId, name = f.DisplayName or f.UserName or tostring(f.VisitorId) })
			end
		end
	end
	return out
end

local function friendOwns(friend, key)
	if not friend.here then
		return false -- the server checks again for friends here; elsewhere it can't know
	end
	local passes, cosmetics = {}, {}
	for k in Config.Catalog.passes do
		passes[k] = friend.here:GetAttribute("Pass_" .. k) == true
	end
	for k in Config.Catalog.cosmetics do
		cosmetics[k] = StoreController.owns(k, friend.here)
	end
	local ok = Gifting.canGift("gift_" .. key, { passes = passes, cosmetics = cosmetics })
	return not ok
end

local function fillGift(parent)
	local people = friends()
	if #people == 0 then
		UI.label(parent, "No friends online right now.", { Name = "NoFriends", LayoutOrder = 1 })
		return
	end
	if not giftFriend then
		for i, f in people do
			UI.button(parent, "🎁 " .. f.name, function()
				giftFriend = f
				StoreController.fill()
			end, { Name = "Friend_" .. f.userId, LayoutOrder = i })
		end
		return
	end
	UI.button(parent, "◀ " .. giftFriend.name, function()
		giftFriend = nil
		StoreController.fill()
	end, { Name = "Back", LayoutOrder = 0, BackgroundColor3 = UI.COLORS.grey })
	local i = 0
	for _, groupName in { "passes", "cosmetics" } do
		for _, key in ordered(Config.Catalog[groupName]) do
			local gift = Config.Catalog.gifts["gift_" .. key]
			if gift and not friendOwns(giftFriend, key) then
				i += 1
				local c = card(parent, "gift_" .. key, gift, i, {
					name = gift.name,
					effect = StoreController.EFFECTS[key],
					buyText = "Gift",
					payload = { key = "gift_" .. key, friendId = giftFriend.userId },
				})
				c.Icon.Text = StoreController.ICONS[key] or "🎁"
			end
		end
	end
end

function StoreController.fill()
	modal.clear()
	local tabs = Instance.new("Frame")
	tabs.Name = "Tabs"
	tabs.BackgroundTransparency = 1
	tabs.LayoutOrder = 1
	tabs.Size = UDim2.new(1, 0, 0, 52)
	tabs.Parent = modal.body
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0.25, -6, 1, 0)
	layout.CellPadding = UDim2.fromOffset(6, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = tabs
	for i, t in StoreController.TABS do
		UI.button(tabs, t[2], function()
			StoreController.setTab(t[1])
		end, {
			Name = "Tab_" .. t[1],
			LayoutOrder = i,
			BackgroundColor3 = if t[1] == tab then UI.COLORS.green else UI.COLORS.grey,
		})
	end
	local parent = list()
	if tab == "Passes" then
		fillPasses(parent)
	elseif tab == "Boosts" then
		fillBoosts(parent)
	elseif tab == "Cosmetics" then
		fillCosmetics(parent)
	else
		fillGift(parent)
	end
end

function StoreController.setTab(t)
	tab = t
	if t ~= "Gift" then
		giftFriend = nil
	end
	StoreController.fill()
end

function StoreController.open(t)
	tab = t or tab
	StoreController.fill()
	modal.open()
end

function StoreController.close()
	modal.close()
end

function StoreController.isOpen()
	return modal.isOpen()
end

function StoreController.giftTo(userId)
	giftFriend = nil
	for _, f in friends() do
		if f.userId == userId then
			giftFriend = f
		end
	end
	StoreController.open("Gift")
end

local function showVipCard(data)
	vipCard.clear()
	UI.label(vipCard.body, data.name, { Name = "Name" })
	for i, perk in data.perks or {} do
		UI.label(vipCard.body, "• " .. perk, {
			Name = "Perk" .. i,
			Size = UDim2.new(1, 0, 0, 28),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end
	UI.button(vipCard.body, `{data.robux} R$`, function()
		buy({ key = data.key })
		vipCard.close()
	end, { Name = "Buy" })
	UI.button(vipCard.body, "Close", vipCard.close, { Name = "Dismiss", BackgroundColor3 = UI.COLORS.grey })
	vipCard.open()
end

function StoreController:Start()
	modal = UI.modal("Store", "Store")
	modal.card.Size = UDim2.fromOffset(620, 600)
	vipCard = UI.modal("VipGate", "VIP Lounge")
	vipCard.card.Size = UDim2.fromOffset(420, 420)
	Net.on("Toast", function(t)
		if type(t) == "table" and t.kind == "vipGate" and type(t.data) == "table" then
			showVipCard(t.data)
		end
	end)
	local me = Players.LocalPlayer
	me.AttributeChanged:Connect(function()
		if modal.isOpen() then
			StoreController.fill()
		end
	end)
	ClientState.Changed:Connect(function(roots)
		if modal.isOpen() and (roots == nil or roots.cosmetics) then
			StoreController.fill()
		end
	end)
end

return StoreController
