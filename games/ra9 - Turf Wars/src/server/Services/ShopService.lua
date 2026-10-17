--[[
Buying (Data/Shop): cosmetics for Shards from the day's rotation and the week's bundle, and Robux: Shard packs, the
season's Turf Pass, +1 pass tier (developer products), the Starter Pack (a game pass), and the Shard Club (a
Roblox subscription, when its id is set). Claiming the pass's tiers too. Cosmetic only, all of it.

Robux receipts are granted exactly once (EconomyService:Receipt) and saved straight after. A product whose id is
still 0 is given for free in Studio, so the whole shop can be tried before the products exist.

  Net "Buy" ("item", key) | ("bundle") | ("robux", productKey | "starter")
  Net "Claim" (tier, "f" | "p")
  ShopService:Reroll(player)   an admin's RESET SHOP: 4 new daily items for this player (until they leave)
]]
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Locker = require(ReplicatedStorage.Shared.Data.Locker)
local Net = require(ReplicatedStorage.Shared.Net)
local Season = require(ReplicatedStorage.Shared.Data.Season)
local Shop = require(ReplicatedStorage.Shared.Data.Shop)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Weapons = require(ReplicatedStorage.Shared.Data.Weapons)

local ShopService = {
	Name = "ShopService",
	Dependencies = { "PlayerDataService", "EconomyService", "SeasonService", "ProgressService" },
	Bought = Signal.new("ShopService.Bought"), -- (player, what, shards?, robux?)
}

local data, economy, season, progress, combat

-- (the same clock the clients read: the shop's rotation must agree on both sides)
function ShopService.now()
	return math.floor(workspace:GetServerTimeNow())
end

local Notify = require(script.Parent.Parent.Notify)

local function say(player, text, kind)
	Net.fire(player, "Toast", text, kind or "info")
end

-- Shards ---------------------------------------------------------------------------------------------------------
function ShopService:BuyItem(player, key)
	local p = data:Get(player)
	local it = Cosmetics.get(key)
	if not p or not it or it.source ~= "shop" then
		return false, "That isn't for sale."
	end
	if Locker.owns(p, key) then
		return false, "You have it already."
	end
	if not Shop.inRotation(key, self.now(), player:GetAttribute("ShopRoll")) then
		return false, "That's not in the shop today."
	end
	local price = Shop.price(it)
	if not economy:Spend(player, price) then
		return false, `You need {price - (p.shards or 0)} more Shards.`
	end
	economy:Give(player, key)
	p.equipped[it.kind] = key
	self.Bought:Fire(player, key, price, nil)
	return true
end

-- A new roll of today's items for one player (Shop.daily's roll, on the Player so their client shows the same).
function ShopService:Reroll(player)
	local roll = (tonumber(player:GetAttribute("ShopRoll")) or 0) + 1
	player:SetAttribute("ShopRoll", roll)
	return roll
end

function ShopService:BuyBundle(player)
	local p = data:Get(player)
	if not p then
		return false, "bad"
	end
	local bundle = Shop.weekly(Shop.weekOf(self.now()))
	local missing = 0
	for _, k in bundle.keys do
		if not Locker.owns(p, k) then
			missing += 1
		end
	end
	if missing == 0 then
		return false, "You have the whole bundle."
	end
	if not economy:Spend(player, bundle.price) then
		return false, `You need {bundle.price - (p.shards or 0)} more Shards.`
	end
	for _, k in bundle.keys do
		economy:Give(player, k)
	end
	self.Bought:Fire(player, "bundle", bundle.price, nil)
	return true
end

-- Robux ----------------------------------------------------------------------------------------------------------
function ShopService:Grant(player, product)
	if product.cosmetic then
		-- (a Robux-only cosmetic: yours for good, and put on)
		economy:Give(player, product.cosmetic)
		local it = Cosmetics.get(product.cosmetic)
		if it then
			data:Get(player).equipped[it.kind] = it.key
			progress.card(player, it.key, "YOURS FOREVER!", it.name)
		end
	elseif product.shards then
		economy:Add(player, product.shards, "robux")
		say(player, `+{product.shards} Shards!  Thank you!`, "good")
	elseif product.key == "pass" then
		season:GrantPremium(player)
		local n = season:State(player).n
		progress.card(player, `s{n}_1p`, "TURF PASS!", `{Season.name(n)}: the premium track is yours`)
	elseif product.key == "tier" then
		season:AddTiers(player, 1)
		say(player, "+1 pass tier!", "good")
	end
	local p = data:Get(player)
	p.stats.robux = (p.stats.robux or 0) + (product.robux or 0)
	self.Bought:Fire(player, product.key, nil, product.robux)
end

function ShopService:GrantStarter(player)
	local p = data:Get(player)
	if not p or p.starter then
		return false
	end
	p.starter = true
	economy:Add(player, Shop.STARTER.shards, "starter")
	economy:Give(player, Shop.STARTER.cosmetic)
	progress.card(player, Shop.STARTER.cosmetic, "STARTER PACK!", Shop.STARTER.desc)
	self.Bought:Fire(player, "starter", nil, Shop.STARTER.robux)
	return true
end

-- The free TNT try: one throw an hour for anyone who hasn't bought it (profile.tntTriedAt, os.time). Sets the
-- attributes the hotbar and every check read: TntTry (ready now), TntTryAt (when the next one comes).
function ShopService:RefreshTry(player)
	local p = data:Get(player)
	if not p or player:GetAttribute("OwnsTNT") == true then
		player:SetAttribute("TntTry", nil)
		player:SetAttribute("TntTryAt", nil)
		return
	end
	local at = (p.tntTriedAt or 0) + Constants.TNT_TRY_SECONDS
	local ready = os.time() >= at
	if player:GetAttribute("TntTry") ~= ready then
		player:SetAttribute("TntTry", ready)
	end
	player:SetAttribute("TntTryAt", (not ready) and at or nil)
end

-- A TNT thrown on the free try: used up (the hour starts now), and the bow back in hand
function ShopService:UseTry(player)
	local p = data:Get(player)
	if not p or player:GetAttribute("OwnsTNT") == true then
		return false
	end
	p.tntTriedAt = os.time()
	self:RefreshTry(player)
	task.delay(0.6, function()
		if player.Parent and Weapons.locked("tnt", player) then
			combat:Equip(player, Weapons.DEFAULT)
		end
	end)
	Notify.to(
		player,
		`That was your free TNT! Get it for good: {Shop.TNT.robux} Robux (50% off)`,
		"info",
		{ icon = "🧨", seconds = 5 }
	)
	return true
end

-- The TNT for good (Shop.TNT): saved, and the attribute every check reads (Weapons.locked)
function ShopService:GrantTNT(player, quiet)
	local p = data:Get(player)
	if not p then
		return false
	end
	player:SetAttribute("OwnsTNT", true)
	player:SetAttribute("TntTry", nil)
	player:SetAttribute("TntTryAt", nil)
	if p.tnt then
		return false
	end
	p.tnt = true
	if not quiet then
		Notify.to(
			player,
			"TNT unlocked for good! Press 2: hold to wind up, let go to lob it",
			"good",
			{ icon = "🧨", seconds = 5 }
		)
		self.Bought:Fire(player, "tnt", nil, Shop.TNT.robux)
	end
	return true
end

local function studio(player, name)
	if RunService:IsStudio() then
		say(player, `Studio test: {name} given free (set its id in Data/Shop).`)
		return true
	end
	return false
end

function ShopService:PromptRobux(player, key)
	if key == "tnt" then
		if player:GetAttribute("OwnsTNT") == true then
			return false, "The TNT is yours."
		end
		if Shop.TNT.id == 0 then
			if studio(player, Shop.TNT.name) then
				self:GrantTNT(player)
				return true
			end
			return false, "The TNT isn't on sale yet."
		end
		pcall(MarketplaceService.PromptGamePassPurchase, MarketplaceService, player, Shop.TNT.id)
		return true
	end
	if key == "starter" then
		local p = data:Get(player)
		if p and p.starter then
			return false, "You have the Starter Pack."
		end
		if Shop.STARTER.id == 0 then
			if studio(player, Shop.STARTER.name) then
				self:GrantStarter(player)
				return true
			end
			return false, "Not on sale yet."
		end
		pcall(MarketplaceService.PromptGamePassPurchase, MarketplaceService, player, Shop.STARTER.id)
		return true
	end
	local product = Shop.products[key]
	if not product then
		return false, "bad"
	end
	if product.cosmetic and (data:Get(player).owned or {})[product.cosmetic] then
		return false, "That's already yours."
	end
	if key == "pass" and season:State(player).premium then
		return false, "You have this season's pass."
	end
	if key == "tier" and Season.tierOf(season:State(player).xp) >= Season.TIERS then
		return false, "You're at the top tier."
	end
	if product.id == 0 then
		if studio(player, product.name) then
			self:Grant(player, product)
			return true
		end
		return false, "Not on sale yet."
	end
	pcall(MarketplaceService.PromptProductPurchase, MarketplaceService, player, product.id)
	return true
end

function ShopService:ProcessReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local p = player and data:Get(player)
	if not p then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- (Roblox tries again when they're back)
	end
	local product = Shop.productById(receipt.ProductId)
	if not product then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- granted only once it's saved: a save that fails says "not yet", and Roblox asks again (the receipt id
	-- kept in the profile stops it being given twice)
	local Granted, NotYet = Enum.ProductPurchaseDecision.PurchaseGranted, Enum.ProductPurchaseDecision.NotProcessedYet
	if economy:Receipt(player, receipt.PurchaseId) then
		return data:Save(player) and Granted or NotYet -- (given before: just make sure it's saved)
	end
	local ok, err = pcall(self.Grant, self, player, product)
	if not ok then
		warn("[ShopService] grant failed: " .. tostring(err))
		local i = p.receipts and table.find(p.receipts, receipt.PurchaseId)
		if i then
			table.remove(p.receipts, i) -- (not given: the retry gives it)
		end
		return NotYet
	end
	progress:Push(player)
	return data:Save(player) and Granted or NotYet
end

-- The Shard Club: a month's Shards, once a month, while subscribed
function ShopService:CheckClub(player)
	local id = Shop.CLUB.subscriptionId
	local p = data:Get(player)
	if not id or not p then
		return false
	end
	local ok, status = pcall(function()
		return MarketplaceService:GetUserSubscriptionStatusAsync(player, id)
	end)
	if not ok or type(status) ~= "table" or not status.IsSubscribed then
		return false
	end
	local d = os.date("!*t", self.now())
	local month = d.year * 12 + d.month
	p.club = p.club or {}
	if p.club.month == month then
		return false
	end
	p.club.month = month
	economy:Add(player, Shop.CLUB.monthlyShards, "club")
	say(player, `Shard Club: +{Shop.CLUB.monthlyShards} Shards for this month!`, "good")
	return true
end

function ShopService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	season = registry.SeasonService
	progress = registry.ProgressService
	combat = registry.CombatService
	-- (the free try: a throw without the TNT bought uses it up)
	combat.Shot:Connect(function(player, key)
		if key == "tnt" and Weapons.trying(key, player) then
			self:UseTry(player)
		end
	end)
	-- (the hour comes round: the try is back)
	task.spawn(function()
		while true do
			task.wait(5)
			for _, player in Players:GetPlayers() do
				pcall(self.RefreshTry, self, player)
			end
		end
	end)
	-- (a tap on the locked TNT: the purchase, right there)
	registry.CombatService.Locked:Connect(function(player, key)
		if key == "tnt" then
			local ok, why = self:PromptRobux(player, "tnt")
			if ok == false and why then
				say(player, why, "bad")
			end
		end
	end)
	Net.on("Buy", function(player, kind, key)
		local ok, why
		if kind == "item" and type(key) == "string" then
			ok, why = self:BuyItem(player, key)
		elseif kind == "bundle" then
			ok, why = self:BuyBundle(player)
		elseif kind == "robux" and type(key) == "string" then
			ok, why = self:PromptRobux(player, key)
		end
		if ok == false and why and why ~= "bad" then
			say(player, why, "bad")
		elseif ok and kind ~= "robux" then
			say(player, kind == "bundle" and "Bundle unlocked!" or "Bought and equipped!", "good")
		end
		progress:Push(player)
	end)
	Net.on("Claim", function(player, tier, track)
		local r, why = season:Claim(player, tier, track)
		if not r then
			if why ~= "bad" then
				say(player, why, "bad")
			end
		elseif r.kind == "shards" then
			say(player, `+{r.amount} Shards`, "good")
		else
			local it = Cosmetics.get(r.key)
			say(player, `{it.name} is yours!`, "good")
		end
		progress:Push(player)
	end)
	MarketplaceService.ProcessReceipt = function(receipt)
		return self:ProcessReceipt(receipt)
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, bought)
		if bought and passId == Shop.STARTER.id and Shop.STARTER.id ~= 0 then
			self:GrantStarter(player)
			progress:Push(player)
		end
		if bought and passId == Shop.TNT.id and Shop.TNT.id ~= 0 then
			self:GrantTNT(player)
			progress:Push(player)
		end
	end)
end

function ShopService:OnPlayerReady(player, profile)
	if profile and profile.tnt then
		player:SetAttribute("OwnsTNT", true)
	end
	self:RefreshTry(player)
	task.spawn(function()
		-- (bought on the website, or a save that missed it: the pass itself says so)
		if Shop.TNT.id ~= 0 and player:GetAttribute("OwnsTNT") ~= true then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, Shop.TNT.id)
			end)
			if ok and owns then
				self:GrantTNT(player, true)
			end
		end
		if Shop.STARTER.id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, Shop.STARTER.id)
			end)
			if ok and owns then
				data:WhenClientReady(player, function()
					if self:GrantStarter(player) then
						progress:Push(player)
					end
				end)
			end
		end
		if self:CheckClub(player) then
			progress:Push(player)
		end
	end)
end

return ShopService
