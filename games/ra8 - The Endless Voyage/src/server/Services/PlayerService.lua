--[[
Survivors on the water (master plan §6: persistent you, expedition risk). Your character spawns on your raft (the
bunk if you have one), heals while you rest on it, and can be hurt by creatures, storms and the sea. Go down and
you're back on your raft in a few seconds; if it happened away from your dock, half of this voyage's finds float
off as a lost bag where you fell (InventoryService.LoseFinds), yours to reel in or anyone's to take.

  where      raft (your own) | visiting (someone else's) | island | water, from where you stand (every 0.25 s)
  buffs      hearty (less damage), swift (faster), lucky (better casts and nets): the Cookpot's food
  the sea    swim back to a ladder; fall out of the world and you're back on deck
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local OceanLayout = require(ReplicatedStorage.Shared.World.OceanLayout)
local Signal = require(ReplicatedStorage.Shared.Signal)

local PlayerService = {
	Name = "PlayerService",
	Dependencies = { "PlayerDataService", "RaftService", "InventoryService" },
	Spawned = Signal.new("PlayerService.Spawned"), -- (player)
	Damaged = Signal.new("PlayerService.Damaged"), -- (player, amount, source)
	Healed = Signal.new("PlayerService.Healed"), -- (player, amount, by)
	Died = Signal.new("PlayerService.Died"), -- (player, source, lostItems)
	Respawned = Signal.new("PlayerService.Respawned"), -- (player)
	Moved = Signal.new("PlayerService.Moved"), -- (player, where, plot) where or plot changed
	Buffed = Signal.new("PlayerService.Buffed"), -- (player, key, seconds)
}

local data, rafts, inventory, registry
local st = {} -- [player] = state
local TICK = 0.25

local function now()
	return workspace:GetServerTimeNow()
end

local function state(player)
	local s = st[player]
	if not s then
		s = {
			hp = Constants.MAX_HP,
			maxHp = Constants.MAX_HP,
			buffs = {}, -- [key] = untilT
			where = "raft",
			plot = nil,
			lastHit = -100,
			protectUntil = 0,
			dead = false,
			respawnAt = nil,
			visiting = nil, -- the host player while you're on their raft (VisitService)
			stats = { damage = 0 },
		}
		st[player] = s
	end
	return s
end

-- Reads -----------------------------------------------------------------------------------------------------------
function PlayerService:State(player)
	return st[player]
end

function PlayerService:IsAlive(player)
	local s = st[player]
	return s ~= nil and not s.dead and s.hp > 0
end

function PlayerService:Root(player)
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

function PlayerService:Position(player)
	local root = self:Root(player)
	return root and root.Position
end

function PlayerService:Where(player)
	local s = st[player]
	return s and s.where or "raft"
end

-- The plot a player is in (their own, one they're visiting, or the nearest).
function PlayerService:Here(player)
	local s = st[player]
	return s and s.plot or rafts:PlotOf(player)
end

function PlayerService:PlayersOnPlot(plot)
	local out = {}
	for player, s in st do
		if s.plot == plot and player.Parent then
			table.insert(out, player)
		end
	end
	return out
end

function PlayerService:HasBuff(player, key)
	local s = st[player]
	local untilT = s and s.buffs[key]
	return untilT ~= nil and untilT > now()
end

function PlayerService:Luck(player)
	return self:HasBuff(player, "lucky") and 1 or 0
end

function PlayerService:MaxSpeed(player)
	return Constants.WALK_SPEED + (self:HasBuff(player, "swift") and 4 or 0)
end

function PlayerService:Visiting(player)
	local s = st[player]
	return s and s.visiting or nil
end

function PlayerService:SetVisiting(player, host)
	state(player).visiting = host
	self:Push(player)
end

-- Views -----------------------------------------------------------------------------------------------------------
function PlayerService:View(player)
	local s = state(player)
	local buffs = {}
	local t = now()
	for key, untilT in s.buffs do
		if untilT > t then
			buffs[key] = math.floor(untilT - t)
		end
	end
	return {
		hp = math.floor(s.hp + 0.5),
		maxHp = s.maxHp,
		buffs = buffs,
		where = s.where,
		plot = s.plot,
		home = rafts:PlotOf(player),
		visiting = s.visiting and s.visiting.UserId or nil,
		visitingName = s.visiting and s.visiting.DisplayName or nil,
		dead = s.dead or nil,
		respawnIn = s.respawnAt and math.max(0, math.ceil(s.respawnAt - t)) or nil,
	}
end

function PlayerService:Push(player)
	local s = state(player)
	s.pushed = now()
	Net.fire(player, "Me", self:View(player))
end

-- Characters -----------------------------------------------------------------------------------------------------
local function setupHumanoid(hum)
	hum.WalkSpeed = Constants.WALK_SPEED
	hum.UseJumpPower = false
	hum.JumpHeight = Constants.JUMP_HEIGHT
	hum.MaxHealth = Constants.MAX_HP
	hum.Health = Constants.MAX_HP
	hum.BreakJointsOnDeath = false
	pcall(function()
		hum.HealthDisplayDistance = 0
		hum.NameDisplayDistance = 80
	end)
end

-- Where you come to: your bunk or your raft (visiting: your host's raft).
function PlayerService:SpawnPoint(player)
	local s = state(player)
	local raft = s.visiting and rafts:RaftOf(s.visiting) or rafts:RaftOf(player)
	if raft then
		return rafts:SpawnPoint(raft)
	end
	return OceanLayout.SPAWN
end

function PlayerService:Spawn(player, pos)
	local s = state(player)
	s.dead = false
	s.respawnAt = nil
	s.hp = s.maxHp
	s.protectUntil = now() + Constants.SPAWN_PROTECT
	pos = pos or self:SpawnPoint(player)
	pcall(function()
		player:RequestStreamAroundAsync(pos, 8)
	end)
	player:SetAttribute("AcGrace", now() + 3)
	player:LoadCharacter()
	local c = player.Character
	if c then
		local hum = c:FindFirstChildOfClass("Humanoid")
		if hum then
			setupHumanoid(hum)
			hum.Died:Connect(function()
				self:_characterDied(player, c)
			end)
		end
		local root = c:FindFirstChild("HumanoidRootPart")
		if root then
			local center = rafts:RaftOf(player) and rafts:Center(rafts:RaftOf(player)) or Vector3.zero
			root.CFrame = CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z + 0.01))
		end
	end
	player:SetAttribute("Status", "alive")
	self:_locate(player, true)
	self:Push(player)
	self.Spawned:Fire(player)
	return c
end

-- Roblox killed the character anyway (the menu's Reset, falling out of the world): the same as going down.
function PlayerService:_characterDied(player, c)
	task.delay(0.5, function()
		if not player.Parent or player.Character ~= c then
			return
		end
		local s = state(player)
		if not s.dead then
			s.hp = 0
			self:Die(player, { kind = "fall" })
		end
	end)
end

-- Teleport (our own moves never count as cheating).
function PlayerService:Teleport(player, pos, lookAt)
	local root = self:Root(player)
	if not root then
		return false
	end
	player:SetAttribute("AcGrace", now() + 2.5)
	pcall(function()
		root.AssemblyLinearVelocity = Vector3.zero
	end)
	if lookAt then
		root.CFrame = CFrame.lookAt(pos, Vector3.new(lookAt.X, pos.Y, lookAt.Z))
	else
		root.CFrame = CFrame.new(pos)
	end
	self:_locate(player, true)
	return true
end

-- Health -----------------------------------------------------------------------------------------------------------
function PlayerService:Damage(player, amount, source)
	local s = state(player)
	if s.dead or amount <= 0 or not player.Parent then
		return 0
	end
	if now() < s.protectUntil then
		return 0
	end
	if self:HasBuff(player, "hearty") then
		amount *= 0.7
	end
	amount = math.min(s.hp, math.floor(amount + 0.5))
	s.hp -= amount
	s.lastHit = now()
	s.stats.damage += amount
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Health = math.max(1, s.hp)
	end
	Net.fire(player, "Hurt", { amount = amount, by = source and source.kind, dir = source and source.dir })
	self.Damaged:Fire(player, amount, source)
	if s.hp <= 0 then
		self:Die(player, source)
	else
		self:Push(player)
	end
	return amount
end

function PlayerService:Heal(player, amount, by)
	local s = state(player)
	if s.dead or amount <= 0 then
		return 0
	end
	local before = s.hp
	s.hp = math.min(s.maxHp, s.hp + amount)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Health = math.max(1, s.hp)
	end
	self.Healed:Fire(player, s.hp - before, by)
	self:Push(player)
	return s.hp - before
end

function PlayerService:Buff(player, key, seconds)
	local s = state(player)
	s.buffs[key] = math.max(s.buffs[key] or 0, now()) + seconds
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = self:MaxSpeed(player)
	end
	Net.fire(
		player,
		"Toast",
		key == "hearty" and "💪 Hearty: you take less damage for a while."
			or key == "swift" and "💨 Swift: faster feet for a while."
			or "🍀 Lucky: better casts and nets for a while.",
		"good"
	)
	self.Buffed:Fire(player, key, seconds)
	self:Push(player)
end

-- A sustained pose everyone sees (AnimController reads the character's "Pose" attribute): "fishing", "bite",
-- "pulling"... for `seconds` (0 clears it now; nil keeps it until cleared or replaced).
function PlayerService:SetPose(player, pose, seconds)
	local c = player.Character
	if not c then
		return
	end
	local s = state(player)
	if seconds == 0 then
		if c:GetAttribute("Pose") == pose then
			c:SetAttribute("Pose", nil)
		end
		return
	end
	c:SetAttribute("Pose", pose)
	s.poseN = (s.poseN or 0) + 1
	local n = s.poseN
	if seconds then
		task.delay(seconds, function()
			if n == s.poseN and c.Parent and c:GetAttribute("Pose") == pose then
				c:SetAttribute("Pose", nil)
			end
		end)
	end
end

-- Going down ---------------------------------------------------------------------------------------------------------
function PlayerService:Die(player, source)
	local s = state(player)
	if s.dead then
		return
	end
	s.dead = true
	s.hp = 0
	s.respawnAt = now() + Constants.RESPAWN_SECONDS
	player:SetAttribute("Status", "down")
	local pos = self:Position(player)
	local home = rafts:RaftOf(player)
	local onOwnRaft = s.where == "raft" and home ~= nil and s.plot == home.plot
	local lost = {}
	if not onOwnRaft and pos then
		lost = inventory:LoseFinds(player)
		if #lost > 0 then
			local bag =
				inventory:SpawnDrop(pos, lost, { owner = player, lost = true, seconds = Constants.LOST_BAG_SECONDS })
			Net.fire(player, "Lost", { pos = bag.pos, items = lost, seconds = Constants.LOST_BAG_SECONDS })
		end
	end
	local profile = data:Get(player)
	if profile then
		profile.stats.deaths += 1
		if #lost > 0 then
			profile.stats.bagsLost += 1
		end
	end
	local why = source and source.kind
	Net.fire(
		player,
		"Alert",
		#lost > 0 and "YOU WENT DOWN · half your finds floated off" or "YOU WENT DOWN",
		Color3.fromRGB(255, 110, 90),
		3
	)
	Net.fire(player, "Sfx", "hit")
	for _, other in Players:GetPlayers() do
		if other ~= player then
			Net.fire(other, "Fx", "down", { pos = pos, by = player.UserId })
		end
	end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = 0
		hum.JumpHeight = 0
		pcall(function()
			hum.PlatformStand = true
		end)
	end
	self:Push(player)
	self.Died:Fire(player, source, lost)
	_ = why
end

function PlayerService:Respawn(player)
	local s = state(player)
	if not s.dead then
		return
	end
	self:Spawn(player)
	Net.fire(player, "Toast", "Back on deck. Your raft heals you while you stand on it.", "info")
	self.Respawned:Fire(player)
end

-- Where you are ---------------------------------------------------------------------------------------------------
function PlayerService:_locate(player, force)
	local s = state(player)
	local pos = self:Position(player)
	if not pos then
		return
	end
	local layout = OceanLayout.plotAt(pos)
	local plot = layout and layout.index or nil
	local raft = plot and rafts:Get(plot)
	local where = "water"
	if raft and rafts:TileAt(raft, pos) then
		where = (raft.owner == player or raft.shared) and "raft" or "visiting"
	elseif plot then
		local island = registry.IslandService
		if island and island:Here(plot) and island:Ashore(plot, pos) then
			where = "island"
		end
	end
	if force or where ~= s.where or plot ~= s.plot then
		s.where, s.plot = where, plot
		rafts:SetAboard(player, raft or nil)
		self.Moved:Fire(player, where, plot)
		self:Push(player)
	end
end

function PlayerService:_tick(dt)
	local t = now()
	for player, s in st do
		if not player.Parent then
			continue
		end
		if s.dead then
			if s.respawnAt and t >= s.respawnAt then
				self:Respawn(player)
			end
			continue
		end
		self:_locate(player)
		local changed = false
		-- your raft heals you while you stand on it (never in the water, never on an island)
		if s.where == "raft" and s.hp < s.maxHp and t - s.lastHit > Constants.REGEN_DELAY then
			s.hp = math.min(s.maxHp, s.hp + Constants.HEAL_PER_SECOND_ON_RAFT * dt)
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.Health = math.max(1, s.hp)
			end
			changed = true
		end
		for key, untilT in s.buffs do
			if untilT <= t then
				s.buffs[key] = nil
				changed = true
				local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if hum then
					hum.WalkSpeed = self:MaxSpeed(player)
				end
			end
		end
		-- fell out of the world: back on deck
		local pos = self:Position(player)
		if pos and pos.Y < Constants.SEA_FLOOR - 20 then
			self:Teleport(player, self:SpawnPoint(player))
		end
		if changed and t - (s.pushed or 0) > 0.5 then
			self:Push(player)
		end
	end
end

-- Boot ----------------------------------------------------------------------------------------------------------
function PlayerService:Init(reg)
	registry = reg
	data = reg.PlayerDataService
	rafts = reg.RaftService
	inventory = reg.InventoryService
	Net.on("Emote", function(player, key)
		if type(key) == "string" and #key <= 16 and self:IsAlive(player) then
			Net.fireAll("Act", { by = player.UserId, mode = "emote", key = key })
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		task.defer(function()
			st[player] = nil
		end)
	end)
end

function PlayerService:OnPlayerReady(player)
	state(player)
	task.spawn(function()
		self:Spawn(player)
	end)
	data:WhenClientReady(player, function()
		self:Push(player)
	end)
end

function PlayerService:OnPlayerLeaving(player)
	st[player] = nil
end

function PlayerService:Start()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= TICK then
			self:_tick(acc)
			acc = 0
		end
	end)
end

return PlayerService
