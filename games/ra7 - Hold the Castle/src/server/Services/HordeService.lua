--[[
The horde: NPC monsters that fill the monster side so even a small server gets a real attack, and NPC dwarves
that help a small crew build and hold (master plan §10: when one dies it comes back as a monster, like everyone
else). NPCs are simulated here, on the server, as plain data (no physics, no Humanoids): they walk the lanes in
MapLayout, smash castle pieces in their way (BuildService.SolidAt), chase dwarves near their lane, and stand on
the shrine to drain it. Clients draw them from a small snapshot sent 8 times a second (HordeController animates
them), so a big horde costs little on a phone.

  build time   NPC dwarves carry rocks to the blueprints and hammer; at the first scare monsters gather on
               the far hill and watch; scouts come over the hill to give everyone a first fight (§12)
  the fight    waves from the monster spawn, sized by how many dwarves are left, how long the fight has gone
               on and how many players are monsters (Formulas.hordeTarget); tougher kinds join over time;
               NPC dwarves guard the shrine and fall back to the next one when it falls
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local MapLayout = require(ReplicatedStorage.Shared.World.MapLayout)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local HordeService = {
	Name = "HordeService",
	Dependencies = { "MatchService", "TeamService", "BuildService", "ResourceService" },
	Spawned = Signal.new("HordeService.Spawned"), -- (npc)
	Died = Signal.new("HordeService.Died"), -- (npc, killerPlayer?)
}

-- What each NPC is like. pieceDmg hits castle pieces; ranged NPCs shoot from `range`.
local STATS = {
	grunt = { hp = 70, dmg = 8, pieceDmg = 18, range = 5, cd = 1, speed = 12, side = "monster", aggro = 16 },
	brute = { hp = 230, dmg = 18, pieceDmg = 60, range = 6.5, cd = 1.6, speed = 9, side = "monster", aggro = 14 },
	spitter = {
		hp = 55,
		dmg = 7,
		pieceDmg = 9,
		range = 30,
		cd = 1.5,
		speed = 12,
		side = "monster",
		aggro = 34,
		ranged = "goo",
	},
	witch = {
		hp = 60,
		dmg = 5,
		pieceDmg = 10,
		range = 26,
		cd = 1.7,
		speed = 11,
		side = "monster",
		aggro = 28,
		ranged = "hex",
		heals = true,
	},
	breaker = {
		hp = 60,
		dmg = 4,
		pieceDmg = 75,
		range = 5,
		cd = 1.5,
		speed = 10,
		side = "monster",
		aggro = 10,
		gateMult = 1.5,
	},
	imp = { hp = 22, dmg = 4, pieceDmg = 6, range = 4, cd = 0.8, speed = 15, side = "monster", aggro = 22 },
	scout = {
		hp = 36,
		dmg = 4,
		pieceDmg = 5,
		range = 4.5,
		cd = 1.1,
		speed = 13,
		side = "monster",
		aggro = 26,
		scout = true,
	},
	dwarf = { hp = 90, dmg = 9, range = 6, cd = 0.9, speed = 13, side = "dwarf", aggro = 14 },
}
HordeService.STATS = STATS
local KINDS = { "grunt", "brute", "spitter", "witch", "breaker", "imp", "scout", "dwarf" }
local KIND_INDEX = {}
for i, k in KINDS do
	KIND_INDEX[k] = i
end
HordeService.KINDS = KINDS

local match, teams, build, resources
local registry
local npcs = {} -- [id] = npc
local nextId = 1
local nextWave = 0
local holdWaves = 0
local nextScout = nil
local watchersOut = false
local sendAcc = 0
local thinkFrame = 0

local function now()
	return workspace:GetServerTimeNow()
end

local function ground(x, z)
	return MapLayout.groundY(x, z)
end

-- Spawning ------------------------------------------------------------------------------------------------------
local function pickLane(zone)
	local lanes = MapLayout.lanes[zone] or MapLayout.lanes[1]
	return lanes[math.random(1, #lanes)].points
end

-- The waypoint index on a lane nearest to (and not behind) a position.
local function laneIndexFrom(points, pos)
	local best, bestD = 1, math.huge
	for k, p in points do
		local d = (p - Vector2.new(pos.X, pos.Z)).Magnitude
		if d < bestD then
			best, bestD = k, d
		end
	end
	return math.min(#points, best + (bestD < 8 and 1 or 0))
end

function HordeService:Spawn(kind, pos, opts)
	opts = opts or {}
	local st = STATS[kind]
	if not st then
		return nil
	end
	local count = 0
	for _ in npcs do
		count += 1
	end
	if count >= Constants.NPC_MAX + 12 then
		return nil
	end
	local mult = 1
	if st.side == "monster" and not st.scout then
		mult = 1 + math.min(0.5, match:FightSeconds() / 60 * 0.05)
	end
	local id = nextId
	nextId = (nextId % 60000) + 1
	local zone = opts.zone or match:ActiveShrine()
	local spread = MapLayout.LANE_SPREAD[zone] or 5
	local npc = {
		id = id,
		kind = kind,
		st = st,
		side = st.side,
		pos = Vector3.new(pos.X, ground(pos.X, pos.Z), pos.Z),
		yaw = 0,
		hp = math.floor(st.hp * mult),
		maxHp = math.floor(st.hp * mult),
		mult = mult,
		zone = zone,
		lane = opts.lane or (st.side == "monster" and pickLane(zone) or nil),
		laneIdx = 2,
		offset = (math.random() * 2 - 1) * spread,
		state = opts.state or (st.side == "monster" and "march" or "work"),
		nextAttack = now() + math.random() * st.cd,
		slowUntil = 0,
		slowMult = 1,
		stunUntil = 0,
		actCount = 0,
		hitAt = 0,
		moving = false,
		carry = nil,
		spawnedAt = now(),
		elite = opts.elite == true,
		guardIdx = opts.guardIdx or id,
		think = id % 5,
	}
	if npc.lane then
		npc.laneIdx = laneIndexFrom(npc.lane, npc.pos)
	end
	npcs[id] = npc
	self.Spawned:Fire(npc)
	return npc
end

-- A mix that gets tougher as the fight goes on (§9: monsters get stronger the longer they fight).
local function chooseKind(minutes)
	local bag = { { "grunt", 10 }, { "spitter", 3 } }
	if minutes >= 1 then
		table.insert(bag, { "breaker", 2 })
	end
	if minutes >= 2 then
		table.insert(bag, { "brute", 2 + math.floor(minutes / 4) })
	end
	if minutes >= 4 then
		table.insert(bag, { "witch", 1 })
	end
	local total = 0
	for _, e in bag do
		total += e[2]
	end
	local r = math.random() * total
	for _, e in bag do
		r -= e[2]
		if r <= 0 then
			return e[1]
		end
	end
	return "grunt"
end
HordeService.chooseKind = chooseKind

local function spawnPoint()
	local c = MapLayout.monsterSpawnCenter(match:Fallen())
	local a = math.random() * math.pi * 2
	local r = 3 + math.random() * 9
	return c + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
end

-- Queries ---------------------------------------------------------------------------------------------------------
function HordeService:Get(id)
	return npcs[id]
end

function HordeService:All()
	return npcs
end

-- NPCs of a side within `radius` of a position.
function HordeService:Near(pos, radius, side)
	local out = {}
	for _, n in npcs do
		if (not side or n.side == side) and n.hp > 0 then
			local d = (n.pos - pos)
			if math.abs(d.Y) < 14 and Vector2.new(d.X, d.Z).Magnitude <= radius then
				table.insert(out, n)
			end
		end
	end
	return out
end

function HordeService:DwarfCount()
	local n = 0
	for _, npc in npcs do
		if npc.side == "dwarf" and npc.hp > 0 then
			n += 1
		end
	end
	return n
end

function HordeService:MonsterCount()
	local n = 0
	for _, npc in npcs do
		if npc.side == "monster" and npc.hp > 0 and not npc.st.scout and npc.kind ~= "imp" and npc.state ~= "watch" then
			n += 1
		end
	end
	return n
end

-- Who counts at a shrine: NPC dwarves, and NPC monsters that are attacking (not scouts or watchers).
function HordeService:CountNear(pos, radius)
	local d, m = 0, 0
	for _, n in self:Near(pos, radius) do
		if n.side == "dwarf" then
			d += 1
		elseif not n.st.scout and n.state ~= "watch" then
			m += n.kind == "imp" and 0.5 or 1
		end
	end
	return d, math.floor(m)
end

-- Damage, healing and effects --------------------------------------------------------------------------------------
function HordeService:Slow(id, mult, seconds)
	local n = npcs[id]
	if n then
		n.slowMult = math.min(n.slowUntil > now() and n.slowMult or 1, 1 - mult)
		n.slowUntil = now() + seconds
	end
end

function HordeService:Stun(id, seconds)
	local n = npcs[id]
	if n then
		n.stunUntil = math.max(n.stunUntil, now() + seconds)
	end
end

function HordeService:Knock(id, dir, dist)
	local n = npcs[id]
	if not n or n.kind == "brute" then
		return
	end
	local d = Vector3.new(dir.X, 0, dir.Z)
	if d.Magnitude < 1e-3 then
		return
	end
	local target = n.pos + d.Unit * dist
	if
		MapLayout.walkable(target.X, target.Z)
		and math.abs(ground(target.X, target.Z) - n.pos.Y) < 3
		and not build:SolidAt(target.X, target.Z, n.side == "dwarf")
	then
		n.pos = Vector3.new(target.X, ground(target.X, target.Z), target.Z)
	end
end

function HordeService:Heal(id, amount)
	local n = npcs[id]
	if n and n.hp > 0 then
		n.hp = math.min(n.maxHp, n.hp + amount)
	end
end

function HordeService:_kill(n, byPlayer)
	if not npcs[n.id] then
		return
	end
	npcs[n.id] = nil
	n.hp = 0
	Net.fireAll(
		"Npc",
		{ kind = "die", id = n.id, position = n.pos, npcKind = n.kind, by = byPlayer and byPlayer.UserId or nil }
	)
	if byPlayer and byPlayer.Parent then
		if n.side == "monster" then
			teams:Stat(byPlayer, "beaten", 1)
			Net.fire(byPlayer, "Popup", n.pos + Vector3.new(0, 7, 0), "Beaten!", "good")
		elseif n.side == "dwarf" then
			teams:Stat(byPlayer, "dwarvesBeaten", 1)
			teams:AddMonsterXp(byPlayer, Constants.MONSTER_XP.kill * 0.6)
		end
	end
	self.Died:Fire(n, byPlayer)
	if n.side == "dwarf" then
		if match:IsFight() then
			-- a fallen dwarf rises as a monster at the monster spawn
			task.delay(3, function()
				if match:IsFight() then
					local m = self:Spawn("grunt", spawnPoint())
					if m then
						m.elite = true
					end
				end
			end)
			match:CheckEnd()
		elseif match:Phase() == "build" then
			task.delay(5, function()
				if match:Phase() == "build" then
					self:Spawn("dwarf", MapLayout.dwarfSpawn(1, n.guardIdx), { guardIdx = n.guardIdx, look = n.look })
				end
			end)
		end
	end
end

-- Damage an NPC. byPlayer: who hit it (or nil: traps, NPC dwarves). Returns true if it fell.
function HordeService:Damage(id, amount, byPlayer, kind)
	local n = npcs[id]
	if not n or n.hp <= 0 or amount <= 0 then
		return false
	end
	n.hp -= amount
	n.hitAt = now()
	if byPlayer then
		n.lastHitBy = byPlayer
		n.lastHitAt = now()
		-- a dwarf who hits a marching (or watching) monster gets its attention
		if
			n.side == "monster"
			and (n.state == "march" or n.state == "siege" or n.state == "watch")
			and teams:Team(byPlayer) == "dwarf"
		then
			n.target = { player = byPlayer }
			n.state = "chase"
		end
	end
	Net.fireAll("Npc", { kind = "hit", id = id, amount = math.floor(amount), dmgKind = kind })
	if n.hp <= 0 then
		local killer = byPlayer
		if not killer and n.lastHitBy and now() - (n.lastHitAt or 0) < Constants.COMBAT_TAG_SECONDS then
			killer = n.lastHitBy
		end
		self:_kill(n, killer)
		return true
	end
	return false
end

-- Attacks --------------------------------------------------------------------------------------------------------
local function dwarfTargets()
	local list = {}
	for _, p in teams:Players("dwarf") do
		local pos = teams:Position(p)
		if pos then
			table.insert(list, { player = p, pos = pos })
		end
	end
	for _, n in npcs do
		if n.side == "dwarf" and n.hp > 0 then
			table.insert(list, { npc = n, pos = n.pos })
		end
	end
	return list
end

local function monsterTargets()
	local list = {}
	for _, p in teams:Players("monster") do
		local pos = teams:Position(p)
		if pos then
			table.insert(list, { player = p, pos = pos })
		end
	end
	for _, n in npcs do
		if n.side == "monster" and n.hp > 0 and n.state ~= "watch" then
			table.insert(list, { npc = n, pos = n.pos })
		end
	end
	return list
end

local function targetPos(target)
	if target.player then
		return teams:IsAlive(target.player) and teams:Position(target.player) or nil
	elseif target.npc then
		return target.npc.hp > 0 and npcs[target.npc.id] and target.npc.pos or nil
	elseif target.piece then
		local p = build:Get(target.piece)
		return p and p.center or nil
	end
	return nil
end

function HordeService:_hit(n, target)
	n.actCount += 1
	local combat = registry.CombatService
	local dmg = n.st.dmg * n.mult
	local function land()
		if n.hp <= 0 and not npcs[n.id] then
			return
		end
		if target.player then
			if combat and teams:IsAlive(target.player) then
				combat:HurtPlayer(target.player, dmg, nil, n.st.ranged or "npc", n.id)
			end
		elseif target.npc then
			self:Damage(target.npc.id, dmg, nil, "npc")
		elseif target.piece then
			local p = build:Get(target.piece)
			if p then
				local mult = (p.def.gate and n.st.gateMult) or 1
				build:Damage(p.id, n.st.pieceDmg * n.mult * mult, nil, n.st.ranged == "hex" and "hex" or "npc")
				if n.st.ranged == "hex" then
					p.curseUntil = now() + 4
					p.curseMult = 0.3
				end
			end
		end
	end
	local tp = targetPos(target)
	if n.st.ranged and tp then
		local dist = (tp - n.pos).Magnitude
		Net.fireAll(
			"Fx",
			"projectile",
			{ style = n.st.ranged, from = n.pos + Vector3.new(0, 4, 0), to = tp + Vector3.new(0, 2, 0), speed = 70 }
		)
		task.delay(math.min(0.8, dist / 70), land)
	else
		land()
	end
end

-- Movement ---------------------------------------------------------------------------------------------------------
-- Step an NPC toward a point. Returns "moved" | "arrived" | "blocked" (a piece: second value) | "stuck".
function HordeService:_step(n, goal, dt, stopAt)
	local to = Vector2.new(goal.X - n.pos.X, goal.Z - n.pos.Z)
	local dist = to.Magnitude
	if dist <= (stopAt or 1.5) then
		n.moving = false
		return "arrived"
	end
	local t = now()
	if n.stunUntil > t then
		n.moving = false
		return "stuck"
	end
	local speed = n.st.speed * (n.slowUntil > t and n.slowMult or 1) * (n.roarUntil and n.roarUntil > t and 1.3 or 1)
	local step = math.min(dist, speed * dt)
	local dir = to.Unit
	n.yaw = math.atan2(-dir.X, -dir.Y)
	local function try(d)
		local nx, nz = n.pos.X + d.X * step, n.pos.Z + d.Y * step
		if not MapLayout.walkable(nx, nz) then
			return nil
		end
		local ny = ground(nx, nz)
		if math.abs(ny - n.pos.Y) > 2.6 then
			return nil
		end
		local piece = build:SolidAt(nx, nz, n.side == "dwarf")
		if piece then
			return nil, piece
		end
		return Vector3.new(nx, ny, nz)
	end
	local nextPos, piece = try(dir)
	if not nextPos and not piece then
		-- slide along whatever is in the way
		if math.abs(dir.X) > 0.1 then
			nextPos = try(Vector2.new(math.sign(dir.X), 0))
		end
		if not nextPos and math.abs(dir.Y) > 0.1 then
			nextPos = try(Vector2.new(0, math.sign(dir.Y)))
		end
	end
	if nextPos then
		n.pos = nextPos
		n.moving = true
		return "moved"
	end
	n.moving = false
	if piece then
		return "blocked", piece
	end
	return "stuck"
end

local function laneGoal(n)
	local pts = n.lane
	local idx = math.clamp(n.laneIdx, 1, #pts)
	local p = pts[idx]
	local q = pts[math.min(#pts, idx + 1)]
	local prev = pts[math.max(1, idx - 1)]
	local d = (q - prev)
	if d.Magnitude < 1e-3 then
		d = Vector2.new(1, 0)
	end
	local perp = Vector2.new(-d.Unit.Y, d.Unit.X)
	local off = idx == #pts and 0.4 or 1
	local g = p + perp * n.offset * off
	return Vector3.new(g.X, 0, g.Y)
end

local function nearest(list, pos, radius)
	local best, bestD
	for _, t in list do
		local d = (t.pos - pos).Magnitude
		if d <= radius and (not bestD or d < bestD) then
			best, bestD = t, d
		end
	end
	return best, bestD
end

-- The guard spot of an NPC dwarf around the shrine it's holding.
local function guardSpot(n)
	local s = MapLayout.shrines[match:ActiveShrine()]
	local a = (n.guardIdx or 1) * 2.399
	local r = 12 + (n.guardIdx or 1) % 3 * 4
	return s.pos + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
end

function HordeService:_thinkMonster(n, dt, dwarves, t)
	local st = n.st
	if n.state == "watch" then
		n.moving = false
		return
	end
	-- look for a dwarf near the lane (not every frame)
	if (thinkFrame + n.think) % 3 == 0 and n.state ~= "chase" then
		local radius = st.aggro * (n.state == "hold" and 1.4 or 1)
		local found = nearest(dwarves, n.pos, radius)
		if found then
			local leash = n.lane and MapLayout.distToLane(n.lane, found.pos.X, found.pos.Z) or 0
			if n.state == "hold" or st.scout or leash <= Constants.NPC_LEASH then
				n.target = found.player and { player = found.player } or { npc = found.npc }
				n.prevState = n.state ~= "chase" and n.state or n.prevState
				n.state = "chase"
			end
		end
	end
	if n.state == "chase" then
		local tp = n.target and targetPos(n.target)
		local leashOk = tp
			and (
				st.scout
				or n.prevState == "hold"
				or not n.lane
				or MapLayout.distToLane(n.lane, tp.X, tp.Z) <= Constants.NPC_LEASH + 8
			)
		if not tp or not leashOk then
			n.state = n.prevState == "hold" and "hold" or "march"
			n.target = nil
			if n.lane then
				n.laneIdx = laneIndexFrom(n.lane, n.pos)
			end
			return
		end
		local dist = (tp - n.pos).Magnitude
		if dist <= st.range + 1.2 then
			n.moving = false
			local dir = Vector2.new(tp.X - n.pos.X, tp.Z - n.pos.Z)
			if dir.Magnitude > 0.1 then
				n.yaw = math.atan2(-dir.Unit.X, -dir.Unit.Y)
			end
			if t >= n.nextAttack and n.stunUntil <= t then
				n.nextAttack = t + st.cd
				self:_hit(n, n.target)
			end
			return
		end
		local res, piece = self:_step(n, tp, dt, st.range * 0.8)
		if res == "blocked" then
			n.state = "siege"
			n.target = { piece = piece.id }
		elseif res == "stuck" then
			n.state = n.prevState == "hold" and "hold" or "march"
			n.target = nil
		end
		return
	end
	if n.state == "siege" then
		local p = n.target and n.target.piece and build:Get(n.target.piece)
		if not p then
			n.state = "march"
			n.target = nil
			if n.lane then
				n.laneIdx = laneIndexFrom(n.lane, n.pos)
			end
			return
		end
		n.moving = false
		local dir = Vector2.new(p.center.X - n.pos.X, p.center.Z - n.pos.Z)
		if dir.Magnitude > 0.1 then
			n.yaw = math.atan2(-dir.Unit.X, -dir.Unit.Y)
		end
		if t >= n.nextAttack and n.stunUntil <= t then
			n.nextAttack = t + st.cd
			self:_hit(n, n.target)
		end
		return
	end
	if n.state == "hold" then
		-- at the shrine: stay on it, hit wards and pieces right next to it
		if not n.holdPos then
			local s = MapLayout.shrines[n.zone]
			local a = math.random() * math.pi * 2
			n.holdPos = s.pos + Vector3.new(math.cos(a) * 7, 0, math.sin(a) * 7)
		end
		local res, piece = self:_step(n, n.holdPos, dt, 1.5)
		if res == "blocked" then
			n.state = "siege"
			n.target = { piece = piece.id }
		end
		return
	end
	-- march along the lane
	if not n.lane then
		n.lane = pickLane(n.zone)
		n.laneIdx = laneIndexFrom(n.lane, n.pos)
	end
	local goal = laneGoal(n)
	local res, piece = self:_step(n, goal, dt, 3)
	if res == "arrived" then
		if n.laneIdx >= #n.lane then
			n.state = "hold"
		else
			n.laneIdx += 1
		end
	elseif res == "blocked" then
		n.state = "siege"
		n.target = { piece = piece.id }
	elseif res == "stuck" and n.stunUntil <= t then
		n.laneIdx = math.min(#n.lane, n.laneIdx + 1)
	end
	if st.heals and t >= (n.nextHeal or 0) then
		n.nextHeal = t + 5
		for _, m in self:Near(n.pos, 16, "monster") do
			self:Heal(m.id, 20)
		end
		Net.fireAll("Fx", "heal", { position = n.pos, radius = 16, monster = true })
	end
end

function HordeService:_thinkDwarf(n, dt, monsters, t)
	local st = n.st
	local fight = match:IsFight()
	-- fight anything that comes close
	if (thinkFrame + n.think) % 3 == 0 or n.state == "defend" then
		local found, d = nearest(monsters, n.pos, fight and 14 or 18)
		if found then
			n.target = found.player and { player = found.player } or { npc = found.npc }
			if d <= st.range + 1.2 then
				n.moving = false
				local dir = Vector2.new(found.pos.X - n.pos.X, found.pos.Z - n.pos.Z)
				if dir.Magnitude > 0.1 then
					n.yaw = math.atan2(-dir.Unit.X, -dir.Unit.Y)
				end
				if t >= n.nextAttack and n.stunUntil <= t then
					n.nextAttack = t + st.cd
					self:_hit(n, n.target)
				end
				n.state = "defend"
				return
			end
			if n.state == "defend" or fight then
				n.state = "defend"
				self:_step(n, found.pos, dt, st.range * 0.8)
				return
			end
		elseif n.state == "defend" then
			n.state = fight and "guard" or "work"
			n.target = nil
		end
	end
	if fight then
		if n.state == "retreat" and n.lane then
			local res = self:_step(n, laneGoal(n), dt, 3)
			if res == "arrived" then
				if n.laneIdx >= #n.lane then
					n.state = "guard"
					n.lane = nil
				else
					n.laneIdx += 1
				end
			elseif res == "stuck" then
				n.laneIdx = math.min(#n.lane, n.laneIdx + 1)
			end
			return
		end
		n.state = "guard"
		n.carry = nil
		self:_step(n, guardSpot(n), dt, 2)
		return
	end
	-- build time: carry materials to the blueprints and hammer them
	n.state = "work"
	if not n.job or (n.job.until_ and t > n.job.until_) then
		n.job = nil
		local piece = build:NearestWork(n.pos, 180)
		if piece then
			local missing = Formulas.missing(piece.need, piece.have)
			local kind = next(missing)
			if kind and piece.state == "blueprint" and not n.carry then
				local node = resources:NearestNode(kind, n.pos)
				if node then
					n.job = { step = "toNode", node = node.id, kind = kind, piece = piece.id, until_ = t + 60 }
				end
			end
			if not n.job then
				n.job = { step = "toWork", piece = piece.id, kind = n.carry, until_ = t + 40 }
			end
		else
			n.job = { step = "idle", until_ = t + 4 }
		end
	end
	local job = n.job
	if job.step == "toNode" then
		local node = resources:Node(job.node)
		if not node then
			n.job = nil
			return
		end
		if self:_step(n, node.pos, dt, node.size / 2 + 2.5) == "arrived" then
			job.step = "gather"
			job.doneAt = t + 2.5
		end
	elseif job.step == "gather" then
		n.moving = false
		if t >= (job.nextSwing or 0) then
			job.nextSwing = t + 0.8
			n.actCount += 1
		end
		if t >= job.doneAt then
			n.carry = job.kind
			job.step = "toWork"
		end
	elseif job.step == "toWork" then
		local piece = build:Get(job.piece)
		if not piece then
			n.job = nil
			return
		end
		local d = build.distToPiece(piece, n.pos)
		if d <= 4 then
			job.step = "hammer"
			job.doneAt = t + 2.4
			if n.carry then
				build:NpcDeliver(piece.id, n.carry, 3, 1)
				n.carry = nil
			end
		else
			local res = self:_step(n, piece.center, dt, 2)
			if res == "stuck" or res == "blocked" then
				job.stuck = (job.stuck or 0) + dt
				if job.stuck > 3 then
					n.job = nil
				end
			end
		end
	elseif job.step == "hammer" then
		n.moving = false
		local piece = build:Get(job.piece)
		if piece then
			local dir = Vector2.new(piece.center.X - n.pos.X, piece.center.Z - n.pos.Z)
			if dir.Magnitude > 0.1 then
				n.yaw = math.atan2(-dir.Unit.X, -dir.Unit.Y)
			end
		end
		if t >= (job.nextSwing or 0) then
			job.nextSwing = t + 0.8
			n.actCount += 1
			if piece then
				build:NpcDeliver(piece.id, nil, 0, 0.6)
			end
		end
		if t >= job.doneAt or not piece then
			n.job = nil
		end
	else
		-- nothing to build: hang around the shrine
		self:_step(n, guardSpot(n), dt, 3)
	end
end

-- Keep NPCs from standing inside each other.
local function separate(list)
	for a = 1, #list do
		local na = list[a]
		for b = a + 1, #list do
			local nb = list[b]
			local dx, dz = nb.pos.X - na.pos.X, nb.pos.Z - na.pos.Z
			local d2 = dx * dx + dz * dz
			local min = (na.kind == "brute" or nb.kind == "brute") and 3.6 or 2.4
			if d2 < min * min and d2 > 1e-4 then
				local d = math.sqrt(d2)
				local push = (min - d) / 2
				local ux, uz = dx / d, dz / d
				local pa = Vector3.new(na.pos.X - ux * push, na.pos.Y, na.pos.Z - uz * push)
				local pb = Vector3.new(nb.pos.X + ux * push, nb.pos.Y, nb.pos.Z + uz * push)
				if MapLayout.walkable(pa.X, pa.Z) and not build:SolidAt(pa.X, pa.Z, na.side == "dwarf") then
					na.pos = Vector3.new(pa.X, ground(pa.X, pa.Z), pa.Z)
				end
				if MapLayout.walkable(pb.X, pb.Z) and not build:SolidAt(pb.X, pb.Z, nb.side == "dwarf") then
					nb.pos = Vector3.new(pb.X, ground(pb.X, pb.Z), pb.Z)
				end
			end
		end
	end
end

-- Waves, scouts and watchers -----------------------------------------------------------------------------------------
function HordeService:_waves(t)
	local phase = match:Phase()
	if phase == "build" then
		local elapsed = match:BuildElapsed()
		local left = match:TimeLeft()
		if not nextScout then
			nextScout = Constants.SCOUT_FIRST_AT
		end
		if elapsed >= nextScout and left > Constants.SCOUT_STOP_BEFORE then
			nextScout = elapsed + Constants.SCOUT_EVERY
			local count = #Players:GetPlayers() >= 4 and 2 or 1
			for _ = 1, count do
				self:Spawn("scout", spawnPoint(), { zone = 1 })
			end
			Net.fireAll("Callout", "A monster scout is coming!", "scout")
		end
		return
	end
	if phase ~= "fight" and phase ~= "laststand" then
		return
	end
	if t < nextWave then
		return
	end
	nextWave = t + Constants.WAVE_EVERY * (holdWaves > 0 and 1 + Constants.HORDE_LATE_HOLD or 1)
	holdWaves = math.max(0, holdWaves - 1)
	local minutes = match:FightSeconds() / 60
	local dwarves = teams:DwarfCount() + self:DwarfCount()
	local want = Formulas.hordeTarget(minutes, dwarves, teams:MonsterPlayerCount())
	local n = math.min(Constants.WAVE_MAX, want - self:MonsterCount())
	for _ = 1, n do
		self:Spawn(chooseKind(minutes), spawnPoint())
	end
end

-- The first scare: monsters gather on the far hill and watch the castle (§12, 2:00).
function HordeService:Watchers()
	if watchersOut then
		return
	end
	watchersOut = true
	local spots =
		{ { -462, 40 }, { -466, 62 }, { -458, 84 }, { -464, -42 }, { -460, -66 }, { -468, -88 }, { -470, 10 } }
	for k, s in spots do
		local kind = k % 3 == 0 and "brute" or (k % 3 == 1 and "grunt" or "spitter")
		local npc = self:Spawn(kind, Vector3.new(s[1], 0, s[2]), { state = "watch", zone = 1 })
		if npc then
			npc.yaw = math.atan2(-1, 0) -- facing east, toward the castle
		end
	end
end

-- NPC dwarves for a small crew at the start of a match.
function HordeService:Helpers()
	local n = math.max(0, Constants.NPC_DWARF_FILL - #Players:GetPlayers())
	for k = 1, n do
		self:Spawn("dwarf", MapLayout.dwarfSpawn(1, k + 20), { guardIdx = k })
	end
end

-- Snapshot -------------------------------------------------------------------------------------------------------
-- Pack every NPC into a string: a header (server time) then 12 bytes each.
function HordeService.pack(list, t)
	local parts = { string.pack("<d", t) }
	for _, n in list do
		local flags = (n.moving and 1 or 0)
			+ (n.actCount % 4) * 2
			+ ((t - (n.hitAt or 0)) < 0.25 and 8 or 0)
			+ (n.carry and 16 or 0)
			+ (n.stunUntil > t and 32 or 0)
			+ (n.elite and 64 or 0)
			+ (n.state == "watch" and 128 or 0)
		local yaw = math.floor(((n.yaw % (math.pi * 2)) / (math.pi * 2)) * 255 + 0.5) % 256
		local hp = math.clamp(math.floor(n.hp / n.maxHp * 255 + 0.5), 0, 255)
		table.insert(
			parts,
			string.pack(
				"<I2Bhhh",
				n.id,
				KIND_INDEX[n.kind] or 1,
				math.clamp(math.floor(n.pos.X * 10 + 0.5), -32768, 32767),
				math.clamp(math.floor(n.pos.Y * 10 + 0.5), -32768, 32767),
				math.clamp(math.floor(n.pos.Z * 10 + 0.5), -32768, 32767)
			) .. string.pack("<BBB", yaw, hp, flags)
		)
	end
	return table.concat(parts)
end

-- Unpack a snapshot: time, { { id, kind, x, y, z, yaw, hp (0..1), flags }, ... }.
function HordeService.unpack(s)
	local t, pos = string.unpack("<d", s)
	local out = {}
	while pos + 11 <= #s do
		local id, k, x, y, z, yaw, hp, flags
		id, k, x, y, z, yaw, hp, flags, pos = string.unpack("<I2BhhhBBB", s, pos)
		table.insert(out, {
			id = id,
			kind = KINDS[k] or "grunt",
			x = x / 10,
			y = y / 10,
			z = z / 10,
			yaw = yaw / 255 * math.pi * 2,
			hp = hp / 255,
			flags = flags,
		})
	end
	return t, out
end

function HordeService:_send()
	local list = {}
	for _, n in npcs do
		table.insert(list, n)
	end
	table.sort(list, function(a, b)
		return a.id < b.id
	end)
	Net.fireAll("Horde", HordeService.pack(list, now()))
end

-- The loop -------------------------------------------------------------------------------------------------------
function HordeService:_tick(dt)
	local t = now()
	thinkFrame += 1
	self:_waves(t)
	local dwarves, monsters = dwarfTargets(), monsterTargets()
	local list = {}
	for _, n in npcs do
		if n.hp > 0 then
			if n.side == "monster" then
				self:_thinkMonster(n, dt, dwarves, t)
			else
				self:_thinkDwarf(n, dt, monsters, t)
			end
			table.insert(list, n)
		end
	end
	separate(list)
	sendAcc += dt
	if sendAcc >= Constants.NPC_SEND then
		sendAcc = 0
		self:_send()
	end
end

-- No new waves for a while (tests, admin).
function HordeService:Pause(seconds)
	nextWave = now() + seconds
end

function HordeService:Clear()
	for id in npcs do
		npcs[id] = nil
	end
	Net.fireAll("Npc", { kind = "clear" })
	self:_send()
end

-- A shrine fell: the horde moves on to the next one (and the NPC dwarves fall back to it).
function HordeService:_onShrineFell(index)
	local zone = math.min(3, index + 1)
	holdWaves = 1
	nextWave = now() + Constants.RETREAT_SECONDS
	for _, n in npcs do
		if n.side == "monster" then
			n.zone = zone
			n.lane = pickLane(zone)
			n.laneIdx = laneIndexFrom(n.lane, n.pos)
			n.holdPos = nil
			if n.state ~= "chase" then
				n.state = "march"
				n.target = nil
			end
		else
			n.lane = pickLane(zone)
			n.laneIdx = laneIndexFrom(n.lane, n.pos)
			n.state = "retreat"
			n.target = nil
		end
	end
end

function HordeService:Init(reg)
	registry = reg
	match = reg.MatchService
	teams = reg.TeamService
	build = reg.BuildService
	resources = reg.ResourceService
	match.Started:Connect(function()
		self:Clear()
		nextScout = nil
		watchersOut = false
		holdWaves = 0
		self:Helpers()
	end)
	match.Scare:Connect(function()
		self:Watchers()
		Net.fireAll("Callout", "Monsters on the hill! They're watching the castle...", "scare")
	end)
	match.Plague:Connect(function()
		for _, n in npcs do
			if n.state == "watch" then
				n.state = "march"
			end
		end
	end)
	match.FightStarted:Connect(function()
		nextWave = now() + 2
		for _, n in npcs do
			if n.state == "watch" then
				n.state = "march"
			end
			if n.st.scout then
				n.state = "march"
			end
		end
	end)
	match.ShrineFell:Connect(function(index)
		self:_onShrineFell(index)
	end)
	match.Ended:Connect(function(result)
		-- the winners cheer, the losers stop
		for _, n in npcs do
			n.state = "watch"
			n.moving = false
			if result.winner == n.side then
				n.actCount += 1
			end
		end
	end)
	match.Reset:Connect(function()
		self:Clear()
	end)
end

function HordeService:Start()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= Constants.NPC_TICK then
			local step = math.min(acc, 0.3)
			acc = 0
			local ok, err = pcall(self._tick, self, step)
			if not ok then
				warn("[HordeService] " .. tostring(err))
			end
		end
	end)
end

return HordeService
