--[[
The plants on the tiles (master plan §9: four readable stages, distinct silhouettes). Each crop is its own plant,
built from turned leaves, round fruit (sphere meshes) and stems, so a field reads at a glance:

  strawberry  low rosettes, white flowers, then red berries
  tomato      staked vines, green then red fruit
  wheat       a clump of stalks that turn gold, with fat ears
  corn        tall stalks with arching leaves, tassels and cobs
  pumpkin     a vine sprawling under one big ribbed pumpkin
  melon       a vine under a big striped melon
  bush        round blueberry bushes dotted with berries
  tree        a little golden-apple tree, blossom then fruit

  CropModels.build(parent, tileTop, key, stage)   a Model "Plant"; stage 1 (seed mounds) .. 4 (ripe, with a
                                                  sparkle over it); tileTop: a CFrame on the tile's top face
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Crops = require(ReplicatedStorage.Shared.Data.Crops)

local CropModels = {}

local rgb = Color3.fromRGB
local WHITE = rgb(250, 250, 245)
local WOOD = rgb(150, 104, 62)
local SOIL_DARK = rgb(92, 60, 40)
local SCALE = 0.72 -- (the plants were drawn for a 5-stud tile; ours are 4)

local function bit(model, cf, size, color, name, shape, material)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Name = name
	if shape == "ball" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	elseif shape == "cyl" then
		p.Shape = Enum.PartType.Cylinder
	end
	p.Parent = model
	return p
end

-- (a leaf: a thin slab leaning out from the stem at `tilt` degrees, turned `yaw` round it)
local function leafCF(base, yaw, tilt, len, y)
	return base
		* CFrame.Angles(0, math.rad(yaw), 0)
		* CFrame.new(0, y or 0, -len * 0.45)
		* CFrame.Angles(math.rad(-tilt), 0, 0)
end

local PLANTS = {}

PLANTS.strawberry = function(m, base, k, phase, c, leaf, light)
	for i = 0, 4 do
		local cf = leafCF(base, i * 72, 28, 1.1 * k, 0.25 * k)
		bit(m, cf, Vector3.new(0.75 * k, 0.1, 1.1 * k), i % 2 == 0 and leaf or light, "Leaf")
	end
	if phase == 2 then
		for i = 0, 1 do
			local cf = base * CFrame.Angles(0, math.rad(40 + i * 180), 0) * CFrame.new(0.45 * k, 0.5 * k, 0)
			bit(m, cf, Vector3.new(0.35, 0.1, 0.35), WHITE, "Flower")
		end
	elseif phase == 3 then
		for i = 0, 2 do
			local cf = base * CFrame.Angles(0, math.rad(20 + i * 120), 0) * CFrame.new(0.75 * k, 0.3, 0)
			bit(m, cf, Vector3.new(0.42, 0.55, 0.42), c.color, "Fruit", "ball")
		end
	end
end

PLANTS.tomato = function(m, base, k, phase, c, leaf, light)
	local h = 3.6 * k
	bit(m, base * CFrame.new(0.15, 1.6, 0.15), Vector3.new(0.14, 3.2, 0.14), WOOD, "Stake")
	bit(m, base * CFrame.new(0, h / 2, 0), Vector3.new(0.14, h, 0.14), leaf, "Vine")
	for i = 0, 3 do
		for j = 0, 1 do
			local cf = leafCF(base, i * 95 + j * 180, 30, 0.9 * k, h * (0.25 + 0.22 * i))
			bit(m, cf, Vector3.new(0.7 * k, 0.08, 0.9 * k), (i + j) % 2 == 0 and leaf or light, "Leaf")
		end
	end
	if phase >= 2 then
		local ripe = phase == 3
		for i = 0, ripe and 3 or 1 do
			local cf = base * CFrame.Angles(0, math.rad(60 + i * 95), 0) * CFrame.new(0.55 * k, h * (0.3 + 0.18 * i), 0)
			bit(m, cf, Vector3.new(0.45, 0.42, 0.45), ripe and c.color or light, ripe and "Fruit" or "Green", "ball")
		end
	end
end

PLANTS.wheat = function(m, base, k, phase, c, leaf, light)
	local gold = c.color
	local stalk = phase == 3 and gold:Lerp(leaf, 0.25) or (phase == 2 and leaf:Lerp(gold, 0.45) or leaf)
	for i = 0, 5 do
		local a = i * 60 + 15
		local h = (2.4 + (i % 3) * 0.35) * k
		local cf = base
			* CFrame.Angles(0, math.rad(a), 0)
			* CFrame.new(0, 0, -0.35 * k)
			* CFrame.Angles(math.rad(-8), 0, 0)
			* CFrame.new(0, h / 2, 0)
		bit(m, cf, Vector3.new(0.1, h, 0.1), stalk, "Stalk")
		bit(
			m,
			cf * CFrame.new(0.12, -h * 0.2, 0) * CFrame.Angles(0, 0, math.rad(-30)),
			Vector3.new(0.06, h * 0.45, 0.25),
			light,
			"Leaf"
		)
		if phase >= 2 then
			bit(
				m,
				cf * CFrame.new(0, h / 2 + 0.35 * k, 0),
				Vector3.new(0.3 * k, 0.85 * k, 0.3 * k),
				phase == 3 and gold or light,
				"Ear",
				"ball"
			)
			if phase == 3 then
				bit(m, cf * CFrame.new(0, h / 2 + 0.95 * k, 0), Vector3.new(0.04, 0.5 * k, 0.04), gold, "Awn")
			end
		end
	end
end

PLANTS.corn = function(m, base, k, phase, c, leaf, light)
	local h = 6 * k
	bit(
		m,
		base * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Vector3.new(h, 0.35, 0.35),
		leaf,
		"Stalk",
		"cyl"
	)
	for i = 0, 3 do
		local cf = leafCF(base, i * 90 + 30, 35, 2.2 * k, h * (0.3 + 0.17 * i))
		bit(m, cf, Vector3.new(0.3, 0.06, 2.2 * k), i % 2 == 0 and leaf or light, "Leaf")
	end
	if phase >= 2 then
		for i = 0, 2 do
			local cf = base * CFrame.new(0, h + 0.3, 0) * CFrame.Angles(0, math.rad(i * 60), math.rad(25))
			bit(m, cf, Vector3.new(0.08, 0.8, 0.08), rgb(200, 170, 90), "Tassel")
		end
	end
	if phase == 3 then
		for i = 0, 1 do
			local cf = base
				* CFrame.Angles(0, math.rad(i * 180 + 45), 0)
				* CFrame.new(0.3, h * 0.55, 0)
				* CFrame.Angles(0, 0, math.rad(-20))
			bit(m, cf, Vector3.new(0.5, 1.4, 0.5), c.color, "Fruit", "ball")
			bit(m, cf * CFrame.new(0.12, -0.2, 0), Vector3.new(0.3, 1.2, 0.55), light, "Husk", "ball")
		end
	end
end

PLANTS.bush = function(m, base, k, phase, c, leaf, light)
	for i = 0, 2 do
		local cf = base * CFrame.Angles(0, math.rad(i * 120), 0) * CFrame.new(0.35 * k, 0.75 * k, 0)
		bit(m, cf, Vector3.new(1.3 * k, 1.2 * k, 1.3 * k), i == 1 and light or leaf, "Leaf", "ball")
	end
	if phase == 3 then
		for i = 0, 6 do
			local a = math.rad(i * 51)
			local cf = base * CFrame.new(math.cos(a) * 0.8 * k, 0.55 + (i % 3) * 0.35 * k, math.sin(a) * 0.8 * k)
			bit(m, cf, Vector3.new(0.26, 0.26, 0.26), c.color, "Fruit", "ball")
		end
	end
end

-- a fruit tree: one a tile, in its middle
PLANTS.tree = function(m, base, k, phase, c, leaf, light)
	local h = 3.2 * k
	bit(
		m,
		base * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Vector3.new(h, 0.55, 0.55),
		WOOD,
		"Trunk",
		"cyl"
	)
	local crowns = { { 0, 0, 0, 3 }, { 0.9, -0.3, 0.5, 2.2 }, { -0.8, -0.4, -0.6, 2.3 }, { 0.2, 0.7, -0.2, 2 } }
	for i, cr in crowns do
		bit(
			m,
			base * CFrame.new(cr[1] * k, h + 0.8 * k + cr[2] * k, cr[3] * k),
			Vector3.new(cr[4] * k, cr[4] * 0.85 * k, cr[4] * k),
			i % 2 == 0 and light or leaf,
			"Leaf",
			"ball"
		)
	end
	if phase == 3 then
		for i = 1, 7 do
			local a = math.rad(i * 51)
			local cf = base
				* CFrame.new(math.cos(a) * 1.35 * k, h + 0.5 * k + (i % 3) * 0.45 * k, math.sin(a) * 1.35 * k)
			bit(m, cf, Vector3.new(0.48, 0.48, 0.48), c.color, "Fruit", "ball", Enum.Material.Neon)
		end
	elseif phase == 2 then
		for i = 1, 4 do
			local a = math.rad(i * 90 + 20)
			bit(
				m,
				base * CFrame.new(math.cos(a) * 1.3 * k, h + 0.9 * k, math.sin(a) * 1.3 * k),
				Vector3.new(0.3, 0.3, 0.3),
				rgb(255, 225, 235),
				"Blossom",
				"ball"
			)
		end
	end
end

-- a vine sprawling over the tile under one big fruit (pumpkins, melons)
local function vine(m, base, k, phase, c, leaf, light, melon)
	for i = 0, 3 do
		local a = i * 90 + 20
		local cf = base
			* CFrame.Angles(0, math.rad(a), 0)
			* CFrame.new(0, 0.35 * k, -1.5 * k)
			* CFrame.Angles(math.rad(-12), 0, 0)
		bit(m, cf, Vector3.new(1.5 * k, 0.1, 1.5 * k), i % 2 == 0 and leaf or light, "Leaf")
		bit(
			m,
			base * CFrame.Angles(0, math.rad(a + 40), 0) * CFrame.new(0, 0.15, -0.9 * k),
			Vector3.new(0.12, 0.12, 1.8 * k),
			leaf,
			"Vine"
		)
	end
	if phase >= 2 then
		local ripe = phase == 3
		local s = (ripe and 1 or 0.55) * k * 1.25
		if melon then
			bit(
				m,
				base * CFrame.new(0, 0.65 * s, 0),
				Vector3.new(2.3 * s, 1.3 * s, 1.5 * s),
				ripe and c.color or light,
				"Fruit",
				"ball"
			)
			for i = -1, 1 do
				bit(
					m,
					base * CFrame.new(i * 0.55 * s, 1.27 * s, 0),
					Vector3.new(0.14, 0.06, 1.1 * s),
					rgb(30, 100, 40),
					"Stripe"
				)
			end
		else
			local color = ripe and c.color or rgb(150, 180, 70)
			bit(m, base * CFrame.new(0, 0.7 * s, 0), Vector3.new(1.6 * s, 1.3 * s, 1.9 * s), color, "Fruit", "ball")
			for _, sx in { -1, 1 } do
				bit(
					m,
					base * CFrame.new(sx * 0.5 * s, 0.68 * s, 0),
					Vector3.new(1.1 * s, 1.2 * s, 1.75 * s),
					color,
					"Fruit",
					"ball"
				)
			end
			bit(
				m,
				base * CFrame.new(0, 1.45 * s, 0) * CFrame.Angles(0, 0, math.rad(12)),
				Vector3.new(0.2, 0.45, 0.2),
				rgb(110, 80, 40),
				"Stem"
			)
		end
	end
end

PLANTS.pumpkin = function(m, base, k, phase, c, leaf, light)
	vine(m, base, k, phase, c, leaf, light, false)
end
PLANTS.melon = function(m, base, k, phase, c, leaf, light)
	vine(m, base, k, phase, c, leaf, light, true)
end

-- the ones that grow one a tile (in its middle); the rest grow four a tile
local SINGLE = { tree = true, pumpkin = true, melon = true }

function CropModels.build(parent, top, key, stage)
	local c = Crops[key]
	if not c then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "Plant"
	model:SetAttribute("Crop", key)
	model:SetAttribute("Stage", stage)
	local leaf = c.leaf
	local light = leaf:Lerp(Color3.new(1, 1, 0.8), 0.25)
	local spots = { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }
	local phase = stage - 1
	if phase == 0 then
		-- seed mounds, each with a tiny sprout
		for i, p in spots do
			local at = top * CFrame.new(p[1], 0, p[2])
			bit(model, at * CFrame.new(0, 0.1, 0), Vector3.new(0.8, 0.25, 0.8), SOIL_DARK, "Mound", "ball")
			bit(
				model,
				at * CFrame.Angles(0, math.rad(i * 50), math.rad(30)) * CFrame.new(0, 0.3, 0),
				Vector3.new(0.08, 0.32, 0.2),
				light,
				"Sprout"
			)
		end
		model.Parent = parent
		return model
	end
	local k = (0.45 + 0.55 * phase / 3) * SCALE
	local build = PLANTS[c.model] or PLANTS.strawberry
	if SINGLE[c.model] then
		build(model, top, k * 1.3, phase, c, leaf, light)
	else
		for i, p in spots do
			build(
				model,
				top * CFrame.new(p[1], 0, p[2]) * CFrame.Angles(0, math.rad(i * 37), 0),
				k,
				phase,
				c,
				leaf,
				light
			)
		end
	end
	if phase == 3 then
		-- a sparkle over a ripe tile, so it reads "ready" from across the field
		local p = bit(
			model,
			top * CFrame.new(0, 4, 0) * CFrame.Angles(0, math.rad(45), math.rad(45)),
			Vector3.new(0.55, 0.55, 0.55),
			WHITE,
			"Ripe",
			nil,
			Enum.Material.Neon
		)
		p.Transparency = 0.15
	end
	model.Parent = parent
	return model
end

return CropModels
