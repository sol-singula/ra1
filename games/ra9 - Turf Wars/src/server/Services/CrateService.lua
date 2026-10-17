--[[
The Crate (the lobby only: Modes = { "lobby" }; Data/Crate has the odds and the pool, Data/Shop.CRATE the prices):
a spin for Shards or for Robux, rolled here and never on the client, granted through EconomyService and saved
straight away. A duplicate (only once the pool is all theirs) gives half the Shards back. The Robux spin is a
developer product: ShopService grants it (ShopService.handlers.crate) once the receipt is in, free in Studio while
its id is 0. Cosmetic, all of it.

  Net "Crate" ("spin", "shards" | "robux")
  Net "Crate" -> { key, kind, name, rarity, dup, refund, paid = "shards" | "robux" }   (a refusal is a Toast)
  CrateService:Spin(player, paid) -> result | nil, why
  CrateService.rng          the Random the rolls use (tests seed it)
  CrateService.Spun         (player, item, paid, dup)
  analytics: crate_spin { kind, key, rarity, paid }
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Crate = require(ReplicatedStorage.Shared.Data.Crate)
local Locker = require(ReplicatedStorage.Shared.Data.Locker)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local CrateService = {
	Name = "CrateService",
	Modes = { "lobby" },
	Dependencies = { "PlayerDataService", "EconomyService", "ProgressService", "ShopService" },
	Spun = Signal.new("CrateService.Spun"),
	rng = Random.new(),
}

local data, economy, progress, shop, registryRef

local function say(player, text, kind)
	Net.fire(player, "Toast", text, kind or "info")
end

function CrateService:Spin(player, paid)
	local p = data:Get(player)
	if not p then
		return nil, "bad"
	end
	if paid == "shards" then
		if not economy:Spend(player, Crate.PRICE) then
			return nil, `You need {Crate.PRICE - (p.shards or 0)} more Shards.`
		end
	elseif paid ~= "robux" then
		return nil, "bad"
	end
	local key, dup = Crate.roll(self.rng, function(k)
		return Locker.owns(p, k)
	end)
	local it = Cosmetics.get(key)
	local refund = 0
	if dup then
		refund = Crate.refund()
		economy:Add(player, refund, "crate_dup")
	else
		economy:Give(player, key)
	end
	p.stats.crateSpins = (p.stats.crateSpins or 0) + 1
	local result = {
		key = key,
		kind = it.kind,
		name = it.name,
		rarity = it.rarity,
		dup = dup,
		refund = refund,
		paid = paid,
	}
	progress:Push(player)
	Net.fire(player, "Crate", result)
	local analytics = registryRef.AnalyticsService
	if analytics and analytics.event then
		pcall(analytics.event, player, "crate_spin", { kind = it.kind, key = key, rarity = it.rarity, paid = paid })
	end
	self.Spun:Fire(player, it, paid, dup)
	data:Save(player) -- (theirs now, whatever happens next)
	return result
end

function CrateService:Init(registry)
	registryRef = registry
	data = registry.PlayerDataService
	economy = registry.EconomyService
	progress = registry.ProgressService
	shop = registry.ShopService
	-- (the Robux spin: ShopService's receipt, then this)
	shop.handlers[Crate.PRODUCT.key] = function(player)
		self:Spin(player, "robux")
	end
	Net.on("Crate", function(player, action, how)
		if action ~= "spin" then
			return
		end
		if how == "robux" then
			local ok, why = shop:PromptRobux(player, Crate.PRODUCT.key)
			if ok == false and why and why ~= "bad" then
				say(player, why, "bad")
			end
			return
		end
		local result, why = self:Spin(player, "shards")
		if not result and why and why ~= "bad" then
			say(player, why, "bad")
			progress:Push(player)
		end
	end)
end

return CrateService
