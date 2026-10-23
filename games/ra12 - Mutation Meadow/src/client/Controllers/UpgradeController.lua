--[[
The Upgrades screen, from your plot's sign (the Expand prompt) or the HUD: the next plot level (cost, size,
unlocks), the next watering can, and sprinklers (buy, then Place mode).

  UpgradeController.open() / close() / isOpen()
]]
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local ClientState = require(script.Parent.Parent.ClientState)
local UI = require(script.Parent.Parent.UI)

local UpgradeController = {}

local controllers
local modal

local function buy(kind)
	Net.request("Upgrade", "buy", { kind = kind }):andThen(function(result)
		if not result.ok and controllers.HudController then
			controllers.HudController.toast(if result.code == "coins" then "Not enough coins" else "Can't buy that")
		end
		if modal.isOpen() then
			UpgradeController.fill()
		end
	end)
end

local function placedCount(profile, kind)
	local n = 0
	for _, k in profile.sprinklers.placed do
		if k == kind then
			n += 1
		end
	end
	return n
end

function UpgradeController.fill()
	modal.clear()
	local p = ClientState.profile
	if not p then
		UI.label(modal.body, "Loading…")
		return
	end
	local nextLevel = p.plotLevel + 1
	local cost = Config.Upgrades.plotCost[nextLevel]
	if cost then
		local size = Config.Upgrades.plotSize[nextLevel]
		local unlocks = {}
		for _, seed in Config.Restock.order do
			local gate = Config.Seeds[seed].gate
			if gate.plotLevel == nextLevel and not gate.eventOnly then
				table.insert(unlocks, Config.Seeds[seed].name)
			end
		end
		UI.label(modal.body, `Plot level {nextLevel}: {size[1]} x {size[2]}`, { Name = "PlotInfo" })
		if #unlocks > 0 then
			UI.label(
				modal.body,
				"Unlocks " .. table.concat(unlocks, ", "),
				{ Name = "Unlocks", Size = UDim2.new(1, 0, 0, 26) }
			)
		end
		UI.button(modal.body, "Expand: 🪙 " .. UI.money(cost), function()
			buy("plot")
		end, { Name = "BuyPlot", BackgroundColor3 = if p.coins >= cost then UI.COLORS.green else UI.COLORS.grey })
	else
		UI.label(modal.body, "Your meadow is full size!", { Name = "PlotInfo" })
	end
	local order = Config.Upgrades.canOrder
	local nextCan = order[(table.find(order, p.can) or #order) + 1]
	if nextCan then
		local c = Config.Upgrades.cans[nextCan].cost
		UI.button(modal.body, `{nextCan} can: 🪙 {UI.money(c)}`, function()
			buy("can")
		end, { Name = "BuyCan", BackgroundColor3 = if p.coins >= c then UI.COLORS.green else UI.COLORS.grey })
	end
	local cfg = Config.Upgrades.sprinklers
	for _, entry in { { "basic", "sprinklerBasic" }, { "advanced", "sprinklerAdvanced" } } do
		local kind, upgradeKind = entry[1], entry[2]
		local owned = p.sprinklers[kind]
		local free = owned - placedCount(p, kind)
		local row = Instance.new("Frame")
		row.Name = "Row_" .. kind
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, 52)
		row.Parent = modal.body
		UI.button(row, `{kind} {owned}/{cfg.maxEach}: 🪙 {UI.money(cfg[kind].cost)}`, function()
			buy(upgradeKind)
		end, {
			Name = "Buy",
			Size = UDim2.new(0.64, 0, 1, 0),
			BackgroundColor3 = if owned < cfg.maxEach and p.coins >= cfg[kind].cost
				then UI.COLORS.green
				else UI.COLORS.grey,
		})
		UI.button(row, `Place ({free})`, function()
			if free > 0 then
				controllers.TileController.startPlacing(kind)
				modal.close()
			end
		end, {
			Name = "Place",
			Position = UDim2.new(0.66, 0, 0, 0),
			Size = UDim2.new(0.34, 0, 1, 0),
			BackgroundColor3 = if free > 0 then UI.COLORS.gold else UI.COLORS.grey,
		})
	end
end

function UpgradeController.open()
	UpgradeController.fill()
	modal.open()
end

function UpgradeController.close()
	modal.close()
end

function UpgradeController.isOpen()
	return modal.isOpen()
end

local function ownPrompt(prompt, name)
	if prompt.Name ~= name then
		return false
	end
	local plot = prompt:FindFirstAncestorOfClass("Model")
	return plot ~= nil and plot:GetAttribute("OwnerId") == Players.LocalPlayer.UserId
end

function UpgradeController:Init(all)
	controllers = all
end

function UpgradeController:Start()
	modal = UI.modal("Upgrades", "Upgrades")
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if ownPrompt(prompt, "Expand") then
			UpgradeController.open()
		end
	end)
	ClientState.Changed:Connect(function()
		if modal.isOpen() then
			UpgradeController.fill()
		end
	end)
end

UpgradeController.ownPrompt = ownPrompt

return UpgradeController
