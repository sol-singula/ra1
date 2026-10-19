--[[
Robux (master plan §11, Data/Shop): boosts for the whole server, cash packs sized by your own income, passes.
Ids of 0 (not made on Roblox yet) are granted free in Studio so the shop can be tried, and show "coming soon" on
a live server. Receipts are granted once (profile.receipts).

  ShopService:Grant(player, key)   apply a product (tests call it)
  ShopService:Push(player)
]]
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Shop = require(ReplicatedStorage.Shared.Data.Shop)

local ShopService = {
	Name = "ShopService",
	Dependencies = { "PlayerDataService", "EconomyService", "BoostService" },
}

local data, economy, boosts, analytics

local function productKey(id)
	for key, pid in Constants.PRODUCTS do
		if pid == id and id ~= 0 then
			return key
		end
	end
	return nil
end

local function passKey(id)
	for key, pid in Constants.PASSES do
		if pid == id and id ~= 0 then
			return key
		end
	end
	return nil
end

function ShopService:Grant(player, key)
	local p = data:Get(player)
	if not p then
		return false
	end
	if Shop.BOOSTS[key] then
		boosts:Activate(key, player)
	elseif Shop.PRODUCTS[key] then
		local rate = math.max(economy:Income(player), 10)
		local amount = math.floor(rate * Shop.PRODUCTS[key].minutes)
		economy:Add(player, amount, "product")
		Net.fire(player, "Toast", `{Shop.PRODUCTS[key].name}: +${amount}!`, "good")
	elseif Shop.PASSES[key] then
		p.passes[key] = true
		Net.fire(player, "Toast", `{Shop.PASSES[key].name} is yours!`, "good")
	else
		return false
	end
	if analytics then
		pcall(analytics.event, player, "purchase_completed", { key = key })
	end
	self:Push(player)
	return true
end

function ShopService:Push(player)
	local p = data:Get(player)
	if not p then
		return
	end
	local function entry(key, def, id)
		return {
			key = key,
			name = def.name,
			desc = def.desc,
			robux = def.robux,
			icon = def.icon,
			id = id,
			soon = id == 0 and not RunService:IsStudio(),
		}
	end
	local out = { boosts = {}, products = {}, passes = {}, owned = p.passes }
	for _, key in Shop.BOOST_LIST do
		table.insert(out.boosts, entry(key, Shop.BOOSTS[key], Constants.PRODUCTS[key] or 0))
	end
	for _, key in Shop.PRODUCT_LIST do
		table.insert(out.products, entry(key, Shop.PRODUCTS[key], Constants.PRODUCTS[key] or 0))
	end
	for _, key in Shop.PASS_LIST do
		table.insert(out.passes, entry(key, Shop.PASSES[key], Constants.PASSES[key] or 0))
	end
	Net.fire(player, "Shop", out)
end

local function prompt(player, key)
	local p = data:Get(player)
	if not p then
		return
	end
	if Shop.PASSES[key] then
		if p.passes[key] then
			return
		end
		local id = Constants.PASSES[key] or 0
		if id == 0 then
			if RunService:IsStudio() then
				ShopService:Grant(player, key)
			else
				Net.fire(player, "Toast", "Coming soon!", "info")
			end
			return
		end
		pcall(MarketplaceService.PromptGamePassPurchase, MarketplaceService, player, id)
	else
		local id = Constants.PRODUCTS[key] or 0
		if id == 0 then
			if RunService:IsStudio() then
				ShopService:Grant(player, key)
			else
				Net.fire(player, "Toast", "Coming soon!", "info")
			end
			return
		end
		pcall(MarketplaceService.PromptProductPurchase, MarketplaceService, player, id)
	end
end

function ShopService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	boosts = registry.BoostService
	analytics = registry.AnalyticsService
	Net.on("Shop", function(player, what, key)
		if what == "open" then
			self:Push(player)
		elseif what == "buy" and type(key) == "string" then
			prompt(player, key)
		end
	end)
	MarketplaceService.ProcessReceipt = function(receipt)
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		local p = player and data:Get(player)
		if not p then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if p.receipts[receipt.PurchaseId] then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		local key = productKey(receipt.ProductId)
		if not key then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		p.receipts[receipt.PurchaseId] = true
		self:Grant(player, key)
		if data:Save(player) then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, bought)
		if bought then
			local key = passKey(passId)
			if key then
				self:Grant(player, key)
			end
		end
	end)
end

function ShopService:OnPlayerLoaded(player, profile)
	-- passes bought while away
	for key, id in Constants.PASSES do
		if id ~= 0 and not profile.passes[key] then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, id)
			if ok and owns then
				profile.passes[key] = true
			end
		end
	end
end

function ShopService:OnPlayerReady(player)
	data:WhenClientReady(player, function()
		self:Push(player)
	end)
end

return ShopService
