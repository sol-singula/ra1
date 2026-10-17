--[[
The first-minute tutorial, the show (TutorialService on the server decides who gets it and saves when it's done).

When the server says { kind = "start" } and you're standing in the arena:

  1. The intro, a short cinematic (about 7 s; Enter, K, Select or the SKIP button skips it after the first second; moving, looking and clicking never do). Letterbox bars, the
     camera sweeps high over the arena (RED ... BLUE, each side's turf rippling in its colour), swoops down onto the
     glowing frontline (THE LINE), skims along it (THIS IS YOUR TURF), rises over your spawn room and drops straight
     into your eyes, looking at the enemy side (TAKE THEIRS). The camera goes back to normal first person after.
  2. The guided steps, one at a time. Each has ONE big short instruction low in the middle, a glowing guide in the
     world (a spot on the floor with a beam and an arrow to it, a marker over the enemy, an arrow along the turf),
     the matching button pulsing, and a payoff when it's done (a big word slamming in, a burst, a shake, a sound, a
     quick zoom). The HUD keeps only what the step needs (Layout.focus).
       build:  PICK A WALL → PLACE IT
       fight:  FIGHT! (the camera turns you to the nearest enemy) → AIM HERE → HOLD TO PULL → LET GO! → HIT THEM →
               KNOCK THEM OUT (the camera follows the line jumping forward: THE LINE MOVED!) → PUSH IT TO THEIR BASE
  3. Tips, each once and only when it fits: 3 = BLADE (an enemy very close), SHIFT = RUN (walking a long while).
  4. Your first win: the camera circles you with confetti (YOU WIN!).

Nothing traps you: every step times out, the timers wait while you're down, a step for the build phase is dropped
once the fight starts, the match never waits for the tutorial, and K (or SKIP) ends it. Phones get tap words (TAP
PLACE, HOLD FIRE), pads their buttons. Reduced Motion: smaller shakes, no zoom punches.

  TutorialController.start(msg)     (the server's start; tests call it too)
  { kind = "intro" } from the server: a returning player's join plays the intro alone (TutorialService.joinIntro)
  TutorialController.skip()         end it now (K, the SKIP button)
  TutorialController.replay()       ask the server to run it again (GOALS → REPLAY)
  TutorialController.state() -> { running, step, intro, cinema, text, history = { { name, how } } }
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Structures = require(ReplicatedStorage.Shared.Data.Structures)
local ArenaBuilder = require(ReplicatedStorage.Shared.World.ArenaBuilder)
local Bus = require(script.Parent.Parent.UI.Bus)
local Device = require(script.Parent.Parent.UI.Device)
local Layout = require(script.Parent.Parent.UI.Layout)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)
local AudioController = require(script.Parent.AudioController)
local BuildController = require(script.Parent.BuildController)
local CameraController = require(script.Parent.CameraController)
local HudController = require(script.Parent.HudController)
local MoveController = require(script.Parent.MoveController)

local TutorialController = { Name = "TutorialController", Order = 70 }

local player = Players.LocalPlayer
local C = Theme.Color
local CELL = Constants.CELL
local V3 = Vector3.new
local BASE_FOV = 80

local refs = {} -- the screen's pieces
TutorialController.refs = refs
local fx -- the world's pieces (a folder in the workspace, this client only)
local run -- the tutorial while it runs: { i, t, gap, built, fired, hit, kill, history, finished }
local cine -- the camera cinematic playing: { t0, dur, drive, finish, skippable, look }
local endCinematic -- (defined with the cinematics below; the phone's SKIP button, built first, calls it)
local session -- after the steps: the tips and the first-win show still watch (until the match ends)
local charge -- the bow's draw (Bus.Charge), nil when not drawing
local punch = 0 -- degrees the lens is punched in (decays)
local history = {}
local introPending -- the server asked for the opening alone (a returning player's join): plays once you're in

-- Little helpers ---------------------------------------------------------------------------------------------
local function now()
	return os.clock()
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function clamp01(x)
	return math.clamp(x, 0, 1)
end

local function smoother(t)
	return t * t * t * (t * (t * 6 - 15) + 10)
end

local function outBack(t)
	local c1 = 1.70158
	return 1 + (c1 + 1) * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end

local function reduced()
	return Theme.reducedMotion()
end

local function by(keyboard, touch, pad)
	local k = Device.kind()
	if k == "touch" then
		return touch or keyboard
	elseif k == "gamepad" then
		return pad or keyboard
	end
	return keyboard
end

local function sound(name, speed)
	pcall(AudioController.play, name, speed)
end

local function shake(strength, seconds)
	CameraController.shake(strength * (reduced() and 0.25 or 1), seconds or 0.3)
end

local function fovPunch(deg)
	if not reduced() then
		punch = deg
	end
end

local function team()
	return Store.team() or player:GetAttribute("Team") or "red"
end

local function teamColor(t)
	return Constants.TEAM_COLOR[t or team()] or C.white
end

-- your own base's side along X (-1 red, +1 blue)
local function side()
	return team() == "red" and -1 or 1
end

local function body()
	local c = player.Character
	return c, c and c:FindFirstChild("HumanoidRootPart"), c and c:FindFirstChild("Head")
end

local function eye()
	local _, root, head = body()
	if head then
		return head.Position
	elseif root then
		return root.Position + V3(0, 1.5, 0)
	end
	return nil
end

local function alive()
	return (Store.get("me") or {}).alive == true and body() ~= nil
end

local function phase()
	return Store.phase()
end

local function playing()
	local p = phase()
	return p == "build" or p == "fight"
end

-- The arena as the client sees it: the turf strips, its half length and width
local function arena()
	local m = Store.get("match") or {}
	local a = workspace:FindFirstChild("Arena")
	local turf = a and a:FindFirstChild("Turf")
	local strips = {}
	if turf then
		for _, p in turf:GetChildren() do
			if p:IsA("BasePart") then
				table.insert(strips, p)
			end
		end
	end
	table.sort(strips, function(x, y)
		return x.Position.X < y.Position.X
	end)
	local edge = math.abs(m.loseBlue or 80)
	local half, width = edge + 20, 96
	if #strips > 0 then
		half = math.max(math.abs(strips[1].Position.X), math.abs(strips[#strips].Position.X)) + CELL / 2
		width = strips[1].Size.Z
	end
	return { strips = strips, half = half, width = width, edge = edge, front = m.frontline or 0 }
end

-- The enemies standing: every character on the other team (people and bots), their root parts
local function enemies()
	local out = {}
	local mine = team()
	local function consider(c)
		if not c or c == player.Character then
			return
		end
		local r = c:FindFirstChild("HumanoidRootPart")
		local hum = c:FindFirstChildOfClass("Humanoid")
		local t = c:GetAttribute("Team")
		if r and t and t ~= mine and (not hum or (hum.Health or 0) > 0) then
			table.insert(out, r)
		end
	end
	for _, p in Players:GetPlayers() do
		consider(p.Character)
	end
	local bots = workspace:FindFirstChild("Bots")
	for _, c in bots and bots:GetChildren() or {} do
		consider(c)
	end
	return out
end

local function nearestEnemy()
	local e = eye()
	if not e then
		return nil
	end
	local best, bestD
	for _, r in enemies() do
		local d = (r.Position - e).Magnitude
		if not bestD or d < bestD then
			best, bestD = r, d
		end
	end
	return best, bestD
end

-- Animations (own clock, so they run the same everywhere): fn(a) with a from 0 to 1, then done()
local anims = {}

local function animate(seconds, fn, done)
	local a = { t0 = now(), dur = math.max(seconds, 1e-3), fn = fn, done = done }
	table.insert(anims, a)
	return a
end

local function after(seconds, fn)
	return animate(seconds, nil, fn)
end

local function stepAnims()
	local t = now()
	local i = 1
	while i <= #anims do
		local a = anims[i]
		local f = (t - a.t0) / a.dur
		if f >= 1 then
			table.remove(anims, i)
			if a.fn then
				a.fn(1)
			end
			if a.done then
				a.done()
			end
		else
			if a.fn then
				a.fn(f)
			end
			i += 1
		end
	end
end

-- The world's pieces -------------------------------------------------------------------------------------------
local function part(name, size, color, transparency)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Size = size
	p.Color = color
	p.Transparency = transparency or 0
	p.CFrame = CFrame.new(0, -50, 0)
	p.Parent = fx
	return p
end

-- The turf ripples: a light sheet over each strip, lit as a wave passes ({ x0, x1, t0, dur, color })
local overlay = {} -- [i] = the sheet over strip i
local overlayFor -- the strip list they were made for
local ripples = {}
local rippleDirty = false -- (a sheet is still lit)

local function ripple(x0, x1, color, seconds)
	table.insert(ripples, { x0 = x0, x1 = x1, t0 = now(), dur = seconds or 0.8, color = color })
end

-- a side's turf lights up, from the line out to its end
local function rippleSide(t)
	local A = arena()
	local s = t == "red" and -1 or 1
	ripple(A.front, s * A.half, teamColor(t), 0.9)
end

local function stepRipples()
	if #ripples == 0 and not rippleDirty then
		return
	end
	rippleDirty = #ripples > 0
	local A = arena()
	if overlayFor ~= A.strips[1] then
		for _, p in overlay do
			p:Destroy()
		end
		overlay = {}
		overlayFor = A.strips[1]
		for i, strip in A.strips do
			overlay[i] = part("TurfGlow", V3(CELL - 0.1, 0.1, A.width), C.white, 1)
			overlay[i].CFrame = CFrame.new(strip.Position.X, 0.06, strip.Position.Z)
		end
	end
	local t = now()
	local lit = {}
	for k = #ripples, 1, -1 do
		local r = ripples[k]
		local f = (t - r.t0) / r.dur
		if f >= 1.4 then
			table.remove(ripples, k)
		else
			local front = lerp(r.x0, r.x1, clamp01(f))
			local lo, hi = math.min(r.x0, r.x1), math.max(r.x0, r.x1)
			for i, strip in A.strips do
				local x = strip.Position.X
				if x >= lo - CELL and x <= hi + CELL then
					local d = (x - front) / 7
					local v = math.exp(-d * d) * (1 - clamp01((f - 1) / 0.4))
					-- (a soft afterglow behind the wave)
					local behind = (r.x1 >= r.x0 and x < front or r.x1 < r.x0 and x > front) and 0.25 or 0
					v = math.max(v, behind * (1 - clamp01(f / 1.4)))
					if not lit[i] or v > lit[i].v then
						lit[i] = { v = v, color = r.color }
					end
				end
			end
		end
	end
	for i, sheet in overlay do
		local l = lit[i]
		sheet.Transparency = l and (1 - 0.8 * l.v) or 1
		if l then
			sheet.Color = l.color
		end
	end
end

-- The line's glow: a bright sheet on the frontline that can slide (the knockout) and pulse (the intro)
local lineGlow
local function glowLine(x, strength)
	local A = arena()
	if not lineGlow then
		lineGlow = part("LineGlow", V3(0.8, 10, A.width), C.white, 1)
	end
	lineGlow.Size = V3(0.8 + strength * 1.2, 10, A.width)
	lineGlow.CFrame = CFrame.new(x, 5, 0)
	lineGlow.Transparency = 1 - 0.85 * clamp01(strength)
end

-- A spot on the floor to build on: four glowing edges, a slab and a beam of light
local spot

local function showSpot(center, w, d, color)
	if not spot then
		spot = { bars = {} }
		for i = 1, 4 do
			spot.bars[i] = part("SpotEdge", V3(1, 1, 1), color)
		end
		spot.slab = part("SpotSlab", V3(1, 0.1, 1), color, 0.6)
		spot.beam = part("SpotBeam", V3(0.6, 30, 0.6), color, 0.4)
	end
	spot.center, spot.w, spot.d = center, w, d
	for _, p in { spot.bars[1], spot.bars[2], spot.bars[3], spot.bars[4], spot.slab, spot.beam } do
		p.Color = color
	end
end

local function hideSpot()
	if spot then
		for _, p in spot.bars do
			p:Destroy()
		end
		spot.slab:Destroy()
		spot.beam:Destroy()
		spot = nil
	end
end

local function stepSpot(t)
	if not spot then
		return
	end
	local k = 1 + (reduced() and 0 or 0.12 * math.sin(t * 6))
	local hw, hd, th = spot.w / 2 * k, spot.d / 2 * k, 0.45
	local c = spot.center
	local b = spot.bars
	b[1].Size, b[1].CFrame = V3(hw * 2 + th, 0.3, th), CFrame.new(c + V3(0, 0.15, -hd))
	b[2].Size, b[2].CFrame = V3(hw * 2 + th, 0.3, th), CFrame.new(c + V3(0, 0.15, hd))
	b[3].Size, b[3].CFrame = V3(th, 0.3, hd * 2 + th), CFrame.new(c + V3(-hw, 0.15, 0))
	b[4].Size, b[4].CFrame = V3(th, 0.3, hd * 2 + th), CFrame.new(c + V3(hw, 0.15, 0))
	spot.slab.Size, spot.slab.CFrame = V3(spot.w, 0.1, spot.d), CFrame.new(c + V3(0, 0.08, 0))
	spot.slab.Transparency = 0.6 + 0.15 * math.sin(t * 6)
	spot.beam.CFrame = CFrame.new(c + V3(0, 15, 0))
	spot.beam.Transparency = 0.45 + 0.2 * math.sin(t * 4)
end

-- An arrow of chevrons along the floor, sliding toward where to go
local path
local CHEVRONS = 18
local GAP = 3.2

local function showPath(from, to, color)
	path = path or { chev = {} }
	path.from, path.to, path.color = from, to, color
end

local function hidePath()
	if path then
		for _, c in path.chev do
			c[1]:Destroy()
			c[2]:Destroy()
		end
		path = nil
	end
end

local function stepPath(t)
	if not path then
		return
	end
	local a = V3(path.from.X, 0.14, path.from.Z)
	local b = V3(path.to.X, 0.14, path.to.Z)
	local d = b - a
	local len = d.Magnitude
	local dir = len > 0.01 and d.Unit or V3(1, 0, 0)
	local shift = reduced() and 0 or (t * 7) % GAP
	for i = 1, CHEVRONS do
		local c = path.chev[i]
		if not c then
			c = { part("Chevron", V3(0.45, 0.14, 2.2), path.color), part("Chevron", V3(0.45, 0.14, 2.2), path.color) }
			path.chev[i] = c
		end
		local s = (i - 1) * GAP + shift + 2
		if s < len - 1 then
			local p = a + dir * s
			local yaw = CFrame.lookAt(p, p + dir)
			c[1].CFrame = yaw * CFrame.Angles(0, math.rad(40), 0) * CFrame.new(0, 0, 0.9)
			c[2].CFrame = yaw * CFrame.Angles(0, math.rad(-40), 0) * CFrame.new(0, 0, 0.9)
			local fade = math.min(1, s / 4, (len - s) / 4)
			for _, q in c do
				q.Transparency = 1 - 0.9 * clamp01(fade)
				q.Color = path.color
			end
		else
			c[1].Transparency, c[2].Transparency = 1, 1
		end
	end
end

-- A marker over an enemy: a big bobbing arrow (always on top)
local mark, markOn

local function showMark(target)
	if not target then
		return
	end
	if not mark or not mark.Parent then
		mark = Theme.new("BillboardGui", {
			Name = "TutorialMark",
			ResetOnSpawn = false, -- (kept through a respawn: the first death mustn't take the marker with it)
			Size = UDim2.fromOffset(120, 120),
			AlwaysOnTop = true,
			LightInfluence = 0,
			StudsOffset = V3(0, 5, 0),
			Parent = player:FindFirstChild("PlayerGui"),
		})
		Theme.title({
			Name = "Arrow",
			Text = "▼",
			Size = UDim2.fromScale(1, 0.7),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = teamColor(Formulas.enemyOf(team())),
			outline = 4,
			Parent = mark,
		})
		Theme.title({
			Name = "Ring",
			Text = "◎",
			Position = UDim2.fromScale(0, 0.62),
			Size = UDim2.fromScale(1, 0.38),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = C.white,
			outline = 2,
			Parent = mark,
		})
	end
	mark.Adornee = target
	mark.Enabled = true
	mark.Arrow.TextColor3 = teamColor(Formulas.enemyOf(team()))
	markOn = target
end

local function hideMark()
	if mark then
		mark.Enabled = false
		mark.Adornee = nil
	end
	markOn = nil
end

-- Bursts: cubes flying out of a point in the world, and bits flying across the screen
local function burstWorld(at, color, n)
	n = n or (Device.isTouch() and 12 or 20)
	for i = 1, n do
		local dir = V3(math.random() - 0.5, math.random() * 0.9 + 0.2, math.random() - 0.5)
		dir = dir.Magnitude > 0.01 and dir.Unit or V3(0, 1, 0)
		local c = (i % 4 == 0) and C.white or color
		local p = part("Burst", V3(0.8, 0.8, 0.8), c)
		p.CFrame = CFrame.new(at)
		local vel = dir * (20 + math.random() * 18)
		local life = 0.7 + math.random() * 0.5
		local pos = at
		local last = 0
		animate(life, function(a)
			local dt = (a - last) * life
			last = a
			vel = vel + V3(0, -45 * dt, 0)
			pos = pos + vel * dt
			p.CFrame = CFrame.new(pos) * CFrame.Angles(a * 6, a * 4, 0)
			p.Transparency = a * a
		end, function()
			p:Destroy()
		end)
	end
end

local function burstScreen(color, y)
	local gui = refs.gui
	if not gui then
		return
	end
	local n = Device.isTouch() and 14 or 22
	for i = 1, n do
		local ang = (i / n) * math.pi * 2 + math.random() * 0.3
		local speed = 260 + math.random() * 220
		local size = 8 + math.random() * 10
		local bit = Theme.new("Frame", {
			Name = "Bit",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, y or 0.42, 0),
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = (i % 3 == 0) and C.white or color,
			BorderSizePixel = 0,
			Parent = gui,
		})
		local vx, vy = math.cos(ang) * speed, math.sin(ang) * speed - 120
		animate(0.75, function(a)
			local t = a * 0.75
			bit.Position = UDim2.new(0.5, vx * t, y or 0.42, vy * t + 380 * t * t)
			bit.Rotation = a * 360
			bit.BackgroundTransparency = a * a
		end, function()
			bit:Destroy()
		end)
	end
end

-- The screen's pieces ---------------------------------------------------------------------------------------------
-- The big title (the cinematics and the payoffs): it slams in from huge with a shake and a punch of the lens
local titleToken

local function slam(text, color, hold, opts)
	opts = opts or {}
	local t = refs.title
	if not t then
		return
	end
	local sc = t.Slam
	local stroke = t:FindFirstChild("TextStroke")
	local token = {}
	titleToken = token
	t.Text = text
	t.TextColor3 = color or C.white
	t.Position = UDim2.fromScale(0.5, opts.y or 0.42)
	t.Visible = true
	local from = reduced() and 1.15 or (opts.big or 2.6)
	animate(0.2, function(a)
		if titleToken == token then
			sc.Scale = lerp(from, 1, outBack(a))
			t.TextTransparency = 1 - a
			t.Rotation = (1 - a) * (opts.tilt or -6)
			if stroke then
				stroke.Transparency = 1 - a
			end
		end
	end, function()
		if titleToken ~= token then
			return
		end
		shake(opts.shake or 0.4, opts.shakeFor or 0.3)
		fovPunch(opts.punch or -7)
		if opts.sound ~= false then
			sound(opts.sound or "hit", opts.pitch or 0.8)
		end
		after(hold or 0.9, function()
			if titleToken ~= token then
				return
			end
			animate(0.25, function(a)
				if titleToken == token then
					sc.Scale = 1 + a * 0.15
					t.TextTransparency = a
					if stroke then
						stroke.Transparency = a
					end
				end
			end, function()
				if titleToken == token then
					t.Visible = false
				end
			end)
		end)
	end)
end

-- The one instruction, low in the middle (nil: none)
local saying, sayToken

local function say(text, hint)
	local l = refs.say
	if not l then
		return
	end
	refs.hint.Text = hint or ""
	refs.hint.Visible = text ~= nil and hint ~= nil and hint ~= ""
	if text == saying then
		return
	end
	saying = text
	if not text then
		l.Visible = false
		return
	end
	l.Text = text
	l.Visible = true
	local token = {}
	sayToken = token
	animate(0.25, function(a)
		if sayToken == token then
			l.Pop.Scale = lerp(reduced() and 1 or 1.8, 1, outBack(a))
			l.TextTransparency = 1 - a
		end
	end)
	sound("tick", 1.25)
end

-- A small tip, once (3 = BLADE, SHIFT = RUN)
local function tip(text)
	local l = refs.tip
	l.Text = text
	l.Visible = true
	l.Pop.Scale = reduced() and 1 or 1.5
	animate(0.2, function(a)
		l.Pop.Scale = lerp(reduced() and 1 or 1.5, 1, outBack(a))
	end)
	sound("tick", 1.5)
	after(3.2, function()
		if l.Text == text then
			l.Visible = false
		end
	end)
end

-- A HUD button pulses (the tray's wall, PLACE, FIRE, the blade, RUN)
local glowing = {} -- [button] = its glow

local function glow(button, only)
	if only then
		for b, g in glowing do
			if b ~= button then
				g:Destroy()
				glowing[b] = nil
			end
		end
	end
	if not button or glowing[button] then
		return
	end
	glowing[button] = Theme.new("Frame", {
		Name = "TutorialGlow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 12, 1, 12),
		BackgroundTransparency = 1,
		Parent = button,
	}, { Theme.corner(8), Theme.new("UIStroke", { Name = "Ring", Thickness = 4, Color = teamColor() }) })
end

local function unglow()
	for _, g in glowing do
		g:Destroy()
	end
	glowing = {}
end

local function stepGlow(t)
	local k = reduced() and 0.5 or (0.5 + 0.5 * math.sin(t * 8))
	for b, g in glowing do
		if not b.Parent then
			g:Destroy()
			glowing[b] = nil
		else
			g.Size = UDim2.new(1, 10 + k * 12, 1, 10 + k * 12)
			g.Ring.Transparency = 0.1 + k * 0.4
			g.Ring.Color = teamColor()
		end
	end
end

-- The letterbox: black bars in from the top and bottom
local function bars(on)
	local top, bottom = refs.barTop, refs.barBottom
	local from = top.Size.Y.Scale
	local to = on and 0.11 or 0
	animate(on and 0.35 or 0.3, function(a)
		local h = lerp(from, to, smoother(a))
		top.Size = UDim2.new(1, 0, h, 0)
		bottom.Size = UDim2.new(1, 0, h, 0)
	end)
end

local function hud()
	return HudController.refs or {}
end

local function buildGui()
	local pg = player:WaitForChild("PlayerGui")
	local gui = Theme.screen("Tutorial", 30, pg)
	refs.gui = gui
	-- the letterbox covers the whole screen, under Roblox's top bar and the phone's notch too
	local box = Theme.new("ScreenGui", {
		Name = "Letterbox",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None,
		DisplayOrder = 29,
		Parent = pg,
	})
	refs.barTop = Theme.new("Frame", {
		Name = "BarTop",
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundColor3 = C.ink,
		BorderSizePixel = 0,
		Parent = box,
	})
	refs.barBottom = Theme.new("Frame", {
		Name = "BarBottom",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundColor3 = C.ink,
		BorderSizePixel = 0,
		Parent = box,
	})
	refs.skipHint = Theme.text({
		Name = "SkipHint",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(320, 20),
		fit = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.grey,
		Visible = false,
		Parent = gui,
	})
	-- (a phone's way to skip a cinematic: a button, so dragging to look around never skips it)
	refs.skipCine = Theme.new("TextButton", {
		Name = "SkipCinematic",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(110, 40),
		BackgroundColor3 = C.white,
		Text = "SKIP  ›",
		Font = Theme.Display,
		TextSize = 18,
		TextColor3 = C.ink,
		AutoButtonColor = true,
		Visible = false,
		Parent = gui,
	}, { Theme.corner(6), Theme.stroke(2, C.ink) })
	refs.skipCine.Activated:Connect(function()
		if cine and cine.skippable and now() - cine.t0 >= 1 then
			endCinematic(true)
		end
	end)
	refs.title = Theme.title({
		Name = "Title",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(1000, 150),
		fit = 132,
		TextXAlignment = Enum.TextXAlignment.Center,
		outline = 5,
		Visible = false,
		Parent = gui,
	})
	Theme.new("UIScale", { Name = "Slam", Parent = refs.title })
	refs.say = Theme.title({
		Name = "Say",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.66),
		Size = UDim2.fromOffset(700, 76),
		fit = 64,
		TextXAlignment = Enum.TextXAlignment.Center,
		outline = 4,
		Visible = false,
		Parent = gui,
	})
	Theme.new("UIScale", { Name = "Pop", Parent = refs.say })
	refs.hint = Theme.title({
		Name = "Hint",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.66, 40),
		Size = UDim2.fromOffset(420, 22),
		fit = 17,
		TextXAlignment = Enum.TextXAlignment.Center,
		outline = 2,
		Visible = false,
		Parent = gui,
	})
	refs.tip = Theme.title({
		Name = "Tip",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.79),
		Size = UDim2.fromOffset(360, 30),
		fit = 26,
		TextXAlignment = Enum.TextXAlignment.Center,
		outline = 3,
		Visible = false,
		Parent = gui,
	})
	Theme.new("UIScale", { Name = "Pop", Parent = refs.tip })
	-- the charge ring round the crosshair: dots that light up as you pull
	refs.ring = Theme.new("Frame", {
		Name = "Ring",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(120, 120),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	refs.dots = {}
	for i = 1, 24 do
		local a = (i - 1) / 24 * math.pi * 2 - math.pi / 2
		refs.dots[i] = Theme.new("Frame", {
			Name = "Dot",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, math.cos(a) * 54, 0.5, math.sin(a) * 54),
			Size = UDim2.fromOffset(8, 8),
			BackgroundColor3 = C.ink,
			BackgroundTransparency = 0.7,
			BorderSizePixel = 0,
			Parent = refs.ring,
		}, { Theme.corner("round") })
	end
	-- (the invite button's corner: it hides while the tutorial guides)
	refs.skip = Theme.new("TextButton", {
		Name = "Skip",
		Position = UDim2.fromOffset(16, 16),
		Size = UDim2.fromOffset(190, 28),
		BackgroundColor3 = C.white,
		BackgroundTransparency = 0.3,
		Text = "",
		AutoButtonColor = true,
		Visible = false,
		Parent = gui,
	}, { Theme.corner(4), Theme.stroke(1, C.muted) })
	Theme.text({
		Name = "Label",
		Text = "SKIP TUTORIAL",
		Position = UDim2.fromOffset(6, 3),
		Size = UDim2.new(1, -12, 1, -6),
		fit = 13,
		Font = Theme.Display,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.muted,
		Parent = refs.skip,
	})
	refs.skip.Activated:Connect(function()
		TutorialController.skip()
	end)
end

-- Cinematics -------------------------------------------------------------------------------------------------------
-- The camera is handed to drive(cam, t, dt) for `seconds`; then it's given back (CameraController.release), looking
-- along cine.look. opts: bars (the letterbox), hideHud, skippable (Enter / K / Select / SKIP after a second)
function endCinematic(skipped)
	local c = cine
	if not c then
		return
	end
	cine = nil
	if c.bars then
		bars(false)
	end
	refs.skipHint.Visible = false
	refs.skipCine.Visible = false
	Layout.cinema(false)
	CameraController.release(c.look)
	if c.finish then
		c.finish(skipped == true)
	end
end

local function cinematic(seconds, drive, finish, opts)
	opts = opts or {}
	if cine then
		endCinematic(true)
	end
	cine = {
		t0 = now(),
		dur = seconds,
		drive = drive,
		finish = finish,
		bars = opts.bars ~= false,
		skippable = opts.skippable == true,
		look = nil,
	}
	local mine = cine
	if mine.bars then
		bars(true)
	end
	Layout.cinema(opts.hideHud ~= false)
	CameraController.takeover(function(cam, dt)
		if cine ~= mine then
			return
		end
		local t = now() - mine.t0
		mine.drive(cam, t, dt)
		if t >= mine.dur then
			endCinematic(false)
		end
	end)
end

local function catmull(p0, p1, p2, p3, t)
	local t2, t3 = t * t, t * t * t
	return (p1 * 2 + (p2 - p0) * t + (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t2 + (p1 * 3 - p0 - p2 * 3 + p3) * t3) * 0.5
end

local function val(v)
	if type(v) == "function" then
		return v()
	end
	return v
end

-- Along keyframes { t, pos, look, fov } (pos and look can be functions: where you are right now)
local function along(keys, t)
	local n = #keys
	if t >= keys[n].t then
		local k = keys[n]
		return val(k.pos), val(k.look), k.fov
	end
	local i = 1
	while i < n - 1 and t >= keys[i + 1].t do
		i += 1
	end
	local a = clamp01((t - keys[i].t) / (keys[i + 1].t - keys[i].t))
	local e = a * 0.3 + smoother(a) * 0.7
	local k0, k1, k2, k3 = keys[math.max(i - 1, 1)], keys[i], keys[i + 1], keys[math.min(i + 2, n)]
	local pos = catmull(val(k0.pos), val(k1.pos), val(k2.pos), val(k3.pos), e)
	local look = catmull(val(k0.look), val(k1.look), val(k2.look), val(k3.look), e)
	return pos, look, lerp(k1.fov, k2.fov, e)
end

local function aimCam(cam, pos, look, fov)
	if (look - pos).Magnitude < 0.01 then
		look = pos + V3(0, 0, -1)
	end
	cam.CFrame = CFrame.lookAt(pos, look)
	cam.FieldOfView = fov + punch
end

-- The intro: RED ... BLUE ... THE LINE ... THIS IS YOUR TURF ... TAKE THEIRS
local INTRO_SECONDS = 7.6

local function playIntro(onDone)
	local A = arena()
	local s, F, half, W = side(), A.front, A.half, A.width
	local mine = team()
	local enemy = Formulas.enemyOf(mine)
	local _, root = body()
	local hz = root and root.Position.Z or 0
	local ahead = V3(-s, 0, 0) -- (toward the enemy)
	local function me()
		return eye() or V3(s * (half - 6), 4.6, hz)
	end
	local keys = {
		{ t = 0, pos = V3(-half * 0.85, 62, W * 0.8), look = V3(-half * 0.4, 0, 0), fov = 60 },
		{ t = 1.8, pos = V3(half * 0.85, 62, W * 0.8), look = V3(half * 0.4, 0, 0), fov = 60 },
		{ t = 3.1, pos = V3(F, 15, W * 0.6), look = V3(F, 1, 0), fov = 72 },
		{ t = 4.4, pos = V3(F + s * 6, 5, -W * 0.2), look = V3(s * half * 0.55, 1, -W * 0.05), fov = 76 },
		{
			t = 5.8,
			pos = function()
				return V3(s * (half - 9), 32, hz + 16)
			end,
			look = me,
			fov = 64,
		},
		{
			t = 6.9,
			pos = me,
			look = function()
				return me() + ahead * 30
			end,
			fov = BASE_FOV,
		},
	}
	local beats = {
		{
			0.3,
			function()
				slam("RED", teamColor("red"), 0.8, { sound = "tick", pitch = 0.7 })
				rippleSide("red")
			end,
		},
		{
			1.45,
			function()
				slam("BLUE", teamColor("blue"), 0.8, { sound = "tick", pitch = 0.7 })
				rippleSide("blue")
			end,
		},
		{
			2.95,
			function()
				slam("THE LINE", C.white, 0.8, { sound = "tick", pitch = 0.9, shake = 0.3 })
				animate(1.6, function(a)
					glowLine(F, math.sin(a * math.pi) * (0.6 + 0.4 * math.sin(a * 20)))
				end, function()
					glowLine(F, 0)
				end)
			end,
		},
		{
			4.15,
			function()
				slam("THIS IS YOUR TURF", teamColor(mine), 1.0, { sound = "built", pitch = 0.9 })
				ripple(F, s * half, teamColor(mine), 0.8)
			end,
		},
		{
			6.75,
			function()
				slam(
					"TAKE THEIRS",
					teamColor(enemy),
					0.6,
					{ sound = "horn", pitch = 1, shake = 0.8, punch = -14, big = 3.2 }
				)
				ripple(F, -s * half, teamColor(enemy), 0.7)
			end,
		},
	}
	local fired = 0
	cinematic(INTRO_SECONDS, function(cam, t)
		while beats[fired + 1] and t >= beats[fired + 1][1] do
			fired += 1
			beats[fired][2]()
		end
		local pos, look, fov = along(keys, t)
		aimCam(cam, pos, look, fov)
		refs.skipHint.Visible = t >= 1
		refs.skipCine.Visible = t >= 1 and Device.isTouch()
		cine.look = ahead
	end, onDone, { bars = true, skippable = true })
	cine.look = ahead
	refs.skipHint.Text = by("PRESS ENTER TO SKIP", "TAP SKIP TO SKIP", "PRESS SELECT TO SKIP")
end

-- FIGHT!: the camera turns you to the nearest enemy and zooms in a little
local function nudge(target, onDone)
	local cam = workspace.CurrentCamera
	local look0 = cam.CFrame.LookVector
	slam("FIGHT!", teamColor(), 0.7, { sound = "horn", pitch = 1, shake = 0.7, punch = -10, big = 3 })
	cinematic(1.1, function(c, t)
		local e = eye() or c.CFrame.Position
		local want = look0
		if target and target.Parent then
			local to = target.Position + V3(0, 1, 0) - e
			if to.Magnitude > 0.1 then
				want = to.Unit
			end
		end
		local a = smoother(clamp01(t / 0.55))
		local look = look0:Lerp(want, a)
		if look.Magnitude < 0.01 then
			look = want
		end
		local z = (t < 0.55) and smoother(t / 0.55) or (1 - smoother(clamp01((t - 0.75) / 0.35)))
		aimCam(c, e, e + look.Unit * 20, BASE_FOV - 18 * z * (reduced() and 0.3 or 1))
		cine.look = want
	end, onDone, { bars = false, hideHud = false })
end

-- THE LINE MOVED!: up and out to watch the line jump toward them, a shockwave along the turf, and back in
local function lineMoved(oldF, newF, onDone)
	local mine = team()
	local color = teamColor(mine)
	local _, root = body()
	local z = root and root.Position.Z or 0
	local cam = workspace.CurrentCamera
	local look0 = cam.CFrame.LookVector
	local mid = (oldF + newF) / 2
	local high = V3(mid - Formulas.forward(mine) * 14, 18, z + 26)
	local shocked = false
	cinematic(2.6, function(c, t)
		local e = eye() or c.CFrame.Position
		local k = smoother(clamp01(t / 0.5)) * (1 - smoother(clamp01((t - 2.0) / 0.6)))
		local lineX = lerp(oldF, newF, smoother(clamp01((t - 0.5) / 0.6)))
		if t >= 0.5 and not shocked then
			shocked = true
			ripple(oldF, newF + Formulas.forward(mine) * 24, color, 0.6)
			slam("THE LINE MOVED!", color, 1.0, { sound = "kill", pitch = 0.7, shake = 0.8, punch = -12, big = 3 })
		end
		glowLine(lineX, t > 0.4 and t < 2.0 and (0.6 + 0.4 * math.sin(t * 25)) or 0)
		local pos = e:Lerp(high, k)
		local at = (e + look0 * 20):Lerp(V3(lineX, 1, z), k)
		aimCam(c, pos, at, lerp(BASE_FOV, 66, k))
		cine.look = look0
	end, function(skipped)
		glowLine(newF, 0)
		if onDone then
			onDone(skipped)
		end
	end, { bars = true, hideHud = true })
end

-- YOU WIN!: the camera circles you, confetti everywhere
local function victoryShow(onDone)
	local mine = team()
	local color = teamColor(mine)
	local _, root = body()
	local cam = workspace.CurrentCamera
	local l = cam.CFrame.LookVector
	local a0 = math.atan2(-l.Z, -l.X)
	slam("YOU WIN!", color, 2.4, { sound = "win", pitch = 1, shake = 0.8, punch = -14, big = 3.4 })
	local nextBurst = 0
	cinematic(5, function(c, t)
		local _, r = body()
		local center = r and r.Position or (root and root.Position) or V3(0, 3, 0)
		local ang = a0 + t * 0.9
		local rad = lerp(9, 15, smoother(clamp01(t / 5)))
		local pos = center + V3(math.cos(ang) * rad, 3 + t * 0.8, math.sin(ang) * rad)
		aimCam(c, pos, center + V3(0, 1.5, 0), 70)
		if t >= nextBurst and t < 4.2 then
			nextBurst = t + 0.6
			local off = V3((math.random() - 0.5) * 16, 8 + math.random() * 6, (math.random() - 0.5) * 16)
			burstWorld(center + off, (math.random() < 0.5) and color or C.white, 14)
		end
		cine.look = l
	end, onDone, { bars = true, hideHud = true, skippable = true })
	burstScreen(color, 0.42)
end

-- The steps ----------------------------------------------------------------------------------------------------------
local function report(name, how)
	table.insert(history, { name = name, how = how })
	if run then
		table.insert(run.history, { name = name, how = how })
	end
	pcall(Net.send, "Tutorial", "step", name, how)
end

local function wallKey()
	return Structures.get("wall") and "wall" or Structures.list[1].key
end

-- The boxes in the way of building: the map's solid shapes (once per map) and the structures standing
local solidsFor, solids

local function boxesOf(folder, out)
	for _, d in folder and folder:GetDescendants() or {} do
		if d:IsA("BasePart") and d.CanCollide then
			local mn, mx = ArenaBuilder.aabbOf(d.CFrame, d.Size)
			table.insert(out, { mn, mx })
		end
	end
	return out
end

local function clear(mn, mx)
	local a = workspace:FindFirstChild("Arena")
	if a ~= solidsFor then
		solidsFor = a
		solids = boxesOf(a and a:FindFirstChild("Map"), {})
	end
	local lo, hi = mn + V3(0.05, 0.6, 0.05), mx - V3(0.05, 0, 0.05)
	for _, list in { solids, boxesOf(workspace:FindFirstChild("Structures"), {}) } do
		for _, b in list do
			if Formulas.boxesOverlap(lo, hi, b[1], b[2]) then
				return false
			end
		end
	end
	return true
end

-- Where to build: a few cells back from the line on your side, near where you stand, a spot that's free
local function buildSpot(key)
	local A = arena()
	local def = Structures.get(key) or Structures.get(wallKey())
	local fwd = Formulas.forward(team())
	local _, root = body()
	local z0 = math.clamp(root and root.Position.Z or 0, -A.width / 2 + 10, A.width / 2 - 10)
	local w, d = Structures.footprint(def, 0)
	for _, dz in { 0, 8, -8, 16, -16, 24, -24, 32, -32 } do
		for back = 3, 9 do
			local x = A.front - fwd * back * CELL
			local z = math.clamp(z0 + dz, -A.width / 2 + 6, A.width / 2 - 6)
			local cx, cz = Formulas.cellOf(x - (w - 1) * CELL / 2, z - (d - 1) * CELL / 2)
			local mn, mx = Formulas.footprintBox(cx, cz, w, d, 0, def.h)
			if BuildController.check(def.key, cx, cz, 0) and clear(mn, mx) then
				return V3((mn.X + mx.X) / 2, 0, (mn.Z + mx.Z) / 2), w * CELL, d * CELL
			end
		end
	end
	return V3(A.front - fwd * 4 * CELL, 0, z0), w * CELL, d * CELL
end

local function lookingAt(target, degrees)
	local cam = workspace.CurrentCamera
	local e = cam and cam.CFrame.Position
	if not e or not target then
		return false
	end
	local to = target.Position + V3(0, 1, 0) - e
	if to.Magnitude < 0.1 then
		return true
	end
	return cam.CFrame.LookVector:Dot(to.Unit) >= math.cos(math.rad(degrees))
end

local function payoff(word, color, at)
	slam(word, color or C.white, 0.7, { shake = 0.55, punch = -12, sound = "kill", pitch = 1.25, big = 3 })
	burstScreen(color or C.white, 0.42)
	if at then
		burstWorld(at, color or C.white)
	end
end

-- Each step: name, phase, timeout, enter(), tick(dt) (what to say and show), done() -> true | "how", win(how)
local STEPS = {
	{
		name = "pick",
		phase = "build",
		timeout = 18,
		enter = function()
			if Device.kind() == "gamepad" and not BuildController.picked() then
				BuildController.pick(wallKey()) -- (no tray on a pad: it's picked for you)
			end
		end,
		tick = function()
			local key = wallKey()
			local slot = Structures.get(key).order
			say(by("PICK A WALL", "TAP A WALL"), by(`press {slot}`, "", ""))
			glow((hud().trayButtons or {})[key], true)
		end,
		done = function()
			return BuildController.picked() ~= nil
		end,
		win = function()
			shake(0.15, 0.15)
			sound("tick", 1.6)
		end,
	},
	{
		name = "place",
		phase = "build",
		timeout = 30,
		tick = function(st)
			local picked = BuildController.picked()
			if (st.spotAt or 0) < now() then
				st.spotAt = now() + 1
				st.center, st.w, st.d = buildSpot(picked or wallKey())
				showSpot(st.center, st.w, st.d, teamColor())
			end
			local _, root = body()
			if root then
				showPath(root.Position, st.center, teamColor())
			end
			if not picked then
				say(by("PICK A WALL", "TAP A WALL"))
				glow((hud().trayButtons or {})[wallKey()], true)
			else
				say(by("PLACE IT", "TAP PLACE", "PRESS R2"), by("aim at the glow and click", "aim at the glow", ""))
				glow(Device.isTouch() and (hud().touch or {}).place or nil, true)
			end
		end,
		done = function()
			return run.built
		end,
		win = function(_, st)
			payoff("NICE!", teamColor(), st.center)
			sound("built", 1)
		end,
		leave = function()
			hideSpot()
			hidePath()
		end,
	},
	{
		name = "fight",
		phase = "fight",
		timeout = 4,
		enter = function(st)
			st.target = nearestEnemy()
			st.nudged = false
			nudge(st.target, function()
				st.nudged = true
			end)
		end,
		tick = function()
			say(nil)
		end,
		done = function(st)
			return st.nudged
		end,
	},
	{
		name = "aim",
		phase = "fight",
		timeout = 7,
		tick = function(st)
			st.target = nearestEnemy()
			showMark(st.target)
			say("AIM HERE")
		end,
		done = function(st)
			return st.target ~= nil and lookingAt(st.target, 9)
		end,
		win = function()
			sound("tick", 1.8)
		end,
	},
	{
		name = "draw",
		phase = "fight",
		timeout = 15,
		enter = function()
			run.fired = false
		end,
		tick = function()
			showMark((nearestEnemy()))
			say(by("HOLD TO PULL", "HOLD FIRE", "HOLD R2"), by("hold the mouse", "", ""))
			refs.ring.Visible = true
			glow(Device.isTouch() and (hud().touch or {}).fire or nil, true)
		end,
		done = function()
			if (charge or 0) >= 0.85 then
				return "full"
			elseif run.fired then
				return "early"
			end
			return false
		end,
	},
	{
		name = "release",
		phase = "fight",
		timeout = 8,
		tick = function()
			showMark((nearestEnemy()))
			say("LET GO!")
			refs.ring.Visible = true
		end,
		done = function()
			return run.fired
		end,
		win = function()
			shake(0.2, 0.15)
		end,
	},
	{
		name = "hit",
		phase = "fight",
		timeout = 45,
		tick = function()
			showMark((nearestEnemy()))
			say("HIT THEM")
			refs.ring.Visible = charge ~= nil
		end,
		done = function()
			return run.hit ~= nil
		end,
		win = function()
			payoff("HIT!", teamColor(Formulas.enemyOf(team())), run.hitAt)
		end,
	},
	{
		name = "knockout",
		phase = "fight",
		timeout = 60,
		tick = function()
			showMark((nearestEnemy()))
			say("KNOCK THEM OUT")
			refs.ring.Visible = charge ~= nil
		end,
		done = function()
			return run.kill ~= nil
		end,
		win = function()
			hideMark()
			unglow()
			say(nil)
			local k = run.kill
			lineMoved(k.from, k.to)
		end,
	},
	{
		name = "push",
		phase = "fight",
		timeout = 8,
		tick = function()
			local A = arena()
			local _, root = body()
			local z = root and root.Position.Z or 0
			local fwd = Formulas.forward(team())
			showPath(V3(A.front - fwd * 6, 0, z), V3(fwd * A.edge, 0, z), teamColor())
			say("PUSH IT TO THEIR BASE")
		end,
		done = function(st)
			return st.t >= 5.5 and "seen"
		end,
		leave = function()
			hidePath()
		end,
	},
}
TutorialController.STEPS = STEPS

local function clearGuides()
	say(nil)
	hideSpot()
	hidePath()
	hideMark()
	unglow()
	refs.ring.Visible = false
end

local function finishRun(how)
	if not run or run.finished then
		return
	end
	run.finished = true
	local st = run.state
	local step = STEPS[run.i]
	if step and step.leave and st then
		step.leave(st)
	end
	clearGuides()
	Layout.focus(false)
	refs.skip.Visible = false
	if how == "skip" then
		session = nil
		pcall(Net.send, "Tutorial", "skip", step and step.name or "intro")
	else
		session = { tips = {}, walk = 0 }
		pcall(Net.send, "Tutorial", "done")
	end
end

-- end it now (K, the SKIP button)
function TutorialController.skip()
	if not run or run.finished then
		return false
	end
	if cine then
		endCinematic(true)
	end
	finishRun("skip")
	return true
end

function TutorialController.replay()
	pcall(Net.send, "Tutorial", "replay")
end

function TutorialController.start(msg)
	if run and not run.finished then
		return false
	end
	msg = msg or {}
	run = {
		i = 0, -- (0: the intro, once you're standing in the arena)
		t = 0,
		gap = 0,
		history = {},
		boost = msg.boost == true,
		replay = msg.replay == true,
	}
	session = nil
	return true
end

function TutorialController.state()
	local step = run and not run.finished and STEPS[run.i]
	return {
		running = run ~= nil and not run.finished,
		step = step and step.name or (run and not run.finished and run.i == 0 and "intro" or nil),
		intro = run ~= nil and run.introPlaying == true,
		cinema = cine ~= nil,
		text = saying,
		history = history,
		session = session ~= nil,
	}
end

-- Each frame: the step that's on, its guides, its payoff -----------------------------------------------------------
local function advance(how)
	local step = STEPS[run.i]
	local st = run.state
	if step then
		if step.leave then
			step.leave(st)
		end
		report(step.name, how ~= true and how or nil)
		if how ~= "timeout" and how ~= "missed" and step.win then
			step.win(how, st)
		end
	end
	unglow()
	hideMark()
	refs.ring.Visible = false
	say(nil)
	run.i += 1
	run.state = nil
	run.gap = (how == "timeout" or how == "missed") and 0.3 or 0.9
	if run.i > #STEPS then
		finishRun("done")
	end
end

local function stepRun(dt)
	if run.i == 0 then
		-- the intro, once you're standing in the arena
		if not run.introPlaying and alive() and playing() then
			run.introPlaying = true
			Layout.focus(true)
			playIntro(function(skipped)
				run.introPlaying = false
				report("intro", skipped and "skip" or nil)
				run.i = 1
				run.gap = 0.5
				refs.skip.Label.Text = by("K · SKIP TUTORIAL", "SKIP TUTORIAL", "SELECT · SKIP")
			end)
		end
		return
	end
	local p = phase()
	if p == "victory" or p == "loading" then
		finishRun("done") -- (the match ended first: they played it)
		return
	end
	local step = STEPS[run.i]
	if not step then
		return
	end
	if step.phase == "build" and p == "fight" then
		advance("missed") -- (the build phase is over)
		return
	end
	if not alive() or (step.phase and step.phase ~= p) then
		-- (down, or waiting for the fight: the step waits, its clock too)
		clearGuides()
		return
	end
	if run.gap > 0 then
		run.gap -= dt
		return
	end
	local st = run.state
	if not st then
		st = { t = 0 }
		run.state = st
		if step.enter then
			step.enter(st)
		end
		if cine then
			return
		end
	end
	st.t += dt
	step.tick(st, dt)
	local how = step.done(st)
	if how then
		advance(how)
	elseif st.t >= step.timeout then
		advance("timeout")
	end
end

-- The tips and the first-win watch, after the steps (once each, only when they fit)
local function stepTips(dt)
	if not session or cine or phase() ~= "fight" or not alive() then
		return
	end
	local kind = Device.kind()
	local me = Store.get("me") or {}
	local _, d = nearestEnemy()
	if
		not session.tips.blade
		and kind ~= "gamepad"
		and workspace:GetAttribute("Charge") == true -- (the blade is only out in the CHARGE)
		and d
		and d < 14
		and me.weapon ~= "blade"
	then
		session.tips.blade = true
		tip(by("3 = BLADE", "TAP BLADE"))
		local b = (hud().bows or {}).blade
		glow(b and b.button)
		after(3.2, unglow)
		report("tip_blade")
	end
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	local moving = hum and (hum.MoveDirection or Vector3.zero).Magnitude > 0.1
	if moving and not MoveController.sprinting() and charge == nil then
		session.walk += dt
	end
	if not session.tips.run and session.walk >= 8 then
		session.tips.run = true
		tip(by("SHIFT = RUN", "TAP RUN", "L3 = RUN"))
		glow(Device.isTouch() and (hud().touch or {}).sprint or nil)
		after(3.2, unglow)
		report("tip_run")
	end
end

local function frame(dt)
	local t = now()
	stepAnims()
	stepRipples()
	stepSpot(t)
	stepPath(t)
	stepGlow(t)
	-- the lens punch eases out; outside a cinematic it goes through the first-person camera
	punch *= math.exp(-dt * 7)
	if math.abs(punch) < 0.05 then
		punch = 0
	end
	CameraController.setFov("tutorial", (not cine and punch ~= 0) and punch or nil)
	if mark and markOn then
		mark.StudsOffset = V3(0, 5 + (reduced() and 0 or 0.6 * math.sin(t * 6)), 0)
	end
	if refs.ring.Visible then
		local c = charge or 0
		local lit = math.floor(c * 24 + 0.5)
		for i, d in refs.dots do
			d.BackgroundColor3 = c >= 0.85 and teamColor(Formulas.enemyOf(team())) or C.ink
			d.BackgroundTransparency = i <= lit and 0 or 0.7
			d.Size = UDim2.fromOffset(i <= lit and 11 or 8, i <= lit and 11 or 8)
		end
	end
	if introPending and not cine and not (run and not run.finished) and alive() and playing() then
		-- the opening alone: RED, BLUE, THE LINE, YOUR TURF, and down into your eyes
		introPending = false
		Layout.focus(true)
		playIntro(function()
			Layout.focus(false)
		end)
	elseif run and not run.finished and not cine then
		stepRun(dt)
	elseif not run or run.finished then
		stepTips(dt)
	end
	-- (SKIP shows while the steps guide, not over a cinematic's letterbox)
	refs.skip.Visible = run ~= nil and not run.finished and run.i > 0 and cine == nil
end

function TutorialController:init()
	buildGui()
	fx = Instance.new("Folder")
	fx.Name = "TutorialFx"
	fx.Parent = workspace
	Net.listen("Tutorial", function(msg)
		if type(msg) ~= "table" then
			return
		end
		if msg.kind == "start" then
			TutorialController.start(msg)
		elseif msg.kind == "intro" and not (run and not run.finished) then
			introPending = true
		elseif msg.kind == "built" and run then
			run.built = true
		end
	end)
	Bus.Charge:Connect(function(c)
		charge = c
	end)
	Bus.Fired:Connect(function()
		if run then
			run.fired = true
		end
	end)
	Net.listen("Hit", function(h)
		if type(h) == "table" and h.parry then
			return -- (a parry isn't a hit on them)
		end
		if run and not run.finished and not run.hit then
			run.hit = h
			-- (where they stood: the burst goes there)
			for _, r in enemies() do
				local c = r.Parent
				local who = Players:GetPlayerFromCharacter(c)
				if
					(who and who.UserId == h.victim) or (not who and c and c.Parent == workspace:FindFirstChild("Bots"))
				then
					run.hitAt = r.Position + V3(0, 1, 0)
				end
			end
		end
	end)
	Net.listen("Kill", function(k)
		if run and not run.finished and not run.kill and k.killer == player.UserId and (k.push or 0) > 0 then
			local to = k.frontline or (Store.get("match") or {}).frontline or 0
			local from = to - Formulas.forward(k.killerTeam or team()) * k.push
			run.kill = { from = from, to = to }
		end
	end)
	Net.listen("Results", function(r)
		local won = r and r.you and r.you.won
		if (session or (run and not run.finished)) and won then
			if run and not run.finished then
				finishRun("done")
			end
			session = nil
			task.defer(function()
				victoryShow(function()
					report("win")
				end)
			end)
		elseif session then
			session = nil
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		-- only a deliberate key skips a cinematic (after its first second): Enter or K, Select on a pad (a phone
		-- has its SKIP button). Moving, looking, clicking or dragging never does: new players press those at once,
		-- and the intro used to end right after RED and BLUE.
		local k = input.KeyCode
		local isSkip = k == Enum.KeyCode.Return or k == Enum.KeyCode.K or k == Enum.KeyCode.ButtonSelect
		if cine and cine.skippable and isSkip and now() - cine.t0 >= 1 then
			endCinematic(true)
			return
		end
		if processed or not run or run.finished then
			return
		end
		if input.KeyCode == Enum.KeyCode.K or input.KeyCode == Enum.KeyCode.ButtonSelect then
			TutorialController.skip()
		end
	end)
	RunService.RenderStepped:Connect(frame)
end

return TutorialController
