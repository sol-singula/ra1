--[[
The Turf Pass (Data/Season): each player's pass for the season now running (profile.season). A new season
starts everyone again at tier 0 (what they claimed stays theirs).

  SeasonService:State(player)          { n, xp, premium, claimed = { ["<tier><f|p>"] = true } }
  SeasonService:AddXP(player, xp)      -> tiers gained
  SeasonService:AddTiers(player, n)    (+1 TIER)
  SeasonService:GrantPremium(player)   (the pass bought)
  SeasonService:Claim(player, tier, track) -> reward | nil, why
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Season = require(ReplicatedStorage.Shared.Data.Season)

local SeasonService = {
	Name = "SeasonService",
	Dependencies = { "PlayerDataService", "EconomyService" },
}

local data, economy

function SeasonService.now()
	return math.floor(workspace:GetServerTimeNow())
end

function SeasonService:State(player)
	local p = data:Get(player)
	if not p then
		return nil
	end
	local n = Season.at(self.now()).n
	if type(p.season) ~= "table" or p.season.n ~= n then
		p.season = { n = n, xp = 0, premium = false, claimed = {} }
	end
	p.season.claimed = p.season.claimed or {}
	return p.season
end

function SeasonService:AddXP(player, xp)
	local s = self:State(player)
	if not s or xp <= 0 then
		return 0
	end
	local before = Season.tierOf(s.xp)
	s.xp = math.min(s.xp + math.floor(xp), Season.TIERS * Season.XP_PER_TIER)
	return Season.tierOf(s.xp) - before
end

function SeasonService:AddTiers(player, n)
	local s = self:State(player)
	if not s then
		return 0
	end
	local before = Season.tierOf(s.xp)
	s.xp = math.min((before + n) * Season.XP_PER_TIER, Season.TIERS * Season.XP_PER_TIER)
	return Season.tierOf(s.xp) - before
end

function SeasonService:GrantPremium(player)
	local s = self:State(player)
	if not s then
		return false
	end
	s.premium = true
	local p = data:Get(player)
	p.stats.passes = (p.stats.passes or 0) + 1
	return true
end

function SeasonService:Claim(player, tier, track)
	local s = self:State(player)
	if not s or type(tier) ~= "number" or (track ~= "f" and track ~= "p") then
		return nil, "bad"
	end
	tier = math.floor(tier)
	local r = Season.reward(s.n, tier, track)
	if not r then
		return nil, "Nothing on that tier."
	end
	if Season.tierOf(s.xp) < tier then
		return nil, `Reach tier {tier} first.`
	end
	if track == "p" and not s.premium then
		return nil, "That's on the premium track: get the Turf Pass."
	end
	local k = tostring(tier) .. track
	if s.claimed[k] then
		return nil, "Already claimed."
	end
	s.claimed[k] = true
	if r.kind == "shards" then
		economy:Add(player, r.amount, "pass")
	else
		economy:Give(player, r.key)
	end
	return r
end

function SeasonService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
end

return SeasonService
