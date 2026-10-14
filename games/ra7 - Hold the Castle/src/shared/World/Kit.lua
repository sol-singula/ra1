-- The building kit every builder uses (the server's world, castle pieces, costumes, the client's ghosts and NPCs,
-- the render tools): a bright palette, part helpers, and props made from plain parts. Art direction (master plan
-- §14): bright and full of colour, chunky and friendly, smooth cartoon shapes (not blocks), big readable
-- silhouettes. Small props don't cast shadows or collide, to keep phones fast.
local CollectionService = game:GetService("CollectionService")

local Kit = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
Kit.rgb = rgb

local M = Enum.Material
Kit.M = M

Kit.C = {
	-- the valley
	grass = rgb(118, 196, 72),
	grassLight = rgb(152, 214, 92),
	grassDark = rgb(86, 162, 62),
	path = rgb(232, 206, 150),
	pathDark = rgb(206, 174, 122),
	dirt = rgb(178, 130, 86),
	cliff = rgb(184, 168, 150),
	cliffDark = rgb(146, 130, 118),
	cliffWarm = rgb(206, 170, 128),
	rock = rgb(176, 172, 166),
	rockDark = rgb(136, 132, 128),
	water = rgb(84, 186, 244),
	waterDeep = rgb(52, 144, 214),
	leaf = rgb(98, 192, 80),
	leafDark = rgb(64, 152, 72),
	leafLight = rgb(164, 222, 92),
	autumn = rgb(250, 170, 60),
	bark = rgb(150, 98, 60),
	pine = rgb(48, 154, 98),
	pineDark = rgb(32, 118, 82),
	snow = rgb(246, 248, 255),
	flowerPink = rgb(255, 130, 190),
	flowerYellow = rgb(255, 230, 90),
	flowerWhite = rgb(255, 255, 250),
	flowerBlue = rgb(110, 170, 255),
	-- the castle
	castle = rgb(232, 218, 190),
	castleDark = rgb(184, 164, 138),
	stone = rgb(198, 194, 186),
	stoneDark = rgb(150, 146, 140),
	wood = rgb(198, 126, 66),
	woodDark = rgb(142, 86, 46),
	woodLight = rgb(234, 172, 106),
	roofRed = rgb(226, 74, 62),
	roofBlue = rgb(72, 126, 224),
	gold = rgb(255, 204, 60),
	goldDark = rgb(214, 150, 30),
	iron = rgb(112, 116, 132),
	steel = rgb(178, 184, 198),
	cloth = rgb(236, 70, 70),
	-- magic
	shrine = rgb(96, 232, 255),
	shrineDeep = rgb(40, 160, 232),
	magic = rgb(176, 116, 255),
	plague = rgb(150, 230, 70),
	blueprint = rgb(96, 204, 255),
	-- the monster forest and the cave
	forest = rgb(64, 74, 116),
	forestDark = rgb(42, 46, 84),
	forestLeaf = rgb(82, 96, 158),
	forestGlow = rgb(186, 120, 255),
	cave = rgb(104, 94, 132),
	caveDark = rgb(66, 58, 92),
	crystal = rgb(120, 232, 255),
	crystalPink = rgb(255, 122, 222),
	mushroom = rgb(232, 64, 74),
	mushroomPurple = rgb(176, 112, 236),
	-- everyday
	red = rgb(232, 62, 62),
	blue = rgb(62, 122, 232),
	green = rgb(62, 190, 96),
	white = rgb(250, 248, 240),
	cream = rgb(255, 244, 214),
	black = rgb(30, 28, 36),
	warm = rgb(255, 192, 112),
	fire = rgb(255, 130, 40),
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
		local h = height / steps
		local d = Kit.disc(
			parent,
			name,
			base + Vector3.new(0, h * (i - 0.5), 0),
			diameter * (1 - t * 0.85),
			h,
			color,
			material,
			extra
		)
		d.CastShadow = i == 1 and (extra == nil or extra.CastShadow ~= false)
		first = first or d
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

-- A round cartoon tree: a short trunk and three puffy clumps of leaves.
function Kit.toonTree(parent, pos, h, rng, color)
	rng = rng or Random.new()
	h = h or rng:NextNumber(16, 24)
	local m = Kit.model("Tree", parent)
	Kit.disc(m, "Trunk", pos + Vector3.new(0, h * 0.3, 0), h * 0.11, h * 0.6, C.bark, M.Wood)
	local col = color or C.leaf
	local clumps = {
		{ Vector3.new(0, h * 0.72, 0), 0.62 },
		{ Vector3.new(h * 0.16, h * 0.6, h * 0.08), 0.44 },
		{ Vector3.new(-h * 0.14, h * 0.62, -h * 0.1), 0.46 },
	}
	for i, c in clumps do
		local d = h * c[2] * rng:NextNumber(0.92, 1.08)
		Kit.ball(
			m,
			"Leaves",
			pos + c[1],
			d,
			col:Lerp(C.leafLight, rng:NextNumber(0, 0.3)),
			M.SmoothPlastic,
			{ CastShadow = i == 1, CanCollide = false }
		)
	end
	return m
end

-- A cartoon pine: a trunk and three stacked cones of soft layers, wide at the bottom.
function Kit.toonPine(parent, pos, h, rng, color)
	rng = rng or Random.new()
	h = h or rng:NextNumber(22, 34)
	local m = Kit.model("Pine", parent)
	Kit.disc(m, "Trunk", pos + Vector3.new(0, h * 0.14, 0), h * 0.08, h * 0.28, C.bark, M.Wood)
	local col = color or (rng:NextNumber() < 0.5 and C.pine or C.pineDark)
	for i = 0, 3 do
		local t = i / 3
		local d = h * (0.56 - 0.36 * t)
		Kit.ellipsoid(
			m,
			"Needles",
			pos + Vector3.new(0, h * (0.3 + 0.5 * t), 0),
			Vector3.new(d, h * 0.3, d),
			col:Lerp(C.leafLight, 0.1 * t),
			M.SmoothPlastic,
			{ CastShadow = i < 2, CanCollide = false }
		)
	end
	Kit.ellipsoid(
		m,
		"Top",
		pos + Vector3.new(0, h * 0.94, 0),
		Vector3.new(h * 0.1, h * 0.18, h * 0.1),
		col,
		M.SmoothPlastic,
		{ CastShadow = false, CanCollide = false }
	)
	return m
end

-- A smooth rounded boulder (or a few), sat into the ground.
function Kit.boulder(parent, pos, size, rng, color)
	rng = rng or Random.new()
	size = size or rng:NextNumber(4, 8)
	local col = color or C.rock
	local p = Kit.ellipsoid(
		parent,
		"Boulder",
		pos + Vector3.new(0, size * 0.28, 0),
		Vector3.new(size, size * 0.72, size * rng:NextNumber(0.8, 1.1)),
		col:Lerp(C.rockDark, rng:NextNumber(0, 0.25)),
		M.SmoothPlastic,
		{ CastShadow = size > 5 }
	)
	p.CFrame = p.CFrame * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
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
			M.SmoothPlastic,
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
		Kit.box(m, "Crystal", cf, Vector3.new(w, hh, w), color or C.crystal, M.Neon, { CastShadow = false })
		Kit.box(
			m,
			"Tip",
			cf * CFrame.new(0, hh / 2, 0) * CFrame.Angles(0, math.rad(45), 0),
			Vector3.new(w * 0.7, w * 0.7, w * 0.7),
			(color or C.crystal):Lerp(C.white, 0.3),
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

return Kit
