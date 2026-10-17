--[[
Kill effects (Data/Cosmetics kind "effect"): what plays where someone falls, in the killer's look. Every one is its
own little film in three beats, a wind-up, the hit and what's left after (1.5 to 3 s, fx.life), built here on this
client from plain parts, particles, beams, lights, billboards, the sticker art (Data/MemeArt) and the studio's shared
sounds (no uploads), each with its own motion, colours and sound.

  ladder     cubes (shiver, burst, bounce, blink out), smoke (a cartoon dust cloud), shards (a crack, then glass;
             Triple: three breaks; VIP: black glass and gold), pixels (they dissolve, head first), ring (a shockwave
             and the floor tiles leap), slice (one slash, and the air comes apart in two), fold (folded away like
             paper), static (TV static, and the set switches off), spark (a sparkler, then the crack), nova (an
             implosion, then a star goes off)
  goals      spears (a crown of spears slams down round them), spotlight (MVP: a spotlight, gold confetti, applause)
  shop       confetti (party poppers), ink (a drop, then SPLAT), orbit (two hoops spin up like a gyroscope and blast
             out), rise (their soul spirals up a column of light), feathers (a pillow bursts), sparkles (rainbow in,
             a rainbow star, rainbow out), blocks (blocks drop in and party on the beat), firework, bubbles (one big
             bubble, popped), chicken (BAWK, it legs it and leaves an egg that hatches), duck (SQUEAK), balloons
             (inflate, lift, one pops), banana (a slip, a flip, a SPLAT, stars)
  Robux      lightning (a storm cloud, a forked strike, charred, twitching, ash), doge (a shiba boings up: comic sans
             words, gold coins), web (THWIP, a cocoon, swung away), oof (knocked flat, a giant OOF slams down and
             deflates), bonk (a wind-up, BONK, squashed flat, birdies), dance (a disco ball drops, they dance on the
             beat, moonwalk off), blackhole (pulled in and stretched thin, collapse, POP), heaven (a golden beam,
             gates rise and open, wings, a halo, up and in, the gates shut)

The ones with a body (KillEffects.usesBody) move a stand-in of whoever fell (opts.body: KillFxController hands over
a still copy of their character; else a mannequin). Each has a time scale (opts.scale) on top of Effects.timeScale
(the kill cam's slow motion), so the victim's kill cam can play the killer's effect slowed right down on them.
Light on phones and low graphics (fewer pieces, one light), capped, and everything cleans up after itself. The
screen-wide touches (a darkened sky, a warm glow) only play in the arena, one at a time.

  KillEffects.play(effectKey, pos, team, opts?) -> handle | nil
        opts = { body?, victimTeam?, dir?, scale? (1), fixed? (ignore Effects.timeScale) }
  KillEffects.playShape(shape, pos, team, opts?)   the same by shape name (tests, previews)
  KillEffects.usesBody(shape)   KillEffects.SHAPES   KillEffects.count()   KillEffects.pieces()   KillEffects.step(dt)
  KillEffects.claim(k) / KillEffects.claimed(k)   the victim's kill cam takes a kill's effect to play itself
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local MemeArt = require(ReplicatedStorage.Shared.Data.MemeArt)
local Effects = require(script.Parent.Effects)

local KillEffects = {}

local rng = Random.new()
local UP = Vector3.yAxis
local WHITE = Color3.fromRGB(252, 252, 252)
local INK = Color3.fromRGB(24, 24, 28)
local GOLD = Color3.fromRGB(255, 200, 50)
local YELLOW = Color3.fromRGB(255, 228, 60)
local ORANGE = Color3.fromRGB(255, 140, 30)
local LIFE = 2.8 -- seconds an effect lasts by default (its own time; each shape sets its own fx.life)
local MAX_PIECES = { high = 520, mid = 340, low = 150 }
local SPARKLE_TEX = "rbxasset://textures/particles/sparkles_main.dds"
-- (the doge's comic sans; an older client without it gets the cartoon font)
local COMIC = (function()
	local ok, f = pcall(function()
		return Enum.Font.ComicNeueAngular
	end)
	return ok and f or Enum.Font.Cartoon
end)()

KillEffects.SHAPES = {
	"cubes",
	"smoke",
	"shards",
	"pixels",
	"ring",
	"slice",
	"fold",
	"static",
	"spark",
	"nova",
	"spears",
	"confetti",
	"ink",
	"orbit",
	"rise",
	"spotlight",
	"feathers",
	"sparkles",
	"blocks",
	"firework",
	"bubbles",
	"chicken",
	"duck",
	"balloons",
	"banana",
	"lightning",
	"doge",
	"web",
	"oof",
	"bonk",
	"dance",
	"blackhole",
	"heaven",
}
local BODY = {
	balloons = true,
	banana = true,
	web = true,
	dance = true,
	blackhole = true,
	heaven = true,
	lightning = true,
	oof = true,
	bonk = true,
}
local TEX = {
	sparkle = SPARKLE_TEX,
	fire = "rbxasset://textures/particles/fire_main.dds",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
}

function KillEffects.usesBody(shape)
	return BODY[shape] == true
end

local folder
local actors = {}
local stepping
local claims = {} -- [victim id .. killer id] = os.clock()

local function getFolder()
	if not folder or not folder.Parent then
		folder = Instance.new("Folder")
		folder.Name = "KillFx"
		folder.Parent = workspace
	end
	return folder
end

local function tier()
	local ok, t = pcall(Effects.tier)
	return ok and t or "low"
end

function KillEffects.count()
	return #actors
end

function KillEffects.pieces()
	local n = 0
	for _, a in actors do
		n += #a.parts
	end
	return n
end

-- the kill cam takes this kill's effect (it plays it itself, slowed, on your stand-in)
local function claimKey(k)
	return tostring(k.victim) .. ":" .. tostring(k.killer)
end
function KillEffects.claim(k)
	if type(k) == "table" then
		claims[claimKey(k)] = os.clock()
	end
end
function KillEffects.claimed(k)
	local at = type(k) == "table" and claims[claimKey(k)]
	return at ~= nil and os.clock() - at < 2
end

-- Easing -------------------------------------------------------------------------------------------------------
local function clamp01(x)
	return math.clamp(x, 0, 1)
end
local function outCubic(x)
	x = clamp01(x)
	return 1 - (1 - x) ^ 3
end
local function outBack(x)
	x = clamp01(x)
	local c1 = 1.9
	return 1 + (c1 + 1) * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end
local function outElastic(x)
	x = clamp01(x)
	if x == 0 or x == 1 then
		return x
	end
	return 2 ^ (-10 * x) * math.sin((x * 10 - 0.75) * (2 * math.pi) / 3) + 1
end
local function bounce(x)
	-- |sin| hops getting smaller
	x = clamp01(x)
	return math.abs(math.sin(x * math.pi * 3)) * (1 - x)
end
local function rainbow(i, t)
	return Color3.fromHSV(((i or 0) * 0.13 + (t or 0) * 0.35) % 1, 0.78, 1)
end
local function randomDir(up)
	local v = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(up or -1, 1), rng:NextNumber(-1, 1))
	return v.Magnitude > 0.01 and v.Unit or UP
end

-- An actor: one effect playing ------------------------------------------------------------------------------------
local Actor = {}
Actor.__index = Actor

function Actor:part(size, color, opts)
	opts = opts or {}
	local p = Instance.new(opts.wedge and "WedgePart" or "Part")
	p.Name = opts.name or "Fx"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = opts.material or Enum.Material.Neon
	if opts.ball then
		p.Shape = Enum.PartType.Ball
	elseif opts.cylinder then
		p.Shape = Enum.PartType.Cylinder
	end
	p.Size = size
	p.Color = color
	p.Transparency = opts.transparency or 0
	p.CFrame = opts.cf or CFrame.new(self.at)
	p.Parent = self.folder
	table.insert(self.parts, p)
	return p
end

-- a flying bit: moved by its velocity, gravity, drag, spin; fades out at the end of its life
function Actor:bit(p, vel, o)
	o = o or {}
	local b = {
		part = p,
		pos = p.Position,
		rot = p.CFrame.Rotation,
		vel = vel or Vector3.zero,
		grav = o.grav or 0,
		drag = o.drag or 0.6,
		axis = o.axis or randomDir(),
		spin = o.spin or 0,
		born = self.age,
		life = o.life or self.life * rng:NextNumber(0.6, 0.95),
		size = p.Size,
		shrink = o.shrink ~= false,
		floor = o.floor,
		bounce = o.bounce or 0.45,
		sway = o.sway,
		twinkle = o.twinkle,
		face = o.face, -- (point along the velocity: sparks, trails)
		alpha = p.Transparency,
		color = o.color, -- fn(t) -> Color3
		onDie = o.onDie,
	}
	table.insert(self.bits, b)
	return b
end

-- a word floating over the spot (a billboard on an invisible anchor)
function Actor:text(str, offset, color, o)
	o = o or {}
	local anchor = self:part(Vector3.new(0.2, 0.2, 0.2), WHITE, { transparency = 1, cf = CFrame.new(self.at + offset) })
	local gui = Instance.new("BillboardGui")
	gui.Name = "Words"
	gui.Size = UDim2.fromScale(o.w or 8, o.h or 3)
	gui.AlwaysOnTop = o.onTop ~= false
	gui.LightInfluence = 0
	gui.MaxDistance = 400
	gui.Adornee = anchor
	gui.Parent = anchor
	local l = Instance.new("TextLabel")
	l.Name = "Text"
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(0.5, 0.5)
	l.Text = str
	l.TextScaled = true
	l.Font = o.font or Enum.Font.FredokaOne
	l.TextColor3 = color
	l.TextStrokeColor3 = o.stroke or INK
	l.TextStrokeTransparency = 0
	l.Rotation = o.rotation or 0
	l.Parent = gui
	return { anchor = anchor, gui = gui, label = l, born = self.age, base = offset }
end

-- A comic sticker (Data/MemeArt) on a billboard over the spot: it pops in with a bounce, then (opts) wobbles,
-- spins, floats up, swings like a mallet, and fades out before the end. size: studs across; delay: seconds.
--   opts = { delay?, life? (to the end of the effect), wobble?, spin? (deg/s), float? (studs/s), swing?, pulse?, onTop? }
function Actor:sticker(name, offset, size, opts)
	opts = opts or {}
	local function make()
		if not self.alive then
			return
		end
		local anchor =
			self:part(Vector3.new(0.2, 0.2, 0.2), WHITE, { transparency = 1, cf = CFrame.new(self.at + offset) })
		local gui = Instance.new("BillboardGui")
		gui.Name = "Sticker_" .. name
		gui.Size = UDim2.fromScale(0.01, 0.01)
		gui.AlwaysOnTop = opts.onTop ~= false
		gui.LightInfluence = 0
		gui.MaxDistance = 500
		gui.Adornee = anchor
		gui.Parent = anchor
		local img = Instance.new("ImageLabel")
		img.Name = "Art"
		img.BackgroundTransparency = 1
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = UDim2.fromScale(0.5, 0.5)
		img.Size = UDim2.fromScale(1, 1)
		img.ScaleType = Enum.ScaleType.Fit
		img.Image = MemeArt.image(name)
		img.Parent = gui
		local born = self.age
		local life = opts.life or math.max(0.6, self.life - self.age - 0.1)
		table.insert(self.ticks, function(_, now)
			local v = now - born
			local k = outBack(clamp01(v / 0.28))
			local fade = clamp01((v - (life - 0.35)) / 0.35)
			local pulse = opts.pulse and (1 + math.sin(v * 9) * 0.06) or 1
			local sz = size * math.max(0.01, k) * pulse * (1 - fade * 0.3)
			gui.Size = UDim2.fromScale(sz, sz)
			img.ImageTransparency = fade
			local rot = 0
			if opts.wobble then
				rot += math.sin(v * 7) * 9
			end
			if opts.spin then
				rot += v * opts.spin
			end
			if opts.swing then
				-- (a mallet: raised, then slams down, a little bounce)
				local u = clamp01(v / 0.45)
				rot += -70 + 110 * (u * u) - (u >= 1 and math.sin((v - 0.45) * 20) * 8 * math.max(0, 1 - (v - 0.45) * 3) or 0)
			end
			img.Rotation = rot
			anchor.CFrame = CFrame.new(self.at + offset + UP * (opts.float or 0) * v)
		end)
	end
	if opts.delay and opts.delay > 0 then
		self:after(opts.delay, make)
	else
		make()
	end
end

-- a sound from the spot: one of the studio's shared clips, pitched (slower in slow motion); delay: seconds from now.
-- Played now, it hands back the Sound (to bend its pitch or stop it).
function Actor:sound(clip, pitch, volume, delay)
	local function play()
		if not self.alive then
			return nil
		end
		self.heard = (self.heard or "") .. clip .. string.format("%.2f", pitch or 1) .. " "
		local ok, s = pcall(function()
			local snd = Instance.new("Sound")
			snd.Name = "FxSound"
			snd.SoundId = Constants.SOUNDS[clip] or clip
			snd.Volume = volume or 0.6
			snd.PlaybackSpeed = math.max(0.2, (pitch or 1) * math.max(0.35, self:speed()))
			snd.RollOffMaxDistance = 220
			snd.Parent = self.anchor
			snd:Play()
			return snd
		end)
		return ok and s or nil
	end
	if delay and delay > 0 then
		table.insert(self.timers, { at = self.age + delay, fn = play })
		return nil
	end
	return play()
end

-- fn in t seconds (the effect's own time, from now)
function Actor:after(t, fn)
	table.insert(self.timers, { at = self.age + t, fn = fn })
end

-- playing in the arena (not in a little world of its own, like a shop card's)? The screen-wide touches only play there.
function Actor:inWorld()
	local ok, yes = pcall(function()
		return self.folder:IsDescendantOf(workspace)
	end)
	return ok and yes == true
end

-- a light at a spot (a PointLight on an anchor); fade: seconds it dies away over (a flash), else it's held. One an
-- effect on a phone, three otherwise.
function Actor:light(at, color, brightness, range, fade)
	self.lights = (self.lights or 0) + 1
	if self.lights > (self.mult < 0.5 and 1 or 3) then
		return nil
	end
	local anchor = self:part(Vector3.one * 0.2, WHITE, { transparency = 1, cf = CFrame.new(at) })
	local l = Instance.new("PointLight")
	l.Name = "FxLight"
	l.Color = color
	l.Brightness = brightness
	l.Range = range or 16
	l.Shadows = false
	l.Parent = anchor
	if fade then
		local t0 = self.age
		local done = false
		table.insert(self.ticks, function(_, now)
			if not done then
				local u = clamp01((now - t0) / fade)
				l.Brightness = brightness * (1 - u) ^ 2
				done = u >= 1
			end
		end)
	end
	return l
end

-- particles at a spot, slowed with the effect: a burst (o.n) or a stream (o.rate a second, for o.stream seconds)
--   o = { tex? (sparkle | fire | smoke), color (Color3 | ColorSequence), n?, rate?, stream?, dir? (where they
--         shoot; else every way), spread? (degrees), speed? {a, b}, size? {a, b}, alpha? {a, b}, life? {a, b},
--         accel?, drag?, light? (emission), spin? (deg/s), delay? }
local function nseq(v)
	if type(v) == "number" then
		return NumberSequence.new({ NumberSequenceKeypoint.new(0, v), NumberSequenceKeypoint.new(1, v) })
	end
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, v[1]), NumberSequenceKeypoint.new(1, v[2]) })
end
function Actor:emit(at, o)
	local function make()
		if not self.alive then
			return nil
		end
		local cf = o.dir and (CFrame.lookAt(at, at + o.dir) * CFrame.Angles(-math.pi / 2, 0, 0)) or CFrame.new(at)
		local anchor = self:part(Vector3.one * 0.2, WHITE, { transparency = 1, cf = cf })
		local e = Instance.new("ParticleEmitter")
		e.Name = "FxParticles"
		e.Texture = TEX[o.tex or "sparkle"] or SPARKLE_TEX
		local c = o.color or WHITE
		e.Color = typeof(c) == "ColorSequence" and c or ColorSequence.new(c)
		e.LightEmission = o.light or 1
		e.LightInfluence = 0
		e.Size = nseq(o.size or { 0.6, 0 })
		e.Transparency = nseq(o.alpha or 0)
		local sp, lf = o.speed or { 6, 12 }, o.life or { 0.5, 1 }
		e.Speed = NumberRange.new(sp[1], sp[2])
		e.Lifetime = NumberRange.new(lf[1], lf[2])
		e.SpreadAngle = Vector2.new(o.spread or 180, o.spread or 180)
		e.Acceleration = o.accel or Vector3.zero
		e.Drag = o.drag or 2
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-(o.spin or 90), o.spin or 90)
		e.Rate = 0
		e.Parent = anchor
		table.insert(self.emitters, e)
		pcall(function()
			e.TimeScale = math.clamp(self:speed(), 0.05, 1)
			if o.n then
				e:Emit(math.min(80, math.max(1, math.floor(o.n * self.mult))))
			end
		end)
		if o.rate then
			e.Rate = o.rate * self.mult
			self:after(o.stream or 0.5, function()
				e.Enabled = false
			end)
		end
		return e
	end
	if o.delay and o.delay > 0 then
		self:after(o.delay, make)
		return nil
	end
	return make()
end

-- a beam of light from a to b (two anchors with an Attachment each): move it by its ends' parts (.a, .b), fade it
-- by its widths. o = { alpha?, curve0?, curve1?, segments?, light?, face? }
function Actor:beam(a, b, color, w0, w1, o)
	o = o or {}
	local pa = self:part(Vector3.one * 0.2, WHITE, { transparency = 1, cf = CFrame.new(a) })
	local pb = self:part(Vector3.one * 0.2, WHITE, { transparency = 1, cf = CFrame.new(b) })
	local a0 = Instance.new("Attachment")
	a0.Parent = pa
	local a1 = Instance.new("Attachment")
	a1.Parent = pb
	local bm = Instance.new("Beam")
	bm.Name = "FxBeam"
	bm.Attachment0, bm.Attachment1 = a0, a1
	bm.Color = typeof(color) == "ColorSequence" and color or ColorSequence.new(color)
	bm.Width0, bm.Width1 = w0, w1 or w0
	bm.LightEmission = o.light or 1
	bm.LightInfluence = 0
	bm.FaceCamera = o.face ~= false
	bm.Segments = o.segments or 12
	bm.CurveSize0, bm.CurveSize1 = o.curve0 or 0, o.curve1 or 0
	bm.Transparency = nseq(o.alpha or 0)
	bm.Parent = pa
	return { beam = bm, a = pa, b = pb }
end

-- a word that pops in over the spot, does something, and fades (a billboard: Actor:text)
--   o = { w?, h?, font?, stroke?, noStroke?, rotation?, delay?, life? (1.4), wobble?, spin? (deg/s), float? (studs/s),
--         elastic? (a springier pop) }
function Actor:word(str, offset, color, o)
	o = o or {}
	local function make()
		if not self.alive then
			return nil
		end
		local w = self:text(str, offset, color, o)
		local W, H = o.w or 6, o.h or 2
		local life = o.life or 1.4
		local born = self.age
		w.gui.Size = UDim2.fromScale(0.01, 0.01)
		w.label.TextStrokeTransparency = o.noStroke and 1 or 0
		table.insert(self.ticks, function(_, now)
			local v = now - born
			if w.gone then
				return
			elseif v > life then
				w.gone = true
				w.label.TextTransparency, w.label.TextStrokeTransparency = 1, 1
				return
			end
			local k = math.max(0.01, o.elastic and outElastic(v / 0.6) or outBack(v / 0.25))
			local fade = clamp01((v - (life - 0.3)) / 0.3)
			w.gui.Size = UDim2.fromScale(W * k, H * k)
			w.label.TextTransparency = fade
			w.label.TextStrokeTransparency = o.noStroke and 1 or fade
			local rot = o.rotation or 0
			if o.wobble then
				rot += math.sin(v * 12) * 7
			end
			if o.spin then
				rot += v * o.spin
			end
			w.label.Rotation = rot
			w.anchor.CFrame = CFrame.new(self.at + offset + UP * (o.float or 0) * v)
		end)
		return w
	end
	if o.delay and o.delay > 0 then
		self:after(o.delay, make)
		return nil
	end
	return make()
end

-- a burst of stock sparkle particles (a ParticleEmitter on an anchor), slowed with the effect
function Actor:sparkleBurst(at, color, n, speed)
	local anchor = self:part(Vector3.new(0.2, 0.2, 0.2), WHITE, { transparency = 1, cf = CFrame.new(at) })
	local e = Instance.new("ParticleEmitter")
	e.Name = "Sparkle"
	e.Texture = SPARKLE_TEX
	e.Color = ColorSequence.new(color or WHITE)
	e.LightEmission = 1
	e.Size = NumberSequence.new(0.7, 0)
	e.Speed = NumberRange.new((speed or 14) * 0.5, speed or 14)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Lifetime = NumberRange.new(0.5, 1.1)
	e.Rate = 0
	e.Drag = 3
	e.Parent = anchor
	table.insert(self.emitters, e)
	pcall(function()
		e.TimeScale = math.clamp(self:speed(), 0.05, 1)
		e:Emit(math.floor((n or 20) * self.mult))
	end)
	return e
end

-- the stand-in: move it, fade it (all pcall'd: a copied avatar can hold anything)
function Actor:bodyPivot(cf)
	if self.body then
		pcall(function()
			self.body:PivotTo(cf)
		end)
	end
end
-- (its parts and decals, looked up once: fading it every frame shouldn't walk the whole model every frame)
function Actor:bodyBits()
	if not self.bodyList then
		local parts, decals = {}, {}
		pcall(function()
			for _, d in self.body:GetDescendants() do
				if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
					table.insert(parts, d)
				elseif d:IsA("Decal") then
					table.insert(decals, d)
				end
			end
		end)
		self.bodyList = { parts = parts, decals = decals }
	end
	return self.bodyList
end
function Actor:bodyFade(alpha)
	if not self.body then
		return
	end
	local list = self:bodyBits()
	pcall(function()
		for _, d in list.parts do
			self.bodyAlpha[d] = self.bodyAlpha[d] or d.Transparency
			d.Transparency = self.bodyAlpha[d] + (1 - self.bodyAlpha[d]) * alpha
		end
		for _, d in list.decals do
			d.Transparency = alpha
		end
	end)
	if self.glow then
		self.glow.FillTransparency = math.max(self.glowFill or 0, alpha)
		self.glow.OutlineTransparency = math.max(self.glowLine or 0, alpha)
	end
end
function Actor:bodyColor(color)
	if not self.body then
		return
	end
	local list = self:bodyBits()
	pcall(function()
		for _, d in list.parts do
			d.Color = color
		end
	end)
end
-- a glow over the whole stand-in (a Highlight: works on any avatar): charred black, golden, the void's purple
function Actor:bodyGlow(fill, outline, fillAlpha, lineAlpha)
	if not self.body then
		return nil
	end
	if not self.glow then
		local ok, h = pcall(function()
			local x = Instance.new("Highlight")
			x.Name = "FxGlow"
			x.DepthMode = Enum.HighlightDepthMode.Occluded
			x.Adornee = self.body
			x.Parent = self.body
			return x
		end)
		if not ok or not h then
			return nil
		end
		self.glow = h
		table.insert(self.parts, h)
	end
	self.glowFill, self.glowLine = fillAlpha or 0, lineAlpha or 0
	self.glow.FillColor = fill
	self.glow.OutlineColor = outline or fill
	self.glow.FillTransparency = self.glowFill
	self.glow.OutlineTransparency = self.glowLine
	return self.glow
end
-- the stand-in's size (1: as it was); only rescaled when it really changes
function Actor:bodyScale(s)
	if not self.body or math.abs((self.bodySize or 1) - s) < 0.02 then
		return
	end
	self.bodySize = s
	pcall(function()
		self.body:ScaleTo(s)
	end)
end

function Actor:speed()
	local s = self.scale
	if not self.fixed then
		s *= math.clamp(Effects.timeScale or 1, 0, 1)
	end
	return s
end

local GRAVITY = 60

function Actor:step(dt)
	local sp = self:speed()
	dt *= sp
	self.age += dt
	local t = self.age
	for i = #self.timers, 1, -1 do
		local tm = self.timers[i]
		if t >= tm.at then
			table.remove(self.timers, i)
			pcall(tm.fn)
		end
	end
	for _, e in self.emitters do
		pcall(function()
			e.TimeScale = math.clamp(sp, 0.05, 1)
		end)
	end
	for i = #self.bits, 1, -1 do
		local b = self.bits[i]
		local age = t - b.born
		local f = age / b.life
		local p = b.part
		if f >= 1 or not p.Parent then
			if b.onDie then
				pcall(b.onDie, b)
			end
			p.Transparency = 1
			table.remove(self.bits, i)
		else
			b.vel = b.vel * (1 - math.min(1, dt * b.drag)) + Vector3.new(0, -GRAVITY * b.grav * dt, 0)
			local sway = Vector3.zero
			if b.sway then
				sway = Vector3.new(math.sin(age * b.sway * 4 + b.born * 7), 0, math.cos(age * b.sway * 3 + b.born * 5))
					* b.sway
					* dt
					* 6
			end
			b.pos += b.vel * dt + sway
			if b.floor and b.pos.Y < b.floor then
				b.pos = Vector3.new(b.pos.X, b.floor, b.pos.Z)
				b.vel = Vector3.new(b.vel.X * 0.7, math.abs(b.vel.Y) * b.bounce, b.vel.Z * 0.7)
				b.spin *= 0.6
			end
			b.rot = CFrame.fromAxisAngle(b.axis, b.spin * dt) * b.rot
			if b.face and b.vel.Magnitude > 0.05 then
				p.CFrame = CFrame.lookAt(b.pos, b.pos + b.vel)
			else
				p.CFrame = CFrame.new(b.pos) * b.rot
			end
			local k = f > 0.6 and (f - 0.6) / 0.4 or 0
			if b.grow then
				p.Size = b.size * (1 + 1.6 * outCubic(f))
			elseif b.twinkle then
				local tw = 0.5 + 0.5 * math.sin(age * b.twinkle + b.born * 13)
				p.Size = b.size * (0.35 + 0.65 * tw) * (1 - k * 0.8)
			elseif b.shrink then
				p.Size = b.size * (1 - 0.7 * k)
			end
			if b.color then
				p.Color = b.color(age)
			end
			p.Transparency = b.alpha + (1 - b.alpha) * k * k
		end
	end
	if self.tick then
		local ok, err = pcall(self.tick, self, t, dt)
		if not ok then
			warn("[KillEffects] " .. tostring(err))
			self.tick = nil
		end
	end
	if t >= self.life then
		self:destroy()
		return false
	end
	return true
end

function Actor:destroy()
	if not self.alive then
		return
	end
	self.alive = false
	for _, p in self.parts do
		p:Destroy()
	end
	if self.ownsBody and self.body then
		self.body:Destroy()
	end
	self.parts, self.bits, self.emitters, self.timers = {}, {}, {}, {}
	if self.anchor then
		self.anchor:Destroy()
	end
end

-- Shapes ------------------------------------------------------------------------------------------------------------
-- Each is a little film in three beats: a wind-up (anticipation), the hit (impact) and what's left (aftermath), with
-- its own motion, colours, sounds and length (fx.life). The cheaper ones are shorter and simpler, never the same.
local S = {}

local function colorFn(fx, token, i)
	if token == "rainbow" then
		return rainbow(i, 0)
	end
	return Cosmetics.color(token, fx.team)
end

-- away from the killer, along the floor
local function facing(fx)
	local d = Vector3.new(fx.dir.X, 0, fx.dir.Z)
	return d.Magnitude > 0.1 and d.Unit or Vector3.new(1, 0, 0)
end

-- a tick that runs fn(u, now) from `from` (the effect's own seconds) for dur, u going 0 .. 1, and once more at 1
local function during(fx, from, dur, fn)
	local done = false
	table.insert(fx.ticks, function(_, now)
		if done then
			return
		end
		local u = (now - from) / dur
		if u < 0 then
			return
		end
		if u >= 1 then
			done, u = true, 1
		end
		fn(u, now)
	end)
end

-- a soft white poof (balls growing and fading)
local function poof(fx, at, n, color, size)
	for _ = 1, math.max(3, math.floor(n * fx.mult)) do
		local p = fx:part(Vector3.one * rng:NextNumber(0.8, 1.6) * (size or 1), color or WHITE, {
			ball = true,
			material = Enum.Material.SmoothPlastic,
			transparency = 0.15,
			cf = CFrame.new(at + randomDir() * 0.6),
		})
		local b = fx:bit(p, randomDir(-0.2) * rng:NextNumber(4, 9), { drag = 3, life = rng:NextNumber(0.5, 0.9) })
		b.shrink = false
		b.grow = true
	end
end

-- a quick flash ball and a ring on the floor
local function flash(fx, color, r)
	local ball = fx:part(Vector3.one * 1, color, { ball = true, transparency = 0.1 })
	local ring = fx:part(Vector3.new(0.25, 1, 1), color, {
		cylinder = true,
		transparency = 0.2,
		cf = CFrame.new(fx.pos + UP * 0.12) * CFrame.Angles(0, 0, math.rad(90)),
	})
	during(fx, fx.age, 0.45, function(u)
		local s = 1 + (r or 6) * outCubic(u)
		ball.Size = Vector3.one * (1 + 3 * outCubic(u))
		ball.Transparency = u >= 1 and 1 or 0.1 + 0.9 * u
		ring.Size = Vector3.new(0.25, s * 2, s * 2)
		ring.Transparency = u >= 1 and 1 or 0.2 + 0.8 * u
	end)
end

-- a ball of light at a spot that swells and fades
local function glowBall(fx, at, color, size, life)
	local p = fx:part(Vector3.one * size, color, { ball = true, transparency = 0.15, cf = CFrame.new(at) })
	local b = fx:bit(p, Vector3.zero, { life = life or 0.35 })
	b.shrink = false
	b.grow = true
	return p
end

-- a flat disc on the floor (or in the air) that races out and fades
local function ring(fx, at, color, radius, dur, thick, tilt)
	local p = fx:part(Vector3.new(thick or 0.2, 0.5, 0.5), color, {
		cylinder = true,
		transparency = 1,
		cf = CFrame.new(at) * (tilt or CFrame.new()) * CFrame.Angles(0, 0, math.rad(90)),
	})
	during(fx, fx.age, dur or 0.5, function(u)
		local s = 0.5 + radius * 2 * outCubic(u)
		p.Size = Vector3.new(thick or 0.2, s, s)
		p.Transparency = u >= 1 and 1 or 0.15 + 0.85 * u
	end)
	return p
end

-- a ring made of short pieces (a hoop, not a disc): place(cf, radius, alpha) lays it out round cf's Y axis
local function hoop(fx, n, color, width)
	local h = { pieces = {} }
	for i = 1, math.max(6, math.floor(n)) do
		h.pieces[i] = fx:part(Vector3.new(width, width, 1), color, { transparency = 1 })
	end
	function h.place(cf, r, alpha)
		local m = #h.pieces
		local len = math.max(0.05, 2 * math.pi * r / m * 1.08)
		for i, p in h.pieces do
			p.Size = Vector3.new(width, width, len)
			p.CFrame = cf * CFrame.Angles(0, i / m * math.pi * 2, 0) * CFrame.new(r, 0, 0)
			p.Transparency = alpha or 0
		end
	end
	return h
end

-- streaks flying out from a spot, pointing where they go
local function sparks(fx, at, n, color, speed, o)
	o = o or {}
	for i = 1, math.max(2, math.floor(n * fx.mult)) do
		local c = type(color) == "function" and color(i) or color
		local p = fx:part(Vector3.new(o.w or 0.1, o.w or 0.1, o.len or 1), c, { cf = CFrame.new(at) })
		fx:bit(p, randomDir(o.up or 0) * rng:NextNumber(speed * 0.6, speed), {
			grav = o.grav or 0.6,
			drag = o.drag or 1.4,
			face = true,
			life = o.life or rng:NextNumber(0.4, 0.8),
			floor = o.floor,
			bounce = o.bounce,
		})
	end
end

-- a jagged bolt from a to b (neon pieces, forking now and then), there for `life`
local function bolt(fx, from, to, width, color, life, forks)
	local pts = { from }
	local segs = 8
	local jag = (to - from).Magnitude * 0.025 + 0.6
	for i = 1, segs - 1 do
		local p = from:Lerp(to, i / segs)
		table.insert(pts, p + Vector3.new(rng:NextNumber(-jag, jag), 0, rng:NextNumber(-jag, jag)))
	end
	table.insert(pts, to)
	local made = {}
	local function seg(a, b, w, l)
		local p = fx:part(Vector3.new(w, w, (b - a).Magnitude + w), color, { cf = CFrame.lookAt((a + b) / 2, b) })
		fx:bit(p, Vector3.zero, { life = l, shrink = false })
		return p
	end
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		table.insert(made, seg(a, b, width, life))
		if forks and i > 1 and i < #pts - 2 and rng:NextNumber() < forks then
			local q = b + Vector3.new(rng:NextNumber(-7, 7), -rng:NextNumber(3, 9), rng:NextNumber(-7, 7))
			local mid = (b + q) / 2 + Vector3.new(rng:NextNumber(-1.5, 1.5), 0, rng:NextNumber(-1.5, 1.5))
			table.insert(made, seg(b, mid, width * 0.5, life * 0.8))
			table.insert(made, seg(mid, q, width * 0.35, life * 0.7))
		end
	end
	return made
end

-- a crackle of electricity from a to b, gone in a blink
local function arc(fx, a, b, color, life)
	local prev = a
	local span = (a - b).Magnitude
	for i = 1, 3 do
		local nextP = a:Lerp(b, i / 3)
		if i < 3 then
			nextP += randomDir() * span * 0.18
		end
		local len = (nextP - prev).Magnitude
		if len > 0.02 then
			local p = fx:part(Vector3.new(0.08, 0.08, len), color, { cf = CFrame.lookAt((prev + nextP) / 2, nextP) })
			fx:bit(p, Vector3.zero, { life = life or 0.1, shrink = false })
		end
		prev = nextP
	end
end

-- the screen's colour for a moment (only in the arena, one at a time): eased in, held, eased out
local gradeUntil = 0
local function grade(fx, props, inT, hold, outT)
	if not fx:inWorld() or os.clock() < gradeUntil then
		return nil
	end
	local ok, cc = pcall(function()
		local c = Instance.new("ColorCorrectionEffect")
		c.Name = "TW_KillFx"
		c.Parent = game:GetService("Lighting")
		return c
	end)
	if not ok or not cc then
		return nil
	end
	local dur = inT + hold + outT
	gradeUntil = os.clock() + dur / math.max(0.05, fx:speed())
	table.insert(fx.parts, cc)
	local pure = Color3.new(1, 1, 1)
	during(fx, fx.age, dur, function(u)
		local t = u * dur
		local k = t < inT and t / inT or (t < inT + hold and 1 or math.max(0, 1 - (t - inT - hold) / outT))
		cc.Brightness = (props.brightness or 0) * k
		cc.Contrast = (props.contrast or 0) * k
		cc.Saturation = (props.saturation or 0) * k
		cc.TintColor = pure:Lerp(props.tint or pure, k)
	end)
	return cc
end

-- a flutter of paper bits (flat, swaying, spinning) that settle on the floor
local function paper(fx, at, n, colorOf, speed, o)
	o = o or {}
	for i = 1, math.max(3, math.floor(n * fx.mult)) do
		local p = fx:part(Vector3.new(0.34, 0.03, 0.2), colorOf(i), {
			material = Enum.Material.SmoothPlastic,
			cf = CFrame.new(at) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0),
		})
		fx:bit(p, (o.dir or randomDir(0.3)) * rng:NextNumber(speed * 0.5, speed) + randomDir() * 3, {
			grav = 0.07,
			drag = 2.4,
			spin = rng:NextNumber(4, 9),
			sway = rng:NextNumber(0.6, 1.3),
			life = rng:NextNumber(1.3, 1.9),
			floor = fx.pos.Y + 0.05,
			bounce = 0,
		})
	end
end

-- the ladder's and the goals' -------------------------------------------------------------------------------------

-- Cubes: the cubes shiver in tight (a beat), burst and tumble, bounce on the floor and blink out one by one
S.cubes = function(fx)
	fx.life = 1.9
	local cubes = {}
	for i = 1, fx.n do
		local c = i % 3 == 0 and WHITE or colorFn(fx, fx.look.color, i)
		local home = fx.at + Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-2, 1.4), rng:NextNumber(-0.6, 0.6))
		local p = fx:part(Vector3.one * rng:NextNumber(0.45, 0.85), c, {
			cf = CFrame.new(home) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0),
		})
		cubes[i] = { p = p, home = home }
	end
	during(fx, 0, 0.16, function(u)
		for _, e in cubes do
			e.p.Position = e.home:Lerp(fx.at, u * 0.45) + randomDir() * 0.07
		end
	end)
	fx:sound("draw", 1.6, 0.3)
	fx:after(0.16, function()
		flash(fx, fx.color, 5)
		fx:light(fx.at, fx.color, 3, 14, 0.4)
		fx:sound("pop", 0.85, 0.7)
		fx:sound("thud", 1.3, 0.5)
		for i, e in cubes do
			local d = e.p.Position - fx.at
			d = d.Magnitude > 0.05 and d.Unit or randomDir()
			local b = fx:bit(e.p, d * rng:NextNumber(12, 22) + UP * rng:NextNumber(6, 12), {
				grav = 1,
				drag = 0.6,
				spin = rng:NextNumber(5, 12),
				floor = fx.pos.Y + 0.3,
				bounce = 0.5,
				life = 1 + i / #cubes * 0.6,
			})
			if i % 3 == 0 then
				b.onDie = function(bb)
					fx:sparkleBurst(bb.pos, WHITE, 3, 4)
				end
			end
		end
		fx:sparkleBurst(fx.at, fx.color, 18, 16)
	end)
	for j = 1, 4 do
		fx:sound("tick", 1.6 + j * 0.15, 0.25, 1.1 + j * 0.14)
	end
end

-- Poof: a cartoon dust cloud: it billows out low and round with a soft whump, little stars blink in it, then it
-- drifts up and thins away
S.smoke = function(fx)
	fx.life = 1.7
	local grey = Color3.fromRGB(236, 236, 242)
	local tint = fx.color:Lerp(WHITE, 0.55)
	fx:sound("pop", 0.55, 0.75)
	fx:sound("wind", 2.4, 0.3)
	local n = math.max(6, math.floor(14 * fx.mult))
	for i = 1, n do
		local a = i / n * math.pi * 2
		local dir = Vector3.new(math.cos(a), rng:NextNumber(0.05, 0.5), math.sin(a))
		local p = fx:part(Vector3.one * rng:NextNumber(1.3, 2.3), i % 3 == 0 and tint or grey, {
			ball = true,
			material = Enum.Material.SmoothPlastic,
			transparency = 0.1,
			cf = CFrame.new(fx.at - UP * 1.4),
		})
		local b = fx:bit(p, dir * rng:NextNumber(9, 14), { grav = -0.04, drag = 3.4, life = rng:NextNumber(1.1, 1.5) })
		b.shrink = false
		b.grow = true
	end
	poof(fx, fx.at, 6, grey, 1.7)
	for i = 1, 3 do
		local off = Vector3.new(rng:NextNumber(-2, 2), rng:NextNumber(-0.5, 1.5), rng:NextNumber(-2, 2))
		fx:word("✦", off, YELLOW, { w = 1.3, h = 1.3, delay = 0.12 + i * 0.13, life = 0.55, spin = 320 })
		fx:sound("tick", 2.4 + i * 0.2, 0.2, 0.12 + i * 0.13)
	end
end

-- Shatter: a crack runs through the air where they stood (a beat), then it breaks like glass: shards fly and
-- tumble, land and glint, and tinkle as they settle. Triple Shatter breaks three times, bigger each time; VIP
-- Shatter is black glass with gold in it, and a gold VIP.
S.shards = function(fx)
	fx.life = 1.9 + ((fx.look.bursts or 1) - 1) * 0.2
	local gold = fx.look.trim == "gold"
	local bursts = fx.look.bursts or 1
	local cracks = {}
	for i = 1, math.max(4, math.floor(7 * fx.mult)) do
		local d = randomDir()
		cracks[i] = { p = fx:part(Vector3.new(0.06, 0.06, 0.1), WHITE, {}), d = d, len = rng:NextNumber(1.2, 2.6) }
	end
	during(fx, 0, 0.14, function(u)
		for _, c in cracks do
			local len = c.len * outCubic(u)
			c.p.Size = Vector3.new(0.06, 0.06, math.max(0.1, len))
			c.p.CFrame = CFrame.lookAt(fx.at + c.d * len / 2, fx.at + c.d * len)
			c.p.Transparency = u >= 1 and 1 or 0
		end
	end)
	fx:sound("tick", 2.6, 0.4)
	for k = 1, bursts do
		fx:after(0.14 + (k - 1) * 0.26, function()
			local power = 1 + (k - 1) * 0.35
			fx:sound("glass", 1.15 - k * 0.1, 0.55 + k * 0.12)
			if k == bursts then
				fx:sound("thud", 1.1, 0.5)
			end
			flash(fx, gold and GOLD or fx.color, 5 * power)
			fx:light(fx.at, gold and GOLD or WHITE, 2.5 * power, 14, 0.35)
			for i = 1, math.max(3, math.floor(fx.n / bursts + 0.5)) do
				local c = (gold and i % 3 == 0) and GOLD or (i % 3 == 0 and WHITE or colorFn(fx, fx.look.color, i))
				local p = fx:part(Vector3.new(rng:NextNumber(0.1, 0.25), 0.06, rng:NextNumber(0.7, 1.5)) * power, c, {
					wedge = true,
					material = Enum.Material.Glass,
					transparency = 0.12,
					cf = CFrame.new(fx.at) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0),
				})
				fx:bit(p, randomDir(-0.1) * rng:NextNumber(16, 30) * power, {
					grav = 0.9,
					drag = 1.1,
					spin = rng:NextNumber(6, 14),
					floor = fx.pos.Y + 0.05,
					bounce = 0.25,
					life = rng:NextNumber(1.1, 1.6),
					twinkle = i % 4 == 0 and 30 or nil, -- (a glint as it lies there)
				})
			end
			fx:sparkleBurst(fx.at, gold and GOLD or WHITE, 14, 20)
		end)
	end
	fx:sound("glass", 2.3, 0.18, 0.85 + bursts * 0.2)
	if gold then
		fx:word(
			"VIP",
			UP * 3.2,
			GOLD,
			{ w = 4, h = 1.6, delay = 0.3, life = 1.3, float = 0.6, font = Enum.Font.LuckiestGuy }
		)
	end
end

-- Pixels: they're pixels for a beat (a blocky body of squares, flickering in top to bottom), then they dissolve from
-- the head down, each square peeling off and drifting away up and on, flickering, with a rising run of blips
S.pixels = function(fx)
	fx.life = 2
	local face = facing(fx)
	local right = face:Cross(UP).Unit
	local rows = math.max(4, math.floor(7 * math.sqrt(fx.mult)))
	local px = {}
	for r = 1, rows do
		for c = 1, 3 do
			local i = #px + 1
			local home = fx.at + right * ((c - 2) * 0.62) + UP * (1.6 - (r - 1) * (4.2 / rows))
			local p = fx:part(Vector3.new(0.58, 0.58, 0.2), i % 4 == 0 and WHITE or colorFn(fx, fx.look.color, i), {
				transparency = 1,
				cf = CFrame.lookAt(home, home - face),
			})
			px[i] = { p = p, row = r }
		end
	end
	during(fx, 0, 0.32, function(u)
		for _, e in px do
			e.p.Transparency = (u * rows >= e.row - 1) and (rng:NextNumber() < 0.15 and 0.6 or 0) or 1
		end
	end)
	fx:sound("click", 1.6, 0.4)
	for r = 1, rows do
		fx:after(0.34 + (r - 1) * 0.07, function()
			fx:sound("tick", 1.1 + r * 0.13, 0.28)
			for _, e in px do
				if e.row == r then
					e.p.Transparency = 0
					fx:bit(
						e.p,
						Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(3, 7), rng:NextNumber(-3, 3)) + face * 3,
						{
							drag = 0.8,
							spin = rng:NextNumber(3, 8),
							twinkle = 16,
							life = rng:NextNumber(0.9, 1.2),
						}
					)
				end
			end
		end)
	end
end

-- Ring: a bright point pulls tight (a beat), a shockwave races out over the floor, and the floor tiles leap as it
-- passes under them, a ripple in three rings
S.ring = function(fx)
	fx.life = 1.7
	local core = fx:part(Vector3.one * 1.6, fx.color, { ball = true, transparency = 0.2 })
	during(fx, 0, 0.18, function(u)
		core.Size = Vector3.one * (1.6 - 1.3 * u)
		core.Transparency = u >= 1 and 1 or 0.2
	end)
	fx:sound("whistle", 2.4, 0.3)
	fx:after(0.18, function()
		fx:sound("ping", 0.7, 0.6)
		fx:sound("thud", 0.9, 0.6)
		ring(fx, fx.pos + UP * 0.15, fx.color, 9, 0.55, 0.3)
		ring(fx, fx.pos + UP * 0.6, WHITE, 6, 0.7, 0.12)
		flash(fx, fx.color, 4)
		fx:light(fx.at, fx.color, 3, 16, 0.5)
	end)
	local tiles = {}
	for i = 1, fx.n do
		local a = i / fx.n * math.pi * 2 + (i % 3) * 0.4
		local r = 2.5 + (i % 3) * 2
		local p = fx:part(Vector3.new(0.9, 0.25, 0.9), i % 2 == 0 and fx.color or WHITE, {
			transparency = 1,
			cf = CFrame.new(fx.pos + Vector3.new(math.cos(a) * r, 0.1, math.sin(a) * r)) * CFrame.Angles(0, -a, 0),
		})
		tiles[i] = { p = p, r = r, base = p.CFrame }
	end
	during(fx, 0.18, 1.4, function(u)
		local front = u * 22
		for _, e in tiles do
			local d = front - e.r
			local h = (d > 0 and d < 3.5) and math.sin(d / 3.5 * math.pi) * 1.3 or 0
			e.p.CFrame = e.base * CFrame.new(0, h, 0) * CFrame.Angles(h * 0.4, 0, 0)
			e.p.Transparency = d > 0 and clamp01((u - 0.65) / 0.35) or 1
		end
	end)
end

-- Slice: a glint where the blade starts (a beat), one clean slash across them, and the air they stood in comes
-- apart in two halves that slide off the cut and drop
S.slice = function(fx)
	fx.life = 1.6
	local face = facing(fx)
	local right = face:Cross(UP).Unit
	local cutDir = (right + UP * 0.8).Unit
	local from, to = fx.at - cutDir * 3.5, fx.at + cutDir * 3.5
	fx:word("✦", from - fx.at, WHITE, { w = 1.6, h = 1.6, life = 0.3, spin = 400 })
	fx:sound("unsheath", 1.5, 0.5)
	local blade = fx:part(Vector3.new(0.08, 0.08, 0.1), WHITE, {})
	local trail = fx:part(Vector3.new(0.02, 0.5, 0.1), fx.color, { transparency = 0.4 })
	during(fx, 0.18, 0.12, function(u)
		local tip = from:Lerp(to, outCubic(u))
		local len = math.max(0.1, (tip - from).Magnitude)
		blade.Size = Vector3.new(0.08, 0.08, len)
		blade.CFrame = CFrame.lookAt((from + tip) / 2, tip)
		trail.Size = Vector3.new(0.02, 0.6 * (1 - u * 0.5), len)
		trail.CFrame = blade.CFrame * CFrame.new(0, -0.3, 0)
	end)
	fx:sound("slash", 1.3, 0.6, 0.18)
	fx:after(0.3, function()
		fx:bit(blade, Vector3.zero, { life = 0.25 })
		fx:bit(trail, Vector3.zero, { life = 0.2 })
		fx:light(fx.at, WHITE, 3, 12, 0.3)
		fx:sound("glass", 1.8, 0.3)
		local victim = Cosmetics.color("team", fx.victimTeam)
		-- the halves: above the cut slides up along it, below drops; ink spills from the cut
		local normal = cutDir:Cross(face).Unit
		for side = -1, 1, 2 do
			local p = fx:part(Vector3.new(2, 2.2, 1), side > 0 and victim or victim:Lerp(INK, 0.4), {
				material = Enum.Material.SmoothPlastic,
				transparency = 0.1,
				cf = CFrame.lookAt(fx.at + normal * side * 1.1, fx.at + normal * side * 1.1 + face),
			})
			fx:bit(p, cutDir * side * 6 + normal * side * 3 + UP * 2, {
				grav = 0.8,
				drag = 0.5,
				spin = 3,
				axis = face,
				floor = fx.pos.Y + 0.5,
				bounce = 0.2,
				life = 1.1,
			})
		end
		sparks(fx, fx.at, 10, INK, 14, { grav = 0.8, floor = fx.pos.Y + 0.05, w = 0.14, len = 0.5 })
		fx:sound("thud", 1.2, 0.45, 0.5)
	end)
end

-- Fold: they become a square of paper for a beat, which folds in half, in half again, flips, and is gone with a
-- click
S.fold = function(fx)
	fx.life = 1.5
	local face = facing(fx)
	local base = CFrame.lookAt(fx.at, fx.at - face)
	local front, back = colorFn(fx, fx.look.color, 1), WHITE
	local quarters = {}
	for qx = -1, 1, 2 do
		for qy = -1, 1, 2 do
			for layer = 0, 1 do
				local p = fx:part(Vector3.new(1.25, 1.25, 0.04), layer == 0 and front or back, {
					material = Enum.Material.SmoothPlastic,
					transparency = 1,
				})
				table.insert(quarters, { p = p, x = qx * 0.63, y = qy * 0.63, z = layer == 0 and -0.025 or 0.025 })
			end
		end
	end
	local function lay(a1, a2, s, spin)
		local cf = base * CFrame.Angles(0, 0, spin) * CFrame.new(0, 0, 0)
		for _, q in quarters do
			local local_ = CFrame.new(q.x, q.y, q.z)
			if q.x > 0 then
				local_ = CFrame.Angles(0, a1, 0) * local_
			end
			if q.y > 0 then
				local_ = CFrame.Angles(a2, 0, 0) * local_
			end
			q.p.CFrame = cf * CFrame.new(local_.Position * s) * local_.Rotation
			q.p.Size = Vector3.new(1.25 * s, 1.25 * s, 0.04)
			q.p.Transparency = s < 0.05 and 1 or 0
		end
	end
	during(fx, 0, 1.25, function(u)
		local t = u * 1.25
		local appear = outBack(t / 0.15)
		local a1 = outCubic(clamp01((t - 0.2) / 0.25)) * math.pi
		local a2 = -outCubic(clamp01((t - 0.5) / 0.25)) * math.pi
		local s = 1.6 * appear * (1 - clamp01((t - 0.85) / 0.35))
		lay(a1, a2, math.max(0.01, s), clamp01((t - 0.8) / 0.4) * math.pi * 3)
	end)
	fx:sound("draw", 1.8, 0.35, 0.2)
	fx:sound("draw", 2.1, 0.35, 0.5)
	fx:sound("click", 1.4, 0.5, 1.15)
	fx:after(1.15, function()
		fx:sparkleBurst(fx.at, WHITE, 8, 6)
	end)
end

-- Static: TV static where they stood, in a red and cyan split, crackling (a beat); then the set switches off: it
-- squashes to a line, the line to a dot, and the dot fades
S.static = function(fx)
	fx.life = 1.5
	local face = facing(fx)
	local cols, rows = 4, math.max(5, math.floor(7 * math.sqrt(fx.mult)))
	local base = CFrame.lookAt(fx.at, fx.at - face)
	local cells = {}
	for r = 1, rows do
		for c = 1, cols do
			local p = fx:part(Vector3.new(0.5, 0.6, 0.06), WHITE, { material = Enum.Material.SmoothPlastic })
			table.insert(cells, { p = p, x = (c - (cols + 1) / 2) * 0.52, y = ((rows + 1) / 2 - r) * 0.62 })
		end
	end
	local red = fx:part(Vector3.new(2.2, 4.4, 0.04), Color3.fromRGB(255, 40, 70), { transparency = 0.6 })
	local cyan = fx:part(Vector3.new(2.2, 4.4, 0.04), Color3.fromRGB(40, 220, 255), { transparency = 0.6 })
	local nextAt = 0
	during(fx, 0, 1.4, function(u, now)
		local t = u * 1.4
		local sy = t < 0.85 and 1 or math.max(0.03, 1 - (t - 0.85) / 0.15)
		local sx = t < 1.0 and 1 or math.max(0, 1 - (t - 1.0) / 0.12)
		local gone = t > 1.12
		local scramble = now >= nextAt
		if scramble then
			nextAt = now + 0.05
		end
		for _, e in cells do
			e.p.Size = Vector3.new(0.5 * sx + 0.02, 0.6 * sy, 0.06)
			e.p.CFrame = base * CFrame.new(e.x * sx, e.y * sy, 0)
			if scramble then
				local v = rng:NextNumber()
				e.p.Color = sy < 1 and WHITE
					or (v < 0.4 and INK or (v < 0.75 and WHITE or Color3.fromRGB(140, 140, 150)))
			end
			e.p.Transparency = gone and 1 or 0
		end
		local j = sy < 1 and 0 or rng:NextNumber(0.1, 0.3)
		red.CFrame = base * CFrame.new(-j, 0, 0.1)
		cyan.CFrame = base * CFrame.new(j, 0, 0.12)
		red.Size = Vector3.new(2.2 * sx + 0.02, 4.4 * sy, 0.04)
		cyan.Size = red.Size
		red.Transparency = sy < 1 and 1 or 0.6
		cyan.Transparency = red.Transparency
	end)
	local hiss = fx:sound("wind", 3.2, 0.35)
	fx:after(0.85, function()
		if hiss then
			hiss:Stop()
		end
		fx:sound("click", 0.7, 0.6)
		fx:sound("ping", 3, 0.25)
	end)
	fx:after(1.12, function()
		glowBall(fx, fx.at, WHITE, 0.6, 0.3)
	end)
end

-- Spark: a sparkler fizzes where they stood (a beat), then it cracks: a flash, sparks bursting out and bouncing
-- over the floor, and a fountain of them spitting up a little longer
S.spark = function(fx)
	fx.life = 1.7
	local c = colorFn(fx, fx.look.color, 1)
	local hot = c:Lerp(WHITE, 0.5)
	local core = fx:part(Vector3.one * 0.6, hot, { ball = true })
	during(fx, 0, 0.3, function(u, now)
		core.Size = Vector3.one * (0.5 + math.abs(math.sin(now * 40)) * 0.4) * (1 + u)
		core.Transparency = u >= 1 and 1 or 0
	end)
	fx:emit(fx.at, { color = hot, rate = 60, stream = 0.3, speed = { 4, 9 }, size = { 0.3, 0 }, life = { 0.2, 0.4 } })
	fx:sound("rocket", 2.4, 0.3)
	fx:after(0.3, function()
		fx:sound("glass", 2.6, 0.5)
		fx:sound("hit", 1.6, 0.5)
		fx:light(fx.at, hot, 4, 16, 0.35)
		glowBall(fx, fx.at, WHITE, 2.4, 0.2)
		sparks(fx, fx.at, fx.n * 1.4, function(i)
			return i % 3 == 0 and WHITE or c
		end, 26, { grav = 0.9, floor = fx.pos.Y + 0.05, bounce = 0.5, life = 0.9, len = 0.7, w = 0.08 })
		fx:emit(fx.at, {
			color = ColorSequence.new(WHITE, c),
			rate = 45,
			stream = 0.8,
			dir = UP,
			spread = 30,
			speed = { 12, 20 },
			accel = Vector3.new(0, -40, 0),
			size = { 0.35, 0 },
			life = { 0.5, 0.9 },
			drag = 0.5,
		})
	end)
	for j = 1, 5 do
		fx:sound("tick", 2.4 + j * 0.3, 0.2, 0.4 + j * 0.15)
	end
end

-- Supernova: an implosion: the light pulls in and a star pulses, faster and faster, whining up (a beat), then it
-- goes: a huge flash, rays in every direction, two shockwaves, and embers drifting in a coloured haze
S.nova = function(fx)
	fx.life = 2.1
	local c = fx.color
	local shell = fx:part(Vector3.one * 9, c, { ball = true, transparency = 0.85 })
	local star = fx:part(Vector3.one, WHITE, { ball = true })
	local light = fx:light(fx.at, c, 1, 20)
	during(fx, 0, 0.5, function(u, now)
		shell.Size = Vector3.one * math.max(0.3, 9 * (1 - outCubic(u)))
		shell.Transparency = u >= 1 and 1 or 0.85 - 0.4 * u
		local beat = math.abs(math.sin(now * (8 + u * 30)))
		star.Size = Vector3.one * (0.5 + beat * 0.7)
		star.Transparency = u >= 1 and 1 or 0
		if light then
			light.Brightness = 0.5 + beat * 2
		end
	end)
	for i = 1, math.max(4, math.floor(10 * fx.mult)) do
		local from = fx.at + randomDir() * 6
		local p = fx:part(Vector3.one * 0.25, i % 2 == 0 and WHITE or c, { ball = true, cf = CFrame.new(from) })
		fx:bit(p, (fx.at - from) * 2.2, { drag = 0, life = 0.45 })
	end
	local whine = fx:sound("whistle", 0.8, 0.35)
	during(fx, 0, 0.5, function(u)
		if whine then
			whine.PlaybackSpeed = (0.8 + u * 1.8) * math.max(0.35, fx:speed())
		end
	end)
	fx:after(0.5, function()
		if whine then
			whine:Stop()
		end
		fx:sound("boom", 0.7, 0.9)
		fx:sound("ping", 0.5, 0.5)
		fx:sound("glass", 0.8, 0.4)
		if light then
			light.Brightness = 8
			during(fx, fx.age, 0.8, function(u)
				light.Brightness = 8 * (1 - u) ^ 2
			end)
		end
		glowBall(fx, fx.at, WHITE, 3, 0.25)
		glowBall(fx, fx.at, c, 5, 0.55)
		ring(fx, fx.pos + UP * 0.2, c, 10, 0.6, 0.3)
		ring(
			fx,
			fx.at,
			WHITE,
			7,
			0.5,
			0.15,
			CFrame.lookAt(Vector3.zero, facing(fx)) * CFrame.Angles(math.rad(90), 0, 0)
		)
		sparks(fx, fx.at, 14, function(i)
			return i % 2 == 0 and WHITE or c
		end, 34, { grav = 0, drag = 2, len = 3, w = 0.14, life = 0.55 })
		fx:sparkleBurst(fx.at, c, 30, 24)
		fx:emit(fx.at, {
			tex = "smoke",
			color = c,
			n = 10,
			speed = { 3, 7 },
			size = { 2, 5 },
			alpha = { 0.6, 1 },
			life = { 0.9, 1.4 },
			light = 0.6,
			spin = 40,
		})
		for _ = 1, math.max(3, math.floor(8 * fx.mult)) do
			local p = fx:part(Vector3.one * 0.2, c:Lerp(WHITE, 0.5), { ball = true, cf = CFrame.new(fx.at) })
			fx:bit(p, randomDir() * rng:NextNumber(3, 7), { drag = 1, twinkle = 20, life = rng:NextNumber(1, 1.5) })
		end
	end)
end

-- Centurion: marks blink in round them on the floor (a beat), then a crown of dark spears comes down out of the sky
-- one after another, slamming into the floor in a ring; their tips flare gold, a C, and they sink away
S.spears = function(fx)
	fx.life = 2.2
	local n = math.max(8, math.floor(12 * math.sqrt(fx.mult)))
	local r = 3.6
	local marks = hoop(fx, n, Color3.fromRGB(220, 40, 50), 0.12)
	during(fx, 0, 0.25, function(u)
		marks.place(CFrame.new(fx.pos + UP * 0.08), r, 1 - u * 0.6)
	end)
	fx:sound("tick", 1.4, 0.3)
	fx:sound("tick", 1.8, 0.3, 0.12)
	local spears = {}
	for i = 1, n do
		local a = i / n * math.pi * 2
		local at = fx.pos + Vector3.new(math.cos(a), 0, math.sin(a)) * r
		local lean = CFrame.lookAt(at, fx.pos + UP * 12) * CFrame.Angles(-math.pi / 2, 0, 0)
		local shaft =
			fx:part(Vector3.new(0.22, 5, 0.22), INK, { material = Enum.Material.SmoothPlastic, transparency = 1 })
		local tip = fx:part(Vector3.new(0.4, 1, 0.4), Color3.fromRGB(70, 70, 80), {
			wedge = true,
			material = Enum.Material.Metal,
			transparency = 1,
		})
		spears[i] = { shaft = shaft, tip = tip, lean = lean, at = at, drop = 0.25 + i * 0.05 }
	end
	during(fx, 0, 2.1, function(u)
		local t = u * 2.1
		for _, s in spears do
			local k = clamp01((t - s.drop) / 0.12)
			local sink = clamp01((t - 1.5) / 0.5) * 5
			local y = (1 - k) * 16 + 2.3 - sink
			s.shaft.CFrame = CFrame.new(s.at) * s.lean.Rotation * CFrame.new(0, y, 0)
			s.tip.CFrame = s.shaft.CFrame * CFrame.new(0, 3, 0)
			local alpha = (t < s.drop) and 1 or 0
			s.shaft.Transparency, s.tip.Transparency = alpha, alpha
		end
	end)
	for i = 1, n do
		if i % 2 == 1 then
			fx:sound("thud", 1 + i * 0.03, 0.45, 0.37 + i * 0.05)
		end
		fx:after(0.37 + i * 0.05, function()
			poof(fx, spears[i].at + UP * 0.3, 2, Color3.fromRGB(200, 200, 205), 0.5)
		end)
	end
	local crown = 0.45 + n * 0.05
	fx:after(crown, function()
		for _, s in spears do
			s.tip.Color = GOLD
			s.tip.Material = Enum.Material.Neon
		end
		marks.place(CFrame.new(fx.pos + UP * 0.08), r, 1)
		ring(fx, fx.pos + UP * 0.2, GOLD, 6, 0.5, 0.2)
		fx:light(fx.at, GOLD, 4, 18, 0.6)
		fx:sound("unsheath", 0.8, 0.6)
		fx:sound("ping", 0.6, 0.5)
		fx:word("C", UP * 3, GOLD, { w = 3, h = 3, life = 1, elastic = true, font = Enum.Font.LuckiestGuy })
	end)
end

-- Spotlight (MVP): the lights dim (a beat), a spotlight clunks on from above and finds them, gold confetti rains
-- down through it, a gold MVP, and the crowd claps
S.spotlight = function(fx)
	fx.life = 2.4
	local warm = Color3.fromRGB(255, 244, 214)
	grade(fx, { brightness = -0.22, contrast = 0.15, saturation = -0.2 }, 0.25, 1.6, 0.5)
	local top = fx.pos + UP * 26 - facing(fx) * 6
	local cone = fx:beam(top, fx.pos + UP * 0.2, warm, 0, 0, { alpha = 0.55 })
	local pool = fx:part(Vector3.new(0.08, 6, 6), warm, {
		cylinder = true,
		transparency = 1,
		cf = CFrame.new(fx.pos + UP * 0.07) * CFrame.Angles(0, 0, math.rad(90)),
	})
	fx:sound("thud", 0.6, 0.8, 0.3)
	fx:sound("click", 0.5, 0.6, 0.3)
	local light = fx:light(fx.at + UP * 3, warm, 0, 18)
	during(fx, 0.3, 2.1, function(u, now)
		local sway = math.sin(now * 2.2) * 0.6 * (1 - u)
		cone.b.CFrame = CFrame.new(fx.pos + UP * 0.2 + Vector3.new(sway, 0, 0))
		local fade = clamp01((u - 0.8) / 0.2)
		cone.beam.Width0, cone.beam.Width1 = 0.8 * (1 - fade), 6.5 * (1 - fade)
		pool.Transparency = 0.45 + 0.55 * fade
		pool.CFrame = CFrame.new(fx.pos + UP * 0.07 + Vector3.new(sway, 0, 0)) * CFrame.Angles(0, 0, math.rad(90))
		if light then
			light.Brightness = 4 * (1 - fade)
		end
	end)
	fx:after(0.4, function()
		paper(fx, fx.pos + UP * 9, fx.n * 2, function(i)
			return i % 3 == 0 and WHITE or GOLD
		end, 4, { dir = -UP })
	end)
	for j = 1, 10 do
		fx:sound("click", rng:NextNumber(0.8, 1.4), 0.25, 0.55 + j * 0.11 + rng:NextNumber(0, 0.05))
	end
	fx:word(
		"★ MVP ★",
		UP * 4,
		GOLD,
		{ w = 7, h = 2.2, delay = 0.45, life = 1.6, elastic = true, font = Enum.Font.LuckiestGuy }
	)
end

-- the shop's ------------------------------------------------------------------------------------------------------

-- Confetti: two party poppers pop up out of the floor either side of them and fire (pop, pop): paper confetti in
-- every colour flutters down, rocking, and settles
S.confetti = function(fx)
	fx.life = 2
	local right = facing(fx):Cross(UP).Unit
	for side = -1, 1, 2 do
		local base = fx.pos + right * side * 1.8
		local aim = (UP * 2 - right * side).Unit
		local cone = fx:part(
			Vector3.new(0.5, 1.1, 0.5),
			side > 0 and Color3.fromRGB(255, 80, 160) or Color3.fromRGB(60, 200, 255),
			{
				wedge = true,
				material = Enum.Material.SmoothPlastic,
			}
		)
		during(fx, 0, 0.35, function(u)
			local s = outBack(u / 0.4)
			cone.CFrame = CFrame.lookAt(base + UP * 0.5 * s, base + UP * 0.5 * s + aim)
				* CFrame.Angles(-math.pi / 2, 0, 0)
			cone.Size = Vector3.new(0.5, 1.1, 0.5) * math.max(0.05, s)
		end)
		local fire = side < 0 and 0.15 or 0.27
		fx:after(fire, function()
			fx:sound("pop", 1 + side * 0.1, 0.75)
			glowBall(fx, base + aim * 1.2 + UP * 0.6, WHITE, 1, 0.2)
			paper(fx, base + aim * 1.2 + UP * 0.6, fx.n / 2, function(i)
				return rainbow(i + side * 3, 0)
			end, 20, { dir = (aim + randomDir() * 0.25).Unit })
			-- (a few streamers: long curly strips)
			for i = 1, math.max(1, math.floor(3 * fx.mult)) do
				local p = fx:part(Vector3.new(0.12, 0.02, 1.4), rainbow(i * 2 + side, 0), {
					material = Enum.Material.SmoothPlastic,
					cf = CFrame.new(base + UP),
				})
				fx:bit(p, aim * rng:NextNumber(14, 20) + randomDir() * 2, {
					grav = 0.12,
					drag = 2,
					spin = 6,
					sway = 1.5,
					life = 1.6,
					floor = fx.pos.Y + 0.05,
					bounce = 0,
				})
			end
		end)
		fx:after(1.6, function()
			cone.Transparency = 1
		end)
	end
	fx:sound("whistle", 2.8, 0.25, 0.45)
end

-- Ink Splash: a fat drop of ink wobbles in the air (a beat), then SPLAT: a glossy splat spreads over the floor in
-- blots, droplets arc out and splat where they land, and it all soaks away
S.ink = function(fx)
	fx.life = 2.1
	local ink = colorFn(fx, fx.look.color, 1)
	local gloss = { material = Enum.Material.Glass }
	local drop = fx:part(Vector3.one * 1.6, ink, { ball = true, material = Enum.Material.Glass })
	during(fx, 0, 0.3, function(u, now)
		local wob = math.sin(now * 30) * 0.15 * (1 - u)
		drop.Size = Vector3.new(1.6 + wob, 1.6 - wob, 1.6 + wob) * (1 + u * 0.3)
		drop.CFrame = CFrame.new(fx.at - UP * u * u * 2.2)
		drop.Transparency = u >= 1 and 1 or 0
	end)
	fx:sound("draw", 0.7, 0.3)
	local function splat(at, size, delay)
		local p = fx:part(Vector3.new(0.06, 0.2, 0.2), ink, {
			cylinder = true,
			material = gloss.material,
			cf = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90)),
		})
		local d = fx.life - fx.age - (delay or 0)
		during(fx, fx.age + (delay or 0), d, function(u)
			local k = outBack(clamp01(u * d / 0.25))
			p.Size = Vector3.new(0.06, size * k, size * k)
			p.Transparency = clamp01((u - 0.7) / 0.3)
		end)
	end
	fx:after(0.3, function()
		fx:sound("thud", 0.8, 0.7)
		fx:sound("pop", 0.45, 0.6)
		splat(fx.pos + UP * 0.05, 5.5)
		for i = 1, math.max(3, math.floor(6 * fx.mult)) do
			local a = i / 6 * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
			splat(
				fx.pos + UP * (0.06 + i * 0.002) + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(2.4, 3.6),
				rng:NextNumber(1, 2)
			)
		end
		for _ = 1, math.max(4, math.floor(fx.n * 0.8)) do
			local p = fx:part(Vector3.one * rng:NextNumber(0.25, 0.45), ink, {
				ball = true,
				material = gloss.material,
				cf = CFrame.new(fx.pos + UP * 0.6),
			})
			local b = fx:bit(p, randomDir(0.4) * rng:NextNumber(10, 18) + UP * 8, {
				grav = 1,
				drag = 0.3,
				life = 1.2,
				floor = fx.pos.Y + 0.15,
				bounce = 0,
			})
			b.shrink = false
			b.onDie = function(bb)
				-- (each droplet splats where it lands)
				local g = fx:part(Vector3.new(0.06, 0.8, 0.8), ink, {
					cylinder = true,
					material = gloss.material,
					cf = CFrame.new(Vector3.new(bb.pos.X, fx.pos.Y + 0.07, bb.pos.Z))
						* CFrame.Angles(0, 0, math.rad(90)),
				})
				fx:bit(g, Vector3.zero, { life = math.max(0.2, fx.life - fx.age - 0.05), shrink = false })
			end
		end
		for j = 1, 3 do
			fx:sound("pop", 1.4 + j * 0.2, 0.25, 0.5 + j * 0.15)
		end
	end)
end

-- Double Ring: two hoops of light appear round them, tilted, and spin up like a gyroscope, closing in faster and
-- faster with a rising hum (a beat); they collapse to a point, a pillar of light, and blast out flat as two
-- shockwaves, one low, one high
S.orbit = function(fx)
	fx.life = 1.9
	local c = fx.color
	local hoops = {
		{ h = hoop(fx, 16 * fx.mult + 4, c, 0.14), axis = Vector3.new(1, 0.3, 0).Unit, rate = 9 },
		{ h = hoop(fx, 16 * fx.mult + 4, WHITE, 0.1), axis = Vector3.new(0, 0.4, 1).Unit, rate = -12 },
	}
	local hum = fx:sound("wind", 1.2, 0.35)
	during(fx, 0, 1.0, function(u, now)
		local r = 3.4 - 3 * u * u
		for i, e in hoops do
			local cf = CFrame.new(fx.at)
				* CFrame.fromAxisAngle(e.axis, now * e.rate * (1 + u * 2))
				* CFrame.Angles(i * 0.9, 0, 0)
			e.h.place(cf, math.max(0.2, r), u >= 1 and 1 or 0.05)
		end
		if hum then
			hum.PlaybackSpeed = (1.2 + u * 2) * math.max(0.35, fx:speed())
		end
	end)
	fx:after(1.0, function()
		if hum then
			hum:Stop()
		end
		fx:sound("boom", 1.4, 0.7)
		fx:sound("ping", 1.2, 0.5)
		fx:sound("glass", 1.6, 0.35)
		glowBall(fx, fx.at, WHITE, 2.4, 0.25)
		fx:light(fx.at, c, 5, 18, 0.5)
		local pillar = fx:beam(fx.pos, fx.pos + UP * 20, c:Lerp(WHITE, 0.4), 2.2, 2.2, {})
		during(fx, fx.age, 0.4, function(u)
			pillar.beam.Width0, pillar.beam.Width1 = 2.2 * (1 - u), 2.2 * (1 - u)
		end)
		for i, e in hoops do
			local y = i == 1 and 0.3 or 2.6
			during(fx, fx.age, 0.6, function(u)
				e.h.place(CFrame.new(fx.pos + UP * y), 0.4 + outCubic(u) * (i == 1 and 9 or 6), u >= 1 and 1 or u)
			end)
		end
		fx:sparkleBurst(fx.at, c, 20, 18)
	end)
end

-- Ascend: their soul lifts out of them: a bright wisp gathers (motes pulling in), rises in a slow spiral up a
-- column of light with cubes winding round it, a chime climbing with it, and bursts into a star at the top
S.rise = function(fx)
	fx.life = 2.4
	local c = fx.color
	local soul = fx:part(Vector3.one * 1.1, WHITE, { ball = true, transparency = 0.15 })
	local halo = fx:part(Vector3.one * 2.2, c:Lerp(WHITE, 0.5), { ball = true, transparency = 0.7 })
	local column = fx:beam(fx.pos, fx.pos + UP * 22, c:Lerp(WHITE, 0.5), 0, 0, { alpha = 0.55 })
	local light = fx:light(fx.at, WHITE, 0.5, 14)
	for _ = 1, math.max(4, math.floor(10 * fx.mult)) do
		local from = fx.at + randomDir() * 4
		local p = fx:part(Vector3.one * 0.22, WHITE, { ball = true, cf = CFrame.new(from) })
		fx:bit(p, (fx.at - from) * 2.6, { drag = 0, life = 0.38 })
	end
	fx:sound("ping", 1, 0.4)
	fx:sound("ping", 1.26, 0.4, 0.35)
	fx:sound("ping", 1.5, 0.4, 0.7)
	fx:sound("ping", 2, 0.5, 1.6)
	fx:sound("win", 1.4, 0.2, 0.3)
	local cubes = {}
	for i = 1, fx.n do
		cubes[i] = fx:part(Vector3.one * 0.4, i % 2 == 0 and WHITE or c, { transparency = 1 })
	end
	local top = fx.at + UP * 13
	during(fx, 0, 1.6, function(u, now)
		local up = u < 0.25 and 0 or ((u - 0.25) / 0.75) ^ 1.6 * 13
		local wob = math.min(1, up / 2) * 0.6
		local at = fx.at + UP * up + Vector3.new(math.sin(now * 5) * wob, 0, math.cos(now * 5) * wob)
		local gather = outBack(u / 0.25)
		local pulse = 1 + math.sin(now * 14) * 0.08
		local gone = u >= 1
		soul.Size = Vector3.one * math.max(0.05, 1.1 * gather * pulse)
		halo.Size = Vector3.one * math.max(0.05, 2.4 * gather * pulse)
		soul.CFrame, halo.CFrame = CFrame.new(at), CFrame.new(at)
		soul.Transparency, halo.Transparency = gone and 1 or 0.15, gone and 1 or 0.7
		local w = gone and 0 or 2.6 * outCubic(u / 0.3)
		column.beam.Width0, column.beam.Width1 = w, w * 0.6
		if light then
			light.Brightness = gone and 0 or 3 * gather
			light.Parent.CFrame = CFrame.new(at)
		end
		for i, cube in cubes do
			local k = i / #cubes
			local a = now * 4 + k * math.pi * 4
			local rr = 1.4 + k
			cube.CFrame = CFrame.new(fx.at + Vector3.new(math.cos(a) * rr, up - 1.5 + k * 3, math.sin(a) * rr))
				* CFrame.Angles(now * 3, a, 0)
			cube.Transparency = (u < 0.25 or gone) and 1 or 0.1
		end
	end)
	fx:after(1.6, function()
		glowBall(fx, top, WHITE, 2.5, 0.3)
		fx:sparkleBurst(top, WHITE, 30, 18)
		sparks(fx, top, 14, function(i)
			return i % 2 == 0 and WHITE or c
		end, 18, { grav = 0.3 })
		ring(fx, top, c, 5, 0.5, 0.15)
	end)
end

-- Feather Burst: a pillow fight: a pillow swells, squeezed (a beat), and bursts with a soft whump: feathers
-- everywhere, drifting down rocking side to side and settling on the floor
S.feathers = function(fx)
	fx.life = 2.6
	local pillow = fx:part(Vector3.new(2.4, 1.2, 1.6), WHITE, { material = Enum.Material.Fabric })
	during(fx, 0, 0.24, function(u)
		local s = 1 + 0.5 * outBack(u)
		pillow.Size = Vector3.new(2.4 * s, 1.2 * s * (1 + math.sin(u * 30) * 0.12), 1.6 * s)
		pillow.CFrame = CFrame.new(fx.at) * CFrame.Angles(0, u * 2, math.sin(u * 20) * 0.15)
		pillow.Transparency = u >= 1 and 1 or 0
	end)
	fx:sound("draw", 1.4, 0.4)
	fx:after(0.24, function()
		fx:sound("pop", 0.7, 0.7)
		fx:sound("wind", 1.6, 0.3)
		poof(fx, fx.at, 8)
		for i = 1, fx.n do
			local c = fx.look.color == "rainbow" and rainbow(i) or (i % 5 == 0 and fx.color or WHITE)
			local p = fx:part(Vector3.new(0.08, 0.35, 1.1), c, {
				wedge = true,
				material = Enum.Material.SmoothPlastic,
				cf = CFrame.new(fx.at) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0),
			})
			fx:bit(p, randomDir(0.2) * rng:NextNumber(8, 16) + UP * 5, {
				grav = 0.06,
				drag = 2.2,
				spin = rng:NextNumber(1.5, 4),
				sway = rng:NextNumber(0.6, 1.2),
				life = rng:NextNumber(1.9, 2.3),
				floor = fx.pos.Y + 0.05,
				bounce = 0,
			})
		end
	end)
	fx:sound("whistle", 1.8, 0.15, 0.8)
end

-- Rainbow Sparkle: rainbow motes spiral IN to a point (a beat), it flares into a rainbow star with a chord, and
-- twinkles spiral up and away through every hue
S.sparkles = function(fx)
	fx.life = 2.3
	for i = 1, math.max(4, math.floor(fx.n / 3)) do
		local a = i / 6 * math.pi * 2
		local p = fx:part(Vector3.one * 0.3, rainbow(i), { ball = true })
		during(fx, 0, 0.4, function(u, now)
			local r = 5 * (1 - u)
			local aa = a + u * 6
			p.CFrame = CFrame.new(
				fx.at + Vector3.new(math.cos(aa) * r, math.sin(now * 3 + i) * 0.5 * (1 - u), math.sin(aa) * r)
			)
			p.Transparency = u >= 1 and 1 or 0
		end)
	end
	fx:sound("ping", 2, 0.3)
	fx:sound("ping", 2.52, 0.3, 0.13)
	fx:sound("ping", 3, 0.3, 0.26)
	fx:after(0.4, function()
		fx:sound("ping", 1, 0.5)
		fx:sound("ping", 1.26, 0.45)
		fx:sound("ping", 1.5, 0.45)
		fx:sound("glass", 1.6, 0.25)
		fx:light(fx.at, rainbow(0, fx.age), 4, 16, 0.6)
		-- the star: six rays in six hues
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2
			local d = (facing(fx):Cross(UP) * math.cos(a) + UP * math.sin(a)).Unit
			local ray = fx:part(Vector3.new(0.25, 0.25, 0.1), rainbow(i), {})
			during(fx, fx.age, 0.5, function(u)
				local len = 6 * outCubic(u)
				ray.Size = Vector3.new(0.3 * (1 - u), 0.3 * (1 - u), math.max(0.1, len))
				ray.CFrame = CFrame.lookAt(fx.at + d * len / 2, fx.at + d * len)
				ray.Transparency = u >= 1 and 1 or u * 0.6
			end)
		end
		glowBall(fx, fx.at, WHITE, 2, 0.3)
		fx:emit(fx.at, {
			color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0.7, 1)),
				ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33, 0.7, 1)),
				ColorSequenceKeypoint.new(0.66, Color3.fromHSV(0.66, 0.7, 1)),
				ColorSequenceKeypoint.new(1, Color3.fromHSV(0.9, 0.7, 1)),
			}),
			n = 40,
			speed = { 8, 18 },
			size = { 0.8, 0 },
			life = { 0.6, 1.2 },
		})
		local t0 = fx.age
		for i = 1, fx.n do
			local p = fx:part(Vector3.one * rng:NextNumber(0.25, 0.5), rainbow(i), { ball = true })
			local a = i / fx.n * math.pi * 8
			local r0 = 0.3 + i / fx.n * 0.8
			local b = fx:bit(p, Vector3.zero, { twinkle = rng:NextNumber(14, 26), life = rng:NextNumber(1.3, 1.8) })
			b.color = function(age)
				return rainbow(i, age)
			end
			table.insert(fx.ticks, function(_, t)
				local u = t - t0
				local rr = r0 + u * 4.5
				local aa = a + u * 3
				b.pos = fx.at + Vector3.new(math.cos(aa) * rr, u * 3 - 0.6 + math.sin(i) * 0.6, math.sin(aa) * rr)
			end)
		end
	end)
end

-- Block Party: rainbow blocks drop out of the sky onto the spot (thud, thud), then the party: on every beat they all
-- hop and change colour, and on the last they blow apart and bounce away
S.blocks = function(fx)
	fx.life = 2.3
	local blocks = {}
	for i = 1, fx.n do
		local s = rng:NextNumber(0.7, 1.1)
		local col, layer = (i - 1) % 9, math.floor((i - 1) / 9)
		local home = fx.pos + Vector3.new((col % 3 - 1) * 1.15, s / 2 + layer * 1.05, (math.floor(col / 3) - 1) * 1.15)
		local p = fx:part(Vector3.one * s, rainbow(i), { material = Enum.Material.SmoothPlastic, transparency = 1 })
		blocks[i] = { p = p, home = home, drop = rng:NextNumber(0, 0.35) + layer * 0.12, i = i }
	end
	local beats = { 0.75, 1.05, 1.35 }
	during(fx, 0, 1.6, function(u)
		local t = u * 1.6
		local beat = 0
		for k, b in beats do
			if t >= b then
				beat = k
			end
		end
		for _, e in blocks do
			local k = clamp01((t - e.drop) / 0.3)
			local y = (1 - k * k) * 12
			local hop = 0
			for _, b in beats do
				local d = t - b
				if d > 0 and d < 0.25 then
					hop = math.sin(d / 0.25 * math.pi) * 1.2
				end
			end
			e.p.CFrame = CFrame.new(e.home + UP * (y + hop)) * CFrame.Angles(0, beat * 0.4, 0)
			e.p.Color = rainbow(e.i + beat * 3)
			e.p.Transparency = (t < e.drop or u >= 1) and 1 or 0
		end
	end)
	fx:sound("thud", 1.1, 0.5, 0.3)
	fx:sound("thud", 0.95, 0.5, 0.5)
	for k, b in beats do
		fx:sound("thud", 0.7, 0.7, b)
		fx:sound("tick", 1.5 + k * 0.25, 0.35, b)
	end
	fx:after(1.6, function()
		fx:sound("pop", 1.1, 0.7)
		fx:sound("boom", 1.8, 0.4)
		flash(fx, rainbow(0, fx.age), 5)
		for _, e in blocks do
			local p = fx:part(e.p.Size, e.p.Color, { material = Enum.Material.SmoothPlastic, cf = e.p.CFrame })
			local d = e.p.Position - fx.at
			d = d.Magnitude > 0.05 and d.Unit or randomDir()
			fx:bit(p, d * rng:NextNumber(10, 18) + UP * 10, {
				grav = 1.1,
				drag = 0.3,
				spin = rng:NextNumber(4, 10),
				floor = fx.pos.Y + 0.4,
				bounce = 0.55,
				life = 0.65,
			})
		end
	end)
end

-- Firework: a rocket fizzes up off the spot trailing sparks (a beat), bursts high up in a sphere of two-colour
-- streaks with a flash and a boom, glitter falling, and a crackle of little pops after
S.firework = function(fx)
	fx.life = 2.4
	local hue = rng:NextNumber()
	local c1, c2 = Color3.fromHSV(hue, 0.8, 1), Color3.fromHSV((hue + 0.45) % 1, 0.7, 1)
	local rocket = fx:part(Vector3.new(0.3, 1, 0.3), WHITE, { cf = CFrame.new(fx.pos + UP) })
	local top = fx.pos + UP * 14
	fx:sound("rocket", 1.4, 0.45)
	during(fx, 0, 0.5, function(u)
		rocket.CFrame = CFrame.new((fx.pos + UP):Lerp(top, outCubic(u))) * CFrame.Angles(0, 0, math.sin(u * 30) * 0.1)
		rocket.Transparency = u >= 1 and 1 or 0
	end)
	for i = 1, 7 do
		fx:after(i * 0.06, function()
			local p = fx:part(Vector3.one * 0.25, i % 2 == 0 and ORANGE or YELLOW, { ball = true, cf = rocket.CFrame })
			fx:bit(p, randomDir() * 2 - UP * 3, { grav = 0.2, life = 0.5 })
		end)
	end
	fx:after(0.5, function()
		fx:sound("boom", 1.6, 0.6)
		fx:sound("glass", 1.2, 0.25)
		fx:light(top, c1, 6, 30, 0.8)
		glowBall(fx, top, WHITE, 3, 0.3)
		for i = 1, fx.n do
			local c = i % 2 == 0 and c1 or c2
			local p = fx:part(Vector3.new(0.18, 0.18, 0.9), c, { cf = CFrame.new(top) })
			local b =
				fx:bit(p, randomDir() * rng:NextNumber(16, 24), { grav = 0.25, drag = 1.1, face = true, life = 1.3 })
			if i % 4 == 0 then
				-- (glitter: it falls on after the streak dies)
				b.onDie = function(bb)
					local g = fx:part(Vector3.one * 0.15, WHITE, { ball = true, cf = CFrame.new(bb.pos) })
					fx:bit(g, Vector3.new(0, -3, 0), { twinkle = 30, life = 0.5 })
				end
			end
		end
		fx:sparkleBurst(top, GOLD, 34, 22)
		for j = 1, 5 do
			fx:after(0.25 + j * 0.12, function()
				fx:sparkleBurst(top + randomDir() * rng:NextNumber(3, 6), j % 2 == 0 and c1 or c2, 8, 6)
				fx:sound("tick", 2 + j * 0.1, 0.25)
			end)
		end
	end)
end

-- Bubble Pop: a big bubble wells up round them, wobbling (a beat), and POPS: a splash of droplets and a cloud of
-- little bubbles that float up wobbling and pop one by one, each with its own plip
S.bubbles = function(fx)
	fx.life = 2.3
	local big = fx:part(Vector3.one, fx.color:Lerp(WHITE, 0.4), {
		ball = true,
		material = Enum.Material.Glass,
		transparency = 0.55,
	})
	during(fx, 0, 0.45, function(u, now)
		local s = 5 * outBack(u / 0.7)
		local wob = math.sin(now * 18) * 0.25 * u
		big.Size = Vector3.new(s + wob, s - wob, s + wob)
		big.CFrame = CFrame.new(fx.at)
		big.Transparency = u >= 1 and 1 or 0.55
	end)
	fx:sound("draw", 2.4, 0.25)
	fx:after(0.45, function()
		fx:sound("pop", 1.3, 0.8)
		fx:sound("glass", 2.4, 0.2)
		for _ = 1, math.max(4, math.floor(10 * fx.mult)) do
			local d = fx:part(Vector3.one * 0.2, WHITE, { ball = true, cf = CFrame.new(fx.at + randomDir() * 2.4) })
			fx:bit(d, randomDir() * 12, { grav = 0.5, life = 0.4 })
		end
		for i = 1, fx.n do
			local s = rng:NextNumber(0.5, 1.4)
			local p = fx:part(Vector3.one * s, i % 3 == 0 and Color3.fromRGB(255, 160, 220) or fx.color, {
				ball = true,
				material = Enum.Material.Glass,
				transparency = 0.45,
				cf = CFrame.new(fx.at + randomDir() * 1.6),
			})
			local b = fx:bit(p, randomDir(0) * 4 + UP * rng:NextNumber(2.5, 5), {
				drag = 0.6,
				sway = rng:NextNumber(0.5, 1),
				life = rng:NextNumber(0.8, 1.7),
			})
			b.shrink = false
			b.onDie = function(bb)
				for _ = 1, 3 do
					local d = fx:part(Vector3.one * 0.15, WHITE, { ball = true, cf = CFrame.new(bb.pos) })
					fx:bit(d, randomDir() * 6, { grav = 0.4, life = 0.25 })
				end
			end
		end
	end)
	for j = 1, 5 do
		fx:sound("pop", 1.6 + j * 0.15, 0.25, 1.2 + j * 0.16)
	end
end

-- funny --------------------------------------------------------------------------------------------------------------
-- a blocky chicken (a model of parts, posed from its root each frame)
local function chickenModel(fx, scale)
	local parts = {}
	local function add(name, size, color, offset, opts)
		local p = fx:part(size * scale, color, opts or { material = Enum.Material.SmoothPlastic })
		p.Name = name
		table.insert(parts, { part = p, offset = offset, size = size * scale })
		return p
	end
	local m = { material = Enum.Material.SmoothPlastic }
	add("Body", Vector3.new(1.6, 1.4, 2), WHITE, CFrame.new(0, 1.3, 0), m)
	add("Tail", Vector3.new(1.2, 0.9, 0.5), WHITE, CFrame.new(0, 1.8, 1.05) * CFrame.Angles(math.rad(-25), 0, 0), m)
	add("Head", Vector3.new(0.9, 0.9, 0.9), WHITE, CFrame.new(0, 2.4, -0.9), m)
	add("Comb", Vector3.new(0.25, 0.45, 0.6), Color3.fromRGB(230, 30, 40), CFrame.new(0, 3.0, -0.9), m)
	add("Beak", Vector3.new(0.4, 0.3, 0.45), ORANGE, CFrame.new(0, 2.35, -1.5), m)
	add("Wattle", Vector3.new(0.2, 0.35, 0.2), Color3.fromRGB(230, 30, 40), CFrame.new(0, 2.0, -1.35), m)
	add("EyeL", Vector3.new(0.12, 0.18, 0.12), INK, CFrame.new(-0.46, 2.55, -1.1), m)
	add("EyeR", Vector3.new(0.12, 0.18, 0.12), INK, CFrame.new(0.46, 2.55, -1.1), m)
	add("WingL", Vector3.new(0.2, 0.9, 1.3), Color3.fromRGB(235, 235, 235), CFrame.new(-0.9, 1.4, 0), m)
	add("WingR", Vector3.new(0.2, 0.9, 1.3), Color3.fromRGB(235, 235, 235), CFrame.new(0.9, 1.4, 0), m)
	add("LegL", Vector3.new(0.18, 0.7, 0.18), ORANGE, CFrame.new(-0.35, 0.35, 0), m)
	add("LegR", Vector3.new(0.18, 0.7, 0.18), ORANGE, CFrame.new(0.35, 0.35, 0), m)
	return {
		parts = parts,
		pose = function(cf, t, flap, run, s)
			for _, e in parts do
				local off = e.offset
				local n = e.part.Name
				if n == "WingL" then
					off = off * CFrame.Angles(0, 0, math.sin(t * 30) * flap)
				elseif n == "WingR" then
					off = off * CFrame.Angles(0, 0, -math.sin(t * 30) * flap)
				elseif n == "LegL" then
					off = CFrame.new(-0.35, 0.7, 0)
						* CFrame.Angles(math.sin(t * 22) * run, 0, 0)
						* CFrame.new(0, -0.35, 0)
				elseif n == "LegR" then
					off = CFrame.new(0.35, 0.7, 0)
						* CFrame.Angles(-math.sin(t * 22) * run, 0, 0)
						* CFrame.new(0, -0.35, 0)
				end
				e.part.CFrame = cf * CFrame.new(off.Position * scale * s) * off.Rotation
				e.part.Size = e.size * s
			end
		end,
	}
end

-- Chicken: a "?" and a poof (a beat), and they're a chicken: it looks about, BAWK!, and legs it, feathers flying
-- and clucking all the way; it leaves an egg behind, which wobbles... and hatches a little chick
S.chicken = function(fx)
	fx.life = 2.7
	fx:word("?", UP * 3.5, WHITE, { w = 2, h = 2, life = 0.35, wobble = true, font = Enum.Font.LuckiestGuy })
	fx:sticker("chicken", Vector3.new(0, 5, 0), 5, { delay = 0.3, wobble = true, float = 0.8 })
	fx:sticker("bawk", Vector3.new(2.5, 8, 0), 5, { delay = 0.55, wobble = true, float = 0.6 })
	fx:sound("draw", 2, 0.3)
	local ch = chickenModel(fx, 1)
	for _, e in ch.parts do
		e.part.Transparency = 1
	end
	local run = facing(fx)
	local start = fx.pos
	local egg = fx:part(Vector3.new(0.7, 0.9, 0.7), Color3.fromRGB(250, 240, 220), {
		material = Enum.Material.SmoothPlastic,
		transparency = 1,
		cf = CFrame.new(fx.pos + UP * 0.45),
	})
	fx:after(0.25, function()
		poof(fx, fx.at, 10, WHITE, 1.3)
		fx:sound("pop", 1.1, 0.6)
		for i = 1, math.floor(10 * fx.mult) do
			local p = fx:part(Vector3.new(0.08, 0.3, 0.9), i % 4 == 0 and Color3.fromRGB(230, 30, 40) or WHITE, {
				wedge = true,
				material = Enum.Material.SmoothPlastic,
				cf = CFrame.new(fx.at),
			})
			fx:bit(p, randomDir(0.2) * 12 + UP * 6, { grav = 0.05, drag = 2.2, spin = 3, sway = 1, life = 2 })
		end
		fx:word("BAWK!", UP * 4, YELLOW, { w = 5, h = 2, delay = 0.25, life = 1.3, wobble = true })
	end)
	for j = 0, 4 do
		fx:sound("pop", 2.2 + (j % 2) * 0.3, 0.45, 0.6 + j * 0.36)
	end
	during(fx, 0.25, 2.4, function(u, now)
		local v = u * 2.4
		local appear = outBack(v / 0.3)
		local alpha = v < 0.05 and 1 or clamp01((v - 2.0) / 0.4)
		for _, e in ch.parts do
			e.part.Transparency = alpha
		end
		local go = math.max(0, v - 0.55)
		local dist = go * 9 + go * go * 3
		local hop = math.abs(math.sin(go * 14)) * 0.5 * (go > 0 and 1 or 0)
		local turn = v < 0.55 and math.sin(v * 18) * 0.6 or 0
		local cf = CFrame.lookAt(start + run * dist + UP * hop, start + run * (dist + 1) + UP * hop)
			* CFrame.Angles(0, turn, 0)
		ch.pose(cf, now, go > 0 and 0.9 or 0.4, go > 0 and 0.8 or 0, math.max(0.05, appear))
		if go > 0 and rng:NextNumber() < 0.1 * fx.mult then
			local p = fx:part(Vector3.new(0.06, 0.25, 0.7), WHITE, {
				wedge = true,
				material = Enum.Material.SmoothPlastic,
				cf = cf * CFrame.new(0, 1.5, 0.8),
			})
			fx:bit(p, UP * 3 + randomDir() * 2, { grav = 0.05, drag = 2, spin = 3, sway = 1, life = 1 })
		end
		-- the egg: left behind, it wobbles, then hatches
		egg.Transparency = v > 0.55 and v < 2.05 and 0 or 1
		local wob = v > 1.4 and math.sin(v * 40) * 0.3 * math.min(1, (v - 1.4) * 3) or 0
		egg.CFrame = CFrame.new(fx.pos + UP * 0.45) * CFrame.Angles(0, 0, wob)
	end)
	fx:sound("tick", 2.6, 0.3, 1.7)
	fx:sound("tick", 2.9, 0.3, 1.95)
	fx:after(2.3, function()
		fx:sound("pop", 2.6, 0.5)
		for i = 1, 2 do
			local shell = fx:part(Vector3.new(0.7, 0.45, 0.7), Color3.fromRGB(250, 240, 220), {
				wedge = true,
				material = Enum.Material.SmoothPlastic,
				cf = CFrame.new(fx.pos + UP * (0.3 + i * 0.3)),
			})
			fx:bit(shell, randomDir(0.5) * 5, { grav = 0.6, spin = 6, life = 0.4 })
		end
		local chick = fx:part(Vector3.one * 0.5, YELLOW, {
			ball = true,
			material = Enum.Material.SmoothPlastic,
			cf = CFrame.new(fx.pos + UP * 0.4),
		})
		fx:bit(chick, UP * 4, { grav = 0.5, life = 0.4, floor = fx.pos.Y + 0.25, bounce = 0.6 })
	end)
end

-- Rubber Duck: the floor ripples (a beat), a giant rubber duck pops up out of it, SQUEAK! (it squashes in time with
-- each squeak), bobs and looks about, then squishes flat and pops into bubbles
S.duck = function(fx)
	fx.life = 2.4
	fx:sticker("duck", Vector3.new(0, 6, 0), 7, { delay = 0.25, wobble = true, pulse = true, life = 1.8 })
	for i = 0, 2 do
		fx:after(i * 0.08, function()
			ring(fx, fx.pos + UP * 0.08, Color3.fromRGB(150, 210, 255), 3.5 + i, 0.4, 0.1)
		end)
	end
	local m = { ball = true, material = Enum.Material.SmoothPlastic }
	local body = fx:part(Vector3.new(3.4, 2.6, 4.2), YELLOW, m)
	local head = fx:part(Vector3.new(2.2, 2.2, 2.2), YELLOW, m)
	local beak = fx:part(Vector3.new(1.2, 0.5, 1), ORANGE, { material = Enum.Material.SmoothPlastic })
	local eyeL = fx:part(Vector3.one * 0.35, INK, m)
	local eyeR = fx:part(Vector3.one * 0.35, INK, m)
	local tail = fx:part(Vector3.new(1, 1.2, 0.6), YELLOW, { material = Enum.Material.SmoothPlastic })
	local all = { body, head, beak, eyeL, eyeR, tail }
	local base = CFrame.lookAt(fx.pos, fx.pos - facing(fx))
	local squeaks = { 0.35, 0.95, 1.5 }
	for _, s in squeaks do
		fx:sound("ping", 2.6 + rng:NextNumber(0, 0.4), 0.65, s)
	end
	fx:sound("pop", 0.8, 0.5, 0.25)
	poof(fx, fx.pos + UP, 4, WHITE, 1)
	during(fx, 0.2, 2.2, function(u, now)
		local v = u * 2.2
		local s = outElastic(v / 0.6)
		local squash = 1
		for _, sq in squeaks do
			local d = now - sq
			if d > 0 and d < 0.3 then
				squash = 1 + math.sin(d / 0.3 * math.pi) * 0.25
			end
		end
		local flat = clamp01((v - 1.8) / 0.25)
		local hop = bounce(v / 1.8) * 2.5
		local cf = base * CFrame.new(0, hop, 0) * CFrame.Angles(0, math.sin(now * 4) * 0.3, math.sin(now * 7) * 0.08)
		local k = math.max(0.02, s * (1 - flat * 0.3))
		local sy = (1 / squash) * (1 - flat * 0.8)
		body.Size = Vector3.new(3.4 * squash, 2.6 * sy, 4.2) * k
		body.CFrame = cf * CFrame.new(0, 1.3 * k * sy, 0)
		head.Size = Vector3.one * 2.2 * k
		head.CFrame = cf * CFrame.new(0, 3.1 * k * sy, -1.2 * k)
		beak.Size = Vector3.new(1.2, 0.5, 1) * k
		beak.CFrame = cf * CFrame.new(0, 2.9 * k * sy, -2.5 * k)
		eyeL.Size, eyeR.Size = Vector3.one * 0.35 * k, Vector3.one * 0.35 * k
		eyeL.CFrame = cf * CFrame.new(-0.6 * k, 3.5 * k * sy, -2.05 * k)
		eyeR.CFrame = cf * CFrame.new(0.6 * k, 3.5 * k * sy, -2.05 * k)
		tail.Size = Vector3.new(1, 1.2, 0.6) * k
		tail.CFrame = cf * CFrame.new(0, 2.2 * k * sy, 2.1 * k) * CFrame.Angles(math.rad(-30), 0, 0)
		if u >= 1 then
			for _, p in all do
				p.Transparency = 1
			end
		end
	end)
	fx:word("SQUEAK!", UP * 6.5, WHITE, { w = 6, h = 2, delay = 0.35, life = 1.4, stroke = ORANGE, wobble = true })
	fx:after(2.2, function()
		fx:sound("pop", 1.4, 0.6)
		for i = 1, math.max(4, math.floor(8 * fx.mult)) do
			local p = fx:part(Vector3.one * rng:NextNumber(0.4, 0.9), i % 2 == 0 and YELLOW or WHITE, {
				ball = true,
				material = Enum.Material.Glass,
				transparency = 0.4,
				cf = CFrame.new(fx.pos + UP + randomDir() * 1.5),
			})
			fx:bit(p, UP * rng:NextNumber(3, 6) + randomDir(0) * 3, { drag = 1, life = 0.2 + rng:NextNumber(0, 0.15) })
		end
	end)
end

-- Balloon Ride: balloons blow up round them with a rising squeal (a beat), lift them off the floor swaying, one pops
-- (they drop a little: a gulp), and the rest carry them on up and away
S.balloons = function(fx)
	fx.life = 2.7
	local n = math.max(4, math.floor((fx.look.count or 8) * fx.mult + 0.5))
	local balloons = {}
	for i = 1, n do
		local a = i / n * math.pi * 2
		local off = Vector3.new(math.cos(a) * 1.4, 5 + (i % 3) * 0.9, math.sin(a) * 1.4)
		local b =
			fx:part(Vector3.new(1.4, 1.7, 1.4), rainbow(i), { ball = true, material = Enum.Material.SmoothPlastic })
		local s = fx:part(Vector3.new(0.05, off.Y - 1.2, 0.05), WHITE, { material = Enum.Material.SmoothPlastic })
		table.insert(balloons, { b = b, s = s, off = off, phase = i })
	end
	local start = fx.body and fx.body:GetPivot() or CFrame.new(fx.at)
	local popped = balloons[1]
	local drop = 0
	local inflate = fx:sound("whistle", 1, 0.35)
	during(fx, 0, 0.45, function(u)
		if inflate then
			inflate.PlaybackSpeed = (1 + u * 1.4) * math.max(0.35, fx:speed())
		end
	end)
	fx:after(1.3, function()
		popped.gone = true
		popped.b.Transparency, popped.s.Transparency = 1, 1
		fx:sound("pop", 1.2, 0.8)
		fx:sparkleBurst(popped.b.Position, popped.b.Color, 10, 10)
		fx:word("!", UP * 3, YELLOW, { w = 1.6, h = 1.6, life = 0.5, wobble = true, font = Enum.Font.LuckiestGuy })
		drop = 1
	end)
	fx:sound("whistle", 1.6, 0.4, 0.5)
	during(fx, 0, 2.7, function(u, now)
		local v = u * 2.7
		local lift = v < 0.45 and 0 or (v - 0.45) ^ 1.6 * 3
		if drop > 0 then
			drop = math.max(0, drop - 0.03)
		end
		lift -= math.sin(drop * math.pi) * 0.8
		local sway = math.sin(now * 2.2) * 0.6
		local top = start.Position + UP * (lift + 2.2) + Vector3.new(sway, 0, 0)
		fx:bodyPivot(start * CFrame.new(0, lift, 0) * CFrame.Angles(0, now * 0.8, math.sin(now * 2.2) * 0.15))
		local grow = outBack(v / 0.45)
		for _, e in balloons do
			if not e.gone then
				local bob = math.sin(now * 3 + e.phase) * 0.25
				local p = top + e.off * Vector3.new(1, 0, 1) + UP * (e.off.Y - 2.2 + bob)
				e.b.Size = Vector3.new(1.4, 1.7, 1.4) * math.max(0.05, grow)
				e.b.CFrame = CFrame.new(p)
				e.s.Size = Vector3.new(0.05, (p - top).Magnitude, 0.05)
				e.s.CFrame = CFrame.lookAt((top + p) / 2, p) * CFrame.Angles(math.rad(90), 0, 0)
			end
		end
		if v > 2.2 then
			fx:bodyFade(clamp01((v - 2.2) / 0.45))
			for _, e in balloons do
				e.b.Transparency = math.max(e.b.Transparency, clamp01((v - 2.2) / 0.45))
				e.s.Transparency = e.b.Transparency
			end
		end
	end)
	fx:sparkleBurst(fx.at, WHITE, 16, 6)
end

-- Banana Slip: a peel slides in under their foot (a beat), whoops: feet up, a full flip through the air and SPLAT
-- flat on the floor, a skid mark, stars going round their head
S.banana = function(fx)
	fx.life = 2.4
	fx:sticker("banana", Vector3.new(0, 2.5, 0), 3.5, { life = 0.9, spin = 200 })
	fx:sticker("splat", Vector3.new(0, 6.5, 0), 6, { delay = 1.05, wobble = true })
	local back = facing(fx)
	local side = back:Cross(UP).Unit
	local peel = {}
	for i = 1, 3 do
		peel[i] = fx:part(Vector3.new(0.9, 0.12, 0.4), YELLOW, { material = Enum.Material.SmoothPlastic })
	end
	local nub =
		fx:part(Vector3.new(0.3, 0.2, 0.3), Color3.fromRGB(90, 60, 20), { material = Enum.Material.SmoothPlastic })
	during(fx, 0, 0.25, function(u)
		local at = fx.pos + UP * 0.15 - back * 3 * (1 - outCubic(u))
		for i, p in peel do
			p.CFrame = CFrame.new(at) * CFrame.Angles(0, (i / 3) * math.pi * 2 + u * 6, 0) * CFrame.new(0.7, 0, 0)
		end
		nub.CFrame = CFrame.new(at + UP * 0.1)
	end)
	fx:sound("shoot", 2.2, 0.3)
	local start = fx.body and fx.body:GetPivot() or CFrame.new(fx.at)
	local skid = fx:part(Vector3.new(0.6, 0.05, 0.1), Color3.fromRGB(110, 90, 40), {
		material = Enum.Material.SmoothPlastic,
		transparency = 1,
	})
	local splatted = false
	fx:sound("whistle", 2.2, 0.45, 0.25)
	during(fx, 0.25, 2.15, function(u, now)
		local v = u * 2.15
		local air = clamp01(v / 0.85)
		local h = math.sin(air * math.pi) * 3.2
		local spin = outCubic(air) * math.pi * 2.5
		local lie = air >= 1 and math.rad(90) or 0
		local p = start.Position + back * (outCubic(air) * 3) + UP * (h - (air >= 1 and 1.3 or 0))
		fx:bodyPivot(CFrame.new(p) * CFrame.fromAxisAngle(side, spin + lie) * start.Rotation)
		local len = outCubic(air) * 3
		skid.Size = Vector3.new(0.6, 0.05, math.max(0.1, len))
		skid.CFrame = CFrame.lookAt(fx.pos + UP * 0.04 + back * len / 2, fx.pos + UP * 0.04 + back * len)
		skid.Transparency = v > 0.05 and (0.2 + 0.8 * clamp01((v - 1.6) / 0.5)) or 1
		if air >= 1 and not splatted then
			splatted = true
			fx:sound("thud", 0.8, 0.7)
			poof(fx, p - UP * 0.6, 6, WHITE, 0.8)
			fx:word("SPLAT!", UP * 3 + back * 3, YELLOW, { w = 6, h = 2.2, life = 1.2, elastic = true })
			for i = 1, 4 do
				local s = fx:text("★", Vector3.zero, YELLOW, { w = 1.2, h = 1.2 })
				local t0 = now
				table.insert(fx.ticks, function(_, t)
					local a = (t - t0) * 5 + i / 4 * math.pi * 2
					s.anchor.CFrame =
						CFrame.new(p + back * 0.9 + UP + Vector3.new(math.cos(a) * 1.2, 0, math.sin(a) * 1.2))
					s.label.TextTransparency = clamp01((t - fx.life + 0.4) / 0.3)
				end)
			end
			for j = 1, 3 do
				fx:sound("ping", 3 + j * 0.2, 0.15, 0.2 + j * 0.25)
			end
		end
		if v > 1.75 then
			fx:bodyFade(clamp01((v - 1.75) / 0.4))
		end
	end)
end

-- the big ones (Robux) ----------------------------------------------------------------------------------------------

-- Lightning Strike: the sky goes dark and a storm cloud boils up overhead while static crawls over the floor toward
-- them, a low rumble (a beat); then the strike: a forked white-blue bolt out of the cloud, the cloud lit from inside,
-- a white flash, a thunder crack. They're left charred black with a glowing edge, twitching, smoking, sparks
-- arcing over a scorched ring; a second, smaller strike flickers; then they crumble into ash
S.lightning = function(fx)
	fx.life = 2.5
	fx:sticker("bolt", Vector3.new(0, 9, 0), 14, { delay = 0.36, life = 0.6, pulse = true })
	fx:sticker("zap", Vector3.new(0, 7, 0), 6.5, { delay = 0.5, wobble = true, float = 0.5, life = 1.3 })
	local blue = Cosmetics.color("electric", fx.team)
	local start = fx.body and fx.body:GetPivot() or CFrame.new(fx.at)
	local STRIKE = 0.38
	-- the sky: dark, then the strike's white flash, then back
	if fx:inWorld() and os.clock() >= gradeUntil then
		pcall(function()
			local cc = Instance.new("ColorCorrectionEffect")
			cc.Name = "TW_Lightning"
			cc.Parent = game:GetService("Lighting")
			table.insert(fx.parts, cc)
			gradeUntil = os.clock() + 1.6
			during(fx, 0, 1.6, function(u)
				local t = u * 1.6
				if t < STRIKE then
					local k = t / STRIKE
					cc.Brightness, cc.Contrast, cc.Saturation = -0.35 * k, 0.4 * k, -0.5 * k
					cc.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(170, 195, 255), k)
				elseif t < STRIKE + 0.12 then
					cc.Brightness = 0.7
				else
					local k = 1 - clamp01((t - STRIKE - 0.12) / 1)
					cc.Brightness, cc.Contrast, cc.Saturation = 0.7 * k * k - 0.2 * k, 0.4 * k, -0.5 * k
					cc.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(170, 195, 255), k)
				end
			end)
		end)
	end
	-- the cloud
	local sky = fx.pos + UP * 34
	local cloud = {}
	local dark, lit = Color3.fromRGB(40, 44, 58), Color3.fromRGB(205, 225, 255)
	for i = 1, math.max(4, math.floor(8 * fx.mult)) do
		local off = Vector3.new(rng:NextNumber(-5, 5), rng:NextNumber(-1, 1.5), rng:NextNumber(-5, 5))
		cloud[i] = {
			p = fx:part(
				Vector3.one,
				dark,
				{ ball = true, material = Enum.Material.SmoothPlastic, transparency = 0.15 }
			),
			off = off,
			s = rng:NextNumber(4, 7),
		}
	end
	during(fx, 0, fx.life, function(u, now)
		local t = u * fx.life
		local grow = outCubic(t / 0.3) * (1 - clamp01((t - 1.7) / 0.7))
		local flashing = (t > STRIKE and t < STRIKE + 0.14) or (t > 0.98 and t < 1.05)
		for i, c in cloud do
			c.p.Size = Vector3.one * math.max(0.05, c.s * grow * (1 + math.sin(now * 3 + i) * 0.08))
			c.p.CFrame = CFrame.new(sky + c.off + Vector3.new(math.sin(now + i) * 0.5, 0, 0))
			c.p.Color = flashing and lit or dark
			c.p.Transparency = grow < 0.06 and 1 or 0.15
		end
	end)
	-- static crawling in over the floor
	for j = 1, 5 do
		fx:after(j * 0.06, function()
			for _ = 1, fx.mult < 0.5 and 1 or 2 do
				local a = rng:NextNumber(0, math.pi * 2)
				local from = fx.pos + UP * 0.2 + Vector3.new(math.cos(a), 0, math.sin(a)) * (6 - j)
				arc(fx, from, fx.pos + UP * rng:NextNumber(0.3, 2.5), blue, 0.1)
			end
		end)
	end
	fx:sound("boom", 0.3, 0.55)
	fx:sound("rocket", 0.35, 0.3)
	fx:after(STRIKE, function()
		local hit = fx.pos + UP * 0.2
		local core = bolt(fx, sky, hit, 0.5, WHITE, 0.42, fx.mult < 0.5 and 0.2 or 0.45)
		bolt(fx, sky, hit, 1.3, blue, 0.48)
		table.insert(fx.ticks, function(_, t)
			local on = math.floor(t * 30) % 3 ~= 0
			for _, p in core do
				if p.Parent then
					p.Transparency = on and 0 or 0.6
				end
			end
		end)
		fx:sound("boom", 0.55, 1)
		fx:sound("glass", 0.6, 0.5)
		fx:sound("rocket", 1.6, 0.4)
		fx:light(fx.pos + UP * 4, lit, 9, 40, 0.7)
		flash(fx, blue, 9)
		ring(fx, fx.pos + UP * 0.1, blue, 8, 0.45, 0.25)
		glowBall(fx, fx.at, WHITE, 3.5, 0.2)
		fx:sparkleBurst(fx.at, blue, 40, 26)
		sparks(fx, fx.pos + UP * 0.5, fx.n, function()
			return rng:NextNumber() < 0.5 and blue or WHITE
		end, 36, { grav = 0.7, drag = 1.2, life = 0.7, len = 1.2, floor = fx.pos.Y + 0.1, up = 0.1 })
		-- the scorch on the floor, its edge glowing
		local scorch = fx:part(Vector3.new(0.1, 7, 7), INK, {
			cylinder = true,
			material = Enum.Material.SmoothPlastic,
			transparency = 0.15,
			cf = CFrame.new(fx.pos + UP * 0.06) * CFrame.Angles(0, 0, math.rad(90)),
		})
		local edge = fx:part(Vector3.new(0.08, 7.6, 7.6), ORANGE, {
			cylinder = true,
			transparency = 0.3,
			cf = CFrame.new(fx.pos + UP * 0.05) * CFrame.Angles(0, 0, math.rad(90)),
		})
		during(fx, fx.age, fx.life - fx.age - 0.05, function(u)
			scorch.Transparency = 0.15 + 0.85 * u * u
			edge.Transparency = 0.3 + 0.7 * clamp01(u * 1.6)
		end)
		-- charred: a black silhouette, edged in a hot orange
		fx:bodyGlow(INK, ORANGE, 0, 0)
		fx:emit(fx.at, {
			tex = "smoke",
			color = Color3.fromRGB(70, 70, 80),
			rate = 14,
			stream = 1.1,
			dir = UP,
			spread = 20,
			speed = { 2, 4 },
			size = { 1, 3 },
			alpha = { 0.4, 1 },
			life = { 0.8, 1.2 },
			light = 0,
			spin = 40,
		})
	end)
	-- twitching
	during(fx, STRIKE, 1.15, function(u)
		local j = (1 - u) * 0.28
		fx:bodyPivot(
			start
				* CFrame.new(rng:NextNumber(-j, j), rng:NextNumber(-j, j) * 0.5, rng:NextNumber(-j, j))
				* CFrame.Angles(0, rng:NextNumber(-j, j), rng:NextNumber(-j, j) * 0.4)
		)
	end)
	-- sparks arcing over the scorch
	for j = 1, math.max(3, math.floor(9 * fx.mult)) do
		fx:after(STRIKE + 0.1 + j * 0.11, function()
			local a = rng:NextNumber(0, math.pi * 2)
			local from = fx.pos + UP * 0.15 + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(2, 3.6)
			arc(fx, from, fx.at + randomDir() * 0.8, j % 2 == 0 and WHITE or blue, 0.09)
			if j % 3 == 0 then
				fx:sound("tick", 2.8 + rng:NextNumber(0, 0.6), 0.2)
			end
		end)
	end
	-- the second, smaller strike
	fx:after(0.98, function()
		local off = Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2))
		bolt(fx, sky + off * 2, fx.pos + off, 0.25, WHITE, 0.16)
		fx:sound("glass", 1.3, 0.3)
		fx:sound("boom", 0.9, 0.35)
	end)
	-- ash
	fx:after(1.6, function()
		fx:sound("crumble", 0.8, 0.5)
		for _ = 1, math.max(4, math.floor(12 * fx.mult)) do
			local p = fx:part(Vector3.one * rng:NextNumber(0.2, 0.45), Color3.fromRGB(45, 45, 50), {
				material = Enum.Material.SmoothPlastic,
				cf = CFrame.new(
					fx.at + Vector3.new(rng:NextNumber(-0.8, 0.8), rng:NextNumber(-2, 1.5), rng:NextNumber(-0.8, 0.8))
				),
			})
			fx:bit(p, randomDir(-1) * 2, { grav = 0.5, spin = 4, floor = fx.pos.Y + 0.15, bounce = 0, life = 0.85 })
		end
		during(fx, fx.age, 0.35, function(u)
			fx:bodyFade(u)
		end)
	end)
end

-- the shiba: a blocky head (ears, muzzle, eyes, nose)
local function dogeHead(fx)
	local tan = Color3.fromRGB(226, 170, 90)
	local cream = Color3.fromRGB(250, 236, 205)
	local m = { material = Enum.Material.SmoothPlastic }
	local w = { wedge = true, material = Enum.Material.SmoothPlastic }
	return {
		{ fx:part(Vector3.new(3, 2.6, 2.6), tan, m), CFrame.new(0, 0, 0) },
		{ fx:part(Vector3.new(1.9, 1.1, 1.3), cream, m), CFrame.new(0, -0.55, -1.5) },
		{ fx:part(Vector3.new(0.6, 0.45, 0.4), INK, m), CFrame.new(0, -0.2, -2.15) },
		{ fx:part(Vector3.new(0.35, 0.35, 0.2), INK, m), CFrame.new(-0.65, 0.45, -1.32) },
		{ fx:part(Vector3.new(0.35, 0.35, 0.2), INK, m), CFrame.new(0.65, 0.45, -1.32) },
		{ fx:part(Vector3.new(0.8, 1.2, 0.5), tan, w), CFrame.new(-1, 1.7, 0) },
		{ fx:part(Vector3.new(0.8, 1.2, 0.5), tan, w), CFrame.new(1, 1.7, 0) },
		{ fx:part(Vector3.new(2.2, 0.5, 0.2), cream, m), CFrame.new(0, -1.15, -1.32) },
	}
end

-- Much Wow: a shiba boings up out of the floor and gives the side-eye (a beat), the doge itself slams in big; then
-- the words, in comic sans, in the meme's colours: "wow", "such kill", "very rekt"... popping in one at a time round
-- it with a rising blip each; a shower of gold coins rains down, clinking, and it all pops away
S.doge = function(fx)
	fx.life = 2.6
	local pieces = dogeHead(fx)
	for _, e in pieces do
		e[3] = e[1].Size
	end
	local base = CFrame.lookAt(fx.pos + UP * 2.5, fx.pos + UP * 2.5 - facing(fx))
	fx:sound("draw", 2.2, 0.4)
	fx:sound("pop", 1.3, 0.6, 0.05)
	during(fx, 0, 2.6, function(u, now)
		local t = u * 2.6
		local rise = outBack(t / 0.35)
		local s = math.max(0.02, math.min(1, rise)) * (1 - clamp01((t - 2.2) / 0.35))
		local eye = t > 0.35 and math.min(1, (t - 0.35) * 5) * 0.3 or 0 -- (the side-eye tilt)
		local cf = base
			* CFrame.new(0, (rise - 1) * 3 + math.sin(now * 5) * 0.12, 0)
			* CFrame.Angles(0, eye * 0.6, eye + math.sin(now * 3) * 0.05)
		for _, e in pieces do
			e[1].CFrame = cf * CFrame.new(e[2].Position * s) * e[2].Rotation
			e[1].Size = e[3] * s
			e[1].Transparency = s < 0.05 and 1 or 0
		end
	end)
	poof(fx, fx.pos + UP, 5, Color3.fromRGB(250, 236, 205), 1)
	fx:sticker("doge", Vector3.new(0, 7.5, 0), 8.5, { delay = 0.3, wobble = true, pulse = true, life = 2.1 })
	-- the words: the stickers and comic sans, taking turns
	local words = { "wow", "such kill", "very rekt", "much skill", "so oof", "amaze", "many arrow", "excite" }
	local colors = {
		Color3.fromRGB(255, 60, 200),
		Color3.fromRGB(60, 220, 255),
		Color3.fromRGB(120, 255, 80),
		Color3.fromRGB(255, 230, 40),
		Color3.fromRGB(255, 120, 40),
		Color3.fromRGB(170, 120, 255),
	}
	local first = rng:NextInteger(1, #words)
	for i = 1, 8 do
		local at = 0.5 + (i - 1) * 0.17
		local a = i * 2.4
		local off = Vector3.new(math.cos(a) * rng:NextNumber(4.5, 6.5), 4.5 + math.sin(a) * 3, math.sin(a) * 1.5)
		if i % 2 == 1 then
			fx:sticker("doge_word" .. ((i + 1) // 2), off, 5, { delay = at, wobble = true, float = 0.35 })
		else
			local word = i == 2 and "wow" or words[(first + i) % #words + 1]
			fx:word(word, off, colors[i % #colors + 1], {
				w = 6,
				h = 2,
				delay = at,
				life = 2.4 - at,
				font = COMIC,
				noStroke = true,
				rotation = rng:NextNumber(-18, 18),
				float = 0.4,
			})
		end
		fx:sound("tick", 1.5 + i * 0.12, 0.35, at)
	end
	-- the coins
	fx:after(1.0, function()
		fx:sound("ping", 2.4, 0.4)
		for i = 1, math.max(4, math.floor(14 * fx.mult)) do
			local p = fx:part(Vector3.new(0.15, 0.9, 0.9), GOLD, {
				cylinder = true,
				cf = CFrame.new(
					fx.pos + Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(7, 10), rng:NextNumber(-3, 3))
				),
			})
			fx:bit(p, Vector3.new(rng:NextNumber(-2, 2), -rng:NextNumber(2, 6), rng:NextNumber(-2, 2)), {
				grav = 0.8,
				drag = 0.1,
				spin = rng:NextNumber(6, 12),
				floor = fx.pos.Y + 0.45,
				bounce = 0.45,
				life = rng:NextNumber(1.1, 1.5),
				twinkle = i % 3 == 0 and 24 or nil,
			})
			if i <= 6 then
				fx:sound("ping", rng:NextNumber(2.8, 3.4), 0.18, 0.45 + i * 0.09)
			end
		end
	end)
	fx:after(2.25, function()
		fx:sound("pop", 1.6, 0.5)
		fx:sparkleBurst(fx.pos + UP * 2.5, GOLD, 16, 10)
	end)
end

-- Web Slinger: THWIP, THWIP: web lines shoot in from above one after another and stick (a beat each); the web wraps
-- them up into a spinning cocoon, a web behind them; a held breath, then a line snaps taut to the sky and they're
-- swung away in a big arc, out of sight
S.web = function(fx)
	fx.life = 2.5
	fx:sticker("web", Vector3.new(0, 3, 0), 9, { delay = 0.3, spin = 25, onTop = false, life = 1.6 })
	fx:sticker("thwip", Vector3.new(0, 8, 0), 7, { delay = 0.05, wobble = true, float = 0.5, life = 1.2 })
	local start = fx.body and fx.body:GetPivot() or CFrame.new(fx.at)
	local center = start.Position
	local back = facing(fx)
	local side = back:Cross(UP).Unit
	local strands = {}
	local n = math.max(4, math.floor((fx.look.count or 12) * fx.mult / 2))
	for i = 1, n do
		local a = i / n * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local from = center + Vector3.new(math.cos(a) * 14, rng:NextNumber(5, 12), math.sin(a) * 14)
		local b = fx:beam(from, from, WHITE, 0.14, 0.1, { curve0 = rng:NextNumber(-2, 2), light = 0.3 })
		strands[i] = { b = b, from = from, at = (i - 1) * 0.08 }
		fx:sound("whistle", 2.8 + i * 0.05, 0.3, strands[i].at)
	end
	fx:sound("slash", 1.6, 0.35, 0.1)
	-- the cocoon: rings of web wrapping round them
	local wraps = {}
	for i = 1, 6 do
		local r = fx:part(Vector3.new(0.2, 3.4, 3.4), WHITE, {
			cylinder = true,
			material = Enum.Material.SmoothPlastic,
			transparency = 1,
		})
		table.insert(wraps, { part = r, y = -2.2 + i * 0.75, tilt = rng:NextNumber(-0.5, 0.5) })
	end
	fx:sound("draw", 1.2, 0.4, 0.5)
	fx:sound("draw", 1.5, 0.35, 0.75)
	-- the swing: round a pivot high up and on, a pendulum
	local pivot = center + UP * 26 + back * 12
	local rel = center - pivot
	local line
	local YANK = 1.15
	fx:after(YANK, function()
		line = fx:beam(pivot, center, WHITE, 0.2, 0.2, { light = 0.3 })
		fx:sound("slash", 1.1, 0.6)
		fx:sound("shoot", 0.7, 0.6)
		fx:sound("whistle", 1.2, 0.4, 0.2)
	end)
	during(fx, 0, 2.5, function(u, now)
		local t = u * 2.5
		local swing = t > YANK and ((t - YANK) / 1.2) ^ 1.6 * math.rad(140) or 0
		local held = t > 1 and t < YANK and math.sin((t - 1) * 60) * 0.06 or 0 -- (the cocoon shivers: the held breath)
		-- (on away from the killer, lifting as it goes so it never dips into the floor)
		local at = pivot + CFrame.fromAxisAngle(side, swing) * rel + UP * (swing * 4) + side * held
		for _, s in strands do
			local shoot = outCubic((t - s.at) / 0.14)
			local tip = s.from:Lerp(at, shoot)
			s.b.b.CFrame = CFrame.new(tip)
			local w = (t < s.at or t > YANK + 0.25) and 0 or 0.14 * (1 - clamp01((t - YANK) / 0.25))
			s.b.beam.Width0, s.b.beam.Width1 = w, w * 0.7
		end
		for i, w in wraps do
			local k = clamp01((t - 0.45 - i * 0.07) / 0.15)
			w.part.Transparency = t > fx.life - 0.5 and 0.15 + 0.85 * clamp01((t - fx.life + 0.5) / 0.4) or 1 - k * 0.85
			w.part.CFrame = CFrame.new(at + UP * w.y) * CFrame.Angles(w.tilt, now * 2, math.rad(90))
		end
		fx:bodyPivot(
			CFrame.new(at) * start.Rotation * CFrame.fromAxisAngle(side, swing * 0.6) * CFrame.Angles(0, now * 2, 0)
		)
		if line then
			line.b.CFrame = CFrame.new(at + UP * 2)
		end
		if t > fx.life - 0.5 then
			fx:bodyFade(clamp01((t - fx.life + 0.5) / 0.4))
			if line then
				line.beam.Width0, line.beam.Width1 = 0, 0
			end
		end
	end)
	fx:word("THWIP!", UP * 4.5, WHITE, { w = 6, h = 2, life = 1, stroke = Color3.fromRGB(200, 30, 40), wobble = true })
end

-- OOF: they're knocked flat on their back, a ragdoll bounce off the floor (thud), while a giant OOF slams down out of
-- the sky onto them, squashing and stretching; comic impact lines burst out, the OOF bounces twice, lower each time,
-- and deflates like a balloon, whistling as it shrinks and spins away
S.oof = function(fx)
	fx.life = 2.3
	local start = fx.body and fx.body:GetPivot() or CFrame.new(fx.at)
	local back = facing(fx)
	local side = back:Cross(UP).Unit
	local height = math.max(1.5, start.Position.Y - fx.pos.Y)
	local feet = Vector3.new(start.Position.X, fx.pos.Y, start.Position.Z)
	local LAND = 0.4
	during(fx, 0, 2.3, function(u, now)
		local t = u * 2.3
		local fall = clamp01(t / LAND)
		local ang = -(fall * fall) * math.rad(88)
		local slide = outCubic(fall) * 1.6
		local hop = t > LAND and bounce((t - LAND) / 0.7) * 0.9 or 0
		local twitch = (t > 1.2 and t < 1.5) and math.sin(now * 50) * 0.08 or 0
		local cf = CFrame.new(feet + back * slide + UP * hop)
			* CFrame.fromAxisAngle(side, ang + twitch)
			* start.Rotation
			* CFrame.new(0, height, 0)
		fx:bodyPivot(cf)
		if t > 1.9 then
			fx:bodyFade(clamp01((t - 1.9) / 0.35))
		end
	end)
	fx:sound("shoot", 0.9, 0.4)
	-- the OOF, slammed down from the sky
	local w = fx:text("OOF", UP * 3.5, YELLOW, { w = 10, h = 4.5, font = Enum.Font.LuckiestGuy })
	local landAt = back * 1.6
	local deflate
	table.insert(fx.ticks, function(_, now)
		local v = now - w.born
		local W, H = 10, 4.5
		local y, sx, sy, rot = 3.5, 1, 1, 0
		if v < LAND then
			y = 3.5 + (1 - v / LAND) ^ 2 * 14
			sx, sy = 0.8, 1.25 -- (stretched as it falls)
		elseif v < 1.4 then
			local b = (v - LAND) / 1
			y = 3.5 + bounce(b) * 2.2
			local sq = math.sin(math.min(1, (v - LAND) / 0.18) * math.pi) * 0.35 * (1 - b)
			sx, sy = 1 + sq, 1 - sq
			rot = math.sin(v * 9) * 6
		else
			local d = clamp01((v - 1.4) / 0.6)
			sx, sy = 1 - d, 1 - d
			y = 3.5 + d * 6
			rot = d * 720
		end
		w.gui.Size = UDim2.fromScale(math.max(0.01, W * sx), math.max(0.01, H * sy))
		w.anchor.CFrame = CFrame.new(fx.at + landAt + UP * y)
		w.label.Rotation = rot
		local fade = clamp01((v - 1.9) / 0.2)
		w.label.TextTransparency, w.label.TextStrokeTransparency = fade, fade
	end)
	fx:after(LAND, function()
		fx:sound("thud", 0.7, 0.9)
		fx:sound("pop", 0.5, 0.6)
		fx:sound("boom", 1.4, 0.4)
		poof(fx, fx.pos + back * 1.6 + UP * 0.5, 7, Color3.fromRGB(240, 235, 220), 1)
		fx:sticker("oof", Vector3.new(0, 7, 0) + landAt, 8, { wobble = true, pulse = true, life = 1 })
		-- comic impact lines
		for i = 1, math.max(6, math.floor(10 * fx.mult)) do
			local a = i / 10 * math.pi * 2
			local d = (side * math.cos(a) + UP * math.abs(math.sin(a)) + back * math.sin(a) * 0.4).Unit
			local p = fx:part(Vector3.new(0.12, 0.12, 1.4), i % 2 == 0 and YELLOW or WHITE, {
				cf = CFrame.lookAt(fx.at + landAt, fx.at + landAt + d),
			})
			fx:bit(p, d * 22, { drag = 5, face = true, life = 0.35 })
		end
		for i = 1, math.floor(8 * fx.mult) do
			local p = fx:part(Vector3.new(0.5, 0.5, 0.15), i % 2 == 0 and YELLOW or ORANGE, { cf = CFrame.new(fx.at) })
			fx:bit(p, randomDir(0.2) * rng:NextNumber(10, 18), { grav = 0.6, drag = 1, spin = 6, life = 1 })
		end
		flash(fx, YELLOW, 5)
	end)
	fx:sound("pop", 0.45, 0.4, LAND + 0.45)
	fx:sound("pop", 0.4, 0.3, LAND + 0.8)
	fx:after(1.4, function()
		deflate = fx:sound("whistle", 2, 0.5)
		during(fx, fx.age, 0.6, function(u)
			if deflate then
				deflate.PlaybackSpeed = (2 - u * 1.4) * math.max(0.35, fx:speed())
			end
		end)
	end)
end

-- Bonk: a "!" over their head as a giant mallet winds up behind them, creaking back (a beat), then WHOOSH, BONK: it
-- slams down, the mallet head squashing, they're squashed into the floor, a shockwave and dust, cracks in the
-- floor; stars and birdies go round their head as they wobble back up, dizzy, and the mallet rocks to a stop
S.bonk = function(fx)
	fx.life = 2.4
	fx:sticker("bonk", Vector3.new(0, 8, 0), 7.5, { delay = 0.55, wobble = true, float = 0.4, life = 1.4 })
	fx:word(
		"!",
		UP * 3.6,
		WHITE,
		{ w = 2, h = 2, life = 0.45, wobble = true, font = Enum.Font.LuckiestGuy, stroke = Color3.fromRGB(220, 40, 50) }
	)
	local brown = Color3.fromRGB(130, 80, 40)
	local red = Color3.fromRGB(220, 40, 50)
	local m = { material = Enum.Material.SmoothPlastic }
	local handle = fx:part(Vector3.new(0.5, 7, 0.5), brown, m)
	local head = fx:part(Vector3.new(2.6, 2.2, 4), red, m)
	local band1 = fx:part(Vector3.new(2.7, 2.3, 0.4), WHITE, m)
	local band2 = fx:part(Vector3.new(2.7, 2.3, 0.4), WHITE, m)
	local mallet = { handle, head, band1, band2 }
	local back = facing(fx)
	local pivot = CFrame.lookAt(fx.pos + back * 7 + UP * 0.5, fx.pos + back * 8 + UP * 0.5)
	local start = fx.body and fx.body:GetPivot() or CFrame.new(fx.at)
	local height = math.max(1.5, start.Position.Y - fx.pos.Y)
	local HIT = 0.55
	fx:sound("draw", 0.8, 0.5)
	fx:sound("draw", 0.7, 0.4, 0.25)
	fx:sound("shoot", 0.6, 0.6, HIT - 0.1)
	during(fx, 0, 2.4, function(u, now)
		local t = u * 2.4
		local a
		if t < 0.45 then
			a = math.rad(-30 - 85 * outCubic(t / 0.45)) -- (wound up, creaking back)
		elseif t < HIT then
			a = math.rad(-115 + 205 * ((t - 0.45) / (HIT - 0.45)) ^ 2)
		else
			a = math.rad(90 - 14 * math.sin((t - HIT) * 18) * math.max(0, 1 - (t - HIT) * 1.8))
		end
		local squash = t > HIT and math.max(0, 1 - (t - HIT) / 0.25) or 0
		local cf = pivot * CFrame.Angles(a, 0, 0)
		handle.CFrame = cf * CFrame.new(0, 3.5, 0)
		head.Size = Vector3.new(2.6 * (1 + squash * 0.4), 2.2, 4 * (1 - squash * 0.3))
		head.CFrame = cf * CFrame.new(0, 7.5, 0) * CFrame.Angles(0, math.rad(90), 0)
		band1.CFrame = head.CFrame * CFrame.new(0, 0, 1.3 * (1 - squash * 0.3))
		band2.CFrame = head.CFrame * CFrame.new(0, 0, -1.3 * (1 - squash * 0.3))
		local fade = clamp01((t - 2.05) / 0.3)
		for _, p in mallet do
			p.Transparency = fade
		end
		-- them: squashed into the floor, then wobbling back up, dizzy
		if t >= HIT then
			local s = t < 1.5 and 0.55 or 0.55 + 0.45 * outElastic((t - 1.5) / 0.5)
			fx:bodyScale(s)
			local wob = t > 1.5 and math.sin(now * 6) * 0.15 * math.max(0, 1 - (t - 1.5)) or 0
			fx:bodyPivot(
				CFrame.new(Vector3.new(start.Position.X, fx.pos.Y + height * s, start.Position.Z))
					* start.Rotation
					* CFrame.Angles(wob, 0, wob * 0.6)
			)
		end
		if t > 2.05 then
			fx:bodyFade(clamp01((t - 2.05) / 0.3))
		end
	end)
	fx:after(HIT, function()
		fx:sound("thud", 0.55, 1)
		fx:sound("boom", 1.1, 0.5)
		fx:sound("ping", 0.9, 0.4)
		poof(fx, fx.pos + UP * 0.5, 8, WHITE, 1)
		ring(fx, fx.pos + UP * 0.12, WHITE, 6, 0.4, 0.2)
		fx:light(fx.at, WHITE, 3, 14, 0.3)
		fx:word("BONK!", UP * 4, WHITE, {
			w = 9,
			h = 3.5,
			life = 1.5,
			elastic = true,
			rotation = -8,
			wobble = true,
			font = Enum.Font.LuckiestGuy,
			stroke = red,
		})
		-- cracks in the floor
		for i = 1, math.max(4, math.floor(7 * fx.mult)) do
			local a = i / 7 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
			local d = Vector3.new(math.cos(a), 0, math.sin(a))
			local len = rng:NextNumber(1.5, 3)
			local p = fx:part(Vector3.new(0.12, 0.05, len), INK, {
				material = Enum.Material.SmoothPlastic,
				cf = CFrame.lookAt(fx.pos + UP * 0.04 + d * (0.8 + len / 2), fx.pos + UP * 0.04 + d * 4),
			})
			fx:bit(p, Vector3.zero, { life = fx.life - fx.age - 0.1, shrink = false })
		end
		-- stars and birdies round their head
		local t0 = fx.age
		for i = 1, 5 do
			local s = fx:text(i % 2 == 0 and "🐦" or "★", Vector3.zero, YELLOW, { w = 1.3, h = 1.3 })
			table.insert(fx.ticks, function(_, now)
				local v = now - t0
				local ang = v * 5 + i / 5 * math.pi * 2
				local s2 = v < 0.95 and 0.55 or math.min(1, 0.55 + (v - 0.95))
				s.anchor.CFrame = CFrame.new(
					fx.pos
						+ UP * (height * 2 * s2 + 0.4)
						+ Vector3.new(math.cos(ang) * 1.6, math.sin(v * 8 + i) * 0.2, math.sin(ang) * 1.6)
				)
				s.label.TextTransparency = clamp01((v - 1.5) / 0.3)
			end)
		end
		for j = 1, 4 do
			fx:sound("ping", 3.2 + (j % 2) * 0.3, 0.15, 0.3 + j * 0.25)
		end
	end)
	fx:sound("draw", 2.2, 0.4, 1.5)
end

-- Dance Off: the lights go down and a disco ball drops in on its string, a record scratch (a beat); the floor lights
-- up in a wave from them, spotlights sweep, and they dance on the beat (a hop, a lean, a lean, a spin...) to a kick,
-- a hi-hat and a little tune; a pose, a sparkle, and they moonwalk off
S.dance = function(fx)
	fx.life = 2.6
	fx:sticker("disco", Vector3.new(0, 10, 0), 5, { delay = 0.35, spin = 90, life = 2 })
	grade(fx, { brightness = -0.15, contrast = 0.2, saturation = 0.2 }, 0.3, 1.6, 0.5)
	local tiles = {}
	local half = 2
	for x = -half, half do
		for z = -half, half do
			local p = fx:part(Vector3.new(1.9, 0.12, 1.9), WHITE, {
				transparency = 1,
				cf = CFrame.new(fx.pos + Vector3.new(x * 2, 0.07, z * 2)),
			})
			table.insert(tiles, { part = p, i = (x + 3) * 7 + (z + 3) * 3, d = math.sqrt(x * x + z * z) })
		end
	end
	local ball =
		fx:part(Vector3.one * 2, Color3.fromRGB(220, 220, 230), { ball = true, material = Enum.Material.Glass })
	local string_ = fx:part(Vector3.new(0.05, 1, 0.05), WHITE, { material = Enum.Material.SmoothPlastic })
	local rays = {}
	for i = 1, math.max(3, math.floor(6 * fx.mult)) do
		rays[i] = fx:beam(fx.pos, fx.pos, rainbow(i), 0.4, 2.2, { alpha = 0.35 })
	end
	local light = fx:light(fx.pos + UP * 6, WHITE, 3, 20)
	local start = fx.body and fx.body:GetPivot() or CFrame.new(fx.at)
	local BEAT, GO = 0.28, 0.45
	fx:sound("slash", 2.4, 0.4)
	fx:sound("draw", 0.6, 0.4, 0.05)
	local tune = { 1, 1.26, 1.5, 1.26, 2, 1.5, 1.26, 1.5 }
	for j = 0, 6 do
		fx:sound("thud", 0.85, 0.55, GO + j * BEAT)
		if j % 2 == 1 then
			fx:sound("click", 2, 0.25, GO + j * BEAT + BEAT / 2)
		end
		fx:sound("ping", tune[j + 1] * 1.4, 0.22, GO + j * BEAT)
	end
	during(fx, 0, 2.6, function(u, now)
		local t = u * 2.6
		local beatF = math.max(0, (t - GO) / BEAT)
		local beat = math.floor(beatF)
		local within = beatF - beat
		local fade = clamp01((t - 2.1) / 0.45)
		-- the floor: a wave of light out from them, then the pattern on the beat
		for _, e in tiles do
			local on = t > GO + e.d * 0.06
			e.part.Color = rainbow(e.i + beat)
			e.part.Transparency = on and math.max(fade, (e.i + beat) % 3 == 0 and 0.55 or 0) or 1
		end
		-- the ball comes down on its string
		local drop = outBack(t / 0.4)
		local top = fx.pos + UP * (12 - 5 * drop)
		ball.CFrame = CFrame.new(top) * CFrame.Angles(0, now * 4, 0)
		ball.Transparency = fade
		local sky = fx.pos + UP * 30
		string_.Size = Vector3.new(0.05, (sky - top).Magnitude, 0.05)
		string_.CFrame = CFrame.new((sky + top) / 2)
		string_.Transparency = fade
		for i, r in rays do
			local a = now * 2.5 + i / #rays * math.pi * 2
			r.a.CFrame = CFrame.new(top)
			r.b.CFrame = CFrame.new(fx.pos + Vector3.new(math.cos(a) * 5, 0.1, math.sin(a) * 5))
			local w = t < GO and 0 or (1 - fade)
			r.beam.Width0, r.beam.Width1 = 0.4 * w, 2.2 * w
		end
		if light then
			light.Color = rainbow(beat, now)
			light.Brightness = t < GO and 0 or 3 * (1 - fade) * (1 - within * 0.6)
		end
		-- the dance: a move per beat
		local pose = CFrame.new()
		if t >= GO and beat < 6 then
			local e = math.sin(within * math.pi)
			local move = beat % 4
			if move == 0 then
				pose = CFrame.new(0, e * 1.1, 0) * CFrame.Angles(0, within * math.pi / 2, 0)
			elseif move == 1 then
				pose = CFrame.new(-e * 0.4, 0, 0) * CFrame.Angles(0, 0, e * 0.35)
			elseif move == 2 then
				pose = CFrame.new(e * 0.4, 0, 0) * CFrame.Angles(0, 0, -e * 0.35)
			else
				pose = CFrame.new(0, e * 0.5, 0) * CFrame.Angles(0, within * math.pi * 2, 0)
			end
		elseif beat >= 6 then
			-- the pose, then the moonwalk off
			local slide = math.max(0, t - (GO + 6.3 * BEAT))
			pose = CFrame.new(0, 0, slide * 3) * CFrame.Angles(0, 0, math.sin(now * 12) * 0.04)
		end
		fx:bodyPivot(start * pose)
		if fade > 0 then
			fx:bodyFade(fade)
		end
	end)
	fx:after(GO + 6 * BEAT, function()
		fx:sparkleBurst(fx.at + UP, WHITE, 20, 10)
		fx:word("✨", UP * 3.6, YELLOW, { w = 2.2, h = 2.2, life = 0.7, elastic = true })
		fx:sound("ping", 2.5, 0.35)
	end)
end

-- Black Hole: space tears open beside them (a spark, the colour drains away) and the hole swells, its disc
-- spinning; everything is pulled in: chips torn up off the floor spiral in and stretch thin, and so do they,
-- spinning, stretched into streaks of their own colour, shrinking into it, the hum rising; it collapses to a point,
-- a beat of silence, and POPS: a flash, a shockwave, sparkles
S.blackhole = function(fx)
	fx.life = 2.4
	fx:sticker(
		"blackhole",
		Vector3.new(0, 3, 0),
		12,
		{ delay = 0.1, spin = -160, pulse = true, onTop = false, life = 1.6 }
	)
	grade(
		fx,
		{ brightness = -0.1, contrast = 0.3, saturation = -0.7, tint = Color3.fromRGB(215, 195, 255) },
		0.25,
		1.4,
		0.6
	)
	local purple, pink = Color3.fromRGB(150, 60, 255), Color3.fromRGB(255, 80, 200)
	local center = fx.at + UP * 0.6
	local SUCK, COLLAPSE, POP = 0.3, 1.55, 1.8
	glowBall(fx, center, WHITE, 0.6, 0.2) -- (the spark where it tears)
	local disc = fx:part(Vector3.new(0.2, 1, 1), INK, { cylinder = true, material = Enum.Material.SmoothPlastic })
	local ring1 = fx:part(Vector3.new(0.15, 1, 1), purple, { cylinder = true, transparency = 0.2 })
	local ring2 = fx:part(Vector3.new(0.12, 1, 1), pink, { cylinder = true, transparency = 0.4 })
	local core = fx:part(Vector3.one, INK, { ball = true, material = Enum.Material.SmoothPlastic })
	local lens = fx:part(Vector3.one, WHITE, { ball = true, material = Enum.Material.ForceField, transparency = 0.3 })
	local light = fx:light(center, purple, 2, 16)
	-- chips torn up off the floor
	local chips = {}
	for i = 1, fx.n do
		local p = fx:part(
			Vector3.new(0.3, 0.3, 0.3),
			i % 3 == 0 and WHITE or (i % 3 == 1 and purple or Color3.fromRGB(110, 105, 120)),
			{}
		)
		chips[i] = {
			p = p,
			a = rng:NextNumber(0, 6.28),
			r = rng:NextNumber(4, 10),
			y = rng:NextNumber(-1.5, 2.5),
			late = rng:NextNumber(0, 0.5),
		}
	end
	-- their streaks: stretched out of them into the hole, in their own colour
	local victim = Cosmetics.color("team", fx.victimTeam)
	local streaks = {}
	for i = 1, math.max(3, math.floor(6 * fx.mult)) do
		streaks[i] = {
			p = fx:part(
				Vector3.new(0.2, 0.2, 0.1),
				i % 2 == 0 and victim or victim:Lerp(WHITE, 0.4),
				{ transparency = 1 }
			),
			off = randomDir() * 0.8,
		}
	end
	local start = fx.body and fx.body:GetPivot() or CFrame.new(fx.at)
	local startOff = start.Position - center
	if startOff.Magnitude < 1 then
		startOff = facing(fx) * 3
		start = CFrame.new(center + startOff) * start.Rotation
	end
	local hum = fx:sound("wind", 0.4, 0.5)
	fx:sound("rocket", 0.35, 0.4)
	during(fx, 0, 2.4, function(u, now)
		local t = u * 2.4
		local open = outBack(t / 0.4) * (t > COLLAPSE and math.max(0, 1 - (t - COLLAPSE) / (POP - COLLAPSE)) or 1)
		local r = 4.5 * open
		local gone = t >= POP
		disc.Size = Vector3.new(0.2, r * 2, r * 2)
		disc.CFrame = CFrame.new(center) * CFrame.Angles(0, now * 3, math.rad(90))
		ring1.Size = Vector3.new(0.15, r * 2.5, r * 2.5)
		ring1.CFrame = CFrame.new(center) * CFrame.Angles(math.rad(14), now * 5, math.rad(90))
		ring2.Size = Vector3.new(0.12, r * 3, r * 3)
		ring2.CFrame = CFrame.new(center) * CFrame.Angles(math.rad(-10), -now * 4, math.rad(90))
		core.Size = Vector3.one * math.max(0.05, r * 0.9)
		core.CFrame = CFrame.new(center)
		lens.Size = Vector3.one * math.max(0.05, r * 1.25 * (1 + math.sin(now * 20) * 0.03))
		lens.CFrame = CFrame.new(center)
		disc.Transparency, core.Transparency = gone and 1 or 0, gone and 1 or 0
		ring1.Transparency, ring2.Transparency = gone and 1 or 0.2, gone and 1 or 0.4
		lens.Transparency = gone and 1 or 0.3
		if light then
			light.Brightness = gone and 0 or 2 * open
		end
		-- the pull
		local k = clamp01((t - SUCK) / (COLLAPSE - SUCK))
		for _, c in chips do
			local kk = clamp01((t - SUCK - c.late) / (COLLAPSE - SUCK - c.late))
			local rr = c.r * (1 - kk * kk)
			local aa = c.a + now * (2 + 9 * kk)
			local pos = center
				+ Vector3.new(
					math.cos(aa) * rr,
					c.y * (1 - kk) - (1 - math.min(1, kk * 4)) * (c.y + 1.4),
					math.sin(aa) * rr
				)
			local tangent = Vector3.new(-math.sin(aa), 0, math.cos(aa))
			c.p.Size = Vector3.new(0.3 * (1 - kk * 0.6), 0.3 * (1 - kk * 0.6), 0.3 + kk * 2.2)
			c.p.CFrame = CFrame.lookAt(pos, pos + tangent)
			c.p.Transparency = (kk > 0.97 or gone) and 1 or 0
		end
		-- them: spiralling in, stretched thin, shrinking, gone
		local orbit = startOff.Magnitude * (1 - k * k)
		local aa = math.atan2(startOff.Z, startOff.X) + k * k * 9
		local pos = center + Vector3.new(math.cos(aa) * orbit, startOff.Y * (1 - k), math.sin(aa) * orbit)
		fx:bodyPivot(CFrame.new(pos) * start.Rotation * CFrame.Angles(k * 3, now * 10 * k, 0))
		fx:bodyScale(math.max(0.05, 1 - k * 0.95))
		if k > 0.1 then
			fx:bodyGlow(purple, pink, 1 - k * 0.6, 0.2)
		end
		if k >= 1 then
			fx:bodyFade(1)
		end
		for _, s in streaks do
			local from = pos + s.off * (1 - k)
			local len = (center - from).Magnitude
			s.p.Size = Vector3.new(0.25 * (1 - k * 0.7), 0.25 * (1 - k * 0.7), math.max(0.1, len * k))
			s.p.CFrame = CFrame.lookAt(from:Lerp(center, k * 0.5), center)
			s.p.Transparency = (k < 0.15 or k >= 1) and 1 or 0.15
		end
		if hum then
			hum.PlaybackSpeed = (0.4 + k * 1.2) * math.max(0.35, fx:speed())
			hum.Volume = t > COLLAPSE and 0 or 0.5
		end
	end)
	fx:after(POP, function()
		fx:sound("boom", 0.8, 0.9)
		fx:sound("glass", 1.8, 0.4)
		fx:sound("ping", 0.5, 0.45)
		glowBall(fx, center, WHITE, 3, 0.25)
		glowBall(fx, center, Color3.fromRGB(200, 120, 255), 6, 0.45)
		ring(fx, center, Color3.fromRGB(200, 120, 255), 9, 0.5, 0.2)
		fx:light(center, Color3.fromRGB(220, 160, 255), 8, 24, 0.45)
		fx:sparkleBurst(center, Color3.fromRGB(200, 120, 255), 40, 24)
		sparks(fx, center, 12, function(i)
			return i % 2 == 0 and WHITE or pink
		end, 28, { grav = 0, drag = 2.2, len = 1.6, life = 0.5 })
	end)
end

-- Golden Gate: the clouds part: the world warms and brightens, a beam of golden light comes down on them and a choir
-- swells (a beat); golden gates rise out of the floor behind them and swing open on white light; wings unfold, a
-- halo lights over their head and they lift, slowly at first, glowing gold, up and in through the gates, feathers
-- drifting down after; the gates swing shut behind them with a soft boom and a last burst of gold
S.heaven = function(fx)
	fx.life = 2.9
	fx:sticker("heaven", Vector3.new(0, 9, 0), 10, { delay = 0.15, spin = 12, float = 1.2, onTop = false, life = 2.4 })
	grade(
		fx,
		{ brightness = 0.18, contrast = 0.1, saturation = 0.25, tint = Color3.fromRGB(255, 236, 190) },
		0.4,
		1.8,
		0.6
	)
	local warm = Color3.fromRGB(255, 236, 170)
	local back = facing(fx)
	local start = fx.body and fx.body:GetPivot() or CFrame.new(fx.at)
	local beam = fx:beam(fx.pos + UP * 70, fx.pos + UP * 70, warm, 4, 4, { alpha = 0.45 })
	local light = fx:light(fx.at + UP * 2, warm, 0, 22)
	-- the gates: two doors of gold bars on hinges, an arch, the light behind
	local gateAt = fx.pos + back * 2.6
	local gateCf = CFrame.lookAt(gateAt, gateAt + back)
	local doors = {}
	for s = -1, 1, 2 do
		local list = {}
		for b = 1, 4 do
			table.insert(list, {
				p = fx:part(Vector3.new(0.18, 6, 0.18), GOLD, { material = Enum.Material.Metal }),
				off = CFrame.new(-s * (b * 0.55), 3, 0),
			})
		end
		for _, y in { 0.4, 3, 5.7 } do
			table.insert(list, {
				p = fx:part(Vector3.new(2.5, 0.2, 0.2), GOLD, { material = Enum.Material.Metal }),
				off = CFrame.new(-s * 1.3, y, 0),
			})
		end
		doors[s] = { list = list, hinge = CFrame.new(s * 2.6, 0, 0) }
	end
	local arch = {}
	for i = 0, 6 do
		local a = math.pi * i / 6
		table.insert(arch, {
			p = fx:part(Vector3.new(0.35, 0.35, 0.35), GOLD, { ball = true }),
			off = CFrame.new(math.cos(a) * 2.6, 6.2 + math.sin(a) * 1.4, 0),
		})
	end
	local glow = fx:part(Vector3.new(5.2, 6.4, 0.1), WHITE, { transparency = 1 })
	-- wings: three feathers a side, fanned; and the halo
	local wings = {}
	for s = -1, 1, 2 do
		for f = 1, 3 do
			table.insert(wings, {
				p = fx:part(
					Vector3.new(0.15, 2.2 - f * 0.35, 1.3),
					WHITE,
					{ wedge = true, material = Enum.Material.SmoothPlastic, transparency = 1 }
				),
				s = s,
				f = f,
			})
		end
	end
	local halo = fx:part(Vector3.new(0.12, 1.6, 1.6), GOLD, { cylinder = true, transparency = 1 })
	fx:sound("ping", 0.5, 0.45)
	fx:sound("ping", 0.63, 0.4, 0.15)
	fx:sound("ping", 0.75, 0.4, 0.3)
	fx:sound("win", 0.8, 0.3, 0.35)
	fx:sound("rocket", 0.3, 0.3, 0.35)
	fx:sound("glass", 0.5, 0.35, 0.8)
	fx:sound("ping", 1.5, 0.3, 0.85)
	fx:sound("whistle", 0.8, 0.25, 1.1)
	fx:sound("thud", 0.6, 0.6, 2.35)
	fx:sound("ping", 1, 0.4, 2.4)
	local OPEN, LIFT, SHUT = 0.75, 0.95, 2.3
	during(fx, 0, 2.9, function(u, now)
		local t = u * 2.9
		local fade = clamp01((t - 2.5) / 0.4)
		-- the beam comes down
		local reach = outCubic(t / 0.35)
		beam.b.CFrame = CFrame.new(fx.pos + UP * (70 - 70 * reach))
		local bw = 4.2 * (1 - fade) * (1 + math.sin(now * 6) * 0.06)
		beam.beam.Width0, beam.beam.Width1 = bw, bw
		if light then
			light.Brightness = 3 * reach * (1 - fade)
		end
		-- the gates rise, open, and shut
		local up = outBack(clamp01((t - 0.3) / 0.4))
		local open = outCubic(clamp01((t - OPEN) / 0.35)) * (1 - outCubic(clamp01((t - SHUT) / 0.25)))
		local base = gateCf * CFrame.new(0, (up - 1) * 7, 0)
		for s, d in doors do
			local hingeCf = base * d.hinge * CFrame.Angles(0, -s * open * math.rad(100), 0) -- (opening away)
			for _, e in d.list do
				e.p.CFrame = hingeCf * e.off
				e.p.Transparency = up < 0.02 and 1 or fade
			end
		end
		for _, e in arch do
			e.p.CFrame = base * e.off
			e.p.Transparency = up < 0.02 and 1 or fade
		end
		glow.CFrame = base * CFrame.new(0, 3.2, 0.3)
		glow.Transparency = 1 - open * 0.75 * (1 - fade)
		-- them: lifted, winged, haloed, glowing gold, up and in through the gates
		local v = math.max(0, t - LIFT)
		local rise = v ^ 1.5 * 2.6
		local into = clamp01((t - 1.6) / 0.7)
		local cf = start * CFrame.new(0, rise, 0) * CFrame.Angles(0, math.sin(now * 1.5) * 0.15, 0)
		cf = CFrame.new(cf.Position + back * into * 2.6) * cf.Rotation
		fx:bodyPivot(cf)
		if t > 0.5 then
			fx:bodyGlow(GOLD, WHITE, 1 - clamp01((t - 0.5) / 1.2) * 0.55, 0.3)
		end
		local grow = outBack(clamp01((t - 0.6) / 0.4))
		local flap = math.sin(now * 9) * 0.35
		for _, w in wings do
			local spread = math.rad(20 + w.f * 18) + flap
			w.p.Size = Vector3.new(0.15, 2.2 - w.f * 0.35, 1.3) * math.max(0.05, grow)
			w.p.CFrame = cf
				* CFrame.new(w.s * 0.5, 0.9, 0.6)
				* CFrame.Angles(w.f * 0.12, w.s * spread, w.s * (0.3 + w.f * 0.15))
				* CFrame.new(0, 0, 0.7)
			w.p.Transparency = t < 0.6 and 1 or math.max(fade, into)
		end
		halo.CFrame = cf * CFrame.new(0, 2.7 + math.sin(now * 4) * 0.1, 0) * CFrame.Angles(0, 0, math.rad(90))
		halo.Transparency = t < 0.65 and 1 or math.max(fade, into)
		if into > 0 then
			fx:bodyFade(into)
		end
		-- sparkles drifting up in the beam
		if t < 2.4 and rng:NextNumber() < 0.45 * fx.mult then
			local p = fx:part(Vector3.one * 0.25, rng:NextNumber() < 0.5 and GOLD or WHITE, {
				ball = true,
				cf = CFrame.new(
					fx.pos + Vector3.new(rng:NextNumber(-1.8, 1.8), rng:NextNumber(0, 4), rng:NextNumber(-1.8, 1.8))
				),
			})
			fx:bit(p, UP * rng:NextNumber(4, 8), { twinkle = 20, life = 0.6, drag = 0 })
		end
	end)
	-- feathers drifting down after them
	fx:after(1.5, function()
		for _ = 1, math.max(3, math.floor(8 * fx.mult)) do
			local p = fx:part(Vector3.new(0.06, 0.3, 0.9), WHITE, {
				wedge = true,
				material = Enum.Material.SmoothPlastic,
				cf = CFrame.new(fx.at + UP * rng:NextNumber(3, 5) + randomDir() * 1.2),
			})
			fx:bit(p, randomDir() * 2, { grav = 0.03, drag = 2, spin = 2, sway = 1, life = rng:NextNumber(1, 1.3) })
		end
	end)
	fx:after(SHUT + 0.2, function()
		fx:sparkleBurst(gateAt + UP * 3, GOLD, 30, 14)
		ring(fx, fx.pos + UP * 0.1, GOLD, 6, 0.5, 0.15)
	end)
	fx:sparkleBurst(fx.at, GOLD, 24, 8)
end

-- Playing ------------------------------------------------------------------------------------------------------------
local MULT = { high = 1, mid = 0.7, low = 0.4 }

local function connect()
	if stepping then
		return
	end
	stepping = RunService.RenderStepped:Connect(function(dt)
		KillEffects.step(dt)
	end)
end

function KillEffects.step(dt)
	dt = math.clamp(dt or 1 / 60, 0, 1 / 15)
	for i = #actors, 1, -1 do
		local a = actors[i]
		if not a.alive or not a:step(dt) then
			table.remove(actors, i)
		end
	end
	if #actors == 0 and stepping then
		stepping:Disconnect()
		stepping = nil
	end
end

function KillEffects.playShape(shape, pos, team, opts)
	local fn = S[shape]
	if not fn or typeof(pos) ~= "Vector3" then
		return nil
	end
	opts = opts or {}
	local t = tier()
	if KillEffects.pieces() > (MAX_PIECES[t] or 150) then
		return nil -- (too much on screen: this one sits out)
	end
	local look = opts.look or { shape = shape, color = "team", count = 12 }
	local dir = typeof(opts.dir) == "Vector3" and opts.dir.Magnitude > 0.01 and opts.dir.Unit or Vector3.new(1, 0, 0)
	local f = getFolder()
	local anchor = Instance.new("Part")
	anchor.Name = "FxAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.CFrame = CFrame.new(pos)
	anchor.Parent = f
	-- pos is where they stood (a body's middle); the floor under it for what lies on the ground
	local ground = pos - UP * 2.9
	pcall(function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { f, opts.body }
		local hit = workspace:Raycast(pos + UP * 0.5, Vector3.new(0, -8, 0), params)
		if hit then
			ground = hit.Position
		end
	end)
	local fx = setmetatable({
		shape = shape,
		look = look,
		pos = ground,
		at = pos + UP * 0.3,
		dir = dir,
		team = team,
		victimTeam = opts.victimTeam,
		color = look.color == "rainbow" and rainbow(0) or Cosmetics.color(look.color or "team", team),
		mult = MULT[t] or 0.4,
		scale = math.clamp(tonumber(opts.scale) or 1, 0.05, 2),
		fixed = opts.fixed == true,
		age = 0,
		life = LIFE,
		folder = f,
		anchor = anchor,
		parts = {},
		bits = {},
		emitters = {},
		timers = {},
		ticks = {},
		body = opts.body,
		ownsBody = opts.ownsBody ~= false and opts.body ~= nil,
		bodyAlpha = {},
		alive = true,
	}, Actor)
	fx.n = math.max(3, math.floor((look.count or 12) * fx.mult * (t == "high" and 1.3 or 1) + 0.5))
	-- a stand-in for the ones that move a body, when none was handed over
	if BODY[shape] and not fx.body then
		local ok, m = pcall(Effects.mannequin, CFrame.new(fx.at), opts.victimTeam)
		if ok and m then
			fx.body, fx.ownsBody = m, true
		end
	end
	fx.tick = function(self, now, dt)
		for _, tk in self.ticks do
			tk(self, now, dt)
		end
	end
	local ok, err = pcall(fn, fx)
	if not ok then
		warn("[KillEffects] " .. shape .. ": " .. tostring(err))
		fx:destroy()
		return nil
	end
	table.insert(actors, fx)
	connect()
	return fx
end

function KillEffects.play(effectKey, pos, team, opts)
	local it = Cosmetics.get(effectKey)
	if not it or it.kind ~= "effect" then
		return nil
	end
	opts = opts or {}
	opts.look = it.look
	return KillEffects.playShape(it.look.shape or "cubes", pos, team, opts)
end

-- (tests) every actor gone now
function KillEffects.clear()
	for _, a in actors do
		a:destroy()
	end
	actors = {}
end

return KillEffects
