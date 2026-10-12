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

local FLOWER_DOTS = { rgb(255, 90, 120), rgb(255, 210, 60), rgb(255, 255, 255), rgb(190, 110, 255) }
local LEAF_GREENS = { rgb(70, 170, 80), rgb(95, 190, 85), rgb(55, 150, 75), rgb(120, 200, 90) }

-- A leafy tree: a trunk that flares at the roots and forks into two branches, under a crown of overlapping leaf
-- balls in light and dark shades (lit from above), sometimes with fruit or blossom dots.
function Scenery.roundTree(parent, pos, scale, rng)
	scale = scale or 1
	local green = LEAF_GREENS[rng:NextInteger(1, #LEAF_GREENS)]
	local bark = rgb(125, 85, 55):Lerp(rgb(95, 65, 45), rng:NextNumber())
	part({
		Name = "Trunk",
		Size = Vector3.new(1.4, 7, 1.4) * scale,
		CFrame = CFrame.new(pos + Vector3.new(0, 3.5 * scale, 0)),
		Color = bark,
		Material = Enum.Material.Wood,
		Parent = parent,
	})
	part({
		Name = "Roots",
		Size = Vector3.new(2.4, 0.8, 2.4) * scale,
		CFrame = CFrame.new(pos + Vector3.new(0, 0.4 * scale, 0)) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0),
		Color = bark:Lerp(rgb(0, 0, 0), 0.15),
		Material = Enum.Material.Wood,
		CastShadow = false,
		Parent = parent,
	})
	for _, side in { -1, 1 } do
		part({
			Name = "Branch",
			Size = Vector3.new(0.7, 3.2, 0.7) * scale,
			CFrame = CFrame.new(pos + Vector3.new(side * 0.9, 6.4, 0) * scale) * CFrame.Angles(0, 0, side * -0.6),
			Color = bark,
			Material = Enum.Material.Wood,
			CastShadow = false,
			Parent = parent,
		})
	end
	local leaves = {
		{ 0, 8.6, 0, 7.4, 0 },
		{ 2.4, 7.6, 1.2, 5.2, 0.08 },
		{ -2.2, 7.9, -1.4, 5.4, -0.1 },
		{ 1.0, 10.2, -1.0, 4.8, 0.16 },
		{ -1.4, 9.8, 1.5, 4.4, 0.12 },
		{ 0.4, 7.2, -2.4, 4.2, -0.06 },
	}
	for i, l in leaves do
		local shade = l[5] >= 0 and green:Lerp(rgb(255, 255, 230), l[5]) or green:Lerp(rgb(0, 0, 0), -l[5])
		ball(parent, "Leaves", pos + Vector3.new(l[1], l[2], l[3]) * scale, l[4] * scale, shade, nil, {
			CastShadow = i <= 2,
		})
	end
	if rng:NextNumber() < 0.35 then
		local dot = ({ rgb(255, 80, 80), rgb(255, 160, 200), rgb(255, 200, 60) })[rng:NextInteger(1, 3)]
		for _ = 1, 5 do
			local a = rng:NextNumber(0, math.pi * 2)
			ball(
				parent,
				"Fruit",
				pos + Vector3.new(math.cos(a) * 3.3, rng:NextNumber(7, 10), math.sin(a) * 3.3) * scale,
				0.7 * scale,
				dot,
				nil,
				{ CastShadow = false, CanCollide = false }
			)
		end
	end
end

-- A pine: five tiers of needles, each a little lighter, on a short trunk; a dusting of snow on top now and then.
function Scenery.pineTree(parent, pos, scale, snowy)
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
	local tiers = { { 8.4, 2.8 }, { 7, 5.2 }, { 5.6, 7.6 }, { 4.2, 9.8 }, { 2.6, 12 } }
	for i, layer in tiers do
		disc(
			parent,
			"Needles",
			pos + Vector3.new(0, layer[2] * scale, 0),
			layer[1] * scale,
			2.6 * scale,
			green:Lerp(rgb(255, 255, 255), i * 0.035),
			nil,
			{ CastShadow = i <= 2 }
		)
	end
	if snowy then
		disc(
			parent,
			"Snow",
			pos + Vector3.new(0, 13.2 * scale, 0),
			1.6 * scale,
			1 * scale,
			rgb(245, 250, 255),
			Enum.Material.Snow
		)
	end
end

-- A round bush: a cluster of leaf balls in two shades over a darker base, with a few flowers or berries.
function Scenery.bush(parent, pos, scale, rng, dotColor)
	scale = scale or 1
	local green = rgb(80, 165, 75):Lerp(rgb(60, 140, 70), rng:NextNumber())
	for i, b in
		{
			{ 0, 1.1, 0, 2.8 },
			{ 1.2, 0.9, 0.4, 2.1 },
			{ -1.1, 0.9, -0.3, 2.2 },
			{ 0.3, 0.8, 1.1, 1.9 },
			{ -0.4, 1.8, -0.2, 1.8 },
		}
	do
		ball(
			parent,
			"Bush",
			pos + Vector3.new(b[1], b[2], b[3]) * scale,
			b[4] * scale,
			i == 5 and green:Lerp(rgb(255, 255, 230), 0.12) or (i % 2 == 0 and green:Lerp(rgb(0, 0, 0), 0.1) or green),
			nil,
			{ CastShadow = i == 1 }
		)
	end
	local dot = dotColor or FLOWER_DOTS[rng:NextInteger(1, #FLOWER_DOTS)]
	for _ = 1, 4 do
		local a = rng:NextNumber(0, math.pi * 2)
		ball(
			parent,
			"Berry",
			pos + Vector3.new(math.cos(a) * 1.35, rng:NextNumber(1.0, 2.1), math.sin(a) * 1.35) * scale,
			0.45 * scale,
			dot,
			nil,
			{ CastShadow = false, CanCollide = false }
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
	-- a smaller stone leaning on it, and moss on top
	part({
		Name = "Rock",
		Size = p.Size * Vector3.new(0.5, 0.55, 0.45),
		CFrame = p.CFrame * CFrame.new(p.Size.X * 0.45, -p.Size.Y * 0.2, p.Size.Z * 0.2) * CFrame.Angles(0, 0.7, 0.2),
		Color = p.Color:Lerp(rgb(0, 0, 0), 0.1),
		Material = Enum.Material.Slate,
		CastShadow = false,
		Parent = parent,
	})
	part({
		Name = "Moss",
		Size = Vector3.new(p.Size.X * 0.7, 0.2, p.Size.Z * 0.6),
		CFrame = p.CFrame * CFrame.new(0, p.Size.Y / 2 + 0.05, 0),
		Color = rgb(95, 160, 80),
		Material = Enum.Material.Grass,
		CastShadow = false,
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
	Scenery.bush(parent, pos + Vector3.new(0, -0.3, 0), 0.75, rng)
end

-- A mountain: a main peak with two rocky shoulders and green foothills, a snow cap with snow running down its
-- ridges, and pines around its foot.
function Scenery.mountain(parent, pos, size, rng)
	local rock = rgb(125, 130, 140):Lerp(rgb(105, 120, 110), rng:NextNumber())
	local quiet = { CastShadow = false }
	ball(parent, "Mountain", pos, size, rock, Enum.Material.Slate, quiet)
	for _, sh in
		{ { 0.32, -0.12, 0.1, 0.75, 0.08 }, { -0.3, -0.16, -0.12, 0.68, -0.06 }, { 0.05, -0.2, 0.34, 0.6, 0.12 } }
	do
		ball(
			parent,
			"Mountain",
			pos + Vector3.new(sh[1], sh[2], sh[3]) * size,
			size * sh[4],
			sh[5] >= 0 and rock:Lerp(rgb(0, 0, 0), sh[5]) or rock:Lerp(rgb(255, 255, 255), -sh[5]),
			Enum.Material.Slate,
			quiet
		)
	end
	-- green foothills
	for k = 1, 4 do
		local a = rng:NextNumber(0, math.pi * 2)
		ball(
			parent,
			"Foothill",
			pos + Vector3.new(math.cos(a) * size * 0.45, -size * 0.05, math.sin(a) * size * 0.45),
			size * rng:NextNumber(0.4, 0.55),
			rgb(90, 160, 85):Lerp(rgb(70, 130, 75), k / 4),
			Enum.Material.Grass,
			quiet
		)
	end
	-- snow cap and streaks down the ridges
	ball(
		parent,
		"Snow",
		pos + Vector3.new(0, size * 0.38, 0),
		size * 0.36,
		rgb(245, 248, 255),
		Enum.Material.Snow,
		quiet
	)
	for _, st in { { 0.12, 0.3, 0.1 }, { -0.1, 0.28, -0.08 }, { 0.02, 0.27, 0.15 } } do
		ball(
			parent,
			"Snow",
			pos + Vector3.new(st[1], st[2], st[3]) * size,
			size * 0.2,
			rgb(235, 242, 255),
			Enum.Material.Snow,
			quiet
		)
	end
	-- a few pines at its sides (not on the side facing the middle of the map, where they'd crowd the play area)
	local out = math.atan2(pos.Z, pos.X + 25)
	for k = 1, 3 do
		local a = out + (k % 2 == 0 and 1 or -1) * rng:NextNumber(1.2, 1.9)
		local r = size * rng:NextNumber(0.72, 0.85)
		Scenery.pineTree(
			parent,
			Vector3.new(pos.X + math.cos(a) * r, 0, pos.Z + math.sin(a) * r),
			rng:NextNumber(1.4, 2.2),
			rng:NextNumber() < 0.4
		)
	end
end

-- Far mountains on the horizon, hazy blue-grey so the world looks deeper.
function Scenery.farMountain(parent, pos, size)
	local haze = rgb(150, 165, 195)
	ball(
		parent,
		"FarMountain",
		pos,
		size,
		haze,
		Enum.Material.SmoothPlastic,
		{ CastShadow = false, CanCollide = false }
	)
	ball(
		parent,
		"FarMountain",
		pos + Vector3.new(size * 0.35, -size * 0.12, 0),
		size * 0.7,
		haze:Lerp(rgb(255, 255, 255), 0.1),
		Enum.Material.SmoothPlastic,
		{ CastShadow = false, CanCollide = false }
	)
	ball(
		parent,
		"FarSnow",
		pos + Vector3.new(0, size * 0.38, 0),
		size * 0.34,
		rgb(235, 240, 250),
		Enum.Material.SmoothPlastic,
		{ CastShadow = false, CanCollide = false }
	)
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
