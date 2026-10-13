-- Coins, game-pass ownership and the player list stats (leaderstats).
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Shop = require(ReplicatedStorage.Shared.Data.Shop)
local Signal = require(ReplicatedStorage.Shared.Signal)

local EconomyService = {
	Name = "EconomyService",
	Dependencies = { "PlayerDataService" },
	PassesChanged = Signal.new("EconomyService.PassesChanged"), -- (player)
	PassesLoaded = Signal.new("EconomyService.PassesLoaded"), -- (player, { [key] = true } owned on Roblox)
}

local data
local owned = {} -- [player] = { DOUBLE = true, ... } from Roblox (live) plus the profile's remembered passes

function EconomyService:Init(registry)
	data = registry.PlayerDataService
	data.ClientReady:Connect(function(player)
		self:PushCoins(player)
		local profile = data:Get(player)
		data:Push(player, {
			passes = self:Passes(player),
			speedLevel = self:SpeedLevel(player),
			weaponLevel = profile and profile.weaponLevel or 1,
		})
	end)
end

function EconomyService:OnPlayerReady(player, profile)
	owned[player] = table.clone(profile.passes)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local coins = Instance.new("NumberValue")
	coins.Name = "Coins"
	coins.Value = profile.coins
	coins.Parent = stats
	local steals = Instance.new("IntValue")
	steals.Name = "Steals"
	steals.Value = profile.steals
	steals.Parent = stats
	stats.Parent = player
	-- ask Roblox which passes this player owns (in the background; a failure just means "not owned")
	task.spawn(function()
		local fromRoblox = {} -- the passes Roblox says this account owns (bought here or on the game page)
		for _, pass in Shop.Passes do
			if pass.id ~= 0 then
				local ok, has =
					pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
				if ok and has and owned[player] then
					owned[player][pass.key] = true
					fromRoblox[pass.key] = true
				end
			end
		end
		if player.Parent then
			self.PassesChanged:Fire(player)
			self.PassesLoaded:Fire(player, fromRoblox)
			data:Push(player, { passes = self:Passes(player) })
		end
	end)
end

function EconomyService:OnPlayerLeaving(player)
	owned[player] = nil
end

-- VIP can also be a gift for a while (the Admin panel): profile.vipUntil (os.time). Gifted VIP counts as the pass.
local function giftedVip(player)
	local profile = data and data:Get(player)
	return profile ~= nil and (profile.vipUntil or 0) > os.time()
end

function EconomyService:Passes(player)
	local list = owned[player] or {}
	if not list.VIP and giftedVip(player) then
		list = table.clone(list)
		list.VIP = true
	end
	return list
end

function EconomyService:HasPass(player, key)
	if key == "VIP" and giftedVip(player) then
		return true
	end
	return (owned[player] or {})[key] == true
end

-- Give VIP for a number of seconds (on top of any gifted time left). The admin panel uses this.
function EconomyService:GiftVip(player, seconds)
	local profile = data:Get(player)
	if not profile then
		return false
	end
	profile.vipUntil = math.max(profile.vipUntil or 0, os.time()) + seconds
	self.PassesChanged:Fire(player)
	data:Push(player, { passes = self:Passes(player), vipUntil = profile.vipUntil })
	-- when it runs out, everything that depends on VIP updates (wings, the name tag, coins)
	task.delay(seconds + 1, function()
		if player.Parent and not giftedVip(player) then
			self.PassesChanged:Fire(player)
			data:Push(player, { passes = self:Passes(player), vipUntil = 0 })
		end
	end)
	return true
end

-- Record a pass (after a purchase, or a free Studio test grant).
function EconomyService:GrantPass(player, key)
	local profile = data:Get(player)
	if not profile or not owned[player] then
		return
	end
	owned[player][key] = true
	profile.passes[key] = true
	self.PassesChanged:Fire(player)
	data:Push(player, { passes = self:Passes(player) })
end

function EconomyService:PushCoins(player)
	local profile = data:Get(player)
	if not profile then
		return
	end
	data:Push(player, { coins = profile.coins, earned = profile.earned, steals = profile.steals })
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		stats.Coins.Value = math.floor(profile.coins)
		stats.Steals.Value = profile.steals
	end
end

-- Add coins. countsAsEarned = false for refunds and sales, so the "earned" leaderboard only counts income.
function EconomyService:Add(player, amount, countsAsEarned)
	local profile = data:Get(player)
	if not profile or amount <= 0 then
		return
	end
	profile.coins += amount
	if countsAsEarned ~= false then
		profile.earned += amount
		EconomyService.addDaily(profile, amount)
	end
	self:PushCoins(player)
end

-- Coins earned in today's period (the daily TOP EARNERS board); starts over when a new period begins.
function EconomyService.addDaily(profile, amount)
	local period = Formulas.dailyPeriod(os.time())
	if profile.dailyPeriod ~= period then
		profile.dailyPeriod = period
		profile.dailyEarned = 0
	end
	profile.dailyEarned += amount
end

function EconomyService.dailyEarned(profile)
	return profile.dailyPeriod == Formulas.dailyPeriod(os.time()) and profile.dailyEarned or 0
end

function EconomyService:Spend(player, amount)
	local profile = data:Get(player)
	if not profile or profile.coins < amount then
		return false
	end
	profile.coins -= amount
	self:PushCoins(player)
	return true
end

function EconomyService:SpeedLevel(player)
	local profile = data:Get(player)
	return profile and profile.speedLevel or 1
end

function EconomyService:Start()
	Net.on("BuySpeed", function(player)
		local profile = data:Get(player)
		if not profile then
			return
		end
		local price = Formulas.speedPrice(profile.speedLevel)
		if not price then
			Net.fire(player, "Toast", "Your speed is maxed out!", "info")
			return
		end
		if not self:Spend(player, price) then
			Net.fire(player, "Toast", "Not enough coins!", "bad")
			return
		end
		profile.speedLevel += 1
		data:Push(player, { speedLevel = profile.speedLevel })
		Net.fire(player, "Toast", `Speed level {profile.speedLevel}! You run faster.`, "good")
		self.PassesChanged:Fire(player) -- walk speed depends on it too
	end)
end

return EconomyService
