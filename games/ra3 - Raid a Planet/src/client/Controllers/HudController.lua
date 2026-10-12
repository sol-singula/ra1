-- The always-on screen, built for phones first:
--   top-left: coins, gems and ore; the planet you're on
--   left: menu buttons (Forge, Bag, Shop, Home)
--   top-centre: the goal card and big alerts
--   top-right: the forge timer, the raid countdown, the next playtime gift and the new-player boost
--   bottom-right: the BLAST button (hold to keep firing)
--   plus toasts, announcements, floating world popups and the DOWN overlay.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Planets = require(ReplicatedStorage.Shared.Data.Planets)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Color
local new = Theme.new
local player = Players.LocalPlayer

local HudController = { Name = "HudController", Order = 10 }

local gui
local coinsLabel, gemsLabel, oreLabel, planetLabel
local goalCard, goalText, goalFill, goalReward, goalCount
local forgePill, raidPill, giftPill, boostPill
local blastButton
local toastHolder, alertLabel, downLabel
local raidAt
local playtimeReceived, forgeReceived
local coinsShown, coinsTarget = nil, 0

HudController.openPanel = nil -- set by PanelController
HudController.blastHeld = false -- read by BlastController

local function serverNow()
	return workspace:GetServerTimeNow()
end

-- Toasts, alerts, announcements, popups -----------------------------------------------------------------------
local TOAST_COLORS = { good = C.good, bad = C.red, info = C.sky }
local TOAST_ICONS = { good = "✅", bad = "⛔", info = "💬" }

function HudController.toast(text, kind)
	local accent = TOAST_COLORS[kind] or C.sky
	local card = new("Frame", {
		Name = "Toast",
		Size = UDim2.fromOffset(470, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.slate,
		BorderSizePixel = 0,
		Parent = toastHolder,
	}, { Theme.corner("round"), Theme.stroke(3, accent) })
	Theme.translucent(card, 0.08)
	new("UIPadding", {
		PaddingLeft = UDim.new(0, 16),
		PaddingRight = UDim.new(0, 16),
		PaddingTop = UDim.new(0, 7),
		PaddingBottom = UDim.new(0, 7),
		Parent = card,
	})
	Theme.text({
		Text = (TOAST_ICONS[kind] or "💬") .. "  " .. text,
		TextSize = 22,
		TextScaled = false,
		TextColor3 = C.white,
		outline = 1.5,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromScale(1, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = card,
	})
	Theme.pop(card)
	local list = {}
	for _, c in toastHolder:GetChildren() do
		if c:IsA("GuiObject") then
			table.insert(list, c)
		end
	end
	if #list > 3 then
		list[1]:Destroy()
	end
	task.delay(3, function()
		card:Destroy()
	end)
end

function HudController.alert(text, color)
	alertLabel.Text = text
	alertLabel.TextColor3 = color or C.mustard
	alertLabel.Visible = true
	Theme.pop(alertLabel)
	local mine = text
	task.delay(3.2, function()
		if alertLabel.Text == mine then
			alertLabel.Visible = false
		end
	end)
end

local announceQueue, announcing = {}, false
local function nextAnnouncement()
	local item = table.remove(announceQueue, 1)
	if not item then
		announcing = false
		return
	end
	announcing = true
	local frame = new("Frame", {
		Name = "Announce",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -70),
		Size = UDim2.fromOffset(520, 52),
		BackgroundColor3 = C.slate,
		BorderSizePixel = 0,
		ZIndex = 20,
		Parent = gui,
	}, { Theme.corner("round"), Theme.stroke(3, item.color) })
	Theme.text({
		Name = "Text",
		Text = item.text,
		TextColor3 = C.white,
		Size = UDim2.new(1, -24, 1, -10),
		Position = UDim2.fromOffset(12, 5),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 21,
		Parent = frame,
	})
	Theme.tween(frame, 0.35, { Position = UDim2.new(0.5, 0, 0, 8) }, Enum.EasingStyle.Back)
	task.delay(3.2, function()
		Theme.tween(frame, 0.3, { Position = UDim2.new(0.5, 0, 0, -70) })
		task.delay(0.35, function()
			frame:Destroy()
			nextAnnouncement()
		end)
	end)
end

function HudController.announce(text, color)
	if #announceQueue >= 4 then
		table.remove(announceQueue, 1)
	end
	table.insert(announceQueue, { text = text, color = color or C.mustard })
	if not announcing then
		nextAnnouncement()
	end
end

function HudController.popup(position, text, color)
	local anchor = new("Part", {
		Name = "PopupAnchor",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		Transparency = 1,
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = CFrame.new(position),
		Parent = workspace,
	})
	local bb = new("BillboardGui", {
		Name = "Popup",
		Adornee = anchor,
		Size = UDim2.fromOffset(200, 50),
		AlwaysOnTop = true,
		MaxDistance = 120,
		Parent = anchor,
	})
	Theme.title({
		Text = text,
		TextColor3 = color or C.mustard,
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = bb,
	})
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		anchor.CFrame = CFrame.new(position + Vector3.new(0, t * 3, 0))
		if t > 0.9 then
			conn:Disconnect()
			anchor:Destroy()
		end
	end)
end

-- Building ---------------------------------------------------------------------------------------------------
local function pill(name, y, color, x, anchor)
	local label = new("TextLabel", {
		Name = name,
		Text = "",
		Font = Theme.Body,
		TextSize = math.floor(19 * Theme.textFactor() + 0.5),
		TextColor3 = color,
		BackgroundColor3 = C.slate,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.X,
		AnchorPoint = anchor or Vector2.new(0, 0),
		Size = UDim2.fromOffset(0, 28),
		Position = x and UDim2.new(1, x, 0, y) or UDim2.fromOffset(14, y),
		Visible = false,
		Parent = gui,
	}, {
		Theme.corner("round"),
		Theme.textStroke(1.5),
		new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
	})
	return label
end

local function buildTopLeft()
	local coins = Theme.slab({
		Name = "Coins",
		Size = UDim2.fromOffset(210, 46),
		Position = UDim2.fromOffset(14, 10),
		round = true,
		Parent = gui,
	})
	Theme.text({
		Text = "💰",
		Size = UDim2.fromOffset(38, 38),
		Position = UDim2.fromOffset(6, 4),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = coins,
	})
	coinsLabel = Theme.title({
		Name = "Value",
		Text = "0",
		Size = UDim2.new(1, -54, 1, -8),
		Position = UDim2.fromOffset(48, 4),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = coins,
	})
	local gems = Theme.slab({
		Name = "Gems",
		Size = UDim2.fromOffset(130, 36),
		Position = UDim2.fromOffset(14, 60),
		round = true,
		Parent = gui,
	})
	Theme.text({
		Text = "💎",
		Size = UDim2.fromOffset(30, 30),
		Position = UDim2.fromOffset(6, 3),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = gems,
	})
	gemsLabel = Theme.title({
		Name = "Value",
		Text = "0",
		TextColor3 = Color3.fromRGB(150, 230, 255),
		Size = UDim2.new(1, -44, 1, -8),
		Position = UDim2.fromOffset(40, 4),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = gems,
	})
	oreLabel = pill("Ore", 102, C.mustard)
	planetLabel = pill("Planet", 134, C.white)
end

local function buildMenu()
	local items = {
		{ "Forge", "⚒️", "FORGE", C.orange, 14, 176 },
		{ "Bag", "🎒", "BAG", C.purple, 96, 176 },
		{ "Shop", "🛒", "SHOP", C.mustard, 14, 266 },
		{ "Home", "🏠", "HUB", C.teal, 96, 266 },
	}
	for _, it in items do
		local button = Theme.iconButton({
			Name = it[1] .. "Button",
			icon = it[2],
			label = it[3],
			color = it[4],
			Position = UDim2.fromOffset(it[5], it[6]),
			Parent = gui,
		})
		button.Activated:Connect(function()
			if it[1] == "Home" then
				Net.send("Travel", "HUB")
			elseif HudController.openPanel then
				HudController.openPanel(it[1])
			end
		end)
	end
end

local function buildCenter()
	goalCard = Theme.slab({
		Name = "Goal",
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(430, 62),
		Position = UDim2.new(0.5, 0, 0, 10),
		round = true,
		Parent = gui,
	})
	Theme.text({
		Text = "⭐",
		Size = UDim2.fromOffset(34, 34),
		Position = UDim2.fromOffset(8, 4),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = goalCard,
	})
	goalText = Theme.title({
		Name = "Text",
		Text = "",
		TextSize = 19,
		Size = UDim2.new(1, -150, 0, 26),
		Position = UDim2.fromOffset(42, 6),
		TextXAlignment = Enum.TextXAlignment.Left,
		outline = 2,
		Parent = goalCard,
	})
	local reward = new("Frame", {
		Name = "RewardPill",
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(96, 34),
		Position = UDim2.new(1, -8, 0, 6),
		BackgroundColor3 = C.orange,
		BorderSizePixel = 0,
		Parent = goalCard,
	}, { Theme.corner("round"), Theme.stroke(2.5) })
	goalReward = Theme.title({
		Name = "Reward",
		Text = "",
		Size = UDim2.new(1, -10, 1, -6),
		Position = UDim2.fromOffset(5, 3),
		TextXAlignment = Enum.TextXAlignment.Center,
		outline = 2,
		Parent = reward,
	})
	local bar
	bar, goalFill = Theme.bar(
		{ Name = "Bar", Size = UDim2.new(1, -150, 0, 18), Position = UDim2.fromOffset(42, 36), Parent = goalCard },
		C.good
	)
	goalCount = Theme.title({
		Name = "Count",
		Text = "",
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		outline = 1.5,
		ZIndex = 3,
		Parent = bar,
	})
	alertLabel = Theme.title({
		Name = "Alert",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(800, 110),
		Position = UDim2.new(0.5, 0, 0.42, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		ZIndex = 30,
		outline = 4,
		Parent = gui,
	})
	downLabel = Theme.title({
		Name = "Down",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(600, 90),
		Position = UDim2.new(0.5, 0, 0.6, 0),
		TextColor3 = C.red,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		ZIndex = 30,
		outline = 4,
		Parent = gui,
	})
	toastHolder = new("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(470, 220),
		Position = UDim2.new(0.5, 0, 1, -130),
		Parent = gui,
	})
	new("UIListLayout", {
		Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = toastHolder,
	})
end

local function buildRight()
	forgePill = pill("ForgeTimer", 10, C.orange, -12, Vector2.new(1, 0))
	raidPill = pill("Raid", 44, Color3.fromRGB(200, 160, 255), -12, Vector2.new(1, 0))
	giftPill = pill("Gift", 78, C.pink, -12, Vector2.new(1, 0))
	boostPill = pill("Boost", 112, C.mustard, -12, Vector2.new(1, 0))
	blastButton = Theme.button({
		Name = "BlastButton",
		Text = "💥 BLAST",
		BackgroundColor3 = C.red,
		AnchorPoint = Vector2.new(1, 1),
		Size = UDim2.fromOffset(150, 150),
		Position = UDim2.new(1, -24, 1, -24),
		round = true,
		Parent = gui,
	})
	blastButton.MouseButton1Down:Connect(function()
		HudController.blastHeld = true
	end)
	blastButton.MouseButton1Up:Connect(function()
		HudController.blastHeld = false
	end)
	blastButton.MouseLeave:Connect(function()
		HudController.blastHeld = false
	end)
	-- a tap also fires once (BlastController reads this)
	blastButton.Activated:Connect(function()
		HudController.blastTapped = true
	end)
end

-- Refreshing ----------------------------------------------------------------------------------------------
local function refresh()
	local s = Store.state
	coinsTarget = s.coins or 0
	gemsLabel.Text = Format.num(s.gems or 0)
	local planetKey = s.planet ~= "HUB" and s.planet or nil
	local top = Planets.list[math.min(#Planets.list, s.unlocked or 1)]
	local showOre = planetKey and Planets.byKey[planetKey] or top
	if showOre and s.ore then
		oreLabel.Text = `🪨 {Format.num(s.ore[showOre.key] or 0)} {showOre.ore}`
		oreLabel.Visible = true
	end
	if planetKey then
		local p = Planets.byKey[planetKey]
		planetLabel.Text = `{p.emoji} {p.name} planet`
		planetLabel.TextColor3 = p.color
	else
		planetLabel.Text = "🛸 The Hub"
		planetLabel.TextColor3 = C.white
	end
	planetLabel.Visible = true
	local g = s.goal
	if g and g ~= false then
		goalCard.Visible = true
		goalText.Text = `GOAL {g.index} OF {g.total}: {g.text}`
		goalReward.Text = "+" .. g.reward
		goalFill.Size = UDim2.new(math.clamp(g.progress / g.target, 0, 1), 0, 1, 0)
		goalCount.Text = `{g.progress} / {g.target}`
	else
		goalCard.Visible = false
	end
end

local function tick()
	local s = Store.state
	-- coins ease toward the real number
	if coinsShown == nil then
		coinsShown = coinsTarget
	else
		coinsShown += (coinsTarget - coinsShown) * 0.2
		if math.abs(coinsTarget - coinsShown) < 1 then
			coinsShown = coinsTarget
		end
	end
	coinsLabel.Text = Format.num(coinsShown)
	-- forge timer
	local f = s.forge
	local since = forgeReceived and os.clock() - forgeReceived or 0
	local text
	if f and f.slots then
		local soonest, ready = nil, 0
		for _, slot in f.slots do
			if slot and slot ~= false then
				local left = slot.left - since
				if left <= 0 then
					ready += 1
				elseif not soonest or left < soonest then
					soonest = left
				end
			end
		end
		if ready > 0 then
			text = `⚒️ {ready} blaster{ready > 1 and "s" or ""} READY!`
		elseif soonest then
			text = `⚒️ Forge: {Format.time(soonest)}`
		end
	end
	forgePill.Text = text or ""
	forgePill.Visible = text ~= nil
	-- raid countdown
	if raidAt then
		local left = raidAt - serverNow()
		raidPill.Text = left > 0 and `☄️ RAID IN {Format.time(left)}` or "☄️ RAID!"
		raidPill.Visible = true
	end
	-- playtime gift and the new-player boost
	local pt = s.playtime
	local ptSince = playtimeReceived and os.clock() - playtimeReceived or 0
	giftPill.Visible = pt ~= nil and pt.nextIn ~= nil and pt.nextText ~= nil
	if giftPill.Visible then
		local left = math.max(0, pt.nextIn - ptSince)
		giftPill.Text = left > 0 and `🎁 {pt.nextText} in {Format.time(left)}` or `🎁 {pt.nextText}!`
	end
	local boostLeft = pt and (pt.boostLeft or 0) - ptSince or 0
	boostPill.Visible = boostLeft > 0
	if boostPill.Visible then
		boostPill.Text = `🚀 2x COINS {Format.time(boostLeft)}`
	end
end

function HudController:init()
	gui = Theme.screen("Hud", 1, player:WaitForChild("PlayerGui"))
	buildTopLeft()
	buildMenu()
	buildCenter()
	buildRight()
	Store.Changed:Connect(function(partial)
		if partial.playtime ~= nil then
			playtimeReceived = os.clock()
		end
		if partial.forge ~= nil then
			forgeReceived = os.clock()
		end
		refresh()
	end)
	Net.listen("Toast", HudController.toast)
	Net.listen("Alert", function(text, color)
		HudController.alert(text, color)
	end)
	Net.listen("Announce", HudController.announce)
	Net.listen("Popup", HudController.popup)
	Net.listen("Event", function(e)
		if e and e.kind == "raid" then
			raidAt = e.at
		end
	end)
	Net.listen("Down", function(seconds)
		downLabel.Visible = true
		local until_ = os.clock() + seconds
		task.spawn(function()
			while os.clock() < until_ do
				downLabel.Text = `😵 DOWN! {math.ceil(until_ - os.clock())}`
				task.wait(0.2)
			end
			downLabel.Visible = false
		end)
	end)
	RunService.RenderStepped:Connect(tick)
	refresh()
	_ = Constants
end

return HudController
