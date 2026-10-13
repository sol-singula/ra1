-- Plain-part scenery: the brick look (studs on top), rocks, crystals, stars and glowing rings.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)

local Scenery = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
Scenery.rgb = rgb

-- Plastic bricks with studs on top (blocks only; balls and cylinders just become plastic).
local TO_PLASTIC = {
	[Enum.Material.Grass] = true,
	[Enum.Material.Sand] = true,
	[Enum.Material.Slate] = true,
	[Enum.Material.Concrete] = true,
	[Enum.Material.Fabric] = true,
	[Enum.Material.Snow] = true,
}
function Scenery.brick(p)
	if TO_PLASTIC[p.Material] then
		p.Material = Enum.Material.Plastic
	end
	if p.Material == Enum.Material.Plastic and (p.Shape == nil or p.Shape == Enum.PartType.Block) then
		p.TopSurface = Enum.SurfaceType.Studs
		p.BottomSurface = Enum.SurfaceType.Inlet
	end
	return p
end

function Scenery.part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		if k ~= "Parent" then
			p[k] = v
		end
	end
	Scenery.brick(p)
	p.Parent = props.Parent
	return p
end
local part = Scenery.part

function Scenery.disc(parent, name, center, diameter, height, color, material, extra)
	local props = {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Parent = parent,
	}
	for k, v in extra or {} do
		props[k] = v
	end
	return part(props)
end
local disc = Scenery.disc

function Scenery.ball(parent, name, center, diameter, color, material, extra)
	local props = {
		Name = name,
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(diameter, diameter, diameter),
		CFrame = CFrame.new(center),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Parent = parent,
	}
	for k, v in extra or {} do
		props[k] = v
	end
	return part(props)
end
local ball = Scenery.ball

-- A rock: a few tilted boxes.
function Scenery.rock(parent, pos, size, color, rng)
	for i = 1, 3 do
		local s = size * rng:NextNumber(0.5, 1)
		part({
			Name = "Rock",
			Size = Vector3.new(s, s * 0.8, s),
			CFrame = CFrame.new(pos + Vector3.new(rng:NextNumber(-1, 1), s * 0.3, rng:NextNumber(-1, 1)) * size * 0.3)
				* CFrame.Angles(0, rng:NextNumber(0, math.pi), math.rad(rng:NextNumber(-12, 12))),
			Color = color:Lerp(rgb(0, 0, 0), i * 0.07),
			Material = Enum.Material.Slate,
			CastShadow = false,
			Parent = parent,
		})
	end
end

-- A glowing crystal: a tall thin box, tilted.
function Scenery.crystal(parent, pos, height, color, rng)
	part({
		Name = "Crystal",
		Size = Vector3.new(height * 0.25, height, height * 0.25),
		CFrame = CFrame.new(pos + Vector3.new(0, height * 0.4, 0)) * CFrame.Angles(
			math.rad(rng:NextNumber(-15, 15)),
			rng:NextNumber(0, math.pi),
			math.rad(rng:NextNumber(-15, 15))
		),
		Color = color,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CastShadow = false,
		Parent = parent,
	})
end

-- A glowing ring lying flat (a pad on the floor).
function Scenery.ring(parent, name, center, diameter, color, extra)
	local props = {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, diameter, diameter),
		CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CastShadow = false,
		Parent = parent,
	}
	for k, v in extra or {} do
		props[k] = v
	end
	return part(props)
end

-- A little star far away (a neon ball that never collides).
function Scenery.star(parent, pos, size)
	return ball(parent, "Star", pos, size, rgb(255, 255, 240), Enum.Material.Neon, {
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})
end

-- A far planet in the sky: a big ball with a ring, no collision.
function Scenery.farPlanet(parent, pos, size, color, ringed)
	ball(parent, "FarPlanet", pos, size, color, Enum.Material.SmoothPlastic, {
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})
	if ringed then
		disc(
			parent,
			"FarRing",
			pos,
			size * 1.9,
			size * 0.04,
			color:Lerp(rgb(255, 255, 255), 0.4),
			Enum.Material.SmoothPlastic,
			{ CanCollide = false, CanQuery = false, CastShadow = false }
		)
	end
end

-- A floating sign: big outlined text over a part.
function Scenery.sign(adornee, w, h, offset, lines, maxDistance)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Sign"
	gui.Size = UDim2.new(w, 0, h, 0)
	gui.StudsOffset = offset
	gui.LightInfluence = 0
	gui.MaxDistance = maxDistance or 160
	gui.Parent = adornee
	local out = {}
	for i, l in lines do
		local t = Instance.new("TextLabel")
		t.Name = "Line" .. i
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, 0, l.h, 0)
		t.Position = UDim2.new(0, 0, l.y, 0)
		t.Text = l.text
		t.TextColor3 = l.color or rgb(255, 255, 255)
		t.Font = l.font or Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextStrokeTransparency = 0
		t.TextStrokeColor3 = rgb(27, 29, 43)
		t.Parent = gui
		out[i] = t
	end
	return gui, out
end

Scenery.WALK_SPEED = Constants.WALK_SPEED

return Scenery
