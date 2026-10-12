-- Bugs and bosses from plain boxes, in the planet's colours. A bug is a body, a head with two square eyes, six
-- stubby legs and two little wings, plus the planet's own touch (ice spikes, a flame, leaf wings...). A boss is
-- the same shape, 4x bigger, with a crown, red eyes and a bigger glow. All parts are anchored; MobService moves
-- the whole model with PivotTo. Wings are tagged so the client flaps them.
local CollectionService = game:GetService("CollectionService")

local Themes = require(script.Parent.Themes)

local MobBuilder = {}

local WHITE = Color3.fromRGB(255, 255, 255)
local INK = Color3.fromRGB(30, 30, 40)
local RED = Color3.fromRGB(255, 60, 60)

local function box(parent, name, size, cf, color, material, extra)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = name == "Root"
	p.CastShadow = false
	for k, v in extra or {} do
		p[k] = v
	end
	p.Parent = parent
	return p
end

-- scale 1 is a bug about 3 studs long. Faces -Z. The model's PrimaryPart "Root" sits at the body centre.
function MobBuilder.build(planet, scale, isBoss)
	local s = scale or 1
	local model = Instance.new("Model")
	model.Name = isBoss and "Boss_" .. planet.key or "Bug_" .. planet.key
	local root = box(model, "Root", Vector3.new(2.4, 1.6, 3.2) * s, CFrame.new(0, 1.3 * s, 0), planet.color)
	root.Transparency = 1
	model.PrimaryPart = root
	local body = planet.color
	local dark = planet.dark
	box(model, "Body", Vector3.new(2.2, 1.4, 2.8) * s, CFrame.new(0, 1.3 * s, 0.2 * s), body)
	box(model, "Belly", Vector3.new(1.6, 0.4, 2) * s, CFrame.new(0, 0.7 * s, 0.2 * s), dark)
	for i = 1, 3 do
		box(model, "Stripe", Vector3.new(2.3, 0.3, 0.3) * s, CFrame.new(0, 1.3 * s, (-0.6 + i * 0.5) * s), dark)
	end
	box(model, "Head", Vector3.new(1.6, 1.2, 1.2) * s, CFrame.new(0, 1.5 * s, -1.7 * s), body)
	local eye = Themes.eyes[planet.key] or WHITE
	for _, side in { -1, 1 } do
		box(
			model,
			"Eye",
			Vector3.new(0.45, 0.45, 0.1) * s,
			CFrame.new(side * 0.4 * s, 1.65 * s, -2.32 * s),
			eye,
			Enum.Material.Neon
		)
		box(
			model,
			"Pupil",
			Vector3.new(0.2, 0.2, 0.08) * s,
			CFrame.new(side * 0.4 * s, 1.6 * s, -2.38 * s),
			isBoss and RED or INK
		)
		box(
			model,
			"Feeler",
			Vector3.new(0.12, 0.9, 0.12) * s,
			CFrame.new(side * 0.4 * s, 2.4 * s, -1.9 * s) * CFrame.Angles(math.rad(-25), 0, side * math.rad(20)),
			dark
		)
		for k = 1, 3 do
			box(
				model,
				"Leg",
				Vector3.new(0.25, 0.9, 0.25) * s,
				CFrame.new(side * 1.25 * s, 0.55 * s, (-0.9 + k * 0.7) * s) * CFrame.Angles(0, 0, side * math.rad(35)),
				dark
			)
		end
		local wing = box(
			model,
			"Wing",
			Vector3.new(1.4, 0.08, 1.8) * s,
			CFrame.new(side * 0.9 * s, 2.1 * s, 0.3 * s) * CFrame.Angles(0, 0, side * math.rad(-15)),
			body:Lerp(WHITE, 0.5),
			Enum.Material.Glass,
			{ Transparency = 0.35 }
		)
		wing:SetAttribute("Side", side)
		CollectionService:AddTag(wing, "MobWing")
	end
	local touch = Themes.mob[planet.key]
	if touch then
		touch(model, s, planet, isBoss, box)
	end
	if isBoss then
		local gold = Color3.fromRGB(255, 215, 60)
		box(model, "Crown", Vector3.new(1.4, 0.4, 1.2) * s, CFrame.new(0, 2.3 * s, -1.7 * s), gold, Enum.Material.Metal)
		for i = -1, 1 do
			box(
				model,
				"Spike",
				Vector3.new(0.3, 0.6, 0.3) * s,
				CFrame.new(i * 0.45 * s, 2.75 * s, -1.7 * s),
				gold,
				Enum.Material.Metal
			)
		end
		-- armour plates down the back
		for i = 1, 3 do
			box(
				model,
				"Plate",
				Vector3.new(1.2, 0.5, 0.5) * s,
				CFrame.new(0, 2.15 * s, (-0.5 + i * 0.5) * s),
				dark:Lerp(gold, 0.3),
				Enum.Material.Metal
			)
		end
		local light = Instance.new("PointLight")
		light.Color = planet.color
		light.Range = 18 * s
		light.Brightness = 1.5
		light.Parent = root
	end
	model:SetAttribute("Planet", planet.key)
	model:SetAttribute("Boss", isBoss == true)
	return model
end

-- A health bar over a mob (the boss's is bigger). Returns the bar's fill and its text.
function MobBuilder.healthBar(model, width, name)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Health"
	gui.Size = UDim2.new(width, 0, width * 0.32, 0)
	gui.StudsOffset = Vector3.new(0, (model.PrimaryPart.Size.Y / 2) + 2.2, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 90
	gui.AlwaysOnTop = true
	gui.Parent = model.PrimaryPart
	local label = Instance.new("TextLabel")
	label.Name = "Name"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0.55, 0)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = WHITE
	label.TextStrokeTransparency = 0
	label.Text = name
	label.Parent = gui
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.BackgroundColor3 = Color3.fromRGB(40, 42, 62)
	bar.BorderSizePixel = 0
	bar.Size = UDim2.new(1, 0, 0.3, 0)
	bar.Position = UDim2.new(0, 0, 0.62, 0)
	bar.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = bar
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Color3.fromRGB(80, 230, 90)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.Parent = bar
	local c2 = Instance.new("UICorner")
	c2.CornerRadius = UDim.new(1, 0)
	c2.Parent = fill
	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.BackgroundTransparency = 1
	text.Size = UDim2.new(1, 0, 1, 0)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = WHITE
	text.TextStrokeTransparency = 0
	text.ZIndex = 3
	text.Parent = gui
	return fill, text, label
end

-- A burst of bits when a mob pops (parts fly out and fade; the server makes them, Debris cleans up).
function MobBuilder.burst(pos, color, count)
	local rng = Random.new()
	for _ = 1, count or 8 do
		local p = Instance.new("Part")
		p.Name = "Bit"
		p.Size = Vector3.new(0.6, 0.6, 0.6)
		p.Color = color
		p.Material = Enum.Material.Neon
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		p.CFrame = CFrame.new(pos + Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0, 1.5), rng:NextNumber(-1, 1)))
		p.AssemblyLinearVelocity = Vector3.new(rng:NextNumber(-14, 14), rng:NextNumber(10, 24), rng:NextNumber(-14, 14))
		p.Parent = workspace:FindFirstChild("Fx") or workspace
		task.delay(1.2, function()
			p:Destroy()
		end)
	end
end

return MobBuilder
