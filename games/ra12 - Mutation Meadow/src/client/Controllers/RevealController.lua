--[[
The mutation reveal (Game Artist build-spec/04-reveal.md): a timed 1.5 s client sequence when a crop turns Wet,
Golden or Wet+Golden. It plays for the Mutation remote (a tile on your plot) and when TileController sees a tile's
Muts gain a mutation (any plot: within Config.Art.reveal.rangeStuds of your character, or yours). The crop wears its
new look first (Models/Crop.applyMutation); the reveal only sells the change. Config.Art.reveal holds the numbers.

  0.00  soil puff (Emit 14; 10 for Wet+Golden so a reveal stays within 30), the Highlight, the FOV punch (-4, back
        over 0.3 s Quad Out; never CameraOffset), exactly one Sound (the key's cue from Config.Art.revealSounds)
  0.05  the burst on Fx / FxAnchor: Wet droplets 16, Golden stars 12, Wet+Golden 10 + 8 (gone after 1.0 s)
  0.10  Wet / Wet+Golden: the flat Glass splash ring grows and fades over 0.45 s
  0.15  Golden / Wet+Golden: the #FFF1A8 shine bar sweeps up the largest fruit over 0.6 s (Linear)
  0.80  the Highlight fades over 0.5 s
  1.50  cleanup: the Highlight, the ring, the bar, the burst and puff emitters, the Sound (the idle MutFx / MutDrops
        of 02-mutations keep running)

reducedFx or Settings.sfx off: no punch, Sound, Highlight, ring or shine; the soil puff and the burst at half count.
At most Config.Art.reveal.concurrent sequences run (the nearest); a new mutation on a tile that is mid-reveal
cancels the old sequence (its final look stays) and starts again from 0. A repeat of the same key on a tile that is
still revealing is ignored (the remote and the tile attribute both report the same mutation).

  RevealController.play(model, key, opts?) -> seq | nil   opts.own (your plot), opts.force (skip the range check)
  RevealController.active() -> { seq }   (tests)  /  RevealController.step(dt)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local CropModel = require(ReplicatedStorage.Shared.Models.Crop)
local MutationMath = require(ReplicatedStorage.Shared.MutationMath)
local Net = require(ReplicatedStorage.Shared.Net)
local Visuals = require(ReplicatedStorage.Shared.Visuals)
local ClientState = require(script.Parent.Parent.ClientState)

local RevealController = {}

local ART = Config.Art
local R = ART.reveal

local running = {} -- [seq] = true
local dead = setmetatable({}, { __mode = "k" }) -- [instance] = true once this destroyed it

local function kill(inst)
	if inst and not dead[inst] then
		dead[inst] = true
		inst:Destroy()
	end
end

local function attached(inst)
	local ok, parent = pcall(function()
		return inst.Parent
	end)
	return ok and parent ~= nil
end
local punch -- { base, t }

local KEYS = { wet = true, golden = true, wetgolden = true }

function RevealController.active()
	local out = {}
	for seq in running do
		table.insert(out, seq)
	end
	return out
end

local function quadOut(x)
	return 1 - (1 - x) * (1 - x)
end

local function numbers(points)
	local keys = {}
	for _, kp in points do
		table.insert(keys, NumberSequenceKeypoint.new(kp[1], kp[2]))
	end
	return NumberSequence.new(keys)
end

local function seqOf(v)
	return if type(v) == "table" then numbers(v) else NumberSequence.new(v)
end

local function emitter(parent, name, spec)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Rate = 0
	e.Color = ColorSequence.new(Color3.fromHex(spec.colours[1]), Color3.fromHex(spec.colours[2]))
	e.Lifetime = NumberRange.new(spec.lifetime[1], spec.lifetime[2])
	e.Speed = NumberRange.new(spec.speed[1], spec.speed[2])
	e.SpreadAngle = Vector2.new(spec.spread[1], spec.spread[2])
	e.Acceleration = Vector3.new(spec.acceleration[1], spec.acceleration[2], spec.acceleration[3])
	e.Size = numbers(spec.size)
	e.Squash = seqOf(spec.squash)
	e.Transparency = numbers(spec.transparency)
	e.LightEmission = spec.lightEmission
	e.Enabled = false
	if spec.orientation then
		e.Orientation = Enum.ParticleOrientation[spec.orientation]
	end
	if spec.rotSpeed then
		e.RotSpeed = NumberRange.new(spec.rotSpeed[1], spec.rotSpeed[2])
	end
	e.Parent = parent
	return e
end

local function emit(e, n)
	pcall(function()
		e:Emit(n)
	end)
end

local function character()
	local c = Players.LocalPlayer and Players.LocalPlayer.Character
	local root = c and c:FindFirstChild("HumanoidRootPart")
	return root and root.Position
end

local function centreOf(model)
	local main = CropModel.main(model) or model:FindFirstChild("Root")
	return main and main.Position
end

local function distance(model)
	local at, me = centreOf(model), character()
	if not at or not me then
		return math.huge
	end
	return (at - me).Magnitude
end

-- the fruit part with the most volume (the shine bar rides it)
local function largestFruit(model)
	local best, size = nil, -1
	for _, p in CropModel.fruit(model) do
		local v = p.Size.X * p.Size.Y * p.Size.Z
		if v > size then
			best, size = p, v
		end
	end
	return best
end

-- a part's width (X) and height (Y) along the crop's own axes, so a turned cylinder fruit still reads right
local function extent(part, frame)
	local r = frame.Rotation:Inverse() * part.CFrame.Rotation
	local s = part.Size
	local function along(i)
		return math.abs(r.XVector[i]) * s.X + math.abs(r.YVector[i]) * s.Y + math.abs(r.ZVector[i]) * s.Z
	end
	return along("X"), along("Y")
end

local function sfxOn()
	return ClientState.get("settings", "sfx") ~= false
end

local function cleanup(seq)
	for _, inst in seq.temp do
		kill(inst)
	end
	seq.temp = {}
	running[seq] = nil
	seq.done = true
end

-- the camera punch: one at a time (it always springs back to the FOV it found)
local function startPunch()
	local camera = workspace.CurrentCamera
	local ok, fov = pcall(function()
		return camera.FieldOfView
	end)
	if not ok or type(fov) ~= "number" then
		return
	end
	local base = if punch then punch.base else fov
	punch = { base = base, t = 0 }
	camera.FieldOfView = base + R.punch.fov
end

local function stepPunch(dt)
	if not punch then
		return
	end
	punch.t += dt
	local x = math.clamp(punch.t / R.punch.sec, 0, 1)
	workspace.CurrentCamera.FieldOfView = punch.base + R.punch.fov * (1 - quadOut(x))
	if x >= 1 then
		punch = nil
	end
end

local function begin(seq)
	local model, key = seq.model, seq.key
	if model:GetAttribute("Muts") ~= key then
		CropModel.applyMutation(model, key)
	end
	local root = model:FindFirstChild("Root") or CropModel.main(model)
	seq.host = CropModel.fxHost(model) or CropModel.anchor(model) or root
	-- 0.00: the soil puff on a flat disc at the ground under the tile
	local origin = model:GetAttribute("Origin") or (root and root.CFrame)
	if root and origin then
		local at = Instance.new("Attachment")
		at.Name = "RevealSoilAt"
		at.WorldCFrame = CFrame.new(origin.Position)
		at.Parent = root
		table.insert(seq.temp, at)
		local soil = emitter(at, "RevealSoil", R.soil)
		soil.Shape = Enum.ParticleEmitterShape.Disc
		soil.EmissionDirection = Enum.NormalId.Top
		local n = R.soil.emit
		if n + (R.droplet.emit[key] or 0) + (R.star.emit[key] or 0) > R.maxEmit then
			n = R.soilPressure
		end
		seq.emitted += math.floor(n * seq.scale)
		emit(soil, math.floor(n * seq.scale))
	end
	if seq.reduced then
		return
	end
	local h = R.highlight
	local highlight = Instance.new("Highlight")
	highlight.Name = "RevealHighlight"
	highlight.Adornee = model
	highlight.FillColor = Color3.fromHex(h.fill[key])
	highlight.OutlineColor = Color3.fromHex(h.outline[key])
	highlight.FillTransparency = h.fillTransparency
	highlight.OutlineTransparency = h.outlineTransparency
	highlight.Parent = model
	seq.highlight = highlight
	table.insert(seq.temp, highlight)
	startPunch()
	-- exactly one Sound: the key's cue (the burst cue only stands in for a key without one)
	local soundHost = if seq.host and seq.host:IsA("BasePart") then seq.host else root
	if soundHost then
		local prior = soundHost:FindFirstChild("RevealSound")
		if prior then
			kill(prior) -- one reveal sound per tile
		end
		local sound = Instance.new("Sound")
		sound.Name = "RevealSound"
		sound.SoundId = ART.revealSounds[key] or ART.revealSounds.burst
		sound.Volume = R.sound.volume
		sound.RollOffMaxDistance = R.sound.maxDistance
		sound.Parent = soundHost
		table.insert(seq.temp, sound)
		pcall(function()
			sound:Play()
		end)
		seq.sound = sound
	end
end

local function burst(seq)
	local key, host = seq.key, seq.host
	if not host then
		return
	end
	for _, kind in { "droplet", "star" } do
		local spec = R[kind]
		local n = spec.emit[key]
		if n then
			local e = emitter(host, if kind == "droplet" then "RevealDroplets" else "RevealStars", spec)
			table.insert(seq.temp, e)
			table.insert(seq.bursts, e)
			seq.emitted += math.floor(n * seq.scale)
			emit(e, math.floor(n * seq.scale))
		end
	end
end

local function ring(seq)
	local origin = seq.model:GetAttribute("Origin")
	if not origin then
		return
	end
	local spec = R.ring
	local p = Instance.new("Part")
	p.Name = "RevealRing"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Shape = Enum.PartType.Cylinder
	p.Material = Enum.Material.Glass
	p.Color = Color3.fromHex(spec.hex)
	p.Reflectance = spec.reflectance
	p.Transparency = spec.transparency
	p.Size = Vector3.new(spec.from[1], spec.from[2], spec.from[3])
	-- a Roblox cylinder runs along X: turned so it lies flat on the soil
	p.CFrame = CFrame.new(origin.Position + Vector3.new(0, spec.from[1] / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	p.Parent = seq.model
	seq.ring = p
	table.insert(seq.temp, p)
end

local function shine(seq)
	local fruit = largestFruit(seq.model)
	if not fruit then
		return
	end
	local frame = seq.model:GetAttribute("Origin") or CFrame.new()
	local fx, fy = extent(fruit, frame)
	local spec = R.shine
	local bar = Instance.new("Part")
	bar.Name = "RevealShine"
	bar.Anchored = true
	bar.CanCollide = false
	bar.CanQuery = false
	bar.CanTouch = false
	bar.CastShadow = false
	bar.Material = Enum.Material.SmoothPlastic
	bar.Color = Color3.fromHex(spec.hex)
	bar.Transparency = spec.transparency
	bar.Size = Vector3.new(fx * spec.widthScale, spec.height, spec.depth)
	bar.Parent = fruit
	seq.bar = { part = bar, fruit = fruit, rot = frame.Rotation, fy = fy, t = 0 }
	table.insert(seq.temp, bar)
	seq.stepBar(0)
end

local function newSeq(model, key, opts)
	local reduced = Visuals.reducedFx == true or not sfxOn()
	local seq = {
		model = model,
		key = key,
		t = 0,
		own = opts.own == true,
		reduced = reduced,
		scale = if reduced then R.reducedEmit else 1,
		temp = {},
		bursts = {},
		emitted = 0,
		fired = {},
		distance = if opts.own or opts.force then 0 else distance(model),
	}
	function seq.stepBar(dt)
		local b = seq.bar
		if not b or dead[b.part] then
			return
		end
		b.t += dt
		local x = math.clamp(b.t / R.shine.sec, 0, 1)
		local y = (-R.shine.travel + 2 * R.shine.travel * x) * b.fy
		b.part.CFrame = CFrame.new(b.fruit.Position + Vector3.new(0, y, 0)) * b.rot
		b.part.Transparency = R.shine.transparency + (1 - R.shine.transparency) * x
		if x >= 1 then
			kill(b.part)
		end
	end
	return seq
end

function RevealController.play(model, key, opts)
	opts = opts or {}
	if not model or not KEYS[key] then
		return nil
	end
	local d = if opts.own or opts.force then 0 else distance(model)
	if d > R.rangeStuds then
		return nil
	end
	-- one per tile: the same key again is the same mutation; a new key cancels and restarts
	for seq in running do
		if seq.model == model or seq.model.Name == model.Name then
			if seq.key == key then
				return seq
			end
			cleanup(seq)
		end
	end
	-- the nearest two
	local list = RevealController.active()
	if #list >= R.concurrent then
		table.sort(list, function(a, b)
			return a.distance > b.distance
		end)
		if list[1].distance <= d then
			if model:GetAttribute("Muts") ~= key then
				CropModel.applyMutation(model, key) -- the look still changes; only the show is dropped
			end
			return nil
		end
		cleanup(list[1])
	end
	local seq = newSeq(model, key, opts)
	running[seq] = true
	model:SetAttribute("Revealed", (model:GetAttribute("Revealed") or 0) + 1)
	model:SetAttribute("RevealKey", key)
	begin(seq)
	RevealController.step(0)
	return seq
end

local function stepSeq(seq, dt)
	if not attached(seq.model) then
		cleanup(seq)
		return
	end
	seq.t += dt
	local t, key = seq.t, seq.key
	if not seq.fired.burst and t >= R.burstAt then
		seq.fired.burst = true
		burst(seq)
	end
	if not seq.reduced then
		if not seq.fired.ring and t >= R.ring.at and (key == "wet" or key == "wetgolden") then
			seq.fired.ring = true
			ring(seq)
		end
		if not seq.fired.shine and t >= R.shine.at and (key == "golden" or key == "wetgolden") then
			seq.fired.shine = true
			shine(seq)
		elseif seq.bar then
			seq.stepBar(dt)
		end
		if seq.ring and not dead[seq.ring] then
			local x = math.clamp((t - R.ring.at) / R.ring.sec, 0, 1)
			local e = quadOut(x)
			local from, to = R.ring.from, R.ring.to
			seq.ring.Size = Vector3.new(from[1], from[2] + (to[2] - from[2]) * e, from[3] + (to[3] - from[3]) * e)
			seq.ring.Transparency = R.ring.transparency + (1 - R.ring.transparency) * e
			if x >= 1 then
				kill(seq.ring)
			end
		end
		local h = R.highlight
		if seq.highlight and t >= h.fadeAt then
			local x = math.clamp((t - h.fadeAt) / h.fadeSec, 0, 1)
			seq.highlight.FillTransparency = h.fillTransparency + (1 - h.fillTransparency) * x
			seq.highlight.OutlineTransparency = h.outlineTransparency + (1 - h.outlineTransparency) * x
		end
	end
	if not seq.fired.bursts and t >= R.burstAt + R.burstLifeSec then
		seq.fired.bursts = true
		for _, e in seq.bursts do
			kill(e)
		end
	end
	if t >= R.cleanupAt then
		cleanup(seq)
	end
end

function RevealController.step(dt)
	for seq in table.clone(running) do
		stepSeq(seq, dt)
	end
	stepPunch(dt)
end

local function myPlot()
	local street = workspace:FindFirstChild("Street")
	local plots = street and street:FindFirstChild("Plots")
	local me = Players.LocalPlayer
	for _, plot in if plots then plots:GetChildren() else {} do
		if me and plot:GetAttribute("OwnerId") == me.UserId then
			return plot
		end
	end
	return nil
end

-- the Mutation remote: a tile on your plot; its key is the tile's mutations plus the new one
local function onMutation(data)
	if type(data) ~= "table" or type(data.tile) ~= "string" or type(data.mut) ~= "string" then
		return
	end
	local plot = myPlot()
	local folder = workspace:FindFirstChild("ClientCrops")
	local model = plot and folder and folder:FindFirstChild(plot.Name .. "_" .. data.tile)
	if not model then
		return
	end
	local set = {}
	local had = model:GetAttribute("Muts")
	if had == "wet" or had == "wetgolden" then
		set.wet = true
	end
	if had == "golden" or had == "wetgolden" then
		set.golden = true
	end
	set[data.mut] = true
	RevealController.play(model, MutationMath.key(set), { own = true })
end

function RevealController:Start()
	Net.on("Mutation", onMutation)
	RunService.Heartbeat:Connect(function(dt)
		RevealController.step(dt)
	end)
end

return RevealController
