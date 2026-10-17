--[[
The HUD (master plan §1, §2, §5, §7): everything on screen, in the SUPERHOT look (white, black, red, blue).

  top left   INVITE (I): Roblox's invite prompt; a friend who joins from it gets you both the Buddy Trail
             SHOP (B): the panel (PanelController): the shop, the pass, the locker, the goals
             PARTY (P), beside INVITE, and the party list under SHOP: PartyController
  top        the phase and its clock (BUILD 0:42 / FIGHT 1:13), the frontline bar (red | blue, the line marked, how
             far each team is from losing), the map's name, the team counts
  centre     the crosshair, the bow's charge under it, hit markers (white; red for a kill), the big alerts
             (BUILD, FIGHT!, RED WINS), the respawn countdown
  top right  🏆 TOP (L) in the corner: the leaderboards (LeaderboardController); under it the kill feed: who, with
             what, how far the line moved
  bottom     health (left), the weapons (right: 1 2 3, each a 3D picture, the TNT's cooldown), the build
             tray in the build phase (seven pieces as 3D pictures with their costs, your points), toasts
  touch      FIRE (hold to draw), SPRINT, SLIDE; PLACE and ROTATE while building
  overlays   the results (who won, the table, the MVP, your reward, the next map); unlock and thank-you cards
             stack down the right, under the kill feed

Nothing overlaps on the smallest canvas the screens get (Theme.MIN_WIDTH x DESIGN.Y, 1240 x 560): every piece
has its own slot, the words inside cards shrink to fit their boxes (Theme.text fit), the toast moves up out of
the way of the build tray and of a question card, and ClientSmoke checks the rectangles.

The tutorial (TutorialController): while it guides (Layout.focused) the invite and shop buttons, the kill feed, the
build hint, the objective, alerts and toasts step aside; while one of its cinematics plays (Layout.inCinema) the whole
HUD does.

The objective is on screen in the first seconds (§1: understood in under 15 s): "Every kill pushes the line toward
their base. Push them off the map."
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Structures = require(ReplicatedStorage.Shared.Data.Structures)
local Weapons = require(ReplicatedStorage.Shared.Data.Weapons)
local Bus = require(script.Parent.Parent.UI.Bus)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)
local Layout = require(script.Parent.Parent.UI.Layout)
local Device = require(script.Parent.Parent.UI.Device)
local Icons = require(script.Parent.Parent.UI.Icons)
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
-- the kill feed: under the TOP button (12..48), five rows of 22 with 3 between
local FEED = { top = 56, h = 5 * 22 + 4 * 3 }
-- the popup stack (unlocks, thank-yous): down the right under the kill feed, two at a time, clear of the touch
-- buttons below
local STACK = { top = 186, w = 300, h = 64, gap = 8, max = 2 }
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

-- The hotbar's key badge: the number to press, in a small square at a slot's top left (black; white when the slot
-- is the one picked, which turns black itself)
local function keyBadge(n, parent)
	local badge = Theme.new("Frame", {
		Name = "Key",
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = C.ink,
		ZIndex = 2,
		Parent = parent,
	}, { Theme.corner(4) })
	label({
		Name = "Num",
		Text = tostring(n),
		Size = UDim2.fromScale(1, 1),
		TextSize = 12,
		TextColor3 = C.white,
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.Display,
		ZIndex = 2,
		Parent = badge,
	})
	return badge
end

local function paintBadge(badge, on)
	if badge then
		badge.BackgroundColor3 = on and C.white or C.ink
		badge.Num.TextColor3 = on and C.ink or C.white
	end
end

-- A hotbar slot (the weapons, the build tray): a white card, softly shaded top to bottom, with its picture
-- (UI/Icons), the key to press in a badge and the name under the picture. The one picked lifts a little, turns
-- black with a ring and a soft glow in your team's colour and a short bar under it, and pops as you switch to it.
local BOW_SLOT = { y = 8, h = 66 } -- (the weapons: a slot's top, its height; lifted, it sits LIFT higher)
local TRAY_SLOT = { y = 32, h = 78 } -- (the tray: under the points)
local LIFT = 6
local function slot(props, n, icon)
	props.BackgroundColor3 = C.white
	props.Text = ""
	props.AutoButtonColor = false
	local b = Theme.new("TextButton", props, {
		Theme.corner(8),
		Theme.new("UIGradient", {
			Name = "Shade",
			Rotation = 90,
			Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(222, 222, 228)),
		}),
	})
	local edge = Theme.stroke(2, C.ink)
	edge.Name = "Edge"
	edge.Parent = b
	-- the glow: a wide soft ring just outside the edge, only on the one picked
	Theme.new("Frame", {
		Name = "Glow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 6, 1, 6),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = b,
	}, { Theme.corner(10), Theme.new("UIStroke", { Name = "Ring", Thickness = 4, Transparency = 0.55 }) })
	icon.Parent = b
	keyBadge(n, b)
	Theme.new("Frame", {
		Name = "Bar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -2),
		Size = UDim2.fromOffset(26, 3),
		BorderSizePixel = 0,
		Visible = false,
		Parent = b,
	}, { Theme.corner(2) })
	return b
end

-- Paint a slot: picked (on), out of reach (dim: a piece you can't afford), or plain; x, y where it sits unpicked
local SHADE_LIGHT = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(222, 222, 228))
local SHADE_DARK = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(120, 120, 132))
local function paintSlot(b, on, dim, teamC, x, y)
	local was = b:GetAttribute("On") == true
	b.BackgroundColor3 = on and Color3.fromRGB(44, 44, 52) or (dim and Color3.fromRGB(232, 232, 235) or C.white)
	b.Shade.Color = on and SHADE_DARK or SHADE_LIGHT
	b.Edge.Color = on and teamC or (dim and C.muted or C.ink)
	b.Edge.Thickness = on and 3 or 2
	b.Glow.Visible = on
	b.Glow.Ring.Color = teamC
	-- (not where a magazine's pips or a piece's cost already sit)
	b.Bar.Visible = on and not b:FindFirstChild("Pips") and not b:FindFirstChild("CostPill")
	b.Bar.BackgroundColor3 = teamC
	b.Icon.ImageTransparency = dim and not on and 0.55 or 0
	b.Label.TextColor3 = on and C.white or (dim and C.muted or C.ink)
	local ammo = b:FindFirstChild("Ammo")
	if ammo then
		ammo.TextColor3 = on and C.white or C.ink
	end
	paintBadge(b.Key, on)
	b.Position = UDim2.fromOffset(x, on and y - LIFT or y)
	if on and not was then
		-- switched to: a quick pop (bigger, then back with a little bounce)
		local scale = b:FindFirstChild("Pop") or Theme.new("UIScale", { Name = "Pop", Parent = b })
		scale.Scale = Theme.reducedMotion() and 1 or 1.12
		Theme.tween(scale, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	b:SetAttribute("On", on)
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
		refs.mapName.Text = "" -- (the map's name stays off the bar: "New game: ..." says it once)
	end
end

-- Top left: invite a friend ------------------------------------------------------------------------------------
function HudController.invite()
	local SocialService = game:GetService("SocialService")
	local ok, can = pcall(function()
		return SocialService:CanSendGameInviteAsync(player)
	end)
	if ok and not can then
		HudController.toast("Invites aren't available on this account.", "bad")
		return false
	end
	local sent = pcall(function()
		local options = Instance.new("ExperienceInviteOptions")
		options.LaunchData = "i:" .. tostring(player.UserId)
		options.PromptMessage = "Come fight with me! We both get the Buddy Trail."
		SocialService:PromptGameInvite(player, options)
	end)
	return sent
end

local function buildInvite(gui)
	local touch = Theme.isTouch()
	local b = Theme.new("TextButton", {
		Name = "Invite",
		Position = UDim2.fromOffset(16, 16),
		Size = UDim2.fromOffset(200, 50),
		BackgroundColor3 = C.white,
		Text = "",
		AutoButtonColor = true,
		Parent = gui,
	}, { Theme.corner(4), Theme.stroke(2, C.ink) })
	Theme.title({
		Name = "Head",
		Text = touch and "👥 INVITE A FRIEND" or "👥 INVITE A FRIEND  [I]",
		Size = UDim2.new(1, -16, 0, 22),
		Position = UDim2.fromOffset(8, 5),
		TextColor3 = C.ink,
		outline = false,
		Parent = b,
	})
	label({
		Name = "Line",
		Text = "You both get the Buddy Trail",
		Size = UDim2.new(1, -16, 0, 16),
		Position = UDim2.fromOffset(8, 28),
		fit = 12,
		TextColor3 = C.muted,
		Parent = b,
	})
	b.Activated:Connect(HudController.invite)
	refs.invite = b
	-- the shop and the rest (PanelController), right under it
	local s = Theme.new("TextButton", {
		Name = "ShopButton",
		Position = UDim2.fromOffset(16, 74),
		Size = UDim2.fromOffset(200, 50),
		BackgroundColor3 = C.ink,
		Text = "",
		AutoButtonColor = true,
		Parent = gui,
	}, { Theme.corner(4), Theme.stroke(2, C.ink) })
	Theme.gem(s, 20, { Name = "Gem", Position = UDim2.fromOffset(6, 5) })
	Theme.title({
		Name = "Head",
		Text = touch and "SHOP & LOCKER" or "SHOP & LOCKER  [B]",
		Size = UDim2.new(1, -36, 0, 22),
		Position = UDim2.fromOffset(30, 5),
		TextColor3 = C.white,
		outline = false,
		Parent = s,
	})
	refs.shopLine = label({
		Name = "Line",
		Text = "Pass · goals · VIP",
		Size = UDim2.new(1, -36, 0, 16),
		Position = UDim2.fromOffset(30, 28),
		fit = 12,
		TextColor3 = C.grey,
		Parent = s,
	})
	s.Activated:Connect(function()
		local Panel = require(script.Parent.PanelController)
		Panel.toggle()
	end)
	refs.shop = s
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
		Position = UDim2.new(1, -12, 0, FEED.top),
		Size = UDim2.fromOffset(FEED_W, FEED.h),
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
	local killer = k.killerName or ({ fall = "the void", reset = "reset", admin = "an admin" })[k.kind] or "?"
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
	-- (no health bar: every hit is a knockout. The slot stays for your team's name and PROTECTED)
	local hp = Theme.new("Frame", {
		Name = "Health",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.fromOffset(230, 18),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = gui,
	})
	refs.health = hp
	refs.hpFill = Theme.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		Parent = hp,
	})
	refs.team = Theme.title({
		Name = "Team",
		Text = "",
		Size = UDim2.fromOffset(230, 22),
		Position = UDim2.fromOffset(0, -26),
		TextColor3 = RED,
		outline = false,
		Parent = hp,
	})
	-- the weapons: a slot each (1 2 3), each with its picture
	local bows = Theme.new("Frame", {
		Name = "Bows",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(#Weapons.list * 82, BOW_SLOT.y + BOW_SLOT.h),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	refs.bowsFrame = bows
	refs.bows = {}
	for i, w in Weapons.list do
		local b = slot({
			Name = "Bow_" .. w.key,
			Position = UDim2.fromOffset((i - 1) * 82, BOW_SLOT.y),
			Size = UDim2.fromOffset(76, BOW_SLOT.h),
			Parent = bows,
		}, i, Icons.weapon(
			w.key,
			Store.team(),
			{ Position = UDim2.fromOffset(4, 1), Size = UDim2.fromOffset(68, 42) }
		))
		label({
			Name = "Label",
			Text = ({ bow = "BOW", tnt = "TNT", blade = "BLADE" })[w.key] or string.upper(w.name),
			Size = UDim2.new(1, -4, 0, 12),
			Position = UDim2.fromOffset(2, 43),
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Center,
			Font = Theme.Display,
			Parent = b,
		})
		-- the top right: the TNT's cooldown in seconds (and a magazine's count with a row of pips under the name, for
		-- a weapon that has one: none does now)
		local ammo = label({
			Name = "Ammo",
			Text = "",
			Size = UDim2.fromOffset(32, 14),
			Position = UDim2.fromOffset(41, 4),
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Right,
			Font = Theme.Display,
			Parent = b,
		})
		local pips
		if w.mag then
			pips = Theme.new("Frame", {
				Name = "Pips",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 57),
				Size = UDim2.fromOffset(w.mag * 8 - 2, 4),
				BackgroundTransparency = 1,
				Visible = false,
				Parent = b,
			})
			for k = 1, w.mag do
				Theme.new("Frame", {
					Name = "Pip" .. k,
					Position = UDim2.fromOffset((k - 1) * 8, 0),
					Size = UDim2.fromOffset(6, 4),
					BorderSizePixel = 0,
					BackgroundColor3 = C.white,
					Parent = pips,
				}, { Theme.corner(1) })
			end
		end
		b.Activated:Connect(function()
			Bus.Weapon:Fire(w.key)
		end)
		refs.bows[w.key] = { button = b, ammo = ammo, key = b.Key, icon = b.Icon, pips = pips, x = (i - 1) * 82 }
	end
	-- the blade's slot is only there in the CHARGE (the fight's last seconds, when the line opens)
	local function chargeSlots()
		local on = workspace:GetAttribute("Charge") == true
		for _, w in Weapons.list do
			if w.melee and refs.bows[w.key] then
				refs.bows[w.key].button.Visible = on
			end
		end
	end
	chargeSlots()
	workspace:GetAttributeChangedSignal("Charge"):Connect(chargeSlots)
	-- the build tray
	local tray = Theme.new("Frame", {
		Name = "BuildTray",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(#Structures.list * 74 + 6, TRAY_SLOT.y + TRAY_SLOT.h),
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
	refs.traySlots = {}
	for i, s in Structures.list do
		local b = slot(
			{
				Name = "Piece_" .. s.key,
				Position = UDim2.fromOffset(3 + (i - 1) * 74, TRAY_SLOT.y),
				Size = UDim2.fromOffset(70, TRAY_SLOT.h),
				Parent = tray,
			},
			i,
			Icons.structure(s.key, Store.team(), { Position = UDim2.fromOffset(3, 2), Size = UDim2.fromOffset(64, 42) })
		)
		label({
			Name = "Label",
			Text = string.upper(s.name),
			Size = UDim2.new(1, -4, 0, 18),
			Position = UDim2.fromOffset(2, 43),
			TextSize = 8,
			TextXAlignment = Enum.TextXAlignment.Center,
			Font = Theme.Display,
			Parent = b,
		})
		-- what it costs, in a small pill along the bottom
		local pill = Theme.new("Frame", {
			Name = "CostPill",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 62),
			Size = UDim2.fromOffset(40, 13),
			BorderSizePixel = 0,
			BackgroundColor3 = C.ink,
			Parent = b,
		}, { Theme.corner("round") })
		label({
			Name = "Cost",
			Text = `{s.cost} PTS`,
			Size = UDim2.fromScale(1, 1),
			TextSize = 9,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = C.white,
			Font = Theme.Display,
			Parent = pill,
		})
		b.Activated:Connect(function()
			BuildController.pick(s.key)
		end)
		refs.trayButtons[s.key] = b
		refs.traySlots[s.key] = { x = 3 + (i - 1) * 74 }
	end
	refs.tray = tray
	refs.buildHint = label({
		Name = "Hint",
		Text = "1-7 or wheel: pick · Click: place · Right-click or R: turn · Q: cancel",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(540, 18),
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
	if Layout.panel() and Layout.statusSink and Layout.statusSink(text, kind) then
		return -- (the panel's open: its own message line says it)
	end
	-- a toast about Shards wears the Shard gem in front of its words
	text = string.gsub(text, " ?◆", " Shards")
	local gem = t:FindFirstChild("Gem") or Theme.gem(t, 20, { Name = "Gem" })
	local shards = string.find(text, "Shard") ~= nil
	gem.Visible = shards
	if shards then
		-- (the words are centred: roughly 0.55 of the letters' height each)
		local width = math.min(t.Size.X.Offset, (utf8.len(text) or #text) * 15 * 0.55)
		gem.Position = UDim2.fromOffset(math.max(0, (t.Size.X.Offset - width) / 2 - 24), 2)
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
	local teamC = Constants.TEAM_COLOR[me.team or ""] or C.ink
	if refs.iconTeam ~= me.team then
		-- the pictures wear your team's colour
		refs.iconTeam = me.team
		for _, b in refs.bows or {} do
			Icons.paint(b.icon, me.team)
		end
		for _, b in refs.trayButtons or {} do
			Icons.paint(b.Icon, me.team)
		end
	end
	for key, b in refs.bows or {} do
		local on = me.weapon == key
		local w = Weapons.get(key)
		local wait = w.throw and (me.readyAt or 0) - os.clock() or 0
		paintSlot(b.button, on, wait > 0, teamC, b.x, BOW_SLOT.y)
		if wait > 0 then
			b.ammo.Text = string.format("%.1f", wait)
		else
			b.ammo.Text = (w.mag and on) and `{me.ammo or 0}/{w.mag}` or ""
		end
		if b.pips then
			b.pips.Visible = on
			for k, pip in b.pips:GetChildren() do
				local n = tonumber(pip.Name:sub(4)) or k
				pip.BackgroundColor3 = n <= (me.ammo or 0) and teamC or Color3.fromRGB(80, 80, 90)
			end
		end
	end
	local building = m.phase == "build"
	if refs.tray then
		refs.tray.Visible = building
		refs.budget.Text = `BUILD POINTS  {me.budget or 0} / {me.budgetMax or Constants.BUILD_BUDGET}`
		local picked = BuildController.picked()
		for key, b in refs.trayButtons do
			local s = Structures.get(key)
			local afford = (me.budget or 0) >= s.cost
			local on = picked == key
			paintSlot(b, on, not afford, teamC, refs.traySlots[key].x, TRAY_SLOT.y)
			b.CostPill.BackgroundColor3 = on and teamC or (afford and C.ink or Color3.fromRGB(170, 170, 176))
		end
		local spot = BuildController.spot()
		refs.buildHint.Text = (picked and spot and not spot.ok and spot.why)
			or "1-7 or wheel: pick · Click: place · Right-click or R: turn · Q: cancel"
		refs.buildHint.TextColor3 = (picked and spot and not spot.ok) and RED or C.muted
	end
	if refs.bows then
		refs.bows.bow.button.Parent.Visible = not building and m.phase ~= "victory" -- (not over the question card)
	end
end

-- Touch controls -----------------------------------------------------------------------------------------------
-- Built for every device and shown while you're playing by touch (Device: a phone, a tablet, a touch laptop being
-- tapped). Round the right thumb, each in its own spot (centre offsets from the bottom-right corner); Roblox's own
-- thumbstick keeps the left side, and its jump button is swapped for ours so nothing sits on anything:
--   FIRE (hold to draw)  JUMP  CROUCH (toggle)  RUN (toggle)  SLIDE  RELOAD (a magazine weapon; none has one now)
--   PLACE and TURN take FIRE's and RUN's spots while building
local TOUCH = {
	fire = { -110, -150, 104 },
	jump = { -60, -52, 72 },
	crouch = { -190, -58, 60 },
	sprint = { -230, -140, 64 },
	slide = { -205, -215, 58 },
	reload = { -60, -235, 52 },
}
HudController.TOUCH = TOUCH

local function buildTouch(gui)
	local function button(name, text, spot, color)
		return Theme.new("TextButton", {
			Name = name,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, spot[1], 1, spot[2]),
			Size = UDim2.fromOffset(spot[3], spot[3]),
			BackgroundColor3 = color or C.white,
			BackgroundTransparency = 0.1,
			Text = text,
			Font = Theme.Display,
			TextSize = spot[3] >= 90 and 18 or 13,
			TextColor3 = color and C.white or C.ink,
			AutoButtonColor = false,
			Visible = false,
			Parent = gui,
		}, { Theme.corner("round"), Theme.stroke(2, C.ink) })
	end
	local function toggle(b, on)
		b.BackgroundColor3 = on and C.ink or C.white
		b.TextColor3 = on and C.white or C.ink
	end
	local fire = button("Fire", "FIRE", TOUCH.fire, C.ink)
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
	local jump = button("Jump", "JUMP", TOUCH.jump)
	jump.Activated:Connect(function()
		Bus.Jump:Fire()
	end)
	local crouchOn = false
	local crouch = button("Crouch", "CROUCH", TOUCH.crouch)
	crouch.Activated:Connect(function()
		crouchOn = not crouchOn
		toggle(crouch, crouchOn)
		Bus.Crouch:Fire(crouchOn)
	end)
	local sprintOn = false
	local sprint = button("Sprint", "RUN", TOUCH.sprint)
	sprint.Activated:Connect(function()
		sprintOn = not sprintOn
		toggle(sprint, sprintOn)
		Bus.Sprint:Fire(sprintOn)
	end)
	local slide = button("Slide", "SLIDE", TOUCH.slide)
	slide.Activated:Connect(function()
		Bus.Slide:Fire()
	end)
	local reload = button("Reload", "RELOAD", TOUCH.reload)
	reload.Activated:Connect(function()
		Bus.Reload:Fire()
	end)
	local place = button("Place", "PLACE", TOUCH.fire, C.ink)
	place.Activated:Connect(function()
		Bus.Place:Fire()
	end)
	local rotate = button("Rotate", "TURN", TOUCH.sprint)
	rotate.Activated:Connect(function()
		Bus.Rotate:Fire()
	end)
	refs.touch = {
		fire = fire,
		jump = jump,
		crouch = crouch,
		sprint = sprint,
		slide = slide,
		reload = reload,
		place = place,
		rotate = rotate,
	}
end
HudController._buildTouch = buildTouch -- (tests: the touch layout on a desktop run)

-- Roblox's own touch jump button sits where ours are: hidden while ours shows (its thumbstick stays)
local function hideRobloxJump()
	local pg = player:FindFirstChild("PlayerGui")
	local tg = pg and pg:FindFirstChild("TouchGui")
	local frame = tg and tg:FindFirstChild("TouchControlFrame")
	local jb = frame and frame:FindFirstChild("JumpButton")
	if jb and jb.Visible then
		jb.Visible = false
	end
end

-- Where the corners go for the way you play: on touch the health moves up under the buttons on the left (the
-- thumbstick has the bottom left), the bows go to the bottom middle (the action buttons have the bottom right),
-- and only one popup shows at a time (the buttons reach up the right side).
function HudController.layoutFor(kind)
	local touch = kind == "touch"
	if refs.health then
		refs.health.AnchorPoint = touch and Vector2.new(0, 0) or Vector2.new(0, 1)
		refs.health.Position = touch and UDim2.fromOffset(16, 160) or UDim2.new(0, 16, 1, -16)
	end
	if refs.bowsFrame then
		refs.bowsFrame.AnchorPoint = touch and Vector2.new(0.5, 1) or Vector2.new(1, 1)
		refs.bowsFrame.Position = touch and UDim2.new(0.5, 0, 1, -16) or UDim2.new(1, -16, 1, -16)
	end
	STACK.max = touch and 1 or 2
	refs.layout = kind
end

local function updateTouch()
	local t = refs.touch
	if not t then
		return
	end
	local on = Device.isTouch()
	local phase = Store.phase()
	local building = phase == "build"
	local playing = phase == "build" or phase == "fight"
	local picked = BuildController.picked() ~= nil
	local me = Store.get("me") or {}
	local w = Weapons.get(me.weapon or "")
	t.fire.Visible = on and phase == "fight"
	t.jump.Visible = on and playing
	t.crouch.Visible = on and playing
	t.sprint.Visible = on and playing and not (building and picked)
	t.slide.Visible = on and playing
	t.reload.Visible = on and phase == "fight" and w ~= nil and w.mag ~= nil
	t.place.Visible = on and building and picked
	t.rotate.Visible = on and building and picked
	if on then
		hideRobloxJump()
	end
	if refs.layout ~= Device.kind() then
		HudController.layoutFor(Device.kind())
	end
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
	Layout.resultsOpen = true
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
	local e = you.earned
	if e and ((e.shards or 0) > 0 or (e.xp or 0) > 0) then
		line ..= `  ·  +{e.shards} SHARDS  +{e.xp} PASS XP`
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
			Layout.resultsOpen = false
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
	local line = u.line
		or u.extra and `{s.name} · equipped`
		or (s.name .. (u.badge and `  ·  {u.badge} WINS IN A ROW` or ""))
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
	if refs.invite then
		-- (clickable with the mouse between games, when first person lets go of it; I and B work any time)
		refs.invite.Modal = false -- (the win screen keeps you in play: no cursor; I, B and Tab work any time)
		refs.shop.Modal = false
		local p = Store.get("profile") or {}
		refs.shopLine.Text = `{Theme.commas(p.shards or 0)} SHARDS  ·  PASS TIER {(p.season or {}).tier or 0}`
	end
	-- the panel's open: the middle of the HUD steps aside
	if Layout.panel() then
		for _, k in { "alert", "objective", "countdown", "respawn", "tray", "cross", "charge", "toast" } do
			if refs[k] then
				refs[k].Visible = false
			end
		end
		if refs.bowsFrame then
			refs.bowsFrame.Visible = false -- (the weapons wait under the panel)
		end
		if refs.results then
			refs.results.Visible = false
		end
	elseif refs.results and refs.results.Visible == false then
		refs.results.Visible = true
	end
	-- a spectating admin has no body: no health, no bows, no crosshair, no build tray
	local watching = player:GetAttribute("Spectating") == true
	if refs.health then
		refs.health.Visible = not watching
	end
	if watching then
		for _, k in { "respawn", "tray", "cross", "charge" } do
			if refs[k] then
				refs[k].Visible = false
			end
		end
		if refs.bowsFrame then
			refs.bowsFrame.Visible = false
		end
	end
	if refs.flash and refs.flash.BackgroundTransparency < 1 then
		refs.flash.BackgroundTransparency = math.min(1, refs.flash.BackgroundTransparency + 0.04)
	end
	if refs.objective and refs.objectiveUntil and (os.clock() > refs.objectiveUntil or m.phase == "victory") then
		refs.objective.Visible = false
	end
	-- the tutorial: a cinematic has the whole screen; while it guides, only what the step needs stays
	if refs.gui then
		refs.gui.Enabled = not Layout.inCinema()
	end
	local focus = Layout.focused()
	if focus or refs.focusHid then
		-- (the first four come back after; the passing ones keep their own timers)
		for i, k in { "invite", "shop", "feed", "buildHint", "objective", "alert", "toast" } do
			if refs[k] and (focus or i <= 4) then
				refs[k].Visible = not focus
			end
		end
		refs.focusHid = focus
	end
end

function HudController:init()
	local gui = Theme.screen("Hud", 5, player:WaitForChild("PlayerGui"))
	refs.gui = gui
	buildTop(gui)
	buildInvite(gui)
	buildCentre(gui)
	buildFeed(gui)
	buildBottom(gui)
	buildTouch(gui)
	HudController.layoutFor(Device.kind())
	-- (the server hears the device at most once every 2 s: a pad and a mouse, or a touch laptop, can flip it every frame)
	local sentKind, sentAt, pending = Device.kind(), os.clock(), false
	Net.send("Settings", "device", sentKind)
	Device.Changed:Connect(function(kind)
		HudController.layoutFor(kind)
		if pending then
			return
		end
		pending = true
		task.delay(math.max(0, 2 - (os.clock() - sentAt)), function()
			pending = false
			if Device.kind() ~= sentKind then
				sentKind, sentAt = Device.kind(), os.clock()
				Net.send("Settings", "device", sentKind)
			end
		end)
	end)
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
		if h.parry then
			HudController.alert("PARRIED!", Color3.fromRGB(30, 30, 34), 0.9) -- (your blade sent an arrow back)
			return
		end
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
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.I then
			HudController.invite()
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return HudController
