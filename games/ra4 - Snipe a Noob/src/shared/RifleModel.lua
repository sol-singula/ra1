-- Builds a rifle out of boxes, in the rifle's colours or a skin's. Used for the Tool other players see in your
-- hands (server) and for your own first-person view model (client). Local space: -Z is forward (the barrel),
-- the origin is the grip. Parts never collide and rays pass through them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Rifles = require(ReplicatedStorage.Shared.Data.Rifles)

local RifleModel = {}

local MASTERY_LOOK = {
	{ body = Color3.fromRGB(255, 200, 60), accent = Color3.fromRGB(255, 240, 170), material = "Foil" }, -- gold
	{ body = Color3.fromRGB(170, 230, 255), accent = Color3.fromRGB(255, 255, 255), material = "Glass", glow = true },
	{ body = Color3.fromRGB(255, 80, 80), accent = Color3.fromRGB(80, 200, 255), glow = true, rainbow = true },
}
RifleModel.MASTERY_NAMES = { "Gold", "Diamond", "Rainbow" }

-- The colours to use: a skin wins over a mastery look, which wins over the rifle's own colours.
function RifleModel.look(rifleKey, skinId, masteryTier)
	local rifle = Rifles.byKey[rifleKey] or Rifles.list[1]
	local skin = skinId and Cosmetics.skinById[skinId]
	if skin then
		return skin
	end
	if masteryTier and MASTERY_LOOK[masteryTier] then
		return MASTERY_LOOK[masteryTier]
	end
	return { body = rifle.color, accent = rifle.accent }
end

local function box(parent, name, size, cf, color, material, neon)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = neon and Enum.Material.Neon or (material and Enum.Material[material] or Enum.Material.SmoothPlastic)
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

-- Returns a Model whose PrimaryPart is "Handle" (the grip), with every other part welded to it, and a
-- "Muzzle" attachment at the end of the barrel. at: where to build it (CFrame).
function RifleModel.build(rifleKey, skinId, masteryTier, at)
	local rifle = Rifles.byKey[rifleKey] or Rifles.list[1]
	local look = RifleModel.look(rifleKey, skinId, masteryTier)
	at = at or CFrame.new()
	local model = Instance.new("Model")
	model.Name = "Rifle_" .. rifle.key
	local body, accent, mat = look.body, look.accent, look.material
	local handle = box(model, "Handle", Vector3.new(0.4, 0.8, 0.45), at * CFrame.new(0, -0.35, 0.1), body, mat)
	model.PrimaryPart = handle
	local L = rifle.barrel
	local parts = {
		{ "Receiver", Vector3.new(0.55, 0.6, 2.2), CFrame.new(0, 0.1, -0.5), body, mat },
		{ "Stock", Vector3.new(0.45, 0.75, 1.5), CFrame.new(0, -0.05, 1.25), body, mat },
		{ "Butt", Vector3.new(0.5, 0.9, 0.25), CFrame.new(0, -0.05, 2.05), accent, nil },
		{ "Barrel", Vector3.new(0.24, 0.24, L), CFrame.new(0, 0.18, -1.6 - L / 2), accent, nil },
		{ "Tip", Vector3.new(0.34, 0.34, 0.35), CFrame.new(0, 0.18, -1.6 - L), body, mat },
		{ "Scope", Vector3.new(0.38, 0.38, 1.7), CFrame.new(0, 0.65, -0.55), accent, nil },
		{ "ScopeFront", Vector3.new(0.48, 0.48, 0.25), CFrame.new(0, 0.65, -1.45), body, mat },
		{ "ScopeBack", Vector3.new(0.44, 0.44, 0.25), CFrame.new(0, 0.65, 0.35), body, mat },
		{ "Mount", Vector3.new(0.2, 0.25, 0.8), CFrame.new(0, 0.45, -0.55), accent, nil },
		{ "Mag", Vector3.new(0.32, 0.55, 0.5), CFrame.new(0, -0.4, -0.75), accent, nil },
	}
	if rifle.shots > 1 then
		table.insert(
			parts,
			{ "Barrel2", Vector3.new(0.2, 0.2, L * 0.9), CFrame.new(0, -0.08, -1.6 - L * 0.45), accent }
		)
	end
	for _, spec in parts do
		local p = box(model, spec[1], spec[2], at * spec[3], spec[4], spec[5])
		local w = Instance.new("WeldConstraint")
		w.Part0 = handle
		w.Part1 = p
		w.Parent = p
	end
	local lens = box(model, "Lens", Vector3.new(0.34, 0.34, 0.06), at * CFrame.new(0, 0.65, -1.59), accent, nil, true)
	local lw = Instance.new("WeldConstraint")
	lw.Part0 = handle
	lw.Part1 = lens
	lw.Parent = lens
	if look.glow then
		for _, p in model:GetChildren() do
			if p:IsA("BasePart") and (p.Name == "Barrel" or p.Name == "Mag" or p.Name == "Scope") then
				p.Material = Enum.Material.Neon
			end
		end
	end
	if look.rainbow then
		model:SetAttribute("Rainbow", true) -- the client cycles its colours
	end
	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = Vector3.new(0, 0.53, -1.95 - L) -- relative to the handle
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
	-- the barrel points along the hand's forward when the arm is raised
	tool.Grip = CFrame.new(0, -0.1, 0.35) * CFrame.Angles(math.rad(90), 0, 0)
	tool:SetAttribute("Rifle", rifleKey)
	tool:SetAttribute("Skin", skinId or "")
	for _, child in model:GetChildren() do
		child.Parent = tool
	end
	model:Destroy()
	return tool
end

return RifleModel
