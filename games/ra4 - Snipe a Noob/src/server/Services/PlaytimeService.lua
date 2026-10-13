-- Reasons to keep playing: playtime gifts (coins and crate keys at 1, 3, 5, 10 ... 60 minutes played today; the
-- HUD counts down to the next one) and the new-player 2x boost (coins and XP) for the first 10 minutes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local PlaytimeService = {
	Name = "PlaytimeService",
	Dependencies = { "PlayerDataService", "EconomyService" },
	GiftGiven = Signal.new("PlaytimeService.GiftGiven"), -- (player, n, gift)
}

local data, economy
local online = {}

local function today(profile)
	local day = Formulas.day(os.time())
	local p = profile.playtime
	if not p or p.day ~= day then
		p = { day = day, seconds = 0, given = 0 }
		profile.playtime = p
	end
	return p
end

function PlaytimeService.giftText(g)
	if g.keys then
		return `{g.keys} crate key{g.keys > 1 and "s" or ""}`
	end
	return `{g.coins} coins`
end

function PlaytimeService:View(player)
	local profile = data:Get(player)
	local p = today(profile)
	local nextGift = Constants.PLAYTIME_GIFTS[p.given + 1]
	return {
		nextIn = nextGift and math.max(0, nextGift.minutes * 60 - p.seconds) or nil,
		nextText = nextGift and self.giftText(nextGift) or nil,
		given = p.given,
		total = #Constants.PLAYTIME_GIFTS,
	}
end

function PlaytimeService:Push(player)
	data:Push(player, { playtime = self:View(player), boostLeft = data:Get(player).newBoostLeft or 0 })
end

function PlaytimeService:_give(player, n)
	local g = Constants.PLAYTIME_GIFTS[n]
	if g.keys then
		economy:AddKeys(player, g.keys)
	else
		economy:AddCoins(player, g.coins, false)
	end
	Net.fire(player, "Alert", `🎁 {g.minutes} min gift: {self.giftText(g)}!`, Color3.fromRGB(255, 205, 50))
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
			if nextGift and p.seconds >= nextGift.minutes * 60 then
				p.given += 1
				self:_give(player, p.given)
				changed = true
			end
			if (profile.newBoostLeft or 0) > 0 then
				profile.newBoostLeft -= 1
				changed = changed or profile.newBoostLeft % 10 == 0
				if profile.newBoostLeft <= 0 then
					Net.fire(player, "Toast", "Your new-player 2x boost is over. Keep sniping! 🎯", "info")
					changed = true
				end
			end
			if changed then
				self:Push(player)
			end
		end
	end
end

function PlaytimeService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	data.ClientReady:Connect(function(player)
		if data:Get(player) then
			self:Push(player)
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
	end
end

return PlaytimeService
