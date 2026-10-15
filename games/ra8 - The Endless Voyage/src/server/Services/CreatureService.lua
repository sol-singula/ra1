--[[
Who lives in the ocean (master plan §9: creatures with a reason to meet them). Island creatures guard what you
came for (crabs on the shore, lurkers in the reeds, beetles by the crystals, wolves in threes, the stone guardian
by the idol); sea creatures come with voyages (sharks and serpents bite the raft's edges: spikes punish them,
spears and harpoons kill them); the Leviathan waits in the Trench, surfacing to bite and diving out of reach.
The server owns every creature as a point in the world (no physics); clients draw and animate them from a
snapshot sent 8 times a second ("Creatures") and events ("Creature": spawn, tell, hit, surface, dive, die).

  states   idle | chase | tell | attack | flee | circle | surface | dive | dead
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Creatures = require(ReplicatedStorage.Shared.Data.Creatures)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local CreatureService = {
	Name = "CreatureService",
	Dependencies = { "PlayerDataService", "RaftService", "InventoryService", "PlayerService", "IslandService" },
	Spawned = Signal.new("CreatureService.Spawned"), -- (c)
	Hit = Signal.new("CreatureService.Hit"), -- (c, dmg, player, how)
	Killed = Signal.new("CreatureService.Killed"), -- (c, killer, hits)
	Attacked = Signal.new("CreatureService.Attacked"), -- (c, player, dmg)
	Bit = Signal.new("CreatureService.Bit"), -- (c, raft, piece, dmg)
	Stole = Signal.new("CreatureService.Stole"), -- (c, player, itemKey)
	Surfaced = Signal.new("CreatureService.Surfaced"), -- (c)
	Left = Signal.new("CreatureService.Left"), -- (c, why)
}

local rafts, inventory, players, island
local creatures = {} -- [id] = c
local nextId = 0
local rng = Random.new()
local TICK = 0.1
local SNAP = 1 / 8
local turretAt = {} -- [plot] = t

local function now()
	return workspace:GetServerTimeNow()
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function yawTo(from, to)
	local d = to - from
	return math.atan2(-d.X, -d.Z)
end

local function send(plot, kind, c, extra)
	local e = { kind = kind, id = c.id, creature = c.kind, pos = c.pos, boss = c.boss or nil, state = c.state }
	for k, v in extra or {} do
		e[k] = v
	end
	for _, p in players:PlayersOnPlot(plot) do
		Net.fire(p, "Creature", e)
	end
end

-- Reads -----------------------------------------------------------------------------------------------------------
function CreatureService:Get(id)
	return creatures[id]
end

function CreatureService:All()
	return creatures
end

function CreatureService:Near(pos, radius, plot)
	local out = {}
	for _, c in creatures do
		if (not plot or c.plot == plot) and c.state ~= "dead" and (c.pos - pos).Magnitude <= radius then
			table.insert(out, c)
		end
	end
	return out
end

function CreatureService:OnPlot(plot)
	local out = {}
	for _, c in creatures do
		if c.plot == plot and c.state ~= "dead" then
			table.insert(out, c)
		end
	end
	return out
end

function CreatureService:Boss(plot)
	for _, c in creatures do
		if c.plot == plot and c.boss and c.state ~= "dead" then
			return c
		end
	end
	return nil
end

-- Can a weapon reach it right now? (diving creatures can't be hit)
function CreatureService:Hittable(c)
	return c.state ~= "dead" and c.state ~= "dive"
end

-- Spawning ----------------------------------------------------------------------------------------------------------
function CreatureService:SpawnAt(kind, pos, plot, opts)
	local def = Creatures.get(kind)
	if not def then
		return nil
	end
	opts = opts or {}
	local danger = opts.danger or 1
	nextId += 1
	local c = {
		id = nextId,
		kind = kind,
		def = def,
		plot = plot,
		pos = pos,
		home = pos,
		yaw = rng:NextNumber(0, math.pi * 2),
		hp = Formulas.creatureHp(def.hp, danger),
		maxHp = Formulas.creatureHp(def.hp, danger),
		dmg = Formulas.creatureDamage(def.dmg, danger),
		speed = def.speed,
		state = def.where == "island" and "idle" or (def.where == "boss" and "dive" or "circle"),
		danger = danger,
		island = opts.island,
		event = opts.event,
		leaveAt = opts.leaveAt,
		boss = def.where == "boss" or nil,
		nextAttack = now() + 1,
		nextBite = now() + 4,
		stateUntil = now() + (def.where == "boss" and 6 or 0),
		hits = {},
		angle = rng:NextNumber(0, math.pi * 2),
		wanderAt = 0,
	}
	creatures[c.id] = c
	send(plot, "spawn", c)
	self.Spawned:Fire(c)
	return c
end

function CreatureService:Remove(id, why)
	local c = creatures[id]
	if not c then
		return
	end
	creatures[id] = nil
	if c.state ~= "dead" then
		c.state = "gone"
		send(c.plot, "flee", c)
		self.Left:Fire(c, why or "left")
	end
end

function CreatureService:ClearPlot(plot, source)
	for id, c in creatures do
		if c.plot == plot and (not source or (source == "island" and c.island) or (source == "event" and c.event)) then
			self:Remove(id, "gone")
		end
	end
end

-- Damage ------------------------------------------------------------------------------------------------------------
function CreatureService:Damage(id, dmg, player, how)
	local c = creatures[id]
	if not c or c.state == "dead" or not self:Hittable(c) then
		return false
	end
	dmg = math.floor(dmg + 0.5)
	c.hp -= dmg
	if player then
		c.hits[player] = (c.hits[player] or 0) + dmg
		c.lastHitBy = player
		c.target = c.target or player
		-- an island creature that was hit wakes up
		if c.state == "idle" then
			c.state = "chase"
		end
	end
	send(c.plot, "hit", c, { dmg = dmg, by = player and player.UserId or nil, how = how, hp = c.hp, max = c.maxHp })
	if player then
		Net.fire(player, "Popup", c.pos + Vector3.new(0, 3, 0), tostring(dmg), Color3.fromRGB(255, 120, 100))
	end
	self.Hit:Fire(c, dmg, player, how)
	if c.boss and not c.enraged and c.hp <= c.maxHp * Constants.LEVIATHAN_ENRAGE then
		c.enraged = true
		for _, p in players:PlayersOnPlot(c.plot) do
			Net.fire(p, "Callout", "🐲 THE LEVIATHAN IS ENRAGED! Hold on and keep the harpoons coming.", "bad")
			Net.fire(p, "Sfx", "roar")
		end
	end
	if c.hp <= 0 then
		self:_die(c, player)
		return true
	end
	return false
end

function CreatureService:_die(c, killer)
	c.state = "dead"
	c.hp = 0
	creatures[c.id] = nil
	send(c.plot, "die", c, { by = killer and killer.UserId or nil })
	for _, p in players:PlayersOnPlot(c.plot) do
		Net.fire(p, "Sfx", c.boss and "win" or "hit", c.pos)
	end
	-- what it leaves
	local drops = {}
	if c.kind == "shark" then
		drops = { { "raw_fish", 3 } }
	elseif c.kind == "sea_serpent" then
		drops = { { "raw_fish", 3 }, { "pearl", 1 } }
	elseif c.kind == "ruin_guardian" then
		drops = { { "old_tech", 1 }, { "stone", 3 } }
	elseif c.kind == "frost_wolf" or c.kind == "mire_lurker" or c.kind == "lava_beetle" then
		drops = { { "fiber", 1 } }
	elseif c.kind == "reef_crab" then
		drops = { { "raw_fish", 1 } }
	end
	if killer and killer.Parent then
		for _, d in drops do
			inventory:Give(killer, d[1], d[2], "kill")
		end
	end
	if c.boss then
		for _, p in players:PlayersOnPlot(c.plot) do
			inventory:Give(p, "leviathan_scale", 3, "boss")
			inventory:Give(p, "tooth", 1, "boss")
			Net.fire(p, "Alert", "🐲 THE LEVIATHAN IS DOWN", Color3.fromRGB(255, 230, 120), 5)
		end
	end
	self.Killed:Fire(c, killer, c.hits)
end

-- Island AI -------------------------------------------------------------------------------------------------------
local function groundAt(c, x, z)
	return island:Ground(c.plot, x, z)
end

local function moveToward(c, target, dt, speed)
	local to = flat(target - c.pos)
	local dist = to.Magnitude
	if dist < 0.1 then
		return 0
	end
	local step = math.min(dist, (speed or c.speed) * dt)
	local nx, nz = c.pos.X + to.Unit.X * step, c.pos.Z + to.Unit.Z * step
	local y = groundAt(c, nx, nz)
	if not y then
		return dist -- the water: stay
	end
	c.pos = Vector3.new(nx, y + 1, nz)
	c.yaw = yawTo(c.pos, target)
	return dist - step
end

local function nearestPlayer(c, radius)
	local best, bestD
	for _, p in players:PlayersOnPlot(c.plot) do
		if players:IsAlive(p) then
			local pos = players:Position(p)
			if pos then
				local d = (flat(pos) - flat(c.pos)).Magnitude
				if d <= radius and (not bestD or d < bestD) and island:Ashore(c.plot, pos) then
					best, bestD = p, d
				end
			end
		end
	end
	return best, bestD
end

function CreatureService:_islandTick(c, dt, t)
	local def = c.def
	local b = def.behaviour
	if c.state == "flee" then
		if b == "steal" then
			c.pos += Vector3.new(0, 6 * dt, 0) + flat(c.pos - c.home).Unit * 10 * dt
			if t >= c.stateUntil then
				self:Remove(c.id, "flew")
			end
			return
		end
		local away = c.pos + flat(c.pos - (c.fleeFrom or c.home)).Unit * 6
		moveToward(c, away, dt, c.speed * 1.2)
		if t >= c.stateUntil then
			c.state = "idle"
		end
		return
	end
	-- who to go for
	local aggro = b == "guard" and 14 or b == "skitter" and 18 or 26
	local target, dist
	if c.target and c.target.Parent and players:IsAlive(c.target) then
		local pos = players:Position(c.target)
		dist = pos and (flat(pos) - flat(c.pos)).Magnitude or nil
		if not dist or dist > aggro * 1.8 or not island:Ashore(c.plot, pos) then
			c.target = nil
		else
			target = c.target
		end
	end
	if not target then
		target, dist = nearestPlayer(c, aggro)
		c.target = target
	end
	-- a leash home
	if (flat(c.pos) - flat(c.home)).Magnitude > (b == "guard" and 20 or 44) then
		c.target = nil
		target = nil
		c.state = "idle"
	end
	if not target then
		if c.state ~= "idle" then
			c.state = "idle"
		end
		-- wander near home
		if t >= c.wanderAt then
			c.wanderAt = t + rng:NextNumber(2, 5)
			local a = rng:NextNumber(0, math.pi * 2)
			c.wanderTo = c.home
				+ Vector3.new(
					math.cos(a) * rng:NextNumber(2, b == "guard" and 5 or 9),
					0,
					math.sin(a) * rng:NextNumber(2, 9)
				)
		end
		if c.wanderTo then
			local left = moveToward(c, c.wanderTo, dt, c.speed * 0.35)
			if left < 1 then
				c.wanderTo = nil
			end
		end
		if (flat(c.pos) - flat(c.home)).Magnitude > 12 then
			moveToward(c, c.home, dt, c.speed * 0.6)
		end
		return
	end
	local tpos = players:Position(target)
	if c.state == "tell" then
		c.yaw = yawTo(c.pos, tpos)
		if t >= c.stateUntil then
			-- the attack lands if they're still in reach
			c.state = "attack"
			c.stateUntil = t + 0.3
			local d = (flat(tpos) - flat(c.pos)).Magnitude
			if d <= def.range + Constants.MELEE_SLACK then
				if b == "steal" then
					local id, item = inventory:Selected(target)
					if item and item.food then
						inventory:Consume(target, id, 1)
						Net.fire(target, "Toast", `🐦 The gull took your {item.name}!`, "bad")
						self.Stole:Fire(c, target, item.key)
					end
					c.state = "flee"
					c.stateUntil = t + 4
					send(c.plot, "attack", c, { target = target.UserId })
					return
				end
				local dir = flat(tpos - c.pos)
				local dmg = players:Damage(
					target,
					c.dmg,
					{ kind = c.kind, dir = dir.Magnitude > 0.01 and dir.Unit or nil, burn = def.burn }
				)
				send(c.plot, "attack", c, { target = target.UserId, dmg = dmg })
				self.Attacked:Fire(c, target, dmg)
			end
			c.nextAttack = t + (b == "skitter" and 2.2 or 1.4)
			if b == "skitter" then
				c.state = "flee"
				c.stateUntil = t + 1.2
				c.fleeFrom = tpos
			end
		end
		return
	elseif c.state == "attack" then
		if t >= c.stateUntil then
			c.state = "chase"
		end
		return
	end
	-- chase
	c.state = "chase"
	if dist and dist <= def.range then
		c.yaw = yawTo(c.pos, tpos)
		if t >= c.nextAttack then
			c.state = "tell"
			c.stateUntil = t + (def.size == "heavy" and 0.9 or 0.6)
			send(c.plot, "tell", c, { target = target.UserId, seconds = c.stateUntil - t })
		end
	else
		moveToward(c, tpos, dt)
	end
end

-- Sea AI ----------------------------------------------------------------------------------------------------------------
function CreatureService:_seaTick(c, dt, t)
	local raft = rafts:Get(c.plot)
	if not raft then
		self:Remove(c.id, "gone")
		return
	end
	if c.leaveAt and t >= c.leaveAt and c.state ~= "surface" then
		for _, p in players:PlayersOnPlot(c.plot) do
			Net.fire(p, "Callout", `{c.def.icon} The {c.def.name} swam off.`, "info")
		end
		self:Remove(c.id, "left")
		return
	end
	local center = rafts:Center(raft)
	local radius = 8 + raft.summary.tiles * 0.9 + (c.boss and 10 or 0)
	radius = math.min(radius, 46)
	if c.state == "circle" or c.state == "dive" then
		if c.boss then
			if t >= c.stateUntil then
				-- up for air: beside the raft
				c.state = "surface"
				c.stateUntil = t + (c.enraged and 14 or 10)
				c.nextBite = t + 1.5
				local a = rng:NextNumber(0, math.pi * 2)
				c.pos = center + Vector3.new(math.cos(a) * 16, Constants.WATER_LEVEL - 0.5, math.sin(a) * 16)
				c.yaw = yawTo(c.pos, center)
				send(c.plot, "surface", c)
				for _, p in players:PlayersOnPlot(c.plot) do
					Net.fire(p, "Sfx", "roar", c.pos)
					Net.fire(
						p,
						"Callout",
						c.enraged and "🐲 IT'S UP! Harpoons, now!" or "🐲 It surfaced! Harpoons while it's up!",
						"bad"
					)
				end
				self.Surfaced:Fire(c)
				return
			end
			c.angle += dt * 0.5
			c.pos = center + Vector3.new(math.cos(c.angle) * 30, Constants.WATER_LEVEL - 10, math.sin(c.angle) * 30)
			c.yaw = c.angle + math.pi / 2
			return
		end
		c.angle += dt * (c.speed / radius)
		c.pos = center
			+ Vector3.new(math.cos(c.angle) * radius, Constants.WATER_LEVEL - 2.5, math.sin(c.angle) * radius)
		c.yaw = c.angle + math.pi / 2
		if t >= c.nextBite then
			local edges = rafts:EdgeTiles(raft)
			if #edges > 0 then
				local e = edges[rng:NextInteger(1, #edges)]
				local tilePos = rafts:TileWorld(raft, e.piece.gx, e.piece.gz, 1)
				local d = ({ Vector3.new(1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1) })[e.rot + 1]
				c.bite = { piece = e.piece, rot = e.rot, pos = tilePos + d * (Constants.TILE / 2 + 2.5) }
				c.state = "surface"
				c.stateUntil = t + 0.9
				c.pos = Vector3.new(c.bite.pos.X, Constants.WATER_LEVEL - 0.3, c.bite.pos.Z)
				c.yaw = yawTo(c.pos, tilePos)
				send(c.plot, "surface", c, { tile = e.piece.id, seconds = 0.9 })
				self.Surfaced:Fire(c)
			else
				c.nextBite = t + 3
			end
		end
		return
	elseif c.state == "surface" then
		if c.boss then
			if t >= c.nextBite then
				c.nextBite = t + (c.enraged and 2 or 3)
				local edges = rafts:EdgeTiles(raft)
				if #edges > 0 then
					local e = edges[rng:NextInteger(1, #edges)]
					local dmg = rafts:Damage(
						raft,
						e.piece,
						Constants.SERPENT_BITE * (c.enraged and 1.3 or 1),
						{ kind = "leviathan" }
					)
					send(c.plot, "bite", c, { tile = e.piece.id, dmg = dmg })
					self.Bit:Fire(c, raft, e.piece, dmg)
					for _, p in players:PlayersOnPlot(c.plot) do
						local pos = players:Position(p)
						if pos and rafts:TileAt(raft, pos) == e.piece then
							players:Damage(p, c.dmg, { kind = "leviathan" })
						end
					end
				end
			end
			if t >= c.stateUntil then
				c.state = "dive"
				c.stateUntil = t + (c.enraged and 8 or 12)
				c.angle = rng:NextNumber(0, math.pi * 2)
				send(c.plot, "dive", c)
				for _, p in players:PlayersOnPlot(c.plot) do
					Net.fire(p, "Callout", "🐲 It dived. Repair what you can before it's back.", "info")
				end
			end
			return
		end
		if t >= c.stateUntil and c.bite then
			local b = c.bite
			c.bite = nil
			local dmg = c.kind == "shark" and Constants.SHARK_BITE or Constants.SERPENT_BITE
			local spiked = rafts:SpikesAt(raft, b.piece, b.rot)
			if spiked then
				dmg = math.floor(dmg * 0.5)
				self:Damage(c.id, Constants.SPIKE_DAMAGE, nil, "spikes")
				for _, p in players:PlayersOnPlot(c.plot) do
					Net.fire(p, "Popup", b.pos + Vector3.new(0, 2, 0), "📌 Spiked!", Color3.fromRGB(255, 200, 120))
				end
			end
			if creatures[c.id] then
				local done = rafts:Damage(raft, b.piece, dmg, { kind = c.kind })
				send(c.plot, "bite", c, { tile = b.piece.id, dmg = done })
				self.Bit:Fire(c, raft, b.piece, done)
				for _, p in players:PlayersOnPlot(c.plot) do
					local pos = players:Position(p)
					if pos and rafts:TileAt(raft, pos) == b.piece then
						players:Damage(p, math.floor(c.dmg * 0.6), { kind = c.kind })
					end
				end
				c.state = "circle"
				c.nextBite = t
					+ Constants.SHARK_BITE_EVERY * (c.kind == "sea_serpent" and 1.4 or 1) * (spiked and 1.6 or 1)
				send(c.plot, "dive", c)
			end
		end
	end
end

-- Turrets fire at whatever's in the water and up.
function CreatureService:_turrets(t)
	for plot, raft in rafts:All() do
		if t < (turretAt[plot] or 0) then
			continue
		end
		local turrets = rafts:Turrets(raft)
		if #turrets == 0 then
			continue
		end
		turretAt[plot] = t + Constants.TURRET_EVERY
		for _, tur in turrets do
			local best, bestD
			for _, c in self:OnPlot(plot) do
				if c.def.where ~= "island" and self:Hittable(c) then
					local d = (c.pos - tur.pos).Magnitude
					if d <= Constants.TURRET_RANGE and (not bestD or d < bestD) then
						best, bestD = c, d
					end
				end
			end
			if best then
				for _, p in players:PlayersOnPlot(plot) do
					Net.fire(p, "Fx", "turret", { from = tur.pos, to = best.pos })
				end
				self:Damage(best.id, Constants.TURRET_DAMAGE, raft.owner, "turret")
			end
		end
	end
end

-- Snapshots -------------------------------------------------------------------------------------------------------
function CreatureService:Pack(plot)
	local list = {}
	for _, c in creatures do
		if c.plot == plot then
			table.insert(list, {
				c.id,
				c.kind,
				math.floor(c.pos.X * 10) / 10,
				math.floor(c.pos.Y * 10) / 10,
				math.floor(c.pos.Z * 10) / 10,
				math.floor(c.yaw * 100) / 100,
				math.max(0, math.floor(c.hp)),
				c.maxHp,
				c.state,
			})
		end
	end
	return { t = now(), list = list }
end

function CreatureService:_tick(dt)
	local t = now()
	for _, c in creatures do
		if c.state == "dead" then
			continue
		end
		if c.def.where == "island" then
			self:_islandTick(c, dt, t)
		else
			self:_seaTick(c, dt, t)
		end
	end
	self:_turrets(t)
end

function CreatureService:Init(reg)
	rafts = reg.RaftService
	inventory = reg.InventoryService
	players = reg.PlayerService
	island = reg.IslandService
	rafts.Released:Connect(function(_, raft)
		self:ClearPlot(raft.plot)
		turretAt[raft.plot] = nil
	end)
end

function CreatureService:Start()
	local acc, snapAcc = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		snapAcc += dt
		if acc >= TICK then
			self:_tick(acc)
			acc = 0
		end
		if snapAcc >= SNAP then
			snapAcc = 0
			for plot in rafts:All() do
				local any = false
				for _, c in creatures do
					if c.plot == plot then
						any = true
						break
					end
				end
				if any then
					local pack = self:Pack(plot)
					for _, p in players:PlayersOnPlot(plot) do
						Net.fire(p, "Creatures", pack)
					end
				end
			end
		end
	end)
end

-- (tests)
CreatureService.creatures = creatures
return CreatureService
