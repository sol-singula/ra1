--[[
The crop models: every seed, every growth stage, and the mutation looks. The live tiles (TileController), the
pedestals (PedestalController) and the capture stage (CaptureService) all build crops through here, so a staged crop
is exactly what players see.

Stages (Crop.stageFor(progress, ripe)): seed (a soil mound with a tiny shoot), sprout (a seedling), growing (the
seed's own leaves at 70%), budding (full leaves and a small unripe fruit), ripe (the full fruit). An item (a kept
crop on a pedestal) is the fruit alone.

Looks (Crop.setMuts(model, muts)):
  Golden   the fruit (or, before it fruits, the leaves) turns Visuals.GOLD (#FFC300), its highlights
           Visuals.GOLD_LIGHT (#FFF1A8), with a shine, pale gold star glints and ONE PointLight (on the Main part)
  Wet      droplet beads on the Main part, a wet sheen and blue glints
  both     gold with beads (still one light)
Fruit parts carry Fruit = true, leaves Leaf = true, the part the light and glints sit on Main = true, and every one
of them its own BaseColor. The model carries Crop = true, Seed, Stage, Muts and Origin (the CFrame it was built on).

  Crop.stageFor(progress, ripe) -> stage
  Crop.build(parent, name, seed, stage, cf, muts?, scale?) -> Model
  Crop.forTile(parent, name, seed, progress, ripe, muts, cf)    a tile's crop (cf is the soil top)
  Crop.item(parent, name, seed, muts, cf, scale)                a kept crop (fruit only)
  Crop.onPedestal(parent, name, seed, muts, pedestal, scale)     a kept crop standing on a pedestal part (the live
                                                                 pedestals and the capture stage's)
  Crop.setMuts(model, muts)      muts is a key ("wet" | "golden" | "wetgolden" | nil) or a { wet, golden } table
  Crop.main(model) / fruit(model) / destroy(model)
]]
local Kit = require(script.Parent.Kit)
local MutationMath = require(script.Parent.Parent.MutationMath)
local Visuals = require(script.Parent.Parent.Visuals)

local Crop = {}

Crop.STAGES = { "seed", "sprout", "growing", "budding", "ripe" }
Crop.MAX_LIGHTS = 1

local LEAF = Visuals.LEAF
local DARK_LEAF = Color3.fromRGB(62, 132, 52)
local STEM = Color3.fromRGB(112, 82, 46)
local STAKE = Color3.fromRGB(150, 112, 72)
local SOIL = Color3.fromRGB(108, 76, 46)

local rad = math.rad

function Crop.stageFor(progress, ripe)
	if ripe or progress >= 1 then
		return "ripe"
	elseif progress >= 0.75 then
		return "budding"
	elseif progress >= 0.45 then
		return "growing"
	elseif progress >= 0.2 then
		return "sprout"
	end
	return "seed"
end

local function mark(p, attr)
	p:SetAttribute(attr, true)
	p:SetAttribute("BaseColor", p.Color)
	return p
end

local function leaf(m, name, size, cf, color)
	return mark(Kit.ball(m, name, size, cf, color or LEAF), "Leaf")
end

local function blade(m, name, size, cf, color)
	return mark(Kit.part(m, name, size, cf, color or LEAF, Enum.Material.SmoothPlastic), "Leaf")
end

local function fruitBall(m, name, size, cf, color)
	return mark(Kit.ball(m, name, size, cf, color), "Fruit")
end

---------------------------------------------------------------------------------------------------------------
-- foliage: (model, ground cf, scale)

local FOLIAGE = {}

function FOLIAGE.tuft(m, cf, s)
	for i = 1, 5 do
		local a = rad(i * 72)
		blade(
			m,
			"Blade" .. i,
			Vector3.new(0.14, 1.5, 0.38) * s,
			cf * CFrame.Angles(0, a, 0) * CFrame.Angles(rad(16), 0, 0) * CFrame.new(0, 0.75 * s, 0),
			if i % 2 == 0 then DARK_LEAF else LEAF
		)
	end
end

function FOLIAGE.bush(m, cf, s)
	local spots = { { 0.45, 0.5, 0.4 }, { -0.5, 0.5, 0.3 }, { 0.1, 0.5, -0.5 }, { 0, 0.95, 0 } }
	for i, o in spots do
		leaf(
			m,
			"Clump" .. i,
			Vector3.new(1.15, 0.9, 1.15) * s,
			cf * CFrame.new(o[1] * s, o[2] * s, o[3] * s),
			if i % 2 == 0 then DARK_LEAF else LEAF
		)
	end
end

function FOLIAGE.vine(m, cf, s)
	Kit.cylinder(m, "Stake", 3 * s, 0.16, cf * CFrame.new(0, 1.5 * s, 0), STAKE, Enum.Material.Wood)
	for i, h in { 0.55, 1.25, 1.95, 2.55 } do
		local side = if i % 2 == 0 then -1 else 1
		leaf(
			m,
			"Clump" .. i,
			Vector3.new(0.95, 0.6, 0.95) * s,
			cf * CFrame.new(0.32 * side * s, h * s, 0.1 * s),
			if i % 2 == 0 then DARK_LEAF else LEAF
		)
	end
end

function FOLIAGE.stalk(m, cf, s)
	Kit.cylinder(m, "Stalk", 3.6 * s, 0.32 * s, cf * CFrame.new(0, 1.8 * s, 0), Color3.fromRGB(110, 172, 72))
	for i = 1, 6 do
		local a = rad(i * 137)
		blade(
			m,
			"Blade" .. i,
			Vector3.new(0.08, 1.8, 0.42) * s,
			cf
				* CFrame.new(0, (0.5 + i * 0.4) * s, 0)
				* CFrame.Angles(0, a, 0)
				* CFrame.Angles(rad(48), 0, 0)
				* CFrame.new(0, 0.85 * s, 0),
			if i % 2 == 0 then DARK_LEAF else LEAF
		)
	end
	Kit.part(
		m,
		"Tassel",
		Vector3.new(0.22, 0.6, 0.22) * s,
		cf * CFrame.new(0, 3.85 * s, 0),
		Color3.fromRGB(196, 176, 120)
	)
end

function FOLIAGE.ground(m, cf, s)
	for i = 1, 4 do
		local a = rad(i * 90 + 30)
		leaf(
			m,
			"Leaf" .. i,
			Vector3.new(1.6, 0.18, 1.35) * s,
			cf * CFrame.Angles(0, a, 0) * CFrame.new(1.35 * s, 0.14, 0) * CFrame.Angles(0, 0, rad(-10)),
			if i % 2 == 0 then DARK_LEAF else LEAF
		)
	end
	Kit.cylinder(
		m,
		"Vine",
		2.6 * s,
		0.12,
		cf * CFrame.Angles(0, rad(20), 0) * CFrame.new(-1.1 * s, 0.1, 0) * CFrame.Angles(0, 0, rad(90)),
		DARK_LEAF
	)
end

function FOLIAGE.cactus(m, cf, s)
	local green = Color3.fromRGB(76, 150, 84)
	mark(Kit.part(m, "Column", Vector3.new(0.6, 2, 0.6) * s, cf * CFrame.new(0, 1 * s, 0), green), "Leaf")
	for i, side in { -1, 1 } do
		mark(
			Kit.part(
				m,
				"Arm" .. i,
				Vector3.new(0.45, 1.1, 0.45) * s,
				cf * CFrame.new(0.55 * side * s, 1.1 * s, 0) * CFrame.Angles(0, 0, rad(-35 * side)),
				green
			),
			"Leaf"
		)
	end
end

local function sprout(m, cf, s)
	Kit.cylinder(m, "Shoot", 0.6 * s, 0.1, cf * CFrame.new(0, 0.3 * s, 0), DARK_LEAF)
	for i, side in { -1, 1 } do
		leaf(
			m,
			"Seedling" .. i,
			Vector3.new(0.55, 0.1, 0.32) * s,
			cf * CFrame.new(0.26 * side * s, 0.62 * s, 0) * CFrame.Angles(0, 0, rad(18 * side))
		)
	end
end

local function mound(m, cf)
	Kit.ball(m, "Mound", Vector3.new(1.3, 0.38, 1.3), cf * CFrame.new(0, 0.08, 0), SOIL, Enum.Material.Ground)
	sprout(m, cf * CFrame.new(0, 0.18, 0), 0.4)
end

---------------------------------------------------------------------------------------------------------------
-- fruit: (model, ground cf, scale, colour); the first part made is the Main one

local FRUIT = {}

function FRUIT.root(m, cf, s, color)
	fruitBall(m, "Root", Vector3.new(0.8, 1.35, 0.8) * s, cf * CFrame.new(0, 0.25 * s, 0), color)
end

local function berries(m, cf, s, color, spots, size, capped)
	for i, o in spots do
		local p = fruitBall(m, "Berry" .. i, size * s, cf * CFrame.new(o[1] * s, o[2] * s, o[3] * s), color)
		if capped then
			Kit.part(
				m,
				"Cap" .. i,
				Vector3.new(0.32, 0.08, 0.32) * s,
				p.CFrame * CFrame.new(0, size.Y * s / 2, 0),
				DARK_LEAF
			)
		end
	end
end

function FRUIT.strawberry(m, cf, s, color)
	berries(
		m,
		cf,
		s,
		color,
		{ { 0.6, 0.45, -0.55 }, { -0.7, 0.4, -0.25 }, { 0.15, 0.4, 0.75 } },
		Vector3.new(0.52, 0.64, 0.52),
		true
	)
end

function FRUIT.blueberry(m, cf, s, color)
	berries(m, cf, s, color, {
		{ 0.62, 0.62, -0.5 },
		{ 0.4, 0.95, -0.55 },
		{ -0.7, 0.55, -0.3 },
		{ -0.5, 0.95, 0.1 },
		{ 0.2, 0.5, 0.78 },
		{ 0.5, 0.85, 0.55 },
	}, Vector3.new(0.36, 0.36, 0.36), false)
end

function FRUIT.tomato(m, cf, s, color)
	berries(
		m,
		cf,
		s,
		color,
		{ { 0.45, 0.95, -0.4 }, { -0.5, 1.6, -0.35 }, { 0.45, 2.2, 0.3 } },
		Vector3.new(0.78, 0.7, 0.78),
		true
	)
end

function FRUIT.cob(m, cf, s, color)
	for i, at in { { 1.6, 0.32, 20 }, { 2.3, -0.32, -24 } } do
		local cob = fruitBall(
			m,
			"Cob" .. i,
			Vector3.new(0.52, 1.25, 0.52) * s,
			cf * CFrame.new(at[2] * s, at[1] * s, 0) * CFrame.Angles(0, 0, rad(at[3])),
			color
		)
		for j, side in { -1, 1 } do
			Kit.part(
				m,
				`Husk{i}_{j}`,
				Vector3.new(0.12, 1.05, 0.4) * s,
				cob.CFrame * CFrame.new(0.24 * side * s, -0.15 * s, 0),
				Color3.fromRGB(128, 180, 86)
			)
		end
	end
end

function FRUIT.gourd(m, cf, s, color)
	fruitBall(m, "Body", Vector3.new(2.8, 2.1, 2.8) * s, cf * CFrame.new(0, 1.05 * s, 0), color)
	for i, o in { { 0.42, 0, 2.1, 2.7 }, { -0.42, 0, 2.1, 2.7 }, { 0, 0.42, 2.7, 2.1 }, { 0, -0.42, 2.7, 2.1 } } do
		fruitBall(
			m,
			"Rib" .. i,
			Vector3.new(o[3], 2.02, o[4]) * s,
			cf * CFrame.new(o[1] * s, 1.02 * s, o[2] * s),
			color:Lerp(Color3.new(0, 0, 0), 0.06)
		)
	end
	Kit.cylinder(
		m,
		"Stem",
		0.6 * s,
		0.34 * s,
		cf * CFrame.new(0, 2.2 * s, 0) * CFrame.Angles(rad(12), 0, 0),
		STEM,
		Enum.Material.Wood
	)
end

local function melon(m, cf, s, color, stripe)
	local size = Vector3.new(3, 2, 2.2) * s
	fruitBall(m, "Body", size, cf * CFrame.new(0, 1 * s, 0), color)
	for i, x in { -0.85, 0, 0.85 } do
		local k = math.sqrt(1 - (x / 1.5) ^ 2)
		local band = fruitBall(
			m,
			"Stripe" .. i,
			Vector3.new(0.32 * s, size.Y * k + 0.06, size.Z * k + 0.06),
			cf * CFrame.new(x * s, 1 * s, 0),
			stripe
		)
		band:SetAttribute("Hi", true)
	end
end

function FRUIT.melon(m, cf, s, color)
	melon(m, cf, s, color, color:Lerp(Color3.new(0, 0, 0), 0.4))
end

function FRUIT.moon(m, cf, s, color)
	melon(m, cf, s * 0.88, color, color:Lerp(Color3.new(1, 1, 1), 0.55))
end

function FRUIT.dragon(m, cf, s, color)
	local body = fruitBall(m, "Body", Vector3.new(1.2, 1.5, 1.2) * s, cf * CFrame.new(0, 2.25 * s, 0), color)
	for i = 1, 6 do
		local a = rad(i * 60)
		local scale = mark(
			Kit.part(
				m,
				"Scale" .. i,
				Vector3.new(0.34, 0.12, 0.22) * s,
				body.CFrame
					* CFrame.Angles(0, a, 0)
					* CFrame.new(0.6 * s, (i % 2 - 0.5) * 0.5 * s, 0)
					* CFrame.Angles(0, 0, rad(30)),
				Color3.fromRGB(120, 200, 92)
			),
			"Fruit"
		)
		scale:SetAttribute("Hi", true)
	end
end

-- seed -> { foliage, fruit }
local SPEC = {
	carrot = { "tuft", "root" },
	strawberry = { "bush", "strawberry" },
	blueberry = { "bush", "blueberry" },
	tomato = { "vine", "tomato" },
	corn = { "stalk", "cob" },
	pumpkin = { "ground", "gourd" },
	watermelon = { "ground", "melon" },
	dragonfruit = { "cactus", "dragon" },
	moonmelon = { "ground", "moon" },
}
Crop.SPEC = SPEC

---------------------------------------------------------------------------------------------------------------

local function tagged(model, attr)
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute(attr) then
			table.insert(out, d)
		end
	end
	return out
end

function Crop.fruit(model)
	return tagged(model, "Fruit")
end

function Crop.main(model)
	return tagged(model, "Main")[1]
end

function Crop.build(parent, name, seed, stage, cf, muts, scale)
	local spec = SPEC[seed] or SPEC.carrot
	local color = Visuals.SEED[seed] or LEAF
	local m = Instance.new("Model")
	m.Name = name
	m:SetAttribute("Crop", true)
	m:SetAttribute("Seed", seed)
	m:SetAttribute("Stage", stage)
	m:SetAttribute("Origin", cf)
	local s = scale or 1
	if stage == "seed" then
		mound(m, cf)
	elseif stage == "sprout" then
		sprout(m, cf, 1.4)
	elseif stage ~= "item" then
		FOLIAGE[spec[1]](m, cf, if stage == "growing" then 0.7 else 1)
	end
	if stage == "budding" then
		FRUIT[spec[2]](m, cf, 0.55, LEAF:Lerp(color, 0.35))
	elseif stage == "ripe" then
		FRUIT[spec[2]](m, cf, 1, color)
	elseif stage == "item" then
		FRUIT[spec[2]](m, cf, s, color)
	end
	local main = Crop.fruit(m)[1] or tagged(m, "Leaf")[1]
	if main then
		main:SetAttribute("Main", true)
		m.PrimaryPart = main
	end
	Crop.setMuts(m, muts)
	m.Parent = parent
	return m
end

function Crop.forTile(parent, name, seed, progress, ripe, muts, cf)
	return Crop.build(parent, name, seed, Crop.stageFor(progress, ripe), cf, muts)
end

function Crop.item(parent, name, seed, muts, cf, scale)
	return Crop.build(parent, name, seed, "item", cf, muts, scale)
end

Crop.PEDESTAL_SCALE = 0.5

function Crop.onPedestal(parent, name, seed, muts, pedestal, scale)
	local top = CFrame.new(pedestal.Position + Vector3.new(0, pedestal.Size.Y / 2, 0))
	return Crop.item(parent, name, seed, muts, top, scale or Crop.PEDESTAL_SCALE)
end

local function beads(look, main)
	local size = main.Size
	local r = math.min(size.X, size.Y, size.Z)
	for i = 1, 7 do
		local a = i * 2.4
		local elev = 0.3 + 0.18 * (i % 4)
		local dir = Vector3.new(math.cos(a) * math.cos(elev), math.sin(elev), math.sin(a) * math.cos(elev))
		local bead = Kit.ball(
			look,
			"Bead" .. i,
			Vector3.one * math.clamp(r * (0.09 + 0.03 * (i % 3)), 0.08, 0.32),
			main.CFrame * CFrame.new(dir * size / 2),
			Visuals.DROP,
			Enum.Material.Glass
		)
		bead.Transparency = 0.25
		bead.Reflectance = 0.3
	end
end

function Crop.setMuts(model, muts)
	local key = if type(muts) == "table" then MutationMath.key(muts) else muts
	if model:GetAttribute("LookSet") and model:GetAttribute("Muts") == key then
		return
	end
	model:SetAttribute("LookSet", true)
	model:SetAttribute("Muts", key)
	local golden = key == "golden" or key == "wetgolden"
	local wet = key == "wet" or key == "wetgolden"
	local targets = Crop.fruit(model)
	if #targets == 0 then
		targets = tagged(model, "Leaf")
	end
	for _, p in targets do
		local base = p:GetAttribute("BaseColor") or p.Color
		if golden then
			p.Color = if p:GetAttribute("Hi") then Visuals.GOLD_LIGHT else Visuals.GOLD
			p.Reflectance = 0.3
			p:SetAttribute("Gold", true)
		else
			p.Color = base
			p.Reflectance = if wet then 0.12 else 0
			p:SetAttribute("Gold", nil)
		end
	end
	local old = model:FindFirstChild("MutLook")
	if old then
		old:Destroy()
	end
	local main = Crop.main(model)
	if not main then
		return
	end
	local light = main:FindFirstChild("GoldLight")
	if light then
		light:Destroy()
	end
	Visuals.mutationFx(main, key)
	if not key then
		return
	end
	local look = Instance.new("Folder")
	look.Name = "MutLook"
	if golden then
		light = Instance.new("PointLight")
		light.Name = "GoldLight"
		light.Color = Visuals.GOLD
		light.Brightness = 1.2
		light.Range = 9
		light.Shadows = false
		light.Parent = main
		local size = main.Size
		Kit.ball(
			look,
			"Shine",
			Vector3.one * math.min(size.X, size.Y, size.Z) * 0.2,
			main.CFrame * CFrame.new(-size.X * 0.22, size.Y * 0.3, -size.Z * 0.3),
			Visuals.GOLD_LIGHT,
			Enum.Material.Neon
		)
	end
	if wet then
		beads(look, main)
	end
	look.Parent = model
end

-- hands the pooled glints back, then destroys the model
function Crop.destroy(model)
	local main = Crop.main(model)
	if main then
		Visuals.release(main)
	end
	model:Destroy()
end

return Crop
