-- Draws a cabin's items (Data/CabinItems) into its compartment: the server builds the real ones (everyone sees
-- them), the client builds a see-through "ghost" of your next upgrade in your own cabin. Every item has its own slot,
-- in the cabin's local frame: +Z is the window wall, -Z the door wall, +X the right wall (looking at the window).
--
--   CabinBuilder.item(parent, cabinCf, key, opts)   build one item; opts = { variant, color, ghost }
--   CabinBuilder.applyFinish(cabin, variant)         recolour the shell (floor and walls) for an interior finish
--   CabinBuilder.applyColor(cabin, color)            the cabin colour on curtains, door sign and bedding
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(ReplicatedStorage.Shared.World.Kit)

local CabinBuilder = {}

local C, M = Kit.C, Kit.M

-- Interior finishes: floor and wall colour/material (the bare cabin is "bare").
CabinBuilder.FINISHES = {
	bare = { floor = Kit.rgb(104, 88, 72), floorMat = M.WoodPlanks, wall = Kit.rgb(146, 136, 118), wallMat = M.SmoothPlastic },
	oak = { floor = Kit.rgb(150, 100, 60), floorMat = M.WoodPlanks, wall = Kit.rgb(168, 116, 70), wallMat = M.Wood },
	forest = { floor = Kit.rgb(88, 60, 40), floorMat = M.WoodPlanks, wall = Kit.rgb(52, 92, 66), wallMat = M.SmoothPlastic },
	midnight = { floor = Kit.rgb(58, 50, 60), floorMat = M.WoodPlanks, wall = Kit.rgb(38, 52, 92), wallMat = M.SmoothPlastic },
	rose = { floor = Kit.rgb(168, 128, 98), floorMat = M.WoodPlanks, wall = Kit.rgb(178, 124, 124), wallMat = M.SmoothPlastic },
}

function CabinBuilder.applyFinish(cabin, variant)
	local f = CabinBuilder.FINISHES[variant or "bare"] or CabinBuilder.FINISHES.bare
	for _, p in cabin.shell do
		if p:GetAttribute("Role") == "floor" then
			p.Color, p.Material = f.floor, f.floorMat
		else
			p.Color, p.Material = f.wall, f.wallMat
		end
	end
end

function CabinBuilder.applyColor(cabin, color)
	for _, p in cabin.color do
		if p.Name == "DoorPlate" then
			p.Color = color and color:Lerp(C.black, 0.45) or C.greenDark
		else
			p.Color = color or C.cream
		end
	end
end

-- Part helper in the cabin frame; ghosts are see-through, glowing and can't be touched.
local function maker(parent, cf, ghost)
	local function finish(p)
		if ghost then
			p.Transparency = math.max(p.Transparency, 0.62)
			p.Material = M.SmoothPlastic
			p.Color = Kit.rgb(150, 220, 255)
			p.CanCollide = false
			p.CanQuery = false
			p.CastShadow = false
			for _, l in p:GetChildren() do
				if l:IsA("Light") then
					l:Destroy()
				end
			end
		end
		return p
	end
	local b = {}
	function b.box(name, lx, ly, lz, sx, sy, sz, color, material, extra)
		return finish(Kit.box(parent, name, cf * CFrame.new(lx, ly, lz), Vector3.new(sx, sy, sz), color, material, extra))
	end
	function b.cf(name, lcf, size, color, material, extra)
		return finish(Kit.box(parent, name, cf * lcf, size, color, material, extra))
	end
	function b.cyl(name, lcf, length, d, color, material, extra)
		return finish(Kit.cyl(parent, name, cf * lcf, length, d, color, material, extra))
	end
	function b.ball(name, lx, ly, lz, d, color, material, extra)
		return finish(Kit.ball(parent, name, (cf * CFrame.new(lx, ly, lz)).Position, d, color, material, extra))
	end
	function b.disc(name, lx, ly, lz, d, h, color, material, extra)
		return finish(Kit.disc(parent, name, (cf * CFrame.new(lx, ly, lz)).Position, d, h, color, material, extra))
	end
	function b.light(part, range, brightness, color)
		if not ghost then
			Kit.light(part, "PointLight", { Range = range, Brightness = brightness, Color = color or C.warm })
		end
	end
	return b
end

local SPECIALIST = {}

function SPECIALIST.mechanic(b)
	b.box("Vise", 4.7, 3.2, -1.4, 1, 1, 1.2, C.steel, M.Metal)
	b.cyl("EnginePart", CFrame.new(5.1, 3.3, 0.6), 1.6, 1.3, C.iron, M.Metal)
	b.box("Toolbox", 5.1, 3.15, 1.9, 1.2, 0.9, 1.6, C.wheel, M.Metal)
	b.cyl("Gear", CFrame.new(4.8, 3.4, -0.2) * CFrame.Angles(0, 0, math.rad(90)), 0.25, 1.4, C.brass, M.Metal)
end

function SPECIALIST.explorer(b)
	b.disc("GlobeStand", 5.1, 3, -1.2, 0.8, 0.5, C.brassDark, M.Metal)
	b.ball("Globe", 5.1, 3.9, -1.2, 1.5, Kit.rgb(70, 120, 170), M.SmoothPlastic)
	for i = 0, 2 do
		b.cyl("Map", CFrame.new(5.0, 2.9 + i * 0.25, 1 + i * 0.3) * CFrame.Angles(0, math.rad(90), 0), 2.2, 0.35, Kit.rgb(222, 206, 160), M.SmoothPlastic)
	end
	b.disc("Compass", 4.8, 2.85, 0.1, 0.9, 0.12, C.brass, M.Metal)
end

function SPECIALIST.botanist(b)
	for i = -1, 1 do
		b.disc("Pot", 5.1, 3.1, i * 1.5, 0.9, 0.8, C.rust, M.SmoothPlastic)
		b.ball("Sprout", 5.1, 3.9, i * 1.5, 1, C.leaf:Lerp(C.moss, (i + 1) / 3), M.Grass)
	end
	local lamp = b.box("GrowLamp", 5.6, 6.2, 0, 0.4, 0.3, 4, Kit.rgb(220, 160, 255), M.Neon)
	b.light(lamp, 10, 1, Kit.rgb(220, 170, 255))
end

-- Build one item. Returns the folder it made.
function CabinBuilder.item(parent, cabinCf, key, opts)
	opts = opts or {}
	local folder = Kit.model(key, parent)
	folder:SetAttribute("Item", key)
	local b = maker(folder, cabinCf, opts.ghost)
	local color = opts.color or C.cream

	if key == "bunk" then
		b.box("BedFrame", 2.3, 0.8, 6.3, 8.3, 1.2, 4, C.woodDark, M.Wood)
		b.box("Mattress", 2.3, 1.65, 6.3, 7.9, 0.6, 3.7, C.cream, M.Fabric)
		b.box("Blanket", 1.6, 2.0, 6.3, 5.4, 0.2, 3.8, color, M.Fabric)
		b.box("Pillow", 5.2, 2.15, 6.3, 1.5, 0.5, 2.8, C.white, M.Fabric)
		b.box("Headboard", 6.3, 2.6, 6.3, 0.4, 3.6, 4.2, C.wood, M.Wood)
		b.box("Footboard", -1.75, 1.8, 6.3, 0.4, 2.2, 4.2, C.wood, M.Wood)
	elseif key == "lamp" then
		b.box("LampBracket", 6.45, 6.4, 6.6, 0.6, 0.25, 0.25, C.brass, M.Metal)
		b.disc("LampShade", 6.0, 6.3, 6.6, 1.3, 0.9, color:Lerp(C.cream, 0.5), M.Fabric)
		local bulb = b.ball("LampBulb", 6.0, 5.9, 6.6, 0.6, C.warm, M.Neon, { CastShadow = false })
		b.light(bulb, 14, 1.6)
	elseif key == "crate" then
		b.box("Crate", -5.1, 1.2, -7.3, 2.6, 2.4, 2.4, C.woodLight, M.WoodPlanks)
		b.box("CrateBand", -5.1, 0.35, -7.3, 2.7, 0.3, 2.5, C.woodDark, M.Wood, { CastShadow = false })
		b.box("CrateBand", -5.1, 2.05, -7.3, 2.7, 0.3, 2.5, C.woodDark, M.Wood, { CastShadow = false })
		b.box("CrateLid", -5.1, 2.5, -7.3, 2.8, 0.2, 2.6, C.wood, M.Wood)
	elseif key == "bench" then
		b.box("BenchBase", -5.3, 1, -1, 2.2, 2, 7, C.wood, M.Wood)
		b.box("Cushion", -5.25, 2.2, -1, 2, 0.4, 6.6, color, M.Fabric)
		b.box("Backrest", -6.2, 3.7, -1, 0.4, 2.6, 6.6, color:Lerp(C.black, 0.15), M.Fabric)
	elseif key == "worksurface" then
		b.box("Tabletop", 5.2, 2.6, 0, 2.6, 0.3, 5, C.woodLight, M.WoodPlanks)
		b.box("TableBrace", 6.0, 1.3, -2.2, 0.3, 2.5, 0.3, C.woodDark, M.Wood, { CastShadow = false })
		b.box("TableBrace", 6.0, 1.3, 2.2, 0.3, 2.5, 0.3, C.woodDark, M.Wood, { CastShadow = false })
		b.box("Jar", 5.0, 3.1, 1.6, 0.6, 0.7, 0.6, C.glass, M.Glass, { Transparency = 0.3 })
	elseif key == "workbench" then
		b.box("BenchBody", 4.9, 1.3, -6.0, 3, 2.6, 5, C.woodDark, M.Wood)
		b.box("BenchTop", 4.9, 2.75, -6.0, 3.2, 0.3, 5.2, C.wood, M.WoodPlanks)
		b.box("Vise", 3.8, 3.25, -7.6, 0.8, 0.7, 1, C.steel, M.Metal)
		b.box("Hammer", 5.0, 3.0, -5.6, 0.25, 0.2, 1.4, C.iron, M.Metal, { CastShadow = false })
		b.box("Drawer", 3.38, 1.6, -6.0, 0.1, 0.8, 2, C.brass, M.Metal, { CastShadow = false })
	elseif key == "insulation" then
		local quilt = C.cream:Lerp(color, 0.15)
		b.box("Quilt", -6.42, 2.4, 0, 0.15, 4, 16, quilt, M.Fabric)
		b.box("Quilt", 6.42, 2.4, 2, 0.15, 4, 12, quilt, M.Fabric)
		b.box("Quilt", 0, 2.35, 8.3, 12.6, 4.2, 0.15, quilt, M.Fabric)
		for i = -3, 3 do
			b.box("QuiltSeam", -6.35, 2.4, i * 2.2, 0.12, 4, 0.1, quilt:Lerp(C.black, 0.2), M.Fabric, { CastShadow = false })
		end
	elseif key == "shelf" then
		b.box("ShelfPlank", -6.05, 6.2, -1, 0.9, 0.2, 5, C.wood, M.Wood)
		b.box("ShelfBracket", -6.4, 5.8, -3, 0.4, 0.6, 0.2, C.brass, M.Metal, { CastShadow = false })
		b.box("ShelfBracket", -6.4, 5.8, 1, 0.4, 0.6, 0.2, C.brass, M.Metal, { CastShadow = false })
	elseif key == "ceiling" then
		b.box("ChandelierRod", 0, 12.2, 0, 0.2, 1.6, 0.2, C.brass, M.Metal, { CastShadow = false })
		b.disc("ChandelierRing", 0, 11.3, 0, 3, 0.25, C.brass, M.Metal, { CastShadow = false })
		for i = 0, 2 do
			local a = i * math.pi * 2 / 3
			local bulb = b.ball("ChandelierBulb", math.cos(a) * 1.3, 10.9, math.sin(a) * 1.3, 0.55, C.warm, M.Neon, { CastShadow = false })
			if i == 0 then
				b.light(bulb, 24, 1.5)
			end
		end
	elseif key == "mapboard" then
		b.box("MapBoard", 4.4, 6.4, -8.42, 4.5, 3.2, 0.2, Kit.rgb(176, 136, 96), M.SmoothPlastic)
		b.box("MapFrame", 4.4, 6.4, -8.5, 4.9, 3.6, 0.1, C.woodDark, M.Wood, { CastShadow = false })
		for i, p in { { 3.2, 7.2 }, { 4.6, 6.1 }, { 5.6, 7.0 }, { 3.9, 5.6 } } do
			b.ball("MapPin", p[1], p[2], -8.3, 0.25, i % 2 == 0 and C.red or C.blueprint, M.Neon, { CastShadow = false })
		end
	elseif key == "toolrack" then
		b.box("Pegboard", 6.45, 6.2, -6.2, 0.2, 2.6, 4.4, C.woodLight, M.WoodPlanks)
		for i = -2, 2 do
			b.box("RackTool", 6.3, 6.2, -6.2 + i * 0.85, 0.15, 1.8, 0.22, i % 2 == 0 and C.steel or C.wheel, M.Metal, { CastShadow = false })
		end
	elseif key == "locker" then
		b.box("Locker", -5.55, 3.5, 6.85, 1.8, 7, 3, Kit.rgb(70, 96, 78), M.Metal)
		b.box("LockerDoorLine", -4.63, 3.5, 6.85, 0.05, 6.6, 0.1, C.iron, M.Metal, { CastShadow = false })
		b.box("LockerHandle", -4.6, 3.8, 6.15, 0.15, 0.8, 0.15, C.brass, M.Metal, { CastShadow = false })
		for i = 0, 2 do
			b.box("LockerVent", -4.62, 6.2 - i * 0.3, 6.85, 0.05, 0.1, 1.8, C.iron, M.Metal, { CastShadow = false })
		end
	elseif key == "comfort" then
		b.box("Rug", 0, 0.2, 0.5, 6, 0.06, 7, color:Lerp(C.cream, 0.35), M.Carpet, { CastShadow = false })
		b.box("RugBorder", 0, 0.19, 0.5, 6.6, 0.05, 7.6, color:Lerp(C.black, 0.3), M.Carpet, { CastShadow = false })
		b.disc("PlantPot", -5.6, 0.8, 4.0, 1.4, 1.6, C.rust, M.SmoothPlastic)
		b.ball("Plant", -5.6, 2.4, 4.0, 2, C.leaf, M.Grass)
		b.ball("Plant", -5.3, 3.1, 4.2, 1.3, C.moss, M.Grass)
	elseif key == "specialist" then
		local fn = SPECIALIST[opts.variant or "mechanic"] or SPECIALIST.mechanic
		fn(b)
	end
	return folder
end

-- The little souvenirs on the display shelf: one model per stop visited (up to 4 kinds).
local SOUVENIRS = {
	ranger = function(b, x)
		b.box("SouvenirLantern", -6.0, 6.7, x, 0.5, 0.7, 0.5, C.iron, M.Metal)
		b.ball("SouvenirGlow", -6.0, 6.7, x, 0.3, C.warm, M.Neon, { CastShadow = false })
	end,
	timber = function(b, x)
		b.cyl("SouvenirLog", CFrame.new(-6.0, 6.55, x) * CFrame.Angles(0, math.rad(90), 0), 0.9, 0.5, C.bark, M.Wood)
	end,
	signal = function(b, x)
		b.box("SouvenirSignal", -6.0, 6.85, x, 0.25, 1.1, 0.25, C.white, M.SmoothPlastic)
		b.ball("SouvenirRed", -6.0, 7.45, x, 0.3, C.signal, M.Neon, { CastShadow = false })
	end,
	platform = function(b, x)
		b.disc("SouvenirPot", -6.0, 6.5, x, 0.5, 0.4, C.concrete, M.SmoothPlastic)
		b.ball("SouvenirVine", -6.0, 6.85, x, 0.5, C.moss, M.Grass)
	end,
}

function CabinBuilder.souvenirs(parent, cabinCf, souvenirs)
	local folder = Kit.model("Souvenirs", parent)
	local b = maker(folder, cabinCf, false)
	local x = -3
	for _, key in { "ranger", "timber", "signal", "platform" } do
		if souvenirs and (souvenirs[key] or 0) > 0 then
			SOUVENIRS[key](b, x)
			x += 1.3
		end
	end
	return folder
end

return CabinBuilder
