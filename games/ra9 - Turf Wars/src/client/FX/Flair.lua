--[[
The cosmetics brought to life (Data/Cosmetics looks with an anim, particles or wings): the bows, the arrow trails and
the banner emblems. Stock Roblox content only (the built-in particle textures, plain parts, gradients); fewer pieces
on phones and low graphics (Effects.tier "low"), everything cleaned up with what it's on.

  colours   Flair.tint(token, team, t, offset)   a colour token that moves: rainbow (through the hues), lava (a hot
                                                 flicker), galaxy (deep purples drifting), electric (blue with white
                                                 flashes), gold and ice (a shimmer), pink; anything else Cosmetics.color
            Flair.moving(token)                  true when the token changes over time
  particles Flair.emitter(part, kind, color?)    a ParticleEmitter on a part: sparkles | embers | snow | sparks | fire
            Flair.drop(kind, pos, team)          one loose bit at pos (feathers, bubbles, blocks, hearts, sparkles,
                                                 sparks, snow, embers), drifting and fading by itself (Flair.step)
            Flair.arc(a, b, color)               a crackle of lightning between two points, gone in a blink
  bows      Flair.bow(parts, look, team, opts)   decorates a bow's parts { grip, limbs = { upper, lower }, tips,
                                                 holder } with its look's anim, particles and wings; returns a
                                                 handle: handle:update(t) each frame, handle:destroy()
  banners   Flair.banner(label, part, anim)      an emblem's TextLabel brought to life; returns a handle like a bow's
            Flair.step(dt)                       moves the loose bits (FlairController calls it every frame)
            Flair.count()                        loose bits up (tests)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Effects = require(script.Parent.Effects)

local Flair = {}

local TEX = {
	sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	fire = "rbxasset://textures/particles/fire_main.dds",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
}
Flair.TEX = TEX

local WHITE = Color3.fromRGB(255, 255, 255)
local NAMED = {
	lava = Color3.fromRGB(255, 90, 20),
	lavaHot = Color3.fromRGB(255, 205, 70),
	galaxy = Color3.fromRGB(70, 30, 150),
	galaxyHot = Color3.fromRGB(190, 110, 255),
	electric = Color3.fromRGB(90, 180, 255),
	gold = Color3.fromRGB(255, 190, 40),
	ice = Color3.fromRGB(150, 220, 255),
	pink = Color3.fromRGB(255, 105, 180),
	candy = Color3.fromRGB(225, 25, 45),
}

local MOVING = { rainbow = true, lava = true, galaxy = true, electric = true, gold = true, ice = true, pink = true }
function Flair.moving(token)
	return MOVING[token] == true
end

function Flair.lite()
	local ok, tier = pcall(Effects.tier)
	return not ok or tier == "low"
end

function Flair.tint(token, team, t, offset)
	t = t or os.clock()
	offset = offset or 0
	if token == "rainbow" then
		return Color3.fromHSV((t * 0.35 + offset) % 1, 0.8, 1)
	elseif token == "lava" then
		return NAMED.lava:Lerp(NAMED.lavaHot, 0.5 + 0.5 * math.sin(t * 5 + offset * 7))
	elseif token == "galaxy" then
		return NAMED.galaxy:Lerp(NAMED.galaxyHot, 0.5 + 0.5 * math.sin(t * 1.6 + offset * 5))
	elseif token == "electric" then
		if math.random() < 0.12 then
			return WHITE
		end
		return NAMED.electric:Lerp(WHITE, 0.25 + 0.25 * math.sin(t * 22 + offset * 9))
	elseif token == "gold" then
		return NAMED.gold:Lerp(WHITE, 0.15 + 0.3 * math.max(0, math.sin(t * 3 + offset * 4)))
	elseif token == "ice" then
		return NAMED.ice:Lerp(WHITE, 0.25 + 0.3 * math.sin(t * 2 + offset * 5))
	elseif token == "pink" then
		return NAMED.pink:Lerp(WHITE, 0.15 + 0.15 * math.sin(t * 4 + offset * 3))
	end
	return Cosmetics.color(token, team)
end

-- Particles -----------------------------------------------------------------------------------------------------
local function seq(a, b)
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b) })
end
local function cseq(a, b)
	return ColorSequence.new(a, b or a)
end

local EMITTERS = {
	sparkles = function(e, color)
		e.Texture = TEX.sparkle
		e.Color = color and cseq(color, WHITE)
			or ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0.7, 1)),
				ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33, 0.7, 1)),
				ColorSequenceKeypoint.new(0.66, Color3.fromHSV(0.66, 0.7, 1)),
				ColorSequenceKeypoint.new(1, Color3.fromHSV(0.9, 0.7, 1)),
			})
		e.Size = seq(0.35, 0)
		e.Lifetime = NumberRange.new(0.4, 0.8)
		e.Rate = 14
		e.Speed = NumberRange.new(0.5, 2)
		e.SpreadAngle = Vector2.new(180, 180)
		e.LightEmission = 1
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-120, 120)
	end,
	embers = function(e, color)
		e.Texture = TEX.fire
		e.Color = cseq(color or NAMED.lavaHot, NAMED.lava)
		e.Size = seq(0.25, 0.02)
		e.Lifetime = NumberRange.new(0.5, 1.1)
		e.Rate = 12
		e.Speed = NumberRange.new(1, 3)
		e.Acceleration = Vector3.new(0, 4, 0)
		e.SpreadAngle = Vector2.new(30, 30)
		e.LightEmission = 1
		e.Transparency = seq(0.1, 1)
	end,
	fire = function(e, color)
		e.Texture = TEX.fire
		e.Color = cseq(color or NAMED.lavaHot, NAMED.lava)
		e.Size = seq(1.4, 0.2)
		e.Lifetime = NumberRange.new(0.4, 0.8)
		e.Rate = 22
		e.Speed = NumberRange.new(2, 5)
		e.Acceleration = Vector3.new(0, 6, 0)
		e.SpreadAngle = Vector2.new(15, 15)
		e.LightEmission = 0.8
		e.Transparency = seq(0.2, 1)
	end,
	snow = function(e, color)
		e.Texture = TEX.sparkle
		e.Color = cseq(color or WHITE, NAMED.ice)
		e.Size = seq(0.18, 0.05)
		e.Lifetime = NumberRange.new(0.8, 1.4)
		e.Rate = 10
		e.Speed = NumberRange.new(0.2, 0.8)
		e.Acceleration = Vector3.new(0, -2, 0)
		e.SpreadAngle = Vector2.new(180, 180)
		e.LightEmission = 0.6
	end,
	sparks = function(e, color)
		e.Texture = TEX.sparkle
		e.Color = cseq(color or WHITE, NAMED.electric)
		e.Size = seq(0.3, 0)
		e.Lifetime = NumberRange.new(0.1, 0.3)
		e.Rate = 26
		e.Speed = NumberRange.new(4, 9)
		e.SpreadAngle = Vector2.new(180, 180)
		e.LightEmission = 1
	end,
}

-- A ParticleEmitter on a part (nil for a kind drawn with loose bits, or on low graphics for the heavy ones).
function Flair.emitter(parent, kind, color)
	local make = EMITTERS[kind]
	if not make or not parent then
		return nil
	end
	local e = Instance.new("ParticleEmitter")
	e.Name = "Flair_" .. kind
	make(e, color)
	if Flair.lite() then
		e.Rate = math.max(2, math.floor(e.Rate * 0.35))
	end
	e.Parent = parent
	return e
end

-- Loose bits ------------------------------------------------------------------------------------------------------
local folder
local bits = {} -- { part, gui?, born, life, vel, spin, kind, size, wobble }
local CAP, CAP_LITE = 160, 40

local function holder()
	if folder and folder.Parent then
		return folder
	end
	folder = Instance.new("Folder")
	folder.Name = "Flair"
	folder.Parent = workspace
	return folder
end

local function piece(size, color, material, shape)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.Neon
	if shape then
		p.Shape = shape
	end
	p.Parent = holder()
	return p
end

local function rnd(a, b)
	return a + math.random() * (b - a)
end

local dropped = 0 -- (every drop asked for, kept or not: tests)
function Flair.drop(kind, pos, _team)
	if typeof(pos) ~= "Vector3" then
		return nil
	end
	dropped += 1
	if #bits >= (Flair.lite() and CAP_LITE or CAP) then
		return nil
	end
	local b = { born = os.clock(), kind = kind, spin = Vector3.new(rnd(-6, 6), rnd(-6, 6), rnd(-6, 6)) }
	local at = pos + Vector3.new(rnd(-0.3, 0.3), rnd(-0.3, 0.3), rnd(-0.3, 0.3))
	if kind == "feathers" then
		b.part = piece(Vector3.new(0.06, 0.35, 0.7), WHITE, Enum.Material.SmoothPlastic)
		b.vel, b.life, b.wobble = Vector3.new(rnd(-1, 1), rnd(-1.5, -0.5), rnd(-1, 1)), rnd(1.2, 1.8), 2.5
	elseif kind == "bubbles" then
		local d = rnd(0.25, 0.5)
		b.part = piece(Vector3.new(d, d, d), Color3.fromRGB(200, 235, 255), Enum.Material.Glass, Enum.PartType.Ball)
		b.part.Transparency = 0.45
		b.vel, b.life, b.wobble = Vector3.new(rnd(-0.6, 0.6), rnd(1, 2.2), rnd(-0.6, 0.6)), rnd(0.8, 1.4), 1.5
		b.pop = true
	elseif kind == "blocks" then
		local d = rnd(0.2, 0.35)
		b.part = piece(Vector3.new(d, d, d), Color3.fromHSV(math.random(), 0.8, 1))
		b.vel, b.life = Vector3.new(rnd(-2, 2), rnd(1, 4), rnd(-2, 2)), rnd(0.7, 1.1)
		b.gravity = 14
	elseif kind == "hearts" then
		b.part = piece(Vector3.new(0.1, 0.1, 0.1), NAMED.pink)
		b.part.Transparency = 1
		local g = Instance.new("BillboardGui")
		g.Size = UDim2.fromOffset(28, 28)
		g.AlwaysOnTop = false
		g.LightInfluence = 0
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(1, 1)
		l.Text = "❤"
		l.TextScaled = true
		l.TextColor3 = NAMED.pink
		l.Parent = g
		g.Adornee = b.part
		g.Parent = b.part
		b.label = l
		b.vel, b.life, b.wobble = Vector3.new(rnd(-0.4, 0.4), rnd(1, 2), rnd(-0.4, 0.4)), rnd(0.8, 1.2), 1
	elseif kind == "sparkles" or kind == "sparks" then
		local d = kind == "sparks" and 0.12 or 0.22
		local color = kind == "sparks" and NAMED.electric:Lerp(WHITE, 0.5) or Color3.fromHSV(math.random(), 0.6, 1)
		b.part = piece(Vector3.new(d, d, d), color, Enum.Material.Neon, Enum.PartType.Ball)
		local speed = kind == "sparks" and 7 or 1.5
		b.vel = Vector3.new(rnd(-1, 1), rnd(-1, 1), rnd(-1, 1)) * speed
		b.life, b.grow = kind == "sparks" and rnd(0.15, 0.3) or rnd(0.4, 0.7), -1
	elseif kind == "snow" then
		b.part = piece(Vector3.new(0.14, 0.14, 0.14), WHITE, Enum.Material.Neon, Enum.PartType.Ball)
		b.vel, b.life, b.wobble = Vector3.new(rnd(-0.4, 0.4), rnd(-1.2, -0.4), rnd(-0.4, 0.4)), rnd(0.8, 1.3), 1
	elseif kind == "embers" then
		b.part = piece(Vector3.new(0.14, 0.14, 0.14), NAMED.lavaHot, Enum.Material.Neon)
		b.vel, b.life = Vector3.new(rnd(-0.5, 0.5), rnd(1.5, 3), rnd(-0.5, 0.5)), rnd(0.5, 0.9)
		b.grow = -1
	else
		return nil
	end
	b.part.CFrame = CFrame.new(at) * CFrame.Angles(rnd(0, 6), rnd(0, 6), rnd(0, 6))
	b.size = b.part.Size
	table.insert(bits, b)
	return b.part
end

-- A crackle of lightning from a to b: a few jagged neon pieces, gone in a blink.
function Flair.arc(a, b, color)
	if typeof(a) ~= "Vector3" or typeof(b) ~= "Vector3" then
		return
	end
	local n = 3
	local prev = a
	for i = 1, n do
		local k = i / n
		local nextP = a:Lerp(b, k)
		if i < n then
			nextP += Vector3.new(rnd(-0.25, 0.25), rnd(-0.25, 0.25), rnd(-0.25, 0.25)) * (a - b).Magnitude
		end
		local len = (nextP - prev).Magnitude
		if len > 0.01 and #bits < (Flair.lite() and CAP_LITE or CAP) then
			local p = piece(Vector3.new(0.05, 0.05, len), color or WHITE)
			p.CFrame = CFrame.lookAt((prev + nextP) / 2, nextP)
			table.insert(bits, { part = p, born = os.clock(), life = rnd(0.05, 0.1), kind = "arc", size = p.Size })
		end
		prev = nextP
	end
end

function Flair.step(dt)
	local t = os.clock()
	for i = #bits, 1, -1 do
		local b = bits[i]
		local age = t - b.born
		if age >= b.life or not b.part.Parent then
			b.part:Destroy()
			table.remove(bits, i)
		elseif b.kind ~= "arc" then
			local k = age / b.life
			if b.gravity then
				b.vel -= Vector3.new(0, b.gravity * dt, 0)
			end
			local sway = b.wobble
					and Vector3.new(math.sin(t * 4 + b.born * 10), 0, math.cos(t * 3 + b.born * 7)) * b.wobble * dt
				or Vector3.zero
			local cf = b.part.CFrame
			b.part.CFrame = (cf + b.vel * dt + sway) * CFrame.Angles(b.spin.X * dt, b.spin.Y * dt, b.spin.Z * dt)
			if b.grow then
				b.part.Size = b.size * math.max(0.05, 1 + b.grow * k)
			elseif b.pop and k > 0.85 then
				b.part.Size = b.size * (1 + (k - 0.85) * 4)
			end
			if b.label then
				b.label.TextTransparency = k * k
			elseif b.kind ~= "bubbles" then
				b.part.Transparency = k * k
			else
				b.part.Transparency = 0.45 + 0.55 * k * k
			end
		end
	end
end

function Flair.count()
	return #bits
end

-- How many bits have been asked for so far (counts the ones the cap turned away too)
function Flair.dropped()
	return dropped
end

-- Bows ----------------------------------------------------------------------------------------------------------
-- A gradient band over each long face of a limb: stripes (candy) or a rainbow, sliding along (UIGradient.Offset).
local function gradientSkin(p, kind)
	local guis = {}
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
		local sg = Instance.new("SurfaceGui")
		sg.Name = "FlairSkin"
		sg.Face = face
		sg.LightInfluence = 0
		local f = Instance.new("Frame")
		f.Size = UDim2.fromScale(1, 1)
		f.BorderSizePixel = 0
		f.BackgroundColor3 = WHITE
		f.Parent = sg
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		if kind == "stripes" then
			local red, white = NAMED.candy, WHITE
			local keys = {}
			for i = 0, 8 do
				local c = i % 2 == 0 and red or white
				table.insert(keys, ColorSequenceKeypoint.new(math.min(1, i / 8), c))
				if i < 8 then
					table.insert(keys, ColorSequenceKeypoint.new(math.min(1, i / 8 + 0.12), c))
				end
			end
			g.Color = ColorSequence.new(keys)
		else
			local keys = {}
			for i = 0, 6 do
				table.insert(keys, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 0.8, 1)))
			end
			g.Color = ColorSequence.new(keys)
		end
		g.Parent = f
		sg.Parent = p
		table.insert(guis, g)
	end
	return guis
end

-- The golden dragon's wings: two layered blades each side of the grip
local function wings(holderModel, size)
	local list = {}
	for _, side in { -1, 1 } do
		for j = 1, 2 do
			local w = Instance.new("WedgePart")
			w.Name = "FlairWing"
			w.Anchored = true
			w.CanCollide = false
			w.CanQuery = false
			w.CanTouch = false
			w.CastShadow = false
			w.Massless = true
			w.Material = j == 1 and Enum.Material.Metal or Enum.Material.Neon
			w.Color = j == 1 and NAMED.gold or Color3.fromRGB(255, 230, 140)
			w.Size = Vector3.new(0.04, 0.5 * size * (j == 1 and 1 or 0.7), 0.9 * size * (j == 1 and 1 or 0.7))
			w.Parent = holderModel
			table.insert(list, { part = w, side = side, layer = j })
		end
	end
	return list
end

--[[
parts: { grip = Part, limbs = { Part, ... }, tips = { Part, ... }, holder = Model (where new pieces go),
         scale = number (the pieces' scale: 1 in the world, the viewmodel's in first person) }
opts:  { static = true } paints the grip and limbs (their tokens, the material) once as well (the third-person bow,
       built plain by the server)
]]
function Flair.bow(parts, look, team, opts)
	opts = opts or {}
	local handle = { parts = parts, look = look or {}, team = team, made = {}, wings = nil, guis = nil, nextArc = 0 }
	look = handle.look
	if not parts or not parts.grip then
		function handle.update() end
		function handle.destroy() end
		return handle
	end
	local scale = parts.scale or 1
	if opts.static then
		local ok, mat = pcall(function()
			return Enum.Material[look.material]
		end)
		for _, p in parts.limbs or {} do
			p.Color = Flair.tint(look.limbs, team, 0, 0)
			if ok and mat then
				p.Material = mat
			end
		end
		for _, p in { parts.grip, table.unpack(parts.tips or {}) } do
			p.Color = Flair.tint(look.grip, team, 0, 0)
			if ok and mat then
				p.Material = mat
			end
		end
	end
	-- moving stripes or a rainbow over the limbs
	if look.anim == "stripes" or look.anim == "rainbow" then
		handle.guis = {}
		for _, p in parts.limbs or {} do
			for _, g in gradientSkin(p, look.anim) do
				table.insert(handle.guis, g)
				table.insert(handle.made, g.Parent.Parent)
			end
		end
	end
	if look.anim == "frost" then
		for _, p in parts.limbs or {} do
			p.Transparency = 0.12
		end
	end
	-- particles off the limbs (one emitter per limb; the view model's are smaller)
	if look.particles then
		for _, p in parts.limbs or {} do
			local e = Flair.emitter(p, look.particles)
			if e then
				if scale < 1 then
					e.Size = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0.12),
						NumberSequenceKeypoint.new(1, 0),
					})
					e.Speed = NumberRange.new(0.2, 0.8)
				end
				table.insert(handle.made, e)
			end
		end
	end
	if look.wings then
		handle.wings = wings(parts.holder or parts.grip.Parent, scale)
		for _, w in handle.wings do
			table.insert(handle.made, w.part)
		end
	end

	function handle.update(_, t)
		t = t or os.clock()
		local g = parts.grip
		if not g.Parent then
			return
		end
		if Flair.moving(look.grip) then
			local c = Flair.tint(look.grip, team, t, 0)
			g.Color = c
			for _, p in parts.tips or {} do
				p.Color = c
			end
		end
		if Flair.moving(look.limbs) and not handle.guis then
			for i, p in parts.limbs or {} do
				p.Color = Flair.tint(look.limbs, team, t, i * 0.15)
			end
		end
		if look.anim == "pulse" then
			local k = 0.5 + 0.5 * math.sin(t * 4)
			for i, p in parts.limbs or {} do
				p.Color = Flair.tint(look.limbs, team, t, i * 0.1):Lerp(WHITE, k * 0.35)
			end
		end
		if handle.guis then
			local off = (t * 0.6) % 1
			for _, gr in handle.guis do
				gr.Offset = Vector2.new(0, off - 0.5)
			end
		end
		if look.anim == "electric" and t >= handle.nextArc then
			handle.nextArc = t + rnd(0.08, 0.25)
			local limbs = parts.limbs or {}
			local p = limbs[math.random(1, math.max(1, #limbs))]
			if p and p.Parent then
				local half = p.Size.Y / 2
				local a = (p.CFrame * CFrame.new(0, rnd(-half, half), 0)).Position
				local b = a + Vector3.new(rnd(-1, 1), rnd(-1, 1), rnd(-1, 1)) * 0.6 * scale
				Flair.arc(a, b, NAMED.electric:Lerp(WHITE, 0.5))
			end
		end
		if look.anim == "sparkle" and math.random() < 0.08 then
			local limbs = parts.limbs or {}
			local p = limbs[math.random(1, math.max(1, #limbs))]
			if p and p.Parent then
				local s = Flair.drop("sparkles", p.Position, team)
				if s and scale < 1 then
					s.Size *= 0.5
				end
			end
		end
		if handle.wings then
			local flap = math.sin(t * 3) * 0.35
			for _, w in handle.wings do
				local spread = math.rad(25 + (w.layer == 2 and 12 or 0)) + flap
				w.part.CFrame = g.CFrame
					* CFrame.new(w.side * 0.18 * scale, 0.15 * scale, 0.15 * scale)
					* CFrame.Angles(0, w.side * spread, 0)
					* CFrame.new(0, 0, 0.45 * scale * (w.layer == 1 and 1 or 0.8))
			end
		end
	end

	function handle.destroy()
		for _, inst in handle.made do
			if inst and inst.Parent then
				inst:Destroy()
			end
		end
		handle.made = {}
	end
	return handle
end

-- Banners ---------------------------------------------------------------------------------------------------------
-- An emblem's TextLabel brought to life; part: the flag it's on (fire or sparkles come off it).
function Flair.banner(label, part, anim)
	local handle = { made = {} }
	local base = label.TextColor3
	if anim == "flame" and part then
		local e = Flair.emitter(part, "fire")
		if e then
			e.Rate = Flair.lite() and 6 or 14
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0.1) })
			table.insert(handle.made, e)
		end
	elseif anim == "sparkle" and part then
		local e = Flair.emitter(part, "sparkles", Color3.fromRGB(255, 220, 120))
		if e then
			table.insert(handle.made, e)
		end
	elseif anim == "electric" and part then
		local e = Flair.emitter(part, "sparks")
		if e then
			e.Rate = 8
			table.insert(handle.made, e)
		end
	end
	local scale = Instance.new("UIScale")
	scale.Parent = label
	table.insert(handle.made, scale)
	local seed = math.random() * 10

	function handle.update(_, t)
		t = (t or os.clock()) + seed
		if not label.Parent then
			return
		end
		if anim == "rainbow" then
			label.TextColor3 = Color3.fromHSV((t * 0.3) % 1, 0.75, 1)
		elseif anim == "flame" then
			label.TextColor3 = NAMED.lava:Lerp(NAMED.lavaHot, 0.5 + 0.5 * math.sin(t * 13) * math.sin(t * 7))
			scale.Scale = 1 + 0.06 * math.sin(t * 11)
		elseif anim == "electric" then
			label.TextColor3 = math.random() < 0.15 and WHITE or NAMED.electric
			label.TextTransparency = math.random() < 0.05 and 0.6 or 0
		elseif anim == "pulse" then
			scale.Scale = 1 + 0.12 * math.sin(t * 3)
		elseif anim == "bounce" then
			scale.Scale = 1 + 0.1 * math.abs(math.sin(t * 4))
			label.Rotation = 8 * math.sin(t * 4)
		elseif anim == "spin" then
			label.Rotation = (t * 90) % 360
		elseif anim == "sparkle" then
			label.TextColor3 = base:Lerp(Color3.fromRGB(255, 230, 140), 0.5 + 0.5 * math.sin(t * 3))
			scale.Scale = 1 + 0.05 * math.sin(t * 2)
		end
	end

	function handle.destroy()
		for _, inst in handle.made do
			if inst and inst.Parent then
				inst:Destroy()
			end
		end
		handle.made = {}
		label.TextColor3 = base
		label.Rotation = 0
	end
	return handle
end

return Flair
