-- Blaster models from plain boxes: a grip, a body in the planet's colour, a barrel, and a glowing core in the
-- rarity's colour. Bigger rarities get a bigger barrel, fins and a glow. The same builder makes the Tool a
-- player holds and the display model in the forge panel.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Blasters = require(ReplicatedStorage.Shared.Data.Blasters)
local Planets = require(ReplicatedStorage.Shared.Data.Planets)

local BlasterBuilder = {}

local INK = Color3.fromRGB(35, 35, 45)

local function box(parent, name, size, cf, color, material, extra)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = false
	p.CanCollide = false
	p.Massless = true
	p.CastShadow = false
	for k, v in extra or {} do
		p[k] = v
	end
	p.Parent = parent
	return p
end

-- Builds the parts under `tool` (a Tool or a Model), welded to its Handle. Faces -Z from the handle.
function BlasterBuilder.build(container, rec)
	local planet = Planets.byKey[rec.planet] or Planets.list[1]
	local rarity = Blasters.byRarity[rec.rarity] or Blasters.Rarities[1]
	local rank = rarity.rank
	local handle = box(container, "Handle", Vector3.new(0.5, 1.1, 0.6), CFrame.new(), INK)
	local function attach(p)
		local w = Instance.new("WeldConstraint")
		w.Part0 = handle
		w.Part1 = p
		w.Parent = p
		return p
	end
	local len = 1.4 + rank * 0.25
	attach(box(container, "Body", Vector3.new(0.7, 0.7, len), CFrame.new(0, 0.75, -len / 2 + 0.3), planet.color))
	attach(box(container, "Top", Vector3.new(0.45, 0.25, len * 0.6), CFrame.new(0, 1.22, -len / 2 + 0.3), planet.dark))
	attach(
		box(
			container,
			"Barrel",
			Vector3.new(0.35 + rank * 0.06, 0.35 + rank * 0.06, 0.8 + rank * 0.15),
			CFrame.new(0, 0.75, -len + 0.3 - 0.4),
			INK
		)
	)
	local core = attach(
		box(
			container,
			"Core",
			Vector3.new(0.5, 0.5, 0.5),
			CFrame.new(0, 0.75, -len * 0.45),
			rarity.color,
			Enum.Material.Neon
		)
	)
	-- the glowing tip
	attach(
		box(
			container,
			"Tip",
			Vector3.new(0.28, 0.28, 0.2),
			CFrame.new(0, 0.75, -len + 0.3 - 0.85 - rank * 0.08),
			rarity.color,
			Enum.Material.Neon
		)
	)
	if rank >= 3 then
		for _, side in { -1, 1 } do
			attach(
				box(
					container,
					"Fin",
					Vector3.new(0.12, 0.5, 0.7),
					CFrame.new(side * 0.42, 0.95, -len * 0.3) * CFrame.Angles(0, 0, side * math.rad(20)),
					rarity.color
				)
			)
		end
	end
	if rarity.glow then
		local light = Instance.new("PointLight")
		light.Color = rarity.color
		light.Range = 6 + rank
		light.Brightness = 1.2
		light.Parent = core
	end
	if rank >= 5 then
		local e = Instance.new("ParticleEmitter")
		e.Name = "Twinkle"
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(rarity.color)
		e.LightEmission = 0.8
		e.Rate = 3
		e.Size = NumberSequence.new(0.3, 0)
		e.Lifetime = NumberRange.new(0.5, 0.9)
		e.Speed = NumberRange.new(0.3, 0.8)
		e.Parent = core
	end
	return handle
end

-- A Tool for the hotbar. Attributes carry what the client needs (uid, name, rarity, cooldown).
function BlasterBuilder.tool(rec, name, cooldown)
	local tool = Instance.new("Tool")
	tool.Name = name
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = "Tap to blast!"
	tool.Grip = CFrame.new(0, -0.3, 0)
	tool:SetAttribute("Kind", "blaster")
	tool:SetAttribute("Uid", rec.uid)
	tool:SetAttribute("Rarity", rec.rarity)
	tool:SetAttribute("Planet", rec.planet)
	tool:SetAttribute("Cooldown", cooldown)
	BlasterBuilder.build(tool, rec)
	return tool
end

return BlasterBuilder
