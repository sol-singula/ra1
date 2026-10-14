--[[
Effects (master plan §13 big moments, §14 look): rocks fly when you mine, dust and sparks when you hammer, walls
rise and crumble, arrows and goo fly, bombs blink then blow, shields and wards shimmer, the plague turns a dwarf
in a column of green smoke, a falling shrine flashes and shakes the screen. Also the light of each phase (it
blends: afternoon, a cloud at the first scare, the plague's purple sunset, the attack's orange, the last stand's
red night), gates that swing open for dwarves, shrine crystals that turn, and the beacons of your team's pings.
Phones can turn effects down (Settings: effects, screen shake) and Reduced Motion turns the shaking off.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Kit = require(ReplicatedStorage.Shared.World.Kit)
local LightingPresets = require(ReplicatedStorage.Shared.World.LightingPresets)
local Looks = require(ReplicatedStorage.Shared.Data.Looks)
local Net = require(ReplicatedStorage.Shared.Net)
local PerformanceController = require(script.Parent.PerformanceController)
local Bus = require(script.Parent.Parent.UI.Bus)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local FxController = { Name = "FxController", Order = 45 }

local player = Players.LocalPlayer
local C, M = Kit.C, Kit.M
local folder
local particles = {} -- { part, vel, life, age, spin, shrink, fade }
local movers = {} -- { update = fn(dt) -> alive }
local MAX_PARTICLES = 260 -- (lite mode: half)

local function full()
	return #particles >= (PerformanceController.lite and MAX_PARTICLES // 2 or MAX_PARTICLES)
end
local shakeUntil, shakeStrength = 0, 0
local light = { from = "build", to = "build", t = 1 }

local function settings()
	return Store.get("settings") or {}
end

local function fxOn()
	return settings().fx ~= false
end

local function camPos()
	local cam = workspace.CurrentCamera
	return cam and cam.CFrame and cam.CFrame.Position or Vector3.new()
end

local function near(pos, radius)
	return (pos - camPos()).Magnitude <= (radius or 160)
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
		local col = color
		if opts.rainbow then
			col = Looks.RAINBOW[math.random(1, #Looks.RAINBOW)]
		end
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
			spin = Vector3.new(),
			gravity = -2,
			grow = 1.8,
			fade = true,
		})
	end
end

-- An expanding flat ring on the ground.
function FxController.ring(pos, color, radius, life, height)
	if not near(pos, 220) then
		return
	end
	local p = chunk(pos + Vector3.new(0, 0.3, 0), Vector3.new(height or 0.4, 1, 1), color, M.Neon)
	p.Shape = Enum.PartType.Cylinder
	p.CFrame = CFrame.new(pos + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
	p.Transparency = 0.2
	local age = 0
	table.insert(movers, {
		update = function(dt)
			age += dt
			local k = math.min(1, age / life)
			local d = radius * 2 * (0.15 + 0.85 * k)
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

-- A sphere that grows and fades (explosions, flashes).
function FxController.sphere(pos, color, radius, life)
	if not near(pos, 260) then
		return
	end
	local p = chunk(pos, Vector3.new(1, 1, 1), color, M.Neon, "ball")
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

-- A bubble that stays for a while (shields, wards), following a part if given.
function FxController.dome(pos, color, radius, seconds, follow)
	local p = chunk(pos, Vector3.new(radius * 2, radius * 2, radius * 2), color, M.ForceField, "ball")
	p.Transparency = 0.55
	local age = 0
	table.insert(movers, {
		update = function(dt)
			age += dt
			if follow and follow.Parent then
				p.CFrame = CFrame.new(follow.Position)
			end
			if age >= seconds then
				p:Destroy()
				return false
			end
			p.Transparency = 0.55 + 0.4 * math.max(0, (age - seconds + 0.4) / 0.4)
			return true
		end,
	})
end

-- A flying projectile: arrows fly straight, goo and bombs arc.
local PROJECTILE = {
	arrow = { size = Vector3.new(0.2, 0.2, 2.6), color = C.woodDark, arc = 0.04 },
	goo = { size = Vector3.new(1.3, 1.3, 1.3), color = C.plague, arc = 0.18, ball = true, neon = true },
	hex = { size = Vector3.new(1.1, 1.1, 1.1), color = C.magic, arc = 0.06, ball = true, neon = true },
	mend = { size = Vector3.new(1, 1, 1), color = C.green, arc = 0.08, ball = true, neon = true },
}
function FxController.projectile(from, to, style, speed)
	if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" then
		return
	end
	if not near(from, 220) and not near(to, 220) then
		return
	end
	local spec = PROJECTILE[style] or PROJECTILE.arrow
	local p = chunk(from, spec.size, spec.color, spec.neon and M.Neon or M.Wood, spec.ball and "ball")
	local dist = (to - from).Magnitude
	local duration = math.clamp(dist / (speed or 120), 0.05, 1.2)
	local age = 0
	local trailAcc = 0
	table.insert(movers, {
		update = function(dt)
			age += dt
			local k = math.min(1, age / duration)
			local pos = from:Lerp(to, k) + Vector3.new(0, math.sin(k * math.pi) * dist * spec.arc, 0)
			local ahead = from:Lerp(to, math.min(1, k + 0.05))
				+ Vector3.new(0, math.sin(math.min(1, k + 0.05) * math.pi) * dist * spec.arc, 0)
			if (ahead - pos).Magnitude > 1e-3 then
				p.CFrame = CFrame.lookAt(pos, ahead)
			else
				p.CFrame = CFrame.new(pos)
			end
			trailAcc += dt
			if spec.ball and trailAcc > 0.04 and fxOn() then
				trailAcc = 0
				FxController.puff(pos, spec.color, 1, 0.6, 0.3)
			end
			if k >= 1 then
				p:Destroy()
				if style == "goo" or style == "hex" then
					FxController.burst(to, spec.color, 6, 0.5, 10, 0.5, { ball = true })
				elseif style == "mend" then
					FxController.ring(to - Vector3.new(0, 2, 0), C.green, 3, 0.4)
				end
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

-- The effects the server asks for ---------------------------------------------------------------------------------
local BUILD_FX = {
	dust = { color = C.cream:Lerp(C.dirt, 0.3) },
	hearts = { color = C.flowerPink },
	sparkles = { color = C.gold, neon = true },
	confetti = { color = C.blue, rainbow = true },
	lightning = { color = C.crystal, neon = true },
}
local NODE_COLOR = { stone = C.rock, wood = C.woodLight, gold = C.gold }
local CASTLE_DEBRIS = { C.castle, C.castleDark, C.stone, C.wood }

local handlers = {}
function handlers.mine(d)
	FxController.burst(
		d.position + Vector3.new(0, 2.5, 0),
		NODE_COLOR[d.kind] or C.rock,
		7,
		0.6,
		18,
		0.7,
		{ material = d.kind == "gold" and M.Neon or nil }
	)
end
function handlers.deplete(d)
	FxController.puff(d.position, C.cream, 6, 3, 0.9)
end
function handlers.regrow(d)
	FxController.burst(d.position + Vector3.new(0, 2, 0), C.leafLight, 5, 0.5, 8, 0.6, { ball = true, gravity = -4 })
end
function handlers.placed(d)
	FxController.ring(d.position - Vector3.new(0, 4, 0), C.blueprint, 6, 0.5)
end
function handlers.hammer(d)
	local style = BUILD_FX[d.style] or BUILD_FX.dust
	FxController.burst(
		d.position,
		style.color,
		6,
		0.55,
		16,
		0.6,
		{ rainbow = style.rainbow, material = style.neon and M.Neon or nil }
	)
	FxController.burst(d.position, C.gold, 3, 0.25, 22, 0.35, { material = M.Neon })
end
function handlers.built(d)
	local base = d.position - Vector3.new(0, (d.size and d.size.Y or 8) / 2, 0)
	FxController.ring(base, C.cream, math.max(6, (d.size and math.max(d.size.X, d.size.Z) or 8)), 0.7, 0.6)
	FxController.puff(base, C.cream:Lerp(C.dirt, 0.2), 10, 3.5, 1.1)
	FxController.burst(d.position, C.gold, 12, 0.4, 20, 0.8, { material = M.Neon })
	if near(d.position, 40) then
		FxController.shake(0.25, 0.25)
	end
end
function handlers.fix(d)
	FxController.burst(d.position, C.green, 6, 0.4, 10, 0.6, { material = M.Neon, gravity = -6 })
end
function handlers.pieceHit(d)
	FxController.burst(d.position, C.castleDark, 4, 0.6, 14, 0.6)
	if near(d.position, 30) then
		FxController.shake(0.15, 0.12)
	end
end
function handlers.crumble(d)
	local size = d.size or Vector3.new(8, 8, 4)
	for k = 1, 3 do
		FxController.burst(d.position + Vector3.new(0, size.Y * (k - 2) * 0.25, 0), CASTLE_DEBRIS[k], 6, 1.4, 26, 1.4)
	end
	FxController.puff(d.position - Vector3.new(0, size.Y / 2, 0), C.cream:Lerp(C.dirt, 0.4), 12, 4, 1.4)
	if near(d.position, 60) then
		FxController.shake(0.6, 0.4)
	end
end
function handlers.projectile(d)
	FxController.projectile(d.from, d.to, d.style, d.speed)
end
function handlers.goo(d)
	local p =
		chunk(d.position + Vector3.new(0, 0.12, 0), Vector3.new(0.2, d.radius * 2, d.radius * 2), C.plague, M.Neon)
	p.Shape = Enum.PartType.Cylinder
	p.CFrame = CFrame.new(d.position + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90))
	p.Transparency = 0.35
	task.delay(d.seconds or 6, function()
		p:Destroy()
	end)
end
function handlers.bombPlant(d)
	local bomb =
		chunk(d.position + Vector3.new(0, 0.8, 0), Vector3.new(1.6, 1.6, 1.6), C.black, M.SmoothPlastic, "ball")
	local fuse = chunk(d.position + Vector3.new(0, 1.9, 0), Vector3.new(0.4, 0.4, 0.4), C.fire, M.Neon, "ball")
	local age = 0
	table.insert(movers, {
		update = function(dt)
			age += dt
			fuse.Transparency = math.floor(age * (4 + age * 6)) % 2 == 0 and 0 or 0.8
			if age >= (d.fuse or 2) then
				bomb:Destroy()
				fuse:Destroy()
				return false
			end
			return true
		end,
	})
end
function handlers.explode(d)
	FxController.sphere(d.position + Vector3.new(0, 2, 0), C.fire, d.radius or 10, 0.5)
	FxController.burst(d.position, C.fire, 14, 0.8, 30, 0.9, { material = M.Neon })
	FxController.puff(d.position, C.black:Lerp(C.rock, 0.5), 10, 4, 1.4)
	if near(d.position, 70) then
		FxController.shake(0.9, 0.5)
	end
end
function handlers.heal(d)
	FxController.ring(d.position - Vector3.new(0, 2.5, 0), d.monster and C.magic or C.green, d.radius or 6, 0.6)
	FxController.burst(
		d.position,
		d.monster and C.magic or C.green,
		5,
		0.4,
		6,
		0.8,
		{ material = M.Neon, gravity = -8 }
	)
end
function handlers.ward(d)
	FxController.ring(d.position - Vector3.new(0, 3, 0), C.green, d.radius or 18, 0.9, 0.8)
	FxController.dome(d.position, C.green, 4, 0.8)
end
local function charOf(userId)
	local p = Players:GetPlayerByUserId(userId or 0)
	return p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
end
function handlers.shield(d)
	FxController.dome(d.position, C.sky, 5, d.seconds or 4, charOf(d.by))
	FxController.ring(d.position - Vector3.new(0, 3, 0), C.sky, d.radius or 12, 0.5)
end
function handlers.roar(d)
	FxController.ring(d.position - Vector3.new(0, 3, 0), C.orange, d.radius or 20, 0.7, 0.8)
	if near(d.position, 30) then
		FxController.shake(0.35, 0.3)
	end
end
function handlers.charge(d)
	local r = charOf(d.by)
	if not r then
		return
	end
	local age = 0
	table.insert(movers, {
		update = function(dt)
			age += dt
			if r.Parent and fxOn() then
				FxController.puff(r.Position - Vector3.new(0, 2.5, 0), C.dirt:Lerp(C.cream, 0.4), 1, 2.2, 0.6)
			end
			return age < (d.seconds or 0.6)
		end,
	})
end
function handlers.dark(d)
	FxController.ring(d.position - Vector3.new(0, 3, 0), C.magic, d.radius or 20, 0.9, 0.8)
	FxController.burst(d.position, C.magic, 10, 0.5, 12, 0.9, { material = M.Neon, gravity = -6 })
end
function handlers.curse(d)
	FxController.ring(d.position, C.magic, 5, d.seconds or 4)
end
function handlers.oil(d)
	FxController.burst(d.position + Vector3.new(0, 6, 0), C.fire, 14, 0.7, 14, 0.8, { material = M.Neon, up = -0.2 })
	FxController.ring(d.position - Vector3.new(0, 3, 0), C.fire, d.radius or 10, 0.6)
end
function handlers.trap(d)
	FxController.puff(d.position, C.dirt, 5, 2.5, 0.8)
end
function handlers.shielded(d)
	FxController.sphere(d.position, C.sky, 5, 0.3)
end
function handlers.upgradeStart(d)
	FxController.ring(d.position - Vector3.new(0, 4, 0), C.magic, 7, 0.6)
end
function handlers.craft(d)
	if d.position then
		FxController.burst(
			d.position + Vector3.new(0, 2, 0),
			C.gold,
			8,
			0.35,
			10,
			0.7,
			{ material = M.Neon, gravity = -4 }
		)
	end
end
function handlers.eat(d)
	if d.position then
		FxController.burst(
			d.position + Vector3.new(0, 2, 0),
			d.item == "potion" and C.crystalPink or C.green,
			6,
			0.35,
			6,
			0.8,
			{ material = M.Neon, gravity = -10 }
		)
	end
end
local function turned(d)
	local pos = d.position
	if not pos then
		return
	end
	for k = 0, 4 do
		task.delay(k * 0.15, function()
			FxController.puff(pos - Vector3.new(0, 2, 0), C.plague:Lerp(C.leafDark, 0.3), 4, 3, 1.4)
		end)
	end
	FxController.ring(pos - Vector3.new(0, 2.8, 0), C.plague, 8, 1)
	if d.userId == player.UserId then
		Bus.Flash:Fire(C.plague, 1)
	end
end
handlers.turn = turned
handlers.plague = turned
function handlers.shrineFall(d)
	FxController.sphere(d.position + Vector3.new(0, 9, 0), C.white, 22, 0.8)
	FxController.burst(d.position + Vector3.new(0, 9, 0), C.shrine, 20, 0.9, 30, 1.4, { material = M.Neon })
	FxController.ring(d.position, C.shrine, 40, 1.2, 1)
	FxController.shake(1, 0.8)
	Bus.Flash:Fire(C.white, 0.8)
end

-- Lighting by phase (it blends over a few seconds) -----------------------------------------------------------------
local function wantedPreset()
	local m = Store.get("match")
	local phase = Store.phase()
	return LightingPresets.forPhase(phase, m and m.scared)
end

local function stepLighting(dt)
	local want = wantedPreset()
	if want ~= light.to then
		light.from = light.t >= 1 and light.to or light.from
		light.to = want
		light.t = 0
	end
	if light.t < 1 then
		light.t = math.min(1, light.t + dt / (Theme.reducedMotion() and 0.01 or 3))
		LightingPresets.apply(LightingPresets.blend(light.from, light.to, light.t))
	end
end

-- Gates swing open when a dwarf comes near (just how it looks: the blocker never moves) ------------------------------
local gates = {} -- [model] = { doors = { { part, hinge, side, base } }, open = 0 }
local function stepGates(dt)
	local castle = workspace:FindFirstChild("Castle")
	if not castle then
		return
	end
	local dwarves = {}
	for _, p in Players:GetPlayers() do
		local c = p.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if r and c:GetAttribute("Team") == "dwarf" then
			table.insert(dwarves, r.Position)
		end
	end
	for _, m in castle:GetChildren() do
		if m:GetAttribute("Key") == "gate" and m:GetAttribute("Built") then
			local g = gates[m]
			if not g then
				g = { doors = {}, open = 0 }
				for _, name in { "DoorL", "DoorR" } do
					local door = m:FindFirstChild(name)
					if door then
						table.insert(g.doors, {
							part = door,
							hinge = door:GetAttribute("Hinge"),
							side = door:GetAttribute("Side") or 1,
							base = door.CFrame,
						})
					end
				end
				gates[m] = g
				m.Destroying:Connect(function()
					gates[m] = nil
				end)
			end
			local root = m.PrimaryPart
			local center = root and root.Position
			local want = 0
			if center then
				for _, pos in dwarves do
					if (pos - center).Magnitude < 12 then
						want = 1
					end
				end
				local horde = FxController.horde
				if want == 0 and horde then
					if #horde.near(center, 11, function(k)
						return k == "dwarf"
					end) > 0 then
						want = 1
					end
				end
			end
			g.open += (want - g.open) * math.min(1, dt * 6)
			for _, door in g.doors do
				if door.hinge and door.part.Parent then
					local angle = math.rad(85) * g.open * door.side
					local hinge = CFrame.new(door.hinge)
					door.part.CFrame = hinge * CFrame.Angles(0, angle, 0) * hinge:Inverse() * door.base
				end
			end
		end
	end
end

-- Shrine crystals turn and bob ------------------------------------------------------------------------------------
local crystals = {}
local function stepShrines(clock)
	local map = workspace:FindFirstChild("Map")
	if not map then
		return
	end
	for i = 1, 3 do
		local s = map:FindFirstChild("Shrine" .. i)
		if s then
			for _, name in { "Crystal", "Core" } do
				local part = s:FindFirstChild(name)
				if part then
					local base = crystals[part]
					if not base then
						base = part.CFrame
						crystals[part] = base
					end
					if s:GetAttribute("State") ~= "fallen" then
						part.CFrame = CFrame.new(base.Position + Vector3.new(0, math.sin(clock * 1.6 + i) * 0.6, 0))
							* CFrame.Angles(0, clock * (name == "Core" and -1.2 or 0.7), 0)
							* CFrame.Angles(0, math.rad(45), 0)
					end
				end
			end
		end
	end
end

-- Pings: a beacon and a label for a few seconds ---------------------------------------------------------------------
local function showPing(ping)
	if type(ping) ~= "table" or typeof(ping.position) ~= "Vector3" then
		return
	end
	local pillar = chunk(ping.position + Vector3.new(0, 14, 0), Vector3.new(1.2, 28, 1.2), C.mustard, M.Neon)
	pillar.Transparency = 0.35
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(200, 54)
	bb.StudsOffset = Vector3.new(0, 16, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Parent = pillar
	Theme.title({
		Text = `{ping.icon} {ping.text}`,
		Size = UDim2.new(1, 0, 0.6, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.mustard,
		Parent = bb,
	})
	Theme.text({
		Text = ping.from or "",
		TextColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, 0, 0.4, 0),
		Position = UDim2.fromScale(0, 0.6),
		TextXAlignment = Enum.TextXAlignment.Center,
		outline = 1.5,
		Parent = bb,
	})
	task.delay(8, function()
		pillar:Destroy()
	end)
end

-- The loop ----------------------------------------------------------------------------------------------------------
local function stepParticles(dt)
	for k = #particles, 1, -1 do
		local pt = particles[k]
		pt.age += dt
		if pt.age >= pt.life or not pt.part.Parent then
			pt.part:Destroy()
			table.remove(particles, k)
		else
			pt.vel -= Vector3.new(0, pt.gravity * dt, 0)
			local pos = pt.part.Position + pt.vel * dt
			local k2 = pt.age / pt.life
			if pt.grow then
				local s = pt.part.Size.X * (1 + pt.grow * dt)
				pt.part.Size = Vector3.new(s, s, s)
			end
			pt.part.CFrame = CFrame.new(pos) * CFrame.Angles(pt.spin.X * pt.age, pt.spin.Y * pt.age, pt.spin.Z * pt.age)
			if pt.fade then
				pt.part.Transparency = math.max(pt.part.Transparency, k2 * k2)
			end
		end
	end
	for k = #movers, 1, -1 do
		local ok, alive = pcall(movers[k].update, dt)
		if not ok or not alive then
			table.remove(movers, k)
		end
	end
end

function FxController:init()
	FxController.horde = require(script.Parent.HordeController)
	folder = workspace:FindFirstChild("Fx") or Instance.new("Folder")
	folder.Name = "Fx"
	folder.Parent = workspace
	Net.listen("Fx", function(kind, data)
		local fn = handlers[kind]
		if fn and type(data) == "table" then
			local ok, err = pcall(fn, data)
			if not ok then
				warn("[FxController] " .. tostring(kind) .. ": " .. tostring(err))
			end
		end
	end)
	Net.listen("Ping", showPing)
	Bus.Shake:Connect(FxController.shake)
	light.to = wantedPreset()
	light.from = light.to
	LightingPresets.apply(light.to)
	RunService.RenderStepped:Connect(function(dt)
		local clock = os.clock()
		stepParticles(dt)
		stepLighting(dt)
		stepGates(dt)
		stepShrines(clock)
		if clock < shakeUntil then
			local cam = workspace.CurrentCamera
			if cam and cam.CFrame then
				local k = shakeStrength * (shakeUntil - clock) / 0.5
				cam.CFrame = cam.CFrame * CFrame.new(math.sin(clock * 55) * k * 0.4, math.cos(clock * 47) * k * 0.4, 0)
			end
		else
			shakeStrength = 0
		end
	end)
end

-- (tests)
FxController.handlers = handlers
function FxController.counts()
	return #particles, #movers
end

return FxController
