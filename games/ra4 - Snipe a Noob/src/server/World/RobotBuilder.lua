-- Robot knights: friendly NPCs that fill a quiet raid. A blocky robot with a glowing visor and a tag that says
-- ROBOT, so nobody is fooled. Anchored; RaidService moves it.
local RobotBuilder = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local STEEL = rgb(150, 160, 185)
local DARK = rgb(70, 75, 95)

local function box(parent, name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Metal
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

-- Returns the model (PrimaryPart "Root" at the feet) and its parts with offsets, for posing.
function RobotBuilder.build(name, color)
	color = color or rgb(120, 220, 255)
	local model = Instance.new("Model")
	model.Name = "Robot_" .. name
	local root = box(model, "Root", Vector3.new(2, 1, 2), CFrame.new(), STEEL)
	root.Transparency = 1
	model.PrimaryPart = root
	local parts = {}
	local plan = {
		{ "LegL", Vector3.new(0.7, 1.6, 0.7), CFrame.new(-0.5, 0.8, 0), DARK },
		{ "LegR", Vector3.new(0.7, 1.6, 0.7), CFrame.new(0.5, 0.8, 0), DARK },
		{ "Torso", Vector3.new(2, 1.9, 1.2), CFrame.new(0, 2.6, 0), STEEL },
		{ "Chest", Vector3.new(1.2, 0.8, 0.2), CFrame.new(0, 2.8, -0.65), color, Enum.Material.Neon },
		{ "ArmL", Vector3.new(0.6, 1.6, 0.6), CFrame.new(-1.35, 2.5, 0), STEEL },
		{ "ArmR", Vector3.new(0.6, 1.6, 0.6), CFrame.new(1.35, 2.5, 0), STEEL },
		{ "Blaster", Vector3.new(0.5, 0.5, 1.6), CFrame.new(1.35, 1.7, -0.6), DARK },
		{ "Head", Vector3.new(1.4, 1.2, 1.2), CFrame.new(0, 4.2, 0), STEEL },
		{ "Visor", Vector3.new(1.2, 0.4, 0.15), CFrame.new(0, 4.3, -0.62), color, Enum.Material.Neon },
		{ "Antenna", Vector3.new(0.15, 0.8, 0.15), CFrame.new(0.4, 5.2, 0), DARK },
		{ "AntennaTip", Vector3.new(0.35, 0.35, 0.35), CFrame.new(0.4, 5.7, 0), color, Enum.Material.Neon },
	}
	for _, p in plan do
		local part = box(model, p[1], p[2], p[3], p[4], p[5])
		table.insert(parts, { part = part, offset = p[3] })
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Tag"
	gui.Size = UDim2.fromOffset(120, 40)
	gui.StudsOffset = Vector3.new(0, 6.6, 0)
	gui.MaxDistance = 120
	gui.LightInfluence = 0
	gui.AlwaysOnTop = true
	gui.Parent = root
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextStrokeTransparency = 0
	t.TextColor3 = color
	t.Text = "🤖 ROBOT " .. name
	t.Parent = gui
	return model, parts
end

function RobotBuilder.pose(robot, cf)
	robot.model.PrimaryPart.CFrame = cf
	for _, p in robot.parts do
		p.part.CFrame = cf * p.offset
	end
end

return RobotBuilder
