--[[
A small layout model of the client's GUIs, enough to check sizes and overlaps without Roblox: absolute rects from
Size, Position and AnchorPoint, ScreenGuis laid out on a virtual canvas of viewport / UIScale (the way a UIScale
on a ScreenGui behaves), UIGridLayout cells, and BillboardGui sizes. UIListLayout positions are not modelled
(sizes are all the tap check needs; overlaps are checked between top-level frames only).

  Layout.canvas(gui, viewport) -> Vector2-like { X, Y }     the virtual canvas a ScreenGui lays out on
  Layout.size(obj, viewport) -> { X, Y } | nil              nil inside a SurfaceGui (sized in studs)
  Layout.rect(obj, viewport) -> { x, y, w, h }              a top-level object's rect on its canvas
  Layout.overlap(a, b) -> boolean
]]
local roblox = require("@lune/roblox")

local Layout = {}

-- unset properties read as Roblox's defaults (the mock errors on a property nobody set)
local function prop(obj, key, default)
	local ok, v = pcall(function()
		return obj[key]
	end)
	if ok and v ~= nil then
		return v
	end
	return default
end
local ZERO2 = roblox.UDim2.new()
local ZEROV = roblox.Vector2.new()
Layout.prop = prop

local function scaleFor(viewport)
	local s = math.min(viewport.X / 1280, viewport.Y / 720)
	return math.clamp(s, 0.55, 1.6)
end

function Layout.canvas(_, viewport)
	local s = scaleFor(viewport)
	return { X = viewport.X / s, Y = viewport.Y / s }
end

local function gridOf(parent)
	for _, c in parent:GetChildren() do
		if c.ClassName == "UIGridLayout" then
			return c
		end
	end
	return nil
end

function Layout.size(obj, viewport)
	local parent = obj.Parent
	if not parent then
		return nil
	end
	if obj.ClassName == "ScreenGui" then
		return Layout.canvas(obj, viewport)
	end
	if obj.ClassName == "BillboardGui" then
		local sz = prop(obj, "Size", ZERO2)
		return { X = sz.X.Offset, Y = sz.Y.Offset }
	end
	if obj.ClassName == "SurfaceGui" or obj.ClassName == "PlayerGui" then
		return nil
	end
	local ps = Layout.size(parent, viewport)
	if not ps then
		return nil
	end
	local grid = gridOf(parent)
	local udim = if grid then prop(grid, "CellSize", ZERO2) else prop(obj, "Size", ZERO2)
	return {
		X = udim.X.Scale * ps.X + udim.X.Offset,
		Y = udim.Y.Scale * ps.Y + udim.Y.Offset,
	}
end

function Layout.rect(obj, viewport)
	local size = Layout.size(obj, viewport)
	local ps = Layout.size(obj.Parent, viewport)
	local anchor = prop(obj, "AnchorPoint", ZEROV)
	local pos = prop(obj, "Position", ZERO2)
	return {
		x = pos.X.Scale * ps.X + pos.X.Offset - anchor.X * size.X,
		y = pos.Y.Scale * ps.Y + pos.Y.Offset - anchor.Y * size.Y,
		w = size.X,
		h = size.Y,
		canvas = ps,
	}
end

function Layout.overlap(a, b)
	return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

return Layout
