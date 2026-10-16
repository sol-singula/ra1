--[[
Combat (master plan §5): health, the three bows, server arrows, hits, knockback, kills and credit.

The client only asks: Draw(true) when you start drawing, Shoot(origin, direction, shotId) when you let go. The
server times the draw itself (the charge is how long it has really been drawing, capped by the bow), checks you're
alive, it's the fight, the bow is ready (cooldown, the crossbow's magazine), and that the arrow starts near your
head. Then it flies the arrow itself in ARROW_STEP steps (Formulas.arrowAt: the same curve the clients draw) against
every opponent's head and body spheres and every solid box (the map's, the structures'), and decides the hit, the
damage (by charge; heads x HEADSHOT), the knockback, and the kill. Everyone is told about the arrow (Arrow) so they
draw it, and where it stopped (ArrowEnd).

Health is the server's own (state.hp), mirrored onto the Humanoid for the health bar. Spawn protection, no friendly
fire, no damage outside the fight. Kills credit the last opponent to hit you; others who hit you in the last
ASSIST_WINDOW seconds get assists.

  CombatService:Spawned(player)            fresh health, protection, the bow you picked
  CombatService:Alive(player)
  CombatService:SetEnabled(on)             the fight phase
  CombatService:Damage(victim, amount, attacker, info)
  CombatService:Kill(victim, attacker, info)
  CombatService.Killed(victim, killer, info)   info: { weapon, head, assists = { players }, kind }
  CombatService.StructureHit(id, damage, attacker)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Weapons = require(ReplicatedStorage.Shared.Data.Weapons)

local CombatService = {
	Name = "CombatService",
	Dependencies = { "PlayerDataService", "TeamService", "ArenaService" },
	Killed = Signal.new("CombatService.Killed"), -- (victim, killer?, info)
	Damaged = Signal.new("CombatService.Damaged"), -- (victim, amount, attacker?, info)
	Shot = Signal.new("CombatService.Shot"), -- (player, weapon)
	StructureHit = Signal.new("CombatService.StructureHit"), -- (id, damage, attacker)
}

local data, teams, arena
local states = {} -- [player] = { hp, alive, weapon, drawAt, ammo, reloadAt, readyAt, protectUntil, hits = { [attacker] = t } }
local arrows = {} -- { id, by, team, weapon, origin, velocity, t, damage, knockback, head }
local nextArrow = 0
local enabled = false

local function now()
	return workspace:GetServerTimeNow()
end

local function state(player)
	local s = states[player]
	if not s then
		s = { hp = Constants.MAX_HEALTH, alive = false, weapon = Weapons.DEFAULT, ammo = nil, readyAt = 0, hits = {} }
		states[player] = s
	end
	return s
end

local function root(player)
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function mirror(player, s)
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.MaxHealth = Constants.MAX_HEALTH
		hum.Health = math.max(s.alive and 1 or 0, s.hp)
	end
end

function CombatService:Push(player)
	local s = state(player)
	local w = Weapons.get(s.weapon)
	Net.fire(player, "Me", {
		team = teams:Team(player),
		alive = s.alive,
		hp = s.hp,
		weapon = s.weapon,
		ammo = s.ammo,
		mag = w and w.mag,
		protected = (s.protectUntil or 0) > now(),
	})
end

function CombatService:Spawned(player)
	local s = state(player)
	s.hp = Constants.MAX_HEALTH
	s.alive = true
	s.drawAt = nil
	s.hits = {}
	s.protectUntil = now() + Constants.SPAWN_PROTECT
	local profile = data:Get(player)
	local pick = profile and profile.settings.weapon
	s.weapon = Weapons.get(pick) and pick or s.weapon or Weapons.DEFAULT
	local w = Weapons.get(s.weapon)
	s.ammo = w.mag
	s.reloadAt = nil
	s.readyAt = 0
	mirror(player, s)
	self:Push(player)
end

function CombatService:Alive(player)
	local s = states[player]
	return s ~= nil and s.alive
end

function CombatService:Health(player)
	return state(player).hp
end

function CombatService:Weapon(player)
	return state(player).weapon
end

function CombatService:SetEnabled(on)
	enabled = on
	if not on then
		for _, s in states do
			s.drawAt = nil
		end
	end
end

function CombatService:Enabled()
	return enabled
end

function CombatService:Kill(victim, attacker, info)
	local s = state(victim)
	if not s.alive then
		return false
	end
	s.alive = false
	s.hp = 0
	s.drawAt = nil
	info = info or {}
	-- assists: other opponents who hit you within the window
	local assists = {}
	local t = now()
	for p, at in s.hits do
		if p ~= attacker and p.Parent and t - at <= Constants.ASSIST_WINDOW then
			table.insert(assists, p)
		end
	end
	info.assists = assists
	mirror(victim, s)
	self:Push(victim)
	self.Killed:Fire(victim, attacker, info)
	return true
end

function CombatService:Damage(victim, amount, attacker, info)
	local s = state(victim)
	if not s.alive or amount <= 0 then
		return false
	end
	if (s.protectUntil or 0) > now() then
		return false
	end
	if attacker then
		if teams:Team(attacker) == teams:Team(victim) then
			return false -- (no friendly fire)
		end
		s.hits[attacker] = now()
	end
	s.hp = math.max(0, s.hp - amount)
	mirror(victim, s)
	self.Damaged:Fire(victim, amount, attacker, info or {})
	if s.hp <= 0 then
		self:Kill(victim, attacker, info)
		return true, true
	end
	return true, false
end

-- Arrows --------------------------------------------------------------------------------------------------------
local function hitPlayers(arrow, a, b)
	local best, bestT, bestHead
	for player, s in states do
		if s.alive and player ~= arrow.by and player.Parent and teams:Team(player) ~= arrow.team then
			local r = root(player)
			if r then
				local p = r.Position
				local head = Formulas.segmentSphere(a, b, p + Vector3.new(0, 2.6, 0), Constants.HIT_RADIUS_HEAD)
				local body = Formulas.segmentSphere(a, b, p + Vector3.new(0, 0.2, 0), Constants.HIT_RADIUS_BODY)
				local t, isHead = nil, false
				if head and (not body or head <= body + 0.02) then
					t, isHead = head, true
				elseif body then
					t = body
				end
				if t and (not bestT or t < bestT) then
					best, bestT, bestHead = player, t, isHead
				end
			end
		end
	end
	return best, bestT, bestHead
end

local function hitSolids(a, b)
	local bestT, bestId
	local mn = Vector3.new(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
	local mx = Vector3.new(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
	for _, s in arena:Solids() do
		-- (a cheap reject: the step's own box)
		if
			s.max.X >= mn.X
			and s.min.X <= mx.X
			and s.max.Y >= mn.Y
			and s.min.Y <= mx.Y
			and s.max.Z >= mn.Z
			and s.min.Z <= mx.Z
		then
			local t = Formulas.segmentBox(a, b, s.min, s.max)
			if t and (not bestT or t < bestT) then
				bestT, bestId = t, s.id
			end
		end
	end
	return bestT, bestId
end

function CombatService:_finish(arrow, pos, kind)
	arrow.done = true
	Net.fireAll("ArrowEnd", { id = arrow.id, pos = pos, kind = kind })
end

function CombatService:_step(dt)
	for i = #arrows, 1, -1 do
		local arrow = arrows[i]
		local t0 = arrow.t
		local t1 = t0 + dt
		local a = Formulas.arrowAt(arrow.origin, arrow.velocity, t0)
		local b = Formulas.arrowAt(arrow.origin, arrow.velocity, t1)
		arrow.t = t1
		local victim, vt, head = hitPlayers(arrow, a, b)
		local st, sid = hitSolids(a, b)
		if victim and (not st or vt <= st) then
			local at = a:Lerp(b, vt)
			self:_hitPlayer(arrow, victim, head, at, (b - a).Unit)
			table.remove(arrows, i)
		elseif st then
			local at = a:Lerp(b, st)
			if sid then
				local w = Weapons.get(arrow.weapon)
				self.StructureHit:Fire(sid, arrow.damage * (w and w.structure or 1), arrow.by)
			end
			self:_finish(arrow, at, sid and "structure" or "world")
			table.remove(arrows, i)
		elseif t1 >= Constants.ARROW_LIFETIME or not arena:Inside(b) then
			self:_finish(arrow, b, "world")
			table.remove(arrows, i)
		end
	end
end

function CombatService:_hitPlayer(arrow, victim, head, at, dir)
	local amount = math.floor(arrow.damage * (head and Constants.HEADSHOT or 1) + 0.5)
	local shooter = arrow.by
	local info = { weapon = arrow.weapon, head = head, kind = "arrow" }
	local ok, killed = self:Damage(victim, amount, shooter.Parent and shooter or nil, info)
	self:_finish(arrow, at, "player")
	if not ok then
		return
	end
	-- knockback: along the arrow, flattened, a little up; capped. The victim's client applies it (it owns its body)
	local flat = Vector3.new(dir.X, 0, dir.Z)
	flat = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(1, 0, 0)
	local kb = flat * math.min(arrow.knockback, Constants.KNOCKBACK_CAP) + Vector3.new(0, arrow.knockback * 0.25, 0)
	local r = root(victim)
	if r and not killed then
		pcall(function()
			r.AssemblyLinearVelocity += kb
		end)
	end
	Net.fire(victim, "Hurt", { amount = amount, from = arrow.origin, knock = kb, head = head })
	if shooter.Parent then
		Net.fire(shooter, "Hit", { damage = amount, head = head, kill = killed, victim = victim.UserId })
	end
end

-- The shot itself (Net "Shoot"): validated, then an arrow.
function CombatService:Shoot(player, origin, direction, shotId)
	if not enabled or typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
		return nil
	end
	local s = state(player)
	if not s.alive then
		return nil
	end
	local w = Weapons.get(s.weapon)
	local t = now()
	if t < (s.readyAt or 0) then
		return nil
	end
	if w.mag then
		if s.reloadAt and t < s.reloadAt then
			return nil
		end
		if s.reloadAt and t >= s.reloadAt then
			s.reloadAt, s.ammo = nil, w.mag
		end
		if (s.ammo or 0) <= 0 then
			return nil
		end
	end
	local r = root(player)
	if not r then
		return nil
	end
	local head = r.Position + Vector3.new(0, 1.5, 0)
	if (origin - head).Magnitude > Constants.ORIGIN_SLACK then
		origin = head -- (too far from you: it starts from your head instead)
	end
	if direction.Magnitude < 0.5 or direction.Magnitude > 1.5 then
		return nil
	end
	direction = direction.Unit
	local charge = w.draw > 0 and Formulas.charge(w, s.drawAt and (t - s.drawAt) or 0) or 1
	local shot = Formulas.shot(w, charge)
	s.drawAt = nil
	s.readyAt = t + w.cooldown
	if w.mag then
		s.ammo -= 1
		if s.ammo <= 0 then
			s.reloadAt = t + w.reload
		end
	end
	nextArrow += 1
	local arrow = {
		id = nextArrow,
		by = player,
		team = teams:Team(player),
		weapon = w.key,
		origin = origin,
		velocity = direction * shot.speed,
		t = 0,
		damage = shot.damage,
		knockback = shot.knockback,
		charge = charge,
		shotId = shotId,
	}
	table.insert(arrows, arrow)
	Net.fireAll("Arrow", {
		id = arrow.id,
		by = player.UserId,
		team = arrow.team,
		weapon = w.key,
		origin = origin,
		velocity = arrow.velocity,
		at = t,
		shotId = shotId,
	})
	self.Shot:Fire(player, w.key)
	if w.mag then
		self:Push(player)
	end
	return arrow
end

function CombatService:Equip(player, key)
	local w = Weapons.get(key)
	if not w then
		return false
	end
	local s = state(player)
	s.weapon = key
	s.ammo = w.mag
	s.reloadAt = nil
	s.drawAt = nil
	local profile = data:Get(player)
	if profile then
		profile.settings.weapon = key
	end
	self:Push(player)
	return true
end

function CombatService:Arrows()
	return arrows
end

function CombatService:Init(registry)
	data = registry.PlayerDataService
	teams = registry.TeamService
	arena = registry.ArenaService
	Net.on("Equip", function(player, key)
		if type(key) == "string" then
			self:Equip(player, key)
		end
	end)
	Net.on("Draw", function(player, on)
		local s = state(player)
		if on == true and s.alive and enabled then
			s.drawAt = now()
		elseif on == false then
			s.drawAt = nil
		end
	end)
	Net.on("Shoot", function(player, origin, direction, shotId)
		self:Shoot(player, origin, direction, shotId)
	end)
	Net.on("Reload", function(player)
		local s = state(player)
		local w = Weapons.get(s.weapon)
		if w.mag and (s.ammo or 0) < w.mag and not s.reloadAt then
			s.reloadAt = now() + w.reload
			s.ammo = 0
			self:Push(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
		for _, s in states do
			s.hits[player] = nil
		end
	end)
end

function CombatService:Start()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		while acc >= Constants.ARROW_STEP do
			acc -= Constants.ARROW_STEP
			self:_step(Constants.ARROW_STEP)
		end
		-- (finished reloads refill the magazine)
		local t = now()
		for player, s in states do
			if s.reloadAt and t >= s.reloadAt then
				local w = Weapons.get(s.weapon)
				s.reloadAt, s.ammo = nil, w.mag
				if player.Parent then
					self:Push(player)
				end
			end
		end
	end)
end

return CombatService
