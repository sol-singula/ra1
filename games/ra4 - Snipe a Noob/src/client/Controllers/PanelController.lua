-- Pop-up panels, one at a time, sized for a phone:
--   Shop     today's Daily Shop (6 skins, 2 pop effects, 2 emotes) for coins
--   Rifles   your rifles: unlock, buy, hold, skins on each, mastery looks
--   Style    pop effects, emotes, crosshairs and kill-feed colours (buy crosshairs and colours here)
--   Quests   the daily gift and today's 3 quests
--   Crates   the Coin Crate and the Key Crate, each with its odds
--   Season   the season pass: 50 tiers, free and pass rewards
--   Store    Robux passes and products
--   Stall    a Trade Plaza stall: sell a skin for coins, or buy one
--   Crate    the reveal card after opening a crate
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local RifleModel = require(ReplicatedStorage.Shared.RifleModel)
local Rifles = require(ReplicatedStorage.Shared.Data.Rifles)
local Shop = require(ReplicatedStorage.Shared.Data.Shop)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)
local HudController = require(script.Parent.HudController)

local C = Theme.Color
local new = Theme.new
local player = Players.LocalPlayer

local PanelController = { Name = "PanelController", Order = 20 }

local gui, dim, card, titleLabel, body, header
local current, currentArg
local builders = {}
local stallPrice = Constants.STALL_PRICES[2]
local skinPick = {} -- [rifleKey] = showing the skin list
local styleTab = "effect"

local HEADER_COLORS = {
	Shop = C.pink,
	Rifles = C.sky,
	Style = C.teal,
	Quests = C.mustard,
	Crates = C.purple,
	Season = C.orange,
	Store = C.good,
	Stall = C.sky,
	Crate = C.purple,
}

local function clearBody()
	for _, c in body:GetChildren() do
		if not c:IsA("UIPadding") then
			c:Destroy()
		end
	end
end

function PanelController.close()
	current = nil
	dim.Visible = false
	ContextActionService:UnbindAction("ClosePanel")
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject = nil
	end
end

function PanelController.open(name, arg)
	if not builders[name] then
		return
	end
	if current == name and arg == nil and name ~= "Crate" then
		PanelController.close()
		return
	end
	current = name
	currentArg = arg
	dim.Visible = true
	header.BackgroundColor3 = HEADER_COLORS[name] or C.purple
	clearBody()
	builders[name](arg)
	dim.BackgroundTransparency = 1
	Theme.tween(dim, 0.2, { BackgroundTransparency = 0.45 })
	Theme.pop(card)
	ContextActionService:BindActionAtPriority("ClosePanel", function(_, state)
		if state == Enum.UserInputState.Begin then
			PanelController.close()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonB, Enum.KeyCode.Backspace)
end

function PanelController.current()
	return current
end

local function refreshOpen()
	if current and current ~= "Crate" then
		clearBody()
		builders[current](currentArg)
	end
end

-- Building blocks -------------------------------------------------------------------------------------------------
local function list(padding)
	new("UIListLayout", {
		Padding = UDim.new(0, padding or 8),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = body,
	})
end

local function line(text, props)
	local t = Theme.text({
		Text = text,
		TextSize = 18,
		TextScaled = false,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = body,
	})
	for k, v in props or {} do
		t[k] = v
	end
	return t
end

local function row(name, color, order, height)
	return new("Frame", {
		Name = name,
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, height or 64),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = body,
	}, { Theme.corner(14), Theme.stroke(3), Theme.gloss(Color3.fromRGB(255, 255, 255), Color3.fromRGB(205, 205, 205)) })
end

local function rowTitle(r, text, sub)
	Theme.title({
		Name = "Title",
		Text = text,
		TextSize = 19,
		TextScaled = false,
		Size = UDim2.new(1, -250, 0, 26),
		Position = UDim2.fromOffset(12, sub and 5 or 18),
		Parent = r,
	})
	if sub then
		Theme.text({
			Name = "Sub",
			Text = sub,
			TextSize = 14,
			TextScaled = false,
			TextColor3 = C.white,
			outline = 1.2,
			Size = UDim2.new(1, -250, 0, 22),
			Position = UDim2.fromOffset(12, 34),
			Parent = r,
		})
	end
end

local function rowButton(parent, name, text, color, x, w, onClick)
	local b = Theme.button({
		Name = name,
		Text = text,
		BackgroundColor3 = color,
		TextSize = 16,
		TextScaled = false,
		AnchorPoint = Vector2.new(1, 0.5),
		Size = UDim2.fromOffset(w or 110, 42),
		Position = UDim2.new(1, x, 0.5, 0),
		Parent = parent,
	})
	b.Activated:Connect(onClick)
	return b
end

local function tabs(order, items, selected, onPick)
	local bar = new("Frame", {
		Name = "Tabs",
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 40),
		BackgroundTransparency = 1,
		Parent = body,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = bar,
	})
	for _, it in items do
		local b = Theme.button({
			Name = "Tab_" .. it[1],
			Text = it[2],
			BackgroundColor3 = it[1] == selected and C.mustard or C.muted,
			TextSize = 15,
			TextScaled = false,
			Size = UDim2.fromOffset(130, 36),
			Parent = bar,
		})
		b.Activated:Connect(function()
			onPick(it[1])
		end)
	end
end

local function itemName(kind, id)
	if kind == "skin" then
		local s = Cosmetics.skinById[id]
		return s and s.name or id, s and s.rarity
	elseif kind == "effect" then
		local e = Cosmetics.effectById[id]
		return e and (e.name .. " pops") or id, e and e.rarity
	elseif kind == "emote" then
		local e = Cosmetics.emoteById[id]
		return e and (e.name .. " emote") or id, e and e.rarity
	end
	return id, nil
end

-- Shop --------------------------------------------------------------------------------------------------------------
builders.Shop = function()
	titleLabel.Text = "🛒 DAILY SHOP"
	list()
	local lo = Store.state.loadout
	local left = lo and lo.shopEndsAt and lo.shopEndsAt - os.time() or 0
	line(
		`New items in {Format.time(math.max(0, left))}. You have 💰 {Format.num(Store.state.coins or 0)}.`,
		{ TextColor3 = C.muted, LayoutOrder = 0 }
	)
	for i, item in lo and lo.shop or {} do
		local name, rarity = itemName(item.kind, item.id)
		local r = row("Item" .. i, Cosmetics.RarityColor[rarity] or C.muted, i)
		rowTitle(r, name, `{rarity or ""} {item.kind == "skin" and "rifle skin" or ""}`)
		if item.bought then
			rowButton(r, "Bought", "✅ BOUGHT", C.muted, -10, 130, function() end)
		else
			rowButton(r, "Buy", `💰 {Format.num(item.price)}`, C.good, -10, 130, function()
				Net.send("BuyShop", i)
			end)
		end
	end
end

-- Rifles ------------------------------------------------------------------------------------------------------------
builders.Rifles = function()
	titleLabel.Text = "🔫 RIFLES"
	list()
	local lo = Store.state.loadout
	local level = Store.state.level or 1
	line("Every rifle pops in one hit. They just play different!", { TextColor3 = C.muted, LayoutOrder = 0 })
	local order = 1
	for _, info in lo and lo.rifles or {} do
		local rifle = Rifles.byKey[info.key]
		local masteryText = info.tier > 0 and ` · {RifleModel.MASTERY_NAMES[info.tier]}` or ""
		local nextNeed = Constants.MASTERY[info.tier + 1]
		local sub = `{rifle.desc}  ·  {info.mastery}{nextNeed and ("/" .. nextNeed) or ""} pops{masteryText}`
		local r = row("Rifle_" .. info.key, info.equipped and C.mustard or C.sky, order, 70)
		order += 1
		local skinName = info.skin and Cosmetics.skinById[info.skin] and Cosmetics.skinById[info.skin].name
		rowTitle(r, `{info.equipped and "👉 " or ""}{rifle.name}{skinName and (" · " .. skinName) or ""}`, sub)
		if not info.owned then
			if info.locked then
				rowButton(r, "Locked", `🔒 LV {rifle.level}`, C.muted, -10, 120, function() end)
			else
				rowButton(r, "Buy", `💰 {Format.num(rifle.price)}`, C.good, -10, 120, function()
					Net.send("BuyRifle", info.key)
				end)
			end
		else
			if not info.equipped then
				rowButton(r, "Hold", "HOLD", C.good, -10, 90, function()
					Net.send("EquipRifle", info.key)
				end)
			end
			rowButton(r, "Skins", "🎨 SKIN", C.purple, info.equipped and -10 or -106, 96, function()
				skinPick[info.key] = not skinPick[info.key]
				refreshOpen()
			end)
		end
		if skinPick[info.key] and info.owned then
			local holder = new("Frame", {
				Name = "SkinsFor_" .. info.key,
				LayoutOrder = order,
				Size = UDim2.new(1, -8, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Parent = body,
			})
			order += 1
			new(
				"UIGridLayout",
				{ CellSize = UDim2.fromOffset(132, 40), CellPadding = UDim2.fromOffset(6, 6), Parent = holder }
			)
			local none = Theme.button({
				Name = "NoSkin",
				Text = "No skin",
				BackgroundColor3 = C.muted,
				TextSize = 14,
				TextScaled = false,
				Parent = holder,
			})
			none.Activated:Connect(function()
				Net.send("EquipSkin", info.key, nil)
			end)
			for _, s in lo.skins do
				local skin = Cosmetics.skinById[s.id]
				local b = Theme.button({
					Name = "Skin_" .. s.uid,
					Text = (s.on == info.key and "✅ " or "") .. (skin and skin.name or s.id),
					BackgroundColor3 = skin and Cosmetics.RarityColor[skin.rarity] or C.muted,
					TextSize = 14,
					TextScaled = false,
					Parent = holder,
				})
				b.Activated:Connect(function()
					Net.send("EquipSkin", info.key, s.uid)
				end)
			end
			if #lo.skins == 0 then
				line(
					"No skins yet: the Daily Shop and Crates have them!",
					{ LayoutOrder = order, TextColor3 = C.muted }
				)
				order += 1
			end
		end
	end
	_ = level
end

-- Style -------------------------------------------------------------------------------------------------------------
builders.Style = function()
	titleLabel.Text = "✨ STYLE"
	list()
	tabs(
		0,
		{
			{ "effect", "💥 POPS" },
			{ "emote", "🕺 EMOTES" },
			{ "crosshair", "🎯 AIM" },
			{ "nameColor", "🎨 NAME" },
		},
		styleTab,
		function(k)
			styleTab = k
			refreshOpen()
		end
	)
	local lo = Store.state.loadout or {}
	local kinds = {
		effect = {
			list = Cosmetics.PopEffects,
			owned = lo.effects,
			on = lo.effect,
			help = "What players pop into when you get them.",
		},
		emote = { list = Cosmetics.Emotes, owned = lo.emotes, on = lo.emote, help = "What you do on the podium." },
		crosshair = {
			list = Cosmetics.Crosshairs,
			owned = lo.crosshairs,
			on = lo.crosshair,
			help = "Your aim dot.",
			buy = true,
		},
		nameColor = {
			list = Cosmetics.NameColors,
			owned = lo.nameColors,
			on = lo.nameColor,
			help = "Your name in the kill feed.",
			buy = true,
		},
	}
	local k = kinds[styleTab]
	line(k.help, { TextColor3 = C.muted, LayoutOrder = 1 })
	for i, item in k.list do
		local owned = k.owned and k.owned[item.id]
		local color = item.color or Cosmetics.RarityColor[item.rarity] or C.muted
		local r = row("Style_" .. item.id, color, i + 1, 56)
		rowTitle(r, (k.on == item.id and "✅ " or "") .. item.name, item.rarity)
		if owned then
			if k.on ~= item.id then
				rowButton(r, "Use", "USE", C.good, -10, 90, function()
					Net.send("EquipStyle", styleTab, item.id)
				end)
			end
		elseif k.buy then
			rowButton(r, "Buy", `💰 {Format.num(item.price)}`, C.good, -10, 120, function()
				Net.send("BuyStyle", styleTab, item.id)
			end)
		else
			rowButton(r, "Where", "SHOP / SEASON", C.muted, -10, 150, function()
				PanelController.open("Shop")
			end)
		end
	end
end

-- Quests --------------------------------------------------------------------------------------------------------------
builders.Quests = function()
	titleLabel.Text = "📜 DAILY QUESTS"
	list()
	local s = Store.state
	local d = s.daily
	if d then
		local r = row("Daily", d.canClaim and C.pink or C.muted, 0, 70)
		rowTitle(r, `🎁 Daily gift · day {d.nextDay}`, d.gifts and d.gifts[((d.nextDay - 1) % #d.gifts) + 1] or "")
		if d.canClaim then
			rowButton(r, "Claim", "CLAIM", C.good, -10, 100, function()
				Net.send("ClaimDaily")
			end)
		else
			rowButton(r, "Wait", Format.time(d.secondsToNext or 0), C.muted, -10, 110, function() end)
		end
	end
	local q = s.quests
	for i, item in q and q.list or {} do
		local r = row("Quest" .. i, item.done and C.good or C.sky, i, 70)
		rowTitle(
			r,
			(item.done and "✅ " or "") .. item.text,
			`{item.progress} / {item.target} · reward {item.reward}`
		)
		if not item.done and q.canSwap then
			rowButton(r, "Swap", `🔁 {q.swapCoins}`, C.purple, -10, 100, function()
				Net.send("RerollQuest", i)
			end)
		end
	end
	line("New quests every day. Swap one a day for coins.", { TextColor3 = C.muted, LayoutOrder = 10 })
end

-- Crates --------------------------------------------------------------------------------------------------------------
builders.Crates = function()
	titleLabel.Text = "🎁 CRATES"
	list()
	local s = Store.state
	line(
		`You have 💰 {Format.num(s.coins or 0)} and 🔑 {s.keys or 0}. Every skin works on every rifle.`,
		{ TextColor3 = C.muted, LayoutOrder = 0 }
	)
	local order = 1
	for _, crate in Cosmetics.Crates do
		if crate.paid and s.canPaidRandom == false then
			continue
		end
		local r = row("Crate_" .. crate.key, crate.paid and C.purple or C.orange, order, 64)
		order += 1
		rowTitle(
			r,
			`{crate.emoji} {crate.name}`,
			crate.coins and `💰 {Format.num(crate.coins)}` or `🔑 {crate.keys} key`
		)
		rowButton(r, "Open", "OPEN", C.good, -10, 100, function()
			Net.send("OpenCrate", crate.key)
		end)
		if crate.keys and (s.keys or 0) < crate.keys then
			rowButton(r, "GetKeys", "GET KEYS", C.mustard, -116, 110, function()
				PanelController.open("Store")
			end)
		end
		-- the odds, always shown
		local odds = Theme.text({
			Name = "Odds_" .. crate.key,
			LayoutOrder = order,
			Text = "ℹ️ Odds: " .. table.concat(Formulas.oddsLines(crate.key), "  ·  "),
			TextSize = 13,
			TextScaled = false,
			TextColor3 = C.ink,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, -16, 0, 0),
			Parent = body,
		})
		odds.TextXAlignment = Enum.TextXAlignment.Left
		order += 1
	end
	if s.canPaidRandom == false then
		line("Key crates aren't available on your account.", { TextColor3 = C.muted, LayoutOrder = order })
	end
end

builders.Crate = function(info)
	titleLabel.Text = "🎁 YOU GOT..."
	list(12)
	local skin = Cosmetics.skinById[info.skin]
	local r = row("Reveal", skin and Cosmetics.RarityColor[skin.rarity] or C.muted, 1, 120)
	Theme.title({
		Name = "Name",
		Text = skin and skin.name or "?",
		TextSize = 40,
		TextScaled = false,
		Size = UDim2.new(1, 0, 0, 50),
		Position = UDim2.fromOffset(0, 16),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = r,
	})
	Theme.text({
		Name = "Rarity",
		Text = skin and (skin.rarity:upper() .. " SKIN") or "",
		TextSize = 20,
		TextScaled = false,
		TextColor3 = C.white,
		outline = 1.5,
		Size = UDim2.new(1, 0, 0, 28),
		Position = UDim2.fromOffset(0, 72),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = r,
	})
	local again = Theme.button({
		Name = "Again",
		Text = "OPEN ANOTHER",
		BackgroundColor3 = C.good,
		LayoutOrder = 2,
		Size = UDim2.fromOffset(200, 46),
		Parent = body,
	})
	again.Activated:Connect(function()
		Net.send("OpenCrate", info.crate)
	end)
	local wear = Theme.button({
		Name = "Wear",
		Text = "PUT IT ON",
		BackgroundColor3 = C.sky,
		LayoutOrder = 3,
		Size = UDim2.fromOffset(200, 46),
		Parent = body,
	})
	wear.Activated:Connect(function()
		PanelController.open("Rifles")
	end)
end

-- Season --------------------------------------------------------------------------------------------------------------
builders.Season = function()
	titleLabel.Text = "🏅 SEASON"
	list()
	local se = Store.state.season
	if not se then
		line("Loading...")
		return
	end
	line(
		`Season {se.n} · ends in {Format.time(math.max(0, se.endsAt - os.time()))} · tier {se.tier} / {Constants.SEASON_TIERS}`,
		{ LayoutOrder = 0, TextColor3 = C.ink }
	)
	if not se.pass then
		local r = row("GetPass", C.orange, 1, 60)
		rowTitle(r, "🏅 Season Pass", "Unlock every pass reward this season")
		rowButton(r, "Buy", "R$ " .. Shop.byKey.SEASON.price, C.good, -10, 110, function()
			Net.send("Purchase", "product", "SEASON")
		end)
	end
	local function rewardText(rw)
		if not rw then
			return ""
		end
		if rw.coins then
			return `{rw.coins} 💰`
		elseif rw.keys then
			return `{rw.keys} 🔑`
		elseif rw.skin then
			return (Cosmetics.skinById[rw.skin] and Cosmetics.skinById[rw.skin].name or rw.skin) .. " skin"
		elseif rw.effect then
			return (Cosmetics.effectById[rw.effect] and Cosmetics.effectById[rw.effect].name or rw.effect) .. " pops"
		elseif rw.emote then
			return (Cosmetics.emoteById[rw.emote] and Cosmetics.emoteById[rw.emote].name or rw.emote) .. " emote"
		end
		return ""
	end
	-- show the next few tiers you can claim or reach
	local first = math.max(1, se.tier - 2)
	for tier = first, math.min(Constants.SEASON_TIERS, first + 7) do
		local free, pass = Formulas.seasonReward(tier)
		local reached = se.tier >= tier
		local r = row("Tier" .. tier, reached and C.sky or C.muted, tier + 1, 60)
		rowTitle(r, `Tier {tier}`, `Free: {rewardText(free)}  ·  Pass: {rewardText(pass)}`)
		local claimedF = se.claimed[tier .. "f"]
		local claimedP = se.claimed[tier .. "p"]
		if reached and not claimedF then
			rowButton(r, "ClaimFree", "FREE", C.good, -10, 80, function()
				Net.send("ClaimSeason", tier, "free")
			end)
		end
		if reached and se.pass and not claimedP then
			rowButton(r, "ClaimPass", "PASS", C.orange, -96, 80, function()
				Net.send("ClaimSeason", tier, "pass")
			end)
		end
	end
	line(
		`Earn season XP by playing. {Constants.SEASON_TIER_XP} XP per tier.`,
		{ LayoutOrder = 99, TextColor3 = C.muted }
	)
end

-- Store (Robux) -----------------------------------------------------------------------------------------------------
builders.Store = function()
	titleLabel.Text = "💎 STORE"
	list()
	local owned = Store.state.passes or {}
	local order = 0
	for _, p in Shop.Passes do
		local r = row("Pass_" .. p.key, C.mustard, order, 62)
		order += 1
		rowTitle(r, p.name, p.desc)
		if owned[p.key] then
			rowButton(r, "Owned", "✅ OWNED", C.muted, -10, 120, function() end)
		else
			local b
			b = rowButton(r, "Buy", "R$ " .. p.price, C.good, -10, 120, function()
				if Theme.busy(b) then
					Net.send("Purchase", "pass", p.key)
				end
			end)
		end
	end
	for _, p in Shop.Products do
		if p.key ~= "REVIVE" then
			local r = row("Product_" .. p.key, C.sky, order, 62)
			order += 1
			rowTitle(r, p.name, p.desc or (p.keys and "Open Key Crates" or ""))
			local b
			b = rowButton(r, "Buy", "R$ " .. p.price, C.good, -10, 120, function()
				if Theme.busy(b) then
					Net.send("Purchase", "product", p.key)
				end
			end)
		end
	end
	line("Nothing here makes your rifle shoot better.", { TextColor3 = C.muted, LayoutOrder = order })
end

-- Trade stall -----------------------------------------------------------------------------------------------------------
builders.Stall = function(index)
	titleLabel.Text = `🏪 STALL {index}`
	list()
	local stalls = Store.state.stalls or {}
	local s = stalls[index]
	if Store.state.canTrade == false then
		line("Trading isn't available on your account.", { TextColor3 = C.muted })
		return
	end
	if s and s.sellerId ~= player.UserId then
		local skin = Cosmetics.skinById[s.skin]
		local r = row("Offer", skin and Cosmetics.RarityColor[skin.rarity] or C.muted, 1, 70)
		rowTitle(r, skin and skin.name or s.skin, `by {s.seller}`)
		rowButton(r, "BuyStall", `💰 {Format.num(s.price)}`, C.good, -10, 130, function()
			Net.send("BuyStall", index)
		end)
		return
	elseif s then
		local r = row("Mine", C.mustard, 1, 70)
		local skin = Cosmetics.skinById[s.skin]
		rowTitle(
			r,
			`Your {skin and skin.name or s.skin}`,
			`For 💰 {Format.num(s.price)} (you get {Format.num(math.floor(s.price * (1 - Constants.TRADE_TAX)))})`
		)
		rowButton(r, "Unlist", "TAKE BACK", C.red, -10, 130, function()
			Net.send("Unlist", index)
		end)
		return
	end
	line(
		`Pick a price, then a skin. The plaza keeps {math.floor(Constants.TRADE_TAX * 100)}%.`,
		{ TextColor3 = C.muted, LayoutOrder = 0 }
	)
	local prices = new("Frame", {
		Name = "Prices",
		LayoutOrder = 1,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = body,
	})
	new("UIGridLayout", { CellSize = UDim2.fromOffset(110, 36), CellPadding = UDim2.fromOffset(6, 6), Parent = prices })
	for _, price in Constants.STALL_PRICES do
		local b = Theme.button({
			Name = "Price_" .. price,
			Text = Format.num(price),
			BackgroundColor3 = price == stallPrice and C.mustard or C.muted,
			TextSize = 15,
			TextScaled = false,
			Parent = prices,
		})
		b.Activated:Connect(function()
			stallPrice = price
			refreshOpen()
		end)
	end
	local lo = Store.state.loadout
	for i, sk in lo and lo.skins or {} do
		local skin = Cosmetics.skinById[sk.id]
		local r = row("Sell_" .. sk.uid, skin and Cosmetics.RarityColor[skin.rarity] or C.muted, i + 1, 56)
		rowTitle(r, skin and skin.name or sk.id, skin and skin.rarity)
		rowButton(r, "List", `SELL {Format.num(stallPrice)}`, C.good, -10, 130, function()
			Net.send("ListStall", index, sk.uid, stallPrice)
		end)
	end
	if not lo or #lo.skins == 0 then
		line("You have no skins to sell yet.", { TextColor3 = C.muted, LayoutOrder = 99 })
	end
end

function PanelController:init()
	gui = Theme.screen("Panels", 15, player:WaitForChild("PlayerGui"))
	dim = new("TextButton", {
		Name = "Dim",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = gui,
	})
	dim.Activated:Connect(PanelController.close)
	card = Theme.card({
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(620, 470),
		Position = UDim2.fromScale(0.5, 0.5),
		Parent = dim,
	})
	header = new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = C.purple,
		BorderSizePixel = 0,
		Parent = card,
	}, { Theme.corner(18), Theme.gloss() })
	titleLabel = Theme.title({
		Name = "Title",
		Text = "",
		Size = UDim2.new(1, -80, 1, -12),
		Position = UDim2.fromOffset(20, 6),
		Parent = header,
	})
	local close = Theme.button({
		Name = "Close",
		Text = "✕",
		BackgroundColor3 = C.red,
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(50, 50),
		Position = UDim2.new(1, 8, 0, -8),
		round = true,
		Parent = card,
	})
	close.Activated:Connect(PanelController.close)
	body = new("ScrollingFrame", {
		Name = "Body",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(14, 76),
		Size = UDim2.new(1, -28, 1, -88),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = card,
	}, { new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 12) }) })
	HudController.openPanel = PanelController.open
	Store.Changed:Connect(function(partial)
		if
			current
			and (
				partial.loadout
				or partial.coins
				or partial.keys
				or partial.passes
				or partial.quests
				or partial.daily
				or partial.season
				or partial.stalls
				or partial.level
			)
		then
			refreshOpen()
		end
	end)
	Net.listen("Crate", function(info)
		PanelController.open("Crate", info)
	end)
	-- the lobby counters open their panels
	local PROMPTS = {
		Prompt_shop = "Shop",
		Prompt_crates = "Crates",
		Prompt_rifles = "Rifles",
		Prompt_style = "Style",
		Prompt_season = "Season",
	}
	pcall(function()
		ProximityPromptService.PromptTriggered:Connect(function(prompt)
			if PROMPTS[prompt.Name] then
				PanelController.open(PROMPTS[prompt.Name])
			elseif prompt.Name == "Prompt_stall" then
				PanelController.open("Stall", tonumber(string.match(prompt.ObjectText, "%d+")))
			end
		end)
	end)
	-- close any panel when you go into a round
	player:GetAttributeChangedSignal("Zone"):Connect(function()
		local z = player:GetAttribute("Zone")
		if current and (z == "arena" or z == "duel") then
			PanelController.close()
		end
	end)
end

return PanelController
