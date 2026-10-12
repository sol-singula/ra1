-- Reasons to keep playing in the first minutes: playtime gifts (coins, ore, gems and blasters at 1, 3, 5, 10...
-- minutes played today; the HUD counts down to the next one) and the new-player 2x coins boost for 10 minutes.
-- Also the raid countdown (the raid itself comes in a later step; the clock already runs so the Hub has a beat).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Planets = require(ReplicatedStorage.Shared.Data.Planets)
local Signal = require(ReplicatedStorage.Shared.Signal)

local PlaytimeService = {
	Name = "PlaytimeService",
	Dependencies = { "PlayerDataService", "EconomyService", "BlasterService", "PlanetService" },
	GiftGiven = Signal.new("PlaytimeService.GiftGiven"), -- (player, n, gift)
}

local data, economy, blasters, planetService
local online = {}
local rng = Random.new()
local nextRaidAt

local function today(profile)
	local day = Formulas.day(os.time())
	local p = profile.playtime
	if not p or p.day ~= day then
		p = { day = day, seconds = 0, given = 0 }
		profile.playtime = p
	end
	return p
end

-- The planet the gifts are measured against: the highest one the player has opened.
local function topPlanet(player)
	return Planets.list[planetService:Unlocked(player)]
end

function PlaytimeService:GiftText(player, n)
	local g = Constants.PLAYTIME_GIFTS[n]
	local planet = topPlanet(player)
	if g.kind == "coins" then
		return `{Format.num(g.amount * planet.bugCoins / 5)} coins`
	elseif g.kind == "ore" then
		return `{g.amount} {planet.ore}`
	elseif g.kind == "gems" then
		return `{g.amount} gems`
	elseif g.kind == "blaster" then
		return `a {Formulas.forgeTier(g.tier).name} blaster`
	end
	return "a gift"
end

function PlaytimeService:View(player)
	local profile = data:Get(player)
	local p = today(profile)
	local nextGift = Constants.PLAYTIME_GIFTS[p.given + 1]
	return {
		nextIn = nextGift and math.max(0, nextGift.at - p.seconds) or nil,
		nextText = nextGift and self:GiftText(player, p.given + 1) or nil,
		given = p.given,
		total = #Constants.PLAYTIME_GIFTS,
		boostLeft = profile.newBoostLeft or 0,
	}
end

function PlaytimeService:Push(player)
	data:Push(player, { playtime = self:View(player) })
end

function PlaytimeService:_give(player, n)
	local g = Constants.PLAYTIME_GIFTS[n]
	local planet = topPlanet(player)
	local text = self:GiftText(player, n)
	if g.kind == "coins" then
		economy:AddCoins(player, math.floor(g.amount * planet.bugCoins / 5), false)
	elseif g.kind == "ore" then
		economy:AddOre(player, planet.key, g.amount)
	elseif g.kind == "gems" then
		economy:AddGems(player, g.amount, true)
	elseif g.kind == "blaster" then
		local rec = blasters:Grant(player, Formulas.rollBlaster(rng, g.tier, planet.key, 1), "gift")
		text = Formulas.blasterName(rec) .. " " .. Formulas.rollStars(rec)
	end
	Net.fire(player, "Alert", `🎁 {math.floor(g.at / 60)} min gift: {text}!`, Color3.fromRGB(255, 205, 50))
	Net.fire(player, "Sfx", "gift")
	self.GiftGiven:Fire(player, n, g)
end

function PlaytimeService:_tick()
	for player in online do
		local profile = data:Get(player)
		if profile then
			local p = today(profile)
			p.seconds += 1
			local changed = false
			local nextGift = Constants.PLAYTIME_GIFTS[p.given + 1]
			if nextGift and p.seconds >= nextGift.at then
				p.given += 1
				self:_give(player, p.given)
				changed = true
			end
			if (profile.newBoostLeft or 0) > 0 then
				profile.newBoostLeft -= 1
				if profile.newBoostLeft <= 0 then
					Net.fire(player, "Toast", "Your new-player 2x boost is over. Keep blasting! 💥", "info")
					changed = true
				end
			end
			if changed then
				self:Push(player)
			end
		end
	end
end

function PlaytimeService:RaidAt()
	return nextRaidAt
end

function PlaytimeService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	blasters = registry.BlasterService
	planetService = registry.PlanetService
	nextRaidAt = workspace:GetServerTimeNow() + Constants.RAID_EVERY
	data.ClientReady:Connect(function(player)
		if data:Get(player) then
			self:Push(player)
			Net.fire(player, "Event", { kind = "raid", at = nextRaidAt })
		end
	end)
end

function PlaytimeService:OnPlayerReady(player, profile)
	if profile.newBoostLeft == nil then
		profile.newBoostLeft = profile._isNew and Constants.NEW_PLAYER_BOOST_SECONDS or 0
	end
	online[player] = true
	self:Push(player)
end

function PlaytimeService:OnPlayerLeaving(player)
	online[player] = nil
end

function PlaytimeService:Start()
	while true do
		task.wait(1)
		self:_tick()
		if workspace:GetServerTimeNow() >= nextRaidAt then
			nextRaidAt += Constants.RAID_EVERY
			Net.fireAll("Event", { kind = "raid", at = nextRaidAt })
		end
	end
end

return PlaytimeService
