--[[
The hotbar's pictures: each weapon and each structure as a little 3D model in a ViewportFrame, in the game's own
look (white pieces, the team's colour where the real thing has it, a dark string), lit from the top left and seen a
little from above, so the bow reads as a bow and the tower as a tower at a glance.

  Icons.weapon(key, team, props)      a ViewportFrame with that weapon (Data/Weapons key) laid across it
  Icons.structure(key, team, props)   a ViewportFrame with that piece (Data/Structures key), seen from the front corner
  Icons.paint(frame, team)            the team's colour on an icon again (after a team change)

Parts here are never in the world: a ViewportFrame draws its own children, nothing collides or casts a shadow.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Structures = require(ReplicatedStorage.Shared.Data.Structures)

local Icons = {}

local WHITE = Constants.WHITE
local INK = Color3.fromRGB(30, 30, 34)

local function teamColor(team)
	return Constants.TEAM_COLOR[team or ""] or Constants.TEAM_COLOR.red
end

-- A piece of an icon. tint: nil for its own colour, else how far from the team's colour toward white (0 = the team's
-- colour itself), so Icons.paint can colour it again
local function piece(model, cf, size, color, tint, shape)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Material = Enum.Material.SmoothPlastic
	p.Size = size
	p.CFrame = cf
	p.Color = color or WHITE
	if shape then
		p.Shape = shape
	end
	if tint then
		p:SetAttribute("Tint", tint)
	end
	p.Parent = model
	return p
end

-- A thin bar from a to b (a limb, a string)
local function bar(model, a, b, thick, depth, color, tint)
	local len = math.max(0.05, (b - a).Magnitude)
	return piece(model, CFrame.lookAt((a + b) / 2, b), Vector3.new(thick, depth or thick, len), color, tint)
end

-- A bow's limb as a curve: n short bars through points bending back from the grip to the tip
local function limb(model, sign, len, curve, thick, color, tint)
	local pts = {}
	local n = 4
	for i = 0, n do
		local f = i / n
		table.insert(pts, Vector3.new(curve * f * f, sign * (0.35 + len * f), 0))
	end
	for i = 1, n do
		bar(model, pts[i], pts[i + 1], thick * (1 - 0.12 * i), thick * 0.7, color, tint)
	end
	return pts[n + 1]
end

-- The weapons, built round the origin in studs (a bow stands along Y, its string toward +X), then turned to lie
-- across the frame
local WEAPON = {}
function WEAPON.bow(m, c)
	piece(m, CFrame.new(-0.05, 0, 0), Vector3.new(0.28, 0.8, 0.3), c, 0)
	local top = limb(m, 1, 1.9, 0.75, 0.24, WHITE)
	local bottom = limb(m, -1, 1.9, 0.75, 0.24, WHITE)
	piece(m, CFrame.new(top), Vector3.new(0.22, 0.22, 0.22), c, 0)
	piece(m, CFrame.new(bottom), Vector3.new(0.22, 0.22, 0.22), c, 0)
	bar(m, top, Vector3.new(0.95, 0, 0), 0.05, nil, INK)
	bar(m, bottom, Vector3.new(0.95, 0, 0), 0.05, nil, INK)
	-- the arrow, nocked
	piece(m, CFrame.new(-0.3, 0, 0.12), Vector3.new(2.5, 0.08, 0.08), WHITE)
	piece(m, CFrame.new(-1.65, 0, 0.12) * CFrame.Angles(0, 0, math.rad(45)), Vector3.new(0.22, 0.22, 0.1), c, 0)
	piece(m, CFrame.new(0.75, 0, 0.12), Vector3.new(0.4, 0.24, 0.03), c, 0)
end
function WEAPON.heavy(m, c)
	piece(m, CFrame.new(-0.05, 0, 0), Vector3.new(0.38, 1.0, 0.4), c, 0)
	piece(m, CFrame.new(-0.05, 0, 0), Vector3.new(0.42, 0.25, 0.44), INK)
	local top = limb(m, 1, 2.2, 0.55, 0.36, WHITE)
	local bottom = limb(m, -1, 2.2, 0.55, 0.36, WHITE)
	-- bands round the limbs and recurved tips in the team's colour
	for _, sgn in { 1, -1 } do
		piece(
			m,
			CFrame.new(0.14, sgn * 1.45, 0) * CFrame.Angles(0, 0, math.rad(sgn * -14)),
			Vector3.new(0.44, 0.22, 0.4),
			c,
			0
		)
	end
	piece(
		m,
		CFrame.new(top + Vector3.new(-0.12, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(-35)),
		Vector3.new(0.2, 0.5, 0.26),
		c,
		0
	)
	piece(
		m,
		CFrame.new(bottom + Vector3.new(-0.12, -0.15, 0)) * CFrame.Angles(0, 0, math.rad(35)),
		Vector3.new(0.2, 0.5, 0.26),
		c,
		0
	)
	bar(m, top, Vector3.new(0.8, 0, 0), 0.07, nil, INK)
	bar(m, bottom, Vector3.new(0.8, 0, 0), 0.07, nil, INK)
	piece(m, CFrame.new(-0.4, 0, 0.16), Vector3.new(2.5, 0.12, 0.12), WHITE)
	piece(m, CFrame.new(-1.75, 0, 0.16) * CFrame.Angles(0, 0, math.rad(45)), Vector3.new(0.3, 0.3, 0.14), c, 0)
end
function WEAPON.crossbow(m, c)
	-- the stock along X, the limbs across it at the front, the string back to the latch, a bolt on top
	piece(m, CFrame.new(0.3, 0, 0), Vector3.new(2.6, 0.3, 0.3), WHITE)
	piece(m, CFrame.new(1.45, -0.15, 0), Vector3.new(0.6, 0.5, 0.32), c, 0)
	piece(m, CFrame.new(0.75, -0.42, 0) * CFrame.Angles(0, 0, math.rad(-12)), Vector3.new(0.24, 0.55, 0.26), c, 0)
	piece(m, CFrame.new(0.45, -0.3, 0), Vector3.new(0.08, 0.26, 0.1), INK)
	local tips = {}
	for i, sgn in { 1, -1 } do
		local a = Vector3.new(-0.85, 0, 0)
		local b = Vector3.new(-0.55, 0, sgn * 1.25)
		bar(m, a, b, 0.22, 0.14, WHITE)
		tips[i] = b
		piece(m, CFrame.new(b), Vector3.new(0.18, 0.18, 0.18), c, 0)
	end
	bar(m, tips[1], Vector3.new(0.05, 0.12, 0), 0.05, nil, INK)
	bar(m, tips[2], Vector3.new(0.05, 0.12, 0), 0.05, nil, INK)
	piece(m, CFrame.new(-0.4, 0.2, 0), Vector3.new(1.3, 0.08, 0.08), WHITE)
	piece(m, CFrame.new(-1.1, 0.2, 0) * CFrame.Angles(0, 0, math.rad(45)), Vector3.new(0.18, 0.18, 0.1), c, 0)
end
function WEAPON.blade(m, c)
	-- along X: the pommel, the grip in the team's colour, the guard, a long white edge with a coloured spine
	piece(m, CFrame.new(1.55, 0, 0), Vector3.new(0.26, 0.26, 0.26), WHITE)
	piece(m, CFrame.new(1.1, 0, 0), Vector3.new(0.7, 0.2, 0.2), c, 0)
	piece(m, CFrame.new(0.68, 0, 0), Vector3.new(0.16, 0.95, 0.24), WHITE)
	piece(m, CFrame.new(-0.6, 0, 0), Vector3.new(2.4, 0.34, 0.08), WHITE)
	piece(m, CFrame.new(-0.5, 0.04, 0), Vector3.new(2.0, 0.08, 0.1), c, 0)
	piece(m, CFrame.new(-1.88, 0, 0) * CFrame.Angles(0, 0, math.rad(45)), Vector3.new(0.24, 0.24, 0.08), WHITE)
end
-- how each lies across its frame (a turn about the view axis), and how much room it takes
local LAY = { bow = 32, heavy = 32, crossbow = -24, blade = -28 }

-- The structures, from Data/Structures' sizes (a cell is 4 studs), like BuildService builds them
local function structureModel(m, def, c)
	local w, d = def.w * Constants.CELL, def.d * Constants.CELL
	local h = def.h
	if def.key == "banner" then
		piece(m, CFrame.new(0, h / 2, 0), Vector3.new(0.6, h, 0.6), WHITE)
		piece(m, CFrame.new(1.2, h - 2.5, 0), Vector3.new(2.4, 4, 0.2), c, 0)
		piece(m, CFrame.new(0, 0.3, 0), Vector3.new(2.4, 0.6, 2.4), WHITE)
	elseif def.key == "tower" then
		local hx, hz = w / 2 - 0.6, d / 2 - 0.6
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				piece(m, CFrame.new(sx * hx, h / 2, sz * hz), Vector3.new(1.2, h, 1.2), WHITE)
			end
		end
		piece(m, CFrame.new(0, h / 2, 0), Vector3.new(w - 2.4, h - 1, d - 2.4), c, 0.35)
		piece(m, CFrame.new(0, h - 0.5, 0), Vector3.new(w, 1, d), c, 0.35)
		for _, sz in { -1, 1 } do
			piece(m, CFrame.new(0, h + 1, sz * (d / 2 - 0.2)), Vector3.new(w, 2, 0.4), c, 0)
			piece(m, CFrame.new(sz * (w / 2 - 0.2), h + 1, 0), Vector3.new(0.4, 2, d), c, 0)
		end
	elseif def.key == "bridge" then
		piece(m, CFrame.new(0, h - 0.5, 0), Vector3.new(w, 1, d), c, 0.35)
		for _, sz in { -1, 1 } do
			piece(m, CFrame.new(0, (h - 1) / 2, sz * (d / 2 - 0.6)), Vector3.new(w - 0.4, h - 1, 1.2), WHITE)
		end
		piece(m, CFrame.new(0, h + 0.4, 0), Vector3.new(w + 0.1, 0.2, d * 0.7), c, 0)
	else
		piece(m, CFrame.new(0, h / 2, 0), Vector3.new(w, h, d), c, 0.35)
		piece(m, CFrame.new(0, h + 0.2, 0), Vector3.new(w + 0.3, 0.4, d + 0.3), WHITE)
		piece(m, CFrame.new(0, h * 0.6, 0), Vector3.new(w + 0.05, 0.5, d + 0.05), c, 0)
		if def.key == "reinforced" then
			for _, sx in { -1, 1 } do
				piece(m, CFrame.new(sx * (w / 2 - 0.4), h / 2, 0), Vector3.new(0.9, h, d + 0.4), WHITE)
			end
		end
	end
	-- a square of turf under it, so it stands on something
	piece(m, CFrame.new(0, -0.15, 0), Vector3.new(w + 1.6, 0.3, d + 1.6), c, 0.6)
end

-- How the model sits as seen along `view` (a camera's turn): its middle, and how far it reaches across, up and
-- toward the camera from there
local function bounds(model, view)
	local lo, hi
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			local s = p.Size / 2
			for _, cx in { -1, 1 } do
				for _, cy in { -1, 1 } do
					for _, cz in { -1, 1 } do
						local q = view:PointToObjectSpace(p.CFrame * Vector3.new(s.X * cx, s.Y * cy, s.Z * cz))
						lo = lo and Vector3.new(math.min(lo.X, q.X), math.min(lo.Y, q.Y), math.min(lo.Z, q.Z)) or q
						hi = hi and Vector3.new(math.max(hi.X, q.X), math.max(hi.Y, q.Y), math.max(hi.Z, q.Z)) or q
					end
				end
			end
		end
	end
	lo, hi = lo or Vector3.zero, hi or Vector3.zero
	return view * ((lo + hi) / 2), (hi - lo) / 2
end

-- The frame, its light and a camera looking at the model from `from` (a direction), just close enough that the
-- model fills `fill` of the frame's width or height, whichever it meets first
local function frame(model, from, props, fill)
	local vf = Instance.new("ViewportFrame")
	vf.Name = "Icon"
	vf.BackgroundTransparency = 1
	vf.Ambient = Color3.fromRGB(175, 175, 182)
	vf.LightColor = Color3.fromRGB(255, 255, 255)
	vf.LightDirection = Vector3.new(-0.6, -1, -0.5)
	for k, v in props or {} do
		if k ~= "Parent" then
			vf[k] = v
		end
	end
	local size = vf.Size
	local aspect = (size and size.Y.Offset > 0) and size.X.Offset / size.Y.Offset or 1
	local cam = Instance.new("Camera")
	cam.FieldOfView = 24
	local view = CFrame.lookAt(Vector3.zero, -from.Unit)
	local center, half = bounds(model, view)
	local tanV = math.tan(math.rad(cam.FieldOfView / 2))
	local dist = math.max(half.Y / tanV, half.X / (tanV * aspect)) / (fill or 1) + half.Z
	cam.CFrame = CFrame.lookAt(center + from.Unit * dist, center)
	cam.Parent = vf
	vf.CurrentCamera = cam
	model.Parent = vf
	if props and props.Parent then
		vf.Parent = props.Parent
	end
	return vf
end

function Icons.weapon(key, team, props)
	local model = Instance.new("Model")
	model.Name = "Weapon"
	local build = WEAPON[key] or WEAPON.bow
	build(model, teamColor(team))
	-- lay it across the frame, tipped toward you a little so it has some depth
	-- (the crossbow from well above, so its limbs show across the stock)
	local tip = key == "crossbow" and 62 or 18
	local turn = CFrame.Angles(0, 0, math.rad(LAY[key] or 0)) * CFrame.Angles(math.rad(tip), math.rad(16), 0)
	for _, p in model:GetChildren() do
		p.CFrame = turn * p.CFrame
	end
	return frame(model, Vector3.new(0, 0, 1), props, 1)
end

function Icons.structure(key, team, props)
	local def = Structures.get(key)
	local model = Instance.new("Model")
	model.Name = "Structure"
	if def then
		structureModel(model, def, teamColor(team))
	end
	return frame(model, Vector3.new(1, 0.75, 1.35), props, 0.9)
end

function Icons.paint(vf, team)
	local c = teamColor(team)
	for _, p in vf:GetDescendants() do
		local tint = p:IsA("BasePart") and p:GetAttribute("Tint")
		if tint then
			p.Color = c:Lerp(WHITE, tint)
		end
	end
end

return Icons
