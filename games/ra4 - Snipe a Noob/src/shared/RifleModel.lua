-- Builds a rifle out of bricks: stock with a cheek rest, pistol grip, trigger guard, receiver with a bolt handle,
-- handguard, round barrel with a muzzle brake (a silencer on the Ghost, two barrels on the Twin), a folded bipod,
-- a magazine, and a scope with rings, turrets and a lens. Then it's painted: every rifle has its own design
-- (wood, racing stripes, desert camo, arctic camo, tiger) and every skin paints its pattern over the stock and the
-- handguard (camo patches, stripes, tiger stripes, dots, glowing lines, cracks, gems, stars, scales, gold trim).
-- Used for the Tool other players see in your hands (server) and your first-person view model (client).
-- Local space: -Z is forward (the barrel), the origin is the grip. Parts never collide and rays pass through.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Rifles = require(ReplicatedStorage.Shared.Data.Rifles)

local RifleModel = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local DARK = rgb(28, 30, 38)

local MASTERY_LOOK = {
	{ -- gold
		stock = rgb(255, 200, 60),
		body = rgb(255, 210, 80),
		metal = rgb(200, 150, 40),
		accent = rgb(255, 240, 170),
		material = "Foil",
		pattern = "trim",
		colors = { rgb(255, 245, 200), rgb(200, 140, 30) },
	},
	{ -- diamond
		stock = rgb(170, 230, 255),
		body = rgb(190, 235, 255),
		metal = rgb(230, 245, 255),
		accent = rgb(255, 255, 255),
		material = "Glass",
		pattern = "gems",
		colors = { rgb(255, 255, 255), rgb(120, 220, 255) },
		glow = true,
	},
	{ -- rainbow
		stock = rgb(255, 80, 80),
		body = rgb(80, 200, 255),
		metal = rgb(40, 40, 50),
		accent = rgb(255, 230, 80),
		pattern = "stripes",
		colors = { rgb(255, 230, 80), rgb(80, 220, 120) },
		glow = true,
		rainbow = true,
	},
}
RifleModel.MASTERY_NAMES = { "Gold", "Diamond", "Rainbow" }

-- The paint job: a skin wins over a mastery look, which wins over the rifle's own design.
-- Returns { stock, body, metal, accent, material, stockMaterial, pattern, colors, glow, rainbow }.
function RifleModel.look(rifleKey, skinId, masteryTier)
	local rifle = Rifles.byKey[rifleKey] or Rifles.list[1]
	local skin = skinId and Cosmetics.skinById[skinId]
	if skin then
		local fancy = skin.material == "Foil" or skin.material == "Glass"
		return {
			stock = skin.body,
			body = skin.body:Lerp(DARK, 0.18),
			metal = fancy and skin.accent or rifle.look.metal,
			accent = skin.accent,
			material = skin.material,
			stockMaterial = skin.material,
			pattern = skin.pattern or "stripes",
			colors = skin.colors or { skin.accent },
			glow = skin.glow,
			rainbow = skin.rainbow,
		}
	end
	if masteryTier and MASTERY_LOOK[masteryTier] then
		return MASTERY_LOOK[masteryTier]
	end
	return rifle.look
end

local function part(parent, name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material and Enum.Material[material] or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A cylinder along the rifle's length (Roblox cylinders run along X, so turn it to Z).
local function tube(parent, name, d, len, at, color, material)
	return part(
		parent,
		name,
		Vector3.new(len, d, d),
		at * CFrame.Angles(0, math.rad(90), 0),
		color,
		material,
		Enum.PartType.Cylinder
	)
end

-- Patterns --------------------------------------------------------------------------------------------------------
-- Paint a pattern on both sides of a box piece (its CFrame and size), with flat slabs just off its sides.
local function paint(model, piece, look, rng, neonOk)
	local cf, s = piece.CFrame, piece.Size
	local colors = look.colors or { look.accent }
	local pattern = look.pattern
	local hx, hy, hz = s.X / 2, s.Y / 2, s.Z / 2
	local made = 0
	local function slab(side, y, z, sy, sz, color, rot, neon)
		-- clip to the face
		sy = math.min(sy, s.Y)
		sz = math.min(sz, s.Z)
		y = math.clamp(y, -hy + sy / 2, hy - sy / 2)
		z = math.clamp(z, -hz + sz / 2, hz - sz / 2)
		local p = part(
			model,
			"Paint",
			Vector3.new(0.03, sy, sz),
			cf * CFrame.new(side * (hx + 0.016), y, z) * CFrame.Angles(rot or 0, 0, 0),
			color,
			neon and "Neon" or look.material
		)
		made += 1
		return p
	end
	local function band(z, width, color, neon)
		part(
			model,
			"Band",
			Vector3.new(s.X + 0.04, s.Y + 0.04, width),
			cf * CFrame.new(0, 0, z),
			color,
			neon and "Neon" or look.material
		)
		made += 1
	end
	for _, side in { -1, 1 } do
		if pattern == "camo" then
			for i = 1, 6 do
				local w, h = s.Z * rng:NextNumber(0.18, 0.34), s.Y * rng:NextNumber(0.35, 0.7)
				slab(side, rng:NextNumber(-hy, hy), rng:NextNumber(-hz, hz), h, w, colors[(i - 1) % #colors + 1])
			end
		elseif pattern == "tiger" or pattern == "candy" then
			local n = math.max(3, math.floor(s.Z / 0.35))
			for i = 1, n do
				local z = -hz + (i - 0.5) * (s.Z / n)
				slab(
					side,
					0,
					z,
					s.Y * 1.3,
					0.09,
					colors[1],
					math.rad(pattern == "candy" and 35 or (i % 2 == 0 and 22 or -18))
				)
			end
		elseif pattern == "dots" or pattern == "scales" then
			local rows, cols = 2, math.max(3, math.floor(s.Z / 0.3))
			for r = 1, rows do
				for c = 1, cols do
					local off = (pattern == "scales" and r % 2 == 0) and 0.5 or 0
					local z = -hz + (c - 0.5 + off) * (s.Z / cols)
					local y = -hy + r * (s.Y / (rows + 1))
					slab(side, y, z, 0.1, 0.1, colors[(r + c) % #colors + 1])
				end
			end
		elseif pattern == "neon" then
			slab(side, 0, 0, 0.07, s.Z * 0.9, colors[1], 0, neonOk)
			slab(side, -hy * 0.55, 0, 0.05, s.Z * 0.6, colors[2] or colors[1], 0, neonOk)
		elseif pattern == "cracks" then
			for i = 1, 4 do
				local z = -hz + (i - 0.5) * (s.Z / 4)
				slab(
					side,
					rng:NextNumber(-hy * 0.4, hy * 0.4),
					z,
					0.06,
					s.Z / 4 * 1.1,
					colors[1],
					math.rad(rng:NextNumber(-35, 35)),
					neonOk
				)
			end
		elseif pattern == "gems" or pattern == "stars" then
			for i = 1, 5 do
				local p = slab(
					side,
					rng:NextNumber(-hy * 0.6, hy * 0.6),
					rng:NextNumber(-hz * 0.85, hz * 0.85),
					pattern == "gems" and 0.16 or 0.07,
					pattern == "gems" and 0.16 or 0.07,
					colors[(i - 1) % #colors + 1],
					math.rad(45),
					pattern == "stars" and neonOk
				)
				if pattern == "gems" then
					p.Material = Enum.Material.Glass
				end
			end
		elseif pattern == "trim" then
			slab(side, hy - 0.05, 0, 0.06, s.Z * 0.95, colors[1])
			slab(side, -hy + 0.05, 0, 0.06, s.Z * 0.95, colors[1])
		elseif pattern == "wood" then
			for i = 1, 3 do
				slab(
					side,
					-hy + i * (s.Y / 4),
					rng:NextNumber(-0.1, 0.1),
					0.025,
					s.Z * rng:NextNumber(0.5, 0.85),
					colors[1]
				)
			end
		end
	end
	if pattern == "stripes" or pattern == "candy" or pattern == "trim" then
		local n = pattern == "stripes" and 3 or 2
		for i = 1, n do
			band(-hz + i * (s.Z / (n + 1)), 0.1, colors[(i - 1) % #colors + 1])
		end
	end
	return made
end

-- Build -------------------------------------------------------------------------------------------------------------
-- Returns a Model whose PrimaryPart is "Handle" (the grip), every other part welded to it, and a "Muzzle"
-- attachment at the end of the barrel. at: where to build it.
function RifleModel.build(rifleKey, skinId, masteryTier, at)
	local rifle = Rifles.byKey[rifleKey] or Rifles.list[1]
	local look = RifleModel.look(rifleKey, skinId, masteryTier)
	at = at or CFrame.new()
	local model = Instance.new("Model")
	model.Name = "Rifle_" .. rifle.key
	local stockColor, body, metal, accent = look.stock, look.body, look.metal, look.accent
	local mat, stockMat = look.material, look.stockMaterial or look.material
	local L = rifle.barrel
	local scopeLen = rifle.key == "EAGLE" and 2.1 or (rifle.key == "SWIFT" and 1.3 or 1.7)
	local scopeD = rifle.key == "EAGLE" and 0.42 or 0.36

	local handle = part(
		model,
		"Handle",
		Vector3.new(0.38, 0.85, 0.5),
		at * CFrame.new(0, -0.4, 0.15) * CFrame.Angles(math.rad(-15), 0, 0),
		stockColor,
		stockMat
	)
	model.PrimaryPart = handle
	local pieces = {}
	local function add(p)
		table.insert(pieces, p)
		return p
	end
	local function at2(x, y, z)
		return at * CFrame.new(x, y, z)
	end
	-- receiver and action
	local receiver = add(part(model, "Receiver", Vector3.new(0.55, 0.62, 2.0), at2(0, 0.12, -0.45), body, mat))
	add(part(model, "Port", Vector3.new(0.06, 0.22, 0.7), at2(0.28, 0.2, -0.4), DARK))
	add(
		part(
			model,
			"BoltStem",
			Vector3.new(0.5, 0.12, 0.12),
			at2(0.42, 0.22, 0.05),
			metal,
			"Metal",
			Enum.PartType.Cylinder
		)
	)
	add(
		part(model, "BoltKnob", Vector3.new(0.24, 0.24, 0.24), at2(0.7, 0.18, 0.05), metal, "Metal", Enum.PartType.Ball)
	)
	add(part(model, "GuardBottom", Vector3.new(0.12, 0.08, 0.7), at2(0, -0.32, -0.25), metal, "Metal"))
	add(part(model, "GuardFront", Vector3.new(0.12, 0.35, 0.08), at2(0, -0.15, -0.6), metal, "Metal"))
	add(part(model, "Trigger", Vector3.new(0.08, 0.25, 0.08), at2(0, -0.2, -0.2), DARK))
	-- stock
	local stock = add(part(model, "Stock", Vector3.new(0.5, 0.62, 1.5), at2(0, -0.02, 1.1), stockColor, stockMat))
	add(part(model, "Cheek", Vector3.new(0.46, 0.22, 0.95), at2(0, 0.38, 1.15), stockColor, stockMat))
	add(part(model, "StockLow", Vector3.new(0.46, 0.45, 0.9), at2(0, -0.42, 1.5), stockColor, stockMat))
	add(part(model, "Butt", Vector3.new(0.54, 1.15, 0.18), at2(0, -0.15, 1.95), DARK))
	-- handguard, barrel, muzzle
	local hgLen = L * 0.55
	local handguard =
		add(part(model, "Handguard", Vector3.new(0.5, 0.5, hgLen), at2(0, 0.05, -1.45 - hgLen / 2), body, mat))
	add(tube(model, "Barrel", 0.22, L, at2(0, 0.18, -1.45 - L / 2), metal, "Metal"))
	local tipZ = -1.45 - L
	if rifle.silencer then
		add(tube(model, "Silencer", 0.42, 1.4, at2(0, 0.18, tipZ - 0.55), DARK, "Metal"))
		add(tube(model, "SilencerRing", 0.46, 0.12, at2(0, 0.18, tipZ - 0.05), accent, mat))
		tipZ -= 1.25
	else
		add(part(model, "Brake", Vector3.new(0.34, 0.3, 0.5), at2(0, 0.18, tipZ - 0.2), metal, "Metal"))
		for _, dz in { -0.08, 0.1 } do
			add(part(model, "Slot", Vector3.new(0.36, 0.06, 0.08), at2(0, 0.18, tipZ - 0.2 + dz), DARK))
		end
		tipZ -= 0.45
	end
	if rifle.shots > 1 then
		add(tube(model, "Barrel2", 0.2, L * 0.92, at2(0, -0.1, -1.45 - L * 0.46), metal, "Metal"))
	end
	-- folded bipod and the magazine
	for _, x in { -0.16, 0.16 } do
		add(part(model, "Bipod", Vector3.new(0.08, 0.08, 1.0), at2(x, -0.25, -1.45 - hgLen * 0.6), metal, "Metal"))
	end
	add(part(model, "Mag", Vector3.new(0.32, 0.55, 0.55), at2(0, -0.38, -0.75), accent, mat))
	-- the scope
	local sy, sz = 0.72, -0.55
	add(tube(model, "Scope", scopeD, scopeLen, at2(0, sy, sz), accent, mat))
	add(tube(model, "ScopeBell", scopeD + 0.2, 0.45, at2(0, sy, sz - scopeLen / 2 - 0.1), body, mat))
	add(tube(model, "Eyepiece", scopeD + 0.1, 0.3, at2(0, sy, sz + scopeLen / 2 + 0.05), body, mat))
	for _, dz in { -scopeLen * 0.3, scopeLen * 0.25 } do
		add(part(model, "Ring", Vector3.new(scopeD + 0.08, scopeD + 0.08, 0.14), at2(0, sy, sz + dz), metal, "Metal"))
		add(part(model, "Mount", Vector3.new(0.16, 0.3, 0.14), at2(0, 0.45, sz + dz), metal, "Metal"))
	end
	add(
		part(
			model,
			"TurretTop",
			Vector3.new(0.2, 0.2, 0.2),
			at2(0, sy + scopeD / 2 + 0.08, sz),
			metal,
			"Metal",
			Enum.PartType.Cylinder
		)
	)
	add(
		part(
			model,
			"TurretSide",
			Vector3.new(0.2, 0.2, 0.2),
			at2(scopeD / 2 + 0.08, sy, sz),
			metal,
			"Metal",
			Enum.PartType.Cylinder
		)
	)
	local lens = tube(model, "Lens", scopeD + 0.12, 0.05, at2(0, sy, sz - scopeLen / 2 - 0.34), accent, "Glass")
	if look.glow then
		lens.Material = Enum.Material.Neon
	end
	add(lens)
	-- the paint job
	local seed = #rifle.key * 97
	for i = 1, #(skinId or "") do
		seed += string.byte(skinId, i) * i
	end
	local rng = Random.new(seed + (masteryTier or 0) * 13)
	local before = #model:GetChildren()
	paint(model, stock, look, rng, true)
	paint(model, handguard, look, rng, true)
	if look.pattern == "neon" or look.pattern == "trim" then
		paint(model, receiver, { pattern = "trim", colors = look.colors, material = look.material }, rng, true)
	end
	for i, p in model:GetChildren() do
		if i > before and p:IsA("BasePart") then
			table.insert(pieces, p)
		end
	end
	if look.glow then
		for _, p in pieces do
			if p.Name == "Scope" or p.Name == "Mag" then
				p.Material = Enum.Material.Neon
			end
		end
	end
	for _, p in pieces do
		if p ~= handle then
			local w = Instance.new("WeldConstraint")
			w.Part0 = handle
			w.Part1 = p
			w.Parent = p
		end
	end
	if look.rainbow then
		model:SetAttribute("Rainbow", true) -- the client cycles its colours
	end
	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = handle.CFrame:PointToObjectSpace((at * CFrame.new(0, 0.18, tipZ)).Position)
	muzzle.Parent = handle
	return model
end

-- The Tool other players see you holding. Roblox's own animation raises the arm for a held tool.
function RifleModel.tool(rifleKey, skinId, masteryTier)
	local model = RifleModel.build(rifleKey, skinId, masteryTier)
	local tool = Instance.new("Tool")
	tool.Name = "Rifle"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ManualActivationOnly = true
	-- no turn: the barrel (the Handle's -Z) points out along the raised arm, the scope on top
	tool.Grip = CFrame.new(0, -0.15, 0)
	tool:SetAttribute("Rifle", rifleKey)
	tool:SetAttribute("Skin", skinId or "")
	for _, child in model:GetChildren() do
		child.Parent = tool
	end
	model:Destroy()
	return tool
end

return RifleModel
