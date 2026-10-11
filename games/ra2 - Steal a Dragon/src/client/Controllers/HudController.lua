-- The always-on screen, built for phones first:
--   top-left: coins and coins per second, egg timer and waiting dragons
--   left: 2 x 2 menu buttons (Shop, Speed, Gift, Invite), above the thumbstick
--   top-centre: the goal card, carry banner and event banners
--   bottom-right: big BONK and LOCK buttons, left of the jump button
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
local goalCard, goalText, goalFill, goalReward
local carryBanner, eventBanner, luckBanner
local lockButton, bonkButton
local giftDot
local toastHolder, alertLabel, bonkedLabel
local events = { legendAt = nil, luckUntil = nil, luckBy = nil }
local eggReceived -- os.clock() when the egg view arrived
local tutorialActive = false

HudController.openPanel = nil -- set by PanelController: function(name)

local function serverNow()
	return workspace:GetServerTimeNow()
end

-- Toasts and alerts ------------------------------------------------------------------------------------------
local TOAST_COLORS = { good = C.good, bad = C.red, info = C.white }

function HudController.toast(text, kind)
	local card = Theme.card({
		Name = "Toast",
		Size = UDim2.fromOffset(460, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = TOAST_COLORS[kind] or C.white,
		Parent = toastHolder,
	})
	Theme.padding(8).Parent = card
	Theme.text({
		Text = text,
		TextSize = 22,
		TextScaled = false,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromScale(1, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = card,
	})
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
		Size = UDim2.fromOffset(220, 60),
		AlwaysOnTop = true,
		MaxDistance = 120,
		Parent = anchor,
	})
	Theme.text({
		Text = text,
		Font = Theme.Display,
		TextColor3 = color or C.mustard,
		TextStrokeTransparency = 0,
		TextStrokeColor3 = C.ink,
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
local function buildCoins()
	local slab = Theme.slab({
		Name = "Coins",
		Size = UDim2.fromOffset(240, 68),
		Position = UDim2.fromOffset(12, 8),
		Parent = gui,
	})
	coinsLabel = Theme.text({
		Name = "Value",
		Text = "💰 0",
		Font = Theme.Display,
		TextColor3 = C.mustard,
		Size = UDim2.new(1, -16, 0, 40),
		Position = UDim2.fromOffset(10, 4),
		Parent = slab,
	})
	cpsLabel = Theme.text({
		Name = "Cps",
		Text = "+0 / sec",
		TextColor3 = C.white,
		Size = UDim2.new(1, -16, 0, 20),
		Position = UDim2.fromOffset(12, 44),
		Parent = slab,
	})
	eggLabel = Theme.text({
		Name = "Egg",
		Text = "",
		TextColor3 = C.white,
		TextStrokeTransparency = 0,
		Size = UDim2.fromOffset(260, 22),
		Position = UDim2.fromOffset(14, 80),
		Parent = gui,
	})
	waitingLabel = Theme.text({
		Name = "Waiting",
		Text = "",
		TextColor3 = C.mustard,
		TextStrokeTransparency = 0,
		Size = UDim2.fromOffset(260, 22),
		Position = UDim2.fromOffset(14, 102),
		Parent = gui,
	})
end

local function buildMenu()
	local items = {
		{ "Shop", "🛒", "SHOP", C.mustard, 12, 132 },
		{ "Speed", "👟", "SPEED", C.sky, 88, 132 },
		{ "Gift", "🎁", "GIFT", C.good, 12, 208 },
		{ "Invite", "👥", "FRIENDS", C.teal, 88, 208 },
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
	bonkButton = Theme.button({
		Name = "BonkButton",
		Text = "",
		BackgroundColor3 = C.red,
		AnchorPoint = Vector2.new(1, 1),
		Size = UDim2.fromOffset(108, 108),
		Position = UDim2.new(1, -170, 1, -20),
		Parent = gui,
	})
	bonkButton.UICorner.CornerRadius = UDim.new(1, 0)
	Theme.text({
		Text = "🔨",
		Size = UDim2.new(1, 0, 0.6, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = bonkButton,
	})
	Theme.text({
		Text = "BONK",
		Font = Theme.Display,
		TextColor3 = C.white,
		TextStrokeTransparency = 0,
		Size = UDim2.new(1, 0, 0.32, 0),
		Position = UDim2.new(0, 0, 0.6, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = bonkButton,
	})
	bonkButton.Activated:Connect(function()
		Net.send("Bonk")
	end)
	lockButton = Theme.button({
		Name = "LockButton",
		Text = "🔒 LOCK",
		Font = Theme.Display,
		BackgroundColor3 = C.white,
		AnchorPoint = Vector2.new(1, 1),
		Size = UDim2.fromOffset(150, 56),
		Position = UDim2.new(1, -150, 1, -140),
		Parent = gui,
	})
	lockButton.Activated:Connect(function()
		Net.send("Lock")
	end)
end

local function buildCenter()
	goalCard = Theme.card({
		Name = "Goal",
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(400, 70),
		Position = UDim2.new(0.5, 0, 0, 8),
		Visible = false,
		Parent = gui,
	})
	goalText = Theme.text({
		Name = "Text",
		Text = "",
		Font = Theme.Display,
		Size = UDim2.new(1, -110, 0, 30),
		Position = UDim2.fromOffset(12, 6),
		Parent = goalCard,
	})
	goalReward = Theme.text({
		Name = "Reward",
		Text = "",
		TextColor3 = Color3.fromRGB(190, 130, 0),
		Size = UDim2.new(0, 96, 0, 26),
		Position = UDim2.new(1, -104, 0, 8),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = goalCard,
	})
	local bar
	bar, goalFill = Theme.bar(
		{ Name = "Bar", Size = UDim2.new(1, -24, 0, 18), Position = UDim2.fromOffset(12, 42), Parent = goalCard },
		C.good
	)
	_ = bar
	carryBanner = Theme.card({
		Name = "Carry",
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(360, 54),
		Position = UDim2.new(0.5, 0, 0, 86),
		BackgroundColor3 = C.mustard,
		Visible = false,
		Parent = gui,
	})
	Theme.text({
		Name = "Text",
		Text = "🏠 RUN HOME!",
		Font = Theme.Display,
		Size = UDim2.new(1, -16, 1, -10),
		Position = UDim2.fromOffset(8, 5),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = carryBanner,
	})
	eventBanner = Theme.slab({
		Name = "Event",
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(380, 40),
		Position = UDim2.new(0.5, 0, 0, 146),
		Visible = false,
		Parent = gui,
	})
	Theme.text({
		Name = "Text",
		Text = "",
		Font = Theme.Display,
		TextColor3 = C.mustard,
		Size = UDim2.new(1, -16, 1, -8),
		Position = UDim2.fromOffset(8, 4),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = eventBanner,
	})
	luckBanner = Theme.slab({
		Name = "Luck",
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(250, 40),
		Position = UDim2.new(1, -12, 0, 8),
		Visible = false,
		Parent = gui,
	})
	Theme.text({
		Name = "Text",
		Text = "",
		Font = Theme.Display,
		TextColor3 = C.good,
		Size = UDim2.new(1, -16, 1, -8),
		Position = UDim2.fromOffset(8, 4),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = luckBanner,
	})

	toastHolder = new("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(460, 220),
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
	alertLabel = Theme.text({
		Name = "Alert",
		Text = "",
		Font = Theme.Display,
		TextStrokeTransparency = 0,
		TextStrokeColor3 = C.ink,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(640, 80),
		Position = UDim2.new(0.5, 0, 0.42, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		Parent = gui,
	})
	bonkedLabel = Theme.text({
		Name = "Bonked",
		Text = "💫 BONKED! 💫",
		Font = Theme.Display,
		TextColor3 = C.mustard,
		TextStrokeTransparency = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(420, 70),
		Position = UDim2.new(0.5, 0, 0.3, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		Parent = gui,
	})
end

-- Updating ---------------------------------------------------------------------------------------------------
local function refresh()
	local s = Store.state
	coinsLabel.Text = "💰 " .. Format.num(s.coins or 0)
	cpsLabel.Text = "+"
		.. Format.num(s.cps or 0)
		.. " / sec"
		.. ((s.friendsHere or 0) > 0 and `  👥 +{s.friendsHere * 10}%` or "")
	local goal = s.goal
	goalCard.Visible = goal ~= nil and goal ~= false and not tutorialActive
	if goal then
		goalText.Text = "⭐ " .. goal.text
		goalReward.Text = "+" .. Format.num(goal.reward)
		goalFill.Size = UDim2.fromScale(math.clamp(goal.progress / goal.target, 0, 1), 1)
	end
	carryBanner.Visible = s.carrying ~= nil and s.carrying ~= false
	if carryBanner.Visible then
		carryBanner.Text.Text = s.carrying.kind == "stolen" and "😈 RUN HOME! Don't get bonked!" or "🏠 RUN HOME!"
	end
	local waiting = s.waiting or 0
	waitingLabel.Text = waiting > 0 and `🪺 {waiting} dragon{waiting > 1 and "s" or ""} waiting for a nest` or ""
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
	-- lock button
	local lockLeft = (s.lockUntil or 0) - serverNow()
	if lockLeft > 0 then
		lockButton.Text = "🔒 " .. Format.time(lockLeft)
		lockButton.BackgroundColor3 = C.good
	else
		lockButton.Text = "🔓 LOCK"
		lockButton.BackgroundColor3 = C.white
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
	task.spawn(function()
		while true do
			pcall(tick)
			task.wait(0.25)
		end
	end)
end

return HudController
