--[[
Fighting and using items (master plan §5, §6). The client swings the instant you press (it plays the animation
straight away, §5: fast input response) and tells the server; the server decides what was hit: the swing's reach
and arc from where it knows you are (with a little slack for lag), the weapon's cooldown, and then the damage,
stagger and knockback (§14: the server validates damage; the client never says what it hit).

  melee      axes, clubs, spears: monsters first; with nothing to fight, the same swing chops a tree or breaks a
             rock (axes chop best, clubs break rocks best); it can break a teammate out of a goo cocoon
  bows       an arrow flies (simulated here) and stops at the first trunk or monster (Obsidian/Moonshot pierce);
             standing on a watch platform: +25% damage
  specials   mastery level 3 of a class: Whirl Chop, Ground Pound, Lunge Thrust, Triple Shot (Data/Progression)
  items      food and medicine heal, brews buff, the map reveals the findings, traps are set at your feet,
             throwables land where you aim (flares light an area, firecrackers stun, sandwiches distract Kermy)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService_ = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local MapLayout = require(ReplicatedStorage.Shared.World.MapLayout)
local Net = require(ReplicatedStorage.Shared.Net)
local Progression = require(ReplicatedStorage.Shared.Data.Progression)
local Signal = require(ReplicatedStorage.Shared.Signal)

local CombatService = {
	Name = "CombatService",
	Dependencies = {
		"PlayerDataService",
		"RunService",
		"SurvivorService",
		"InventoryService",
		"MonsterService",
		"ResourceService",
		"CampService",
		"BossService",
	},
	Acted = Signal.new("CombatService.Acted"), -- (player, item, mode)
	Hit = Signal.new("CombatService.Hit"), -- (player, targetKind, amount, item) a monster, the boss or a cocoon
	Used = Signal.new("CombatService.Used"), -- (player, item)
	Thrown = Signal.new("CombatService.Thrown"), -- (player, item, at)
	Placed = Signal.new("CombatService.Placed"), -- (player, item)
	Special = Signal.new("CombatService.Special"), -- (player, class)
	Revealed = Signal.new("CombatService.Revealed"), -- (player) read the Ranger's Map
}

local data, runs, survivors, inventory, monsters, resources, camp, boss
local cooldowns = {} -- [player] = { [key] = readyAt }
local projectiles = {} -- { { pos, vel, dmg, owner, item, pierce, hit = {}, untilT } }
local world -- WorldService (set by it, to avoid a dependency loop): map reveals, the idol

local function now()
	return workspace:GetServerTimeNow()
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

function CombatService.setWorld(w)
	world = w
end

local function ready(player, key, seconds)
	cooldowns[player] = cooldowns[player] or {}
	local t = now()
	if t < (cooldowns[player][key] or 0) - 0.12 then -- (slack for network jitter: a press the client allowed counts)
		return false
	end
	cooldowns[player][key] = t + seconds
	return true
end

local function profileOf(player)
	return data:Get(player)
end

local function masteryLevel(player, class)
	local profile = profileOf(player)
	if not profile or not class then
		return 1
	end
	return (Formulas.mastery(profile.mastery[class] or 0))
end

local function damageMult(player)
	local mult = 1
	if workspace:GetAttribute("Blessing") == "strength" then
		mult *= 1.2
	end
	_ = player
	return mult
end

-- Validated aim: a flat unit vector (falls back to where the character faces).
local function aimOf(player, aim)
	local hrp = survivors:Root(player)
	if typeof(aim) == "Vector3" and aim.Magnitude > 0.01 and aim.Magnitude < 1e4 then
		local f = flat(aim)
		if f.Magnitude > 0.01 then
			return f.Unit, aim.Unit
		end
	end
	local look = hrp and hrp.CFrame.LookVector or Vector3.new(0, 0, -1)
	return flat(look).Unit, look
end

local function inArc(origin, dir, pos, range, arcDeg)
	local rel = flat(pos - origin)
	local d = rel.Magnitude
	if d > range then
		return false
	end
	if d < 2.5 then
		return true
	end
	local cos = rel.Unit:Dot(dir)
	return cos >= math.cos(math.rad(arcDeg / 2))
end

-- Melee -------------------------------------------------------------------------------------------------------------------
function CombatService:_melee(player, item, aim, opts)
	opts = opts or {}
	local origin = survivors:Position(player)
	if not origin then
		return false
	end
	local dir = aim
	local range = (opts.range or item.range) + Constants.MELEE_SLACK
	local arc = (opts.arc or item.arc) + Constants.ARC_SLACK
	local dmg = item.dmg * (opts.dmgMult or 1) * damageMult(player)
	local hitSomething = false
	-- monsters
	local victims = {}
	for _, m in monsters:Near(origin, range) do
		if inArc(origin, dir, m.pos, range + m.beh.radius, arc) and math.abs(m.pos.Y - origin.Y) < 10 then
			table.insert(victims, m)
		end
	end
	local maxTargets = opts.maxTargets or (item.class == "spear" and (item.pierce and 3 or 1) or 3)
	for i, m in victims do
		if i > maxTargets then
			break
		end
		local amount = dmg * ((item.vs and item.vs[m.kind]) or 1)
		local crit = math.random() < 0.08
		if crit then
			amount *= 1.5
		end
		local done = monsters:Damage(m.id, amount, player, {
			stagger = opts.stagger or item.stagger or 0,
			knock = item.knock,
			dir = flat(m.pos - origin).Magnitude > 0.01 and flat(m.pos - origin).Unit or dir,
			kind = item.class,
			crit = crit,
		})
		if done > 0 then
			hitSomething = true
			self.Hit:Fire(player, m.kind, done, item)
		end
	end
	-- Mega Kermy
	local b = boss:Get()
	if b and b.hp > 0 and inArc(origin, dir, b.pos, range + 6, arc + 20) then
		local done = boss:Damage(dmg, player, { item = item })
		if done > 0 then
			hitSomething = true
			self.Hit:Fire(player, "mega_kermy", done, item)
		end
	end
	-- goo cocoons (breaking a teammate out)
	for _, c in boss:CocoonsNear(origin, range) do
		if inArc(origin, dir, c.pos, range + 3, arc + 30) then
			boss:HitCocoon(c.id, dmg, player)
			hitSomething = true
		end
	end
	if hitSomething or opts.noGather then
		return hitSomething
	end
	-- nothing to fight: chop the tree or break the rock you swing at, the one most in front of you (in a wide arc
	-- of the aim, or of where the character faces, so a laggy aim still chops; something behind you never counts)
	local hrp = survivors:Root(player)
	local facing = hrp and flat(hrp.CFrame.LookVector)
	facing = facing and facing.Magnitude > 0.01 and facing.Unit or nil
	local best, bestKind, bestScore
	local function consider(kind, target, x, z, radius)
		local rel = flat(Vector3.new(x, origin.Y, z) - origin)
		local gap = math.max(0, rel.Magnitude - radius) -- to its surface
		if gap > Constants.GATHER_RANGE then
			return
		end
		local cos = 1
		if rel.Magnitude > 0.05 then
			cos = math.max(rel.Unit:Dot(dir), facing and rel.Unit:Dot(facing) or -1)
		end
		if cos < math.cos(math.rad(75)) then
			return
		end
		-- straight ahead and close wins; a giant (too big to chop) only when there's nothing else
		local score = gap + (1 - cos) * 6 + ((kind == "tree" and not resources:CanChop(target)) and 100 or 0)
		if not bestScore or score < bestScore then
			best, bestKind, bestScore = target, kind, score
		end
	end
	for _, n in resources:NodesNear(origin, Constants.GATHER_RANGE) do
		consider("node", n, n.x, n.z, resources:NodeRadius(n))
	end
	for _, t in resources:TreesNear(origin, Constants.GATHER_RANGE) do
		consider("tree", t, t.rec.x, t.rec.z, t.rec.trunk)
	end
	if bestKind == "node" then
		resources:HitNode(player, best, item.rock or 0.3)
		return true
	elseif bestKind == "tree" then
		if resources:CanChop(best) then
			resources:HitTree(player, best, item.tree or 0.2)
		else
			resources:TooBig(player, best)
		end
		return true
	end
	return false
end

-- Bows ----------------------------------------------------------------------------------------------------------------------
local function onPlatform(player)
	local pos = survivors:Position(player)
	if not pos then
		return false
	end
	for _, s in camp:Structures() do
		if s.key == "platform" and s.state == "built" then
			if (flat(s.slot.pos) - flat(pos)).Magnitude < 5 and pos.Y > s.slot.pos.Y + 6 then
				return true
			end
		end
	end
	return false
end

function CombatService:_shoot(player, item, aim3, spread)
	local origin = survivors:Position(player)
	if not origin then
		return false
	end
	local dir = aim3
	if spread and spread ~= 0 then
		local f = flat(dir)
		local c, s = math.cos(spread), math.sin(spread)
		dir = Vector3.new(f.X * c - f.Z * s, dir.Y, f.X * s + f.Z * c).Unit
	end
	local dmg = item.dmg * damageMult(player) * (onPlatform(player) and 1.25 or 1)
	local start = origin + Vector3.new(0, 1.5, 0) + flat(dir) * 2
	table.insert(projectiles, {
		pos = start,
		vel = dir * Constants.ARROW_SPEED,
		dmg = dmg,
		owner = player,
		item = item,
		pierce = item.pierce,
		hit = {},
		untilT = now() + Constants.PROJECTILE_SECONDS,
		range = item.range,
		from = start,
	})
	Net.fireAll("Fx", "arrow", { from = start, dir = dir, speed = Constants.ARROW_SPEED, by = player.UserId })
	return true
end

function CombatService:_stepProjectiles(dt)
	local t = now()
	for i = #projectiles, 1, -1 do
		local p = projectiles[i]
		local done = t > p.untilT
		if not done then
			local nextPos = p.pos + p.vel * dt
			p.vel = p.vel - Vector3.new(0, Constants.ARROW_GRAVITY * dt, 0)
			-- trunks stop arrows
			local clear = monsters:LineClear(p.pos, nextPos, 0)
			if not clear then
				done = true
			end
			-- monsters
			if not done then
				local mid = (p.pos + nextPos) / 2
				for _, m in monsters:Near(mid, (nextPos - p.pos).Magnitude / 2 + 3) do
					if not p.hit[m.id] then
						local rel = m.pos + Vector3.new(0, 2, 0) - p.pos
						local seg = nextPos - p.pos
						local tt = math.clamp(rel:Dot(seg) / math.max(seg:Dot(seg), 1e-6), 0, 1)
						local closest = (p.pos + seg * tt) - (m.pos + Vector3.new(0, 2, 0))
						if closest.Magnitude < m.beh.radius + 1.6 then
							p.hit[m.id] = true
							local amount = monsters:Damage(m.id, p.dmg, p.owner, {
								stagger = p.item.stagger or 0,
								knock = 2,
								dir = flat(p.vel).Unit,
								kind = "bow",
							})
							if amount > 0 then
								self.Hit:Fire(p.owner, m.kind, amount, p.item)
							end
							if not p.pierce then
								done = true
								break
							end
						end
					end
				end
				local b = boss:Get()
				if not done and b and b.hp > 0 and not p.hit.boss then
					if (b.pos + Vector3.new(0, 10, 0) - nextPos).Magnitude < 9 then
						p.hit.boss = true
						local amount = boss:Damage(p.dmg, p.owner, { item = p.item })
						self.Hit:Fire(p.owner, "mega_kermy", amount, p.item)
						if not p.pierce then
							done = true
						end
					end
				end
				for _, c in boss:CocoonsNear(nextPos, 2) do
					boss:HitCocoon(c.id, p.dmg, p.owner)
					done = true
				end
			end
			if
				not done
				and (nextPos.Y < MapLayout.groundY(nextPos.X, nextPos.Z) or (nextPos - p.from).Magnitude > p.range)
			then
				done = true
			end
			p.pos = nextPos
		end
		if done then
			table.remove(projectiles, i)
		end
	end
end

-- Specials (mastery level 3) ------------------------------------------------------------------------------------------------
function CombatService:_special(player, item, aim, aim3)
	local class = Items.masteryClass(item)
	local spec = class and Progression.SPECIALS[class]
	if not spec or spec.passive or masteryLevel(player, class) < 3 then
		return false
	end
	if not ready(player, "special", Constants.SPECIAL_COOLDOWN) then
		return false
	end
	local origin = survivors:Position(player)
	if class == "axe" then
		self:_melee(
			player,
			item,
			aim,
			{ range = spec.radius, arc = 360, dmgMult = spec.dmg, maxTargets = 8, noGather = true }
		)
	elseif class == "club" then
		self:_melee(player, item, aim, {
			range = spec.radius,
			arc = 360,
			dmgMult = spec.dmg,
			stagger = 3,
			maxTargets = 8,
			noGather = true,
		})
		Net.fireAll("Fx", "ring", { pos = origin, radius = spec.radius, color = "club" })
	elseif class == "spear" then
		player:SetAttribute("AcGrace", now() + 0.8)
		Net.fire(player, "Dash", aim, spec.length, 0.35)
		task.delay(0.2, function()
			self:_melee(
				player,
				item,
				aim,
				{ range = spec.length, arc = 30, dmgMult = spec.dmg, maxTargets = 6, noGather = true }
			)
		end)
	elseif class == "bow" then
		if not inventory:Take(player, "arrows", 1) then
			Net.fire(player, "Toast", "Out of arrows!", "bad")
			return false
		end
		for k = -1, 1 do
			self:_shoot(player, item, aim3, k * 0.18)
		end
	end
	Net.fireAll("Act", { by = player.UserId, item = item.key, mode = "special" })
	self.Special:Fire(player, class)
	return true
end

-- Using items -----------------------------------------------------------------------------------------------------------------
function CombatService:Use(player, slotId)
	if not runs:InRun(player) or not survivors:IsAlive(player) then
		return false
	end
	local slot = inventory:Slot(player, slotId)
	local item = slot and Items.get(slot.key)
	if not item then
		return false
	end
	if not ready(player, "use", 0.6) then
		return false
	end
	if item.kind == "food" or item.kind == "support" then
		if item.autoRevive then
			Net.fire(player, "Toast", "Keep it: it gets you up by itself when you go down.", "info")
			return false
		end
		local s = survivors:State(player)
		local full = s and s.hp >= s.maxHp
		if full and not item.buff and not item.stamina then
			Net.fire(player, "Toast", "You're already at full health.", "info")
			return false
		end
		inventory:Consume(player, slotId, 1)
		if item.heal then
			survivors:Heal(player, item.heal, item.healOver)
		end
		if item.stamina then
			survivors:RestoreStamina(player, item.stamina)
		end
		if item.buff then
			if item.buff.speed then
				survivors:Buff(player, "speed", item.buff.speed, item.buff.seconds)
			end
			if item.buff.shield then
				survivors:Buff(player, "shield", item.buff.shield, item.buff.seconds)
			end
			if item.buff.regen then
				survivors:Buff(player, "regen", item.buff.regen, item.buff.seconds)
			end
		end
		-- Field Medic (support mastery 3): friends close by get half
		if item.heal and masteryLevel(player, "support") >= 3 then
			local pos = survivors:Position(player)
			for _, tg in survivors:Targets() do
				if tg.player ~= player and pos and (tg.pos - pos).Magnitude < 14 then
					survivors:Heal(tg.player, item.heal * 0.5, item.healOver, player)
				end
			end
		end
		Net.fire(player, "Sfx", "eat")
		Net.fireAll("Act", { by = player.UserId, item = item.key, mode = "use" })
		self.Used:Fire(player, item)
		return true
	end
	if item.key == "ranger_map" then
		inventory:Consume(player, slotId, 1)
		if world then
			world:RevealAll(player)
		end
		self.Revealed:Fire(player)
		self.Used:Fire(player, item)
		return true
	end
	if Items.isEquipment(item) then
		return inventory:ToggleEquip(player, slotId)
	end
	return false
end

-- Set a trap at your feet (or where you aim, close by).
function CombatService:Place(player, slotId, pos)
	if not runs:InRun(player) or not survivors:IsAlive(player) then
		return false
	end
	local slot = inventory:Slot(player, slotId)
	local item = slot and Items.get(slot.key)
	if not item or item.kind ~= "trap" then
		return false
	end
	local me = survivors:Position(player)
	if not me then
		return false
	end
	if typeof(pos) ~= "Vector3" or (flat(pos) - flat(me)).Magnitude > 10 then
		pos = me + flat(survivors:Root(player).CFrame.LookVector) * 4
	end
	local quick = masteryLevel(player, "trap") >= 3 and 0.5 or 1
	if not ready(player, "trap", 1 * quick) then
		return false
	end
	local at = Vector3.new(pos.X, MapLayout.groundY(pos.X, pos.Z), pos.Z)
	local trap, why = monsters:PlaceTrap(player, item, at)
	if not trap then
		Net.fire(player, "Toast", why or "Can't set a trap here.", "bad")
		return false
	end
	inventory:Consume(player, slotId, 1)
	Net.fireAll("Fx", "trapset", { pos = at, item = item.key })
	self.Placed:Fire(player, item)
	return true
end

-- Throw something to where you aim (within reach).
function CombatService:Throw(player, slotId, target)
	if not runs:InRun(player) or not survivors:IsAlive(player) then
		return false
	end
	local slot = inventory:Slot(player, slotId)
	local item = slot and Items.get(slot.key)
	if not item or item.kind ~= "throw" then
		return false
	end
	local me = survivors:Position(player)
	if not me then
		return false
	end
	local quick = masteryLevel(player, "trap") >= 3 and 0.5 or 1
	if not ready(player, "throw", 1.2 * quick) then
		return false
	end
	if typeof(target) ~= "Vector3" then
		target = me + flat(survivors:Root(player).CFrame.LookVector) * 20
	end
	local rel = flat(target - me)
	if rel.Magnitude > Constants.THROW_RANGE then
		target = me + rel.Unit * Constants.THROW_RANGE
	end
	local at = Vector3.new(target.X, MapLayout.groundY(target.X, target.Z), target.Z)
	inventory:Consume(player, slotId, 1)
	Net.fireAll("Fx", "throw", { from = me + Vector3.new(0, 2, 0), to = at, item = item.key, seconds = 0.7 })
	local th = item.throw
	task.delay(0.7, function()
		if th.kind == "firecracker" then
			Net.fireAll("Fx", "bang", { pos = at, radius = th.radius })
			monsters:Firecracker(at, th.radius, th.stun, th.dmg, player)
		elseif th.kind == "flare" then
			Net.fireAll("Fx", "flare", { pos = at, seconds = th.seconds, radius = th.radius })
			Net.fireAll("Ping", {
				key = "flare",
				text = "Flare",
				icon = "🎆",
				position = at,
				from = player.DisplayName,
				until_ = now() + th.seconds,
			})
		elseif th.kind == "bait" then
			Net.fireAll("Fx", "bait", { pos = at, seconds = th.seconds + 6 })
			monsters:AddBait(at, th.seconds + 6)
		end
	end)
	Net.fireAll("Act", { by = player.UserId, item = item.key, mode = "throw" })
	self.Thrown:Fire(player, item, at)
	return true
end

-- The main action: whatever you hold.
function CombatService:Act(player, slotIndex, aim, mode)
	if not runs:InRun(player) or not survivors:IsAlive(player) then
		return false
	end
	if type(slotIndex) == "number" then
		inventory:Select(player, slotIndex)
	end
	local slotId, item = inventory:Selected(player)
	if not item or item.kind == "light" or item.kind == "resource" or item.kind == "ammo" or item.kind == "key" then
		-- bare hands (or a torch in hand): a weak punch that still chops a little (nobody is ever stuck with nothing)
		item = {
			key = "hands",
			kind = "weapon",
			class = nil,
			dmg = 4,
			cd = 0.6,
			range = 5,
			arc = 90,
			tree = 0.15,
			rock = 0.15,
			stagger = 0,
			knock = 1,
		}
	end
	local dir, dir3 = aimOf(player, aim)
	player:SetAttribute("ActAt", now())
	if item.kind == "weapon" then
		if mode == "special" then
			return self:_special(player, item, dir, dir3)
		end
		if not ready(player, "weapon", item.cd) then
			return false
		end
		if item.class == "bow" then
			if not inventory:Take(player, "arrows", 1) then
				Net.fire(player, "Toast", "Out of arrows! Make more at the workbench.", "bad")
				return false
			end
			self:_shoot(player, item, dir3)
		else
			self:_melee(player, item, dir)
		end
		Net.fireAll("Act", { by = player.UserId, item = item.key, mode = "main", dir = dir })
		self.Acted:Fire(player, item, "main")
		return true
	elseif item.kind == "food" or item.kind == "support" or item.key == "ranger_map" or Items.isEquipment(item) then
		return self:Use(player, slotId)
	elseif item.kind == "trap" then
		return self:Place(player, slotId, nil)
	elseif item.kind == "throw" then
		local me = survivors:Position(player)
		local target = me and (me + dir * 22) or nil
		return self:Throw(player, slotId, target)
	end
	return false
end

function CombatService:Init(registry)
	data = registry.PlayerDataService
	runs = registry.RunService
	survivors = registry.SurvivorService
	inventory = registry.InventoryService
	monsters = registry.MonsterService
	resources = registry.ResourceService
	camp = registry.CampService
	boss = registry.BossService
	Net.on("Act", function(player, slot, aim, mode)
		self:Act(player, slot, aim, mode == "special" and "special" or "main")
	end)
	Net.on("Use", function(player, slotId)
		if type(slotId) == "string" then
			self:Use(player, slotId)
		end
	end)
	Net.on("Throw", function(player, slotId, target)
		if type(slotId) == "string" then
			self:Throw(player, slotId, target)
		end
	end)
	Net.on("Place", function(player, slotId, pos)
		if type(slotId) == "string" then
			self:Place(player, slotId, pos)
		end
	end)
	runs.Reset:Connect(function()
		table.clear(projectiles)
	end)
	Players.PlayerRemoving:Connect(function(player)
		cooldowns[player] = nil
	end)
end

function CombatService:Start()
	RunService_.Heartbeat:Connect(function(dt)
		if #projectiles > 0 then
			local ok, err = pcall(self._stepProjectiles, self, math.min(dt, 0.1))
			if not ok then
				warn("[CombatService] " .. tostring(err))
			end
		end
	end)
end

-- (tests)
function CombatService:_projectiles()
	return projectiles
end

return CombatService
