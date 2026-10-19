--[[
Coming back (master plan §10, §13): crops kept growing on their saved timestamps (CropService runs on os.time, so
they're simply ripe); with a machine the farm also kept harvesting and selling, at half the live income rate, up
to a cap of hours (8 with the Night Shift pass). The welcome-back card says what grew, what was earned, and the
next useful upgrade (TaskService pushes it).

  OfflineService:Settle(player)   paid now; returns { seconds, earned, ripe }
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Upgrades = require(ReplicatedStorage.Shared.Data.Upgrades)

local OfflineService = {
	Name = "OfflineService",
	Dependencies = { "PlayerDataService", "EconomyService", "CropService" },
}

local data, economy, crops, analytics
local pending = {} -- [player] = the card to send once the client is ready

function OfflineService:Settle(player)
	local p = data:Get(player)
	if not p then
		return nil
	end
	local lastSeen = p.away and p.away.at or 0
	local seconds = lastSeen > 0 and math.max(0, os.time() - lastSeen) or 0
	if seconds < Constants.OFFLINE_MIN_SECONDS then
		return nil
	end
	local hours = p.passes and p.passes.nightShift and Constants.OFFLINE_PASS_HOURS or Constants.OFFLINE_HOURS
	local counted = math.min(seconds, hours * 3600)
	local earned = 0
	if Upgrades.machine(p.owned) > 0 then
		local rate = p.away.rate or 0 -- $ a minute when they left
		earned = math.floor(rate * Constants.OFFLINE_RATE * counted / 60)
		if earned > 0 then
			economy:Add(player, earned, "away")
		end
	end
	local s = crops:Summary(player)
	local card = {
		seconds = seconds,
		counted = counted,
		earned = earned,
		ripe = s.ripe,
		capped = seconds > counted,
		hours = hours,
	}
	if analytics then
		pcall(analytics.event, player, "welcome_back", card)
	end
	return card
end

function OfflineService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	crops = registry.CropService
	analytics = registry.AnalyticsService
end

function OfflineService:OnPlayerLoaded(player)
	pending[player] = self:Settle(player)
end

function OfflineService:OnPlayerReady(player)
	data:WhenClientReady(player, function()
		local card = pending[player]
		pending[player] = nil
		if card then
			task.delay(1.5, function()
				if player.Parent then
					Net.fire(player, "Away", card)
				end
			end)
		end
	end)
end

function OfflineService:OnPlayerLeaving(player, profile)
	profile.away = { at = os.time(), rate = economy:Income(player) }
	pending[player] = nil
end

return OfflineService
