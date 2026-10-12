-- Builds a blocky dragon Model from primitive parts. The invisible "Root" part is the PrimaryPart: it sits
-- around the body, carries the prompts and the name tag, and every other part is welded to it, so moving the
-- Root moves the whole dragon. The dragon faces -Z (Roblox's forward).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Dragons = require(ReplicatedStorage.Shared.Data.Dragons)

local DragonBuilder = {}

local ROOT_HALF = 1.75 -- the Root is 3.5 tall; its centre is this far above the feet

-- name, size, offset from the feet centre, colour key, extra rotation (degrees x, y, z)
local PARTS = {
	{ "Body", Vector3.new(2.2, 1.8, 3), Vector3.new(0, 1.6, 0), "body" },
	{ "Belly", Vector3.new(1.7, 1.3, 0.3), Vector3.new(0, 1.45, -1.5), "belly" },
	{ "Head", Vector3.new(1.7, 1.5, 1.6), Vector3.new(0, 2.9, -1.7), "body" },
	{ "Snout", Vector3.new(1.2, 0.8, 0.9), Vector3.new(0, 2.6, -2.85), "body" },
	{ "EyeL", Vector3.new(0.45, 0.5, 0.1), Vector3.new(-0.45, 3.15, -2.53), "white" },
	{ "EyeR", Vector3.new(0.45, 0.5, 0.1), Vector3.new(0.45, 3.15, -2.53), "white" },
	{ "PupilL", Vector3.new(0.22, 0.3, 0.06), Vector3.new(-0.42, 3.1, -2.6), "ink" },
	{ "PupilR", Vector3.new(0.22, 0.3, 0.06), Vector3.new(0.42, 3.1, -2.6), "ink" },
	{ "HornL", Vector3.new(0.3, 0.8, 0.3), Vector3.new(-0.5, 3.95, -1.5), "belly", { -20, 0, 10 } },
	{ "HornR", Vector3.new(0.3, 0.8, 0.3), Vector3.new(0.5, 3.95, -1.5), "belly", { -20, 0, -10 } },
	{ "WingL", Vector3.new(2.4, 0.15, 1.7), Vector3.new(-1.9, 2.75, 0), "wing", { 0, 0, -25 } },
	{ "WingR", Vector3.new(2.4, 0.15, 1.7), Vector3.new(1.9, 2.75, 0), "wing", { 0, 0, 25 } },
	{ "WingTipL", Vector3.new(1.4, 0.15, 1.3), Vector3.new(-3.3, 3.55, 0.2), "wing", { 0, 0, -40 } },
	{ "WingTipR", Vector3.new(1.4, 0.15, 1.3), Vector3.new(3.3, 3.55, 0.2), "wing", { 0, 0, 40 } },
	{ "Tail", Vector3.new(0.9, 0.9, 1.6), Vector3.new(0, 1.3, 2.1), "body" },
	{ "Tail2", Vector3.new(0.6, 0.6, 1.4), Vector3.new(0, 1.65, 3.3), "body", { 20, 0, 0 } },
	{ "TailTip", Vector3.new(0.9, 0.2, 0.9), Vector3.new(0, 1.95, 4.05), "wing", { 0, 45, 0 } },
	{ "Spike1", Vector3.new(0.3, 0.5, 0.5), Vector3.new(0, 2.7, -0.8), "wing" },
	{ "Spike2", Vector3.new(0.3, 0.5, 0.5), Vector3.new(0, 2.7, 0.2), "wing" },
	{ "Spike3", Vector3.new(0.3, 0.5, 0.5), Vector3.new(0, 2.6, 1.2), "wing" },
	{ "LegFL", Vector3.new(0.7, 0.9, 0.7), Vector3.new(-0.75, 0.45, -0.9), "body" },
	{ "LegFR", Vector3.new(0.7, 0.9, 0.7), Vector3.new(0.75, 0.45, -0.9), "body" },
	{ "LegBL", Vector3.new(0.7, 0.9, 0.7), Vector3.new(-0.75, 0.45, 0.9), "body" },
	{ "LegBR", Vector3.new(0.7, 0.9, 0.7), Vector3.new(0.75, 0.45, 0.9), "body" },
}

local WHITE = Color3.fromRGB(255, 255, 255)
local INK = Color3.fromRGB(27, 29, 43)

function DragonBuilder.scaleFor(stage)
	return Constants.STAGE_SCALE[stage] or 1
end

-- Height of the Root centre above the feet for a given scale.
function DragonBuilder.rootHeight(scale)
	return ROOT_HALF * scale
end

-- build(id, special, stage, sizeMult, skin) -> Model. Position it with DragonBuilder.place(model, feetCFrame).
-- sizeMult shrinks a dragon you carry so it doesn't block your view. skin (an entry of Data/Skins) repaints the
-- wings, horns, spikes and belly.
function DragonBuilder.build(id, special, stage, sizeMult, skin)
	local d = Dragons.byId[id]
	local s = DragonBuilder.scaleFor(stage or 1) * (sizeMult or 1)
	local model = Instance.new("Model")
	model.Name = "Dragon_" .. id
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(3, 3.5, 5) * s
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = true
	root.CFrame = CFrame.new(0, ROOT_HALF * s, 0)
	root.Parent = model
	model.PrimaryPart = root
	local colors = { body = d.body, belly = d.belly, wing = d.wing, white = WHITE, ink = INK }
	if special == "GOLD" then
		colors.body, colors.wing = Color3.fromRGB(255, 205, 60), Color3.fromRGB(235, 160, 30)
	elseif special == "ICE" then
		colors.body, colors.wing = Color3.fromRGB(185, 235, 255), Color3.fromRGB(120, 200, 255)
	end
	if skin then
		colors.wing = skin.wing or colors.wing
		colors.belly = skin.belly or colors.belly
	end
	for _, spec in PARTS do
		local name, size, offset, key = spec[1], spec[2], spec[3], spec[4]
		local skip = d.fancy and (name == "HornL" or name == "HornR") and d.horns ~= "normal" and d.horns ~= "big"
		if d.fancy and d.horns == "big" and (name == "HornL" or name == "HornR") then
			size, offset = size * Vector3.new(1.3, 1.5, 1.3), offset + Vector3.new(0, 0.25, 0.1)
		end
		local bigWings = d.fancy and (d.wings == "big" or d.wings == "feather" or d.wings == "crystal")
		if bigWings and name:sub(1, 4) == "Wing" then
			local side = (name:sub(-1) == "L") and -1 or 1
			size = size * Vector3.new(1.45, 1, 1.35)
			offset = Vector3.new(offset.X * 1.4, offset.Y + 0.1, offset.Z) + Vector3.new(side * 0.1, 0, 0)
		end
		if skip then
			continue
		end
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size * s
		local rot = spec[5] or { 0, 0, 0 }
		p.CFrame = root.CFrame
			* CFrame.new((offset - Vector3.new(0, ROOT_HALF, 0)) * s)
			* CFrame.Angles(math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3]))
		p.Color = colors[key]
		p.Material = special == "ICE" and key ~= "ink" and Enum.Material.Glass or Enum.Material.SmoothPlastic
		if special == "GOLD" and (key == "body" or key == "wing") then
			p.Material = Enum.Material.Foil
		end
		if d.fancy and not special then
			-- custom dragons: their own materials, see-through ghosts, glowing eyes
			if key == "body" and d.mat then
				p.Material = Enum.Material[d.mat]
			elseif key == "wing" and d.wingMat then
				p.Material = Enum.Material[d.wingMat]
			end
			if d.alpha and (key == "body" or key == "belly" or key == "wing") then
				p.Transparency = d.alpha
			end
			if d.alphaWing and key == "wing" then
				p.Transparency = d.alphaWing
			end
		end
		if d.fancy and d.eyes then
			if name == "EyeL" or name == "EyeR" then
				p.Color = d.eyes
				p.Material = Enum.Material.Neon
			elseif name == "PupilL" or name == "PupilR" then
				p.Transparency = 1
			end
		end
		if skin and skin.wingMaterial and spec[4] == "wing" then
			p.Material = skin.wingMaterial
		end
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.Massless = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		local w = Instance.new("WeldConstraint")
		w.Part0 = root
		w.Part1 = p
		w.Parent = p
		p.Parent = model
	end
	if d.fancy then
		DragonBuilder._decorate(model, root, d, s, colors)
	end
	-- Specials and rare glow
	local body = model:FindFirstChild("Body")
	if special == "FIRE" then
		local fire = Instance.new("Fire")
		fire.Size = 4 * s
		fire.Heat = 3
		fire.Parent = body
	elseif special == "ICE" or special == "GOLD" or special == "RAINBOW" then
		DragonBuilder.twinkle(body, Dragons.Specials[special].color, s)
	end
	if special == "RAINBOW" or id == "REX" or (d.fancy and table.find(d.fx, "rainbow")) then
		CollectionService:AddTag(model, "RainbowDragon")
	end
	local rank = Dragons.RarityRank[d.rarity]
	if rank >= 4 or special then
		local light = Instance.new("PointLight")
		light.Color = special and Dragons.Specials[special].color or Dragons.RarityColor[d.rarity]
		light.Range = 10 * s
		light.Brightness = 1.5
		light.Parent = body
	end
	model:SetAttribute("DragonId", id)
	model:SetAttribute("Special", special)
	model:SetAttribute("Stage", stage or 1)
	model:SetAttribute("Skin", skin and skin.key or nil)
	model:SetAttribute("Scale", s)
	return model
end

-- Custom dragons ------------------------------------------------------------------------------------------------
-- Extra parts and effects for the custom dragons (Data/FancyDragons.lua). Offsets are from the feet centre in a
-- Baby's studs (like PARTS) and get scaled; the dragon faces -Z. Spinning pieces (orbs, halos, rings) hang on a
-- Weld named "Spin" tagged DragonSpin, which FxController turns on each client; pieces tagged DragonPulse throb.
local TEX = {
	sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	spark = "rbxasset://textures/particles/fire_sparks_main.dds",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
	glow = "rbxasset://textures/particles/forcefield_glow_main.dds",
	vortex = "rbxasset://textures/particles/forcefield_vortex_main.dds",
}

-- A few soft twinkles: used instead of Roblox's Sparkles, whose big stars swamp the screen when many dragons
-- stand together.
function DragonBuilder.twinkle(parent, color, scale)
	scale = scale or 1
	local e = Instance.new("ParticleEmitter")
	e.Name = "Twinkle"
	e.Texture = TEX.sparkle
	e.Color = ColorSequence.new(color)
	e.LightEmission = 0.6
	e.Rate = 2
	e.Size = NumberSequence.new(0.35 * scale, 0)
	e.Speed = NumberRange.new(0.3 * scale, 0.8 * scale)
	e.Lifetime = NumberRange.new(0.6, 1)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Parent = parent
	return e
end

-- Particle effects: texture, colour (a colours key or a Color3), rate, size, speed, lifetime, acceleration, extras
local FX = {
	embers = { "spark", "accent", 10, 0.35, 2, 1.2, Vector3.new(0, 3, 0), { LightEmission = 1, SpreadAngle = 40 } },
	snow = {
		"sparkle",
		Color3.fromRGB(240, 250, 255),
		6,
		0.3,
		0.6,
		2.4,
		Vector3.new(0, -1.5, 0),
		{ SpreadAngle = 180 },
	},
	bubbles = { "glow", Color3.fromRGB(190, 240, 255), 4, 0.45, 1, 2.2, Vector3.new(0, 1.5, 0), { Transparency = 0.4 } },
	stars = { "sparkle", "accent", 6, 0.4, 1.2, 1.6, Vector3.zero, { LightEmission = 1, SpreadAngle = 180 } },
	petals = { "sparkle", "accent", 5, 0.35, 0.8, 2.6, Vector3.new(0, -0.8, 0), { SpreadAngle = 180, RotSpeed = 90 } },
	lightning = {
		"spark",
		Color3.fromRGB(255, 245, 140),
		14,
		0.3,
		6,
		0.25,
		Vector3.zero,
		{ LightEmission = 1, SpreadAngle = 180 },
	},
	void = { "vortex", "accent", 5, 1.2, 0.5, 1.4, Vector3.zero, { LightEmission = 0.6, Transparency = 0.3 } },
	coins = {
		"sparkle",
		Color3.fromRGB(255, 215, 60),
		6,
		0.35,
		1.5,
		1.4,
		Vector3.new(0, -3, 0),
		{ LightEmission = 0.8, SpreadAngle = 60 },
	},
	aura = { "glow", "accent", 3, 2.2, 0.2, 1.6, Vector3.zero, { LightEmission = 0.7, Transparency = 0.55 } },
}

local function mat(name, default)
	return name and Enum.Material[name] or default
end

function DragonBuilder._decorate(model, root, d, s, colors)
	local accent = d.accent or d.belly
	local accentMat = mat(d.accentMat, Enum.Material.SmoothPlastic)
	colors.accent = accent
	local function color(c)
		return typeof(c) == "Color3" and c or colors[c] or accent
	end
	local function add(name, size, offset, c, rot, material, props)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size * s
		rot = rot or { 0, 0, 0 }
		p.CFrame = root.CFrame
			* CFrame.new((offset - Vector3.new(0, ROOT_HALF, 0)) * s)
			* CFrame.Angles(math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3]))
		p.Color = color(c)
		p.Material = material or accentMat
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		p.Massless = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		for k, v in props or {} do
			p[k] = v
		end
		local w = Instance.new("WeldConstraint")
		w.Part0 = root
		w.Part1 = p
		w.Parent = p
		p.Parent = model
		return p
	end
	-- a piece circling at radius r around a vertical axis through (0, y, z), starting at angle a
	local function spinner(name, size, c, material, r, y, z, a, speed, tilt, shape)
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = shape or Enum.PartType.Block
		p.Size = size * s
		p.Color = color(c)
		p.Material = material or Enum.Material.Neon
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		p.Massless = true
		local w = Instance.new("Weld")
		w.Name = "Spin"
		w:SetAttribute("R", r * s)
		w:SetAttribute("Y", (y - ROOT_HALF) * s)
		w:SetAttribute("Z", z * s)
		w:SetAttribute("A", a)
		w:SetAttribute("Speed", speed)
		w:SetAttribute("Tilt", tilt or 0)
		w.C0 = DragonBuilder.spinC0(w, 0)
		w.Part0 = root
		w.Part1 = p
		w.Parent = p
		CollectionService:AddTag(w, "DragonSpin")
		p.Parent = model
		return p
	end
	local function ring(name, count, r, y, z, speed, tilt, seg)
		for i = 1, count do
			local a = (i - 1) / count * math.pi * 2
			spinner(name, seg or Vector3.new(0.35, 0.12, 0.2), "accent", Enum.Material.Neon, r, y, z, a, speed, tilt)
		end
	end
	local pulse = table.find(d.fx, "pulse") ~= nil
	local function glowy(p)
		if pulse then
			CollectionService:AddTag(p, "DragonPulse")
		end
		return p
	end

	-- wing styles
	local wingColor = colors.wing
	for _, side in { -1, 1 } do
		local sd = side == -1 and "L" or "R"
		if d.wings == "butterfly" then
			add(
				"WingLobe" .. sd,
				Vector3.new(1.9, 0.12, 1.6),
				Vector3.new(side * 2.1, 2.35, 1.0),
				"accent",
				{ 0, side * -20, side * 15 },
				nil,
				{
					Transparency = d.alphaWing or 0,
				}
			)
			add(
				"WingDot" .. sd,
				Vector3.new(0.6, 0.14, 0.6),
				Vector3.new(side * 2.5, 2.95, 0.1),
				"belly",
				{ 0, 0, side * 25 }
			)
		elseif d.wings == "bat" then
			for i, z in { -0.4, 0.3, 1.0 } do
				add(
					"WingBone" .. sd .. i,
					Vector3.new(0.14, 0.14, 1.9),
					Vector3.new(side * (1.6 + i * 0.7), 2.85 + i * 0.25, z * 0.4),
					wingColor:Lerp(Color3.new(0, 0, 0), 0.4),
					{ 0, side * (i * 12), side * 25 },
					Enum.Material.SmoothPlastic
				)
			end
		elseif d.wings == "feather" then
			local light = wingColor:Lerp(Color3.new(1, 1, 1), 0.35)
			for i = 1, 3 do
				add(
					"Feather" .. sd .. i,
					Vector3.new(3.4 - i * 0.6, 0.12, 0.55),
					Vector3.new(side * (2.4 - i * 0.15), 2.7 - i * 0.12, 0.9 + i * 0.4),
					i % 2 == 0 and wingColor or light,
					{ 0, side * -8, side * 25 },
					mat(d.wingMat, Enum.Material.SmoothPlastic)
				)
			end
		elseif d.wings == "crystal" then
			add(
				"WingEdge" .. sd,
				Vector3.new(3.5, 0.2, 0.18),
				Vector3.new(side * 2.7, 2.95, -1.05),
				"accent",
				{ 0, 0, side * 25 },
				Enum.Material.Neon
			)
			glowy(
				add(
					"WingShard" .. sd,
					Vector3.new(0.35, 1.1, 0.35),
					Vector3.new(side * 4.6, 4.5, 0.2),
					"accent",
					{ 0, 0, side * -20 },
					Enum.Material.Neon
				)
			)
		end
	end
	-- horn styles
	if d.horns == "unicorn" then
		add(
			"UnicornHorn",
			Vector3.new(0.28, 1.5, 0.28),
			Vector3.new(0, 4.25, -2.15),
			"accent",
			{ -28, 0, 0 },
			Enum.Material.Neon
		)
		add(
			"HornBase",
			Vector3.new(0.45, 0.25, 0.45),
			Vector3.new(0, 3.68, -1.85),
			"belly",
			{ -28, 0, 0 },
			Enum.Material.Foil
		)
	elseif d.horns == "antlers" then
		for _, side in { -1, 1 } do
			local c = colors.belly:Lerp(Color3.fromRGB(120, 80, 50), 0.5)
			add(
				"Antler",
				Vector3.new(0.18, 1.1, 0.18),
				Vector3.new(side * 0.6, 4.1, -1.5),
				c,
				{ 0, 0, side * -25 },
				Enum.Material.Wood
			)
			add(
				"Antler",
				Vector3.new(0.15, 0.6, 0.15),
				Vector3.new(side * 0.95, 4.4, -1.5),
				c,
				{ 0, 0, side * -65 },
				Enum.Material.Wood
			)
			add(
				"Antler",
				Vector3.new(0.15, 0.55, 0.15),
				Vector3.new(side * 0.55, 4.55, -1.35),
				c,
				{ -20, 0, side * -5 },
				Enum.Material.Wood
			)
		end
	elseif d.horns == "big" then
		for _, side in { -1, 1 } do
			add(
				"HornTip",
				Vector3.new(0.28, 0.7, 0.28),
				Vector3.new(side * 0.7, 4.75, -0.95),
				"belly",
				{ -70, 0, side * -15 },
				Enum.Material.SmoothPlastic
			)
		end
	end

	-- extras
	for _, extra in d.extras do
		if extra == "crown" then
			add(
				"Crown",
				Vector3.new(1.45, 0.35, 1.35),
				Vector3.new(0, 3.82, -1.7),
				Color3.fromRGB(255, 205, 50),
				nil,
				Enum.Material.Foil
			)
			for i = -2, 2 do
				add(
					"CrownSpike",
					Vector3.new(0.24, 0.5, 0.24),
					Vector3.new(i * 0.3, 4.2, -2.3),
					Color3.fromRGB(255, 205, 50),
					nil,
					Enum.Material.Foil
				)
			end
			glowy(
				add(
					"CrownGem",
					Vector3.new(0.3, 0.3, 0.1),
					Vector3.new(0, 3.85, -2.42),
					"accent",
					{ 0, 0, 45 },
					Enum.Material.Neon
				)
			)
		elseif extra == "halo" then
			ring("Halo", 10, 0.85, 4.75, -1.7, 1.5, 0)
		elseif extra == "orbs" then
			for i = 1, 3 do
				local orb = spinner(
					"Orb",
					Vector3.new(0.6, 0.6, 0.6),
					"accent",
					Enum.Material.Neon,
					3.1,
					3.1,
					0,
					(i - 1) * math.pi * 2 / 3,
					1.2,
					0,
					Enum.PartType.Ball
				)
				glowy(orb)
			end
		elseif extra == "ring" then
			ring("Ring", 18, 2.8, 1.9, 0, 0.6, 0.35, Vector3.new(0.75, 0.1, 0.28))
		elseif extra == "mane" then
			for i, spec in
				{ { -0.95, 2.6, 40 }, { -0.7, 3.4, 22 }, { 0, 3.78, 0 }, { 0.7, 3.4, -22 }, { 0.95, 2.6, -40 } }
			do
				add(
					"Mane" .. i,
					Vector3.new(0.45, 0.95, 0.35),
					Vector3.new(spec[1], spec[2], -0.95),
					"accent",
					{ 0, 0, spec[3] }
				)
			end
		elseif extra == "fins" then
			for i, z in { -0.8, 0.2, 1.2 } do
				add(
					"Fin" .. i,
					Vector3.new(0.14, 1.2 - i * 0.15, 0.95),
					Vector3.new(0, 3.0 - i * 0.05, z),
					"accent",
					{ -15, 0, 0 }
				)
			end
			for _, side in { -1, 1 } do
				add(
					"EarFin",
					Vector3.new(0.12, 0.65, 0.75),
					Vector3.new(side * 0.92, 3.15, -1.5),
					"accent",
					{ 0, 0, side * -35 }
				)
			end
		elseif extra == "gem" then
			glowy(
				add(
					"Gem",
					Vector3.new(0.42, 0.42, 0.12),
					Vector3.new(0, 3.42, -2.52),
					"accent",
					{ 0, 0, 45 },
					Enum.Material.Neon
				)
			)
		elseif extra == "stripes" then
			for i, z in { -0.85, 0, 0.85 } do
				glowy(add("Stripe" .. i, Vector3.new(2.28, 1.86, 0.32), Vector3.new(0, 1.6, z), "accent"))
			end
		elseif extra == "spots" then
			for i, spot in
				{
					{ 1.12, 1.85, -0.6, "x" },
					{ -1.12, 1.6, 0.6, "x" },
					{ 1.12, 1.4, 0.8, "x" },
					{ -1.12, 2.0, -0.7, "x" },
					{ 0.45, 2.52, -0.2, "y" },
					{ -0.4, 2.52, 0.9, "y" },
				}
			do
				local size = spot[4] == "x" and Vector3.new(0.08, 0.45, 0.45) or Vector3.new(0.45, 0.08, 0.45)
				glowy(add("Spot" .. i, size, Vector3.new(spot[1], spot[2], spot[3]), "accent"))
			end
		elseif extra == "tailflame" then
			local flame = add(
				"TailFlame",
				Vector3.new(0.6, 0.6, 0.6),
				Vector3.new(0, 2.15, 4.35),
				"accent",
				{ 45, 45, 0 },
				Enum.Material.Neon
			)
			local fire = Instance.new("Fire")
			fire.Size = 2.5 * s
			fire.Heat = 4
			fire.Color = accent
			fire.SecondaryColor = colors.belly
			fire.Parent = flame
		elseif extra == "backflame" then
			for _, side in { -1, 1 } do
				local f = glowy(
					add(
						"BackFlame",
						Vector3.new(0.45, 1.0, 0.45),
						Vector3.new(side * 0.5, 2.95, 0.7),
						"accent",
						{ 20, 0, side * -10 },
						Enum.Material.Neon
					)
				)
				local fire = Instance.new("Fire")
				fire.Size = 1.8 * s
				fire.Heat = 3
				fire.Color = accent
				fire.SecondaryColor = colors.body
				fire.Parent = f
			end
		elseif extra == "armor" then
			local steel = Color3.fromRGB(170, 176, 188)
			for i, z in { -0.9, 0, 0.9 } do
				add(
					"Armor" .. i,
					Vector3.new(2.05, 0.25, 0.8),
					Vector3.new(0, 2.55, z),
					steel,
					nil,
					Enum.Material.DiamondPlate
				)
			end
			add(
				"ChestPlate",
				Vector3.new(1.85, 0.95, 0.15),
				Vector3.new(0, 1.5, -1.62),
				steel,
				nil,
				Enum.Material.DiamondPlate
			)
			add(
				"ChestEmblem",
				Vector3.new(0.5, 0.5, 0.06),
				Vector3.new(0, 1.55, -1.72),
				"accent",
				{ 0, 0, 45 },
				Enum.Material.Neon
			)
		elseif extra == "beard" then
			add("Beard", Vector3.new(0.85, 0.7, 0.35), Vector3.new(0, 2.0, -2.75), "accent", { 10, 0, 0 })
		elseif extra == "tusks" then
			for _, side in { -1, 1 } do
				add(
					"Tusk",
					Vector3.new(0.18, 0.65, 0.18),
					Vector3.new(side * 0.45, 2.1, -3.15),
					Color3.fromRGB(250, 245, 230),
					{ 25, 0, 0 },
					Enum.Material.SmoothPlastic
				)
			end
		elseif extra == "antenna" then
			for _, side in { -1, 1 } do
				add(
					"Antenna",
					Vector3.new(0.1, 0.9, 0.1),
					Vector3.new(side * 0.4, 4.1, -1.9),
					Color3.fromRGB(40, 40, 50),
					{ -15, 0, side * -20 },
					Enum.Material.SmoothPlastic
				)
				glowy(
					add(
						"AntennaTip",
						Vector3.new(0.32, 0.32, 0.32),
						Vector3.new(side * 0.56, 4.55, -2.0),
						"accent",
						nil,
						Enum.Material.Neon,
						{
							Shape = Enum.PartType.Ball,
						}
					)
				)
			end
		elseif extra == "mask" then
			add("Mask", Vector3.new(1.75, 0.42, 0.06), Vector3.new(0, 3.13, -2.52), "accent")
		elseif extra == "spikes_big" then
			for i, z in { -0.8, 0.2, 1.2, 2.2 } do
				add(
					"BigSpike" .. i,
					Vector3.new(0.4, 0.95, 0.7),
					Vector3.new(0, 2.95 - (i == 4 and 0.9 or 0), z),
					"accent",
					{ -20, 0, 0 }
				)
			end
		elseif extra == "leaves" then
			local leaf = Color3.fromRGB(90, 190, 80)
			for i, spec in
				{ { -0.8, 2.6, 0.4, 30 }, { 0.8, 2.6, -0.3, -30 }, { -0.5, 2.6, 1.2, 50 }, { 0.6, 2.6, 1.0, -50 } }
			do
				add(
					"Leaf" .. i,
					Vector3.new(0.7, 0.08, 0.4),
					Vector3.new(spec[1], spec[2], spec[3]),
					leaf,
					{ 0, spec[4], 10 },
					Enum.Material.Grass
				)
			end
		elseif extra == "icicles" then
			for i, spec in { { -1.9, 0.4 }, { -2.6, -0.2 }, { 1.9, 0.4 }, { 2.6, -0.2 } } do
				add(
					"Icicle" .. i,
					Vector3.new(0.16, 0.6, 0.16),
					Vector3.new(spec[1] * (d.wings == "crystal" and 1.3 or 1), 2.25, spec[2]),
					Color3.fromRGB(200, 245, 255),
					nil,
					Enum.Material.Glass
				)
			end
		end
	end

	-- effects
	local body = model:FindFirstChild("Body")
	for _, fx in d.fx do
		local spec = FX[fx]
		if spec then
			local e = Instance.new("ParticleEmitter")
			e.Name = "Fx_" .. fx
			e.Texture = TEX[spec[1]]
			local c = color(spec[2])
			e.Color = ColorSequence.new(c)
			e.Rate = math.max(1, spec[3] * 0.5) -- (kept low: a base full of dragons adds up)
			e.Size = NumberSequence.new(spec[4] * s, 0)
			e.Speed = NumberRange.new(spec[5] * s * 0.5, spec[5] * s)
			e.Lifetime = NumberRange.new(spec[6] * 0.7, spec[6])
			e.Acceleration = spec[7] * s
			for k, v in spec[8] do
				if k == "RotSpeed" then
					e.RotSpeed = NumberRange.new(-v, v)
				elseif k == "Transparency" then
					e.Transparency = NumberSequence.new(v, 1)
				elseif k == "SpreadAngle" then
					e.SpreadAngle = Vector2.new(v, v)
				else
					e[k] = v
				end
			end
			e.Parent = body
		elseif fx == "fire" then
			local fire = Instance.new("Fire")
			fire.Size = 3 * s
			fire.Heat = 4
			fire.Color = accent
			fire.SecondaryColor = colors.belly
			fire.Parent = body
		elseif fx == "smoke" then
			local smoke = Instance.new("Smoke")
			smoke.Color = colors.belly
			smoke.Opacity = 0.08
			smoke.RiseVelocity = 1.5
			smoke.Size = 1.5 * s
			smoke.Parent = body
		elseif fx == "sparkles" then
			DragonBuilder.twinkle(body, accent, s)
		elseif fx == "glow" then
			local light = Instance.new("PointLight")
			light.Name = "FancyGlow"
			light.Color = accent
			light.Range = 12 * s
			light.Brightness = 2
			light.Parent = body
		elseif fx == "trail" then
			local tip = model:FindFirstChild("TailTip")
			if tip then
				local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
				a0.Position = Vector3.new(0.4 * s, 0, 0)
				a1.Position = Vector3.new(-0.4 * s, 0, 0)
				a0.Parent, a1.Parent = tip, tip
				local trail = Instance.new("Trail")
				trail.Attachment0, trail.Attachment1 = a0, a1
				trail.Color = ColorSequence.new(accent)
				trail.LightEmission = 0.8
				trail.Lifetime = 0.45
				trail.Transparency = NumberSequence.new(0.2, 1)
				trail.Parent = tip
			end
		end
	end
	model:SetAttribute("Fancy", true)
end

-- The Weld C0 of a spinning piece at time t (FxController calls this every frame on each client).
function DragonBuilder.spinC0(w, t)
	local a = (w:GetAttribute("A") or 0) + t * (w:GetAttribute("Speed") or 1)
	return CFrame.new(0, w:GetAttribute("Y") or 0, w:GetAttribute("Z") or 0)
		* CFrame.Angles(w:GetAttribute("Tilt") or 0, 0, 0)
		* CFrame.Angles(0, a, 0)
		* CFrame.new(w:GetAttribute("R") or 0, 0, 0)
end

-- Put the dragon's feet at feetCFrame (its facing comes from feetCFrame's rotation).
function DragonBuilder.place(model, feetCFrame)
	local s = model:GetAttribute("Scale") or 1
	model:PivotTo(feetCFrame * CFrame.new(0, ROOT_HALF * s, 0))
end

-- A floating name tag: line 1 in the rarity colour, line 2 underneath.
function DragonBuilder.label(model, line1, color, line2, color2)
	local root = model.PrimaryPart
	local s = model:GetAttribute("Scale") or 1
	local gui = root:FindFirstChild("Tag")
	if not gui then
		gui = Instance.new("BillboardGui")
		gui.Name = "Tag"
		-- small and only when you're close: a base full of dragons would otherwise be a wall of names
		gui.Size = UDim2.new(5, 0, 1.7, 0)
		gui.StudsOffset = Vector3.new(0, 2.4 * s + 1.2, 0)
		gui.MaxDistance = 30
		gui.LightInfluence = 0
		gui.Parent = root
		for i, name in { "Line1", "Line2" } do
			local t = Instance.new("TextLabel")
			t.Name = name
			t.BackgroundTransparency = 1
			-- the top line (a nest dragon's level) a bit bigger than the second
			t.Size = UDim2.new(1, 0, i == 1 and 0.56 or 0.44, 0)
			t.Position = UDim2.new(0, 0, (i - 1) * 0.56, 0)
			t.Font = i == 1 and Enum.Font.LuckiestGuy or Enum.Font.FredokaOne
			t.TextScaled = true
			t.TextStrokeTransparency = 0
			t.TextStrokeColor3 = INK
			t.TextColor3 = WHITE
			t.Parent = gui
		end
	end
	gui.Line1.Text = line1
	gui.Line1.TextColor3 = color or WHITE
	gui.Line2.Text = line2 or ""
	gui.Line2.TextColor3 = color2 or WHITE
	return gui
end

return DragonBuilder
