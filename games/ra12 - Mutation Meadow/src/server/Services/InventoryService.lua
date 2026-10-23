--[[
Coins, seeds, the basket, and kept items with their pedestals (§2 InventoryService).

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

Kept items: harvesting a mutated crop mints an item (ItemModel.mint) that carries the mutation. The Backpack holds
Config.Inventory.backpackByPlotLevel[level] items, counting displayed ones. An item sells for sell x mutation mult
(x2 with 2x Sell Cash). Pedestals: pedestalsByPlotLevel[level], +1 once the collection has collectionPedestalAt
finds, at most pedestalMax; a displayed item is locked.

  InventoryService.backpackCap(profile) / itemCount(profile)
  InventoryService.itemPrice(player, item)
  InventoryService.keepCrop(player, profile, tile, onFull) -> ok, code   (FarmService, for a ripe mutated crop):
      true (minted) | true, "left" (onFull "leave": untouched) | true, "sold" (onFull "sell") | false, "backpack_full"
  InventoryService.pedestalCount(profile)
  InventoryService.renderPedestals(player)
  InventoryService.ItemKept(player, guid, item) / ItemSold(player, item, coins) / Displayed(player, guid, slot)

Remotes: Basket:sellAll (within Config.Net.standRangeStuds of your own stand), Basket:setAutoSell (plot level
Config.Inventory.autoSellPlotLevel or more), Inventory:sellItem {id} (not locked), Inventory:display {id, pedestal},
Inventory:undisplay {pedestal}.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local MutationMath = require(ReplicatedStorage.Shared.MutationMath)
local Signal = require(ReplicatedStorage.Shared.Signal)

local DataService = require(script.Parent.DataService)
local ItemModel = require(script.Parent.Parent.Items.ItemModel)
local Guards = require(script.Parent.Parent.Net.Guards)
local NetService = require(script.Parent.NetService)
local PlotService = require(script.Parent.PlotService)
local Purchase = require(script.Parent.Parent.Purchase)

local InventoryService = {
	Economy = Signal.new(),
	ItemKept = Signal.new(),
	ItemSold = Signal.new(),
	Displayed = Signal.new(),
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

---------------------------------------------------------------------------------------------------------------
-- kept items

local names = {} -- [userId] = name (GetNameFromUserIdAsync is slow and rate-limited)

local function nameOf(userId)
	if names[userId] == nil then
		local ok, name = pcall(function()
			return Players:GetNameFromUserIdAsync(userId)
		end)
		if not ok then
			return "a farmer" -- not cached: try again next time
		end
		names[userId] = name
	end
	return names[userId]
end

function InventoryService.backpackCap(profile)
	local list = Config.Inventory.backpackByPlotLevel
	return list[profile.plotLevel] or list[#list]
end

function InventoryService.itemCount(profile)
	local n = 0
	for _ in profile.items do
		n += 1
	end
	return n
end

function InventoryService.itemPrice(player, item)
	local mult = if Purchase.owns(player, "doubleCash") then Config.Catalog.passes.doubleCash.mult else 1
	return MutationMath.value(item.seed, item.muts) * mult
end

function InventoryService.keepCrop(player, profile, tile, onFull)
	if InventoryService.itemCount(profile) >= InventoryService.backpackCap(profile) then
		if onFull == "sell" then
			InventoryService.addCoins(player, InventoryService.itemPrice(player, tile), "sellCrop")
			return true, "sold"
		elseif onFull == "leave" then
			return true, "left"
		end
		return false, "backpack_full"
	end
	local guid, item = ItemModel.mint(profile, player.UserId, tile.seed, tile.muts)
	changed(player, "items", profile.items)
	InventoryService.ItemKept:Fire(player, guid, item)
	return true
end

function InventoryService.pedestalCount(profile)
	local cfg = Config.Inventory
	local n = cfg.pedestalsByPlotLevel[profile.plotLevel] or cfg.pedestalsByPlotLevel[#cfg.pedestalsByPlotLevel]
	local found = 0
	for _ in profile.collection.found do
		found += 1
	end
	if found >= cfg.collectionPedestalAt then
		n += 1
	end
	return math.min(n, cfg.pedestalMax)
end

function InventoryService.renderPedestals(player)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local unlocked = InventoryService.pedestalCount(profile)
	for i = 1, Config.Inventory.pedestalMax do
		local part = PlotService.pedestalPart(player, i)
		if part then
			local guid = profile.pedestals[tostring(i)]
			local item = guid and profile.items[guid]
			part:SetAttribute("Unlocked", i <= unlocked)
			part:SetAttribute("ItemId", if item then guid else nil)
			part:SetAttribute("ItemSeed", item and item.seed)
			part:SetAttribute("ItemMuts", item and MutationMath.key(item.muts))
			part:SetAttribute(
				"ItemLabel",
				item
					and `{MutationMath.label(item.muts)} {Config.Seeds[item.seed].name}\nfound by {nameOf(item.foundBy)}`
			)
		end
	end
end

local function itemFor(player, profile, guid)
	local item = profile.items[guid]
	if item and item.locked then
		return nil, "locked"
	end
	if not Guards.ownsItem(profile, guid, player.UserId) then
		return nil, "ownership"
	end
	return item
end

local function sellItem(player, payload, profile)
	local item, code = itemFor(player, profile, payload.id)
	if not item then
		return false, code
	end
	local coins = InventoryService.itemPrice(player, item)
	profile.items[payload.id] = nil
	ItemModel.registry[payload.id] = nil
	changed(player, "items", profile.items)
	InventoryService.addCoins(player, coins, "sellItem")
	InventoryService.ItemSold:Fire(player, item, coins)
	return true
end

local function display(player, payload, profile)
	local slot = payload.pedestal
	if slot > InventoryService.pedestalCount(profile) then
		return false, "pedestal_locked"
	end
	if profile.pedestals[tostring(slot)] then
		return false, "pedestal_taken"
	end
	local item, code = itemFor(player, profile, payload.id)
	if not item then
		return false, code
	end
	profile.pedestals[tostring(slot)] = payload.id
	item.locked = true
	changed(player, "pedestals", profile.pedestals)
	changed(player, "items", profile.items)
	InventoryService.renderPedestals(player)
	InventoryService.Displayed:Fire(player, payload.id, slot)
	return true
end

local function undisplay(player, payload, profile)
	local key = tostring(payload.pedestal)
	local guid = profile.pedestals[key]
	if not guid then
		return false, "empty"
	end
	profile.pedestals[key] = nil
	local item = profile.items[guid]
	if item and not profile.outbox[guid] then
		item.locked = false -- a pending gift keeps its own lock
	end
	changed(player, "pedestals", profile.pedestals)
	changed(player, "items", profile.items)
	InventoryService.renderPedestals(player)
	return true
end

function InventoryService:Init()
	NetService.on("Basket", "sellAll", nil, sellAll)
	NetService.on("Basket", "setAutoSell", nil, setAutoSell)
	NetService.on("Inventory", "sellItem", nil, sellItem)
	NetService.on("Inventory", "display", nil, display)
	NetService.on("Inventory", "undisplay", nil, undisplay)
end

function InventoryService:OnPlayerLoaded(player)
	InventoryService.renderPedestals(player)
end

return InventoryService
