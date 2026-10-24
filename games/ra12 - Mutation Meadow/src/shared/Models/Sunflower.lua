--[[
The Block Party sunflower, shared by the street (StreetBuilder, BlockPartyService) and the capture stage: a stem with
leaves, and one head per look (Drooping, Perking, Standing, Bloom, Wilt), each a Model of a seed centre, a green
calyx and a ring of petals. One look shows at a time. The head faces cf's LookVector.

  Sunflower.build(parent, cf) -> Model "Sunflower" (Stem first: the prompt and the range centre)
  Sunflower.setLook(model, look) / look(model)
  Sunflower.LOOKS
]]
local Kit = require(script.Parent.Kit)

local Sunflower = {}

local rad = math.rad

Sunflower.LOOKS = { "Drooping", "Perking", "Standing", "Bloom", "Wilt" }
Sunflower.STEM_HEIGHT = 14
Sunflower.PETALS = 14

-- look -> petal colour, head height, droop (degrees), size
local LOOK = {
	Drooping = { Color3.fromRGB(170, 150, 60), 12.6, 70, 0.75 },
	Perking = { Color3.fromRGB(220, 190, 50), 13.6, 40, 0.85 },
	Standing = { Color3.fromRGB(250, 210, 40), 14.4, 15, 0.95 },
	Bloom = { Color3.fromRGB(255, 205, 20), 15, 0, 1.15 },
	Wilt = { Color3.fromRGB(130, 110, 70), 12, 85, 0.7 },
}

local STEM = Color3.fromRGB(70, 140, 50)
local LEAF = Color3.fromRGB(80, 156, 58)
local SEEDS = Color3.fromRGB(96, 62, 30)
local CALYX = Color3.fromRGB(64, 120, 46)

local function head(model, name, cf)
	local look = LOOK[name]
	local s = look[4]
	local m = Kit.model(model, name)
	local at = cf * CFrame.new(0, look[2], -0.5) * CFrame.Angles(-rad(look[3]), 0, 0)
	local facing = CFrame.Angles(0, rad(90), 0) -- a cylinder's axis turned to face forward
	local centre = Kit.part(
		m,
		"Centre",
		Vector3.new(0.6, 3.2 * s, 3.2 * s),
		at * CFrame.new(0, 0, -0.15) * facing,
		SEEDS,
		Enum.Material.Fabric
	)
	centre.Shape = Enum.PartType.Cylinder
	local calyx = Kit.part(m, "Calyx", Vector3.new(0.4, 3.8 * s, 3.8 * s), at * CFrame.new(0, 0, 0.25) * facing, CALYX)
	calyx.Shape = Enum.PartType.Cylinder
	for i = 1, Sunflower.PETALS do
		local a = rad(i * 360 / Sunflower.PETALS)
		Kit.ball(
			m,
			"Petal" .. i,
			Vector3.new(1.15, 2.7, 0.22) * s,
			at * CFrame.Angles(0, 0, a) * CFrame.new(0, 2.25 * s, 0.05),
			look[1]
		)
	end
	return m
end

function Sunflower.build(parent, cf)
	local model = Instance.new("Model")
	model.Name = "Sunflower"
	local stem = Kit.cylinder(
		model,
		"Stem",
		Sunflower.STEM_HEIGHT,
		1.1,
		cf * CFrame.new(0, Sunflower.STEM_HEIGHT / 2, 0),
		STEM,
		Enum.Material.Grass
	)
	stem.CanQuery = true -- the Water prompt sits on it
	for i, h in { 3, 5.5, 8, 10.5 } do
		local side = if i % 2 == 0 then -1 else 1
		Kit.ball(
			model,
			"Leaf" .. i,
			Vector3.new(3.2, 0.25, 1.6),
			cf * CFrame.new(1.6 * side, h, 0) * CFrame.Angles(0, 0, rad(18 * side)),
			LEAF
		)
	end
	for _, name in Sunflower.LOOKS do
		head(model, name, cf)
	end
	Sunflower.setLook(model, "Drooping")
	model.PrimaryPart = stem
	model.Parent = parent
	return model
end

function Sunflower.setLook(model, look)
	for _, name in Sunflower.LOOKS do
		local m = model:FindFirstChild(name)
		if m then
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					d.Transparency = if name == look then 0 else 1
				end
			end
		end
	end
	model:SetAttribute("Look", look)
end

function Sunflower.look(model)
	return model:GetAttribute("Look")
end

return Sunflower
