-- Robux purchases: opens Roblox's purchase prompts, grants game passes, and handles developer product
-- receipts exactly once (receipt ids are remembered in the profile and saved right away).
-- Products and passes whose ID is still 0 are granted for free in Studio so everything can be tested.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Dragons = require(ReplicatedStorage.Shared.Data.Dragons)
local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Shop = require(ReplicatedStorage.Shared.Data.Shop)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Skins = require(ReplicatedStorage.Shared.Data.Skins)

local ShopService = {
	Name = "ShopService",
	Dependencies = {
		"PlayerDataService",
		"EconomyService",
		"DragonService",
		"BaseService",
		"RoadService",
		"RewardService",
		"ToolService",
	},
	Purchased = Signal.new("ShopService.Purchased"), -- (player, name, robux) a real Robux purchase went through
}

local data, economy, dragons, baseService, road, reward, tools
local targets = {} -- [player] = { [productKey] = target } remembered between prompt and receipt
local MAX_RECEIPTS = 60

function ShopService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	dragons = registry.DragonService
	baseService = registry.BaseService
	road = registry.RoadService
	reward = registry.RewardService
	tools = registry.ToolService

	Net.on("Purchase", function(player, kind, key, target)
		if type(key) ~= "string" then
			return
		end
		if kind == "pass" then
			self:PromptPass(player, key)
		elseif kind == "product" then
			self:PromptProduct(player, key, target)
		end
	end)
	dragons.GrowRequested:Connect(function(player, uid)
		self:PromptProduct(player, "GROW", uid)
	end)
	road.BuyNowRequested:Connect(function(player, roadId)
		local err = road:CanTake(player, road:Entry(roadId))
		if err then
			Net.fire(player, "Toast", err, "bad")
			return
		end
		self:PromptProduct(player, "BUYNOW", roadId)
	end)
	reward.HatchNowRequested:Connect(function(player)
		self:PromptProduct(player, "HATCH")
	end)
	tools.PotionsRequested:Connect(function(player)
		self:PromptProduct(player, "POTIONS")
	end)
	-- the plates in each base: Auto Collect (next to the coin pad) and 5-Minute Lock (next to the lock pad)
	baseService.PlateStepped:Connect(function(player, plate)
		if plate == "auto" then
			if economy:HasPass(player, "AUTO") then
				Net.fire(player, "Toast", "Auto Collect is ON: coins come right to you! 🧲", "good")
			else
				self:PromptPass(player, "AUTO")
			end
		elseif plate == "lock" then
			self:PromptProduct(player, "LOCK5")
		elseif plate == "levelall" then
			local bought, spent = dragons:LevelAll(player)
			if bought > 0 then
				Net.fire(player, "Toast", `⬆️ {bought} level-ups for {Format.num(spent)} coins!`, "good")
				Net.fire(player, "Sfx", "levelup")
			elseif dragons:CanLevelAny(player) then
				-- can't afford a single level: offer the +5 Levels for ALL boost
				self:PromptProduct(player, "LEVELALL")
			else
				Net.fire(player, "Toast", "Put dragons in your nests first!", "info")
			end
		end
	end)
	-- skins: coin skins are bought here, Robux skins through their product
	Net.on("BuySkin", function(player, key)
		self:BuySkin(player, key)
	end)
	Net.on("EquipSkin", function(player, key)
		self:EquipSkin(player, key)
	end)
	data.ClientReady:Connect(function(player)
		self:PushSkins(player)
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local pass = Shop.passById[passId]
		if purchased and pass then
			economy:GrantPass(player, pass.key)
			Net.fire(player, "Alert", `Thank you! {pass.name} is yours! {pass.icon}`, Color3.fromRGB(80, 220, 120))
			self.Purchased:Fire(player, pass.name, pass.price)
		end
	end)
	MarketplaceService.ProcessReceipt = function(info)
		return self:ProcessReceipt(info)
	end
end

function ShopService:OnPlayerLeaving(player)
	targets[player] = nil
end

local function studioFree(player, item)
	if RunService:IsStudio() then
		Net.fire(player, "Toast", `Studio test: {item.name} given for free (set its ID in Shop.lua).`, "info")
		return true
	end
	Net.fire(player, "Toast", "Coming soon!", "info")
	return false
end

function ShopService:PromptPass(player, key)
	local pass = Shop.passByKey[key]
	if not pass or economy:HasPass(player, key) then
		return
	end
	if pass.id == 0 then
		if studioFree(player, pass) then
			economy:GrantPass(player, key)
		end
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, pass.id)
end

function ShopService:PromptProduct(player, key, target)
	local product = Shop.productByKey[key]
	if not product then
		return
	end
	targets[player] = targets[player] or {}
	targets[player][key] = target
	if product.id == 0 then
		if studioFree(player, product) then
			self:Grant(player, key, target)
		end
		return
	end
	MarketplaceService:PromptProductPurchase(player, product.id)
end

-- Give what a product buys. Returns true when granted.
function ShopService:Grant(player, key, target)
	local profile = data:Get(player)
	if not profile then
		return false
	end
	Net.fire(player, "Sfx", "buy")
	local income = baseService:Income(player)
	if key == "LUCK" then
		road:AddLuck(Constants.LUCK_SECONDS, player.DisplayName)
		Net.fireAll(
			"Alert",
			`🍀 {player.DisplayName} bought SERVER LUCK! Rare dragons for everyone!`,
			Color3.fromRGB(80, 220, 120)
		)
	elseif key == "LOCKNOW" then
		baseService:Lock(player)
	elseif key == "LOCK5" then
		baseService:Lock(player, Constants.LOCK_BOOST_SECONDS)
	elseif key == "COINS_S" then
		economy:Add(player, math.max(1000, math.floor(income * 600)))
	elseif key == "COINS_L" then
		economy:Add(player, math.max(25000, math.floor(income * 7200)))
	elseif key == "DEAL" then
		local id = Formulas.dailyDeal(Formulas.day(os.time()))
		dragons:Grant(player, id)
		Net.fire(player, "Alert", `Daily Deal: {Dragons.byId[id].name}! 🎁`, Color3.fromRGB(255, 205, 50))
	elseif key == "GROW" then
		if not dragons:AddLevels(player, target, Constants.GROW_PRODUCT_LEVELS) then
			economy:Add(player, math.max(1000, math.floor(income * 600)), false) -- no dragon below MAX: coins instead
		end
	elseif key == "LEVELALL" then
		if dragons:AddLevelsAll(player, Constants.LEVEL_ALL_PRODUCT_LEVELS) == 0 then
			economy:Add(player, math.max(1000, math.floor(income * 600)), false) -- nothing to level: coins instead
		end
	elseif key == "POTIONS" then
		tools:AddPotions(player, Constants.POTION_PACK)
	elseif Skins.byProduct[key] then
		self:GiveSkin(player, Skins.byProduct[key].key)
	elseif key == "HATCH" then
		reward:HatchNow(player)
		reward:Hatch(player)
	elseif key == "BUYNOW" then
		local entry = road:Entry(target)
		if not road:GiveFromRoad(player, target) then
			-- it walked away or someone took it: pay out its coin price instead
			local coins = entry and entry.price or math.max(5000, math.floor(income * 600))
			economy:Add(player, coins, false)
			Net.fire(player, "Toast", `It got away! You get {Format.num(coins)} coins instead.`, "info")
		end
	elseif key == "OFFLINE2X" then
		if reward:OfflinePending(player) then
			reward:ClaimOffline(player, true)
		else
			economy:Add(player, math.max(500, math.floor(income * 600)))
		end
	else
		return false
	end
	return true
end

-- Skins --------------------------------------------------------------------------------------------------------
function ShopService:PushSkins(player)
	local profile = data:Get(player)
	if profile then
		data:Push(player, { skins = profile.skins, skin = profile.skin })
	end
end

function ShopService:GiveSkin(player, key)
	local profile = data:Get(player)
	local skin = Skins.byKey[key]
	if not profile or not skin then
		return
	end
	profile.skins[key] = true
	self:EquipSkin(player, key)
	Net.fire(player, "Alert", `New skin: {skin.name}! {skin.icon}`, Color3.fromRGB(80, 220, 120))
end

function ShopService:BuySkin(player, key)
	local profile = data:Get(player)
	local skin = type(key) == "string" and Skins.byKey[key]
	if not profile or not skin or profile.skins[key] then
		return
	end
	if skin.product then
		self:PromptProduct(player, skin.product)
	elseif economy:Spend(player, skin.coins) then
		self:GiveSkin(player, key)
	else
		Net.fire(player, "Toast", `You need {Format.num(skin.coins)} coins for {skin.name}.`, "bad")
	end
end

function ShopService:EquipSkin(player, key)
	local profile = data:Get(player)
	if not profile or type(key) ~= "string" or not profile.skins[key] or not Skins.byKey[key] then
		return
	end
	profile.skin = key
	dragons:RefreshSkin(player)
	self:PushSkins(player)
end

function ShopService:ProcessReceipt(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local profile = player and data:Get(player)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if table.find(profile.receipts, info.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local product = Shop.productById[info.ProductId]
	if not product then
		warn("[ShopService] unknown product " .. tostring(info.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local target = targets[player] and targets[player][product.key]
	local ok, granted = pcall(self.Grant, self, player, product.key, target)
	if not ok or not granted then
		warn("[ShopService] grant failed: " .. tostring(granted))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	table.insert(profile.receipts, info.PurchaseId)
	while #profile.receipts > MAX_RECEIPTS do
		table.remove(profile.receipts, 1)
	end
	data:Save(player)
	self.Purchased:Fire(player, product.name, info.CurrencySpent or product.price)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

return ShopService
