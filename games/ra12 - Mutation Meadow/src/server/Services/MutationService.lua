--[[
Crop mutations (§2 MutationService). WeatherService decides when a crop rolls; this applies the result.

Each mutation applies at most once per crop; a Wet crop can still turn Golden (Wet + Golden sells for
Config.Mutations.stackMult). On a mutation the owner gets Mutation { tile, mut, value, newEntry } and Mutated fires.

  MutationService.tryRoll(tile, mut, chance, rng) -> boolean    pure: rolls and sets tile.muts[mut]
  MutationService.roll(player, tileId, mut, chance, rng) -> boolean
  MutationService.apply(player, tileId, mut) -> boolean          a guaranteed mutation (the Welcome Shower)
  MutationService.Mutated(player, seed, mutKey)                  for the collection (M7), quests (M8), telemetry (M10)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MutationMath = require(ReplicatedStorage.Shared.MutationMath)
local Signal = require(ReplicatedStorage.Shared.Signal)

local DataService = require(script.Parent.DataService)
local FarmService = require(script.Parent.FarmService)
local NetService = require(script.Parent.NetService)

local MutationService = {
	Mutated = Signal.new(),
}

function MutationService.tryRoll(tile, mut, chance, rng)
	if tile.muts[mut] then
		return false
	end
	if rng:NextNumber() < chance then
		tile.muts[mut] = true
		return true
	end
	return false
end

local function announce(player, profile, tileId, tile, mut)
	local key = MutationMath.key(tile.muts)
	NetService.fire(player, "Mutation", {
		tile = tileId,
		mut = mut,
		value = MutationMath.value(tile.seed, tile.muts),
		newEntry = profile.collection.found[tile.seed .. ":" .. key] == nil,
	})
	NetService.change(player, { "tiles", tileId }, tile)
	FarmService.render(player, tileId)
	MutationService.Mutated:Fire(player, tile.seed, key)
end

function MutationService.roll(player, tileId, mut, chance, rng)
	local profile = DataService.get(player)
	local tile = profile and profile.tiles[tileId]
	if not tile or not MutationService.tryRoll(tile, mut, chance, rng) then
		return false
	end
	announce(player, profile, tileId, tile, mut)
	return true
end

function MutationService.apply(player, tileId, mut)
	local profile = DataService.get(player)
	local tile = profile and profile.tiles[tileId]
	if not tile or tile.muts[mut] then
		return false
	end
	tile.muts[mut] = true
	announce(player, profile, tileId, tile, mut)
	return true
end

return MutationService
