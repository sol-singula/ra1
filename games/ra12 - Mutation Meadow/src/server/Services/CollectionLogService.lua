--[[
The Collection Log: every seed in every mutation, 9 x 3 = 27 entries ("seed:wet" | "seed:golden" | "seed:wetgolden").

On MutationService.Mutated the entry for the crop's whole mutation set is recorded: found[e] = { at, n = 1 } the
first time, n + 1 after. (Wet then Golden on one crop finds wetgolden.) Collection:claim {entry} pays the first-find
coins once (Config.Collection.firstFind, source "collection"); Collection:claim {milestone} needs that many entries
found and grants the milestone once (all earned-only: tag_collector, deco_lantern, the extra pedestal, title_master
plus the master_gardener badge).

  CollectionLogService.ENTRIES             the 27 entry keys, in seed order
  CollectionLogService.foundCount(profile)
  CollectionLogService.record(player, seed, mutKey)
  CollectionLogService.Found(player, entry, isNew)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Clock = require(ReplicatedStorage.Shared.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Shared.Signal)

local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local MutationService = require(script.Parent.MutationService)
local NetService = require(script.Parent.NetService)
local Telemetry = require(script.Parent.Parent.Telemetry)

local CollectionLogService = {
	Found = Signal.new(),
}

local MUTS = { "wet", "golden", "wetgolden" }

CollectionLogService.ENTRIES = {}
for _, seed in Config.Restock.order do
	for _, mut in MUTS do
		table.insert(CollectionLogService.ENTRIES, seed .. ":" .. mut)
	end
end

local services

function CollectionLogService.foundCount(profile)
	local n = 0
	for _ in profile.collection.found do
		n += 1
	end
	return n
end

function CollectionLogService.record(player, seed, mutKey)
	local profile = DataService.get(player)
	if not profile or not mutKey then
		return
	end
	local entry = seed .. ":" .. mutKey
	local found = profile.collection.found[entry]
	local isNew = found == nil
	if isNew then
		profile.collection.found[entry] = { at = Clock.now(), n = 1 }
	else
		found.n += 1
	end
	NetService.change(player, { "collection" }, profile.collection)
	CollectionLogService.Found:Fire(player, entry, isNew)
	if isNew then
		InventoryService.renderPedestals(player) -- the 18th find unlocks a pedestal
		if CollectionLogService.foundCount(profile) >= #CollectionLogService.ENTRIES and services.RewardService then
			services.RewardService.award(player, "master_gardener")
		end
	end
end

local MILESTONE_COSMETIC = { tag_collector = true, deco_lantern = true, title_master = true }

local function claim(player, payload, profile)
	local c = profile.collection
	if payload.entry then
		local entry = payload.entry
		if not c.found[entry] then
			return false, "not_found"
		end
		if c.claimed[entry] then
			return false, "claimed"
		end
		c.claimed[entry] = true
		NetService.change(player, { "collection" }, c)
		InventoryService.addCoins(player, Config.Collection.firstFind[entry:match(":(%a+)$")], "collection")
		Telemetry.log(player, "collection_claim", { key = entry })
		return true
	end
	local n = payload.milestone
	local reward = Config.Collection.milestones[n]
	local key = tostring(n)
	if CollectionLogService.foundCount(profile) < n then
		return false, "not_yet"
	end
	if c.milestones[key] then
		return false, "claimed"
	end
	c.milestones[key] = true
	Telemetry.log(player, "milestone_claim", { n = n })
	if MILESTONE_COSMETIC[reward] then
		profile.cosmetics.owned[reward] = true
		NetService.change(player, { "cosmetics" }, profile.cosmetics)
	end
	if reward == "title_master" and services.RewardService then
		services.RewardService.award(player, "master_gardener")
	end
	NetService.change(player, { "collection" }, c)
	InventoryService.renderPedestals(player)
	return true
end

function CollectionLogService:Init(all)
	services = all
	NetService.on("Collection", "claim", nil, claim)
end

function CollectionLogService:Start()
	MutationService.Mutated:Connect(CollectionLogService.record)
end

return CollectionLogService
