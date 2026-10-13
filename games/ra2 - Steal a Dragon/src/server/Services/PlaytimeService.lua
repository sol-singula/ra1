-- Reasons to keep playing, especially in the first minutes:
--   Playtime gifts: the longer you play today, the better the gifts (Formulas.PLAYTIME_GIFTS: coins at 1 minute,
--   potions at 3, a dragon at 5, ... a big dragon at an hour). They arrive by themselves; the HUD counts down to
--   the next one and says what it is. Minutes played count per day (UTC), so rejoining doesn't restart them.
--   New-player boost: brand-new players earn double for their first 10 minutes of play (BaseService:Income).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local PlaytimeService = {
	Name = "PlaytimeService",
	Dependencies = {
		"PlayerDataService",
		"EconomyService",
		"BaseService",
		"DragonService",
		"RoadService",
		"ToolService",
	},
	GiftGiven = Signal.new("PlaytimeService.GiftGiven"), -- (player, n, gift)
}

local data, economy, baseService, dragons, road, tools
local online = {} -- [player] = true once ready

-- Today's playtime record, reset when the day changes.
local function today(profile)
	local day = Formulas.day(os.time())
	local p = profile.playtime
	if not p or p.day ~= day then
		p = { day = day, seconds = 0, given = 0 }
		profile.playtime = p
	end
	return p
end

function PlaytimeService:GiftFor(player, n)
	local profile = data:Get(player)
	return Formulas.playtimeGift(
		n,
		baseService:Income(player),
		Formulas.bestSpecies(profile.dragons),
		today(profile).day * 10 + n
	)
end

-- What the HUD shows: seconds to the next gift and what it is, and the new-player boost left.
function PlaytimeService:View(player)
	local profile = data:Get(player)
	local p = today(profile)
	local nextGift = Formulas.PLAYTIME_GIFTS[p.given + 1]
	return {
		nextIn = nextGift and math.max(0, nextGift.at - p.seconds) or nil,
		nextText = nextGift and self:GiftFor(player, p.given + 1).text or nil,
		given = p.given,
		total = #Formulas.PLAYTIME_GIFTS,
		boostLeft = profile.newBoostLeft or 0,
	}
end

function PlaytimeService:Push(player)
	data:Push(player, { playtime = self:View(player) })
end

function PlaytimeService:_give(player, n)
	local gift = self:GiftFor(player, n)
	if gift.kind == "coins" then
		economy:Add(player, gift.amount)
	elseif gift.kind == "dragon" then
		dragons:Grant(player, gift.id)
	elseif gift.kind == "potion" then
		tools:AddPotions(player, gift.count)
	elseif gift.kind == "luck" then
		road:AddLuck(Constants.LUCK_SECONDS, player.DisplayName)
	end
	local minutes = math.floor(Formulas.PLAYTIME_GIFTS[n].at / 60)
	Net.fire(player, "Alert", `🎁 {minutes} min playtime gift: {gift.text}!`, Color3.fromRGB(255, 205, 50))
	Net.fire(player, "Sfx", "buy")
	-- and straight away, the next thing to stay for
	local nextGift = Formulas.PLAYTIME_GIFTS[n + 1]
	if nextGift then
		local wait = math.max(1, math.ceil((nextGift.at - Formulas.PLAYTIME_GIFTS[n].at) / 60))
		local nextText = self:GiftFor(player, n + 1).text
		task.delay(3, function()
			if player.Parent then
				Net.fire(player, "Toast", `🎁 Next gift in {wait} min: {nextText}! Keep playing!`, "good")
			end
		end)
	end
	self.GiftGiven:Fire(player, n, gift)
end

-- One second of play for everyone online.
function PlaytimeService:_tick()
	for player in online do
		local profile = data:Get(player)
		if profile then
			local p = today(profile)
			p.seconds += 1
			local changed = false
			local nextGift = Formulas.PLAYTIME_GIFTS[p.given + 1]
			if nextGift and p.seconds >= nextGift.at then
				p.given += 1
				self:_give(player, p.given)
				changed = true
			end
			if (profile.newBoostLeft or 0) > 0 then
				profile.newBoostLeft -= 1
				if profile.newBoostLeft <= 0 then
					Net.fire(player, "Toast", "Your new-player 2x boost is over. Keep stealing! 🐉", "info")
					changed = true
				end
			end
			if changed then
				baseService:PushIncome(player)
				self:Push(player)
			end
		end
	end
end

function PlaytimeService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	baseService = registry.BaseService
	dragons = registry.DragonService
	road = registry.RoadService
	tools = registry.ToolService
	data.ClientReady:Connect(function(player)
		if data:Get(player) then
			self:Push(player)
		end
	end)
end

function PlaytimeService:OnPlayerReady(player, profile)
	if profile.newBoostLeft == nil then
		-- only brand-new players (older saves never had this field)
		profile.newBoostLeft = profile._isNew and Constants.NEW_PLAYER_BOOST_SECONDS or 0
	end
	online[player] = true
	self:Push(player)
	baseService:PushIncome(player)
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
