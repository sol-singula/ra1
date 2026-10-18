--[[
Offline earnings and the "while you were away" card (master plan §8). The farm keeps working while they're gone:
crops keep growing on the server's clock (FarmService), and the machines and the warehouse keep earning, at
Constants.OFFLINE_RATE of what they'd make live, for up to Constants.OFFLINE_HOURS (OFFLINE_PASS_HOURS with the Long
Nap pass; the franchise's perk adds more).

  before the tractor and conveyor  nothing to earn away (the crops still ripen)
  with them                        the fields' rate (Flow's grow), sold at the stand's price
  with the warehouse               the operation's pace: the slowest station's rate, shipped (Flow.SHIP_MULT)

When they come back after at least OFFLINE_MIN_SECONDS, the Cash is added and Net "Away" shows the card: how long
they were gone, what it earned (and whether it hit the cap), and what's ready: ripe tiles, a Special Order waiting,
the day's calendar reward.

profile.away = { at (os.time when they left) }

  OfflineService:Earned(profile, seconds) -> Cash, capped
  OfflineService:Hours(profile)            the cap for them
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Flow = require(ReplicatedStorage.Shared.Data.Flow)
local Net = require(ReplicatedStorage.Shared.Net)
local Upgrades = require(ReplicatedStorage.Shared.Data.Upgrades)

local OfflineService = {
	Name = "OfflineService",
	Dependencies = { "PlayerDataService", "EconomyService", "FarmService" },
}

local data, economy, farm, analytics, registryRef

function OfflineService:Hours(profile)
	local hours = Constants.OFFLINE_HOURS
	if profile.passes and profile.passes.longNap then
		hours = Constants.OFFLINE_PASS_HOURS
	end
	local perk = profile.franchise and profile.franchise.perks and profile.franchise.perks.nap or 0
	return hours + perk * 2
end

function OfflineService:Earned(profile, seconds)
	local owned = profile.owned or {}
	local cap = self:Hours(profile) * 3600
	local capped = seconds > cap
	local minutes = math.min(seconds, cap) / 60
	local rates = Flow.rates(profile, workspace:GetServerTimeNow())
	local perMinute = 0
	if owned.warehouse then
		perMinute = math.min(rates.grow, rates.pack, rates.store, rates.ship)
			* Flow.SHIP_MULT
			* (1 + Upgrades.stat(owned, "orderPrice", 0))
	elseif owned.tractor and owned.conveyor then
		perMinute = rates.grow * (1 + Upgrades.stat(owned, "price", 0))
	end
	local mult = registryRef.FranchiseService and registryRef.FranchiseService:IncomeMult(profile) or 1
	return math.floor(perMinute * minutes * Constants.OFFLINE_RATE * mult + 0.5), capped
end

function OfflineService:OnPlayerReady(player, profile)
	profile.away = profile.away or { at = 0 }
	local at = profile.away.at or 0
	if at <= 0 then
		return
	end
	local seconds = os.time() - at
	profile.away.at = 0
	if seconds < Constants.OFFLINE_MIN_SECONDS then
		return
	end
	local earned, capped = self:Earned(profile, seconds)
	if earned > 0 then
		economy:Add(player, earned, "away")
	end
	-- what's waiting for them
	local ripe = 0
	for n in farm:Tiles(player) do
		if farm:Ripe(player, n) then
			ripe += 1
		end
	end
	local card = {
		seconds = seconds,
		earned = earned,
		capped = capped,
		hours = self:Hours(profile),
		ripe = ripe,
		special = profile.orders and profile.orders.special ~= nil or nil,
	}
	if analytics then
		pcall(analytics.event, player, "away", { seconds = seconds, earned = earned, capped = capped })
	end
	data:WhenClientReady(player, function()
		card.calendar = registryRef.DailyService and registryRef.DailyService:Claimable(player) or nil
		Net.fire(player, "Away", card)
	end)
end

function OfflineService:OnPlayerLeaving(_, profile)
	profile.away = profile.away or {}
	profile.away.at = os.time()
end

function OfflineService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	farm = registry.FarmService
	analytics = registry.AnalyticsService
	registryRef = registry
end

return OfflineService
