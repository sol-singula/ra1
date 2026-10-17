--[[
Structures coming down (drawn on each client only): when the server says a piece was destroyed (Net "Structure",
kind "destroyed", with where it stood and what broke it), the same parts it was made of (StructureModel) are broken
into chunks: each block cut into a few smaller blocks of its own shape and colour (wedges, balls and posts stay
whole), with small gaps so it reads as fractured. They fly apart, away from what hit it (an arrow knocks them back
along its flight, a TNT throws them out and up, some high enough to rain back down, lost turf just crumbles), spin,
bounce on the floor and slide to a stop, then shrink and fade and are gone after about 3 s. Dust rolls out from the
base and a few sparks fly.

The chunks are anchored parts this controller moves itself (its own little gravity and bounce), never collide with
anyone and are out of every query. How many depends on the graphics tier (GraphicsController: far fewer on phones),
there is a cap on how many are flying at once, and only so many are made each frame (the rest wait their turn).

  DebrisController.shatter(info)              (the "destroyed" message; tests call it directly)
  DebrisController.burst(pos, color, n, power, ground)   loose chunks thrown up from a spot (a TNT on bare floor)
  DebrisController.count() / .queued()        (tests)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Net)
local StructureModel = require(ReplicatedStorage.Shared.StructureModel)
local AudioController = require(script.Parent.AudioController)
local GraphicsController = require(script.Parent.GraphicsController)

local DebrisController = { Name = "DebrisController", Order = 47 }

local folder
local chunks = {} -- { part, pos, vel, rot, axis, spin, angle, born, life, size, floor, half }
local puffs = {} -- { part, born, life, from, to, rise }
local pending = {} -- chunks waiting to be made: { spec = { cf, size, color, wedge?, shape? }, vel, spin, floor, life }
local GRAVITY = 110
local rng = Random.new()

-- per graphics tier: chunks for one piece (a TNT's / anything else's), flying at once, made per frame
local BUDGET = {
	high = { tnt = 110, other = 60, live = 320, frame = 60, dust = 8, sparks = 6 },
	mid = { tnt = 70, other = 40, live = 200, frame = 40, dust = 6, sparks = 4 },
	low = { tnt = 32, other = 20, live = 80, frame = 20, dust = 3, sparks = 2 },
}

local function budget()
	return BUDGET[GraphicsController.tier()] or BUDGET.low
end

local function newPart(class, size, color, cf)
	local p = Instance.new(class)
	p.Name = "Chunk"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = GraphicsController.tier() ~= "low"
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.Color = color
	p.CFrame = cf
	p.Parent = folder
	return p
end

-- Cut one part into about `n` blocks of its shape (a grid over its own axes, each a little smaller than its cell)
local function fracture(spec, n, color, out)
	local size = spec.size
	if spec.wedge or spec.shape or n <= 1 then
		table.insert(out, { cf = spec.cf, size = size, color = color, wedge = spec.wedge, shape = spec.shape })
		return
	end
	local vol = size.X * size.Y * size.Z
	local cube = (vol / n) ^ (1 / 3)
	local nx = math.clamp(math.floor(size.X / cube + 0.5), 1, 5)
	local ny = math.clamp(math.floor(size.Y / cube + 0.5), 1, 5)
	local nz = math.clamp(math.floor(size.Z / cube + 0.5), 1, 5)
	local cell = Vector3.new(size.X / nx, size.Y / ny, size.Z / nz)
	for i = 1, nx do
		for j = 1, ny do
			for k = 1, nz do
				local off = Vector3.new(
					(i - 0.5) * cell.X - size.X / 2,
					(j - 0.5) * cell.Y - size.Y / 2,
					(k - 0.5) * cell.Z - size.Z / 2
				)
				local shrink = rng:NextNumber(0.82, 0.97)
				-- (each chunk a touch lighter or darker: broken faces catch the light differently)
				local shade = rng:NextNumber(-0.07, 0.05)
				local c = shade < 0 and color:Lerp(Color3.new(0, 0, 0), -shade)
					or color:Lerp(Color3.new(1, 1, 1), shade)
				table.insert(out, { cf = spec.cf * CFrame.new(off), size = cell * shrink, color = c })
			end
		end
	end
end

local function dust(at, color, n, spread, life)
	for _ = 1, n do
		local p = newPart("Part", Vector3.new(1.5, 1.5, 1.5), color, CFrame.new(at))
		p.Name = "Dust"
		p.Shape = Enum.PartType.Ball
		p.CastShadow = false
		p.Transparency = 0.35
		local dir = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
		dir = dir.Magnitude > 0.01 and dir.Unit or Vector3.new(1, 0, 0)
		table.insert(puffs, {
			part = p,
			born = os.clock(),
			life = life * rng:NextNumber(0.8, 1.2),
			from = at,
			to = at + dir * spread * rng:NextNumber(0.5, 1) + Vector3.new(0, rng:NextNumber(1, 3), 0),
			size0 = rng:NextNumber(1.2, 2.2),
			size1 = rng:NextNumber(4, 7),
		})
	end
end

local function sparks(at, n, speed)
	for _ = 1, n do
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.3, 1.2), rng:NextNumber(-1, 1)).Unit
		table.insert(pending, {
			spec = {
				cf = CFrame.new(at),
				size = Vector3.new(0.18, 0.18, 0.18),
				color = Color3.fromRGB(255, rng:NextInteger(150, 220), 60),
				neon = true,
			},
			vel = dir * speed * rng:NextNumber(0.6, 1.2),
			spin = 0,
			floor = at.Y - 50,
			life = rng:NextNumber(0.35, 0.7),
		})
	end
end

-- Queue the chunks of one piece, each with its flight: out from `from`, harder with more power
local function launch(list, from, power, dir, floor, tnt)
	for _, c in list do
		local pos = c.cf.Position
		local out = pos - from
		out = Vector3.new(out.X, math.max(out.Y, 0) * 0.5, out.Z)
		out = out.Magnitude > 0.05 and out.Unit or Vector3.new(rng:NextNumber(-1, 1), 0.3, rng:NextNumber(-1, 1)).Unit
		local speed = 3 + power * rng:NextNumber(18, 48)
		local vel = out * speed + Vector3.new(0, rng:NextNumber(2, 8) + power * rng:NextNumber(8, 30), 0)
		if dir then
			vel += dir * power * rng:NextNumber(10, 24)
		end
		if tnt and rng:NextNumber() < 0.22 then
			vel += Vector3.new(0, rng:NextNumber(30, 55), 0) -- (high up: it rains back down)
		end
		table.insert(pending, {
			spec = c,
			vel = vel,
			spin = rng:NextNumber(2, 10) * (0.5 + power),
			floor = floor,
			life = rng:NextNumber(2.4, 3.0),
		})
	end
end

function DebrisController.shatter(info)
	if type(info) ~= "table" or typeof(info.min) ~= "Vector3" or typeof(info.max) ~= "Vector3" then
		return 0
	end
	local b = budget()
	local blast = type(info.blast) == "table" and info.blast or nil
	local tnt = blast and blast.tnt == true
	local power = blast and tonumber(blast.power) or 0.18
	local mid = (info.min + info.max) / 2
	local from = blast and typeof(blast.pos) == "Vector3" and blast.pos or Vector3.new(mid.X, info.min.Y, mid.Z)
	local dir = blast and typeof(blast.dir) == "Vector3" and blast.dir or nil
	local specs = StructureModel.parts(info.key, info.team, info.min, info.max)
	-- the piece's chunks, shared out by size (the big blocks get most of them)
	local total = 0
	for _, s in specs do
		total += s.size.X * s.size.Y * s.size.Z
	end
	local n = tnt and b.tnt or b.other
	local list = {}
	for _, s in specs do
		local vol = s.size.X * s.size.Y * s.size.Z
		local share = math.floor(n * vol / math.max(total, 0.01) + 0.5)
		fracture(s, share, StructureModel.color(s.tone, info.team), list)
	end
	-- (over budget: drop the smallest at random so the shape still reads)
	while #list > n do
		table.remove(list, rng:NextInteger(1, #list))
	end
	launch(list, from, power, dir, info.min.Y, tnt)
	dust(Vector3.new(mid.X, info.min.Y + 0.6, mid.Z), Color3.fromRGB(226, 223, 216), b.dust, 7, 1.4)
	sparks(from, b.sparks + (tnt and b.sparks or 0), tnt and 40 or 22)
	-- (the crunch from where it stood, quieter the further off it is)
	local cam = workspace.CurrentCamera
	local d = cam and (cam.CFrame.Position - mid).Magnitude or 0
	AudioController.playAt("crumble", mid, tnt and 0.8 or 1.15, math.clamp(1 - d / 160, 0.15, 1))
	return #list
end

function DebrisController.burst(pos, color, n, power, ground)
	local list = {}
	for _ = 1, math.max(0, n) do
		local s = rng:NextNumber(0.4, 1.1)
		table.insert(list, {
			cf = CFrame.new(pos + Vector3.new(rng:NextNumber(-1.5, 1.5), 0.3, rng:NextNumber(-1.5, 1.5))),
			size = Vector3.new(s, s * rng:NextNumber(0.5, 1), s),
			color = color,
		})
	end
	launch(list, pos - Vector3.new(0, 1.5, 0), power, nil, ground or pos.Y, true)
end

local function make(item)
	local spec = item.spec
	local p = newPart(spec.wedge and "WedgePart" or "Part", spec.size, spec.color, spec.cf)
	if spec.shape == "Ball" then
		p.Shape = Enum.PartType.Ball
	elseif spec.shape == "Cylinder" then
		p.Shape = Enum.PartType.Cylinder
	end
	if spec.neon then
		p.Name = "Spark"
		p.Material = Enum.Material.Neon
		p.CastShadow = false
	end
	local axis = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
	table.insert(chunks, {
		part = p,
		pos = spec.cf.Position,
		rot = spec.cf - spec.cf.Position,
		vel = item.vel,
		axis = axis.Magnitude > 0.01 and axis.Unit or Vector3.new(0, 1, 0),
		spin = item.spin,
		angle = 0,
		born = os.clock(),
		life = item.life,
		size = spec.size,
		floor = item.floor,
		half = math.min(spec.size.X, spec.size.Y, spec.size.Z) / 2,
	})
end

local function step(dt)
	dt = math.clamp(dt or 1 / 60, 0, 1 / 15)
	local b = budget()
	-- new chunks: only so many a frame, never more flying than the cap (the oldest pending wait)
	local made = 0
	while #pending > 0 and made < b.frame do
		if #chunks >= b.live then
			-- (at the cap: the ones that can't fly are dropped rather than kept waiting)
			table.clear(pending)
			break
		end
		make(table.remove(pending, 1))
		made += 1
	end
	local now = os.clock()
	for i = #chunks, 1, -1 do
		local c = chunks[i]
		local age = now - c.born
		if age >= c.life or not c.part.Parent then
			c.part:Destroy()
			table.remove(chunks, i)
		else
			c.vel += Vector3.new(0, -GRAVITY * dt, 0)
			c.pos += c.vel * dt
			c.angle += c.spin * dt
			-- the floor: a bounce (less each time), sliding to a stop
			if c.pos.Y - c.half < c.floor then
				c.pos = Vector3.new(c.pos.X, c.floor + c.half, c.pos.Z)
				if c.vel.Y < 0 then
					local up = -c.vel.Y * 0.32
					c.vel = Vector3.new(c.vel.X * 0.6, up > 2 and up or 0, c.vel.Z * 0.6)
					c.spin *= 0.55
				end
			end
			-- the last 0.7 s: shrink and fade away
			local fade = math.clamp((age - (c.life - 0.7)) / 0.7, 0, 1)
			c.part.Size = c.size * (1 - fade * 0.85)
			c.part.Transparency = fade * 0.9
			c.part.CFrame = CFrame.new(c.pos) * CFrame.fromAxisAngle(c.axis, c.angle) * c.rot
		end
	end
	for i = #puffs, 1, -1 do
		local d = puffs[i]
		local f = (now - d.born) / d.life
		if f >= 1 then
			d.part:Destroy()
			table.remove(puffs, i)
		else
			local e = 1 - (1 - f) ^ 2
			local s = d.size0 + (d.size1 - d.size0) * e
			d.part.Size = Vector3.new(s, s, s)
			d.part.CFrame = CFrame.new(d.from:Lerp(d.to, e))
			d.part.Transparency = 0.35 + 0.65 * f
		end
	end
end

function DebrisController.count()
	return #chunks
end

function DebrisController.queued()
	return #pending
end

function DebrisController.dust()
	return #puffs
end

function DebrisController:init()
	folder = Instance.new("Folder")
	folder.Name = "DebrisFx"
	folder.Parent = workspace
	Net.listen("Structure", function(s)
		if type(s) == "table" and s.kind == "destroyed" and not s.quiet and not s.refund then
			DebrisController.shatter(s)
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return DebrisController
