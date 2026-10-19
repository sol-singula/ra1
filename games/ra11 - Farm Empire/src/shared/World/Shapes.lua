--[[
Part helpers for the builders: anchored, collision-free by default, in the low-poly look (SmoothPlastic, one flat
colour a part, no studs).

  Shapes.part(parent, size, cframe, color, props)      a Block
  Shapes.wedge / Shapes.cylinder / Shapes.ball
  Shapes.model(parent, name)
  Shapes.label(part, text, props)                       a BillboardGui over a part (a sign, a price)
  Shapes.face(part, text, face, props)                  words on a surface
  Shapes.ghost(part)                                    the see-through blue look of a preview
  Shapes.clear(folder)
]]
local Shapes = {}

local function apply(p, props)
	for k, v in props or {} do
		p[k] = v
	end
end

function Shapes.part(parent, size, cframe, color, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = (props and props.CanCollide) or false
	p.CanQuery = (props and props.CanQuery) ~= false
	p.CanTouch = false
	p.CastShadow = true
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

-- A sign over a part: white outlined letters, readable from a way off
function Shapes.label(part, text, props)
	props = props or {}
	local bb = Instance.new("BillboardGui")
	bb.Name = props.Name or "Label"
	bb.Size = props.Size or UDim2.fromOffset(220, 50)
	bb.StudsOffset = props.StudsOffset or Vector3.new(0, 4, 0)
	bb.AlwaysOnTop = props.AlwaysOnTop == true
	bb.MaxDistance = props.MaxDistance or 120
	bb.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = props.BackgroundTransparency or 1
	label.BackgroundColor3 = props.BackgroundColor3 or Color3.fromRGB(40, 30, 24)
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = props.TextColor3 or Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(40, 30, 24)
	label.Text = text
	label.Parent = bb
	if props.BackgroundTransparency and props.BackgroundTransparency < 1 then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = label
	end
	bb.Parent = part
	return bb
end

-- Words on a surface of a part (a shop's sign board)
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
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = props.TextColor3 or Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = props.TextStrokeTransparency or 0
	label.TextStrokeColor3 = Color3.fromRGB(40, 30, 24)
	label.Text = text
	label.Parent = sg
	sg.Parent = part
	return sg
end

-- The preview look: see-through blue, no collisions
function Shapes.ghost(part, color)
	part.Color = color or Color3.fromRGB(120, 200, 255)
	part.Transparency = 0.6
	part.CanCollide = false
	part.CastShadow = false
	part.Material = Enum.Material.ForceField
	return part
end

-- A low-poly tree: a trunk and two or three leaf blocks
function Shapes.tree(parent, cframe, scale, leafColor)
	scale = scale or 1
	local m = Shapes.model(parent, "Tree")
	local trunk = Color3.fromRGB(122, 80, 46)
	Shapes.part(m, Vector3.new(1.2 * scale, 4 * scale, 1.2 * scale), cframe * CFrame.new(0, 2 * scale, 0), trunk)
	local leaf = leafColor or Color3.fromRGB(70, 170, 80)
	Shapes.part(m, Vector3.new(5 * scale, 4 * scale, 5 * scale), cframe * CFrame.new(0, 5.5 * scale, 0), leaf)
	Shapes.part(
		m,
		Vector3.new(3.4 * scale, 2.6 * scale, 3.4 * scale),
		cframe * CFrame.new(0, 8.4 * scale, 0),
		leaf:Lerp(Color3.new(1, 1, 1), 0.15)
	)
	return m
end

return Shapes
