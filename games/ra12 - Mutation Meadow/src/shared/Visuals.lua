-- How crops look (the client's world and the capture stage): a colour per seed (the fruit), the leaf colour while it
-- grows, and the mutation sparkles
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

-- mutation colours: the Backpack frame, the world sparkles
Visuals.MUT = {
	wet = Color3.fromRGB(80, 170, 255),
	golden = Color3.fromRGB(255, 200, 40),
	wetgolden = Color3.fromRGB(150, 255, 220),
}

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
	fx.Color = ColorSequence.new(Visuals.MUT[key])
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
