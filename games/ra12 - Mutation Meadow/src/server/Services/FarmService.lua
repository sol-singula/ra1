--[[
Planting, growing, harvesting and upgrades (§2 FarmService).

Growth ticks on the server every Config.Upgrades.growTickSec: each growing tile gains dt x rate boosted seconds
(Growth.rate: sprinkler x (1 + friend boost) x weather). Clients animate from the tile attributes PlotService sets.

Remotes:
  Plot:plant {tile, seed}        an empty active tile of your own (no sprinkler), within Config.Net.tileRangeStuds,
                                 one seed spent
  Plot:harvest {tile, onFull?}   a ripe tile: a normal crop sells (Auto-Sell) or goes to the basket; a full basket
                                 refuses with a toast unless onFull = "sell" sells that one crop now. Mutated crops
                                 go to MutationService (M5) when it exists. Then harvestsLeft - 1: regrow or clear.
  Plot:harvestAll {}             every ripe normal crop (the Welcome-back card); mutated ones wait for a tap
  Plot:water {tile, ownerId?}    your own growing tile: the can (Growth.useCan); someone else's: a help
                                 (SocialService.helpWater)
  Plot:sprinkler {kind, tile}    places an owned, unplaced sprinkler on an empty main tile of yours
  Plot:pickup {tile}             takes it back
  Upgrade:buy {kind}             "plot" (next level, plotCost), "can" (Config.Upgrades.canOrder), "sprinklerBasic",
                                 "sprinklerAdvanced" (at most sprinklers.maxEach owned of each)

On load, crops grow offline at rate 1 for min(away, offlineCapSec); away welcomeBackSec or more sends the
Welcome-back card (a Toast of kind "welcomeBack" with data { awaySec, ripe }).

  FarmService.rateFor(player, profile, tileId)
  FarmService.weather(player) -> { rain, shower }   WeatherService replaces this (M5)
  FarmService.render(player, tileId)
  FarmService.BadgeEarned(player, badgeKey)          "full_meadow" on reaching the top plot level
  FarmService.Harvested(player, seed, tileId)        for quests (M8)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Clock = require(ReplicatedStorage.Shared.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local Growth = require(ReplicatedStorage.Shared.Growth)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Tiles = require(ReplicatedStorage.Shared.Tiles)

local DataService = require(script.Parent.DataService)
local Guards = require(script.Parent.Parent.Net.Guards)
local InventoryService = require(script.Parent.InventoryService)
local NetService = require(script.Parent.NetService)
local PlotService = require(script.Parent.PlotService)
local SocialService = require(script.Parent.SocialService)

local FarmService = {
	BadgeEarned = Signal.new(),
	Harvested = Signal.new(),
}

local services
local active = setmetatable({}, { __mode = "k" }) -- [player] = true while loaded
local shownRate = setmetatable({}, { __mode = "k" }) -- [player][tileId] = the rate on the tile's attributes

local SPRINKLER_KINDS = { sprinklerBasic = "basic", sprinklerAdvanced = "advanced" }

function FarmService.weather()
	return { rain = false, shower = false }
end

function FarmService.rateFor(player, profile, id)
	return Growth.rate(
		Growth.sprinklerMult(profile.sprinklers.placed, id),
		SocialService.friendBoost(player),
		Growth.weatherMult(FarmService.weather(player))
	)
end

function FarmService.render(player, id)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local rate = FarmService.rateFor(player, profile, id)
	shownRate[player] = shownRate[player] or {}
	shownRate[player][id] = rate
	PlotService.renderTile(player, id, rate)
end

local function tileChanged(player, profile, id)
	NetService.change(player, { "tiles", id }, profile.tiles[id])
	FarmService.render(player, id)
end

local function nearTile(player, ownerPlayer, id)
	local part = PlotService.tilePart(ownerPlayer, id)
	return part ~= nil and Guards.near(player, part.Position, Guards.RANGE.tile)
end

---------------------------------------------------------------------------------------------------------------
-- plant and harvest

local function plant(player, payload, profile)
	local id, seed = payload.tile, payload.seed
	if not Guards.ownsTile(player, id) then
		return false, "ownership"
	end
	if profile.tiles[id] or profile.sprinklers.placed[id] then
		return false, "occupied"
	end
	if not nearTile(player, player, id) then
		return false, "too_far"
	end
	if not InventoryService.spendSeeds(player, seed, 1, "plant") then
		return false, "no_seed"
	end
	profile.tiles[id] = Growth.newTile(seed, Clock.now())
	tileChanged(player, profile, id)
	return true
end

-- one ripe tile; mutated crops only when allowed (a tap, not harvestAll)
local function harvestOne(player, profile, id, onFull, allowMutated)
	local tile = profile.tiles[id]
	if not tile then
		return false, "empty"
	end
	if not Growth.ripe(tile) then
		return false, "not_ripe"
	end
	local mutated = next(tile.muts) ~= nil
	if mutated and not allowMutated then
		return false, "mutated"
	end
	if mutated and services.MutationService then
		return services.MutationService.harvest(player, profile, id)
	end
	local full = InventoryService.basketCount(profile) >= Config.Inventory.basketCap
	if profile.autoSell or (full and onFull == "sell") then
		InventoryService.addCoins(player, InventoryService.sellValue(player, tile.seed), "harvest")
	elseif not InventoryService.addToBasket(player, tile.seed) then
		return false, "basket_full"
	end
	FarmService.Harvested:Fire(player, tile.seed, id)
	tile.harvestsLeft -= 1
	if tile.harvestsLeft > 0 then
		Growth.regrow(tile, Clock.now())
	else
		profile.tiles[id] = nil
	end
	tileChanged(player, profile, id)
	return true
end

local function harvest(player, payload, profile)
	if not Guards.ownsTile(player, payload.tile) then
		return false, "ownership"
	end
	if not nearTile(player, player, payload.tile) then
		return false, "too_far"
	end
	return harvestOne(player, profile, payload.tile, payload.onFull, true)
end

local function harvestAll(player, _, profile)
	local ids = {}
	for id in profile.tiles do
		table.insert(ids, id)
	end
	table.sort(ids)
	local n = 0
	for _, id in ids do
		local ok, code = harvestOne(player, profile, id, nil, false)
		if ok then
			n += 1
		elseif code == "basket_full" then
			break
		end
	end
	return n > 0, if n > 0 then nil else "nothing_ripe"
end

local function water(player, payload, profile)
	if payload.ownerId ~= nil and payload.ownerId ~= player.UserId then
		local ok, code = SocialService.helpWater(player, payload.ownerId, payload.tile)
		if ok then
			local owner = Guards.sameServer(payload.ownerId)
			FarmService.render(owner, payload.tile)
		end
		return ok, code
	end
	local id = payload.tile
	if not Guards.ownsTile(player, id) then
		return false, "ownership"
	end
	local tile = profile.tiles[id]
	if not tile then
		return false, "empty"
	end
	if not nearTile(player, player, id) then
		return false, "too_far"
	end
	local ok, code = Growth.useCan(tile, Config.Upgrades.cans[profile.can].growSpeedBonus)
	if ok then
		tileChanged(player, profile, id)
	end
	return ok, code
end

---------------------------------------------------------------------------------------------------------------
-- sprinklers

local function placedCount(profile, kind)
	local n = 0
	for _, k in profile.sprinklers.placed do
		if k == kind then
			n += 1
		end
	end
	return n
end

-- the main tiles a sprinkler's change touches (its area)
local function rerenderArea(player, profile, id)
	for _, near in Tiles.neighbors(id, Config.Upgrades.sprinklers.area) do
		if profile.tiles[near] then
			FarmService.render(player, near)
		end
	end
	FarmService.render(player, id)
end

local function sprinkler(player, payload, profile)
	local id, kind = payload.tile, payload.kind
	if not Tiles.rc(id) or not Guards.ownsTile(player, id) then
		return false, "ownership"
	end
	if profile.tiles[id] or profile.sprinklers.placed[id] then
		return false, "occupied"
	end
	if placedCount(profile, kind) >= profile.sprinklers[kind] then
		return false, "none_left"
	end
	if not nearTile(player, player, id) then
		return false, "too_far"
	end
	profile.sprinklers.placed[id] = kind
	NetService.change(player, { "sprinklers" }, profile.sprinklers)
	rerenderArea(player, profile, id)
	return true
end

local function pickup(player, payload, profile)
	local id = payload.tile
	if not Guards.ownsTile(player, id) then
		return false, "ownership"
	end
	if not profile.sprinklers.placed[id] then
		return false, "empty"
	end
	if not nearTile(player, player, id) then
		return false, "too_far"
	end
	profile.sprinklers.placed[id] = nil
	NetService.change(player, { "sprinklers" }, profile.sprinklers)
	rerenderArea(player, profile, id)
	return true
end

---------------------------------------------------------------------------------------------------------------
-- upgrades

local function buyPlot(player, profile)
	local nextLevel = profile.plotLevel + 1
	local cost = Config.Upgrades.plotCost[nextLevel]
	if not cost then
		return false, "max"
	end
	if not InventoryService.spendCoins(player, cost, "plot") then
		return false, "coins"
	end
	profile.plotLevel = nextLevel
	NetService.change(player, { "plotLevel" }, nextLevel)
	PlotService.refresh(player)
	for _, seed in Config.Restock.order do
		local gate = Config.Seeds[seed].gate
		if gate.plotLevel == nextLevel and not gate.eventOnly then
			NetService.toast(player, "unlock", `{Config.Seeds[seed].name} unlocked!`, { seed = seed })
		end
	end
	if nextLevel == #Config.Upgrades.plotCost then
		FarmService.BadgeEarned:Fire(player, "full_meadow")
	end
	return true
end

local function buyCan(player, profile)
	local order = Config.Upgrades.canOrder
	local nextCan = order[(table.find(order, profile.can) or #order) + 1]
	if not nextCan then
		return false, "max"
	end
	if not InventoryService.spendCoins(player, Config.Upgrades.cans[nextCan].cost, "can") then
		return false, "coins"
	end
	profile.can = nextCan
	NetService.change(player, { "can" }, nextCan)
	return true
end

local function buySprinkler(player, profile, kind)
	local cfg = Config.Upgrades.sprinklers
	if profile.sprinklers[kind] >= cfg.maxEach then
		return false, "max"
	end
	if not InventoryService.spendCoins(player, cfg[kind].cost, "sprinkler") then
		return false, "coins"
	end
	profile.sprinklers[kind] += 1
	NetService.change(player, { "sprinklers" }, profile.sprinklers)
	return true
end

local function upgrade(player, payload, profile)
	local kind = payload.kind
	if kind == "plot" then
		return buyPlot(player, profile)
	elseif kind == "can" then
		return buyCan(player, profile)
	end
	return buySprinkler(player, profile, SPRINKLER_KINDS[kind])
end

---------------------------------------------------------------------------------------------------------------
-- the grow tick, offline growth, the Welcome-back card

-- dt since the last tick; a tile planted (or regrown) mid-tick only grows from then
function FarmService.tick(dt, now)
	for player in active do
		local profile = DataService.get(player)
		if profile then
			local shown = shownRate[player] or {}
			for id, tile in profile.tiles do
				local rate = FarmService.rateFor(player, profile, id)
				local ripened = Growth.tick(tile, math.min(dt, math.max(0, now - tile.plantedAt)), rate)
				if ripened then
					tileChanged(player, profile, id)
				elseif rate ~= shown[id] and not Growth.ripe(tile) then
					FarmService.render(player, id)
				end
			end
		end
	end
end

function FarmService.applyOffline(player, profile, now)
	local before = DataService.lastSeenBefore(player)
	if not before then
		return nil
	end
	local gone = math.max(0, now - before)
	local away = math.min(gone, Config.Upgrades.offlineCapSec)
	local ripe = 0
	for _, tile in profile.tiles do
		if not Growth.ripe(tile) then
			tile.grown += away
		end
		if Growth.ripe(tile) then
			ripe += 1
		end
	end
	if gone >= Config.Upgrades.welcomeBackSec then
		NetService.toast(player, "welcomeBack", "Welcome back!", { awaySec = away, ripe = ripe })
	end
	return away
end

function FarmService:Init(all)
	services = all
	NetService.on("Plot", "plant", nil, plant)
	NetService.on("Plot", "harvest", nil, harvest)
	NetService.on("Plot", "harvestAll", nil, harvestAll)
	NetService.on("Plot", "water", nil, water)
	NetService.on("Plot", "sprinkler", nil, sprinkler)
	NetService.on("Plot", "pickup", nil, pickup)
	NetService.on("Upgrade", "buy", nil, upgrade)
end

function FarmService:Start()
	local last = Clock.now()
	while true do
		task.wait(Config.Upgrades.growTickSec)
		local now = Clock.now()
		FarmService.tick(now - last, now)
		SocialService.prune(now)
		last = now
	end
end

function FarmService:OnPlayerLoaded(player, profile)
	FarmService.applyOffline(player, profile, Clock.now())
	active[player] = true
	for id in profile.tiles do
		FarmService.render(player, id)
	end
	for id in profile.sprinklers.placed do
		FarmService.render(player, id)
	end
end

function FarmService:OnPlayerLeaving(player)
	active[player] = nil
	shownRate[player] = nil
end

return FarmService
