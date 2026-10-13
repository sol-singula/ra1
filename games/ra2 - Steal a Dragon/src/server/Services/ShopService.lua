-- Robux purchases: opens Roblox's purchase prompts, grants game passes, and handles developer product
-- receipts exactly once (receipt ids are remembered in the profile and saved right away).
-- Products and passes whose ID is still 0 are granted for free in Studio so everything can be tested.
local CollectionService = game:GetService("CollectionService")
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
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

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
	Prompted = Signal.new("ShopService.Prompted"), -- (player, kind "pass"|"product", key) a purchase prompt opened
	CardShown = Signal.new("ShopService.CardShown"), -- (player, key, why) an offer card popped up
}

local data, economy, dragons, baseService, road, reward, tools
local targets = {} -- [player] = { [productKey] = target } remembered between prompt and receipt
local offeredAt = {} -- [player] = { [key] = os.clock() } when a world offer was last shown
local starterShown = {} -- [player] = true once the Starter Pack card showed this session
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
		self:Offer(player, "product", "GROW", uid)
	end)
	road.BuyNowRequested:Connect(function(player, roadId)
		local err = road:CanTake(player, road:Entry(roadId))
		if err then
			Net.fire(player, "Toast", err, "bad")
			return
		end
		if not self:Offer(player, "product", "BUYNOW", roadId) and not self:OffersAllowed(player) then
			Net.fire(player, "Toast", "Buy dragons with coins for now! 🪙", "info")
		end
	end)
	reward.HatchNowRequested:Connect(function(player)
		self:Offer(player, "product", "HATCH")
	end)
	tools.PotionsRequested:Connect(function(player)
		self:Offer(player, "product", "POTIONS")
	end)
	-- the moments a player wants something: right after being robbed, and an Epic+ road dragon they can't afford
	dragons.Placed:Connect(function(thief, _, kind, from)
		if kind == "stolen" and from and from ~= thief and from.Parent then
			self:OfferLockAfterRobbed(from)
		end
	end)
	road.CantAfford:Connect(function(player, roadId)
		self:OfferBuyNow(player, roadId)
	end)
	-- the plates in each base: Auto Collect (next to the coin pad) and 30-Minute Lock (next to the lock pad).
	-- Stepping on one never opens a purchase (players walk over them collecting coins): you hold its button,
	-- and the buttons only show for the owner once their tutorial is done.
	baseService.PlateStepped:Connect(function(player, plate)
		if plate == "auto" and economy:HasPass(player, "AUTO") then
			Net.fire(player, "Toast", "Auto Collect is ON: coins come right to you! 🧲", "good")
		end
	end)
	for _, world in WorldBuilder.layout.bases do
		for _, spec in
			{
				{ world.autoPlate, "Prompt_auto", "Get Auto Collect", "pass", "AUTO" },
				{ world.lockPlate, "Prompt_lock30", "Lock 30 min", "product", "LOCK30" },
			}
		do
			if spec[1] then
				local p = Instance.new("ProximityPrompt")
				p.Name = spec[2]
				p.ActionText = spec[3]
				p.ObjectText = "Robux"
				p.HoldDuration = 0.5
				p.MaxActivationDistance = 7
				p.RequiresLineOfSight = false
				p.Enabled = false
				p.Parent = spec[1]
				p.Triggered:Connect(function(player)
					local base = baseService:Get(player)
					if not base or base.world ~= world then
						Net.fire(player, "Toast", "That's not your base!", "info")
					elseif spec[4] == "pass" then
						if economy:HasPass(player, spec[5]) then
							Net.fire(player, "Toast", "Auto Collect is ON: coins come right to you! 🧲", "good")
						else
							self:PromptPass(player, spec[5])
						end
					else
						self:PromptProduct(player, spec[5])
					end
				end)
			end
		end
	end
	if registry.TutorialService and registry.TutorialService.Finished then
		registry.TutorialService.Finished:Connect(function(player)
			self:RefreshPlates(player)
		end)
	end
	-- LEVEL ALL podiums: hold to spend coins on level-ups across all your nests (coins only, never Robux)
	for _, world in WorldBuilder.layout.bases do
		local p = Instance.new("ProximityPrompt")
		p.Name = "Prompt_levelall"
		p.ActionText = "Level up all (coins)"
		p.ObjectText = "LEVEL ALL"
		p.HoldDuration = 0.5
		p.MaxActivationDistance = 9
		p.RequiresLineOfSight = false
		-- only the owner sees it (PromptController), so it never hides a thief's Steal prompt on the same key
		p:SetAttribute("Kind", "levelall")
		p:SetAttribute("OwnerUserId", 0)
		p.Parent = world.levelPlate
		CollectionService:AddTag(p, "DragonPrompt")
		p.Triggered:Connect(function(player)
			if baseService:Get(player) and baseService:Get(player).world == world then
				self:LevelAllWithCoins(player)
			else
				Net.fire(player, "Toast", "That's not your base!", "info")
			end
		end)
	end
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

local function levelPrompt(player)
	local base = baseService:Get(player)
	return base and base.world.levelPlate and base.world.levelPlate:FindFirstChild("Prompt_levelall")
end

-- The plate buttons in a player's base show once their tutorial is done.
function ShopService:RefreshPlates(player)
	local base = baseService:Get(player)
	local profile = data:Get(player)
	if not base then
		return
	end
	for _, plate in { base.world.autoPlate, base.world.lockPlate } do
		for _, p in plate and plate:GetChildren() or {} do
			if p:IsA("ProximityPrompt") then
				p.Enabled = profile ~= nil and profile.tutorialDone == true
			end
		end
	end
end

-- May the world show this player Robux offers right now? Not during the tutorial or a new player's first minutes.
function ShopService:OffersAllowed(player)
	local profile = data:Get(player)
	if not profile or not profile.tutorialDone then
		return false
	end
	if profile._isNew and os.time() - (profile._joinedAt or 0) < Constants.OFFER_NEW_PLAYER_SECONDS then
		return false
	end
	return true
end

-- A Robux offer from the world (not the Shop): only when allowed, and the same one at most once a minute.
-- Returns true if the purchase prompt opened.
function ShopService:Offer(player, kind, key, target)
	if not self:OffersAllowed(player) then
		return false
	end
	local mine = offeredAt[player] or {}
	offeredAt[player] = mine
	if mine[key] and os.clock() - mine[key] < Constants.OFFER_COOLDOWN then
		return false
	end
	mine[key] = os.clock()
	if kind == "pass" then
		self:PromptPass(player, key)
	else
		self:PromptProduct(player, key, target)
	end
	return true
end

-- An offer card (a small panel with Buy and No thanks) instead of opening Roblox's prompt straight away. Same
-- rules as Offer; cooldown defaults to OFFER_COOLDOWN. Returns true if the card was shown.
function ShopService:OfferCard(player, key, why, card, cooldown)
	local product = Shop.productByKey[key]
	if not product or not self:OffersAllowed(player) then
		return false
	end
	local mine = offeredAt[player] or {}
	offeredAt[player] = mine
	if mine[key] and os.clock() - mine[key] < (cooldown or Constants.OFFER_COOLDOWN) then
		return false
	end
	mine[key] = os.clock()
	Net.fire(player, "Offer", {
		key = key,
		title = card.title,
		text = card.text,
		icon = card.icon or product.icon,
		price = product.price,
		target = card.target,
	})
	self.CardShown:Fire(player, key, why)
	return true
end

-- "Someone stole your dragon! Lock your base for 30 minutes?" (not while a lock is already running)
function ShopService:OfferLockAfterRobbed(player)
	local base = baseService:Get(player)
	if not base or baseService:IsLocked(base) then
		return false
	end
	return self:OfferCard(player, "LOCK30", "robbed", {
		title = "😱 YOU GOT ROBBED!",
		text = "Lock your base for 30 minutes. No one can steal from you!",
		icon = "🔒",
	}, Constants.OFFER_ROBBED_COOLDOWN)
end

-- Tried to buy an Epic (or better) road dragon without enough coins: offer to take it now.
function ShopService:OfferBuyNow(player, roadId)
	local entry = road:Entry(roadId)
	local d = entry and Dragons.byId[entry.id]
	if not d or Dragons.RarityRank[d.rarity] < Dragons.RarityRank.Epic or road:CanTake(player, entry) then
		return false
	end
	return self:OfferCard(player, "BUYNOW", "cant_afford", {
		title = `{d.rarity == "Epic" and "💜" or "⭐"} {string.upper(d.rarity)} DRAGON!`,
		text = `Not enough coins for {d.name}? Take it right now!`,
		icon = "⚡",
		target = roadId,
	})
end

-- The Starter Pack card: once a session, after STARTER_AFTER_SECONDS of play, until it is bought.
function ShopService:OfferStarter(player)
	local profile = data:Get(player)
	if not profile or profile.starterBought or starterShown[player] then
		return false
	end
	if
		self:OfferCard(player, "STARTER", "starter", {
			title = "🎒 STARTER PACK",
			text = "1 Epic dragon + 5 speed potions + a bag of coins. One time only!",
		})
	then
		starterShown[player] = true
		return true
	end
	return false
end

-- (tests) forget when offers were last shown
function ShopService:ResetOffers(player)
	offeredAt[player] = nil
	starterShown[player] = nil
end

function ShopService:OnPlayerReady(player)
	local p = levelPrompt(player)
	if p then
		p:SetAttribute("OwnerUserId", player.UserId)
	end
	self:RefreshPlates(player)
	task.delay(Constants.STARTER_AFTER_SECONDS, function()
		-- busy (carrying, a panel open on their side)? try again a little later, a few times
		for _ = 1, 5 do
			if player.Parent == nil or self:OfferStarter(player) or starterShown[player] then
				return
			end
			task.wait(60)
		end
	end)
end

function ShopService:OnPlayerLeaving(player)
	targets[player] = nil
	offeredAt[player] = nil
	starterShown[player] = nil
	local base = baseService:Get(player)
	for _, plate in base and { base.world.autoPlate, base.world.lockPlate } or {} do
		for _, p in plate and plate:GetChildren() or {} do
			if p:IsA("ProximityPrompt") then
				p.Enabled = false
			end
		end
	end
	local p = levelPrompt(player)
	if p then
		p:SetAttribute("OwnerUserId", 0)
	end
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
	self.Prompted:Fire(player, "pass", key)
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
	self.Prompted:Fire(player, "product", key)
	MarketplaceService:PromptProductPurchase(player, product.id)
end

function ShopService:LevelAllWithCoins(player)
	local bought, spent = dragons:LevelAll(player)
	if bought > 0 then
		Net.fire(player, "Toast", `⬆️ {bought} level-ups for {Format.num(spent)} coins!`, "good")
		Net.fire(player, "Sfx", "levelup")
	elseif dragons:CanLevelAny(player) then
		Net.fire(player, "Toast", "Not enough coins for a level-up yet. Collect your coins!", "info")
	else
		Net.fire(player, "Toast", "Put dragons in your nests first!", "info")
	end
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
	elseif key == "LOCK30" then
		baseService:Lock(player, Constants.LOCK_BOOST_SECONDS)
	elseif key == "STARTER" then
		local epics = Dragons.byRarity.Epic
		local id = epics[math.random(1, #epics)].id
		dragons:Grant(player, id)
		tools:AddPotions(player, 5)
		economy:Add(player, math.max(Constants.STARTER_COINS_MIN, math.floor(income * Constants.STARTER_COINS_SECONDS)))
		profile.starterBought = true
		Net.fire(player, "Alert", `Starter Pack: {Dragons.byId[id].name}! 🎒`, Color3.fromRGB(255, 205, 50))
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
