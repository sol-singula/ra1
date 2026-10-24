--[[
Part helpers for the shared models (crops, the sunflower, Patch, the capture farmers' props). Every part is
anchored (or welded, for props on a rig), never collides and never takes a click or a raycast, so a crop on a tile
never hides the tile's ClickDetector.

  Kit.part(parent, name, size, cf, color, material?)        a block
  Kit.ball(parent, name, size, cf, color, material?)        an ellipsoid (a block with a Sphere SpecialMesh)
  Kit.cylinder(parent, name, length, diameter, cf, ...)     a cylinder standing along cf's up axis
  Kit.sphere(parent, name, diameter, cf, color, material?)  a true Ball part
  Kit.wedge(parent, name, size, cf, color, material?)       a WedgePart (its slope faces -Z)
  Kit.model(parent, name)
  Kit.weld(part, to)                                        unanchors part and welds it to to
]]
local Kit = {}

local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- a Roblox cylinder runs along X; this stands it up

function Kit.part(parent, name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = 0
	p.Shape = Enum.PartType.Block
	p.Parent = parent
	return p
end

function Kit.ball(parent, name, size, cf, color, material)
	local p = Kit.part(parent, name, size, cf, color, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.Name = "Shape"
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

function Kit.sphere(parent, name, diameter, cf, color, material)
	local p = Kit.part(parent, name, Vector3.new(diameter, diameter, diameter), cf, color, material)
	p.Shape = Enum.PartType.Ball
	return p
end

function Kit.wedge(parent, name, size, cf, color, material)
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = 0
	p.Parent = parent
	return p
end

function Kit.cylinder(parent, name, length, diameter, cf, color, material)
	local p = Kit.part(parent, name, Vector3.new(length, diameter, diameter), cf * UPRIGHT, color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

function Kit.model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

function Kit.weld(part, to)
	part.Anchored = false
	part.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = to
	weld.Part1 = part
	weld.Parent = part
	return weld
end

return Kit
