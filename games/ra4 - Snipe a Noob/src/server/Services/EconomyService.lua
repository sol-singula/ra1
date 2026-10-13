-- Coins, crate keys, XP and levels, game-pass ownership, and the player list stats (Pops, Level).
-- Coin multipliers: VIP +20%, 2x Coins, the new-player 2x boost, and the squad bonus (+10% per friend here).
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Shop = require(ReplicatedStorage.Shared.Data.Shop)
local Signal = require(ReplicatedStorage.Shared.Signal)

local EconomyService = {
	Name = "EconomyService",
	Dependencies = { "PlayerDataService", "TeamService" },
	PassesChanged = Signal.new("EconomyService.PassesChanged"), -- (player)
	LevelUp = Signal.new("EconomyService.LevelUp"), -- (player, level)
	XpGained = Signal.new("EconomyService.XpGained"), -- (player, amount)
}

local data, team
local owned = {}

function EconomyService:Init(registry)
	data = registry.PlayerDataService
	team = registry.TeamService
	data.ClientReady:Connect(function(player)
		self:PushAll(player)
	end)
end

function EconomyService:OnPlayerReady(player, profile)
	owned[player] = table.clone(profile.passes)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local pops = Instance.new("IntValue")
	pops.Name = "Pops"
	pops.Value = 0 -- this round
	pops.Parent = stats
	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Value = (Formulas.levelFromXp(profile.xp))
	level.Parent = stats
	stats.Parent = player
	player:SetAttribute("Level", level.Value)
	task.spawn(function()
		for _, pass in Shop.Passes do
			if pass.id ~= 0 then
				local ok, has =
					pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
				if ok and has and owned[player] then
					owned[player][pass.key] = true
				end
			end
		end
		if player.Parent then
			self.PassesChanged:Fire(player)
			data:Push(player, { passes = self:Passes(player) })
		end
	end)
end

function EconomyService:OnPlayerLeaving(player)
	owned[player] = nil
end

function EconomyService:Passes(player)
	return owned[player] or {}
end

function EconomyService:HasPass(player, key)
	return (owned[player] or {})[key] == true
end

function EconomyService:GrantPass(player, key)
	local profile = data:Get(player)
	if not profile or not owned[player] then
		return
	end
	owned[player][key] = true
	profile.passes[key] = true
	self.PassesChanged:Fire(player)
	data:Push(player, { passes = self:Passes(player) })
	Net.fire(player, "Owned", { [key] = true })
end

function EconomyService:Level(player)
	local profile = data:Get(player)
	return profile and (Formulas.levelFromXp(profile.xp)) or 1
end

function EconomyService:PushAll(player)
	local profile = data:Get(player)
	if not profile then
		return
	end
	local level, into, need = Formulas.levelFromXp(profile.xp)
	data:Push(player, {
		coins = profile.coins,
		keys = profile.keys,
		earned = profile.earned,
		level = level,
		xpInto = into,
		xpNeed = need,
		passes = self:Passes(player),
		boostLeft = profile.newBoostLeft or 0,
	})
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		stats.Level.Value = level
	end
	player:SetAttribute("Level", level)
end

-- Everything that multiplies coins earned from playing.
function EconomyService:CoinMult(player)
	local profile = data:Get(player)
	local mult = 1
	if profile and (profile.newBoostLeft or 0) > 0 then
		mult *= Constants.NEW_PLAYER_BOOST_MULT
	end
	if self:HasPass(player, "VIP") then
		mult *= Constants.VIP_COIN_MULT
	end
	if self:HasPass(player, "COINS2") then
		mult *= 2
	end
	mult *= team:CoinMult(player)
	return mult
end

-- Add coins. fromPlay (default true) applies the multipliers and counts toward lifetime earned.
function EconomyService:AddCoins(player, amount, fromPlay)
	local profile = data:Get(player)
	if not profile or amount <= 0 then
		return 0
	end
	if fromPlay ~= false then
		amount = math.floor(amount * self:CoinMult(player))
		profile.earned += amount
	end
	profile.coins += amount
	self:PushAll(player)
	return amount
end

function EconomyService:SpendCoins(player, amount)
	local profile = data:Get(player)
	if not profile or profile.coins < amount then
		return false
	end
	profile.coins -= amount
	self:PushAll(player)
	return true
end

function EconomyService:AddKeys(player, amount)
	local profile = data:Get(player)
	if not profile or amount <= 0 then
		return
	end
	profile.keys += amount
	self:PushAll(player)
end

function EconomyService:SpendKeys(player, amount)
	local profile = data:Get(player)
	if not profile or profile.keys < amount then
		return false
	end
	profile.keys -= amount
	self:PushAll(player)
	return true
end

-- XP: levels up (with coins and a banner) as it crosses each level.
function EconomyService:AddXp(player, amount)
	local profile = data:Get(player)
	if not profile or amount <= 0 then
		return
	end
	local before = Formulas.levelFromXp(profile.xp)
	if (profile.newBoostLeft or 0) > 0 then
		amount *= Constants.NEW_PLAYER_BOOST_MULT
	end
	profile.xp += math.floor(amount)
	self.XpGained:Fire(player, amount)
	local after = Formulas.levelFromXp(profile.xp)
	for level = before + 1, after do
		local coins = Formulas.levelCoins(level)
		profile.coins += coins
		Net.fire(player, "Alert", `⬆️ LEVEL {level}! +{coins} coins`, Color3.fromRGB(120, 220, 255))
		Net.fire(player, "Sfx", "levelup")
		self.LevelUp:Fire(player, level)
	end
	self:PushAll(player)
end

return EconomyService
