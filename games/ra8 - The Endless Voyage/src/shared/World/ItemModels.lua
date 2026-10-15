--[[
What items look like: in the hand, floating in the water when dropped, and as the little 3D pictures in the bag,
the hotbar and the crafting lists (client/UI/Icons). Every one of the 54 items is built from plain parts, so
nothing needs uploading, and what you hold is what the icon shows.

  ItemModels.held(item, parent) -> model, grip     grip: an invisible part where the hand closes round it
  ItemModels.holdCFrame(item, hand) -> CFrame       the weld's C0 from the hand to the grip
  ItemModels.icon(item, parent) -> model            the same model, loose (for a ViewportFrame)
How things sit in the hand (Roblox's hand frame: -Y comes out of the bottom of the fist, -Z is the back of the
fingers; in the hold pose, with the forearm level in front of you, -Y points ahead and -Z points up): rods are held
by the handle, pointing ahead; axes, picks and hammers stand up out of the fist, the head forward; spears
point ahead; lanterns hang. Every builder draws its item along -Z from the origin (the grip), "up" along +Y.
]]
local Items = require(script.Parent.Parent.Data.Items)
local Kit = require(script.Parent.Kit)

local ItemModels = {}

local C, M = Kit.C, Kit.M
local V3 = Vector3.new
local A = CFrame.Angles
local R = math.rad

local EXTRA = {
	CanCollide = false,
	CanQuery = false,
	CanTouch = false,
	Massless = true,
	CastShadow = false,
	Anchored = false,
}

local function p(m, name, cf, size, color, material, shape)
	local part = Kit.box(m, name, cf, size, color, material or M.SmoothPlastic, EXTRA)
	if shape == "Ball" then
		part.Shape = Enum.PartType.Ball
	elseif shape == "Cylinder" then
		part.Shape = Enum.PartType.Cylinder
	end
	return part
end

local function w(m, name, cf, size, color, material)
	return Kit.wedge(m, name, cf, size, color, material or M.SmoothPlastic, EXTRA)
end

-- a cylinder along the local Z of `cf` (Roblox cylinders lie along X)
local function cylZ(m, name, cf, len, dia, color, material)
	return p(m, name, cf * A(0, R(90), 0), V3(len, dia, dia), color, material, "Cylinder")
end

-- a cylinder standing up along Y
local function cylY(m, name, cf, h, dia, color, material)
	return p(m, name, cf * A(0, 0, R(90)), V3(h, dia, dia), color, material, "Cylinder")
end

local function ball(m, name, cf, dia, color, material)
	return p(m, name, cf, V3(dia, dia, dia), color, material, "Ball")
end

local RARITY_METAL = {
	common = C.iron,
	uncommon = C.steel,
	rare = C.steel:Lerp(C.blueprint, 0.3),
	epic = Color3.fromRGB(150, 110, 230),
	legendary = C.gold,
}
local function metalOf(item)
	return RARITY_METAL[item.rarity] or C.iron
end

local PINK = Color3.fromRGB(255, 130, 150)
local BRASS = Color3.fromRGB(196, 150, 70)
local IVORY = Color3.fromRGB(246, 238, 214)
local GLASS = Color3.fromRGB(170, 220, 230)
local TEAL = Color3.fromRGB(32, 110, 120)
local ICE = Color3.fromRGB(190, 230, 255)

local draw = {}

-- Tools ---------------------------------------------------------------------------------------------------------------
-- a wooden handle along -Z from the grip, with a dark wrap near the hand
local function handle(m, len, dia, color)
	cylZ(m, "Handle", CFrame.new(0, 0, -len / 2), len, dia, color or C.woodDark, M.Wood)
	cylZ(m, "Wrap", CFrame.new(0, 0, -0.45), 0.8, dia * 1.25, C.barkDark, M.Fabric)
	cylZ(m, "Wrap2", CFrame.new(0, 0, -len + 0.5), 0.5, dia * 1.2, C.barkDark, M.Fabric)
end

-- The rods: the basic wooden one, the iron one, the long one, the salvage rod with a claw on its line, the deep rod.
function draw.rod(m, item)
	local key = item.key
	local long = key == "long_rod" or key == "salvage_rod"
	local col = (key == "deep_rod" or key == "iron_rod") and C.steel
		or key == "long_rod" and C.steel:Lerp(C.blueprint, 0.3)
		or key == "salvage_rod" and Color3.fromRGB(150, 110, 230)
		or C.plank
	local reel = key == "fishing_rod" and C.iron or key == "salvage_rod" and C.gold or C.steel
	handle(m, 1.6, 0.26, C.woodDark)
	-- the rod tapers in three pieces, with line guides
	local k = long and 1.25 or 1
	cylZ(m, "Rod", CFrame.new(0, 0, -2.6 * k), 2.2 * k, 0.2, col, key == "fishing_rod" and M.Wood or M.Metal)
	cylZ(m, "Rod2", CFrame.new(0, 0, -4.4 * k), 1.6 * k, 0.15, col, key == "fishing_rod" and M.Wood or M.Metal)
	cylZ(m, "Tip", CFrame.new(0, 0, -5.6 * k), 1 * k, 0.1, col, key == "fishing_rod" and M.Wood or M.Metal)
	for _, z in { -2.2, -3.6, -4.9 } do
		cylZ(m, "Guide", CFrame.new(0, -0.12, z * k), 0.1, 0.24, C.iron, M.Metal)
	end
	-- the reel and its crank
	cylY(m, "Reel", CFrame.new(0, -0.42, -1.1) * A(R(90), 0, 0), 0.26, 0.6, reel, M.Metal)
	cylY(m, "Spool", CFrame.new(0, -0.42, -1.1) * A(R(90), 0, 0), 0.3, 0.42, C.cream, M.Fabric)
	p(m, "Crank", CFrame.new(0.25, -0.5, -1.1), V3(0.3, 0.08, 0.08), C.iron, M.Metal)
	ball(m, "Knob", CFrame.new(0.4, -0.5, -1.1), 0.14, C.woodDark, M.Wood)
	-- the line, and a bobber (a claw on the salvage rod)
	local tipZ = -6 * k
	local hang = Vector3.new(0, -math.cos(R(65)), math.sin(R(65))) -- "down" when the rod is held at 65°
	local tip = Vector3.new(0, 0, tipZ)
	local function along(d)
		return CFrame.new(tip + hang * d) * A(R(-65), 0, 0)
	end
	cylY(m, "Line", along(0.6), 1.2, 0.04, C.cream, M.Fabric)
	if key == "salvage_rod" then
		for i = 0, 2 do
			local a = i / 3 * math.pi * 2
			w(
				m,
				"Claw",
				along(1.3) * A(0, a, 0) * CFrame.new(0.22, 0, 0) * A(0, 0, R(-30)),
				V3(0.12, 0.5, 0.16),
				C.gold,
				M.Metal
			)
		end
		ball(m, "ClawHub", along(1.15), 0.3, C.gold, M.Metal)
	else
		ball(m, "Bobber", along(1.25), 0.32, C.red, M.SmoothPlastic)
		ball(m, "BobberTop", along(1.1), 0.26, C.white, M.SmoothPlastic)
	end
	return V3(0, 0, -0.5)
end

-- The heads sit across the top of the handle (the handle runs along -Z, the strike goes +Y), the way a real one is.
-- (A wedge part is thick at +Z and comes to an edge at -Z, along its bottom; the flips below turn that edge where
-- it's needed.)
local function tip(m, name, cf, len, wide, thick, color, material)
	-- a pointed tip along -Z from `cf`: four wedges round the axis, meeting at a point
	for i = 0, 3 do
		w(
			m,
			name,
			cf * A(0, 0, R(90 * i)) * CFrame.new(0, wide / 4, -len / 2),
			V3(thick, wide / 2, len),
			color,
			material
		)
	end
end

function draw.axe(m, item)
	local col = metalOf(item)
	local bright = C.white:Lerp(col, 0.35)
	handle(m, 3, 0.3)
	local top = CFrame.new(0, 0, -2.75)
	-- the eye round the handle's end, a short poll behind it
	p(m, "Eye", top, V3(0.4, 0.55, 0.55), col:Lerp(C.ink, 0.15), M.Metal)
	p(m, "Poll", top * CFrame.new(0, -0.38, 0), V3(0.4, 0.25, 0.45), col:Lerp(C.ink, 0.3), M.Metal)
	-- the cheek narrows out of the eye, then the blade flares wide to its edge
	p(m, "Cheek", top * CFrame.new(0, 0.45, 0), V3(0.26, 0.4, 0.5), col, M.Metal)
	p(m, "Blade", top * CFrame.new(0, 0.95, 0), V3(0.18, 0.6, 0.95), col, M.Metal)
	w(m, "Flare", top * CFrame.new(0, 0.5, 0.36) * A(R(180), 0, 0), V3(0.18, 0.3, 0.23), col, M.Metal)
	w(m, "Flare2", top * CFrame.new(0, 0.5, -0.36) * A(0, 0, R(180)), V3(0.18, 0.3, 0.23), col, M.Metal)
	p(m, "Edge", top * CFrame.new(0, 1.28, 0), V3(0.12, 0.08, 0.98), bright, M.Metal)
	return V3(0, 0, -0.35)
end

function draw.pick(m, item)
	local col = metalOf(item)
	handle(m, 3, 0.3)
	local top = CFrame.new(0, 0, -2.75)
	-- a socket on the handle and a long head across it, curving a little back towards the hand, pointed both ends
	p(m, "Socket", top, V3(0.42, 0.5, 0.5), col:Lerp(C.ink, 0.2), M.Metal)
	for _, side in { 1, -1 } do
		local arm = top * A(R(side * -12), 0, 0) * CFrame.new(0, side * 0.75, 0)
		p(m, "Arm", arm, V3(0.26, 1.05, 0.3), col, M.Metal)
		local point = arm * CFrame.new(0, side * 0.52, 0) * A(R(side * 90), 0, 0)
		tip(m, "Point", point, 0.55, 0.3, 0.26, col:Lerp(C.white, 0.2), M.Metal)
	end
	return V3(0, 0, -0.35)
end

function draw.hammer(m)
	handle(m, 2.6, 0.3)
	local top = CFrame.new(0, 0, -2.35)
	-- a heavy head across the handle: the round striking face forward, the split claw behind for pulling nails
	p(m, "Head", top * CFrame.new(0, 0.2, 0), V3(0.5, 0.95, 0.5), C.iron, M.Metal)
	cylY(m, "Neck", top * CFrame.new(0, 0.75, 0), 0.25, 0.48, C.iron, M.Metal)
	cylY(m, "Face", top * CFrame.new(0, 0.93, 0), 0.14, 0.62, C.steel, M.Metal)
	for _, x in { 0.12, -0.12 } do
		p(m, "Claw", top * CFrame.new(x, -0.45, 0.06) * A(R(18), 0, 0), V3(0.16, 0.5, 0.34), C.iron, M.Metal)
		w(m, "ClawTip", top * CFrame.new(x, -0.82, 0.2) * A(R(18 + 90), 0, 0), V3(0.16, 0.3, 0.3), C.iron, M.Metal)
	end
	cylZ(m, "Collar", top * CFrame.new(0, 0, 0.36), 0.2, 0.36, C.steel, M.Metal)
	return V3(0, 0, -0.35)
end

function draw.pry(m)
	cylZ(m, "Bar", CFrame.new(0, 0, -1.6), 3.2, 0.26, C.iron, M.Metal)
	cylZ(m, "Bend", CFrame.new(0, 0.25, -3.3) * A(R(-40), 0, 0), 0.9, 0.26, C.iron, M.Metal)
	w(m, "Fork", CFrame.new(0.12, 0.55, -3.6) * A(R(-40), 0, 0), V3(0.12, 0.35, 0.5), C.iron, M.Metal)
	w(m, "Fork2", CFrame.new(-0.12, 0.55, -3.6) * A(R(-40), 0, 0), V3(0.12, 0.35, 0.5), C.iron, M.Metal)
	p(m, "Heel", CFrame.new(0, 0.12, 0.05) * A(R(20), 0, 0), V3(0.26, 0.4, 0.26), C.iron, M.Metal)
	return V3(0, 0, -0.5)
end

function draw.lantern(m)
	-- a hanging lantern: a hoop handle, a glass body that glows, a cap and a flame
	p(m, "Hoop", CFrame.new(0, 1.55, 0), V3(0.08, 0.5, 0.5), C.iron, M.Metal)
	cylY(m, "Cap", CFrame.new(0, 1.15, 0), 0.18, 0.95, C.iron, M.Metal)
	cylY(m, "Base", CFrame.new(0, -0.05, 0), 0.16, 0.9, C.iron, M.Metal)
	local glass = p(m, "Glass", CFrame.new(0, 0.55, 0), V3(0.7, 1.05, 0.7), C.warm, M.Neon)
	for _, a in { 0, 90 } do
		p(
			m,
			"Rib",
			CFrame.new(0, 0.55, 0) * A(0, R(a + 45), 0) * CFrame.new(0.4, 0, 0),
			V3(0.08, 1.05, 0.08),
			C.iron,
			M.Metal
		)
	end
	ball(m, "Flame", CFrame.new(0, 0.55, 0), 0.3, C.fire, M.Neon)
	return V3(0, 1.5, 0), glass
end

-- Weapons -------------------------------------------------------------------------------------------------------------
function draw.spear(m, item)
	local col = metalOf(item)
	local wood = item.key == "sharp_stick" and C.bark or C.woodDark
	cylZ(m, "Shaft", CFrame.new(0, 0, -2.4), 6, 0.22, wood, M.Wood)
	for i = 1, 3 do
		cylZ(m, "Lash", CFrame.new(0, 0, -4.9 - i * 0.12), 0.08, 0.3, C.rope, M.Fabric)
	end
	if item.key == "sharp_stick" then
		tip(m, "Tip", CFrame.new(0, 0, -5.4), 0.8, 0.24, 0.24, C.woodLight, M.Wood)
	else
		-- a leaf-shaped blade: wide and flat, coming to a point
		cylZ(m, "Socket", CFrame.new(0, 0, -5.45), 0.35, 0.3, col:Lerp(C.ink, 0.2), M.Metal)
		tip(m, "Tip", CFrame.new(0, 0, -5.6), 1.1, 0.5, 0.12, col, M.Metal)
		tip(m, "TipRidge", CFrame.new(0, 0, -5.6), 1.05, 0.16, 0.16, col:Lerp(C.white, 0.25), M.Metal)
	end
	return V3(0, 0, -1.6)
end

function draw.harpoon(m, item)
	local col = metalOf(item)
	cylZ(m, "Shaft", CFrame.new(0, 0, -2.2), 5.4, 0.26, C.iron, M.Metal)
	tip(m, "Tip", CFrame.new(0, 0, -4.9), 1, 0.4, 0.14, col, M.Metal)
	for _, side in { 1, -1 } do
		-- barbs swept back from behind the point
		w(m, "Barb", CFrame.new(side * 0.2, 0, -4.75) * A(0, 0, R(side * 90)), V3(0.08, 0.22, 0.5), col, M.Metal)
	end
	cylZ(m, "Grip", CFrame.new(0, 0, -0.8), 1.2, 0.34, C.barkDark, M.Fabric)
	cylZ(m, "RopeEye", CFrame.new(0, 0.2, 0.3), 0.2, 0.3, C.iron, M.Metal)
	p(m, "Rope", CFrame.new(0, -0.1, 0.55) * A(R(30), 0, 0), V3(0.12, 0.12, 1), C.rope, M.Fabric)
	return V3(0, 0, -1.4)
end

-- Resources -------------------------------------------------------------------------------------------------------------
local byKey = {}

function byKey.wood(m)
	p(m, "Plank", CFrame.new(0, 0, 0) * A(0, R(10), 0), V3(0.5, 0.3, 2.2), C.plank, M.WoodPlanks)
	p(m, "Plank2", CFrame.new(0, 0.3, 0) * A(0, R(-8), 0), V3(0.5, 0.3, 2), C.woodLight, M.WoodPlanks)
	cylZ(m, "Log", CFrame.new(0.55, 0.1, 0) * A(0, R(4), 0), 1.9, 0.5, C.bark, M.Wood)
end

function byKey.scrap(m)
	p(
		m,
		"Plastic",
		CFrame.new(0, 0, 0) * A(0, R(20), R(10)),
		V3(1.2, 0.3, 0.9),
		Color3.fromRGB(60, 140, 200),
		M.Plastic
	)
	p(m, "Bits", CFrame.new(0.5, 0.3, 0.3) * A(R(20), 0, R(-15)), V3(0.6, 0.2, 0.7), C.iron, M.CorrodedMetal)
	ball(m, "Bolt", CFrame.new(-0.4, 0.3, -0.3), 0.3, C.steel, M.Metal)
	p(
		m,
		"Bottle",
		CFrame.new(-0.3, 0.25, 0.4) * A(0, 0, R(90)),
		V3(0.3, 0.3, 0.8),
		Color3.fromRGB(120, 200, 170),
		M.Glass
	)
end

function byKey.rope(m)
	-- a coil: short segments round a ring
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		p(
			m,
			"Coil",
			CFrame.new(math.cos(a) * 0.55, 0, math.sin(a) * 0.55) * A(0, -a, 0),
			V3(0.5, 0.3, 0.46),
			C.rope,
			M.Fabric
		)
	end
	p(m, "Tie", CFrame.new(0.55, 0.1, 0), V3(0.3, 0.42, 0.56), C.barkDark, M.Fabric)
end

function byKey.cloth(m)
	p(m, "Bolt", CFrame.new(0, 0, 0) * A(0, R(8), 0), V3(1.4, 0.35, 1.1), C.canvas, M.Fabric)
	p(m, "Fold", CFrame.new(0.2, 0.3, -0.1) * A(0, R(-12), 0), V3(1, 0.25, 0.8), C.canvas:Lerp(C.cloth, 0.25), M.Fabric)
	p(m, "Seam", CFrame.new(0, 0.46, 0.2) * A(0, R(-12), 0), V3(0.9, 0.04, 0.05), C.cloth, M.Fabric)
end

function byKey.metal(m)
	p(m, "Ingot", CFrame.new(0, 0, 0), V3(1.4, 0.45, 0.7), C.steel, M.Metal)
	w(m, "Side", CFrame.new(0.85, 0, 0) * A(0, R(-90), 0), V3(0.7, 0.45, 0.3), C.steel, M.Metal)
	w(m, "Side2", CFrame.new(-0.85, 0, 0) * A(0, R(90), 0), V3(0.7, 0.45, 0.3), C.steel, M.Metal)
	p(m, "Mark", CFrame.new(0, 0.24, 0), V3(0.5, 0.02, 0.3), C.iron, M.Metal)
end

function byKey.palm(m)
	cylZ(m, "Rib", CFrame.new(0, 0, -0.2), 2.6, 0.12, C.bark, M.Wood)
	for i = 0, 5 do
		local side = i % 2 == 0 and 1 or -1
		local z = -1.3 + i * 0.4
		p(
			m,
			"Leaf",
			CFrame.new(side * 0.45, 0, z) * A(0, R(side * 35), R(side * 10)),
			V3(1, 0.05, 0.3),
			C.leaf,
			M.Grass
		)
	end
end

function byKey.fiber(m)
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		cylZ(
			m,
			"Strand",
			CFrame.new(math.cos(a) * 0.14, math.sin(a) * 0.14, 0),
			1.8,
			0.14,
			C.canvas:Lerp(C.leafLight, 0.3),
			M.Fabric
		)
	end
	cylZ(m, "Band", CFrame.new(0, 0, 0), 0.3, 0.5, C.rope, M.Fabric)
end

function byKey.stone(m)
	p(m, "Rock", CFrame.new(0, 0, 0) * A(R(15), R(20), R(10)), V3(1.1, 0.8, 1), C.rock, M.Rock)
	p(m, "Rock2", CFrame.new(0.3, 0.2, -0.2) * A(R(-20), R(50), R(5)), V3(0.8, 0.7, 0.7), C.rockDark, M.Rock)
end

function byKey.ore(m)
	p(m, "Rock", CFrame.new(0, 0, 0) * A(R(15), R(20), R(10)), V3(1.1, 0.8, 1), C.rockDark, M.Rock)
	for i = 1, 4 do
		local a = i / 4 * math.pi * 2
		ball(
			m,
			"Vein",
			CFrame.new(math.cos(a) * 0.45, 0.2 + (i % 2) * 0.2, math.sin(a) * 0.4),
			0.3,
			Color3.fromRGB(230, 150, 60),
			M.Metal
		)
	end
end

function byKey.coral(m)
	cylY(m, "Base", CFrame.new(0, -0.3, 0), 0.2, 1, C.sand, M.Sand)
	cylY(m, "Stem", CFrame.new(0, 0.2, 0), 1, 0.3, PINK, M.Pebble)
	cylY(m, "Branch", CFrame.new(0.3, 0.6, 0) * A(0, 0, R(-35)), 0.9, 0.22, PINK, M.Pebble)
	cylY(m, "Branch2", CFrame.new(-0.25, 0.7, 0.1) * A(R(20), 0, R(35)), 0.8, 0.2, PINK, M.Pebble)
	ball(m, "Tip", CFrame.new(0.5, 1, 0), 0.3, PINK:Lerp(C.white, 0.3), M.Pebble)
end

function byKey.plank(m)
	p(m, "Plank", CFrame.new(0, 0, 0), V3(0.6, 0.18, 2.4), C.woodLight, M.WoodPlanks)
	p(m, "Plank2", CFrame.new(0, 0.2, 0) * A(0, R(6), 0), V3(0.6, 0.18, 2.3), C.plank, M.WoodPlanks)
end

function byKey.gear(m)
	cylZ(m, "Disc", CFrame.new(0, 0, 0), 0.3, 1.3, C.steel, M.Metal)
	cylZ(m, "Hub", CFrame.new(0, 0, 0), 0.34, 0.4, C.iron, M.Metal)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		p(
			m,
			"Tooth",
			CFrame.new(math.cos(a) * 0.72, math.sin(a) * 0.72, 0) * A(0, 0, a),
			V3(0.3, 0.24, 0.3),
			C.steel,
			M.Metal
		)
	end
end

function byKey.glass(m)
	local pane = p(m, "Pane", CFrame.new(0, 0, 0) * A(0, R(15), 0), V3(1.4, 1.1, 0.12), GLASS, M.Glass)
	pane.Transparency = 0.35
	p(m, "Shine", CFrame.new(-0.35, 0.3, 0.07) * A(0, R(15), R(40)), V3(0.5, 0.06, 0.02), C.white, M.Neon)
end

function byKey.pearl(m)
	w(m, "Shell", CFrame.new(0, -0.25, 0) * A(0, 0, 0), V3(1.3, 0.3, 1), C.cream, M.Sand)
	cylY(m, "ShellBase", CFrame.new(0, -0.42, 0), 0.1, 1.2, C.sand, M.Sand)
	local pearl = ball(m, "Pearl", CFrame.new(0, 0.2, 0), 0.7, Color3.fromRGB(250, 240, 236), M.SmoothPlastic)
	pearl.Reflectance = 0.4
	ball(m, "Gleam", CFrame.new(-0.15, 0.4, 0.2), 0.16, C.white, M.Neon)
end

local function crystal(m, color, material)
	local rng = Random.new(7)
	Kit.crystals(m, V3(0, -0.4, 0), 1.3, color, rng, 4)
	for _, d in m:GetChildren() do
		if d:IsA("BasePart") then
			d.Material = material or d.Material
			for k, v in EXTRA do
				d[k] = v
			end
		end
	end
end

function byKey.heat_crystal(m)
	crystal(m, C.ember, M.Neon)
	cylY(m, "Base", CFrame.new(0, -0.5, 0), 0.2, 1, C.rockDark, M.Rock)
end

function byKey.frost_crystal(m)
	crystal(m, ICE, M.Ice)
	cylY(m, "Base", CFrame.new(0, -0.5, 0), 0.2, 1, C.moon:Lerp(C.white, 0.5), M.Ice)
end

function byKey.old_tech(m)
	p(m, "Box", CFrame.new(0, 0, 0), V3(1.3, 0.9, 0.9), C.iron, M.DiamondPlate)
	p(m, "Screen", CFrame.new(0, 0.1, -0.46), V3(0.8, 0.45, 0.04), C.glowcap, M.Neon)
	for i = 0, 2 do
		ball(m, "Knob", CFrame.new(-0.4 + i * 0.4, -0.3, -0.47), 0.14, i == 1 and C.red or C.good, M.Neon)
	end
	cylY(m, "Antenna", CFrame.new(0.45, 0.85, 0.2), 0.8, 0.06, C.steel, M.Metal)
	ball(m, "Tip", CFrame.new(0.45, 1.25, 0.2), 0.14, C.red, M.Neon)
end

function byKey.leviathan_scale(m)
	w(m, "Scale", CFrame.new(0, 0.3, 0) * A(R(-90), 0, 0), V3(1.4, 1.2, 0.18), TEAL, M.Slate)
	p(m, "Scale2", CFrame.new(0, -0.5, 0), V3(1.4, 0.9, 0.18), TEAL, M.Slate)
	p(m, "Edge", CFrame.new(0, -0.5, -0.1), V3(1.2, 0.7, 0.04), TEAL:Lerp(C.glowcap, 0.4), M.Neon)
end

function byKey.supply_crate(m)
	p(m, "Crate", CFrame.new(0, 0, 0), V3(1.3, 1.1, 1.3), C.wood, M.WoodPlanks)
	for _, sx in { -1, 1 } do
		p(m, "Band", CFrame.new(sx * 0.42, 0, 0), V3(0.16, 1.14, 1.34), C.iron, M.Metal)
	end
	p(m, "Lid", CFrame.new(0, 0.6, 0), V3(1.4, 0.1, 1.4), C.woodDark, M.Wood)
	ball(m, "Beacon", CFrame.new(0, 0.85, 0), 0.34, C.canvasRed, M.Neon)
end

-- Food ------------------------------------------------------------------------------------------------------------------
function byKey.coconut(m)
	ball(m, "Nut", CFrame.new(0, 0, 0), 1.1, C.bark:Lerp(C.woodDark, 0.4), M.Fabric)
	for i = 0, 2 do
		local a = i / 3 * math.pi * 2
		ball(m, "Eye", CFrame.new(math.cos(a) * 0.2, 0.52, math.sin(a) * 0.2), 0.14, C.barkDark, M.SmoothPlastic)
	end
	cylY(m, "Split", CFrame.new(0.45, -0.1, 0) * A(0, 0, R(-70)), 0.12, 0.5, C.white, M.SmoothPlastic)
end

function byKey.berries(m)
	p(m, "Leaf", CFrame.new(0, -0.35, 0) * A(0, R(20), 0), V3(1.4, 0.06, 0.8), C.leaf, M.Grass)
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		ball(
			m,
			"Berry",
			CFrame.new(math.cos(a) * 0.3, 0.05 + (i % 2) * 0.2, math.sin(a) * 0.3),
			0.42,
			C.flowerBlue,
			M.SmoothPlastic
		)
	end
	ball(m, "Berry", CFrame.new(0, 0.35, 0), 0.42, C.flowerBlue:Lerp(C.purple, 0.3), M.SmoothPlastic)
end

local function fish(m, color, cooked)
	p(m, "Body", CFrame.new(0, 0, 0), V3(0.6, 0.7, 1.4), color, M.SmoothPlastic)
	w(m, "Head", CFrame.new(0, 0, -1) * A(R(-90), 0, 0), V3(0.6, 0.6, 0.7), color, M.SmoothPlastic)
	w(m, "Tail", CFrame.new(0, 0.2, 1) * A(R(90), 0, 0), V3(0.2, 0.6, 0.6), color, M.SmoothPlastic)
	w(m, "Tail2", CFrame.new(0, -0.2, 1) * A(R(90), 0, R(180)), V3(0.2, 0.6, 0.6), color, M.SmoothPlastic)
	w(m, "Fin", CFrame.new(0, 0.5, 0.1) * A(0, 0, 0), V3(0.12, 0.35, 0.6), color:Lerp(C.ink, 0.2), M.SmoothPlastic)
	ball(m, "Eye", CFrame.new(0.26, 0.15, -0.9), 0.18, C.white, M.SmoothPlastic)
	ball(m, "Pupil", CFrame.new(0.33, 0.15, -0.92), 0.1, C.ink, M.SmoothPlastic)
	if cooked then
		for i = 0, 2 do
			p(
				m,
				"Grill",
				CFrame.new(0.31, 0.1, -0.4 + i * 0.4) * A(0, 0, R(30)),
				V3(0.02, 0.5, 0.08),
				C.barkDark,
				M.SmoothPlastic
			)
		end
	end
end

function byKey.raw_fish(m)
	fish(m, Color3.fromRGB(120, 170, 200), false)
end

function byKey.cooked_fish(m)
	fish(m, C.autumn, true)
end

function byKey.fish_stew(m)
	cylY(m, "Bowl", CFrame.new(0, -0.2, 0), 0.6, 1.5, C.cream, M.SmoothPlastic)
	cylY(m, "Stew", CFrame.new(0, 0.12, 0), 0.1, 1.3, C.autumn:Lerp(C.red, 0.3), M.SmoothPlastic)
	w(
		m,
		"Tail",
		CFrame.new(0.3, 0.4, 0) * A(R(90), R(30), 0),
		V3(0.15, 0.4, 0.4),
		Color3.fromRGB(120, 170, 200),
		M.SmoothPlastic
	)
	ball(m, "Steam", CFrame.new(-0.2, 0.6, 0.1), 0.3, C.white, M.SmoothPlastic).Transparency = 0.5
end

function byKey.coconut_cake(m)
	cylY(m, "Cake", CFrame.new(0, -0.15, 0), 0.6, 1.4, C.canvas, M.Sand)
	cylY(m, "Icing", CFrame.new(0, 0.2, 0), 0.14, 1.46, C.white, M.SmoothPlastic)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		p(
			m,
			"Shaving",
			CFrame.new(math.cos(a) * 0.4, 0.32, math.sin(a) * 0.4) * A(0, a, R(20)),
			V3(0.25, 0.04, 0.12),
			C.cream,
			M.SmoothPlastic
		)
	end
	ball(m, "Cherry", CFrame.new(0, 0.42, 0), 0.26, C.red, M.SmoothPlastic)
end

function byKey.pearl_tea(m)
	cylY(m, "Cup", CFrame.new(0, 0, 0), 0.9, 1, C.white, M.SmoothPlastic)
	cylY(m, "Tea", CFrame.new(0, 0.4, 0), 0.06, 0.88, Color3.fromRGB(200, 150, 90), M.SmoothPlastic)
	p(m, "Handle", CFrame.new(0.6, 0, 0), V3(0.3, 0.5, 0.12), C.white, M.SmoothPlastic)
	ball(m, "Pearl", CFrame.new(0.1, 0.46, -0.1), 0.26, Color3.fromRGB(250, 240, 236), M.SmoothPlastic)
	cylY(m, "Saucer", CFrame.new(0, -0.5, 0), 0.08, 1.5, C.white, M.SmoothPlastic)
end

-- Charts, blueprints, artifacts ---------------------------------------------------------------------------------------
function byKey.chart(m)
	cylZ(m, "Scroll", CFrame.new(0, 0, 0) * A(0, R(90), 0), 1.6, 0.5, C.cream, M.Fabric)
	p(m, "Map", CFrame.new(0.3, 0.1, 0.2) * A(R(-90), R(10), 0), V3(1, 0.8, 0.04), C.cream, M.Fabric)
	p(m, "Isle", CFrame.new(0.3, 0.13, 0.2) * A(R(-90), R(10), 0), V3(0.3, 0.2, 0.02), C.leaf, M.SmoothPlastic)
	p(m, "X", CFrame.new(0.55, 0.13, 0) * A(R(-90), R(55), 0), V3(0.2, 0.04, 0.02), C.red, M.SmoothPlastic)
	p(m, "Ribbon", CFrame.new(-0.5, 0, 0), V3(0.2, 0.56, 0.56), C.cloth, M.Fabric)
end

function byKey.bottle(m)
	local glass = cylZ(
		m,
		"Glass",
		CFrame.new(0, 0, 0) * A(0, R(90), 0) * A(0, R(90), 0),
		1.4,
		0.6,
		Color3.fromRGB(120, 200, 170),
		M.Glass
	)
	glass.Transparency = 0.35
	local neck =
		cylZ(m, "Neck", CFrame.new(0.95, 0, 0) * A(0, R(90), 0), 0.5, 0.3, Color3.fromRGB(120, 200, 170), M.Glass)
	neck.Transparency = 0.35
	cylZ(m, "Cork", CFrame.new(1.25, 0, 0) * A(0, R(90), 0), 0.24, 0.26, C.woodLight, M.Wood)
	cylZ(m, "Note", CFrame.new(-0.1, 0, 0) * A(0, R(90), 0), 0.9, 0.3, C.cream, M.Fabric)
end

function byKey.blueprint(m)
	cylZ(m, "Roll", CFrame.new(0, 0, 0) * A(0, R(90), 0), 1.6, 0.5, C.blueprint, M.Fabric)
	p(m, "Band", CFrame.new(0, 0, 0), V3(0.3, 0.56, 0.56), C.white, M.Fabric)
	p(m, "Sheet", CFrame.new(0.4, 0.1, 0.3) * A(R(-90), R(10), 0), V3(1, 0.8, 0.04), C.blueprint, M.Fabric)
	p(m, "Lines", CFrame.new(0.4, 0.13, 0.3) * A(R(-90), R(10), 0), V3(0.6, 0.4, 0.02), C.white, M.SmoothPlastic)
end

function byKey.old_compass(m)
	cylY(m, "Case", CFrame.new(0, 0, 0), 0.3, 1.2, BRASS, M.Metal)
	cylY(m, "Face", CFrame.new(0, 0.16, 0), 0.04, 1, C.cream, M.SmoothPlastic)
	w(m, "Needle", CFrame.new(0, 0.2, -0.22) * A(R(-90), 0, 0), V3(0.12, 0.45, 0.04), C.red, M.SmoothPlastic)
	w(m, "Needle2", CFrame.new(0, 0.2, 0.22) * A(R(90), 0, 0), V3(0.12, 0.45, 0.04), C.white, M.SmoothPlastic)
	ball(m, "Pin", CFrame.new(0, 0.22, 0), 0.12, BRASS, M.Metal)
	cylY(m, "Ring", CFrame.new(0, 0.3, 0.7), 0.1, 0.3, BRASS, M.Metal)
end

function byKey.ship_bell(m)
	Kit.cone(m, "Bell", V3(0, -0.5, 0), 1.3, 1.1, BRASS, 4, M.Metal, EXTRA)
	cylY(m, "Lip", CFrame.new(0, -0.5, 0), 0.16, 1.4, BRASS:Lerp(C.gold, 0.4), M.Metal)
	ball(m, "Crown", CFrame.new(0, 0.7, 0), 0.3, BRASS, M.Metal)
	ball(m, "Clapper", CFrame.new(0, -0.55, 0), 0.26, C.iron, M.Metal)
	p(m, "Yoke", CFrame.new(0, 0.95, 0), V3(0.9, 0.16, 0.16), C.woodDark, M.Wood)
end

function byKey.logbook(m)
	p(m, "Cover", CFrame.new(0, 0, 0), V3(1.3, 0.3, 1), C.cloth:Lerp(C.ink, 0.4), M.Fabric)
	p(m, "Pages", CFrame.new(0.04, 0, 0), V3(1.24, 0.22, 0.94), C.cream, M.SmoothPlastic)
	p(m, "Spine", CFrame.new(-0.66, 0, 0), V3(0.06, 0.32, 1.02), C.gold, M.Metal)
	p(m, "Strap", CFrame.new(0.3, 0, 0), V3(0.16, 0.34, 1.04), C.barkDark, M.Fabric)
	p(m, "Anchor", CFrame.new(0.1, 0.17, 0), V3(0.3, 0.02, 0.36), C.gold, M.Metal)
end

function byKey.idol(m)
	p(m, "Base", CFrame.new(0, -0.6, 0), V3(1.1, 0.3, 1.1), C.rockDark, M.Slate)
	p(m, "Body", CFrame.new(0, 0, 0), V3(0.7, 0.9, 0.6), C.rock, M.Slate)
	p(m, "Head", CFrame.new(0, 0.75, 0), V3(0.8, 0.6, 0.6), C.rock, M.Slate)
	for _, sx in { -1, 1 } do
		p(m, "Eye", CFrame.new(sx * 0.2, 0.8, -0.3), V3(0.16, 0.16, 0.04), C.glowcap, M.Neon)
	end
	p(m, "Mouth", CFrame.new(0, 0.6, -0.3), V3(0.3, 0.06, 0.04), C.ink, M.SmoothPlastic)
	w(m, "Crest", CFrame.new(0, 1.2, 0) * A(0, 0, 0), V3(0.5, 0.3, 0.6), C.rockDark, M.Slate)
end

function byKey.tooth(m)
	w(m, "Tooth", CFrame.new(0, 0.5, 0) * A(0, 0, 0), V3(0.5, 1.4, 0.5), IVORY, M.Marble)
	p(m, "Root", CFrame.new(0, -0.4, 0), V3(0.6, 0.5, 0.6), IVORY:Lerp(C.bark, 0.3), M.Marble)
	w(m, "Tip", CFrame.new(0, 1.3, 0) * A(0, R(180), 0), V3(0.5, 0.5, 0.5), IVORY, M.Marble)
end

function byKey.relic(m)
	cylZ(m, "Disc", CFrame.new(0, 0, 0), 0.2, 1.2, BRASS:Lerp(C.goldDark, 0.5), M.Metal)
	ball(m, "Gem", CFrame.new(0, 0, -0.12), 0.5, C.glowPurple, M.Neon)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		p(
			m,
			"Ray",
			CFrame.new(math.cos(a) * 0.5, math.sin(a) * 0.5, 0) * A(0, 0, a),
			V3(0.3, 0.1, 0.12),
			BRASS,
			M.Metal
		)
	end
	p(m, "Chain", CFrame.new(0, 0.8, 0), V3(0.08, 0.5, 0.08), C.steel, M.Metal)
end

function draw.other(m, item)
	local fn = byKey[item.key]
	if fn then
		fn(m, item)
		return nil
	end
	local col = item.kind == "food" and C.autumn or item.kind == "artifact" and C.gold or C.white
	ball(m, "Item", CFrame.new(0, 0, 0), 0.8, col, M.SmoothPlastic)
	return nil
end

-- The weld from the hand to the grip, by what the item is.
function ItemModels.holdCFrame(item, hand)
	local down = hand and hand.Size.Y / 2 or 0.15
	local kind = Items.toolKind(item)
	if kind == "axe" or kind == "pick" or kind == "hammer" then
		return CFrame.new(0, -down, 0) * CFrame.Angles(0, 0, math.pi)
	elseif kind == "rod" then
		-- the rod stands up from the fist like an angler's: 65° above level with the forearm out, forward (never
		-- down at the deck) with the arm hanging
		return CFrame.new(0, -down, 0) * CFrame.Angles(math.rad(-25), 0, 0)
	elseif kind == "pry" or (item.weapon and item.weapon.class) or item.light then
		return CFrame.new(0, -down, 0) * CFrame.Angles(math.rad(-90), 0, 0)
	end
	return CFrame.new(0, -down - 0.3, 0)
end

local function build(item, loose)
	local m = Instance.new("Model")
	m.Name = item.key
	local kind = Items.toolKind(item)
	local fn = draw[kind] or (item.weapon and draw[item.weapon.class]) or (item.light and draw.lantern) or draw.other
	local at, glow = fn(m, item)
	local grip = p(m, "Grip", CFrame.new(at or V3(0, 0, 0)), V3(0.2, 0.2, 0.2), C.woodDark, M.SmoothPlastic)
	grip.Transparency = 1
	if not loose then
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and d ~= grip then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = grip
				weld.Part1 = d
				weld.Parent = d
			end
		end
	end
	m.PrimaryPart = grip
	if item.light and glow then
		Kit.light(
			glow,
			"PointLight",
			{ Name = "HeldLight", Color = C.warm, Range = item.light.range, Brightness = item.light.brightness }
		)
	end
	return m, grip
end

function ItemModels.held(item, parent)
	local m, grip = build(item, false)
	m.Parent = parent
	return m, grip
end

-- The model on its own (anchored, no welds), for a ViewportFrame.
function ItemModels.icon(item, parent)
	local m = build(item, true)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	m.Parent = parent
	return m
end

return ItemModels
