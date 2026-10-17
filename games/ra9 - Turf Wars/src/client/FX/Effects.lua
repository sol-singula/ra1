--[[
The look of a hit (master plan §0, the store art): SUPERHOT white with bold neon red and blue. Client-only pieces,
all anchored parts that never collide or answer a query, moved here each frame:

  Effects.shatter(opts)          a body breaking into white and team-coloured shards that burst out along the hit's
                                 direction, with a neon flash, a ring shockwave, sparks and a short glow.
                                 opts = { pos, dir?, team, parts? (the body's parts to cut from), power?,
                                 scale? (more or fewer shards), quiet? (no flash, glow ball or rings: the kill cam's
                                 slow motion, where they'd hang in the air) }
  Effects.impact(pos, color, dir?)   an arrow landing: a pop of light, a little ring, white chips and team sparks
  Effects.explosion(pos, radius, color?)   a blast (ExplosionController owns it: this just hands it over)
  Effects.mannequin(cf, team)    a blocky stand-in body (the kill cam's replay of you), parts in a Model
  Effects.timeScale              0..1: how fast every piece here moves (the kill cam's freeze frame and slow motion)

The parts come from a pool and go back to it, and there is a cap on how many are alive at once (by the graphics
tier: GraphicsController, and always the light version on a phone), so twenty kills at once can't sink the frame
rate: near the cap a kill gets fewer shards, then only its flash, then nothing more until pieces die away.

  Effects.count()   Effects.cap()   Effects.tier()   Effects.pooled()   (tests)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Device = require(script.Parent.Parent.UI.Device)
local GraphicsController = require(script.Parent.Parent.Controllers.GraphicsController)

local Effects = { timeScale = 1 }

local rng = Random.new()
local WHITE = Color3.fromRGB(250, 250, 250)
local AWAY = CFrame.new(0, -5000, 0) -- (where a pooled part waits)
local POOL_MAX = 160 -- per shape

-- per tier: pieces alive at once, shards for one body, sparks, and whether it gets a light and a second ring
local CAPS = {
	high = { live = 360, shards = 42, sparks = 14, chips = 9, light = true, rings = 2 },
	mid = { live = 220, shards = 28, sparks = 10, chips = 7, light = true, rings = 1 },
	low = { live = 90, shards = 12, sparks = 5, chips = 4, light = false, rings = 1 },
}

local folder
local live = {} -- { part, kind, age, life, ... }
local pool = { Block = {}, Wedge = {}, Ball = {}, Cylinder = {} }
local stepping

function Effects.tier()
	if Device.isTouch() then
		return "low"
	end
	return GraphicsController.tier()
end

function Effects.cap()
	return CAPS[Effects.tier()] or CAPS.low
end

function Effects.count()
	return #live
end

function Effects.pooled()
	local n = 0
	for _, list in pool do
		n += #list
	end
	return n
end

local function getFolder()
	if not folder or not folder.Parent then
		folder = Instance.new("Folder")
		folder.Name = "Effects"
		folder.Parent = workspace
	end
	return folder
end

local function take(shape, size, color, neon)
	local list = pool[shape]
	local p = table.remove(list)
	if not p or not p.Parent then
		p = Instance.new(shape == "Wedge" and "WedgePart" or "Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		if shape == "Ball" then
			p.Shape = Enum.PartType.Ball
		elseif shape == "Cylinder" then
			p.Shape = Enum.PartType.Cylinder
		end
		p.Parent = getFolder()
	end
	p.Name = "Fx" .. shape
	p.Size = size
	p.Color = color
	p.Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
	p.Transparency = 0
	return p
end

local function give(p, shape)
	local list = pool[shape]
	if #list < POOL_MAX and p.Parent then
		p.CFrame = AWAY
		p.Transparency = 1
		table.insert(list, p)
	else
		p:Destroy()
	end
end

local function room(n)
	return math.max(0, math.min(n, Effects.cap().live - #live))
end

local function add(e)
	e.age = 0
	table.insert(live, e)
	if not stepping then
		stepping = RunService.RenderStepped:Connect(function(dt)
			Effects.step(dt)
		end)
	end
	return e
end

local function teamColor(team)
	return Constants.TEAM_COLOR[team or ""] or Constants.TEAM_COLOR.red
end

local function randomDir()
	local v = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
	return v.Magnitude > 0.01 and v.Unit or Vector3.yAxis
end

-- a ball that swells from s0 to s1 and fades (a flash, a glow)
local function flash(pos, color, s0, s1, life, t0, alpha)
	local p = take("Ball", Vector3.new(s0, s0, s0), color, true)
	p.CFrame = CFrame.new(pos)
	local e = { part = p, shape = "Ball", kind = "grow", at = pos, s0 = s0, s1 = s1, life = life, t0 = t0 or 0 }
	e.alpha = alpha or 0.05 -- (how see-through it starts)
	return add(e)
end

-- a ring racing out, facing `normal`: a circle of thin neon pieces (a hollow ring; a cylinder would be a solid
-- disc). Returns how many pieces it made.
local ARCS = { high = 16, mid = 12, low = 8 }
local function ring(pos, normal, color, r1, life, thick, alpha, pieces)
	local n = normal.Magnitude > 0.01 and normal.Unit or Vector3.yAxis
	local side = math.abs(n.Y) < 0.95 and Vector3.yAxis or Vector3.xAxis
	-- (in this frame X is the normal; the ring lies in Y and Z)
	local up = n:Cross(side).Unit
	local cf = CFrame.fromMatrix(pos, n, up, n:Cross(up).Unit)
	local count = room(pieces or ARCS[Effects.tier()] or 8)
	for i = 1, count do
		local p = take("Block", Vector3.new(thick or 0.14, thick or 0.14, 0.2), color, true)
		p.CFrame = AWAY
		p.Transparency = alpha or 0.1
		add({
			part = p,
			shape = "Block",
			kind = "arc",
			cf = cf * CFrame.Angles(i / count * math.pi * 2, 0, 0),
			n = count,
			r1 = r1,
			life = life,
			thick = thick or 0.14,
			alpha = alpha or 0.1,
		})
	end
	return count
end

local function spark(pos, dir, color, speed, life, len)
	local p = take("Block", Vector3.new(0.09, 0.09, len or 1.4), color, true)
	p.CFrame = CFrame.lookAt(pos, pos + dir)
	return add({
		part = p,
		shape = "Block",
		kind = "spark",
		pos = pos,
		vel = dir * speed,
		life = life,
		len = len or 1.4,
	})
end

local function glow(pos, color, range, life)
	local holder = take("Block", Vector3.new(0.2, 0.2, 0.2), color, false)
	holder.Transparency = 1
	holder.CFrame = CFrame.new(pos)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = 6
	light.Shadows = false
	light.Parent = holder
	return add({ part = holder, shape = "Block", kind = "light", light = light, life = life })
end

-- one shard: a sliver of white or the team's colour (some glowing), cut from somewhere inside the body
local function shard(at, color, neon, vel, life, scale)
	local wedge = rng:NextNumber() < 0.55
	local a, b = rng:NextNumber(0.45, 1.25), rng:NextNumber(0.35, 0.9)
	local size = Vector3.new(rng:NextNumber(0.12, 0.3), a, b) * (scale or 1)
	local p = take(wedge and "Wedge" or "Block", size, color, neon)
	local rot = CFrame.fromAxisAngle(randomDir(), rng:NextNumber(0, math.pi * 2))
	p.CFrame = CFrame.new(at) * rot
	return add({
		part = p,
		shape = wedge and "Wedge" or "Block",
		kind = "shard",
		pos = at,
		vel = vel,
		rot = rot,
		axis = randomDir(),
		spin = rng:NextNumber(6, 18),
		size = size,
		life = life,
		floor = at.Y - 3.2,
	})
end

-- a random point inside one of the parts (bigger parts more often)
local function pointIn(parts, weights, total)
	local pick = rng:NextNumber(0, total)
	for i, p in parts do
		pick -= weights[i]
		if pick <= 0 or i == #parts then
			local s = p.Size * 0.5
			return p.CFrame * Vector3.new(
				rng:NextNumber(-s.X, s.X),
				rng:NextNumber(-s.Y, s.Y),
				rng:NextNumber(-s.Z, s.Z)
			),
				p.Color
		end
	end
	return parts[1].Position, parts[1].Color
end

function Effects.shatter(opts)
	local pos = opts.pos
	if typeof(pos) ~= "Vector3" then
		return 0
	end
	local cap = Effects.cap()
	local team = teamColor(opts.team)
	local dir = typeof(opts.dir) == "Vector3" and opts.dir.Magnitude > 0.01 and opts.dir.Unit or Vector3.yAxis
	local power = opts.power or 1
	local made = 0
	-- the flash first (the last thing the cap takes away): white hot, then the team's glow
	if room(1) == 0 then
		return 0
	end
	if not opts.quiet then
		flash(pos, WHITE, 0.8, 4, 0.14, 0, 0.35)
		made += 1
	end
	if room(1) > 0 and not opts.quiet then
		flash(pos, team, 0.8, 1.8, 0.18, 0.02, 0.65)
		made += 1
	end
	for i = 1, opts.quiet and 0 or cap.rings do
		-- the shockwave: across the arrow's path in the team's colour, and (high) a white one flat on the floor
		if i == 1 then
			made += ring(pos, dir, team, 5.5, 0.4, 0.14, 0.05)
		else
			made += ring(Vector3.new(pos.X, pos.Y - 2.6, pos.Z), Vector3.yAxis, WHITE, 7, 0.55, 0.12, 0.2)
		end
	end
	if cap.light and room(1) > 0 then
		glow(pos, team, 18, 0.55)
		made += 1
	end
	local parts, weights, total = {}, {}, 0
	for _, p in opts.parts or {} do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
			local w = p.Size.X * p.Size.Y * p.Size.Z
			table.insert(parts, p)
			table.insert(weights, w)
			total += w
		end
	end
	local n = room(math.floor(cap.shards * math.clamp(opts.scale or 1, 0.2, 1.5)))
	for i = 1, n do
		local at, own
		if #parts > 0 then
			at, own = pointIn(parts, weights, total)
		else
			at = pos + Vector3.new(rng:NextNumber(-0.9, 0.9), rng:NextNumber(-2.2, 2.4), rng:NextNumber(-0.9, 0.9))
		end
		-- (about half white, a third the team's colour, the rest glowing neon: the store art's white and colour)
		local roll = i / n
		local color, neon = WHITE, false
		if roll > 0.5 and roll <= 0.82 then
			color = own and own ~= Constants.WHITE and own or team
		elseif roll > 0.82 then
			color, neon = team, true
		end
		local out = at - pos
		out = out.Magnitude > 0.01 and out.Unit or randomDir()
		local vel = dir * rng:NextNumber(16, 36) * power
			+ out * rng:NextNumber(5, 14)
			+ Vector3.new(0, rng:NextNumber(4, 13), 0)
		shard(at, color, neon, vel, rng:NextNumber(1.1, 1.9))
		made += 1
	end
	for i = 1, room(cap.sparks) do
		local d = (dir * 1.4 + randomDir()).Unit
		spark(pos, d, i % 3 == 0 and WHITE or team, rng:NextNumber(40, 80), rng:NextNumber(0.25, 0.5))
		made += 1
	end
	return made
end

function Effects.impact(pos, color, dir)
	if typeof(pos) ~= "Vector3" then
		return 0
	end
	local cap = Effects.cap()
	color = color or teamColor(nil)
	local back = typeof(dir) == "Vector3" and dir.Magnitude > 0.01 and -dir.Unit or Vector3.yAxis
	local made = 0
	if room(1) > 0 then
		flash(pos, WHITE, 0.4, 2.4, 0.14, 0, 0.2)
		made += 1
	end
	if room(1) > 0 then
		made += ring(pos, back, color, 2.2, 0.26, 0.07, 0.1, math.ceil((ARCS[Effects.tier()] or 8) / 2))
	end
	for i = 1, room(cap.chips) do
		local d = (back * 1.2 + randomDir()).Unit
		local vel = d * rng:NextNumber(10, 22) + Vector3.new(0, rng:NextNumber(3, 9), 0)
		shard(pos, i == 1 and color or WHITE, false, vel, rng:NextNumber(0.4, 0.7), 0.45).floor = pos.Y - 6
		made += 1
	end
	for _ = 1, room(math.ceil(cap.sparks / 2)) do
		spark(pos, (back + randomDir() * 0.8).Unit, color, rng:NextNumber(26, 46), rng:NextNumber(0.15, 0.3), 0.8)
		made += 1
	end
	return made
end

function Effects.explosion(pos, radius, color)
	local Explosion = require(script.Parent.Parent.Controllers.ExplosionController)
	return Explosion.blast({ pos = pos, radius = radius, color = color, ground = pos and pos.Y })
end

-- A blocky stand-in (R6 shapes) in the team's colour, standing at cf, for a replay
function Effects.mannequin(cf, team)
	local model = Instance.new("Model")
	model.Name = "Mannequin"
	local color = teamColor(team)
	local function limb(name, size, offset, c)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Material = Enum.Material.SmoothPlastic
		p.Size = size
		p.Color = c or color
		p.CFrame = cf * offset
		p.Parent = model
		return p
	end
	limb("Torso", Vector3.new(2, 2, 1), CFrame.new(0, 0, 0))
	limb("Head", Vector3.new(1.25, 1.25, 1.25), CFrame.new(0, 1.65, 0))
	limb("Left Arm", Vector3.new(1, 2, 1), CFrame.new(-1.5, 0, 0) * CFrame.Angles(0.2, 0, -0.08))
	limb("Right Arm", Vector3.new(1, 2, 1), CFrame.new(1.5, 0, 0) * CFrame.Angles(-0.25, 0, 0.08))
	limb("Left Leg", Vector3.new(1, 2, 1), CFrame.new(-0.5, -2, 0) * CFrame.Angles(-0.15, 0, 0))
	limb("Right Leg", Vector3.new(1, 2, 1), CFrame.new(0.5, -2, 0) * CFrame.Angles(0.15, 0, 0))
	model.Parent = getFolder()
	return model
end

-- A stand-in that wears someone's own look: a still copy of their character (avatar, clothes, accessories, the team
-- bands) at cf, anchored and out of the way of everything. nil if there's no character to copy (then a mannequin).
function Effects.lookalike(character, cf, team)
	if typeof(character) ~= "Instance" then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	-- (characters aren't Archivable by default: Clone would give nil)
	local okA, was = pcall(function()
		local w = character.Archivable
		character.Archivable = true
		return w
	end)
	local ok, copy = pcall(function()
		return character:Clone()
	end)
	if okA then
		pcall(function()
			character.Archivable = was
		end)
	end
	if not ok or not copy then
		return nil
	end
	pcall(function()
		copy.Name = "Lookalike"
		for _, d in copy:GetDescendants() do
			if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") or d:IsA("Sound") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				d.LocalTransparencyModifier = 0
				if d.Name == "HumanoidRootPart" then
					d.Transparency = 1
				end
			elseif d:IsA("Decal") then
				d.Transparency = 0 -- (the face: the shatter may have hidden the real one already)
			end
		end
		local hum = copy:FindFirstChildOfClass("Humanoid")
		if hum then
			-- (kept so the clothes still show; no name over it, no health bar, no physics of its own)
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		end
		local r = copy:FindFirstChild("HumanoidRootPart")
		local offset = r and r.CFrame:ToObjectSpace(copy:GetPivot()) or CFrame.new()
		copy:PivotTo(cf * offset)
	end)
	copy:SetAttribute("Team", team)
	copy.Parent = getFolder()
	return copy
end

local GRAVITY = 70

function Effects.step(dt)
	dt = math.clamp(dt or 1 / 60, 0, 1 / 15) * math.clamp(Effects.timeScale, 0, 1)
	for i = #live, 1, -1 do
		local e = live[i]
		e.age += dt
		local f = e.age / e.life
		local p = e.part
		if f >= 1 or not p.Parent then
			if e.light then
				e.light:Destroy()
			end
			give(p, e.shape)
			table.remove(live, i)
		elseif e.kind == "shard" then
			e.vel = e.vel * (1 - math.min(1, dt * 0.9)) + Vector3.new(0, -GRAVITY * dt, 0)
			e.pos += e.vel * dt
			if e.pos.Y < e.floor then
				-- (a bounce off the floor, losing most of it)
				e.pos = Vector3.new(e.pos.X, e.floor, e.pos.Z)
				e.vel = Vector3.new(e.vel.X * 0.5, math.abs(e.vel.Y) * 0.3, e.vel.Z * 0.5)
				e.spin *= 0.5
			end
			e.rot = CFrame.fromAxisAngle(e.axis, e.spin * dt) * e.rot
			p.CFrame = CFrame.new(e.pos) * e.rot
			if f > 0.65 then
				local k = (f - 0.65) / 0.35
				p.Transparency = k * k
				p.Size = e.size * (1 - 0.6 * k)
			end
		elseif e.kind == "spark" then
			e.vel = e.vel * (1 - math.min(1, dt * 3)) + Vector3.new(0, -GRAVITY * 0.5 * dt, 0)
			e.pos += e.vel * dt
			local v = e.vel.Magnitude > 0.01 and e.vel.Unit or Vector3.yAxis
			p.CFrame = CFrame.lookAt(e.pos, e.pos + v)
			p.Size = Vector3.new(0.09, 0.09, e.len * (1 - f * 0.7))
			p.Transparency = f * f
		elseif e.kind == "grow" then
			local g = math.clamp((e.age - e.t0) / (e.life * 0.55), 0, 1)
			local s = e.s0 + (e.s1 - e.s0) * (1 - (1 - g) ^ 3)
			p.Size = Vector3.new(s, s, s)
			p.CFrame = CFrame.new(e.at)
			p.Transparency = math.clamp(e.alpha + (1 - e.alpha) * f * f * 1.05, 0, 1)
		elseif e.kind == "arc" then
			-- (one piece of a ring: out along its spoke, long enough to meet its neighbours, thinning as it goes)
			local r = 0.4 + (e.r1 - 0.4) * (1 - (1 - f) ^ 2.5)
			local thick = e.thick * (1 - 0.5 * f)
			p.Size = Vector3.new(thick, thick, r * math.pi * 2 / e.n * 1.08)
			p.CFrame = e.cf * CFrame.new(0, r, 0)
			p.Transparency = e.alpha + (1 - e.alpha) * f * f
		elseif e.kind == "light" then
			e.light.Brightness = 6 * (1 - f) ^ 2
		end
	end
	if #live == 0 and stepping then
		stepping:Disconnect()
		stepping = nil
	end
end

return Effects
