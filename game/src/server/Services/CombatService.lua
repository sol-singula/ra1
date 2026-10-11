-- Player HP, hit validation, abilities, thrown food and KO/respawn (GDD §27.8.7, canon C12).
-- MVP kit: ABL_001 Swipe Combo, ABL_006 Calm Down!, and the equipped mutation's ability.
-- KO never costs mutations, items or currency: the player respawns in the kitchen at 60 % HP, a bit woozy.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local CombatService = {
	Name = "CombatService",
	Dependencies = {
		"PlayerDataService",
		"ProgressionService",
		"MutationService",
		"RestaurantService",
		"RepairService",
	},
	KnockedOut = Signal.new("CombatService.KnockedOut"), -- (player, sourceCustomer?)
}

local data, progression, mutations, restaurantSvc, repair
local customers -- set by CustomerAIService (it depends on us, so it registers itself)
local state = {} -- [player] = { hp, maxHp, koUntil, woozyUntil, cooldowns, combo, comboAt }

local function now()
	return workspace:GetServerTimeNow()
end

local function hrpOf(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

function CombatService:SetCustomerProvider(provider)
	customers = provider
end

function CombatService:_push(player)
	local s = state[player]
	if s then
		data:Push(player, { hp = math.ceil(s.hp), maxHp = s.maxHp })
	end
end

function CombatService:ApplyWalkSpeed(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local s = state[player]
	if not humanoid or not s then
		return
	end
	if s.koUntil > now() then
		humanoid.WalkSpeed = 0
		return
	end
	local speed = Formulas.walkSpeed(progression:Stat(player, "MOVE"))
	if s.woozyUntil > now() then
		speed *= Constants.WOOZY_MOVE
	end
	humanoid.WalkSpeed = speed
end

function CombatService:IsKO(player)
	local s = state[player]
	return s ~= nil and s.koUntil > now()
end

-- `source` is the customer who dealt the damage; whoever lands the knock-out does a victory dance and leaves.
function CombatService:DamagePlayer(player, amount, source)
	local s = state[player]
	local hrp = hrpOf(player)
	if not s or not hrp or s.koUntil > now() then
		return
	end
	local dealt = amount * Formulas.damageTakenMult(progression:Stat(player, "DEF"))
	s.hp = math.max(0, s.hp - dealt)
	s.inCombatUntil = now() + Constants.IN_COMBAT_SECONDS
	Net.fireAll("Popup", hrp.Position + Vector3.new(0, 3, 0), `-{math.ceil(dealt)}`, Color3.fromRGB(255, 75, 62))
	self:_push(player)
	if s.hp <= 0 then
		self:_knockOut(player, source)
	end
end

function CombatService:_knockOut(player, source)
	local s = state[player]
	s.koUntil = now() + Constants.KO_SECONDS
	self:ApplyWalkSpeed(player)
	Net.fire(player, "KO", Constants.KO_SECONDS)
	self.KnockedOut:Fire(player, source)
	task.delay(Constants.KO_SECONDS, function()
		if not state[player] then
			return
		end
		s.hp = s.maxHp * Constants.KO_RESPAWN_HP
		s.woozyUntil = now() + Constants.WOOZY_SECONDS
		local r = restaurantSvc:Get(player)
		if r and player.Character then
			player.Character:PivotTo(r.layout.kitchenSpawn)
		end
		self:ApplyWalkSpeed(player)
		self:_push(player)
		task.delay(Constants.WOOZY_SECONDS + 0.1, function()
			if state[player] then
				self:ApplyWalkSpeed(player)
			end
		end)
	end)
end

-- Customers of this player's restaurant inside a cone in front of the character.
function CombatService:_targets(player, range, arc, max)
	local hrp = hrpOf(player)
	if not hrp or not customers then
		return {}
	end
	local look = hrp.CFrame.LookVector * Vector3.new(1, 0, 1)
	local found = {}
	for _, c in customers:InRestaurant(restaurantSvc:Get(player)) do
		local offset = (c.pos - hrp.Position) * Vector3.new(1, 0, 1)
		local dist = offset.Magnitude
		if dist <= range + 1.5 then -- +1.5 for the proxy's own width and network tolerance
			local angle = dist > 0.01 and math.deg(math.acos(math.clamp(look.Unit:Dot(offset.Unit), -1, 1))) or 0
			if angle <= arc / 2 then
				table.insert(found, { c = c, dist = dist })
			end
		end
	end
	table.sort(found, function(a, b)
		return a.dist < b.dist
	end)
	local out = {}
	for i = 1, math.min(max, #found) do
		out[i] = found[i].c
	end
	return out
end

function CombatService:_ready(player, abilityId)
	local s = state[player]
	if not s or s.koUntil > now() then
		return false
	end
	local readyAt = s.cooldowns[abilityId] or 0
	if now() < readyAt then
		return false
	end
	s.cooldowns[abilityId] = now() + Constants.ABILITIES[abilityId].cooldown
	if abilityId ~= "ABL_001" then
		Net.fire(player, "Cooldown", abilityId, Constants.ABILITIES[abilityId].cooldown)
	end
	return true
end

function CombatService:_hit(player, list, damage, label)
	local str = progression:Stat(player, "STR")
	for _, c in list do
		customers:Hit(c, Formulas.damageToCustomer(damage, str, c.personality.def), player, label)
	end
	if #list > 0 then
		state[player].inCombatUntil = now() + Constants.IN_COMBAT_SECONDS
	end
end

function CombatService:_attack(player)
	if not self:_ready(player, "ABL_001") then
		return
	end
	local s = state[player]
	local spec = Constants.ABILITIES.ABL_001
	s.combo = (now() - s.comboAt <= spec.chainReset) and (s.combo % 3) + 1 or 1
	s.comboAt = now()
	local label = s.combo == 3 and "BIF!" or nil
	self:_hit(player, self:_targets(player, spec.range, spec.arc, spec.targets), spec.damage[s.combo], label)
end

function CombatService:_ability(player, abilityId)
	if abilityId == "ABL_006" then
		if not customers then
			return
		end
		local hrp = hrpOf(player)
		local target = hrp
			and customers:NearestAngry(restaurantSvc:Get(player), hrp.Position, Constants.ABILITIES.ABL_006.range)
		if not target then
			Net.fire(player, "Toast", "Nobody nearby needs calming down.", "info")
			return
		end
		if self:_ready(player, "ABL_006") then
			customers:Calm(target, player, progression:Stat(player, "CHARM"))
		end
		return
	end
	if abilityId ~= mutations:Ability(player) or not Constants.ABILITIES[abilityId] then
		return
	end
	local spec = Constants.ABILITIES[abilityId]
	if abilityId == "ABL_062" then
		local hrp = hrpOf(player)
		if hrp and self:_ready(player, abilityId) then
			local n = repair:Burst(player, hrp.Position)
			Net.fire(
				player,
				"Toast",
				n > 0 and `Repair Burst fixed {n} piece(s)!` or "Nothing broken nearby.",
				n > 0 and "good" or "info"
			)
		end
		return
	end
	if self:_ready(player, abilityId) then
		local label = abilityId == "ABL_012" and "POP-POP!" or "SNIP-YEET!"
		local list = self:_targets(player, spec.range, spec.arc, spec.targets)
		self:_hit(player, list, spec.damage, label)
		if abilityId == "ABL_017" then
			for _, c in list do
				customers:Stagger(c, 0.6) -- STS_KNOCKDOWN on landing
			end
		end
	end
end

-- A customer lobs food at a player along a scripted arc (no physics). Whoever is near the landing spot when it
-- lands gets hit: the target player, or another customer, which starts a whole new argument.
function CombatService:ThrowFood(fromPos, player, dmgMult, color, thrower)
	local hrp = hrpOf(player)
	if not hrp then
		return
	end
	local to = hrp.Position + hrp.AssemblyLinearVelocity * Vector3.new(1, 0, 1) * 0.3 -- leads the target a little
	Net.fireAll("Projectile", fromPos, to, Constants.THROWN_FOOD_FLIGHT, color)
	task.delay(Constants.THROWN_FOOD_FLIGHT, function()
		local current = hrpOf(player)
		if current and (current.Position - to).Magnitude <= Constants.THROWN_FOOD_HIT_RADIUS then
			self:DamagePlayer(player, Constants.THROWN_FOOD_DAMAGE * dmgMult, thrower)
		elseif customers then
			customers:HitByFood(to, thrower)
		end
	end)
end

local function setup(self, player)
	local maxHp = Formulas.maxHp(progression:Level(player), 0)
	local s = state[player]
	if not s then
		s = {
			hp = maxHp,
			maxHp = maxHp,
			koUntil = 0,
			woozyUntil = 0,
			inCombatUntil = 0,
			cooldowns = {},
			combo = 0,
			comboAt = 0,
		}
		state[player] = s
	end
	s.maxHp = maxHp
	self:ApplyWalkSpeed(player)
	self:_push(player)
end

function CombatService:Init(registry)
	data = registry.PlayerDataService
	progression = registry.ProgressionService
	mutations = registry.MutationService
	restaurantSvc = registry.RestaurantService
	repair = registry.RepairService

	Net.on("Attack", function(player)
		self:_attack(player)
	end)
	Net.on("Ability", function(player, abilityId)
		if typeof(abilityId) == "string" then
			self:_ability(player, abilityId)
		end
	end)
	progression.LevelChanged:Connect(function(player)
		local s = state[player]
		if s then
			local maxHp = Formulas.maxHp(progression:Level(player), 0)
			s.hp += maxHp - s.maxHp
			s.maxHp = maxHp
			self:_push(player)
		end
	end)
	progression.StatsChanged:Connect(function(player)
		self:ApplyWalkSpeed(player)
	end)
	data.ClientReady:Connect(function(player)
		self:_push(player)
	end)
end

function CombatService:OnPlayerReady(player)
	setup(self, player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid then
			return
		end
		-- the default Humanoid health is unused; HP lives in this service so nobody ever "dies"
		humanoid.BreakJointsOnDeath = false
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
		local s = state[player]
		if s then
			s.hp = s.maxHp
			s.koUntil = 0
		end
		setup(self, player)
	end)
end

function CombatService:OnPlayerLeaving(player)
	state[player] = nil
end

function CombatService:Start()
	-- slow out-of-combat regeneration: 2 % of max HP per second after 6 s without combat
	while true do
		task.wait(1)
		local t = now()
		for player, s in state do
			if s.koUntil < t and s.inCombatUntil < t and s.hp < s.maxHp and player.Parent == Players then
				s.hp = math.min(s.maxHp, s.hp + s.maxHp * 0.02)
				self:_push(player)
			end
		end
	end
end

return CombatService
