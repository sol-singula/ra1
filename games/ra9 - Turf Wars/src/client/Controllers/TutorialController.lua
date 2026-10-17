--[[
The new-player tutorial, the show: a private practice of about 2:15 that ends in a WIN (TutorialService on the server
decides who gets it, takes them out of the match, pays the Shards and joins them to the live match after).

When the server says { kind = "start", practice = { origin, team, ... } } this client draws the practice arena far
out past the match (World/Practice: nobody else is sent a part of it), its bots (puppets drawn here, slow and shaky,
that never hurt you: their arrows only ever just miss) and what you build, keeps the HUD fed with the practice's
own state (the match's never reaches you: Net.hush), and runs the steps:

  0:00 intro        letterbox, a sweep over the small arena (THIS IS YOUR TURF … THE LINE … TAKE THEIRS) and down
                    into your eyes
  0:08 first_kill   one bot walks slowly at you ~15 studs off; HOLD… LET GO! (any release hits: heavy aim help);
                    the arrow in slow motion, a freeze on the hit, the kill effect close up, KNOCKOUT!
  0:15 multi_kill   two side by side: DOUBLE KILL! TRIPLE KILL! (bigger each time, the Shards fly into the
                    counter), then the camera follows the line jumping forward: THE LINE MOVED!
  0:33 near_miss    at once the camera's (letterbox, your shots held): it turns to an archer, who draws fast and
                    looses; the arrow whips just past your head in slow motion: THEY SHOOT BACK. BUILD COVER! (~5 s)
  0:38 build        BUILD TIME: NO SHOOTING and the build tray at once (the wall pulsing in it), a quick look up
                    over the line while you pick; PICK A WALL → PLACE IT: one wall is all it asks (any wall you put
                    up counts; the clock waits until then); ADD ANOTHER IF YOU LIKE while the clock runs, then three
                    bot arrows thud into your wall
  1:00 tnt          a bot lobs TNT at your wall, followed in slow motion, and it blows: THAT'S TNT. YOURS FOREVER
                    IN THE SHOP. (the TNT's slot glows: no popup)
  1:16 push         a wave of four: every knockout jumps the line, a short kill cam each, 2 MORE TO WIN!
  1:54 win          the last one in slow motion, the camera pulls out and circles you, fireworks
                    (FireworksController.show), VICTORY!, the Shards counting up, a free trail; THE REAL GAME STARTS
                    NOW and you walk through the gate (a fade to white) into the live match. The white stays up (the
                    practice's show all cleared away) until the server joins you: if the live match is between games
                    (its victory, its loading) that waits, a calm NEXT MATCH STARTING… card on it, for the next one

Each step has ONE big short instruction low in the middle, a guide in the world (a spot on the floor with a beam and
an arrow to it, a marker over the target), the button it needs pulsing, and a payoff. Words by device: tap words on
a phone (TAP A WALL, HOLD FIRE), pad buttons on a gamepad (R2), keys on a keyboard.

Nothing traps you: every step times out and does its part for you (the shot, the piece), the whole show stays under
3:00 (and the server ends it there regardless), and after the intro SKIP (K, Select, the button) drops you straight
into the live match. Reduced Motion: smaller shakes, no lens punches.

After it, in the live match: two tips, once each, when they fit (3 = BLADE close in the CHARGE, SHIFT = RUN).

  TutorialController.start(msg)     (the server's start; tests call it too)
  { kind = "intro" } from the server: a returning player's join plays the intro alone (TutorialService.joinIntro)
  TutorialController.skip()         end it now (K, the SKIP button): into the live match
  TutorialController.replay()       ask the server to run it again (GOALS → REPLAY)
  TutorialController.state() -> { running, step, intro, cinema, text, history = { { name, how, t } }, practice,
                                  kills, front, elapsed }
  TutorialController.practice()     the practice while it's on: { origin, team, world, front, kills, bots, built }
  TutorialController.cinematic()    true while one of its camera shows plays (the kill cam waits)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local StructureModel = require(ReplicatedStorage.Shared.StructureModel)
local Structures = require(ReplicatedStorage.Shared.Data.Structures)
local Weapons = require(ReplicatedStorage.Shared.Data.Weapons)
local Practice = require(ReplicatedStorage.Shared.World.Practice)
local Effects = require(script.Parent.Parent.FX.Effects)
local KillEffects = require(script.Parent.Parent.FX.KillEffects)
local Bus = require(script.Parent.Parent.UI.Bus)
local Device = require(script.Parent.Parent.UI.Device)
local Layout = require(script.Parent.Parent.UI.Layout)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)
local ArrowController = require(script.Parent.ArrowController)
local AudioController = require(script.Parent.AudioController)
local BuildController = require(script.Parent.BuildController)
local CameraController = require(script.Parent.CameraController)
local DebrisController = require(script.Parent.DebrisController)
local ExplosionController = require(script.Parent.ExplosionController)
local FireworksController = require(script.Parent.FireworksController)
local HudController = require(script.Parent.HudController)
local KillFxController = require(script.Parent.KillFxController)
local MoveController = require(script.Parent.MoveController)
local WeaponController = require(script.Parent.WeaponController)

-- (a match's: not in the lobby, which has its own screens)
local TutorialController = { Name = "TutorialController", Order = 70, Modes = { "turf", "ctf", "brawl" } }

local player = Players.LocalPlayer
local C = Theme.Color
local CELL = Constants.CELL
local V3 = Vector3.new
local BASE_FOV = 80
local GOLD = Color3.fromRGB(255, 200, 40)
local LATE = 145 -- seconds in: any step not yet begun is passed over and the win hurries (the show stays under 3:00)
local FINISH_BY = 170 -- the victory's camera show is cut to end the win by about here

local refs = {} -- the screen's pieces
TutorialController.refs = refs
local fx -- the world's pieces (a folder in the workspace, this client only)
local run -- the tutorial while it runs: { i, state, gap, history, finished }
local pr -- the practice while it's on: { origin, team, world, front, kills, bots, built, phase, ends, hold, t0 }
local cine -- the camera cinematic playing: { t0, dur, drive, finish, skippable, look }
local endCinematic -- (defined with the cinematics below; the phone's SKIP button, built first, calls it)
local session -- after the practice: the tips still watch, in the live match
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

local function sound(name, speed, volume)
	pcall(AudioController.play, name, speed, volume)
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
	return (pr and pr.team) or Store.team() or player:GetAttribute("Team") or "red"
end

local function enemyTeam()
	return Formulas.enemyOf(team())
end

local function teamColor(t)
	return Constants.TEAM_COLOR[t or team()] or C.white
end

-- your own base's side along X (-1 red, +1 blue), and the way you push (+1 red, -1 blue)
local function side()
	return team() == "red" and -1 or 1
end

local function fwd()
	return Formulas.forward(team())
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
	if pr then
		return body() ~= nil
	end
	return (Store.get("me") or {}).alive == true and body() ~= nil
end

local function phase()
	return Store.phase()
end

local function playing()
	local p = phase()
	return p == "build" or p == "fight"
end

local function elapsed()
	return pr and (now() - pr.t0) or 0
end

local function hud()
	return HudController.refs or {}
end

-- The arena as this client sees it: the practice's while it's on (else the match's), its strips, half length,
-- width, the lose line, the line and the middle along Z
local function arena()
	if pr then
		return {
			strips = pr.world.strips,
			half = Practice.HALF,
			width = Practice.WIDTH,
			edge = Practice.EDGE,
			front = pr.front,
			z = pr.origin.Z,
		}
	end
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
	return { strips = strips, half = half, width = width, edge = edge, front = m.frontline or 0, z = 0 }
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

local function clearOverlay()
	for _, p in overlay do
		p:Destroy()
	end
	overlay = {}
	overlayFor = nil
	ripples = {}
end

local function stepRipples()
	if #ripples == 0 and not rippleDirty then
		return
	end
	rippleDirty = #ripples > 0
	local A = arena()
	if overlayFor ~= A.strips[1] then
		clearOverlay()
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

-- The line's glow: a bright sheet on the frontline that can slide (a knockout) and pulse (the intro)
local lineGlow
local function glowLine(x, strength)
	local A = arena()
	if not lineGlow or not lineGlow.Parent then
		lineGlow = part("LineGlow", V3(0.8, 10, A.width), C.white, 1)
	end
	lineGlow.Size = V3(0.8 + strength * 1.2, 10, A.width)
	lineGlow.CFrame = CFrame.new(x, 5, A.z)
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

-- A marker over a target: a big bobbing arrow (always on top)
local mark, markOn

local function showMark(target)
	if not target then
		return
	end
	if not mark or not mark.Parent then
		mark = Theme.new("BillboardGui", {
			Name = "TutorialMark",
			ResetOnSpawn = false,
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
			TextColor3 = teamColor(enemyTeam()),
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
	mark.Arrow.TextColor3 = teamColor(enemyTeam())
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
	sound("count", 1.25, 0.6)
end

-- A small line, once (3 = BLADE, SHIFT = RUN, why a piece can't go there)
local function tip(text)
	local l = refs.tip
	l.Text = text
	l.Visible = true
	l.Pop.Scale = reduced() and 1 or 1.5
	animate(0.2, function(a)
		l.Pop.Scale = lerp(reduced() and 1 or 1.5, 1, outBack(a))
	end)
	sound("count", 1.5, 0.5)
	after(3.2, function()
		if l.Text == text then
			l.Visible = false
		end
	end)
end

-- A HUD button pulses (the tray's wall, PLACE, FIRE, the TNT, the blade, RUN)
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

-- The fade to white (into the live match) and back (the latest one wins: a fade back never fights one still going in)
local fadeToken

local function fade(to, seconds, done)
	local f = refs.fade
	local from = f.BackgroundTransparency
	local token = {}
	fadeToken = token
	f.Visible = true
	animate(seconds or 0.5, function(a)
		if fadeToken == token then
			f.BackgroundTransparency = lerp(from, to, smoother(a))
		end
	end, function()
		if fadeToken ~= token then
			return
		end
		f.Visible = to < 0.999
		if done then
			done()
		end
	end)
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
	refs.fade = Theme.new("Frame", {
		Name = "Fade",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.white,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 10,
		Parent = box,
	})
	-- (on the white while the live match is between games: a calm card, no slam, no sound)
	refs.waitCard = Theme.title({
		Name = "NextMatch",
		Text = "NEXT MATCH STARTING…",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(640, 60),
		fit = 44,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.ink,
		outline = false,
		Visible = false,
		ZIndex = 11,
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
		Size = UDim2.fromOffset(760, 80),
		fit = 66,
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
		Position = UDim2.new(0.5, 0, 0.66, 42),
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
	-- the free trail at the win: a card under the title
	refs.reward = Theme.new("Frame", {
		Name = "Reward",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.64),
		Size = UDim2.fromOffset(380, 104),
		BackgroundColor3 = C.ink,
		Visible = false,
		Parent = gui,
	}, { Theme.corner(8), Theme.stroke(3, GOLD) })
	Theme.new("UIScale", { Name = "Pop", Parent = refs.reward })
	refs.rewardHead = Theme.title({
		Name = "Head",
		Text = "FREE TRAIL!",
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = GOLD,
		outline = false,
		Parent = refs.reward,
	})
	refs.rewardLine = Theme.text({
		Name = "Line",
		Text = "",
		Position = UDim2.fromOffset(12, 46),
		Size = UDim2.new(1, -24, 0, 26),
		fit = 22,
		Font = Theme.Display,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.white,
		Parent = refs.reward,
	})
	refs.rewardSub = Theme.text({
		Name = "Sub",
		Text = "Yours for good, on your arrows now",
		Position = UDim2.fromOffset(12, 76),
		Size = UDim2.new(1, -24, 0, 18),
		fit = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.grey,
		Parent = refs.reward,
	})
	-- (the invite button's corner: it hides while the tutorial guides) big enough for a thumb
	refs.skip = Theme.new("TextButton", {
		Name = "Skip",
		Position = UDim2.fromOffset(16, 16),
		Size = UDim2.fromOffset(200, 44),
		BackgroundColor3 = C.white,
		BackgroundTransparency = 0.25,
		Text = "",
		AutoButtonColor = true,
		Visible = false,
		Parent = gui,
	}, { Theme.corner(6), Theme.stroke(1, C.muted) })
	Theme.text({
		Name = "Label",
		Text = "SKIP TUTORIAL",
		Position = UDim2.fromOffset(6, 4),
		Size = UDim2.new(1, -12, 1, -8),
		fit = 15,
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
-- along cine.look. opts: bars (the letterbox), hideHud, skippable (Enter / K / Select / SKIP after a second),
-- noShots (your shots are held while it plays: onShot takes them and nothing flies)
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
	Effects.timeScale = 1
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
		noShots = opts.noShots == true,
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
		if t >= mine.dur and cine == mine then
			endCinematic(false)
		end
	end)
	return mine
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

-- The intro: THIS IS YOUR TURF … THE LINE … TAKE THEIRS, and down into your eyes
local INTRO_SECONDS = 8

local function playIntro(onDone)
	local A = arena()
	local s, F, half, W, Z = side(), A.front, A.half, A.width, A.z
	local mine = team()
	local enemy = Formulas.enemyOf(mine)
	local _, root = body()
	local hz = root and root.Position.Z or Z
	local ahead = V3(-s, 0, 0) -- (toward the enemy)
	local function me()
		return eye() or V3(-s * Practice.START, 4.6, hz)
	end
	local keys = {
		{ t = 0, pos = V3(s * half * 0.9, 44, Z + W * 1.1), look = V3(s * half * 0.3, 0, Z), fov = 62 },
		{ t = 2.4, pos = V3(s * half * 0.2, 34, Z + W * 0.95), look = V3(F, 0, Z), fov = 64 },
		{ t = 3.9, pos = V3(F, 12, Z + W * 0.55), look = V3(F, 1, Z), fov = 72 },
		{ t = 5.5, pos = V3(F - s * 10, 14, Z - W * 0.35), look = V3(-s * half * 0.6, 1, Z), fov = 70 },
		{
			t = 6.6,
			pos = function()
				return me() + V3(s * 10, 12, 6)
			end,
			look = me,
			fov = 66,
		},
		{
			t = 7.4,
			pos = me,
			look = function()
				return me() + ahead * 30
			end,
			fov = BASE_FOV,
		},
	}
	local beats = {
		{
			0.4,
			function()
				slam("THIS IS YOUR TURF", teamColor(mine), 1.6, { sound = "built", pitch = 0.9 })
				rippleSide(mine)
			end,
		},
		{
			3.2,
			function()
				slam("THE LINE", C.white, 0.9, { sound = "count", pitch = 0.9, shake = 0.3 })
				animate(1.6, function(a)
					glowLine(F, math.sin(a * math.pi) * (0.6 + 0.4 * math.sin(a * 20)))
				end, function()
					glowLine(F, 0)
				end)
			end,
		},
		{
			5.0,
			function()
				slam(
					"TAKE THEIRS",
					teamColor(enemy),
					1.0,
					{ sound = "horn", pitch = 1, shake = 0.8, punch = -14, big = 3.2 }
				)
				rippleSide(enemy)
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

-- The camera turns you to a target and zooms in a little (seconds)
local function nudge(target, seconds, onDone)
	local cam = workspace.CurrentCamera
	local look0 = cam.CFrame.LookVector
	seconds = seconds or 0.8
	cinematic(seconds, function(c, t)
		local e = eye() or c.CFrame.Position
		local want = look0
		local at = typeof(target) == "Vector3" and target or (target and target.Parent and target.Position)
		if at then
			local to = at + V3(0, 0.4, 0) - e
			if to.Magnitude > 0.1 then
				want = to.Unit
			end
		end
		local a = smoother(clamp01(t / (seconds * 0.7)))
		local look = look0:Lerp(want, a)
		if look.Magnitude < 0.01 then
			look = want
		end
		local z = math.sin(clamp01(t / seconds) * math.pi)
		aimCam(c, e, e + look.Unit * 20, BASE_FOV - 12 * z * (reduced() and 0.3 or 1))
		cine.look = want
	end, onDone, { bars = false, hideHud = false })
end

-- THE LINE MOVED!: up and out to watch the line jump toward them, a shockwave along the turf, and back in
local function lineMoved(oldF, newF, onDone)
	local mine = team()
	local color = teamColor(mine)
	local _, root = body()
	local z = root and root.Position.Z or arena().z
	local cam = workspace.CurrentCamera
	local look0 = cam.CFrame.LookVector
	local mid = (oldF + newF) / 2
	local high = V3(mid - Formulas.forward(mine) * 14, 18, z + 22)
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

-- The practice ------------------------------------------------------------------------------------------------------
-- The HUD reads the practice's own state (the match's never reaches this client while it's on)
local function pushMatch()
	if not pr then
		return
	end
	local n = 0
	for _, b in pr.bots do
		if b.alive then
			n += 1
		end
	end
	Store.set("match", {
		phase = pr.phase,
		ends = pr.ends,
		map = "practice",
		mapName = "PRACTICE",
		tagline = "Your own private arena",
		frontline = pr.front,
		loseRed = -Practice.EDGE,
		loseBlue = Practice.EDGE,
		width = Practice.WIDTH,
		push = Practice.PUSH,
		red = team() == "red" and 1 or n,
		blue = team() == "blue" and 1 or n,
		matchId = -1,
		practice = true,
	})
end

local function setPhase(p, seconds, hold)
	pr.phase = p
	pr.hold = hold
	pr.ends = workspace:GetServerTimeNow() + (hold or seconds or 0)
	pushMatch()
end

-- The bots: puppets in the enemy's colour, drawn here only. They walk slowly up to a little past the line, sway as
-- they go (shaky), face you, and never hurt anyone.
local function botFolder()
	local f = pr.world.folder:FindFirstChild("Bots")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Bots"
		f.Parent = pr.world.folder
	end
	return f
end

local function puppet(x, dz, opts)
	opts = opts or {}
	local color = teamColor(enemyTeam())
	local model = Instance.new("Model")
	model.Name = "PracticeBot"
	local b = {
		model = model,
		x = x,
		z = pr.origin.Z + dz,
		keep = opts.keep or 11, -- (studs past the line it walks up to)
		speed = opts.speed or 2.6,
		alive = true,
		seed = math.random() * 10,
		draw = 0, -- (0..1: the bow raised)
	}
	local function limb(name, size, c)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Material = Enum.Material.SmoothPlastic
		p.Size = size
		p.Color = c
		p.Parent = model
		return p
	end
	b.torso = limb("Torso", V3(2, 2, 1), color)
	b.head = limb("Head", V3(1.25, 1.25, 1.25), Constants.WHITE)
	b.la = limb("Left Arm", V3(1, 2, 1), color)
	b.ra = limb("Right Arm", V3(1, 2, 1), color)
	b.ll = limb("Left Leg", V3(1, 2, 1), Constants.WHITE)
	b.rl = limb("Right Leg", V3(1, 2, 1), Constants.WHITE)
	b.bow = limb("Bow", V3(0.25, 3.4, 0.25), C.ink)
	b.parts = { b.torso, b.head, b.la, b.ra, b.ll, b.rl, b.bow }
	model.PrimaryPart = b.torso
	model:SetAttribute("BotId", -900 - #pr.bots)
	model:SetAttribute("Team", enemyTeam())
	model.Parent = botFolder()
	table.insert(pr.bots, b)
	return b
end

local function stepBots(dt)
	if not pr then
		return
	end
	local t = now()
	local f = fwd()
	local _, root = body()
	for _, b in pr.bots do
		if b.alive then
			local goal = pr.front + f * b.keep
			local dx = goal - b.x
			local moving = math.abs(dx) > 0.2
			if moving then
				b.x += math.sign(dx) * math.min(math.abs(dx), b.speed * dt)
			end
			-- (never on your side of the line)
			if (b.x - pr.front) * f < 3 then
				b.x = pr.front + f * 3
			end
			b.z += math.sin(t * 1.7 + b.seed) * 0.5 * dt
			local at = V3(b.x, 3, b.z)
			local to = root and V3(root.Position.X, 3, root.Position.Z) or at - V3(f, 0, 0)
			if (to - at).Magnitude < 0.1 then
				to = at - V3(f, 0, 0)
			end
			local sway = math.sin(t * 2.3 + b.seed) * 0.07
			local base = CFrame.lookAt(at, to) * CFrame.Angles(0, 0, sway)
			local swing = moving and math.sin(t * 7 + b.seed) * 0.55 or 0
			local raise = b.draw * math.pi / 2
			b.torso.CFrame = base
			b.head.CFrame = base * CFrame.new(0, 1.65, 0)
			b.la.CFrame = base * CFrame.new(-1.5, 0.6, 0) * CFrame.Angles(swing + raise, 0, 0) * CFrame.new(0, -0.6, 0)
			b.ra.CFrame = base
				* CFrame.new(1.5, 0.6, 0)
				* CFrame.Angles(-swing + raise * 0.9, 0, 0)
				* CFrame.new(0, -0.6, 0)
			b.ll.CFrame = base * CFrame.new(-0.5, -1, 0) * CFrame.Angles(-swing, 0, 0) * CFrame.new(0, -1, 0)
			b.rl.CFrame = base * CFrame.new(0.5, -1, 0) * CFrame.Angles(swing, 0, 0) * CFrame.new(0, -1, 0)
			b.bow.CFrame = b.la.CFrame * CFrame.new(0, -1.1, -0.3)
		end
	end
end

local function liveBots()
	local out = {}
	for _, b in pr and pr.bots or {} do
		if b.alive then
			table.insert(out, b)
		end
	end
	return out
end

-- The enemies standing: every character on the other team (people and bots), their root parts (the practice: its
-- puppets' bodies)
local function enemies()
	local out = {}
	if pr then
		for _, b in liveBots() do
			table.insert(out, b.torso)
		end
		return out
	end
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

-- The line moves a knockout's worth toward their base: the turf repainted, a ripple running over it
local function moveLine()
	local f = fwd()
	local old = pr.front
	pr.front = f * Practice.PUSH * math.min(pr.kills, Practice.KILLS)
	Practice.paint(pr.world, pr.front, team())
	ripple(old, pr.front + f * 12, teamColor(), 0.6)
	animate(0.6, function(a)
		glowLine(lerp(old, pr.front, smoother(a)), math.sin(a * math.pi))
	end, function()
		glowLine(pr.front, 0)
	end)
	pushMatch()
	return old
end

local onKill -- fn(bot) for the step that's on (set with the steps)

-- A bot knocked out: it shatters (its parts into shards along the arrow), your kill effect plays on it, the hit
-- marker, the sound and the screen's pop; the line moves; the server pays the Shards (they fly into the counter)
local function knockOut(b, dir)
	if not b.alive then
		return
	end
	b.alive = false
	local pos = b.torso.Position
	pcall(Effects.shatter, { pos = pos, dir = dir, team = enemyTeam(), parts = b.parts })
	for _, p in b.parts do
		p.Transparency = 1
	end
	local effect = ((Store.get("profile") or {}).equipped or {}).effect
	if effect and Cosmetics.get(effect) then
		pcall(KillEffects.play, effect, pos, team(), { victimTeam = enemyTeam(), dir = dir })
	end
	pcall(HudController.hitMarker, true, false)
	pcall(KillFxController.pop)
	sound("kill", 1)
	pr.kills += 1
	pcall(Net.send, "Tutorial", "kill")
	moveLine()
	after(1.6, function()
		b.model:Destroy()
	end)
	if onKill then
		onKill(b)
	end
end

local function trail()
	return ((Store.get("profile") or {}).equipped or {}).trail
end

-- The velocity that flies an arrow (gravity g) from a to b in T seconds
local function ballistic(a, b, T, g)
	return (b - a) / T + V3(0, 0.5 * g * T, 0)
end

-- Your arrow onto a bot (any release finds one: the heavy aim help). mode: "slow" (followed in slow motion, a freeze
-- on the hit, the kill effect close up), "cam" (a short kill cam after it lands), "quick" (no camera)
local function fireAt(b, start, power, mode, done)
	b.targeted = true
	local aim = b.torso.Position + V3(0, 0.3, 0)
	local w = Weapons.get(Weapons.DEFAULT)
	local speed = Formulas.shot(w, math.max(power or 1, 0.7)).speed
	local T = math.max((aim - start).Magnitude / speed, 0.05)
	local vel = ballistic(start, aim, T, Constants.GRAVITY)
	local key = ArrowController.replay(start, vel, team(), trail())
	local cam = workspace.CurrentCamera
	local look0 = cam and cam.CFrame.LookVector or V3(fwd(), 0, 0)
	local function hit()
		ArrowController.stop(key, aim)
		knockOut(b, vel.Unit)
	end
	if mode == "slow" then
		local FLY, FREEZE, CLOSE = 1.15, 0.4, 1.4
		local hitDone = false
		local side3 = vel.Unit:Cross(V3(0, 1, 0))
		side3 = side3.Magnitude > 0.01 and side3.Unit or V3(0, 0, 1)
		cinematic(FLY + FREEZE + CLOSE, function(c, t)
			if t < FLY then
				local tau = T * smoother(clamp01(t / FLY)) ^ 0.8
				ArrowController.at(key, tau)
				local p = Formulas.arrowAt(start, vel, tau)
				local d = Formulas.arrowVelocity(vel, tau).Unit
				aimCam(c, p - d * 3.5 + side3 * 1.4 + V3(0, 0.7, 0), p + d * 4, 58)
			else
				if not hitDone then
					hitDone = true
					hit()
					Effects.timeScale = 0.05 -- (the freeze frame)
					shake(0.7, 0.3)
					refs.fade.Visible = true
					refs.fade.BackgroundTransparency = 0.35
					fade(1, 0.3)
				end
				local k = t - FLY
				if k >= FREEZE and Effects.timeScale < 0.4 then
					Effects.timeScale = 0.45 -- (the kill effect close up, slowed)
					slam(
						"KNOCKOUT!",
						teamColor(),
						1.1,
						{ sound = "kill", pitch = 0.8, shake = 0.6, punch = -12, big = 3.2 }
					)
					burstScreen(teamColor(), 0.42)
				end
				local ang = k * 0.5
				local off = side3 * math.cos(ang) * 6 - vel.Unit * math.sin(ang) * 2 + V3(0, 1.5, 0)
				aimCam(c, aim + off - vel.Unit * 2, aim, lerp(58, 50, clamp01(k / (FREEZE + CLOSE))))
			end
			cine.look = look0
		end, function()
			if not hitDone then
				hit()
			end
			if done then
				done()
			end
		end, { bars = true, hideHud = true })
		return
	end
	local real = math.max(T, 0.18)
	animate(real, function(a)
		ArrowController.at(key, T * a)
	end, function()
		hit()
		if mode == "cam" then
			-- the short kill cam: the view leans in on them as they shatter, slowed, and back
			Effects.timeScale = 0.4
			cinematic(1.5, function(c, t)
				local e = eye() or c.CFrame.Position
				local k = math.sin(clamp01(t / 1.5) * math.pi)
				aimCam(c, e:Lerp(aim, 0.35 * k), aim:Lerp(e + look0 * 20, 1 - k), BASE_FOV - 26 * k)
				cine.look = look0
			end, done, { bars = false, hideHud = false })
		elseif done then
			done()
		end
	end)
end

-- the bot a shot goes to: the nearest to where you aimed (not one already hit)
local function pickTarget(start, dir)
	local best, bestDot
	for _, b in liveBots() do
		if not b.targeted and not b.waiting then
			local to = b.torso.Position - start
			local dot = to.Magnitude > 0.1 and to.Unit:Dot(dir) or 1
			if not bestDot or dot > bestDot then
				best, bestDot = b, dot
			end
		end
	end
	return best
end

-- An arrow into nothing (shooting while there's nothing to shoot): it flies off and is gone
local function strayArrow(start, dir, power)
	local w = Weapons.get(Weapons.DEFAULT)
	local vel = dir * Formulas.shot(w, power or 1).speed
	local key = ArrowController.replay(start, vel, team(), trail())
	animate(0.9, function(a)
		ArrowController.at(key, a * 0.9)
	end, function()
		ArrowController.stop(key)
	end)
end

-- Any release in the practice: the step that's on decides (shots = { mode }) else it flies off
local function onShot(start, dir, _w, power)
	if not pr then
		return false
	end
	if (cine and cine.noShots) or pr.leaving then
		return true -- (a show that's watching, not shooting: the shot is held, nothing flies)
	end
	local st = run and not run.finished and run.state
	local want = st and st.shots
	local target = want and not cine and pickTarget(start, dir)
	if target then
		st.fired = (st.fired or 0) + 1
		st.idle = 0
		fireAt(target, start, power, want.mode)
	else
		strayArrow(start, dir, power)
	end
	return true
end

-- the tutorial shoots for you (a step timed out): from your eye at the next bot, the same flight
local function autoFire(mode)
	local b = pickTarget(eye() or V3(0, 4, 0), V3(fwd(), 0, 0))
	if b and not cine then
		fireAt(b, (eye() or b.torso.Position) + V3(fwd(), 0, 0), 1, mode)
		return true
	end
	return false
end

-- What you build here: drawn on this client from StructureModel once the server says yes (Net "Tutorial" built)
local function addBuilt(s)
	if not pr or pr.built[s.id] then
		return
	end
	local model = Instance.new("Model")
	model.Name = "Built" .. s.id
	model:SetAttribute("Key", s.key)
	for _, spec in StructureModel.parts(s.key, s.team, s.min, s.max) do
		StructureModel.make(spec, s.team).Parent = model
	end
	model.Parent = pr.world.folder
	pr.built[s.id] = { id = s.id, key = s.key, team = s.team, min = s.min, max = s.max, rot = s.rot, model = model }
	pr.lastBuilt = pr.built[s.id]
	if typeof(s.budget) == "number" then
		Store.merge("me", { budget = s.budget })
	end
	sound("built", 1.1)
end

local function builtOf(key)
	local best
	for _, s in pr and pr.built or {} do
		if (not key or s.key == key) and (not best or s.id < best.id) then
			best = s
		end
	end
	return best
end

-- The practice's own rules for a piece, the same as the server's (TutorialService:_build): your points, inside the
-- field, your own turf, nothing already there. Returns nil when it can go, else why not (in the server's words).
local function practiceWhy(key, cx, cz, rot)
	local def = Structures.get(key)
	if not def or not pr then
		return "No team"
	end
	local w, d = Structures.footprint(def, rot)
	local mn, mx = Formulas.footprintBox(cx, cz, w, d, 0, def.h)
	local z0 = pr.origin.Z
	if ((Store.get("me") or {}).budget or 0) < def.cost then
		return "Not enough build points"
	elseif
		mn.X < -Practice.EDGE
		or mx.X > Practice.EDGE
		or mn.Z < z0 - Practice.WIDTH / 2
		or mx.Z > z0 + Practice.WIDTH / 2
	then
		return "Outside the battlefield"
	elseif (team() == "red" and mx.X > pr.front) or (team() == "blue" and mn.X < pr.front) then
		return "Only on your own turf"
	end
	for _, s in pr.built do
		if Formulas.boxesOverlap(mn + V3(0.05, 0, 0.05), mx - V3(0.05, 0, 0.05), s.min, s.max) then
			return "Something's already there"
		end
	end
	return nil
end

-- Where to build: a cell or so back from the line on your side, level with where you stand, a spot both checks pass
-- (the HUD's and the practice's). Returns its centre, its size along X and Z, and its cell.
local function buildSpot(key, back, rot)
	local A = arena()
	local def = Structures.get(key)
	local f = fwd()
	local _, root = body()
	local lo, hi = A.z - A.width / 2 + 8, A.z + A.width / 2 - 8
	local z0 = math.clamp(root and root.Position.Z or A.z, lo, hi)
	local w, d = Structures.footprint(def, rot)
	for _, ddz in { 0, 6, -6, 12, -12 } do
		for b = back, back + 4 do
			local x = A.front - f * (b + (w - 1) / 2) * CELL
			local z = math.clamp(z0 + ddz, lo, hi)
			local cx, cz = Formulas.cellOf(x - (w - 1) * CELL / 2, z - (d - 1) * CELL / 2)
			local mn, mx = Formulas.footprintBox(cx, cz, w, d, 0, def.h)
			if BuildController.check(key, cx, cz, rot) and not practiceWhy(key, cx, cz, rot) then
				return V3((mn.X + mx.X) / 2, 0, (mn.Z + mx.Z) / 2), w * CELL, d * CELL, cx, cz
			end
		end
	end
	local cx, cz = Formulas.cellOf(A.front - f * (back + 1) * CELL, z0)
	return V3((cx + 0.5) * CELL, 0, (cz + 0.5) * CELL), w * CELL, d * CELL, cx, cz
end

-- Why the piece can't go where you're aiming (nil: it can): the HUD's own check first, then the practice's rules
-- (the HUD's hint for it steps aside while the tutorial guides, so the step says it)
local function aimWhy(key)
	local sp = BuildController.spot()
	if not sp or not pr then
		return nil
	end
	if not sp.ok then
		return sp.why
	end
	return practiceWhy(key, sp.cx, sp.cz, BuildController.rotation())
end

local lastSent = 0 -- (when a piece last went to the server: one in flight is never doubled by the step's timeout)

-- A bot's arrow, drawn here and moved by hand (never a hit): from its bow to `to`, on past it by `beyond` studs,
-- in slow motion (slow, 0..1) for a stretch either side of `to`; stop(at) where it lands
local function botArrow(b, to, beyond, slow, done)
	local from = b.torso.Position + V3(0, 1.4, 0)
	local speed = 150
	local T = (to - from).Magnitude / speed
	local vel = ballistic(from, to, T, Constants.GRAVITY)
	local tEnd = T * (1 + (beyond or 0) / math.max((to - from).Magnitude, 1))
	local key = ArrowController.replay(from, vel, enemyTeam(), nil)
	local tau = 0
	local passed = false
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		local near = slow and math.abs(tau - T) < 0.06
		tau += dt * (near and slow or 1)
		if not passed and tau >= T then
			passed = true
			if beyond and beyond > 0 then
				sound("flyby", 1)
				shake(0.35, 0.25)
				fovPunch(-6)
			end
		end
		ArrowController.at(key, math.min(tau, tEnd))
		if tau >= tEnd then
			conn:Disconnect()
			local at = Formulas.arrowAt(from, vel, tEnd)
			ArrowController.stop(key, at)
			pcall(AudioController.playAt, "impact", at)
			if done then
				done(at)
			end
		end
	end)
	return key
end

-- The TNT: a bundle of red sticks lobbed from a bot onto `target`, followed in slow motion, then the blast (the
-- pieces it reaches come down in debris); fn done() after
local function lobTnt(b, target, done)
	local from = b.torso.Position + V3(0, 2, 0)
	local T = 1.25
	local vel = ballistic(from, target, T, Constants.TNT_GRAVITY)
	local bundle = Instance.new("Model")
	bundle.Name = "PracticeTnt"
	local sticks = {}
	for i, off in { -0.3, 0, 0.3 } do
		local p = part("Stick", V3(0.55, 1.8, 0.55), Constants.TNT_RED)
		p.Material = Enum.Material.SmoothPlastic
		p.Parent = bundle
		sticks[i] = { p, off }
	end
	local spark = part("Fuse", V3(0.4, 0.4, 0.4), GOLD)
	spark.Parent = bundle
	bundle.Parent = fx
	pcall(AudioController.loop, "fuse", true, 0.5)
	local cam = workspace.CurrentCamera
	local look0 = cam and cam.CFrame.LookVector or V3(fwd(), 0, 0)
	local FLY, BOOM = 3.4, 2.6
	local blown = false
	local flat = V3(vel.X, 0, vel.Z)
	flat = flat.Magnitude > 0.01 and flat.Unit or V3(-fwd(), 0, 0)
	local across = flat:Cross(V3(0, 1, 0)).Unit
	cinematic(FLY + BOOM, function(c, t)
		if t < FLY then
			local tau = T * clamp01(t / FLY)
			local p = Formulas.lobAt(from, vel, tau)
			local spin = CFrame.new(p) * CFrame.Angles(tau * 9, tau * 5, 0)
			for _, s in sticks do
				s[1].CFrame = spin * CFrame.new(s[2], 0, 0)
			end
			spark.CFrame = spin * CFrame.new(0, 1.1, 0)
			spark.Transparency = math.random() < 0.5 and 0 or 0.5
			aimCam(c, p - flat * 7 + across * 4 + V3(0, 2.5, 0), p + flat * 3, 62)
		else
			if not blown then
				blown = true
				bundle:Destroy()
				pcall(AudioController.loop, "fuse", false)
				pcall(ExplosionController.blast, {
					pos = target,
					radius = Constants.TNT_RADIUS,
					team = enemyTeam(),
					ground = 0,
				})
				shake(1.2, 0.5)
				Effects.timeScale = 0.35
				for id, s in pr.built do
					if Formulas.boxDistance(target, s.min, s.max) <= Constants.TNT_RADIUS then
						s.model:Destroy()
						pr.built[id] = nil
						pcall(DebrisController.shatter, {
							key = s.key,
							team = s.team,
							min = s.min,
							max = s.max,
							rot = s.rot,
							blast = { pos = target, power = 1, tnt = true },
						})
					end
				end
			end
			local k = t - FLY
			local pos = target - flat * (11 + k * 1.5) + across * 6 + V3(0, 5 + k, 0)
			aimCam(c, pos, target + V3(0, 2, 0), 64)
		end
		cine.look = look0
	end, function()
		if not blown then
			bundle:Destroy()
			pcall(AudioController.loop, "fuse", false)
		end
		if done then
			done()
		end
	end, { bars = true, hideHud = true })
end

-- The gate into the live match: two white piers, a lintel, a glowing veil you walk through
local function showGate(at)
	local f = fwd()
	local gate = Instance.new("Model")
	gate.Name = "PracticeGate"
	local base = CFrame.lookAt(at, at + V3(f, 0, 0))
	for _, dz in { -3.5, 3.5 } do
		local p = part("Pier", V3(1.4, 9, 1.4), Constants.WHITE)
		p.Material = Enum.Material.SmoothPlastic
		p.CFrame = base * CFrame.new(dz, 4.5, 0)
		p.Parent = gate
	end
	local top = part("Lintel", V3(9, 1.4, 1.6), Constants.WHITE)
	top.Material = Enum.Material.SmoothPlastic
	top.CFrame = base * CFrame.new(0, 9.4, 0)
	top.Parent = gate
	local veil = part("Veil", V3(5.6, 8.6, 0.2), GOLD, 0.35)
	veil.CFrame = base * CFrame.new(0, 4.4, 0)
	veil.Parent = gate
	gate.Parent = fx
	return gate, veil
end

-- The steps ----------------------------------------------------------------------------------------------------------
local function report(name, how)
	local e = { name = name, how = how, t = math.floor(elapsed() * 10 + 0.5) / 10 }
	table.insert(history, e)
	if run then
		table.insert(run.history, e)
	end
	pcall(Net.send, "Tutorial", "step", name, how)
end

local function payoff(word, color, at)
	slam(word, color or C.white, 0.8, { shake = 0.55, punch = -12, sound = "kill", pitch = 1.25, big = 3 })
	burstScreen(color or C.white, 0.42)
	if at then
		burstWorld(at, color or C.white)
	end
end

-- the words while a kill waits for you: HOLD… until the bow's pulled far enough, then LET GO!
local function holdWords()
	if (charge or 0) >= 0.8 then
		say("LET GO!")
	else
		say(by("HOLD…", "HOLD FIRE…", "HOLD R2…"), by("hold the mouse, then let go", "", ""))
	end
	refs.ring.Visible = true
	glow(Device.isTouch() and (hud().touch or {}).fire or nil, true)
end

-- a kill the step waits on: shoot when it's been idle `wait` seconds (any release counts)
local function waitKill(st, dt, wait, mode)
	st.idle = (st.idle or 0) + dt
	if st.idle >= wait and not cine and charge == nil then
		st.idle = 0
		st.auto = (st.auto or 0) + 1
		autoFire(mode)
	end
end

-- turn the piece to `rot` (BuildController keeps one rotation: R and the right click flip it)
local function turnTo(rot)
	if BuildController.rotation() ~= rot then
		BuildController.rotate()
	end
end

-- PICK A WALL: done once it's picked (or one's already up). carry: its words and the tray's glow stay on into the
-- next step (no blink between them), gap 0: no pause either.
local function pickStep(name, key, rot, words, wait)
	return {
		name = name,
		timeout = wait,
		grace = 1,
		gap = 0,
		carry = true,
		enter = function()
			turnTo(rot)
			if Device.kind() == "gamepad" and BuildController.picked() ~= key then
				BuildController.pick(key) -- (no tray on a pad: it's picked for you)
			end
		end,
		tick = function()
			if builtOf(key) then
				return "built" -- (one's up already: picked and placed in a breath)
			end
			local slot = Structures.get(key).order
			say(by(words[1], words[2], words[1]), by(`press {slot}`, "", ""))
			glow((hud().trayButtons or {})[key], true)
			return BuildController.picked() == key
		end,
		expire = function()
			if BuildController.picked() ~= key then
				BuildController.pick(key)
			end
		end,
	}
end

-- PLACE IT: one is all it asks. Any `key` you put up counts, wherever it went (the glow is only a suggestion), and so
-- does one placed a moment early (between the steps). The glow stays put: it moves only when you turn the piece or
-- its spot can't take it any more. Where you aim and it can't go, it says why (the ghost goes red for the practice's
-- own rules too). On its timeout the piece goes up for you, on the glow, unless one of yours is already on its way.
local function placeStep(name, key, rot, back, wait, word, lesson)
	local function spotFor(st)
		st.rot = BuildController.rotation()
		st.center, st.w, st.d, st.cx, st.cz = buildSpot(key, back, st.rot)
		showSpot(st.center, st.w, st.d, teamColor())
	end
	return {
		name = name,
		timeout = wait,
		grace = 3,
		gap = 0,
		enter = function(st)
			turnTo(rot) -- (across the field: facing the line)
			spotFor(st)
		end,
		tick = function(st)
			if st.builtAt then
				return st.t - st.builtAt >= 2.2 -- (a moment for what it taught)
			end
			local b = builtOf(key)
			if b then
				st.builtAt = st.t
				payoff(word, teamColor(), (b.min + b.max) / 2)
				hideSpot()
				hidePath()
				unglow()
				say(nil)
				after(0.9, function()
					if run and run.state == st then
						say(lesson)
					end
				end)
				return false
			end
			if BuildController.rotation() ~= st.rot or practiceWhy(key, st.cx, st.cz, st.rot) then
				spotFor(st)
			end
			local _, root = body()
			if root then
				showPath(root.Position, st.center, teamColor())
			end
			if BuildController.picked() ~= key then
				BuildController.pick(key)
			end
			local why = aimWhy(key)
			local ghost = workspace:FindFirstChild("BuildGhost")
			if why and ghost and ghost:IsA("BasePart") then
				ghost.Color = Constants.TEAM_COLOR.red
				ghost.Transparency = 0.6
			end
			say(
				by("PLACE IT", "TAP PLACE", "PRESS R2"),
				why and string.upper(why) or by("aim at the glow and click", "aim at the glow", "")
			)
			refs.hint.TextColor3 = why and Constants.TEAM_COLOR.red or C.white
			glow(Device.isTouch() and (hud().touch or {}).place or nil, true)
			return false
		end,
		expire = function(st)
			if st.builtAt or builtOf(key) or now() - lastSent < 1.5 then
				return
			end
			-- (it's built for you, right on the glow: a fresh spot, so it's one the server takes)
			spotFor(st)
			lastSent = now()
			pcall(Net.send, "Build", key, st.cx, st.cz, st.rot)
			Bus.Tap:Fire("build_" .. key)
		end,
		leave = function()
			hideSpot()
			hidePath()
			refs.hint.TextColor3 = C.white
			if BuildController.picked() then
				BuildController.pick(nil)
			end
		end,
	}
end

-- The free trail at the win, once the server's said what it is (a few seconds into the show): a card under the title
local function rewardCard(st, t)
	if st.card or not pr or t < 3.2 or (not pr.reward and t < 6) then
		return
	end
	st.card = true
	local rw = pr.reward or {}
	if not rw.name then
		return -- (a replay: no reward)
	end
	refs.rewardLine.Text = string.upper(rw.name)
	refs.reward.Visible = true
	refs.reward.Pop.Scale = reduced() and 1 or 1.6
	animate(0.3, function(a)
		refs.reward.Pop.Scale = lerp(reduced() and 1 or 1.6, 1, outBack(a))
	end)
	burstScreen(GOLD, 0.64)
	sound("built", 1.4)
	after(5, function()
		refs.reward.Visible = false
	end)
end

-- Each step: name, timeout (then expire(st) does its part for you; grace more seconds and it moves on anyway),
-- enter(st), tick(st, dt) -> true | "how" when it's done, leave(st); gap (the pause before it, default 0.6 s), carry
-- (its words and glow stay up into the next step). The clock stops while a cinematic plays.
local STEPS
STEPS = {
	{
		name = "first_kill",
		timeout = 7,
		grace = 7,
		enter = function(st)
			setPhase("fight", 99, 99)
			st.bot = puppet(pr.front + fwd() * 24, 0, { keep = 11, speed = 3 })
			st.shots = { mode = "slow" }
			st.need = 1
			nudge(st.bot.torso, 0.9)
		end,
		tick = function(st)
			if st.killed >= st.need then
				hideMark()
				return not cine and (st.how or true)
			end
			showMark(st.bot.torso)
			holdWords()
			return false
		end,
		expire = function()
			autoFire("slow")
		end,
		kill = function(st)
			st.killed += 1
			say(nil)
			refs.ring.Visible = false
			unglow()
		end,
	},
	{
		name = "multi_kill",
		timeout = 18,
		grace = 6,
		enter = function(st)
			st.bots = {
				puppet(pr.front + fwd() * 30, -3.5, { keep = 12, speed = 3.2 }),
				puppet(pr.front + fwd() * 30, 3.5, { keep = 12, speed = 3.2 }),
			}
			st.shots = { mode = "quick" }
			st.need = 2
			st.from = pr.front
			slam("TWO MORE!", teamColor(enemyTeam()), 0.7, { sound = "count", pitch = 1.1, big = 2.2 })
		end,
		tick = function(st, dt)
			if st.killed >= st.need then
				if not st.moved then
					st.moved = true
					hideMark()
					say(nil)
					refs.ring.Visible = false
					after(0.7, function()
						lineMoved(st.from, pr.front, function()
							-- (and what they're worth: the counter they flew into)
							st.seen = st.t
							say("EVERY KNOCKOUT PAYS ◆")
							glow(hud().shop, true)
						end)
					end)
				end
				return st.seen ~= nil and st.t - st.seen >= 2.6
			end
			local target = nearestEnemy()
			showMark(target)
			holdWords()
			waitKill(st, dt, 7.5, "quick")
			return false
		end,
		expire = function()
			for _, b in liveBots() do
				knockOut(b, V3(fwd(), 0.2, 0).Unit)
			end
		end,
		kill = function(st)
			st.killed += 1
			local n = st.killed + 1 -- (with the first: a streak of 2, then 3)
			local word = n == 2 and "DOUBLE KILL!" or "TRIPLE KILL!"
			local color = n == 2 and Color3.fromRGB(255, 196, 40) or Color3.fromRGB(255, 120, 20)
			slam(word, color, 0.8, {
				sound = "kill",
				pitch = 0.9 + n * 0.1,
				shake = 0.5 + n * 0.2,
				punch = -10 - n * 2,
				big = 2.8 + n * 0.3,
			})
			burstScreen(color, 0.42)
			pcall(AudioController.streak, n)
		end,
	},
	{
		name = "near_miss",
		timeout = 7,
		grace = 2,
		gap = 0.2,
		enter = function(st)
			-- the camera's at once (your shots held), so you watch this one rather than shoot it: it turns to the
			-- archer, who draws fast and looses; the arrow whips just past your head in slow motion, and back to you.
			-- Never a target (the aim help passes it over); knocked out anyway, the step still runs its course.
			local _, root = body()
			local dz = math.clamp((root and root.Position.Z or pr.origin.Z) - pr.origin.Z - 5, -14, 14)
			local b = puppet(pr.front + fwd() * 26, dz, { keep = 26, speed = 0 })
			b.waiting = true
			st.archer = b
			local cam = workspace.CurrentCamera
			local look0 = cam.CFrame.LookVector
			local e0 = eye() or cam.CFrame.Position
			local SHOW, DRAW, LOOSE = 4.2, 0.45, 1.25
			local aimAt = b.head.Position
			cinematic(SHOW, function(c, t)
				local e = eye() or e0
				if b.alive then
					aimAt = b.head.Position
				end
				local to = aimAt - e
				local want = to.Magnitude > 0.1 and to.Unit or look0
				-- (turned to it in under half a second, held, and eased back to where you looked at the end)
				local k = smoother(clamp01(t / DRAW)) * (1 - smoother(clamp01((t - (SHOW - 0.7)) / 0.7)))
				local look = look0:Lerp(want, k)
				look = look.Magnitude > 0.01 and look.Unit or want
				b.draw = st.loosed and 0 or clamp01((t - DRAW) / (LOOSE - DRAW))
				if t >= LOOSE and not st.loosed then
					st.loosed = true
					if b.alive then
						-- (just past your head: over and to the side, slowed right down as it goes by)
						local right = CFrame.lookAt(e, aimAt).RightVector
						botArrow(b, e + right * 1.5 + V3(0, 1.3, 0), 30, 0.12, function()
							st.landed = true
						end)
					else
						st.landed = true
					end
				end
				if (st.landed or t >= LOOSE + 1.8) and not st.told then
					st.told = true
					slam("THEY SHOOT BACK.", teamColor(enemyTeam()), 1.1, { sound = "hit", pitch = 0.7, shake = 0.4 })
					say("BUILD COVER!")
				end
				aimCam(c, e, e + look * 20, lerp(BASE_FOV, 58, k * (reduced() and 0.5 or 1)))
				cine.look = look0
			end, function()
				st.done = true
			end, { bars = true, hideHud = true, noShots = true })
		end,
		tick = function(st)
			return st.done == true
		end,
		leave = function(st)
			if st.archer then
				st.archer.draw = 0
			end
		end,
	},
	{
		name = "build_view",
		timeout = 5,
		grace = 1,
		carry = true,
		enter = function(st)
			-- the build phase: no shooting, the clock waits until you've built. The tray is up at once (no
			-- letterbox, the HUD stays) with the wall pulsing in it, and a quick look up over the line plays while
			-- you pick (the tray works all through it)
			setPhase("build", nil, 45)
			Store.merge("me", { budget = Constants.BUILD_BUDGET, budgetMax = Constants.BUILD_BUDGET })
			slam("BUILD TIME: NO SHOOTING", C.white, 1.1, { sound = "build", pitch = 1, big = 2.2 })
			say(by("PICK A WALL", "TAP A WALL", "PICK A WALL"), by(`press {Structures.get("wall").order}`, "", ""))
			glow((hud().trayButtons or {}).wall, true)
			rippleSide(team())
			local _, root = body()
			local z = root and root.Position.Z or pr.origin.Z
			local e0 = eye() or V3(0, 4, z)
			local cam = workspace.CurrentCamera
			local look0 = cam.CFrame.LookVector
			local f = fwd()
			local high = V3(pr.front - f * 12, 22, z + 14)
			cinematic(2.4, function(c, t)
				local e = eye() or e0
				local k = smoother(clamp01(t / 0.7)) * (1 - smoother(clamp01((t - 1.6) / 0.8)))
				glowLine(pr.front, (t >= 0.4 and t < 1.8) and (0.6 + 0.4 * math.sin(t * 12)) or 0)
				aimCam(c, e:Lerp(high, k), (e + look0 * 20):Lerp(V3(pr.front, 0, z), k), lerp(BASE_FOV, 66, k))
				cine.look = look0
			end, function()
				glowLine(pr.front, 0)
				st.seen = true
			end, { bars = false, hideHud = false })
		end,
		tick = function(st)
			return st.seen == true
		end,
	},
	pickStep("pick_wall", "wall", 1, { "PICK A WALL", "TAP A WALL" }, 6),
	placeStep("place_wall", "wall", 1, 1, 10, "NICE WALL!", "PIECES COST POINTS"),
	{
		name = "fight_again",
		timeout = 14,
		grace = 2,
		enter = function(st)
			-- built: the clock runs (5 s; another piece if you like, never asked for), then the fight, and the wall
			-- takes three arrows
			setPhase("build", 5)
			say("ADD ANOTHER IF YOU LIKE", by("or wait: the fight's coming", "or wait: the fight's coming", ""))
			st.archer = liveBots()[1] or puppet(pr.front + fwd() * 30, -6, { keep = 26, speed = 5 })
		end,
		tick = function(st)
			if st.t >= 5 and not st.fight then
				st.fight = true
				say(nil)
				setPhase("fight", 99, 99)
				slam("FIGHT!", teamColor(), 0.8, { sound = "horn", pitch = 1, shake = 0.7, punch = -10, big = 3 })
			end
			local wall = builtOf("wall") or builtOf()
			if st.fight and st.t >= 6 and not st.volley then
				st.volley = true
				if wall then
					local f = fwd()
					local faceX = f > 0 and wall.max.X + 0.05 or wall.min.X - 0.05
					local mz = (wall.min.Z + wall.max.Z) / 2
					local cam = workspace.CurrentCamera
					local look0 = cam.CFrame.LookVector
					local center = V3(faceX, 4, mz)
					-- the camera beside the wall, watching the arrows thud into it
					cinematic(3.4, function(c)
						aimCam(c, center + V3(-f * 4, 3, 13), center + V3(f * 6, 0, 0), 62)
						cine.look = look0
					end, function()
						st.thudded = true
					end, { bars = true, hideHud = true })
					st.archer.draw = 1
					for i = 1, 3 do
						after(0.35 + (i - 1) * 0.75, function()
							if pr and st.archer.alive then
								local to = V3(faceX, 2.5 + i * 1.6, mz + (i - 2) * 1.6)
								botArrow(st.archer, to, 0, nil)
							end
						end)
					end
					after(1.2, function()
						if run and run.state == st then
							slam("WALLS STOP ARROWS!", teamColor(), 1.2, { sound = "built", big = 2.2 })
						end
					end)
				else
					st.thudded = true
				end
			end
			return st.thudded == true and st.t >= 9.5
		end,
	},
	{
		name = "tnt",
		timeout = 16,
		grace = 2,
		enter = function(st)
			st.archer = liveBots()[1] or puppet(pr.front + fwd() * 28, -6, { keep = 22, speed = 5 })
			st.archer.keep = 15
			st.archer.speed = 3.5
			st.archer.draw = 0
		end,
		tick = function(st)
			local b = st.archer
			if st.t >= 2.6 and not st.wound then
				st.wound = true
				b.draw = 0.6
				say("LOOK OUT!")
				pcall(AudioController.loop, "fuse", true, 0.5)
			end
			if st.t >= 4.2 and not st.thrown then
				st.thrown = true
				say(nil)
				local wall = builtOf("wall") or builtOf()
				local target = wall
						and V3((wall.min.X + wall.max.X) / 2, wall.max.Y * 0.5, (wall.min.Z + wall.max.Z) / 2)
					or ((eye() or V3(0, 3, pr.origin.Z)) + V3(fwd() * 9, -3, 3))
				lobTnt(b, target, function()
					st.blown = st.t
					slam("THAT'S TNT.", Constants.TNT_RED, 1.4, { sound = "boom", pitch = 1, shake = 0.6, big = 2.6 })
					after(1.8, function()
						if run and run.state == st then
							say("YOURS FOREVER IN THE SHOP.")
							glow(((hud().bows or {}).tnt or {}).button, true)
						end
					end)
				end)
			end
			-- the thrower walks off
			if st.blown then
				b.keep = 40
			end
			return st.blown ~= nil and st.t - st.blown >= 9.4
		end,
		leave = function(st)
			unglow()
			if st.archer and st.archer.alive then
				st.archer.alive = false
				st.archer.model:Destroy()
			end
		end,
	},
	{
		name = "push",
		timeout = 25,
		grace = 6,
		enter = function(st)
			for _, b in liveBots() do
				b.alive = false
				b.model:Destroy()
			end
			local f = fwd()
			-- (two come on first; the other two wait further back and come once those are down)
			st.later = {}
			for i, dz in { -6, 6, -10, 10 } do
				local b = puppet(pr.front + f * (28 + i * 3), dz, { keep = i <= 2 and 11 + i or 34, speed = 2.8 })
				if i > 2 then
					b.waiting = true -- (not a target yet: they're hanging back)
					table.insert(st.later, b)
				end
			end
			st.from = pr.front
			st.shots = { mode = "cam" }
			st.need = 3
			slam("HERE THEY COME!", teamColor(enemyTeam()), 1.4, { sound = "horn", pitch = 1.1, big = 2.6 })
			-- (up for a look at the wave walking in, and back down)
			local e0 = eye() or V3(0, 4, pr.origin.Z)
			local cam = workspace.CurrentCamera
			local look0 = cam.CFrame.LookVector
			local wave = V3(pr.front + f * 26, 2, pr.origin.Z)
			cinematic(3.4, function(c, t)
				local e = eye() or e0
				local k = smoother(clamp01(t / 0.9)) * (1 - smoother(clamp01((t - 2.5) / 0.9)))
				aimCam(c, e:Lerp(e + V3(-f * 6, 9, 10), k), (e + look0 * 20):Lerp(wave, k), lerp(BASE_FOV, 62, k))
				cine.look = look0
			end, nil, { bars = true, hideHud = true })
			after(3.6, function()
				if run and run.state == st then
					slam("PUSH THE LINE!", teamColor(), 1.0, { sound = "count", pitch = 1.2, big = 2.4 })
				end
			end)
		end,
		tick = function(st, dt)
			if st.killed >= st.need then
				hideMark()
				return not cine
			end
			showMark(nearestEnemy())
			if st.killed == 0 then
				holdWords()
			else
				refs.ring.Visible = true
			end
			waitKill(st, dt, 7.5, "cam")
			return false
		end,
		expire = function(st)
			-- (a knockout each for you, but the last: that one's the win)
			for _, b in liveBots() do
				if st.killed < st.need then
					knockOut(b, V3(fwd(), 0.2, 0).Unit)
				end
			end
		end,
		kill = function(st)
			st.killed += 1
			local left = Practice.KILLS - pr.kills
			say(left == 1 and "1 MORE TO WIN!" or `{left} MORE TO WIN!`)
			if st.killed == 2 then
				-- the first two down: the camera shows how far the line's come, and the last two walk on
				after(1.7, function()
					if run and run.state == st then
						lineMoved(st.from, pr.front, function()
							for i, b in st.later do
								b.keep = 10 + i * 2
								b.waiting = nil
							end
						end)
					end
				end)
			end
		end,
	},
	{
		name = "final_kill",
		timeout = 6,
		grace = 7,
		always = true,
		enter = function(st)
			local bots = liveBots()
			for i = 2, #bots do
				bots[i].alive = false
				bots[i].model:Destroy()
			end
			st.bot = liveBots()[1] or puppet(pr.front + fwd() * 18, 0, { keep = 10 })
			st.shots = { mode = "slow" }
			st.need = 1
			st.hurry = elapsed() >= LATE -- (running long: the shot's taken for you at once)
			say("LAST ONE!")
		end,
		tick = function(st)
			if st.killed >= st.need then
				hideMark()
				return not cine and st.swept ~= false
			end
			showMark(st.bot.torso)
			if st.hurry and st.t > 0.5 and not st.hurried then
				st.hurried = true
				autoFire("slow")
			end
			if st.t > 1.5 then
				holdWords()
			end
			return false
		end,
		expire = function()
			autoFire("slow")
		end,
		kill = function(st)
			st.killed += 1
			say(nil)
			refs.ring.Visible = false
			unglow()
			-- (the line all the way: their base is yours)
			pr.kills = Practice.KILLS
			local old = pr.front
			moveLine()
			ripple(old, fwd() * Practice.HALF, teamColor(), 1.2)
			st.swept = false
			after(3.1, function()
				if run and run.state == st then
					slam("THEIR BASE IS YOURS!", teamColor(), 1.2, { sound = "horn", big = 2.4 })
					lineMoved(old - fwd() * Practice.PUSH, pr.front, function()
						st.swept = true
					end)
				end
			end)
		end,
	},
	{
		name = "victory",
		timeout = 14,
		grace = 2,
		always = true,
		enter = function(st)
			setPhase("victory", 30)
			pcall(Net.send, "Tutorial", "win")
			local mine = team()
			local color = teamColor(mine)
			local _, root = body()
			local cam = workspace.CurrentCamera
			local l = cam.CFrame.LookVector
			local a0 = math.atan2(-l.Z, -l.X)
			local center0 = root and root.Position or V3(0, 3, pr.origin.Z)
			if FireworksController.show then
				pcall(FireworksController.show, V3(fwd() * 22, 0, pr.origin.Z), color, {
					seconds = 16,
					radius = 30,
					depth = 20,
					back = V3(fwd(), 0, 0),
					tilt = false,
				})
			end
			sound("victory", 1)
			slam("VICTORY!", color, 2.6, { sound = "horn", pitch = 1.2, shake = 0.9, punch = -16, big = 3.6 })
			after(0.4, function()
				burstScreen(color, 0.42)
				burstScreen(GOLD, 0.42)
			end)
			-- the camera pulls out of your eyes and circles you
			cinematic(math.clamp(FINISH_BY - elapsed() - 6, 6, 15), function(c, t)
				rewardCard(st, t)
				local _, r = body()
				local center = r and r.Position or center0
				local out = smoother(clamp01(t / 1.4))
				local ang = a0 + t * 0.55
				local rad = lerp(0.5, 14, out)
				local pos = center + V3(math.cos(ang) * rad, lerp(1.5, 6 + t * 0.5, out), math.sin(ang) * rad)
				aimCam(
					c,
					pos,
					center + V3(0, lerp(1.5, 3, out), 0) + V3(fwd() * 6 * (1 - out), 0, 0),
					lerp(BASE_FOV, 66, out)
				)
				cine.look = V3(-fwd(), 0, 0)
			end, function()
				st.shown = true
			end, { bars = true, hideHud = false })
		end,
		tick = function(st)
			rewardCard(st, 99)
			return st.shown == true
		end,
	},
	{
		name = "gate",
		timeout = 6,
		grace = 3,
		always = true,
		enter = function(st)
			slam("THE REAL GAME STARTS NOW", C.white, 1.6, { sound = "horn", pitch = 0.9, big = 2.2 })
			local _, root = body()
			local p = root and root.Position or V3(0, 3, pr.origin.Z)
			st.at = V3(p.X - fwd() * 8, 0, p.Z)
			st.gate, st.veil = showGate(st.at)
		end,
		tick = function(st)
			local _, root = body()
			if st.through then
				return st.t - st.through >= 0.7
			end
			if root then
				showPath(root.Position, st.at, GOLD)
			end
			say(by("WALK THROUGH THE GATE", "WALK INTO THE GATE", "WALK THROUGH THE GATE"))
			st.veil.Transparency = 0.25 + 0.2 * math.sin(st.t * 5)
			local d = root and V3(root.Position.X - st.at.X, 0, root.Position.Z - st.at.Z).Magnitude or 99
			if d <= 3.5 then
				st.through = st.t
				fade(0, 0.6)
				sound("victory", 1.3, 0.6)
			end
			return false
		end,
		expire = function(st)
			st.through = st.t
			fade(0, 0.6)
		end,
		leave = function(st)
			hidePath()
			if st.gate then
				st.gate:Destroy()
			end
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

-- The show stops, all of it, at once: the camera's handed back, every title, word, card, burst, firework, letterbox
-- and slow motion gone, and nothing still pending can bring one back (a step's callbacks check run.state; the titles
-- their token; what's left of the animations is played out to its end now, so their pieces are cleaned up)
local function clearShow()
	if run then
		run.state = nil
	end
	onKill = nil
	if cine then
		endCinematic(true)
	end
	titleToken, sayToken = nil, nil
	for _ = 1, 3 do
		local pending = anims
		anims = {}
		for _, a in pending do
			if a.fn then
				pcall(a.fn, 1)
			end
			if a.done then
				pcall(a.done)
			end
		end
	end
	clearGuides()
	refs.title.Visible = false
	refs.tip.Visible = false
	refs.reward.Visible = false
	refs.skip.Visible = false
	refs.skipHint.Visible = false
	refs.skipCine.Visible = false
	refs.barTop.Size = UDim2.new(1, 0, 0, 0)
	refs.barBottom.Size = UDim2.new(1, 0, 0, 0)
	for _, d in refs.gui:GetChildren() do
		if d.Name == "Bit" then
			d:Destroy()
		end
	end
	if FireworksController.stop then
		pcall(FireworksController.stop)
	end
	pcall(AudioController.loop, "fuse", false)
	Effects.timeScale = 1
	punch = 0
	CameraController.setFov("tutorial", nil)
	BuildController.pick(nil)
end

-- The practice is over (done, skipped, or the server's time): this client's world goes, the camera and the screen
-- are the match's again (the server's join brings the match's state)
local function endPractice()
	clearShow()
	refs.waitCard.Visible = false
	WeaponController.shotHook = nil
	Layout.cinema(false)
	Layout.focus(false)
	Layout.practice(false)
	clearOverlay()
	if lineGlow then
		lineGlow:Destroy()
		lineGlow = nil
	end
	for _, d in fx:GetChildren() do
		d:Destroy()
	end
	if pr then
		pr.world.folder:Destroy()
		pr = nil
	end
	-- (from white, back into the live match)
	if refs.fade.Visible then
		local token = {}
		fadeToken = token
		after(0.25, function()
			if fadeToken == token then
				fade(1, 0.8)
			end
		end)
	end
end

-- Done with the practice, waiting for the server to join us to the live match: the show's cleared away at once and
-- the screen goes (or stays) white with the HUD off, the practice still under it, until the server's "leave" (at once,
-- or once the live match's next game starts: its "wait" puts NEXT MATCH STARTING… on the white). If that never comes,
-- out anyway after LEAVE_WAIT.
local LEAVE_WAIT = Constants.TUTORIAL_JOIN_WAIT + 8

local function leaving()
	if not pr or pr.leaving then
		return
	end
	pr.leaving = now()
	clearShow()
	Layout.cinema(true)
	if not refs.fade.Visible or refs.fade.BackgroundTransparency > 0.01 then
		fade(0, 0.35)
	end
end

local function finishRun(how)
	if not run or run.finished then
		return
	end
	run.finished = true
	local st = run.state
	local step = STEPS[run.i]
	if step and step.leave and st then
		pcall(step.leave, st)
	end
	onKill = nil
	if how == "skip" then
		session = nil
		pcall(Net.send, "Tutorial", "skip", step and step.name or "intro")
	else
		session = { tips = {}, walk = 0 }
		pcall(Net.send, "Tutorial", "done")
	end
	leaving()
end

-- end it now (K, the SKIP button): into the live match
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
	-- (the server's start wins: a run this screen still thinks is going is over)
	if run and not run.finished then
		run.finished = true
	end
	msg = msg or {}
	local info = type(msg.practice) == "table" and msg.practice or {}
	local origin = typeof(info.origin) == "Vector3" and info.origin or Practice.origin(1)
	local t = (info.team == "red" or info.team == "blue") and info.team or "red"
	if pr then
		endPractice()
	end
	-- (alive in the practice before anything else: a stale "down" from the match must never leave RESPAWNING up)
	Store.merge("me", { team = t, alive = true, hp = Constants.MAX_HEALTH })
	local okWorld, world = pcall(Practice.build, origin, t, workspace)
	if not okWorld then
		-- (the arena couldn't be drawn: never stranded in an empty practice, straight to the match instead)
		warn("[Tutorial] practice arena failed: " .. tostring(world))
		Net.send("Tutorial", "skip")
		return false
	end
	pr = {
		origin = origin,
		team = t,
		world = world,
		front = 0,
		kills = 0,
		bots = {},
		built = {},
		phase = "fight",
		ends = 0,
		t0 = now(),
	}
	Layout.practice(true)
	Layout.focus(true)
	WeaponController.shotHook = onShot
	setPhase("fight", 99, 99)
	Store.merge("me", {
		team = t,
		alive = true,
		hp = Constants.MAX_HEALTH,
		weapon = Weapons.DEFAULT,
		ammo = nil,
		budget = info.budget or Constants.BUILD_BUDGET,
		budgetMax = Constants.BUILD_BUDGET,
		protected = false,
	})
	run = {
		i = 0, -- (0: the intro, once you're standing in the practice)
		gap = 0,
		history = {},
		replay = msg.replay == true,
	}
	session = nil
	return true
end

-- true while one of the tutorial's camera shows plays (the intro, a kill, THE LINE MOVED!): the kill cam waits
function TutorialController.cinematic()
	return cine ~= nil
end

function TutorialController.practice()
	return pr
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
		practice = pr ~= nil,
		kills = pr and pr.kills or 0,
		front = pr and pr.front or nil,
		elapsed = elapsed(),
	}
end

-- Each frame: the step that's on, its guides, its payoff -----------------------------------------------------------
local function advance(how)
	local step = STEPS[run.i]
	local st = run.state
	if step then
		if step.leave and st then
			step.leave(st)
		end
		report(step.name, how ~= true and how or nil)
	end
	-- (a step that carries on into the next keeps its words and glow up: the next one says the same, no blink)
	if not (step and step.carry) then
		unglow()
		say(nil)
	end
	hideMark()
	refs.ring.Visible = false
	run.i += 1
	run.state = nil
	onKill = nil
	local nextStep = STEPS[run.i]
	run.gap = nextStep and nextStep.gap or 0.6
	if run.i > #STEPS then
		finishRun("done")
	end
end

local function stepRun(dt)
	if run.i == 0 then
		-- the intro, once you're standing in the practice
		local _, root = body()
		if not run.introPlaying and root and pr and Practice.inside(pr.origin, root.Position, 4) then
			run.introPlaying = true
			playIntro(function(skipped)
				run.introPlaying = false
				report("intro", skipped and "skip" or nil)
				run.i = 1
				run.gap = 0.3
				refs.skip.Label.Text = by("K · SKIP TUTORIAL", "SKIP TUTORIAL", "SELECT · SKIP")
			end)
		end
		return
	end
	local step = STEPS[run.i]
	if not step then
		return
	end
	if run.gap > 0 then
		run.gap -= dt
		return
	end
	local st = run.state
	if not st then
		st = { t = 0, killed = 0 }
		run.state = st
		onKill = function(b)
			if run and run.state == st and step.kill then
				step.kill(st, b)
			end
		end
		if elapsed() >= LATE and not step.always then
			advance("late") -- (running long: straight on to the win)
			return
		end
		step.enter(st)
	end
	if cine then
		return -- (the clock waits while the camera's taken)
	end
	st.t += dt
	local how = step.tick(st, dt)
	if how then
		advance(how)
		return
	end
	if step.timeout and not st.expired and st.t >= step.timeout then
		st.expired = true
		st.how = "timeout"
		if step.expire then
			step.expire(st)
		else
			advance("timeout")
			return
		end
	end
	if st.t >= (step.timeout or 30) + (step.grace or 4) then
		advance("timeout")
	end
end

-- The tips, in the live match after it (once each, only when they fit)
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
		and Layout.charging() -- (the blade is only out in the CHARGE)
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

local holdAt = 0
local function frame(dt)
	local t = now()
	stepAnims()
	stepRipples()
	stepSpot(t)
	stepPath(t)
	stepGlow(t)
	stepBots(dt)
	-- the lens punch eases out; outside a cinematic it goes through the first-person camera
	punch *= math.exp(-dt * 7)
	if math.abs(punch) < 0.05 then
		punch = 0
	end
	CameraController.setFov("tutorial", (not cine and punch ~= 0) and punch or nil)
	if mark and markOn then
		mark.StudsOffset = V3(0, 4 + (reduced() and 0 or 0.6 * math.sin(t * 6)), 0)
	end
	if refs.ring.Visible then
		local c = charge or 0
		local lit = math.floor(c * 24 + 0.5)
		for i, d in refs.dots do
			d.BackgroundColor3 = c >= 0.8 and teamColor(enemyTeam()) or C.ink
			d.BackgroundTransparency = i <= lit and 0 or 0.7
			d.Size = UDim2.fromOffset(i <= lit and 11 or 8, i <= lit and 11 or 8)
		end
	end
	-- (the practice's clock waits while it holds: the HUD keeps showing the same time)
	if pr and pr.hold and t >= holdAt then
		holdAt = t + 0.5
		pr.ends = workspace:GetServerTimeNow() + pr.hold
		pushMatch()
	end
	if pr and pr.leaving and t - pr.leaving >= LEAVE_WAIT then
		endPractice() -- (the server's join never came: never left on a white screen)
	end
	if introPending and not cine and not (run and not run.finished) and alive() and playing() then
		-- the opening alone: YOUR TURF, THE LINE, TAKE THEIRS, and down into your eyes
		introPending = false
		Layout.focus(true)
		playIntro(function()
			Layout.focus(false)
		end)
	elseif run and not run.finished then
		stepRun(dt)
	elseif not run or run.finished then
		stepTips(dt)
	end
	-- (SKIP shows once the intro's over, not over a cinematic's letterbox)
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
		elseif msg.kind == "built" and pr then
			addBuilt(msg)
		elseif msg.kind == "refused" and pr and type(msg.why) == "string" then
			tip(string.upper(msg.why))
		elseif msg.kind == "reward" and pr then
			pr.reward = msg
		elseif msg.kind == "wait" then
			-- (the server's done with it, the live match is between games: on the white, a calm card, until its next)
			if run and not run.finished then
				run.finished = true
				session = { tips = {}, walk = 0 }
			end
			leaving()
			refs.waitCard.Visible = pr ~= nil
		elseif msg.kind == "leave" then
			-- (the server's ended it: done, skipped, or its time) into the live match
			if run and not run.finished then
				run.finished = true
				session = msg.how ~= "skip" and { tips = {}, walk = 0 } or nil
			end
			if pr then
				endPractice()
			end
		end
	end)
	Bus.Charge:Connect(function(c)
		charge = c
	end)
	Bus.Tap:Connect(function(name)
		if not pr or type(name) ~= "string" then
			return
		end
		if name == "build_refused" then
			-- (the ghost's red where you aimed: say why, the way the server says it)
			local why = BuildController.picked() and aimWhy(BuildController.picked())
			if why then
				tip(string.upper(why))
			end
		elseif string.sub(name, 1, 6) == "build_" then
			lastSent = now()
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		-- only a deliberate key skips a cinematic (after its first second): Enter or K, Select on a pad (a phone
		-- has its SKIP button). Moving, looking, clicking or dragging never does: new players press those at once.
		local k = input.KeyCode
		local isSkip = k == Enum.KeyCode.Return or k == Enum.KeyCode.K or k == Enum.KeyCode.ButtonSelect
		if cine and cine.skippable and isSkip and now() - cine.t0 >= 1 then
			endCinematic(true)
			return
		end
		if processed or not run or run.finished or run.i == 0 then
			return
		end
		if input.KeyCode == Enum.KeyCode.K or input.KeyCode == Enum.KeyCode.ButtonSelect then
			TutorialController.skip()
		end
	end)
	RunService.RenderStepped:Connect(frame)
end

return TutorialController
