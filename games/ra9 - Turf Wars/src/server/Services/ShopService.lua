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

local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Locker = require(ReplicatedStorage.Shared.Data.Locker)
local Net = require(ReplicatedStorage.Shared.Net)
local Season = require(ReplicatedStorage.Shared.Data.Season)
local Shop = require(ReplicatedStorage.Shared.Data.Shop)
local Signal = require(ReplicatedStorage.Shared.Signal)

local ShopService = {
	Name = "ShopService",
	Dependencies = { "PlayerDataService", "EconomyService", "SeasonService", "ProgressService" },
	Bought = Signal.new("ShopService.Bought"), -- (player, what, shards?, robux?)
}

local data, economy, season, progress

-- (the same clock the clients read: the shop's rotation must agree on both sides)
function ShopService.now()
	return math.floor(workspace:GetServerTimeNow())
end

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
		return false, `You need {price - (p.shards or 0)} more ◆.`
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
		return false, `You need {bundle.price - (p.shards or 0)} more ◆.`
	end
	for _, k in bundle.keys do
		economy:Give(player, k)
	end
	self.Bought:Fire(player, "bundle", bundle.price, nil)
	return true
end

-- Robux ----------------------------------------------------------------------------------------------------------
function ShopService:Grant(player, product)
	if product.shards then
		economy:Add(player, product.shards, "robux")
		say(player, `+{product.shards} ◆  Thank you!`, "good")
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
	if economy:Receipt(player, receipt.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- (granted before)
	end
	self:Grant(player, product)
	data:Save(player)
	progress:Push(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
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
	say(player, `Shard Club: +{Shop.CLUB.monthlyShards} ◆ for this month!`, "good")
	return true
end

function ShopService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	season = registry.SeasonService
	progress = registry.ProgressService
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
			say(player, `+{r.amount} ◆`, "good")
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
	end)
end

function ShopService:OnPlayerReady(player)
	task.spawn(function()
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
