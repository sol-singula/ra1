--[[
Every move in the game, decided on the server (master plan §21: the server decides every fight, not the
player's phone). The client sends "Act" with the slot ("main" or "special"), where it's aiming, and (for a dwarf's
main move) what it's pointing at: a node to mine or a piece to hammer.

  main     melee: after a short wind-up (§13: clear wind-ups so the other side can react) it hits the best target
           in an arc in front of you (Fighters and Brutes hit a few); a monster with nothing to hit swings at the
           castle instead. ranged: a projectile along your aim with a little aim help on phones.
  special  Builder Quick Wall, Miner Big Dig, Fighter Shield Wall, Archer Volley, Healer Ward;
           Grunt Roar, Brute Charge, Spitter Goo Puddle, Witch Dark Circle, Breaker Bomb.
Damage goes through HurtPlayer (spawn protection, no friendly fire, shields, armor), HordeService (NPCs) and
BuildService (pieces: dwarves never hurt their own castle).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Jobs = require(ReplicatedStorage.Shared.Data.Jobs)
local MapLayout = require(ReplicatedStorage.Shared.World.MapLayout)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local CombatService = {
	Name = "CombatService",
	Dependencies = { "MatchService", "TeamService", "BuildService", "ResourceService", "HordeService" },
	Acted = Signal.new("CombatService.Acted"), -- (player, slot, moveKey)
	Hit = Signal.new("CombatService.Hit"), -- (byPlayer?, victim { player | npc | piece }, amount, kind)
	Healed = Signal.new("CombatService.Healed"), -- (byPlayer?, targetPlayer?, amount)
}

local match, teams, build, resources, horde
local cooldowns = {} -- [player] = { main = t, special = t }
local effects = {} -- [player] = { slow, shield, stun, roar, boost, potion }
local puddles = {} -- { pos, radius, untilT, by, slow, dps }
local bombs = {} -- { pos, at, by, move }

local function now()
	return workspace:GetServerTimeNow()
end

local function fx(player)
	local e = effects[player]
	if not e then
		e = {
			slowUntil = 0,
			slowMult = 1,
			shieldUntil = 0,
			shieldCut = 0,
			stunUntil = 0,
			roarUntil = 0,
			roarSpeed = 1,
			roarDmg = 1,
			boostUntil = 0,
			boostMult = 1,
			potionUntil = 0,
			potionMult = 1,
		}
		effects[player] = e
	end
	return e
end

-- Effects on players ------------------------------------------------------------------------------------------
function CombatService:Slow(player, mult, seconds)
	local e = fx(player)
	local t = now()
	e.slowMult = math.min(e.slowUntil > t and e.slowMult or 1, 1 - mult)
	e.slowUntil = math.max(e.slowUntil, t + seconds)
end

function CombatService:Stun(player, seconds)
	local e = fx(player)
	e.stunUntil = math.max(e.stunUntil, now() + seconds)
end

function CombatService:Boost(player, mult, seconds)
	local e = fx(player)
	e.boostMult = mult
	e.boostUntil = now() + seconds
end

function CombatService:Potion(player, mult, seconds)
	local e = fx(player)
	e.potionMult = mult
	e.potionUntil = now() + seconds
end

function CombatService:IsStunned(player)
	return fx(player).stunUntil > now()
end

-- Walk speed from the job and every effect on the player.
function CombatService:_speed(player)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return
	end
	local job = teams:JobData(player)
	local base = job and teams:Team(player) and job.speed or Constants.DWARF_WALK
	local e = fx(player)
	local t = now()
	local mult = 1
	if e.slowUntil > t then
		mult *= e.slowMult
	end
	if e.roarUntil > t then
		mult *= e.roarSpeed
	end
	if e.boostUntil > t then
		mult *= e.boostMult
	end
	if e.potionUntil > t then
		mult *= e.potionMult
	end
	local speed = e.stunUntil > t and 0 or base * mult
	if math.abs(hum.WalkSpeed - speed) > 0.05 then
		hum.WalkSpeed = speed
	end
end

-- Damage and healing -----------------------------------------------------------------------------------------
-- Hurt a player. byPlayer: who did it (nil for NPCs and traps). npcId: the NPC that did it. Returns the damage.
function CombatService:HurtPlayer(victim, amount, byPlayer, kind, npcId)
	if not teams:IsAlive(victim) or amount <= 0 then
		return 0
	end
	local character = victim.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if not hum then
		return 0
	end
	local t = now()
	if (character:GetAttribute("ProtectedUntil") or 0) > t then
		return 0
	end
	local team = teams:Team(victim)
	if byPlayer and teams:Team(byPlayer) == team then
		return 0 -- no friendly fire
	end
	local e = fx(victim)
	if e.shieldUntil > t then
		amount *= 1 - e.shieldCut
	end
	if team == "dwarf" then
		local s = teams:State(victim)
		amount *= Formulas.armorMult(s and s.gear.armor or 0)
	end
	amount = math.max(1, math.floor(amount + 0.5))
	teams:NoteHit(victim, byPlayer, npcId)
	hum.Health = hum.Health - amount
	Net.fire(victim, "Hurt", { amount = amount, by = byPlayer and byPlayer.UserId or nil, kind = kind })
	if byPlayer then
		teams:Stat(byPlayer, "damage", amount)
		if teams:Team(byPlayer) == "monster" then
			teams:AddMonsterXp(byPlayer, amount * Constants.MONSTER_XP.damage)
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			Net.fire(byPlayer, "Popup", root.Position + Vector3.new(0, 4, 0), tostring(amount), "hit")
		end
	end
	self.Hit:Fire(byPlayer, { player = victim }, amount, kind)
	return amount
end

function CombatService:HealPlayer(target, amount, byPlayer)
	if not teams:IsAlive(target) then
		return 0
	end
	local hum = target.Character:FindFirstChildOfClass("Humanoid")
	local before = hum.Health
	hum.Health = math.min(hum.MaxHealth, hum.Health + amount)
	local healed = hum.Health - before
	if healed > 0 and byPlayer and byPlayer ~= target then
		teams:Stat(byPlayer, "healed", math.floor(healed))
	end
	if healed > 0 then
		self.Healed:Fire(byPlayer, target, healed)
	end
	return healed
end

local function knock(player, dir, force)
	local d = Vector3.new(dir.X, 0, dir.Z)
	if d.Magnitude < 1e-3 then
		return
	end
	player:SetAttribute("AcGrace", now() + 1.2)
	Net.fire(player, "Knock", d.Unit, force)
end

-- Targets ---------------------------------------------------------------------------------------------------------
-- Enemies of a team near a position: { player | npc, pos, radius }.
local function enemiesOf(team, pos, radius)
	local out = {}
	local other = team == "dwarf" and "monster" or "dwarf"
	for _, p in teams:Players(other) do
		local pp = teams:Position(p)
		if pp and (pp - pos).Magnitude <= radius then
			table.insert(out, { player = p, pos = pp, radius = 1.6 })
		end
	end
	for _, n in horde:Near(pos, radius, other) do
		table.insert(out, {
			npc = n,
			pos = n.pos + Vector3.new(0, 2.6 * (n.kind == "brute" and 1.4 or 1), 0),
			radius = n.kind == "brute" and 2.4 or 1.5,
		})
	end
	return out
end
CombatService.enemiesOf = enemiesOf

local function friendsOf(team, pos, radius)
	local out = {}
	for _, p in teams:Players(team) do
		local pp = teams:Position(p)
		if pp and (pp - pos).Magnitude <= radius then
			table.insert(out, { player = p, pos = pp })
		end
	end
	for _, n in horde:Near(pos, radius, team) do
		table.insert(out, { npc = n, pos = n.pos })
	end
	return out
end

-- Hit one enemy (a player or an NPC). Returns the damage done.
function CombatService:_hitEnemy(attacker, e, amount, kind, knockForce, fromPos)
	if e.player then
		local done = self:HurtPlayer(e.player, amount, attacker, kind)
		if done > 0 and knockForce then
			knock(e.player, e.pos - fromPos, knockForce)
		end
		return done
	elseif e.npc then
		horde:Damage(e.npc.id, amount, attacker, kind)
		if knockForce then
			horde:Knock(e.npc.id, e.pos - fromPos, knockForce * 0.35)
		end
		self.Hit:Fire(attacker, { npc = e.npc }, amount, kind)
		Net.fire(attacker, "Popup", e.pos + Vector3.new(0, 3, 0), tostring(math.floor(amount + 0.5)), "hit")
		return amount
	end
	return 0
end

-- How hard this player hits right now (gear, monster level, the Grunt's pack, a Roar).
function CombatService:_damageMult(player, job)
	local team = teams:Team(player)
	local s = teams:State(player)
	local t = now()
	if team == "dwarf" then
		local m = Formulas.weaponMult(s and s.gear.weapon or 0)
		if job.heightBonus then
			local pos = teams:Position(player)
			if pos and pos.Y - 3 - MapLayout.groundY(pos.X, pos.Z) >= Jobs.HIGH_GROUND then
				m *= 1 + job.heightBonus
			end
		end
		return m
	end
	local m = teams:MonsterMult(player)
	if job.pack then
		local pos = teams:Position(player)
		local near = 0
		if pos then
			for _, p in teams:Players("monster") do
				local pp = p ~= player and teams:Position(p)
				if pp and (pp - pos).Magnitude <= Jobs.PACK_RADIUS then
					near += 1
				end
			end
			near += #horde:Near(pos, Jobs.PACK_RADIUS, "monster")
		end
		m *= Formulas.packMult(job, near)
	end
	local e = fx(player)
	if e.roarUntil > t then
		m *= e.roarDmg
	end
	return m
end

-- The nearest castle piece a monster can hit from here (in front of it, in reach).
local function pieceInFront(pos, facing, range, arc)
	local best, bestD
	for _, p in build:Near(pos, range + 2) do
		local d, dy = build.distToPiece(p, pos)
		if dy > -6 and dy < p.def.height + 6 and Formulas.inArc(facing, p.center - pos, arc or 140) then
			if not bestD or d < bestD then
				best, bestD = p, d
			end
		end
	end
	return best
end

-- Moves ------------------------------------------------------------------------------------------------------------
function CombatService:_melee(player, job, move, facing)
	local root = teams:Root(player)
	if not root or not teams:IsAlive(player) then
		return
	end
	local pos = root.Position
	local team = teams:Team(player)
	local mult = self:_damageMult(player, job)
	local list = enemiesOf(team, pos, move.range + 4)
	table.sort(list, function(a, b)
		return (a.pos - pos).Magnitude < (b.pos - pos).Magnitude
	end)
	local hits = 0
	for _, e in list do
		local d = e.pos - pos
		if
			Vector2.new(d.X, d.Z).Magnitude <= move.range + e.radius
			and math.abs(d.Y) < 8
			and Formulas.inArc(facing, d, move.arc or 90)
		then
			self:_hitEnemy(player, e, (move.damage or 0) * mult, move.key, move.knock, pos)
			hits += 1
			if hits >= (move.cleave or 1) then
				break
			end
		end
	end
	if hits == 0 and team == "monster" and move.pieceDamage then
		local p = pieceInFront(pos, facing, move.range, 150)
		if p then
			local amount = move.pieceDamage * mult * ((p.def.gate and move.gateMult) or 1)
			build:Damage(p.id, amount, player, move.key)
			self.Hit:Fire(player, { piece = p }, amount, move.key)
			hits = 1
		end
	end
	if hits > 0 then
		Net.fireAll("Sfx", "hit", pos)
	end
end

-- A projectile: aim help, then the hit lands after it flies. Returns the end point.
function CombatService:_shoot(player, job, move, dir, damageMult, style)
	local root = teams:Root(player)
	if not root or not teams:IsAlive(player) then
		return
	end
	local team = teams:Team(player)
	local origin = root.Position + Vector3.new(0, 1.5, 0)
	local range = move.range
	if job.heightBonus and origin.Y - 4.5 - MapLayout.groundY(origin.X, origin.Z) >= Jobs.HIGH_GROUND then
		range *= 1.3
	end
	dir = dir.Magnitude > 1e-3 and dir.Unit or root.CFrame.LookVector
	local mult = self:_damageMult(player, job) * (damageMult or 1)
	-- a Healer's Mend looks for a hurt friend first
	local target, kind
	if move.friendly then
		local best, bestAng
		for _, f in friendsOf(team, origin, range) do
			local hurt
			if f.player then
				local hum = f.player ~= player
					and f.player.Character
					and f.player.Character:FindFirstChildOfClass("Humanoid")
				hurt = hum and hum.Health < hum.MaxHealth
			else
				hurt = f.npc.hp < f.npc.maxHp
			end
			if hurt then
				local v = f.pos - origin
				local ang = math.deg(math.acos(math.clamp(v.Unit:Dot(dir), -1, 1)))
				if ang <= move.assist * 1.5 and (not bestAng or ang < bestAng) then
					best, bestAng = f, ang
				end
			end
		end
		if best then
			target, kind = best, "friend"
		end
	end
	if not target then
		local bestAlong, bestAng, assisted
		for _, e in enemiesOf(team, origin, range) do
			local v = e.pos - origin
			local along = v:Dot(dir)
			if along > 0 and along <= range then
				local perp = (v - dir * along).Magnitude
				if perp <= 2 + e.radius then
					if not bestAlong or along < bestAlong then
						target, bestAlong = e, along
					end
				elseif not bestAlong then
					local ang = math.deg(math.acos(math.clamp(v.Unit:Dot(dir), -1, 1)))
					if ang <= (move.assist or 0) and (not bestAng or ang < bestAng) then
						assisted, bestAng = e, ang
					end
				end
			end
		end
		target = target or assisted
		kind = target and "enemy" or nil
	end
	local endPos = target and target.pos or origin + dir * range
	-- monsters' shots can hit the castle on the way
	local piece
	if team == "monster" and move.pieceDamage then
		local stepLen = 2
		local far = target and (target.pos - origin).Magnitude or range
		for k = 1, math.floor(far / stepLen) do
			local p = origin + dir * (k * stepLen)
			local pc = build:PieceAtCell(MapLayout.cellOf(p.X, p.Z))
			if pc and p.Y <= pc.groundY + pc.def.height + 0.5 and p.Y >= pc.groundY - 1 then
				piece = pc
				endPos = p
				target = nil
				break
			end
		end
	end
	local dist = (endPos - origin).Magnitude
	Net.fireAll("Fx", "projectile", {
		style = style or move.projectile or "arrow",
		from = origin,
		to = endPos,
		speed = move.speed or 120,
		by = player.UserId,
	})
	local delay = math.min(1, dist / (move.speed or 120))
	task.delay(delay, function()
		if target and kind == "friend" then
			if target.player then
				self:HealPlayer(target.player, move.heal * (damageMult or 1), player)
			else
				horde:Heal(target.npc.id, move.heal)
				teams:Stat(player, "healed", move.heal)
			end
			Net.fireAll("Fx", "heal", { position = target.pos, radius = 3 })
		elseif target then
			self:_hitEnemy(player, target, (move.damage or 0) * mult, move.key, move.knock, origin)
			if move.slow then
				if target.player then
					self:Slow(target.player, move.slow, move.slowSeconds or 2)
				else
					horde:Slow(target.npc.id, move.slow, move.slowSeconds or 2)
				end
			end
		elseif piece then
			build:Damage(piece.id, move.pieceDamage * mult, player, move.key)
			if move.curse then
				piece.curseUntil = now() + move.curseSeconds
				piece.curseMult = move.curse
				Net.fireAll("Fx", "curse", { id = piece.id, position = piece.center, seconds = move.curseSeconds })
			end
			self.Hit:Fire(player, { piece = piece }, move.pieceDamage * mult, move.key)
		end
	end)
	return endPos
end

local specials = {}

-- Builder: a free quick wall right in front of you (a comeback tool, §10).
function specials.quickWall(_self, player, _job, _move, facing)
	local pos = teams:Position(player)
	local f = Vector3.new(facing.X, 0, facing.Z)
	f = f.Magnitude > 1e-3 and f.Unit or Vector3.new(0, 0, -1)
	local rot = math.abs(f.X) > math.abs(f.Z) and 1 or 0
	local c = pos + f * 6
	local w, d = rot == 1 and 1 or 2, rot == 1 and 2 or 1
	local i = math.floor(c.X / Constants.CELL - w / 2 + 0.5)
	local j = math.floor(c.Z / Constants.CELL - d / 2 + 0.5)
	local piece, why = build:Place(player, "quickWall", i, j, rot, { built = true })
	if not piece then
		Net.fire(player, "Toast", why or "No room for a wall there.", "bad")
		return false
	end
	Net.fireAll("Fx", "built", { id = piece.id, position = piece.center, key = piece.key, size = piece.size })
	return true
end

-- Miner: rip a big chunk out of the node in reach.
function specials.bigDig(_self, player, _job, move, _facing, target)
	local pos = teams:Position(player)
	local id = type(target) == "table" and target.node
	if not id then
		local best, bestD
		for nid, n in resources:Nodes() do
			local d = (n.pos - pos).Magnitude
			if n.amount > 0 and d <= Constants.MINE_RANGE + n.size / 2 and (not bestD or d < bestD) then
				best, bestD = nid, d
			end
		end
		id = best
	end
	if not id or not resources:Mine(player, id, move.amount, true) then
		Net.fire(player, "Toast", "Stand by a rock, tree or gold vein to Big Dig.", "bad")
		return false
	end
	return true
end

-- Fighter: block most damage and shove monsters back.
function specials.shieldWall(_self, player, _job, move)
	local e = fx(player)
	e.shieldUntil = now() + move.seconds
	e.shieldCut = move.cut
	local pos = teams:Position(player)
	for _, en in enemiesOf("dwarf", pos, move.radius) do
		if en.player then
			knock(en.player, en.pos - pos, move.push)
		else
			horde:Knock(en.npc.id, en.pos - pos, move.push * 0.6)
		end
	end
	Net.fireAll("Fx", "shield", { by = player.UserId, position = pos, seconds = move.seconds, radius = move.radius })
	return true
end

-- Archer: five arrows at once.
function specials.volley(self, player, job, move, facing)
	local n = move.arrows
	for k = 1, n do
		local a = math.rad(-move.spread / 2 + (k - 1) * move.spread / (n - 1))
		local dir = (CFrame.Angles(0, a, 0) * Vector3.new(facing.X, facing.Y, facing.Z))
		self:_shoot(player, job, job.main, dir, move.damageMult, "arrow")
	end
	return true
end

-- Healer: heal everyone near and shield the walls for a moment.
function specials.ward(self, player, _job, move)
	local pos = teams:Position(player)
	for _, f in friendsOf("dwarf", pos, move.radius) do
		if f.player then
			self:HealPlayer(f.player, move.heal, player)
		else
			horde:Heal(f.npc.id, move.heal)
		end
	end
	for _, p in build:Near(pos, move.radius, true) do
		p.shieldUntil = now() + move.shieldSeconds
	end
	Net.fireAll(
		"Fx",
		"ward",
		{ by = player.UserId, position = pos, radius = move.radius, seconds = move.shieldSeconds }
	)
	return true
end

-- Grunt: monsters near you get fast and fierce.
function specials.roar(_self, player, _job, move)
	local pos = teams:Position(player)
	local t = now()
	for _, p in teams:Players("monster") do
		local pp = teams:Position(p)
		if pp and (pp - pos).Magnitude <= move.radius then
			local e = fx(p)
			e.roarUntil = t + move.seconds
			e.roarSpeed = move.speed
			e.roarDmg = move.damage
		end
	end
	for _, n in horde:Near(pos, move.radius, "monster") do
		n.roarUntil = t + move.seconds
	end
	Net.fireAll("Fx", "roar", { by = player.UserId, position = pos, radius = move.radius })
	Net.fireAll("Sfx", "roar", pos)
	return true
end

-- Brute: charge through everything in front (the client moves its own character; the server finds the hits).
function specials.charge(self, player, job, move, facing)
	local dir = Vector3.new(facing.X, 0, facing.Z)
	dir = dir.Magnitude > 1e-3 and dir.Unit or Vector3.new(0, 0, -1)
	player:SetAttribute("AcGrace", now() + move.seconds + 1)
	Net.fire(player, "Dash", dir, move.distance, move.seconds)
	local hitPlayers, hitNpcs, hitPieces = {}, {}, {}
	local mult = self:_damageMult(player, job)
	task.spawn(function()
		local stop = now() + move.seconds + 0.15
		while now() < stop and teams:IsAlive(player) do
			local pos = teams:Position(player)
			if pos then
				for _, e in enemiesOf("monster", pos, 5.5) do
					if e.player and not hitPlayers[e.player] then
						hitPlayers[e.player] = true
						self:_hitEnemy(player, e, move.damage * mult, "charge", move.knock, pos)
					elseif e.npc and not hitNpcs[e.npc.id] then
						hitNpcs[e.npc.id] = true
						self:_hitEnemy(player, e, move.damage * mult, "charge", move.knock, pos)
					end
				end
				for _, p in build:Near(pos, 4) do
					if not hitPieces[p.id] then
						hitPieces[p.id] = true
						build:Damage(p.id, move.pieceDamage * mult, player, "charge")
					end
				end
			end
			task.wait(0.1)
		end
	end)
	Net.fireAll("Fx", "charge", { by = player.UserId, dir = dir, seconds = move.seconds })
	return true
end

-- Spitter: a goo puddle where you aim; dwarves in it slow down and get hurt.
function specials.goo(_self, player, _job, move, facing)
	local root = teams:Root(player)
	local origin = root.Position
	local dir = Vector3.new(facing.X, 0, facing.Z)
	dir = dir.Magnitude > 1e-3 and dir.Unit or root.CFrame.LookVector
	local dist = move.range
	-- land it on the first dwarf in the way, if one is close to the aim
	for _, e in enemiesOf("monster", origin, move.range) do
		local v = e.pos - origin
		local along = v:Dot(dir)
		if along > 0 and (v - dir * along).Magnitude < 6 and along < dist then
			dist = along
		end
	end
	local p = origin + dir * dist
	local landing = Vector3.new(p.X, MapLayout.groundY(p.X, p.Z), p.Z)
	table.insert(puddles, {
		pos = landing,
		radius = move.radius,
		untilT = now() + move.seconds,
		by = player,
		slow = move.slow,
		dps = move.dps,
	})
	Net.fireAll(
		"Fx",
		"projectile",
		{ style = "goo", from = origin + Vector3.new(0, 1.5, 0), to = landing, speed = 80, by = player.UserId }
	)
	Net.fireAll("Fx", "goo", { position = landing, radius = move.radius, seconds = move.seconds })
	return true
end

-- Witch: heal monsters near you and call two imps.
function specials.dark(self, player, _job, move)
	local pos = teams:Position(player)
	for _, f in friendsOf("monster", pos, move.radius) do
		if f.player then
			self:HealPlayer(f.player, move.heal, player)
		else
			horde:Heal(f.npc.id, move.heal)
		end
	end
	for k = 1, move.imps do
		local a = k * math.pi
		horde:Spawn("imp", pos + Vector3.new(math.cos(a) * 3, 0, math.sin(a) * 3))
	end
	Net.fireAll("Fx", "dark", { by = player.UserId, position = pos, radius = move.radius })
	Net.fireAll("Sfx", "magic", pos)
	return true
end

-- Breaker: plant a bomb that blows up walls.
function specials.bomb(self, player, _job, move, facing)
	local pos = teams:Position(player)
	local f = Vector3.new(facing.X, 0, facing.Z)
	f = f.Magnitude > 1e-3 and f.Unit or Vector3.new(0, 0, -1)
	local p = pos + f * 3
	local at = Vector3.new(p.X, MapLayout.groundY(p.X, p.Z), p.Z)
	table.insert(bombs, {
		pos = at,
		at = now() + move.fuse,
		by = player,
		move = move,
		mult = self:_damageMult(player, Jobs.byKey.breaker),
	})
	Net.fireAll("Fx", "bombPlant", { position = at, fuse = move.fuse, by = player.UserId })
	return true
end

-- The request ------------------------------------------------------------------------------------------------------
function CombatService:Act(player, slot, aim, target)
	if slot ~= "main" and slot ~= "special" then
		return false
	end
	if not match:InMatch() or not teams:IsAlive(player) then
		return false
	end
	local team = teams:Team(player)
	local job = teams:JobData(player)
	if not team or not job then
		return false
	end
	local t = now()
	local cd = cooldowns[player]
	if not cd then
		cd = { main = 0, special = 0 }
		cooldowns[player] = cd
	end
	if t < cd[slot] - 0.08 or self:IsStunned(player) then
		return false
	end
	local move = job[slot]
	local root = teams:Root(player)
	local facing = (typeof(aim) == "Vector3" and aim.Magnitude > 0.01) and aim.Unit or root.CFrame.LookVector
	-- a dwarf's main move on a node or a piece: mine it or hammer it
	if team == "dwarf" and slot == "main" and type(target) == "table" then
		if type(target.node) == "number" then
			local ok = resources:Mine(player, target.node, job.minePower or 1, false)
			if ok then
				cd.main = t + move.cooldown
				Net.fireAll("Act", { by = player.UserId, move = "mine", windup = 0.1, slot = slot })
				self.Acted:Fire(player, slot, "mine")
				return true
			end
		elseif type(target.piece) == "number" then
			local result = build:Hammer(player, target.piece)
			if result and result ~= "fine" then
				cd.main = t + move.cooldown
				if result ~= "needs" then
					Net.fireAll("Act", { by = player.UserId, move = "hammer", windup = 0.1, slot = slot })
					self.Acted:Fire(player, slot, "hammer")
				end
				return true
			end
		end
	end
	if slot == "special" then
		local fn = specials[move.key]
		if not fn then
			return false
		end
		local ok = fn(self, player, job, move, facing, target)
		if ok then
			cd.special = t + move.cooldown
			Net.fireAll("Act", { by = player.UserId, move = move.key, windup = 0, slot = slot })
			self.Acted:Fire(player, slot, move.key)
			Net.fire(player, "Sfx", move.key == "volley" and "arrow" or "magic")
		end
		return ok
	end
	cd.main = t + move.cooldown
	Net.fireAll("Act", { by = player.UserId, move = move.key, windup = move.windup, slot = slot })
	self.Acted:Fire(player, slot, move.key)
	if move.kind == "ranged" then
		task.delay(move.windup, function()
			local r = teams:Root(player)
			if r and teams:IsAlive(player) then
				self:_shoot(
					player,
					job,
					move,
					typeof(aim) == "Vector3" and aim or r.CFrame.LookVector,
					1,
					move.projectile
				)
				Net.fireAll("Sfx", move.projectile == "arrow" and "arrow" or "spit", r.Position)
			end
		end)
	else
		Net.fireAll("Sfx", "swing", root.Position)
		task.delay(move.windup, function()
			self:_melee(player, job, move, facing)
		end)
	end
	return true
end

-- Puddles and bombs ------------------------------------------------------------------------------------------------
function CombatService:_tick(dt)
	local t = now()
	for k = #puddles, 1, -1 do
		local pd = puddles[k]
		if t >= pd.untilT then
			table.remove(puddles, k)
		else
			for _, e in enemiesOf("monster", pd.pos, pd.radius) do
				if e.player then
					self:Slow(e.player, pd.slow, 0.6)
					self:HurtPlayer(e.player, pd.dps * dt, pd.by and pd.by.Parent and pd.by or nil, "goo")
				else
					horde:Slow(e.npc.id, pd.slow, 0.6)
					horde:Damage(e.npc.id, pd.dps * dt, pd.by, "goo")
				end
			end
		end
	end
	for k = #bombs, 1, -1 do
		local b = bombs[k]
		if t >= b.at then
			table.remove(bombs, k)
			local by = b.by and b.by.Parent and b.by or nil
			for _, p in build:Near(b.pos, b.move.radius) do
				build:Damage(
					p.id,
					b.move.pieceDamage * b.mult,
					by and teams:Team(by) == "monster" and by or nil,
					"bomb"
				)
			end
			for _, e in enemiesOf("monster", b.pos, b.move.radius) do
				self:_hitEnemy(by, e, b.move.damage * b.mult, "bomb", 22, b.pos)
			end
			Net.fireAll("Fx", "explode", { position = b.pos, radius = b.move.radius })
			Net.fireAll("Sfx", "crumble", b.pos)
		end
	end
	for player in effects do
		if player.Parent then
			self:_speed(player)
		else
			effects[player] = nil
		end
	end
end

function CombatService:Init(reg)
	match = reg.MatchService
	teams = reg.TeamService
	build = reg.BuildService
	resources = reg.ResourceService
	horde = reg.HordeService
	Net.on("Act", function(player, slot, aim, target)
		if typeof(aim) ~= "Vector3" then
			aim = nil
		end
		if target ~= nil and type(target) ~= "table" then
			target = nil
		end
		self:Act(player, slot, aim, target)
	end)
	teams.Spawned:Connect(function(player)
		effects[player] = nil
		cooldowns[player] = { main = 0, special = 0 }
	end)
	match.Reset:Connect(function()
		table.clear(puddles)
		table.clear(bombs)
	end)
end

function CombatService:Start()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.2 then
			local step = math.min(acc, 0.5)
			acc = 0
			local ok, err = pcall(self._tick, self, step)
			if not ok then
				warn("[CombatService] " .. tostring(err))
			end
		end
	end)
end

function CombatService:OnPlayerLeaving(player)
	cooldowns[player] = nil
	effects[player] = nil
end

-- (tests)
function CombatService:Cooldowns(player)
	return cooldowns[player]
end

return CombatService
