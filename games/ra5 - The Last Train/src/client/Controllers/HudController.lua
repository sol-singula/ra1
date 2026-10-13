-- The always-on screen, laid out for phones first (the thumbs own the bottom corners):
--   top centre   the departure board: what the train is doing and a big timer (doors close in 2:10, final call,
--                next stop...), the distance, the next milestone and the fuel. It never hides while the doors are
--                open, so the departure time is always one glance away.
--   top left     the field bag (what you're carrying, not saved until you're aboard) and your stored materials
--   left         the crew's goal (fuel, or the next train upgrade) with its progress
--   right        CABIN (go to your cabin), BUILD, TRAIN, FRIENDS, HALL
--   and          toasts, the train's announcements as subtitles, big alerts, "+2 🔩" popups in the world, fades,
--                the milestone banner, the late-join summary card, and, when you're outside and the train is
--                about to leave, a glowing line to the nearest open door and red edges on the final call
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CabinItems = require(ReplicatedStorage.Shared.Data.CabinItems)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Layout = require(ReplicatedStorage.Shared.World.Layout)
local Net = require(ReplicatedStorage.Shared.Net)
local Resources = require(ReplicatedStorage.Shared.Data.Resources)
local TrainUpgrades = require(ReplicatedStorage.Shared.Data.TrainUpgrades)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Color
local new = Theme.new
local player = Players.LocalPlayer

local HudController = { Name = "HudController", Order = 20 }

local gui, board, headline, timer, info, phaseBar
local bagFrame, bagTitle, bagItems, bagHint, storageLine
local goalFrame, goalText, goalFill
local toastHolder, announceFrame, announceText, alertFrame, alertText, fadeFrame, fadeText
local milestoneFrame, edges
local buttons, dots = {}, {}
local guideBeam, guideAnchor

local PHASE_TEXT = {
	lobby = "Departs in",
	departing = "Doors closing",
	traveling = "Next stop",
	arriving = "Arriving",
	scavenging = "Doors close in",
	warning = "Train leaving soon!",
	ended = "Out of fuel",
}

local function panels()
	return require(script.Parent.PanelController)
end

local function inTrain()
	local c = player.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	return hrp ~= nil and Layout.inTrain(hrp.Position), hrp
end
HudController.inTrain = inTrain

-- Toasts ---------------------------------------------------------------------------------------------------------
local TOAST_ICON = { good = "✔", bad = "✖", info = "•" }
local TOAST_EDGE = { good = C.good, bad = C.bad, info = C.edge }

function HudController.toast(text, kind)
	kind = kind or "info"
	local t = Theme.slab({
		Name = "Toast",
		Size = UDim2.fromOffset(460, 34),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.ink,
		BackgroundTransparency = 0.12,
		LayoutOrder = math.floor(os.clock() * 100),
		Parent = toastHolder,
	})
	t.UIStroke.Color = TOAST_EDGE[kind] or C.edge
	t.UIStroke.Transparency = 0.1
	Theme.padding(10, 6).Parent = t
	Theme.text({
		Text = `{TOAST_ICON[kind] or "•"}  {text}`,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 15,
		TextColor3 = kind == "bad" and Theme.lighten(C.bad, 0.4) or C.cream,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = t,
	})
	Theme.pop(t)
	local list = {}
	for _, c in toastHolder:GetChildren() do
		if c.Name == "Toast" then
			table.insert(list, c)
		end
	end
	table.sort(list, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	while #list > 3 do
		table.remove(list, 1):Destroy()
	end
	task.delay(5, function()
		if t.Parent then
			t:Destroy()
		end
	end)
	return t
end

-- The train's announcements, as subtitles under the board.
local ANNOUNCE_COLOR = { chime = C.cream, warning = C.amber, final = C.bad, milestone = C.amber }
local announceSerial = 0
function HudController.announce(text, kind)
	announceSerial += 1
	local serial = announceSerial
	announceText.Text = "📢  " .. text
	announceText.TextColor3 = ANNOUNCE_COLOR[kind] or C.cream
	announceFrame.Visible = true
	Theme.pop(announceFrame)
	task.delay(7, function()
		if announceSerial == serial then
			announceFrame.Visible = false
		end
	end)
end

local alertSerial = 0
function HudController.alert(text, color)
	alertSerial += 1
	local serial = alertSerial
	alertText.Text = text
	alertText.TextColor3 = typeof(color) == "Color3" and color or C.amber
	alertFrame.Visible = true
	Theme.pop(alertFrame)
	task.delay(4, function()
		if alertSerial == serial then
			alertFrame.Visible = false
		end
	end)
end

-- "+2 🔩" floating up from a spot in the world.
function HudController.popup(position, text, color)
	if typeof(position) ~= "Vector3" then
		return
	end
	local anchor = new("Part", {
		Name = "PopupAnchor",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = CFrame.new(position),
		Parent = workspace,
	})
	local bb = new("BillboardGui", {
		Name = "Popup",
		Size = UDim2.fromOffset(220, 44),
		StudsOffset = Vector3.new(0, 0, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 120,
		Adornee = anchor,
		Parent = anchor,
	})
	local label = Theme.title({
		Text = text,
		Size = UDim2.fromScale(1, 1),
		TextColor3 = typeof(color) == "Color3" and color or C.amber,
		TextXAlignment = Enum.TextXAlignment.Center,
		outline = 2,
		Parent = bb,
	})
	Theme.tween(bb, 1.4, { StudsOffset = Vector3.new(0, 3.5, 0) })
	task.delay(0.8, function()
		Theme.tween(label, 0.6, { TextTransparency = 1 })
	end)
	task.delay(1.5, function()
		anchor:Destroy()
	end)
end

local fadeSerial = 0
function HudController.fade(seconds, text)
	seconds = tonumber(seconds) or 0.8
	fadeSerial += 1
	local serial = fadeSerial
	fadeFrame.Visible = true
	fadeFrame.BackgroundTransparency = Theme.reducedMotion() and 0 or 1
	fadeText.Text = text or ""
	Theme.tween(fadeFrame, seconds * 0.35, { BackgroundTransparency = 0 })
	task.delay(seconds * 0.6, function()
		if fadeSerial == serial then
			Theme.tween(fadeFrame, seconds * 0.4, { BackgroundTransparency = 1 })
			task.delay(seconds * 0.45, function()
				if fadeSerial == serial then
					fadeFrame.Visible = false
				end
			end)
		end
	end)
end

function HudController.milestone(km)
	milestoneFrame.Big.Text = `{km} KM`
	milestoneFrame.Small.Text = `MILESTONE · EVERY CREW MEMBER GETS {Constants.MILESTONE_PARTS} ⚙️`
	milestoneFrame.Visible = true
	Theme.pop(milestoneFrame)
	task.delay(4.5, function()
		milestoneFrame.Visible = false
	end)
end

-- The late-join card: where the crew is and what it's doing.
function HudController.summary(s)
	local old = gui:FindFirstChild("Summary")
	if old then
		old:Destroy()
	end
	local card = Theme.slab({
		Name = "Summary",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(420, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.08,
		ZIndex = 20,
		Parent = gui,
	})
	Theme.padding(16, 14).Parent = card
	Theme.list("y", 6).Parent = card
	Theme.title({
		Text = "Welcome aboard",
		Size = UDim2.new(1, 0, 0, 30),
		TextColor3 = C.amber,
		ZIndex = 21,
		LayoutOrder = 1,
		Parent = card,
	})
	local where = s.stop and `At {s.stop}` or s.nextStop and `On the line · next stop: {s.nextStop}` or "On the line"
	local lines = {
		`🚂  Expedition #{s.code or "?"} · {where}`,
		`📏  {Formulas.round1(s.distance or 0)} km so far · next milestone {s.nextMilestone or "?"} km`,
		`⛽  Fuel {s.fuel or 0} · the next trip needs {s.cost or "?"}`,
		s.goal and `🎯  The crew is working on: {s.goal}` or nil,
		s.timeLeft and s.stop and `⏱  The doors close in {Format.time(s.timeLeft)}: you can still go out!` or nil,
		`👥  {s.crew or 1} aboard. Your cabin is yours: tap CABIN to go there.`,
	}
	for i, line in lines do
		Theme.text({
			Text = line,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextSize = 15,
			ZIndex = 21,
			LayoutOrder = 1 + i,
			Parent = card,
		})
	end
	local ok = Theme.button({
		Name = "GotIt",
		Text = "Got it",
		Size = UDim2.new(1, 0, 0, 40),
		ZIndex = 21,
		LayoutOrder = 20,
		Parent = card,
	})
	ok.Activated:Connect(function()
		card:Destroy()
	end)
	Theme.pop(card)
	task.delay(14, function()
		if card.Parent then
			card:Destroy()
		end
	end)
	return card
end

-- Building the screen --------------------------------------------------------------------------------------------
local function buildBoard()
	board = Theme.slab({
		Name = "Board",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(360, 84),
		BackgroundColor3 = C.ink,
		BackgroundTransparency = 0.12,
		Parent = gui,
	})
	headline = Theme.title({
		Name = "Headline",
		Text = "The Last Train",
		Size = UDim2.new(1, -20, 0, 18),
		Position = UDim2.fromOffset(10, 6),
		TextColor3 = C.amber,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = board,
	})
	timer = Theme.title({
		Name = "Timer",
		Text = "Boarding",
		Size = UDim2.new(1, -20, 0, 34),
		Position = UDim2.fromOffset(10, 23),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = board,
	})
	info = Theme.text({
		Name = "Info",
		Text = "",
		Size = UDim2.new(1, -20, 0, 16),
		Position = UDim2.fromOffset(10, 59),
		TextColor3 = C.muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = board,
	})
	local barFrame
	barFrame, phaseBar =
		Theme.bar({ Name = "PhaseBar", Size = UDim2.new(1, -24, 0, 3), Position = UDim2.new(0, 12, 1, -6) }, C.amber)
	barFrame.Parent = board
end

local function buildBag()
	bagFrame = Theme.slab({
		Name = "Bag",
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.fromOffset(214, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.ink,
		BackgroundTransparency = 0.18,
		Parent = gui,
	})
	Theme.padding(10, 6).Parent = bagFrame
	Theme.list("y", 3).Parent = bagFrame
	bagTitle = Theme.title({
		Name = "Title",
		Text = "🎒 Bag 0/12",
		Size = UDim2.new(1, 0, 0, 18),
		TextColor3 = C.amber,
		LayoutOrder = 1,
		Parent = bagFrame,
	})
	bagItems = Theme.text({
		Name = "Items",
		Text = "empty",
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = 15,
		LayoutOrder = 2,
		Parent = bagFrame,
	})
	bagHint = Theme.text({
		Name = "Hint",
		Text = "Not saved until you're back aboard",
		Size = UDim2.new(1, 0, 0, 14),
		TextSize = 12,
		TextColor3 = C.warn,
		Visible = false,
		LayoutOrder = 3,
		Parent = bagFrame,
	})
	storageLine = Theme.text({
		Name = "Storage",
		Text = "",
		Size = UDim2.new(1, 0, 0, 16),
		TextSize = 13,
		TextColor3 = C.muted,
		LayoutOrder = 4,
		Parent = bagFrame,
	})

	goalFrame = Theme.slab({
		Name = "Goal",
		Position = UDim2.fromOffset(8, 112),
		Size = UDim2.fromOffset(214, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.ink,
		BackgroundTransparency = 0.18,
		Visible = false,
		Parent = gui,
	})
	Theme.padding(10, 6).Parent = goalFrame
	Theme.list("y", 4).Parent = goalFrame
	Theme.title({
		Name = "Title",
		Text = "Crew goal",
		Size = UDim2.new(1, 0, 0, 15),
		TextColor3 = C.amber,
		LayoutOrder = 1,
		Parent = goalFrame,
	})
	goalText = Theme.text({
		Name = "Text",
		Text = "",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 13,
		LayoutOrder = 2,
		Parent = goalFrame,
	})
	local bar
	bar, goalFill = Theme.bar({ Name = "Bar", Size = UDim2.new(1, 0, 0, 6), LayoutOrder = 3 }, C.amber)
	bar.Parent = goalFrame
end

local BUTTONS = {
	{ key = "cabin", icon = "🚪", label = "Cabin" },
	{ key = "build", icon = "🛠️", label = "Build" },
	{ key = "train", icon = "⚙️", label = "Train" },
	{ key = "friends", icon = "👋", label = "Friends" },
	{ key = "hall", icon = "🏆", label = "Hall" },
}

local function buildButtons()
	local column = new("Frame", {
		Name = "Buttons",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 96),
		Size = UDim2.fromOffset(62, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Theme.list("y", 7, Enum.HorizontalAlignment.Center).Parent = column
	for i, b in BUTTONS do
		local button, dot = Theme.iconButton({
			Name = b.key,
			icon = b.icon,
			label = b.label,
			Size = UDim2.fromOffset(60, 60),
			LayoutOrder = i,
			Parent = column,
		})
		buttons[b.key] = button
		dots[b.key] = dot
		button.Activated:Connect(function()
			if b.key == "cabin" then
				Net.send("GoCabin")
			else
				panels().toggle(b.key)
			end
		end)
	end
	Theme.keyHint(buttons.build, "B", "")
	Theme.keyHint(buttons.train, "T", "")
	Theme.keyHint(buttons.cabin, "C", "")
end

local function buildOverlays()
	toastHolder = new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -118),
		Size = UDim2.fromOffset(470, 120),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local tl = Theme.list("y", 5, Enum.HorizontalAlignment.Center)
	tl.VerticalAlignment = Enum.VerticalAlignment.Bottom
	tl.Parent = toastHolder

	announceFrame = Theme.slab({
		Name = "Announce",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 96),
		Size = UDim2.fromOffset(520, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.black,
		BackgroundTransparency = 0.35,
		Visible = false,
		Parent = gui,
	})
	announceFrame.UIStroke.Transparency = 0.8
	Theme.padding(12, 6).Parent = announceFrame
	announceText = Theme.text({
		Name = "Text",
		Text = "",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = announceFrame,
	})

	alertFrame = new("Frame", {
		Name = "Alert",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(640, 70),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	alertText = Theme.title({
		Name = "Text",
		Text = "",
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		outline = 2,
		Parent = alertFrame,
	})

	milestoneFrame = new("Frame", {
		Name = "Milestone",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromOffset(520, 110),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	Theme.title({
		Name = "Big",
		Text = "10 KM",
		Size = UDim2.new(1, 0, 0, 74),
		TextColor3 = C.amber,
		TextXAlignment = Enum.TextXAlignment.Center,
		outline = 2.5,
		Parent = milestoneFrame,
	})
	Theme.title({
		Name = "Small",
		Text = "",
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.fromOffset(0, 78),
		TextXAlignment = Enum.TextXAlignment.Center,
		outline = 1.5,
		Parent = milestoneFrame,
	})

	-- red edges on the final call while you're still outside
	edges = new(
		"Frame",
		{ Name = "Edges", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = gui }
	)
	for _, e in
		{
			{ UDim2.new(1, 0, 0, 24), UDim2.fromScale(0, 0), 90 },
			{ UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 1, -24), 270 },
			{ UDim2.new(0, 24, 1, 0), UDim2.fromScale(0, 0), 0 },
			{ UDim2.new(0, 24, 1, 0), UDim2.new(1, -24, 0, 0), 180 },
		}
	do
		local f = new(
			"Frame",
			{ Size = e[1], Position = e[2], BackgroundColor3 = C.bad, BorderSizePixel = 0, Parent = edges }
		)
		new("UIGradient", { Rotation = e[3], Transparency = NumberSequence.new(0.2, 1), Parent = f })
	end

	local fadeGui = Theme.screen("Fade", 50, player.PlayerGui)
	fadeGui.IgnoreGuiInset = true
	fadeFrame = new("Frame", {
		Name = "Black",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.black,
		BackgroundTransparency = 1,
		Visible = false,
		Parent = fadeGui,
	})
	fadeText = Theme.title({
		Name = "Text",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(600, 40),
		TextColor3 = C.cream,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = fadeFrame,
	})
end

-- Updating ------------------------------------------------------------------------------------------------------
local function chips(items, plans)
	local parts = {}
	for _, key in Resources.MATERIALS do
		local n = items and items[key]
		if n and n > 0 then
			table.insert(parts, `{Resources.byKey[key].icon} {n}`)
		end
	end
	if items and (items.fuel or 0) > 0 then
		table.insert(parts, `{Resources.FUEL.icon} {items.fuel}`)
	end
	for key, n in plans or {} do
		if n > 0 then
			local bp = Resources.BLUEPRINTS[key]
			table.insert(parts, `{bp and bp.icon or "📜"} {n}`)
		end
	end
	return parts
end

function HudController.refreshBag()
	local bag = Store.state.bag or {}
	local count, cap = bag.count or 0, bag.cap or Constants.BAG_BASE
	bagTitle.Text = string.upper(`🎒 Bag {count}/{cap}`) .. (count >= cap and "  · FULL" or "")
	bagTitle.TextColor3 = count >= cap and C.warn or C.amber
	local parts = chips(bag.items, bag.plans)
	bagItems.Text = #parts > 0 and table.concat(parts, "   ") or "empty"
	bagItems.TextColor3 = #parts > 0 and C.cream or C.muted
	local aboard = inTrain()
	bagHint.Visible = count > 0 and not aboard
	local storage = Store.state.storage
	if storage then
		local s = {}
		for _, key in Resources.MATERIALS do
			table.insert(s, `{Resources.byKey[key].icon}{storage[key] or 0}`)
		end
		local plans = 0
		for _, n in Store.state.blueprints or {} do
			plans += n
		end
		if plans > 0 then
			table.insert(s, `📜{plans}`)
		end
		storageLine.Text = "Stored  " .. table.concat(s, "  ")
	end
end

-- The BUILD dot: the next cabin upgrade is affordable. The TRAIN dot: you have something the next stage needs.
function HudController.refreshDots()
	local built = Store.state.cabin and Store.state.cabin.built or {}
	local storage = Store.state.storage or {}
	local blueprints = Store.state.blueprints or {}
	local nextItem = Formulas.nextCabinItem(built)
	dots.build.Visible = nextItem ~= nil and Formulas.canBuild(nextItem, built, storage, blueprints) == true
	local trainDot = false
	local tv = Store.state.train
	for _, u in tv and tv.upgrades or {} do
		for res, n in u.missing or {} do
			if res == "plans" then
				local def = TrainUpgrades.byKey[u.key]
				local stage = def and def.stages[(u.stage or 0) + 1]
				if stage and stage.plans and (blueprints[stage.plans] or 0) > 0 then
					trainDot = true
				end
			elseif n > 0 and (storage[res] or 0) > 0 then
				trainDot = true
			end
		end
	end
	dots.train.Visible = trainDot
	buttons.hall.Visible = Store.phase() == "lobby" or (Store.state.hall ~= nil and #Store.state.hall.records > 0)
end

local function refreshGoal()
	local e = Store.state.expedition
	local goal = e and e.goal
	goalFrame.Visible = goal ~= nil and not Store.state.recovery
	if goal then
		goalText.Text = goal.text
		goalFill.Size = UDim2.fromScale(math.clamp(goal.progress or 0, 0.02, 1), 1)
		goalFill.BackgroundColor3 = goal.key == "fuel" and C.fuel or C.amber
		goalFrame.Title.Text = goal.key == "fuel" and "⛽ CREW NEEDS FUEL" or "CREW GOAL · TRAIN UPGRADE"
	end
end

local function boardText()
	local e = Store.state.expedition or {}
	local phase = Store.phase()
	local final = workspace:GetAttribute("Final") == true
	local left = Store.timeLeft()
	local km = Formulas.round1(Store.distance())
	local head = PHASE_TEXT[phase] or ""
	local big = left and Format.time(left) or ""
	local color, headColor = C.cream, C.amber
	if phase == "lobby" then
		if not left then
			head, big = `The Last Train · {e.region or "Overgrown Line"}`, "Boarding"
		end
	elseif phase == "traveling" then
		local nextStop = e.nextStop
		big = nextStop and string.upper(nextStop.name) or "· · ·"
		head = nextStop and "Next stop" or "On the line"
	elseif phase == "arriving" then
		big = e.nextStop and string.upper(e.nextStop.name) or (e.stop and string.upper(e.stop.name) or "")
	elseif phase == "scavenging" then
		head = e.stop and `{e.stop.name} · doors close in` or "Doors close in"
	elseif phase == "warning" then
		headColor = final and C.bad or C.warn
		color = final and C.bad or C.warn
		head = final and "Final call! Get aboard!" or "Train leaving soon!"
	elseif phase == "departing" then
		headColor, color = C.bad, C.bad
		head = e.stop and "Doors closing!" or "All aboard!"
	elseif phase == "ended" then
		big = `{km} KM`
		head = "Out of fuel · back to the station"
	end
	local infoText =
		`🚂 {km} km   ·   🏁 {Formulas.nextMilestone(Store.distance())} km   ·   ⛽ {e.fuel or 0} / trip {e.cost or "?"}`
	return head, big, infoText, color, headColor
end

local function refreshBoard()
	local head, big, infoText, color, headColor = boardText()
	headline.Text = string.upper(head)
	headline.TextColor3 = headColor
	timer.Text = string.upper(big)
	timer.TextColor3 = color
	info.Text = infoText
	-- how much of the phase is gone
	local e = Store.state.expedition
	local ends = workspace:GetAttribute("PhaseEnds")
	local started = workspace:GetAttribute("PhaseStarted")
	if type(ends) == "number" and ends > 0 and type(started) == "number" and ends > started then
		local t = math.clamp((workspace:GetServerTimeNow() - started) / (ends - started), 0, 1)
		if Store.phase() == "warning" and e and e.phaseStarted then
			t = math.clamp(1 - (ends - workspace:GetServerTimeNow()) / Constants.WARNING_AT, 0, 1)
		end
		phaseBar.Size = UDim2.fromScale(math.max(t, 0.01), 1)
		phaseBar.BackgroundColor3 = color == C.cream and C.amber or color
	else
		phaseBar.Size = UDim2.fromScale(0, 1)
	end
	board.Visible = not Store.state.recovery
end

-- The way back: a glowing line to the nearest open door while you're outside and the train is about to go.
local function refreshGuide()
	local phase = Store.phase()
	local aboard, hrp = inTrain()
	local leaving = phase == "warning" or (phase == "departing" and workspace:GetAttribute("Doors") ~= "closed")
	local show = leaving
		and hrp ~= nil
		and not aboard
		and not Store.state.recovery
		and Store.state.expedition
		and Store.state.expedition.stop ~= nil
	edges.Visible = show and (workspace:GetAttribute("Final") == true or phase == "departing")
	if not show then
		if guideBeam then
			guideBeam.Enabled = false
		end
		return
	end
	local best, bestD
	for _, d in Layout.doors do
		local dist = (d.cf.Position - hrp.Position).Magnitude
		if not bestD or dist < bestD then
			best, bestD = d, dist
		end
	end
	if not guideAnchor then
		guideAnchor = new("Part", {
			Name = "DoorGuide",
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Transparency = 1,
			Size = Vector3.new(0.2, 0.2, 0.2),
			Parent = workspace,
		})
		local a1 = new("Attachment", { Name = "Door", Parent = guideAnchor })
		guideBeam = new("Beam", {
			Name = "DoorBeam",
			Attachment1 = a1,
			Color = ColorSequence.new(C.amber, C.good),
			Width0 = 0.5,
			Width1 = 0.5,
			FaceCamera = true,
			LightEmission = 1,
			Transparency = NumberSequence.new(0.15),
			TextureSpeed = 2,
			Parent = guideAnchor,
		})
	end
	guideAnchor.CFrame = CFrame.new(best.cf.Position - Vector3.new(0, 3, -1.5))
	local a0 = hrp:FindFirstChild("GuideFrom")
		or new("Attachment", { Name = "GuideFrom", Position = Vector3.new(0, -1.5, 0), Parent = hrp })
	guideBeam.Attachment0 = a0
	guideBeam.Enabled = true
end

function HudController:init()
	gui = Theme.screen("Hud", 10, player:WaitForChild("PlayerGui"))
	HudController.gui = gui
	buildBoard()
	buildBag()
	buildButtons()
	buildOverlays()
	HudController.buttons = buttons
	HudController.dots = dots

	Net.listen("Toast", function(text, kind)
		HudController.toast(text, kind)
	end)
	Net.listen("Announce", function(text, kind)
		HudController.announce(text, kind)
	end)
	Net.listen("Alert", function(text, color)
		HudController.alert(text, color)
	end)
	Net.listen("Popup", function(position, text, color)
		HudController.popup(position, text, color)
	end)
	Net.listen("Fade", function(seconds, text)
		HudController.fade(seconds, text)
	end)
	Net.listen("Milestone", function(m)
		if type(m) == "table" and m.km then
			HudController.milestone(m.km)
		end
	end)
	Net.listen("Summary", function(s)
		if type(s) == "table" then
			HudController.summary(s)
		end
	end)
	Store.Changed:Connect(function(partial)
		if partial.bag or partial.storage or partial.blueprints then
			HudController.refreshBag()
		end
		if partial.expedition or partial.recovery ~= nil then
			refreshGoal()
		end
		if
			partial.storage
			or partial.blueprints
			or partial.cabin
			or partial.train
			or partial.hall
			or partial.expedition
		then
			HudController.refreshDots()
		end
	end)
	HudController.refreshBag()
	HudController.refreshDots()
	refreshGoal()
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if acc < 0.2 then
			return
		end
		acc = 0
		refreshBoard()
		refreshGuide()
		bagHint.Visible = (Store.state.bag and Store.state.bag.count or 0) > 0 and not inTrain()
	end)
	refreshBoard()
	_ = CabinItems
end

return HudController
