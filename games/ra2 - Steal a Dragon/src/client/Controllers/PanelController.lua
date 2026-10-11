-- Pop-up panels: Shop (boosts and passes), Speed (upgrades), Gift (daily streak) and Welcome Back (coins
-- earned while away). One panel at a time, big buttons, big close X, sized to fit a phone in landscape.
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

local gui, dim, card, titleLabel, body
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
	body.Position = UDim2.fromOffset(12, 68)
	body.Size = UDim2.new(1, -24, 1, -78)
end

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
	clearBody()
	builders[name]()
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

local function list(padding)
	new("UIListLayout", {
		Padding = UDim.new(0, padding or 10),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = body,
	})
end

-- Shop -------------------------------------------------------------------------------------------------------
local function shopCard(item, kind, order)
	local owned = kind == "pass" and (Store.state.passes or {})[item.key]
	local cell = Theme.card({ Name = item.key, LayoutOrder = order, BackgroundColor3 = C.white, Parent = body })
	Theme.text({
		Text = item.icon,
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 6),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = cell,
	})
	Theme.text({
		Text = item.name,
		Font = Theme.Display,
		Size = UDim2.new(1, -12, 0, 24),
		Position = UDim2.fromOffset(6, 48),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = cell,
	})
	Theme.text({
		Text = item.text,
		TextSize = 15,
		TextScaled = false,
		TextColor3 = C.muted,
		Size = UDim2.new(1, -12, 0, 52),
		Position = UDim2.fromOffset(6, 74),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = cell,
	})
	local buy = Theme.button({
		Name = "Buy",
		Text = owned and "OWNED ✓" or ("R$ " .. item.price),
		Font = Theme.Display,
		BackgroundColor3 = owned and C.good or C.mustard,
		Size = UDim2.new(1, -16, 0, 40),
		Position = UDim2.new(0, 8, 1, -48),
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
	body.Position = UDim2.fromOffset(12, 118)
	body.Size = UDim2.new(1, -24, 1, -128)
	for _, b in tabs:GetChildren() do
		if b:IsA("TextButton") then
			b.BackgroundColor3 = shopTab == b.Name and C.mustard or C.white
		end
	end
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(170, 186),
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
	line(`Speed level {level} / {Constants.MAX_SPEED_LEVEL}`, { Font = Theme.Display, TextSize = 30 })
	line("Run faster to steal and get away!", { TextColor3 = C.muted })
	local price = Formulas.speedPrice(level)
	local buy = Theme.button({
		Name = "BuySpeed",
		Text = price and ("+1 SPEED: 💰 " .. Format.num(price)) or "MAX SPEED!",
		Font = Theme.Display,
		BackgroundColor3 = price and C.mustard or C.good,
		Size = UDim2.fromOffset(320, 60),
		Parent = body,
	})
	buy.Activated:Connect(function()
		if price then
			Net.send("BuySpeed")
		end
	end)
	line(
		`🪺 Nests: {s.nests or Constants.START_NESTS} — buy more at your base`,
		{ TextColor3 = C.muted, TextSize = 18 }
	)
	local fast = Theme.button({
		Name = "FastFeet",
		Text = (s.passes or {}).FAST and "👟 Fast Feet: OWNED" or "👟 Fast Feet (R$ 199): +25% with a dragon",
		BackgroundColor3 = C.sky,
		TextSize = 18,
		TextScaled = false,
		Size = UDim2.fromOffset(420, 46),
		Parent = body,
	})
	fast.Activated:Connect(function()
		Net.send("Purchase", "pass", "FAST")
	end)
end

-- Gift -------------------------------------------------------------------------------------------------------
builders.Gift = function()
	titleLabel.Text = "🎁 DAILY GIFT"
	list(12)
	local d = Store.state.daily or { streak = 0, canClaim = false, nextDay = 1, gift = "" }
	line(
		d.streak > 0 and `🔥 {d.streak} day streak!` or "Come every day for bigger gifts!",
		{ Font = Theme.Display, TextSize = 26 }
	)
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
		local tile = Theme.card({
			Name = "Day" .. i,
			LayoutOrder = i,
			Size = UDim2.fromOffset(74, 90),
			BackgroundColor3 = isNext and C.mustard or (i <= d.streak and C.good or C.white),
			Parent = row,
		})
		Theme.text({
			Text = "Day " .. i,
			Font = Theme.Display,
			Size = UDim2.new(1, -6, 0, 22),
			Position = UDim2.fromOffset(3, 4),
			TextXAlignment = Enum.TextXAlignment.Center,
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
			Font = Theme.Display,
			BackgroundColor3 = C.good,
			Size = UDim2.fromOffset(260, 60),
			Parent = body,
		})
		claim.Activated:Connect(function()
			Net.send("ClaimDaily")
			PanelController.close()
		end)
	else
		line(`Next gift: {d.gift}`, { TextColor3 = C.muted })
		line(`Come back in {Format.time(d.secondsToNext or 0)}!`, { Font = Theme.Display })
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
	line(
		"💰 " .. Format.num(o.coins),
		{ Font = Theme.Display, TextSize = 46, TextColor3 = Color3.fromRGB(200, 140, 0) }
	)
	local row =
		new("Frame", { Name = "Buttons", BackgroundTransparency = 1, Size = UDim2.fromOffset(460, 64), Parent = body })
	local claim = Theme.button({
		Name = "Claim",
		Text = "CLAIM",
		Font = Theme.Display,
		BackgroundColor3 = C.good,
		Size = UDim2.new(0.5, -6, 1, 0),
		Parent = row,
	})
	claim.Activated:Connect(function()
		Net.send("ClaimOffline")
		PanelController.close()
	end)
	local double = Theme.button({
		Name = "Double",
		Text = "x2 DOUBLE IT! R$ " .. Shop.productByKey.OFFLINE2X.price,
		Font = Theme.Display,
		BackgroundColor3 = C.mustard,
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
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(600, 430),
		Parent = dim,
	})
	titleLabel = Theme.text({
		Name = "Title",
		Text = "",
		Font = Theme.Display,
		TextColor3 = C.ketchup,
		Size = UDim2.new(1, -90, 0, 44),
		Position = UDim2.fromOffset(18, 10),
		Parent = card,
	})
	local close = Theme.button({
		Name = "Close",
		Text = "✕",
		Font = Theme.Display,
		BackgroundColor3 = C.red,
		TextColor3 = C.white,
		Size = UDim2.fromOffset(56, 56),
		Position = UDim2.new(1, -66, 0, 8),
		Parent = card,
	})
	close.Activated:Connect(PanelController.close)
	body = new("ScrollingFrame", {
		Name = "Body",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -24, 1, -78),
		Position = UDim2.fromOffset(12, 68),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		Parent = card,
	})
	new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8), Parent = body })
	tabs = new("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -24, 0, 44),
		Position = UDim2.fromOffset(12, 64),
		Visible = false,
		Parent = card,
	})
	for i, t in { { "boosts", "⚡ BOOSTS" }, { "passes", "👑 PASSES" } } do
		local b = Theme.button({
			Name = t[1],
			Text = t[2],
			Font = Theme.Display,
			BackgroundColor3 = C.white,
			Size = UDim2.new(0.5, -6, 1, 0),
			Position = UDim2.new((i - 1) * 0.5, (i - 1) * 6, 0, 0),
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
