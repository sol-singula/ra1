--[[
What items look like in the world (master plan §11: loot must stand out from background clutter): the thing in your
hand, and the thing on the ground, which glows in its rarity's colour. Built from plain parts by item class or
kind, so every item in Data/Items has a model without uploading any meshes.

  ItemModels.held(item, parent) -> model, grip     grip: the part to weld to the hand (the handle's end)
  ItemModels.dropped(item, cf, parent) -> model     on the ground, with a rarity glow
]]
local Items = require(script.Parent.Parent.Data.Items)
local Kit = require(script.Parent.Kit)

local ItemModels = {}

local C, M = Kit.C, Kit.M
local V3 = Vector3.new

local METAL = {
	common = C.stone,
	uncommon = C.iron,
	rare = C.steel,
	epic = Color3.fromRGB(150, 110, 230),
	legendary = C.gold,
}

local function headColor(item)
	if item.glow then
		return item.class == "axe" and C.glowcap or C.glowPurple
	end
	return METAL[item.rarity] or C.stone
end

local function p(m, name, cf, size, color, material, shape)
	local part = Kit.box(m, name, cf, size, color, material or M.SmoothPlastic, {
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Massless = true,
		CastShadow = false,
		Anchored = false,
	})
	if shape == "Ball" then
		part.Shape = Enum.PartType.Ball
	elseif shape == "Cylinder" then
		part.Shape = Enum.PartType.Cylinder
	end
	return part
end

-- Every builder draws the item with its handle along -Z from the origin (the grip), "up" along +Y.
local draw = {}

function draw.axe(m, item)
	local grip = p(m, "Handle", CFrame.new(0, 0, -1.4), V3(0.3, 0.3, 3.2), C.woodDark, M.Wood)
	local col = headColor(item)
	p(m, "Head", CFrame.new(0, 0.55, -2.8), V3(0.25, 1.3, 0.9), col, item.glow and M.Neon or M.Metal)
	p(m, "Edge", CFrame.new(0, 1.15, -2.8), V3(0.2, 0.25, 1.1), C.white:Lerp(col, 0.4), M.Metal)
	return grip
end

function draw.club(m, item)
	local grip = p(m, "Handle", CFrame.new(0, 0, -1.3), V3(0.35, 0.35, 3), C.woodDark, M.Wood)
	if item.key == "branch_club" or item.key == "spiked_club" then
		p(m, "Knob", CFrame.new(0, 0, -3.1), V3(0.9, 0.9, 1.6), C.bark, M.Wood)
		if item.key == "spiked_club" then
			for k = 0, 3 do
				local a = k / 4 * math.pi * 2
				p(
					m,
					"Spike",
					CFrame.new(math.cos(a) * 0.5, math.sin(a) * 0.5, -3.1),
					V3(0.15, 0.15, 0.15),
					C.iron,
					M.Metal
				)
			end
		end
	else
		local col = headColor(item)
		p(m, "Head", CFrame.new(0, 0, -3), V3(1.6, 0.9, 0.9), col, item.key == "boulder_maul" and M.Rock or M.Metal)
		if item.rarity == "legendary" then
			p(m, "Band", CFrame.new(0, 0, -3), V3(1.7, 0.95, 0.3), C.jersey, M.Metal)
		end
	end
	return grip
end

function draw.spear(m, item)
	local grip = p(m, "Shaft", CFrame.new(0, 0, -2.2), V3(0.25, 0.25, 6.4), C.woodDark, M.Wood)
	local col = headColor(item)
	p(m, "Tip", CFrame.new(0, 0, -5.8), V3(0.4, 0.15, 1), col, item.key == "obsidian_pike" and M.Glass or M.Metal)
	if item.key == "sharp_stick" then
		m:FindFirstChild("Tip").Color = C.woodLight
	end
	return grip
end

function draw.bow(m, item)
	local col = item.key == "crossbow" and C.woodDark or (item.glow and C.moon or C.wood)
	local grip = p(m, "Grip", CFrame.new(0, 0, 0), V3(0.3, 0.8, 0.3), C.woodDark, M.Wood)
	p(
		m,
		"LimbTop",
		CFrame.new(0, 1.2, 0.25) * CFrame.Angles(math.rad(-14), 0, 0),
		V3(0.2, 1.8, 0.2),
		col,
		item.glow and M.Neon or M.Wood
	)
	p(
		m,
		"LimbBottom",
		CFrame.new(0, -1.2, 0.25) * CFrame.Angles(math.rad(14), 0, 0),
		V3(0.2, 1.8, 0.2),
		col,
		item.glow and M.Neon or M.Wood
	)
	p(m, "String", CFrame.new(0, 0, 0.55), V3(0.05, 4, 0.05), C.cream, M.SmoothPlastic)
	return grip
end

function draw.light(m, item)
	if item.key == "torch" then
		local grip = p(m, "Stick", CFrame.new(0, 0.9, 0), V3(0.3, 2.2, 0.3), C.woodDark, M.Wood)
		local flame = p(m, "Flame", CFrame.new(0, 2.3, 0), V3(0.7, 1, 0.7), C.fire, M.Neon, "Ball")
		local f = Instance.new("Fire")
		f.Size = 2
		f.Heat = 5
		f.Parent = flame
		return grip, flame
	end
	local grip = p(m, "Handle", CFrame.new(0, 1.3, 0), V3(0.15, 0.6, 0.15), C.iron, M.Metal)
	local glass = p(
		m,
		"Glass",
		CFrame.new(0, 0.5, 0),
		V3(0.8, 1, 0.8),
		item.key == "glow_jar" and Color3.fromRGB(190, 255, 140) or C.warm,
		M.Neon
	)
	p(m, "Cap", CFrame.new(0, 1.05, 0), V3(0.9, 0.2, 0.9), C.iron, M.Metal)
	return grip, glass
end

local function blob(m, _item, color, size)
	return p(m, "Item", CFrame.new(0, 0, 0), size or V3(0.9, 0.9, 0.9), color, M.SmoothPlastic, "Ball")
end

local KIND_COLORS = {
	food = C.autumn,
	support = C.white,
	throw = C.red,
	trap = C.iron,
	armor = C.woodLight,
	pack = C.canvasGreen,
	charm = C.gold,
	key = C.gold,
	ammo = C.woodLight,
}
local RESOURCE = {
	wood = { C.bark, V3(0.8, 0.8, 2.2), "Cylinder", M.Wood },
	stone = { C.stone, V3(1.2, 0.9, 1.1), "Ball", M.Rock },
	fiber = { C.fern, V3(0.6, 0.6, 1.6), nil, M.Grass },
	scrap = { C.iron, V3(1, 0.4, 1), nil, M.Metal },
	herb = { C.green, V3(0.8, 0.8, 0.8), "Ball", M.Grass },
	glowcap = { C.glowcap, V3(0.9, 0.6, 0.9), "Ball", M.Neon },
	raw_meat = { C.red, V3(1, 0.6, 0.8), "Ball", M.SmoothPlastic },
}

function draw.other(m, item)
	local r = RESOURCE[item.key]
	if r then
		return p(m, "Item", CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(90), 0), r[2], r[1], r[4], r[3])
	end
	if item.kind == "food" then
		local col = item.key == "berries" and C.flowerBlue
			or item.key == "ice_cream" and C.flowerPink
			or item.key == "honey" and C.yellow
			or item.key == "golden_apple" and C.gold
			or item.key == "stew" and C.autumn
			or C.mushroomBrown
		return blob(m, item, col)
	end
	if item.key == "bandage" then
		return p(m, "Item", CFrame.new(0, 0, 0), V3(0.8, 0.6, 0.6), C.white, M.Fabric, "Cylinder")
	end
	if item.key == "medkit" then
		local box = p(m, "Item", CFrame.new(0, 0, 0), V3(1.2, 0.9, 0.6), C.white, M.SmoothPlastic)
		p(m, "Cross", CFrame.new(0, 0, -0.32), V3(0.6, 0.2, 0.05), C.red, M.SmoothPlastic)
		p(m, "Cross2", CFrame.new(0, 0, -0.32), V3(0.2, 0.6, 0.05), C.red, M.SmoothPlastic)
		return box
	end
	if item.key == "speed_brew" or item.key == "shield_brew" then
		local bottle = p(
			m,
			"Item",
			CFrame.new(0, 0, 0),
			V3(0.7, 0.9, 0.7),
			item.key == "speed_brew" and C.yellow or C.blue,
			M.Glass,
			"Ball"
		)
		p(m, "Neck", CFrame.new(0, 0.6, 0), V3(0.25, 0.4, 0.25), C.white, M.Glass)
		return bottle
	end
	if item.kind == "armor" then
		return p(
			m,
			"Item",
			CFrame.new(0, 0, 0),
			V3(1.6, 1.8, 0.6),
			item.armor >= 0.25 and C.steel or C.woodLight,
			M.Fabric
		)
	end
	if item.kind == "pack" then
		return p(m, "Item", CFrame.new(0, 0, 0), V3(1.4, 1.6, 0.9), C.canvasGreen, M.Fabric)
	end
	if item.kind == "trap" then
		local base = p(m, "Item", CFrame.new(0, 0, 0), V3(1.6, 0.2, 1.6), C.iron, M.Metal, "Cylinder")
		base.CFrame = CFrame.Angles(0, 0, math.rad(90))
		return base
	end
	if item.key == "arrows" then
		local shaft = p(m, "Item", CFrame.new(0, 0, 0), V3(0.12, 0.12, 2.2), C.woodLight, M.Wood)
		p(m, "Fletch", CFrame.new(0, 0, 1), V3(0.4, 0.05, 0.4), C.red, M.Fabric)
		return shaft
	end
	if item.key == "ranger_map" then
		return p(m, "Item", CFrame.new(0, 0, 0), V3(0.5, 0.5, 1.6), C.cream, M.Fabric, "Cylinder")
	end
	if item.key == "strange_idol" then
		return p(m, "Item", CFrame.new(0, 0, 0), V3(0.8, 1.4, 0.8), C.rockMoss, M.Rock)
	end
	return blob(m, item, KIND_COLORS[item.kind] or C.white, V3(0.8, 0.8, 0.8))
end

local function build(item)
	local m = Instance.new("Model")
	m.Name = item.key
	local fn = draw[item.class or ""] or (item.kind == "light" and draw.light) or draw.other
	local grip, glow = fn(m, item)
	-- weld every part to the grip
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d ~= grip then
			local w = Instance.new("WeldConstraint")
			w.Part0 = grip
			w.Part1 = d
			w.Parent = d
		end
	end
	m.PrimaryPart = grip
	if item.light and glow then
		Kit.light(glow, "PointLight", {
			Name = "HeldLight",
			Color = item.key == "glow_jar" and Color3.fromRGB(190, 255, 150) or C.warm,
			Range = item.light.range,
			Brightness = item.light.brightness,
		})
	end
	return m, grip
end

function ItemModels.held(item, parent)
	local m, grip = build(item)
	m.Parent = parent
	return m, grip
end

-- On the ground: lying down, with a soft beam of its rarity's colour (rare and up) so loot reads from afar.
function ItemModels.dropped(item, cf, parent)
	local m, grip = build(item)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	m:PivotTo(cf * CFrame.Angles(0, 0, math.rad(90)))
	local order = Items.RARITY[item.rarity] and Items.RARITY[item.rarity].order or 1
	if order >= 3 then
		local beam = Kit.box(
			m,
			"Beam",
			CFrame.new(cf.Position + V3(0, 6, 0)),
			V3(0.5, 12, 0.5),
			Items.rarityColor(item.rarity),
			M.Neon,
			{ CanCollide = false, CanQuery = false, CastShadow = false, Transparency = 0.55 }
		)
		_ = beam
	end
	Kit.light(grip, "PointLight", {
		Name = "Glow",
		Color = Items.rarityColor(item.rarity),
		Range = 6 + order * 2,
		Brightness = 0.6 + order * 0.25,
	})
	m.Parent = parent
	return m, grip
end

return ItemModels
