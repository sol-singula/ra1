--[[
Effects (master plan §5: telegraphed attacks you can read; §11: big readable moments). Chips fly when you chop and
the tree tips over when it falls, rocks spark, crates burst with sparkles, the camp's pieces go up in a puff of
dust, arrows and throws fly, firecrackers bang, flares burn red, Kermy vanishes in a puff of smoke.

Every monster attack is drawn on the ground while its tell plays (§5: "an attack you can see coming"):
  a red line for a lunge, a dart or a charge (it fills up as the moment comes), a red circle for a slam or where a
  pinecone will land, Mega Kermy's shadow where he'll come down and the shockwave rings you jump over.
Plus damage numbers, floating "+3 🪵" popups, dizzy stars, a rustling bush where Kermy is about to pop out, the
beacons of your team's pings, and the screen shake (Settings: effects, screen shake; Reduced Motion turns shaking off).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Kit = require(ReplicatedStorage.Shared.World.Kit)
local MapLayout = require(ReplicatedStorage.Shared.World.MapLayout)
local Net = require(ReplicatedStorage.Shared.Net)
local Rigs = require(ReplicatedStorage.Shared.World.Rigs)
local MonsterController = require(script.Parent.MonsterController)
local PerformanceController = require(script.Parent.PerformanceController)
local Bus = require(script.Parent.Parent.UI.Bus)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local FxController = { Name = "FxController", Order = 45 }

local player = Players.LocalPlayer
local C, M = Kit.C, Kit.M
local folder
local particles = {} -- { part, vel, life, age, spin, gravity, grow, fade }
local movers = {} -- { update = fn(dt) -> alive }
local MAX_PARTICLES = 240
local shakeUntil, shakeStrength = 0, 0
local RED = Color3.fromRGB(255, 52, 52)
local GOO = Color3.fromRGB(120, 230, 90)
local BOSS_ID = 65500

local function settings()
	return Store.get("settings") or {}
end

local function fxOn()
	return settings().fx ~= false
end

local function full()
	return #particles >= (PerformanceController.lite and MAX_PARTICLES // 2 or MAX_PARTICLES)
end

local function camPos()
	local cam = workspace.CurrentCamera
	return cam and cam.CFrame and cam.CFrame.Position or Vector3.zero
end

local function near(pos, radius)
	return typeof(pos) == "Vector3" and (pos - camPos()).Magnitude <= (radius or 170)
end

local function ground(pos)
	return Vector3.new(pos.X, MapLayout.groundY(pos.X, pos.Z), pos.Z)
end

-- Primitives -----------------------------------------------------------------------------------------------------------------------
local function chunk(pos, size, color, material, shape)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = material or M.SmoothPlastic
	p.CFrame = CFrame.new(pos)
	if shape == "ball" then
		p.Shape = Enum.PartType.Ball
	elseif shape == "cylinder" then
		p.Shape = Enum.PartType.Cylinder
	end
	p.Parent = folder
	return p
end

-- A burst of small pieces flying out with gravity.
function FxController.burst(pos, color, count, size, speed, life, opts)
	opts = opts or {}
	if not near(pos) then
		return
	end
	count = fxOn() and count or math.ceil(count / 3)
	for _ = 1, count do
		if full() then
			break
		end
		local s = size * (0.6 + math.random() * 0.8)
		local col = typeof(color) == "table" and color[math.random(1, #color)] or color
		local p = chunk(
			pos + Vector3.new(math.random() - 0.5, math.random() * 0.5, math.random() - 0.5),
			Vector3.new(s, s, s),
			col,
			opts.material,
			opts.ball and "ball"
		)
		local a = math.random() * math.pi * 2
		local up = opts.up or 0.6
		local v = Vector3.new(math.cos(a), up + math.random() * up, math.sin(a)) * speed * (0.5 + math.random() * 0.7)
		table.insert(particles, {
			part = p,
			vel = v,
			life = life * (0.7 + math.random() * 0.6),
			age = 0,
			spin = Vector3.new(math.random() * 6, math.random() * 6, math.random() * 6),
			gravity = opts.gravity or 40,
			fade = opts.fade ~= false,
		})
	end
end

-- Rising puffs of smoke or dust.
function FxController.puff(pos, color, count, size, life)
	if not near(pos) then
		return
	end
	count = fxOn() and count or math.ceil(count / 3)
	for _ = 1, count do
		if full() then
			break
		end
		local p = chunk(
			pos + Vector3.new((math.random() - 0.5) * size, 0, (math.random() - 0.5) * size),
			Vector3.new(size, size, size),
			color,
			M.SmoothPlastic,
			"ball"
		)
		p.Transparency = 0.3
		table.insert(particles, {
			part = p,
			vel = Vector3.new((math.random() - 0.5) * 4, 3 + math.random() * 4, (math.random() - 0.5) * 4),
			life = life,
			age = 0,
			spin = Vector3.zero,
			gravity = -2,
			grow = 1.8,
			fade = true,
		})
	end
end

-- An expanding flat ring on the ground.
function FxController.ring(pos, color, radius, life, height, from)
	if not near(pos, 240) then
		return
	end
	local p = chunk(pos + Vector3.new(0, 0.3, 0), Vector3.new(height or 0.4, 1, 1), color, M.Neon, "cylinder")
	p.CFrame = CFrame.new(pos + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
	p.Transparency = 0.2
	local age = 0
	table.insert(movers, {
		update = function(dt)
			age += dt
			local k = math.min(1, age / life)
			local d = radius * 2 * ((from or 0.15) + (1 - (from or 0.15)) * k)
			p.Size = Vector3.new(height or 0.4, d, d)
			p.Transparency = 0.2 + 0.8 * k
			if k >= 1 then
				p:Destroy()
				return false
			end
			return true
		end,
	})
end

-- A sphere that grows and fades (bangs, flashes).
function FxController.sphere(pos, color, radius, life)
	if not near(pos, 260) then
		return
	end
	local p = chunk(pos, Vector3.one, color, M.Neon, "ball")
	local age = 0
	table.insert(movers, {
		update = function(dt)
			age += dt
			local k = math.min(1, age / life)
			local d = radius * 2 * (0.3 + 0.7 * math.sqrt(k))
			p.Size = Vector3.new(d, d, d)
			p.Transparency = 0.15 + 0.85 * k
			if k >= 1 then
				p:Destroy()
				return false
			end
			return true
		end,
	})
end

function FxController.shake(strength, seconds)
	if settings().shake == false or Theme.reducedMotion() then
		return
	end
	if os.clock() + seconds > shakeUntil then
		shakeUntil = os.clock() + seconds
	end
	shakeStrength = math.max(shakeStrength * (shakeUntil > os.clock() and 1 or 0), strength)
end

-- Floating text in the world ("+3 🪵", damage numbers): rises and fades.
function FxController.popup(pos, text, color, size, seconds)
	if typeof(pos) ~= "Vector3" or not near(pos, 140) then
		return
	end
	local anchor = chunk(pos, Vector3.new(0.2, 0.2, 0.2), C.white)
	anchor.Transparency = 1
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(160, size or 34)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 150
	bb.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.Text = tostring(text)
	label.TextColor3 = typeof(color) == "Color3" and color or C.white
	label.TextStrokeTransparency = 0
	label.Parent = bb
	local age, life = 0, seconds or 1
	local drift = Vector3.new((math.random() - 0.5) * 1.5, 0, (math.random() - 0.5) * 1.5)
	table.insert(movers, {
		update = function(dt)
			age += dt
			local k = age / life
			anchor.CFrame = CFrame.new(pos + drift * k + Vector3.new(0, 2.5 * k, 0))
			label.TextTransparency = math.max(0, (k - 0.6) / 0.4)
			label.TextStrokeTransparency = label.TextTransparency
			if k >= 1 then
				anchor:Destroy()
				return false
			end
			return true
		end,
	})
end

-- Telegraphs on the ground ------------------------------------------------------------------------------------------------------
-- A red strip from a point along a direction that fills up over `seconds`. follow() -> pos, dir keeps it attached.
function FxController.line(from, dir, length, width, seconds, color, follow)
	color = color or RED
	local outline = chunk(from, Vector3.new(width, 0.12, length), color, M.Neon)
	outline.Transparency = 0.75
	local fill = chunk(from, Vector3.new(width * 0.92, 0.16, 0.1), color, M.Neon)
	fill.Transparency = 0.35
	local age = 0
	local function place(pos, d)
		local flat = Vector3.new(d.X, 0, d.Z)
		if flat.Magnitude < 0.01 then
			return
		end
		flat = flat.Unit
		local base = ground(pos) + Vector3.new(0, 0.25, 0)
		local k = math.min(1, age / math.max(0.05, seconds))
		outline.CFrame = CFrame.lookAt(base + flat * length / 2, base + flat * length)
		local fl = math.max(0.1, length * k)
		fill.Size = Vector3.new(width * 0.92, 0.16, fl)
		fill.CFrame = CFrame.lookAt(
			base + flat * fl / 2 + Vector3.new(0, 0.02, 0),
			base + flat * length + Vector3.new(0, 0.02, 0)
		)
	end
	place(from, dir)
	table.insert(movers, {
		update = function(dt)
			age += dt
			if follow then
				local p, d = follow()
				if p and d then
					from, dir = p, d
				end
			end
			place(from, dir)
			if age >= seconds + 0.15 then
				outline:Destroy()
				fill:Destroy()
				return false
			end
			return true
		end,
	})
end

-- A red circle that fills from the middle over `seconds`.
function FxController.circle(center, radius, seconds, color)
	color = color or RED
	local base = ground(center) + Vector3.new(0, 0.25, 0)
	local outline = chunk(base, Vector3.new(0.12, radius * 2, radius * 2), color, M.Neon, "cylinder")
	outline.CFrame = CFrame.new(base) * CFrame.Angles(0, 0, math.rad(90))
	outline.Transparency = 0.75
	local fill = chunk(base, Vector3.new(0.16, 0.2, 0.2), color, M.Neon, "cylinder")
	fill.Transparency = 0.35
	local age = 0
	table.insert(movers, {
		update = function(dt)
			age += dt
			local k = math.min(1, age / math.max(0.05, seconds))
			local d = radius * 2 * k
			fill.Size = Vector3.new(0.16, math.max(0.2, d), math.max(0.2, d))
			fill.CFrame = CFrame.new(base + Vector3.new(0, 0.02, 0)) * CFrame.Angles(0, 0, math.rad(90))
			if age >= seconds + 0.15 then
				outline:Destroy()
				fill:Destroy()
				return false
			end
			return true
		end,
	})
end

-- Dizzy stars circling over a head.
function FxController.stars(getPos, seconds)
	local stars = {}
	for k = 1, 3 do
		stars[k] = chunk(Vector3.zero, Vector3.new(0.6, 0.6, 0.6), C.yellow, M.Neon, "ball")
	end
	local age = 0
	table.insert(movers, {
		update = function(dt)
			age += dt
			local pos = getPos()
			if not pos or age >= seconds then
				for _, s in stars do
					s:Destroy()
				end
				return false
			end
			for k, s in stars do
				local a = age * 5 + k / 3 * math.pi * 2
				s.CFrame = CFrame.new(
					pos + Vector3.new(math.cos(a) * 1.4, 0.3 + math.sin(age * 8 + k) * 0.15, math.sin(a) * 1.4)
				)
			end
			return true
		end,
	})
end

-- A monster's head, for stars and words.
local function headOf(id, kind)
	return function()
		local p = MonsterController.position(id)
		return p and p + Vector3.new(0, (Rigs.HEIGHT[kind] or 4) + 0.6, 0)
	end
end

-- Trees: shake when chopped, tip over when felled ---------------------------------------------------------------------------------
local function findTree(id, pos)
	local map = workspace:FindFirstChild("Map")
	local forest = map and map:FindFirstChild("Forest")
	if not forest or typeof(pos) ~= "Vector3" then
		return nil
	end
	local cx, cz = math.floor(pos.X / 128), math.floor(pos.Z / 128)
	for dx = -1, 1 do
		for dz = -1, 1 do
			local chunkModel = forest:FindFirstChild("Chunk_" .. (cx + dx) .. "_" .. (cz + dz))
			if chunkModel then
				for _, m in chunkModel:GetChildren() do
					if m:GetAttribute("TreeId") == id then
						return m
					end
				end
			end
		end
	end
	return nil
end

local function treeParts(model)
	local list = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(list, { part = d, cf = d.CFrame })
		end
	end
	return list
end

local shaking = {}
local function shakeTree(id, pos)
	if shaking[id] or not near(pos, 120) then
		return
	end
	local model = findTree(id, pos)
	if not model then
		return
	end
	local parts = treeParts(model)
	local pivot = CFrame.new(ground(pos))
	shaking[id] = true
	local age = 0
	table.insert(movers, {
		update = function(dt)
			age += dt
			local a = math.sin(age * 40) * 0.04 * math.max(0, 1 - age / 0.35)
			for _, e in parts do
				if e.part.Parent then
					e.part.CFrame = pivot * CFrame.Angles(a, 0, a * 0.6) * pivot:Inverse() * e.cf
				end
			end
			if age >= 0.35 then
				shaking[id] = nil
				return false
			end
			return true
		end,
	})
end

local function fellTree(d)
	local model = findTree(d.tree, d.pos)
	if not model then
		return
	end
	local parts = treeParts(model)
	local base = ground(d.pos)
	local dir = typeof(d.dir) == "Vector3" and d.dir or Vector3.new(1, 0, 0)
	local axis = Vector3.new(0, 1, 0):Cross(dir)
	if axis.Magnitude < 1e-3 then
		axis = Vector3.new(1, 0, 0)
	end
	axis = axis.Unit
	local age = 0
	local landed = false
	table.insert(movers, {
		update = function(dt)
			age += dt
			local k = math.min(1, (age / 1.1) ^ 2)
			local a = k * math.rad(86)
			local rot = CFrame.fromAxisAngle(axis, a)
			for _, e in parts do
				if e.part.Parent then
					local rel = e.cf.Position - base
					local cf = e.cf - e.cf.Position
					e.part.CFrame = CFrame.new(base + rot * rel) * (rot * cf)
				end
			end
			if k >= 1 and not landed then
				landed = true
				local tip = base + dir * (d.h or 20) * 0.6
				FxController.puff(tip, C.dirt:Lerp(C.cream, 0.5), 10, 3, 1.2)
				FxController.burst(tip, { C.leaf, C.leafDark, C.pine }, 12, 0.6, 14, 1)
				if near(tip, 50) then
					FxController.shake(0.35, 0.3)
				end
			end
			return age < 1.6 and model.Parent ~= nil
		end,
	})
end

-- Projectiles -----------------------------------------------------------------------------------------------------------------------
local function arrow(d)
	if typeof(d.from) ~= "Vector3" or typeof(d.dir) ~= "Vector3" then
		return
	end
	if not near(d.from, 240) then
		return
	end
	local p = chunk(d.from, Vector3.new(0.18, 0.18, 2.4), C.woodDark, M.Wood)
	local tip = chunk(d.from, Vector3.new(0.3, 0.3, 0.4), C.steel, M.Metal)
	local pos, vel = d.from, d.dir.Unit * (d.speed or Constants.ARROW_SPEED)
	local age = 0
	table.insert(movers, {
		update = function(dt)
			age += dt
			vel = vel - Vector3.new(0, Constants.ARROW_GRAVITY * dt, 0)
			local nextPos = pos + vel * dt
			if nextPos.Y < MapLayout.groundY(nextPos.X, nextPos.Z) or age > Constants.PROJECTILE_SECONDS then
				p:Destroy()
				tip:Destroy()
				return false
			end
			p.CFrame = CFrame.lookAt(nextPos, nextPos + vel)
			tip.CFrame = p.CFrame * CFrame.new(0, 0, -1.3)
			pos = nextPos
			return true
		end,
	})
end

local THROWN = {
	firecracker = { color = C.red, size = 0.6 },
	flare = { color = C.fire, size = 0.5, neon = true },
	kermy_bait = { color = C.woodLight, size = 0.9 },
	pinecone = { color = C.bark, size = 0.9 }, -- a Pelter's lob
	boulder = { color = C.rock, size = 1.8 }, -- the camp's catapult
}
local function throw(d)
	if typeof(d.from) ~= "Vector3" or typeof(d.to) ~= "Vector3" then
		return
	end
	local spec = THROWN[d.item] or THROWN.firecracker
	local p = chunk(
		d.from,
		Vector3.new(spec.size, spec.size, spec.size),
		spec.color,
		spec.neon and M.Neon or M.SmoothPlastic,
		"ball"
	)
	local dist = (d.to - d.from).Magnitude
	local seconds = d.seconds or 0.7
	local age = 0
	table.insert(movers, {
		update = function(dt)
			age += dt
			local k = math.min(1, age / seconds)
			p.CFrame = CFrame.new(d.from:Lerp(d.to, k) + Vector3.new(0, math.sin(k * math.pi) * dist * 0.35, 0))
			if k >= 1 then
				p:Destroy()
				return false
			end
			return true
		end,
	})
end

-- Lasting things: a flare, a sandwich, bees ----------------------------------------------------------------------------------------
local function lasting(seconds, build)
	local parts = build()
	local age = 0
	table.insert(movers, {
		update = function(dt)
			age += dt
			if age >= seconds then
				for _, p in parts do
					p:Destroy()
				end
				return false
			end
			return true
		end,
	})
end

-- The server's effects ------------------------------------------------------------------------------------------------------------------
local handlers = {}
function handlers.chop(d)
	FxController.burst(d.pos, { C.woodLight, C.bark, C.wood }, 6, 0.4, 14, 0.6)
	shakeTree(d.tree, d.pos)
end
function handlers.fell(d)
	fellTree(d)
end
function handlers.sparks(d)
	FxController.burst(d.pos, { C.rock, C.rockDark }, 6, 0.5, 16, 0.6)
	FxController.burst(d.pos, C.yellow, 3, 0.18, 22, 0.25, { material = M.Neon })
end
function handlers.clank(d)
	FxController.burst(d.pos, { C.iron, C.steel }, 5, 0.35, 16, 0.5)
	FxController.burst(d.pos, C.warm, 4, 0.15, 24, 0.25, { material = M.Neon })
end
function handlers.arrow(d)
	arrow(d)
end
function handlers.throw(d)
	throw(d)
end
function handlers.bang(d)
	FxController.sphere(d.pos + Vector3.new(0, 1.5, 0), C.yellow, (d.radius or 10) * 0.6, 0.35)
	FxController.burst(d.pos, { C.red, C.yellow, C.fire }, 14, 0.4, 26, 0.6, { material = M.Neon })
	FxController.puff(d.pos, C.rock, 6, 2.5, 1)
	if near(d.pos, 40) then
		FxController.shake(0.3, 0.25)
	end
end
function handlers.flare(d)
	lasting(d.seconds or 30, function()
		local ball = chunk(ground(d.pos) + Vector3.new(0, 0.5, 0), Vector3.new(0.7, 0.7, 0.7), C.red, M.Neon, "ball")
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 90, 70)
		light.Range = math.min(60, d.radius or 30)
		light.Brightness = 3
		light.Parent = ball
		local smoke = Instance.new("ParticleEmitter")
		smoke.Rate = 12
		smoke.Lifetime = NumberRange.new(1.5, 2.5)
		smoke.Speed = NumberRange.new(2, 4)
		smoke.Size = NumberSequence.new(1.2, 3)
		smoke.Color = ColorSequence.new(Color3.fromRGB(255, 120, 110))
		smoke.Transparency = NumberSequence.new(0.5, 1)
		smoke.Parent = ball
		return { ball }
	end)
end
function handlers.bait(d)
	lasting(d.seconds or 10, function()
		local base = ground(d.pos)
		local bread = chunk(base + Vector3.new(0, 0.25, 0), Vector3.new(1.4, 0.3, 1.0), C.woodLight)
		local filling = chunk(base + Vector3.new(0, 0.42, 0), Vector3.new(1.5, 0.12, 1.1), C.green)
		local top = chunk(base + Vector3.new(0, 0.6, 0), Vector3.new(1.4, 0.3, 1.0), C.woodLight)
		local stink = Instance.new("ParticleEmitter")
		stink.Rate = 6
		stink.Lifetime = NumberRange.new(1.5, 2)
		stink.Speed = NumberRange.new(1, 2)
		stink.Size = NumberSequence.new(0.4, 1)
		stink.Color = ColorSequence.new(Color3.fromRGB(150, 210, 80))
		stink.Transparency = NumberSequence.new(0.3, 1)
		stink.Parent = top
		return { bread, filling, top }
	end)
end
function handlers.bees(d)
	lasting(d.seconds or 5, function()
		local swarm = chunk(d.pos + Vector3.new(0, 2, 0), Vector3.new(1, 1, 1), C.yellow)
		swarm.Transparency = 1
		local e = Instance.new("ParticleEmitter")
		e.Rate = 40
		e.Lifetime = NumberRange.new(0.6, 1)
		e.Speed = NumberRange.new(4, 8)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Size = NumberSequence.new(0.25)
		e.Color = ColorSequence.new(Color3.fromRGB(255, 210, 40))
		e.Parent = swarm
		return { swarm }
	end)
end
function handlers.built(d)
	local base = ground(d.pos)
	FxController.ring(base, C.cream, 8, 0.7, 0.6)
	FxController.puff(base, C.cream:Lerp(C.dirt, 0.2), 10, 3, 1.1)
	FxController.burst(d.pos + Vector3.new(0, 3, 0), C.gold, 12, 0.35, 18, 0.8, { material = M.Neon })
	if near(d.pos, 40) then
		FxController.shake(0.2, 0.2)
	end
end
function handlers.repair(d)
	FxController.burst(d.pos + Vector3.new(0, 2, 0), C.green, 6, 0.35, 8, 0.7, { material = M.Neon, gravity = -6 })
end
function handlers.splinter(d)
	FxController.burst(d.pos, { C.wood, C.woodDark, C.plank }, 8, 0.5, 18, 0.8)
end
function handlers.crumble(d)
	FxController.burst(d.pos, { C.wood, C.woodDark, C.stone }, 14, 0.9, 24, 1.2)
	FxController.puff(ground(d.pos), C.cream:Lerp(C.dirt, 0.4), 12, 3.5, 1.3)
	if near(d.pos, 60) then
		FxController.shake(0.5, 0.35)
	end
end
function handlers.goo(d)
	FxController.burst(d.pos, GOO, 6, 0.5, 10, 0.6, { ball = true, material = M.Neon })
end
function handlers.loot(d)
	FxController.burst(d.pos, { C.gold, C.white, C.blueprint }, 12, 0.3, 14, 0.8, { material = M.Neon, gravity = 10 })
	FxController.ring(ground(d.pos), C.gold, 4, 0.5)
end
function handlers.ring(d)
	FxController.ring(ground(d.pos), d.color == "club" and C.orange or C.white, d.radius or 10, 0.45, 0.8)
	if near(d.pos, 30) then
		FxController.shake(0.25, 0.2)
	end
end
function handlers.trapset(d)
	FxController.puff(ground(d.pos), C.dirt, 4, 1.5, 0.6)
end

-- Monster events: tells on the ground, hits, words, stars ------------------------------------------------------------------------------
local function mobFollow(id)
	return function()
		local m = MonsterController.mobs[id]
		local p = MonsterController.position(id)
		if not m or not p then
			return nil
		end
		local s = m.samples[#m.samples]
		local yaw = s and s.yaw or 0
		return p, Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
	end
end

local function onMob(e)
	if type(e) ~= "table" then
		return
	end
	local id = e.id or BOSS_ID
	local m = MonsterController.mobs[id]
	local kind = m and m.kind or (id == BOSS_ID and "mega_kermy" or "snapcap")
	if e.kind == "tell" then
		local seconds = e.seconds or 1
		if e.from and e.to then
			-- Mega Kermy's charge (red) or grab (green): from his feet to where it ends
			local dir = e.to - e.from
			FxController.line(e.from, dir, dir.Magnitude, e.width or 8, seconds, e.tell == "grab" and GOO or RED)
		elseif e.at and e.radius then
			FxController.circle(e.at, e.radius, seconds)
		elseif e.length then
			local follow = mobFollow(id)
			local p, dir = follow()
			if p then
				FxController.line(p, dir, e.length, e.width or 4, seconds, RED, e.tell == "howl" and follow or nil)
			end
		end
		if e.tell == "howl" and m then
			local p = MonsterController.position(id)
			if p then
				FxController.ring(ground(p), Color3.fromRGB(255, 90, 90), 6, 0.5, 0.3)
			end
		end
	elseif e.kind == "jump" and e.to then
		FxController.circle(e.to, 14, e.seconds or 1.6, Color3.fromRGB(30, 30, 40))
	elseif e.kind == "slam" and e.at then
		FxController.ring(ground(e.at), C.cream, e.radius or 10, 0.45, 0.8)
		FxController.puff(ground(e.at), C.dirt:Lerp(C.cream, 0.4), 10, 3.5, 1)
		if e.rings then
			-- shockwave rings rolling out: jump over them
			for k = 1, e.rings do
				task.delay((k - 1) * 0.35, function()
					FxController.ring(
						ground(e.at),
						Color3.fromRGB(150, 255, 110),
						e.ringMax or 60,
						(e.ringMax or 60) / (e.ringSpeed or 30),
						1.4,
						0.2
					)
				end)
			end
		end
		if near(e.at, 80) then
			FxController.shake(id == BOSS_ID and 0.9 or 0.45, 0.4)
		end
	elseif e.kind == "hit" and m then
		local p = MonsterController.position(id)
		if p and e.amount then
			local mine = e.by == player.UserId
			FxController.popup(
				p + Vector3.new(0, (Rigs.HEIGHT[kind] or 4) * 0.7, 0),
				tostring(e.amount) .. (e.crit and "!" or ""),
				e.crit and C.yellow or (mine and C.white or Color3.fromRGB(220, 220, 220)),
				e.crit and 42 or (mine and 32 or 24),
				0.9
			)
		end
	elseif e.kind == "faceplant" or e.kind == "stagger" or e.kind == "ko" then
		if m then
			FxController.stars(
				headOf(id, kind),
				e.kind == "faceplant" and (id == BOSS_ID and 5 or 2.4) or (e.kind == "ko" and 4 or 1.4)
			)
		end
		if e.kind == "faceplant" and e.tree then
			local p = MonsterController.position(id)
			if p then
				FxController.burst(p + Vector3.new(0, 6, 0), { C.leaf, C.bark }, 14, 0.6, 16, 1)
				if near(p, 80) then
					FxController.shake(id == BOSS_ID and 0.8 or 0.3, 0.4)
				end
			end
		end
	elseif e.kind == "die" then
		local p = MonsterController.position(id)
		if p and e.puff then
			FxController.puff(p + Vector3.new(0, 2, 0), Color3.fromRGB(150, 210, 100), 10, 2.5, 1)
		elseif p and not e.fled then
			FxController.puff(p, C.cream, 6, 2, 0.8)
		end
	elseif e.kind == "throw" and typeof(e.from) == "Vector3" and typeof(e.to) == "Vector3" then
		-- a Pelter's pinecone (or the catapult's boulder) arcs over; its landing spot is already circled red
		throw({ from = e.from, to = e.to, seconds = e.seconds or 1, item = e.catapult and "boulder" or "pinecone" })
	elseif e.kind == "land" and typeof(e.at) == "Vector3" then
		local base = ground(e.at)
		FxController.burst(
			base + Vector3.new(0, 0.5, 0),
			e.big and { C.rock, C.rockDark } or { C.bark, C.woodDark },
			e.big and 12 or 7,
			e.big and 0.7 or 0.4,
			16,
			0.7
		)
		FxController.puff(base, C.dirt:Lerp(C.cream, 0.4), e.big and 8 or 4, e.big and 3 or 2, 0.8)
		if e.big and near(e.at, 50) then
			FxController.shake(0.3, 0.25)
		end
	elseif (e.kind == "smash" or e.kind == "spike") and m then
		local p = MonsterController.position(id)
		if p then
			FxController.burst(
				p + Vector3.new(0, 2, 0),
				{ C.wood, C.woodDark, C.plank },
				e.kind == "smash" and 6 or 9,
				0.45,
				14,
				0.6
			)
		end
	elseif e.kind == "trap" and typeof(e.at) == "Vector3" then
		-- snap! (a bear trap's jaws, a snare's rope)
		FxController.burst(ground(e.at) + Vector3.new(0, 0.6, 0), { C.iron, C.steel }, 6, 0.3, 12, 0.5)
		FxController.ring(ground(e.at), C.white, 4, 0.35, 0.4)
	elseif e.kind == "spawn" and id == BOSS_ID then
		FxController.shake(0.7, 1.2)
	elseif e.kind == "rustle" and e.at then
		-- a bush shakes where Kermy will pop out
		task.delay(e.delay or 0, function()
			local base = ground(e.at)
			local bush = Kit.ellipsoid(
				folder,
				"Rustle",
				base + Vector3.new(0, 1.4, 0),
				Vector3.new(4.2, 3, 4.2),
				C.leafDark,
				M.Grass,
				{ CanCollide = false, CanQuery = false, CastShadow = false }
			)
			local age = 0
			table.insert(movers, {
				update = function(dt)
					age += dt
					bush.CFrame = CFrame.new(base + Vector3.new(math.sin(age * 40) * 0.3, 1.4, 0))
						* CFrame.Angles(0, 0, math.sin(age * 30) * 0.12)
					if math.random() < 0.3 then
						FxController.burst(base + Vector3.new(0, 2.5, 0), C.leaf, 1, 0.3, 6, 0.6)
					end
					if age >= (e.seconds or 1.2) + 0.6 then
						bush:Destroy()
						return false
					end
					return true
				end,
			})
		end)
	end
end

-- Pings: a light pillar where your teammate pinged ----------------------------------------------------------------------------------------
local function onPing(ping)
	if type(ping) ~= "table" or typeof(ping.position) ~= "Vector3" then
		return
	end
	local base = ground(ping.position)
	local color = ping.key == "kermy" and RED
		or ping.key == "help" and Color3.fromRGB(255, 120, 60)
		or ping.key == "loot" and C.gold
		or C.blueprint
	local pillar = chunk(base + Vector3.new(0, 30, 0), Vector3.new(60, 1.2, 1.2), color, M.Neon, "cylinder")
	pillar.CFrame = CFrame.new(base + Vector3.new(0, 30, 0)) * CFrame.Angles(0, 0, math.rad(90))
	pillar.Transparency = 0.45
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(180, 50)
	bb.StudsOffsetWorldSpace = Vector3.new(0, -24, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Parent = pillar
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.TextColor3 = C.white
	label.TextStrokeTransparency = 0
	label.Text = `{ping.icon or "📍"} {ping.text or ""}\n{ping.from or ""}`
	label.Parent = bb
	local seconds = Constants.PING_SECONDS
	local age = 0
	table.insert(movers, {
		update = function(dt)
			age += dt
			pillar.Transparency = 0.45 + 0.4 * math.max(0, (age - seconds + 1))
			if age >= seconds then
				pillar:Destroy()
				return false
			end
			return true
		end,
	})
end

-- Mimics breathe (master plan §10: a subtle tell): every few seconds the crate lifts a hair and settles ---------------------------------
local mimics = {} -- [model] = { parts, phase, lift }
local function scanMimics()
	local loot = workspace:FindFirstChild("Loot")
	for _, m in loot and loot:GetChildren() or {} do
		if m:GetAttribute("Mimic") and not m:GetAttribute("Opened") and not mimics[m] then
			mimics[m] = { parts = treeParts(m), phase = math.random() * 3, lift = 0 }
		end
	end
end

local function breathe(clock)
	for m, rec in mimics do
		if not m.Parent or m:GetAttribute("Opened") then
			mimics[m] = nil
		elseif rec.parts[1] and near(rec.parts[1].cf.Position, 90) then
			local k = ((clock + rec.phase) % 3.2) / 0.6 -- a breath every 3.2 s
			local lift = k < 1 and math.sin(k * math.pi) * 0.16 or 0
			if lift ~= rec.lift then
				rec.lift = lift
				for _, e in rec.parts do
					if e.part.Parent then
						e.part.CFrame = e.cf + Vector3.new(0, lift, 0)
					end
				end
			end
		end
	end
end

-- The loop -----------------------------------------------------------------------------------------------------------------------------------
local scanAcc = 0
local function step(dt)
	scanAcc += dt
	if scanAcc >= 2 then
		scanAcc = 0
		scanMimics()
	end
	breathe(os.clock())
	for i = #particles, 1, -1 do
		local q = particles[i]
		q.age += dt
		if q.age >= q.life or not q.part.Parent then
			q.part:Destroy()
			table.remove(particles, i)
		else
			q.vel -= Vector3.new(0, q.gravity * dt, 0)
			local cf = q.part.CFrame
			q.part.CFrame = (cf + q.vel * dt) * CFrame.Angles(q.spin.X * dt, q.spin.Y * dt, q.spin.Z * dt)
			if q.grow then
				q.part.Size = q.part.Size * (1 + (q.grow - 1) * dt / q.life)
			end
			if q.fade then
				q.part.Transparency = math.max(q.part.Transparency, q.age / q.life)
			end
		end
	end
	for i = #movers, 1, -1 do
		local ok, alive = pcall(movers[i].update, dt)
		if not ok or not alive then
			table.remove(movers, i)
		end
	end
	-- the screen shake (the camera offset of your humanoid)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		local now = os.clock()
		if now < shakeUntil then
			local s = shakeStrength * ((shakeUntil - now) / 0.4)
			hum.CameraOffset =
				Vector3.new((math.random() - 0.5) * s, (math.random() - 0.5) * s, (math.random() - 0.5) * s * 0.5)
		elseif hum.CameraOffset ~= Vector3.zero then
			hum.CameraOffset = Vector3.zero
			shakeStrength = 0
		end
	end
end

function FxController:init()
	folder = workspace:FindFirstChild("Fx") or Instance.new("Folder")
	folder.Name = "Fx"
	folder.Parent = workspace
	Net.listen("Fx", function(kind, data)
		local h = handlers[kind]
		if h and type(data) == "table" then
			h(data)
		end
	end)
	Net.listen("Mob", onMob)
	Net.listen("Ping", onPing)
	Net.listen("Popup", function(pos, text, color)
		FxController.popup(pos, text, color, 30, 1.2)
	end)
	Net.listen("Hurt", function(h)
		if type(h) == "table" and (h.amount or 0) > 0 then
			FxController.shake(math.clamp((h.amount or 10) / 40, 0.15, 0.8), 0.25)
		end
	end)
	Bus.Shake:Connect(function(strength, seconds)
		FxController.shake(strength or 0.3, seconds or 0.3)
	end)
	RunService.RenderStepped:Connect(step)
	_ = Items
end

-- (tests)
FxController.particles = particles
FxController.movers = movers
FxController.handlers = handlers
FxController.mimics = mimics

return FxController
