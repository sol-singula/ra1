--[[
Who is a dwarf and who is a monster (master plan §4, §10), their jobs, and their bodies.

  * Everyone starts a match as a dwarf, with the dwarf job they picked last (the Job Board changes it before
    the plague). Joining during build time: straight in as a dwarf. Joining during the fight: a monster, with a
    short hint (no fresh dwarf appears at the last stand: §12 late players never get an unfair edge).
  * The plague turns about 1 in 4 dwarves (volunteers first, then players who have no friend here, so friend
    groups stay together at the start: §19). Nobody turns in a small server: the horde attacks instead.
  * A dwarf who dies in the fight becomes a monster: never sits out (§10). They pick a monster job while they
    wait to come back at the monster spawn (the forest, or the last shrine taken). Monsters come back too,
    not too fast (§9), and grow stronger: their own level this match and the length of the fight.
  * Bodies: dwarves keep their own avatar, short and wide, with a beard, a helmet, armor and their job's tool;
    monsters get a monster body for their job (Shared/World/Costumes) in their monster skin.
Characters are loaded by the server (CharacterAutoLoads is off) so nobody appears in the wrong place.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Costumes = require(ReplicatedStorage.Shared.World.Costumes)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Jobs = require(ReplicatedStorage.Shared.Data.Jobs)
local Kit = require(ReplicatedStorage.Shared.World.Kit)
local Looks = require(ReplicatedStorage.Shared.Data.Looks)
local MapLayout = require(ReplicatedStorage.Shared.World.MapLayout)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Groups = require(script.Parent.Parent.World.Groups)

local TeamService = {
	Name = "TeamService",
	Dependencies = { "PlayerDataService", "MatchService" },
	TeamChanged = Signal.new("TeamService.TeamChanged"), -- (player, team, why) why: "start" | "join" | "plague" | "died" | "hangout"
	Spawned = Signal.new("TeamService.Spawned"), -- (player, character, team)
	Died = Signal.new("TeamService.Died"), -- (player, killer?, team, killerNpc?)
	JobChanged = Signal.new("TeamService.JobChanged"), -- (player, jobKey)
	JobPicked = Signal.new("TeamService.JobPicked"), -- (player, jobKey) a dwarf picked at a Job Board (even the same job)
	StatAdded = Signal.new("TeamService.StatAdded"), -- (player, key, n)
	LevelUp = Signal.new("TeamService.LevelUp"), -- (player, monsterLevel)
}

local data, match
local registry
local states = {} -- [player] = the player's state this match (see newState)
local descCache = {} -- [userId] = HumanoidDescription (their own avatar)
local friendsHere = {} -- [player] = true if a friend is in this server
local teamObjects = {}
local spawnCounter = 0

local function now()
	return workspace:GetServerTimeNow()
end

local STAT_KEYS = {
	"built",
	"walls",
	"traps",
	"beaten",
	"dwarvesBeaten",
	"broken",
	"gates",
	"mined",
	"healed",
	"fixed",
	"crafted",
	"heldSeconds",
	"shrines",
	"deaths",
	"damage",
}

local function newState(player)
	local profile = data:Get(player)
	local stats = {}
	for _, k in STAT_KEYS do
		stats[k] = 0
	end
	return {
		team = nil,
		job = profile and profile.dwarfJob or Jobs.DEFAULT_DWARF,
		alive = false,
		spawnedAt = 0,
		monsterXp = 0,
		monsterLevel = 1,
		gear = { armor = 0, weapon = 0 },
		food = 0,
		potions = 0,
		volunteer = false,
		stats = stats,
		matchId = match:State().id,
		respawnAt = nil,
		dwarfSince = nil, -- when they started holding as a dwarf in the fight (heldSeconds)
		lastHit = nil, -- { by = player | nil, npc = id | nil, at = time }
		turnedBy = nil, -- "plague" | "died" | "join"
	}
end

function TeamService:State(player)
	return states[player]
end

function TeamService:Team(player)
	local s = states[player]
	return s and s.team
end

function TeamService:Job(player)
	local s = states[player]
	return s and s.job
end

function TeamService:JobData(player)
	local s = states[player]
	return s and Jobs.byKey[s.job]
end

function TeamService:IsAlive(player)
	local s = states[player]
	if not s or not s.alive then
		return false
	end
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

-- Alive players on a team.
function TeamService:Players(team)
	local out = {}
	for player, s in states do
		if s.team == team and player.Parent and self:IsAlive(player) then
			table.insert(out, player)
		end
	end
	return out
end

function TeamService:DwarfCount()
	return #self:Players("dwarf")
end

-- Players on the monster team (alive or waiting to come back).
function TeamService:MonsterPlayerCount()
	local n = 0
	for player, s in states do
		if s.team == "monster" and player.Parent then
			n += 1
		end
	end
	return n
end

function TeamService:Root(player)
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

function TeamService:Position(player)
	local r = self:Root(player)
	return r and r.Position
end

-- Monster strength this match: own level and the length of the fight.
function TeamService:MonsterMult(player)
	local s = states[player]
	return Formulas.monsterMult(s and s.monsterLevel or 1, match:FightSeconds() / 60)
end

-- Add to a match stat (and everything that counts it: tasks, analytics).
function TeamService:Stat(player, key, n)
	local s = states[player]
	if not s or not n or n == 0 then
		return
	end
	s.stats[key] = (s.stats[key] or 0) + n
	self.StatAdded:Fire(player, key, n)
	if key == "built" or key == "beaten" or key == "dwarvesBeaten" or key == "broken" then
		self:_leaderstats(player)
		self:Push(player)
	end
end

function TeamService:AddMonsterXp(player, amount)
	local s = states[player]
	if not s or s.team ~= "monster" or amount <= 0 then
		return
	end
	s.monsterXp += amount
	local level = Formulas.monsterLevel(s.monsterXp)
	if level > s.monsterLevel then
		s.monsterLevel = level
		self.LevelUp:Fire(player, level)
		Net.fire(player, "Toast", `Monster level {level}! You hit harder and take more.`, "good")
		self:RefreshNameplate(player)
		Net.fire(player, "Sfx", "levelup")
		-- grow into it now: more health
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local job = Jobs.byKey[s.job]
		if hum and job and hum.Health > 0 then
			local frac = hum.Health / hum.MaxHealth
			hum.MaxHealth = math.floor(job.hp * self:MonsterMult(player))
			hum.Health = hum.MaxHealth * frac
		end
	end
	self:Push(player)
end

-- What this player's HUD shows about them in this match.
function TeamService:View(player)
	local s = states[player]
	if not s then
		return { team = false }
	end
	return {
		team = s.team or false,
		job = s.job,
		alive = self:IsAlive(player),
		level = s.monsterLevel,
		xp = s.monsterXp,
		nextXp = Formulas.monsterNextXp(s.monsterLevel),
		gear = s.gear,
		food = s.food,
		potions = s.potions,
		volunteer = s.volunteer,
		respawnAt = s.respawnAt,
		stats = s.stats,
	}
end

function TeamService:Push(player)
	if player.Parent then
		Net.fire(player, "Me", self:View(player))
	end
end

function TeamService:_leaderstats(player)
	local s = states[player]
	local ls = player:FindFirstChild("leaderstats")
	if not ls or not s then
		return
	end
	local built, beaten = ls:FindFirstChild("Built"), ls:FindFirstChild("Beaten")
	if built then
		built.Value = s.stats.built
	end
	if beaten then
		beaten.Value = s.stats.beaten + s.stats.dwarvesBeaten
	end
end

-- Bodies ------------------------------------------------------------------------------------------------------
local MONSTER_SCALE = {
	grunt = { h = 1, w = 1.08, d = 1.05, head = 1.05 },
	brute = { h = 1.3, w = 1.45, d = 1.3, head = 1.15 },
	spitter = { h = 0.95, w = 1, d = 1.05, head = 1 },
	witch = { h = 1.02, w = 0.95, d = 0.95, head = 1 },
	breaker = { h = 1, w = 1.15, d = 1.1, head = 1.05 },
}

local function ownDescription(player)
	local cached = descCache[player.UserId]
	if cached then
		return cached:Clone()
	end
	local ok, desc = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(math.max(1, player.UserId))
	end)
	if ok and desc then
		descCache[player.UserId] = desc
		return desc:Clone()
	end
	return Instance.new("HumanoidDescription")
end

local function lookFor(player, s)
	local profile = data:Get(player)
	local eq = profile and profile.looks.equipped or Looks.default
	local look = {
		team = s.team,
		job = s.job,
		armor = Looks.byKey[eq.armor],
		beard = Looks.byKey[eq.beard],
		skin = Looks.byKey[eq.skin],
		weapon = Looks.byKey[eq.weapon],
		flag = Looks.byKey[eq.flag],
	}
	return look
end
TeamService.lookFor = lookFor

local function setDescription(player, character, s)
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local desc
	if s.team == "monster" then
		local sc = MONSTER_SCALE[s.job] or MONSTER_SCALE.grunt
		local col = Costumes.monsterColors(s.job, lookFor(player, s).skin)
		desc = Instance.new("HumanoidDescription")
		desc.HeightScale, desc.WidthScale, desc.DepthScale, desc.HeadScale = sc.h, sc.w, sc.d, sc.head
		desc.BodyTypeScale, desc.ProportionScale = 0, 0
		desc.HeadColor, desc.TorsoColor = col.main, col.main
		desc.LeftArmColor, desc.RightArmColor = col.main, col.main
		desc.LeftLegColor, desc.RightLegColor = col.cloth, col.cloth
	else
		desc = ownDescription(player)
		desc.HeightScale, desc.WidthScale, desc.DepthScale, desc.HeadScale = 0.86, 1.2, 1.15, 1.18
		desc.BodyTypeScale, desc.ProportionScale = 0, 0
	end
	pcall(hum.ApplyDescription, hum, desc)
end

-- Strip what a monster shouldn't wear (their avatar's clothes, hats, face).
local function stripAvatar(character)
	for _, d in character:GetChildren() do
		if d:IsA("Accessory") or d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") or d:IsA("BodyColors") then
			d:Destroy()
		end
	end
	local head = character:FindFirstChild("Head")
	local face = head and head:FindFirstChild("face")
	if face then
		face:Destroy()
	end
end

-- Dress a character in its costume (removing any old one), welded to the body parts.
function TeamService:Dress(player, character, s)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Costume") then
			d:Destroy()
		end
	end
	local bones = {}
	for _, d in character:GetChildren() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			bones[d.Name] = d
		end
	end
	local head = bones.Head
	local rig = {
		bones = bones,
		scale = head and head.Size.Y / 1.2 or 1,
		parent = character,
		add = function(bone, part)
			part:SetAttribute("Costume", true)
			local w = Instance.new("WeldConstraint")
			w.Part0 = bones[bone]
			w.Part1 = part
			w.Parent = part
		end,
	}
	local look = lookFor(player, s)
	look.heavy = false
	if s.team == "monster" then
		stripAvatar(character)
	end
	Costumes.dress(rig, look)
end

-- The name over a character: the name in team colours, the job and level, the title.
local function nameplate(player, character, s)
	local head = character:FindFirstChild("Head")
	if not head then
		return
	end
	local old = head:FindFirstChild("Nameplate")
	if old then
		old:Destroy()
	end
	local profile = data:Get(player)
	local title = profile and Looks.titleByKey[profile.titles.equipped]
	local job = Jobs.byKey[s.job]
	local bb = Instance.new("BillboardGui")
	bb.Name = "Nameplate"
	bb.Size = UDim2.fromOffset(200, 50)
	bb.StudsOffset = Vector3.new(0, 3.2, 0)
	bb.MaxDistance = 90
	bb.LightInfluence = 0
	bb.Parent = head
	local name = Instance.new("TextLabel")
	name.Name = "Name"
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0.56, 0)
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.TextStrokeTransparency = 0.3
	name.TextColor3 = s.team == "monster" and Kit.rgb(196, 255, 120) or Kit.rgb(255, 222, 120)
	name.Text = (job and job.icon .. " " or "")
		.. player.DisplayName
		.. (s.team == "monster" and ` · Lv {s.monsterLevel}` or "")
	name.Parent = bb
	local sub = Instance.new("TextLabel")
	sub.Name = "Title"
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.new(0, 0, 0.56, 0)
	sub.Size = UDim2.new(1, 0, 0.4, 0)
	sub.Font = Enum.Font.FredokaOne
	sub.TextScaled = true
	sub.TextStrokeTransparency = 0.4
	sub.TextColor3 = Kit.rgb(255, 255, 255)
	sub.Text = title and title.name or ""
	sub.Parent = bb
	local hum = character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

-- Redraw the name over a player's head (a new title, a level up).
function TeamService:RefreshNameplate(player)
	local s = states[player]
	if s and player.Character then
		nameplate(player, player.Character, s)
	end
end

local function setCollision(character, team)
	local group = team == "dwarf" and "Dwarves" or team == "monster" and "Monsters" or "Default"
	Groups.set(character, group)
	character.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			d.CollisionGroup = group
		end
	end)
end

local function spawnCFrame(s)
	spawnCounter += 1
	local pos, facing
	if s.team == "dwarf" then
		pos = MapLayout.dwarfSpawn(match:ActiveShrine(), spawnCounter)
		facing = Vector3.new(-1, 0, 0)
	elseif s.team == "monster" then
		pos = MapLayout.monsterSpawn(match:Fallen(), spawnCounter)
		facing = Vector3.new(1, 0, 0)
	else
		pos = MapLayout.hangoutSpawn(spawnCounter)
		facing = Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(pos, pos + facing)
end

-- Put a player in the world for their team and job (yields while the character loads).
function TeamService:Spawn(player)
	local s = states[player]
	if not s or not player.Parent then
		return
	end
	s.respawnAt = nil
	s.spawning = true
	local ok, err = pcall(player.LoadCharacter, player)
	s.spawning = false
	if not ok then
		warn("[TeamService] LoadCharacter failed: " .. tostring(err))
		return
	end
	local character = player.Character
	if not character then
		return
	end
	self:_setup(player, character)
end

function TeamService:_setup(player, character)
	local s = states[player]
	local hum = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if not hum or not s then
		return
	end
	player:SetAttribute("AcGrace", now() + 3)
	character:PivotTo(spawnCFrame(s))
	setDescription(player, character, s)
	if character.Parent == nil then
		return
	end
	self:Dress(player, character, s)
	local job = Jobs.byKey[s.job]
	if s.team == "dwarf" or s.team == "monster" then
		local mult = s.team == "monster" and self:MonsterMult(player) or 1
		hum.MaxHealth = math.floor((job and job.hp or 100) * mult)
		hum.Health = hum.MaxHealth
		hum.WalkSpeed = job and job.speed or Constants.DWARF_WALK
		hum.JumpHeight = s.team == "monster" and Constants.MONSTER_JUMP or Constants.DWARF_JUMP
		if job and job.floats then
			hum.HipHeight += 1.2
		end
	else
		hum.MaxHealth = 100
		hum.Health = 100
		hum.WalkSpeed = Constants.DWARF_WALK
	end
	hum.BreakJointsOnDeath = s.team ~= "dwarf"
	hum.MaxSlopeAngle = Constants.MAX_SLOPE -- the cliffs and ridges are terrain: too steep to walk up
	character:SetAttribute("Team", s.team or "none")
	character:SetAttribute("Job", s.job)
	player:SetAttribute("Team", s.team or "none")
	player:SetAttribute("Job", s.job)
	setCollision(character, s.team)
	nameplate(player, character, s)
	s.alive = s.team ~= nil
	s.spawnedAt = now()
	character:SetAttribute("ProtectedUntil", now() + Constants.SPAWN_PROTECT)
	hum.Died:Connect(function()
		if player.Character == character then
			self:_onDied(player, character)
		end
	end)
	self:Push(player)
	self.Spawned:Fire(player, character, s.team)
end

-- Teams -------------------------------------------------------------------------------------------------------
local function setTeamObject(player, team)
	local t = team and teamObjects[team]
	pcall(function()
		player.Team = t
		player.Neutral = t == nil
	end)
end

-- Make a player a dwarf (a new match, or joining during build time).
function TeamService:MakeDwarf(player, why)
	local s = states[player]
	if not s then
		return
	end
	s.team = "dwarf"
	local profile = data:Get(player)
	local j = profile and Jobs.byKey[profile.dwarfJob]
	s.job = (j and j.team == "dwarf") and j.key or Jobs.DEFAULT_DWARF
	s.dwarfSince = match:IsFight() and now() or nil
	setTeamObject(player, "dwarf")
	self.TeamChanged:Fire(player, "dwarf", why)
	task.spawn(self.Spawn, self, player)
end

-- Turn a player into a monster. why: "plague" | "died" | "join". They come back after `delay` seconds.
function TeamService:MakeMonster(player, why, delay)
	local s = states[player]
	if not s or s.team == "monster" then
		return
	end
	if s.team == "dwarf" and s.dwarfSince then
		self:Stat(player, "heldSeconds", math.floor(now() - s.dwarfSince))
	end
	s.dwarfSince = nil
	s.team = "monster"
	s.turnedBy = why
	s.job = s.monsterJob or Jobs.DEFAULT_MONSTER
	s.monsterXp = s.monsterXp or 0
	setTeamObject(player, "monster")
	self.TeamChanged:Fire(player, "monster", why)
	s.respawnAt = now() + (delay or Constants.TURN_RESPAWN)
	self:_offerPicker(player)
	self:Push(player)
end

-- To the hangout (between matches): no team, no tool.
function TeamService:ToHangout(player)
	local s = states[player]
	if not s then
		return
	end
	if s.team == "dwarf" and s.dwarfSince then
		self:Stat(player, "heldSeconds", math.floor(now() - s.dwarfSince))
		s.dwarfSince = nil
	end
	s.team = nil
	s.respawnAt = nil
	setTeamObject(player, nil)
	self.TeamChanged:Fire(player, nil, "hangout")
	task.spawn(self.Spawn, self, player)
end

function TeamService:_offerPicker(player)
	local s = states[player]
	local list = {}
	for _, j in Jobs.monster do
		table.insert(list, {
			key = j.key,
			unlocked = Formulas.jobUnlocked(j, s.monsterLevel, match:FightSeconds()),
		})
	end
	Net.fire(player, "Picker", {
		jobs = list,
		current = s.job,
		respawnAt = s.respawnAt,
		why = s.turnedBy,
	})
end

-- Jobs ----------------------------------------------------------------------------------------------------------
local function nearJobBoard(pos)
	for _, jb in MapLayout.jobBoards do
		if (jb.pos - pos).Magnitude <= 18 then
			return true
		end
	end
	return false
end

function TeamService:SetJob(player, key)
	local s = states[player]
	local job = type(key) == "string" and Jobs.byKey[key]
	if not s or not job then
		return false, "no job"
	end
	if job.team ~= s.team then
		return false, "That's not your team's job."
	end
	if s.team == "dwarf" then
		if match:IsFight() then
			return false, "Jobs are locked once the plague comes."
		end
		local pos = self:Position(player)
		if not pos or not nearJobBoard(pos) then
			return false, "Go to a Job Board to change jobs."
		end
		self.JobPicked:Fire(player, key)
		if s.job == key then
			return true
		end
		s.job = key
		local profile = data:Get(player)
		if profile then
			profile.dwarfJob = key
		end
		-- a new tool and a new body (keep the same share of health)
		local c = player.Character
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if c and hum and hum.Health > 0 then
			local frac = hum.Health / hum.MaxHealth
			self:Dress(player, c, s)
			hum.MaxHealth = job.hp
			hum.Health = math.max(1, job.hp * frac)
			hum.WalkSpeed = job.speed
			c:SetAttribute("Job", key)
			player:SetAttribute("Job", key)
			nameplate(player, c, s)
		end
	else
		if not Formulas.jobUnlocked(job, s.monsterLevel, match:FightSeconds()) then
			return false, `{job.name} unlocks at monster level {job.unlock}.`
		end
		s.monsterJob = key
		if s.job == key then
			return true
		end
		s.job = key
		-- alive in the spawn: swap body right away; otherwise it's the body you come back with
		local pos = self:Position(player)
		local spawn = MapLayout.monsterSpawnCenter(match:Fallen())
		if self:IsAlive(player) and pos and (pos - spawn).Magnitude <= 34 then
			task.spawn(self.Spawn, self, player)
		end
	end
	self.JobChanged:Fire(player, key)
	self:Push(player)
	return true
end

-- Deaths ----------------------------------------------------------------------------------------------------
function TeamService:NoteHit(victim, byPlayer, npcId)
	local s = states[victim]
	if s then
		s.lastHit = { by = byPlayer, npc = npcId, at = now() }
	end
end

function TeamService:_onDied(player, character)
	local s = states[player]
	if not s or not s.alive then
		return
	end
	s.alive = false
	local killer, killerNpc
	if s.lastHit and now() - s.lastHit.at <= Constants.COMBAT_TAG_SECONDS then
		killer = s.lastHit.by
		killerNpc = s.lastHit.npc
	end
	if killer and (not killer.Parent or killer == player) then
		killer = nil
	end
	self:Stat(player, "deaths", 1)
	local team = s.team
	self.Died:Fire(player, killer, team, killerNpc)
	if killer then
		local ks = states[killer]
		if ks and ks.team ~= team then
			if ks.team == "monster" then
				self:Stat(killer, "dwarvesBeaten", 1)
				self:AddMonsterXp(killer, Constants.MONSTER_XP.kill)
			else
				self:Stat(killer, "beaten", 1)
			end
		end
	end
	local pos = character:FindFirstChild("HumanoidRootPart") and character.HumanoidRootPart.Position
	if team == "dwarf" then
		if match:IsFight() then
			Net.fireAll("Fx", "turn", { position = pos, userId = player.UserId })
			Net.fire(player, "Alert", "You fell... and rose as a MONSTER!", Kit.C.plague, 3)
			self:MakeMonster(player, "died", Constants.TURN_RESPAWN)
			match:CheckEnd()
		else
			s.respawnAt = now() + Constants.BUILD_RESPAWN
			self:Push(player)
		end
	elseif team == "monster" then
		local late = match:FightSeconds() >= 360
		s.respawnAt = now() + (late and Constants.MONSTER_RESPAWN_LATE or Constants.MONSTER_RESPAWN)
		self:_offerPicker(player)
		self:Push(player)
	end
end

-- The plague: pick who turns (volunteers first, then players without a friend here), and turn them.
function TeamService:Plague()
	local dwarves = self:Players("dwarf")
	local n = Formulas.plagueCount(#dwarves)
	if n <= 0 then
		return {}
	end
	local pool = {}
	for _, p in dwarves do
		local s = states[p]
		local score = math.random()
		if s.volunteer then
			score -= 10
		end
		if friendsHere[p] then
			score += 2
		end
		table.insert(pool, { p = p, score = score })
	end
	table.sort(pool, function(a, b)
		return a.score < b.score
	end)
	local picked = {}
	for i = 1, math.min(n, #pool) do
		local p = pool[i].p
		table.insert(picked, p)
		local profile = data:Get(p)
		if profile then
			profile.stats.turned += 1
		end
		Net.fireAll("Fx", "plague", { userId = p.UserId, position = self:Position(p) })
		Net.fire(p, "Alert", "The plague got you! You're a MONSTER now!", Kit.C.plague, 4)
		self:MakeMonster(p, "plague", Constants.PLAGUE_SECONDS - 1)
	end
	return picked
end

-- Requests ----------------------------------------------------------------------------------------------------
function TeamService:Init(reg)
	registry = reg
	data = reg.PlayerDataService
	match = reg.MatchService
	for _, spec in
		{
			{ "dwarf", "Dwarves", "Bright orange" },
			{ "monster", "Monsters", "Lime green" },
		}
	do
		local t = Teams:FindFirstChild(spec[2]) or Instance.new("Team")
		t.Name = spec[2]
		t.AutoAssignable = false
		pcall(function()
			t.TeamColor = BrickColor.new(spec[3])
		end)
		t.Parent = Teams
		teamObjects[spec[1]] = t
	end

	Net.on("Job", function(player, key)
		local ok, why = self:SetJob(player, key)
		if not ok and why then
			Net.fire(player, "Toast", why, "bad")
		end
	end)
	Net.on("Volunteer", function(player, on)
		local s = states[player]
		if s and s.team == "dwarf" and match:Phase() == "build" then
			s.volunteer = on == true
			Net.fire(
				player,
				"Toast",
				s.volunteer and "You'll be one of the monsters when the plague comes!"
					or "OK, you'll stay a dwarf if you can.",
				"info"
			)
			self:Push(player)
		end
	end)

	match.Started:Connect(function()
		for player, s in states do
			local fresh = newState(player)
			fresh.volunteer = false
			states[player] = fresh
			_ = s
			self:MakeDwarf(player, "start")
		end
	end)
	match.FightStarted:Connect(function()
		for player, s in states do
			if s.team == "dwarf" then
				s.dwarfSince = now()
			end
			self:Push(player)
		end
	end)
	match.Plague:Connect(function()
		self:Plague()
	end)
	match.Ended:Connect(function()
		for player, s in states do
			if s.team == "dwarf" and s.dwarfSince then
				self:Stat(player, "heldSeconds", math.floor(now() - s.dwarfSince))
				s.dwarfSince = nil
			end
			s.respawnAt = nil
		end
	end)
	match.Reset:Connect(function()
		for player in states do
			self:ToHangout(player)
		end
	end)
	match.ShrineFell:Connect(function()
		-- monsters waiting to come back will come back at the new spawn; tell them where
		for player, s in states do
			if s.team == "monster" then
				self:Push(player)
			end
		end
	end)
end

function TeamService:Start()
	while true do
		task.wait(0.25)
		local t = now()
		for player, s in states do
			if s.respawnAt and t >= s.respawnAt and not s.spawning and player.Parent and match:InMatch() then
				s.respawnAt = nil
				task.spawn(self.Spawn, self, player)
			end
		end
	end
end

function TeamService:OnPlayerReady(player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	for _, n in { "Built", "Beaten" } do
		local v = Instance.new("IntValue")
		v.Name = n
		v.Parent = ls
	end
	ls.Parent = player
	states[player] = newState(player)
	task.spawn(function()
		for _, other in Players:GetPlayers() do
			if other ~= player then
				local ok, yes = pcall(player.IsFriendsWith, player, other.UserId)
				if ok and yes then
					friendsHere[player] = true
					friendsHere[other] = true
				end
			end
		end
	end)
	local phase = match:Phase()
	if phase == "build" then
		self:MakeDwarf(player, "join")
	elseif match:IsFight() then
		self:MakeMonster(player, "join", 1)
		Net.fire(player, "Alert", "The monsters are attacking! Join them: smash the castle!", Kit.C.plague, 4)
	else
		self:ToHangout(player)
	end
end

function TeamService:OnPlayerLeaving(player)
	local s = states[player]
	if s and s.team == "dwarf" and s.dwarfSince then
		self:Stat(player, "heldSeconds", math.floor(now() - s.dwarfSince))
		s.dwarfSince = nil
	end
	-- left the match: keep the state until the rewards are paid (ProgressService reads it), then forget
	task.defer(function()
		states[player] = nil
		friendsHere[player] = nil
		descCache[player.UserId] = nil
		match:CheckEnd()
	end)
end

-- (tests)
function TeamService:_states()
	return states
end
_ = registry

return TeamService
