--[[
The missions after the tutorial, the show (HookService counts them; Data/Hook says what they are), and the WELCOME
BACK banner for anyone returning (TutorialService sends it instead of the tutorial or the intro).

  a mission    a big card at the top: its icon, MISSION 2/5, the title, what to do, a progress bar and the reward
               (+25 ◆). It pops in (a springy scale and a tilt), its edge glows round in a moving gradient, the bar
               slides as it fills and the count punches. A guide in the world: a bouncing arrow over the nearest
               enemy (enemy), a glowing arrow on the frontline pointing at their side (line), or a hint to open the
               build tray (build; in the fight it says "next build phase").
  done         the card flashes gold, MISSION COMPLETE! +25 ◆ slams into the middle, confetti rains, a sound; the
               next card slides in a moment later
  complete     a big HOOK COMPLETE! card with the reward (Shards and a cosmetic, worn already) and SEE THE SHOP
  welcome      WELCOME BACK, <name>! slides down with their wins, streak and knockouts; gone in a few seconds

Nothing here blocks the camera or the controls; the card steps aside while the shop panel is open.

  HookController.state() -> { mission = msg?, welcome = bool, complete = bool, marker = "enemy" | "line" | nil }
  HookController.handle(msg)   (Net "Hook"; tests call it too)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Hook = require(ReplicatedStorage.Shared.Data.Hook)
local Net = require(ReplicatedStorage.Shared.Net)
local Layout = require(script.Parent.Parent.UI.Layout)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)
local AudioController = require(script.Parent.AudioController)

local HookController = { Name = "HookController", Order = 72 }

local C = Theme.Color
local player = Players.LocalPlayer
local GOLD = Color3.fromRGB(255, 196, 40)
local refs = {}
HookController.refs = refs
local mission -- the current { kind = "step", ... } message
local completeShown, welcomeShown = false, false
local marker -- "enemy" | "line" | nil (what the world guide shows)
local world -- this client's guide pieces: { folder, arrow, line }

local function team()
	return Store.team() or player:GetAttribute("Team") or "red"
end

local function tween(inst, seconds, props, style, dir)
	return Theme.tween(inst, seconds, props, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out)
end

local function sound(cue)
	pcall(AudioController.play, cue)
end

-- The screen ---------------------------------------------------------------------------------------------------
local function gui()
	if not refs.gui then
		refs.gui = Theme.screen("Hook", 18, player:WaitForChild("PlayerGui"))
	end
	return refs.gui
end

-- A moving rainbow-ish gradient round an edge (a mission card's glow)
local function glowEdge(parent, color)
	local stroke = Theme.new("UIStroke", {
		Name = "Glow",
		Thickness = 3,
		Color = C.white,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
	Theme.new("UIGradient", {
		Name = "Spin",
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, color),
			ColorSequenceKeypoint.new(0.5, C.white),
			ColorSequenceKeypoint.new(1, color),
		}),
		Parent = stroke,
	})
	return stroke
end

local function label(props)
	props.TextColor3 = props.TextColor3 or C.ink
	return Theme.text(props)
end

-- Confetti over the whole screen: little coloured slips falling and turning
local function confetti(n)
	local root = gui()
	for _ = 1, n or 36 do
		local slip = Theme.new("Frame", {
			Name = "Confetti",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(math.random(), 0, -0.05, 0),
			Size = UDim2.fromOffset(math.random(6, 11), math.random(10, 16)),
			Rotation = math.random(0, 360),
			BackgroundColor3 = Color3.fromHSV(math.random(), 0.8, 1),
			BorderSizePixel = 0,
			ZIndex = 30,
			Parent = root,
		})
		local fall = 1.2 + math.random() * 0.9
		tween(slip, fall, {
			Position = UDim2.new(slip.Position.X.Scale + (math.random() - 0.5) * 0.2, 0, 1.05, 0),
			Rotation = slip.Rotation + math.random(-540, 540),
		}, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
		task.delay(fall + 0.1, function()
			slip:Destroy()
		end)
	end
end

-- A big word slammed into the middle (scales down from huge, holds, fades)
local function slam(text, color)
	local root = gui()
	local l = label({
		Name = "Slam",
		Text = text,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.38, 0),
		Size = UDim2.fromOffset(640, 70),
		TextSize = 40,
		Font = Theme.Display,
		TextColor3 = color or GOLD,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 31,
		Parent = root,
	})
	Theme.textStroke(3, C.ink).Parent = l
	local scale = Theme.new("UIScale", { Scale = 2.4, Parent = l })
	tween(scale, 0.28, { Scale = 1 }, Enum.EasingStyle.Back)
	l.Rotation = -6
	tween(l, 0.28, { Rotation = 0 }, Enum.EasingStyle.Back)
	task.delay(1.4, function()
		tween(l, 0.35, { TextTransparency = 1 })
		task.delay(0.4, function()
			l:Destroy()
		end)
	end)
	return l
end

-- The mission card ---------------------------------------------------------------------------------------------
local function closeCard()
	if refs.card then
		refs.card:Destroy()
		refs.card = nil
	end
end

local function stepText(s)
	if s.phase == "build" and Store.phase() ~= "build" then
		return "Next build phase: pick a wall and place it on your side."
	end
	return s.desc
end

local function paintProgress(animated)
	local card = refs.card
	local s = mission and Hook.step(mission.i)
	if not card or not s then
		return
	end
	local f = math.clamp((mission.have or 0) / math.max(1, s.need), 0, 1)
	local fill = card.Bar.Fill
	if animated then
		tween(fill, 0.35, { Size = UDim2.fromScale(f, 1) }, Enum.EasingStyle.Back)
		local sc = card.Count:FindFirstChildOfClass("UIScale")
		if sc then
			sc.Scale = 1.6
			tween(sc, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		end
	else
		fill.Size = UDim2.fromScale(f, 1)
	end
	card.Count.Text = `{mission.have or 0}/{s.need}`
	card.Desc.Text = stepText(s)
end

local function showCard(msg)
	closeCard()
	local s = Hook.step(msg.i)
	if not s then
		return
	end
	local tc = Constants.TEAM_COLOR[team()] or GOLD
	local card = Theme.card({
		Name = "Mission",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 92),
		Size = UDim2.fromOffset(440, 118),
		BackgroundColor3 = C.white,
		Parent = gui(),
	})
	refs.card = card
	glowEdge(card, tc)
	label({
		Name = "Icon",
		Text = s.icon or "⭐",
		Position = UDim2.fromOffset(10, 18),
		Size = UDim2.fromOffset(64, 64),
		TextSize = 44,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = card,
	})
	label({
		Name = "Which",
		Text = `MISSION {msg.i}/{msg.total or #Hook.STEPS}`,
		Position = UDim2.fromOffset(84, 8),
		Size = UDim2.fromOffset(200, 16),
		TextSize = 12,
		Font = Theme.Display,
		TextColor3 = tc,
		Parent = card,
	})
	label({
		Name = "Title",
		Text = s.title,
		Position = UDim2.fromOffset(84, 24),
		Size = UDim2.new(1, -170, 0, 28),
		fit = 24,
		Font = Theme.Display,
		Parent = card,
	})
	label({
		Name = "Desc",
		Text = stepText(s),
		Position = UDim2.fromOffset(84, 54),
		Size = UDim2.new(1, -96, 0, 30),
		fit = 14,
		TextColor3 = C.muted,
		Parent = card,
	})
	local reward = label({
		Name = "Reward",
		Text = `+{s.shards} ◆`,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(80, 26),
		TextSize = 16,
		Font = Theme.Display,
		TextColor3 = C.ink,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = card,
	})
	reward.BackgroundTransparency = 0
	reward.BackgroundColor3 = GOLD
	Theme.corner(6).Parent = reward
	local bar = Theme.new("Frame", {
		Name = "Bar",
		Position = UDim2.new(0, 84, 1, -24),
		Size = UDim2.new(1, -150, 0, 12),
		BackgroundColor3 = Color3.fromRGB(225, 225, 230),
		BorderSizePixel = 0,
		Parent = card,
	}, { Theme.corner(6) })
	Theme.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = tc,
		BorderSizePixel = 0,
		Parent = bar,
	}, { Theme.corner(6) })
	local count = label({
		Name = "Count",
		Text = "",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 1, -30),
		Size = UDim2.fromOffset(52, 22),
		TextSize = 16,
		Font = Theme.Display,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = card,
	})
	Theme.new("UIScale", { Scale = 1, Parent = count })
	-- in: a springy scale and a tilt
	local scale = Theme.new("UIScale", { Scale = 0.4, Parent = card })
	card.Rotation = -8
	tween(scale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(card, 0.45, { Rotation = 0 }, Enum.EasingStyle.Back)
	card.Visible = not Layout.panel()
	paintProgress(false)
	sound("click")
end

-- The world guide ----------------------------------------------------------------------------------------------
local function clearWorld()
	if world then
		world.folder:Destroy()
		world = nil
	end
end

local function ensureWorld()
	if world then
		return world
	end
	local folder = Instance.new("Folder")
	folder.Name = "HookGuide"
	folder.Parent = workspace
	-- the enemy arrow (a billboard: always readable)
	local anchor = Instance.new("Part")
	anchor.Name = "EnemyAnchor"
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Parent = folder
	local bb = Instance.new("BillboardGui")
	bb.Name = "Arrow"
	bb.AlwaysOnTop = true
	bb.Size = UDim2.fromOffset(60, 60)
	bb.Adornee = anchor
	bb.Enabled = false
	bb.Parent = anchor
	local t = Instance.new("TextLabel")
	t.Name = "Glyph"
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Text = "▼"
	t.TextScaled = true
	t.Font = Enum.Font.GothamBlack
	t.TextColor3 = GOLD
	t.TextStrokeTransparency = 0
	t.Parent = bb
	-- the line arrow (neon chevrons on the frontline)
	local line = Instance.new("Part")
	line.Name = "LineArrow"
	line.Anchored, line.CanCollide, line.CanQuery, line.CanTouch = true, false, false, false
	line.Material = Enum.Material.Neon
	line.Color = GOLD
	line.Size = Vector3.new(6, 0.3, 3)
	line.Transparency = 1
	line.Parent = folder
	world = { folder = folder, anchor = anchor, arrow = bb, line = line }
	return world
end

local function nearestEnemy()
	local c = player.Character
	local me = c and c:FindFirstChild("HumanoidRootPart")
	if not me then
		return nil
	end
	local mine = team()
	local best, bestD
	local function consider(ch)
		if not ch or ch == c then
			return
		end
		local r = ch:FindFirstChild("HumanoidRootPart")
		local t = ch:GetAttribute("Team")
		if r and t and t ~= mine then
			local d = (r.Position - me.Position).Magnitude
			if not bestD or d < bestD then
				best, bestD = r, d
			end
		end
	end
	for _, p in Players:GetPlayers() do
		consider(p.Character)
	end
	local bots = workspace:FindFirstChild("Bots")
	for _, ch in bots and bots:GetChildren() or {} do
		consider(ch)
	end
	return best
end

local function stepWorld(t)
	local fighting = Store.phase() == "fight"
	if not marker or not fighting then
		if world then
			world.arrow.Enabled = false
			world.line.Transparency = 1
		end
		return
	end
	local w = ensureWorld()
	if marker == "enemy" then
		local r = nearestEnemy()
		w.arrow.Enabled = r ~= nil
		if r then
			w.anchor.CFrame = CFrame.new(r.Position + Vector3.new(0, 4.2 + math.sin(t * 6) * 0.5, 0))
		end
		w.line.Transparency = 1
	elseif marker == "line" then
		w.arrow.Enabled = false
		local x = (Store.get("match") or {}).frontline or workspace:GetAttribute("Frontline") or 0
		local fwd = Formulas.forward(team())
		local pulse = (math.sin(t * 5) + 1) / 2
		w.line.Transparency = 0.15 + pulse * 0.35
		w.line.CFrame = CFrame.new(x + fwd * (2 + pulse * 2), 0.4, 0) * CFrame.Angles(0, fwd > 0 and 0 or math.pi, 0)
	end
end

-- The messages -------------------------------------------------------------------------------------------------
local function showWelcome(msg)
	welcomeShown = true
	local root = gui()
	local banner = Theme.card({
		Name = "Welcome",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -120),
		Size = UDim2.fromOffset(460, 84),
		BackgroundColor3 = C.ink,
		Parent = root,
	})
	refs.welcome = banner
	glowEdge(banner, GOLD)
	label({
		Name = "Title",
		Text = `WELCOME BACK, {string.upper(player.DisplayName)}!`,
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.new(1, -24, 0, 32),
		fit = 26,
		Font = Theme.Display,
		TextColor3 = GOLD,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = banner,
	})
	label({
		Name = "Line",
		Text = `🏆 {msg.wins or 0} wins   🔥 streak {msg.streak or 0}   🎯 {msg.kills or 0} knockouts`,
		Position = UDim2.fromOffset(12, 46),
		Size = UDim2.new(1, -24, 0, 24),
		fit = 16,
		TextColor3 = C.white,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = banner,
	})
	tween(banner, 0.5, { Position = UDim2.new(0.5, 0, 0, 92) }, Enum.EasingStyle.Back)
	sound("horn")
	task.delay(3.8, function()
		if banner.Parent then
			tween(
				banner,
				0.35,
				{ Position = UDim2.new(0.5, 0, 0, -120) },
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			)
			task.delay(0.4, function()
				banner:Destroy()
				if refs.welcome == banner then
					refs.welcome = nil
				end
			end)
		end
	end)
end

local function showComplete(msg)
	completeShown = true
	marker = nil
	closeCard()
	local root = gui()
	local it = msg.cosmetic and Cosmetics.get(msg.cosmetic)
	local card = Theme.card({
		Name = "Complete",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(440, 230),
		BackgroundColor3 = C.white,
		Parent = root,
	})
	refs.complete = card
	Layout.modal("hookComplete", card) -- (the mouse comes free for its buttons)
	glowEdge(card, GOLD)
	label({
		Name = "Title",
		Text = "HOOK COMPLETE! 🎉",
		Position = UDim2.fromOffset(12, 14),
		Size = UDim2.new(1, -24, 0, 40),
		fit = 32,
		Font = Theme.Display,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = card,
	})
	label({
		Name = "Reward",
		Text = `+{msg.shards or 0} ◆` .. (it and `   and the {it.name} {Cosmetics.KIND_NAME[it.kind] or ""}` or ""),
		Position = UDim2.fromOffset(12, 62),
		Size = UDim2.new(1, -24, 0, 30),
		fit = 20,
		Font = Theme.Display,
		TextColor3 = Color3.fromRGB(190, 140, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = card,
	})
	label({
		Name = "Line",
		Text = "It's on already. There's loads more in the shop: kill effects, bows, trails!",
		Position = UDim2.fromOffset(12, 96),
		Size = UDim2.new(1, -24, 0, 40),
		fit = 15,
		TextColor3 = C.muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = card,
	})
	local function close()
		if card.Parent then
			card:Destroy()
		end
		if refs.complete == card then
			refs.complete = nil
		end
	end
	local shop = Theme.new("TextButton", {
		Name = "Shop",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, -80, 0, 156),
		Size = UDim2.fromOffset(150, 48),
		BackgroundColor3 = GOLD,
		Text = "SEE THE SHOP",
		Font = Theme.Display,
		TextSize = 16,
		TextColor3 = C.ink,
		Modal = true,
		Parent = card,
	}, { Theme.corner(6), Theme.stroke(2, C.ink) })
	shop.Activated:Connect(function()
		close()
		local ok, Panel = pcall(require, script.Parent.PanelController)
		if ok and Panel and Panel.open then
			pcall(Panel.open, "shop")
		end
	end)
	local play = Theme.new("TextButton", {
		Name = "Play",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 80, 0, 156),
		Size = UDim2.fromOffset(150, 48),
		BackgroundColor3 = C.ink,
		Text = "KEEP PLAYING",
		Font = Theme.Display,
		TextSize = 16,
		TextColor3 = C.white,
		Modal = true,
		Parent = card,
	}, { Theme.corner(6) })
	play.Activated:Connect(close)
	local scale = Theme.new("UIScale", { Scale = 0.3, Parent = card })
	tween(scale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
	confetti(60)
	sound("victory")
	task.delay(12, close)
end

function HookController.handle(msg)
	if type(msg) ~= "table" then
		return
	end
	if msg.kind == "welcome" then
		showWelcome(msg)
	elseif msg.kind == "step" then
		mission = msg
		local s = Hook.step(msg.i)
		marker = s and (s.marker == "enemy" or s.marker == "line") and s.marker or nil
		-- (a card that follows a MISSION COMPLETE waits for the slam to clear)
		if refs.justDone and os.clock() - refs.justDone < 1.2 then
			task.delay(1.2 - (os.clock() - refs.justDone), function()
				if mission == msg then
					showCard(msg)
				end
			end)
		else
			showCard(msg)
		end
	elseif msg.kind == "progress" then
		if mission and mission.key == msg.key then
			mission.have = msg.have
			paintProgress(true)
			sound("count")
		end
	elseif msg.kind == "stepDone" then
		refs.justDone = os.clock()
		if refs.card then
			refs.card.BackgroundColor3 = GOLD
			if mission then
				mission.have = Hook.step(mission.i) and Hook.step(mission.i).need or mission.have
				paintProgress(true)
			end
			local card = refs.card
			task.delay(0.5, function()
				if card.Parent and refs.card == card then
					closeCard()
				end
			end)
		end
		slam(`MISSION COMPLETE!  +{msg.shards or 0} ◆`)
		confetti(36)
		sound("full")
	elseif msg.kind == "complete" then
		mission = nil
		showComplete(msg)
	end
end

function HookController.state()
	return {
		mission = mission,
		welcome = welcomeShown,
		complete = completeShown,
		marker = marker,
		card = refs.card,
	}
end

function HookController:init()
	Net.listen("Hook", HookController.handle)
	Layout.onPanel(function(open)
		if refs.card then
			refs.card.Visible = not open
		end
	end)
	Store.Changed:Connect(function(partial)
		if partial.match and mission and refs.card then
			local s = Hook.step(mission.i)
			if s then
				refs.card.Desc.Text = stepText(s)
			end
		end
	end)
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for _, root in { refs.card, refs.welcome, refs.complete } do
			local g = root and root:FindFirstChild("Glow")
			local spin = g and g:FindFirstChild("Spin")
			if spin then
				spin.Rotation = (t * 120) % 360
			end
		end
		stepWorld(t)
	end)
	player.CharacterRemoving:Connect(function()
		if world then
			world.arrow.Enabled = false
		end
	end)
	-- (a new match: the guide is rebuilt fresh, in the new arena)
	workspace:GetAttributeChangedSignal("MapKey"):Connect(clearWorld)
end

return HookController
