--[[
Pictures of items and raft pieces for the UI (master plan §4: readable): a little 3D view of the item's own model
(World/ItemModels) or the piece (World/RaftModels) in a ViewportFrame, lit from the top left, so every icon is the
thing you hold and build. When an item has uploaded 2D art (Data/IconIds, filled in by tools/icons/upload_icons.py)
that image is used instead.

  Icons.item(parent, key, opts)    -> the ImageLabel or ViewportFrame, filling its parent (opts.inset px)
  Icons.piece(parent, key, opts)
  Icons.clear(parent)              removes an icon made here
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IconIds = require(ReplicatedStorage.Shared.Data.IconIds)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local ItemModels = require(ReplicatedStorage.Shared.World.ItemModels)
local RaftModels = require(ReplicatedStorage.Shared.World.RaftModels)

local Icons = {}

local NAME = "Icon3D"
local ITEM_DIR = Vector3.new(0.18, 0.42, 1).Unit
local PIECE_DIR = Vector3.new(0.75, 0.7, 1).Unit

-- The box round every part of the model, turned the way it is (the 8 corners of each part).
local function bounds(model)
	local lo, hi
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			local cf, s = d.CFrame, d.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local c = cf:PointToWorldSpace(Vector3.new(sx * s.X, sy * s.Y, sz * s.Z))
						lo = lo and Vector3.new(math.min(lo.X, c.X), math.min(lo.Y, c.Y), math.min(lo.Z, c.Z)) or c
						hi = hi and Vector3.new(math.max(hi.X, c.X), math.max(hi.Y, c.Y), math.max(hi.Z, c.Z)) or c
					end
				end
			end
		end
	end
	if not lo then
		return Vector3.zero, Vector3.new(1, 1, 1)
	end
	return (lo + hi) / 2, hi - lo
end

local function viewport(parent, opts)
	local inset = opts and opts.inset or 3
	local vp = Instance.new("ViewportFrame")
	vp.Name = NAME
	vp.BackgroundTransparency = 1
	vp.BorderSizePixel = 0
	vp.Position = UDim2.fromOffset(inset, inset)
	vp.Size = UDim2.new(1, -inset * 2, 1, -inset * 2)
	vp.ZIndex = opts and opts.zIndex or 1
	vp.Ambient = Color3.fromRGB(150, 150, 172)
	vp.LightColor = Color3.fromRGB(255, 250, 236)
	vp.LightDirection = Vector3.new(-0.6, -1, -0.5)
	local cam = Instance.new("Camera")
	cam.FieldOfView = 28
	cam.Parent = vp
	vp.CurrentCamera = cam
	vp.Parent = parent
	return vp, cam
end

-- Frame the model: the camera looks at its middle from `dir`, far enough back to see all of it.
local function frame(cam, model, dir, pad)
	local center, size = bounds(model)
	local radius = math.max(0.6, size.Magnitude / 2)
	local dist = radius / math.tan(math.rad(14)) * (pad or 1.05)
	cam.CFrame = CFrame.lookAt(center + dir * dist, center)
end

local function image(parent, id, opts)
	local inset = opts and opts.inset or 2
	local img = Instance.new("ImageLabel")
	img.Name = NAME
	img.BackgroundTransparency = 1
	img.BorderSizePixel = 0
	img.Image = "rbxassetid://" .. tostring(id)
	img.ScaleType = Enum.ScaleType.Fit
	img.Position = UDim2.fromOffset(inset, inset)
	img.Size = UDim2.new(1, -inset * 2, 1, -inset * 2)
	img.ZIndex = opts and opts.zIndex or 1
	img.Parent = parent
	return img
end

function Icons.clear(parent)
	local old = parent:FindFirstChild(NAME)
	while old do
		old:Destroy()
		old = parent:FindFirstChild(NAME)
	end
end

function Icons.item(parent, key, opts)
	Icons.clear(parent)
	local item = Items.get(key)
	if not item then
		return nil
	end
	local id = IconIds[key]
	if type(id) == "number" and id > 0 then
		return image(parent, id, opts)
	end
	local vp, cam = viewport(parent, opts)
	local ok, model = pcall(ItemModels.icon, item, vp)
	if not ok or not model then
		vp:Destroy()
		return nil
	end
	-- the item lies along -Z: turn it to run along +X and tilt the business end up and to the right
	local tilt = (opts and opts.tilt) or 32
	model:PivotTo(CFrame.Angles(0, 0, math.rad(tilt)) * CFrame.Angles(0, -math.pi / 2, 0))
	frame(cam, model, ITEM_DIR, opts and opts.pad)
	return vp
end

function Icons.piece(parent, key, opts)
	Icons.clear(parent)
	local vp, cam = viewport(parent, opts)
	local ok, model = pcall(RaftModels.build, key, CFrame.new(), { colours = opts and opts.colours }, vp)
	if not ok or not model then
		vp:Destroy()
		return nil
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	frame(cam, model, PIECE_DIR, opts and opts.pad or 1.1)
	return vp
end

return Icons
