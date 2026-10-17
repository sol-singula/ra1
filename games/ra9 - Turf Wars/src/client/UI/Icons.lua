--[[
The hotbar's pictures: each weapon and each structure as a little 3D model in a ViewportFrame, in the game's own
look (white pieces, the team's colour where the real thing has it, a dark string), lit from the top left and seen a
little from above, so the bow reads as a bow and the tower as a tower at a glance.

  Icons.weapon(key, team, props)      a ViewportFrame with that weapon (Data/Weapons key) laid across it
  Icons.structure(key, team, props)   a ViewportFrame with that piece (Data/Structures key) as it's built
                                      (StructureModel: the same castle stone, wood, iron and team trim), seen from
                                      the front corner
  Icons.paint(frame, team)            the team's colour on an icon again (after a team change)

And the shop's pictures (PanelController), so every card shows the real thing:

  Icons.cosmetic(item, team, props)   a cosmetic (Data/Cosmetics): a bow in its finish, a trail as a glowing
                                      streak behind an arrow, a kill effect as a burst (3D); a banner as a flag, a
                                      title as a nameplate (drawn with frames)
  Icons.shardPile(size, props)        Shards: 1 a few gems, 2 a heap, 3 a crate of them, 4 an overflowing vault
  Icons.gift(team, props)             the Starter Pack: a present with gems
  Icons.pass(props)                   the Turf Pass: a gold ticket with a crown
  Icons.tierUp(props)                 +1 TIER: steps up, the top one gold, an arrow over it

Parts here are never in the world: a ViewportFrame draws its own children, nothing collides or casts a shadow.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local StructureModel = require(ReplicatedStorage.Shared.StructureModel)
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
function WEAPON.tnt(m)
	-- a bundle of three red sticks lying along X, two dark bands round them, a fuse curling out of one end with its
	-- spark
	local red = Constants.TNT_RED
	for _, at in { Vector3.new(0, 0.2, 0.18), Vector3.new(0, 0.2, -0.18), Vector3.new(0, -0.14, 0) } do
		piece(m, CFrame.new(at), Vector3.new(2.3, 0.42, 0.42), red, nil, Enum.PartType.Cylinder)
		-- (the stick's paper end, a lighter ring)
		piece(
			m,
			CFrame.new(at + Vector3.new(-1.16, 0, 0)),
			Vector3.new(0.04, 0.36, 0.36),
			Color3.fromRGB(236, 170, 150),
			nil,
			Enum.PartType.Cylinder
		)
	end
	for _, x in { -0.55, 0.55 } do
		piece(m, CFrame.new(x, 0.08, 0), Vector3.new(0.18, 0.9, 0.86), INK)
	end
	bar(m, Vector3.new(1.15, 0.2, 0.18), Vector3.new(1.55, 0.5, 0.18), 0.07, nil, INK)
	bar(m, Vector3.new(1.55, 0.5, 0.18), Vector3.new(1.8, 0.42, 0.18), 0.07, nil, INK)
	local spark = piece(
		m,
		CFrame.new(1.86, 0.42, 0.18),
		Vector3.new(0.3, 0.3, 0.3),
		Color3.fromRGB(255, 200, 60),
		nil,
		Enum.PartType.Ball
	)
	spark.Material = Enum.Material.Neon
	for i = 1, 4 do
		local a = i * math.pi / 2 + 0.4
		bar(
			m,
			Vector3.new(1.86, 0.42, 0.18),
			Vector3.new(1.86 + math.cos(a) * 0.32, 0.42 + math.sin(a) * 0.32, 0.18),
			0.05,
			nil,
			Color3.fromRGB(255, 230, 120)
		).Material =
			Enum.Material.Neon
	end
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
local LAY = { bow = 32, tnt = 18, blade = -28 }

-- The structures, from Data/Structures' sizes (a cell is 4 studs), exactly as BuildService builds them
local function structureModel(m, def, team, c)
	local w, d = def.w * Constants.CELL, def.d * Constants.CELL
	for _, spec in StructureModel.parts(def.key, team, Vector3.new(-w / 2, 0, -d / 2), Vector3.new(w / 2, def.h, d / 2)) do
		local p = StructureModel.make(spec, team)
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Massless = true
		p.Parent = m
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
	-- (the TNT from a little more above, so the bundle shows its three sticks)
	local tip = key == "tnt" and 30 or 18
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
		structureModel(model, def, team or "red", teamColor(team))
	end
	return frame(model, Vector3.new(1, 0.75, 1.35), props, 0.9)
end

-- The shop's pictures ------------------------------------------------------------------------------------------
local GOLD = Color3.fromRGB(255, 196, 40)
local GEM = Color3.fromRGB(40, 190, 230)
local GEM_LIGHT = Color3.fromRGB(150, 235, 250)
Icons.GOLD = GOLD

-- A colour token (Data/Cosmetics) as a colour and a tint, so Icons.paint can follow a team change
local function token(t, team)
	if t == "team" then
		return Cosmetics.color(t, team), 0
	elseif t == "light" then
		return Cosmetics.color(t, team), 0.5
	end
	return Cosmetics.color(t, team), nil
end

-- A bow in a finish: its grip and limbs in the look's colours and material
local SURFACE = {
	Glass = { Enum.Material.Glass, 0.25 },
	ForceField = { Enum.Material.Neon, 0.35 }, -- (a hologram: a see-through glow)
	Ice = { Enum.Material.Ice, 0.1 },
}
local function finishedBow(m, look, team)
	local grip, gt = token(look.grip, team)
	local limbs, lt = token(look.limbs, team)
	local surf = SURFACE[look.material]
	local mat = surf and surf[1] or Enum.Material[look.material or "SmoothPlastic"]
	local see = surf and surf[2] or 0
	local top = limb(m, 1, 1.9, 0.75, 0.26, limbs, lt)
	local bottom = limb(m, -1, 1.9, 0.75, 0.26, limbs, lt)
	for _, p in m:GetChildren() do
		p.Material, p.Transparency = mat, see
	end
	piece(m, CFrame.new(-0.05, 0, 0), Vector3.new(0.32, 0.85, 0.34), grip, gt).Material = mat
	piece(m, CFrame.new(top), Vector3.new(0.24, 0.24, 0.24), grip, gt).Material = mat
	piece(m, CFrame.new(bottom), Vector3.new(0.24, 0.24, 0.24), grip, gt).Material = mat
	bar(m, top, Vector3.new(0.95, 0, 0), 0.05, nil, INK)
	bar(m, bottom, Vector3.new(0.95, 0, 0), 0.05, nil, INK)
end

-- An arrow along +X with its tracer streaking out behind it: the team's glow thinning and fading, then the trail's
-- own lines beside it (dashed, twisting, jittering, or afterimages, as the look says)
local function streak(m, look, team)
	local tc = teamColor(team)
	local len = 4.2 * math.clamp(look.length or 1, 0.6, 2)
	piece(m, CFrame.new(0.9, 0, 0), Vector3.new(1.8, 0.1, 0.1), WHITE)
	piece(m, CFrame.new(1.9, 0, 0) * CFrame.Angles(0, 0, math.rad(45)), Vector3.new(0.3, 0.3, 0.12), tc, 0)
	piece(m, CFrame.new(0.15, 0.12, 0), Vector3.new(0.4, 0.16, 0.03), tc, 0)
	piece(m, CFrame.new(0.15, -0.12, 0), Vector3.new(0.4, 0.16, 0.03), tc, 0)
	local n = 6
	for i = 1, n do
		local f = (i - 0.5) / n
		local th = 0.18 * (1 - f * 0.6)
		local p = piece(m, CFrame.new(-len * f, 0, 0), Vector3.new(len / n + 0.02, th, th), tc, 0)
		p.Material = Enum.Material.Neon
		p.Transparency = f * 0.75
	end
	for li, l in look.lines or {} do
		local c, tint = token(l[4], team)
		local th = math.clamp(l[3] * 1.4, 0.06, 0.4)
		local segs = (look.dash or look.jitter or look.spin) and 8 or 1
		for i = 1, segs do
			if not (look.dash and i % 2 == 0) then
				local f = (i - 0.5) / segs
				local y = (l[1] + l[2]) * 2.2
				if look.spin then
					y = math.sin(f * math.pi * 3 + li * math.pi) * (math.abs(l[1]) + 0.1) * 2.6
				elseif look.jitter then
					y += (i % 2 == 0 and 0.18 or -0.18)
				end
				local p = piece(m, CFrame.new(-len * f, y, 0.05), Vector3.new(len / segs * 0.9, th, th), c, tint)
				p.Material = c == Cosmetics.color("white") and Enum.Material.Neon or Enum.Material.SmoothPlastic
				p.Transparency = f * 0.5
			end
		end
	end
	-- a ribbon: a soft band streaming out behind, wide at the arrow and thinning
	if look.ribbon then
		local c, tint = token(look.ribbon[2], team)
		for i = 1, 4 do
			local f = (i - 0.5) / 4
			local w = math.clamp(look.ribbon[1], 0.1, 1) * 0.7 * (1 - f * 0.7)
			local p = piece(m, CFrame.new(-len * f * 0.8, -0.05, -0.05), Vector3.new(len / 4 * 0.85, w, 0.03), c, tint)
			p.Transparency = 0.25 + f * 0.6
		end
	end
	-- afterimages: faded copies of the arrow behind it
	for i = 1, look.ghost or 0 do
		local x = -i * 1.3
		piece(m, CFrame.new(x + 0.9, 0.35, 0), Vector3.new(1.8, 0.08, 0.08), WHITE).Transparency = 0.3 + i * 0.2
		piece(m, CFrame.new(x + 1.9, 0.35, 0) * CFrame.Angles(0, 0, math.rad(45)), Vector3.new(0.26, 0.26, 0.1), tc, 0).Transparency = 0.3
			+ i * 0.2
	end
end

-- A kill effect: a burst round a bright core, in the look's shape and colour
local function burst(m, look, team)
	local c, tint = token(look.color, team)
	piece(m, CFrame.new(), Vector3.new(0.7, 0.7, 0.7), c, tint, Enum.PartType.Ball).Material = Enum.Material.Neon
	local shape = look.shape
	local n = math.clamp(look.count or 10, 8, 16)
	local golden = math.pi * (3 - math.sqrt(5))
	local turned = CFrame.Angles(0, 0, math.rad(90)) -- (a cylinder lies along X: stood up)
	if shape == "ring" then
		for ring = 1, (look.count or 0) >= 18 and 2 or 1 do
			local r = ring == 1 and 2 or 1.3
			for i = 1, 16 do
				local a = i / 16 * math.pi * 2
				piece(
					m,
					CFrame.new(math.cos(a) * r, math.sin(a) * r, 0) * CFrame.Angles(0, 0, a),
					Vector3.new(0.2, r * 0.42, 0.2),
					c,
					tint
				)
			end
		end
	elseif shape == "rise" then
		piece(m, CFrame.new(0, -1.6, 0) * turned, Vector3.new(0.15, 3.4, 3.4), c, tint, Enum.PartType.Cylinder)
		for i = 1, n do
			local a = i * golden
			local r = 0.5 + (i % 3) * 0.45
			piece(
				m,
				CFrame.new(math.cos(a) * r, -1.2 + (i / n) * 3, math.sin(a) * r * 0.5),
				Vector3.new(0.18, 0.6 + (i % 4) * 0.24, 0.18),
				c,
				tint
			).Transparency = (
				i / n
			) * 0.5
		end
	elseif shape == "spotlight" then
		local beam = piece(m, CFrame.new(0, 0.6, 0) * turned, Vector3.new(4.4, 2, 2), c, tint, Enum.PartType.Cylinder)
		beam.Material, beam.Transparency = Enum.Material.Neon, 0.6
		piece(m, CFrame.new(0, -1.6, 0) * turned, Vector3.new(0.1, 3.2, 3.2), c, tint, Enum.PartType.Cylinder).Material =
			Enum.Material.Neon
	else
		-- cubes, shards, pixels: pieces thrown out all round (on a fixed spiral, so every card is the same)
		for i = 1, n do
			local y = 1 - (i - 0.5) / n * 2
			local rr = math.sqrt(1 - y * y)
			local a = i * golden
			local dir = Vector3.new(math.cos(a) * rr, y, math.sin(a) * rr * 0.4)
			local at = dir * (1.5 + (i % 3) * 0.35)
			if shape == "shards" then
				bar(m, at - dir * 0.55, at + dir * 0.55, 0.16, 0.16, c, tint)
			elseif shape == "pixels" then
				piece(m, CFrame.new(at), Vector3.new(0.42, 0.42, 0.08), c, tint)
			else
				piece(m, CFrame.new(at) * CFrame.Angles(a, a * 0.7, 0), Vector3.new(0.42, 0.42, 0.42), c, tint)
			end
		end
	end
end

-- Vector art (a banner, a title): a clear box marked as a picture (its pieces sit on each other on purpose)
local function art(props)
	local box = Instance.new("Frame")
	box.Name = "Icon"
	box.BackgroundTransparency = 1
	box.BorderSizePixel = 0
	for k, v in props or {} do
		if k ~= "Parent" then
			box[k] = v
		end
	end
	box:SetAttribute("Art", true)
	if props and props.Parent then
		box.Parent = props.Parent
	end
	return box
end
local function rect(parent, name, props, radius)
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	for k, v in props do
		f[k] = v
	end
	if radius then
		local c = Instance.new("UICorner")
		c.CornerRadius = radius
		c.Parent = f
	end
	f.Parent = parent
	return f
end
local function words(parent, name, s, props)
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.Text = s
	t.TextScaled = true
	t.Font = Enum.Font.GothamBlack
	t.TextColor3 = Color3.new(1, 1, 1)
	for k, v in props do
		t[k] = v
	end
	t.Parent = parent
	return t
end

-- A banner: a flag on a pole in the team's colour, the emblem on it
local function flag(it, team, props)
	local box = art(props)
	rect(box, "Pole", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.3, 0.06),
		Size = UDim2.new(0, 4, 0.9, 0),
		BackgroundColor3 = INK,
	}, UDim.new(1, 0))
	rect(box, "Knob", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.3, 0.07),
		Size = UDim2.fromOffset(9, 9),
		BackgroundColor3 = GOLD,
	}, UDim.new(1, 0))
	local cloth = rect(box, "Cloth", {
		Position = UDim2.new(0.3, 2, 0.12, 0),
		Size = UDim2.fromScale(0.44, 0.62),
		BackgroundColor3 = teamColor(team),
	}, UDim.new(0, 2))
	cloth:SetAttribute("Tint", 0)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(175, 175, 175))
	g.Parent = cloth
	rect(cloth, "Hem", {
		Position = UDim2.new(0, 0, 1, -4),
		Size = UDim2.new(1, 0, 0, 4),
		BackgroundColor3 = WHITE,
	})
	words(cloth, "Emblem", (it.look or {}).emblem or "★", {
		Position = UDim2.fromScale(0.12, 0.1),
		Size = UDim2.fromScale(0.76, 0.72),
	})
	return box
end

-- A title: a dark nameplate with the words in white under a little gold crown
local function nameplate(it, props)
	local box = art(props)
	local plate = rect(box, "Plate", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.6),
		Size = UDim2.fromScale(0.94, 0.48),
		BackgroundColor3 = INK,
	}, UDim.new(0, 6))
	rect(plate, "Gold", {
		Position = UDim2.new(0, 6, 0, 3),
		Size = UDim2.new(1, -12, 0, 3),
		BackgroundColor3 = GOLD,
	})
	words(plate, "Words", string.upper((it.look or {}).text or it.name), {
		Position = UDim2.new(0, 8, 0, 8),
		Size = UDim2.new(1, -16, 1, -12),
	})
	local crown = rect(box, "Crown", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0.36, -1),
		Size = UDim2.fromOffset(24, 7),
		BackgroundColor3 = GOLD,
	})
	for i, x in { 0.08, 0.5, 0.92 } do
		rect(crown, "Point" .. i, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, 0),
			Size = UDim2.fromOffset(i == 2 and 9 or 7, i == 2 and 9 or 7),
			Rotation = 45,
			BackgroundColor3 = GOLD,
		})
	end
	return box
end

function Icons.cosmetic(it, team, props)
	props = props or {}
	if not it then
		return art(props)
	elseif it.kind == "banner" then
		return flag(it, team, props)
	elseif it.kind == "title" then
		return nameplate(it, props)
	end
	local model = Instance.new("Model")
	model.Name = "Cosmetic"
	local look = it.look or {}
	local turn
	if it.kind == "skin" then
		finishedBow(model, look, team)
		turn = CFrame.Angles(0, 0, math.rad(LAY.bow)) * CFrame.Angles(math.rad(18), math.rad(16), 0)
	elseif it.kind == "trail" then
		streak(model, look, team)
		turn = CFrame.Angles(0, 0, math.rad(16)) * CFrame.Angles(math.rad(14), math.rad(-12), 0)
	else
		burst(model, look, team)
		turn = CFrame.Angles(math.rad(10), math.rad(20), 0)
	end
	for _, p in model:GetChildren() do
		p.CFrame = turn * p.CFrame
	end
	return frame(model, Vector3.new(0, 0.1, 1), props, 0.94)
end

-- A gem: a long crystal stood up (with a lighter tip), or a cube on its corner, in the Shards' aqua
local function crystal(m, at, s, long, lean)
	if long then
		local cf = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(lean or 0)) * CFrame.Angles(0, math.rad(45), 0)
		piece(m, cf, Vector3.new(0.55 * s, 1.5 * s, 0.55 * s), GEM)
		piece(
			m,
			cf * CFrame.new(0, 0.75 * s, 0) * CFrame.Angles(math.rad(45), 0, 0),
			Vector3.new(0.39 * s, 0.39 * s, 0.39 * s),
			GEM_LIGHT
		)
	else
		piece(
			m,
			CFrame.new(at) * CFrame.Angles(0, math.rad(45 + (lean or 0)), 0) * CFrame.Angles(math.rad(35.26), 0, 0),
			Vector3.new(0.8 * s, 0.8 * s, 0.8 * s),
			GEM
		)
	end
end

-- Where the gems go for the two smaller packs: { x, y, z, size, long, lean }
local PILE = {
	{ { 0, 0.2, 0, 1.2, true, 0 }, { -0.8, -0.3, 0.3, 0.9, false, 10 }, { 0.8, -0.35, 0.2, 0.8, false, -20 } },
	{
		{ 0, 0.5, 0, 1.3, true, 0 },
		{ -0.7, 0.1, 0.2, 1, true, 18 },
		{ 0.75, 0.05, 0.1, 1, true, -16 },
		{ -1.3, -0.5, 0.5, 0.8, false, 0 },
		{ 1.3, -0.5, 0.4, 0.8, false, 25 },
		{ 0, -0.55, 0.8, 0.75, false, 12 },
	},
}
function Icons.shardPile(size, props)
	local model = Instance.new("Model")
	model.Name = "Shards"
	size = math.clamp(size or 1, 1, 4)
	if size <= 2 then
		for _, g in PILE[size] do
			crystal(model, Vector3.new(g[1], g[2], g[3]), g[4], g[5], g[6])
		end
		if size == 2 then
			piece(model, CFrame.new(0, -0.95, 0.2), Vector3.new(3.4, 0.25, 1.8), GEM_LIGHT)
		end
	else
		-- a white crate (3) or a black vault banded in gold (4), full to the top and spilling over
		local w = size == 3 and 3 or 3.8
		local h = size == 3 and 1.6 or 2
		local trim = size == 3 and INK or GOLD
		piece(model, CFrame.new(0, -h / 2, 0), Vector3.new(w, h, 2), size == 3 and WHITE or INK)
		piece(model, CFrame.new(0, -0.15, 0), Vector3.new(w + 0.12, 0.25, 2.12), trim)
		piece(model, CFrame.new(0, -h + 0.15, 0), Vector3.new(w + 0.12, 0.25, 2.12), trim)
		for _, sx in { -1, 1 } do
			piece(model, CFrame.new(sx * (w / 2 - 0.1), -h / 2, 0), Vector3.new(0.25, h, 2.14), trim)
		end
		if size == 4 then
			piece(model, CFrame.new(0, -h / 2, 1.05), Vector3.new(0.5, 0.6, 0.12), GOLD)
		end
		local n = size == 3 and 7 or 11
		for i = 1, n do
			local tall = i % 2 == 1
			crystal(
				model,
				Vector3.new(((i - 1) / (n - 1) - 0.5) * (w - 0.6), tall and 0.45 or 0.15, (i % 3 - 1) * 0.35),
				tall and 0.95 or 0.8,
				tall,
				(i % 3 - 1) * 14
			)
		end
		if size == 4 then
			crystal(model, Vector3.new(-2.3, -1.6, 0.9), 0.8, false, 20)
			crystal(model, Vector3.new(2.25, -1.65, 0.8), 0.7, false, -10)
			crystal(model, Vector3.new(0, 1.15, 0), 1.2, true, 0)
		end
	end
	return frame(model, Vector3.new(0.35, 0.55, 1), props, 0.92)
end

function Icons.gift(team, props)
	local model = Instance.new("Model")
	model.Name = "Gift"
	local tc = teamColor(team)
	piece(model, CFrame.new(0, 0, 0), Vector3.new(2.4, 1.9, 2.4), WHITE)
	piece(model, CFrame.new(0, 1.05, 0), Vector3.new(2.6, 0.45, 2.6), WHITE)
	piece(model, CFrame.new(0, 0.2, 0), Vector3.new(0.5, 2.4, 2.65), tc, 0)
	piece(model, CFrame.new(0, 0.2, 0), Vector3.new(2.65, 2.4, 0.5), tc, 0)
	for _, s in { 1, -1 } do
		piece(
			model,
			CFrame.new(s * 0.45, 1.6, 0) * CFrame.Angles(0, 0, math.rad(s * -35)),
			Vector3.new(0.9, 0.55, 0.3),
			tc,
			0
		)
	end
	crystal(model, Vector3.new(1.85, -0.35, 1), 0.9, true, -12)
	crystal(model, Vector3.new(-1.75, -0.6, 1.1), 0.75, false, 0)
	return frame(model, Vector3.new(0.6, 0.55, 1), props, 0.9)
end

function Icons.pass(props)
	local model = Instance.new("Model")
	model.Name = "Pass"
	local tilt = CFrame.Angles(0, 0, math.rad(-12)) * CFrame.Angles(math.rad(-18), math.rad(22), 0)
	local function at(cf, size, color, metal)
		local p = piece(model, tilt * cf, size, color)
		if metal then
			p.Material = Enum.Material.Metal
		end
		return p
	end
	at(CFrame.new(), Vector3.new(3.6, 2.3, 0.18), GOLD, true)
	at(CFrame.new(0, 0, 0.1), Vector3.new(3.0, 1.75, 0.05), WHITE)
	-- the crown on it, and a notch each side like a ticket
	at(CFrame.new(0, -0.25, 0.15), Vector3.new(1.4, 0.4, 0.1), GOLD, true)
	for i, x in { -0.6, 0, 0.6 } do
		at(
			CFrame.new(x, i == 2 and 0.2 or 0.1, 0.15) * CFrame.Angles(0, 0, math.rad(45)),
			Vector3.new(0.42, 0.42, 0.1),
			GOLD,
			true
		)
	end
	for _, s in { -1, 1 } do
		at(CFrame.new(s * 1.8, 0, 0) * CFrame.Angles(0, 0, math.rad(45)), Vector3.new(0.4, 0.4, 0.22), INK)
	end
	return frame(model, Vector3.new(0, 0, 1), props, 0.92)
end

function Icons.tierUp(props)
	local model = Instance.new("Model")
	model.Name = "TierUp"
	for i = 1, 3 do
		local h = 0.6 * i
		piece(model, CFrame.new((i - 2) * 1.05, h / 2, 0), Vector3.new(1, h, 1.2), i == 3 and GOLD or WHITE)
	end
	-- the arrow, up from the top step
	piece(model, CFrame.new(1.05, 2.6, 0), Vector3.new(0.3, 1.2, 0.3), GOLD)
	for _, s in { 1, -1 } do
		piece(
			model,
			CFrame.new(1.05 + s * 0.24, 3.05, 0) * CFrame.Angles(0, 0, math.rad(s * 45)),
			Vector3.new(0.3, 0.8, 0.3),
			GOLD
		)
	end
	return frame(model, Vector3.new(0.5, 0.45, 1), props, 0.9)
end

function Icons.paint(vf, team)
	local c = teamColor(team)
	for _, p in vf:GetDescendants() do
		local tint = p:IsA("BasePart") and p:GetAttribute("Tint")
		local tone = p:IsA("BasePart") and p:GetAttribute("Tone")
		if tint then
			p.Color = c:Lerp(WHITE, tint)
		elseif tone then
			p.Color = StructureModel.color(tone, team) -- (a structure: its stone, wood, iron or team trim)
		end
	end
end

return Icons
