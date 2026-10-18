--[[
The parts the world is made of, ra9's way: matte SmoothPlastic, no textures, detail from geometry (master plan §1).
A Shapes set builds into one folder; Shapes.at(frame) places everything in a frame's own coordinates (a plot's:
local -Z toward the road), so one building stands the same on both sides of the street.

  local s = Shapes.new(folder, frame?)
  s:box(x, y, z, w, h, d, opts)        a box centred at (x, y, z) in the frame
  s:block(x, z, w, d, h, opts, y0)     a box standing on y0 (default the ground)
  s:wedge(x, y, z, w, h, d, opts, yaw) a wedge (a roof slope), turned yaw degrees round Y
  s:cyl(x, y, z, length, diameter, opts, axis)   a cylinder along "x" | "y" | "z"
  s:toon(x, z, w, d, h, opts, y0)      a block with a darker foot band and a lighter cap (the toon look)
  s:sphere(x, y, z, w, h?, d?, opts)   a sphere (canopies, bushes, hills)
  Shapes.shade(color, k)               darker (k < 0) or lighter (k > 0)
  s:world(x, z, y)                     the world spot of a frame spot
  s.parts                              how many parts it has built
  opts: { color, material, name, collide (default true), transparency, shadow, reflect, parent }
  Shapes.deco(opts)                    the same opts marked looks-only (no collision, no queries)
]]
local Shapes = {}
Shapes.__index = Shapes

function Shapes.new(folder, frame)
	return setmetatable({ folder = folder, cf = frame or CFrame.new(), parts = 0 }, Shapes)
end

function Shapes.deco(opts)
	opts = opts or {}
	if opts.collide == nil then
		opts.collide = false
	end
	return opts
end

function Shapes:part(className, cf, size, opts)
	opts = opts or {}
	local p = Instance.new(className)
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Material = opts.material or Enum.Material.SmoothPlastic
	p.Color = opts.color or Color3.fromRGB(240, 240, 236)
	p.Transparency = opts.transparency or 0
	p.CanCollide = opts.collide ~= false
	p.CastShadow = opts.shadow ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Name = opts.name or "Shape"
	if opts.reflect then
		p.Reflectance = opts.reflect
	end
	if not p.CanCollide then
		p.CanQuery = opts.query == true
		p.CanTouch = false
		if opts.shadow == nil and math.max(size.X, size.Y, size.Z) < 3 then
			p.CastShadow = false
		end
	end
	p.Parent = opts.parent or self.folder
	self.parts += 1
	return p
end

function Shapes:box(x, y, z, w, h, d, opts)
	return self:part("Part", self.cf * CFrame.new(x, y, z), Vector3.new(w, h, d), opts)
end

function Shapes:block(x, z, w, d, h, opts, y0)
	return self:box(x, (y0 or 0) + h / 2, z, w, h, d, opts)
end

function Shapes:wedge(x, y, z, w, h, d, opts, yaw)
	return self:part(
		"WedgePart",
		self.cf * CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yaw or 0), 0),
		Vector3.new(w, h, d),
		opts
	)
end

function Shapes:cyl(x, y, z, length, diameter, opts, axis)
	local turn = CFrame.new()
	if axis == "y" then
		turn = CFrame.Angles(0, 0, math.rad(90))
	elseif axis == "z" then
		turn = CFrame.Angles(0, math.rad(90), 0)
	end
	local p = self:part("Part", self.cf * CFrame.new(x, y, z) * turn, Vector3.new(length, diameter, diameter), opts)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- Shades of a colour (the toon look: a darker foot, a lighter cap)
function Shapes.shade(c, k)
	if k < 0 then
		return c:Lerp(Color3.new(0, 0, 0), -k)
	end
	return c:Lerp(Color3.new(1, 1, 1), k)
end

-- A toon block: the box, a darker band round its foot and a lighter cap on top, so it reads as drawn
function Shapes:toon(x, z, w, d, h, opts, y0)
	local box = self:block(x, z, w, d, h, opts, y0)
	local c = opts.color or box.Color
	local name = opts.name or "Shape"
	local foot = math.min(0.7, h * 0.16)
	self:block(
		x,
		z,
		w + 0.3,
		d + 0.3,
		foot,
		Shapes.deco({ color = Shapes.shade(c, -0.28), name = name .. "Foot" }),
		y0 or 0
	)
	self:block(
		x,
		z,
		w + 0.16,
		d + 0.16,
		0.28,
		Shapes.deco({ color = Shapes.shade(c, 0.22), name = name .. "Cap" }),
		(y0 or 0) + h - 0.14
	)
	return box
end

-- A sphere (a tree's canopy, a bush, a round hill)
function Shapes:sphere(x, y, z, w, h, d, opts)
	local p = self:box(x, y, z, w, h or w, d or w, opts)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

function Shapes:world(x, z, y)
	return self.cf * Vector3.new(x, y or 0, z)
end

-- A child set in a sub-frame of this one (a building turned or moved inside the plot)
function Shapes:sub(folder, offset)
	return setmetatable({ folder = folder or self.folder, cf = self.cf * (offset or CFrame.new()), parts = 0 }, Shapes)
end

return Shapes
