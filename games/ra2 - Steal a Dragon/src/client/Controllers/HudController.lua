-- The always-on screen, built for phones first:
--   top-left: coins and coins per second, egg timer and waiting dragons
--   left: 2 x 2 menu buttons (Shop, Speed, Gift, Invite), above the thumbstick
--   top-centre: the goal card, carry banner and event banners
--   bottom-right: the LOCK button, left of the jump button (bonking is the bat in the hotbar)
--   plus toasts, big alerts, floating world popups and the BONKED overlay.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")

local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Color
local new = Theme.new
local player = Players.LocalPlayer

local HudController = { Name = "HudController", Order = 10 }

local gui
local coinsLabel, cpsLabel, eggLabel, waitingLabel
local goalCard, goalText, goalFill, goalReward, goalCount
local carryBanner, eventBanner, luckBanner
local lockButton
local giftDot
local toastHolder, alertLabel, bonkedLabel
local events = { legendAt = nil, luckUntil = nil, luckBy = nil }
local eggReceived -- os.clock() when the egg view arrived
local coinsShown, coinsTarget = nil, 0 -- the number on screen eases toward the real coin count
local hints = {} -- key hint badges, shown for keyboard and gamepad players
local tutorialActive = false

HudController.openPanel = nil -- set by PanelController: function(name)

local function serverNow()
	return workspace:GetServerTimeNow()
end

-- Toasts and alerts ------------------------------------------------------------------------------------------
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
	-- keep at most 3
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

-- A number or word that floats up from a spot in the world.
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
		Size = UDim2.fromOffset(240, 70),
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
		anchor.CFrame = CFrame.new(position + Vector3.new(0, t * 4, 0))
		if t > 1.2 then
			conn:Disconnect()
			anchor:Destroy()
		end
	end)
end

-- Building ---------------------------------------------------------------------------------------------------
-- A small dark pill with outlined text, hidden while its text is empty.
local function infoPill(name, y, color)
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
		Size = UDim2.fromOffset(0, 28),
		Position = UDim2.fromOffset(14, y),
		Visible = false,
		Parent = gui,
	}, {
		Theme.corner("round"),
		Theme.textStroke(1.5),
		new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
	})
	return Theme.translucent(label, 0.2)
end

local function buildCoins()
	local pill = new("Frame", {
		Name = "Coins",
		Size = UDim2.fromOffset(224, 54),
		Position = UDim2.fromOffset(40, 10),
		BackgroundColor3 = C.mustard,
		BorderSizePixel = 0,
		Parent = gui,
	}, {
		Theme.corner("round"),
		Theme.stroke(3.5),
		Theme.gloss(Color3.fromRGB(255, 255, 255), Color3.fromRGB(215, 175, 120)),
	})
	local icon = new("Frame", {
		Name = "CoinIcon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(62, 62),
		Position = UDim2.new(0, 0, 0.5, 0),
		BackgroundColor3 = C.orange,
		BorderSizePixel = 0,
		Parent = pill,
	}, {
		Theme.corner("round"),
		Theme.stroke(3.5),
		Theme.gloss(Color3.fromRGB(255, 240, 160), Color3.fromRGB(230, 150, 40)),
	})
	Theme.text({
		Text = "💰",
		Size = UDim2.fromScale(0.8, 0.8),
		Position = UDim2.fromScale(0.1, 0.08),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = icon,
	})
	coinsLabel = Theme.title({
		Name = "Value",
		Text = "0",
		Size = UDim2.new(1, -48, 1, -10),
		Position = UDim2.fromOffset(38, 5),
		outline = 3,
		Parent = pill,
	})
	cpsLabel = new("TextLabel", {
		Name = "Cps",
		Text = "+0 / sec",
		Font = Theme.Display,
		TextSize = math.floor(19 * Theme.textFactor() + 0.5),
		TextColor3 = C.good,
		BackgroundColor3 = C.slate,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 24),
		Position = UDim2.new(0, 34, 1, -2),
		Parent = pill,
	}, {
		Theme.corner("round"),
		Theme.stroke(2),
		Theme.textStroke(1.5),
		new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
	})
	eggLabel = infoPill("Egg", 92, C.white)
	waitingLabel = infoPill("Waiting", 120, C.mustard)
end

local function buildMenu()
	local items = {
		{ "Shop", "🛒", "SHOP", C.mustard, 14, 156 },
		{ "Speed", "👟", "SPEED", C.sky, 96, 156 },
		{ "Gift", "🎁", "GIFT", C.pink, 14, 246 },
		{ "Invite", "👥", "FRIENDS", C.teal, 96, 246 },
	}
	for _, it in items do
		local button, dot = Theme.iconButton({
			Name = it[1] .. "Button",
			icon = it[2],
			label = it[3],
			color = it[4],
			Position = UDim2.fromOffset(it[5], it[6]),
			Parent = gui,
		})
		if it[1] == "Gift" then
			giftDot = dot
		end
		button.Activated:Connect(function()
			if it[1] == "Invite" then
				HudController.invite()
			elseif HudController.openPanel then
				HudController.openPanel(it[1])
			end
		end)
	end
end

local function buildActions()
	lockButton = Theme.button({
		Name = "LockButton",
		Text = "🔓 LOCK",
		BackgroundColor3 = C.orange,
		AnchorPoint = Vector2.new(1, 1),
		Size = UDim2.fromOffset(150, 54),
		Position = UDim2.new(1, -160, 1, -40),
		round = true,
		Parent = gui,
	})
	lockButton.Activated:Connect(function()
		Net.send("Lock")
	end)
	table.insert(hints, Theme.keyHint(lockButton, "L", "Y"))
end

local function banner(name, size, position, color, anchor)
	local frame = new("Frame", {
		Name = name,
		AnchorPoint = anchor or Vector2.new(0.5, 0),
		Size = size,
		Position = position,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Visible = false,
		Parent = gui,
	}, {
		Theme.corner("round"),
		Theme.stroke(3.5),
		Theme.gloss(Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 200, 200)),
	})
	Theme.title({
		Name = "Text",
		Text = "",
		Size = UDim2.new(1, -24, 1, -10),
		Position = UDim2.fromOffset(12, 5),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = frame,
	})
	return frame
end

local function buildCenter()
	goalCard = Theme.slab({
		Name = "Goal",
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(430, 62),
		Position = UDim2.new(0.5, 10, 0, 10),
		Visible = false,
		round = true,
		Parent = gui,
	})
	local star = new("Frame", {
		Name = "Star",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(58, 58),
		Position = UDim2.new(0, 4, 0.5, 0),
		BackgroundColor3 = C.mustard,
		BorderSizePixel = 0,
		Parent = goalCard,
	}, {
		Theme.corner("round"),
		Theme.stroke(3.5),
		Theme.gloss(Color3.fromRGB(255, 255, 255), Color3.fromRGB(220, 160, 60)),
	})
	Theme.text({
		Text = "⭐",
		Size = UDim2.fromScale(0.74, 0.74),
		Position = UDim2.fromScale(0.13, 0.12),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = star,
	})
	goalText = Theme.title({
		Name = "Text",
		Text = "",
		Size = UDim2.new(1, -150, 0, 24),
		Position = UDim2.fromOffset(42, 6),
		outline = 2,
		Parent = goalCard,
	})
	local reward = new("Frame", {
		Name = "RewardPill",
		AnchorPoint = Vector2.new(1, 0.5),
		Size = UDim2.fromOffset(96, 34),
		Position = UDim2.new(1, -8, 0.5, 0),
		BackgroundColor3 = C.mustard,
		BorderSizePixel = 0,
		Parent = goalCard,
	}, {
		Theme.corner("round"),
		Theme.stroke(2.5),
		Theme.gloss(Color3.fromRGB(255, 255, 255), Color3.fromRGB(220, 170, 80)),
	})
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
	bar, goalFill = Theme.bar({
		Name = "Bar",
		Size = UDim2.new(1, -150, 0, 18),
		Position = UDim2.fromOffset(42, 34),
		Parent = goalCard,
	}, C.good)
	goalCount = Theme.title({
		Name = "Count",
		Text = "",
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		outline = 1.5,
		ZIndex = 3,
		Parent = bar,
	})
	carryBanner = banner("Carry", UDim2.fromOffset(380, 54), UDim2.new(0.5, 10, 0, 84), C.mustard)
	carryBanner.Text.Text = "🏠 RUN HOME!"
	eventBanner = banner("Event", UDim2.fromOffset(390, 44), UDim2.new(0.5, 10, 0, 146), C.purple)
	luckBanner = banner("Luck", UDim2.fromOffset(230, 44), UDim2.new(1, -12, 0, 10), C.good, Vector2.new(1, 0))

	toastHolder = new("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(470, 220),
		Position = UDim2.new(0.5, 0, 1, -150),
		Parent = gui,
	})
	new("UIListLayout", {
		Padding = UDim.new(0, 6),
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = toastHolder,
	})
	alertLabel = Theme.title({
		Name = "Alert",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(680, 84),
		Position = UDim2.new(0.5, 0, 0.42, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		outline = 4,
		Visible = false,
		Parent = gui,
	})
	bonkedLabel = Theme.title({
		Name = "Bonked",
		Text = "💫 BONKED! 💫",
		TextColor3 = C.mustard,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(440, 76),
		Position = UDim2.new(0.5, 0, 0.3, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		outline = 4,
		Visible = false,
		Parent = gui,
	})
end

-- Updating ---------------------------------------------------------------------------------------------------
local function refresh()
	local s = Store.state
	-- coins count up over about half a second instead of jumping, and the pill gives a little punch
	local target = s.coins or 0
	if coinsShown == nil or Theme.reducedMotion() then
		coinsShown = target
		coinsLabel.Text = Format.num(target)
	elseif target > coinsTarget then
		local punch = coinsLabel.Parent:FindFirstChild("Punch")
			or new("UIScale", { Name = "Punch", Parent = coinsLabel.Parent })
		punch.Scale = 1.12
		Theme.tween(punch, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	coinsTarget = target
	cpsLabel.Text = "+"
		.. Format.num(s.cps or 0)
		.. " / sec"
		.. ((s.friendsHere or 0) > 0 and `  👥 +{s.friendsHere * 10}%` or "")
	local goal = s.goal
	goalCard.Visible = goal ~= nil and goal ~= false and not tutorialActive
	if goal then
		goalText.Text = goal.text
		goalReward.Text = "+" .. Format.num(goal.reward)
		goalCount.Text = Format.num(goal.progress) .. " / " .. Format.num(goal.target)
		goalFill.Size = UDim2.fromScale(math.clamp(goal.progress / goal.target, 0, 1), 1)
	end
	carryBanner.Visible = s.carrying ~= nil and s.carrying ~= false
	if carryBanner.Visible then
		carryBanner.Text.Text = s.carrying.kind == "stolen" and "😈 RUN HOME! Don't get bonked!" or "🏠 RUN HOME!"
	end
	local waiting = s.waiting or 0
	waitingLabel.Text = waiting > 0 and `🪺 {waiting} dragon{waiting > 1 and "s" or ""} waiting for a nest` or ""
	waitingLabel.Visible = waiting > 0
	giftDot.Visible = s.daily ~= nil and s.daily.canClaim == true
end

local function tick()
	local s = Store.state
	-- egg timer
	if s.egg and eggReceived then
		local left = s.egg.secondsLeft - (os.clock() - eggReceived)
		eggLabel.Text = left > 0 and `🥚 {s.egg.name} egg: {Format.time(left)}` or `🥚 {s.egg.name} egg is READY!`
	else
		eggLabel.Text = ""
	end
	eggLabel.Visible = eggLabel.Text ~= ""
	-- lock button: only shown inside your own base, where it works (contextual UI keeps the screen clear)
	lockButton.Visible = HudController.inOwnBase() ~= false
	local lockLeft = (s.lockUntil or 0) - serverNow()
	if lockLeft > 0 then
		lockButton.Text = "🔒 " .. Format.time(lockLeft)
		lockButton.BackgroundColor3 = C.good
	else
		lockButton.Text = "🔓 LOCK"
		lockButton.BackgroundColor3 = C.orange
	end
	-- the carry banner gently pulses so it's hard to miss (not with Reduced Motion)
	if carryBanner.Visible and not Theme.reducedMotion() then
		local pulse = carryBanner:FindFirstChild("Pulse") or new("UIScale", { Name = "Pulse", Parent = carryBanner })
		pulse.Scale = 1 + math.abs(math.sin(os.clock() * 4)) * 0.05
	end
	-- events
	local legendLeft = events.legendAt and events.legendAt - serverNow()
	if legendLeft and legendLeft > 0 and legendLeft <= 30 then
		eventBanner.Visible = true
		eventBanner.Text.Text = "⭐ LEGEND DRAGON IN " .. Format.time(legendLeft)
	else
		eventBanner.Visible = false
	end
	local luckLeft = events.luckUntil and events.luckUntil - serverNow()
	if luckLeft and luckLeft > 0 then
		luckBanner.Visible = true
		luckBanner.Text.Text = "🍀 LUCK " .. Format.time(luckLeft)
	else
		luckBanner.Visible = false
	end
end

-- true / false when we can tell whether the character stands in its own base, nil when we can't.
function HudController.inOwnBase()
	local index = Store.state.baseIndex
	local bases = workspace:FindFirstChild("Bases")
	local base = index and bases and bases:FindFirstChild("Base" .. index)
	local floor = base and base:FindFirstChild("Floor")
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not floor or not hrp then
		return nil
	end
	local p = floor.CFrame:PointToObjectSpace(hrp.Position)
	return math.abs(p.X) <= floor.Size.X / 2 + 1 and math.abs(p.Z) <= floor.Size.Z / 2 + 1 and p.Y < 30
end

-- Key hints follow the input the player is using right now (hidden on touch screens).
function HudController.updateHints()
	local kind = Theme.inputKind()
	for _, badge in hints do
		badge.Visible = kind ~= "touch"
		badge.Text = badge:GetAttribute(kind == "gamepad" and "Gamepad" or "Keyboard")
		badge.Size = UDim2.fromOffset(kind == "gamepad" and 36 or 30, 26)
	end
end

function HudController.invite()
	local ok = pcall(function()
		local options = Instance.new("ExperienceInviteOptions")
		options.LaunchData = "invite:" .. player.UserId
		options.PromptMessage = "Come steal dragons with me!"
		SocialService:PromptGameInvite(player, options)
	end)
	if not ok then
		HudController.toast("Invites don't work here. Try in the real game!", "info")
	end
end

function HudController:init()
	gui = Theme.screen("Hud", 1, player:WaitForChild("PlayerGui"))
	buildCoins()
	buildMenu()
	buildActions()
	buildCenter()
	Store.Changed:Connect(function(partial)
		if partial.egg ~= nil then
			eggReceived = os.clock()
		end
		refresh()
	end)
	Net.listen("Toast", HudController.toast)
	Net.listen("Alert", function(text, color)
		HudController.alert(text, color)
	end)
	Net.listen("Popup", HudController.popup)
	Net.listen("Event", function(e)
		if e.kind == "legend" then
			events.legendAt = e.at
		elseif e.kind == "luck" then
			events.luckUntil = e.untilTime
			events.luckBy = e.by
		end
	end)
	Net.listen("Tutorial", function(info)
		tutorialActive = info ~= false and info ~= nil
		refresh()
	end)
	Net.listen("Bonked", function(seconds)
		bonkedLabel.Visible = true
		task.delay(seconds, function()
			bonkedLabel.Visible = false
		end)
	end)
	refresh()
	HudController.updateHints()
	pcall(function()
		game:GetService("UserInputService").LastInputTypeChanged:Connect(HudController.updateHints)
	end)
	RunService.RenderStepped:Connect(function(dt)
		if coinsShown and coinsShown ~= coinsTarget then
			local diff = coinsTarget - coinsShown
			coinsShown = math.abs(diff) < 1 and coinsTarget or coinsShown + diff * math.min(1, dt * 7)
			coinsLabel.Text = Format.num(coinsShown)
		end
	end)
	task.spawn(function()
		while true do
			pcall(tick)
			task.wait(0.25)
		end
	end)
end

return HudController
