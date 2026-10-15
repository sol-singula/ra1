--[[
What items look like in the hand (and floating in the water when dropped). Built from plain parts by item kind, so
every item has a model without uploading meshes.

  ItemModels.held(item, parent) -> model, grip     grip: an invisible part where the hand closes round it
  ItemModels.holdCFrame(item, hand) -> CFrame       the weld's C0 from the hand to the grip
How things sit in the hand (Roblox's hand frame: -Y comes out of the bottom of the fist, -Z is the back of the
fingers; in the hold pose, with the forearm level in front of you, -Y points ahead and -Z points up): hooks and rods
are held by the handle, pointing ahead; axes, picks and hammers stand up out of the fist, the head forward; spears
point ahead; lanterns hang.
]]
local Items = require(script.Parent.Parent.Data.Items)
local Kit = require(script.Parent.Kit)

local ItemModels = {}

local C, M = Kit.C, Kit.M
local V3 = Vector3.new

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

local RARITY_METAL = {
	common = C.iron,
	uncommon = C.steel,
	rare = C.steel:Lerp(C.blueprint, 0.3),
	epic = Color3.fromRGB(150, 110, 230),
	legendary = C.gold,
}

-- Every builder draws the item along -Z from the origin (the grip), "up" along +Y.
local draw = {}

function draw.hook(m, item)
	local col = RARITY_METAL[item.rarity] or C.iron
	p(m, "Handle", CFrame.new(0, 0, -0.8), V3(0.3, 0.3, 1.8), C.woodDark, M.Wood)
	p(m, "Line", CFrame.new(0, 0.1, -2.4), V3(0.08, 0.08, 1.6), C.rope, M.Fabric)
	p(m, "Hook", CFrame.new(0, 0.3, -3.3), V3(0.2, 0.8, 0.2), col, M.Metal)
	p(m, "Barb", CFrame.new(0, 0.7, -3.1), V3(0.2, 0.2, 0.6), col, M.Metal)
	return V3(0, 0, -0.4)
end

function draw.rod(m, item)
	p(m, "Rod", CFrame.new(0, 0, -2.6), V3(0.18, 0.18, 5.6), item.rarity == "rare" and C.steel or C.wood, M.Wood)
	p(m, "Reel", CFrame.new(0, -0.35, -0.9), V3(0.5, 0.5, 0.3), C.iron, M.Metal, "Cylinder")
	p(m, "Line", CFrame.new(0, -0.6, -5.3), V3(0.05, 1.2, 0.05), C.cream, M.Fabric)
	return V3(0, 0, -0.5)
end

local function headed(m, _, headSize, headColor, headMat)
	p(m, "Handle", CFrame.new(0, 0, -1.4), V3(0.3, 0.3, 3), C.woodDark, M.Wood)
	p(m, "Head", CFrame.new(0, 0.45, -2.7), headSize, headColor, headMat)
	return V3(0, 0, -0.35)
end

function draw.axe(m, item)
	local grip = headed(m, item, V3(0.25, 1.2, 0.9), RARITY_METAL[item.rarity] or C.iron, M.Metal)
	p(m, "Edge", CFrame.new(0, 1.05, -2.7), V3(0.2, 0.2, 1), C.white:Lerp(C.steel, 0.4), M.Metal)
	return grip
end

function draw.pick(m, item)
	return headed(m, item, V3(0.3, 0.4, 2.2), RARITY_METAL[item.rarity] or C.iron, M.Metal)
end

function draw.hammer(m, item)
	return headed(m, item, V3(0.7, 0.7, 1.1), C.iron, M.Metal)
end

function draw.pry(m)
	p(m, "Bar", CFrame.new(0, 0, -1.6), V3(0.25, 0.25, 3.4), C.iron, M.Metal)
	p(m, "Claw", CFrame.new(0, 0.3, -3.3), V3(0.25, 0.7, 0.4), C.iron, M.Metal)
	return V3(0, 0, -0.5)
end

function draw.spear(m, item)
	p(m, "Shaft", CFrame.new(0, 0, -2.4), V3(0.22, 0.22, 6), C.woodDark, M.Wood)
	p(m, "Tip", CFrame.new(0, 0, -5.7), V3(0.35, 0.12, 1), RARITY_METAL[item.rarity] or C.iron, M.Metal)
	return V3(0, 0, -1.6)
end

function draw.harpoon(m, item)
	p(m, "Shaft", CFrame.new(0, 0, -2.2), V3(0.28, 0.28, 5.4), C.iron, M.Metal)
	p(m, "Tip", CFrame.new(0, 0, -5.3), V3(0.5, 0.16, 1.2), RARITY_METAL[item.rarity] or C.steel, M.Metal)
	p(m, "Rope", CFrame.new(0, -0.2, 0.4), V3(0.12, 0.12, 1), C.rope, M.Fabric)
	return V3(0, 0, -1.4)
end

function draw.lantern(m)
	local grip = p(m, "Handle", CFrame.new(0, 1.3, 0), V3(0.15, 0.6, 0.15), C.iron, M.Metal)
	local glass = p(m, "Glass", CFrame.new(0, 0.5, 0), V3(0.8, 1, 0.8), C.warm, M.Neon)
	p(m, "Cap", CFrame.new(0, 1.05, 0), V3(0.9, 0.2, 0.9), C.iron, M.Metal)
	_ = grip
	return V3(0, 1.5, 0), glass
end

function draw.other(m, item)
	local col = item.kind == "food" and C.autumn
		or item.kind == "artifact" and C.gold
		or item.kind == "chart" and C.cream
		or C.white
	if item.key == "coconut" then
		col = C.bark
	elseif item.key == "berries" then
		col = C.flowerBlue
	elseif item.key == "raw_fish" or item.key == "cooked_fish" then
		return p(
			m,
			"Fish",
			CFrame.new(0, 0, 0),
			V3(0.5, 0.6, 1.6),
			item.key == "raw_fish" and C.steel or C.autumn,
			M.SmoothPlastic
		) and nil
	elseif item.kind == "chart" then
		p(
			m,
			"Scroll",
			CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(90)),
			V3(1.4, 0.5, 0.5),
			C.cream,
			M.Fabric,
			"Cylinder"
		)
		return nil
	elseif item.key == "supply_crate" then
		p(m, "Crate", CFrame.new(0, 0, 0), V3(1.2, 1.1, 1.2), C.wood, M.WoodPlanks)
		return nil
	end
	p(m, "Item", CFrame.new(0, 0, 0), V3(0.8, 0.8, 0.8), col, M.SmoothPlastic, "Ball")
	return nil
end

-- The weld from the hand to the grip, by what the item is.
function ItemModels.holdCFrame(item, hand)
	local down = hand and hand.Size.Y / 2 or 0.15
	local kind = Items.toolKind(item)
	if kind == "axe" or kind == "pick" or kind == "hammer" then
		return CFrame.new(0, -down, 0) * CFrame.Angles(0, 0, math.pi)
	elseif kind == "hook" or kind == "rod" or kind == "pry" or (item.weapon and item.weapon.class) or item.light then
		return CFrame.new(0, -down, 0) * CFrame.Angles(math.rad(-90), 0, 0)
	end
	return CFrame.new(0, -down - 0.3, 0)
end

local function build(item)
	local m = Instance.new("Model")
	m.Name = item.key
	local kind = Items.toolKind(item)
	local fn = draw[kind] or (item.weapon and draw[item.weapon.class]) or (item.light and draw.lantern) or draw.other
	local at, glow = fn(m, item)
	local grip = p(m, "Grip", CFrame.new(at or V3(0, 0, 0)), V3(0.2, 0.2, 0.2), C.woodDark, M.SmoothPlastic)
	grip.Transparency = 1
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
		Kit.light(
			glow,
			"PointLight",
			{ Name = "HeldLight", Color = C.warm, Range = item.light.range, Brightness = item.light.brightness }
		)
	end
	return m, grip
end

function ItemModels.held(item, parent)
	local m, grip = build(item)
	m.Parent = parent
	return m, grip
end

return ItemModels
