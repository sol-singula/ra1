-- The season (2 weeks): every XP you earn also counts as season XP, 600 per tier, 50 tiers. Each tier has a
-- free reward (coins, a key every 5 tiers) and a pass reward (more coins, keys, season-only skins, pop effects
-- and emotes) for players with this season's Season Pass (a Robux product). A new season starts fresh.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local SeasonService = {
	Name = "SeasonService",
	Dependencies = { "PlayerDataService", "EconomyService", "LoadoutService", "ShopService" },
	Claimed = Signal.new("SeasonService.Claimed"), -- (player, tier, track)
}

local data, economy, loadout

local function current(profile)
	local n = Formulas.season(os.time())
	if profile.season.n ~= n then
		profile.season = { n = n, xp = 0, pass = false, claimed = {} }
	end
	return profile.season
end

function SeasonService:View(player)
	local profile = data:Get(player)
	local s = current(profile)
	local _, endsAt = Formulas.season(os.time())
	return {
		n = s.n,
		endsAt = endsAt,
		xp = s.xp,
		tier = Formulas.seasonTier(s.xp),
		pass = s.pass,
		claimed = table.clone(s.claimed),
	}
end

function SeasonService:Push(player)
	if data:Get(player) then
		data:Push(player, { season = self:View(player) })
	end
end

function SeasonService:Claim(player, tier, track)
	local profile = data:Get(player)
	if not profile then
		return false
	end
	local s = current(profile)
	if tier < 1 or tier > Constants.SEASON_TIERS or Formulas.seasonTier(s.xp) < tier then
		return false
	end
	if track == "pass" and not s.pass then
		Net.fire(player, "Toast", "That one needs the Season Pass.", "info")
		return false
	end
	local key = tier .. (track == "pass" and "p" or "f")
	if s.claimed[key] then
		return false
	end
	s.claimed[key] = true
	local free, pass = Formulas.seasonReward(tier)
	local rw = track == "pass" and pass or free
	local text
	if rw.coins then
		economy:AddCoins(player, rw.coins, false)
		text = `{rw.coins} coins`
	elseif rw.keys then
		economy:AddKeys(player, rw.keys)
		text = `{rw.keys} crate key`
	elseif rw.skin then
		loadout:GrantSkin(player, rw.skin, "season")
		text = "a season skin"
	elseif rw.effect then
		loadout:GrantStyle(player, "effect", rw.effect)
		text = "a pop effect"
	elseif rw.emote then
		loadout:GrantStyle(player, "emote", rw.emote)
		text = "an emote"
	end
	Net.fire(player, "Toast", `🏅 Tier {tier}: {text}!`, "good")
	Net.fire(player, "Sfx", "gift")
	self.Claimed:Fire(player, tier, track)
	self:Push(player)
	return true
end

function SeasonService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	loadout = registry.LoadoutService
	economy.XpGained:Connect(function(player, amount)
		local profile = data:Get(player)
		if profile then
			local s = current(profile)
			local before = Formulas.seasonTier(s.xp)
			s.xp += math.floor(amount)
			local after = Formulas.seasonTier(s.xp)
			if after > before then
				Net.fire(player, "Toast", `🏅 Season tier {after}! Claim it at the Season counter.`, "good")
			end
			self:Push(player)
		end
	end)
	registry.ShopService.SeasonChanged:Connect(function(player)
		self:Push(player)
	end)
	Net.on("ClaimSeason", function(player, tier, track)
		if type(tier) == "number" and (track == "free" or track == "pass") then
			self:Claim(player, math.floor(tier), track)
		end
	end)
	data.ClientReady:Connect(function(player)
		self:Push(player)
	end)
end

return SeasonService
