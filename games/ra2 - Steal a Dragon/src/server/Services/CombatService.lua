-- Fighting. A bonk hits the nearest player (or NPC raider) in range: they're stunned, knocked back, flash red with
-- dizzy stars, and drop any dragon they carry. Your weapon tier (Constants.WEAPONS, bought with coins) sets the
-- range, stun and knockback; Mega Bonk stuns longer; bonks inside your own base are stronger (home defense).
-- Anyone carrying a stolen dragon wears a THIEF tag with a bounty that the player who bonks them collects, and
-- bonk streaks are announced to the server.
-- Also owns walk speed (speed level, carrying slow-down, Fast Feet, stuns, potions) and the VIP name tag.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local CombatService = {
	Name = "CombatService",
	Dependencies = { "PlayerDataService", "EconomyService", "DragonService", "TeamService", "BaseService" },
	Bonked = Signal.new("CombatService.Bonked"), -- (attacker, victim, wasCarrying)
	Swung = Signal.new("CombatService.Swung"), -- (attacker) every bonk swing, hit or miss
	WeaponChanged = Signal.new("CombatService.WeaponChanged"), -- (player) bought a better weapon
	-- NPC raiders (NpcService) register here: fn() -> list of { position, carrying, model, bonk = fn(attacker, seconds,
	-- push) }, so bonks hit them like players
	npcTargets = {},
}

local data, economy, dragons, team, baseService
local lastBonk = {}
local stunnedUntil = {}
local streaks = {} -- [player] = { count, last }
local boostUntil = {} -- Speed Potion

local function humanoid(player)
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

function CombatService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	dragons = registry.DragonService
	team = registry.TeamService
	baseService = registry.BaseService
	dragons.CarryChanged:Connect(function(player)
		self:RefreshSpeed(player)
		self:_vipTag(player)
	end)
	economy.PassesChanged:Connect(function(player)
		self:RefreshSpeed(player)
		self:_vipTag(player)
	end)
	Net.on("Bonk", function(player)
		self:Bonk(player)
	end)
	Net.on("BuyWeapon", function(player)
		self:BuyWeapon(player)
	end)
	dragons.CarryChanged:Connect(function(player)
		self:_thiefTag(player)
	end)
end

function CombatService:OnPlayerReady(player)
	player.CharacterAdded:Connect(function()
		task.wait()
		self:RefreshSpeed(player)
		self:_vipTag(player)
	end)
	self:RefreshSpeed(player)
	self:_vipTag(player)
end

function CombatService:OnPlayerLeaving(player)
	lastBonk[player] = nil
	stunnedUntil[player] = nil
	streaks[player] = nil
	boostUntil[player] = nil
end

function CombatService:IsBoosted(player)
	return (boostUntil[player] or 0) > os.clock()
end

-- Speed Potion: run faster for a while (drinking another adds the time on top).
function CombatService:Boost(player, seconds)
	boostUntil[player] = math.max(boostUntil[player] or 0, os.clock()) + seconds
	self:RefreshSpeed(player)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if hrp and not hrp:FindFirstChild("SpeedFx") then
		local fx = Instance.new("ParticleEmitter")
		fx.Name = "SpeedFx"
		fx.Color = ColorSequence.new(Color3.fromRGB(90, 230, 255))
		fx.LightEmission = 0.8
		fx.Size = NumberSequence.new(0.5, 0)
		fx.Lifetime = NumberRange.new(0.3, 0.5)
		fx.Rate = 40
		fx.Speed = NumberRange.new(1, 2)
		fx.Parent = hrp
	end
	local untilTime = boostUntil[player]
	task.delay(seconds + 0.05, function()
		if boostUntil[player] == untilTime then
			boostUntil[player] = nil
			if player.Parent then
				self:RefreshSpeed(player)
			end
			local old = hrp and hrp:FindFirstChild("SpeedFx")
			if old then
				old:Destroy()
			end
		end
	end)
end

function CombatService:IsStunned(player)
	return (stunnedUntil[player] or 0) > os.clock()
end

function CombatService:RefreshSpeed(player)
	local hum = humanoid(player)
	local profile = data:Get(player)
	if not hum or not profile then
		return
	end
	if self:IsStunned(player) then
		hum.WalkSpeed = 0
		return
	end
	local c = dragons:Carrying(player)
	local speed = Formulas.walkSpeed(profile.speedLevel, c and c.rec, os.time(), economy:Passes(player))
	hum.WalkSpeed = self:IsBoosted(player) and speed * Constants.POTION_SPEED_MULT or speed
end

function CombatService:_vipTag(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head or not economy:HasPass(player, "VIP") then
		return
	end
	local existing = head:FindFirstChild("VIPTag")
	if existing then
		-- a carried dragon sits on your head and has its own name tag: hide the VIP tag so they don't overlap
		existing.Enabled = dragons:Carrying(player) == nil
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "VIPTag"
	gui.Size = UDim2.new(2.6, 0, 0.7, 0)
	gui.StudsOffset = Vector3.new(0, 1.6, 0)
	gui.MaxDistance = 40
	gui.Enabled = dragons:Carrying(player) == nil
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Text = "👑 VIP"
	t.Font = Enum.Font.LuckiestGuy
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(255, 205, 50)
	t.TextStrokeTransparency = 0
	t.Parent = gui
	gui.Parent = head
end

function CombatService:Weapon(player)
	local profile = data:Get(player)
	return Constants.WEAPONS[math.clamp(profile and profile.weaponLevel or 1, 1, #Constants.WEAPONS)]
end

-- Buy the next weapon tier with coins.
function CombatService:BuyWeapon(player)
	local profile = data:Get(player)
	if not profile then
		return
	end
	local nextW = Constants.WEAPONS[profile.weaponLevel + 1]
	if not nextW then
		Net.fire(player, "Toast", "You have the best weapon!", "info")
		return
	end
	if not economy:Spend(player, nextW.price) then
		Net.fire(player, "Toast", `You need {Format.num(nextW.price)} coins!`, "bad")
		return
	end
	profile.weaponLevel += 1
	data:Push(player, { weaponLevel = profile.weaponLevel })
	Net.fire(player, "Alert", `⚔️ New weapon: {nextW.name}!`, Color3.fromRGB(255, 205, 60))
	Net.fire(player, "Sfx", "levelup")
	self.WeaponChanged:Fire(player)
end

-- A thief tag (with the bounty) over anyone carrying a stolen dragon.
function CombatService:_thiefTag(player)
	local head = player.Character and player.Character:FindFirstChild("Head")
	if not head then
		return
	end
	local old = head:FindFirstChild("ThiefTag")
	local c = dragons:Carrying(player)
	if not c or c.kind ~= "stolen" then
		if old then
			old:Destroy()
		end
		local glow = player.Character:FindFirstChild("ThiefGlow")
		if glow then
			glow:Destroy()
		end
		return
	end
	local gui = old or Instance.new("BillboardGui")
	gui.Name = "ThiefTag"
	gui.Size = UDim2.new(6, 0, 1.4, 0)
	gui.StudsOffset = Vector3.new(0, 5.2, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 140
	gui.LightInfluence = 0
	local t = gui:FindFirstChild("Text") or Instance.new("TextLabel")
	t.Name = "Text"
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.LuckiestGuy
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(255, 90, 90)
	t.TextStrokeTransparency = 0
	t.Text = `😈 THIEF · 💰{Format.num(self:Bounty(player))}`
	t.Parent = gui
	gui.Parent = head
	if not player.Character:FindFirstChild("ThiefGlow") then
		local h = Instance.new("Highlight")
		h.Name = "ThiefGlow"
		h.FillTransparency = 1
		h.OutlineColor = Color3.fromRGB(255, 70, 70)
		h.Parent = player.Character
	end
end

-- What bonking this player pays right now (only while they carry a stolen dragon).
function CombatService:Bounty(player)
	local c = dragons:Carrying(player)
	if not c or c.kind ~= "stolen" then
		return 0
	end
	return math.max(
		Constants.BOUNTY_MIN,
		math.floor(Formulas.dragonIncome(c.rec, os.time()) * Constants.BOUNTY_SECONDS)
	)
end

-- A red flash and dizzy stars on a bonked character.
local function hitFx(character, seconds)
	if not character then
		return
	end
	local flash = Instance.new("Highlight")
	flash.Name = "HitFlash"
	flash.FillColor = Color3.fromRGB(255, 60, 60)
	flash.FillTransparency = 0.35
	flash.OutlineColor = Color3.fromRGB(255, 255, 255)
	flash.Parent = character
	task.delay(0.35, function()
		flash:Destroy()
	end)
	local head = character:FindFirstChild("Head")
	if head and not head:FindFirstChild("Dizzy") then
		local stars = Instance.new("ParticleEmitter")
		stars.Name = "Dizzy"
		stars.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		stars.Color = ColorSequence.new(Color3.fromRGB(255, 230, 90))
		stars.LightEmission = 1
		stars.Size = NumberSequence.new(0.5, 0)
		stars.Speed = NumberRange.new(1, 2)
		stars.Lifetime = NumberRange.new(0.5, 0.8)
		stars.Rate = 18
		stars.Parent = head
		task.delay(seconds, function()
			stars:Destroy()
		end)
	end
end

-- Nearest valid target in range (players and NPC rivals); ones carrying a dragon come first.
function CombatService:_target(attacker, pos, range)
	local best, bestDist, bestCarry
	local function consider(target, p, carry)
		local dist = (p - pos).Magnitude
		if dist <= range then
			if not best or (carry and not bestCarry) or (carry == bestCarry and dist < bestDist) then
				best, bestDist, bestCarry = target, dist, carry
			end
		end
	end
	for _, other in Players:GetPlayers() do
		-- players still doing the tutorial can't be bonked
		local profile = data and data:Get(other)
		local learning = profile ~= nil and not profile.tutorialDone
		if other ~= attacker and not learning and not team:AreTeam(attacker, other) then
			local op = baseService:Position(other)
			if op then
				consider(other, op, dragons:Carrying(other) ~= nil)
			end
		end
	end
	for _, provider in CombatService.npcTargets do
		for _, npc in provider() do
			consider(npc, npc.position, npc.carrying)
		end
	end
	return best
end

-- Count a hit toward the attacker's bonk streak, and tell the server at 3, 5, 10 and 20.
function CombatService:_streak(attacker)
	local s = streaks[attacker]
	local t = os.clock()
	if not s or t - s.last > Constants.STREAK_WINDOW then
		s = { count = 0, last = t }
		streaks[attacker] = s
	end
	s.count += 1
	s.last = t
	if Constants.STREAK_ANNOUNCE[s.count] then
		Net.fireAll(
			"Announce",
			`🔥 {attacker.DisplayName} is on a {s.count}-BONK STREAK!`,
			Color3.fromRGB(255, 120, 40)
		)
	end
	return s.count
end

function CombatService:Bonk(attacker)
	if (lastBonk[attacker] or -99) > os.clock() - Constants.BONK_COOLDOWN or self:IsStunned(attacker) then
		return
	end
	local pos = baseService:Position(attacker)
	if not pos then
		return
	end
	lastBonk[attacker] = os.clock()
	self.Swung:Fire(attacker)
	Net.fireAll("Sfx", "swing", pos)
	local weapon = self:Weapon(attacker)
	local home = baseService:InOwnBase(attacker)
	local range = weapon.range + (home and Constants.HOME_DEFENSE_RANGE or 0)
	local victim = self:_target(attacker, pos, range)
	if not victim then
		return
	end
	local seconds = weapon.stun
		+ (economy:HasPass(attacker, "MEGABONK") and Constants.MEGA_STUN_BONUS or 0)
		+ (home and Constants.HOME_DEFENSE_STUN or 0)
	local knock = weapon.knock
	local streak = self:_streak(attacker)

	-- an NPC rival
	if typeof(victim) == "table" then
		local push = victim.position - pos
		push = Vector3.new(push.X, 0, push.Z)
		push = push.Magnitude > 0.1 and push.Unit or Vector3.new(0, 0, 1)
		victim.bonk(attacker, seconds, push * knock)
		hitFx(victim.model, seconds)
		Net.fireAll("Popup", victim.position + Vector3.new(0, 5, 0), "BONK!", Color3.fromRGB(255, 220, 60))
		Net.fireAll("Sfx", "bonk", victim.position)
		return
	end

	local wasCarrying = dragons:Carrying(victim) ~= nil
	local bounty = self:Bounty(victim)
	stunnedUntil[victim] = os.clock() + seconds
	self:RefreshSpeed(victim)
	if wasCarrying then
		dragons:Drop(victim)
		local profile = data:Get(attacker)
		if profile then
			profile.stats.bonks += 1
		end
	end
	local vp = baseService:Position(victim)
	local hrp = victim.Character and victim.Character:FindFirstChild("HumanoidRootPart")
	if hrp and vp then
		local push = (vp - pos)
		push = Vector3.new(push.X, 0, push.Z)
		push = push.Magnitude > 0.1 and push.Unit or Vector3.new(0, 0, 1)
		hrp.AssemblyLinearVelocity = push * knock + Vector3.new(0, 20 + knock * 0.15, 0)
	end
	hitFx(victim.Character, seconds)
	Net.fire(victim, "Bonked", seconds)
	Net.fireAll(
		"Popup",
		(vp or pos) + Vector3.new(0, 5, 0),
		streak >= 3 and `BONK x{streak}!` or "BONK!",
		Color3.fromRGB(255, 220, 60)
	)
	Net.fireAll("Sfx", "bonk", vp or pos)
	if bounty > 0 then
		economy:Add(attacker, bounty)
		Net.fireAll(
			"Announce",
			`🔨 {attacker.DisplayName} stopped thief {victim.DisplayName}! +{Format.num(bounty)} bounty`,
			Color3.fromRGB(255, 205, 60)
		)
	elseif wasCarrying then
		Net.fire(attacker, "Toast", "BONK! They dropped the dragon. Grab it! 🐉", "good")
	end
	task.delay(seconds + 0.05, function()
		if victim.Parent then
			self:RefreshSpeed(victim)
		end
	end)
	self.Bonked:Fire(attacker, victim, wasCarrying)
end

return CombatService
