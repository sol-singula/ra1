--[[
The sell stand screen, from your stand's Sell prompt or the HUD: what's in the basket and what it's worth, Sell All,
the Auto-Sell toggle (plot level 2+), and the Items tab (kept crops arrive in M5).

  SellController.open() / close() / isOpen()
  SellController.value(profile)   the basket's coins
]]
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local ClientState = require(script.Parent.Parent.ClientState)
local UI = require(script.Parent.Parent.UI)

local SellController = {}

local controllers
local modal
local tab = "basket"

function SellController.value(profile)
	local mult = if profile.passes and profile.passes.doubleCash then Config.Catalog.passes.doubleCash.mult else 1
	local total = 0
	for seed, count in profile.basket do
		total += Config.Seeds[seed].sell * count * mult
	end
	return total
end

function SellController.fill()
	modal.clear()
	local p = ClientState.profile
	if not p then
		return
	end
	local tabs = Instance.new("Frame")
	tabs.Name = "Tabs"
	tabs.BackgroundTransparency = 1
	tabs.Size = UDim2.new(1, 0, 0, UI.MIN_TAP)
	tabs.Parent = modal.body
	UI.button(tabs, "Basket", function()
		tab = "basket"
		SellController.fill()
	end, {
		Name = "BasketTab",
		Size = UDim2.new(0.49, 0, 1, 0),
		BackgroundColor3 = if tab == "basket" then UI.COLORS.green else UI.COLORS.grey,
	})
	UI.button(tabs, "Items", function()
		tab = "items"
		SellController.fill()
	end, {
		Name = "ItemsTab",
		Position = UDim2.new(0.51, 0, 0, 0),
		Size = UDim2.new(0.49, 0, 1, 0),
		BackgroundColor3 = if tab == "items" then UI.COLORS.green else UI.COLORS.grey,
	})
	if tab == "items" then
		UI.label(modal.body, "Kept crops show here soon!", { Name = "ItemsSoon" })
		return
	end
	local n = 0
	for _, seed in Config.Restock.order do
		local count = p.basket[seed]
		if count and count > 0 then
			n += count
			UI.label(
				modal.body,
				`{Config.Seeds[seed].name} x{count}`,
				{ Name = "Line_" .. seed, Size = UDim2.new(1, 0, 0, 26) }
			)
		end
	end
	if n == 0 then
		UI.label(modal.body, "Your basket is empty", { Name = "Empty" })
	end
	UI.sellButton(modal.body, "Sell All: 🪙 " .. UI.money(SellController.value(p)), function()
		Net.request("Basket", "sellAll", {}):andThen(function(result)
			if not result.ok and controllers.HudController then
				controllers.HudController.toast(
					if result.code == "too_far" then "Walk to your sell stand" else "Nothing to sell"
				)
			end
		end)
	end, { Name = "SellAll" })
	if p.plotLevel >= Config.Inventory.autoSellPlotLevel then
		UI.button(modal.body, if p.autoSell then "Auto-Sell: ON" else "Auto-Sell: OFF", function()
			Net.request("Basket", "setAutoSell", { on = not p.autoSell })
		end, { Name = "AutoSell", BackgroundColor3 = if p.autoSell then UI.COLORS.green else UI.COLORS.grey })
	end
end

function SellController.open()
	SellController.fill()
	modal.open()
end

function SellController.close()
	modal.close()
end

function SellController.isOpen()
	return modal.isOpen()
end

function SellController:Init(all)
	controllers = all
end

function SellController:Start()
	modal = UI.modal("SellStand", "Sell Stand")
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if controllers.UpgradeController.ownPrompt(prompt, "Sell") then
			SellController.open()
		end
	end)
	ClientState.Changed:Connect(function()
		if modal.isOpen() then
			SellController.fill()
		end
	end)
end

return SellController
