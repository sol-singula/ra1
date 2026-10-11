-- The always-on HUD (GDD §24.13): player card, wallet, restaurant status, carried items, ability bar,
-- toasts, the served-customer card, level-up banner, world popups and the KO overlay.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Net)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Color
local new = Theme.new
local player = Players.LocalPlayer

local HudController = { Name = "HudController", Order = 10 }

local gui, refs = nil, {}

local function pill(parent, name, icon, pos, color)
	local f = Theme.slab({ Name = name, Size = UDim2.fromOffset(150, 40), Position = pos, Parent = parent })
	Theme.text({
		Text = icon,
		Size = UDim2.fromOffset(30, 30),
		Position = UDim2.fromOffset(8, 5),
		Parent = f,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	return Theme.text({
		Name = "Value",
		Text = "0",
		TextColor3 = color,
		Font = Theme.Display,
		Size = UDim2.new(1, -50, 0, 26),
		Position = UDim2.fromOffset(42, 7),
		Parent = f,
	})
end

function HudController:toast(text, kind)
	local color = kind == "good" and C.good or (kind == "bad" and C.ketchup or C.paper)
	local t = Theme.card({
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = C.paper,
		Parent = refs.toasts,
	})
	new(
		"Frame",
		{ Size = UDim2.new(0, 10, 1, 0), BackgroundColor3 = color, BorderSizePixel = 0, Parent = t },
		{ Theme.corner(6) }
	)
	Theme.text({
		Text = text,
		TextSize = 20,
		TextScaled = false,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		Position = UDim2.fromOffset(18, 0),
		Parent = t,
	})
	new("UIPadding", { PaddingRight = UDim.new(0, 14), Parent = t })
	task.delay(3.5, function()
		t:Destroy()
	end)
end

local function buildPlayerCard()
	local card = Theme.slab({
		Name = "PlayerCard",
		Size = UDim2.fromOffset(300, 84),
		Position = UDim2.fromOffset(16, 16),
		Parent = gui,
	})
	local badge = Theme.card({
		Size = UDim2.fromOffset(60, 60),
		Position = UDim2.fromOffset(12, 12),
		BackgroundColor3 = C.mustard,
		Parent = card,
	})
	refs.level = Theme.text({
		Text = "1",
		Font = Theme.Display,
		Size = UDim2.fromScale(1, 0.8),
		Position = UDim2.fromScale(0, 0.12),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = badge,
	})
	Theme.text({
		Text = player.DisplayName,
		TextColor3 = C.paper,
		Size = UDim2.fromOffset(200, 22),
		Position = UDim2.fromOffset(84, 10),
		Parent = card,
	})
	local hp, hpFill =
		Theme.bar({ Size = UDim2.fromOffset(200, 16), Position = UDim2.fromOffset(84, 36), Parent = card }, C.ketchup)
	refs.hpFill = hpFill
	refs.hpText = Theme.text({
		Text = "100/100",
		TextColor3 = C.white,
		TextSize = 13,
		TextScaled = false,
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = hp,
	})
	local _, xpFill =
		Theme.bar({ Size = UDim2.fromOffset(200, 10), Position = UDim2.fromOffset(84, 58), Parent = card }, C.teal)
	refs.xpFill = xpFill
	refs.xpText = Theme.text({
		Text = "",
		TextColor3 = C.paper,
		TextSize = 12,
		TextScaled = false,
		Size = UDim2.fromOffset(200, 12),
		Position = UDim2.fromOffset(84, 69),
		Parent = card,
	})
end

local function buildRight()
	refs.mb = pill(gui, "MB", "🪙", UDim2.new(1, -330, 0, 16), C.mustard)
	refs.ms = pill(gui, "MS", "💎", UDim2.new(1, -170, 0, 16), C.teal)
	local bar = Theme.slab({
		Name = "Restaurant",
		Size = UDim2.fromOffset(314, 36),
		Position = UDim2.new(1, -330, 0, 62),
		Parent = gui,
	})
	refs.restaurant = Theme.text({
		Text = "Broken Burger Shack",
		TextColor3 = C.paper,
		Size = UDim2.new(1, -20, 0, 22),
		Position = UDim2.fromOffset(10, 7),
		Parent = bar,
	})
end

local function buildButtons()
	local col = new("Frame", {
		Name = "Menu",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(140, 150),
		Position = UDim2.fromOffset(16, 112),
		Parent = gui,
	}, {
		new("UIListLayout", { Padding = UDim.new(0, 8) }),
	})
	refs.buttons = {}
	for _, spec in { { "Stats", "📊 Stats" }, { "Menu", "📋 Menu" }, { "Upgrade", "🔨 Upgrade" } } do
		refs.buttons[spec[1]] =
			Theme.button({ Name = spec[1], Text = spec[2], Size = UDim2.fromOffset(140, 38), Parent = col })
	end
	refs.statBadge = Theme.card({
		Size = UDim2.fromOffset(26, 26),
		Position = UDim2.new(1, -14, 0, -8),
		BackgroundColor3 = C.ketchup,
		Visible = false,
		Parent = refs.buttons.Stats,
	})
	refs.statBadgeText = Theme.text({
		Text = "2",
		TextColor3 = C.white,
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = refs.statBadge,
	})
end

local function buildCarry()
	refs.carry = new("Frame", {
		Name = "Carry",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -104),
		Size = UDim2.fromOffset(600, 44),
		Parent = gui,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 8),
		}),
	})
	refs.hint = Theme.text({
		Name = "Hint",
		Text = "",
		TextColor3 = C.paper,
		TextSize = 18,
		TextScaled = false,
		TextStrokeTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -152),
		Size = UDim2.fromOffset(700, 24),
		Parent = gui,
	})
end

function HudController:renderCarry(items, capacity, hint)
	refs.hint.Text = hint or ""
	refs.hint.Visible = hint ~= nil
	for _, child in refs.carry:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for i = 1, capacity do
		local item = items[i]
		local slot =
			Theme.slab({ Size = UDim2.fromOffset(item and 220 or 44, 44), LayoutOrder = i, Parent = refs.carry })
		if item then
			new("Frame", {
				Size = UDim2.fromOffset(28, 28),
				Position = UDim2.fromOffset(8, 8),
				BackgroundColor3 = item.color,
				BorderSizePixel = 0,
				Parent = slot,
			}, { Theme.corner(8), Theme.stroke(2) })
			Theme.text({
				Text = item.name,
				TextColor3 = C.paper,
				TextSize = 16,
				TextScaled = false,
				Size = UDim2.new(1, -46, 0, 20),
				Position = UDim2.fromOffset(42, 3),
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = slot,
			})
			Theme.text({
				Text = item.detail,
				TextColor3 = C.mustard,
				TextSize = 13,
				TextScaled = false,
				Size = UDim2.new(1, -46, 0, 16),
				Position = UDim2.fromOffset(42, 23),
				Parent = slot,
			})
		else
			Theme.text({
				Text = "✋",
				Size = UDim2.fromScale(1, 1),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextTransparency = 0.5,
				Parent = slot,
			})
		end
	end
end

local function buildAbilityBar()
	local bar = new("Frame", {
		Name = "Abilities",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(300, 70),
		Parent = gui,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 12),
		}),
	})
	refs.abilities = {}
	for i, spec in { { "ABL_001", "👊", "Click" }, { "ABL_006", "💗", "Q" }, { "MUTATION", "🧬", "G" } } do
		local b = Theme.button({
			Name = spec[1],
			Text = spec[2],
			Size = UDim2.fromOffset(70, 70),
			LayoutOrder = i,
			BackgroundColor3 = C.paper,
			Parent = bar,
		})
		Theme.text({
			Text = spec[3],
			TextSize = 12,
			TextScaled = false,
			TextColor3 = C.ink,
			Size = UDim2.new(1, 0, 0, 14),
			Position = UDim2.new(0, 0, 1, -12),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = b,
		})
		local shade = new("TextLabel", {
			Name = "Cooldown",
			BackgroundColor3 = C.ink,
			BackgroundTransparency = 0.35,
			Size = UDim2.fromScale(1, 1),
			Text = "",
			TextColor3 = C.white,
			Font = Theme.Display,
			TextScaled = true,
			Visible = false,
			ZIndex = 3,
			Parent = b,
		}, { Theme.corner(12) })
		refs.abilities[spec[1]] = { button = b, shade = shade }
	end
	refs.abilities.MUTATION.button.Visible = false
end

function HudController:cooldown(key, seconds)
	local a = refs.abilities[key]
	if not a then
		return
	end
	a.shade.Visible = true
	local endAt = os.clock() + seconds
	task.spawn(function()
		while os.clock() < endAt do
			a.shade.Text = tostring(math.ceil(endAt - os.clock()))
			task.wait(0.1)
		end
		a.shade.Visible = false
	end)
end

function HudController:abilityButton(key)
	return refs.abilities[key] and refs.abilities[key].button
end

function HudController:menuButton(name)
	return refs.buttons[name]
end

local function popup(position, text, color)
	local anchor = new("Part", {
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		Transparency = 1,
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = CFrame.new(position),
		Parent = workspace.CurrentCamera,
	})
	local bb = new(
		"BillboardGui",
		{ Size = UDim2.fromOffset(220, 44), AlwaysOnTop = true, MaxDistance = 80, Adornee = anchor, Parent = anchor }
	)
	local label = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = text,
		TextColor3 = color,
		Font = Theme.Display,
		TextScaled = true,
		TextStrokeTransparency = 0,
		TextStrokeColor3 = C.ink,
		Parent = bb,
	})
	TweenService:Create(bb, TweenInfo.new(1.2), { StudsOffset = Vector3.new(0, 3, 0) }):Play()
	TweenService:Create(
		label,
		TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }
	):Play()
	task.delay(1.3, function()
		anchor:Destroy()
	end)
end

function HudController:servedCard(s)
	local card = Theme.card({ Size = UDim2.fromOffset(300, 96), Position = UDim2.new(1, 20, 0, 116), Parent = gui })
	Theme.text({
		Text = s.name,
		Font = Theme.Display,
		TextColor3 = C.teal,
		Size = UDim2.new(1, -24, 0, 24),
		Position = UDim2.fromOffset(12, 8),
		Parent = card,
	})
	Theme.text({
		Text = `{s.mood} · satisfaction {s.satisfaction}`,
		Size = UDim2.new(1, -24, 0, 20),
		Position = UDim2.fromOffset(12, 34),
		Parent = card,
	})
	local money = `+{s.net} MB  (paid {s.pay}, tip {s.tip}, food −{s.cost})  ·  +{s.xp} XP`
	if s.jackpot then
		money = "JACKPOT TIP! " .. money
	end
	Theme.text({
		Text = money,
		TextColor3 = C.muted,
		Size = UDim2.new(1, -24, 0, 18),
		Position = UDim2.fromOffset(12, 60),
		Parent = card,
	})
	card:TweenPosition(UDim2.new(1, -316, 0, 116), Enum.EasingDirection.Out, Enum.EasingStyle.Back, 0.35, true)
	task.delay(4, function()
		card:TweenPosition(UDim2.new(1, 20, 0, 116), Enum.EasingDirection.In, Enum.EasingStyle.Quad, 0.3, true)
		task.wait(0.35)
		card:Destroy()
	end)
end

local function banner(text, sub, color)
	local f = Theme.card({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.35),
		Size = UDim2.fromOffset(520, 120),
		BackgroundColor3 = C.paper,
		Parent = gui,
	})
	Theme.text({
		Text = text,
		Font = Theme.Display,
		TextColor3 = color,
		Size = UDim2.new(1, -20, 0, 64),
		Position = UDim2.fromOffset(10, 10),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = f,
	})
	Theme.text({
		Text = sub,
		Size = UDim2.new(1, -20, 0, 28),
		Position = UDim2.fromOffset(10, 78),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = f,
	})
	task.delay(2.8, function()
		f:Destroy()
	end)
end

local function render(partial)
	local s = Store.state
	if partial.level or partial.xp then
		refs.level.Text = tostring(s.level or 1)
		local req = s.xpReq or 1
		refs.xpFill.Size = UDim2.fromScale(math.clamp((s.xp or 0) / req, 0, 1), 1)
		refs.xpText.Text = `XP {s.xp or 0} / {req}`
	end
	if partial.hp or partial.maxHp then
		local max = s.maxHp or 100
		refs.hpFill.Size = UDim2.fromScale(math.clamp((s.hp or max) / max, 0, 1), 1)
		refs.hpText.Text = `{s.hp or max}/{max}`
	end
	if partial.mb then
		refs.mb.Text = tostring(s.mb)
	end
	if partial.ms then
		refs.ms.Text = tostring(s.ms)
	end
	if partial.tierName or partial.stars then
		refs.restaurant.Text = `🏠 {s.tierName or ""}   ★ {string.format("%.1f", s.stars or 2.5)}`
	end
	if partial.statPoints ~= nil then
		refs.statBadge.Visible = (s.statPoints or 0) > 0
		refs.statBadgeText.Text = tostring(s.statPoints or 0)
	end
	if partial.ability ~= nil then
		local a = refs.abilities.MUTATION
		a.button.Visible = s.ability ~= false and s.ability ~= nil
		a.button.Text = ({ ABL_012 = "🐙", ABL_017 = "🦀", ABL_062 = "🔧" })[s.ability] or "🧬"
	end
	if partial.levelUp then
		banner(`LEVEL {partial.levelUp}!`, "+2 stat points. Open Stats to spend them.", C.mustard)
	end
end

function HudController:init()
	gui = new("ScreenGui", {
		Name = "HUD",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	refs.gui = gui
	buildPlayerCard()
	buildRight()
	buildButtons()
	buildCarry()
	buildAbilityBar()
	refs.toasts = new("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -184),
		Size = UDim2.fromOffset(700, 200),
		Parent = gui,
	}, {
		new("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
		}),
	})
	self:renderCarry({}, 1)

	Store.Changed:Connect(render)
	Net.listen("Toast", function(text, kind)
		self:toast(text, kind)
	end)
	Net.listen("Carry", function(items, capacity, hint)
		self:renderCarry(items, capacity, hint)
	end)
	Net.listen("Popup", popup)
	Net.listen("Served", function(summary)
		self:servedCard(summary)
	end)
	Net.listen("Cooldown", function(abilityId, seconds)
		self:cooldown(abilityId == "ABL_006" and "ABL_006" or "MUTATION", seconds)
	end)
	Net.listen("KO", function(seconds)
		banner("SEEING STARS!", `Back on your feet in {seconds} s · nothing lost`, C.mustard)
	end)
end

function HudController:gui()
	return gui
end

return HudController
