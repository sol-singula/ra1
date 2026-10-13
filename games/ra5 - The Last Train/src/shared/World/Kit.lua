-- The building kit every builder uses (server world, client travel scenery, cabin ghosts): a controlled palette of
-- colours and materials, part helpers, and props made from plain parts (trees, rocks, lamps, crates, barrels,
-- signs). Art direction: stylized cinematic realism. Rich materials and warm practical lights against cool misty
-- outdoors; readable silhouettes. Small props don't cast shadows, to keep phones fast.
local Kit = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
Kit.rgb = rgb

local M = Enum.Material
Kit.M = M

Kit.C = {
	-- the train
	green = rgb(30, 66, 50),
	greenDark = rgb(19, 44, 34),
	cream = rgb(226, 212, 178),
	brass = rgb(201, 156, 74),
	brassDark = rgb(150, 110, 50),
	roof = rgb(46, 44, 46),
	iron = rgb(40, 40, 44),
	steel = rgb(112, 114, 120),
	wheel = rgb(150, 36, 30),
	wood = rgb(124, 76, 44),
	woodDark = rgb(72, 44, 28),
	woodLight = rgb(178, 128, 80),
	carpet = rgb(110, 30, 34),
	glass = rgb(150, 190, 200),
	warm = rgb(255, 190, 120),
	-- the world
	grass = rgb(66, 96, 48),
	grassDark = rgb(46, 70, 36),
	moss = rgb(84, 112, 56),
	dirt = rgb(98, 78, 58),
	gravel = rgb(112, 106, 98),
	concrete = rgb(148, 144, 134),
	concreteDark = rgb(104, 100, 94),
	rust = rgb(138, 74, 42),
	rustDark = rgb(96, 52, 34),
	pine = rgb(42, 78, 52),
	pineDark = rgb(30, 58, 40),
	leaf = rgb(70, 104, 50),
	bark = rgb(82, 58, 42),
	rock = rgb(108, 106, 102),
	red = rgb(196, 40, 40),
	white = rgb(236, 232, 222),
	black = rgb(18, 18, 20),
	signal = rgb(255, 70, 50),
	fuel = rgb(206, 48, 40),
	blueprint = rgb(70, 130, 230),
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
	local props = { Name = name, CFrame = cf, Size = size, Color = color, Material = material or M.SmoothPlastic, Parent = parent }
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
		local d = Kit.disc(parent, name, base + Vector3.new(0, h * (i - 0.5), 0), diameter * (1 - t * 0.85), h, color, material, extra)
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
	local b = Kit.ball(parent, name, center, diameter, color or C.warm, M.Neon, { CastShadow = false, CanCollide = false })
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
	local board = Kit.box(parent, opts.name or "Sign", cf, Vector3.new(w, h, 0.4), opts.color or C.greenDark, M.Wood)
	Kit.box(parent, "SignFrame", cf * CFrame.new(0, 0, 0.12), Vector3.new(w + 0.5, h + 0.5, 0.3), opts.frame or C.brassDark, M.Metal, { CastShadow = false })
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

-- A fir: a dark trunk and five soft layers of branches, wide at the bottom, narrow at the top.
function Kit.pine(parent, pos, h, rng, color)
	rng = rng or Random.new()
	h = h or rng:NextNumber(26, 44)
	local m = Kit.model("Pine", parent)
	local trunkH = h * 0.32
	Kit.disc(m, "Trunk", pos + Vector3.new(0, trunkH / 2, 0), h * 0.055, trunkH, C.bark, M.Wood)
	local col = color or (rng:NextNumber() < 0.5 and C.pine or C.pineDark)
	local tiers = 5
	for i = 0, tiers - 1 do
		local t = i / (tiers - 1)
		local d = h * (0.56 - 0.4 * t)
		Kit.ellipsoid(
			m,
			"Needles",
			pos + Vector3.new(rng:NextNumber(-0.3, 0.3), h * (0.24 + 0.6 * t), rng:NextNumber(-0.3, 0.3)),
			Vector3.new(d, d * 0.46, d),
			col:Lerp(C.moss, (1 - t) * 0.12),
			M.Grass,
			{ CastShadow = i < 2, CanCollide = false }
		)
	end
	Kit.ellipsoid(m, "Top", pos + Vector3.new(0, h * 0.93, 0), Vector3.new(h * 0.1, h * 0.2, h * 0.1), col, M.Grass, { CastShadow = false, CanCollide = false })
	return m
end

-- A leafy tree: trunk and a few overlapping leaf clumps.
function Kit.oak(parent, pos, h, rng, color)
	rng = rng or Random.new()
	h = h or rng:NextNumber(18, 28)
	local m = Kit.model("Tree", parent)
	Kit.disc(m, "Trunk", pos + Vector3.new(0, h * 0.3, 0), h * 0.09, h * 0.6, C.bark, M.Wood)
	local col = color or C.leaf
	for i = 1, 4 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = h * 0.14
		local d = h * rng:NextNumber(0.42, 0.56)
		Kit.ellipsoid(
			m,
			"Leaves",
			pos + Vector3.new(math.cos(a) * r, h * rng:NextNumber(0.62, 0.8), math.sin(a) * r),
			Vector3.new(d, d * 0.78, d),
			col:Lerp(C.moss, rng:NextNumber(0, 0.4)),
			M.Grass,
			{ CastShadow = i <= 2, CanCollide = false }
		)
	end
	return m
end

function Kit.bush(parent, pos, size, rng)
	rng = rng or Random.new()
	size = size or rng:NextNumber(3, 6)
	for i = 1, 3 do
		Kit.ball(
			parent,
			"Bush",
			pos + Vector3.new(rng:NextNumber(-1, 1) * size * 0.4, size * 0.3, rng:NextNumber(-1, 1) * size * 0.4),
			size * rng:NextNumber(0.6, 1),
			C.grassDark:Lerp(C.moss, rng:NextNumber(0, 0.6)),
			M.Grass,
			{ CastShadow = false, CanCollide = i == 1 }
		)
	end
end

function Kit.rock(parent, pos, size, rng)
	rng = rng or Random.new()
	size = size or rng:NextNumber(2, 6)
	local cf = CFrame.new(pos + Vector3.new(0, size * 0.3, 0))
		* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi), rng:NextNumber(-0.3, 0.3))
	return Kit.box(parent, "Rock", cf, Vector3.new(size, size * 0.7, size * 0.85), C.rock:Lerp(C.moss, rng:NextNumber(0, 0.25)), M.Slate)
end

-- A tall grass tuft / fern (thin wedges), no collision.
function Kit.fern(parent, pos, rng)
	rng = rng or Random.new()
	for i = 1, 3 do
		local a = rng:NextNumber(0, math.pi * 2)
		Kit.wedge(
			parent,
			"Fern",
			CFrame.new(pos + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, a, 0) * CFrame.Angles(math.rad(-15), 0, 0),
			Vector3.new(0.2, 1.8, 1.4),
			C.grass:Lerp(C.moss, rng:NextNumber(0, 0.5)),
			M.Grass,
			{ CanCollide = false, CastShadow = false }
		)
	end
end

-- A lamp post with a warm lantern and light.
function Kit.lampPost(parent, pos, h, color)
	h = h or 12
	local m = Kit.model("LampPost", parent)
	Kit.disc(m, "Post", pos + Vector3.new(0, h / 2, 0), 0.5, h, C.iron, M.Metal)
	Kit.box(m, "Arm", CFrame.new(pos + Vector3.new(0.9, h - 0.4, 0)), Vector3.new(2, 0.3, 0.3), C.iron, M.Metal)
	Kit.box(m, "Hood", CFrame.new(pos + Vector3.new(1.7, h - 0.6, 0)), Vector3.new(1.4, 0.4, 1.4), C.iron, M.Metal)
	local bulb = Kit.ball(m, "Lantern", pos + Vector3.new(1.7, h - 1.2, 0), 0.9, color or C.warm, M.Neon, { CastShadow = false })
	Kit.light(bulb, "PointLight", { Color = color or C.warm, Range = 22, Brightness = 1.8 })
	return m, bulb
end

function Kit.crate(parent, cf, size, color)
	size = size or Vector3.new(3, 3, 3)
	local m = Kit.model("Crate", parent)
	Kit.box(m, "Box", cf, size, color or C.woodLight, M.WoodPlanks)
	local t = 0.25
	for _, y in { -1, 1 } do
		Kit.box(m, "Band", cf * CFrame.new(0, y * (size.Y / 2 - t), 0), size + Vector3.new(0.12, -size.Y + t * 2, 0.12), C.woodDark, M.Wood, { CastShadow = false })
	end
	return m
end

function Kit.barrel(parent, pos, color, h)
	h = h or 3.2
	local m = Kit.model("Barrel", parent)
	Kit.disc(m, "Barrel", pos + Vector3.new(0, h / 2, 0), 2.4, h, color or C.rust, M.CorrodedMetal)
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
		Kit.box(m, "Post", CFrame.new(p + Vector3.new(0, 1.6, 0)), Vector3.new(0.5, 3.2, 0.5), color or C.woodDark, M.Wood)
	end
	local mid = a + dir / 2
	local look = CFrame.lookAt(mid, b)
	for _, y in { 1.2, 2.5 } do
		Kit.box(m, "Rail", look + Vector3.new(0, y, 0), Vector3.new(0.25, 0.4, len), color or C.woodDark, M.Wood, { CastShadow = false })
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
			Kit.cyl(m, "Log", cf * CFrame.new(0, d / 2 + r * d * 0.86, z), length, d, C.bark:Lerp(C.woodLight, 0.25), M.Wood)
		end
	end
	return m
end

-- Railway track (two rails on sleepers) along X, centred on `cf`, `length` long.
function Kit.track(parent, cf, length)
	local m = Kit.model("Track", parent)
	Kit.box(m, "Ballast", cf * CFrame.new(0, -0.35, 0), Vector3.new(length, 0.7, 14), C.gravel, M.Pebble)
	for _, z in { -2.9, 2.9 } do
		Kit.box(m, "Rail", cf * CFrame.new(0, 0.35, z), Vector3.new(length, 0.5, 0.5), C.steel, M.Metal, { CastShadow = false })
	end
	local n = math.floor(length / 3)
	for i = 0, n - 1 do
		Kit.box(m, "Sleeper", cf * CFrame.new(-length / 2 + 1.5 + i * 3, 0.05, 0), Vector3.new(1.2, 0.3, 9), C.woodDark, M.Wood, { CastShadow = false })
	end
	return m
end

-- Invisible wall that keeps players inside an area.
function Kit.wall(parent, cf, size)
	return Kit.box(parent, "Boundary", cf, size, C.black, M.SmoothPlastic, { Transparency = 1, CanQuery = false, CastShadow = false })
end

return Kit
