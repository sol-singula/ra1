--[[
Crop growth (pure; the caller passes the time). A tile grows `grown` boosted seconds; it is ripe at the seed's
growSec. Boosts multiply:

  rate = sprinklerMult x (1 + friendBoost) x weatherMult

  Growth.sprinklerMult(placed, tileId)   the best sprinkler whose area covers the tile (overlaps don't stack): 1,
                                         or Config.Upgrades.sprinklers[kind].growthMult
  Growth.friendBoost(friends)            min(friendBoostEach x friends, friendBoostMax)
  Growth.weatherMult(weather)            weather = { rain = bool, shower = bool } (shower: the Welcome Shower on
                                         your own plot); rainGrowthMult if either, else 1
  Growth.rate(sprinkler, friendBoost, weather)
  Growth.growSec(tile)                   the seed's growSec
  Growth.ripe(tile)
  Growth.tick(tile, dt, rate)            grows a non-ripe tile; returns true when it just became ripe
  Growth.timeLeft(tile, rate)            seconds to ripe at that rate (0 when ripe)
  Growth.boostRemaining(tile, share)     grown += share x (growSec - grown), for a growing tile (a can, a help)
  Growth.useCan(tile, cut)               the can: once per growth, while growing -> true | false, "ripe" | "can_used"
  Growth.newTile(seed, now)              a freshly planted tile
  Growth.regrow(tile, now)               after a harvest that leaves harvests: grown = 0 again
]]
local Config = require(script.Parent.Config)
local Tiles = require(script.Parent.Tiles)

local Growth = {}

function Growth.sprinklerMult(placed, tileId)
	local best = 1
	if not placed or not Tiles.rc(tileId) then
		return best
	end
	for _, id in Tiles.neighbors(tileId, Config.Upgrades.sprinklers.area) do
		local kind = placed[id]
		local s = kind and Config.Upgrades.sprinklers[kind]
		if s and s.growthMult > best then
			best = s.growthMult
		end
	end
	return best
end

function Growth.friendBoost(friends)
	return math.min(Config.Social.friendBoostEach * friends, Config.Social.friendBoostMax)
end

function Growth.weatherMult(weather)
	if weather and (weather.rain or weather.shower) then
		return Config.Weather.rainGrowthMult
	end
	return 1
end

function Growth.rate(sprinkler, friendBoost, weather)
	return sprinkler * (1 + friendBoost) * weather
end

function Growth.growSec(tile)
	return Config.Seeds[tile.seed].growSec
end

function Growth.ripe(tile)
	return tile.grown >= Growth.growSec(tile)
end

function Growth.tick(tile, dt, rate)
	if Growth.ripe(tile) then
		return false
	end
	tile.grown += dt * rate
	return Growth.ripe(tile)
end

function Growth.timeLeft(tile, rate)
	return math.max(0, Growth.growSec(tile) - tile.grown) / rate
end

function Growth.boostRemaining(tile, share)
	tile.grown += share * (Growth.growSec(tile) - tile.grown)
end

function Growth.useCan(tile, cut)
	if Growth.ripe(tile) then
		return false, "ripe"
	end
	if tile.canUsed then
		return false, "can_used"
	end
	Growth.boostRemaining(tile, cut)
	tile.canUsed = true
	return true
end

function Growth.newTile(seed, now)
	return {
		seed = seed,
		plantedAt = now,
		grown = 0,
		harvestsLeft = Config.Seeds[seed].harvests,
		muts = {},
		canUsed = false,
	}
end

function Growth.regrow(tile, now)
	tile.grown = 0
	tile.plantedAt = now
	tile.canUsed = false
	tile.muts = {}
end

return Growth
