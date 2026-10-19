--[[
Part helpers for the builders: anchored, collision-free by default, in the low-poly look (SmoothPlastic, one flat
colour a part, no studs).

  Shapes.part(parent, size, cframe, color, props)      a Block
  Shapes.wedge / Shapes.cylinder / Shapes.ball
  Shapes.sphere(parent, size, cframe, color, props)    a smooth sphere (a sphere mesh: any proportions)
  Shapes.model(parent, name) / Shapes.folder(parent, name) / Shapes.clear(inst)
  Shapes.sign(parent, cframe, w, h, title, line, opts) a signboard: a framed board on posts, words on both faces
  Shapes.face(part, text, face, props)                 words on one surface of a part
  Shapes.label(part, text, props)                      a BillboardGui over a part (opts.studs: sized in studs)
  Shapes.tree(parent, cframe, scale, leafColor)        a round low-poly tree
  Shapes.shade(color, k)                               darker (k < 0) or lighter (k > 0)
]]
local Shapes = {}

local INK = Color3.fromRGB(58, 38, 28)
local CREAM = Color3.fromRGB(252, 244, 222)

local function apply(p, props)
	for k, v in props or {} do
		p[k] = v
	end
end

function Shapes.shade(c, k)
	if k < 0 then
		return c:Lerp(Color3.new(0, 0, 0), -k)
	end
	return c:Lerp(Color3.new(1, 1, 1), k)
end

function Shapes.part(parent, size, cframe, color, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = (props and props.CanCollide) or false
	p.CanQuery = not props or props.CanQuery ~= false
	p.CanTouch = false
	p.CastShadow = math.max(size.X, size.Y, size.Z) >= 3
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	apply(p, props)
	p.Parent = parent
	return p
end

function Shapes.wedge(parent, size, cframe, color, props)
	local p = Instance.new("WedgePart")
	p.Anchored = true
	p.CanCollide = (props and props.CanCollide) or false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	apply(p, props)
	p.Parent = parent
	return p
end

function Shapes.cylinder(parent, size, cframe, color, props)
	local p = Shapes.part(parent, size, cframe, color, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end

function Shapes.ball(parent, size, cframe, color, props)
	local p = Shapes.part(parent, size, cframe, color, props)
	p.Shape = Enum.PartType.Ball
	return p
end

-- A sphere of any proportions (a sphere mesh on a block): canopies, fruit, bushes
function Shapes.sphere(parent, size, cframe, color, props)
	local p = Shapes.part(parent, size, cframe, color, props)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

function Shapes.model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

function Shapes.folder(parent, name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

function Shapes.clear(inst)
	if inst then
		for _, c in inst:GetChildren() do
			c:Destroy()
		end
	end
end

-- Words on a surface: padded, scaled to fit
function Shapes.face(part, text, face, props)
	props = props or {}
	local sg = Instance.new("SurfaceGui")
	sg.Name = props.Name or "Face"
	sg.Face = face or Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = props.PixelsPerStud or 40
	sg.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(props.fill or 0.9, props.fillY or 0.8)
	label.Font = props.Font or Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = props.TextColor3 or Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = props.TextStrokeTransparency or 0
	label.TextStrokeColor3 = props.TextStrokeColor3 or INK
	label.Text = text
	label.Parent = sg
	sg.Parent = part
	return sg
end

-- A signboard: two posts, a dark frame and a cream board, the title big and an optional line under it, readable
-- from both sides. cframe: the ground point under the board's middle, facing the reader (-z).
--   opts: { board = colour, frame = colour, ink = text colour, accent = the title's colour, bottom = board's
--           height off the ground (default 2), posts = false (a board on a wall), back = false (one face) }
function Shapes.sign(parent, cframe, w, h, title, line, opts)
	opts = opts or {}
	local m = Shapes.model(parent, opts.name or "Sign")
	local bottom = opts.bottom or 2
	local frame = opts.frame or Color3.fromRGB(110, 72, 44)
	if opts.posts ~= false then
		for _, x in { -w / 2 + 0.5, w / 2 - 0.5 } do
			Shapes.part(m, Vector3.new(0.5, bottom + h, 0.5), cframe * CFrame.new(x, (bottom + h) / 2, 0.15), frame)
		end
	end
	Shapes.part(m, Vector3.new(w + 0.5, h + 0.5, 0.3), cframe * CFrame.new(0, bottom + h / 2, 0.1), frame)
	local board =
		Shapes.part(m, Vector3.new(w, h, 0.4), cframe * CFrame.new(0, bottom + h / 2, -0.1), opts.board or CREAM)
	board.Name = "Board"
	local function words(face)
		local sg = Instance.new("SurfaceGui")
		sg.Face = face
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = opts.ppi or 50
		sg.LightInfluence = 0
		local hasLine = line ~= nil and line ~= ""
		local t = Instance.new("TextLabel")
		t.Name = "Title"
		t.BackgroundTransparency = 1
		t.Position = UDim2.fromScale(0.06, hasLine and 0.08 or 0.12)
		t.Size = UDim2.fromScale(0.88, hasLine and 0.52 or 0.76)
		t.Font = Enum.Font.GothamBlack
		t.TextScaled = true
		t.TextColor3 = opts.accent or opts.ink or INK
		t.Text = title
		t.Parent = sg
		if hasLine then
			local l = Instance.new("TextLabel")
			l.Name = "Line"
			l.BackgroundTransparency = 1
			l.Position = UDim2.fromScale(0.08, 0.6)
			l.Size = UDim2.fromScale(0.84, 0.3)
			l.Font = Enum.Font.GothamBold
			l.TextScaled = true
			l.TextColor3 = opts.ink or INK
			l.Text = line
			l.Parent = sg
		end
		sg.Parent = board
		return sg
	end
	words(Enum.NormalId.Front)
	if opts.back ~= false then
		words(Enum.NormalId.Back)
	end
	return m, board
end

-- A sign over a part: a dark rounded tag with white words (opts.studs = Vector2: sized in studs, so it shrinks
-- with distance like the world does, instead of covering the screen from afar)
function Shapes.label(part, text, props)
	props = props or {}
	local bb = Instance.new("BillboardGui")
	bb.Name = props.Name or "Label"
	if props.studs then
		bb.Size = UDim2.new(props.studs.X, 0, props.studs.Y, 0)
	else
		bb.Size = props.Size or UDim2.fromOffset(220, 50)
	end
	bb.StudsOffset = props.StudsOffset or Vector3.new(0, 4, 0)
	bb.AlwaysOnTop = props.AlwaysOnTop == true
	bb.MaxDistance = props.MaxDistance or 80
	bb.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = props.BackgroundTransparency or 0.15
	label.BackgroundColor3 = props.BackgroundColor3 or Color3.fromRGB(40, 30, 24)
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = props.TextColor3 or Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = props.BackgroundTransparency == 1 and 0 or 1
	label.TextStrokeColor3 = INK
	label.Text = text
	label.Parent = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.25, 0)
	corner.Parent = label
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.06, 0)
	pad.PaddingRight = UDim.new(0.06, 0)
	pad.PaddingTop = UDim.new(0.1, 0)
	pad.PaddingBottom = UDim.new(0.1, 0)
	pad.Parent = label
	bb.Parent = part
	return bb
end

-- The old see-through look of a preview
function Shapes.ghost(part, color)
	part.Color = color or Color3.fromRGB(120, 200, 255)
	part.Transparency = 0.78
	part.CanCollide = false
	part.CastShadow = false
	part.Material = Enum.Material.ForceField
	return part
end

-- A round low-poly tree: a trunk and three overlapping canopy spheres
function Shapes.tree(parent, cframe, scale, leafColor)
	scale = scale or 1
	local m = Shapes.model(parent, "Tree")
	local trunk = Color3.fromRGB(122, 80, 46)
	Shapes.cylinder(
		m,
		Vector3.new(5 * scale, 1.3 * scale, 1.3 * scale),
		cframe * CFrame.new(0, 2.5 * scale, 0) * CFrame.Angles(0, 0, math.pi / 2),
		trunk
	)
	local leaf = leafColor or Color3.fromRGB(70, 170, 80)
	Shapes.sphere(m, Vector3.new(6.2, 5.2, 6.2) * scale, cframe * CFrame.new(0, 6.6 * scale, 0), leaf)
	Shapes.sphere(
		m,
		Vector3.new(4.2, 3.8, 4.2) * scale,
		cframe * CFrame.new(1.6 * scale, 8.2 * scale, 0.8 * scale),
		Shapes.shade(leaf, 0.14)
	)
	Shapes.sphere(
		m,
		Vector3.new(3.8, 3.4, 3.8) * scale,
		cframe * CFrame.new(-1.4 * scale, 7.6 * scale, -1 * scale),
		Shapes.shade(leaf, -0.1)
	)
	return m
end

return Shapes
