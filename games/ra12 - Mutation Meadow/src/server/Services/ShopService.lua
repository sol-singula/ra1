--[[
Patch's seed shop and the global restock (§2 ShopService, §3 Restock).

Every Config.Restock.intervalSec slot has one stock list, the same on every server: rng = Random.new(slot), then for
each seed in Config.Restock.order rng:NextNumber() < chance gives qty (else 0). All nine always roll, in order; Moon
Melon is then zeroed unless the slot is in an event week, so the other rolls never shift.

At each new slot: Restock { slot, endsAt, stock } to everyone, Patch's restock line to players near Patch or with the
shop open, and when a tier Config.Patch.lines.rare.minTier+ seed stocked, the rare line (the highest tier's name) to
everyone with Patch alerts on.

Stock is per player per slot: profile.restock = { slot, bought }, reset when the slot changes.

Remotes: Shop:buySeed {seed, qty} (shop open, gate passed, enough stock left, enough coins), Shop:close {}.
Patch's prompt opens the shop (PatchService).

  ShopService.stockFor(slot, eventWeek) -> { [seed] = qty }   pure
  ShopService.isEventSlot(slot)
  ShopService.current() -> { slot, endsAt, stock }
  ShopService.open(player, via) / close(player) / isOpen(player)
  ShopService.gateReason(profile, seed, eventWeek)  nil when buyable, else "lifetimeCoins" | "plotLevel" | "eventOnly"
  ShopService.Restocked(state)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Clock = require(ReplicatedStorage.Shared.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local Schedule = require(ReplicatedStorage.Shared.Schedule)
local Signal = require(ReplicatedStorage.Shared.Signal)

local DataService = require(script.Parent.DataService)
local DevCommands = require(script.Parent.Parent.Net.DevCommands)
local InventoryService = require(script.Parent.InventoryService)
local NetService = require(script.Parent.NetService)
local Telemetry = require(script.Parent.Parent.Telemetry)

local ShopService = {
	Restocked = Signal.new(),
	Opened = Signal.new(),
}

local services
local state -- { slot, endsAt, stock }
local forced = {} -- [slot] = { [seed] = qty } from the DevCommand
local openFor = setmetatable({}, { __mode = "k" }) -- [player] = true

function ShopService.stockFor(slot, eventWeek)
	local rng = Random.new(slot)
	local stock = {}
	for _, seed in Config.Restock.order do
		local s = Config.Restock.stock[seed]
		stock[seed] = if rng:NextNumber() < s.chance then s.qty else 0
	end
	for _, seed in Config.Restock.order do
		if Config.Restock.stock[seed].eventOnly and not eventWeek then
			stock[seed] = 0
		end
	end
	return stock
end

function ShopService.isEventSlot(slot)
	local startsAt = slot * Config.Restock.intervalSec
	return Schedule.isEventWeek(Schedule.currentUpdate(startsAt).updateId)
end

local function build(slot)
	local stock = ShopService.stockFor(slot, ShopService.isEventSlot(slot))
	for seed, qty in forced[slot] or {} do
		stock[seed] = qty
	end
	return { slot = slot, endsAt = Schedule.slotEndsAt(slot), stock = stock }
end

function ShopService.current()
	return state
end

-- this slot's bought counts; reset = start a new slot's record (only when buying)
local function bought(profile, reset)
	if profile.restock.slot ~= state.slot then
		if not reset then
			return {}
		end
		profile.restock.slot = state.slot
		profile.restock.bought = {}
	end
	return profile.restock.bought
end

function ShopService.gateReason(profile, seed, eventWeek)
	local gate = Config.Seeds[seed].gate
	if gate.lifetimeCoins and profile.lifetimeCoins < gate.lifetimeCoins then
		return "lifetimeCoins"
	end
	if gate.plotLevel and profile.plotLevel < gate.plotLevel then
		return "plotLevel"
	end
	if gate.eventOnly and not eventWeek then
		return "eventOnly"
	end
	return nil
end

local function payloadFor(player, extra)
	local profile = DataService.get(player)
	local data = { slot = state.slot, endsAt = state.endsAt, stock = state.stock }
	if profile then
		data.bought = bought(profile)
	end
	for k, v in extra or {} do
		data[k] = v
	end
	return data
end

function ShopService.isOpen(player)
	return openFor[player] == true
end

function ShopService.open(player, via)
	local profile = DataService.get(player)
	if not profile then
		return false
	end
	local first = not profile.patchTips.shopHello
	openFor[player] = true
	NetService.fire(player, "Restock", payloadFor(player, { open = true }))
	Telemetry.log(player, "shop_open", { via = via })
	local patch = services and services.PatchService
	if patch then
		patch.say(player, if first then "shopHello" else "shopAgain")
	end
	ShopService.Opened:Fire(player, via)
	return true
end

function ShopService.close(player)
	openFor[player] = nil
end

local function rareSeed(stock)
	local best
	for _, seed in Config.Restock.order do
		local tier = Config.Seeds[seed].tier
		if
			stock[seed] > 0
			and tier >= Config.Patch.lines.rare.minTier
			and (not best or tier > Config.Seeds[best].tier)
		then
			best = seed
		end
	end
	return best
end

local function announce()
	for _, player in Players:GetPlayers() do
		NetService.fire(player, "Restock", payloadFor(player))
	end
	local patch = services and services.PatchService
	if patch then
		for _, player in Players:GetPlayers() do
			if openFor[player] or patch.isNear(player, Config.Patch.lines.restock.rangeStuds) then
				patch.say(player, "restock")
			end
		end
		local rare = rareSeed(state.stock)
		if rare then
			for _, player in Players:GetPlayers() do
				local profile = DataService.get(player)
				if profile and profile.settings.patchAlerts then
					patch.say(player, "rare", Config.Seeds[rare].name)
				end
			end
		end
	end
	ShopService.Restocked:Fire(state)
end

function ShopService.tick(now)
	local slot = Schedule.restockSlot(now)
	if not state or slot ~= state.slot then
		local first = state == nil
		state = build(slot)
		if not first then
			announce()
		end
	end
end

local function buySeed(player, payload, profile)
	if not openFor[player] then
		return false, "shop_closed"
	end
	local seed, qty = payload.seed, payload.qty
	if ShopService.gateReason(profile, seed, ShopService.isEventSlot(state.slot)) then
		return false, "locked"
	end
	local b = bought(profile, true)
	if (state.stock[seed] or 0) - (b[seed] or 0) < qty then
		return false, "sold_out"
	end
	if not InventoryService.spendCoins(player, Config.Seeds[seed].buy * qty, "seed") then
		return false, "coins"
	end
	b[seed] = (b[seed] or 0) + qty
	InventoryService.addSeeds(player, seed, qty, "shop")
	NetService.change(player, { "restock" }, profile.restock)
	return true
end

function ShopService:Init(all)
	services = all
	ShopService.tick(Clock.now())
	NetService.on("Shop", "buySeed", nil, buySeed)
	NetService.on("Shop", "close", nil, function(player)
		ShopService.close(player)
		return true
	end)
	NetService.snapshotPart("restock", function(player)
		return payloadFor(player)
	end)
	DevCommands.register("restock", function(_, args)
		local seed = args[2]
		if args[1] ~= "force" or type(seed) ~= "string" or not Config.Seeds[seed] then
			return false, "usage: restock force <seed>"
		end
		local slot = state.slot
		forced[slot] = forced[slot] or {}
		forced[slot][seed] = Config.Restock.stock[seed].qty
		state = build(slot)
		announce()
		return true
	end)
end

function ShopService:Start()
	Players.PlayerRemoving:Connect(ShopService.close)
	while true do
		task.wait(1)
		ShopService.tick(Clock.now())
	end
end

function ShopService:OnPlayerLoaded(player)
	NetService.fire(player, "Restock", payloadFor(player))
end

return ShopService
