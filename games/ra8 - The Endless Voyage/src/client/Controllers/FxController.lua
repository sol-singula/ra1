--[[
Effects (master plan §4: feedback for every action; §10: travel you can watch). The hook's line flies out and the
piece splashes in; chips fly when you chop and sparks when you mine; a built piece puffs; a storm's waves roll over
the deck and a bite shakes it; harpoons and the turret draw their lines; crates sparkle; a creature's tell is a
red ring on the ground; dolphins jump, a shadow passes under the raft, a whirlpool spins; your lost bag has a marker
in the world. Plus floating "+2 🌳" popups and the screen shake (Settings: effects, screen shake; Reduced Motion
turns shaking off).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Kit = require(ReplicatedStorage.Shared.World.Kit)
local Net = require(ReplicatedStorage.Shared.Net)
local CreatureController = require(script.Parent.CreatureController)
local PerformanceController = require(script.Parent.PerformanceController)
local Bus = require(script.Parent.Parent.UI.Bus)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local FxController = { Name = "FxController", Order = 45 }

local player = Players.LocalPlayer
local C, M = Kit.C, Kit.M
local folder
local particles = {}
local movers = {}
local MAX_PARTICLES = 220
local shakeUntil, shakeStrength = 0, 0
local handlers = {}
local RED = Color3.fromRGB(255, 70, 60)
local BLUE = Color3.fromRGB(150, 210, 240)
local tells = {} -- [creatureId] = untilT

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
	return typeof(pos) == "Vector3" and (pos - camPos()).Magnitude <= (radius or 200)
end

local function water(pos)
	return Vector3.new(pos.X, Constants.WATER_LEVEL + 0.2, pos.Z)
end

-- Primitives ------------------------------------------------------------------------------------------------------
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

-- An expanding flat ring (on the water or the ground).
function FxController.ring(pos, color, radius, life, height, from)
	if not near(pos, 260) then
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

-- A line from a to b that flies out over `fly` seconds and fades over `life`.
function FxController.line(from, to, color, width, fly, life)
	if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" or not near(from, 260) then
		return
	end
	local p = chunk(from, Vector3.new(width, width, 0.1), color, M.Neon)
	local age = 0
	table.insert(movers, {
		update = function(dt)
			age += dt
			local k = math.min(1, age / math.max(0.01, fly))
			local len = math.max(0.1, (to - from).Magnitude * k)
			p.Size = Vector3.new(width, width, len)
			p.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -len / 2)
			if age > fly then
				p.Transparency = math.min(1, (age - fly) / life)
			end
			if age >= fly + life then
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

-- Floating text in the world.
function FxController.popup(pos, text, color, size, seconds)
	if typeof(pos) ~= "Vector3" or not near(pos, 160) then
		return
	end
	local anchor = chunk(pos, Vector3.new(0.2, 0.2, 0.2), C.white)
	anchor.Transparency = 1
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(180, size or 34)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 160
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
	local age, life = 0, seconds or 1.2
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

-- A marker in the world with a label (the lost bag).
function FxController.marker(pos, text, color, seconds)
	if typeof(pos) ~= "Vector3" then
		return
	end
	local anchor = chunk(pos + Vector3.new(0, 3, 0), Vector3.new(0.2, 0.2, 0.2), C.white)
	anchor.Transparency = 1
	local bb = Instance.new("BillboardGui")
	bb.Name = "Marker"
	bb.Size = UDim2.fromOffset(220, 40)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 600
	bb.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color or C.white
	label.TextStrokeTransparency = 0
	label.Parent = bb
	local beam = chunk(pos, Vector3.new(0.4, 40, 0.4), color or C.white, M.Neon)
	beam.CFrame = CFrame.new(pos + Vector3.new(0, 20, 0))
	beam.Transparency = 0.6
	task.delay(seconds or 120, function()
		anchor:Destroy()
		beam:Destroy()
	end)
end

-- Handlers for the server's "Fx" -------------------------------------------------------------------------------------
function handlers.hook(d)
	if typeof(d.from) ~= "Vector3" or typeof(d.to) ~= "Vector3" then
		return
	end
	FxController.line(d.from + Vector3.new(0, 1, 0), d.to, C.rope, 0.12, Constants.HOOK_FLIGHT, 0.5)
	FxController.burst(d.to, BLUE, 6, 0.3, 6, 0.6, { ball = true, up = 1.2 })
end

function handlers.splash(d)
	local pos = d.pos and water(d.pos)
	if not pos then
		return
	end
	FxController.ring(pos, BLUE, d.small and 3 or 6, 0.5, 0.3)
	FxController.burst(pos, { BLUE, C.white }, d.small and 6 or 12, 0.35, 7, 0.7, { ball = true, up = 1.4 })
end

function handlers.cast(d)
	if typeof(d.to) ~= "Vector3" then
		return
	end
	FxController.line(d.from + Vector3.new(0, 1.5, 0), d.to, C.rope, 0.08, 0.4, 0.3)
	-- the bobber sits there until the rod's state changes
	local bob = chunk(d.to, Vector3.new(0.7, 0.7, 0.7), RED, M.SmoothPlastic, "ball")
	local age = 0
	table.insert(movers, {
		update = function(dt)
			age += dt
			local f = Store.get("fish")
			local mine = d.by == player.UserId
			if mine and (not f or f.state == "off" or f.state == "caught" or f.state == "away") or age > 40 then
				bob:Destroy()
				return false
			end
			local dip = f and f.state == "bite" and mine and -0.6 or 0
			bob.CFrame = CFrame.new(d.to + Vector3.new(0, math.sin(age * 3) * 0.15 + dip, 0))
			return true
		end,
	})
end

function handlers.chop(d)
	FxController.burst(d.pos + Vector3.new(0, 2, 0), { C.woodLight, C.plank, C.leaf }, 8, 0.35, 9, 0.8)
	FxController.shake(0.12, 0.1)
end

function handlers.fell(d)
	FxController.burst(d.pos + Vector3.new(0, 4, 0), { C.leaf, C.leafLight, C.bark }, 22, 0.5, 11, 1.1)
	FxController.puff(d.pos, C.sand or Color3.fromRGB(220, 200, 150), 6, 1.5, 1)
	FxController.shake(0.25, 0.2)
end

function handlers.sparks(d)
	FxController.burst(
		d.pos + Vector3.new(0, 1.5, 0),
		{ Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 160, 60) },
		8,
		0.2,
		10,
		0.5,
		{ material = M.Neon, up = 1.2 }
	)
end

function handlers.clank(d)
	FxController.burst(d.pos + Vector3.new(0, 1.5, 0), { C.iron, C.steel }, 6, 0.25, 8, 0.6)
end

function handlers.crumble(d)
	FxController.burst(d.pos + Vector3.new(0, 1, 0), { C.rock, C.rockDark }, 16, 0.6, 9, 1, { material = M.Rock })
	FxController.puff(d.pos, C.rock, 5, 1.6, 0.9)
	FxController.shake(0.2, 0.15)
end

function handlers.built(d)
	FxController.puff(d.pos, Color3.fromRGB(230, 215, 180), 8, 1.4, 0.9)
	FxController.burst(
		d.pos + Vector3.new(0, 1, 0),
		{ C.gold, C.white },
		10,
		0.25,
		7,
		0.7,
		{ material = M.Neon, up = 1.5 }
	)
end

function handlers.demolish(d)
	FxController.puff(d.pos, C.sand or Color3.fromRGB(210, 190, 150), 8, 1.6, 1)
	FxController.burst(d.pos + Vector3.new(0, 1, 0), { C.plank, C.woodDark }, 10, 0.4, 7, 0.9)
end

function handlers.crack(d)
	FxController.burst(d.pos + Vector3.new(0, 0.6, 0), { C.woodDark, C.bark }, 6, 0.3, 6, 0.6)
	FxController.shake(0.15, 0.12)
end

function handlers.repair(d)
	FxController.burst(
		d.pos + Vector3.new(0, 1, 0),
		{ C.gold, Color3.fromRGB(140, 230, 140) },
		8,
		0.22,
		6,
		0.6,
		{ material = M.Neon, up = 1.5 }
	)
end

function handlers.wave(d)
	local c = d.center and water(d.center)
	if not c then
		return
	end
	FxController.ring(c, BLUE, 44, 1.6, 0.6, 0.05)
	FxController.burst(
		c + Vector3.new((math.random() - 0.5) * 20, 0, (math.random() - 0.5) * 20),
		{ BLUE, C.white },
		14,
		0.5,
		9,
		1,
		{ ball = true, up = 1.6 }
	)
	FxController.shake(0.3, 0.4)
end

function handlers.storm()
	FxController.shake(0.25, 0.6)
end

function handlers.bite(d)
	local pos = d.pos
	if pos then
		FxController.burst(pos, { RED, C.woodDark }, 10, 0.35, 8, 0.7)
	end
	FxController.shake(0.35, 0.3)
end

function handlers.harpoon(d)
	FxController.line(d.from, d.to, C.steel, 0.18, (d.to - d.from).Magnitude / Constants.HARPOON_SPEED, 0.4)
end

function handlers.turret(d)
	FxController.line(d.from, d.to, Color3.fromRGB(255, 220, 120), 0.14, 0.12, 0.3)
	FxController.burst(d.to, { RED, C.white }, 6, 0.25, 6, 0.5)
end

function handlers.loot(d)
	if d.pos then
		FxController.burst(
			d.pos + Vector3.new(0, 2, 0),
			{ C.gold, C.white, C.mustard },
			16,
			0.25,
			7,
			0.9,
			{ material = M.Neon, up = 1.6 }
		)
	end
end

function handlers.discover(d)
	if d.pos then
		FxController.ring(d.pos, C.gold, 10, 1.2, 0.4)
		FxController.burst(
			d.pos + Vector3.new(0, 2, 0),
			{ C.gold, C.white },
			20,
			0.3,
			8,
			1,
			{ material = M.Neon, up = 1.8 }
		)
	end
end

function handlers.puzzle(d)
	if d.pos then
		FxController.ring(d.pos, C.warm, 4, 0.6, 0.3)
	end
end

function handlers.net(d)
	if d.pos then
		FxController.burst(water(d.pos), BLUE, 5, 0.3, 5, 0.5, { ball = true, up = 1.2 })
	end
end

function handlers.down(d)
	if d.pos then
		FxController.puff(d.pos, Color3.fromRGB(120, 120, 130), 6, 1.2, 1)
	end
end

function handlers.sail(d)
	FxController.shake(0.15, 0.5)
	if d.center then
		FxController.ring(water(d.center), C.white, 30, 1.4, 0.3, 0.3)
	end
end

function handlers.dolphins(d)
	local c = d.center and water(d.center)
	if not c or not near(c, 300) then
		return
	end
	for i = 1, 3 do
		local fin = chunk(c, Vector3.new(0.5, 1.6, 2.6), Color3.fromRGB(120, 140, 160), M.SmoothPlastic)
		local age, phase = 0, i * 2
		table.insert(movers, {
			update = function(dt)
				age += dt
				local a = age * 0.6 + phase
				local r = 26 + i * 4
				local jump = math.max(0, math.sin(age * 2 + phase)) * 4
				local pos = c + Vector3.new(math.cos(a) * r, jump - 0.5, math.sin(a) * r)
				fin.CFrame = CFrame.lookAt(pos, pos + Vector3.new(-math.sin(a), jump > 2 and 0.3 or -0.1, math.cos(a)))
				if age > 12 then
					fin:Destroy()
					return false
				end
				return true
			end,
		})
	end
end

function handlers.shadow(d)
	local c = d.center and water(d.center)
	if not c or not near(c, 300) then
		return
	end
	local body = chunk(c, Vector3.new(14, 4, 60), Color3.fromRGB(10, 25, 40), M.SmoothPlastic)
	body.Transparency = 0.35
	local age = 0
	table.insert(movers, {
		update = function(dt)
			age += dt
			local x = -80 + age * 14
			body.CFrame = CFrame.new(c + Vector3.new(x, -6 - math.sin(age) * 1.5, 10))
				* CFrame.Angles(0, math.rad(90), 0)
			if age > 11 then
				body:Destroy()
				return false
			end
			return true
		end,
	})
	FxController.shake(0.1, 1)
end

function handlers.whirlpool(d)
	local c = d.center and water(d.center)
	if not c then
		return
	end
	local age = 0
	local rings = {}
	for i = 1, 3 do
		local p = chunk(c, Vector3.new(0.3, 20 + i * 12, 20 + i * 12), BLUE, M.Neon, "cylinder")
		p.Transparency = 0.5
		rings[i] = p
	end
	table.insert(movers, {
		update = function(dt)
			age += dt
			for i, p in rings do
				p.CFrame = CFrame.new(c)
					* CFrame.Angles(0, age * (1.5 - i * 0.3), 0)
					* CFrame.Angles(0, 0, math.rad(90))
			end
			if age > (d.seconds or 16) then
				for _, p in rings do
					p:Destroy()
				end
				return false
			end
			return true
		end,
	})
	FxController.shake(0.2, 2)
end

-- Creature events: tells, hits, deaths, surfacing.
local function onCreature(e)
	if type(e) ~= "table" then
		return
	end
	if e.kind == "tell" then
		tells[e.id] = os.clock() + (e.seconds or 0.6)
	elseif e.kind == "hit" and e.pos then
		FxController.burst(e.pos + Vector3.new(0, 1.5, 0), { RED, C.white }, 5, 0.25, 6, 0.5)
	elseif e.kind == "die" and e.pos then
		FxController.burst(
			e.pos + Vector3.new(0, 1.5, 0),
			{ RED, Color3.fromRGB(120, 120, 130) },
			e.boss and 60 or 14,
			e.boss and 1.2 or 0.4,
			e.boss and 16 or 8,
			1.2
		)
		if e.boss then
			FxController.ring(water(e.pos), C.gold, 40, 2, 0.6)
			FxController.shake(0.8, 1.2)
		end
	elseif e.kind == "surface" and e.pos then
		FxController.ring(water(e.pos), BLUE, e.boss and 16 or 6, 0.8, 0.4)
		FxController.burst(water(e.pos), { BLUE, C.white }, 12, 0.4, 8, 0.8, { ball = true, up = 1.5 })
		if e.boss then
			FxController.shake(0.4, 0.6)
		end
	elseif e.kind == "bite" and e.pos then
		FxController.shake(0.35, 0.3)
	end
end

-- The tells' rings under creatures (every frame while they play).
local tellRings = {}
local function updateTells(clock)
	for id, untilT in tells do
		local pos = CreatureController.position(id)
		if clock > untilT or not pos then
			tells[id] = nil
			if tellRings[id] then
				tellRings[id]:Destroy()
				tellRings[id] = nil
			end
		else
			local m = CreatureController.get(id)
			local radius = (m and m.def.range or 4) + 1
			local ring = tellRings[id]
			if not ring then
				ring = chunk(pos, Vector3.new(0.15, radius * 2, radius * 2), RED, M.Neon, "cylinder")
				ring.Transparency = 0.4
				tellRings[id] = ring
			end
			ring.CFrame = CFrame.new(pos - Vector3.new(0, (m and m.def.where == "island") and 0.8 or -0.2, 0))
				* CFrame.Angles(0, 0, math.rad(90))
		end
	end
end

-- The loop ----------------------------------------------------------------------------------------------------------------
local function step(dt)
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
	updateTells(os.clock())
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
	Net.listen("Creature", onCreature)
	Net.listen("Popup", function(pos, text, color)
		FxController.popup(pos, text, color, 30, 1.2)
	end)
	Net.listen("Hurt", function(h)
		if type(h) == "table" and (h.amount or 0) > 0 then
			FxController.shake(math.clamp((h.amount or 10) / 40, 0.15, 0.8), 0.25)
		end
	end)
	Net.listen("Lost", function(l)
		if type(l) == "table" and typeof(l.pos) == "Vector3" then
			FxController.marker(
				l.pos,
				"🎒 YOUR LOST BAG",
				Theme.Color.mustard,
				l.seconds or Constants.LOST_BAG_SECONDS
			)
		end
	end)
	Bus.Shake:Connect(function(strength, seconds)
		FxController.shake(strength or 0.3, seconds or 0.3)
	end)
	RunService.RenderStepped:Connect(step)
end

-- (tests)
FxController.particles = particles
FxController.movers = movers
FxController.handlers = handlers

return FxController
