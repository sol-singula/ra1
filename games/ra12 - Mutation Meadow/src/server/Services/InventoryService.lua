--[[
Coins, seeds and the basket (§2 InventoryService; the items part arrives in M5).

Every coin and seed change goes through here, so M10 can log the economy from one place (Economy fires for each).
Every coin gain also counts toward lifetimeCoins; crossing a seed's lifetimeCoins gate toasts "<Seed> unlocked!".

  InventoryService.addCoins(player, n, source)
  InventoryService.spendCoins(player, n, sink) -> boolean
  InventoryService.addSeeds(player, seed, n, source)
  InventoryService.spendSeeds(player, seed, n, sink) -> boolean
  InventoryService.basketCount(profile)
  InventoryService.addToBasket(player, seed) -> boolean (false when full: the toast is sent)
  InventoryService.sellValue(player, seed)  the coins one normal crop sells for (2x Sell Cash included)
  InventoryService.Economy(player, kind, delta, reason)   kind "coins" or "seed:<key>"

Remotes: Basket:sellAll (within Config.Net.standRangeStuds of your own stand), Basket:setAutoSell (plot level
Config.Inventory.autoSellPlotLevel or more).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Shared.Signal)

local DataService = require(script.Parent.DataService)
local Guards = require(script.Parent.Parent.Net.Guards)
local NetService = require(script.Parent.NetService)
local PlotService = require(script.Parent.PlotService)
local Purchase = require(script.Parent.Parent.Purchase)

local InventoryService = {
	Economy = Signal.new(),
}

InventoryService.BASKET_FULL = "Basket full! Sell at the stand."

local function changed(player, field, value)
	NetService.change(player, { field }, value)
end

function InventoryService.addCoins(player, n, source)
	local profile = DataService.get(player)
	if not profile or n <= 0 then
		return
	end
	local before = profile.lifetimeCoins
	profile.coins += n
	profile.lifetimeCoins += n
	changed(player, "coins", profile.coins)
	changed(player, "lifetimeCoins", profile.lifetimeCoins)
	InventoryService.Economy:Fire(player, "coins", n, source)
	for _, seed in Config.Restock.order do
		local gate = Config.Seeds[seed].gate.lifetimeCoins
		if gate and before < gate and profile.lifetimeCoins >= gate then
			NetService.toast(player, "unlock", `{Config.Seeds[seed].name} unlocked!`, { seed = seed })
		end
	end
end

function InventoryService.spendCoins(player, n, sink)
	local profile = DataService.get(player)
	if not profile or n < 0 or profile.coins < n then
		return false
	end
	profile.coins -= n
	changed(player, "coins", profile.coins)
	InventoryService.Economy:Fire(player, "coins", -n, sink)
	return true
end

function InventoryService.addSeeds(player, seed, n, source)
	local profile = DataService.get(player)
	if not profile or n <= 0 or not Config.Seeds[seed] then
		return
	end
	profile.seeds[seed] = (profile.seeds[seed] or 0) + n
	changed(player, "seeds", profile.seeds)
	InventoryService.Economy:Fire(player, "seed:" .. seed, n, source)
end

function InventoryService.spendSeeds(player, seed, n, sink)
	local profile = DataService.get(player)
	local have = profile and profile.seeds[seed] or 0
	if have < n then
		return false
	end
	profile.seeds[seed] = if have - n > 0 then have - n else nil
	changed(player, "seeds", profile.seeds)
	InventoryService.Economy:Fire(player, "seed:" .. seed, -n, sink)
	return true
end

function InventoryService.basketCount(profile)
	local n = 0
	for _, count in profile.basket do
		n += count
	end
	return n
end

function InventoryService.addToBasket(player, seed)
	local profile = DataService.get(player)
	if not profile then
		return false
	end
	if InventoryService.basketCount(profile) >= Config.Inventory.basketCap then
		NetService.toast(player, "warn", InventoryService.BASKET_FULL)
		return false
	end
	profile.basket[seed] = (profile.basket[seed] or 0) + 1
	changed(player, "basket", profile.basket)
	return true
end

function InventoryService.sellValue(player, seed)
	local mult = if Purchase.owns(player, "doubleCash") then Config.Catalog.passes.doubleCash.mult else 1
	return Config.Seeds[seed].sell * mult
end

local function sellAll(player, _, profile)
	local stand = PlotService.standPart(player)
	if not stand or not Guards.near(player, stand.Position, Guards.RANGE.stand) then
		return false, "too_far"
	end
	local total = 0
	for seed, count in profile.basket do
		total += InventoryService.sellValue(player, seed) * count
	end
	if total <= 0 then
		return false, "empty"
	end
	table.clear(profile.basket)
	changed(player, "basket", profile.basket)
	InventoryService.addCoins(player, total, "sell")
	return true
end

local function setAutoSell(player, payload, profile)
	if profile.plotLevel < Config.Inventory.autoSellPlotLevel then
		return false, "locked"
	end
	profile.autoSell = payload.on
	changed(player, "autoSell", profile.autoSell)
	return true
end

function InventoryService:Init()
	NetService.on("Basket", "sellAll", nil, sellAll)
	NetService.on("Basket", "setAutoSell", nil, setAutoSell)
end

return InventoryService
