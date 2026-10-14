--[[
The monsters (master plan §5 enemy framework, §10 roster). Simulated here, on the server, as plain data (no physics,
no Humanoids): they steer round the trunks, break camp walls in their way, stamp on the fire, and hunt survivors.
Clients draw them from a small snapshot sent 8 times a second (MonsterController animates them), so a forest full
of monsters costs little on a phone (§11, §14: efficient AI, no pathfinding every frame).

Every attack is telegraphed (§5: "an attack that can be anticipated and countered"): a wind-up everyone sees
(Mob "tell" events: a crouch, a howl and red eyes, a ring or a circle on the ground, Kermy's SIX... SEVEN!), then
the hit, resolved with a little latency forgiveness (SurvivorService.ResolveHit).

  night     waves from the forest, sized by the night, the survivors at the stage boundary and the difficulty
            (Formulas.nightBudget, §8); new kinds join as the nights go on; at dawn they slink away
  day       a few packs roam the deep forest; from day 3 a golden pack (elites, §10) guards rare loot; findings
            have guards (WorldService)
  Kermy     the pursuer (Enemies.kermy): hunts whoever is alone; lunges after his tell, faceplants when he misses;
            fakes a retreat, then charges; takes bush shortcuts (a rustling bush warns you); can't resist a Smelly
            Sandwich; by day he peeks from the trees, or naps in his lair (sneak, or he wakes up)
  mimics    crates that bite (LootService springs them): they run off with the loot, get tired, run again
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService_ = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Enemies = require(ReplicatedStorage.Shared.Data.Enemies)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local MapLayout = require(ReplicatedStorage.Shared.World.MapLayout)
local MobCodes = require(ReplicatedStorage.Shared.Data.MobCodes)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local MonsterService = {
	Name = "MonsterService",
	Dependencies = {
		"PlayerDataService",
		"RunService",
		"SurvivorService",
		"InventoryService",
		"CampService",
		"ResourceService",
	},
	Spawned = Signal.new("MonsterService.Spawned"), -- (mob)
	Killed = Signal.new("MonsterService.Killed"), -- (mob, killer?, assists = { [player] = damage })
	Hurt = Signal.new("MonsterService.Hurt"), -- (mob, amount, byPlayer?)
	KermyKO = Signal.new("MonsterService.KermyKO"), -- (mob, killer?, assists)
	KermyWoke = Signal.new("MonsterService.KermyWoke"), -- (player?)
	Sighting = Signal.new("MonsterService.Sighting"), -- () Kermy's first appearance of the run
	Learned = Signal.new("MonsterService.Learned"), -- (player, enemyKey, tipKey): a tell read right
	Seen = Signal.new("MonsterService.Seen"), -- (player, enemyKey, elite)
}

local data, runs, survivors, inventory, camp, resources
local mobs = {} -- [id] = mob
local nextId = 1
local externals = {} -- entities other services draw through the snapshot (Mega Kermy): [id] = entity
local traps = {} -- [id] = { id, pos, item, root, dmg, uses, owner, model }
local nextTrap = 1
local baits = {} -- { pos, untilT }
local staticObstacles = {} -- [cell] = { { x, z, r } }
local dynamicObstacles = {} -- [tag] = { { x, z, r } }
local treeCells = {} -- [cell] = { tree record } (reachable trees; ResourceService says which are felled)
local night = { budget = 0, spent = 0, carry = 0, nextWave = 0, waves = 0 }
local kermy -- the run's Kermy mob (or nil)
local kermyState = { sighted = false, nextPeek = 0, koUntil = 0, lair = nil, nightSpawned = false }
local elitePack
local sendAcc = 0
local CELL = 16

local KINDS, STATES = MobCodes.KINDS, MobCodes.STATES
local KIND_INDEX, STATE_INDEX = MobCodes.KIND_INDEX, MobCodes.STATE_INDEX
MonsterService.KINDS = KINDS
MonsterService.STATES = STATES

-- How each kind behaves (on top of Data/Enemies' numbers).
local B = {
	snapcap = {
		radius = 1,
		aggro = 45,
		leap = 8,
		leapTime = 0.3,
		hitRadius = 2.8,
		recover = 0.8,
		cooldown = 1.5,
		pieceDmg = 6,
	},
	grinwolf = {
		radius = 1.4,
		aggro = 60,
		circle = 13,
		dash = 14,
		dashTime = 0.35,
		hitRadius = 3,
		recover = 1,
		cooldown = 2.2,
		knock = 6,
		pieceDmg = 10,
	},
	pelter = {
		radius = 1,
		aggro = 55,
		keepMin = 18,
		keepMax = 28,
		flight = 0.8,
		splash = 3.6,
		cooldown = 2.8,
		pieceDmg = 4,
	},
	stumpy = {
		radius = 2.2,
		aggro = 40,
		slamRadius = 9,
		knock = 10,
		recover = 1.4,
		cooldown = 2.6,
		pieceDmg = 60,
		resist = 1,
	},
	mimic = { radius = 1.4, aggro = 30, range = 6, recover = 0.8, cooldown = 1.8, pieceDmg = 8 },
	kermy = {
		radius = 1.6,
		lunge = 20,
		lungeTime = 0.4,
		hitRadius = 3.6,
		knock = 12,
		cooldown = 3.5,
		pieceDmg = 40,
		resist = 2,
	},
}
MonsterService.BEHAVIOR = B

local function now()
	return workspace:GetServerTimeNow()
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function ground(x, z)
	return MapLayout.groundY(x, z)
end

local function cellKey(x, z)
	return math.floor(x / CELL) * 100000 + math.floor(z / CELL)
end

-- Obstacles ------------------------------------------------------------------------------------------------------------
local function addCircle(grid, x, z, r, v)
	for cx = math.floor((x - r) / CELL), math.floor((x + r) / CELL) do
		for cz = math.floor((z - r) / CELL), math.floor((z + r) / CELL) do
			local k = cx * 100000 + cz
			grid[k] = grid[k] or {}
			table.insert(grid[k], v)
		end
	end
end

-- A solid circle monsters walk round (a finding's building, a big rock). Replaced by tag each run.
function MonsterService:SetObstacles(tag, list)
	dynamicObstacles[tag] = list
end

-- Every obstacle circle near (x, z): { x, z, r }
local function obstaclesNear(x, z, radius)
	local out = {}
	for cx = math.floor((x - radius) / CELL), math.floor((x + radius) / CELL) do
		for cz = math.floor((z - radius) / CELL), math.floor((z + radius) / CELL) do
			local k = cx * 100000 + cz
			for _, t in treeCells[k] or {} do
				if not resources:IsFelled(t.id) then
					table.insert(out, { x = t.x, z = t.z, r = t.trunk, tree = t })
				end
			end
			for _, o in staticObstacles[k] or {} do
				table.insert(out, o)
			end
		end
	end
	for _, list in dynamicObstacles do
		for _, o in list do
			if (o.x - x) ^ 2 + (o.z - z) ^ 2 < (radius + o.r) ^ 2 then
				table.insert(out, o)
			end
		end
	end
	return out
end
MonsterService.obstaclesNear = obstaclesNear

-- Is the straight line a -> b clear of trunks and rocks? (Kermy's lunge, a Pelter's throw)
function MonsterService:LineClear(a, b, pad)
	pad = pad or 0
	local d = flat(b - a)
	local len = d.Magnitude
	if len < 0.5 then
		return true
	end
	local dir = d / len
	local mid = (a + b) / 2
	for _, o in obstaclesNear(mid.X, mid.Z, len / 2 + 6) do
		local rel = Vector3.new(o.x - a.X, 0, o.z - a.Z)
		local t = rel:Dot(dir)
		if t > 0 and t < len then
			local lateral = (rel - dir * t).Magnitude
			if lateral < o.r + pad then
				return false, o
			end
		end
	end
	return true
end

-- Camp barriers: the wall ring's built walls and gates block monsters crossing it.
local function angleOf(x, z)
	local a = math.deg(math.atan2(z, x)) % 360
	return a
end

local function inArc(a, a0, a1)
	a, a0, a1 = a % 360, a0 % 360, a1 % 360
	if a0 <= a1 then
		return a >= a0 and a <= a1
	end
	return a >= a0 or a <= a1
end

local function barrierAt(angle)
	for _, s in camp:Barriers() do
		local a0, a1
		if s.key == "gate" then
			local half = math.deg(MapLayout.CAMP.gateWidth / 2 / MapLayout.CAMP.wallRadius) + 1
			a0, a1 = s.slot.angle - half, s.slot.angle + half
		else
			a0, a1 = s.slot.a0 - 0.5, s.slot.a1 + 0.5
		end
		if inArc(angle, a0, a1) then
			return s
		end
	end
	return nil
end

-- A move from a to b that crosses the wall ring through a built barrier: that barrier (else nil).
local function crossing(a, b)
	local R = MapLayout.CAMP.wallRadius
	local ra = math.sqrt(a.X * a.X + a.Z * a.Z)
	local rb = math.sqrt(b.X * b.X + b.Z * b.Z)
	if (ra - R) * (rb - R) > 0 and math.abs(rb - R) > 1.2 then
		return nil
	end
	return barrierAt(angleOf(b.X, b.Z))
end

-- The nearest gap in the wall ring (an unbuilt slot) within maxDeg of an angle: its angle, or nil.
local function nearestGap(angle, maxDeg)
	local best, bestD
	for d = 0, maxDeg, 4 do
		for _, sign in { 1, -1 } do
			local a = angle + d * sign
			if not barrierAt(a) then
				if not bestD or d < bestD then
					best, bestD = a, d
				end
			end
		end
		if best then
			return best
		end
	end
	return nil
end

-- Spawning ---------------------------------------------------------------------------------------------------------------
local function freeSpot(x, z, radius)
	for _ = 1, 20 do
		local ok = MapLayout.walkable(x, z)
		if ok then
			for _, o in obstaclesNear(x, z, radius + 4) do
				if (o.x - x) ^ 2 + (o.z - z) ^ 2 < (o.r + radius + 0.5) ^ 2 then
					ok = false
					break
				end
			end
		end
		if ok then
			return x, z
		end
		x += math.random(-6, 6)
		z += math.random(-6, 6)
	end
	return x, z
end

function MonsterService:Spawn(kind, pos, opts)
	opts = opts or {}
	local def = Enemies.get(kind)
	assert(def, "unknown monster " .. tostring(kind))
	local beh = B[kind] or B.snapcap
	local x, z = freeSpot(pos.X, pos.Z, beh.radius)
	local diff = runs:Difficulty()
	local players = runs:StagePlayers()
	local elite = opts.elite == true
	local hp
	local dmg = Formulas.monsterDamage(def.dmg, diff, elite)
	if kind == "kermy" then
		hp = Formulas.kermyHp(def.hp, math.max(1, runs:Night()), players, diff)
		dmg = Formulas.kermyDamage(def.dmg, math.max(1, runs:Night()), diff)
	else
		hp = Formulas.monsterHp(def.hp, players, diff, elite)
	end
	local id = nextId
	nextId = nextId % 65000 + 1
	local m = {
		id = id,
		kind = kind,
		def = def,
		beh = beh,
		elite = elite,
		pos = Vector3.new(x, ground(x, z), z),
		yaw = opts.yaw or math.random() * math.pi * 2,
		hp = hp,
		maxHp = hp,
		dmg = dmg,
		speed = def.speed * (elite and Enemies.ELITE.speed or 1),
		state = opts.state or "chase",
		stateUntil = 0,
		nextAttack = now() + 1 + math.random(),
		stunUntil = 0,
		rootUntil = 0,
		hitAt = -99,
		actCount = 0,
		moving = false,
		home = opts.home or opts.guard,
		guard = opts.guard,
		day = opts.day == true,
		pack = opts.pack,
		loot = opts.loot,
		opener = opts.opener,
		dmgBy = {},
		spawnedAt = now(),
		lastRetreatHp = hp,
	}
	if runs:Event() == "bloodmoon" and not m.day then
		m.speed *= 1.2
	end
	mobs[id] = m
	Net.fireAll("Mob", { kind = "spawn", id = id, monster = kind, elite = elite })
	self.Spawned:Fire(m)
	return m
end

function MonsterService:SpawnPack(kind, pos, n, opts)
	opts = opts or {}
	local pack = { members = {}, token = nil }
	local out = {}
	for i = 1, n do
		local a = i / n * math.pi * 2
		local o = table.clone(opts)
		o.pack = pack
		local m = self:Spawn(kind, pos + Vector3.new(math.cos(a) * 4, 0, math.sin(a) * 4), o)
		table.insert(pack.members, m)
		table.insert(out, m)
	end
	return out, pack
end

-- A sprung mimic: it runs from whoever opened it, carrying the loot.
function MonsterService:SpawnMimic(pos, items, opener)
	local m = self:Spawn("mimic", pos, { loot = items, opener = opener, state = "flee" })
	m.stateUntil = now() + 6
	m.escapeAt = now() + 60
	m.bitten = false
	return m
end

function MonsterService:Get(id)
	return mobs[id]
end

function MonsterService:All()
	return mobs
end

function MonsterService:Count(filter)
	local n = 0
	for _, m in mobs do
		if not filter or filter(m) then
			n += 1
		end
	end
	return n
end

-- Monsters within radius of pos (alive, not hidden), nearest first.
function MonsterService:Near(pos, radius)
	local out = {}
	for _, m in mobs do
		if m.hp > 0 and m.state ~= "hidden" and m.state ~= "dead" then
			local d = (flat(m.pos) - flat(pos)).Magnitude
			if d <= radius + m.beh.radius then
				table.insert(out, m)
			end
		end
	end
	table.sort(out, function(a, b)
		return (a.pos - pos).Magnitude < (b.pos - pos).Magnitude
	end)
	return out
end

function MonsterService:Kermy()
	return kermy
end

function MonsterService:ElitePack()
	return elitePack
end

-- The Kermy-free list of external entities (Mega Kermy): drawn through the snapshot.
function MonsterService:SetExternal(id, entity)
	externals[id] = entity
end

local function event(t)
	Net.fireAll("Mob", t)
end

-- Damage --------------------------------------------------------------------------------------------------------------------
-- Hit a monster. opts = { stagger = 0-3, knock = studs, dir = Vector3, kind = weapon class, crit = bool }
function MonsterService:Damage(id, amount, byPlayer, opts)
	local m = mobs[id]
	if not m or m.hp <= 0 or m.harmless then
		return 0
	end
	opts = opts or {}
	local t = now()
	if m.kind == "kermy" and m.state == "faceplant" and byPlayer then
		self.Learned:Fire(byPlayer, "kermy", "faceplant")
	end
	if m.state == "faceplant" or m.state == "tired" or m.state == "eat" or m.state == "sleep" then
		amount *= 1.5
	end
	amount = math.max(1, math.floor(amount + 0.5))
	m.hp -= amount
	m.hitAt = t
	if byPlayer then
		m.dmgBy[byPlayer] = (m.dmgBy[byPlayer] or 0) + amount
		m.lastAttacker = byPlayer
	end
	event({ kind = "hit", id = id, amount = amount, crit = opts.crit, by = byPlayer and byPlayer.UserId })
	self.Hurt:Fire(m, amount, byPlayer)
	-- a sleeping Kermy wakes up
	if m.kind == "kermy" and m.state == "sleep" then
		self:_wake(m, byPlayer)
	end
	-- a stagger stops a wind-up (§5 clubs: "staggering certain enemies"); a big enough one staggers anytime
	local resist = m.beh.resist or 0
	local stagger = opts.stagger or 0
	if stagger >= 1 and m.kind ~= "mega_kermy" and (m.state == "tell" or stagger > resist) then
		m.state = "stagger"
		m.tellNext = nil
		m.stateUntil = t + Constants.STAGGER_SECONDS
		m.stunUntil = m.stateUntil
		event({ kind = "stagger", id = id })
		if byPlayer and m.kind == "stumpy" then
			self.Learned:Fire(byPlayer, "stumpy", "stagger")
		end
	end
	if opts.knock and opts.dir and m.kind ~= "kermy" and m.kind ~= "stumpy" then
		self:_shove(m, opts.dir, opts.knock * (m.def.size == "small" and 1.3 or 0.8))
	end
	if m.hp <= 0 then
		self:_kill(m, byPlayer)
	elseif m.kind == "kermy" then
		self:_kermyHurt(m, byPlayer)
	end
	return amount
end

function MonsterService:_shove(m, dir, dist)
	dir = flat(dir)
	if dir.Magnitude < 0.01 then
		return
	end
	local target = m.pos + dir.Unit * dist
	if crossing(m.pos, target) then
		return
	end
	for _, o in obstaclesNear(target.X, target.Z, m.beh.radius + 4) do
		if (o.x - target.X) ^ 2 + (o.z - target.Z) ^ 2 < (o.r + m.beh.radius) ^ 2 then
			return
		end
	end
	if MapLayout.walkable(target.X, target.Z) then
		m.pos = Vector3.new(target.X, ground(target.X, target.Z), target.Z)
	end
end

function MonsterService:Stun(id, seconds)
	local m = mobs[id]
	if m and m.kind ~= "mega_kermy" then
		m.state = "stagger"
		m.stateUntil = now() + seconds
		m.stunUntil = m.stateUntil
		event({ kind = "stagger", id = id })
	end
end

function MonsterService:Root(id, seconds)
	local m = mobs[id]
	if m and m.kind ~= "kermy" then
		m.rootUntil = now() + seconds
	end
end

local function assistsOf(m)
	local out = {}
	for p, dmg in m.dmgBy do
		if p.Parent then
			out[p] = dmg
		end
	end
	return out
end

function MonsterService:_kill(m, killer)
	m.hp = 0
	if m.kind == "kermy" then
		self:_kermyKO(m, killer)
		return
	end
	mobs[m.id] = nil
	event({ kind = "die", id = m.id, by = killer and killer.UserId })
	-- what it leaves behind
	local drops = {}
	for _, d in m.def.drops or {} do
		if math.random() < d[4] then
			table.insert(drops, { key = d[1], n = math.random(d[2], d[3]) })
		end
	end
	for _, it in m.loot or {} do
		table.insert(drops, it)
	end
	if m.elite then
		table.insert(drops, {
			key = ({ "hunting_spear", "shield_brew", "medkit", "lucky_clover", "owl_feather" })[math.random(1, 5)],
			n = 1,
		})
		if math.random() < 0.25 then
			table.insert(
				drops,
				{ key = ({ "crystal_axe", "boulder_maul", "crossbow", "night_goggles" })[math.random(1, 4)], n = 1 }
			)
		end
	end
	if #drops > 0 then
		inventory:SpawnDrop(m.pos, drops)
	end
	if m.pack then
		local alive = 0
		for _, other in m.pack.members do
			if other.hp > 0 then
				alive += 1
			end
		end
		if alive == 1 then
			for _, other in m.pack.members do
				if other.hp > 0 and other.kind == "grinwolf" then
					other.state = "flee"
					other.stateUntil = now() + 6
					other.fleeing = true
				end
			end
		end
	end
	self.Killed:Fire(m, killer, assistsOf(m))
end

-- Kermy ---------------------------------------------------------------------------------------------------------------------
function MonsterService:_kermyHurt(m, by)
	-- the fake retreat: every quarter of his health, he "runs away"... then turns and charges (§5)
	if m.lastRetreatHp - m.hp >= m.maxHp * 0.25 and m.state ~= "flee" and m.state ~= "charge" then
		m.lastRetreatHp = m.hp
		m.state = "flee"
		m.stateUntil = now() + 2.6
		m.fleeFrom = by and survivors:Position(by) or m.pos
		m.retreating = true
		event({ kind = "say", id = m.id, text = "NOPE NOPE NOPE" })
	end
end

function MonsterService:_kermyKO(m, killer)
	local assists = assistsOf(m)
	m.state = "ko"
	m.stateUntil = now() + 2.2
	m.hp = 0
	event({ kind = "ko", id = m.id, by = killer and killer.UserId })
	Net.fireAll("Callout", "🐸 Kermy is KNOCKED OUT! (He'll be back...)", "good")
	local d = Formulas.difficulty(runs:Difficulty())
	local back = d.kermyBack or Constants.KERMY_BACK_AFTER
	kermyState.koUntil = runs:Night() >= 5 and (now() + back) or math.huge
	-- he drops something good
	local drops = { { key = ({ "kermy_bait", "medkit", "speed_brew", "golden_apple" })[math.random(1, 4)], n = 1 } }
	if math.random() < 0.12 then
		table.insert(drops, { key = "kermy_jersey", n = 1 })
	end
	inventory:SpawnDrop(m.pos, drops)
	self.KermyKO:Fire(m, killer, assists)
	self.Killed:Fire(m, killer, assists)
	task.delay(2.2, function()
		if mobs[m.id] == m then
			mobs[m.id] = nil
			event({ kind = "die", id = m.id, puff = true })
		end
		if kermy == m then
			kermy = nil
		end
	end)
end

function MonsterService:_wake(m, by)
	if m.state ~= "sleep" then
		return
	end
	m.state = "wake"
	m.stateUntil = now() + 1.2
	m.dayChaseUntil = now() + 30
	event({ kind = "say", id = m.id, text = "WHO'S IN MY HOUSE?!" })
	Net.fireAll("Callout", "🐸 You woke Kermy up! RUN!", "bad")
	self.KermyWoke:Fire(by)
end

-- Spawn Kermy at night: far from the camp, on the side of whoever is most alone.
function MonsterService:_spawnKermyNight()
	if kermy and mobs[kermy.id] then
		return kermy
	end
	local targets = survivors:Targets()
	local pos
	if #targets > 0 then
		local t = targets[math.random(1, #targets)]
		local dir = flat(t.pos).Magnitude > 1 and flat(t.pos).Unit or Vector3.new(1, 0, 0)
		local p = t.pos + dir * 70
		pos = Vector3.new(p.X, 0, p.Z)
	else
		pos = MapLayout.polar(math.random(0, 359), 140)
	end
	if not MapLayout.walkable(pos.X, pos.Z) then
		pos = MapLayout.polar(math.random(0, 359), 140)
	end
	kermy = self:Spawn("kermy", pos, { state = "chase" })
	kermy.lastRetreatHp = kermy.hp
	event({ kind = "say", id = kermy.id, text = "six... seven..." })
	Net.fireAll("Callout", "🐸 Kermy is hunting... stay together!", "bad")
	Net.fireAll("Sfx", "roar")
	return kermy
end

-- Day 1: Kermy shows himself at the edge of the clearing, does the 6-7, and runs off (§4: meet the threat).
function MonsterService:_sighting()
	if kermyState.sighted then
		return
	end
	kermyState.sighted = true
	local angle = MapLayout.GATE_ANGLES[math.random(1, 4)] + 28
	local p = MapLayout.polar(angle, 84)
	local m = self:Spawn("kermy", p, { state = "show" })
	m.stateUntil = now() + 3.2
	m.harmless = true
	m.yaw = math.atan2(p.X, p.Z)
	event({ kind = "say", id = m.id, text = "SIX... SEVEN!" })
	Net.fireAll("Callout", "😨 What was THAT?! Something's watching from the trees...", "bad")
	Net.fireAll("Sfx", "roar", m.pos)
	self.Sighting:Fire()
end

-- By day: Kermy peeks at someone from behind a tree, then ducks away.
function MonsterService:_peek()
	local options = {}
	for _, t in survivors:Targets() do
		if flat(t.pos).Magnitude > 70 then
			table.insert(options, t)
		end
	end
	if #options == 0 then
		return
	end
	local t = options[math.random(1, #options)]
	local a = math.random() * math.pi * 2
	local p = t.pos + Vector3.new(math.cos(a), 0, math.sin(a)) * math.random(45, 65)
	if not MapLayout.walkable(p.X, p.Z) or flat(p).Magnitude < 80 then
		return
	end
	local m = self:Spawn("kermy", p, { state = "peek" })
	m.stateUntil = now() + 6
	m.harmless = true
	m.peekAt = t.player
	local d = flat(t.pos - m.pos)
	m.yaw = math.atan2(-d.X, -d.Z)
end

-- Kermy's lair: he naps on his throne by day (days 2-7) if this run has the lair.
function MonsterService:SetLair(cf)
	kermyState.lair = cf
end

function MonsterService:_napAtLair()
	local cf = kermyState.lair
	if not cf or (kermy and mobs[kermy.id]) then
		return
	end
	kermy = self:Spawn("kermy", cf.Position, { state = "sleep" })
	kermy.home = cf.Position
	local look = cf.LookVector
	kermy.yaw = math.atan2(-look.X, -look.Z)
	kermy.lair = true
end

-- Traps, baits, throws ---------------------------------------------------------------------------------------------------------
function MonsterService:PlaceTrap(owner, item, pos)
	local count = 0
	for _ in traps do
		count += 1
	end
	if count >= Constants.TRAPS_MAX then
		return nil, "The team has set too many traps. Use some up first."
	end
	local id = nextTrap
	nextTrap += 1
	local uses = item.trap.uses
	local profile = owner and data:Get(owner)
	if profile and table.find(profile.perks or {}, "trapper") then
		uses += 1
	end
	local t = {
		id = id,
		pos = pos,
		item = item.key,
		root = item.trap.root,
		dmg = item.trap.dmg,
		uses = uses,
		owner = owner,
		hits = {},
	}
	local folder = workspace:FindFirstChild("Traps") or workspace
	local model = Instance.new("Model")
	model.Name = item.key
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Anchored = true
	base.CanCollide = false
	base.Size = Vector3.new(0.3, 2.4, 2.4)
	base.Shape = Enum.PartType.Cylinder
	base.CFrame = CFrame.new(pos + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	base.Color = item.key == "snare" and Color3.fromRGB(200, 170, 120) or Color3.fromRGB(96, 100, 112)
	base.Material = item.key == "snare" and Enum.Material.Fabric or Enum.Material.Metal
	base.Parent = model
	model.Parent = folder
	t.model = model
	traps[id] = t
	return t
end

function MonsterService:Traps()
	return traps
end

function MonsterService:AddBait(pos, seconds)
	table.insert(baits, { pos = pos, untilT = now() + seconds })
end

-- A firecracker goes off: small monsters are stunned, Kermy is startled.
function MonsterService:Firecracker(pos, radius, stun, dmg, by)
	for _, m in self:Near(pos, radius) do
		if m.kind == "kermy" then
			if m.state ~= "ko" and m.state ~= "sleep" then
				m.state = "startled"
				m.stateUntil = now() + 1.5
				event({ kind = "say", id = m.id, text = "AAAH!" })
			end
		elseif m.def.size == "small" or m.def.size == "medium" then
			self:Damage(m.id, dmg, by, {})
			if mobs[m.id] then
				self:Stun(m.id, stun)
			end
		else
			self:Damage(m.id, dmg, by, {})
		end
	end
end

-- Movement ------------------------------------------------------------------------------------------------------------------
-- Move toward goal at speed for dt, steering round trunks and rocks. Returns a blocking barrier if the wall ring stops it.
function MonsterService:_step(m, goal, speed, dt)
	local to = flat(goal - m.pos)
	local dist = to.Magnitude
	if dist < 0.3 then
		m.moving = false
		return nil
	end
	local dir = to / dist
	local r = m.beh.radius
	local look = math.min(dist, speed * 0.9 + 5)
	local avoid = Vector3.zero
	for _, o in obstaclesNear(m.pos.X, m.pos.Z, look + 4) do
		local rel = Vector3.new(o.x - m.pos.X, 0, o.z - m.pos.Z)
		local d = rel.Magnitude
		local clear = o.r + r + 0.6
		if d < clear and d > 0.01 then
			-- inside it: push straight out
			local out = -rel / d * (clear - d)
			m.pos = Vector3.new(m.pos.X + out.X, m.pos.Y, m.pos.Z + out.Z)
		end
		local ahead = rel:Dot(dir)
		if ahead > 0 and ahead < look then
			local lateral = rel - dir * ahead
			local lm = lateral.Magnitude
			if lm < clear then
				local side = lm > 0.05 and -lateral / lm or Vector3.new(-dir.Z, 0, dir.X)
				avoid += side * (1 - lm / clear) * (1 - ahead / look) * 2.2
			end
		end
	end
	local moveDir = dir + avoid
	if moveDir.Magnitude < 0.05 then
		moveDir = Vector3.new(-dir.Z, 0, dir.X)
	end
	moveDir = moveDir.Unit
	local stepLen = math.min(dist, speed * dt)
	local nextPos = m.pos + moveDir * stepLen
	local barrier = crossing(m.pos, nextPos)
	if barrier then
		m.moving = false
		return barrier
	end
	if not MapLayout.walkable(nextPos.X, nextPos.Z) then
		-- slide along the edge instead
		nextPos = m.pos + Vector3.new(-moveDir.Z, 0, moveDir.X) * stepLen
		if not MapLayout.walkable(nextPos.X, nextPos.Z) then
			m.moving = false
			return nil
		end
	end
	m.pos = Vector3.new(nextPos.X, ground(nextPos.X, nextPos.Z), nextPos.Z)
	m.yaw = math.atan2(-moveDir.X, -moveDir.Z)
	m.moving = true
	return nil
end

local function face(m, pos)
	local d = flat(pos - m.pos)
	if d.Magnitude > 0.01 then
		m.yaw = math.atan2(-d.X, -d.Z)
	end
end

local function yawDir(m)
	return Vector3.new(-math.sin(m.yaw), 0, -math.cos(m.yaw))
end

-- Targets ---------------------------------------------------------------------------------------------------------------------
-- A survivor for this monster: the nearest within aggro, Grinwolves prefer the busy ones (§10: "surrounds distracted
-- players"), Kermy prefers whoever is far from the fire and alone.
function MonsterService:_pickTarget(m, targets, radius)
	local best, bestScore
	local t = now()
	for _, tg in targets do
		local d = (flat(tg.pos) - flat(m.pos)).Magnitude
		if d <= radius then
			local score = -d
			if m.kind == "grinwolf" then
				local busy = tg.player:GetAttribute("ActAt")
				if type(busy) == "number" and t - busy < 1.5 then
					score += 25
				end
			elseif m.kind == "kermy" then
				score = flat(tg.pos).Magnitude * 0.6 - d * 0.4
				local alone = true
				for _, other in targets do
					if other ~= tg and (other.pos - tg.pos).Magnitude < Constants.ISOLATED_RADIUS then
						alone = false
					end
				end
				if alone then
					score += 60
				end
			end
			if not bestScore or score > bestScore then
				best, bestScore = tg, score
			end
		end
	end
	return best
end

-- Hit every survivor in a circle (resolved with dodge forgiveness). tip: the bestiary tell it teaches.
function MonsterService:_areaHit(m, center, radius, dmg, knock, tip)
	for _, tg in survivors:Targets() do
		local d = (flat(tg.pos) - flat(center)).Magnitude
		if d <= radius then
			local player = tg.player
			survivors:ResolveHit(player, m.kind .. ":" .. tip, function()
				local dir = flat(tg.pos - center)
				dir = dir.Magnitude > 0.01 and dir.Unit or yawDir(m)
				survivors:Damage(player, dmg, { kind = m.kind, dir = dir, knock = knock })
			end)
		elseif m.tellInside and m.tellInside[tg.player] then
			-- was in the marked area when it started, and got out in time
			self.Learned:Fire(tg.player, m.kind, tip)
		end
	end
	m.tellInside = nil
end

-- Hit whoever is near a line (dashes, lunges, charges): resolved with dodge forgiveness.
function MonsterService:_lineHit(m, a, b, width, dmg, knock, tip)
	local hitAny = false
	local seg = flat(b - a)
	local len = seg.Magnitude
	local dir = len > 0.01 and seg / len or yawDir(m)
	m.struck = m.struck or {}
	for _, tg in survivors:Targets() do
		local rel = flat(tg.pos - a)
		local t = math.clamp(rel:Dot(dir), 0, len)
		local lateral = (rel - dir * t).Magnitude
		if lateral <= width and math.abs(tg.pos.Y - m.pos.Y) < 8 and not m.struck[tg.player] then
			hitAny = true
			m.struck[tg.player] = true
			local player = tg.player
			survivors:ResolveHit(player, m.kind .. ":" .. tip, function()
				survivors:Damage(player, dmg, { kind = m.kind, dir = dir, knock = knock })
			end)
		end
	end
	return hitAny
end

local function setState(m, state, seconds)
	m.state = state
	m.stateUntil = now() + (seconds or 0)
end

-- Telegraph an attack: everyone sees the wind-up for `seconds` (§5).
local function tell(m, tellKind, seconds, data_)
	m.state = "tell"
	m.tellKind = tellKind
	m.stateUntil = now() + seconds
	m.actCount += 1
	m.struck = {} -- who this attack has hit already (a lunge lasts several ticks: one hit each)
	local e = { kind = "tell", id = m.id, tell = tellKind, seconds = seconds }
	for k, v in data_ or {} do
		e[k] = v
	end
	event(e)
end

-- The wall ring: blocked monsters look for a gap, or smash through.
function MonsterService:_handleBarrier(m, barrier, goal)
	local angle = angleOf(m.pos.X, m.pos.Z)
	local gap = nearestGap(angle, 40)
	if gap and not m.smashing then
		local R = MapLayout.CAMP.wallRadius
		local outside = flat(m.pos).Magnitude > R
		local through = MapLayout.polar(gap, outside and (R - 5) or (R + 5))
		m.detour = Vector3.new(through.X, 0, through.Z)
		m.detourUntil = now() + 4
		return
	end
	-- smash it
	m.smashing = barrier
	if now() >= m.nextAttack then
		m.nextAttack = now() + (m.beh.cooldown or 1.5)
		m.actCount += 1
		face(m, barrier.slot.pos)
		camp:DamageStructure(barrier, (m.beh.pieceDmg or 10) * (m.elite and 1.5 or 1))
		event({ kind = "smash", id = m.id })
		if barrier.state ~= "built" then
			m.smashing = nil
		end
	end
	_ = goal
end

-- Walk toward a goal (a survivor or the fire), handling detours and the wall ring.
function MonsterService:_go(m, goal, speed, dt)
	local t = now()
	if m.detour and t < (m.detourUntil or 0) then
		if (flat(m.detour) - flat(m.pos)).Magnitude < 3 then
			m.detour = nil
		else
			goal = m.detour
		end
	else
		m.detour = nil
	end
	local barrier = self:_step(m, goal, speed, dt)
	if barrier then
		self:_handleBarrier(m, barrier, goal)
	else
		m.smashing = nil
	end
end

-- Thinking -------------------------------------------------------------------------------------------------------------------------
function MonsterService:_baitNear(m)
	local t = now()
	for i = #baits, 1, -1 do
		local b = baits[i]
		if t > b.untilT then
			table.remove(baits, i)
		elseif (flat(b.pos) - flat(m.pos)).Magnitude < 30 then
			return b
		end
	end
	return nil
end

local function towardFire()
	return MapLayout.CAMP_PROPS.fire
end

function MonsterService:_thinkCommon(m, _dt, targets)
	local t = now()
	-- pick or keep a target
	if
		not m.target
		or not m.target.player.Parent
		or survivors:Status(m.target.player) ~= "alive"
		or t - (m.retarget or 0) > 2
	then
		m.retarget = t
		local aggro = m.day and math.min(m.beh.aggro, 30) or m.beh.aggro
		local found = self:_pickTarget(m, targets, aggro)
		m.target = found
	elseif m.target then
		for _, tg in targets do
			if tg.player == m.target.player then
				m.target = tg
			end
		end
	end
	return m.target
end

-- Snapcap: hop after you, crouch, leap at where you were.
function MonsterService:_thinkSnapcap(m, dt, targets)
	local t = now()
	local tg = self:_thinkCommon(m, dt, targets)
	if m.state == "tell" then
		if t >= m.stateUntil then
			setState(m, "attack", m.beh.leapTime)
			m.leapFrom = m.pos
		end
		return
	elseif m.state == "attack" then
		local f = 1 - math.max(0, m.stateUntil - t) / m.beh.leapTime
		local p = m.leapFrom:Lerp(m.leapTo, math.clamp(f, 0, 1))
		m.pos = Vector3.new(p.X, ground(p.X, p.Z), p.Z)
		if t >= m.stateUntil then
			self:_areaHit(m, m.leapTo, m.beh.hitRadius, m.dmg, 3, "leap")
			setState(m, "recover", m.beh.recover)
		end
		return
	elseif m.state == "recover" or m.state == "stagger" then
		if t >= m.stateUntil then
			m.state = "chase"
		end
		return
	end
	if tg then
		local d = (flat(tg.pos) - flat(m.pos)).Magnitude
		if d < m.beh.leap and t >= m.nextAttack then
			m.nextAttack = t + m.beh.cooldown
			face(m, tg.pos)
			local dir = flat(tg.pos - m.pos)
			local reach = math.min(m.beh.leap, dir.Magnitude + 1)
			m.leapTo = m.pos + (dir.Magnitude > 0.01 and dir.Unit or yawDir(m)) * reach
			m.tellInside = { [tg.player] = true }
			tell(m, "crouch", m.def.tell, { at = m.leapTo })
			return
		end
		m.state = "chase"
		self:_go(m, tg.pos, m.speed, dt)
	else
		self:_wanderOrCamp(m, dt)
	end
end

-- Grinwolf: circle the target with the pack; one at a time, howl and dart in.
function MonsterService:_thinkWolf(m, dt, targets)
	local t = now()
	if m.state == "flee" then
		local away = m.pos + (flat(m.pos) - flat(towardFire())).Unit * 20
		self:_step(m, away, m.speed * 1.1, dt)
		if t >= m.stateUntil then
			mobs[m.id] = nil
			event({ kind = "die", id = m.id, fled = true })
		end
		return
	end
	local tg = self:_thinkCommon(m, dt, targets)
	if m.state == "tell" then
		if tg then
			face(m, tg.pos)
		end
		if t >= m.stateUntil then
			setState(m, "attack", m.beh.dashTime)
			m.dashFrom = m.pos
			m.dashDir = yawDir(m)
		end
		return
	elseif m.state == "attack" then
		local f = 1 - math.max(0, m.stateUntil - t) / m.beh.dashTime
		local target = m.dashFrom + m.dashDir * m.beh.dash * math.clamp(f, 0, 1)
		local before = m.pos
		local ok = self:_step(m, target, m.beh.dash / m.beh.dashTime, dt)
		_ = ok
		if t >= m.stateUntil then
			self:_lineHit(m, m.dashFrom, m.pos, m.beh.hitRadius, m.dmg, m.beh.knock, "dart")
			setState(m, "recover", m.beh.recover)
			if m.pack and m.pack.token == m then
				m.pack.token = nil
			end
		end
		_ = before
		return
	elseif m.state == "recover" or m.state == "stagger" then
		if t >= m.stateUntil then
			m.state = "circle"
			if m.pack and m.pack.token == m then
				m.pack.token = nil
			end
		end
		return
	end
	if not tg then
		self:_wanderOrCamp(m, dt)
		return
	end
	local d = (flat(tg.pos) - flat(m.pos)).Magnitude
	-- one wolf of the pack at a time darts in
	local pack = m.pack
	local mayDart = not pack or pack.token == nil or pack.token == m or (pack.token and pack.token.hp <= 0)
	if d < m.beh.dash and t >= m.nextAttack and mayDart then
		m.nextAttack = t + m.beh.cooldown + math.random()
		if pack then
			pack.token = m
		end
		face(m, tg.pos)
		tell(m, "howl", m.def.tell, { target = tg.player.UserId, length = m.beh.dash, width = m.beh.hitRadius * 2 })
		return
	end
	-- circle at a distance, spread round the target
	m.state = "circle"
	local slot = m.id % 6
	local a = (t * 0.6 + slot * math.pi / 3)
	local ringR = m.beh.circle
	local goal = tg.pos + Vector3.new(math.cos(a) * ringR, 0, math.sin(a) * ringR)
	if d > ringR * 2 then
		goal = tg.pos
	end
	self:_go(m, goal, m.speed * (d > ringR * 2 and 1 or 0.7), dt)
end

-- Pinecone Pelter: keep its distance, lob a pinecone at a marked spot, hide behind a trunk.
function MonsterService:_thinkPelter(m, dt, targets)
	local t = now()
	local tg = self:_thinkCommon(m, dt, targets)
	if m.state == "tell" then
		if t >= m.stateUntil then
			-- the pinecone flies (the client draws the arc), then lands on the spot
			local spot = m.lobAt
			event({ kind = "throw", id = m.id, from = m.pos + Vector3.new(0, 3, 0), to = spot, seconds = m.beh.flight })
			setState(m, "recover", 0.4)
			task.delay(m.beh.flight, function()
				self:_areaHit(m, spot, m.beh.splash, m.dmg, 2, "lob")
				event({ kind = "land", id = m.id, at = spot })
			end)
			m.hideUntil = t + 2.2
		end
		return
	elseif m.state == "recover" or m.state == "stagger" then
		if t >= m.stateUntil then
			m.state = "chase"
		end
		return
	end
	if not tg then
		self:_wanderOrCamp(m, dt)
		return
	end
	local d = (flat(tg.pos) - flat(m.pos)).Magnitude
	if t < (m.hideUntil or 0) then
		-- duck behind the nearest trunk, away from the target
		local best, bestD
		for _, o in obstaclesNear(m.pos.X, m.pos.Z, 16) do
			if o.tree then
				local od = (o.x - m.pos.X) ^ 2 + (o.z - m.pos.Z) ^ 2
				if not bestD or od < bestD then
					best, bestD = o, od
				end
			end
		end
		if best then
			local away = flat(Vector3.new(best.x, 0, best.z) - tg.pos)
			away = away.Magnitude > 0.01 and away.Unit or Vector3.new(1, 0, 0)
			local cover = Vector3.new(best.x, 0, best.z) + away * (best.r + 2)
			self:_go(m, cover, m.speed, dt)
			m.state = "chase"
			return
		end
	end
	if d < m.beh.keepMax + 4 and d > 6 and t >= m.nextAttack and self:LineClear(m.pos, tg.pos, 0.5) then
		m.nextAttack = t + m.beh.cooldown
		face(m, tg.pos)
		m.lobAt = Vector3.new(tg.pos.X, ground(tg.pos.X, tg.pos.Z), tg.pos.Z)
		m.tellInside = { [tg.player] = true }
		tell(m, "lob", m.def.tell, { at = m.lobAt, radius = m.beh.splash })
		return
	end
	m.state = "chase"
	if d < m.beh.keepMin then
		local away = flat(m.pos - tg.pos)
		away = away.Magnitude > 0.01 and away.Unit or Vector3.new(1, 0, 0)
		self:_go(m, m.pos + away * 10, m.speed, dt)
	elseif d > m.beh.keepMax then
		self:_go(m, tg.pos, m.speed, dt)
	else
		m.moving = false
		face(m, tg.pos)
	end
end

-- Stumpy: slow; raises both arms (a ring on the ground) and slams. A club or hammer hit staggers it.
function MonsterService:_thinkStumpy(m, dt, targets)
	local t = now()
	local tg = self:_thinkCommon(m, dt, targets)
	if m.state == "tell" then
		if t >= m.stateUntil then
			self:_areaHit(m, m.pos, m.beh.slamRadius, m.dmg, m.beh.knock, "slam")
			event({ kind = "slam", id = m.id, at = m.pos, radius = m.beh.slamRadius })
			-- slams break walls nearby too
			for _, s in camp:Barriers() do
				if (flat(s.slot.pos) - flat(m.pos)).Magnitude < m.beh.slamRadius + 3 then
					camp:DamageStructure(s, m.beh.pieceDmg)
				end
			end
			setState(m, "recover", m.beh.recover)
		end
		return
	elseif m.state == "recover" or m.state == "stagger" then
		if t >= m.stateUntil then
			m.state = "chase"
		end
		return
	end
	local goal = tg and tg.pos or towardFire()
	local d = (flat(goal) - flat(m.pos)).Magnitude
	if tg and d < m.beh.slamRadius - 2 and t >= m.nextAttack then
		m.nextAttack = t + m.beh.cooldown
		m.tellInside = {}
		for _, other in targets do
			if (flat(other.pos) - flat(m.pos)).Magnitude <= m.beh.slamRadius then
				m.tellInside[other.player] = true
			end
		end
		tell(m, "slam", m.def.tell, { at = m.pos, radius = m.beh.slamRadius })
		return
	end
	m.state = "chase"
	if tg then
		self:_go(m, tg.pos, m.speed, dt)
	else
		self:_wanderOrCamp(m, dt)
	end
end

-- Mimic: a sprung one runs with the loot, tires, runs again; a night one hops after you and bites.
function MonsterService:_thinkMimic(m, dt, targets)
	local t = now()
	if m.loot then
		if t > (m.escapeAt or math.huge) then
			mobs[m.id] = nil
			event({ kind = "die", id = m.id, fled = true })
			Net.fireAll("Toast", "📦 The mimic got away with its loot...", "info")
			return
		end
		if m.state == "flee" then
			local from = m.opener and survivors:Position(m.opener) or m.pos
			local away = flat(m.pos - (from or m.pos))
			away = away.Magnitude > 0.01 and away.Unit or Vector3.new(1, 0, 0)
			self:_go(m, m.pos + away * 12, m.speed, dt)
			if t >= m.stateUntil then
				setState(m, "tired", 4.5)
				event({ kind = "say", id = m.id, text = "*pant pant*" })
			end
			return
		elseif m.state == "tired" or m.state == "stagger" then
			m.moving = false
			if t >= m.stateUntil then
				setState(m, "flee", 4)
			end
			return
		end
		m.state = "flee"
		m.stateUntil = t + 4
		return
	end
	-- a night mimic: chase and bite
	local tg = self:_thinkCommon(m, dt, targets)
	if m.state == "tell" then
		if t >= m.stateUntil then
			local a = m.pos
			local b = m.pos + yawDir(m) * m.beh.range
			self:_lineHit(m, a, b, 2.5, m.dmg, 3, "breathe")
			setState(m, "recover", m.beh.recover)
		end
		return
	elseif m.state == "recover" or m.state == "stagger" then
		if t >= m.stateUntil then
			m.state = "chase"
		end
		return
	end
	if tg then
		local d = (flat(tg.pos) - flat(m.pos)).Magnitude
		if d < m.beh.range and t >= m.nextAttack then
			m.nextAttack = t + m.beh.cooldown
			face(m, tg.pos)
			tell(m, "chomp", m.def.tell, { length = m.beh.range, width = 5 })
			return
		end
		m.state = "chase"
		self:_go(m, tg.pos, m.speed, dt)
	else
		self:_wanderOrCamp(m, dt)
	end
end

-- No one to chase: at night, head for the fire (and stamp on it); by day, wander near home.
function MonsterService:_wanderOrCamp(m, dt)
	local t = now()
	if m.day or m.guard then
		local home = m.home or m.pos
		if not m.wanderTo or t > (m.wanderUntil or 0) or (flat(m.wanderTo) - flat(m.pos)).Magnitude < 2 then
			local a = math.random() * math.pi * 2
			local r = math.random(4, m.guard and 12 or 30)
			m.wanderTo = home + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			m.wanderUntil = t + math.random(4, 8)
		end
		m.state = m.guard and "guard" or "wander"
		self:_step(m, m.wanderTo, m.speed * 0.45, dt)
		return
	end
	local fire = towardFire()
	local d = (flat(fire) - flat(m.pos)).Magnitude
	if d < 7 then
		m.moving = false
		m.state = "smash"
		if t >= m.nextAttack then
			m.nextAttack = t + 1
			m.actCount += 1
			camp:Stomp(1.5 * (m.def.size == "heavy" and 2 or 1))
		end
		return
	end
	m.state = "chase"
	self:_go(m, fire, m.speed, dt)
end

-- Kermy.
function MonsterService:_thinkKermy(m, dt, targets)
	local t = now()
	local st = m.state
	if st == "ko" then
		m.moving = false
		return
	end
	if st == "show" then
		-- the day 1 sighting: stand at the edge doing the 6-7, then run into the trees
		m.moving = false
		if t >= m.stateUntil then
			m.state = "flee"
			m.stateUntil = t + 3
			m.fleeFrom = Vector3.zero
			m.vanish = true
		end
		return
	end
	if st == "peek" then
		m.moving = false
		local tooClose = false
		for _, tg in targets do
			if (flat(tg.pos) - flat(m.pos)).Magnitude < 28 then
				tooClose = true
			end
		end
		if tooClose or t >= m.stateUntil then
			mobs[m.id] = nil
			if kermy == m then
				kermy = nil
			end
			event({ kind = "die", id = m.id, puff = true })
		end
		return
	end
	if st == "sleep" then
		m.moving = false
		-- noise wakes him: someone sprinting or fighting close by
		for _, tg in targets do
			local d = (flat(tg.pos) - flat(m.pos)).Magnitude
			if d < 22 then
				local s = tg.state
				local busy = tg.player:GetAttribute("ActAt")
				if (s and s.sprinting) or (type(busy) == "number" and t - busy < 0.5 and d < 16) then
					self:_wake(m, tg.player)
					break
				end
			end
		end
		return
	end
	if st == "wake" or st == "startled" or st == "gloat" or st == "stagger" then
		m.moving = false
		if t >= m.stateUntil then
			m.state = "chase"
		end
		return
	end
	if st == "faceplant" then
		m.moving = false
		if t >= m.stateUntil then
			m.state = "chase"
			event({ kind = "say", id = m.id, text = "ow." })
		end
		return
	end
	if st == "eat" then
		m.moving = false
		if t >= m.stateUntil then
			m.state = "chase"
			event({ kind = "say", id = m.id, text = "*burp*" })
		end
		return
	end
	if st == "hidden" then
		if t >= m.stateUntil then
			m.pos = m.emergeAt
			m.state = "chase"
			event({ kind = "say", id = m.id, text = "SURPRISE!" })
			m.nextAttack = math.min(m.nextAttack, t + 0.6)
		end
		return
	end
	if st == "flee" then
		local from = m.fleeFrom or m.pos
		local away = flat(m.pos - from)
		away = away.Magnitude > 0.01 and away.Unit or yawDir(m)
		self:_step(m, m.pos + away * 20, 22, dt)
		if t >= m.stateUntil then
			if m.vanish then
				mobs[m.id] = nil
				if kermy == m then
					kermy = nil
				end
				event({ kind = "die", id = m.id, puff = true })
				return
			end
			-- the fake retreat's punchline: a look back, a grin, then the charge
			face(m, from)
			tell(m, "peekback", 0.7)
			m.tellNext = "charge"
		end
		return
	end
	if st == "charge" then
		local before = m.pos
		local blocked = self:_step(m, m.chargeTo, 30, dt)
		local hit = self:_lineHit(m, before, m.pos, m.beh.hitRadius, m.dmg * 0.85, m.beh.knock, "retreat")
		if hit or t >= m.stateUntil or (flat(m.chargeTo) - flat(m.pos)).Magnitude < 2 or blocked then
			setState(m, hit and "gloat" or "recover", 1.2)
			m.retreating = false
		end
		return
	end
	if st == "tell" then
		if m.tellNext == "charge" and t >= m.stateUntil then
			m.tellNext = nil
			local tg = self:_pickTarget(m, targets, 60) or m.target
			local goal = tg and tg.pos or (m.pos + yawDir(m) * 20)
			face(m, goal)
			m.chargeTo = m.pos + flat(goal - m.pos).Unit * math.min(36, flat(goal - m.pos).Magnitude + 6)
			setState(m, "charge", 2)
			return
		end
		if m.tellNext == "lunge" and t >= m.stateUntil then
			m.tellNext = nil
			setState(m, "attack", m.beh.lungeTime)
			m.lungeFrom = m.pos
			m.lungeDir = yawDir(m)
			return
		end
		return
	end
	if st == "attack" then
		-- the lunge: straight ahead; a tree in the way means a faceplant
		local f = 1 - math.max(0, m.stateUntil - t) / m.beh.lungeTime
		local goal = m.lungeFrom + m.lungeDir * m.beh.lunge * math.clamp(f, 0, 1)
		local before = m.pos
		local clear, tree = self:LineClear(m.pos, goal, m.beh.radius * 0.6)
		if not clear and tree then
			setState(m, "faceplant", 2.5)
			event({ kind = "faceplant", id = m.id, tree = true })
			return
		end
		m.pos = Vector3.new(goal.X, ground(goal.X, goal.Z), goal.Z)
		local hit = self:_lineHit(m, before, m.pos, m.beh.hitRadius, m.dmg, m.beh.knock, "lunge")
		if hit then
			m.lungeHit = true
		end
		if t >= m.stateUntil then
			if m.lungeHit then
				m.lungeHit = false
				setState(m, "gloat", 1.2)
				event({ kind = "say", id = m.id, text = "HEHEHE" })
			else
				setState(m, "faceplant", 2.2)
				event({ kind = "faceplant", id = m.id })
				-- whoever he was after read the tell right
				if m.target and m.target.player.Parent then
					self.Learned:Fire(m.target.player, "kermy", "lunge")
				end
			end
		end
		return
	end
	if st == "recover" then
		if t >= m.stateUntil then
			m.state = "chase"
		end
		return
	end
	-- a Smelly Sandwich nearby: he can't help himself
	local bait = self:_baitNear(m)
	if bait then
		if (flat(bait.pos) - flat(m.pos)).Magnitude < 3 then
			setState(m, "eat", math.max(0.5, bait.untilT - t))
			event({ kind = "say", id = m.id, text = "SANDWICH!" })
			for _, tg in targets do
				if (tg.pos - m.pos).Magnitude < 60 then
					self.Learned:Fire(tg.player, "kermy", "bait")
				end
			end
			return
		end
		self:_go(m, bait.pos, m.speed * 1.2, dt)
		m.state = "chase"
		return
	end
	-- by day, after waking up: chase for a while, then back to his nap
	if m.lair and m.dayChaseUntil and t > m.dayChaseUntil then
		self:_go(m, m.home, m.speed, dt)
		if (flat(m.home) - flat(m.pos)).Magnitude < 3 then
			m.state = "sleep"
			m.dayChaseUntil = nil
			event({ kind = "say", id = m.id, text = "zzz..." })
		end
		return
	end
	-- hunt
	if not m.target or t - (m.retarget or 0) > 4 or survivors:Status(m.target.player) ~= "alive" then
		m.retarget = t
		m.target = self:_pickTarget(m, targets, m.lair and 90 or 400)
	else
		for _, tg in targets do
			if tg.player == m.target.player then
				m.target = tg
			end
		end
	end
	local tg = m.target
	if not tg then
		self:_wanderOrCamp(m, dt)
		return
	end
	local d = (flat(tg.pos) - flat(m.pos)).Magnitude
	-- the bush shortcut: far behind? he dives into a bush and pops out near you (a rustling bush warns you)
	if d > 55 and t > (m.nextShortcut or 0) and not m.lair then
		m.nextShortcut = t + 20
		local behind = tg.pos
			- flat(
					tg.player.Character
							and tg.player.Character:FindFirstChild("HumanoidRootPart")
							and tg.player.Character.HumanoidRootPart.CFrame.LookVector
						or Vector3.new(0, 0, 1)
				)
				* 14
		local ex, ez = freeSpot(behind.X, behind.Z, m.beh.radius)
		m.emergeAt = Vector3.new(ex, ground(ex, ez), ez)
		setState(m, "hidden", 2.4)
		event({ kind = "rustle", id = m.id, at = m.emergeAt, seconds = 1.2, delay = 1.2 })
		self.Learned:Fire(tg.player, "kermy", "bush")
		return
	end
	if d < Constants.KERMY_LUNGE_RANGE and t >= m.nextAttack and self:LineClear(m.pos, tg.pos, 0.6) then
		m.nextAttack = t + m.beh.cooldown
		face(m, tg.pos)
		local slow = inventory:Gear(tg.player).kermyTell
		tell(
			m,
			"sixseven",
			Constants.KERMY_TELL * slow,
			{ target = tg.player.UserId, length = m.beh.lunge, width = m.beh.hitRadius * 2 }
		)
		m.tellNext = "lunge"
		event({ kind = "say", id = m.id, text = "SIX... SEVEN!" })
		return
	end
	m.state = "chase"
	self:_go(m, tg.pos, m.lair and m.speed * 0.9 or m.speed, dt)
end

-- Traps, spikes, catapults ------------------------------------------------------------------------------------------------------
function MonsterService:_traps(t)
	for id, trap in traps do
		for _, m in mobs do
			if m.hp > 0 and m.kind ~= "kermy" and m.kind ~= "mega_kermy" and not trap.hits[m.id] then
				if (flat(m.pos) - flat(trap.pos)).Magnitude < 2.8 then
					trap.hits[m.id] = true
					trap.uses -= 1
					m.rootUntil = t + trap.root
					event({ kind = "trap", id = m.id, at = trap.pos, trap = trap.item })
					if trap.dmg > 0 then
						self:Damage(m.id, trap.dmg, trap.owner, {})
					end
					if trap.uses <= 0 then
						if trap.model then
							trap.model:Destroy()
						end
						traps[id] = nil
						break
					end
				end
			end
		end
	end
end

function MonsterService:_spikes(t)
	for _, s in camp:Spikes() do
		local def = s.upgraded and { dmg = 26 } or { dmg = 15 }
		for _, m in mobs do
			if m.hp > 0 and (flat(m.pos) - flat(s.slot.pos)).Magnitude < 3.2 and t - (m.spikedAt or 0) > 1 then
				m.spikedAt = t
				self:Damage(m.id, def.dmg, nil, {})
				camp:UseSpike(s)
				event({ kind = "spike", id = m.id })
			end
		end
	end
end

function MonsterService:_catapults(t)
	if not runs:IsNight() then
		return
	end
	for _, s in camp:Catapults() do
		if t >= (s.nextShot or 0) then
			s.nextShot = t + 3
			local origin = s.slot.pos + Vector3.new(0, 10, 0)
			local best, bestD
			for _, m in mobs do
				if m.hp > 0 and m.state ~= "hidden" then
					local d = (flat(m.pos) - flat(origin)).Magnitude
					if d < 90 and d > 10 and (not bestD or d < bestD) then
						best, bestD = m, d
					end
				end
			end
			if best then
				local at = best.pos
				event({ kind = "throw", from = origin, to = at, seconds = 1, catapult = true })
				task.delay(1, function()
					for _, m in self:Near(at, 4) do
						self:Damage(m.id, 30, nil, {})
					end
					event({ kind = "land", at = at, big = true })
				end)
			end
		end
	end
end

-- Separation: monsters don't stand inside each other.
local function separate(list)
	for i = 1, #list do
		local a = list[i]
		for j = i + 1, #list do
			local b = list[j]
			local d = flat(a.pos - b.pos)
			local min = a.beh.radius + b.beh.radius
			local mag = d.Magnitude
			if mag < min and mag > 0.01 then
				local push = d / mag * (min - mag) * 0.5
				a.pos = Vector3.new(a.pos.X + push.X, a.pos.Y, a.pos.Z + push.Z)
				b.pos = Vector3.new(b.pos.X - push.X, b.pos.Y, b.pos.Z - push.Z)
			end
		end
	end
end

-- Nights and days -----------------------------------------------------------------------------------------------------------------
function MonsterService:_startNight(n)
	local seconds = Constants.NIGHT_SECONDS[n] or 100
	night = {
		n = n,
		budget = Formulas.nightBudget(n, runs:StagePlayers(), runs:Difficulty())
			* (runs:Event() == "bloodmoon" and 1.2 or 1)
			* (runs:Event() == "fog" and 1.1 or 1),
		spent = 0,
		carry = 0,
		nextWave = now() + 4,
		waves = math.max(1, math.floor(seconds * 0.8 / Constants.WAVE_EVERY)),
		started = now(),
		kermyAt = now() + 8,
	}
	-- day wanderers go home for the night
	for id, m in mobs do
		if m.day and not m.guard then
			mobs[id] = nil
			event({ kind = "die", id = id, fled = true })
		elseif m.kind == "kermy" and (m.state == "sleep" or m.lair or m.harmless) then
			mobs[id] = nil
			event({ kind = "die", id = id, puff = true })
			if kermy == m then
				kermy = nil
			end
		end
	end
	kermyState.koUntil = 0
	kermyState.nightSpawned = false
end

local WAVE_WEIGHTS = { snapcap = 3, grinwolf = 2.5, pelter = 2, stumpy = 1.2, mimic = 0.8 }

function MonsterService:_wave()
	local n = night.n or 1
	local per = night.budget / night.waves + night.carry
	local alive = self:Count(function(m)
		return not m.day
	end)
	if alive >= Constants.NPC_MAX then
		night.carry = math.min(per, night.budget * 0.3)
		return
	end
	local kinds = {}
	local total = 0
	for _, key in Enemies.NIGHT do
		local def = Enemies.get(key)
		if def.nights <= n then
			local w = WAVE_WEIGHTS[key] or 1
			if runs:Event() == "fog" and key == "grinwolf" then
				w *= 2
			end
			table.insert(kinds, { key = key, w = w, cost = def.cost })
			total += w
		end
	end
	-- where the wave comes from: the forest round the camp, or next to someone out alone
	local origin
	local targets = survivors:Targets()
	local outside = {}
	for _, tg in targets do
		if flat(tg.pos).Magnitude > 90 then
			table.insert(outside, tg)
		end
	end
	if #outside > 0 and math.random() < 0.45 then
		local tg = outside[math.random(1, #outside)]
		local a = math.random() * math.pi * 2
		local dist = math.random(Constants.SPAWN_DISTANCE[1], Constants.SPAWN_DISTANCE[2])
		origin = tg.pos + Vector3.new(math.cos(a), 0, math.sin(a)) * dist
	else
		origin = MapLayout.polar(math.random(0, 359), math.random(120, 150))
	end
	if not MapLayout.walkable(origin.X, origin.Z) or flat(origin).Magnitude < 90 then
		origin = MapLayout.polar(math.random(0, 359), 130)
	end
	local elite = Formulas.difficulty(runs:Difficulty()).elitesNightly or runs:Event() == "bloodmoon"
	local spent = 0
	local guard = 0
	while spent < per and guard < 20 and alive < Constants.NPC_MAX do
		guard += 1
		local roll = math.random() * total
		local pick = kinds[1]
		for _, k in kinds do
			roll -= k.w
			if roll <= 0 then
				pick = k
				break
			end
		end
		local off = Vector3.new(math.random(-8, 8), 0, math.random(-8, 8))
		if pick.key == "grinwolf" then
			if spent + pick.cost * 3 > per * 1.4 then
				continue
			end
			self:SpawnPack("grinwolf", origin + off, 3, { elite = elite and math.random() < 0.15 })
			spent += pick.cost * 3
			alive += 3
		else
			self:Spawn(pick.key, origin + off, { elite = elite and math.random() < 0.12 })
			spent += pick.cost
			alive += 1
		end
	end
	night.spent += spent
	night.carry = math.max(0, per - spent)
end

function MonsterService:_dawn()
	-- everything from the night slinks back into the forest
	for id, m in mobs do
		if not m.day and not m.guard and not m.loot then
			mobs[id] = nil
			event({ kind = "die", id = id, fled = true })
		end
	end
	if kermy then
		mobs[kermy.id] = nil
		event({ kind = "die", id = kermy.id, puff = true })
		kermy = nil
	end
	for id, trap in traps do
		_ = id
		_ = trap
	end
end

function MonsterService:_startDay(n)
	if n >= 2 then
		-- packs roam the deep forest
		for _ = 1, Constants.DAY_PACKS do
			local p = MapLayout.polar(math.random(0, 359), math.random(380, 470))
			if MapLayout.walkable(p.X, p.Z) then
				self:SpawnPack("grinwolf", p, math.random(2, 3), { day = true, home = p })
			end
		end
		self:_napAtLair()
	end
	if n >= Constants.ELITE_FROM_DAY and n <= 6 then
		local p = MapLayout.polar(math.random(0, 359), math.random(360, 460))
		if MapLayout.walkable(p.X, p.Z) then
			local list
			if math.random() < 0.5 then
				list = self:SpawnPack("grinwolf", p, 2, { day = true, home = p, elite = true })
			else
				list = { self:Spawn("stumpy", p, { day = true, home = p, elite = true }) }
			end
			elitePack = { members = list, pos = p, kind = list[1].kind }
			Net.fireAll(
				"Callout",
				`✨ A golden {list[1].def.name} roams the deep forest. Rare loot if you dare!`,
				"info"
			)
		end
	end
	kermyState.nextPeek = now() + Constants.KERMY_DAY_PEEK_EVERY
end

function MonsterService:Clear()
	for id in mobs do
		event({ kind = "die", id = id, fled = true })
	end
	table.clear(mobs)
	for id, trap in traps do
		if trap.model then
			trap.model:Destroy()
		end
		traps[id] = nil
	end
	table.clear(baits)
	kermy = nil
	elitePack = nil
	kermyState = { sighted = false, nextPeek = 0, koUntil = 0, lair = kermyState.lair, nightSpawned = false }
end

-- Snapshot ----------------------------------------------------------------------------------------------------------------------
-- Pack every monster: a header (server time), then 13 bytes each.
function MonsterService.pack(list, t)
	local parts = { string.pack("<d", t) }
	for _, n in list do
		local flags = (n.moving and 1 or 0)
			+ (n.elite and 2 or 0)
			+ ((t - (n.hitAt or -99)) < 0.25 and 4 or 0)
			+ ((n.stunUntil or 0) > t and 8 or 0)
			+ (n.state == "hidden" and 16 or 0)
			+ ((n.rootUntil or 0) > t and 32 or 0)
			+ ((n.actCount or 0) % 2) * 64
			+ (n.harmless and 128 or 0)
		local yaw = math.floor((((n.yaw or 0) % (math.pi * 2)) / (math.pi * 2)) * 255 + 0.5) % 256
		local hp = math.clamp(math.floor((n.hp or 0) / math.max(1, n.maxHp or 1) * 255 + 0.5), 0, 255)
		table.insert(
			parts,
			string.pack(
				"<I2Bhhh",
				n.id,
				KIND_INDEX[n.kind] or 2,
				math.clamp(math.floor(n.pos.X * 10 + 0.5), -32768, 32767),
				math.clamp(math.floor(n.pos.Y * 10 + 0.5), -32768, 32767),
				math.clamp(math.floor(n.pos.Z * 10 + 0.5), -32768, 32767)
			) .. string.pack("<BBBB", yaw, hp, flags, STATE_INDEX[n.state] or 1)
		)
	end
	return table.concat(parts)
end

-- Unpack a snapshot: time, { { id, kind, x, y, z, yaw, hp (0..1), flags, state }, ... }.
function MonsterService.unpack(s)
	return MobCodes.unpack(s)
end

function MonsterService:_send()
	local list = {}
	for _, m in mobs do
		table.insert(list, m)
	end
	for _, e in externals do
		if e.pos then
			table.insert(list, e)
		end
	end
	table.sort(list, function(a, b)
		return a.id < b.id
	end)
	Net.fireAll("Mobs", MonsterService.pack(list, now()))
end

-- The loop --------------------------------------------------------------------------------------------------------------------
function MonsterService:_tick(dt)
	local t = now()
	local phase = runs:Phase()
	if phase == "night" then
		if t >= night.nextWave and t - night.started < (Constants.NIGHT_SECONDS[night.n] or 100) * 0.85 then
			night.nextWave = t + Constants.WAVE_EVERY
			self:_wave()
		end
		if not kermyState.nightSpawned and t >= (night.kermyAt or math.huge) then
			kermyState.nightSpawned = true
			self:_spawnKermyNight()
		elseif kermyState.nightSpawned and not kermy and t >= kermyState.koUntil then
			self:_spawnKermyNight()
		end
	elseif phase == "day" then
		local run = runs:Get()
		if run and run.day == 1 and not kermyState.sighted and runs:Seconds() >= Constants.FIRST_SIGHTING_AT then
			self:_sighting()
		elseif run and run.day >= 2 and t >= kermyState.nextPeek then
			kermyState.nextPeek = t + Constants.KERMY_DAY_PEEK_EVERY
			if not kermy or not mobs[kermy.id] then
				self:_peek()
			end
		end
	end
	local targets = survivors:Targets()
	local list = {}
	for _, m in mobs do
		if m.hp > 0 or m.state == "ko" then
			if m.kind == "kermy" then
				self:_thinkKermy(m, dt, targets)
			elseif t < (m.rootUntil or 0) or (m.state == "stagger" and t < m.stateUntil) then
				m.moving = false
			elseif m.kind == "snapcap" then
				self:_thinkSnapcap(m, dt, targets)
			elseif m.kind == "grinwolf" then
				self:_thinkWolf(m, dt, targets)
			elseif m.kind == "pelter" then
				self:_thinkPelter(m, dt, targets)
			elseif m.kind == "stumpy" then
				self:_thinkStumpy(m, dt, targets)
			elseif m.kind == "mimic" then
				self:_thinkMimic(m, dt, targets)
			end
			if mobs[m.id] then
				table.insert(list, m)
			end
		end
	end
	separate(list)
	self:_traps(t)
	self:_spikes(t)
	self:_catapults(t)
	-- monsters wandering far from everyone are taken away (and leave room for new ones)
	for id, m in mobs do
		if not m.day and not m.guard and not m.loot and m.kind ~= "kermy" and t - m.spawnedAt > 20 then
			local near = flat(m.pos).Magnitude < 260
			for _, tg in targets do
				if (tg.pos - m.pos).Magnitude < 240 then
					near = true
				end
			end
			if not near then
				mobs[id] = nil
				event({ kind = "die", id = id, fled = true })
			end
		end
	end
	-- who has seen what (the bestiary)
	if t - (self._seenAt or 0) >= 1 then
		self._seenAt = t
		for _, m in mobs do
			if m.state ~= "hidden" then
				for _, tg in targets do
					if (tg.pos - m.pos).Magnitude < 60 then
						self.Seen:Fire(tg.player, m.kind, m.elite)
					end
				end
			end
		end
	end
	sendAcc += dt
	if sendAcc >= Constants.NPC_SEND then
		sendAcc = 0
		self:_send()
	end
end

function MonsterService:Init(registry)
	data = registry.PlayerDataService
	runs = registry.RunService
	survivors = registry.SurvivorService
	inventory = registry.InventoryService
	camp = registry.CampService
	resources = registry.ResourceService
	for _, t in MapLayout.trees() do
		if t.reachable then
			local k = cellKey(t.x, t.z)
			treeCells[k] = treeCells[k] or {}
			table.insert(treeCells[k], t)
		end
	end
	for _, p in MapLayout.ancientPines do
		addCircle(staticObstacles, p.pos.X, p.pos.Z, p.radius, { x = p.pos.X, z = p.pos.Z, r = p.radius, pine = p.id })
	end
	for _, o in MapLayout.OUTCROPS do
		local r = o.r * 0.55
		addCircle(staticObstacles, o.x, o.z, r, { x = o.x, z = o.z, r = r })
	end
	runs.Reset:Connect(function()
		self:Clear()
		kermyState.lair = nil
	end)
	runs.NightStarted:Connect(function(n)
		self:_startNight(n)
	end)
	runs.NightSurvived:Connect(function()
		self:_dawn()
	end)
	runs.DayStarted:Connect(function(n)
		self:_startDay(n)
	end)
	runs.BossStarted:Connect(function()
		self:_dawn() -- night 7 belongs to Mega Kermy (BossService); the forest's own monsters clear out
	end)
	runs.Ended:Connect(function()
		self:Clear()
	end)
end

function MonsterService:OnPlayerReady(player)
	data:WhenClientReady(player, function()
		local list = {}
		for _, m in mobs do
			table.insert(list, m)
		end
		Net.fire(player, "Mobs", MonsterService.pack(list, now()))
	end)
end

function MonsterService:Start()
	local acc = 0
	RunService_.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= Constants.NPC_TICK then
			local step = math.min(acc, 0.25)
			acc = 0
			local ok, err = pcall(self._tick, self, step)
			if not ok then
				warn("[MonsterService] tick failed: " .. tostring(err))
			end
		end
	end)
end

-- (tests)
MonsterService._mobs = mobs
function MonsterService:_night()
	return night
end
function MonsterService:_kermyState()
	return kermyState
end

_ = Players
return MonsterService
