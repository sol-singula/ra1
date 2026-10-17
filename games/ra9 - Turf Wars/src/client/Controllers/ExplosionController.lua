--[[
The TNT on screen (drawn on each client): a thrown bundle flying its lob (the same curve the server flies,
Formulas.lobAt, timed by server time; your own drawn the moment you let go), tumbling, its fuse spitting sparks; and
where it goes off (Net "Blast") the explosion everyone sees:

  * a white flash and a light, then a fireball: a hot core, an orange ball and a dark red one rolling up, each
    growing and burning out in turn
  * smoke puffs rolling out and up, sparks flying in every direction and falling
  * a shockwave ring racing out across the floor, and a scorch mark left a moment
  * clods of floor thrown up that rain back down (DebrisController.burst); the structures it breaks shatter on their
    own (DebrisController)
  * the store art's neon on top: a ring in the thrower's colour and a burst of white and coloured shards (Effects)
  * the camera shakes, harder the closer you are, and a boom from where it went off (AudioController's layered
    "boom": a sub, a crack, debris and a hall tail; quieter far away, and the arena dips around it when it's close)

Anything else can set one off: ExplosionController.blast{ pos, radius, color?, team? } (Effects.explosion does).

Fewer smoke puffs, sparks and clods on phones and low graphics (GraphicsController.tier()).

  ExplosionController.predict(origin, velocity, team, shotId)   your own throw, at once
  ExplosionController.blast(info)                               (the Blast message; tests call it directly)
  ExplosionController.bombs() / .effects()                      (tests)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Effects = require(script.Parent.Parent.FX.Effects)
local AudioController = require(script.Parent.AudioController)
local CameraController = require(script.Parent.CameraController)
local DebrisController = require(script.Parent.DebrisController)
local GraphicsController = require(script.Parent.GraphicsController)

local ExplosionController = { Name = "ExplosionController", Order = 25 }

local player = Players.LocalPlayer
local folder
local live = {} -- [key] = { model, sticks, spark, origin, velocity, born, team }
local byServer = {} -- [serverId] = key
local fx = {} -- { part, born, life, kind, ... } the explosion's pieces, each animated by its kind
local rng = Random.new()
local INK = Color3.fromRGB(30, 30, 34)

local COUNTS = {
	high = { smoke = 12, sparks = 26, clods = 12 },
	mid = { smoke = 8, sparks = 16, clods = 7 },
	low = { smoke = 4, sparks = 8, clods = 3 },
}

local function getFolder()
	if not folder or not folder.Parent then
		folder = Instance.new("Folder")
		folder.Name = "BlastFx"
		folder.Parent = workspace
	end
	return folder
end

local function part(size, color, neon, shape)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Parent = getFolder()
	return p
end

-- The bundle in flight: three red sticks, a dark band, the fuse and its spark
local function spawnBomb(key, origin, velocity, team, born)
	local sticks = {}
	for i = 1, 3 do
		local s = part(Vector3.new(1.3, 0.38, 0.38), Constants.TNT_RED, false, Enum.PartType.Cylinder)
		s.Name = "TntStick"
		sticks[i] = s
	end
	local band = part(Vector3.new(0.2, 0.86, 0.86), INK, false)
	band.Name = "TntBand"
	local spark = part(Vector3.new(0.3, 0.3, 0.3), Color3.fromRGB(255, 200, 70), true, Enum.PartType.Ball)
	spark.Name = "TntSpark"
	live[key] = {
		sticks = sticks,
		band = band,
		spark = spark,
		origin = origin,
		velocity = velocity,
		born = born,
		team = team,
		spin = Vector3.new(rng:NextNumber(5, 9), rng:NextNumber(-4, 4), rng:NextNumber(2, 5)),
	}
	return live[key]
end

local function removeBomb(key)
	local b = live[key]
	if not b then
		return
	end
	live[key] = nil
	for _, s in b.sticks do
		s:Destroy()
	end
	b.band:Destroy()
	b.spark:Destroy()
end

function ExplosionController.predict(origin, velocity, team, shotId)
	return spawnBomb("me" .. tostring(shotId), origin, velocity, team, workspace:GetServerTimeNow())
end

-- one piece of the explosion: kind "grow" (a ball from s0 to s1 while it fades), "ring" (a flat disc racing out),
-- "spark" (flies and falls), "smoke" (rolls out and up), "scorch" (lies there and fades), "light"
local function effect(kind, p, life, extra)
	local e = extra or {}
	e.kind, e.part, e.life, e.born = kind, p, life, os.clock()
	table.insert(fx, e)
	return e
end

function ExplosionController.blast(info)
	if type(info) ~= "table" or typeof(info.pos) ~= "Vector3" then
		return
	end
	local pos = info.pos
	local radius = tonumber(info.radius) or Constants.TNT_RADIUS
	local ground = tonumber(info.ground) or pos.Y
	local counts = COUNTS[GraphicsController.tier()] or COUNTS.low
	-- (the bundle that made it is gone now)
	if info.id ~= nil then
		removeBomb(byServer[info.id] or ("s" .. tostring(info.id)))
		byServer[info.id] = nil
	end
	-- the flash and its light
	local flash = part(Vector3.new(2, 2, 2), Color3.fromRGB(255, 252, 235), true, Enum.PartType.Ball)
	flash.Name = "Flash"
	flash.CFrame = CFrame.new(pos)
	effect("grow", flash, 0.18, { s0 = 2, s1 = radius * 1.5, at = pos, t0 = 0 })
	local lamp = part(Vector3.new(0.2, 0.2, 0.2), Color3.new(1, 1, 1), false)
	lamp.Name = "BlastLight"
	lamp.Transparency = 1
	lamp.CFrame = CFrame.new(pos + Vector3.new(0, 2, 0))
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 170, 70)
	light.Range = radius * 4
	light.Brightness = 8
	light.Parent = lamp
	effect("light", lamp, 0.6, { light = light })
	-- the fireball: a hot core, an orange ball, a dark red one rolling up
	local layers = {
		{ Color3.fromRGB(255, 236, 160), 1, radius * 1.15, 0.45, 0 },
		{ Color3.fromRGB(255, 122, 20), 1.5, radius * 1.75, 0.65, 2 },
		{ Color3.fromRGB(180, 36, 16), 2, radius * 2.1, 0.9, 4.5 },
	}
	for i, l in layers do
		local ball = part(Vector3.new(l[2], l[2], l[2]), l[1], true, Enum.PartType.Ball)
		ball.Name = "Fireball"
		ball.CFrame = CFrame.new(pos)
		ball.Transparency = 0.05 * i
		effect("grow", ball, l[4], { s0 = l[2], s1 = l[3], at = pos, rise = l[5], t0 = 0.05 * i })
	end
	-- smoke puffs rolling out and up
	for _ = 1, counts.smoke do
		local grey = rng:NextInteger(70, 130)
		local puff = part(Vector3.new(2, 2, 2), Color3.fromRGB(grey, grey, grey + 4), false, Enum.PartType.Ball)
		puff.Name = "Smoke"
		puff.CFrame = CFrame.new(pos)
		puff.Transparency = 1
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.1, 0.9), rng:NextNumber(-1, 1)).Unit
		effect("smoke", puff, rng:NextNumber(1.4, 2.2), {
			from = pos,
			to = pos + dir * radius * rng:NextNumber(0.5, 1) + Vector3.new(0, rng:NextNumber(3, 7), 0),
			s0 = rng:NextNumber(2, 3.5),
			s1 = rng:NextNumber(6, 10),
		})
	end
	-- sparks in every direction
	for _ = 1, counts.sparks do
		local s = part(Vector3.new(0.18, 0.18, 1.1), Color3.fromRGB(255, rng:NextInteger(150, 230), 60), true)
		s.Name = "BlastSpark"
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.1, 1.2), rng:NextNumber(-1, 1)).Unit
		s.CFrame = CFrame.lookAt(pos, pos + dir)
		effect("spark", s, rng:NextNumber(0.45, 0.9), { pos = pos, vel = dir * rng:NextNumber(35, 70) })
	end
	-- the shockwave across the floor, and a scorch mark
	local flat = CFrame.new(pos.X, ground + 0.12, pos.Z) * CFrame.Angles(0, 0, math.rad(90))
	local ring = part(Vector3.new(0.2, 2, 2), Color3.fromRGB(255, 236, 200), true, Enum.PartType.Cylinder)
	ring.Name = "Shockwave"
	ring.CFrame = flat
	ring.Transparency = 0.15
	effect("ring", ring, 0.5, { cf = flat, s0 = 2, s1 = radius * 2.6 })
	local ring2 = part(Vector3.new(0.12, 2, 2), Color3.fromRGB(210, 205, 196), false, Enum.PartType.Cylinder)
	ring2.Name = "Shockwave"
	ring2.CFrame = flat * CFrame.new(0.04, 0, 0)
	ring2.Transparency = 0.3
	effect("ring", ring2, 0.8, { cf = flat * CFrame.new(0.04, 0, 0), s0 = 2, s1 = radius * 3.2 })
	local scorch =
		part(Vector3.new(0.06, radius * 1.1, radius * 1.1), Color3.fromRGB(40, 36, 34), false, Enum.PartType.Cylinder)
	scorch.Name = "Scorch"
	scorch.CFrame = flat * CFrame.new(-0.05, 0, 0)
	scorch.Transparency = 0.35
	effect("scorch", scorch, 3)
	-- clods of floor thrown up (they rain back down)
	if pos.Y - ground < 3 then
		DebrisController.burst(
			Vector3.new(pos.X, ground, pos.Z),
			Color3.fromRGB(205, 200, 192),
			counts.clods,
			1,
			ground
		)
	end
	-- the shake and the boom, by how far off you are
	local cam = workspace.CurrentCamera
	local d = cam and (cam.CFrame.Position - pos).Magnitude or 0
	local near = math.clamp(1 - d / 110, 0, 1)
	if near > 0 then
		CameraController.shake(0.12 + 0.9 * near * near, 0.25 + 0.45 * near)
	end
	-- the store art's neon: a ring in the thrower's colour racing out, white and coloured shards flying off
	local tint = typeof(info.color) == "Color3" and info.color or Constants.TEAM_COLOR[info.team or ""]
	if tint then
		local glowRing = part(Vector3.new(0.16, 2, 2), tint, true, Enum.PartType.Cylinder)
		glowRing.Name = "Shockwave"
		glowRing.CFrame = flat * CFrame.new(0.08, 0, 0)
		effect("ring", glowRing, 0.42, { cf = flat * CFrame.new(0.08, 0, 0), s0 = 2, s1 = radius * 2.2 })
	end
	Effects.shatter({ pos = pos, dir = Vector3.yAxis, team = info.team, power = 1.4, scale = 0.7 })
	-- the boom from where it went off (3D: it rolls off with distance and comes from its side), duller far away
	local near2 = math.clamp(1 - d / 220, 0.25, 1)
	AudioController.playAt("boom", pos, 1 + rng:NextNumber(-0.05, 0.05), near2)
	if d < 60 then
		AudioController.duck(0.4 * (1 - d / 60), 0.5)
	end
end

local function step(dt)
	dt = math.clamp(dt or 1 / 60, 0, 1 / 15)
	local now = workspace:GetServerTimeNow()
	for key, b in live do
		local t = now - b.born
		if t > Constants.TNT_FUSE + 0.6 then
			removeBomb(key)
		else
			local p = Formulas.lobAt(b.origin, b.velocity, math.min(t, Constants.TNT_FUSE))
			local turn = CFrame.Angles(b.spin.X * t, b.spin.Y * t, b.spin.Z * t)
			local cf = CFrame.new(p) * turn
			local spots = { Vector3.new(0, 0.2, 0.2), Vector3.new(0, 0.2, -0.2), Vector3.new(0, -0.18, 0) }
			for i, s in b.sticks do
				s.CFrame = cf * CFrame.new(spots[i])
			end
			b.band.CFrame = cf
			b.spark.CFrame = cf * CFrame.new(0.75, 0.05, 0)
			local flick = 0.24 + math.abs(math.sin(t * 57)) * 0.22
			b.spark.Size = Vector3.new(flick, flick, flick)
		end
	end
	local clock = os.clock()
	for i = #fx, 1, -1 do
		local e = fx[i]
		local f = (clock - e.born) / e.life
		if f >= 1 or not e.part.Parent then
			e.part:Destroy()
			table.remove(fx, i)
		elseif e.kind == "grow" then
			local g = math.clamp((clock - e.born - (e.t0 or 0)) / (e.life * 0.6), 0, 1)
			local s = e.s0 + (e.s1 - e.s0) * (1 - (1 - g) ^ 3)
			e.part.Size = Vector3.new(s, s, s)
			e.part.CFrame = CFrame.new(e.at + Vector3.new(0, (e.rise or 0) * f, 0))
			e.part.Transparency = math.clamp(f * f * 1.1, 0, 1)
		elseif e.kind == "ring" then
			local s = e.s0 + (e.s1 - e.s0) * (1 - (1 - f) ^ 2)
			e.part.Size = Vector3.new(e.part.Size.X, s, s)
			e.part.CFrame = e.cf
			e.part.Transparency = 0.15 + 0.85 * f
		elseif e.kind == "spark" then
			e.vel += Vector3.new(0, -80 * dt, 0)
			e.pos += e.vel * dt
			local v = e.vel.Magnitude > 0.01 and e.vel.Unit or Vector3.new(0, 1, 0)
			e.part.CFrame = CFrame.lookAt(e.pos, e.pos + v)
			e.part.Transparency = f * f
		elseif e.kind == "smoke" then
			local g = 1 - (1 - f) ^ 2
			local s = e.s0 + (e.s1 - e.s0) * g
			e.part.Size = Vector3.new(s, s, s)
			e.part.CFrame = CFrame.new(e.from:Lerp(e.to, g))
			-- (in quickly behind the fireball, then thinning out)
			e.part.Transparency = f < 0.12 and 1 - f / 0.12 * 0.7 or 0.3 + 0.7 * ((f - 0.12) / 0.88)
		elseif e.kind == "scorch" then
			e.part.Transparency = 0.35 + 0.65 * math.clamp((f - 0.6) / 0.4, 0, 1)
		elseif e.kind == "light" then
			e.light.Brightness = 8 * (1 - f) ^ 2
		end
	end
end

function ExplosionController.bombs()
	local n = 0
	for _ in live do
		n += 1
	end
	return n
end

function ExplosionController.effects(kind)
	local n = 0
	for _, e in fx do
		if not kind or e.kind == kind then
			n += 1
		end
	end
	return n
end

function ExplosionController:init()
	getFolder()
	Net.listen("Bomb", function(b)
		if type(b) ~= "table" then
			return
		end
		if b.by == player.UserId then
			byServer[b.id] = "me" .. tostring(b.shotId)
			if live[byServer[b.id]] then
				return -- (already drawn: the prediction)
			end
		end
		local key = "s" .. tostring(b.id)
		byServer[b.id] = byServer[b.id] or key
		spawnBomb(byServer[b.id], b.origin, b.velocity, b.team, b.at or workspace:GetServerTimeNow())
	end)
	Net.listen("Blast", function(info)
		ExplosionController.blast(info)
	end)
	RunService.RenderStepped:Connect(step)
end

return ExplosionController
