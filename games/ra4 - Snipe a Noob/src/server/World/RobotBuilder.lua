-- Robots: classic yellow-and-blue noobs made of boxes, with a tag that says ROBOT so nobody is fooled. Used to
-- fill quiet rounds (they walk and shoot) and as targets on the range (they stand still, kind = "dummy").
-- The model's PrimaryPart "Root" sits where a player's HumanoidRootPart would (the middle of the body), so the
-- same hit shapes work. Every part is anchored; RobotService moves the whole model with PivotTo.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RifleModel = require(ReplicatedStorage.Shared.RifleModel)

local RobotBuilder = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local YELLOW = rgb(245, 205, 48)
local BLUE = rgb(13, 105, 172)
local GREEN = rgb(75, 151, 75)
local INK = rgb(27, 29, 43)
local STRAW = rgb(215, 190, 120)
local RED = rgb(220, 50, 50)

local function box(parent, name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = true
	p.Parent = parent
	return p
end

-- kind: "bot" (a noob that fights) or "dummy" (a range target). Returns the model.
function RobotBuilder.build(name, kind, at)
	at = at or CFrame.new(0, 3, 0)
	local dummy = kind == "dummy"
	local model = Instance.new("Model")
	model.Name = (dummy and "Target_" or "Robot_") .. name
	local root = box(model, "Root", Vector3.new(2, 2, 1), at, BLUE)
	root.Transparency = 1
	model.PrimaryPart = root
	local skin = dummy and STRAW or YELLOW
	local plan = {
		{ "Head", Vector3.new(1.25, 1.25, 1.25), CFrame.new(0, 1.6, 0), skin },
		{ "Torso", Vector3.new(2, 2, 1), CFrame.new(0, 0, 0), dummy and STRAW or BLUE },
		{ "LeftArm", Vector3.new(1, 2, 1), CFrame.new(-1.5, 0, 0), skin },
		{ "RightArm", Vector3.new(1, 2, 1), CFrame.new(1.5, 0.35, -0.5) * CFrame.Angles(math.rad(80), 0, 0), skin },
		{ "LeftLeg", Vector3.new(1, 2, 1), CFrame.new(-0.5, -2, 0), dummy and STRAW or GREEN },
		{ "RightLeg", Vector3.new(1, 2, 1), CFrame.new(0.5, -2, 0), dummy and STRAW or GREEN },
	}
	for _, p in plan do
		box(model, p[1], p[2], at * p[3], p[4])
	end
	if dummy then
		-- a bullseye on the chest and a post
		box(model, "Bull", Vector3.new(1.4, 1.4, 0.1), at * CFrame.new(0, 0, -0.55), rgb(255, 255, 255))
		box(model, "Eye", Vector3.new(0.7, 0.7, 0.12), at * CFrame.new(0, 0, -0.57), RED)
		box(
			model,
			"Post",
			Vector3.new(0.4, 3, 0.4),
			at * CFrame.new(0, -1.5, 0.7),
			rgb(120, 80, 50),
			Enum.Material.Wood
		)
	else
		-- a face, and a rifle in the right hand
		box(model, "EyeL", Vector3.new(0.18, 0.28, 0.05), at * CFrame.new(-0.25, 1.75, -0.64), INK)
		box(model, "EyeR", Vector3.new(0.18, 0.28, 0.05), at * CFrame.new(0.25, 1.75, -0.64), INK)
		box(model, "Smile", Vector3.new(0.5, 0.1, 0.05), at * CFrame.new(0, 1.38, -0.64), INK)
		local rifle = RifleModel.build("BOLT", nil, nil, at * CFrame.new(1.5, 0.4, -1.4))
		rifle.Name = "Rifle"
		for _, p in rifle:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored = true
			end
		end
		rifle.Parent = model
	end
	if dummy then
		return model -- the bullseye says it all
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Tag"
	gui.Size = UDim2.fromOffset(130, 34)
	gui.StudsOffset = Vector3.new(0, 3.3, 0)
	gui.MaxDistance = dummy and 60 or 150
	gui.LightInfluence = 0
	gui.Parent = root
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextStrokeTransparency = 0
	t.TextColor3 = dummy and rgb(255, 230, 160) or rgb(255, 140, 140)
	t.Text = dummy and "🎯 TARGET" or ("🤖 " .. name)
	t.Parent = gui
	return model
end

return RobotBuilder
