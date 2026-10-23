--[[
Developer-product receipts (§7). PurchaseService (M9) sets MarketplaceService.ProcessReceipt to call this.

  Receipts.process(receipt, handlers) -> Enum.ProductPurchaseDecision
      handlers[key](player, profile, receipt) grants the product; key comes from Config.Catalog.byProductId

The grant only counts once the profile, with the PurchaseId recorded, is saved: anything else rolls the profile
back and returns NotProcessedYet so Roblox asks again (also on the player's next join).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.Parent.Services.DataService)
local TableUtil = require(ReplicatedStorage.Shared.TableUtil)

local Receipts = {}

local processing = {} -- [PurchaseId] = true while a grant is being saved

function Receipts.process(receipt, handlers)
	local notYet = Enum.ProductPurchaseDecision.NotProcessedYet
	local granted = Enum.ProductPurchaseDecision.PurchaseGranted

	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local profile = player and DataService.get(player)
	if not profile then
		return notYet
	end
	if table.find(profile.receipts, receipt.PurchaseId) then
		return granted
	end
	if processing[receipt.PurchaseId] then
		return notYet
	end
	local entry = Config.Catalog.byProductId[receipt.ProductId]
	local key = entry and entry.key
	local handler = key and handlers[key]
	if not handler then
		warn(`[Receipts] no handler for product {receipt.ProductId} ({key})`)
		return notYet
	end

	processing[receipt.PurchaseId] = true
	local snap = TableUtil.deepCopy(profile)
	local ok, err = pcall(handler, player, profile, receipt)
	if not ok then
		warn(`[Receipts] {key} for {receipt.PlayerId} failed: {err}`)
		TableUtil.replaceContents(profile, snap)
		processing[receipt.PurchaseId] = nil
		return notYet
	end
	table.insert(profile.receipts, receipt.PurchaseId)
	while #profile.receipts > Config.Save.receiptsKeep do
		table.remove(profile.receipts, 1)
	end
	local saved = DataService.save(player, "receipt"):await()
	processing[receipt.PurchaseId] = nil
	if saved then
		return granted
	end
	TableUtil.replaceContents(profile, snap)
	return notYet
end

return Receipts
