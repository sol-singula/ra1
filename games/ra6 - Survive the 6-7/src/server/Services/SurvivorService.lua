--[[
Survivors: characters, health, stamina, dodging, going down and getting back up (master plan §5, §7, §8).

  health     100; armor and shield brews cut damage; the campfire heals you while you rest by it (out of combat);
             food and bandages heal over time. Never Roblox's own death: at 0 you're DOWNED.
  stamina    sprinting and dodging spend it, it comes back after a short pause (§5: powerful enough to escape
             danger, not tedious). The client predicts its own sprint; the server keeps the real stamina.
  dodge      a quick roll with i-frames and a cooldown. Latency forgiveness: a hit waits a moment
             (ResolveHit) so a dodge that reached the server just late still counts (§5: latency must not make dodges
             feel random).
  downed     crawl; a teammate holds the Revive prompt on you (a medkit or the Medic perk speeds it up); alone, crawl
             into the campfire's light to get up by yourself (Normal and Hard). A Feather of Second Wind gets you up
             at once. Bleed out and you're a GHOST: your pack drops where you fell, and you're back at the camp at
             dawn (25 seconds if it's daytime).
  the team   if every survivor in the run is down or a ghost at the same time, the run is lost (RunService.Wipe).
  waiting    joined after the roster locked: no character, you watch until the next run (§8).
]]
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService_ = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local MapLayout = require(ReplicatedStorage.Shared.World.MapLayout)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local SurvivorService = {
	Name = "SurvivorService",
	Dependencies = { "PlayerDataService", "RunService", "InventoryService" },
	Spawned = Signal.new("SurvivorService.Spawned"), -- (player)
	Damaged = Signal.new("SurvivorService.Damaged"), -- (player, amount, source)
	Downed = Signal.new("SurvivorService.Downed"), -- (player, source)
	Revived = Signal.new("SurvivorService.Revived"), -- (player, by?, how)
	Ghosted = Signal.new("SurvivorService.Ghosted"), -- (player)
	Respawned = Signal.new("SurvivorService.Respawned"), -- (player)
	Dodged = Signal.new("SurvivorService.Dodged"), -- (player, sourceKind?) an attack missed thanks to a dodge
	DodgeUsed = Signal.new("SurvivorService.DodgeUsed"), -- (player)
	Healed = Signal.new("SurvivorService.Healed"), -- (player, amount, by?)
}

local data, runs, inventory
local camp -- CampService, set by CampService (the fire's light and fuel), to avoid a dependency loop
local st = {} -- [player] = survivor state
local TICK = 0.1

local function now()
	return workspace:GetServerTimeNow()
end

local function state(player)
	local s = st[player]
	if not s then
		s = {
			status = "none",
			hp = Constants.MAX_HP,
			maxHp = Constants.MAX_HP,
			stamina = Constants.STAMINA_MAX,
			sprint = false,
			sprinting = false,
			lastStamina = 0,
			dodgeAt = -99,
			dodgeReady = 0,
			iframeUntil = 0,
			lastHit = -99,
			protectUntil = 0,
			buffs = {},
			heals = {},
			fireRevive = 0,
			stats = { damage = 0, revives = 0, downs = 0, dodged = 0, ghosts = 0, healed = 0 },
		}
		st[player] = s
	end
	return s
end

function SurvivorService.setCamp(c)
	camp = c
end

-- Queries --------------------------------------------------------------------------------------------------------
function SurvivorService:State(player)
	return st[player]
end

function SurvivorService:Status(player)
	local s = st[player]
	return s and s.status or "none"
end

function SurvivorService:IsAlive(player)
	return self:Status(player) == "alive"
end

function SurvivorService:Root(player)
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

function SurvivorService:Position(player)
	local hrp = self:Root(player)
	return hrp and hrp.Position or nil
end

-- Survivors who can be hit or targeted: alive (or downed, for finishing moves: never; downed are left alone).
function SurvivorService:Targets()
	local out = {}
	for _, p in runs:Active() do
		local s = st[p]
		if s and s.status == "alive" then
			local pos = self:Position(p)
			if pos then
				table.insert(out, { player = p, pos = pos, state = s })
			end
		end
	end
	return out
end

function SurvivorService:Stats(player)
	return state(player).stats
end

local function hasPerk(player, key)
	local profile = data:Get(player)
	return profile ~= nil and table.find(profile.perks or {}, key) ~= nil
end
SurvivorService.hasPerk = hasPerk

function SurvivorService:StaminaMax(player)
	local g = inventory:Gear(player)
	return Constants.STAMINA_MAX * g.staminaMax * (hasPerk(player, "marathon") and 1.2 or 1)
end

-- Speeds the client should use (and the anti-cheat allows).
function SurvivorService:Speeds(player)
	local s = state(player)
	local g = inventory:Gear(player)
	local mult = g.speed
	local b = s.buffs.speed
	if b and b.untilT > now() then
		mult *= b.mult
	end
	if workspace:GetAttribute("Blessing") == "swift" then
		mult *= 1.1 -- the Blessing of the Wind (WorldService)
	end
	if s.status == "downed" then
		return Constants.CRAWL_SPEED, Constants.CRAWL_SPEED
	end
	return Constants.WALK_SPEED * mult, Constants.SPRINT_SPEED * mult
end

function SurvivorService:MaxSpeed(player)
	local _, sprint = self:Speeds(player)
	return sprint
end

-- Views ----------------------------------------------------------------------------------------------------------
function SurvivorService:View(player)
	local s = state(player)
	local t = now()
	local buffs = {}
	for k, b in s.buffs do
		if b.untilT > t then
			buffs[k] = math.ceil(b.untilT - t)
		end
	end
	local walk, sprint = self:Speeds(player)
	return {
		status = s.status,
		hp = math.ceil(s.hp),
		maxHp = s.maxHp,
		stamina = math.floor(s.stamina),
		staminaMax = math.floor(self:StaminaMax(player)),
		walk = walk,
		sprint = sprint,
		armor = inventory:Gear(player).armor,
		buffs = buffs,
		bleedUntil = s.status == "downed" and s.bleedUntil or nil,
		fireRevive = s.status == "downed" and s.fireRevive or nil,
		respawnAt = s.status == "ghost" and s.respawnAt or nil,
		dodgeReady = s.dodgeReady,
	}
end

function SurvivorService:Push(player)
	local s = state(player)
	s.pushed = now()
	Net.fire(player, "Me", self:View(player))
end

local function teamView()
	local list = {}
	for _, p in runs:Active() do
		local s = st[p]
		if s then
			local pos = SurvivorService:Position(p)
			table.insert(list, {
				userId = p.UserId,
				name = p.DisplayName,
				hp = math.ceil(s.hp),
				maxHp = s.maxHp,
				status = s.status,
				pos = pos and Vector3.new(math.floor(pos.X), math.floor(pos.Y), math.floor(pos.Z)) or nil,
				bleedUntil = s.status == "downed" and s.bleedUntil or nil,
			})
		end
	end
	return list
end

-- Characters -------------------------------------------------------------------------------------------------------
local function setupHumanoid(player, character)
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	hum.WalkSpeed = Constants.WALK_SPEED
	hum.UseJumpPower = false -- (JumpHeight, so a downed survivor's 0 holds)
	hum.JumpHeight = Constants.JUMP_HEIGHT
	hum.MaxSlopeAngle = Constants.MAX_SLOPE
	hum.MaxHealth = Constants.MAX_HP
	hum.Health = Constants.MAX_HP
	hum.BreakJointsOnDeath = false
	pcall(function()
		hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
		hum.HealthDisplayDistance = 0
		hum.NameDisplayDistance = 80
	end)
	_ = player
end

-- Give a player a character at a spot (yields while Roblox builds it).
function SurvivorService:Spawn(player, pos)
	local s = state(player)
	s.status = "alive"
	s.hp = s.maxHp
	s.stamina = self:StaminaMax(player)
	s.protectUntil = now() + Constants.SPAWN_PROTECT
	s.buffs = {}
	s.heals = {}
	s.fireRevive = 0
	s.bleedUntil = nil
	s.respawnAt = nil
	pos = pos or MapLayout.spawnPoint(math.random(1, 12))
	pcall(function()
		player:RequestStreamAroundAsync(pos, 8)
	end)
	player:SetAttribute("AcGrace", now() + 3)
	player.ReplicationFocus = nil -- (back to your own character)
	player:LoadCharacter()
	local c = player.Character
	if c then
		setupHumanoid(player, c)
		local hum = c:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.Died:Connect(function()
				self:_characterDied(player, c)
			end)
		end
		local hrp = c:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.CFrame = CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0))
		end
		c:SetAttribute("Status", "alive")
	end
	player:SetAttribute("Status", "alive")
	self:Push(player)
	self.Spawned:Fire(player)
	return c
end

local function removeCharacter(player)
	local c = player.Character
	if c then
		player.Character = nil
		c:Destroy()
	end
end

--[[ A character that died anyway. The client owns its character, so the server can't stop it dying there (the
Roblox menu's Reset if the client couldn't turn it off, falling out of the world), and characters don't come back
by themselves here. Down: what bleeding out would do. Up: back at the camp, with the health you had. ]]
function SurvivorService:_characterDied(player, c)
	task.delay(1, function()
		if not player.Parent or player.Character ~= c or not runs:InRun(player) then
			return
		end
		local s = state(player)
		if s.status == "downed" then
			self:Ghost(player)
		elseif s.status == "alive" then
			local hp = s.hp
			self:Spawn(player, MapLayout.spawnPoint(math.random(1, 12)))
			s.hp = math.clamp(hp, 1, s.maxHp)
			self:Push(player)
		end
	end)
end

-- Out of the run (a ghost, or waiting): the world streams in round the teammate you watch, not round nothing.
function SurvivorService:Watch(player, userId)
	local s = state(player)
	if s.status == "alive" or s.status == "downed" or player.Character then
		player.ReplicationFocus = nil
		return
	end
	local target = type(userId) == "number" and Players:GetPlayerByUserId(userId) or nil
	local hrp = target and target ~= player and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
	player.ReplicationFocus = hrp or nil
end

-- Waiting for the next run: no character, the client shows the run and how to get into one.
function SurvivorService:SetWaiting(player)
	local s = state(player)
	s.status = "waiting"
	removeCharacter(player)
	player:SetAttribute("Status", "waiting")
	self:Push(player)
end

-- Damage and healing -------------------------------------------------------------------------------------------------
function SurvivorService:Invulnerable(player)
	local s = state(player)
	local t = now()
	return s.status ~= "alive" or t < s.protectUntil or t < s.iframeUntil
end

-- A hit that the target could dodge: waits a moment for a late dodge (lag), then lands unless they dodged in time.
-- onHit runs if it lands; returns nothing (the hit resolves later).
function SurvivorService:ResolveHit(player, sourceKind, onHit)
	local s = state(player)
	local t0 = now()
	local ping = 0.1
	pcall(function()
		ping = player:GetNetworkPing()
	end)
	local grace = math.clamp(ping / 2 + 0.03, 0.03, Constants.DODGE_GRACE_MAX)
	task.delay(grace, function()
		if s.status ~= "alive" then
			return
		end
		-- dodged: i-frames covered the moment of the hit, or a dodge started within the grace after it
		if s.dodgeAt >= t0 - Constants.IFRAME_SECONDS and s.dodgeAt <= t0 + grace + 0.02 then
			s.stats.dodged += 1
			self.Dodged:Fire(player, sourceKind)
			Net.fire(player, "Popup", self:Position(player) or Vector3.zero, "DODGED!", Color3.fromRGB(150, 230, 255))
			return
		end
		if t0 < s.protectUntil then
			return
		end
		onHit()
	end)
end

-- Damage a survivor (already resolved). source = { kind = "kermy" | ..., dir = Vector3?, knock = studs? }
function SurvivorService:Damage(player, amount, source)
	local s = state(player)
	if s.status ~= "alive" or amount <= 0 then
		return 0
	end
	if now() < s.protectUntil then
		return 0
	end
	local g = inventory:Gear(player)
	local shield = s.buffs.shield and s.buffs.shield.untilT > now() and s.buffs.shield.cut or 0
	local dark = camp ~= nil and runs:IsNight() and not camp:FireLit()
	local dmg = Formulas.damageTaken(amount, g.armor, shield, dark)
	s.hp -= dmg
	s.lastHit = now()
	s.stats.damage += dmg
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Health = math.max(1, s.hp)
	end
	local dir = source and source.dir
	Net.fire(player, "Hurt", { amount = dmg, by = source and source.kind, dir = dir })
	if source and source.knock and dir then
		player:SetAttribute("AcGrace", now() + 0.8)
		Net.fire(player, "Knock", dir, source.knock)
	end
	self.Damaged:Fire(player, dmg, source)
	if s.hp <= 0 then
		self:Down(player, source)
	else
		self:Push(player)
	end
	return dmg
end

function SurvivorService:Heal(player, amount, over, by)
	local s = state(player)
	if s.status ~= "alive" or amount <= 0 then
		return
	end
	if hasPerk(player, "medic") then
		amount *= 1.4
	end
	if over and over > 0 then
		table.insert(s.heals, { perSec = amount / over, untilT = now() + over, by = by })
	else
		local before = s.hp
		s.hp = math.min(s.maxHp, s.hp + amount)
		s.stats.healed += s.hp - before
		self.Healed:Fire(player, s.hp - before, by)
	end
	self:Push(player)
end

function SurvivorService:Buff(player, kind, value, seconds)
	local s = state(player)
	if kind == "speed" then
		s.buffs.speed = { mult = value, untilT = now() + seconds }
	elseif kind == "shield" then
		s.buffs.shield = { cut = value, untilT = now() + seconds }
	elseif kind == "regen" then
		s.buffs.regen = { perSec = value, untilT = now() + seconds }
	end
	self:Push(player)
end

function SurvivorService:RestoreStamina(player, amount)
	local s = state(player)
	s.stamina = math.min(self:StaminaMax(player), s.stamina + amount)
	self:Push(player)
end

-- Down, revive, ghost ----------------------------------------------------------------------------------------------
function SurvivorService:_reviveTime(reviver)
	local t = Constants.REVIVE_SECONDS
	local _, item = inventory:Selected(reviver)
	if item and item.fastRevive then
		t *= 0.5
	end
	if hasPerk(reviver, "medic") then
		t *= 0.7
	end
	if hasPerk(reviver, "quick_hands") then
		t *= 0.85
	end
	return t
end

function SurvivorService:_makePrompt(player)
	local hrp = self:Root(player)
	if not hrp then
		return
	end
	local old = hrp:FindFirstChild("Revive")
	if old then
		old:Destroy()
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Revive"
	prompt.ActionText = "Revive"
	prompt.ObjectText = player.DisplayName
	prompt.HoldDuration = Constants.REVIVE_SECONDS
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt:SetAttribute("ReviveOf", player.UserId)
	prompt.Parent = hrp -- (the downed survivor's own client hides it: InputController)
	prompt.Triggered:Connect(function(reviver)
		if reviver ~= player then
			self:Revive(player, reviver, "teammate")
		end
	end)
end

function SurvivorService:Down(player, source)
	local s = state(player)
	if s.status ~= "alive" then
		return
	end
	-- a Feather of Second Wind: straight back up
	if inventory:Has(player, "revive_charm") then
		inventory:Take(player, "revive_charm", 1)
		s.hp = 50
		s.protectUntil = now() + 2
		self:Buff(player, "shield", 0.5, 3)
		Net.fire(player, "Alert", "🪶 SECOND WIND!", Color3.fromRGB(255, 240, 160), 2)
		self.Revived:Fire(player, nil, "charm")
		self:Push(player)
		return
	end
	local d = Formulas.difficulty(runs:Difficulty())
	s.status = "downed"
	s.hp = 0
	s.downedAt = now()
	s.bleedUntil = now() + d.bleed + (hasPerk(player, "light_sleeper") and 8 or 0)
	s.fireRevive = 0
	s.sprinting = false
	s.stats.downs += 1
	player:SetAttribute("Status", "downed")
	if player.Character then
		player.Character:SetAttribute("Status", "downed")
		local hum = player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.Health = 1
			hum.WalkSpeed = Constants.CRAWL_SPEED
			hum.JumpHeight = 0
		end
	end
	self:_makePrompt(player)
	Net.fireAll("Callout", `🆘 {player.DisplayName} is down! Revive them!`, "bad")
	Net.fire(player, "Sfx", "downed")
	self.Downed:Fire(player, source)
	self:Push(player)
	self:_checkWipe()
end

function SurvivorService:Revive(player, by, how)
	local s = state(player)
	if s.status ~= "downed" then
		return false
	end
	s.status = "alive"
	s.hp = Constants.REVIVE_HP
	s.protectUntil = now() + 2
	s.lastHit = now()
	s.bleedUntil = nil
	s.fireRevive = 0
	player:SetAttribute("Status", "alive")
	local c = player.Character
	if c then
		c:SetAttribute("Status", "alive")
		local hum = c:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.Health = s.hp
			hum.WalkSpeed = Constants.WALK_SPEED
			hum.JumpHeight = Constants.JUMP_HEIGHT
		end
		local hrp = c:FindFirstChild("HumanoidRootPart")
		local prompt = hrp and hrp:FindFirstChild("Revive")
		if prompt then
			prompt:Destroy()
		end
	end
	if by then
		state(by).stats.revives += 1
		Net.fireAll("Toast", `🤝 {by.DisplayName} revived {player.DisplayName}!`, "good")
	else
		Net.fire(player, "Toast", "🔥 You warmed up by the fire and got back on your feet.", "good")
	end
	self.Revived:Fire(player, by, how or (by and "teammate" or "fire"))
	self:Push(player)
	return true
end

function SurvivorService:Ghost(player)
	local s = state(player)
	if s.status ~= "downed" then
		return
	end
	local pos = self:Position(player) or MapLayout.CAMP_PROPS.fire
	inventory:DropAll(player, Vector3.new(pos.X, MapLayout.groundY(pos.X, pos.Z), pos.Z), player.DisplayName)
	s.status = "ghost"
	s.hp = 0
	s.stats.ghosts += 1
	-- back at dawn; by day after a short wait
	s.respawnAt = runs:IsNight() and nil or (now() + 25)
	removeCharacter(player)
	player:SetAttribute("Status", "ghost")
	Net.fireAll("Callout", `👻 {player.DisplayName} is out until dawn.`, "bad")
	self.Ghosted:Fire(player)
	self:Push(player)
	self:_checkWipe()
end

function SurvivorService:Respawn(player)
	local s = state(player)
	if s.status ~= "ghost" or not runs:InRun(player) then
		return
	end
	self:Spawn(player, MapLayout.spawnPoint(math.random(1, 12)))
	inventory:GiveKit(player, Constants.RESPAWN_KIT)
	inventory:Select(player, 1)
	Net.fire(player, "Toast", "You're back! Your lost pack is where you fell.", "good")
	self.Respawned:Fire(player)
end

-- Could this downed survivor still get up by themselves? The campfire's light (if the difficulty allows it), close
-- enough to crawl into before they bleed out.
function SurvivorService:_canSelfRevive(player, s)
	if s.status ~= "downed" then
		return false
	end
	local d = Formulas.difficulty(runs:Difficulty())
	if not d.fireRevive or (camp and not camp:FireLit()) then
		return false
	end
	local p = self:Position(player)
	if not p then
		return false
	end
	local fire = camp and camp:FirePosition() or MapLayout.CAMP_PROPS.fire
	local radius = camp and camp:FireRadius() or Constants.FIRE_LIGHT[1]
	local dist = math.max(0, (Vector3.new(p.X, 0, p.Z) - Vector3.new(fire.X, 0, fire.Z)).Magnitude - radius)
	local left = (s.bleedUntil or 0) - now() - (Constants.FIRE_REVIVE_SECONDS - s.fireRevive)
	return left > 0 and dist <= left * Constants.CRAWL_SPEED
end

-- The run is lost when nobody can get back up: nobody standing, no downed survivor who can still crawl to the fire,
-- and (by day) no ghost about to come back.
function SurvivorService:_checkWipe()
	if not runs:Get() or runs:Phase() == "results" then
		return
	end
	local active = runs:Active()
	if #active == 0 then
		return
	end
	for _, p in active do
		local s = st[p]
		if not s or s.status == "alive" or s.status == "waiting" then
			return
		end
		if self:_canSelfRevive(p, s) then
			return
		end
		if s.status == "ghost" and s.respawnAt and runs:IsDay() then
			return
		end
	end
	runs:Wipe()
end

-- Sprint and dodge --------------------------------------------------------------------------------------------------
function SurvivorService:SetSprint(player, on)
	local s = state(player)
	s.sprint = on == true
end

function SurvivorService:Dodge(player, dir)
	local s = state(player)
	if s.status ~= "alive" or typeof(dir) ~= "Vector3" then
		return false
	end
	local t = now()
	if t < s.dodgeReady or s.stamina < Constants.DODGE_COST then
		return false
	end
	dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude < 0.01 then
		local hrp = self:Root(player)
		dir = hrp and -hrp.CFrame.LookVector or Vector3.new(0, 0, 1)
	end
	dir = dir.Unit
	local g = inventory:Gear(player)
	s.dodgeAt = t
	s.iframeUntil = t + Constants.IFRAME_SECONDS
	s.dodgeReady = t + Constants.DODGE_COOLDOWN * g.dodgeCd
	s.stamina -= Constants.DODGE_COST
	s.lastStamina = t
	player:SetAttribute("AcGrace", t + 0.6)
	Net.fire(player, "Dash", dir, Constants.DODGE_DISTANCE, Constants.DODGE_SECONDS)
	Net.fireAll("Act", { by = player.UserId, item = "dodge", dir = dir })
	self.DodgeUsed:Fire(player)
	self:Push(player)
	return true
end

-- The loop --------------------------------------------------------------------------------------------------------------
function SurvivorService:_tick(dt)
	local t = now()
	local fire = camp and camp:FirePosition() or MapLayout.CAMP_PROPS.fire
	local fireLit = camp == nil or camp:FireLit()
	local fireRadius = camp and camp:FireRadius() or Constants.FIRE_LIGHT[1]
	local d = Formulas.difficulty(runs:Difficulty())
	local anyDowned = false
	for player, s in st do
		if not player.Parent then
			continue
		end
		local changed = false
		if s.status == "alive" then
			local hrp = self:Root(player)
			local staminaMax = self:StaminaMax(player)
			local g = inventory:Gear(player)
			local moving = hrp ~= nil and (hrp.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude > 3
			s.sprinting = s.sprint and s.stamina > 1 and moving
			if s.sprinting then
				s.stamina = math.max(0, s.stamina - Constants.SPRINT_COST * g.sprintCost * dt)
				s.lastStamina = t
				changed = true
			elseif s.stamina < staminaMax and t - s.lastStamina > Constants.STAMINA_DELAY then
				s.stamina = math.min(staminaMax, s.stamina + Constants.STAMINA_REGEN * g.staminaRegen * dt)
				changed = true
			end
			-- healing over time, the regen buff, the campfire
			local heal = 0
			for i = #s.heals, 1, -1 do
				local h = s.heals[i]
				heal += h.perSec * dt
				if t >= h.untilT then
					table.remove(s.heals, i)
				end
			end
			local regen = s.buffs.regen
			if regen and regen.untilT > t then
				heal += regen.perSec * dt
			end
			if hrp and fireLit and t - s.lastHit > Constants.REGEN_DELAY then
				if (hrp.Position - fire).Magnitude < fireRadius then
					heal += Constants.FIRE_REGEN * dt
				end
			end
			if heal > 0 and s.hp < s.maxHp then
				s.hp = math.min(s.maxHp, s.hp + heal)
				s.stats.healed += heal
				changed = true
				local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if hum then
					hum.Health = math.max(1, s.hp)
				end
			end
			-- fell out of the world
			if hrp and hrp.Position.Y < -60 then
				player:SetAttribute("AcGrace", t + 2)
				hrp.CFrame = CFrame.new(MapLayout.spawnPoint(1))
			end
		elseif s.status == "downed" then
			local hrp = self:Root(player)
			if hrp and d.fireRevive and fireLit and (hrp.Position - fire).Magnitude < fireRadius then
				s.fireRevive += dt
				changed = true
				if s.fireRevive >= Constants.FIRE_REVIVE_SECONDS then
					self:Revive(player, nil, "fire")
				end
			elseif s.fireRevive > 0 then
				s.fireRevive = 0
				changed = true
			end
			if s.status == "downed" and t >= (s.bleedUntil or math.huge) then
				self:Ghost(player)
			end
		elseif s.status == "ghost" then
			if s.respawnAt and t >= s.respawnAt and runs:IsDay() then
				self:Respawn(player)
			end
		end
		if changed and t - (s.pushed or 0) > 0.2 then
			self:Push(player)
		end
		if s.status == "downed" then
			anyDowned = true
		end
	end
	if anyDowned then
		self:_checkWipe()
	end
end

-- Revive holds: the medkit and the Medic perk make a teammate's hold finish early.
function SurvivorService:_watchHolds()
	ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt, reviver)
		local userId = prompt:GetAttribute("ReviveOf")
		if not userId then
			return
		end
		local target = Players:GetPlayerByUserId(userId)
		if not target or target == reviver then
			return
		end
		local need = self:_reviveTime(reviver)
		if need >= Constants.REVIVE_SECONDS - 0.01 then
			return
		end
		local s = state(reviver)
		local token = {}
		s.holding = token
		task.delay(need, function()
			if s.holding == token and prompt.Parent then
				local a, b = self:Position(reviver), self:Position(target)
				if a and b and (a - b).Magnitude <= 12 then
					self:Revive(target, reviver, "teammate")
				end
			end
		end)
	end)
	ProximityPromptService.PromptButtonHoldEnded:Connect(function(_, reviver)
		local s = st[reviver]
		if s then
			s.holding = nil
		end
	end)
end

function SurvivorService:Init(registry)
	data = registry.PlayerDataService
	runs = registry.RunService
	inventory = registry.InventoryService
	Net.on("Sprint", function(player, on)
		self:SetSprint(player, on)
	end)
	Net.on("Dodge", function(player, dir)
		self:Dodge(player, dir)
	end)
	Net.on("Watch", function(player, userId)
		self:Watch(player, userId)
	end)
	inventory.Equipped:Connect(function(player)
		local s = st[player]
		if s then
			s.stamina = math.min(s.stamina, self:StaminaMax(player))
			self:Push(player)
		end
	end)
	runs.Joined:Connect(function(player)
		task.spawn(self.Spawn, self, player, MapLayout.spawnPoint(#runs:Active() + math.random(0, 5)))
	end)
	runs.Waiting:Connect(function(player)
		self:SetWaiting(player)
	end)
	runs.Reset:Connect(function()
		for _, s in st do
			s.stats = { damage = 0, revives = 0, downs = 0, dodged = 0, ghosts = 0, healed = 0 }
		end
	end)
	-- the night ends: every ghost gets up at the camp (§8: back in the next stage)
	runs.DayStarted:Connect(function()
		for player, s in st do
			if s.status == "ghost" and player.Parent then
				self:Respawn(player)
			end
		end
	end)
	runs.NightStarted:Connect(function()
		for _, s in st do
			if s.status == "ghost" then
				s.respawnAt = nil -- caught by the night: wait for dawn
			end
		end
	end)
	runs.Left:Connect(function()
		task.defer(self._checkWipe, self)
	end)
	pcall(function()
		self:_watchHolds()
	end)
end

function SurvivorService:OnPlayerReady(player)
	state(player)
	data:WhenClientReady(player, function()
		self:Push(player)
	end)
end

function SurvivorService:OnPlayerLeaving(player)
	st[player] = nil
end

function SurvivorService:Start()
	local acc, teamAcc = 0, 0
	RunService_.Heartbeat:Connect(function(dt)
		acc += dt
		teamAcc += dt
		if acc >= TICK then
			self:_tick(acc)
			acc = 0
		end
		if teamAcc >= 0.5 then
			teamAcc = 0
			Net.fireAll("Team", teamView())
		end
	end)
end

return SurvivorService
