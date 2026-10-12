-- Coins, gems, ore, game-pass ownership and the player list stats.
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Planets = require(ReplicatedStorage.Shared.Data.Planets)
local Shop = require(ReplicatedStorage.Shared.Data.Shop)
local Signal = require(ReplicatedStorage.Shared.Signal)

local EconomyService = {
	Name = "EconomyService",
	Dependencies = { "PlayerDataService" },
	PassesChanged = Signal.new("EconomyService.PassesChanged"), -- (player)
}

local data
local owned = {}

function EconomyService:Init(registry)
	data = registry.PlayerDataService
	data.ClientReady:Connect(function(player)
		self:PushAll(player)
	end)
end

function EconomyService:OnPlayerReady(player, profile)
	owned[player] = table.clone(profile.passes)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local coins = Instance.new("NumberValue")
	coins.Name = "Coins"
	coins.Value = profile.coins
	coins.Parent = stats
	local bosses = Instance.new("IntValue")
	bosses.Name = "Bosses"
	bosses.Value = profile.stats.bosses
	bosses.Parent = stats
	stats.Parent = player
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

function EconomyService:PushAll(player)
	local profile = data:Get(player)
	if not profile then
		return
	end
	data:Push(player, {
		coins = profile.coins,
		gems = profile.gems,
		earned = profile.earned,
		ore = table.clone(profile.ore),
		passes = self:Passes(player),
	})
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		stats.Coins.Value = math.floor(profile.coins)
		stats.Bosses.Value = profile.stats.bosses
	end
end

-- The new-player boost and VIP multiply coins (not gems or ore).
function EconomyService:CoinMult(player)
	local profile = data:Get(player)
	local mult = 1
	if profile and (profile.newBoostLeft or 0) > 0 then
		mult *= Constants.NEW_PLAYER_BOOST_MULT
	end
	return mult
end

function EconomyService:AddCoins(player, amount, countsAsEarned)
	local profile = data:Get(player)
	if not profile or amount <= 0 then
		return 0
	end
	if countsAsEarned ~= false then
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

function EconomyService:AddGems(player, amount, fromPlay)
	local profile = data:Get(player)
	if not profile or amount <= 0 then
		return 0
	end
	if fromPlay and self:HasPass(player, "GEMS2") then
		amount *= 2
	end
	profile.gems += amount
	self:PushAll(player)
	return amount
end

function EconomyService:SpendGems(player, amount)
	local profile = data:Get(player)
	if not profile or profile.gems < amount then
		return false
	end
	profile.gems -= amount
	self:PushAll(player)
	return true
end

function EconomyService:AddOre(player, planetKey, amount)
	local profile = data:Get(player)
	if not profile or amount <= 0 or not Planets.byKey[planetKey] then
		return
	end
	profile.ore[planetKey] = (profile.ore[planetKey] or 0) + amount
	self:PushAll(player)
end

function EconomyService:SpendOre(player, planetKey, amount)
	local profile = data:Get(player)
	if not profile or (profile.ore[planetKey] or 0) < amount then
		return false
	end
	profile.ore[planetKey] -= amount
	self:PushAll(player)
	return true
end

function EconomyService.oreText(planetKey, n)
	return `{Format.num(n)} {Planets.byKey[planetKey].ore}`
end

return EconomyService
