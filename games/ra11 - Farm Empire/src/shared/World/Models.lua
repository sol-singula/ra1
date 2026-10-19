--[[
The moving things, built from parts: the machines (auto-harvester, tractor, combine), the trucks, the forklift and
the little people (customers and workers). Low-poly, one colour a part, chunky enough to read from the default
camera. Every model's PrimaryPart is its body; the client moves it by its PrimaryPart's CFrame.

  Models.machine(parent, tier, color)   1 harvester · 2 tractor · 3 combine · 4 (the fleet uses two combines)
  Models.truck(parent, color)
  Models.forklift(parent)
  Models.person(parent, shirt)          a blocky figure with a Body, Head, LegL, LegR
  Models.place(person, cframe)          stand a person at a CFrame (feet on the ground)
  Models.pallet(parent, cframe, crop)
]]
local Shapes = require(script.Parent.Shapes)

local Models = {}

local rgb = Color3.fromRGB
local STEEL = rgb(96, 100, 110)
local TYRE = rgb(40, 40, 44)
local GLASS = rgb(150, 206, 236)

local function wheel(m, cframe, r, w)
	local p = Shapes.cylinder(m, Vector3.new(w, r * 2, r * 2), cframe * CFrame.Angles(0, 0, math.pi / 2), TYRE)
	p.Name = "Wheel"
	Shapes.cylinder(m, Vector3.new(w + 0.1, r, r), cframe * CFrame.Angles(0, 0, math.pi / 2), rgb(200, 200, 200))
	return p
end

function Models.machine(parent, tier, color)
	color = color or rgb(222, 56, 48)
	local m = Shapes.model(parent, "Machine")
	m:SetAttribute("Tier", tier)
	local body
	if tier == 1 then
		-- the auto-harvester: a small boxy robot on four wheels with a cutter bar in front
		body = Shapes.part(m, Vector3.new(3.4, 2, 4.2), CFrame.new(0, 1.9, 0), color)
		Shapes.part(m, Vector3.new(2.6, 0.8, 2), CFrame.new(0, 3.2, 0.4), rgb(240, 240, 240))
		Shapes.part(m, Vector3.new(4.2, 0.6, 1), CFrame.new(0, 0.9, 2.6), STEEL) -- cutter
		Shapes.part(m, Vector3.new(0.4, 1.2, 0.4), CFrame.new(1.2, 3.9, -1), STEEL)
		Shapes.ball(m, Vector3.new(0.7, 0.7, 0.7), CFrame.new(1.2, 4.6, -1), rgb(255, 200, 36))
		for _, x in { -1.6, 1.6 } do
			for _, z in { -1.4, 1.4 } do
				wheel(m, CFrame.new(x, 0.9, z), 0.9, 0.7)
			end
		end
	elseif tier == 2 then
		-- the tractor: a tall cab, big back wheels, a hopper trailer behind
		body = Shapes.part(m, Vector3.new(3.2, 2.2, 5), CFrame.new(0, 2.3, 0.4), color)
		Shapes.part(m, Vector3.new(3, 2.6, 2.4), CFrame.new(0, 4.6, -0.6), color:Lerp(Color3.new(0, 0, 0), 0.25))
		Shapes.part(m, Vector3.new(2.6, 1.6, 2), CFrame.new(0, 4.8, -0.6), GLASS)
		Shapes.part(m, Vector3.new(3.2, 0.3, 2.6), CFrame.new(0, 6.05, -0.6), rgb(240, 240, 240))
		Shapes.cylinder(
			m,
			Vector3.new(1.6, 0.5, 0.5),
			CFrame.new(1, 4.2, 1.8) * CFrame.Angles(0, 0, math.pi / 2),
			STEEL
		)
		wheel(m, CFrame.new(-1.9, 1.1, 1.8), 1.1, 0.8)
		wheel(m, CFrame.new(1.9, 1.1, 1.8), 1.1, 0.8)
		wheel(m, CFrame.new(-1.9, 1.7, -1.4), 1.7, 1)
		wheel(m, CFrame.new(1.9, 1.7, -1.4), 1.7, 1)
		-- trailer
		Shapes.part(m, Vector3.new(3.4, 1.8, 4), CFrame.new(0, 2.4, -5.4), rgb(90, 140, 70))
		Shapes.part(m, Vector3.new(0.4, 0.4, 2.6), CFrame.new(0, 1.8, -3.2), STEEL)
		wheel(m, CFrame.new(-1.9, 1, -5.6), 1, 0.7)
		wheel(m, CFrame.new(1.9, 1, -5.6), 1, 0.7)
	else
		-- the combine: a wide header, a tall body, a chute
		body = Shapes.part(m, Vector3.new(4.4, 3.2, 7), CFrame.new(0, 3, 0), color)
		Shapes.part(m, Vector3.new(3.6, 2.6, 2.6), CFrame.new(0, 5.9, 1.6), color:Lerp(Color3.new(0, 0, 0), 0.25))
		Shapes.part(m, Vector3.new(3.2, 1.6, 2.2), CFrame.new(0, 6.1, 1.6), GLASS)
		Shapes.part(m, Vector3.new(9, 1.2, 2.2), CFrame.new(0, 1.3, 4.6), rgb(255, 200, 36)) -- header
		for i = -3, 3 do
			Shapes.wedge(m, Vector3.new(1, 0.8, 1), CFrame.new(i * 1.3, 1.3, 5.9) * CFrame.Angles(0, math.pi, 0), STEEL)
		end
		Shapes.cylinder(m, Vector3.new(6, 0.8, 0.8), CFrame.new(3.6, 5.6, -1) * CFrame.Angles(0, 0, math.pi / 2), STEEL) -- chute
		wheel(m, CFrame.new(-2.4, 1.9, 1.6), 1.9, 1.2)
		wheel(m, CFrame.new(2.4, 1.9, 1.6), 1.9, 1.2)
		wheel(m, CFrame.new(-2, 1.1, -2.6), 1.1, 0.9)
		wheel(m, CFrame.new(2, 1.1, -2.6), 1.1, 0.9)
	end
	body.Name = "Body"
	m.PrimaryPart = body
	return m
end

function Models.truck(parent, color)
	color = color or rgb(242, 244, 246)
	local m = Shapes.model(parent, "Truck")
	local body = Shapes.part(m, Vector3.new(4, 4.2, 10), CFrame.new(0, 3.6, -2), color) -- the box
	body.Name = "Body"
	Shapes.part(m, Vector3.new(3.8, 2.8, 3.2), CFrame.new(0, 2.6, 4.6), rgb(60, 110, 200)) -- the cab
	Shapes.part(m, Vector3.new(3.4, 1.4, 1), CFrame.new(0, 3.4, 5.8), GLASS)
	Shapes.part(m, Vector3.new(4.2, 1.2, 14), CFrame.new(0, 1.3, 0), STEEL) -- chassis
	for _, z in { 4.4, -0.6, -4.2 } do
		wheel(m, CFrame.new(-2.1, 1.1, z), 1.1, 0.8)
		wheel(m, CFrame.new(2.1, 1.1, z), 1.1, 0.8)
	end
	m.PrimaryPart = body
	return m
end

function Models.forklift(parent)
	local m = Shapes.model(parent, "Forklift")
	local body = Shapes.part(m, Vector3.new(2.6, 1.6, 3.4), CFrame.new(0, 1.6, 0), rgb(255, 200, 36))
	body.Name = "Body"
	Shapes.part(m, Vector3.new(0.3, 4, 0.3), CFrame.new(-1, 3.2, 2), STEEL)
	Shapes.part(m, Vector3.new(0.3, 4, 0.3), CFrame.new(1, 3.2, 2), STEEL)
	Shapes.part(m, Vector3.new(2.4, 0.2, 2), CFrame.new(0, 0.5, 3.2), STEEL)
	Shapes.part(m, Vector3.new(2.4, 0.3, 2.4), CFrame.new(0, 3.4, -0.4), rgb(40, 40, 44)) -- roof
	Shapes.part(m, Vector3.new(0.2, 1.8, 0.2), CFrame.new(-1.1, 2.6, -1.4), rgb(40, 40, 44))
	Shapes.part(m, Vector3.new(0.2, 1.8, 0.2), CFrame.new(1.1, 2.6, -1.4), rgb(40, 40, 44))
	wheel(m, CFrame.new(-1.4, 0.6, 1), 0.6, 0.5)
	wheel(m, CFrame.new(1.4, 0.6, 1), 0.6, 0.5)
	wheel(m, CFrame.new(-1.4, 0.6, -1.2), 0.6, 0.5)
	wheel(m, CFrame.new(1.4, 0.6, -1.2), 0.6, 0.5)
	m.PrimaryPart = body
	return m
end

local SHIRTS = {
	rgb(240, 90, 90),
	rgb(80, 150, 240),
	rgb(90, 190, 110),
	rgb(250, 200, 60),
	rgb(190, 110, 230),
	rgb(255, 140, 60),
	rgb(60, 190, 190),
}
local SKINS = { rgb(235, 200, 160), rgb(200, 150, 110), rgb(140, 95, 65), rgb(250, 220, 190) }

function Models.person(parent, i, shirt)
	local m = Shapes.model(parent, "Person")
	local skin = SKINS[(i or 0) % #SKINS + 1]
	local body =
		Shapes.part(m, Vector3.new(1.6, 2, 0.9), CFrame.new(0, 2.4, 0), shirt or SHIRTS[(i or 0) % #SHIRTS + 1])
	body.Name = "Body"
	body.CastShadow = false
	local head = Shapes.part(m, Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 4, 0), skin)
	head.Name = "Head"
	local hair = Shapes.part(
		m,
		Vector3.new(1.3, 0.4, 1.3),
		CFrame.new(0, 4.6, 0),
		({ rgb(60, 40, 30), rgb(230, 200, 90), rgb(30, 30, 30), rgb(160, 80, 40) })[(i or 0) % 4 + 1]
	)
	hair.Name = "Hair"
	local legs = rgb(60, 70, 110)
	Shapes.part(m, Vector3.new(0.6, 1.4, 0.6), CFrame.new(-0.45, 0.7, 0), legs).Name = "LegL"
	Shapes.part(m, Vector3.new(0.6, 1.4, 0.6), CFrame.new(0.45, 0.7, 0), legs).Name = "LegR"
	m.PrimaryPart = body
	return m
end

-- Stand a person at cframe (its feet on cframe's origin), legs swinging by phase (0: still)
function Models.place(m, cframe, phase)
	local swing = phase and math.sin(phase) * 0.35 or 0
	m.Body.CFrame = cframe * CFrame.new(0, 2.4, 0)
	m.Head.CFrame = cframe * CFrame.new(0, 4, 0)
	m.Hair.CFrame = cframe * CFrame.new(0, 4.6, 0)
	m.LegL.CFrame = cframe * CFrame.new(-0.45, 0.7, 0) * CFrame.Angles(swing, 0, 0)
	m.LegR.CFrame = cframe * CFrame.new(0.45, 0.7, 0) * CFrame.Angles(-swing, 0, 0)
	local bag = m:FindFirstChild("Bag")
	if bag then
		bag.CFrame = cframe * CFrame.new(1.2, 1.6, 0)
	end
end

function Models.bag(m)
	local b = Shapes.part(m, Vector3.new(1.1, 0.8, 0.9), m.Body.CFrame * CFrame.new(1.2, -0.8, 0), rgb(150, 100, 60))
	b.Name = "Bag"
	return b
end

-- A pallet of crates
function Models.pallet(parent, cframe, color)
	local m = Shapes.model(parent, "Pallet")
	Shapes.part(m, Vector3.new(4, 0.4, 4), cframe * CFrame.new(0, 0.2, 0), rgb(186, 130, 76))
	local c = color or rgb(200, 150, 90)
	for i = 0, 1 do
		for j = 0, 1 do
			Shapes.part(m, Vector3.new(1.8, 1.6, 1.8), cframe * CFrame.new(-1 + i * 2, 1.2, -1 + j * 2), c)
		end
	end
	Shapes.part(m, Vector3.new(1.8, 1.6, 1.8), cframe * CFrame.new(0, 2.8, 0), c:Lerp(Color3.new(1, 1, 1), 0.1))
	return m
end

return Models
