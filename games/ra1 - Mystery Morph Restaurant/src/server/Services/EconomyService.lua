-- The only module that changes currency (GDD §27.8.12). Balances are whole numbers and never go below 0.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Signal)

local EconomyService = {
	Name = "EconomyService",
	Dependencies = { "PlayerDataService" },
	Changed = Signal.new("EconomyService.Changed"), -- (player, currency, delta, reason)
}

local CURRENCY_FIELD = { MB = "mb", MS = "ms" }
local data

function EconomyService:Init(registry)
	data = registry.PlayerDataService
	data.ClientReady:Connect(function(player)
		self:PushWallet(player)
	end)
end

function EconomyService:OnPlayerReady(player)
	self:PushWallet(player)
end

function EconomyService:PushWallet(player)
	local profile = data:Get(player)
	if profile then
		data:Push(player, { mb = profile.mb, ms = profile.ms })
	end
end

function EconomyService:Balance(player, currency)
	local profile = data:Get(player)
	return profile and profile[CURRENCY_FIELD[currency]] or 0
end

function EconomyService:Grant(player, currency, amount, reason)
	local profile = data:Get(player)
	local field = CURRENCY_FIELD[currency]
	amount = math.floor(amount)
	if not profile or not field or amount <= 0 then
		return false
	end
	profile[field] += amount
	if currency == "MB" then
		profile.lifetime.earned += amount
	end
	self.Changed:Fire(player, currency, amount, reason)
	self:PushWallet(player)
	return true
end

-- Returns false (and changes nothing) when the player cannot afford it.
function EconomyService:Spend(player, currency, amount, reason)
	local profile = data:Get(player)
	local field = CURRENCY_FIELD[currency]
	amount = math.ceil(amount)
	if not profile or not field or amount < 0 or profile[field] < amount then
		return false
	end
	profile[field] -= amount
	self.Changed:Fire(player, currency, -amount, reason)
	self:PushWallet(player)
	return true
end

-- Charge up to `amount` without going below 0 (waste at the trash, §C9). Returns what was charged.
function EconomyService:ChargeUpTo(player, currency, amount, reason)
	local profile = data:Get(player)
	local field = CURRENCY_FIELD[currency]
	if not profile or not field then
		return 0
	end
	local charged = math.min(profile[field], math.floor(amount))
	if charged > 0 then
		profile[field] -= charged
		self.Changed:Fire(player, currency, -charged, reason)
		self:PushWallet(player)
	end
	return charged
end

return EconomyService
