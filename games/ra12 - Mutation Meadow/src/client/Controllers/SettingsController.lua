--[[
Settings (from the HUD's Settings button): Patch alerts, music, sound effects, reduced effects (Settings:set), the
Auto-Harvest Gnome toggle for gnome owners (Settings:set gnomeOn), your garden name (Settings:gardenName; the
server filters it), the Odds and the Wardrobe. The HUD also gets a Gnome ON / OFF button while you own the gnome.

  SettingsController.open() / close() / isOpen() / fill()
  SettingsController.setGardenName(text)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local ClientState = require(script.Parent.Parent.ClientState)
local UI = require(script.Parent.Parent.UI)

local SettingsController = {}

local SETTINGS = {
	{ "patchAlerts", "Patch alerts" },
	{ "music", "Music" },
	{ "sfx", "Sound effects" },
	{ "reducedFx", "Reduced effects" },
}

local controllers
local modal, gnomeButton, nameBox

local function ownsGnome()
	return Players.LocalPlayer:GetAttribute("Pass_gnome") == true
end

local function toggleGnome()
	local p = ClientState.profile
	if p then
		Net.request("Settings", "set", { key = "gnomeOn", value = not p.gnomeOn })
	end
end

function SettingsController.setGardenName(text)
	if type(text) == "string" and text:match("%S") then
		Net.request("Settings", "gardenName", { name = text })
	end
end

function SettingsController.fill()
	modal.clear()
	local p = ClientState.profile
	if not p then
		return
	end
	for _, entry in SETTINGS do
		local key, label = entry[1], entry[2]
		local on = p.settings[key] == true
		UI.button(modal.body, `{label}: {if on then "ON" else "OFF"}`, function()
			Net.request("Settings", "set", { key = key, value = not on })
		end, { Name = "Set_" .. key, BackgroundColor3 = if on then UI.COLORS.green else UI.COLORS.grey })
	end
	if ownsGnome() then
		UI.button(modal.body, `Gnome: {if p.gnomeOn then "ON" else "OFF"}`, toggleGnome, {
			Name = "Set_gnomeOn",
			BackgroundColor3 = if p.gnomeOn then UI.COLORS.green else UI.COLORS.grey,
		})
	end
	local nameRow =
		UI.frame(modal.body, { Name = "GardenName", Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1 })
	nameBox = Instance.new("TextBox")
	nameBox.Name = "NameBox"
	nameBox.PlaceholderText = "Garden name"
	nameBox.Text = p.settings.gardenName or ""
	nameBox.ClearTextOnFocus = false
	nameBox.TextScaled = true
	nameBox.Size = UDim2.new(0.68, 0, 1, 0)
	nameBox.Parent = nameRow
	UI.button(nameRow, "Save", function()
		SettingsController.setGardenName(nameBox.Text)
	end, { Name = "SaveName", Position = UDim2.new(0.7, 0, 0, 0), Size = UDim2.new(0.3, 0, 1, 0) })
	UI.button(modal.body, "Wardrobe", function()
		controllers.WardrobeController.open()
	end, { Name = "Wardrobe", BackgroundColor3 = UI.COLORS.ink })
	UI.button(modal.body, "Odds", function()
		controllers.OddsController.open()
	end, { Name = "Odds", BackgroundColor3 = UI.COLORS.ink })
end

function SettingsController.open()
	SettingsController.fill()
	modal.open()
end

function SettingsController.close()
	modal.close()
end

function SettingsController.isOpen()
	return modal.isOpen()
end

local function refreshHud()
	local hud = controllers.HudController
	local bar = hud.gui and hud.gui:FindFirstChild("Bar")
	if not bar then
		return
	end
	if not gnomeButton then
		gnomeButton =
			UI.button(bar, "", toggleGnome, { Name = "Gnome", Size = UDim2.new(1, -16, 0, 40), LayoutOrder = 50 })
	end
	local p = ClientState.profile
	gnomeButton.Visible = ownsGnome()
	gnomeButton.Text = `🧙 Gnome: {if p and p.gnomeOn then "ON" else "OFF"}`
	gnomeButton.BackgroundColor3 = if p and p.gnomeOn then UI.COLORS.green else UI.COLORS.grey
end

function SettingsController:Init(all)
	controllers = all
end

function SettingsController:Start()
	modal = UI.modal("Settings", "Settings")
	modal.card.Size = UDim2.fromOffset(400, 600)
	ClientState.Changed:Connect(function()
		if modal.isOpen() then
			SettingsController.fill()
		end
		refreshHud()
	end)
	Players.LocalPlayer.AttributeChanged:Connect(function()
		refreshHud()
		if modal.isOpen() then
			SettingsController.fill()
		end
	end)
	refreshHud()
end

return SettingsController
