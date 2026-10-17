--[[
Fireworks when a team wins: a show in three acts over FIREWORKS_SECONDS, in the winners' colour with gold and white,
SUPERHOT-plain (neon cubes and balls, no textures). Drawn on each client only (nothing crosses the network but the
Winner the match already sends).

  1. the opening volley   rockets rise in waves from both ends of the winners' side, fizzing trails and whistles,
                          popping into small shells
  2. the main show        big shells, each its own kind: peonies (a ball of stars), willows (gold streaks that
                          droop), crossettes (stars that split in four), rings, strobing glitter; each with a crackle
                          a beat later; near, middle and far, low and high, so the whole sky fills
  3. the finale           a rapid barrage, then one giant golden shell that fills the sky: a bright flash on the
                          screen, a deep boom, every light on the arena at once

Each burst lights up the arena under it (a few pooled PointLights), and every launch, whistle, burst and crackle is
heard where it happened (AudioController's fw_ cues, made from the shared clips). The camera tilts up a little to
watch, and back down at the end, for a player just standing there: not with Reduced Motion, not under a cinematic
or a menu, and it gives up for good the moment you look round or draw the bow.

Phones and low graphics (Effects.tier) get fewer of everything, and there is a cap on the pieces alive at once
(CAPS: trails and crackles only get the first 80% of it, so the shells always have room). The parts come from a
pool and the pieces' tables are reused; when the show is over and the last star has faded every part, light and the
flash are destroyed and the frame step is disconnected.

  FireworksController.start(team)               the match's victory (over the winners' side of the arena)
  FireworksController.show(center, color, opts) the full show anywhere: center is the ground under it, color the
                                                main colour; opts = { seconds?, radius? (the half-width of the
                                                stage, 40), depth?, back? (Vector3: which way the far shells go;
                                                default away from the camera), accent? (Color3), tilt? (false: leave
                                                the camera alone), flash? (false), sound? (false) }
  FireworksController.stop()                    everything gone now
  FireworksController.active()   .count()   .act() ("volley" | "main" | "finale" | nil)   .stats()   .cap()  (tests)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Effects = require(script.Parent.Parent.FX.Effects)
local Bus = require(script.Parent.Parent.UI.Bus)
local Theme = require(script.Parent.Parent.UI.Theme)
local Store = require(script.Parent.Parent.Store)
local AudioController = require(script.Parent.AudioController)
local CameraController = require(script.Parent.CameraController)

local FireworksController = { Name = "FireworksController", Order = 45 }

local player = Players.LocalPlayer
local rng = Random.new()
local WHITE = Color3.fromRGB(255, 252, 245)
local GOLD = Color3.fromRGB(255, 194, 60)
local GOLD_LIGHT = Color3.fromRGB(255, 228, 150)
local EMBER = Color3.fromRGB(255, 160, 70)
local AWAY = CFrame.new(0, -5000, 0) -- (where a pooled part waits)
local UPRIGHT = CFrame.Angles(math.rad(90), 0, 0) -- (a rocket's long side along its flight)
local GRAVITY = 40
local GOLDEN = math.pi * (3 - math.sqrt(5))

-- per tier: pieces alive at once (rockets, sparks, stars, glows), arena lights, and the multiplier on every count
local CAPS = {
	high = { live = 420, lights = 3, mult = 1, trail = 0.03, main = 0.3, barrage = 0.07 },
	mid = { live = 300, lights = 2, mult = 0.7, trail = 0.045, main = 0.38, barrage = 0.1 },
	low = { live = 150, lights = 1, mult = 0.4, trail = 0.07, main = 0.5, barrage = 0.15 },
}
-- the acts, as fractions of the show (14 s: the volley to 3.5 s, the main show to 9.8 s, the barrage to 11.8 s,
-- the giant gold shell up at 11.9 s, bursting near 12.7 s and raining down past the end)
local ACT = { volley = 0.25, main = 0.7, barrage = 0.84, giant = 0.85 }
local KINDS = { "peony", "willow", "crossette", "ring", "strobe" }
local TILT, TILT_CEIL = math.rad(14), math.rad(30) -- (how far the camera looks up, never past looking this high)

local folder
local live = {} -- the pieces: { kind, part, shape, pos, vel, age, life, ... }
local spare = {} -- (finished pieces' tables, reused)
local pool = { Block = {}, Ball = {} }
local lights = {} -- { holder, light, b }
local crackles = {} -- { at, pos, r, left, ends, on }
local cap = CAPS.low
local s -- the running show
local stats = {}
local stepping
local flashGui, flashFrame
local lastMatch
local lastLook = -math.huge -- (os.clock() of the player's last look round)
local lastCharge = -math.huge
local bag, bagI = { table.unpack(KINDS) }, #KINDS + 1
local muted, noFlash = false, false -- (the show's opts.sound / opts.flash false: kept past its end for the last stars)

-- Parts ------------------------------------------------------------------------------------------------------------
local function take(shape, size, color)
	local p = table.remove(pool[shape])
	if not p or not p.Parent then
		p = Instance.new("Part")
		p.Name = "Fw" .. shape
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		if shape == "Ball" then
			p.Shape = Enum.PartType.Ball
		end
		p.Parent = folder
	end
	p.Size = size
	p.Color = color
	p.Transparency = 0
	return p
end

local function room(n)
	return math.max(0, math.min(n, cap.live - #live))
end

-- one piece; every field set here, so a reused table carries nothing over
local function spawn(kind, shape, pos, vel, life, size, color)
	local e = table.remove(spare) or {}
	e.kind = kind
	e.shape = shape
	e.part = take(shape, size, color)
	e.pos = pos
	e.vel = vel
	e.age = 0
	e.life = life
	e.size = size
	e.s1 = nil
	e.drag = 1.4
	e.grav = GRAVITY
	e.fade = 2 -- (transparency: age ^ fade)
	e.a0 = 0
	e.strobe = nil
	e.phase = 0
	e.streak = false
	e.split = false
	e.shell = nil
	e.tint = color
	e.accent = color
	e.scale = 1
	e.trail = nil
	e.trailT = 0
	e.part.CFrame = CFrame.new(pos)
	table.insert(live, e)
	if #live > (stats.peak or 0) then
		stats.peak = #live
	end
	return e
end

local function remove(i)
	local e = live[i]
	if e.part.Parent then
		e.part.CFrame = AWAY
		e.part.Transparency = 1
		table.insert(pool[e.shape], e.part)
	end
	e.part = nil
	e.shell = nil
	local n = #live
	live[i] = live[n] -- (swap out: the order doesn't matter)
	live[n] = nil
	table.insert(spare, e)
end

local function randomDir()
	local v = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
	return v.Magnitude > 0.01 and v.Unit or Vector3.yAxis
end

-- the i-th of n directions spread evenly over a ball (turned by `spin`)
local function even(i, n, spin)
	local y = 1 - (i - 0.5) / n * 2
	local r = math.sqrt(math.max(0, 1 - y * y))
	local a = i * GOLDEN + spin
	return Vector3.new(math.cos(a) * r, y, math.sin(a) * r)
end

-- Light and sound ----------------------------------------------------------------------------------------------------
local soundAt = { fw_launch = 0, fw_whistle = 0, fw_burst = 0, fw_crackle = 0 }
local GAP = { fw_launch = 0.06, fw_whistle = 0.25, fw_burst = 0.05, fw_crackle = 0.15 }

local function sound(cue, pos, speed, volume)
	if muted then
		return
	end
	local t = os.clock()
	if t < (soundAt[cue] or 0) then
		return -- (a barrage needn't play every launch: a few voices carry it)
	end
	soundAt[cue] = t + (GAP[cue] or 0)
	pcall(AudioController.playAt, cue, pos, speed, volume)
end

local function makeLights()
	for _ = #lights + 1, cap.lights do
		local holder = Instance.new("Part")
		holder.Name = "FwLight"
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.CastShadow = false
		holder.Transparency = 1
		holder.Size = Vector3.new(1, 1, 1)
		holder.CFrame = AWAY
		local l = Instance.new("PointLight")
		l.Shadows = false
		l.Range = 60
		l.Brightness = 0
		l.Parent = holder
		holder.Parent = folder
		table.insert(lights, { holder = holder, light = l, b = 0 })
	end
end

-- the arena lit up under a burst: the dimmest light jumps there
local function glowArena(pos, color, brightness)
	local best
	for _, it in lights do
		if not best or it.b < best.b then
			best = it
		end
	end
	if not best then
		return
	end
	best.b = math.max(best.b, brightness)
	best.holder.CFrame = CFrame.new(pos - Vector3.new(0, 16, 0)) -- (a little under it: the ground catches it)
	best.light.Color = color
	best.light.Brightness = best.b
end

local function screenFlash()
	if noFlash then
		return
	end
	local pg = player and player:FindFirstChild("PlayerGui")
	if not pg then
		return
	end
	if not flashGui or not flashGui.Parent then
		flashGui = Theme.new("ScreenGui", {
			Name = "FireworksFlash",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			DisplayOrder = 12,
			Parent = pg,
		})
		flashFrame = Theme.new("Frame", {
			Name = "Flash",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = GOLD_LIGHT,
			BorderSizePixel = 0,
			Parent = flashGui,
		})
	end
	flashFrame.BackgroundTransparency = Theme.reducedMotion() and 0.65 or 0.12 -- (softer with Reduced Motion)
	stats.flash = true
end

-- Shells -------------------------------------------------------------------------------------------------------------
local function star(pos, dir, speed, life, size, color)
	return spawn("star", "Block", pos, dir * speed, life, size, color)
end

local function glow(pos, color, s0, s1, life)
	if room(1) < 1 then
		return
	end
	local e = spawn("glow", "Ball", pos, Vector3.zero, life, Vector3.new(s0, s0, s0), color)
	e.s1 = s1
	e.a0 = 0.15
end

-- the crackle a beat after a shell: little white pops all through where its stars went
local function crackle(pos, r, n, delay)
	local c
	for _, it in crackles do
		if not it.on then
			c = it
			break
		end
	end
	if not c then
		c = {}
		table.insert(crackles, c)
	end
	c.on = true
	c.at = os.clock() + delay
	c.ends = c.at + 0.4
	c.pos = pos
	c.r = r
	c.left = n
	c.started = false
	stats.crackles = (stats.crackles or 0) + 1
end

local BURST = {}

function BURST.peony(e, n, sc)
	local spin = rng:NextNumber(0, 6.28)
	local light = e.tint:Lerp(WHITE, 0.45)
	for i = 1, room(n) do
		local c = (i % 6 == 0) and e.accent or ((i % 2 == 0) and light or e.tint)
		local st = star(
			e.pos,
			even(i, n, spin),
			(30 + rng:NextNumber(0, 6)) * sc,
			rng:NextNumber(1.4, 1.9),
			Vector3.one * 1.2 * sc,
			c
		)
		st.drag = 1.5
	end
end

function BURST.willow(e, n, sc)
	local spin = rng:NextNumber(0, 6.28)
	local warm = e.tint:Lerp(GOLD, 0.55)
	for i = 1, room(n) do
		local c = (i % 3 == 0) and GOLD_LIGHT or ((i % 3 == 1) and GOLD or warm)
		local st =
			star(e.pos, even(i, n, spin), 36 * sc, rng:NextNumber(2.6, 3.2), Vector3.new(0.35, 0.35, 2.4) * sc, c)
		st.drag, st.grav, st.fade, st.streak = 2.4, 9, 3, true -- (slowed fast, then droops a long way down)
	end
end

function BURST.crossette(e, n, sc)
	local spin = rng:NextNumber(0, 6.28)
	for i = 1, room(n) do
		local st = star(e.pos, even(i, n, spin), 30 * sc, rng:NextNumber(0.5, 0.65), Vector3.one * 1.5 * sc, e.tint)
		st.drag, st.fade, st.split, st.accent = 0.8, 6, true, e.accent
	end
end

-- a crossette's star at the end of its run: four smaller ones, square to the way it went
local function split(e)
	local v = e.vel.Magnitude > 0.01 and e.vel.Unit or Vector3.yAxis
	local side = math.abs(v.Y) < 0.9 and Vector3.yAxis or Vector3.xAxis
	local a = v:Cross(side).Unit
	local b = v:Cross(a).Unit
	for i = 1, room(4) do
		local d = (i == 1 and a) or (i == 2 and -a) or (i == 3 and b) or -b
		local st = star(
			e.pos,
			(d + v * 0.3).Unit,
			22,
			rng:NextNumber(0.8, 1.05),
			Vector3.one * 0.9,
			i % 2 == 0 and WHITE or e.accent
		)
		st.drag = 1.8
	end
end

function BURST.ring(e, n, sc)
	local normal = (Vector3.yAxis + randomDir() * 0.9).Unit -- (tilted, so it reads as a ring from the ground)
	local side = math.abs(normal.Y) < 0.9 and Vector3.yAxis or Vector3.xAxis
	local a = normal:Cross(side).Unit
	local b = normal:Cross(a).Unit
	local light = e.tint:Lerp(WHITE, 0.5)
	local made = room(n)
	for i = 1, made do
		local ang = i / made * math.pi * 2
		local st = star(
			e.pos,
			a * math.cos(ang) + b * math.sin(ang),
			38 * sc,
			1.5,
			Vector3.one * 1.1 * sc,
			i % 2 == 0 and light or e.tint
		)
		st.drag, st.grav = 1.6, 18
	end
	-- (a few stars in the middle, the accent)
	for i = 1, room(math.max(2, math.floor(n / 6))) do
		local st = star(e.pos, even(i, 6, 0), 8 * sc, 1.1, Vector3.one * 0.9 * sc, e.accent)
		st.drag = 2
	end
end

function BURST.strobe(e, n, sc)
	local spin = rng:NextNumber(0, 6.28)
	for i = 1, room(n) do
		local st = star(
			e.pos,
			even(i, n, spin),
			26 * sc,
			rng:NextNumber(2, 2.5),
			Vector3.one * 0.8 * sc,
			i % 3 == 0 and GOLD_LIGHT or WHITE
		)
		st.drag, st.grav, st.fade = 1.9, 14, 3
		st.strobe, st.phase = rng:NextNumber(12, 18), rng:NextNumber(0, 1) -- (each blinks to its own beat)
	end
end

-- the volley's and the barrage's small shells
function BURST.small(e, n, sc)
	BURST[(rng:NextNumber() < 0.3) and "ring" or "peony"](e, n, sc)
end

function BURST.giant(e, n, sc)
	local spin = rng:NextNumber(0, 6.28)
	for i = 1, room(n) do
		local c = (i % 4 == 0) and WHITE or ((i % 2 == 0) and GOLD_LIGHT or GOLD)
		local st = star(
			e.pos,
			even(i, n, spin),
			rng:NextNumber(62, 74) * sc,
			rng:NextNumber(3, 3.6),
			Vector3.new(0.6, 0.6, 3.2),
			c
		)
		st.drag, st.grav, st.fade, st.streak = 1.3, 14, 3, true
	end
	-- a gold ring racing out round it, and glitter hanging in the middle
	local made = room(math.floor(n / 4))
	for i = 1, made do
		local ang = i / made * math.pi * 2
		local st = star(e.pos, Vector3.new(math.cos(ang), 0.08, math.sin(ang)), 84, 2.2, Vector3.one * 1.4, GOLD_LIGHT)
		st.drag, st.grav = 1.2, 8
	end
	for i = 1, room(math.floor(n / 5)) do
		local st =
			star(e.pos, even(i, 30, spin), rng:NextNumber(10, 30), rng:NextNumber(2.4, 3.2), Vector3.one * 0.8, WHITE)
		st.drag, st.grav, st.fade = 2, 6, 2
		st.strobe, st.phase = rng:NextNumber(10, 16), rng:NextNumber(0, 1)
	end
end

-- how many stars each kind makes at full size (times the tier's mult)
local STARS = { peony = 40, willow = 30, crossette = 10, ring = 26, strobe = 34, small = 18, giant = 160 }

local function burst(e)
	local shell = e.shell or "small"
	local sc = e.scale
	local n = math.max(shell == "crossette" and 5 or 8, math.floor((STARS[shell] or 18) * cap.mult * sc + 0.5))
	if shell == "giant" then
		n = math.max(40, math.floor(STARS.giant * cap.mult))
	end
	BURST[shell](e, n, sc)
	if shell == "giant" then
		glow(e.pos, GOLD_LIGHT, 8, 70, 0.6)
		for _, it in lights do
			it.b = 0 -- (all of them at once, spread round it)
		end
		for i = 1, #lights do
			glowArena(e.pos + Vector3.new((i - 2) * 40, 0, 0), GOLD_LIGHT, 9)
		end
		screenFlash()
		if not Theme.reducedMotion() then
			CameraController.shake(0.3, 0.5)
		end
		if not muted then
			pcall(AudioController.play, "fw_finale")
		end
		stats.giant = true
		return
	end
	glow(e.pos, e.tint:Lerp(WHITE, 0.6), 2, 10 * sc, 0.22)
	glowArena(e.pos, e.tint, 2.5 + 2 * sc)
	sound("fw_burst", e.pos, shell == "small" and 1.25 or (1.05 - 0.15 * sc), shell == "small" and 0.7 or 1)
	if shell ~= "small" then
		stats.types[shell] = (stats.types[shell] or 0) + 1
		crackle(e.pos, 26 * sc, math.max(4, math.floor(14 * cap.mult)), rng:NextNumber(0.45, 0.8))
	end
end

-- a rocket from `from` to `to` in `flight` s (a light gravity bends its climb), bursting into `shell` there
local ROCKET = Vector3.new(0.45, 2, 0.45)
local function rocket(from, to, flight, shell, tint, accent, scale)
	if room(1) < 1 then
		return nil
	end
	local g = 8
	local vel = (to - from) / flight + Vector3.new(0, 0.5 * g * flight, 0)
	local e = spawn("rocket", "Block", from, vel, flight, shell == "giant" and ROCKET * 1.8 or ROCKET, WHITE)
	e.drag, e.grav, e.fade = 0, g, 0
	e.shell, e.tint, e.accent, e.scale = shell, tint, accent, scale or 1
	e.trail = shell == "giant" and cap.trail * 0.5 or cap.trail
	sound("fw_launch", from, shell == "giant" and 0.7 or 1, shell == "giant" and 1 or 0.6)
	return e
end

-- the fizz behind a rocket
local SPARK = Vector3.new(0.35, 0.35, 0.35)
local function trail(e)
	if #live >= cap.live * 0.8 then
		return
	end
	local back = e.vel.Magnitude > 0.01 and e.vel.Unit or Vector3.yAxis
	local c = rng:NextNumber() < 0.4 and WHITE or (rng:NextNumber() < 0.5 and GOLD or EMBER)
	local sp =
		spawn("spark", "Block", e.pos - back * 1.2, randomDir() * 4 - e.vel * 0.06, rng:NextNumber(0.3, 0.45), SPARK, c)
	sp.drag, sp.grav = 2, 20
end

-- The stage ------------------------------------------------------------------------------------------------------------
-- a spot over the stage: u across it (-1..1, the ends), v toward the back (0 the middle, 1 its back, 2 far behind)
local function spot(u, v, h)
	return s.center + s.along * (u * s.half) + s.back * (v * s.depth) + Vector3.new(0, h, 0)
end

local function color3(i)
	return (i % 3 == 0) and s.accent or ((i % 3 == 1) and s.color or WHITE)
end

local function nextKind()
	if bagI > #bag then
		for i = #bag, 2, -1 do -- (every kind once in a while, in a new order each time round)
			local j = rng:NextInteger(1, i)
			bag[i], bag[j] = bag[j], bag[i]
		end
		bagI = 1
	end
	bagI += 1
	return bag[bagI - 1]
end

-- the volley: a rocket from each end of the side, a few to a wave, fanning in and up
local function volley(t)
	local per = math.max(2, math.floor(4 * cap.mult + 0.5))
	local j = s.vIdx
	for side = -1, 1, 2 do
		local v = rng:NextNumber(-0.6, 0.6)
		local from = spot(side, v, 1)
		local to = spot(
			side * (0.75 - 0.4 * rng:NextNumber()),
			v + rng:NextNumber(-0.2, 0.2),
			30 + j * 5 + rng:NextNumber(0, 6)
		)
		if
			rocket(
				from,
				to,
				rng:NextNumber(0.85, 1.05),
				"small",
				(j + side) % 2 == 0 and s.color or WHITE,
				s.accent,
				0.7
			)
		then
			stats.volley += 1
		end
		if j == 0 then
			sound("fw_whistle", from + Vector3.new(0, 10, 0), 1 + s.wave * 0.06, 0.8)
		end
	end
	s.vIdx += 1
	if s.vIdx >= per then
		s.vIdx = 0
		s.wave += 1
		s.vNext = s.t0 + s.wave * 0.8 * s.len / 14
	else
		s.vNext = t + 0.1
	end
end

-- the main show: near, middle and far, each its own kind of shell
local LAYERS = {
	{ v0 = -0.8, v1 = 0.6, h0 = 32, h1 = 46, scale = 0.85 },
	{ v0 = 0, v1 = 1.2, h0 = 44, h1 = 60, scale = 1 },
	{ v0 = 1.2, v1 = 2.3, h0 = 58, h1 = 80, scale = 1.25 },
}
local function shell(i)
	local layer = LAYERS[rng:NextInteger(1, #LAYERS)]
	local u = rng:NextNumber(-0.9, 0.9)
	local v = rng:NextNumber(layer.v0, layer.v1)
	local kind = nextKind()
	local to = spot(u, v, rng:NextNumber(layer.h0, layer.h1))
	local from = spot(u + rng:NextNumber(-0.1, 0.1), v, 1)
	local accent = (i % 2 == 0) and GOLD or WHITE
	if rocket(from, to, rng:NextNumber(1, 1.3), kind, kind == "strobe" and WHITE or s.color, accent, layer.scale) then
		stats.main += 1
		if rng:NextNumber() < 0.3 then
			sound("fw_whistle", from + Vector3.new(0, 12, 0), rng:NextNumber(0.9, 1.15), 0.6)
		end
	end
end

local function barrage(i)
	local u, v = rng:NextNumber(-1, 1), rng:NextNumber(-0.6, 1.4)
	local from = spot(u, v, 1)
	local to = spot(u * 0.8, v, rng:NextNumber(34, 62))
	if rocket(from, to, rng:NextNumber(0.5, 0.65), "small", color3(i), GOLD, 0.75) then
		stats.barrage += 1
	end
end

-- The camera -----------------------------------------------------------------------------------------------------------
local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function tiltStep(t)
	if s.tiltOff then
		return
	end
	-- (you looked round, drew the bow, a cinematic or a menu has the camera: it's yours, left where it is)
	if
		lastLook > s.t0
		or lastCharge > s.t0
		or CameraController.takenOver()
		or CameraController.mouseFree()
		or Theme.reducedMotion()
	then
		s.tiltOff = true
		return
	end
	local x = t - s.t0
	local want = TILT * smooth(x / 1.8) * smooth((s.len - x) / 1.5)
	local turned = CameraController.lookUp(want - s.tilted, TILT_CEIL)
	s.tilted += turned
	stats.tilt = math.max(stats.tilt or 0, s.tilted)
end

-- The frame ------------------------------------------------------------------------------------------------------------
local function cleanup()
	for _, list in pool do
		for _, p in list do
			p:Destroy()
		end
		table.clear(list)
	end
	for _, it in lights do
		it.holder:Destroy()
	end
	table.clear(lights)
	if flashGui then
		flashGui:Destroy()
		flashGui, flashFrame = nil, nil
	end
	if stepping then
		stepping:Disconnect()
		stepping = nil
	end
end

local function stepShow(t)
	local x = t - s.t0
	local len = s.len
	if x < len * ACT.volley then
		while t >= s.vNext and x < len * ACT.volley do
			volley(t)
		end
	elseif x < len * ACT.main then
		if t >= s.mNext then
			s.mNext = t + cap.main * rng:NextNumber(0.75, 1.25)
			s.n += 1
			shell(s.n)
			if rng:NextNumber() < 0.35 then
				s.n += 1
				shell(s.n) -- (a pair now and then)
			end
		end
	elseif x < len * ACT.barrage then
		while t >= s.bNext do
			s.bNext = math.max(s.bNext + cap.barrage, t - 0.1)
			s.n += 1
			barrage(s.n)
		end
	elseif not s.giant and x >= len * ACT.giant then
		s.giant = true
		rocket(spot(0, 0.3, 1), spot(0, 0.3, 74), 0.8, "giant", GOLD, WHITE, 1)
	end
	tiltStep(t)
	if x >= len then
		s = nil
	end
end

local function step(dt)
	local t = os.clock()
	if s then
		stepShow(t)
	end
	for i = #live, 1, -1 do
		local e = live[i]
		e.age += dt
		if e.age >= e.life then
			if e.kind == "rocket" then
				burst(e)
			elseif e.split then
				split(e)
			end
			remove(i)
			continue
		end
		local kind = e.kind
		if kind == "glow" then
			local f = e.age / e.life
			local d = e.size.X + (e.s1 - e.size.X) * (1 - (1 - f) ^ 2)
			e.part.Size = Vector3.new(d, d, d)
			e.part.Transparency = e.a0 + (1 - e.a0) * f
			continue
		end
		if e.drag > 0 then
			e.vel *= 1 - math.min(1, dt * e.drag)
		end
		e.vel -= Vector3.new(0, e.grav * dt, 0)
		e.pos += e.vel * dt
		if kind == "rocket" then
			e.part.CFrame = CFrame.lookAt(e.pos, e.pos + e.vel) * UPRIGHT
			e.trailT -= dt
			if e.trailT <= 0 then
				e.trailT = e.trail
				trail(e)
			end
		else
			if e.streak and e.vel.Magnitude > 0.5 then
				e.part.CFrame = CFrame.lookAt(e.pos, e.pos + e.vel)
			else
				e.part.CFrame = CFrame.new(e.pos)
			end
			local f = e.age / e.life
			local a = f ^ e.fade
			if e.strobe and f > 0.25 and math.floor(e.age * e.strobe + e.phase) % 2 == 1 then
				a = 1 -- (the glitter's off beat)
			end
			e.part.Transparency = a
		end
	end
	-- the crackles: their pops spread over a moment
	for _, c in crackles do
		if c.on and t >= c.at then
			if not c.started then
				c.started = true
				sound("fw_crackle", c.pos, rng:NextNumber(0.9, 1.15), 0.8)
			end
			local go = t >= c.ends and c.left or math.ceil(c.left * math.min(1, dt / math.max(dt, c.ends - t)))
			for _ = 1, math.min(go, c.left) do
				c.left -= 1
				if #live < cap.live * 0.8 then
					local p = spawn(
						"glow",
						"Ball",
						c.pos + randomDir() * (c.r * rng:NextNumber(0.3, 1)),
						Vector3.zero,
						rng:NextNumber(0.1, 0.18),
						Vector3.one * 0.5,
						WHITE
					)
					p.s1, p.a0 = 1.6, 0
				end
			end
			if c.left <= 0 then
				c.on = false
				c.pos = nil
			end
		end
	end
	for _, it in lights do
		if it.b > 0 then
			it.b = it.b * math.exp(-dt * 5)
			if it.b < 0.03 then
				it.b = 0
				it.holder.CFrame = AWAY
			end
			it.light.Brightness = it.b
		end
	end
	if flashFrame and flashFrame.BackgroundTransparency < 1 then
		flashFrame.BackgroundTransparency = math.min(1, flashFrame.BackgroundTransparency + dt * 1.4)
	end
	if not s and #live == 0 then
		local busy = flashFrame and flashFrame.BackgroundTransparency < 1
		for _, c in crackles do
			busy = busy or c.on
		end
		if not busy then
			cleanup()
		end
	end
end

-- The public calls -----------------------------------------------------------------------------------------------------
function FireworksController.show(center, color, opts)
	opts = opts or {}
	if not folder or not folder.Parent then
		folder = Instance.new("Folder")
		folder.Name = "Fireworks"
		folder.Parent = workspace
	end
	local ok, tier = pcall(Effects.tier)
	cap = CAPS[ok and tier or "low"] or CAPS.low
	center = typeof(center) == "Vector3" and center or Vector3.zero
	-- (which way is "back": given, or away from where you're looking from)
	local back = typeof(opts.back) == "Vector3" and opts.back or nil
	if not back then
		local cam = workspace.CurrentCamera
		local d = cam and (center - cam.CFrame.Position) or Vector3.xAxis
		back = Vector3.new(d.X, 0, d.Z)
	end
	back = back.Magnitude > 0.01 and Vector3.new(back.X, 0, back.Z).Unit or Vector3.xAxis
	local now = os.clock()
	local len = tonumber(opts.seconds) or Constants.FIREWORKS_SECONDS
	local half = tonumber(opts.radius) or 40
	s = {
		t0 = now,
		len = len,
		opts = opts,
		center = Vector3.new(center.X, center.Y, center.Z),
		back = back,
		along = Vector3.yAxis:Cross(back).Unit,
		half = half,
		depth = tonumber(opts.depth) or half * 0.6,
		color = typeof(color) == "Color3" and color or WHITE,
		accent = typeof(opts.accent) == "Color3" and opts.accent or GOLD,
		vNext = now,
		vIdx = 0,
		wave = 0,
		mNext = 0,
		bNext = 0,
		n = 0,
		giant = false,
		tilted = 0,
		tiltOff = opts.tilt == false,
	}
	muted, noFlash = opts.sound == false, opts.flash == false
	stats = {
		volley = 0,
		main = 0,
		barrage = 0,
		giant = false,
		flash = false,
		crackles = 0,
		peak = #live,
		types = {},
		tilt = 0,
	}
	makeLights()
	if not stepping then
		stepping = RunService.RenderStepped:Connect(step)
	end
	return true
end

-- the match's victory: over the winners' side of the arena (their half, back from the line, its whole width)
function FireworksController.start(winner)
	local m = Store.get("match") or {}
	local lo, hi = m.loseRed or -80, m.loseBlue or 80
	local mid = (lo + hi) / 2
	local base = winner == "blue" and hi or (winner == "red" and lo or mid) -- (red's end is the low one)
	local back = Vector3.new(base == mid and 1 or (base > mid and 1 or -1), 0, 0)
	local depth = math.max(12, math.abs(base - mid) / 2)
	return FireworksController.show(
		Vector3.new((base + mid) / 2, 0, 0),
		Constants.TEAM_COLOR[winner] or WHITE,
		{ radius = ((m.width or 96) - 12) / 2, depth = depth, back = back }
	)
end

function FireworksController.stop()
	s = nil
	for i = #live, 1, -1 do
		remove(i)
	end
	for _, c in crackles do
		c.on = false
	end
	cleanup()
end

function FireworksController.active()
	return s ~= nil
end

function FireworksController.count()
	return #live
end

function FireworksController.act()
	if not s then
		return nil
	end
	local x = os.clock() - s.t0
	return (x < s.len * ACT.volley and "volley") or (x < s.len * ACT.main and "main") or "finale"
end

function FireworksController.stats()
	return stats
end

function FireworksController.cap()
	return cap, CAPS
end

function FireworksController:init()
	folder = Instance.new("Folder")
	folder.Name = "Fireworks"
	folder.Parent = workspace
	Store.Changed:Connect(function(partial)
		local m = partial.match
		if m and m.phase == "victory" and m.winner and m.matchId ~= lastMatch then
			lastMatch = m.matchId
			FireworksController.start(m.winner)
		end
	end)
	-- (looking round or drawing the bow: the camera's yours, the tilt stops)
	UserInputService.InputChanged:Connect(function(input)
		local kind = input.UserInputType
		if
			kind == Enum.UserInputType.MouseMovement
			or kind == Enum.UserInputType.Touch
			or (kind == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.Thumbstick2)
		then
			lastLook = os.clock()
		end
	end)
	Bus.Look:Connect(function()
		lastLook = os.clock()
	end)
	Bus.Charge:Connect(function(c)
		if c ~= nil then
			lastCharge = os.clock()
		end
	end)
end

return FireworksController
