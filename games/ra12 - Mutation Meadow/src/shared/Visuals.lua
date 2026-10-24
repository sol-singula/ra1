--[[
How crops look (the client's world and the capture stage, through Models/Crop): a colour per seed (the fruit), the
leaf colour while it grows, the Golden colours, the pooled mutation glints and the Golden reveal.

  Visuals.mutationFx(part, key) / release(part) / setReduced(on) / poolSize()
  Visuals.goldenReveal(model)      the reveal when a crop turns Golden: a star burst, a ring, the light flaring
                                   and the fruit sweeping from its own colour to gold (client side: the live tiles
                                   and the capture stage's `capture reveal`)
  Visuals.grownNow(part, now)
]]
local Visuals = {}

Visuals.LEAF = Color3.fromRGB(90, 170, 70)
Visuals.SEED = {
	carrot = Color3.fromRGB(245, 140, 40),
	strawberry = Color3.fromRGB(230, 50, 70),
	blueberry = Color3.fromRGB(70, 90, 200),
	tomato = Color3.fromRGB(220, 50, 40),
	corn = Color3.fromRGB(245, 210, 60),
	pumpkin = Color3.fromRGB(240, 130, 30),
	watermelon = Color3.fromRGB(60, 160, 70),
	dragonfruit = Color3.fromRGB(235, 70, 160),
	moonmelon = Color3.fromRGB(190, 200, 255),
}

-- the Golden material: the body colour and its highlight (star glints, the shine)
Visuals.GOLD = Color3.fromHex("#FFC300")
Visuals.GOLD_LIGHT = Color3.fromHex("#FFF1A8")
-- Wet droplet beads
Visuals.DROP = Color3.fromRGB(200, 232, 255)

-- mutation colours: the Backpack frame, the world sparkles
Visuals.MUT = {
	wet = Color3.fromRGB(80, 170, 255),
	golden = Visuals.GOLD,
	wetgolden = Color3.fromRGB(150, 255, 220),
}
-- the glints' own colour: star glints are the pale gold highlight
local GLINT = {
	wet = Color3.fromRGB(190, 230, 255),
	golden = Visuals.GOLD_LIGHT,
	wetgolden = Visuals.GOLD_LIGHT,
}
Visuals.SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

-- Reduced effects (Settings): particle rates are cut by REDUCED_RATE (75% fewer) and the rain sheet is off
Visuals.REDUCED_RATE = 0.25
Visuals.reducedFx = false

local RATES = { wet = 8, golden = 8, wetgolden = 14 }
local active = setmetatable({}, { __mode = "k" }) -- [emitter] = key, the emitters in use
local pool = {} -- free emitters, reused instead of made and destroyed (Visuals.poolSize())

local function rateFor(key)
	return RATES[key] * (if Visuals.reducedFx then Visuals.REDUCED_RATE else 1)
end

local function take()
	local fx = table.remove(pool)
	if not fx then
		fx = Instance.new("ParticleEmitter")
		fx.Name = "MutFx"
		fx.LightEmission = 0.8
		fx.Lifetime = NumberRange.new(0.8, 1.4)
		fx.Speed = NumberRange.new(1, 2)
		fx.Size = NumberSequence.new(0.25)
		fx.Texture = Visuals.SPARKLE
		fx.SpreadAngle = Vector2.new(180, 180)
	end
	fx.Enabled = true
	return fx
end

local function give(fx)
	active[fx] = nil
	fx.Enabled = false
	fx.Parent = nil
	table.insert(pool, fx)
end

-- sparkles on a part for a mutation key ("wet" | "golden" | "wetgolden" | nil clears them); emitters are pooled
function Visuals.mutationFx(part, key)
	local fx = part:FindFirstChild("MutFx")
	if not key then
		if fx then
			give(fx)
		end
		return
	end
	if fx and fx:GetAttribute("Key") == key then
		return
	end
	fx = fx or take()
	fx:SetAttribute("Key", key)
	fx.Color = ColorSequence.new(GLINT[key])
	fx.Rate = rateFor(key)
	active[fx] = key
	fx.Parent = part
end

-- a part about to be destroyed hands its emitter back first
function Visuals.release(part)
	local fx = part:FindFirstChild("MutFx")
	if fx then
		give(fx)
	end
end

function Visuals.setReduced(on)
	on = on == true
	if Visuals.reducedFx == on then
		return
	end
	Visuals.reducedFx = on
	for fx, key in active do
		fx.Rate = rateFor(key)
	end
end

function Visuals.poolSize()
	return #pool
end

-- the parts Models/Crop made gold carry Gold = true; the one with the light is the crop's Main part
local function goldParts(model)
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Gold") then
			table.insert(out, d)
		end
	end
	return out
end

function Visuals.goldenReveal(model)
	local parts = goldParts(model)
	local main = parts[1]
	for _, p in parts do
		if p:GetAttribute("Main") then
			main = p
		end
	end
	if not main then
		return nil
	end
	local burst = Instance.new("ParticleEmitter")
	burst.Name = "RevealBurst"
	burst.Texture = Visuals.SPARKLE
	burst.Color = ColorSequence.new(Visuals.GOLD_LIGHT)
	burst.LightEmission = 1
	burst.Lifetime = NumberRange.new(0.6, 1.2)
	burst.Speed = NumberRange.new(6, 11)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Size = NumberSequence.new(0.45)
	burst.Rate = 0
	burst.Parent = main
	pcall(function()
		burst:Emit(if Visuals.reducedFx then 10 else 40)
	end)
	local ring = Instance.new("Part")
	ring.Name = "RevealRing"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Material = Enum.Material.Neon
	ring.Color = Visuals.GOLD_LIGHT
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.1, 1, 1)
	ring.CFrame = CFrame.new(main.Position - Vector3.new(0, main.Size.Y / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Transparency = 0.2
	ring.Parent = model
	local light = main:FindFirstChildOfClass("PointLight")
	local brightness = light and light.Brightness
	local targets = {}
	for _, p in parts do
		targets[p] = p.Color
		p.Color = p:GetAttribute("BaseColor") or p.Color
	end
	task.spawn(function()
		local steps = 10
		for i = 1, steps do
			local t = i / steps
			for p, gold in targets do
				p.Color = (p:GetAttribute("BaseColor") or gold):Lerp(gold, t)
			end
			local d = 1 + 9 * t
			ring.Size = Vector3.new(0.1, d, d)
			ring.Transparency = 0.2 + 0.8 * t
			if light then
				light.Brightness = brightness + 6 * math.sin(t * math.pi)
			end
			task.wait(0.05)
		end
		if light then
			light.Brightness = brightness
		end
		ring:Destroy()
		task.wait(1.5)
		burst:Destroy()
	end)
	model:SetAttribute("Revealed", (model:GetAttribute("Revealed") or 0) + 1)
	return burst, ring
end

-- grown boosted seconds now, from a tile part's attributes (the server stays authoritative)
function Visuals.grownNow(part, now)
	local grown = part:GetAttribute("Grown")
	if not grown then
		return nil
	end
	local rate = part:GetAttribute("Rate") or 1
	local at = part:GetAttribute("At") or now
	return math.min(part:GetAttribute("GrowSec"), grown + math.max(0, now - at) * rate)
end

return Visuals
