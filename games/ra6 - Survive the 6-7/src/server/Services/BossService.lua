--[[
Mega Kermy, the final boss (master plan §10: bosses introduce new mechanics, not just a bigger health bar; the
final boss is the culmination of the run's skills). He comes for the camp on night 7.

  phase 1 (100-66%)  CHARGE: he paws the ground, a red line shows where he'll go, then he charges straight along
                     it. Bait him into an Ancient Pine (stand in front of one, dodge at the last moment): he gets
                     stuck and DIZZY, the 67 on his back glows, and he takes 2.5x damage. Each pine takes two
                     charges. Camp walls in his way break and stagger him. Up close he STOMPS (a ring).
  phase 2 (66-33%)   + the SIX-SEVEN SLAM: he jumps, a shadow shows where he'll land, and shockwave rings roll out:
                     jump over them. Each slam calls Snapcaps and Pelters from the trees.
  phase 3 (< 33%)    + the GOO GRAB: he reaches for someone (a line shows the reach) and sticks them in a goo
                     cocoon on a tree. Teammates hit the cocoon to break them out; alone, mash to escape.
  always             after a few attacks he sits down, panting (TIRED): free hits. At 5 minutes he enrages.

He's drawn through the monster snapshot (MonsterService:SetExternal); his health bar goes out as "Boss".
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService_ = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Enemies = require(ReplicatedStorage.Shared.Data.Enemies)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Kit = require(ReplicatedStorage.Shared.World.Kit)
local MapLayout = require(ReplicatedStorage.Shared.World.MapLayout)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local BossService = {
	Name = "BossService",
	Dependencies = {
		"PlayerDataService",
		"RunService",
		"SurvivorService",
		"InventoryService",
		"CampService",
		"MonsterService",
	},
	Started = Signal.new("BossService.Started"), -- (boss)
	PhaseChanged = Signal.new("BossService.PhaseChanged"), -- (phase)
	PineStun = Signal.new("BossService.PineStun"), -- (player?, pineId) the baiter, if any
	Grabbed = Signal.new("BossService.Grabbed"), -- (player)
	Freed = Signal.new("BossService.Freed"), -- (victim, by?)
	Defeated = Signal.new("BossService.Defeated"), -- (boss, killer?, assists)
	Hurt = Signal.new("BossService.Hurt"), -- (amount, byPlayer?)
}

local data, runs, survivors, inventory, camp, monsters
local boss -- the fight's state (nil when there is none)
local cocoons = {} -- [id] = { id, player, pos, hp, model }
local nextCocoon = 1
local pineHits = {} -- [pineId] = hits taken
local BOSS_ID = 65500
local RADIUS = 6
local ARENA = 92

local function now()
	return workspace:GetServerTimeNow()
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function yawDir(yaw)
	return Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
end

local function event(t)
	t.id = BOSS_ID
	Net.fireAll("Mob", t)
end

function BossService:Get()
	return boss
end

function BossService:Active()
	return boss ~= nil and boss.hp > 0
end

function BossService:View()
	if not boss then
		return false
	end
	return {
		name = "MEGA KERMY",
		hp = math.max(0, math.ceil(boss.hp)),
		maxHp = boss.maxHp,
		phase = boss.phase,
		state = boss.state,
		enraged = boss.enraged,
		weak = boss.state == "faceplant" or boss.state == "tired",
	}
end

function BossService:_push()
	Net.fireAll("Boss", self:View())
end

local function setState(state, seconds)
	boss.state = state
	boss.stateUntil = now() + (seconds or 0)
end

-- Ancient Pines -----------------------------------------------------------------------------------------------------------------
local function mapBuilder()
	local ok, mb = pcall(function()
		return require(script.Parent.Parent.World.MapBuilder)
	end)
	return ok and mb or nil
end

function BossService:_pines()
	local out = {}
	for _, p in MapLayout.ancientPines do
		if (pineHits[p.id] or 0) < Constants.ANCIENT_PINE_HITS then
			table.insert(out, p)
		end
	end
	return out
end

function BossService:_breakPine(p)
	local mb = mapBuilder()
	local entry = mb and mb.camp and mb.camp.pines[p.id]
	if entry and entry.model then
		for _, d in entry.model:GetDescendants() do
			if d:IsA("BasePart") and d.Name ~= "Trunk" and d.Name ~= "Root" and d.Name ~= "Moss" then
				d.Transparency = 1
				d.CanCollide = false
			elseif d:IsA("BasePart") and d.Name == "Trunk" then
				d.Size = Vector3.new(4, d.Size.Y, d.Size.Z)
				d.CFrame = CFrame.new(p.pos + Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
			end
		end
	end
	Net.fireAll("Fx", "crumble", { pos = p.pos + Vector3.new(0, 6, 0) })
	Net.fireAll("Callout", "🌲 An Ancient Pine came crashing down!", "bad")
end

function BossService:_resetPines()
	table.clear(pineHits)
	local mb = mapBuilder()
	if not (mb and mb.camp) then
		return
	end
	for _, p in MapLayout.ancientPines do
		local entry = mb.camp.pines[p.id]
		if entry and entry.model then
			local parent = entry.model.Parent
			entry.model:Destroy()
			local m, rune = Kit.ancientPine(parent, p.pos, p.id * 17)
			m.Name = "AncientPine" .. p.id
			m:SetAttribute("PineId", p.id)
			mb.camp.pines[p.id] = { model = m, rune = rune }
		end
	end
end

-- The fight -------------------------------------------------------------------------------------------------------------------------
function BossService:Begin()
	local hp = Formulas.bossHp(runs:StagePlayers(), runs:Difficulty(), camp:TotemBuilt())
	local start = MapLayout.polar(270, ARENA - 4)
	boss = {
		id = BOSS_ID,
		kind = "mega_kermy",
		def = Enemies.get("mega_kermy"),
		beh = { radius = RADIUS },
		pos = Vector3.new(start.X, MapLayout.groundY(start.X, start.Z), start.Z),
		yaw = 0,
		hp = hp,
		maxHp = hp,
		phase = 1,
		state = "show",
		stateUntil = now() + 4,
		nextAttack = now() + 6,
		attacks = 0,
		moving = false,
		actCount = 0,
		hitAt = -99,
		stunUntil = 0,
		startedAt = now(),
		dmgBy = {},
		pineStuns = {},
		speed = Enemies.get("mega_kermy").speed,
		dmg = Formulas.monsterDamage(Enemies.get("mega_kermy").dmg, runs:Difficulty()),
	}
	boss.yaw = math.atan2(boss.pos.X, boss.pos.Z)
	monsters:SetExternal(BOSS_ID, boss)
	event({ kind = "spawn", monster = "mega_kermy" })
	event({ kind = "say", text = "SIIIX... SEEEVEN!!!" })
	Net.fireAll("Sfx", "roar")
	if camp:TotemBuilt() then
		Net.fireAll("Callout", "🗿 The Totem weakens him! The Ancient Pines glow: bait his charge into them!", "good")
	else
		Net.fireAll("Callout", "👹 MEGA KERMY! Bait his charge into an Ancient Pine!", "bad")
	end
	self:_push()
	self.Started:Fire(boss)
end

function BossService:End()
	if boss then
		monsters:SetExternal(BOSS_ID, nil)
		event({ kind = "die" })
	end
	boss = nil
	for id, c in cocoons do
		self:_release(c, nil, true)
		cocoons[id] = nil
	end
	Net.fireAll("Boss", false)
end

-- Damage to Mega Kermy (CombatService). opts.item: the weapon (its bossBonus).
function BossService:Damage(amount, byPlayer, opts)
	if not boss or boss.hp <= 0 or boss.state == "show" then
		return 0
	end
	opts = opts or {}
	local mult = 1
	if boss.state == "faceplant" then
		mult = Constants.BOSS_WEAK_MULT
	elseif boss.state == "tired" then
		mult = Constants.BOSS_TIRED_MULT
	end
	if opts.item and opts.item.bossBonus then
		mult *= opts.item.bossBonus
	end
	amount = math.max(1, math.floor(amount * mult + 0.5))
	boss.hp -= amount
	boss.hitAt = now()
	if byPlayer then
		boss.dmgBy[byPlayer] = (boss.dmgBy[byPlayer] or 0) + amount
	end
	event({ kind = "hit", amount = amount, crit = mult > 1.5, by = byPlayer and byPlayer.UserId })
	self.Hurt:Fire(amount, byPlayer)
	-- phases
	local frac = boss.hp / boss.maxHp
	local phase = frac <= 0.33 and 3 or frac <= 0.66 and 2 or 1
	if phase > boss.phase then
		boss.phase = phase
		event({ kind = "say", text = phase == 2 and "NOW I'M MAD!" or "SIX... SEVEN... SIX... SEVEN!!" })
		Net.fireAll(
			"Alert",
			phase == 2 and "MEGA KERMY IS ANGRY!" or "MEGA KERMY IS FURIOUS!",
			Color3.fromRGB(255, 120, 90),
			3
		)
		Net.fireAll("Sfx", "roar")
		self.PhaseChanged:Fire(phase)
	end
	if boss.hp <= 0 then
		self:_defeat(byPlayer)
	end
	self:_push()
	return amount
end

function BossService:_defeat(killer)
	local assists = {}
	for p, d in boss.dmgBy do
		if p.Parent then
			assists[p] = d
		end
	end
	setState("ko", 99)
	boss.hp = 0
	event({ kind = "ko", by = killer and killer.UserId })
	event({ kind = "say", text = "...six... seven... zzz" })
	Net.fireAll("Alert", "MEGA KERMY IS DOWN!", Color3.fromRGB(255, 214, 80), 4)
	for id, c in cocoons do
		self:_release(c, nil, true)
		cocoons[id] = nil
	end
	-- a shower of loot round him
	local drops = {}
	local pool = { "golden_apple", "medkit", "kermy_jersey", "old_timber", "slammer_67", "moonshot", "ranger_coat" }
	for _ = 1, 3 + #runs:Active() do
		table.insert(drops, { key = pool[math.random(1, #pool)], n = 1 })
	end
	inventory:SpawnDrop(boss.pos, drops)
	self.Defeated:Fire(boss, killer, assists)
	self:_push()
	task.delay(2.5, function()
		runs:Win()
	end)
end

-- Attacks ------------------------------------------------------------------------------------------------------------------------------
local function targetsList()
	return survivors:Targets()
end

function BossService:_pickTarget()
	local list = targetsList()
	if #list == 0 then
		return nil
	end
	-- mostly the nearest, sometimes someone else (everyone gets a turn at baiting)
	table.sort(list, function(a, b)
		return (a.pos - boss.pos).Magnitude < (b.pos - boss.pos).Magnitude
	end)
	if #list > 1 and math.random() < 0.35 then
		return list[math.random(2, #list)]
	end
	return list[1]
end

local function face(pos)
	local d = flat(pos - boss.pos)
	if d.Magnitude > 0.01 then
		boss.yaw = math.atan2(-d.X, -d.Z)
	end
end

function BossService:_tell(kind, seconds, extra)
	boss.state = "tell"
	boss.tellKind = kind
	boss.stateUntil = now() + seconds
	boss.actCount += 1
	local e = { kind = "tell", tell = kind, seconds = seconds }
	for k, v in extra or {} do
		e[k] = v
	end
	event(e)
end

function BossService:_cooldown()
	local cd = boss.phase == 3 and 2.2 or boss.phase == 2 and 2.8 or 3.4
	if boss.enraged then
		cd *= 0.7
	end
	return cd
end

-- An attack is over: count it, and after a few, a breather.
function BossService:_afterAttack(recover)
	boss.attacks += 1
	boss.nextAttack = now() + self:_cooldown()
	local tiredEvery = boss.phase == 3 and 3 or 4
	if boss.attacks % tiredEvery == 0 then
		setState("tired", 4)
		event({ kind = "say", text = "*huff* *puff*" })
	else
		setState("recover", recover or 0.8)
	end
end

-- Hit survivors in a circle (resolved with dodge forgiveness).
function BossService:_area(center, radius, dmg, knock, tip)
	for _, tg in targetsList() do
		if (flat(tg.pos) - flat(center)).Magnitude <= radius then
			local player = tg.player
			survivors:ResolveHit(player, "mega_kermy:" .. tip, function()
				local dir = flat(tg.pos - center)
				dir = dir.Magnitude > 0.01 and dir.Unit or yawDir(boss.yaw)
				survivors:Damage(player, dmg, { kind = "mega_kermy", dir = dir, knock = knock })
			end)
		end
	end
end

function BossService:_startCharge(tg)
	face(tg.pos)
	local dir = yawDir(boss.yaw)
	boss.chargeDir = dir
	boss.chargeFrom = boss.pos
	boss.chargeTarget = tg.player
	boss.chargeLen = 80
	local to = boss.pos + dir * boss.chargeLen
	local tell = Constants.BOSS_CHARGE_TELL * (boss.enraged and 0.8 or 1)
	self:_tell("charge", tell, { from = boss.pos, to = to, width = RADIUS * 1.4 })
	boss.next = "charge"
end

function BossService:_charge(dt)
	local speed = Constants.BOSS_CHARGE_SPEED * (boss.enraged and 1.15 or 1)
	local before = boss.pos
	local step = boss.chargeDir * speed * dt
	local nextPos = boss.pos + step
	-- an Ancient Pine in the way: stuck and dizzy (the weak spot is open)
	for _, p in self:_pines() do
		local rel = flat(p.pos - nextPos)
		if rel.Magnitude < p.radius + RADIUS then
			pineHits[p.id] = (pineHits[p.id] or 0) + 1
			setState("faceplant", Constants.BOSS_STUN)
			boss.stunUntil = boss.stateUntil
			event({ kind = "faceplant", tree = true, pine = p.id })
			event({ kind = "say", text = "@#%&!" })
			Net.fireAll("Callout", "💫 He's STUCK! Hit the glowing 67 on his back!", "good")
			Net.fireAll("Sfx", "thud", p.pos)
			local baiter = boss.chargeTarget
			if baiter and baiter.Parent then
				boss.pineStuns[baiter] = (boss.pineStuns[baiter] or 0) + 1
			end
			self.PineStun:Fire(baiter, p.id)
			if pineHits[p.id] >= Constants.ANCIENT_PINE_HITS then
				self:_breakPine(p)
			end
			boss.attacks += 1
			boss.nextAttack = now() + Constants.BOSS_STUN + self:_cooldown()
			return
		end
	end
	-- the camp's walls: he smashes through, staggered
	local R = MapLayout.CAMP.wallRadius
	local rb = flat(nextPos).Magnitude
	local ra = flat(boss.pos).Magnitude
	if (ra - R) * (rb - R) <= 0 then
		for _, s in camp:Barriers() do
			if (flat(s.slot.pos) - flat(nextPos)).Magnitude < RADIUS + 6 then
				camp:DamageStructure(s, 400)
				setState("stagger", 1.5)
				boss.stunUntil = boss.stateUntil
				event({ kind = "stagger" })
				self:_afterAttack(1.5)
				return
			end
		end
	end
	-- out of the arena, or off the walkable ground: skid to a stop
	if flat(nextPos).Magnitude > ARENA + 10 or not MapLayout.walkable(nextPos.X, nextPos.Z) then
		self:_afterAttack(1.4)
		return
	end
	boss.pos = Vector3.new(nextPos.X, MapLayout.groundY(nextPos.X, nextPos.Z), nextPos.Z)
	boss.moving = true
	-- trample anyone in the way
	for _, tg in targetsList() do
		local rel = flat(tg.pos - before)
		local along = rel:Dot(boss.chargeDir)
		local lateral = (rel - boss.chargeDir * along).Magnitude
		if
			along >= -2
			and along <= step.Magnitude + 4
			and lateral < RADIUS + 1.5
			and not (boss.trampled and boss.trampled[tg.player])
		then
			boss.trampled = boss.trampled or {}
			boss.trampled[tg.player] = true
			local player = tg.player
			survivors:ResolveHit(player, "mega_kermy:charge", function()
				survivors:Damage(player, boss.dmg, { kind = "mega_kermy", dir = boss.chargeDir, knock = 18 })
			end)
		end
	end
	if (flat(boss.pos) - flat(boss.chargeFrom)).Magnitude >= boss.chargeLen then
		self:_afterAttack(1.2)
	end
end

function BossService:_startJump(tg)
	face(tg.pos)
	boss.jumpFrom = boss.pos
	boss.jumpTo = Vector3.new(tg.pos.X, MapLayout.groundY(tg.pos.X, tg.pos.Z), tg.pos.Z)
	if flat(boss.jumpTo).Magnitude > ARENA then
		boss.jumpTo = flat(boss.jumpTo).Unit * (ARENA - 8)
		boss.jumpTo = Vector3.new(boss.jumpTo.X, MapLayout.groundY(boss.jumpTo.X, boss.jumpTo.Z), boss.jumpTo.Z)
	end
	self:_tell("jump", 0.6)
	boss.next = "jump"
end

function BossService:_land()
	local at = boss.jumpTo
	boss.pos = at
	self:_area(at, 14, boss.dmg * 0.9, 14, "slam")
	event({ kind = "slam", at = at, radius = 14, rings = 2, ringSpeed = 30, ringMax = 60 })
	Net.fireAll("Sfx", "thud", at)
	-- two shockwave rings: anyone on the ground when a ring passes is hit (jump over them!)
	for k = 0, 1 do
		local delay = k * 0.7
		local hit = {}
		local t0 = now() + delay
		task.spawn(function()
			while boss and now() - t0 < 2.2 do
				local radius = math.max(0, (now() - t0) * 30)
				if radius > 0 then
					for _, tg in targetsList() do
						local d = (flat(tg.pos) - flat(at)).Magnitude
						if not hit[tg.player] and math.abs(d - radius) < 2.2 and d > 14 then
							hit[tg.player] = true
							local airborne = tg.pos.Y - MapLayout.groundY(tg.pos.X, tg.pos.Z) > 4.6
							if airborne then
								monsters.Learned:Fire(tg.player, "mega_kermy", "slam")
							else
								survivors:Damage(
									tg.player,
									22,
									{ kind = "mega_kermy", dir = flat(tg.pos - at).Unit, knock = 6 }
								)
							end
						end
					end
				end
				task.wait(0.05)
			end
		end)
	end
	-- the slam calls the forest's little monsters
	for i = 1, 6 do
		local p = MapLayout.polar(math.random(0, 359), ARENA + 6)
		monsters:Spawn(i <= 4 and "snapcap" or "pelter", p, {})
	end
	self:_afterAttack(1.4)
end

function BossService:_startGrab(tg)
	face(tg.pos)
	local reach = 26
	boss.grabTarget = tg.player
	boss.grabTo = boss.pos + yawDir(boss.yaw) * reach
	self:_tell("grab", 1, { from = boss.pos, to = boss.grabTo, width = 4, target = tg.player.UserId })
	boss.next = "grab"
end

function BossService:_grab()
	local a, b = boss.pos, boss.grabTo
	local dir = flat(b - a).Unit
	local len = flat(b - a).Magnitude
	local victim
	for _, tg in targetsList() do
		local rel = flat(tg.pos - a)
		local along = math.clamp(rel:Dot(dir), 0, len)
		if (rel - dir * along).Magnitude < 4 then
			victim = tg.player
			break
		end
	end
	if victim then
		survivors:ResolveHit(victim, "mega_kermy:grab", function()
			self:_cocoon(victim)
		end)
	elseif boss.grabTarget and boss.grabTarget.Parent then
		monsters.Learned:Fire(boss.grabTarget, "mega_kermy", "grab")
	end
	self:_afterAttack(1)
end

-- Goo cocoons ----------------------------------------------------------------------------------------------------------------------------
function BossService:_cocoon(player)
	for _, c in cocoons do
		if c.player == player then
			return
		end
	end
	local spot
	local pines = self:_pines()
	if #pines > 0 then
		local p = pines[math.random(1, #pines)]
		local out = flat(p.pos).Unit
		spot = p.pos - out * (p.radius + 2.5) + Vector3.new(0, 3, 0)
	else
		local q = MapLayout.polar(math.random(0, 359), 60)
		spot = Vector3.new(q.X, MapLayout.groundY(q.X, q.Z) + 3, q.Z)
	end
	local id = nextCocoon
	nextCocoon += 1
	local model =
		Kit.ellipsoid(workspace, "Cocoon", spot, Vector3.new(5, 7, 5), Color3.fromRGB(120, 230, 90), Kit.M.Neon, {
			Transparency = 0.35,
			CanCollide = false,
		})
	model:SetAttribute("CocoonId", id)
	local c = {
		id = id,
		player = player,
		pos = spot,
		hp = Constants.COCOON_HP,
		maxHp = Constants.COCOON_HP,
		model = model,
		since = now(),
	}
	cocoons[id] = c
	local hrp = survivors:Root(player)
	if hrp then
		player:SetAttribute("AcGrace", now() + 30)
		hrp.CFrame = CFrame.new(spot)
		hrp.Anchored = true
	end
	player:SetAttribute("Cocooned", true)
	Net.fireAll("Callout", `🟢 {player.DisplayName} is stuck in a goo cocoon! Break them out!`, "bad")
	Net.fire(player, "Alert", "STUCK IN GOO! Mash to break out!", Color3.fromRGB(150, 255, 120), 2)
	self.Grabbed:Fire(player)
end

function BossService:_release(c, by, silent)
	if c.model then
		c.model:Destroy()
	end
	local player = c.player
	if player and player.Parent then
		local hrp = survivors:Root(player)
		if hrp then
			hrp.Anchored = false
			player:SetAttribute("AcGrace", now() + 2)
		end
		player:SetAttribute("Cocooned", nil)
		if not silent then
			Net.fireAll(
				"Toast",
				by and `🟢 {by.DisplayName} broke {player.DisplayName} out!`
					or `🟢 {player.DisplayName} broke free!`,
				"good"
			)
			self.Freed:Fire(player, by)
		end
	end
end

function BossService:CocoonsNear(pos, radius)
	local out = {}
	for _, c in cocoons do
		if (c.pos - pos).Magnitude <= radius + 3 then
			table.insert(out, c)
		end
	end
	return out
end

function BossService:HitCocoon(id, amount, by)
	local c = cocoons[id]
	if not c or by == c.player then
		return 0
	end
	c.hp -= amount
	Net.fireAll("Fx", "goo", { pos = c.pos })
	if c.hp <= 0 then
		cocoons[id] = nil
		self:_release(c, by)
	end
	return amount
end

function BossService:Mash(player)
	for id, c in cocoons do
		if c.player == player then
			c.hp -= Constants.COCOON_MASH
			if c.hp <= 0 then
				cocoons[id] = nil
				self:_release(c, nil)
			end
			return true
		end
	end
	return false
end

function BossService:Cocoons()
	return cocoons
end

-- Thinking -----------------------------------------------------------------------------------------------------------------------------
function BossService:_tick(dt)
	if not boss or boss.hp <= 0 then
		return
	end
	local t = now()
	if not boss.enraged and t - boss.startedAt >= Constants.BOSS_ENRAGE_AT then
		boss.enraged = true
		boss.speed *= 1.3
		event({ kind = "say", text = "SIX SEVEN SIX SEVEN SIX SEVEN!!!" })
		Net.fireAll("Alert", "MEGA KERMY IS ENRAGED!", Color3.fromRGB(255, 90, 90), 3)
		self:_push()
	end
	-- the goo squeezes whoever is inside
	for id, c in cocoons do
		if not c.player.Parent or survivors:Status(c.player) ~= "alive" then
			cocoons[id] = nil
			self:_release(c, nil, true)
		else
			c.squeeze = (c.squeeze or 0) + dt
			if c.squeeze >= 1 then
				c.squeeze = 0
				survivors:Damage(c.player, Constants.COCOON_SQUEEZE, { kind = "goo" })
			end
		end
	end
	local st = boss.state
	boss.moving = false
	if st == "show" then
		-- walks in from the trees
		local goal = Vector3.new(0, 0, 0)
		local dir = flat(goal - boss.pos)
		if dir.Magnitude > 30 then
			local step = dir.Unit * boss.speed * 0.6 * dt
			local p = boss.pos + step
			boss.pos = Vector3.new(p.X, MapLayout.groundY(p.X, p.Z), p.Z)
			boss.moving = true
			face(goal)
		end
		if t >= boss.stateUntil then
			setState("chase")
		end
		return
	end
	if st == "faceplant" or st == "tired" or st == "stagger" or st == "recover" then
		if t >= boss.stateUntil then
			setState("chase")
			boss.trampled = nil
		end
		return
	end
	if st == "tell" then
		if t >= boss.stateUntil then
			local nxt = boss.next
			boss.next = nil
			boss.trampled = nil
			if nxt == "charge" then
				setState("charge", 3)
			elseif nxt == "jump" then
				setState("jump", 1.6)
				boss.jumpStart = t
				event({ kind = "jump", from = boss.jumpFrom, to = boss.jumpTo, seconds = 1.6 })
			elseif nxt == "grab" then
				self:_grab()
			elseif nxt == "stomp" then
				self:_area(boss.pos, 12, boss.dmg * 0.75, 12, "stomp")
				event({ kind = "slam", at = boss.pos, radius = 12 })
				self:_afterAttack(1)
			else
				setState("chase")
			end
		end
		return
	end
	if st == "charge" then
		self:_charge(dt)
		if boss.state == "charge" and t >= boss.stateUntil then
			self:_afterAttack(1)
		end
		return
	end
	if st == "jump" then
		local f = math.clamp((t - boss.jumpStart) / 1.6, 0, 1)
		local p = boss.jumpFrom:Lerp(boss.jumpTo, f)
		boss.pos = Vector3.new(p.X, p.Y + math.sin(f * math.pi) * 28, p.Z)
		boss.moving = true
		if f >= 1 then
			self:_land()
		end
		return
	end
	-- chase and choose the next attack
	local tg = self:_pickTarget()
	if not tg then
		return
	end
	if not boss.target or t - (boss.retarget or 0) > 5 or survivors:Status(boss.target.player) ~= "alive" then
		boss.retarget = t
		boss.target = tg
	else
		for _, x in targetsList() do
			if x.player == boss.target.player then
				boss.target = x
			end
		end
	end
	tg = boss.target
	local d = (flat(tg.pos) - flat(boss.pos)).Magnitude
	if t >= boss.nextAttack then
		local roll = math.random()
		if d < 11 then
			face(tg.pos)
			self:_tell("stomp", 0.8, { at = boss.pos, radius = 12 })
			boss.next = "stomp"
		elseif boss.phase >= 3 and roll < 0.3 and d < 26 then
			self:_startGrab(tg)
		elseif boss.phase >= 2 and roll < 0.55 then
			self:_startJump(tg)
		else
			self:_startCharge(tg)
		end
		return
	end
	-- walk toward the target (slowly: he's huge)
	if d > 14 then
		local dir = flat(tg.pos - boss.pos).Unit
		local p = boss.pos + dir * boss.speed * dt
		if flat(p).Magnitude < ARENA + 6 then
			boss.pos = Vector3.new(p.X, MapLayout.groundY(p.X, p.Z), p.Z)
			boss.moving = true
		end
		face(tg.pos)
	end
end

function BossService:Init(registry)
	data = registry.PlayerDataService
	runs = registry.RunService
	survivors = registry.SurvivorService
	inventory = registry.InventoryService
	camp = registry.CampService
	monsters = registry.MonsterService
	Net.on("Mash", function(player)
		self:Mash(player)
	end)
	runs.BossStarted:Connect(function()
		task.delay(3, function()
			if runs:Phase() == "boss" then
				self:Begin()
			end
		end)
	end)
	runs.Ended:Connect(function()
		self:End()
	end)
	runs.Reset:Connect(function()
		self:End()
		self:_resetPines()
	end)
	_ = data
end

function BossService:OnPlayerReady(player)
	data:WhenClientReady(player, function()
		Net.fire(player, "Boss", self:View())
	end)
end

function BossService:OnPlayerLeaving(player)
	for id, c in cocoons do
		if c.player == player then
			cocoons[id] = nil
			if c.model then
				c.model:Destroy()
			end
		end
	end
end

function BossService:Start()
	local acc, pushAcc = 0, 0
	RunService_.Heartbeat:Connect(function(dt)
		acc += dt
		pushAcc += dt
		if acc >= 0.05 then
			local ok, err = pcall(self._tick, self, acc)
			if not ok then
				warn("[BossService] " .. tostring(err))
			end
			acc = 0
		end
		if pushAcc >= 0.5 and boss then
			pushAcc = 0
			self:_push()
		end
	end)
end

-- (tests)
function BossService:_pineHits()
	return pineHits
end

_ = Players
return BossService
