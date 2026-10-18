--[[
The shop (Data/Shop; the SHOP panel). Robux buys Gems, the Starter Pack, Instant Harvest and the four passes; Gems
buy skips and boosts.

Robux receipts are granted exactly once (profile.receipts keeps the last RECEIPTS_KEPT ids) and saved straight
after; a save that fails answers "not processed yet" so Roblox asks again. A product or pass whose id
(Constants.PRODUCTS / PASSES) is still 0 is given free in Studio (so the whole shop can be tried) and says
"coming soon" live. Passes are checked with UserOwnsGamePassAsync each visit (bought on the website, or a save that
missed it).

  Net "Shop" ("open") | ("robux", key) a product or pass | ("gems", key) a Gem buy
  Net "Shop" to the client: { products, passes, gems, owned = { [pass] = true }, starter, boostLeft, studio }

  ShopService:Grant(player, key)       a product's goods (tests, Studio)
  ShopService:GrantPass(player, key)
  ShopService:BuyGems(player, key) -> ok, why
  ShopService:ProcessReceipt(receipt)
]]
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Shop = require(ReplicatedStorage.Shared.Data.Shop)
local Signal = require(ReplicatedStorage.Shared.Signal)

local ShopService = {
	Name = "ShopService",
	Dependencies = { "PlayerDataService", "EconomyService", "FarmService", "AnimalService", "SpecialService" },
	Bought = Signal.new("ShopService.Bought"), -- (player, key, currency "robux" | "gems")
	RECEIPTS_KEPT = 50,
}

local data, economy, farm, animals, special, analytics

local function say(player, text, kind)
	Net.fire(player, "Toast", text, kind or "info")
end

local function productKeyById(id)
	for key, pid in Constants.PRODUCTS do
		if pid ~= 0 and pid == id then
			return key
		end
	end
	return nil
end

function ShopService:Push(player)
	local p = data:Get(player)
	if not p then
		return
	end
	local products, passes, gems = {}, {}, {}
	for _, key in Shop.PRODUCT_ORDER do
		local it = Shop.PRODUCTS[key]
		if not (it.once and p.starter) then
			table.insert(
				products,
				{ key = key, name = it.name, text = it.text, robux = it.robux, soon = Constants.PRODUCTS[key] == 0 }
			)
		end
	end
	for _, key in Shop.PASS_ORDER do
		local it = Shop.PASSES[key]
		table.insert(passes, {
			key = key,
			name = it.name,
			text = it.text,
			robux = it.robux,
			owned = p.passes[key] == true,
			soon = Constants.PASSES[key] == 0,
		})
	end
	for _, key in Shop.GEM_ORDER do
		local it = Shop.GEMS[key]
		table.insert(gems, { key = key, name = it.name, text = it.text, gems = it.gems })
	end
	Net.fire(player, "Shop", {
		products = products,
		passes = passes,
		gems = gems,
		starter = p.starter == true,
		boostLeft = math.max(0, (p.boostUntil or 0) - os.time()),
		studio = RunService:IsStudio(),
	})
end

-- The goods --------------------------------------------------------------------------------------------------------
function ShopService:Grant(player, key)
	local p = data:Get(player)
	local it = Shop.PRODUCTS[key]
	if not p or not it then
		return false
	end
	if it.gems then
		economy:AddGems(player, it.gems, "robux")
		say(player, `+{it.gems} Gems! Thank you!`, "good")
	elseif key == "starter" then
		if p.starter then
			return false
		end
		p.starter = true
		local s = Shop.starter(p.level)
		economy:AddGems(player, s.gems, "starter")
		economy:Add(player, s.cash, "starter")
		p.goldenSeeds = (p.goldenSeeds or 0) + s.seeds
		say(player, `STARTER PACK: +{s.gems} Gems, +{s.cash} Cash, {s.seeds} golden seeds!`, "good")
	elseif key == "skipGrow" then
		local n = farm:RipenAll(player)
		say(player, `INSTANT HARVEST: {n} crops ripe!`, "good")
	end
	if analytics then
		pcall(analytics.event, player, "robux", { key = key })
	end
	self.Bought:Fire(player, key, "robux")
	self:Push(player)
	return true
end

function ShopService:GrantPass(player, key)
	local p = data:Get(player)
	if not p or not Shop.PASSES[key] or p.passes[key] then
		return false
	end
	p.passes[key] = true
	if key == "vip" then
		player:SetAttribute("VIP", true)
	end
	say(player, `{Shop.PASSES[key].name} is yours! Thank you!`, "good")
	if analytics then
		pcall(analytics.event, player, "pass", { key = key })
	end
	self.Bought:Fire(player, key, "robux")
	economy:Push(player)
	self:Push(player)
	return true
end

function ShopService:BuyGems(player, key)
	local p = data:Get(player)
	local it = type(key) == "string" and Shop.GEMS[key]
	if not p or not it then
		return false, "bad"
	end
	if key == "special" and (not p.owned.shed or special:Current(player)) then
		return false, p.owned.shed and "A Special Order is already on" or "Build the packing shed first"
	end
	if key == "boost" and (p.boostUntil or 0) - os.time() >= Shop.BOOST_MAX then
		return false, "Your Cash Rush is full"
	end
	if not economy:SpendGems(player, it.gems) then
		return false, `You need {it.gems - (p.gems or 0)} more Gems`
	end
	if key == "ripen" then
		say(player, `{farm:RipenAll(player)} crops ripe!`, "good")
	elseif key == "feed" then
		say(player, `{animals:FeedAll(player)} animals fed!`, "good")
	elseif key == "seeds" then
		p.goldenSeeds = (p.goldenSeeds or 0) + 10
		say(player, "+10 golden seeds!", "good")
	elseif key == "boost" then
		p.boostUntil = math.max(p.boostUntil or 0, os.time()) + Shop.BOOST_SECONDS
		say(player, "CASH RUSH! x2 everything shipped", "good")
	elseif key == "special" then
		special:Spawn(player)
	end
	if analytics then
		pcall(analytics.event, player, "gem_buy", { key = key, gems = it.gems })
	end
	self.Bought:Fire(player, key, "gems")
	self:Push(player)
	return true
end

function ShopService:PromptRobux(player, key)
	local p = data:Get(player)
	if not p or type(key) ~= "string" then
		return false, "bad"
	end
	local isPass = Shop.PASSES[key] ~= nil
	if not isPass and not Shop.PRODUCTS[key] then
		return false, "bad"
	end
	if isPass and p.passes[key] then
		return false, "That's yours already"
	end
	if key == "starter" and p.starter then
		return false, "You have the Starter Pack"
	end
	local id = isPass and Constants.PASSES[key] or Constants.PRODUCTS[key]
	if id == 0 then
		if RunService:IsStudio() then
			say(player, "Studio test: given free (set its id in Constants).")
			if isPass then
				return self:GrantPass(player, key)
			end
			return self:Grant(player, key)
		end
		return false, "Coming soon!"
	end
	if analytics then
		pcall(analytics.event, player, "buy_tap", { key = key })
	end
	if isPass then
		pcall(MarketplaceService.PromptGamePassPurchase, MarketplaceService, player, id)
	else
		pcall(MarketplaceService.PromptProductPurchase, MarketplaceService, player, id)
	end
	return true
end

function ShopService:ProcessReceipt(receipt)
	local NotYet, Granted = Enum.ProductPurchaseDecision.NotProcessedYet, Enum.ProductPurchaseDecision.PurchaseGranted
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local p = player and data:Get(player)
	local key = productKeyById(receipt.ProductId)
	if not p or not key then
		return NotYet
	end
	p.receipts = p.receipts or {}
	if table.find(p.receipts, receipt.PurchaseId) then
		return data:Save(player) and Granted or NotYet -- (given before: just make sure it's saved)
	end
	table.insert(p.receipts, receipt.PurchaseId)
	while #p.receipts > self.RECEIPTS_KEPT do
		table.remove(p.receipts, 1)
	end
	local ok, err = pcall(self.Grant, self, player, key)
	if not ok then
		warn("[ShopService] grant failed: " .. tostring(err))
		table.remove(p.receipts, table.find(p.receipts, receipt.PurchaseId))
		return NotYet
	end
	return data:Save(player) and Granted or NotYet
end

function ShopService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	farm = registry.FarmService
	animals = registry.AnimalService
	special = registry.SpecialService
	analytics = registry.AnalyticsService
	Net.on("Shop", function(player, what, key)
		local ok, why = nil, nil
		if what == "open" then
			self:Push(player)
		elseif what == "robux" then
			ok, why = self:PromptRobux(player, key)
		elseif what == "gems" then
			ok, why = self:BuyGems(player, key)
		end
		if ok == false and why and why ~= "bad" then
			say(player, why, "bad")
		end
	end)
	MarketplaceService.ProcessReceipt = function(receipt)
		return self:ProcessReceipt(receipt)
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, bought)
		if not bought then
			return
		end
		for key, id in Constants.PASSES do
			if id ~= 0 and id == passId then
				self:GrantPass(player, key)
			end
		end
	end)
end

function ShopService:OnPlayerReady(player, profile)
	profile.passes = profile.passes or {}
	if profile.passes.vip then
		player:SetAttribute("VIP", true)
	end
	task.spawn(function()
		for key, id in Constants.PASSES do
			if id ~= 0 and not profile.passes[key] then
				local ok, owns = pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
				end)
				if ok and owns and player.Parent then
					self:GrantPass(player, key)
				end
			end
		end
	end)
	data:WhenClientReady(player, function()
		self:Push(player)
	end)
end

return ShopService
