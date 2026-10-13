-- Robux purchases: opens Roblox's purchase prompts, grants passes, handles developer product receipts exactly
-- once. Items whose ID is still 0 are granted for free in Studio so everything can be tested.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Shop = require(ReplicatedStorage.Shared.Data.Shop)
local Signal = require(ReplicatedStorage.Shared.Signal)

local ShopService = {
	Name = "ShopService",
	Dependencies = { "PlayerDataService", "EconomyService", "CombatService" },
	Purchased = Signal.new("ShopService.Purchased"), -- (player, name, robux)
	SeasonChanged = Signal.new("ShopService.SeasonChanged"), -- (player) bought the season pass
}

local data, economy, combat

local function studioFree(player, item)
	if RunService:IsStudio() then
		Net.fire(player, "Toast", `Studio test: {item.name} given for free (set its ID in Shop.lua).`, "info")
		return true
	end
	return false
end

function ShopService:GrantProduct(player, item)
	local profile = data:Get(player)
	if item.keys then
		economy:AddKeys(player, item.keys)
		Net.fire(
			player,
			"Alert",
			`🔑 +{item.keys} CRATE KEY{item.keys > 1 and "S" or ""}!`,
			Color3.fromRGB(255, 200, 40)
		)
	elseif item.key == "CALLOUT" then
		profile.callout = true
		Net.fire(
			player,
			"Toast",
			"Your Round Callout is ready: your name goes up in gold when the next round starts!",
			"good"
		)
	elseif item.key == "SEASON" then
		local n = Formulas.season(os.time())
		if profile.season.n ~= n then
			profile.season = { n = n, xp = 0, pass = false, claimed = {} }
		end
		profile.season.pass = true
		Net.fire(
			player,
			"Alert",
			"🏅 SEASON PASS! Claim your rewards at the Season counter.",
			Color3.fromRGB(255, 170, 40)
		)
		if self.SeasonChanged then
			self.SeasonChanged:Fire(player)
		end
	elseif item.key == "REVIVE" then
		if combat.isPopped(player) then
			combat:Respawn(player)
		end
	end
	Net.fire(player, "Sfx", "buy")
end

function ShopService:PromptPass(player, key)
	local item = Shop.byKey[key]
	if not item then
		return
	end
	if economy:HasPass(player, key) then
		Net.fire(player, "Toast", "You already own that!", "info")
		return
	end
	if item.id == 0 then
		if studioFree(player, item) then
			economy:GrantPass(player, key)
		end
		return
	end
	pcall(MarketplaceService.PromptGamePassPurchase, MarketplaceService, player, item.id)
end

function ShopService:PromptProduct(player, key)
	local item = Shop.byKey[key]
	if not item then
		return
	end
	if item.id == 0 then
		if studioFree(player, item) then
			self:GrantProduct(player, item)
		end
		return
	end
	pcall(MarketplaceService.PromptProductPurchase, MarketplaceService, player, item.id)
end

function ShopService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	combat = registry.CombatService
	Net.on("Purchase", function(player, kind, key)
		if type(key) ~= "string" then
			return
		end
		if kind == "pass" then
			self:PromptPass(player, key)
		elseif kind == "product" then
			self:PromptProduct(player, key)
		end
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, bought)
		local item = Shop.passById[passId]
		if bought and item then
			economy:GrantPass(player, item.key)
			Net.fire(player, "Alert", `✅ {item.name}!`, Color3.fromRGB(120, 255, 140))
			self.Purchased:Fire(player, item.name, item.price)
		end
	end)
	MarketplaceService.ProcessReceipt = function(receipt)
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		local profile = player and data:Get(player)
		if not profile then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if table.find(profile.receipts, receipt.PurchaseId) then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		local item = Shop.productById[receipt.ProductId]
		if not item then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		self:GrantProduct(player, item)
		table.insert(profile.receipts, receipt.PurchaseId)
		if #profile.receipts > 50 then
			table.remove(profile.receipts, 1)
		end
		data:Save(player)
		self.Purchased:Fire(player, item.name, item.price)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
end

return ShopService
