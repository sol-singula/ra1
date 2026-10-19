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

local STEEL = rgb(150, 156, 166)
local GLASS = rgb(150, 206, 236)

-- A wheel: a dark tyre (its axis along x) with a coloured hub on its outer face
local function wheel(k, x, y, z, width, dia, hub)
	k.cyl(x, y, z, width, dia, INK, nil, "Wheel")
	local side = x >= 0 and 1 or -1
	k.cyl(x + side * (width / 2 + 0.03), y, z, 0.08, dia * 0.5, hub or YELLOW, nil, "Hub")
end

-- the machines: 1 the auto-harvester (a little robot harvester), 2 the farm tractor, 3 the combine (the fleet
-- parks two of them). Built facing -z on the ground (y = 0); every part rests on or is bolted to another.
function Models.machine(parent, tier, color)
	color = color or rgb(222, 56, 48)
	local m = Shapes.model(parent, "Machine")
	m:SetAttribute("Tier", tier)
	local k = kit(m)
	if tier == 1 then
		-- wheels (r 0.8) either side of a chassis, the body on it, a crop bin on top, the cutter bar in front
		for _, x in { -1.6, 1.6 } do
			for _, z in { -1.2, 1.3 } do
				wheel(k, x, 0.8, z, 0.5, 1.6)
			end
		end
		k.box(0, 0.8, 0.05, 2.7, 0.5, 3.6, INK, "Chassis") -- 0.55 .. 1.05
		k.box(0, 1.85, 0.2, 2.6, 1.6, 3.2, color, "Body") -- 1.05 .. 2.65, z -1.4 .. 1.8
		k.box(0, 2.7, 0.2, 2.7, 0.1, 3.3, Shapes.shade(color, 0.25), "Trim")
		k.box(0, 3.15, 0.7, 2.2, 0.8, 1.8, rgb(240, 236, 226), "Bin") -- 2.75 .. 3.55
		for i, c in { rgb(228, 40, 56), rgb(250, 210, 60), rgb(232, 64, 40) } do
			k.ball(-0.6 + (i - 1) * 0.6, 3.6, 0.7, 0.6, 0.5, 0.6, c, "Crop")
		end
		k.box(0, 2.1, -1.45, 2, 0.6, 0.1, GLASS, "Eyes", Enum.Material.Neon)
		k.box(0, 1.55, -1.45, 1.4, 0.2, 0.1, INK, "Mouth")
		for _, x in { -0.8, 0.8 } do
			k.box(x, 1.15, -1.9, 0.25, 0.25, 1.0, STEEL, "Arm") -- z -2.4 .. -1.4
		end
		k.box(0, 0.75, -2.9, 3.8, 0.6, 1.0, YELLOW, "Header") -- z -3.4 .. -2.4
		for i = -3, 3 do
			k.box(i * 0.55, 0.6, -3.65, 0.25, 0.25, 0.5, STEEL, "Tooth")
		end
		k.box(0.9, 3.25, 1.4, 0.15, 1.2, 0.15, INK, "Antenna") -- 2.65 .. 3.85
		k.ball(0.9, 4, 1.4, 0.5, 0.5, 0.5, rgb(255, 80, 60), "Beacon").Material = Enum.Material.Neon
	elseif tier == 2 then
		-- the tractor: big back wheels and small front ones, the engine hood and the rear body flush on top,
		-- a cab on posts over the seat, fenders, an exhaust, a cutter header on arms in front
		for _, sx in { -1, 1 } do
			wheel(k, sx * 1.75, 1.7, 1.2, 1, 3.4)
			wheel(k, sx * 1.25, 0.9, -2.4, 0.6, 1.8)
			k.box(sx * 1.75, 3.5, 1.2, 1.1, 0.2, 2.4, color, "Fender") -- over the wheel (top 3.4)
		end
		k.cyl(0, 1.7, 1.2, 2.5, 0.5, INK, nil, "RearAxle")
		k.cyl(0, 0.9, -2.4, 1.9, 0.4, INK, nil, "FrontAxle")
		k.box(0, 1.15, -2.4, 0.6, 0.5, 0.6, INK, "Bracket") -- the axle up to the hood (bottom 1.3)
		k.box(0, 2.1, 1.2, 2.5, 1.2, 2.8, color, "Body") -- 1.5 .. 2.7, z -0.2 .. 2.6
		k.box(0, 2.0, -1.7, 1.8, 1.4, 3.4, color, "Hood") -- 1.3 .. 2.7, z -3.4 .. 0
		k.box(0, 2.74, -1.7, 0.5, 0.08, 3.4, YELLOW, "Stripe")
		k.box(0, 1.95, -3.44, 1.5, 1.0, 0.08, INK, "Grille")
		for _, x in { -0.6, 0.6 } do
			k.box(x, 2.45, -3.45, 0.35, 0.25, 0.06, rgb(255, 245, 200), "Light", Enum.Material.Neon)
		end
		k.cyl(0.55, 3.4, -2.6, 1.4, 0.3, STEEL, "y", "Exhaust") -- 2.7 .. 4.1
		-- the cab
		k.box(0, 2.85, 1.7, 1.0, 0.3, 0.9, INK, "Seat") -- on the body (2.7)
		k.box(0, 3.4, 2.1, 1.0, 0.9, 0.15, INK, "Backrest")
		k.box(0, 3.2, 0.5, 0.15, 1.0, 0.15, INK, "Column") -- 2.7 .. 3.7
		k.cyl(0, 3.75, 0.5, 0.12, 0.9, INK, "y", "SteeringWheel")
		for _, x in { -1.15, 1.15 } do
			for _, z in { -0.1, 2.5 } do
				k.box(x, 4.0, z, 0.2, 2.6, 0.2, INK, "Post") -- 2.7 .. 5.3
			end
		end
		k.box(0, 5.42, 1.2, 2.7, 0.25, 3.0, color, "Roof")
		local front = k.box(0, 4.1, -0.1, 2.1, 2.2, 0.08, GLASS, "Glass")
		front.Transparency = 0.45
		-- the header
		for _, x in { -0.7, 0.7 } do
			k.box(x, 1.4, -3.8, 0.25, 0.25, 0.8, STEEL, "Arm") -- z -4.2 .. -3.4
		end
		k.box(0, 0.8, -4.8, 5, 0.9, 1.2, rgb(206, 58, 50), "Header") -- z -5.4 .. -4.2
		for i = -4, 4 do
			k.box(i * 0.55, 0.6, -5.65, 0.25, 0.25, 0.5, YELLOW, "Tooth")
		end
	else
		-- the combine: big front drive wheels, small rear steering wheels, a tall body, the grain tank and the
		-- glass cab on top, the auger folded along the side, the feeder, the wide header with its reel
		for _, sx in { -1, 1 } do
			wheel(k, sx * 2.3, 1.8, -1.0, 1.2, 3.6)
			wheel(k, sx * 2.1, 1.1, 3.4, 0.8, 2.2)
		end
		k.box(0, 3.2, 1.4, 3.4, 3.2, 6.4, color, "Body") -- 1.6 .. 4.8, z -1.8 .. 4.6
		k.box(0, 3.2, 4.63, 2.8, 2.4, 0.08, Shapes.shade(color, -0.3), "Grille")
		k.box(0, 4.82, 1.4, 3.5, 0.08, 6.5, Shapes.shade(color, 0.25), "Trim")
		k.box(0, 5.5, 2.6, 3.0, 1.4, 2.8, Shapes.shade(color, 0.12), "Tank") -- 4.8 .. 6.2
		local cab = k.box(0, 5.8, -0.8, 2.6, 2.0, 2.0, GLASS, "Cab") -- 4.8 .. 6.8, z -1.8 .. 0.2
		cab.Transparency = 0.3
		for _, x in { -1.25, 1.25 } do
			for _, z in { -1.75, 0.15 } do
				k.box(x, 5.8, z, 0.15, 2.0, 0.15, INK, "Post")
			end
		end
		k.box(0, 6.92, -0.8, 2.9, 0.25, 2.3, color, "CabRoof")
		for _, x in { -0.8, 0.8 } do
			k.box(x, 6.9, -1.98, 0.4, 0.2, 0.1, rgb(255, 245, 200), "Light", Enum.Material.Neon)
		end
		k.cyl(-2.0, 5.0, 1.6, 5, 0.6, STEEL, "z", "Auger") -- along the left side
		k.cyl(-2.0, 4.6, -0.9, 0.8, 0.6, STEEL, "y", "Spout")
		k.cyl(1.2, 7.0, 3.6, 1.6, 0.35, INK, "y", "Exhaust") -- on the tank (6.2)
		for i = 0, 3 do
			k.box(-1.78, 1.0 + i * 0.95, -1.3, 0.12, 0.1, 0.7, INK, "Step") -- the ladder up the side
		end
		k.box(0, 1.6, -2.6, 2.0, 1.4, 1.6, Shapes.shade(color, -0.15), "Feeder") -- z -3.4 .. -1.8
		k.box(0, 0.9, -4.4, 9, 1, 2, YELLOW, "Header") -- 0.4 .. 1.4, z -5.4 .. -3.4
		k.cyl(0, 1.9, -4.6, 8.6, 1.1, rgb(206, 58, 50), nil, "Reel")
		for _, x in { -4.3, 4.3 } do
			k.box(x, 1.6, -4.6, 0.2, 0.9, 0.3, INK, "ReelArm")
		end
		for i = -7, 7 do
			k.box(i * 0.58, 0.6, -5.65, 0.25, 0.25, 0.5, STEEL, "Tooth")
		end
	end
	return m
end

function Models.truck(parent, color)
	color = color or rgb(242, 244, 246)
	local m = Shapes.model(parent, "Truck")
	local k = kit(m)
	local blue = rgb(60, 110, 200)
	for _, z in { -5, 2.2, 4.8 } do
		for _, sx in { -1, 1 } do
			wheel(k, sx * 1.9, 1.1, z, 0.8, 2.2, rgb(200, 200, 205))
		end
	end
	k.box(0, 1.3, 0, 3.0, 0.8, 14, rgb(96, 100, 110), "Chassis") -- 0.9 .. 1.7
	k.box(0, 1.95, 1.5, 3.0, 0.5, 10, rgb(80, 84, 92), "Deck") -- 1.7 .. 2.2
	k.box(0, 4.5, 1.5, 4.2, 4.6, 10, color, "Body") -- 2.2 .. 6.8, z -3.5 .. 6.5
	k.box(0, 6.85, 1.5, 4.3, 0.1, 10.1, Shapes.shade(color, -0.12), "BoxCap")
	k.box(0, 3.4, 1.5, 4.26, 0.8, 9.6, blue, "Stripe")
	k.box(0, 4.5, 6.53, 4.0, 4.4, 0.08, Shapes.shade(color, -0.08), "Doors")
	k.box(0, 3.8, -5.2, 4.0, 3.2, 3.4, blue, "Cab") -- 2.2 .. 5.4, z -6.9 .. -3.5
	k.box(0, 1.95, -5.2, 3.0, 0.5, 3.4, blue, "CabBase") -- down to the chassis
	k.box(0, 4.6, -6.93, 3.6, 1.4, 0.08, GLASS, "Windscreen")
	k.box(0, 2.5, -6.95, 4.0, 0.5, 0.12, rgb(200, 200, 205), "Bumper")
	for _, x in { -1.5, 1.5 } do
		k.box(x, 3.0, -6.95, 0.6, 0.4, 0.08, rgb(255, 245, 200), "Light", Enum.Material.Neon)
	end
	return m
end

-- The forklift: a yellow body, a counterweight, the overhead guard on four posts, the mast and the forks, a beacon
function Models.forklift(parent)
	local m = Shapes.model(parent, "Forklift")
	local k = kit(m)
	k.box(0, 1.5, 0.4, 2.6, 1.4, 3.4, YELLOW, "Body") -- 0.8 .. 2.2, z -1.3 .. 2.1
	k.box(0, 1.9, 2.1, 2.6, 1.8, 0.9, INK, "Counterweight")
	k.box(0, 2.35, 0.8, 1.2, 0.3, 1.2, INK, "Seat") -- on the body
	k.box(0, 2.95, 1.3, 1.2, 0.9, 0.2, INK, "Backrest")
	for _, sx in { -1.15, 1.15 } do
		for _, sz in { -0.7, 1.7 } do
			k.box(sx, 3.6, sz, 0.15, 2.8, 0.15, INK, "Guard") -- 2.2 .. 5.0
		end
	end
	wheel(k, -1.45, 0.6, -0.8, 0.5, 1.2)
	wheel(k, 1.45, 0.6, -0.8, 0.5, 1.2)
	wheel(k, -1.45, 0.5, 1.6, 0.5, 1.0)
	wheel(k, 1.45, 0.5, 1.6, 0.5, 1.0)
	k.box(0, 5.07, 0.5, 2.6, 0.15, 2.8, INK, "GuardTop")
	k.box(0, 5.3, 1.6, 0.4, 0.3, 0.4, rgb(244, 116, 32), "Beacon", Enum.Material.Neon)
	k.box(0, 2.0, -1.33, 2.5, 0.3, 0.06, rgb(244, 116, 32), "Stripe")
	for _, sx in { -0.8, 0.8 } do
		k.box(sx, 3, -1.4, 0.2, 5, 0.2, STEEL, "Mast") -- against the body's front
	end
	k.box(0, 1, -1.58, 2, 1.2, 0.15, INK, "Carriage")
	k.box(-0.6, 0.5, -2.65, 0.3, 0.12, 2, INK, "Fork")
	k.box(0.6, 0.5, -2.65, 0.3, 0.12, 2, INK, "Fork")
	-- a pallet of boxes on the forks
	k.box(0, 0.74, -2.65, 2.4, 0.36, 2.2, rgb(200, 160, 110), "Load")
	k.box(0, 1.77, -2.65, 2.2, 1.7, 2.0, rgb(196, 160, 110), "Load")
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
