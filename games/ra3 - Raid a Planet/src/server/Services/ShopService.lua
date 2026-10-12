-- Robux purchases: opens Roblox's purchase prompts, grants passes, handles developer product receipts exactly
-- once. Items whose ID is still 0 are granted for free in Studio so everything can be tested.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Net)
local Shop = require(ReplicatedStorage.Shared.Data.Shop)
local Signal = require(ReplicatedStorage.Shared.Signal)

local ShopService = {
	Name = "ShopService",
	Dependencies = { "PlayerDataService", "EconomyService", "ForgeService" },
	Purchased = Signal.new("ShopService.Purchased"), -- (player, name, robux)
}

local data, economy, forge
local pendingFinish = {} -- [player] = slot waiting for a Finish Now receipt

local function studioFree(player, item)
	if RunService:IsStudio() then
		Net.fire(player, "Toast", `Studio test: {item.name} given for free (set its ID in Shop.lua).`, "info")
		return true
	end
	return false
end

function ShopService:GrantProduct(player, item)
	if item.gems then
		economy:AddGems(player, item.gems, false)
		Net.fire(player, "Alert", `💎 +{item.gems} GEMS!`, Color3.fromRGB(120, 220, 255))
	elseif item.key == "LUCK" then
		local profile = data:Get(player)
		profile.luckUntil = math.max(profile.luckUntil or 0, os.time()) + 15 * 60
		Net.fire(player, "Alert", "🍀 LUCK ELIXIR: 15 minutes of better rolls!", Color3.fromRGB(120, 255, 140))
		forge:Push(player)
	elseif string.sub(item.key, 1, 7) == "FINISH_" then
		local slot = pendingFinish[player] or 1
		pendingFinish[player] = nil
		forge:CompleteSlot(player, slot)
	elseif item.key == "CALLOUT" then
		Net.fire(player, "Toast", "Your Raid Callout is ready for the next raid!", "good")
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
	forge = registry.ForgeService
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
	forge.FinishNowRequested:Connect(function(player, slot, price)
		pendingFinish[player] = slot
		self:PromptProduct(player, "FINISH_" .. price)
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

function ShopService:OnPlayerLeaving(player)
	pendingFinish[player] = nil
end

return ShopService
