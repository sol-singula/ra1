--[[
The Block Party sunflower (Game Artist build-spec/03-sunflower.md, GA-03), shared by the street (StreetBuilder,
BlockPartyService, SunflowerController) and the capture stage.

The server builds the Model with only Stem (the Water prompt and the range centre, invisible) and the Origin
attribute (the ground under the flower, front = -Z). The art is 38 SmoothPlastic parts built under that Model
(on the client by SunflowerController, on the capture stage by CaptureService): Root, StemBase, Stem1-4, LeafL1/L2,
LeafR1/R2, HeadPivot (Disc, SeedDot1-8, Petal1-18, the FxBloom attachment). One set of parts is posed between the
four stages (drooping / perking / standing / bloom) from Config.SunflowerVisuals.poses: the stem segments hinge one
on the next, the leaves ride their segment and tip down, the head sits on top of Stem4 and nods its face down, the
petals cup closed over the face.

  Sunflower.build(parent, cf) -> Model "Sunflower" (Stem, Origin)
  Sunflower.buildArt(model)          the 38 art parts (once), posed bloom; PrimaryPart = Root
  Sunflower.pose(stage) -> params    a stage's pose; Sunflower.wiltPose(alpha) the wilt alpha of the way to drooping
  Sunflower.mix(a, b, t) -> params   t of the way from a to b (t may pass 1 for the Back ease; colours clamp)
  Sunflower.apply(model, params)     the parts' CFrames and colours
  Sunflower.setPose(model, stage)    apply(pose(stage)) at once; the Pose attribute
  Sunflower.setFar(model, far)       the LOD: SeedDots and every other petal hidden
  Sunflower.bloomFx(model, weather, opts) -> fx   petal pop + burst (+ the column Beam and the flash light unless
                                     opts.reduced); opts.hold keeps the column up (capture stills)
  Sunflower.stepFx(fx, t) / clearFx(model)
  Sunflower.thirsty(model) -> BillboardGui "Thirsty" on HeadPivot (hidden)
  Sunflower.parts(model) -> { name = part }
]]
local Config = require(script.Parent.Parent.Config)
local Kit = require(script.Parent.Kit)

local Sunflower = {}

local SV = Config.SunflowerVisuals
local rad = math.rad
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- Kit.cylinder's stand-up turn
-- a petal wedge's axes in the rim frame: thickness along the disc's axis, width around the rim, the tip (-Z) out
local PETAL_AXES = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0))

local COLOURS = { "petal", "disc", "seed", "stem", "leafTop", "leafUnder" }

local function v3(t)
	return Vector3.new(t[1], t[2], t[3])
end

local function angles(t)
	return if t then CFrame.Angles(rad(t[1]), rad(t[2]), rad(t[3])) else CFrame.new()
end

local SPEC = {}
for _, p in SV.parts do
	SPEC[p.name] = p
end

local art = setmetatable({}, { __mode = "k" }) -- [model] = { name = part }

function Sunflower.build(parent, cf)
	local model = Instance.new("Model")
	model.Name = "Sunflower"
	local stem = Kit.cylinder(model, "Stem", 14, 1.1, cf * CFrame.new(0, 7, 0), Color3.fromHex("#5BC236"))
	stem.Transparency = 1 -- the art is the look; the Stem is the prompt and the range centre
	stem.CanQuery = true -- the Water prompt sits on it
	model.PrimaryPart = stem
	model:SetAttribute("Origin", cf)
	model.Parent = parent
	return model
end

function Sunflower.parts(model)
	local refs = art[model]
	if refs then
		return refs
	end
	local root = model:FindFirstChild("Root")
	if not root then
		return nil
	end
	refs = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Stem" then
			refs[d.Name] = d
		end
	end
	art[model] = refs
	return refs
end

function Sunflower.buildArt(model)
	local existing = Sunflower.parts(model)
	if existing then
		return existing
	end
	local O = model:GetAttribute("Origin") or CFrame.new()
	local refs = {}
	for _, p in SV.parts do
		local cf = O * CFrame.new(v3(p.offset)) * angles(p.rot)
		local colour = Color3.fromHex(p.hex)
		local part
		if p.shape == "cylV" then
			part = Kit.cylinder(model, p.name, p.size[1], p.size[2], cf, colour)
		elseif p.shape == "wedge" then
			part = Kit.wedge(model, p.name, v3(p.size), cf, colour)
		else
			part = Kit.part(model, p.name, v3(p.size), cf, colour)
		end
		part.Transparency = p.transparency or 0
		part.CastShadow = p.shadow == true
		refs[p.name] = part
	end
	local pivot = refs.HeadPivot
	local h = SV.head
	refs.Disc = Kit.cylinder(pivot, "Disc", h.disc.size[1], h.disc.size[2], CFrame.new(), Color3.fromHex(h.disc.hex))
	for i = 1, h.seeds.count do
		refs["SeedDot" .. i] =
			Kit.sphere(pivot, "SeedDot" .. i, h.seeds.size, CFrame.new(), Color3.fromHex(h.seeds.hex))
	end
	for i = 1, h.petals.count do
		refs["Petal" .. i] =
			Kit.wedge(pivot, "Petal" .. i, v3(h.petals.size), CFrame.new(), Color3.fromHex(h.petals.hex))
	end
	for _, d in pivot:GetChildren() do
		d.CastShadow = false
	end
	local fx = Instance.new("Attachment")
	fx.Name = "FxBloom"
	fx.Position = v3(h.fxAt)
	fx.Parent = pivot
	art[model] = refs
	model.PrimaryPart = refs.Root
	Sunflower.setPose(model, "bloom")
	return refs
end

-- poses ------------------------------------------------------------------------------------------------------------

local function params(spec)
	local out = { tilt = table.clone(spec.tilt), head = spec.head, cup = spec.cup, leaf = spec.leaf }
	for _, key in COLOURS do
		out[key] = Color3.fromHex(spec[key])
	end
	return out
end

function Sunflower.pose(stage)
	return params(SV.poses[stage] or SV.poses.drooping)
end

function Sunflower.mix(a, b, t)
	local c = math.clamp(t, 0, 1)
	local out = { tilt = {} }
	for i = 1, 4 do
		out.tilt[i] = a.tilt[i] + (b.tilt[i] - a.tilt[i]) * t
	end
	for _, key in { "head", "cup", "leaf" } do
		out[key] = a[key] + (b[key] - a[key]) * t
	end
	for _, key in COLOURS do
		out[key] = a[key]:Lerp(b[key], c)
	end
	return out
end

-- section 3.4: bloom to drooping, linearly; the petals toward the deep-wilt colour
function Sunflower.wiltPose(alpha)
	local p = Sunflower.mix(Sunflower.pose("bloom"), Sunflower.pose("drooping"), math.clamp(alpha, 0, 1))
	p.petal = Color3.fromHex(SV.poses.bloom.petal):Lerp(Color3.fromHex(SV.wilt.petal), math.clamp(alpha, 0, 1))
	return p
end

function Sunflower.apply(model, p)
	local refs = Sunflower.parts(model)
	if not refs then
		return
	end
	local O = model:GetAttribute("Origin") or CFrame.new()
	-- the stem: each segment hinges at the top of the one below
	local joint = O * CFrame.new(0, SV.stemBaseTop, 0)
	local frames = {}
	for i, name in SV.stems do
		local len = SPEC[name].size[1]
		local hinge = joint * CFrame.Angles(rad(p.tilt[i]), 0, 0)
		frames[name] = hinge * CFrame.new(0, len / 2, 0)
		refs[name].CFrame = frames[name] * UPRIGHT
		refs[name].Color = p.stem
		joint = hinge * CFrame.new(0, len, 0)
	end
	-- the leaves ride their segment, then tip down about their stem end
	for leaf, stem in SV.stemOf do
		local spec = SPEC[leaf]
		local rest = O * CFrame.new(v3(spec.offset)) * angles(spec.rot)
		local seg = O * CFrame.new(v3(SPEC[stem].offset))
		local half = spec.size[3] / 2
		local cf = frames[stem] * seg:ToObjectSpace(rest)
		refs[leaf].CFrame = cf * CFrame.new(0, 0, half) * CFrame.Angles(-rad(p.leaf), 0, 0) * CFrame.new(0, 0, -half)
		refs[leaf].Color = p[SV.leafTone[leaf]]
	end
	-- the head on Stem4's top, nodding its face (-Z) toward the ground
	local h = SV.head
	local top = (joint * CFrame.new(0, SV.headGap, 0)).Position
	local head = CFrame.new(top) * O.Rotation * CFrame.Angles(-rad(p.head), 0, 0)
	refs.HeadPivot.CFrame = head
	local disc = head * CFrame.new(0, h.discAt, 0)
	refs.Disc.CFrame = disc * CFrame.Angles(rad(90), 0, 0) * UPRIGHT
	refs.Disc.Color = p.disc
	local ring = h.seeds.count - 1
	for i = 1, h.seeds.count do
		local at = Vector3.new(0, 0, h.seeds.z)
		if i <= ring then
			local a = rad(360 * (i - 1) / ring)
			at = Vector3.new(math.cos(a) * h.seeds.ring, math.sin(a) * h.seeds.ring, h.seeds.z)
		end
		refs["SeedDot" .. i].CFrame = disc * CFrame.new(at)
		refs["SeedDot" .. i].Color = p.seed
	end
	local len = h.petals.size[3]
	for i = 1, h.petals.count do
		local base = disc
			* CFrame.Angles(0, 0, rad((i - 1) * h.petals.step))
			* CFrame.new(0, h.petals.rim, 0)
			* CFrame.Angles(rad(h.petals.cup + p.cup), 0, 0)
		refs["Petal" .. i].CFrame = base * CFrame.new(0, len / 2, 0) * PETAL_AXES
		refs["Petal" .. i].Color = p.petal
	end
end

function Sunflower.setPose(model, stage)
	Sunflower.apply(model, Sunflower.pose(stage))
	model:SetAttribute("Pose", stage)
end

-- section 6: far away, the seed dots and every other petal (9 stay)
function Sunflower.setFar(model, far)
	local refs = Sunflower.parts(model)
	if not refs then
		return
	end
	for i = 1, SV.head.seeds.count do
		refs["SeedDot" .. i].Transparency = if far then 1 else 0
	end
	for i = 2, SV.head.petals.count, 2 do
		refs["Petal" .. i].Transparency = if far then 1 else 0
	end
	model:SetAttribute("Far", far == true)
end

-- the bloom VFX (section 4) ----------------------------------------------------------------------------------------

local function numbers(points)
	local keys = {}
	for _, kp in points do
		table.insert(keys, NumberSequenceKeypoint.new(kp[1], kp[2]))
	end
	return NumberSequence.new(keys)
end

local function emitter(parent, name, spec, colour0, colour1)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Rate = 0
	e.Color = ColorSequence.new(colour0, colour1)
	e.Lifetime = NumberRange.new(spec.lifetime[1], spec.lifetime[2])
	e.Speed = NumberRange.new(spec.speed[1], spec.speed[2])
	e.Size = numbers(spec.size)
	e.Transparency = numbers(spec.transparency)
	e.LightEmission = spec.lightEmission
	e.LightInfluence = 0
	e.Parent = parent
	return e
end

function Sunflower.columnColour(weather)
	return Color3.fromHex(SV.fx.colours[weather] or SV.fx.colours.rain)
end

function Sunflower.clearFx(model)
	local refs = Sunflower.parts(model)
	if not refs then
		return
	end
	local pivot = refs.HeadPivot
	for _, name in { "PetalPop", "Burst", "Column", "BloomLight", "BeamBottom", "BeamTop" } do
		for _, holder in { pivot, pivot:FindFirstChild("FxBloom") } do
			local d = holder and holder:FindFirstChild(name)
			if d then
				d:Destroy()
			end
		end
	end
end

function Sunflower.bloomFx(model, weather, opts)
	opts = opts or {}
	local refs = Sunflower.parts(model)
	if not refs then
		return nil
	end
	Sunflower.clearFx(model)
	local fx, pivot = SV.fx, refs.HeadPivot
	local at = pivot.FxBloom
	local colour = Sunflower.columnColour(weather)
	local scale = if opts.reduced then fx.reducedEmit else 1
	local pop = emitter(at, "PetalPop", fx.pop, Color3.fromHex(fx.pop.colours[1]), Color3.fromHex(fx.pop.colours[2]))
	pop.Shape = Enum.ParticleEmitterShape.Sphere
	pop.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	pop.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	pop.Squash = NumberSequence.new(fx.pop.squash)
	local burst = emitter(at, "Burst", fx.burst, colour, colour)
	burst.SpreadAngle = Vector2.new(fx.burst.spread[1], fx.burst.spread[2])
	burst.Acceleration = v3(fx.burst.acceleration)
	pop:Emit(math.floor(fx.pop.emit * scale))
	burst:Emit(math.floor(fx.burst.emit * scale))
	local handle = { model = model, colour = colour }
	if not opts.reduced then
		local bottom = Instance.new("Attachment")
		bottom.Name = "BeamBottom"
		bottom.Position = Vector3.new(0, fx.beam.bottom, 0)
		bottom.Parent = pivot
		local top = Instance.new("Attachment")
		top.Name = "BeamTop"
		top.Position = Vector3.new(0, fx.beam.top, 0)
		top.Parent = pivot
		local beam = Instance.new("Beam")
		beam.Name = "Column"
		beam.Attachment0 = bottom
		beam.Attachment1 = top
		beam.Color = ColorSequence.new(colour)
		beam.Width0 = fx.beam.width[1]
		beam.Width1 = fx.beam.width[2]
		beam.Transparency = numbers(fx.beam.transparency)
		beam.LightEmission = fx.beam.lightEmission
		beam.LightInfluence = 0
		beam.FaceCamera = true
		beam.Segments = fx.beam.segments
		beam.Parent = at
		local light = Instance.new("PointLight")
		light.Name = "BloomLight"
		light.Color = colour
		light.Brightness = fx.light.brightness
		light.Range = fx.light.range
		light.Shadows = false
		light.Parent = pivot
		handle.beam, handle.light = beam, light
	end
	handle.hold = opts.hold == true
	return handle
end

-- t seconds into the bloom: the column fades to fully transparent and the light to 0 over fx.sec
function Sunflower.stepFx(handle, t)
	if not handle or handle.hold then
		return
	end
	local a = math.clamp(t / SV.fx.sec, 0, 1)
	if handle.beam then
		local points = {}
		for _, kp in SV.fx.beam.transparency do
			table.insert(points, { kp[1], kp[2] + (1 - kp[2]) * a })
		end
		handle.beam.Transparency = numbers(points)
	end
	if handle.light then
		handle.light.Brightness = SV.fx.light.brightness * (1 - a)
	end
end

-- the thirsty icon (section 5) -------------------------------------------------------------------------------------

function Sunflower.thirsty(model)
	local refs = Sunflower.parts(model)
	if not refs then
		return nil
	end
	local pivot = refs.HeadPivot
	local existing = pivot:FindFirstChild("Thirsty")
	if existing then
		return existing
	end
	local t = SV.thirsty
	local gui = Instance.new("BillboardGui")
	gui.Name = "Thirsty"
	gui.Adornee = pivot
	gui.Size = UDim2.fromOffset(t.size, t.size)
	gui.StudsOffset = Vector3.new(0, t.offset, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = t.maxDistance
	gui.Enabled = false
	local frame = Instance.new("Frame")
	frame.Name = "Icon"
	frame.Size = UDim2.fromOffset(t.size, t.size)
	frame.BackgroundTransparency = 1
	frame.Parent = gui
	local circle = Instance.new("ImageLabel")
	circle.Name = "Circle"
	circle.Size = UDim2.fromScale(1, 1)
	circle.Image = ""
	circle.BackgroundColor3 = Color3.fromHex(t.hex)
	circle.BackgroundTransparency = 0
	circle.BorderSizePixel = 0
	circle.Parent = frame
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = circle
	local mark = Instance.new("TextLabel")
	mark.Name = "Mark"
	mark.Size = UDim2.fromScale(1, 1)
	mark.BackgroundTransparency = 1
	mark.Text = "!"
	mark.TextColor3 = Color3.new(1, 1, 1)
	mark.Font = Enum.Font.GothamBlack
	mark.TextScaled = true
	mark.Parent = circle
	gui.Parent = pivot
	return gui
end

return Sunflower
