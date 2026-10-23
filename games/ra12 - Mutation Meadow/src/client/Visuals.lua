-- How crops look on the client: a colour per seed (the crop's fruit) and the leaf colour while it grows
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

-- sparkles on a part for a mutation key ("wet" | "golden" | "wetgolden" | nil clears them)
function Visuals.mutationFx(part, key)
	local fx = part:FindFirstChild("MutFx")
	if not key then
		if fx then
			fx:Destroy()
		end
		return
	end
	if fx and fx:GetAttribute("Key") == key then
		return
	end
	if fx then
		fx:Destroy()
	end
	fx = Instance.new("ParticleEmitter")
	fx.Name = "MutFx"
	fx:SetAttribute("Key", key)
	fx.Color = ColorSequence.new(Visuals.MUT[key])
	fx.LightEmission = 0.8
	fx.Rate = if key == "wetgolden" then 14 else 8
	fx.Lifetime = NumberRange.new(0.8, 1.4)
	fx.Speed = NumberRange.new(1, 2)
	fx.Size = NumberSequence.new(0.25)
	fx.Parent = part
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
