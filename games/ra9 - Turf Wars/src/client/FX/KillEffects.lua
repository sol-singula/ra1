--[[
Kill effects (Data/Cosmetics kind "effect"): what plays where someone falls, in the killer's look. Every one is its
own little animation, built here on this client from plain parts, billboards and the studio's shared sounds (no
uploads): colour, sparkle, secondary motion and a punchline.

  bursts     cubes, shards, pixels, ring, rise, spotlight (the originals, much juicier now), feathers (drifting down
             and swaying), sparkles (a twinkling rainbow spiral), blocks (rainbow blocks bouncing on the floor),
             firework (a rocket up, a burst of trails, crackles), bubbles (wobbling up and popping)
  funny      chicken (a poof, and they're a chicken running off, clucking, feathers flying), duck (a giant rubber duck
             pops up: squeak), balloons (floated away on a bunch of balloons), banana (a slip, a spin, a splat and
             stars), doge (a shiba pops up: "wow", "such kill"...), oof (a giant bouncing OOF), bonk (a giant mallet:
             BONK, stars), dance (a disco floor and ball, and they dance out)
  big        lightning (the sky goes dark, a jagged bolt, a scorch ring, sparks, thunder), web (web lines shoot in,
             wrap them up, and yank them away), blackhole (a swirling hole: everything sucked in and stretched),
             heaven (a golden beam, little wings, and up they go)

The ones with a body (KillEffects.usesBody) move a stand-in of whoever fell (opts.body: KillFxController hands over
a still copy of their character; else a mannequin). Each has a time scale (opts.scale) on top of Effects.timeScale
(the kill cam's slow motion), so the victim's kill cam can play the killer's effect slowed right down on them.
Light on phones and low graphics (fewer pieces), capped, and everything cleans up after itself.

  KillEffects.play(effectKey, pos, team, opts?) -> handle | nil
        opts = { body?, victimTeam?, dir?, scale? (1), fixed? (ignore Effects.timeScale) }
  KillEffects.playShape(shape, pos, team, opts?)   the same by shape name (tests, previews)
  KillEffects.usesBody(shape)   KillEffects.SHAPES   KillEffects.count()   KillEffects.pieces()   KillEffects.step(dt)
  KillEffects.claim(k) / KillEffects.claimed(k)   the victim's kill cam takes a kill's effect to play itself

A shop card's live preview (UI/ItemPreview) plays one inside a ViewportFrame: opts.parent (its WorldModel) holds the
pieces instead of workspace, opts.ground is the floor (no raycast), and opts.preview keeps it quiet and to itself (no
sounds, the lightning's darkness kept off Lighting as fx.grade for the preview to show, light piece counts, not
counted or stepped here: the caller steps the handle and destroys it). A viewport doesn't draw billboards, so every
word and sticker's BillboardGui is also listed in fx.boards for the preview to draw over the frame.
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
local LIFE = 2.8 -- seconds an effect lasts (its own time)
local MAX_PIECES = { high = 520, mid = 340, low = 150 }
local SPARKLE_TEX = "rbxasset://textures/particles/sparkles_main.dds"

KillEffects.SHAPES = {
	"cubes",
	"shards",
	"pixels",
	"ring",
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
local BODY = { balloons = true, banana = true, web = true, dance = true, blackhole = true, heaven = true }

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
		life = o.life or LIFE * rng:NextNumber(0.6, 0.95),
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
	gui.Enabled = not self.preview -- (a preview draws it itself)
	gui.Parent = anchor
	table.insert(self.boards, gui)
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
--   opts = { delay?, life? (LIFE - delay), wobble?, spin? (deg/s), float? (studs/s), swing?, pulse?, onTop? }
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
		gui.Enabled = not self.preview -- (a preview draws it itself)
		gui.Parent = anchor
		table.insert(self.boards, gui)
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
		local life = opts.life or math.max(0.6, LIFE - (opts.delay or 0) - 0.1)
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

-- a sound from the spot: one of the studio's shared clips, pitched (slower in slow motion)
function Actor:sound(clip, pitch, volume, delay)
	local function play()
		if not self.alive or self.preview then
			return -- (a shop preview plays silently)
		end
		pcall(function()
			local id = Constants.SOUNDS[clip] or clip
			local anchor = self.anchor
			local s = Instance.new("Sound")
			s.Name = "FxSound"
			s.SoundId = id
			s.Volume = volume or 0.6
			s.PlaybackSpeed = math.max(0.2, (pitch or 1) * math.max(0.35, self:speed()))
			s.RollOffMaxDistance = 220
			s.Parent = anchor
			s:Play()
		end)
	end
	if delay and delay > 0 then
		table.insert(self.timers, { at = delay, fn = play })
	else
		play()
	end
end

function Actor:after(t, fn)
	table.insert(self.timers, { at = t, fn = fn })
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
function Actor:bodyFade(alpha)
	if not self.body then
		return
	end
	pcall(function()
		for _, d in self.body:GetDescendants() do
			if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
				self.bodyAlpha[d] = self.bodyAlpha[d] or d.Transparency
				d.Transparency = self.bodyAlpha[d] + (1 - self.bodyAlpha[d]) * alpha
			elseif d:IsA("Decal") then
				d.Transparency = alpha
			end
		end
	end)
end
function Actor:bodyColor(color)
	if not self.body then
		return
	end
	pcall(function()
		for _, d in self.body:GetDescendants() do
			if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
				d.Color = color
			end
		end
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
local S = {}

local function colorFn(fx, token, i)
	if token == "rainbow" then
		return rainbow(i, 0)
	end
	return Cosmetics.color(token, fx.team)
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
	local t0 = fx.age
	table.insert(fx.ticks, function(_, t)
		local u = clamp01((t - t0) / 0.45)
		local s = 1 + (r or 6) * outCubic(u)
		ball.Size = Vector3.one * (1 + 3 * outCubic(u))
		ball.Transparency = 0.1 + 0.9 * u
		ring.Size = Vector3.new(0.25, s * 2, s * 2)
		ring.Transparency = 0.2 + 0.8 * u
	end)
end

-- the originals, juicier ---------------------------------------------------------------------------------------
S.cubes = function(fx)
	flash(fx, fx.color, 5)
	for i = 1, fx.n do
		local c = i % 3 == 0 and WHITE or colorFn(fx, fx.look.color, i)
		local p = fx:part(Vector3.one * rng:NextNumber(0.45, 0.85), c, { cf = CFrame.new(fx.at) })
		fx:bit(p, randomDir(0.1) * rng:NextNumber(14, 26) + UP * 6, {
			grav = 1,
			drag = 0.8,
			spin = rng:NextNumber(4, 12),
			floor = fx.pos.Y + 0.3,
		})
	end
	fx:sparkleBurst(fx.at, fx.color, 24, 16)
end

S.shards = function(fx)
	flash(fx, fx.color, 6)
	for i = 1, fx.n do
		local c = i % 3 == 0 and WHITE or colorFn(fx, fx.look.color, i)
		local p = fx:part(Vector3.new(0.14, 0.14, rng:NextNumber(0.8, 1.6)), c, { cf = CFrame.new(fx.at) })
		fx:bit(
			p,
			randomDir(0) * rng:NextNumber(20, 34),
			{ grav = 0.6, drag = 1.4, face = true, floor = fx.pos.Y + 0.1 }
		)
	end
	fx:sparkleBurst(fx.at, WHITE, 18, 20)
end

S.pixels = function(fx)
	for i = 1, fx.n do
		local c = i % 4 == 0 and WHITE or colorFn(fx, fx.look.color, i)
		local p = fx:part(Vector3.new(0.5, 0.5, 0.08), c, { cf = CFrame.new(fx.at + randomDir() * 1.2) })
		fx:bit(p, randomDir(0.3) * 3 + UP * rng:NextNumber(3, 7), { drag = 1.2, spin = 2, twinkle = 22 })
	end
end

S.ring = function(fx)
	for wave = 0, 1 do
		fx:after(wave * 0.18, function()
			for i = 1, fx.n do
				local a = i / fx.n * math.pi * 2
				local dir = Vector3.new(math.cos(a), 0, math.sin(a))
				local c = (i + wave) % 2 == 0 and fx.color or WHITE
				local p =
					fx:part(Vector3.new(0.6, 0.3, 0.6), c, { cf = CFrame.new(fx.at + dir * 0.5 + UP * wave * 0.6) })
				fx:bit(p, dir * (18 - wave * 5), { drag = 1.6, life = 1.1 })
			end
		end)
	end
	flash(fx, fx.color, 7)
end

S.rise = function(fx)
	for i = 1, fx.n do
		local p = fx:part(Vector3.one * 0.55, i % 2 == 0 and WHITE or fx.color, {
			cf = CFrame.new(fx.pos + Vector3.new(rng:NextNumber(-1, 1), i * 0.15, rng:NextNumber(-1, 1))),
		})
		fx:bit(p, UP * (6 + i * 0.6), { drag = 0.2, spin = 3, twinkle = 10, life = 1.8 })
	end
	fx:sparkleBurst(fx.at + UP * 2, WHITE, 20, 6)
end

S.spotlight = function(fx)
	local beam = fx:part(Vector3.new(60, 3, 3), fx.color, {
		cylinder = true,
		transparency = 0.45,
		cf = CFrame.new(fx.pos + UP * 30) * CFrame.Angles(0, 0, math.rad(90)),
	})
	table.insert(fx.ticks, function(_, t)
		beam.Transparency = 0.45 + 0.5 * clamp01((t - 1.6) / 1)
		beam.Size = Vector3.new(60, 3 + math.sin(t * 9) * 0.3, 3 + math.sin(t * 9) * 0.3)
	end)
	for i = 1, fx.n do
		local a = i / fx.n * math.pi * 2
		local p = fx:part(Vector3.new(0.4, 0.2, 0.4), i % 2 == 0 and WHITE or INK, {
			cf = CFrame.new(fx.pos + Vector3.new(math.cos(a) * 2, 0.2, math.sin(a) * 2)),
		})
		fx:bit(p, Vector3.new(math.cos(a), 0, math.sin(a)) * 4, { drag = 1, life = 2 })
	end
	fx:sparkleBurst(fx.at, GOLD, 30, 8)
end

-- bursts -------------------------------------------------------------------------------------------------------------
S.feathers = function(fx)
	poof(fx, fx.at, 6)
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
			life = rng:NextNumber(2.2, 2.7),
			floor = fx.pos.Y + 0.05,
			bounce = 0,
		})
	end
end

S.sparkles = function(fx)
	local t0 = fx.age
	for i = 1, fx.n do
		local p = fx:part(Vector3.one * rng:NextNumber(0.25, 0.5), rainbow(i), { ball = true })
		local a = i / fx.n * math.pi * 8
		local r0 = 0.3 + i / fx.n * 0.8
		local b = fx:bit(p, Vector3.zero, { twinkle = rng:NextNumber(14, 26), life = rng:NextNumber(1.8, 2.6) })
		b.color = function(age)
			return rainbow(i, age)
		end
		table.insert(fx.ticks, function(_, t)
			local u = t - t0
			local r = r0 + u * 4.5
			local aa = a + u * 3
			b.pos = fx.at + Vector3.new(math.cos(aa) * r, u * 3 - 0.6 + math.sin(i) * 0.6, math.sin(aa) * r)
		end)
	end
	fx:sparkleBurst(fx.at, WHITE, 40, 18)
	flash(fx, rainbow(0), 4)
end

S.blocks = function(fx)
	for i = 1, fx.n do
		local s = rng:NextNumber(0.6, 1.1)
		local p = fx:part(Vector3.one * s, rainbow(i), {
			material = Enum.Material.SmoothPlastic,
			cf = CFrame.new(fx.at + randomDir() * 0.4) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0),
		})
		fx:bit(p, randomDir(0.3) * rng:NextNumber(10, 20) + UP * 12, {
			grav = 1.1,
			drag = 0.3,
			spin = rng:NextNumber(4, 10),
			floor = fx.pos.Y + s / 2,
			bounce = 0.55,
			shrink = true,
		})
	end
	poof(fx, fx.at, 5, WHITE, 0.8)
	fx:sound("pop", 1.2, 0.5)
end

S.firework = function(fx)
	local rocket = fx:part(Vector3.new(0.3, 1, 0.3), WHITE, { cf = CFrame.new(fx.pos + UP) })
	local top = fx.pos + UP * 14
	local t0 = fx.age
	fx:sound("rocket", 1.4, 0.4)
	table.insert(fx.ticks, function(_, t)
		local u = clamp01((t - t0) / 0.5)
		rocket.CFrame = CFrame.new((fx.pos + UP):Lerp(top, outCubic(u)))
		rocket.Transparency = u >= 1 and 1 or 0
	end)
	-- the trail up
	for i = 1, 6 do
		fx:after(i * 0.07, function()
			local p = fx:part(Vector3.one * 0.25, ORANGE, { ball = true, cf = rocket.CFrame })
			fx:bit(p, randomDir() * 2, { grav = 0.2, life = 0.5 })
		end)
	end
	fx:after(0.5, function()
		fx:sound("boom", 1.6, 0.5)
		for i = 1, fx.n do
			local c = rainbow(math.floor(i / 6))
			local p = fx:part(Vector3.new(0.18, 0.18, 0.9), c, { cf = CFrame.new(top) })
			fx:bit(p, randomDir() * rng:NextNumber(16, 24), { grav = 0.25, drag = 1.1, face = true, life = 1.5 })
		end
		fx:sparkleBurst(top, GOLD, 40, 22)
		local ball = fx:part(Vector3.one * 3, WHITE, { ball = true, transparency = 0.2, cf = CFrame.new(top) })
		fx:bit(ball, Vector3.zero, { life = 0.3 })
		-- the crackles after
		for j = 1, 5 do
			fx:after(0.25 + j * 0.12, function()
				local at = top + randomDir() * rng:NextNumber(3, 6)
				fx:sparkleBurst(at, rainbow(j), 8, 6)
				fx:sound("tick", 2 + j * 0.1, 0.25)
			end)
		end
	end)
end

S.bubbles = function(fx)
	for i = 1, fx.n do
		local s = rng:NextNumber(0.6, 1.6)
		local p = fx:part(Vector3.one * s, i % 3 == 0 and Color3.fromRGB(255, 160, 220) or fx.color, {
			ball = true,
			material = Enum.Material.Glass,
			transparency = 0.45,
			cf = CFrame.new(fx.at + randomDir() * 0.8),
		})
		local b = fx:bit(p, randomDir(0) * 4 + UP * rng:NextNumber(2.5, 5), {
			drag = 0.6,
			sway = rng:NextNumber(0.5, 1),
			life = rng:NextNumber(1.6, 2.6),
		})
		b.shrink = false
		b.onDie = function(bb)
			-- pop: a ring of droplets
			if fx.alive then
				for _ = 1, 4 do
					local d = fx:part(Vector3.one * 0.15, WHITE, { ball = true, cf = CFrame.new(bb.pos) })
					fx:bit(d, randomDir() * 6, { grav = 0.4, life = 0.3 })
				end
			end
		end
	end
	fx:sound("pop", 1.5, 0.4)
	fx:sound("pop", 1.8, 0.3, 0.6)
	fx:sound("pop", 1.3, 0.3, 1.2)
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
	local wl = add("WingL", Vector3.new(0.2, 0.9, 1.3), Color3.fromRGB(235, 235, 235), CFrame.new(-0.9, 1.4, 0), m)
	local wr = add("WingR", Vector3.new(0.2, 0.9, 1.3), Color3.fromRGB(235, 235, 235), CFrame.new(0.9, 1.4, 0), m)
	local ll = add("LegL", Vector3.new(0.18, 0.7, 0.18), ORANGE, CFrame.new(-0.35, 0.35, 0), m)
	local lr = add("LegR", Vector3.new(0.18, 0.7, 0.18), ORANGE, CFrame.new(0.35, 0.35, 0), m)
	return {
		parts = parts,
		wings = { wl, wr },
		legs = { ll, lr },
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
				local o = off.Position * scale * s
				e.part.CFrame = cf * CFrame.new(o) * off.Rotation
				e.part.Size = e.size * s
			end
		end,
	}
end

S.chicken = function(fx)
	fx:sticker("chicken", Vector3.new(0, 5, 0), 5, { delay = 0.2, wobble = true, float = 0.8 })
	fx:sticker("bawk", Vector3.new(2.5, 8, 0), 5, { delay = 0.45, wobble = true, float = 0.6 })
	poof(fx, fx.at, 10, WHITE, 1.3)
	fx:sound("pop", 1.1, 0.6)
	for i = 1, math.floor(10 * fx.mult) do
		local p = fx:part(Vector3.new(0.08, 0.3, 0.9), i % 4 == 0 and Color3.fromRGB(230, 30, 40) or WHITE, {
			wedge = true,
			material = Enum.Material.SmoothPlastic,
			cf = CFrame.new(fx.at),
		})
		fx:bit(p, randomDir(0.2) * 12 + UP * 6, { grav = 0.05, drag = 2.2, spin = 3, sway = 1, life = 2.4 })
	end
	local ch = chickenModel(fx, 1)
	local run = Vector3.new(fx.dir.X, 0, fx.dir.Z)
	run = run.Magnitude > 0.1 and run.Unit or Vector3.new(1, 0, 0)
	local start = fx.pos
	for _, e in ch.parts do
		e.part.Transparency = 1
	end
	local t0 = fx.age
	-- clucks as it runs
	for j = 0, 4 do
		fx:sound("pop", 2.2 + (j % 2) * 0.3, 0.45, 0.35 + j * 0.38)
	end
	table.insert(fx.ticks, function(_, t)
		local u = t - t0
		local appear = outBack(u / 0.3)
		for _, e in ch.parts do
			e.part.Transparency = u < 0.05 and 1 or (u > LIFE - 0.4 and clamp01((u - (LIFE - 0.4)) / 0.4) or 0)
		end
		-- a beat of looking about, then off it goes, hopping
		local go = math.max(0, u - 0.55)
		local dist = go * 9 + go * go * 3
		local hop = math.abs(math.sin(go * 14)) * 0.5 * (go > 0 and 1 or 0)
		local turn = u < 0.55 and math.sin(u * 18) * 0.6 or 0
		local cf = CFrame.lookAt(start + run * dist + UP * hop, start + run * (dist + 1) + UP * hop)
			* CFrame.Angles(0, turn, 0)
		ch.pose(cf, u, go > 0 and 0.9 or 0.4, go > 0 and 0.8 or 0, math.max(0.05, appear))
		-- a feather now and then
		if go > 0 and fx.alive and rng:NextNumber() < 0.12 * fx.mult then
			local p = fx:part(Vector3.new(0.06, 0.25, 0.7), WHITE, {
				wedge = true,
				material = Enum.Material.SmoothPlastic,
				cf = cf * CFrame.new(0, 1.5, 0.8),
			})
			fx:bit(p, UP * 3 + randomDir() * 2, { grav = 0.05, drag = 2, spin = 3, sway = 1, life = 1.4 })
		end
	end)
	local t = fx:text("BAWK!", UP * 4, YELLOW, { w = 5, h = 2 })
	table.insert(fx.ticks, function(_, now)
		local u = now - t.born
		t.label.Rotation = math.sin(u * 20) * 8
		t.gui.Size = UDim2.fromScale(5 * outBack(u / 0.25), 2 * outBack(u / 0.25))
		t.label.TextTransparency = clamp01((u - 1.2) / 0.5)
		t.label.TextStrokeTransparency = t.label.TextTransparency
	end)
end

S.duck = function(fx)
	fx:sticker("duck", Vector3.new(0, 6, 0), 7, { delay = 0.1, wobble = true, pulse = true })
	local body = fx:part(Vector3.new(3.4, 2.6, 4.2), YELLOW, { ball = true, material = Enum.Material.SmoothPlastic })
	local head = fx:part(Vector3.new(2.2, 2.2, 2.2), YELLOW, { ball = true, material = Enum.Material.SmoothPlastic })
	local beak = fx:part(Vector3.new(1.2, 0.5, 1), ORANGE, { material = Enum.Material.SmoothPlastic })
	local eyeL = fx:part(Vector3.one * 0.35, INK, { ball = true, material = Enum.Material.SmoothPlastic })
	local eyeR = fx:part(Vector3.one * 0.35, INK, { ball = true, material = Enum.Material.SmoothPlastic })
	local tail = fx:part(Vector3.new(1, 1.2, 0.6), YELLOW, { material = Enum.Material.SmoothPlastic })
	local face = Vector3.new(-fx.dir.X, 0, -fx.dir.Z)
	face = face.Magnitude > 0.1 and face.Unit or Vector3.new(0, 0, -1)
	local base = CFrame.lookAt(fx.pos, fx.pos + face)
	local t0 = fx.age
	fx:sound("ping", 2.6, 0.7, 0.12)
	fx:sound("ping", 2.9, 0.6, 0.7)
	fx:sound("ping", 2.6, 0.6, 1.3)
	poof(fx, fx.at, 6, WHITE, 1)
	table.insert(fx.ticks, function(_, t)
		local u = t - t0
		local s = outElastic(u / 0.6) * (u > LIFE - 0.5 and (1 - clamp01((u - (LIFE - 0.5)) / 0.5)) or 1)
		local squash = 1 + math.sin(u * 16) * 0.12 * (1 - clamp01(u / 1.5))
		local hop = bounce(u / 2) * 3
		local cf = base * CFrame.new(0, hop, 0) * CFrame.Angles(0, math.sin(u * 4) * 0.25, math.sin(u * 7) * 0.08)
		local k = math.max(0.02, s)
		body.Size = Vector3.new(3.4 * squash, 2.6 / squash, 4.2) * k
		body.CFrame = cf * CFrame.new(0, 1.3 * k, 0)
		head.Size = Vector3.one * 2.2 * k
		head.CFrame = cf * CFrame.new(0, 3.1 * k, -1.2 * k)
		beak.Size = Vector3.new(1.2, 0.5, 1) * k
		beak.CFrame = cf * CFrame.new(0, 2.9 * k, -2.5 * k)
		eyeL.Size, eyeR.Size = Vector3.one * 0.35 * k, Vector3.one * 0.35 * k
		eyeL.CFrame = cf * CFrame.new(-0.6 * k, 3.5 * k, -2.05 * k)
		eyeR.CFrame = cf * CFrame.new(0.6 * k, 3.5 * k, -2.05 * k)
		tail.Size = Vector3.new(1, 1.2, 0.6) * k
		tail.CFrame = cf * CFrame.new(0, 2.2 * k, 2.1 * k) * CFrame.Angles(math.rad(-30), 0, 0)
	end)
	local w = fx:text("SQUEAK!", UP * 6.5, WHITE, { w = 6, h = 2, stroke = ORANGE })
	table.insert(fx.ticks, function(_, now)
		local u = now - w.born
		w.gui.Size = UDim2.fromScale(6 * outBack(u / 0.3), 2 * outBack(u / 0.3))
		w.label.TextTransparency = clamp01((u - 1.4) / 0.6)
		w.label.TextStrokeTransparency = w.label.TextTransparency
	end)
end

S.balloons = function(fx)
	local n = math.max(4, math.floor(fx.look.count * fx.mult + 0.5))
	local balloons = {}
	for i = 1, n do
		local a = i / n * math.pi * 2
		local off = Vector3.new(math.cos(a) * 1.4, 5 + (i % 3) * 0.9, math.sin(a) * 1.4)
		local b = fx:part(Vector3.new(1.4, 1.7, 1.4), rainbow(i), {
			ball = true,
			material = Enum.Material.SmoothPlastic,
		})
		local s = fx:part(Vector3.new(0.05, off.Y - 1.2, 0.05), WHITE, { material = Enum.Material.SmoothPlastic })
		table.insert(balloons, { b = b, s = s, off = off, phase = i })
	end
	local start = fx.body and fx.body:GetPivot() or CFrame.new(fx.at)
	local t0 = fx.age
	fx:sound("whistle", 1.6, 0.4, 0.3)
	table.insert(fx.ticks, function(_, t)
		local u = t - t0
		local lift = u < 0.4 and 0 or (u - 0.4) ^ 1.6 * 3.2
		local sway = math.sin(u * 2.2) * 0.6
		local top = start.Position + UP * (lift + 2.2) + Vector3.new(sway, 0, 0)
		fx:bodyPivot(start * CFrame.new(0, lift, 0) * CFrame.Angles(0, u * 0.8, math.sin(u * 2.2) * 0.15))
		local grow = outBack(u / 0.35)
		for _, e in balloons do
			local bob = math.sin(u * 3 + e.phase) * 0.25
			local p = top + e.off * Vector3.new(1, 0, 1) + UP * (e.off.Y - 2.2 + bob)
			e.b.Size = Vector3.new(1.4, 1.7, 1.4) * math.max(0.05, grow)
			e.b.CFrame = CFrame.new(p)
			local mid = (top + p) / 2
			e.s.Size = Vector3.new(0.05, (p - top).Magnitude, 0.05)
			e.s.CFrame = CFrame.lookAt(mid, p) * CFrame.Angles(math.rad(90), 0, 0)
		end
		if u > LIFE - 0.5 then
			fx:bodyFade(clamp01((u - (LIFE - 0.5)) / 0.5))
		end
	end)
	-- a bye-bye wave of sparkles
	fx:sparkleBurst(fx.at, WHITE, 16, 6)
end

S.banana = function(fx)
	fx:sticker("banana", Vector3.new(0, 2.5, 0), 3.5, { life = 1, spin = 200 })
	fx:sticker("splat", Vector3.new(0, 6.5, 0), 6, { delay = 0.9, wobble = true })
	local peel = fx:part(Vector3.new(1.4, 0.25, 0.7), YELLOW, { material = Enum.Material.SmoothPlastic })
	local tip =
		fx:part(Vector3.new(0.3, 0.2, 0.3), Color3.fromRGB(90, 60, 20), { material = Enum.Material.SmoothPlastic })
	-- (the peel's three flaps, splayed out)
	for i = 1, 3 do
		local a = (i / 3) * math.pi * 2
		fx:part(Vector3.new(0.9, 0.12, 0.4), YELLOW, {
			material = Enum.Material.SmoothPlastic,
			cf = CFrame.new(fx.pos + UP * 0.15) * CFrame.Angles(0, a, 0) * CFrame.new(0.7, 0, 0),
		})
	end
	peel.CFrame = CFrame.new(fx.pos + UP * 0.15)
	tip.CFrame = CFrame.new(fx.pos + UP * 0.15 + Vector3.new(-0.8, 0, 0))
	local start = fx.body and fx.body:GetPivot() or CFrame.new(fx.at)
	local back = Vector3.new(fx.dir.X, 0, fx.dir.Z)
	back = back.Magnitude > 0.1 and back.Unit or Vector3.new(1, 0, 0)
	local side = back:Cross(UP).Unit
	local t0 = fx.age
	local splatted = false
	fx:sound("whistle", 2.2, 0.45, 0.05)
	table.insert(fx.ticks, function(_, t)
		local u = t - t0
		-- feet out, a full flip backwards through the air, flat on the floor
		local air = clamp01(u / 0.9)
		local h = math.sin(air * math.pi) * 3.2
		local spin = outCubic(air) * math.pi * 2.5
		local lie = air >= 1 and math.rad(90) or 0
		local p = start.Position + back * (outCubic(air) * 3) + UP * (h - (air >= 1 and 1.3 or 0))
		fx:bodyPivot(CFrame.new(p) * CFrame.fromAxisAngle(side, spin + lie) * start.Rotation)
		if air >= 1 and not splatted then
			splatted = true
			fx:sound("thud", 0.8, 0.7)
			poof(fx, p - UP * 0.6, 6, WHITE, 0.8)
			local w = fx:text("SPLAT!", UP * 3 + back * 3, YELLOW, { w = 6, h = 2.2 })
			w.born = t
			table.insert(fx.ticks, function(_, now)
				local v = now - w.born
				w.gui.Size = UDim2.fromScale(6 * outBack(v / 0.25), 2.2 * outBack(v / 0.25))
				w.label.TextTransparency = clamp01((v - 1) / 0.5)
				w.label.TextStrokeTransparency = w.label.TextTransparency
			end)
			-- stars circling over their head
			for i = 1, 4 do
				local s = fx:text("★", Vector3.zero, YELLOW, { w = 1.2, h = 1.2 })
				table.insert(fx.ticks, function(_, now)
					local v = now - t
					local a = v * 5 + i / 4 * math.pi * 2
					s.anchor.CFrame =
						CFrame.new(p + back * 0.9 + UP * 1 + Vector3.new(math.cos(a) * 1.2, 0, math.sin(a) * 1.2))
				end)
			end
		end
		if u > LIFE - 0.5 then
			fx:bodyFade(clamp01((u - (LIFE - 0.5)) / 0.5))
		end
	end)
end

-- the big ones ------------------------------------------------------------------------------------------------------
S.lightning = function(fx)
	fx:sticker("bolt", Vector3.new(0, 9, 0), 14, { delay = 0.12, life = 0.7, pulse = true })
	fx:sticker("zap", Vector3.new(0, 7, 0), 6.5, { delay = 0.35, wobble = true, float = 0.5 })
	local blue = Cosmetics.color("electric", fx.team)
	-- the sky goes dark for a beat (on this client)
	pcall(function()
		local Lighting = game:GetService("Lighting")
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "TW_Lightning"
		cc.Brightness = -0.35
		cc.Contrast = 0.4
		cc.Saturation = -0.4
		cc.TintColor = Color3.fromRGB(190, 210, 255)
		-- (a shop preview keeps it to itself: the preview shows it on its own frame)
		cc.Parent = fx.preview and fx.folder or Lighting
		fx.grade = cc
		table.insert(fx.parts, cc)
		local t0 = fx.age
		table.insert(fx.ticks, function(_, t)
			local u = t - t0
			-- dark, then the bolt's white flash, then back
			if u < 0.25 then
				cc.Brightness = -0.35 * (u / 0.25)
			elseif u < 0.4 then
				cc.Brightness = 0.6
			else
				cc.Brightness = 0.6 * (1 - clamp01((u - 0.4) / 0.8))
				cc.Contrast = 0.4 * (1 - clamp01((u - 0.4) / 0.8))
			end
		end)
	end)
	local function bolt(from, to, width, color, life)
		local pts = { from }
		local segs = 9
		for i = 1, segs - 1 do
			local p = from:Lerp(to, i / segs)
			table.insert(pts, p + Vector3.new(rng:NextNumber(-2.2, 2.2), 0, rng:NextNumber(-2.2, 2.2)))
		end
		table.insert(pts, to)
		local made = {}
		for i = 1, #pts - 1 do
			local a, b = pts[i], pts[i + 1]
			local p = fx:part(Vector3.new(width, width, (b - a).Magnitude + width), color, {
				cf = CFrame.lookAt((a + b) / 2, b),
			})
			table.insert(made, p)
			fx:bit(p, Vector3.zero, { life = life, shrink = false })
			-- a branch now and then
			if i > 2 and i < #pts - 2 and rng:NextNumber() < 0.4 then
				local q = b + Vector3.new(rng:NextNumber(-5, 5), rng:NextNumber(-4, -1), rng:NextNumber(-5, 5))
				local br = fx:part(Vector3.new(width * 0.5, width * 0.5, (q - b).Magnitude), color, {
					cf = CFrame.lookAt((b + q) / 2, q),
				})
				fx:bit(br, Vector3.zero, { life = life * 0.7, shrink = false })
			end
		end
		return made
	end
	fx:after(0.25, function()
		local sky = fx.pos + UP * 90 + Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6))
		local core = bolt(sky, fx.pos, 0.55, WHITE, 0.45)
		bolt(sky, fx.pos, 1.2, blue, 0.5)
		-- the flicker
		table.insert(fx.ticks, function(_, t)
			local on = math.floor(t * 30) % 3 ~= 0
			for _, p in core do
				if p.Parent then
					p.Transparency = on and 0 or 0.6
				end
			end
		end)
		fx:sound("boom", 0.55, 0.9)
		fx:sound("glass", 0.6, 0.4)
		flash(fx, blue, 9)
		fx:sparkleBurst(fx.at, blue, 40, 26)
		for _ = 1, fx.n do
			local p = fx:part(
				Vector3.new(0.1, 0.1, 1.2),
				rng:NextNumber() < 0.5 and blue or WHITE,
				{ cf = CFrame.new(fx.pos + UP * 0.5) }
			)
			fx:bit(
				p,
				randomDir(0.1) * rng:NextNumber(20, 36),
				{ grav = 0.7, drag = 1.2, face = true, life = 0.7, floor = fx.pos.Y + 0.1 }
			)
		end
		-- the scorch on the floor
		local scorch = fx:part(Vector3.new(0.1, 7, 7), INK, {
			cylinder = true,
			material = Enum.Material.SmoothPlastic,
			transparency = 0.15,
			cf = CFrame.new(fx.pos + UP * 0.06) * CFrame.Angles(0, 0, math.rad(90)),
		})
		local glow = fx:part(Vector3.new(0.12, 3, 3), Color3.fromRGB(255, 140, 40), {
			cylinder = true,
			transparency = 0.2,
			cf = CFrame.new(fx.pos + UP * 0.08) * CFrame.Angles(0, 0, math.rad(90)),
		})
		local t1 = fx.age
		table.insert(fx.ticks, function(_, t)
			local u = clamp01((t - t1) / (LIFE - 0.4))
			scorch.Transparency = 0.15 + 0.85 * u * u
			glow.Transparency = 0.2 + 0.8 * clamp01(u * 2)
		end)
		-- smoke rising off the spot
		for _ = 1, math.floor(6 * fx.mult) do
			local s = fx:part(Vector3.one * rng:NextNumber(1, 2), Color3.fromRGB(60, 60, 70), {
				ball = true,
				material = Enum.Material.SmoothPlastic,
				transparency = 0.4,
				cf = CFrame.new(fx.pos + randomDir(0) * 1.2),
			})
			fx:bit(s, UP * rng:NextNumber(3, 6) + randomDir(0), { drag = 0.8, life = 1.8, shrink = false })
		end
		fx:bodyColor(INK)
	end)
end

-- the shiba: a blocky head (ears, muzzle, eyes, nose) and a few words in the meme's colours
S.doge = function(fx)
	local tan = Color3.fromRGB(226, 170, 90)
	local cream = Color3.fromRGB(250, 236, 205)
	local m = { material = Enum.Material.SmoothPlastic }
	local pieces = {
		{ fx:part(Vector3.new(3, 2.6, 2.6), tan, m), CFrame.new(0, 0, 0) },
		{ fx:part(Vector3.new(1.9, 1.1, 1.3), cream, m), CFrame.new(0, -0.55, -1.5) },
		{ fx:part(Vector3.new(0.6, 0.45, 0.4), INK, m), CFrame.new(0, -0.2, -2.15) },
		{ fx:part(Vector3.new(0.35, 0.35, 0.2), INK, m), CFrame.new(-0.65, 0.45, -1.32) },
		{ fx:part(Vector3.new(0.35, 0.35, 0.2), INK, m), CFrame.new(0.65, 0.45, -1.32) },
		{
			fx:part(Vector3.new(0.8, 1.2, 0.5), tan, { wedge = true, material = Enum.Material.SmoothPlastic }),
			CFrame.new(-1, 1.7, 0),
		},
		{
			fx:part(Vector3.new(0.8, 1.2, 0.5), tan, { wedge = true, material = Enum.Material.SmoothPlastic }),
			CFrame.new(1, 1.7, 0),
		},
		{ fx:part(Vector3.new(2.2, 0.5, 0.2), cream, m), CFrame.new(0, -1.15, -1.32) },
	}
	local face = Vector3.new(-fx.dir.X, 0, -fx.dir.Z)
	face = face.Magnitude > 0.1 and face.Unit or Vector3.new(0, 0, -1)
	local base = CFrame.lookAt(fx.pos + UP * 2.5, fx.pos + UP * 2.5 + face)
	local t0 = fx.age
	poof(fx, fx.at, 6, cream, 1)
	fx:sound("pop", 1.3, 0.6)
	table.insert(fx.ticks, function(_, t)
		local u = t - t0
		local s = math.max(0.02, outBack(u / 0.4)) * (u > LIFE - 0.4 and (1 - clamp01((u - (LIFE - 0.4)) / 0.4)) or 1)
		local tilt = math.sin(u * 3) * 0.25 -- (the head tilt)
		local cf = base * CFrame.new(0, math.sin(u * 5) * 0.15, 0) * CFrame.Angles(0, 0, tilt)
		for _, e in pieces do
			e[3] = e[3] or e[1].Size
			e[1].CFrame = cf * CFrame.new(e[2].Position * s) * e[2].Rotation
			e[1].Size = e[3] * s
			e[1].Transparency = s < 0.05 and 1 or 0
		end
	end)
	-- the meme itself: the shiba sticker, big, tilting, and the words as stickers popping round it
	fx:sticker("doge", Vector3.new(0, 7.5, 0), 8, { delay = 0.15, wobble = true, pulse = true })
	for i = 1, 4 do
		local a = (i - 1) * math.pi / 2 + 0.6
		fx:sticker(
			"doge_word" .. i,
			Vector3.new(math.cos(a) * 6, 6 + math.sin(a) * 3.5, math.sin(a) * 2),
			5.5,
			{ delay = 0.35 + i * 0.3, wobble = true, float = 0.35 }
		)
	end
	local words = { "so oof", "amaze", "wow", "such kill", "very rekt", "much skill" }
	local colors = {
		Color3.fromRGB(255, 60, 200),
		Color3.fromRGB(60, 220, 255),
		Color3.fromRGB(120, 255, 80),
		Color3.fromRGB(255, 230, 40),
		Color3.fromRGB(255, 120, 40),
		Color3.fromRGB(170, 120, 255),
	}
	local n = 2 -- (the other words are stickers now)
	for i = 1, n do
		fx:after(1.7 + i * 0.3, function()
			local off = Vector3.new(rng:NextNumber(-5, 5), rng:NextNumber(3, 7), rng:NextNumber(-3, 3))
			local w = fx:text(words[i], off, colors[i], {
				w = 6,
				h = 2,
				font = Enum.Font.Cartoon,
				stroke = WHITE,
				rotation = rng:NextNumber(-18, 18),
			})
			w.label.TextStrokeTransparency = 1
			fx:sound("tick", 1.6 + i * 0.12, 0.35)
			table.insert(fx.ticks, function(_, now)
				local v = now - w.born
				w.gui.Size = UDim2.fromScale(6 * outBack(v / 0.25), 2 * outBack(v / 0.25))
				w.anchor.CFrame = CFrame.new(fx.at + w.base + UP * v * 0.4)
				w.label.TextTransparency = clamp01((v - 1.3) / 0.5)
			end)
		end)
	end
end

S.web = function(fx)
	fx:sticker("web", Vector3.new(0, 3, 0), 9, { delay = 0.15, spin = 25, onTop = false })
	fx:sticker("thwip", Vector3.new(0, 8, 0), 7, { delay = 0.1, wobble = true, float = 0.5 })
	local strands = {}
	local start = fx.body and fx.body:GetPivot() or CFrame.new(fx.at)
	local center = start.Position
	local anchors = {}
	for i = 1, math.max(4, math.floor((fx.look.count or 12) * fx.mult / 2)) do
		local a = i / 6 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		table.insert(anchors, center + Vector3.new(math.cos(a) * 14, rng:NextNumber(4, 12), math.sin(a) * 14))
	end
	for _, a in anchors do
		table.insert(strands, {
			from = a,
			part = fx:part(Vector3.new(0.12, 0.12, 0.1), WHITE, { material = Enum.Material.SmoothPlastic }),
		})
	end
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
	local pull = (center + UP * 60 - fx.dir * 30)
	local t0 = fx.age
	fx:sound("whistle", 2.6, 0.4)
	fx:sound("slash", 1.6, 0.35, 0.3)
	table.insert(fx.ticks, function(_, t)
		local u = t - t0
		-- the strands shoot in (0 .. 0.35), wrap (0.35 .. 0.9), then the yank (0.9 ..)
		local shoot = outCubic(u / 0.35)
		local yank = u > 1 and (u - 1) ^ 2 * 2.2 or 0
		local yankDir = (pull - center).Unit
		local at = center + yankDir * yank * 20
		for _, s in strands do
			local tipPos = s.from:Lerp(at, shoot)
			local len = (tipPos - s.from).Magnitude
			s.part.Size = Vector3.new(0.12, 0.12, math.max(0.1, len))
			s.part.CFrame = CFrame.lookAt((s.from + tipPos) / 2, tipPos)
			s.part.Transparency = u > 1 and clamp01((u - 1) / 0.4) or 0
		end
		for i, w in wraps do
			local k = clamp01((u - 0.35 - i * 0.07) / 0.15)
			w.part.Transparency = 1 - k * 0.85
			w.part.CFrame = CFrame.new(at + UP * w.y) * CFrame.Angles(w.tilt, u * 2, math.rad(90))
		end
		fx:bodyPivot(start * CFrame.new(start:PointToObjectSpace(at)) * CFrame.Angles(0, u > 1 and (u - 1) * 6 or 0, 0))
		-- the line up to the sky as it's yanked
		if u > 0.9 and not fx.line then
			fx.line = fx:part(Vector3.new(0.18, 0.18, 1), WHITE, { material = Enum.Material.SmoothPlastic })
			fx:sound("whistle", 1.4, 0.5)
		end
		if fx.line then
			local top = pull
			fx.line.Size = Vector3.new(0.18, 0.18, (top - at).Magnitude)
			fx.line.CFrame = CFrame.lookAt((top + at) / 2, top)
		end
		if u > LIFE - 0.6 then
			fx:bodyFade(clamp01((u - (LIFE - 0.6)) / 0.6))
		end
	end)
	local w = fx:text("THWIP!", UP * 4.5, WHITE, { w = 6, h = 2, stroke = Color3.fromRGB(200, 30, 40) })
	table.insert(fx.ticks, function(_, now)
		local v = now - w.born
		w.gui.Size = UDim2.fromScale(6 * outBack(v / 0.25), 2 * outBack(v / 0.25))
		w.label.TextTransparency = clamp01((v - 1) / 0.5)
		w.label.TextStrokeTransparency = w.label.TextTransparency
	end)
end

S.oof = function(fx)
	fx:sticker("oof", Vector3.new(0, 6, 0), 9, { delay = 0.05, wobble = true, pulse = true })
	local w = fx:text("OOF", UP * 3.5, YELLOW, { w = 10, h = 4.5, font = Enum.Font.LuckiestGuy })
	fx:sound("thud", 0.7, 0.8)
	fx:sound("pop", 0.6, 0.5, 0.35)
	table.insert(fx.ticks, function(_, now)
		local v = now - w.born
		local s = outElastic(v / 0.7)
		local squash = 1 + math.sin(v * 18) * 0.25 * (1 - clamp01(v / 1.2))
		w.gui.Size = UDim2.fromScale(10 * s * squash, 4.5 * s / squash)
		w.anchor.CFrame = CFrame.new(fx.at + UP * (3.5 + bounce(v / 1.6) * 2.5))
		w.label.Rotation = math.sin(v * 9) * 6
		w.label.TextTransparency = clamp01((v - 1.9) / 0.6)
		w.label.TextStrokeTransparency = w.label.TextTransparency
	end)
	for i = 1, math.floor(10 * fx.mult) do
		local p = fx:part(Vector3.new(0.5, 0.5, 0.15), i % 2 == 0 and YELLOW or ORANGE, { cf = CFrame.new(fx.at) })
		fx:bit(p, randomDir(0.2) * rng:NextNumber(10, 18), { grav = 0.6, drag = 1, spin = 6, life = 1.2 })
	end
	flash(fx, YELLOW, 5)
end

S.bonk = function(fx)
	fx:sticker("mallet", Vector3.new(1.5, 7, 0), 7, { life = 1.1, swing = true })
	fx:sticker("bonk", Vector3.new(0, 8, 0), 7.5, { delay = 0.45, wobble = true, float = 0.4 })
	local brown = Color3.fromRGB(130, 80, 40)
	local red = Color3.fromRGB(220, 40, 50)
	local m = { material = Enum.Material.SmoothPlastic }
	local handle = fx:part(Vector3.new(0.5, 7, 0.5), brown, m)
	local head = fx:part(Vector3.new(2.6, 2.2, 4), red, m)
	local band1 = fx:part(Vector3.new(2.7, 2.3, 0.4), WHITE, m)
	local band2 = fx:part(Vector3.new(2.7, 2.3, 0.4), WHITE, m)
	local side = Vector3.new(fx.dir.X, 0, fx.dir.Z)
	side = side.Magnitude > 0.1 and side.Unit or Vector3.new(1, 0, 0)
	local pivot = CFrame.lookAt(fx.pos + side * 7 + UP * 0.5, fx.pos + side * 8 + UP * 0.5)
	local t0 = fx.age
	local hit = false
	table.insert(fx.ticks, function(_, t)
		local u = t - t0
		-- up and back, then down hard (0.3 .. 0.5), a rebound wobble
		local a
		if u < 0.3 then
			a = math.rad(-30 - 60 * outCubic(u / 0.3))
		elseif u < 0.45 then
			a = math.rad(-90 + 180 * ((u - 0.3) / 0.15) ^ 2)
		else
			a = math.rad(90 - 12 * math.sin((u - 0.45) * 20) * math.max(0, 1 - (u - 0.45) * 2))
		end
		local cf = pivot * CFrame.Angles(a, 0, 0)
		handle.CFrame = cf * CFrame.new(0, 3.5, 0)
		head.CFrame = cf * CFrame.new(0, 7.5, 0) * CFrame.Angles(0, math.rad(90), 0)
		band1.CFrame = head.CFrame * CFrame.new(0, 0, 1.3)
		band2.CFrame = head.CFrame * CFrame.new(0, 0, -1.3)
		if u >= 0.45 and not hit then
			hit = true
			fx:sound("thud", 0.55, 1)
			fx:sound("ping", 0.9, 0.4)
			poof(fx, fx.pos + UP * 0.5, 8, WHITE, 1)
			if fx.body then
				-- (squashed into the floor)
				local b = fx.body:GetPivot()
				fx:bodyPivot(b * CFrame.new(0, -2, 0))
			end
			local w = fx:text("BONK!", UP * 4, WHITE, { w = 9, h = 3.5, font = Enum.Font.LuckiestGuy, stroke = red })
			w.born = t
			table.insert(fx.ticks, function(_, now)
				local v = now - w.born
				local s = outElastic(v / 0.6)
				w.gui.Size = UDim2.fromScale(9 * s, 3.5 * s)
				w.label.Rotation = -8 + math.sin(v * 12) * 4
				w.label.TextTransparency = clamp01((v - 1.4) / 0.5)
				w.label.TextStrokeTransparency = w.label.TextTransparency
			end)
			for i = 1, 5 do
				local s = fx:text("★", Vector3.zero, YELLOW, { w = 1.3, h = 1.3 })
				table.insert(fx.ticks, function(_, now)
					local v = now - t
					local ang = v * 5 + i / 5 * math.pi * 2
					s.anchor.CFrame = CFrame.new(
						fx.pos
							+ UP * 1.6
							+ Vector3.new(math.cos(ang) * 1.6, math.sin(v * 8 + i) * 0.2, math.sin(ang) * 1.6)
					)
					s.label.TextTransparency = clamp01((v - 1.6) / 0.4)
				end)
			end
		end
		local fade = u > LIFE - 0.4 and clamp01((u - (LIFE - 0.4)) / 0.4) or 0
		for _, p in { handle, head, band1, band2 } do
			p.Transparency = fade
		end
	end)
end

S.dance = function(fx)
	fx:sticker("disco", Vector3.new(0, 10, 0), 5, { delay = 0.1, spin = 90 })
	local tiles = {}
	local n = 5
	for x = 1, n do
		for z = 1, n do
			local p = fx:part(Vector3.new(1.9, 0.12, 1.9), rainbow(x + z), {
				cf = CFrame.new(fx.pos + Vector3.new((x - 3) * 2, 0.07, (z - 3) * 2)),
			})
			table.insert(tiles, { part = p, i = x * 7 + z * 3 })
		end
	end
	local ball =
		fx:part(Vector3.one * 2, Color3.fromRGB(220, 220, 230), { ball = true, material = Enum.Material.Glass })
	local rays = {}
	for i = 1, math.max(4, math.floor(8 * fx.mult)) do
		table.insert(rays, fx:part(Vector3.new(0.12, 0.12, 9), rainbow(i), { transparency = 0.3 }))
	end
	local start = fx.body and fx.body:GetPivot() or CFrame.new(fx.at)
	local t0 = fx.age
	for j = 0, 7 do
		fx:sound("tick", ({ 1, 1.26, 1.5, 1.26 })[j % 4 + 1] * 1.4, 0.35, j * 0.28)
	end
	table.insert(fx.ticks, function(_, t)
		local u = t - t0
		local beat = math.floor(u * 6)
		for _, e in tiles do
			e.part.Color = rainbow(e.i + beat)
			e.part.Transparency = (e.i + beat) % 3 == 0 and 0.55 or 0
		end
		local top = fx.pos + UP * (7 - 2 * outBack(1 - u / 0.4))
		ball.CFrame = CFrame.new(top) * CFrame.Angles(0, u * 4, 0)
		for i, r in ipairs(rays) do
			local a = u * 2.5 + i / #rays * math.pi * 2
			local d = Vector3.new(math.cos(a), -0.8, math.sin(a)).Unit
			r.CFrame = CFrame.lookAt(top + d * 4.5, top + d * 9)
			r.Color = rainbow(i, u)
		end
		-- the stand-in does a little spin and bob, sliding off to the side
		local bob = math.abs(math.sin(u * 9)) * 0.6
		local slide = math.max(0, u - 1.2) * 2
		fx:bodyPivot(start * CFrame.new(slide, bob, 0) * CFrame.Angles(0, u * 7, math.sin(u * 9) * 0.25))
		local fade = u > LIFE - 0.5 and clamp01((u - (LIFE - 0.5)) / 0.5) or 0
		if fade > 0 then
			fx:bodyFade(fade)
			for _, e in tiles do
				e.part.Transparency = math.max(e.part.Transparency, fade)
			end
			ball.Transparency = fade
			for _, r in rays do
				r.Transparency = 0.3 + 0.7 * fade
			end
		end
	end)
	fx:sparkleBurst(fx.pos + UP * 7, WHITE, 24, 10)
end

S.blackhole = function(fx)
	fx:sticker("blackhole", Vector3.new(0, 3, 0), 12, { delay = 0.05, spin = -160, pulse = true, onTop = false })
	local center = fx.at + UP * 0.6
	local disc = fx:part(Vector3.new(0.2, 1, 1), INK, {
		cylinder = true,
		material = Enum.Material.SmoothPlastic,
		cf = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
	})
	local ring = fx:part(Vector3.new(0.15, 1, 1), Color3.fromRGB(150, 60, 255), {
		cylinder = true,
		transparency = 0.2,
	})
	local ring2 = fx:part(Vector3.new(0.12, 1, 1), Color3.fromRGB(255, 80, 200), {
		cylinder = true,
		transparency = 0.4,
	})
	local core = fx:part(Vector3.one, INK, { ball = true, material = Enum.Material.SmoothPlastic })
	-- debris spiralling in
	local debris = {}
	for i = 1, fx.n do
		local p =
			fx:part(Vector3.one * rng:NextNumber(0.2, 0.5), i % 3 == 0 and WHITE or Color3.fromRGB(150, 60, 255), {})
		table.insert(
			debris,
			{ part = p, a = rng:NextNumber(0, 6.28), r = rng:NextNumber(5, 10), y = rng:NextNumber(-1, 3) }
		)
	end
	local start = fx.body and fx.body:GetPivot() or CFrame.new(fx.at)
	local t0 = fx.age
	fx:sound("rocket", 0.4, 0.5)
	fx:sound("boom", 0.4, 0.5, 2.1)
	table.insert(fx.ticks, function(_, t)
		local u = t - t0
		local open = outBack(u / 0.4) * (u > 2.2 and math.max(0, 1 - (u - 2.2) / 0.25) or 1)
		local r = 5 * open
		disc.Size = Vector3.new(0.2, r * 2, r * 2)
		disc.CFrame = CFrame.new(center) * CFrame.Angles(0, u * 3, math.rad(90))
		ring.Size = Vector3.new(0.15, r * 2.4, r * 2.4)
		ring.CFrame = CFrame.new(center) * CFrame.Angles(math.rad(14), u * 5, math.rad(90))
		ring2.Size = Vector3.new(0.12, r * 2.9, r * 2.9)
		ring2.CFrame = CFrame.new(center) * CFrame.Angles(math.rad(-10), -u * 4, math.rad(90))
		core.Size = Vector3.one * math.max(0.05, r * 0.9)
		core.CFrame = CFrame.new(center)
		for _, d in debris do
			local k = clamp01(u / 2.2)
			local rr = d.r * (1 - k)
			local aa = d.a + u * (3 + 8 * k)
			d.part.CFrame = CFrame.new(center + Vector3.new(math.cos(aa) * rr, d.y * (1 - k), math.sin(aa) * rr))
			d.part.Transparency = k > 0.95 and 1 or 0
		end
		-- the stand-in: pulled to the middle, spinning, stretched thin (shrunk), gone
		local k = clamp01((u - 0.3) / 1.8)
		local pos = start.Position:Lerp(center, k * k)
		fx:bodyPivot(CFrame.new(pos) * start.Rotation * CFrame.Angles(k * 3, u * 10 * k, 0))
		pcall(function()
			if fx.body and fx.body.ScaleTo then
				fx.body:ScaleTo(math.max(0.05, 1 - k * 0.95))
			end
		end)
		if k >= 1 then
			fx:bodyFade(1)
		end
		if u > 2.2 and not fx.imploded then
			fx.imploded = true
			flash(fx, Color3.fromRGB(200, 120, 255), 8)
			fx:sparkleBurst(center, Color3.fromRGB(200, 120, 255), 40, 24)
		end
		local fade = u > 2.45 and 1 or 0
		disc.Transparency, core.Transparency = fade, fade
		ring.Transparency = math.max(0.2, fade)
		ring2.Transparency = math.max(0.4, fade)
	end)
end

S.heaven = function(fx)
	fx:sticker("heaven", Vector3.new(0, 7, 0), 11, { delay = 0.1, spin = 12, float = 1.5, onTop = false })
	local beam = fx:part(Vector3.new(80, 4, 4), GOLD, {
		cylinder = true,
		transparency = 0.55,
		cf = CFrame.new(fx.pos + UP * 40) * CFrame.Angles(0, 0, math.rad(90)),
	})
	local halo = fx:part(Vector3.new(0.18, 1.6, 1.6), GOLD, { cylinder = true })
	local wingL = fx:part(Vector3.new(0.2, 2.2, 1.6), WHITE, { wedge = true, material = Enum.Material.SmoothPlastic })
	local wingR = fx:part(Vector3.new(0.2, 2.2, 1.6), WHITE, { wedge = true, material = Enum.Material.SmoothPlastic })
	local start = fx.body and fx.body:GetPivot() or CFrame.new(fx.at)
	local t0 = fx.age
	-- a soft choir: three slow notes stacked
	fx:sound("ping", 0.5, 0.45)
	fx:sound("ping", 0.63, 0.4, 0.15)
	fx:sound("ping", 0.75, 0.4, 0.3)
	fx:sound("win", 0.8, 0.25, 0.4)
	table.insert(fx.ticks, function(_, t)
		local u = t - t0
		local rise = math.max(0, u - 0.35) ^ 1.4 * 3.5
		local cf = start * CFrame.new(0, rise, 0) * CFrame.Angles(0, u * 0.6, 0)
		fx:bodyPivot(cf)
		local flap = math.sin(u * 10) * 0.5
		local grow = outBack(u / 0.4)
		wingL.Size = Vector3.new(0.2, 2.2, 1.6) * math.max(0.05, grow)
		wingR.Size = wingL.Size
		wingL.CFrame = cf
			* CFrame.new(-0.9, 0.8, 0.8)
			* CFrame.Angles(0, math.rad(-30) + flap, 0)
			* CFrame.new(0, 0, 0.6)
		wingR.CFrame = cf * CFrame.new(0.9, 0.8, 0.8) * CFrame.Angles(0, math.rad(30) - flap, 0) * CFrame.new(0, 0, 0.6)
		halo.CFrame = cf * CFrame.new(0, 2.6 + math.sin(u * 4) * 0.1, 0) * CFrame.Angles(0, 0, math.rad(90))
		beam.Size = Vector3.new(80, 4 + math.sin(u * 6) * 0.4, 4 + math.sin(u * 6) * 0.4)
		local fade = u > LIFE - 0.6 and clamp01((u - (LIFE - 0.6)) / 0.6) or 0
		beam.Transparency = 0.55 + 0.45 * fade
		halo.Transparency, wingL.Transparency, wingR.Transparency = fade, fade, fade
		if fade > 0 then
			fx:bodyFade(fade)
		end
		-- sparkles drifting up in the beam
		if fx.alive and rng:NextNumber() < 0.5 * fx.mult then
			local p = fx:part(Vector3.one * 0.25, rng:NextNumber() < 0.5 and GOLD or WHITE, {
				ball = true,
				cf = CFrame.new(
					fx.pos + Vector3.new(rng:NextNumber(-1.6, 1.6), rng:NextNumber(0, 4), rng:NextNumber(-1.6, 1.6))
				),
			})
			fx:bit(p, UP * rng:NextNumber(4, 8), { twinkle = 20, life = 1.2, drag = 0 })
		end
	end)
	fx:sparkleBurst(fx.at, GOLD, 30, 8)
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
	local preview = opts.preview == true
	local t = preview and "low" or tier()
	if not preview and KillEffects.pieces() > (MAX_PIECES[t] or 150) then
		return nil -- (too much on screen: this one sits out)
	end
	local look = opts.look or { shape = shape, color = "team", count = 12 }
	local dir = typeof(opts.dir) == "Vector3" and opts.dir.Magnitude > 0.01 and opts.dir.Unit or Vector3.new(1, 0, 0)
	local f = typeof(opts.parent) == "Instance" and opts.parent or getFolder()
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
	local ground = typeof(opts.ground) == "Vector3" and opts.ground or pos - UP * 2.9
	pcall(function()
		if opts.ground then
			return
		end
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
		fixed = opts.fixed == true or preview,
		preview = preview,
		age = 0,
		life = LIFE,
		folder = f,
		anchor = anchor,
		parts = {},
		bits = {},
		emitters = {},
		timers = {},
		ticks = {},
		boards = {},
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
			if preview then
				m.Parent = f
			end
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
	if not preview then
		table.insert(actors, fx)
		connect()
	end
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
