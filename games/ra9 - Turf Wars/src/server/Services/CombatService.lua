--[[
Combat (master plan §5): health, the three bows and the blade, server arrows, slashes, hits, knockback, kills and
credit.

The blade: the client sends Swing(direction) as you click; the server checks the cadence and finds the nearest enemy
in reach (Weapons blade.range from you, inside blade.arc degrees of where you look, nothing solid between), and hits
it (more from behind). Everyone is told (Swing) so they see the slash.

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
  CombatService:Remove(player)             out of the fight, no kill (a spectating admin)
  CombatService:Heal(player)               full health
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
	Rejected = Signal.new("CombatService.Rejected"), -- (player, reason) a shot the server refused (the anti-cheat counts)
	Parried = Signal.new("CombatService.Parried"), -- (swinger, shooter) a blade knocked an arrow back
}

local data, teams, arena
local states = {} -- [player] = { hp, alive, weapon, drawAt, ammo, reloadAt, readyAt, protectUntil, hits = { [attacker] = t } }
local arrows = {} -- { id, by, team, weapon, origin, velocity, t, damage, knockback, head }
local nextArrow = 0
local enabled = false

local function now()
	return workspace:GetServerTimeNow()
end

-- The trail the shooter wears (drawn by every client; cosmetic only).
local function trailOf(player)
	local profile = data and data:Get(player)
	return profile and profile.equipped and profile.equipped.trail or nil
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

-- The bow in your hand that everyone else sees (your own client hides it: you see the viewmodel). Welded to the
-- left hand, massless, out of every query (the hit spheres are the server's, not these parts).
function CombatService:HoldBow(player, key)
	local c = player.Character
	local hand = c and (c:FindFirstChild("LeftHand") or c:FindFirstChild("Left Arm"))
	if not hand then
		return nil
	end
	local old = c:FindFirstChild("HeldBow")
	if old then
		old:Destroy()
	end
	local team = teams:Team(player)
	local color = Constants.TEAM_COLOR[team or ""] or Constants.WHITE
	local model = Instance.new("Model")
	model.Name = "HeldBow"
	model:SetAttribute("Weapon", key)
	local function part(name, size, c3, offset)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = c3
		p.Material = Enum.Material.SmoothPlastic
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CastShadow = false
		p.CFrame = hand.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hand
		weld.Part1 = p
		weld.Parent = p
		p.Parent = model
		return p
	end
	local big = key == "heavy"
	if key == "blade" then
		-- held in the right hand for everyone else: a grip, a guard, the blade
		local right = c:FindFirstChild("RightHand") or c:FindFirstChild("Right Arm")
		if right then
			hand = right
		end
		part("Grip", Vector3.new(0.25, 0.25, 0.7), color, CFrame.new(0, -0.3, 0))
		part("Guard", Vector3.new(0.9, 0.2, 0.2), Color3.fromRGB(118, 122, 132), CFrame.new(0, -0.3, -0.45))
		part("Edge", Vector3.new(0.12, 0.3, 2.4), Color3.fromRGB(214, 218, 225), CFrame.new(0, -0.3, -1.75))
		part("Bevel", Vector3.new(0.13, 0.06, 2.3), Color3.fromRGB(250, 251, 253), CFrame.new(0, -0.43, -1.75))
	elseif key == "crossbow" then
		part("Stock", Vector3.new(0.25, 0.25, 1.8), Constants.WHITE, CFrame.new(0, -0.2, -0.6))
		part("Limbs", Vector3.new(2.2, 0.15, 0.2), color, CFrame.new(0, -0.2, -1.4))
	else
		local len = big and 2 or 1.6
		part("Grip", Vector3.new(0.25, 0.6, 0.25), color, CFrame.new(0, -0.3, 0))
		part(
			"Upper",
			Vector3.new(0.15, len, 0.15),
			Constants.WHITE,
			CFrame.new(0, -0.3 + len / 2 + 0.25, -0.2) * CFrame.Angles(math.rad(-15), 0, 0)
		)
		part(
			"Lower",
			Vector3.new(0.15, len, 0.15),
			Constants.WHITE,
			CFrame.new(0, -0.3 - len / 2 - 0.25, -0.2) * CFrame.Angles(math.rad(15), 0, 0)
		)
		part("String", Vector3.new(0.04, len * 2 + 0.4, 0.04), Color3.fromRGB(30, 30, 34), CFrame.new(0, -0.3, 0.25))
	end
	model.Parent = c
	return model
end

function CombatService:Spawned(player)
	local s = state(player)
	s.hp = Constants.MAX_HEALTH
	s.alive = true
	s.drawAt = nil
	s.hits = {}
	s.protectUntil = now() + Constants.SPAWN_PROTECT
	s.attacked = false
	local profile = data:Get(player)
	local pick = profile and profile.settings.weapon
	s.weapon = Weapons.get(pick) and pick or s.weapon or Weapons.DEFAULT
	if not CombatService.allowed(s.weapon) then
		s.weapon = Weapons.DEFAULT -- (the blade only comes out in the CHARGE)
	end
	local w = Weapons.get(s.weapon)
	s.ammo = w.mag
	s.reloadAt = nil
	s.readyAt = 0
	mirror(player, s)
	self:HoldBow(player, s.weapon)
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

-- Out of the fight without going down (no kill, no feed): a spectating admin. Nothing can hit them.
function CombatService:Remove(player)
	local s = state(player)
	s.alive = false
	s.hp = 0
	s.drawAt = nil
	s.hits = {}
	for _, o in states do
		o.hits[player] = nil
	end
	self:Push(player)
end

-- Back to full health (an admin's heal).
function CombatService:Heal(player)
	local s = state(player)
	if not s.alive then
		return false
	end
	s.hp = Constants.MAX_HEALTH
	mirror(player, s)
	self:Push(player)
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
	-- safe on your own spawn deck until you shoot or swing (it's open, so walls don't do it)
	if attacker and not s.attacked and arena and arena:OnDeck(victim, teams:Team(victim)) then
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
			table.remove(arrows, i)
			if not self:_parry(arrow, victim, at, (b - a).Unit) then
				self:_hitPlayer(arrow, victim, head, at, (b - a).Unit)
			end
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

-- A blade swing in the last PARRY_SECONDS, facing the arrow: it's knocked away and flies back at whoever shot it
-- (now the swinger's arrow). true when parried.
function CombatService:_parry(arrow, victim, at, dir)
	local s = states[victim]
	if not s or (s.parryUntil or 0) < now() or not s.parryDir then
		return false
	end
	if s.parryDir:Dot(-Vector3.new(dir.X, 0, dir.Z).Unit) < Constants.PARRY_DOT then
		return false -- (from the side or behind: the blade wasn't in the way)
	end
	self:_finish(arrow, at, "parry")
	local speed = arrow.velocity.Magnitude
	local back = -dir
	local shooter = arrow.by
	local sr = shooter and shooter.Parent and root(shooter)
	if sr then
		local to = (sr.Position + Vector3.new(0, 1.5, 0)) - at
		if to.Magnitude > 1 then
			back = to.Unit
		end
	end
	local origin = at + back * 1.5
	nextArrow += 1
	local again = {
		id = nextArrow,
		by = victim,
		team = teams:Team(victim),
		weapon = arrow.weapon,
		origin = origin,
		velocity = back * speed,
		t = 0,
		damage = arrow.damage,
		knockback = arrow.knockback,
		charge = arrow.charge,
	}
	table.insert(arrows, again)
	Net.fireAll("Arrow", {
		id = again.id,
		by = victim.UserId,
		team = again.team,
		weapon = again.weapon,
		origin = origin,
		velocity = again.velocity,
		at = now(),
		trail = trailOf(victim),
		parried = true,
	})
	Net.fire(victim, "Hit", { damage = 0, parry = true, pos = at })
	self.Parried:Fire(victim, shooter)
	return true
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
	victim:SetAttribute("AcGrace", os.clock() + 1.5) -- (the knockback is ours: the anti-cheat lets it go)
	Net.fire(victim, "Hurt", { amount = amount, from = arrow.origin, knock = kb, head = head })
	if shooter.Parent then
		Net.fire(shooter, "Hit", { damage = amount, head = head, kill = killed, victim = victim.UserId })
	end
end

-- Start or stop drawing (Net "Draw"; bots call it directly). The charge is timed from here.
function CombatService:Draw(player, on)
	local s = state(player)
	if on == true and s.alive and enabled then
		s.drawAt = now()
	elseif on == false then
		s.drawAt = nil
	end
end

-- Is the straight line from a to b blocked by the map or a structure? (bots check their line of fire with it)
function CombatService:Blocked(a, b)
	return (hitSolids(a, b)) ~= nil
end

-- The shot itself (Net "Shoot"): validated, then an arrow.
function CombatService:Shoot(player, origin, direction, shotId)
	if not enabled or typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
		return nil
	end
	local s = state(player)
	if not s.alive then
		self.Rejected:Fire(player, "dead")
		return nil
	end
	local w = Weapons.get(s.weapon)
	if w.melee then
		return nil -- (the blade swings through Swing, never shoots)
	end
	if direction ~= direction or origin ~= origin then
		return nil -- (NaN)
	end
	if shotId ~= nil and (type(shotId) ~= "number" or shotId ~= shotId or math.abs(shotId) > 2 ^ 31) then
		shotId = nil -- (only a plain number goes back out to everyone)
	end
	local t = now()
	if t < (s.readyAt or 0) - 0.08 then
		self.Rejected:Fire(player, "rate") -- (faster than the bow can shoot, beyond a little lag)
		return nil
	elseif t < (s.readyAt or 0) then
		return nil
	end
	if w.mag then
		if s.reloadAt and t < s.reloadAt then
			self.Rejected:Fire(player, "reload")
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
		self.Rejected:Fire(player, "origin")
	elseif (origin - head).Magnitude > 0.5 and hitSolids(head, origin) then
		origin = head -- (never from the far side of a wall)
	end
	if direction.Magnitude < 0.5 or direction.Magnitude > 1.5 then
		return nil
	end
	direction = direction.Unit
	s.attacked = true -- (shooting gives up the spawn deck's safety)
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
		trail = trailOf(player),
	})
	self.Shot:Fire(player, w.key)
	if w.mag then
		self:Push(player)
	end
	return arrow
end

-- The blade is only out in the CHARGE (the fight's last seconds, MatchService sets workspace "Charge"): bows only
-- the rest of the time
function CombatService.allowed(key)
	local w = Weapons.get(key)
	return w ~= nil and (not w.melee or workspace:GetAttribute("Charge") == true)
end

-- A slash (Net "Swing"; bots call it too): the nearest enemy in reach and in front, nothing solid between.
function CombatService:Swing(player, direction)
	if not enabled or typeof(direction) ~= "Vector3" or direction.Magnitude < 0.5 or direction.Magnitude > 1.5 then
		return nil
	end
	local s = state(player)
	local w = Weapons.get(s.weapon)
	if not s.alive or not w or not w.melee or not CombatService.allowed(s.weapon) then
		return nil
	end
	local t = now()
	if t < (s.readyAt or 0) - 0.08 then
		self.Rejected:Fire(player, "rate")
		return nil
	elseif t < (s.readyAt or 0) then
		return nil
	end
	s.readyAt = t + w.cooldown
	s.attacked = true
	local r = root(player)
	if not r then
		return nil
	end
	local look = Vector3.new(direction.X, 0, direction.Z)
	look = look.Magnitude > 0.01 and look.Unit or r.CFrame.LookVector
	-- the swing knocks back arrows from the front for a moment (see _parry)
	s.parryUntil, s.parryDir = t + Constants.PARRY_SECONDS, look
	local eye = r.Position + Vector3.new(0, 1.5, 0)
	local mine = teams:Team(player)
	local best, bestD
	for other, os_ in states do
		local orr = os_.alive and other ~= player and other.Parent and teams:Team(other) ~= mine and root(other)
		if orr then
			local to = orr.Position - r.Position
			local flat = Vector3.new(to.X, 0, to.Z)
			local d = flat.Magnitude
			local inArc = d < 1.5 or math.deg(math.acos(math.clamp(flat.Unit:Dot(look), -1, 1))) <= w.arc
			if d <= w.range and math.abs(to.Y) < 5 and inArc and (not bestD or d < bestD) then
				if not self:Blocked(eye, orr.Position + Vector3.new(0, 1, 0)) then
					best, bestD = other, d
				end
			end
		end
	end
	Net.fireAll("Swing", { by = player.UserId, hit = best ~= nil, pos = r.Position, dir = look })
	self.Shot:Fire(player, w.key)
	if not best then
		return nil
	end
	local vr = root(best)
	-- from behind: the victim faces away from you
	local away = (vr.Position - r.Position)
	away = Vector3.new(away.X, 0, away.Z)
	local back = away.Magnitude > 0.01 and vr.CFrame.LookVector:Dot(away.Unit) > 0.5
	local amount = math.floor(w.damage[1] * (back and w.backstab or 1) + 0.5)
	local info = { weapon = w.key, head = false, kind = "melee", back = back }
	local ok, killed = self:Damage(best, amount, player, info)
	if not ok then
		return best, false
	end
	local kb = look * math.min(w.knockback, Constants.KNOCKBACK_CAP) + Vector3.new(0, w.knockback * 0.3, 0)
	if not killed then
		pcall(function()
			vr.AssemblyLinearVelocity += kb
		end)
	end
	best:SetAttribute("AcGrace", os.clock() + 1.5)
	Net.fire(best, "Hurt", { amount = amount, from = r.Position, knock = kb, head = false })
	Net.fire(
		player,
		"Hit",
		{ damage = amount, head = back, kill = killed, victim = best.UserId, melee = true, pos = vr.Position }
	)
	return best, killed
end

function CombatService:Equip(player, key)
	local w = Weapons.get(key)
	if not w or not CombatService.allowed(key) then
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
	self:HoldBow(player, key)
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
		self:Draw(player, on)
	end)
	Net.on("Shoot", function(player, origin, direction, shotId)
		self:Shoot(player, origin, direction, shotId)
	end)
	Net.on("Swing", function(player, direction)
		self:Swing(player, direction)
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
	-- the CHARGE is over: blades away, bows back out
	workspace:GetAttributeChangedSignal("Charge"):Connect(function()
		if workspace:GetAttribute("Charge") == true then
			return
		end
		for who, st in states do
			local sw = Weapons.get(st.weapon)
			if sw and sw.melee and who.Parent then
				self:Equip(who, Weapons.DEFAULT)
			end
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
