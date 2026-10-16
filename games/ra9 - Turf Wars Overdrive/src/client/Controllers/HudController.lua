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
  overlays   the results (who won, the table, the MVP, your reward, the next map) and unlock cards

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
local BuildController = require(script.Parent.BuildController)

local HudController = { Name = "HudController", Order = 40 }

local C = Theme.Color
local RED, BLUE = Constants.TEAM_COLOR.red, Constants.TEAM_COLOR.blue
local player = Players.LocalPlayer
local refs = {}
HudController.refs = refs
local feed = {}
local hitUntil = 0

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
	local names = { build = "BUILD", fight = "FIGHT", victory = "RESULTS", loading = "NEXT MAP" }
	if refs.phase then
		refs.phase.Text = (names[phase] or "")
			.. ((phase == "build" or phase == "fight") and (" " .. clock(left)) or "")
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
		Size = UDim2.fromOffset(800, 90),
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
		Size = UDim2.fromOffset(620, 22),
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
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
		Size = UDim2.fromOffset(330, 150),
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
		Size = UDim2.fromOffset(330, 22),
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
		TextSize = 13,
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
			Text = `{i}  {string.upper(string.split(w.name, " ")[2] or w.name)}`,
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
		Position = UDim2.new(0.5, 0, 1, -132),
		Size = UDim2.fromOffset(600, 24),
		TextSize = 15,
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
	local sprint = button("Sprint", "RUN", UDim2.new(1, -220, 1, -110), 64)
	sprint.Activated:Connect(function()
		sprintOn = not sprintOn
		sprint.BackgroundColor3 = sprintOn and C.ink or C.white
		sprint.TextColor3 = sprintOn and C.white or C.ink
		Bus.Sprint:Fire(sprintOn)
	end)
	button("Slide", "SLIDE", UDim2.new(1, -210, 1, -190), 58).Activated:Connect(function()
		Bus.Slide:Fire()
	end)
	local place = button("Place", "PLACE", UDim2.new(1, -110, 1, -150), 104, C.ink)
	place.Activated:Connect(function()
		Bus.Place:Fire()
	end)
	local rotate = button("Rotate", "TURN", UDim2.new(1, -220, 1, -110), 64)
	rotate.Activated:Connect(function()
		Bus.Rotate:Fire()
	end)
	refs.touch = { fire = fire, place = place, rotate = rotate, sprint = sprint }
end

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
	local card = Theme.card({
		Name = "Results",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(560, 380),
		BackgroundColor3 = C.white,
		Parent = gui,
	})
	refs.results = card
	Theme.title({
		Text = `{Constants.TEAM_NAME[r.winner] or "?"} WINS`,
		Size = UDim2.new(1, 0, 0, 54),
		Position = UDim2.fromOffset(0, 10),
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
		Position = UDim2.fromOffset(10, 64),
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = card,
	})
	local y = 96
	label({
		Text = "PLAYER                         K     D     A     BUILT",
		Size = UDim2.new(1, -40, 0, 16),
		Position = UDim2.fromOffset(20, y),
		TextSize = 11,
		TextColor3 = C.muted,
		Font = Theme.Display,
		Parent = card,
	})
	y += 20
	for i = 1, math.min(8, #(r.rows or {})) do
		local row = r.rows[i]
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
			Size = UDim2.new(1, -40, 0, 22),
			Position = UDim2.fromOffset(20, y),
			TextSize = 14,
			Font = Enum.Font.Code,
			TextColor3 = Constants.TEAM_COLOR[row.team or ""] or C.ink,
			Parent = card,
		})
		y += 24
	end
	if r.next then
		label({
			Text = `NEXT: {string.upper(r.next.name)}  ·  {r.next.tagline or ""}`,
			AnchorPoint = Vector2.new(0, 1),
			Size = UDim2.new(1, -20, 0, 20),
			Position = UDim2.new(0, 10, 1, -12),
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Center,
			Font = Theme.Display,
			Parent = card,
		})
	end
	Theme.pop(card)
	task.delay(Constants.VICTORY_SECONDS + Constants.TRANSITION_SECONDS, function()
		if refs.results == card then
			card:Destroy()
			refs.results = nil
		end
	end)
end

function HudController.showUnlock(u)
	local s = u.step
	if not s then
		return
	end
	local card = Theme.card({
		Name = "Unlock",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 140),
		Size = UDim2.fromOffset(380, 70),
		BackgroundColor3 = C.ink,
		Parent = refs.gui,
	})
	Theme.title({
		Text = `WIN #{u.wins} · NEW {string.upper(s.kind)}`,
		Size = UDim2.new(1, -20, 0, 26),
		Position = UDim2.fromOffset(10, 8),
		TextColor3 = C.white,
		outline = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = card,
	})
	label({
		Text = s.name .. (u.badge and `  ·  {u.badge} WINS IN A ROW` or ""),
		Size = UDim2.new(1, -20, 0, 22),
		Position = UDim2.fromOffset(10, 38),
		TextSize = 16,
		TextColor3 = C.white,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = card,
	})
	Theme.pop(card)
	task.delay(5, function()
		card:Destroy()
	end)
end

-- Each frame ---------------------------------------------------------------------------------------------------
local function step()
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
	if refs.flash and refs.flash.BackgroundTransparency < 1 then
		refs.flash.BackgroundTransparency = math.min(1, refs.flash.BackgroundTransparency + 0.04)
	end
	if refs.objective and refs.objectiveUntil and os.clock() > refs.objectiveUntil then
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
