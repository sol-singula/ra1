-- Pop-up panels: Shop (boosts and passes), Speed (upgrades), Gift (daily streak) and Welcome Back (coins
-- earned while away). One panel at a time: a coloured header, a round close button on the corner, big glossy
-- buttons, and a little pop when it opens. Sized to fit a phone in landscape.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Shop = require(ReplicatedStorage.Shared.Data.Shop)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)
local HudController = require(script.Parent.HudController)

local C = Theme.Color
local new = Theme.new
local player = Players.LocalPlayer

local PanelController = { Name = "PanelController", Order = 20 }

local gui, dim, card, titleLabel, body, header
local current
local builders = {}
local shopTab = "boosts"

local tabs

local function clearBody()
	for _, c in body:GetChildren() do
		if not c:IsA("UIPadding") then
			c:Destroy()
		end
	end
	tabs.Visible = false
	body.Position = UDim2.fromOffset(14, 82)
	body.Size = UDim2.new(1, -28, 1, -94)
end

local HEADER_COLORS = { Shop = C.purple, Speed = C.sky, Gift = C.pink, Offline = C.good }

function PanelController.close()
	current = nil
	dim.Visible = false
end

function PanelController.open(name)
	if current == name then
		PanelController.close()
		return
	end
	current = name
	dim.Visible = true
	header.BackgroundColor3 = HEADER_COLORS[name] or C.purple
	clearBody()
	builders[name]()
	Theme.pop(card)
end

local function refreshOpen()
	if current then
		clearBody()
		builders[current]()
	end
end

local function line(text, props)
	local t = Theme.text({
		Text = text,
		TextSize = 22,
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

-- A big outlined line (headline inside a panel).
local function headline(text, size, color)
	return Theme.title({
		Text = text,
		TextSize = size or 30,
		TextScaled = false,
		TextColor3 = color or C.white,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = body,
	})
end

local function list(padding)
	new("UIListLayout", {
		Padding = UDim.new(0, padding or 10),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = body,
	})
end

-- Shop -------------------------------------------------------------------------------------------------------
local CARD_COLORS = { C.purple, C.sky, C.mustard, C.pink, C.teal, C.orange, C.good, C.red }

local function shopCard(item, kind, order)
	local owned = kind == "pass" and (Store.state.passes or {})[item.key]
	local cell = Theme.card({ Name = item.key, LayoutOrder = order, BackgroundColor3 = C.white, Parent = body })
	cell.ClipsDescendants = true
	local top = new("Frame", {
		Name = "Top",
		Size = UDim2.new(1, 0, 0, 84),
		BackgroundColor3 = CARD_COLORS[(order - 1) % #CARD_COLORS + 1],
		BorderSizePixel = 0,
		Parent = cell,
	}, { Theme.corner(16), Theme.gloss(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 190, 190)) })
	Theme.text({
		Text = item.icon,
		Size = UDim2.new(1, 0, 0, 58),
		Position = UDim2.fromOffset(0, 12),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = top,
	})
	Theme.text({
		Text = item.name,
		Font = Theme.Display,
		Size = UDim2.new(1, -12, 0, 24),
		Position = UDim2.fromOffset(6, 90),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = cell,
	})
	Theme.text({
		Text = item.text,
		TextSize = 14,
		TextScaled = false,
		TextColor3 = C.muted,
		Size = UDim2.new(1, -14, 0, 40),
		Position = UDim2.fromOffset(7, 114),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = cell,
	})
	local buy = Theme.button({
		Name = "Buy",
		Text = owned and "OWNED ✓" or ("R$ " .. item.price),
		BackgroundColor3 = owned and Color3.fromRGB(150, 150, 165) or C.good,
		Size = UDim2.new(1, -18, 0, 42),
		Position = UDim2.new(0, 9, 1, -50),
		round = true,
		Parent = cell,
	})
	buy.Activated:Connect(function()
		if not owned then
			Net.send("Purchase", kind, item.key)
		end
	end)
end

builders.Shop = function()
	titleLabel.Text = "🛒 SHOP"
	tabs.Visible = true
	body.Position = UDim2.fromOffset(14, 134)
	body.Size = UDim2.new(1, -28, 1, -146)
	for _, b in tabs:GetChildren() do
		if b:IsA("TextButton") then
			b.BackgroundColor3 = shopTab == b.Name and C.mustard or Color3.fromRGB(165, 160, 185)
		end
	end
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(172, 206),
		CellPadding = UDim2.fromOffset(10, 10),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = body,
	})
	if shopTab == "boosts" then
		for i, p in Shop.Products do
			if not p.hidden then
				shopCard(p, "product", i)
			end
		end
	else
		for i, p in Shop.Passes do
			shopCard(p, "pass", i)
		end
	end
end

-- Speed ------------------------------------------------------------------------------------------------------
builders.Speed = function()
	titleLabel.Text = "👟 SPEED"
	list(12)
	local s = Store.state
	local level = s.speedLevel or 1
	headline(`LEVEL {level} / {Constants.MAX_SPEED_LEVEL}`, 34, C.sky)
	local meter =
		new("Frame", { Name = "Meter", BackgroundTransparency = 1, Size = UDim2.fromOffset(440, 30), Parent = body })
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 4),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = meter,
	})
	for i = 1, Constants.MAX_SPEED_LEVEL do
		new("Frame", {
			Name = "Pip" .. i,
			LayoutOrder = i,
			Size = UDim2.fromOffset(40, 28),
			BackgroundColor3 = i <= level and C.sky or Color3.fromRGB(205, 200, 215),
			BorderSizePixel = 0,
			Parent = meter,
		}, {
			Theme.corner(8),
			Theme.stroke(2.5),
			Theme.gloss(Color3.fromRGB(255, 255, 255), Color3.fromRGB(195, 195, 195)),
		})
	end
	line("Run faster to steal and get away!", { TextColor3 = C.muted })
	local price = Formulas.speedPrice(level)
	local buy = Theme.button({
		Name = "BuySpeed",
		Text = price and ("+1 SPEED  💰 " .. Format.num(price)) or "MAX SPEED!",
		BackgroundColor3 = price and C.good or C.mustard,
		Size = UDim2.fromOffset(330, 62),
		round = true,
		Parent = body,
	})
	buy.Activated:Connect(function()
		if price then
			Net.send("BuySpeed")
		end
	end)
	local fast = Theme.button({
		Name = "FastFeet",
		Text = (s.passes or {}).FAST and "👟 FAST FEET: OWNED" or "👟 FAST FEET  R$ 199  (+25% with a dragon)",
		BackgroundColor3 = C.purple,
		TextSize = 19,
		TextScaled = false,
		Size = UDim2.fromOffset(440, 48),
		round = true,
		Parent = body,
	})
	fast.Activated:Connect(function()
		Net.send("Purchase", "pass", "FAST")
	end)
	line(
		`🪺 Nests: {s.nests or Constants.START_NESTS}. Buy more at your base!`,
		{ TextColor3 = C.muted, TextSize = 18 }
	)
end

-- Gift -------------------------------------------------------------------------------------------------------
builders.Gift = function()
	titleLabel.Text = "🎁 DAILY GIFT"
	list(12)
	local d = Store.state.daily or { streak = 0, canClaim = false, nextDay = 1, gift = "" }
	headline(d.streak > 0 and `🔥 {d.streak} DAY STREAK!` or "COME BACK EVERY DAY!", 28, C.pink)
	local row =
		new("Frame", { Name = "Days", BackgroundTransparency = 1, Size = UDim2.fromOffset(560, 92), Parent = body })
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = row,
	})
	for i, gift in Formulas.DAILY_GIFTS do
		local isNext = i == ((d.nextDay - 1) % #Formulas.DAILY_GIFTS + 1)
		local done = i <= d.streak and not isNext
		local tile = Theme.card({
			Name = "Day" .. i,
			LayoutOrder = i,
			Size = UDim2.fromOffset(74, 92),
			BackgroundColor3 = isNext and C.mustard or (done and C.good or C.white),
			Parent = row,
		})
		Theme.gloss(Color3.fromRGB(255, 255, 255), Color3.fromRGB(215, 215, 215)).Parent = tile
		if isNext then
			tile.UIStroke.Color = C.orange
			tile.UIStroke.Thickness = 5
		end
		Theme.title({
			Text = done and "✓" or ("DAY " .. i),
			Size = UDim2.new(1, -6, 0, 22),
			Position = UDim2.fromOffset(3, 4),
			TextXAlignment = Enum.TextXAlignment.Center,
			outline = 2,
			Parent = tile,
		})
		Theme.text({
			Text = gift.kind == "coins" and ("💰\n" .. Format.num(gift.amount))
				or (gift.kind == "luck" and "🍀\nLuck" or "🐉\n" .. gift.text:match("^(%S+)")),
			TextSize = 15,
			TextScaled = false,
			Size = UDim2.new(1, -6, 1, -30),
			Position = UDim2.fromOffset(3, 28),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = tile,
		})
	end
	if d.canClaim then
		line(`Today: {d.gift}`, { TextColor3 = C.ink })
		local claim = Theme.button({
			Name = "Claim",
			Text = "CLAIM! 🎁",
			BackgroundColor3 = C.good,
			Size = UDim2.fromOffset(280, 64),
			round = true,
			Parent = body,
		})
		claim.Activated:Connect(function()
			Net.send("ClaimDaily")
			PanelController.close()
		end)
	else
		line(`Next gift: {d.gift}`, { TextColor3 = C.muted })
		headline(`COME BACK IN {Format.time(d.secondsToNext or 0)}`, 24, C.sky)
	end
	line("Day 2 = a Rare dragon. Day 7 = a LEGEND!", { TextColor3 = C.ketchup, TextSize = 18 })
end

-- Welcome back -----------------------------------------------------------------------------------------------
local offline
builders.Offline = function()
	titleLabel.Text = "👋 WELCOME BACK!"
	list(14)
	local o = offline or { coins = 0, seconds = 0 }
	line(`While you were away ({Format.time(o.seconds)}), your dragons made:`, { TextColor3 = C.muted })
	headline("💰 " .. Format.num(o.coins), 56, C.mustard)
	local row =
		new("Frame", { Name = "Buttons", BackgroundTransparency = 1, Size = UDim2.fromOffset(460, 64), Parent = body })
	local claim = Theme.button({
		Name = "Claim",
		Text = "CLAIM",
		BackgroundColor3 = C.good,
		Size = UDim2.new(0.5, -6, 1, 0),
		round = true,
		Parent = row,
	})
	claim.Activated:Connect(function()
		Net.send("ClaimOffline")
		PanelController.close()
	end)
	local double = Theme.button({
		Name = "Double",
		Text = "x2 DOUBLE IT! R$ " .. Shop.productByKey.OFFLINE2X.price,
		BackgroundColor3 = C.purple,
		round = true,
		Size = UDim2.new(0.5, -6, 1, 0),
		Position = UDim2.new(0.5, 6, 0, 0),
		Parent = row,
	})
	double.Activated:Connect(function()
		Net.send("Purchase", "product", "OFFLINE2X")
		PanelController.close()
	end)
end

function PanelController:init()
	gui = Theme.screen("Panels", 5, player:WaitForChild("PlayerGui"))
	dim = new("Frame", {
		Name = "Dim",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Size = UDim2.new(1, 0, 1, 0),
		Visible = false,
		Active = true,
		Parent = gui,
	})
	card = Theme.card({
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 6),
		Size = UDim2.fromOffset(610, 440),
		Parent = dim,
	})
	header = new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 66),
		BackgroundColor3 = C.purple,
		BorderSizePixel = 0,
		Parent = card,
	}, { Theme.corner(16), Theme.gloss(Color3.fromRGB(255, 255, 255), Color3.fromRGB(185, 185, 185)) })
	-- square off the header's bottom corners
	new("Frame", {
		Name = "HeaderBase",
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.new(0, 0, 1, -18),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = header,
	}, { Theme.gloss(Color3.fromRGB(190, 190, 190), Color3.fromRGB(185, 185, 185)) })
	titleLabel = Theme.title({
		Name = "Title",
		Text = "",
		Size = UDim2.new(1, -110, 0, 46),
		Position = UDim2.fromOffset(20, 10),
		outline = 3,
		ZIndex = 2,
		Parent = card,
	})
	local close = Theme.button({
		Name = "Close",
		Text = "✕",
		BackgroundColor3 = C.red,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(58, 58),
		Position = UDim2.new(1, -8, 0, 8),
		round = true,
		ZIndex = 3,
		Parent = card,
	})
	close.UIStroke.Thickness = 4
	close.Activated:Connect(PanelController.close)
	body = new("ScrollingFrame", {
		Name = "Body",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -28, 1, -94),
		Position = UDim2.fromOffset(14, 82),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		Parent = card,
	})
	new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8), Parent = body })
	tabs = new("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -28, 0, 44),
		Position = UDim2.fromOffset(14, 80),
		Visible = false,
		Parent = card,
	})
	for i, t in { { "boosts", "⚡ BOOSTS" }, { "passes", "👑 PASSES" } } do
		local b = Theme.button({
			Name = t[1],
			Text = t[2],
			BackgroundColor3 = C.mustard,
			Size = UDim2.new(0.5, -6, 1, 0),
			Position = UDim2.new((i - 1) * 0.5, (i - 1) * 6, 0, 0),
			round = true,
			Parent = tabs,
		})
		b.Activated:Connect(function()
			shopTab = t[1]
			refreshOpen()
		end)
	end
	HudController.openPanel = PanelController.open
	Store.Changed:Connect(function(partial)
		if
			current
			and current ~= "Offline"
			and (partial.passes or partial.speedLevel or partial.daily or partial.nests)
		then
			refreshOpen()
		end
	end)
	Net.listen("Offline", function(info)
		offline = info
		PanelController.open("Offline")
	end)
	-- returning players see the daily gift when they join (new players get the red dot instead, so the
	-- panel never pops up in the middle of the tutorial)
	local shownDaily = false
	Store.Changed:Connect(function(partial)
		local d = Store.state.daily
		if partial.tutorialDone == false then
			shownDaily = true
		end
		if not shownDaily and partial.daily and d and d.canClaim and Store.state.tutorialDone and not current then
			shownDaily = true
			task.delay(2, function()
				if not current then
					PanelController.open("Gift")
				end
			end)
		end
	end)
end

return PanelController
