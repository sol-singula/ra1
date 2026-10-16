--[[
The HUD (master plan §1, §2, §5, §7): everything on screen, in the SUPERHOT look (white, black, red, blue).

  top        the phase and its clock (BUILD 0:42 / FIGHT 1:13), the frontline bar (red | blue, the line marked, how
             far each team is from losing), the map's name, the team counts
  centre     the crosshair, the bow's charge under it, hit markers (white; red for a kill), the big alerts
             (BUILD, FIGHT!, RED WINS), the respawn countdown
  top right  the kill feed: who, with what, how far the line moved
  bottom     health (left), the bows (right: 1 2 3, the crossbow's bolts), the build tray in the build phase
             (seven pieces with their costs, your points), toasts
  touch      FIRE (hold to draw), SPRINT, SLIDE; PLACE and ROTATE while building
  overlays   the results (who won, the table, the MVP, your reward, the next map); unlock and thank-you cards
             stack down the right, under the kill feed

Nothing overlaps on the smallest canvas the screens get (Theme.MIN_WIDTH x DESIGN.Y, 1240 x 560): every piece
has its own slot, the words inside cards shrink to fit their boxes (Theme.text fit), the toast moves up out of
the way of the build tray and of a question card, and ClientSmoke checks the rectangles.

The objective is on screen in the first seconds (§1: understood in under 15 s): "Every kill pushes the line toward
their base. Push them off the map."
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Structures = require(ReplicatedStorage.Shared.Data.Structures)
local Weapons = require(ReplicatedStorage.Shared.Data.Weapons)
local Bus = require(script.Parent.Parent.UI.Bus)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)
local Layout = require(script.Parent.Parent.UI.Layout)
local BuildController = require(script.Parent.BuildController)

local HudController = { Name = "HudController", Order = 40 }

local C = Theme.Color
local RED, BLUE = Constants.TEAM_COLOR.red, Constants.TEAM_COLOR.blue
local player = Players.LocalPlayer
local refs = {}
HudController.refs = refs
local feed = {}
local hitUntil = 0
local FEED_W = 300 -- (clear of the 560-wide top bar on a 1240 canvas)
-- the popup stack (unlocks, thank-yous): down the right under the kill feed, two at a time, clear of the touch
-- buttons below
local STACK = { top = 176, w = 300, h = 64, gap = 8, max = 2 }
-- where the toast sits (its bottom, up from the screen's bottom): normally, in the build phase (above the tray's
-- hint), and while a question card is up (between the results card and it)
local TOAST_UP = { normal = 132, build = 150, modal = 166 }
local RESULT_ROWS = 5 -- (the results card ends above the question card)

local function now()
	return workspace:GetServerTimeNow()
end

local function clock(seconds)
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function label(props)
	props.TextColor3 = props.TextColor3 or C.ink
	return Theme.text(props)
end

-- The top: phase, clock, the frontline bar ---------------------------------------------------------------------
local function buildTop(gui)
	local top = Theme.new("Frame", {
		Name = "Top",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(560, 74),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local pill = Theme.new("Frame", {
		Name = "Phase",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(190, 32),
		BackgroundColor3 = C.ink,
		BorderSizePixel = 0,
		Parent = top,
	}, { Theme.corner(4) })
	refs.phase = Theme.title({
		Name = "Text",
		Text = "BUILD 1:00",
		Size = UDim2.new(1, 0, 1, -4),
		Position = UDim2.fromOffset(0, 2),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.white,
		outline = false,
		Parent = pill,
	})
	refs.phasePill = pill
	-- the bar: red from the left to the line, blue after it
	local bar = Theme.new("Frame", {
		Name = "Frontline",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 38),
		Size = UDim2.fromOffset(520, 16),
		BackgroundColor3 = BLUE,
		BorderSizePixel = 0,
		Parent = top,
	}, { Theme.corner(3), Theme.stroke(2, C.ink) })
	refs.redFill = Theme.new("Frame", {
		Name = "Red",
		Size = UDim2.new(0.5, 0, 1, 0),
		BackgroundColor3 = RED,
		BorderSizePixel = 0,
		Parent = bar,
	}, { Theme.corner(3) })
	refs.lineMark = Theme.new("Frame", {
		Name = "Line",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 4, 1, 10),
		BackgroundColor3 = C.white,
		BorderSizePixel = 0,
		Parent = bar,
	}, { Theme.stroke(1.5, C.ink) })
	refs.redCount = label({
		Name = "RedCount",
		Text = "RED 0",
		Size = UDim2.fromOffset(110, 18),
		Position = UDim2.new(0, -2, 1, 2),
		TextSize = 13,
		TextColor3 = RED,
		Font = Theme.Display,
		Parent = bar,
	})
	refs.blueCount = label({
		Name = "BlueCount",
		Text = "BLUE 0",
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(110, 18),
		Position = UDim2.new(1, 2, 1, 2),
		TextSize = 13,
		TextColor3 = BLUE,
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Theme.Display,
		Parent = bar,
	})
	refs.mapName = label({
		Name = "Map",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(260, 18),
		Position = UDim2.new(0.5, 0, 1, 2),
		TextSize = 12,
		TextColor3 = C.muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = bar,
	})
end

function HudController.updateTop()
	local m = Store.get("match") or {}
	local phase = m.phase or "loading"
	local left = (m.ends or now()) - now()
	local names = { build = "BUILD", fight = "FIGHT", victory = "NEXT GAME", loading = "NEXT MAP" }
	if refs.phase then
		refs.phase.Text = (names[phase] or "")
			.. ((phase == "build" or phase == "fight" or phase == "victory") and (" " .. clock(left)) or "")
		refs.phasePill.BackgroundColor3 = phase == "fight" and C.ink or Color3.fromRGB(70, 70, 78)
	end
	local lo, hi = m.loseRed or -80, m.loseBlue or 80
	local f = math.clamp(((m.frontline or 0) - lo) / math.max(1, hi - lo), 0, 1)
	if refs.redFill then
		refs.redFill.Size = UDim2.new(f, 0, 1, 0)
		refs.lineMark.Position = UDim2.new(f, 0, 0.5, 0)
		refs.redCount.Text = `RED {m.red or 0}`
		refs.blueCount.Text = `BLUE {m.blue or 0}`
		refs.mapName.Text = string.upper(m.mapName or "")
	end
end

-- The centre: crosshair, charge, hit markers, alerts -----------------------------------------------------------
local function buildCentre(gui)
	local cross = Theme.new("Frame", {
		Name = "Crosshair",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(40, 40),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	for _, spec in { { 0, -12, 2, 8 }, { 0, 12, 2, 8 }, { -12, 0, 8, 2 }, { 12, 0, 8, 2 } } do
		Theme.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, spec[1], 0.5, spec[2]),
			Size = UDim2.fromOffset(spec[3], spec[4]),
			BackgroundColor3 = C.ink,
			BorderSizePixel = 0,
			Parent = cross,
		})
	end
	Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(3, 3),
		BackgroundColor3 = RED,
		BorderSizePixel = 0,
		Parent = cross,
	})
	refs.cross = cross
	local charge = Theme.new("Frame", {
		Name = "Charge",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 26),
		Size = UDim2.fromOffset(60, 5),
		BackgroundColor3 = Color3.fromRGB(210, 210, 214),
		BorderSizePixel = 0,
		Visible = false,
		Parent = gui,
	}, { Theme.corner(2) })
	refs.chargeFill = Theme.new("Frame", {
		Name = "Fill",
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = C.ink,
		BorderSizePixel = 0,
		Parent = charge,
	}, { Theme.corner(2) })
	refs.charge = charge
	local hit = Theme.new("Frame", {
		Name = "Hit",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(34, 34),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	refs.hitLines = {}
	for _, r in { 45, -45, 135, -135 } do
		local l = Theme.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, math.cos(math.rad(r)) * 12, 0.5, math.sin(math.rad(r)) * 12),
			Size = UDim2.fromOffset(9, 3),
			Rotation = r,
			BackgroundColor3 = C.ink,
			BorderSizePixel = 0,
			Parent = hit,
		})
		table.insert(refs.hitLines, l)
	end
	refs.hit = hit
	refs.alert = Theme.title({
		Name = "Alert",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.32),
		Size = UDim2.fromOffset(560, 90),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.ink,
		outline = false,
		Visible = false,
		Parent = gui,
	})
	refs.objective = label({
		Name = "Objective",
		Text = "Every kill pushes the line toward their base. Push them off the map.",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 108),
		Size = UDim2.fromOffset(600, 22),
		fit = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = gui,
	})
	-- the countdown to the next game, big, once the results card has gone
	refs.countdown = Theme.title({
		Name = "Countdown",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(600, 70),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.ink,
		outline = false,
		Visible = false,
		Parent = gui,
	})
	refs.respawn = Theme.title({
		Name = "Respawn",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.6),
		Size = UDim2.fromOffset(400, 40),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = RED,
		outline = false,
		Visible = false,
		Parent = gui,
	})
	refs.flash = Theme.new("Frame", {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = RED,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 0,
		Parent = gui,
	})
end

function HudController.alert(text, color, seconds)
	local a = refs.alert
	if not a then
		return
	end
	a.Text = string.upper(text or "")
	a.TextColor3 = color or C.ink
	a.Visible = true
	Theme.pop(a)
	local token = {}
	refs.alertToken = token
	task.delay(seconds or 1.5, function()
		if refs.alertToken == token then
			a.Visible = false
		end
	end)
end

function HudController.hitMarker(kill, head)
	hitUntil = os.clock() + (kill and 0.45 or 0.2)
	for _, l in refs.hitLines or {} do
		l.BackgroundColor3 = kill and RED or (head and C.ink or Color3.fromRGB(60, 60, 66))
		l.Size = UDim2.fromOffset(kill and 13 or 9, 3)
	end
end

-- The kill feed ------------------------------------------------------------------------------------------------
local function buildFeed(gui)
	refs.feed = Theme.new("Frame", {
		Name = "Feed",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(FEED_W, 150),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Theme.new("UIListLayout", { Padding = UDim.new(0, 3), HorizontalAlignment = Enum.HorizontalAlignment.Right }),
	})
end

function HudController.addFeed(k)
	if not refs.feed then
		return
	end
	local icon = (Weapons.get(k.weapon or "") or {}).icon or "✖"
	local killer = k.killerName or ({ fall = "the void", reset = "reset" })[k.kind] or "?"
	local row = Theme.new("Frame", {
		Size = UDim2.fromOffset(FEED_W, 22),
		BackgroundColor3 = C.white,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Parent = refs.feed,
	}, { Theme.corner(3) })
	local text = `{killer}  {icon}{k.head and " 🎯" or ""}  {k.victimName or "?"}`
	if (k.push or 0) > 0 then
		text ..= `   +{math.floor(k.push / Constants.CELL)}`
	end
	label({
		Text = text,
		Size = UDim2.new(1, -10, 1, 0),
		Position = UDim2.fromOffset(5, 0),
		fit = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Constants.TEAM_COLOR[k.killerTeam or ""] or C.ink,
		Parent = row,
	})
	table.insert(feed, row)
	while #feed > 5 do
		table.remove(feed, 1):Destroy()
	end
	task.delay(7, function()
		local i = table.find(feed, row)
		if i then
			table.remove(feed, i)
			row:Destroy()
		end
	end)
end

-- The bottom: health, weapons, the build tray, toasts ----------------------------------------------------------
local function buildBottom(gui)
	local hp = Theme.new("Frame", {
		Name = "Health",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.fromOffset(230, 18),
		BackgroundColor3 = Color3.fromRGB(220, 220, 224),
		BorderSizePixel = 0,
		Parent = gui,
	}, { Theme.corner(3), Theme.stroke(2, C.ink) })
	refs.hpFill = Theme.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.ink,
		BorderSizePixel = 0,
		Parent = hp,
	}, { Theme.corner(3) })
	refs.team = Theme.title({
		Name = "Team",
		Text = "",
		Size = UDim2.fromOffset(230, 22),
		Position = UDim2.fromOffset(0, -26),
		TextColor3 = RED,
		outline = false,
		Parent = hp,
	})
	-- the bows: three buttons (1 2 3)
	local bows = Theme.new("Frame", {
		Name = "Bows",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(3 * 82, 64),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	refs.bows = {}
	for i, w in Weapons.list do
		local b = Theme.new("TextButton", {
			Name = "Bow_" .. w.key,
			Position = UDim2.fromOffset((i - 1) * 82, 0),
			Size = UDim2.fromOffset(76, 64),
			BackgroundColor3 = C.white,
			Text = "",
			AutoButtonColor = false,
			Parent = bows,
		}, { Theme.corner(4), Theme.stroke(2, C.ink) })
		label({
			Text = w.icon,
			Size = UDim2.new(1, 0, 0, 28),
			Position = UDim2.fromOffset(0, 4),
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = b,
		})
		label({
			Name = "Name",
			Text = `{i}  {({ bow = "BOW", crossbow = "CROSSBOW", heavy = "HEAVY" })[w.key] or string.upper(w.name)}`,
			Size = UDim2.new(1, -4, 0, 14),
			Position = UDim2.fromOffset(2, 32),
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Center,
			Font = Theme.Display,
			Parent = b,
		})
		local ammo = label({
			Name = "Ammo",
			Text = "",
			Size = UDim2.new(1, 0, 0, 14),
			Position = UDim2.fromOffset(0, 46),
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = b,
		})
		b.Activated:Connect(function()
			Bus.Weapon:Fire(w.key)
		end)
		refs.bows[w.key] = { button = b, ammo = ammo }
	end
	-- the build tray
	local tray = Theme.new("Frame", {
		Name = "BuildTray",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(#Structures.list * 74 + 6, 106),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	refs.budget = Theme.title({
		Name = "Budget",
		Text = "",
		Size = UDim2.new(1, 0, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.ink,
		outline = false,
		Parent = tray,
	})
	refs.trayButtons = {}
	for i, s in Structures.list do
		local b = Theme.new("TextButton", {
			Name = "Piece_" .. s.key,
			Position = UDim2.fromOffset(3 + (i - 1) * 74, 26),
			Size = UDim2.fromOffset(70, 70),
			BackgroundColor3 = C.white,
			Text = "",
			AutoButtonColor = false,
			Parent = tray,
		}, { Theme.corner(4), Theme.stroke(2, C.ink) })
		label({
			Text = s.icon,
			Size = UDim2.new(1, 0, 0, 26),
			Position = UDim2.fromOffset(0, 4),
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = b,
		})
		label({
			Text = `{i} {string.upper(s.name)}`,
			Size = UDim2.new(1, -4, 0, 24),
			Position = UDim2.fromOffset(2, 30),
			TextSize = 9,
			TextXAlignment = Enum.TextXAlignment.Center,
			Font = Theme.Display,
			Parent = b,
		})
		label({
			Name = "Cost",
			Text = tostring(s.cost),
			Size = UDim2.new(1, 0, 0, 14),
			Position = UDim2.fromOffset(0, 54),
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = b,
		})
		b.Activated:Connect(function()
			BuildController.pick(s.key)
		end)
		refs.trayButtons[s.key] = b
	end
	refs.tray = tray
	refs.buildHint = label({
		Name = "Hint",
		Text = "Click to place · R rotate · Q cancel",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(420, 18),
		Position = UDim2.new(0.5, 0, 0, -2),
		TextSize = 12,
		TextColor3 = C.muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = tray,
	})
	refs.toast = label({
		Name = "Toast",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -TOAST_UP.normal),
		Size = UDim2.fromOffset(600, 24),
		fit = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		Parent = gui,
	})
end

function HudController.toast(text, kind)
	local t = refs.toast
	if not t then
		return
	end
	t.Text = text
	t.TextColor3 = kind == "bad" and RED or C.ink
	t.Visible = true
	local token = {}
	refs.toastToken = token
	task.delay(3, function()
		if refs.toastToken == token then
			t.Visible = false
		end
	end)
end

function HudController.updateBottom()
	local me = Store.get("me") or {}
	local m = Store.get("match") or {}
	if refs.hpFill then
		refs.hpFill.Size = UDim2.fromScale(math.clamp((me.hp or 0) / Constants.MAX_HEALTH, 0, 1), 1)
		local team = me.team
		refs.team.Text = team and (`TEAM {Constants.TEAM_NAME[team]}` .. (me.protected and "  ·  PROTECTED" or ""))
			or ""
		refs.team.TextColor3 = Constants.TEAM_COLOR[team or ""] or C.ink
		refs.hpFill.BackgroundColor3 = Constants.TEAM_COLOR[team or ""] or C.ink
	end
	for key, b in refs.bows or {} do
		local on = me.weapon == key
		b.button.BackgroundColor3 = on and C.ink or C.white
		for _, d in b.button:GetChildren() do
			if d:IsA("TextLabel") then
				d.TextColor3 = on and C.white or C.ink
			end
		end
		local w = Weapons.get(key)
		b.ammo.Text = (w.mag and on) and `{me.ammo or 0}/{w.mag}` or ""
	end
	local building = m.phase == "build"
	if refs.tray then
		refs.tray.Visible = building
		refs.budget.Text = `BUILD POINTS  {me.budget or 0} / {me.budgetMax or Constants.BUILD_BUDGET}`
		local picked = BuildController.picked()
		for key, b in refs.trayButtons do
			local s = Structures.get(key)
			local afford = (me.budget or 0) >= s.cost
			b.BackgroundColor3 = picked == key and C.ink or (afford and C.white or Color3.fromRGB(225, 225, 228))
			for _, d in b:GetChildren() do
				if d:IsA("TextLabel") then
					d.TextColor3 = picked == key and C.white or (afford and C.ink or C.muted)
				end
			end
		end
		local spot = BuildController.spot()
		refs.buildHint.Text = (picked and spot and not spot.ok and spot.why) or "Click to place · R rotate · Q cancel"
		refs.buildHint.TextColor3 = (picked and spot and not spot.ok) and RED or C.muted
	end
	if refs.bows then
		refs.bows.bow.button.Parent.Visible = not building
	end
end

-- Touch controls -----------------------------------------------------------------------------------------------
local function buildTouch(gui)
	if not Theme.isTouch() then
		return
	end
	local function button(name, text, pos, size, color)
		return Theme.new("TextButton", {
			Name = name,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = pos,
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = color or C.white,
			BackgroundTransparency = 0.1,
			Text = text,
			Font = Theme.Display,
			TextSize = 14,
			TextColor3 = color and C.white or C.ink,
			AutoButtonColor = false,
			Parent = gui,
		}, { Theme.corner("round"), Theme.stroke(2, C.ink) })
	end
	local fire = button("Fire", "FIRE", UDim2.new(1, -110, 1, -150), 104, C.ink)
	fire.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			Bus.Fire:Fire(true)
		end
	end)
	fire.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			Bus.Fire:Fire(false)
		end
	end)
	local sprintOn = false
	-- (each clear of the others and of the bows panel along the bottom right)
	local sprint = button("Sprint", "RUN", UDim2.new(1, -220, 1, -130), 64)
	sprint.Activated:Connect(function()
		sprintOn = not sprintOn
		sprint.BackgroundColor3 = sprintOn and C.ink or C.white
		sprint.TextColor3 = sprintOn and C.white or C.ink
		Bus.Sprint:Fire(sprintOn)
	end)
	button("Slide", "SLIDE", UDim2.new(1, -210, 1, -205), 58).Activated:Connect(function()
		Bus.Slide:Fire()
	end)
	local place = button("Place", "PLACE", UDim2.new(1, -110, 1, -150), 104, C.ink)
	place.Activated:Connect(function()
		Bus.Place:Fire()
	end)
	local rotate = button("Rotate", "TURN", UDim2.new(1, -220, 1, -130), 64)
	rotate.Activated:Connect(function()
		Bus.Rotate:Fire()
	end)
	refs.touch = { fire = fire, place = place, rotate = rotate, sprint = sprint }
end

HudController._buildTouch = buildTouch -- (tests: the touch layout on a desktop run)

local function updateTouch()
	local t = refs.touch
	if not t then
		return
	end
	local building = Store.phase() == "build"
	t.fire.Visible = not building
	t.sprint.Visible = not building or BuildController.picked() == nil
	t.place.Visible = building and BuildController.picked() ~= nil
	t.rotate.Visible = building and BuildController.picked() ~= nil
end

-- Results and unlocks ------------------------------------------------------------------------------------------
function HudController.showResults(r)
	if refs.results then
		refs.results:Destroy()
	end
	local gui = refs.gui
	local winColor = Constants.TEAM_COLOR[r.winner] or C.ink
	-- the top rows, and yours in the last one if you're further down
	local rows = {}
	for i = 1, math.min(RESULT_ROWS, #(r.rows or {})) do
		rows[i] = r.rows[i]
	end
	if #rows == RESULT_ROWS then
		local mine
		for i, row in r.rows do
			if row.userId == player.UserId then
				mine = i
			end
		end
		if mine and mine > RESULT_ROWS then
			rows[RESULT_ROWS] = r.rows[mine]
		end
	end
	local card = Theme.card({
		Name = "Results",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 104),
		-- (only as tall as its rows, under the top bar: the fireworks stay in view above and round it)
		Size = UDim2.fromOffset(520, 150 + #rows * 22),
		BackgroundColor3 = C.white,
		Parent = gui,
	})
	refs.results = card
	Theme.title({
		Text = `{Constants.TEAM_NAME[r.winner] or "?"} WINS`,
		Size = UDim2.new(1, -20, 0, 46),
		Position = UDim2.fromOffset(10, 10),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = winColor,
		outline = false,
		Parent = card,
	})
	local you = r.you or {}
	local line = you.won and "VICTORY" or (you.won == false and "DEFEAT" or "")
	if you.step then
		line ..= `  ·  WIN #{you.step.win}: {you.step.name}`
	elseif you.won and not you.qualified then
		line ..= "  ·  (play a full match for the win to count)"
	end
	label({
		Text = line,
		Size = UDim2.new(1, -20, 0, 20),
		Position = UDim2.fromOffset(10, 62),
		fit = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = card,
	})
	local y = 88
	label({
		Text = "PLAYER                         K     D     A     BUILT",
		Size = UDim2.new(1, -40, 0, 16),
		Position = UDim2.fromOffset(20, y),
		fit = 11,
		TextColor3 = C.muted,
		Font = Theme.Display,
		Parent = card,
	})
	y += 20
	for _, row in rows do
		local mvp = row.userId == r.mvp and "  ★ MVP" or ""
		label({
			Text = string.format(
				"%-24s %4d  %4d  %4d   %5d%s",
				string.sub(row.name or "?", 1, 22),
				row.kills,
				row.deaths,
				row.assists,
				row.built,
				mvp
			),
			Size = UDim2.new(1, -40, 0, 20),
			Position = UDim2.fromOffset(20, y + 1),
			fit = 14,
			TextWrapped = false,
			Font = Enum.Font.Code,
			TextColor3 = Constants.TEAM_COLOR[row.team or ""] or C.ink,
			Parent = card,
		})
		y += 22
	end
	if r.next then
		label({
			Text = `NEXT: {string.upper(r.next.name)}  ·  {r.next.tagline or ""}`,
			AnchorPoint = Vector2.new(0, 1),
			Size = UDim2.new(1, -20, 0, 20),
			Position = UDim2.new(0, 10, 1, -12),
			fit = 13,
			TextXAlignment = Enum.TextXAlignment.Center,
			Font = Theme.Display,
			Parent = card,
		})
	end
	Theme.pop(card)
	task.delay(Constants.RESULTS_CARD_SECONDS, function()
		if refs.results == card then
			card:Destroy()
			refs.results = nil
		end
	end)
end

-- The popup stack: each card in its own slot down the right, the oldest on top; more than fit wait their turn.
local stack = {} -- the cards on screen, in order
local waiting = {} -- { build, seconds }

local function restack()
	for i, card in stack do
		card.Position = UDim2.new(1, -16, 0, STACK.top + (i - 1) * (STACK.h + STACK.gap))
	end
end

local function pushCard(build, seconds)
	if #stack >= STACK.max then
		table.insert(waiting, { build, seconds })
		return nil
	end
	local card = Theme.card({
		Name = "Popup",
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(STACK.w, STACK.h),
		BackgroundColor3 = C.ink,
		Parent = refs.gui,
	})
	build(card)
	table.insert(stack, card)
	restack()
	Theme.pop(card)
	task.delay(seconds, function()
		local i = table.find(stack, card)
		if i then
			table.remove(stack, i)
		end
		card:Destroy()
		restack()
		local nextUp = table.remove(waiting, 1)
		if nextUp then
			pushCard(nextUp[1], nextUp[2])
		end
	end)
	return card
end

-- A small picture of a trail: the team's tracer, and the white line beside it for the Thank-You Trail.
local function trailPreview(card, key)
	local box = Theme.new("Frame", {
		Name = "Preview",
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = C.white,
		BorderSizePixel = 0,
		Parent = card,
	}, { Theme.corner(4) })
	local color = Constants.TEAM_COLOR[Store.team() or ""] or RED
	local function line(y, h, c)
		Theme.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, y),
			Size = UDim2.fromOffset(34, h),
			Rotation = -20,
			BackgroundColor3 = c,
			BorderSizePixel = 0,
			Parent = box,
		})
	end
	if key == "extra_thanks" then
		line(19, 4, color)
		line(27, 2, C.ink) -- (the white line, drawn dark on the white tile so it shows)
	else
		line(22, 4, color)
	end
end

function HudController.showUnlock(u)
	local s = u.step
	if not s then
		return nil
	end
	local head = u.title or (u.wins and `WIN #{u.wins} · NEW {string.upper(s.kind)}` or `NEW {string.upper(s.kind)}`)
	local line = u.extra and `{s.name} · equipped` or (s.name .. (u.badge and `  ·  {u.badge} WINS IN A ROW` or ""))
	return pushCard(function(card)
		card.Name = u.extra and "Thanks" or "Unlock"
		local x = 12
		if s.kind == "trail" then
			trailPreview(card, s.key)
			x = 64
		end
		Theme.title({
			Name = "Head",
			Text = head,
			Size = UDim2.new(1, -x - 12, 0, 24),
			Position = UDim2.fromOffset(x, 8),
			TextColor3 = C.white,
			outline = false,
			Parent = card,
		})
		label({
			Name = "Line",
			Text = line,
			Size = UDim2.new(1, -x - 12, 0, 22),
			Position = UDim2.fromOffset(x, 34),
			fit = 15,
			TextColor3 = C.white,
			Parent = card,
		})
	end, u.extra and 6 or 5)
end

function HudController.popups()
	return stack, waiting
end

-- Where the toast goes now: up out of the way of the build tray, or of a question card.
function HudController.toastSlot()
	if Layout.modalOpen() then
		return TOAST_UP.modal
	end
	return Store.phase() == "build" and TOAST_UP.build or TOAST_UP.normal
end

-- Each frame ---------------------------------------------------------------------------------------------------
local function step()
	if refs.toast then
		refs.toast.Position = UDim2.new(0.5, 0, 1, -HudController.toastSlot())
	end
	HudController.updateTop()
	HudController.updateBottom()
	updateTouch()
	if refs.hit then
		refs.hit.Visible = os.clock() < hitUntil
	end
	local me = Store.get("me") or {}
	local m = Store.get("match") or {}
	if refs.respawn then
		local dead = me.alive == false and (m.phase == "build" or m.phase == "fight")
		refs.respawn.Visible = dead
		refs.respawn.Text = dead and "RESPAWNING…" or ""
	end
	if refs.cross then
		refs.cross.Visible = me.alive ~= false and m.phase ~= "victory"
	end
	if refs.countdown then
		local show = m.phase == "victory" and refs.results == nil
		refs.countdown.Visible = show
		if show then
			local left = math.max(0, math.ceil((m.ends or now()) - now()))
			refs.countdown.Text = `NEXT GAME IN {left}`
			refs.countdown.TextColor3 = Constants.TEAM_COLOR[m.winner or ""] or C.ink
		end
	end
	if refs.flash and refs.flash.BackgroundTransparency < 1 then
		refs.flash.BackgroundTransparency = math.min(1, refs.flash.BackgroundTransparency + 0.04)
	end
	if refs.objective and refs.objectiveUntil and (os.clock() > refs.objectiveUntil or m.phase == "victory") then
		refs.objective.Visible = false
	end
end

function HudController:init()
	local gui = Theme.screen("Hud", 5, player:WaitForChild("PlayerGui"))
	refs.gui = gui
	buildTop(gui)
	buildCentre(gui)
	buildFeed(gui)
	buildBottom(gui)
	buildTouch(gui)
	refs.objectiveUntil = os.clock() + 20
	Net.listen("Alert", function(text, color, seconds)
		HudController.alert(text, color, seconds)
	end)
	Net.listen("Toast", function(text, kind)
		HudController.toast(text, kind)
	end)
	Net.listen("Kill", function(k)
		HudController.addFeed(k)
		if k.victim == player.UserId then
			refs.flash.BackgroundTransparency = 0.55
		end
	end)
	Net.listen("Hit", function(h)
		HudController.hitMarker(h.kill, h.head)
	end)
	Net.listen("Hurt", function()
		refs.flash.BackgroundTransparency = 0.75
	end)
	Net.listen("Results", function(r)
		HudController.showResults(r)
	end)
	Net.listen("Unlock", function(u)
		HudController.showUnlock(u)
	end)
	Bus.Charge:Connect(function(c)
		if refs.charge then
			refs.charge.Visible = c ~= nil
			refs.chargeFill.Size = UDim2.new(c or 0, 0, 1, 0)
			refs.chargeFill.BackgroundColor3 = (c or 0) >= 0.999 and RED or C.ink
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return HudController
