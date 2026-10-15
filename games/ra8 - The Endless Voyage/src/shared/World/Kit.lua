-- The building kit every builder uses (the server's forest and camp, the findings, monsters and items, the client's
-- effects, the render tools): a palette, part helpers, and props made from plain parts. Art direction (master plan
-- §11): high-quality stylized 3D for phones: attractive tree silhouettes with varied foliage and believable bark,
-- a forest floor of rocks, ferns, logs and mushrooms, a camp that glows warm against cool moonlight, loot that
-- stands out. Small props don't cast shadows or collide, to keep phones fast.
local CollectionService = game:GetService("CollectionService")

local Kit = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
Kit.rgb = rgb

local M = Enum.Material
Kit.M = M

Kit.C = {
	ink = rgb(22, 22, 34),
	good = rgb(60, 205, 90),
	sand = rgb(226, 206, 160),
	cliffDark = rgb(70, 72, 80),
	-- the forest floor
	grass = rgb(104, 168, 64),
	grassLight = rgb(146, 200, 82),
	grassDark = rgb(70, 128, 52),
	moss = rgb(92, 140, 58),
	path = rgb(170, 132, 90),
	pathDark = rgb(132, 98, 66),
	dirt = rgb(132, 96, 64),
	rock = rgb(150, 148, 142),
	rockDark = rgb(108, 106, 104),
	rockMoss = rgb(112, 132, 92),
	water = rgb(66, 150, 176),
	-- trees
	bark = rgb(112, 76, 50),
	barkDark = rgb(78, 54, 38),
	barkRed = rgb(138, 74, 52), -- the giants
	birch = rgb(236, 232, 220),
	birchMark = rgb(48, 44, 42),
	pine = rgb(44, 128, 76),
	pineLight = rgb(78, 158, 86),
	pineDark = rgb(28, 96, 64),
	spruce = rgb(34, 104, 82),
	spruceDark = rgb(22, 78, 66),
	leaf = rgb(96, 172, 62),
	leafLight = rgb(158, 206, 80),
	leafDark = rgb(62, 132, 56),
	birchLeaf = rgb(170, 204, 86),
	autumn = rgb(232, 150, 54),
	autumnRed = rgb(206, 84, 52),
	fern = rgb(78, 150, 62),
	fernDark = rgb(52, 116, 54),
	deadWood = rgb(124, 112, 100),
	-- flowers and mushrooms
	flowerPink = rgb(255, 130, 190),
	flowerYellow = rgb(255, 222, 80),
	flowerWhite = rgb(250, 250, 244),
	flowerBlue = rgb(110, 160, 255),
	mushroom = rgb(220, 58, 60),
	mushroomBrown = rgb(176, 120, 76),
	glowcap = rgb(110, 230, 255),
	glowPurple = rgb(184, 120, 255),
	-- the camp
	wood = rgb(178, 118, 70),
	woodDark = rgb(116, 76, 48),
	woodLight = rgb(214, 162, 104),
	plank = rgb(196, 146, 96),
	canvas = rgb(214, 190, 140),
	canvasGreen = rgb(96, 128, 78),
	canvasRed = rgb(196, 76, 62),
	stone = rgb(170, 166, 158),
	stoneDark = rgb(124, 120, 116),
	iron = rgb(96, 100, 112),
	steel = rgb(170, 176, 190),
	rope = rgb(200, 170, 120),
	cloth = rgb(198, 64, 58),
	fire = rgb(255, 136, 40),
	ember = rgb(255, 84, 30),
	warm = rgb(255, 190, 110),
	blueprint = rgb(96, 204, 255),
	gold = rgb(255, 200, 60),
	goldDark = rgb(204, 140, 30),
	-- Kermy and friends
	kermy = rgb(118, 196, 58),
	kermyDark = rgb(76, 146, 44),
	jersey = rgb(108, 62, 186),
	jerseyTrim = rgb(255, 196, 44),
	-- everyday
	red = rgb(226, 62, 62),
	blue = rgb(62, 120, 226),
	green = rgb(62, 186, 96),
	white = rgb(250, 248, 240),
	cream = rgb(255, 244, 214),
	black = rgb(28, 26, 34),
	purple = rgb(150, 92, 220),
	yellow = rgb(255, 214, 60),
	moon = rgb(176, 200, 255),
}
local C = Kit.C

-- Parts ---------------------------------------------------------------------------------------------------------
function Kit.part(props)
	local p = Instance.new(props.ClassName or "Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = M.SmoothPlastic
	for k, v in props do
		if k ~= "Parent" and k ~= "ClassName" then
			p[k] = v
		end
	end
	p.Parent = props.Parent
	return p
end
local part = Kit.part

-- A box from its CFrame and size, with colour and material (the most common call).
function Kit.box(parent, name, cf, size, color, material, extra)
	local props = {
		Name = name,
		CFrame = cf,
		Size = size,
		Color = color,
		Material = material or M.SmoothPlastic,
		Parent = parent,
	}
	for k, v in extra or {} do
		props[k] = v
	end
	return part(props)
end

function Kit.wedge(parent, name, cf, size, color, material, extra)
	local props = {
		ClassName = "WedgePart",
		Name = name,
		CFrame = cf,
		Size = size,
		Color = color,
		Material = material or M.SmoothPlastic,
		Parent = parent,
	}
	for k, v in extra or {} do
		props[k] = v
	end
	return part(props)
end

-- A cylinder standing up (Roblox cylinders lie along X, so turn it).
function Kit.disc(parent, name, center, diameter, height, color, material, extra)
	local props = {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material or M.SmoothPlastic,
		Parent = parent,
	}
	for k, v in extra or {} do
		props[k] = v
	end
	return part(props)
end

-- A cylinder along a CFrame's X axis (pipes, logs, wheels).
function Kit.cyl(parent, name, cf, length, diameter, color, material, extra)
	local props = {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(length, diameter, diameter),
		CFrame = cf,
		Color = color,
		Material = material or M.SmoothPlastic,
		Parent = parent,
	}
	for k, v in extra or {} do
		props[k] = v
	end
	return part(props)
end

function Kit.ball(parent, name, center, diameter, color, material, extra)
	local props = {
		Name = name,
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(diameter, diameter, diameter),
		CFrame = CFrame.new(center),
		Color = color,
		Material = material or M.SmoothPlastic,
		Parent = parent,
	}
	for k, v in extra or {} do
		props[k] = v
	end
	return part(props)
end

-- A cone of stacked discs (base at `base`, pointing up): roofs, pine tiers.
function Kit.cone(parent, name, base, diameter, height, color, steps, material, extra)
	steps = steps or 4
	local first
	for i = 1, steps do
		local t = (i - 1) / steps
		local h = height / steps -- a negative height hangs the cone down (stalactites)
		local d = Kit.disc(
			parent,
			name,
			base + Vector3.new(0, h * (i - 0.5), 0),
			diameter * (1 - t * 0.85),
			math.abs(h),
			color,
			material,
			extra
		)
		d.CastShadow = i == 1 and (extra == nil or extra.CastShadow ~= false)
		first = first or d
	end
	return first
end

-- A smooth cone roof (towers): wedges round a centre, each sloping out from the peak to the rim.
function Kit.roofCone(parent, name, base, radius, height, color, material, sides, extra)
	sides = sides or 12
	local first
	local w = 2 * math.pi * radius / sides * 1.06
	for k = 0, sides - 1 do
		local a = (k + 0.5) / sides * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local pos = base + dir * (radius / 2) + Vector3.new(0, height / 2, 0)
		local p = Kit.wedge(
			parent,
			name,
			CFrame.lookAt(pos, pos + dir),
			Vector3.new(w, height, radius),
			color,
			material,
			extra
		)
		p.CastShadow = k % 3 == 0
		first = first or p
	end
	return first
end

function Kit.model(name, parent)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

function Kit.folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Lights ----------------------------------------------------------------------------------------------------------
function Kit.light(parent, className, props)
	local l = Instance.new(className or "PointLight")
	l.Shadows = false
	for k, v in props or {} do
		l[k] = v
	end
	l.Parent = parent
	return l
end

-- A warm glowing bulb (neon) with a point light.
function Kit.bulb(parent, name, center, diameter, color, range, brightness)
	local b =
		Kit.ball(parent, name, center, diameter, color or C.warm, M.Neon, { CastShadow = false, CanCollide = false })
	Kit.light(b, "PointLight", { Color = color or C.warm, Range = range or 16, Brightness = brightness or 1.6 })
	return b
end

-- Text ------------------------------------------------------------------------------------------------------------
-- Text painted on a part's face (signs, plates, boards). Returns the TextLabel.
function Kit.text(target, face, text, opts)
	opts = opts or {}
	local gui = Instance.new("SurfaceGui")
	gui.Name = opts.name or "Text"
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = opts.ppu or 40
	gui.LightInfluence = opts.lightInfluence or 0.4
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = opts.font or Enum.Font.Oswald
	label.TextColor3 = opts.color or C.cream
	label.TextXAlignment = opts.align or Enum.TextXAlignment.Center
	label.TextWrapped = true
	label.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.06, 0)
	pad.PaddingRight = UDim.new(0.06, 0)
	pad.PaddingTop = UDim.new(0.08, 0)
	pad.PaddingBottom = UDim.new(0.08, 0)
	pad.Parent = label
	return label
end

-- A sign board on posts or a wall: a dark board with a brass frame and text. `cf` faces the reader (-Z = front).
function Kit.sign(parent, cf, w, h, text, opts)
	opts = opts or {}
	local board = Kit.box(parent, opts.name or "Sign", cf, Vector3.new(w, h, 0.4), opts.color or C.woodDark, M.Wood)
	Kit.box(
		parent,
		"SignFrame",
		cf * CFrame.new(0, 0, 0.12),
		Vector3.new(w + 0.5, h + 0.5, 0.3),
		opts.frame or C.goldDark,
		M.Metal,
		{ CastShadow = false }
	)
	Kit.text(board, Enum.NormalId.Front, text, { color = opts.textColor or C.cream, font = opts.font, ppu = opts.ppu })
	return board
end

-- Props -----------------------------------------------------------------------------------------------------------
-- An ellipsoid (a part with a sphere mesh): soft shapes like tree layers and bushes.
function Kit.ellipsoid(parent, name, center, size, color, material, extra)
	local p = Kit.box(parent, name, CFrame.new(center), size, color, material, extra)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- A round cartoon tree: a short trunk with two branches and puffy clumps of leaves (leaf-textured).
function Kit.toonTree(parent, pos, h, rng, color)
	rng = rng or Random.new()
	h = h or rng:NextNumber(16, 24)
	local m = Kit.model("Tree", parent)
	Kit.disc(m, "Trunk", pos + Vector3.new(0, h * 0.3, 0), h * 0.11, h * 0.6, C.bark, M.Wood)
	Kit.disc(m, "Root", pos + Vector3.new(0, h * 0.03, 0), h * 0.17, h * 0.06, C.bark, M.Wood, { CastShadow = false })
	for k, a in { rng:NextNumber(0, 3), rng:NextNumber(3, 6) } do
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		Kit.box(
			m,
			"Branch",
			CFrame.lookAt(
				pos + Vector3.new(0, h * (0.42 + k * 0.06), 0),
				pos + Vector3.new(0, h * (0.62 + k * 0.05), 0) + dir * h * 0.22
			) * CFrame.new(0, 0, -h * 0.1),
			Vector3.new(h * 0.045, h * 0.045, h * 0.24),
			C.bark,
			M.Wood,
			{ CastShadow = false, CanCollide = false }
		)
	end
	local col = color or C.leaf
	local clumps = {
		{ Vector3.new(0, h * 0.74, 0), 0.6 },
		{ Vector3.new(h * 0.17, h * 0.62, h * 0.08), 0.44 },
		{ Vector3.new(-h * 0.15, h * 0.64, -h * 0.1), 0.46 },
		{ Vector3.new(-h * 0.06, h * 0.6, h * 0.18), 0.4 },
		{ Vector3.new(h * 0.08, h * 0.86, -h * 0.06), 0.38 },
		{ Vector3.new(h * 0.05, h * 0.55, -h * 0.17), 0.34 },
	}
	for i, c in clumps do
		local d = h * c[2] * rng:NextNumber(0.9, 1.1)
		local leaf = Kit.ball(
			m,
			"Leaves",
			pos + c[1] + Vector3.new(rng:NextNumber(-0.4, 0.4), 0, rng:NextNumber(-0.4, 0.4)),
			d,
			col:Lerp(C.leafLight, rng:NextNumber(0, 0.3)):Lerp(C.leafDark, i > 3 and 0.2 or 0),
			M.Grass,
			{ CastShadow = i <= 2, CanCollide = false }
		)
		if i > 3 then
			CollectionService:AddTag(leaf, "Detail")
		end
	end
	return m
end

-- A cartoon pine: a trunk and stacked soft layers of needles (leaf-textured), wide at the bottom.
function Kit.toonPine(parent, pos, h, rng, color)
	rng = rng or Random.new()
	h = h or rng:NextNumber(22, 34)
	local m = Kit.model("Pine", parent)
	Kit.disc(m, "Trunk", pos + Vector3.new(0, h * 0.14, 0), h * 0.08, h * 0.28, C.bark, M.Wood)
	local col = color or (rng:NextNumber() < 0.5 and C.pine or C.pineDark)
	local tiers = 5
	for i = 0, tiers - 1 do
		local t = i / (tiers - 1)
		local d = h * (0.58 - 0.4 * t)
		local layer = Kit.ellipsoid(
			m,
			"Needles",
			pos + Vector3.new(rng:NextNumber(-0.3, 0.3), h * (0.26 + 0.56 * t), rng:NextNumber(-0.3, 0.3)),
			Vector3.new(d, h * 0.24, d),
			col:Lerp(C.leafLight, 0.12 * t):Lerp(C.pineDark, (1 - t) * 0.25),
			M.Grass,
			{ CastShadow = i < 2, CanCollide = false }
		)
		if i % 2 == 1 then
			CollectionService:AddTag(layer, "Detail")
		end
	end
	Kit.ellipsoid(
		m,
		"Top",
		pos + Vector3.new(0, h * 0.95, 0),
		Vector3.new(h * 0.1, h * 0.18, h * 0.1),
		col,
		M.Grass,
		{ CastShadow = false, CanCollide = false }
	)
	return m
end

-- A bare dead tree: a crooked trunk and a few forked branches.
function Kit.deadTree(parent, pos, h, rng, color)
	rng = rng or Random.new()
	h = h or rng:NextNumber(8, 12)
	local m = Kit.model("DeadTree", parent)
	local col = color or C.bark:Lerp(C.cliffDark, 0.45)
	Kit.box(
		m,
		"Trunk",
		CFrame.new(pos + Vector3.new(0, h * 0.35, 0))
			* CFrame.Angles(rng:NextNumber(-0.1, 0.1), 0, rng:NextNumber(-0.1, 0.1)),
		Vector3.new(h * 0.1, h * 0.7, h * 0.1),
		col,
		M.Wood
	)
	for k = 1, 4 do
		local a = k / 4 * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local y = h * rng:NextNumber(0.45, 0.72)
		local len = h * rng:NextNumber(0.25, 0.42)
		local from = pos + Vector3.new(0, y, 0)
		local to = from + Vector3.new(math.cos(a) * len, len * rng:NextNumber(0.5, 0.9), math.sin(a) * len)
		Kit.box(
			m,
			"Branch",
			CFrame.lookAt((from + to) / 2, to),
			Vector3.new(h * 0.05, h * 0.05, (to - from).Magnitude),
			col,
			M.Wood,
			{ CastShadow = false, CanCollide = false }
		)
	end
	return m
end

-- A fallen, mossy log lying on the ground.
function Kit.fallenLog(parent, pos, len, rng)
	rng = rng or Random.new()
	local m = Kit.model("FallenLog", parent)
	local d = rng:NextNumber(1.6, 2.4)
	local cf = CFrame.new(pos + Vector3.new(0, d * 0.4, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
	Kit.cyl(m, "Log", cf, len, d, C.bark:Lerp(C.woodDark, 0.3), M.Wood)
	Kit.box(
		m,
		"Moss",
		cf * CFrame.new(rng:NextNumber(-len * 0.2, len * 0.2), d * 0.42, 0),
		Vector3.new(len * 0.45, d * 0.2, d * 0.7),
		C.leafDark,
		M.Grass,
		{ CanCollide = false, CastShadow = false }
	)
	return m
end

-- A tree stump with its rings showing.
function Kit.stump(parent, pos, rng)
	rng = rng or Random.new()
	local m = Kit.model("Stump", parent)
	local d = rng:NextNumber(1.6, 2.6)
	local h = rng:NextNumber(0.8, 1.6)
	Kit.disc(m, "Stump", pos + Vector3.new(0, h / 2 - 0.1, 0), d, h, C.bark, M.Wood)
	Kit.disc(
		m,
		"Rings",
		pos + Vector3.new(0, h - 0.06, 0),
		d * 0.82,
		0.1,
		C.woodLight,
		M.WoodPlanks,
		{ CanCollide = false, CastShadow = false }
	)
	return m
end

-- A smooth rounded boulder (or a few), sat into the ground. A part with a sphere mesh still collides as its box
-- (invisible corners to bump into and stand on), so the rock itself doesn't collide: an invisible box inside it
-- does, about as wide as the rock at your waist.
function Kit.boulder(parent, pos, size, rng, color, material)
	rng = rng or Random.new()
	size = size or rng:NextNumber(4, 8)
	local col = color or C.rock
	local p = Kit.ellipsoid(
		parent,
		"Boulder",
		pos + Vector3.new(0, size * 0.28, 0),
		Vector3.new(size, size * 0.72, size * rng:NextNumber(0.8, 1.1)),
		col:Lerp(C.rockDark, rng:NextNumber(0, 0.25)),
		material or M.Rock,
		{ CastShadow = size > 5, CanCollide = false }
	)
	p.CFrame = p.CFrame
		* CFrame.Angles(rng:NextNumber(-0.15, 0.15), rng:NextNumber(0, math.pi), rng:NextNumber(-0.15, 0.15))
	if size >= 2 then
		Kit.box(
			parent,
			"BoulderCollider",
			p.CFrame,
			p.Size * Vector3.new(0.72, 0.84, 0.72),
			col,
			M.SmoothPlastic,
			{ Transparency = 1, CastShadow = false }
		)
	end
	return p
end

function Kit.bush(parent, pos, size, rng, color)
	rng = rng or Random.new()
	size = size or rng:NextNumber(3, 5)
	for i = 1, 3 do
		Kit.ball(
			parent,
			"Bush",
			pos + Vector3.new(rng:NextNumber(-1, 1) * size * 0.4, size * 0.3, rng:NextNumber(-1, 1) * size * 0.4),
			size * rng:NextNumber(0.6, 1),
			(color or C.leafDark):Lerp(C.leaf, rng:NextNumber(0, 0.6)),
			M.Grass,
			{ CastShadow = false, CanCollide = i == 1 }
		)
	end
end

-- A little patch of flowers (no collision).
function Kit.flowers(parent, pos, rng, n)
	rng = rng or Random.new()
	local colors = { C.flowerPink, C.flowerYellow, C.flowerWhite, C.flowerBlue }
	for _ = 1, n or 5 do
		local p = pos + Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
		local stem = Kit.box(
			parent,
			"Stem",
			CFrame.new(p + Vector3.new(0, 0.4, 0)),
			Vector3.new(0.15, 0.8, 0.15),
			C.leafDark,
			M.SmoothPlastic,
			{ CanCollide = false, CastShadow = false }
		)
		local bloom = Kit.ball(
			parent,
			"Flower",
			p + Vector3.new(0, 0.9, 0),
			0.6,
			colors[rng:NextInteger(1, #colors)],
			M.SmoothPlastic,
			{ CanCollide = false, CastShadow = false }
		)
		-- pure decoration: phones in lite mode leave it out (PerformanceController)
		CollectionService:AddTag(stem, "Detail")
		CollectionService:AddTag(bloom, "Detail")
	end
end

-- A big cartoon mushroom: a pale stem and a round cap with spots.
function Kit.mushroom(parent, pos, h, color, rng)
	rng = rng or Random.new()
	h = h or 8
	local m = Kit.model("Mushroom", parent)
	Kit.disc(m, "Stem", pos + Vector3.new(0, h * 0.4, 0), h * 0.22, h * 0.8, C.cream, M.SmoothPlastic)
	local cap = Kit.ellipsoid(
		m,
		"Cap",
		pos + Vector3.new(0, h * 0.82, 0),
		Vector3.new(h * 0.95, h * 0.5, h * 0.95),
		color or C.mushroom,
		M.SmoothPlastic
	)
	for _ = 1, 4 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = h * rng:NextNumber(0.15, 0.32)
		Kit.ball(
			m,
			"Spot",
			cap.Position + Vector3.new(math.cos(a) * r, h * 0.18, math.sin(a) * r),
			h * 0.14,
			C.white,
			M.SmoothPlastic,
			{ CanCollide = false, CastShadow = false }
		)
	end
	return m
end

-- A cluster of glowing crystals (the cave, the shrines, the rift).
function Kit.crystals(parent, pos, h, color, rng, n)
	rng = rng or Random.new()
	local m = Kit.model("Crystals", parent)
	for i = 1, n or 4 do
		local hh = h * (i == 1 and 1 or rng:NextNumber(0.45, 0.8))
		local w = hh * 0.28
		local tilt = i == 1 and 0 or rng:NextNumber(0.2, 0.5)
		local a = rng:NextNumber(0, math.pi * 2)
		local base = pos + Vector3.new(math.cos(a), 0, math.sin(a)) * (i == 1 and 0 or w * 1.1)
		local cf = CFrame.new(base) * CFrame.Angles(0, a, 0) * CFrame.Angles(tilt, 0, 0) * CFrame.new(0, hh / 2, 0)
		Kit.box(m, "Crystal", cf, Vector3.new(w, hh, w), color or C.glowcap, M.Neon, { CastShadow = false })
		Kit.box(
			m,
			"Tip",
			cf * CFrame.new(0, hh / 2, 0) * CFrame.Angles(0, math.rad(45), 0),
			Vector3.new(w * 0.7, w * 0.7, w * 0.7),
			(color or C.glowcap):Lerp(C.white, 0.3),
			M.Neon,
			{ CastShadow = false, CanCollide = false }
		)
	end
	return m
end

-- A torch on a post: a warm flame and a light.
function Kit.torch(parent, pos, h, color)
	h = h or 6
	local m = Kit.model("Torch", parent)
	Kit.disc(m, "Post", pos + Vector3.new(0, h / 2, 0), 0.5, h, C.woodDark, M.Wood)
	Kit.disc(m, "Bowl", pos + Vector3.new(0, h + 0.2, 0), 1.3, 0.6, C.iron, M.Metal, { CastShadow = false })
	local flame = Kit.ellipsoid(
		m,
		"Flame",
		pos + Vector3.new(0, h + 1.1, 0),
		Vector3.new(1, 1.6, 1),
		color or C.fire,
		M.Neon,
		{ CastShadow = false, CanCollide = false }
	)
	Kit.light(flame, "PointLight", { Color = color or C.warm, Range = 18, Brightness = 1.6 })
	return m, flame
end

-- A banner on a pole: a coloured cloth with a trim stripe. `cf` stands at the pole's foot, the cloth faces -Z.
function Kit.banner(parent, cf, h, color, trim, name)
	h = h or 12
	local m = Kit.model(name or "Banner", parent)
	Kit.cyl(m, "Pole", cf * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), h, 0.45, C.woodDark, M.Wood)
	Kit.ball(m, "Knob", (cf * CFrame.new(0, h + 0.2, 0)).Position, 0.8, C.gold, M.Metal, { CastShadow = false })
	local w, ch = h * 0.32, h * 0.5
	local cloth = Kit.box(
		m,
		"Cloth",
		cf * CFrame.new(w / 2 + 0.3, h - ch / 2 - 0.6, 0),
		Vector3.new(w, ch, 0.2),
		color or C.cloth,
		M.Fabric,
		{ CanCollide = false }
	)
	Kit.box(
		m,
		"Trim",
		cf * CFrame.new(w / 2 + 0.3, h - ch - 0.4, 0),
		Vector3.new(w, 0.5, 0.25),
		trim or C.gold,
		M.Fabric,
		{ CanCollide = false, CastShadow = false }
	)
	return m, cloth
end

-- A lantern hanging from a crooked post (lights a road at night).
function Kit.lantern(parent, pos, facing, h)
	h = h or 7
	local m = Kit.model("Lantern", parent)
	local dir = facing or Vector3.new(1, 0, 0)
	Kit.box(m, "Post", CFrame.new(pos + Vector3.new(0, h / 2, 0)), Vector3.new(0.5, h, 0.5), C.woodDark, M.Wood)
	Kit.box(
		m,
		"Arm",
		CFrame.lookAt(pos + Vector3.new(0, h - 0.4, 0) + dir * 0.9, pos + Vector3.new(0, h - 0.4, 0) + dir * 2),
		Vector3.new(0.3, 0.3, 1.9),
		C.woodDark,
		M.Wood,
		{ CastShadow = false }
	)
	local at = pos + Vector3.new(0, h - 1.3, 0) + dir * 1.7
	Kit.box(
		m,
		"Cage",
		CFrame.new(at),
		Vector3.new(0.9, 1.1, 0.9),
		C.iron,
		M.Metal,
		{ CastShadow = false, CanCollide = false }
	)
	Kit.bulb(m, "Light", at, 0.6, C.warm, 16, 1.2)
	return m
end

-- A signpost with arrows pointing the way (text on both faces).
function Kit.signpost(parent, pos, signs)
	local m = Kit.model("Signpost", parent)
	Kit.box(m, "Post", CFrame.new(pos + Vector3.new(0, 2.6, 0)), Vector3.new(0.45, 5.2, 0.45), C.woodDark, M.Wood)
	for k, sg in signs do
		local cf = CFrame.lookAt(pos, pos + sg.dir) * CFrame.Angles(0, math.rad(-90), 0)
		local board = Kit.box(
			m,
			"Arrow",
			cf * CFrame.new(1.3, 4.6 - k * 1.05, 0),
			Vector3.new(2.8, 0.8, 0.2),
			C.woodLight,
			M.WoodPlanks,
			{ CastShadow = false }
		)
		Kit.text(board, Enum.NormalId.Front, sg.text, { font = Enum.Font.LuckiestGuy, color = C.woodDark, ppu = 30 })
		Kit.text(board, Enum.NormalId.Back, sg.text, { font = Enum.Font.LuckiestGuy, color = C.woodDark, ppu = 30 })
	end
	return m
end

function Kit.crate(parent, cf, size, color)
	size = size or Vector3.new(3, 3, 3)
	local m = Kit.model("Crate", parent)
	Kit.box(m, "Box", cf, size, color or C.woodLight, M.WoodPlanks)
	local t = 0.25
	for _, y in { -1, 1 } do
		Kit.box(
			m,
			"Band",
			cf * CFrame.new(0, y * (size.Y / 2 - t), 0),
			size + Vector3.new(0.12, -size.Y + t * 2, 0.12),
			C.woodDark,
			M.Wood,
			{ CastShadow = false }
		)
	end
	return m
end

function Kit.barrel(parent, pos, color, h)
	h = h or 3.2
	local m = Kit.model("Barrel", parent)
	Kit.disc(m, "Barrel", pos + Vector3.new(0, h / 2, 0), 2.4, h, color or C.wood, M.WoodPlanks)
	for _, y in { 0.25, 0.75 } do
		Kit.disc(m, "Ring", pos + Vector3.new(0, h * y, 0), 2.55, 0.18, C.iron, M.Metal, { CastShadow = false })
	end
	return m
end

-- A fence of posts and two rails from a to b (on the ground).
function Kit.fence(parent, a, b, color)
	local m = Kit.model("Fence", parent)
	local dir = b - a
	local len = dir.Magnitude
	local n = math.max(1, math.floor(len / 6))
	for i = 0, n do
		local p = a + dir * (i / n)
		Kit.box(
			m,
			"Post",
			CFrame.new(p + Vector3.new(0, 1.6, 0)),
			Vector3.new(0.5, 3.2, 0.5),
			color or C.woodDark,
			M.Wood
		)
	end
	local mid = a + dir / 2
	local look = CFrame.lookAt(mid, b)
	for _, y in { 1.2, 2.5 } do
		Kit.box(
			m,
			"Rail",
			look + Vector3.new(0, y, 0),
			Vector3.new(0.25, 0.4, len),
			color or C.woodDark,
			M.Wood,
			{ CastShadow = false }
		)
	end
	return m
end

-- A stack of logs lying along the CFrame's X axis.
function Kit.logs(parent, cf, length, rows)
	local m = Kit.model("Logs", parent)
	rows = rows or 3
	local d = 1.6
	for r = 0, rows - 1 do
		local count = rows - r + 1
		for i = 0, count - 1 do
			local z = (i - (count - 1) / 2) * d
			Kit.cyl(
				m,
				"Log",
				cf * CFrame.new(0, d / 2 + r * d * 0.86, z),
				length,
				d,
				C.bark:Lerp(C.woodLight, 0.25),
				M.Wood
			)
		end
	end
	return m
end

-- Invisible wall that keeps players inside an area.
function Kit.wall(parent, cf, size)
	return Kit.box(
		parent,
		"Boundary",
		cf,
		size,
		C.black,
		M.SmoothPlastic,
		{ Transparency = 1, CanQuery = false, CastShadow = false }
	)
end

-- The forest ---------------------------------------------------------------------------------------------------------
-- Trees come from MapLayout.trees(): { x, y, z, kind, h, trunk, seed }. Each is a Model with a colliding Trunk
-- (cover) and soft, non-colliding foliage. Low part counts: about five parts a tree. Each trunk stops a few studs
-- inside the lowest layer of the crown: the camera fades whatever is between it and you (Invisicam), and a trunk
-- running up through a faded crown shows as a dark line in the tree.
local function trunkPart(m, t, height, color, material, diameter)
	return Kit.disc(
		m,
		"Trunk",
		Vector3.new(t.x, t.y + height / 2 - 0.6, t.z),
		diameter or t.trunk * 2,
		height + 1.2,
		color,
		material or M.Wood,
		{ CastShadow = true }
	)
end

local function tint(base, rng, toward, amount)
	return base:Lerp(toward, rng:NextNumber(0, amount))
end

-- A pine: a straight trunk and three overlapping tiers of needles narrowing to a tip (the canopy starts above head
-- height, so you can see monsters between the trunks).
function Kit.pine(parent, t)
	local rng = Random.new(t.seed)
	local m = Kit.model("Pine", parent)
	local h = t.h
	trunkPart(m, t, h * 0.36, C.bark:Lerp(C.barkDark, rng:NextNumber(0, 0.4)))
	local col = tint(C.pine, rng, rng:NextNumber() < 0.5 and C.pineDark or C.pineLight, 0.7)
	local base = Vector3.new(t.x, t.y, t.z)
	local tiers = {
		{ 0.44, 0.56, 0.36 },
		{ 0.63, 0.42, 0.32 },
		{ 0.8, 0.27, 0.27 },
	}
	for i, tier in tiers do
		local f = (i - 1) / 2
		local w = h * tier[2] * rng:NextNumber(0.92, 1.08)
		Kit.ellipsoid(
			m,
			"Needles",
			base + Vector3.new(rng:NextNumber(-0.3, 0.3), h * tier[1], rng:NextNumber(-0.3, 0.3)),
			Vector3.new(w, h * tier[3], w),
			col:Lerp(C.pineLight, 0.2 * f):Lerp(C.pineDark, (1 - f) * 0.25),
			M.Grass,
			{ CanCollide = false, CastShadow = i < 3 }
		)
	end
	Kit.ellipsoid(
		m,
		"Top",
		base + Vector3.new(0, h * 0.94, 0),
		Vector3.new(h * 0.1, h * 0.16, h * 0.1),
		col:Lerp(C.pineLight, 0.25),
		M.Grass,
		{ CanCollide = false, CastShadow = false }
	)
	return m
end

-- A spruce: taller and narrower, darker, four tiers to a sharp tip.
function Kit.spruce(parent, t)
	local rng = Random.new(t.seed)
	local m = Kit.model("Spruce", parent)
	local h = t.h
	trunkPart(m, t, h * 0.3, C.barkDark:Lerp(C.bark, rng:NextNumber(0, 0.5)))
	local col = tint(C.spruce, rng, C.spruceDark, 0.8)
	local base = Vector3.new(t.x, t.y, t.z)
	for i = 0, 3 do
		local f = i / 3
		local w = h * (0.38 - 0.25 * f) * rng:NextNumber(0.94, 1.06)
		Kit.ellipsoid(
			m,
			"Needles",
			base + Vector3.new(0, h * (0.32 + 0.46 * f), 0),
			Vector3.new(w, h * (0.27 - 0.05 * f), w),
			col:Lerp(C.pine, 0.25 * f),
			M.Grass,
			{ CanCollide = false, CastShadow = i < 2 }
		)
	end
	Kit.ellipsoid(
		m,
		"Top",
		base + Vector3.new(0, h * 0.92, 0),
		Vector3.new(h * 0.07, h * 0.2, h * 0.07),
		col,
		M.Grass,
		{ CanCollide = false, CastShadow = false }
	)
	return m
end

-- An oak: a short thick trunk, a branch, and three puffy clumps of leaves (now and then in autumn colours).
function Kit.oak(parent, t)
	local rng = Random.new(t.seed)
	local m = Kit.model("Oak", parent)
	local h = t.h
	trunkPart(m, t, h * 0.55, C.bark)
	local a = rng:NextNumber(0, math.pi * 2)
	local dir = Vector3.new(math.cos(a), 0, math.sin(a))
	local base = Vector3.new(t.x, t.y, t.z)
	Kit.box(
		m,
		"Branch",
		CFrame.lookAt(base + Vector3.new(0, h * 0.42, 0), base + Vector3.new(0, h * 0.62, 0) + dir * h * 0.24)
			* CFrame.new(0, 0, -h * 0.11),
		Vector3.new(h * 0.06, h * 0.06, h * 0.26),
		C.bark,
		M.Wood,
		{ CastShadow = false, CanCollide = false }
	)
	local col = C.leaf
	local autumn = rng:NextNumber()
	if autumn < 0.08 then
		col = C.autumn
	elseif autumn < 0.12 then
		col = C.autumnRed
	end
	local clumps = {
		{ Vector3.new(0, h * 0.74, 0), 0.62 },
		{ dir * h * 0.2 + Vector3.new(0, h * 0.62, 0), 0.46 },
		{ -dir * h * 0.16 + Vector3.new(h * 0.08, h * 0.64, -h * 0.08), 0.48 },
	}
	for i, c in clumps do
		Kit.ball(
			m,
			"Leaves",
			base + c[1],
			h * c[2] * rng:NextNumber(0.9, 1.1),
			col:Lerp(C.leafLight, rng:NextNumber(0, 0.25)):Lerp(C.leafDark, i == 3 and 0.25 or 0),
			M.Grass,
			{ CastShadow = i == 1, CanCollide = false }
		)
	end
	return m
end

-- A birch: a slim white trunk with short dark marks and small yellow-green crowns.
function Kit.birch(parent, t)
	local rng = Random.new(t.seed)
	local m = Kit.model("Birch", parent)
	local h = t.h
	trunkPart(m, t, h * 0.6, C.birch, M.SmoothPlastic)
	local base = Vector3.new(t.x, t.y, t.z)
	-- short dark marks on the bark, here and there round the trunk (full rings read as a seam in the trunk)
	for _ = 1, 6 do
		local w = t.trunk * rng:NextNumber(0.7, 1.2)
		Kit.box(
			m,
			"Mark",
			CFrame.new(base + Vector3.new(0, h * rng:NextNumber(0.08, 0.45), 0))
				* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
				* CFrame.new(0, 0, -(t.trunk - 0.02)),
			Vector3.new(w, rng:NextNumber(0.12, 0.26), 0.08),
			C.birchMark,
			M.SmoothPlastic,
			{ CanCollide = false, CastShadow = false }
		)
	end
	for i = 1, 2 do
		local off = Vector3.new(rng:NextNumber(-1.4, 1.4), 0, rng:NextNumber(-1.4, 1.4))
		Kit.ball(
			m,
			"Leaves",
			base + off + Vector3.new(0, h * (0.66 + 0.16 * (i - 1)), 0),
			h * (0.42 - 0.08 * (i - 1)) * rng:NextNumber(0.9, 1.1),
			C.birchLeaf:Lerp(C.leaf, rng:NextNumber(0, 0.4)),
			M.Grass,
			{ CastShadow = i == 1, CanCollide = false }
		)
	end
	return m
end

-- A sapling by the camp: a thin trunk and a few small clumps of fresh leaves (the first thing anyone chops).
function Kit.sapling(parent, t)
	local rng = Random.new(t.seed)
	local m = Kit.model("Sapling", parent)
	local h = t.h
	trunkPart(m, t, h * 0.5, C.bark:Lerp(C.barkDark, 0.2))
	local base = Vector3.new(t.x, t.y, t.z)
	local col = C.leafLight:Lerp(C.leaf, rng:NextNumber(0, 0.5))
	local clumps = {
		{ Vector3.new(0, h * 0.72, 0), 0.5 },
		{ Vector3.new(h * 0.14, h * 0.58, h * 0.06), 0.38 },
		{ Vector3.new(-h * 0.12, h * 0.62, -h * 0.1), 0.36 },
	}
	for i, c in clumps do
		Kit.ball(
			m,
			"Leaves",
			base + c[1],
			h * c[2] * rng:NextNumber(0.9, 1.1),
			col:Lerp(C.leafDark, (i - 1) * 0.12),
			M.Grass,
			{ CastShadow = i == 1, CanCollide = false }
		)
	end
	return m
end

-- A dead tree for the deep forest: grey, crooked, bare.
function Kit.snag(parent, t)
	return Kit.deadTree(parent, Vector3.new(t.x, t.y, t.z), t.h, Random.new(t.seed), C.deadWood)
end

-- A giant of the deep forest: a thick red trunk with buttress roots, the crown high above the others.
function Kit.giant(parent, t)
	local rng = Random.new(t.seed)
	local m = Kit.model("Giant", parent)
	local h = t.h
	trunkPart(m, t, h * 0.58, C.barkRed:Lerp(C.barkDark, rng:NextNumber(0, 0.3)))
	local base = Vector3.new(t.x, t.y, t.z)
	for k = 0, 2 do
		local a = k / 3 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local p = base + dir * t.trunk * 1.2 + Vector3.new(0, 1.6, 0)
		Kit.wedge(
			m,
			"Root",
			CFrame.lookAt(p, p + dir),
			Vector3.new(t.trunk * 0.7, 3.6, t.trunk * 1.6),
			C.barkRed,
			M.Wood,
			{ CastShadow = false }
		)
	end
	local col = tint(C.spruceDark, rng, C.pineDark, 0.6)
	for i = 0, 2 do
		local f = i / 2
		local w = h * (0.36 - 0.14 * f)
		Kit.ellipsoid(
			m,
			"Needles",
			base + Vector3.new(0, h * (0.6 + 0.14 * f), 0),
			Vector3.new(w, h * 0.16, w),
			col:Lerp(C.pine, 0.2 * f),
			M.Grass,
			{ CanCollide = false, CastShadow = i == 0 }
		)
	end
	return m
end

-- An Ancient Pine at the clearing's edge: huge, mossy, with old carvings that glow once the Totem of the Seventh
-- Night stands (Mega Kermy gets stuck when he charges into one).
function Kit.ancientPine(parent, pos, seed)
	local rng = Random.new(seed or 1)
	local m = Kit.model("AncientPine", parent)
	local h = 64
	local t = { x = pos.X, y = pos.Y, z = pos.Z, trunk = 3.6 }
	trunkPart(m, t, h * 0.42, C.barkDark:Lerp(C.barkRed, 0.35))
	local base = Vector3.new(pos.X, pos.Y, pos.Z)
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local p = base + dir * 4.4 + Vector3.new(0, 1.8, 0)
		Kit.wedge(
			m,
			"Root",
			CFrame.lookAt(p, p + dir),
			Vector3.new(2.6, 4, 5),
			C.barkDark,
			M.Wood,
			{ CastShadow = false }
		)
	end
	Kit.disc(
		m,
		"Moss",
		base + Vector3.new(0, 3, 0),
		7.6,
		2.2,
		C.moss,
		M.Grass,
		{ CanCollide = false, CastShadow = false }
	)
	local rune = Kit.box(
		m,
		"Rune",
		CFrame.new(base + Vector3.new(0, 9, 0))
			* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			* CFrame.new(0, 0, -3.5),
		Vector3.new(1.6, 3.2, 0.3),
		C.glowcap,
		M.Neon,
		{ CanCollide = false, CastShadow = false, Transparency = 0.6 }
	)
	for i = 0, 3 do
		local f = i / 3
		local w = h * (0.46 - 0.3 * f)
		Kit.ellipsoid(
			m,
			"Needles",
			base + Vector3.new(0, h * (0.46 + 0.36 * f), 0),
			Vector3.new(w, h * (0.24 - 0.05 * f), w),
			C.pineDark:Lerp(C.pine, 0.35 * f),
			M.Grass,
			{ CanCollide = false, CastShadow = i < 2 }
		)
	end
	return m, rune
end

-- One tree model for a MapLayout tree record.
local TREE_BUILDERS = {
	pine = Kit.pine,
	spruce = Kit.spruce,
	oak = Kit.oak,
	birch = Kit.birch,
	dead = Kit.snag,
	giant = Kit.giant,
	sapling = Kit.sapling,
}
-- A tree on the boundary hills, out of reach: just a trunk and one tall crown (two parts).
function Kit.farTree(parent, t)
	local rng = Random.new(t.seed)
	local m = Kit.model("FarTree", parent)
	local h = t.h
	trunkPart(m, t, h * 0.3, C.barkDark)
	local col = (t.kind == "spruce" and C.spruce or C.pine):Lerp(C.pineDark, rng:NextNumber(0, 0.6))
	Kit.ellipsoid(
		m,
		"Crown",
		Vector3.new(t.x, t.y + h * 0.6, t.z),
		Vector3.new(h * 0.4, h * 0.8, h * 0.4),
		col,
		M.Grass,
		{ CanCollide = false, CastShadow = false }
	)
	return m
end

function Kit.tree(parent, t)
	local build = t.reachable == false and Kit.farTree or TREE_BUILDERS[t.kind] or Kit.pine
	local m = build(parent, t)
	m:SetAttribute("TreeId", t.id)
	return m
end

-- A fern: a few long leaf-shaped fronds arching out from the ground (no collision).
function Kit.fern(parent, pos, rng, size)
	rng = rng or Random.new()
	size = size or rng:NextNumber(1.6, 2.6)
	local col = C.fern:Lerp(C.fernDark, rng:NextNumber(0, 0.6))
	local n = rng:NextInteger(5, 6)
	local a0 = rng:NextNumber(0, math.pi * 2)
	for k = 1, n do
		local a = a0 + k / n * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local len = size * rng:NextNumber(1.6, 2.1)
		local mid = pos + dir * len * 0.45 + Vector3.new(0, size * 0.45, 0)
		local p = Kit.ellipsoid(
			parent,
			"Frond",
			mid,
			Vector3.new(size * 0.42, 0.12, len),
			col:Lerp(C.leafLight, rng:NextNumber(0, 0.15)),
			M.Grass,
			{ CanCollide = false, CastShadow = false, CanQuery = false }
		)
		p.CFrame = CFrame.lookAt(mid, mid + dir) * CFrame.Angles(math.rad(rng:NextNumber(18, 34)), 0, 0)
		if k > 3 then
			CollectionService:AddTag(p, "Detail")
		end
	end
end

-- A little cluster of mushrooms (brown or red), or glowing ones for the deep forest.
function Kit.mushrooms(parent, pos, rng, glowing)
	rng = rng or Random.new()
	for k = 1, rng:NextInteger(2, 3) do
		local p = pos + Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
		local h = rng:NextNumber(0.6, 1.4)
		Kit.disc(parent, "Stem", p + Vector3.new(0, h / 2, 0), h * 0.35, h, C.cream, M.SmoothPlastic, {
			CanCollide = false,
			CastShadow = false,
			CanQuery = false,
		})
		local cap = Kit.ellipsoid(
			parent,
			"Cap",
			p + Vector3.new(0, h, 0),
			Vector3.new(h * 1.1, h * 0.55, h * 1.1),
			glowing and C.glowcap or (k == 1 and C.mushroom or C.mushroomBrown),
			glowing and M.Neon or M.SmoothPlastic,
			{ CanCollide = false, CastShadow = false, CanQuery = false }
		)
		if k > 1 then
			CollectionService:AddTag(cap, "Detail")
		end
	end
end

-- A small mossy rock (decoration).
function Kit.pebble(parent, pos, rng, size)
	rng = rng or Random.new()
	size = size or rng:NextNumber(1, 2.4)
	local p = Kit.ellipsoid(
		parent,
		"Pebble",
		pos + Vector3.new(0, size * 0.2, 0),
		Vector3.new(size, size * 0.6, size * rng:NextNumber(0.8, 1.2)),
		C.rock:Lerp(C.rockMoss, rng:NextNumber(0, 0.5)),
		M.Rock,
		{ CanCollide = size > 1.8, CastShadow = false }
	)
	p.CFrame = p.CFrame * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
	return p
end

return Kit
