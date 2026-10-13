-- The always-on screen, built for phones first:
--   top-left: coins, crate keys and your level; bottom: the level bar
--   top-centre: the round card (what's happening and the clock); in a round: your pops and your place
--   top-right: the top 5 of the round; right: the kill feed
--   centre: streak banners, big alerts; the pop screen when you're popped (who got you, the countdown, Revive)
--   left (lobby only): Shop, Crates, Rifles, Style, Season, Quests, Store; the PLAY / LOBBY button
--   plus toasts, announcements, the podium banner and the crown notice.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Color
local new = Theme.new
local player = Players.LocalPlayer

local HudController = { Name = "HudController", Order = 10 }

local gui
local coinsLabel, keysLabel, levelLabel, levelFill, levelText
local roundTitle, roundClock, roundCard, myLine, lastMinutePill, boostPill, crownPill
local scoreFrame, feedFrame, streakLabel, alertLabel, toastHolder
local menu, playButton, lobbyButton, questDot, voteBar, giftPill
local poppedFrame, poppedTitle, poppedSub, poppedCount, reviveButton
local podiumBanner
local round = { state = "waiting", endsAt = 0 }
local scores = {}
local poppedBack = 0
local coinsShown, coinsTarget = nil, 0

HudController.openPanel = nil -- set by PanelController

local function serverNow()
	return workspace:GetServerTimeNow()
end

local function inArena()
	local z = player:GetAttribute("Zone")
	return z == "arena" or z == "duel" or z == "range"
end

-- Toasts, alerts, announcements ---------------------------------------------------------------------------------
local TOAST_COLORS = { good = C.good, bad = C.red, info = C.sky }
local TOAST_ICONS = { good = "✅", bad = "⛔", info = "💬" }

function HudController.toast(text, kind)
	local accent = TOAST_COLORS[kind] or C.sky
	local card = new("Frame", {
		Name = "Toast",
		Size = UDim2.fromOffset(440, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.slate,
		BorderSizePixel = 0,
		Parent = toastHolder,
	}, { Theme.corner("round"), Theme.stroke(3, accent) })
	Theme.translucent(card, 0.08)
	new("UIPadding", {
		PaddingLeft = UDim.new(0, 16),
		PaddingRight = UDim.new(0, 16),
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		Parent = card,
	})
	Theme.text({
		Text = (TOAST_ICONS[kind] or "💬") .. "  " .. text,
		TextSize = 20,
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
	task.delay(2.6, function()
		card:Destroy()
	end)
end

function HudController.alert(text, color)
	alertLabel.Text = text
	alertLabel.TextColor3 = color or C.mustard
	alertLabel.Visible = true
	Theme.pop(alertLabel)
	local mine = text
	task.delay(3, function()
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
		Size = UDim2.fromOffset(520, 50),
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
	Theme.tween(frame, 0.35, { Position = UDim2.new(0.5, 0, 0, 84) }, Enum.EasingStyle.Back)
	task.delay(3, function()
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

-- Streak banner and kill feed ----------------------------------------------------------------------------------
function HudController.streak(name, text, color)
	streakLabel.Text = `{text}: {name}`
	streakLabel.TextColor3 = color or C.orange
	streakLabel.Visible = true
	Theme.pop(streakLabel)
	local mine = streakLabel.Text
	task.delay(2.5, function()
		if streakLabel.Text == mine then
			streakLabel.Visible = false
		end
	end)
end

function HudController.feed(e)
	local row = new("Frame", {
		Name = "FeedLine",
		Size = UDim2.fromOffset(330, 26),
		BackgroundColor3 = C.slate,
		BorderSizePixel = 0,
		LayoutOrder = math.floor(os.clock() * 100),
		Parent = feedFrame,
	}, { Theme.corner(8) })
	Theme.translucent(row, 0.3)
	local mine = e.killer == player.DisplayName
	local victimMe = e.victim == player.DisplayName
	if mine or victimMe then
		Theme.stroke(2, mine and C.mustard or C.red).Parent = row
	end
	local rifle = e.skin and `{e.rifle} · {e.skin}` or e.rifle or ""
	local line = new("Frame", {
		Name = "Parts",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Parent = row,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = line,
	})
	local function part(order, text, color, size)
		local t = Theme.text({
			Name = "P" .. order,
			LayoutOrder = order,
			Text = text,
			TextSize = size or 15,
			TextScaled = false,
			TextWrapped = false,
			TextColor3 = color or C.white,
			outline = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 22),
			Parent = line,
		})
		t.TextWrapped = false
		return t
	end
	part(1, e.killer, e.killerColor)
	part(2, e.headshot and "🎯" or "🔫")
	if rifle ~= "" then
		part(3, "[" .. rifle .. "]", Color3.fromRGB(200, 200, 215), 12)
	end
	part(4, e.victim, e.victimColor)
	if e.tag then
		part(5, e.tag, C.mustard, 13)
	end
	local rows = {}
	for _, c in feedFrame:GetChildren() do
		if c:IsA("Frame") then
			table.insert(rows, c)
		end
	end
	table.sort(rows, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	while #rows > 5 do
		table.remove(rows, 1):Destroy()
	end
	task.delay(6, function()
		row:Destroy()
	end)
end

-- Building ----------------------------------------------------------------------------------------------------------
local function pill(name, color, props)
	local label = new("TextLabel", {
		Name = name,
		Text = "",
		Font = Theme.Body,
		TextSize = math.floor(18 * Theme.textFactor() + 0.5),
		TextColor3 = color,
		BackgroundColor3 = C.slate,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 28),
		Visible = false,
		Parent = gui,
	}, {
		Theme.corner("round"),
		Theme.textStroke(1.5),
		new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
	})
	for k, v in props or {} do
		label[k] = v
	end
	return label
end

local function buildTopLeft()
	local coins = Theme.slab({
		Name = "Coins",
		Size = UDim2.fromOffset(190, 42),
		Position = UDim2.fromOffset(14, 10),
		round = true,
		Parent = gui,
	})
	Theme.text({
		Text = "💰",
		Size = UDim2.fromOffset(34, 34),
		Position = UDim2.fromOffset(6, 4),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = coins,
	})
	coinsLabel = Theme.title({
		Name = "Value",
		Text = "0",
		Size = UDim2.new(1, -50, 1, -8),
		Position = UDim2.fromOffset(44, 4),
		Parent = coins,
	})
	local keys = Theme.slab({
		Name = "Keys",
		Size = UDim2.fromOffset(96, 34),
		Position = UDim2.fromOffset(14, 56),
		round = true,
		Parent = gui,
	})
	Theme.text({
		Text = "🔑",
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.fromOffset(6, 3),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = keys,
	})
	keysLabel = Theme.title({
		Name = "Value",
		Text = "0",
		TextColor3 = C.mustard,
		Size = UDim2.new(1, -40, 1, -8),
		Position = UDim2.fromOffset(36, 4),
		Parent = keys,
	})
	local level = Theme.slab({
		Name = "Level",
		Size = UDim2.fromOffset(86, 34),
		Position = UDim2.fromOffset(116, 56),
		BackgroundColor3 = C.sky,
		round = true,
		Parent = gui,
	})
	levelLabel = Theme.title({
		Name = "Value",
		Text = "LV 1",
		Size = UDim2.new(1, -10, 1, -8),
		Position = UDim2.fromOffset(5, 4),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = level,
	})
	-- the level bar along the bottom
	local bar
	bar, levelFill = Theme.bar({
		Name = "LevelBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(360, 16),
		Position = UDim2.new(0.5, 0, 1, -8),
		Parent = gui,
	}, C.sky)
	levelText = Theme.title({
		Name = "Text",
		Text = "",
		TextSize = 13,
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		outline = 1.5,
		ZIndex = 3,
		Parent = bar,
	})
	boostPill = pill("Boost", C.mustard, { Position = UDim2.fromOffset(14, 96) })
	crownPill = pill("Crown", C.mustard, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 120) })
end

local function buildRoundCard()
	roundCard = Theme.slab({
		Name = "Round",
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(300, 70),
		Position = UDim2.new(0.5, 0, 0, 8),
		round = true,
		Parent = gui,
	})
	roundClock = Theme.title({
		Name = "Clock",
		Text = "",
		Size = UDim2.new(1, -20, 0, 34),
		Position = UDim2.fromOffset(10, 4),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = roundCard,
	})
	roundTitle = Theme.text({
		Name = "Title",
		Text = "",
		TextColor3 = C.white,
		outline = 1.5,
		Size = UDim2.new(1, -20, 0, 24),
		Position = UDim2.fromOffset(10, 40),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = roundCard,
	})
	myLine = pill("Mine", C.white, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 84) })
	giftPill = pill("Gift", C.pink, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10) })
	voteBar = new("Frame", {
		Name = "VoteBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 84),
		Size = UDim2.fromOffset(480, 40),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = voteBar,
	})
	lastMinutePill = pill("LastMinute", C.orange, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 152),
		Text = "⏰ LAST MINUTE · 2X COINS",
	})
end

local function buildScoreAndFeed()
	scoreFrame = Theme.slab({
		Name = "Scores",
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(200, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(1, -12, 0, 10),
		Visible = false,
		Parent = gui,
	})
	new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scoreFrame })
	new("UIPadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		Parent = scoreFrame,
	})
	feedFrame = new("Frame", {
		Name = "Feed",
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(330, 150),
		Position = UDim2.new(1, -12, 0, 190),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	new("UIListLayout", {
		Padding = UDim.new(0, 3),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Parent = feedFrame,
	})
end

local function buildCenter()
	alertLabel = Theme.title({
		Name = "Alert",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(640, 50),
		Position = UDim2.new(0.5, 0, 0.3, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	})
	streakLabel = Theme.title({
		Name = "Streak",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(600, 44),
		Position = UDim2.new(0.5, 0, 0.4, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	})
	toastHolder = new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(440, 160),
		Position = UDim2.new(0.5, 0, 1, -36),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	new("UIListLayout", {
		Padding = UDim.new(0, 6),
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = toastHolder,
	})
	-- the pop screen
	poppedFrame = new("Frame", {
		Name = "Popped",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 30,
		Parent = gui,
	})
	poppedTitle = Theme.title({
		Name = "Title",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(620, 46),
		Position = UDim2.new(0.5, 0, 0, 96),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.red,
		ZIndex = 31,
		Parent = poppedFrame,
	})
	poppedSub = Theme.text({
		Name = "Sub",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(620, 28),
		Position = UDim2.new(0.5, 0, 0, 144),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.white,
		outline = 1.5,
		ZIndex = 31,
		Parent = poppedFrame,
	})
	poppedCount = Theme.title({
		Name = "Count",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(400, 40),
		Position = UDim2.new(0.5, 0, 1, -110),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 31,
		Parent = poppedFrame,
	})
	reviveButton = Theme.button({
		Name = "Revive",
		Text = "⚡ BACK NOW · R$ 9",
		BackgroundColor3 = C.good,
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(220, 46),
		Position = UDim2.new(0.5, 0, 1, -56),
		ZIndex = 32,
		Parent = poppedFrame,
	})
	reviveButton.Activated:Connect(function()
		if Theme.busy(reviveButton, 1.5) then
			Net.send("Purchase", "product", "REVIVE")
		end
	end)
	podiumBanner = Theme.slab({
		Name = "Podium",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(520, 92),
		Position = UDim2.new(0.5, 0, 1, -40),
		Visible = false,
		ZIndex = 25,
		Parent = gui,
	})
end

local function buildMenu()
	menu = new("Frame", {
		Name = "Menu",
		Size = UDim2.fromOffset(170, 360),
		Position = UDim2.fromOffset(14, 128),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local items = {
		{ "Shop", "🛒", "SHOP", C.pink },
		{ "Crates", "🎁", "CRATES", C.purple },
		{ "Rifles", "🔫", "RIFLES", C.sky },
		{ "Style", "✨", "STYLE", C.teal },
		{ "Season", "🏅", "SEASON", C.orange },
		{ "Quests", "📜", "QUESTS", C.mustard },
		{ "Store", "💎", "STORE", C.good },
	}
	for i, it in items do
		local col, row = (i - 1) % 2, (i - 1) // 2
		local button, dot = Theme.iconButton({
			Name = it[1] .. "Button",
			icon = it[2],
			label = it[3],
			color = it[4],
			Size = UDim2.fromOffset(66, 66),
			Position = UDim2.fromOffset(col * 80, row * 84),
			Parent = menu,
		})
		if it[1] == "Quests" then
			questDot = dot
		end
		button.Activated:Connect(function()
			if HudController.openPanel then
				HudController.openPanel(it[1])
			end
		end)
	end
	playButton = Theme.button({
		Name = "PlayButton",
		Text = "▶ PLAY",
		BackgroundColor3 = C.orange,
		AnchorPoint = Vector2.new(1, 1),
		Size = UDim2.fromOffset(170, 64),
		Position = UDim2.new(1, -24, 1, -40),
		Visible = false,
		Parent = gui,
	})
	playButton.Activated:Connect(function()
		Net.send("Play")
	end)
	lobbyButton = Theme.button({
		Name = "LobbyButton",
		Text = "🏠 LOBBY",
		BackgroundColor3 = C.slate,
		Size = UDim2.fromOffset(100, 36),
		Position = UDim2.fromOffset(14, 96),
		Visible = false,
		Parent = gui,
	})
	lobbyButton.Activated:Connect(function()
		Net.send("Leave")
	end)
end

-- Updating ------------------------------------------------------------------------------------------------------
local function drawScores()
	for _, c in scoreFrame:GetChildren() do
		if c:IsA("TextLabel") then
			c:Destroy()
		end
	end
	local myRank, total = nil, #scores
	for i, s in scores do
		if s.userId == player.UserId and not s.robot then
			myRank = i
		end
		if i <= 5 then
			local me = s.userId == player.UserId and not s.robot
			Theme.text({
				Name = "Row" .. i,
				LayoutOrder = i,
				Text = `{i}. {s.name}{s.robot and " 🤖" or ""}   {s.pops}`,
				TextSize = 16,
				TextScaled = false,
				TextColor3 = me and C.mustard or (i == 1 and Color3.fromRGB(255, 225, 120) or C.white),
				outline = 1.2,
				Size = UDim2.new(1, 0, 0, 20),
				Parent = scoreFrame,
			})
		end
	end
	local mine
	for _, s in scores do
		if s.userId == player.UserId and not s.robot then
			mine = s
		end
	end
	if mine and inArena() and round.state == "round" then
		myLine.Text = `🎯 {mine.pops} pops · #{myRank} of {total}`
		myLine.Visible = true
	else
		myLine.Visible = false
	end
end

local function drawRound()
	local now = serverNow()
	local left = math.max(0, (round.endsAt or 0) - now)
	local state = round.state
	if state == "waiting" then
		roundClock.Text = "⏳ WAITING"
		roundClock.TextColor3 = C.mustard
		roundTitle.Text = "A round starts with 2 players"
	elseif state == "lobby" then
		roundClock.Text = "NEXT ROUND " .. Format.time(left)
		roundClock.TextColor3 = C.mustard
		roundTitle.Text = "Vote for a map on the pads!"
	elseif state == "round" then
		roundClock.Text = "⏱ " .. Format.time(left)
		roundClock.TextColor3 = left <= Constants.LAST_MINUTE and C.orange or C.white
		roundTitle.Text = inArena() and (round.map or "") or `{round.map or ""} · tap PLAY to jump in`
	else
		roundClock.Text = "🏆 ROUND OVER"
		roundClock.TextColor3 = C.mustard
		roundTitle.Text = "Next round soon"
	end
	lastMinutePill.Visible = state == "round" and left <= Constants.LAST_MINUTE and inArena()
	local zone = player:GetAttribute("Zone")
	local inRound = zone == "arena"
	scoreFrame.Visible = state == "round" and #scores > 0
	feedFrame.Visible = true
	menu.Visible = not inArena()
	playButton.Visible = state == "round" and zone == "lobby"
	lobbyButton.Visible = inRound
	-- the pop screen countdown
	if poppedFrame.Visible then
		local wait = math.max(0, poppedBack - now)
		poppedCount.Text = wait > 0 and string.format("BACK IN %d", math.ceil(wait)) or ""
		if wait <= 0 or not player:GetAttribute("Popped") then
			poppedFrame.Visible = false
		end
	end
	crownPill.Visible = player:GetAttribute("Crown") == true and inRound
	crownPill.Text = "👑 You lead! Everyone sees your crown"
	-- the next playtime gift (lobby only; the round has the scoreboard there)
	local pt = Store.state.playtime
	giftPill.Visible = pt ~= nil and pt.nextIn ~= nil and not inArena() and not scoreFrame.Visible
	if giftPill.Visible then
		giftPill.Text = `🎁 {pt.nextText} in {Format.time(
			math.max(0, pt.nextIn - (os.clock() - (HudController._ptAt or os.clock())))
		)}`
	end
	voteBar.Visible = state == "lobby" and not inArena() and Store.state.vote ~= nil and Store.state.vote.open == true
	local boost = Store.state.boostLeft or 0
	boostPill.Visible = boost > 0 and not inArena()
	boostPill.Text = "🚀 2X COINS " .. Format.time(boost)
end

local function drawProfile(partial)
	local s = Store.state
	if partial.coins and s.coins then
		coinsTarget = s.coins
		if coinsShown == nil then
			coinsShown = coinsTarget
			coinsLabel.Text = Format.num(coinsShown)
		end
	end
	if partial.keys then
		keysLabel.Text = Format.num(s.keys or 0)
	end
	if partial.level or partial.xpInto then
		levelLabel.Text = "LV " .. (s.level or 1)
		local need = s.xpNeed or 1
		levelFill.Size = UDim2.fromScale(math.clamp((s.xpInto or 0) / need, 0, 1), 1)
		levelText.Text = `LV {s.level or 1}  ·  {Format.num(s.xpInto or 0)} / {Format.num(need)} XP`
	end
	if (partial.quests or partial.daily) and questDot then
		questDot.Visible = (s.daily and s.daily.canClaim) == true
	end
	if partial.playtime then
		HudController._ptAt = os.clock()
	end
	if partial.vote then
		for _, c in voteBar:GetChildren() do
			if c:IsA("TextButton") then
				c:Destroy()
			end
		end
		for _, o in s.vote.options or {} do
			local b = Theme.button({
				Name = "Vote_" .. o.key,
				Text = `{o.emoji} {o.name} ({o.votes})`,
				BackgroundColor3 = C.sky,
				TextSize = 15,
				TextScaled = false,
				Size = UDim2.fromOffset(150, 38),
				Parent = voteBar,
			})
			b.Activated:Connect(function()
				Net.send("Vote", o.key)
			end)
		end
	end
end

function HudController:init()
	gui = Theme.screen("Hud", 10, player:WaitForChild("PlayerGui"))
	buildTopLeft()
	buildRoundCard()
	buildScoreAndFeed()
	buildCenter()
	buildMenu()
	Net.listen("Toast", HudController.toast)
	Net.listen("Alert", HudController.alert)
	Net.listen("Announce", HudController.announce)
	Net.listen("Streak", HudController.streak)
	Net.listen("Feed", HudController.feed)
	Net.listen("Round", function(info)
		round = info
		drawRound()
	end)
	Net.listen("Score", function(list)
		scores = list
		drawScores()
	end)
	Net.listen("Popped", function(info)
		poppedBack = info.back or (serverNow() + Constants.RESPAWN_SECONDS)
		poppedTitle.Text = info.headshot and `🎯 HEADSHOT by {info.by}!` or `💥 POPPED by {info.by}!`
		local extra = info.skin and ` · {info.skin} skin` or ""
		poppedSub.Text = info.how == "shot" and `LV {info.level} · {info.rifle}{extra}` or ""
		poppedFrame.Visible = true
		reviveButton.Visible = player:GetAttribute("Zone") == "arena"
	end)
	Net.listen("Podium", function(list)
		for _, c in podiumBanner:GetChildren() do
			if c:IsA("TextLabel") then
				c:Destroy()
			end
		end
		local medals = { "🥇", "🥈", "🥉" }
		local lines = {}
		for i, r in list do
			table.insert(lines, `{medals[i]} {r.name} ({r.pops})`)
		end
		Theme.title({
			Text = #lines > 0 and table.concat(lines, "   ") or "Nobody popped anyone!",
			Size = UDim2.new(1, -20, 0, 40),
			Position = UDim2.fromOffset(10, 8),
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 26,
			Parent = podiumBanner,
		})
		Theme.text({
			Text = "🏆 TOP 3 THIS ROUND",
			TextColor3 = C.mustard,
			outline = 1.5,
			Size = UDim2.new(1, -20, 0, 26),
			Position = UDim2.fromOffset(10, 54),
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 26,
			Parent = podiumBanner,
		})
		podiumBanner.Visible = true
		Theme.pop(podiumBanner)
		task.delay(Constants.PODIUM_SECONDS, function()
			podiumBanner.Visible = false
		end)
	end)
	Store.Changed:Connect(drawProfile)
	drawProfile({ coins = true, keys = true, level = true })
	player:GetAttributeChangedSignal("Zone"):Connect(function()
		drawRound()
		drawScores()
	end)
	RunService.RenderStepped:Connect(function(dt)
		if coinsShown ~= nil and coinsShown ~= coinsTarget then
			local diff = coinsTarget - coinsShown
			coinsShown = math.abs(diff) < 1 and coinsTarget or coinsShown + diff * math.min(1, dt * 8)
			coinsLabel.Text = Format.num(coinsShown)
		end
	end)
	task.spawn(function()
		while true do
			drawRound()
			task.wait(0.25)
		end
	end)
end

return HudController
