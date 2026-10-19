--[[
The moving things, built from parts: the machines (auto-harvester, tractor, combine), the trucks, the forklift and
the little people (customers and workers). Low-poly, one colour a part, chunky enough to read from the default
camera. Every vehicle's PrimaryPart is an invisible Root at its ground origin: PivotTo a ground CFrame.

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

-- A helper: boxes and cylinders in a model's own frame (x across, y up, -z forward)
local function kit(m)
	local k = {}
	-- the root: an invisible part at the model's ground origin, its PrimaryPart, so PivotTo(a ground CFrame)
	-- stands it on the ground
	local root = Shapes.part(m, Vector3.new(1, 1, 1), CFrame.new(), Color3.new(1, 1, 1))
	root.Name = "Root"
	root.Transparency = 1
	root.CanQuery = false
	m.PrimaryPart = root
	function k.box(x, y, z, w, h, d, color, name, material)
		local p = Shapes.part(m, Vector3.new(w, h, d), CFrame.new(x, y, z), color)
		p.Name = name or "Part"
		if material then
			p.Material = material
		end
		return p
	end
	function k.cyl(x, y, z, len, dia, color, axis, name)
		local turn = axis == "y" and CFrame.Angles(0, 0, math.pi / 2)
			or (axis == "z" and CFrame.Angles(0, math.pi / 2, 0) or CFrame.new())
		local p = Shapes.cylinder(m, Vector3.new(len, dia, dia), CFrame.new(x, y, z) * turn, color)
		p.Name = name or "Part"
		return p
	end
	function k.ball(x, y, z, w, h, d, color, name)
		local p = Shapes.sphere(m, Vector3.new(w, h, d), CFrame.new(x, y, z), color)
		p.Name = name or "Part"
		return p
	end
	return k
end

local INK = rgb(40, 34, 30)
local YELLOW = rgb(255, 200, 36)

-- the machines: 1 the auto-harvester (a little robot harvester), 2 the farm tractor, 3 the combine (the fleet
-- parks two of them). Built facing -z; the body is the PrimaryPart.
function Models.machine(parent, tier, color)
	color = color or rgb(222, 56, 48)
	local m = Shapes.model(parent, "Machine")
	m:SetAttribute("Tier", tier)
	local k = kit(m)
	local body
	if tier == 1 then
		body = k.box(0, 1.9, 0, 3.4, 1.8, 4.2, color, "Body")
		k.box(0, 2.85, 0, 3.5, 0.2, 4.3, Shapes.shade(color, 0.2), "Cap")
		k.box(0, 3.3, 0.6, 2.4, 0.9, 1.8, rgb(240, 240, 240), "Top")
		k.box(0, 3.4, -0.4, 2, 0.5, 0.2, rgb(150, 206, 236), "Eyes", Enum.Material.Neon)
		k.box(0, 1.1, -2.7, 4.4, 0.7, 1.2, YELLOW, "Header")
		for i = -2, 2 do
			k.box(i * 0.85, 0.75, -3.35, 0.35, 0.35, 0.6, rgb(150, 156, 166), "Tooth")
		end
		k.box(1.2, 4.2, 1.2, 0.3, 1.4, 0.3, INK, "Antenna")
		k.ball(1.2, 5, 1.2, 0.6, 0.6, 0.6, rgb(255, 80, 60), "Beacon")
		for _, x in { -1.75, 1.75 } do
			for _, z in { -1.3, 1.3 } do
				k.cyl(x, 0.85, z, 0.6, 1.7, INK, nil, "Wheel")
				k.cyl(x * 1.04, 0.85, z, 0.62, 0.8, YELLOW, nil, "Rim")
			end
		end
	elseif tier == 2 then
		-- The tractor: a body, a hood with a stripe, a seat and wheel, big back wheels, a header in front
		local green = color
		body = k.box(0, 2.6, 0.6, 3, 1.8, 5, green, "Body")
		k.box(0, 3.2, -2, 2.6, 1.4, 1.6, green, "Hood")
		k.box(0, 3.95, -2, 2.7, 0.15, 1.7, YELLOW, "Stripe")
		k.box(0, 4.4, 1.6, 2.6, 0.2, 2.4, INK, "Seat")
		k.box(0, 5, 1.2, 0.2, 1.2, 0.2, INK, "Column")
		k.cyl(0, 5.6, 1, 0.2, 1.2, INK, "y", "SteeringWheel")
		k.box(0.9, 5, -2.5, 0.35, 2.6, 0.35, rgb(150, 156, 166), "Exhaust")
		k.box(0, 5.6, 0.9, 2.8, 2, 2.6, rgb(150, 206, 236), "Cab")
		k.box(0, 6.7, 0.9, 3, 0.25, 2.8, green, "Roof")
		for _, sx in { -1, 1 } do
			k.cyl(sx * 1.9, 1.8, 1.4, 1, 3.6, INK, nil, "BigWheel")
			k.cyl(sx * 2.42, 1.8, 1.4, 0.1, 1.8, YELLOW, nil, "Rim")
			k.cyl(sx * 1.6, 1, -2.6, 0.7, 2, INK, nil, "SmallWheel")
			k.cyl(sx * 1.97, 1, -2.6, 0.1, 1, YELLOW, nil, "Rim")
		end
		local hw = 6.2
		k.box(0, 1.2, -4, hw, 1, 1.4, rgb(206, 58, 50), "Header")
		for i = 0, math.floor(hw / 1.2) do
			k.box(-hw / 2 + 0.6 + i * 1.2, 0.7, -4.4, 0.5, 0.5, 0.8, YELLOW, "Tooth")
		end
	else
		-- the combine: a wide reel header, a tall body, a glass cab, the unloading auger
		body = k.box(0, 3.2, 0.5, 4.6, 3.6, 7, color, "Body")
		k.box(0, 5.1, 0.5, 4.7, 0.25, 7.1, Shapes.shade(color, 0.2), "Cap")
		k.box(0, 6.2, -1.6, 3.4, 2.4, 2.6, rgb(150, 206, 236), "Cab")
		k.box(0, 7.5, -1.6, 3.6, 0.3, 2.8, color, "CabRoof")
		k.box(0, 1.4, -4.4, 9.4, 1.2, 2, YELLOW, "Header")
		k.cyl(0, 2.3, -4.8, 9, 1.2, rgb(206, 58, 50), nil, "Reel")
		for i = -4, 4 do
			k.box(i * 1.05, 0.9, -5.5, 0.4, 0.4, 0.9, rgb(150, 156, 166), "Tooth")
		end
		k.cyl(3.6, 5.6, 1.8, 6, 0.8, rgb(150, 156, 166), nil, "Auger")
		k.box(0, 4.2, 4.2, 3.6, 2.6, 0.6, Shapes.shade(color, -0.2), "Grille")
		for _, sx in { -1, 1 } do
			k.cyl(sx * 2.5, 1.9, -1.4, 1.2, 3.8, INK, nil, "BigWheel")
			k.cyl(sx * 3.12, 1.9, -1.4, 0.1, 1.8, YELLOW, nil, "Rim")
			k.cyl(sx * 2.1, 1.1, 2.8, 0.9, 2.2, INK, nil, "SmallWheel")
		end
	end
	_ = body
	return m
end

function Models.truck(parent, color)
	color = color or rgb(242, 244, 246)
	local m = Shapes.model(parent, "Truck")
	local k = kit(m)
	local body = k.box(0, 3.8, 1.5, 4.2, 4.6, 10, color, "Body")
	k.box(0, 6.15, 1.5, 4.3, 0.2, 10.1, Shapes.shade(color, -0.12), "BoxCap")
	k.box(0, 3.2, 1.5, 4.25, 0.8, 9.6, rgb(60, 110, 200), "Stripe")
	k.box(0, 2.8, -5.2, 4, 3.2, 3.4, rgb(60, 110, 200), "Cab")
	k.box(0, 3.4, -6.95, 3.6, 1.4, 0.15, rgb(150, 206, 236), "Windscreen")
	k.box(0, 1.6, -6.95, 3.4, 0.6, 0.2, rgb(200, 200, 205), "Bumper")
	for _, x in { -1.5, 1.5 } do
		k.box(x, 2.2, -6.98, 0.6, 0.4, 0.1, rgb(255, 245, 200), "Light", Enum.Material.Neon)
	end
	k.box(0, 1.3, 0, 4.2, 0.8, 14, rgb(96, 100, 110), "Chassis")
	for _, z in { -5, 2, 5 } do
		for _, sx in { -1, 1 } do
			k.cyl(sx * 2.1, 1.1, z, 0.8, 2.2, INK, nil, "Wheel")
			k.cyl(sx * 2.22, 1.1, z, 0.82, 1, rgb(200, 200, 205), nil, "Hub")
		end
	end
	_ = body
	return m
end

-- The forklift: a yellow body, a counterweight, the overhead guard, the mast and the forks, a beacon
function Models.forklift(parent)
	local m = Shapes.model(parent, "Forklift")
	local k = kit(m)
	local body = k.box(0, 1.5, 0.4, 2.6, 1.4, 3.4, YELLOW, "Body")
	k.box(0, 1.9, 2.1, 2.6, 1.8, 0.9, INK, "Counterweight")
	k.box(0, 2.5, 0.8, 1.2, 0.3, 1.2, INK, "Seat")
	for _, sx in { -1.15, 1.15 } do
		for _, sz in { -0.7, 1.7 } do
			k.box(sx, 3.6, sz, 0.15, 2.6, 0.15, INK, "Guard")
		end
		k.cyl(sx, 0.6, -0.9, 0.5, 1.2, INK, nil, "Wheel")
		k.cyl(sx, 0.5, 1.8, 0.5, 1, INK, nil, "Wheel")
	end
	k.box(0, 4.95, 0.5, 2.6, 0.15, 2.8, INK, "GuardTop")
	k.box(0, 5.2, 1.6, 0.4, 0.3, 0.4, rgb(244, 116, 32), "Beacon", Enum.Material.Neon)
	k.box(0, 2.3, -1.3, 2.5, 0.3, 0.2, rgb(244, 116, 32), "Stripe")
	for _, sx in { -0.8, 0.8 } do
		k.box(sx, 3, -1.55, 0.2, 5, 0.2, rgb(150, 156, 166), "Mast")
	end
	k.box(0, 1, -1.75, 2, 1.2, 0.15, INK, "Carriage")
	k.box(-0.6, 0.5, -2.75, 0.3, 0.12, 2, INK, "Fork")
	k.box(0.6, 0.5, -2.75, 0.3, 0.12, 2, INK, "Fork")
	-- a pallet of boxes on the forks
	k.box(0, 0.75, -2.75, 2.6, 0.35, 2.6, rgb(200, 160, 110), "Load")
	k.box(0, 1.8, -2.75, 2.4, 1.7, 2.4, rgb(196, 160, 110), "Load")
	_ = body
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
