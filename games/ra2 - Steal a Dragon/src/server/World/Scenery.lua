-- Scenery pieces built from plain parts: trees, rocks, flowers, mountains, clouds, lanterns, castle towers,
-- flags and the lobby's golden dragon statue. Small decorations don't cast shadows, to keep phones fast.
--
-- Brick style (Constants.BRICK_STYLE): like most top Roblox games, the world is made of shiny plastic bricks with
-- Roblox's classic studs on top. Stone, wood, grass and fabric become plain plastic in the same colour, and every
-- block gets SurfaceType.Studs on top (Inlet underneath). Neon, foil and glass keep their glow and shine.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)

local Scenery = {}

local TO_PLASTIC = {
	[Enum.Material.SmoothPlastic] = true,
	[Enum.Material.Cobblestone] = true,
	[Enum.Material.Slate] = true,
	[Enum.Material.Grass] = true,
	[Enum.Material.WoodPlanks] = true,
	[Enum.Material.Wood] = true,
	[Enum.Material.Fabric] = true,
	[Enum.Material.Marble] = true,
	[Enum.Material.Pavement] = true,
	[Enum.Material.Snow] = true,
}

-- Turn a part into a plastic brick with studs on top (blocks only; balls and cylinders just become plastic).
function Scenery.brick(p)
	if not Constants.BRICK_STYLE then
		return p
	end
	if TO_PLASTIC[p.Material] then
		p.Material = Enum.Material.Plastic
	end
	if p.Material == Enum.Material.Plastic and (p.Shape == nil or p.Shape == Enum.PartType.Block) then
		p.TopSurface = Enum.SurfaceType.Studs
		p.BottomSurface = Enum.SurfaceType.Inlet
	end
	return p
end

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
Scenery.rgb = rgb

function Scenery.part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		if k ~= "Parent" then
			p[k] = v
		end
	end
	Scenery.brick(p)
	p.Parent = props.Parent
	return p
end
local part = Scenery.part

-- A cylinder standing up (Roblox cylinders lie along X, so turn it).
function Scenery.disc(parent, name, center, diameter, height, color, material, extra)
	local props = {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Parent = parent,
	}
	for k, v in extra or {} do
		props[k] = v
	end
	return part(props)
end
local disc = Scenery.disc

function Scenery.ball(parent, name, center, diameter, color, material, extra)
	local props = {
		Name = name,
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(diameter, diameter, diameter),
		CFrame = CFrame.new(center),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Parent = parent,
	}
	for k, v in extra or {} do
		props[k] = v
	end
	return part(props)
end
local ball = Scenery.ball

-- A cone made of stacked discs (base at `base`, pointing up).
function Scenery.cone(parent, name, base, diameter, height, color, steps, material)
	steps = steps or 4
	for i = 1, steps do
		local t = (i - 1) / steps
		local h = height / steps
		disc(
			parent,
			name,
			base + Vector3.new(0, h * (i - 0.5), 0),
			diameter * (1 - t * 0.85),
			h,
			color,
			material,
			{ CastShadow = i == 1 }
		)
	end
end

local LEAF_GREENS = { rgb(70, 170, 80), rgb(95, 190, 85), rgb(55, 150, 75), rgb(120, 200, 90) }

function Scenery.roundTree(parent, pos, scale, rng)
	scale = scale or 1
	local green = LEAF_GREENS[rng:NextInteger(1, #LEAF_GREENS)]
	part({
		Name = "Trunk",
		Size = Vector3.new(1.4, 7, 1.4) * scale,
		CFrame = CFrame.new(pos + Vector3.new(0, 3.5 * scale, 0)),
		Color = rgb(125, 85, 55),
		Material = Enum.Material.Wood,
		Parent = parent,
	})
	ball(parent, "Leaves", pos + Vector3.new(0, 8.5 * scale, 0), 7.5 * scale, green)
	ball(parent, "Leaves", pos + Vector3.new(2.2, 7.4, 1.2) * scale, 5 * scale, green:Lerp(rgb(255, 255, 255), 0.08))
	ball(parent, "Leaves", pos + Vector3.new(-2, 7.8, -1.4) * scale, 5.4 * scale, green:Lerp(rgb(0, 0, 0), 0.08))
end

function Scenery.pineTree(parent, pos, scale)
	scale = scale or 1
	part({
		Name = "Trunk",
		Size = Vector3.new(1.2, 4, 1.2) * scale,
		CFrame = CFrame.new(pos + Vector3.new(0, 2 * scale, 0)),
		Color = rgb(110, 75, 50),
		Material = Enum.Material.Wood,
		Parent = parent,
	})
	local green = rgb(45, 130, 80)
	for i, layer in { { 8, 3 }, { 6.4, 6 }, { 4.6, 9 }, { 2.8, 11.6 } } do
		disc(
			parent,
			"Needles",
			pos + Vector3.new(0, layer[2] * scale, 0),
			layer[1] * scale,
			3 * scale,
			green:Lerp(rgb(255, 255, 255), i * 0.03),
			nil,
			{ CastShadow = i <= 2 }
		)
	end
end

function Scenery.rock(parent, pos, size, rng)
	local p = part({
		Name = "Rock",
		Size = Vector3.new(
			size * rng:NextNumber(0.9, 1.4),
			size * rng:NextNumber(0.6, 0.9),
			size * rng:NextNumber(0.9, 1.3)
		),
		CFrame = CFrame.new(pos + Vector3.new(0, size * 0.25, 0))
			* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6.28), rng:NextNumber(-0.3, 0.3)),
		Color = rgb(140, 138, 150):Lerp(rgb(110, 105, 120), rng:NextNumber()),
		Material = Enum.Material.Slate,
		Parent = parent,
	})
	return p
end

local FLOWER_COLORS =
	{ rgb(255, 90, 120), rgb(255, 210, 60), rgb(255, 255, 255), rgb(190, 110, 255), rgb(255, 140, 60) }

function Scenery.flowers(parent, pos, count, rng)
	for _ = 1, count do
		local offset = Vector3.new(rng:NextNumber(-2.5, 2.5), 0.45, rng:NextNumber(-2.5, 2.5))
		ball(
			parent,
			"Flower",
			pos + offset,
			0.9,
			FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)],
			nil,
			{ CastShadow = false, CanCollide = false }
		)
	end
	ball(parent, "Bush", pos + Vector3.new(0, 0.4, 0), 2.6, rgb(80, 165, 75), nil, { CastShadow = false })
end

function Scenery.mountain(parent, pos, size, rng)
	local rock = rgb(125, 130, 140):Lerp(rgb(105, 120, 110), rng:NextNumber())
	ball(parent, "Mountain", pos, size, rock, Enum.Material.Slate)
	ball(
		parent,
		"Mountain",
		pos + Vector3.new(size * 0.3, -size * 0.12, size * 0.1),
		size * 0.75,
		rock:Lerp(rgb(0, 0, 0), 0.08),
		Enum.Material.Slate
	)
	ball(parent, "Snow", pos + Vector3.new(0, size * 0.38, 0), size * 0.36, rgb(245, 248, 255), Enum.Material.Snow)
end

function Scenery.cloud(parent, pos, scale)
	for _, b in { { 0, 0, 0, 14 }, { 9, -1, 2, 10 }, { -9, -1, -1, 11 }, { 3, 3, -2, 9 } } do
		ball(
			parent,
			"Cloud",
			pos + Vector3.new(b[1], b[2], b[3]) * scale,
			b[4] * scale,
			rgb(255, 255, 255),
			nil,
			{ CastShadow = false, CanCollide = false, Transparency = 0.05 }
		)
	end
end

-- A lantern on a post with a warm light.
function Scenery.lantern(parent, pos, height)
	height = height or 9
	part({
		Name = "Post",
		Size = Vector3.new(0.8, height, 0.8),
		CFrame = CFrame.new(pos + Vector3.new(0, height / 2, 0)),
		Color = rgb(60, 45, 40),
		Material = Enum.Material.Wood,
		Parent = parent,
	})
	part({
		Name = "Cap",
		Size = Vector3.new(2, 0.4, 2),
		CFrame = CFrame.new(pos + Vector3.new(0, height + 1.9, 0)),
		Color = rgb(60, 45, 40),
		Parent = parent,
	})
	local glow = part({
		Name = "Lantern",
		Size = Vector3.new(1.5, 1.8, 1.5),
		CFrame = CFrame.new(pos + Vector3.new(0, height + 0.8, 0)),
		Color = rgb(255, 200, 90),
		Material = Enum.Material.Neon,
		CastShadow = false,
		Parent = parent,
	})
	local light = Instance.new("PointLight")
	light.Color = rgb(255, 190, 110)
	light.Range = 18
	light.Brightness = 1.2
	light.Parent = glow
end

-- A flag on a pole: pos is the bottom of the pole.
function Scenery.flag(parent, pos, height, color, facing)
	part({
		Name = "FlagPole",
		Size = Vector3.new(0.35, height, 0.35),
		CFrame = CFrame.new(pos + Vector3.new(0, height / 2, 0)),
		Color = rgb(235, 235, 240),
		Parent = parent,
	})
	part({
		Name = "Flag",
		Size = Vector3.new(0.15, 2.2, 3.6),
		CFrame = CFrame.new(pos + Vector3.new(0, height - 1.3, 0))
			* CFrame.Angles(0, facing or 0, 0)
			* CFrame.new(0, 0, -1.9),
		Color = color,
		CastShadow = false,
		Parent = parent,
	})
end

-- A round castle tower with a pointed roof and a flag.
function Scenery.tower(parent, pos, diameter, height, stone, roof, flagColor)
	disc(parent, "Tower", pos + Vector3.new(0, height / 2, 0), diameter, height, stone, Enum.Material.Cobblestone)
	disc(
		parent,
		"TowerTop",
		pos + Vector3.new(0, height + 0.5, 0),
		diameter + 1.2,
		1,
		stone:Lerp(rgb(0, 0, 0), 0.1),
		Enum.Material.Cobblestone
	)
	Scenery.cone(parent, "Roof", pos + Vector3.new(0, height + 1, 0), diameter + 1.6, diameter * 1.1, roof, 4)
	Scenery.flag(parent, pos + Vector3.new(0, height + 1 + diameter * 1.1 - 0.5, 0), 4, flagColor or roof)
end

return Scenery
