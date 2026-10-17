--[[
The Turf Pass: a new season every 4 weeks, 30 tiers climbed with pass XP from playing. Two tracks:

  free      everyone: Shards on every other tier, a cosmetic at tiers 5, 15 and 25
  premium   the season's Turf Pass (Robux, Data/Shop.PASS, bought again each season): a cosmetic on every 3rd
            tier (the 30th legendary), a season title straight away at tier 1, Shards on the rest

Season cosmetics are that season's only: they never come back to the shop (Data/Cosmetics, source "pass").
Everything is worked out from the clock, so every server agrees on the season without talking to each other.

  Season.at(t)              { n, startsAt, endsAt }
  Season.name(n)
  Season.xpFor(info)        pass XP for a match (the info ProgressService:Award gets)
  Season.tierOf(xp)
  Season.reward(n, tier, track)   { kind = "shards", amount } | { kind = "cosmetic", key } | nil
]]
local Cosmetics = require(script.Parent.Cosmetics)

local Season = {}

Season.EPOCH = 1791763200 -- Monday 12 October 2026, 00:00 UTC: season 1 starts
Season.DAYS = 28
Season.TIERS = 30
Season.XP_PER_TIER = 800
Season.DAILY_BONUS = 300 -- the day's first match

local THEMES = { "White Out", "Red Shift", "Blue Hour", "Overdrive", "Glass", "Static", "Afterglow", "Zero" }

function Season.at(t)
	local length = Season.DAYS * 86400
	local i = math.max(0, (t - Season.EPOCH) // length)
	local startsAt = Season.EPOCH + i * length
	return { n = i + 1, startsAt = startsAt, endsAt = startsAt + length }
end

function Season.theme(n)
	return THEMES[(n - 1) % #THEMES + 1]
end

function Season.name(n)
	return `SEASON {n}: {string.upper(Season.theme(n))}`
end

function Season.xpFor(info)
	if (info.seconds or 0) < 60 then
		return 0
	end
	local xp = 120
	xp += info.won and 100 or 0
	xp += math.min(150, (info.kills or 0) * 10)
	xp += math.min(60, (info.assists or 0) * 5)
	xp += math.min(60, (info.built or 0) * 2)
	xp += info.mvp and 50 or 0
	return xp
end

function Season.tierOf(xp)
	return math.min(Season.TIERS, (xp or 0) // Season.XP_PER_TIER)
end

-- What each season's cosmetics are made of, in turn (a look from Data/Cosmetics under the season's name)
local LOOKS = {
	{ "trail", "Comet" },
	{ "effect", "Supernova" },
	{ "skin", "Prism" },
	{ "banner", "Bolt" },
	{ "trail", "Double Helix" },
	{ "effect", "Pixels" },
	{ "skin", "Glass" },
	{ "trail", "Overcharge" },
	{ "banner", "Sun" },
	{ "effect", "Ascend" },
	{ "skin", "Hologram" },
	{ "trail", "Echo" },
	{ "banner", "Eye" },
}
local FREE_TIERS = { [5] = true, [15] = true, [25] = true }

local function isCosmeticTier(tier, track)
	if track == "f" then
		return FREE_TIERS[tier] == true
	end
	return tier == 1 or tier % 3 == 0
end

function Season.reward(n, tier, track)
	if tier < 1 or tier > Season.TIERS then
		return nil
	end
	if isCosmeticTier(tier, track) then
		return { kind = "cosmetic", key = `s{n}_{tier}{track}` }
	end
	if track == "f" then
		return tier % 2 == 0 and { kind = "shards", amount = 20 } or nil
	end
	return { kind = "shards", amount = 25 + (tier // 10) * 5 }
end

-- The season's cosmetics, made on demand from their keys (Cosmetics.get calls this)
Cosmetics.setSeasonResolver(function(key)
	local n, tier, track = string.match(key, "^s(%d+)_(%d+)([fp])$")
	n, tier = tonumber(n), tonumber(tier)
	if not n or not tier or not isCosmeticTier(tier, track) then
		return nil
	end
	local theme = Season.theme(n)
	if track == "p" and tier == 1 then
		return {
			key = key,
			kind = "title",
			name = theme,
			rarity = "epic",
			source = "pass",
			season = n,
			look = { text = theme },
		}
	end
	local i = (n * 7 + tier + (track == "f" and 3 or 0)) % #LOOKS + 1
	local kind, base = LOOKS[i][1], LOOKS[i][2]
	return {
		key = key,
		kind = kind,
		name = `{theme} {base}`,
		rarity = tier == Season.TIERS and "legendary" or (track == "p" and "epic" or "rare"),
		source = "pass",
		season = n,
		look = Cosmetics.look(kind, base),
	}
end)

return Season
