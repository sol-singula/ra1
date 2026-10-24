--[[
How crops look (the client's world and the capture stage, through Models/Crop): a colour per seed (the fruit), the
leaf colour while it grows, the Golden colours and the pooled mutation emitters. The mutation numbers are
Config.MutationVisuals (Game Artist build-spec/02-mutations.md); the mutation reveal is RevealController
(build-spec/04-reveal.md).

  Visuals.mutationFx(host, key, opts?)   the pooled emitters for a mutation key (nil clears them):
      golden      MutFx glint on host (Rate 0.35)
      wet         MutFx drip on opts.drip (or host) (Rate 3, large fruit 4)
      wetgolden   MutFx glint on host (Rate 0.25) + MutDrops drip on opts.drip (or host)
    opts = { drip = Instance, large = bool }; reducedFx cuts every rate to REDUCED_RATE
  Visuals.release(host) / setReduced(on) / poolSize() / rateOf(emitter)
  Visuals.grownNow(part, now)
]]
local Config = require(script.Parent.Config)

local MV = Config.MutationVisuals

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

-- the Golden material (GA-02 section 0): the body colour, its shade and its highlight
Visuals.GOLD = Color3.fromHex("#FFC300")
Visuals.GOLD_SHADE = Color3.fromHex("#E0A100")
Visuals.GOLD_LIGHT = Color3.fromHex("#FFF1A8")

-- mutation colours for UI (the chip fill; Wet+Golden is gold with a blue stroke, GA-02 section 4)
Visuals.MUT = {
	wet = Color3.fromHex(MV.chips.wet.fill),
	golden = Color3.fromHex(MV.chips.golden.fill),
	wetgolden = Color3.fromHex(MV.chips.wetgolden.fill),
}
-- the engine's default particle texture (GA-02: no other texture)
Visuals.SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

-- Reduced effects (Settings): particle rates are cut by REDUCED_RATE (75% fewer) and the rain sheet is off
Visuals.REDUCED_RATE = 0.25
Visuals.reducedFx = false

local active = setmetatable({}, { __mode = "k" }) -- [emitter] = its base rate, the emitters in use
local pool = {} -- free emitters, reused instead of made and destroyed (Visuals.poolSize())

local function seq(points)
	local keys = {}
	for i, p in points do
		keys[i] = NumberSequenceKeypoint.new(p[1], p[2])
	end
	return NumberSequence.new(keys)
end

local function setRate(fx)
	fx.Rate = active[fx] * (if Visuals.reducedFx then Visuals.REDUCED_RATE else 1)
end

local function take()
	local fx = table.remove(pool)
	if not fx then
		fx = Instance.new("ParticleEmitter")
		fx.Texture = Visuals.SPARKLE
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

-- GA-02 section 2.3: one small star now and then
local function glint(fx, key, large)
	local g = MV.glint
	fx.Color = ColorSequence.new(Color3.fromHex(g.colours[1]), Color3.fromHex(g.colours[2]))
	fx.LightEmission = g.lightEmission
	fx.LightInfluence = g.lightInfluence
	fx.Lifetime = NumberRange.new(g.lifetime[1], g.lifetime[2])
	fx.Speed = NumberRange.new(0)
	fx.SpreadAngle = Vector2.new(0, 0)
	fx.Size = seq({ { 0, 0 }, { 0.5, if large then g.sizeLarge else g.size }, { 1, 0 } })
	fx.Transparency = NumberSequence.new(g.transparency)
	fx.Rotation = NumberRange.new(g.rotation[1], g.rotation[2])
	fx.RotSpeed = NumberRange.new(0)
	fx.Squash = NumberSequence.new(0)
	fx.Acceleration = Vector3.zero
	fx.Drag = 0
	fx.EmissionDirection = Enum.NormalId.Top
	fx.Orientation = Enum.ParticleOrientation.FacingCamera
	fx.Shape = Enum.ParticleEmitterShape.Box
	fx.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	fx.ZOffset = g.zOffset
	fx.LockedToPart = true
	fx:SetAttribute("Mode", "glint")
	return if key == "wetgolden" then g.rateWetGolden else g.rate
end

-- GA-02 section 3.3: a tall drop falling now and then
local function drip(fx, large)
	local d = MV.drip
	fx.Color = ColorSequence.new(Color3.fromHex(d.hex))
	fx.LightEmission = d.lightEmission
	fx.LightInfluence = d.lightInfluence
	fx.Lifetime = NumberRange.new(d.lifetime[1], d.lifetime[2])
	fx.Speed = NumberRange.new(d.speed[1], d.speed[2])
	fx.SpreadAngle = Vector2.new(0, 0)
	fx.Size = seq(d.size)
	fx.Transparency = seq(d.transparency)
	fx.Rotation = NumberRange.new(0)
	fx.RotSpeed = NumberRange.new(0)
	fx.Squash = seq(d.squash)
	fx.Acceleration = Vector3.new(d.acceleration[1], d.acceleration[2], d.acceleration[3])
	fx.Drag = 0
	fx.EmissionDirection = Enum.NormalId.Bottom
	fx.Orientation = Enum.ParticleOrientation.VelocityParallel
	fx.Shape = Enum.ParticleEmitterShape.Box
	fx.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	fx.ZOffset = 0
	fx.LockedToPart = false
	fx:SetAttribute("Mode", "drip")
	return if large then d.rateLarge else d.rate
end

local SLOTS = { "MutFx", "MutDrops" }

local function releaseOn(host)
	if not host then
		return
	end
	for _, name in SLOTS do
		local fx = host:FindFirstChild(name)
		if fx then
			give(fx)
		end
	end
end

function Visuals.mutationFx(host, key, opts)
	opts = opts or {}
	local dripHost = opts.drip or host
	-- what this key wants: { host, slot name, mode }
	local want = {}
	if key == "golden" then
		want = { { host, "MutFx", "glint" } }
	elseif key == "wet" then
		want = { { dripHost, "MutFx", "drip" } }
	elseif key == "wetgolden" then
		want = { { host, "MutFx", "glint" }, { dripHost, "MutDrops", "drip" } }
	end
	-- hand back whatever this key no longer uses
	for _, h in { host, dripHost } do
		for _, name in SLOTS do
			local fx = h:FindFirstChild(name)
			local kept = false
			for _, w in want do
				kept = kept or (w[1] == h and w[2] == name)
			end
			if fx and not kept then
				give(fx)
			end
		end
	end
	for _, w in want do
		local fx = w[1]:FindFirstChild(w[2]) or take()
		fx.Name = w[2]
		active[fx] = if w[3] == "glint" then glint(fx, key, opts.large) else drip(fx, opts.large)
		fx:SetAttribute("Key", key)
		setRate(fx)
		fx.Parent = w[1]
	end
end

-- a host about to be destroyed hands its emitters back first
function Visuals.release(host)
	releaseOn(host)
end

function Visuals.rateOf(fx)
	return active[fx]
end

function Visuals.setReduced(on)
	on = on == true
	if Visuals.reducedFx == on then
		return
	end
	Visuals.reducedFx = on
	for fx in active do
		setRate(fx)
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
