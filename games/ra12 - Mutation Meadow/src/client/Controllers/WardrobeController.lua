--[[
The Wardrobe: four slots (Theme, Trail, Tag, Can), each listing what you can wear there: owned, earned, the bundle's
items, VIP perks (VIP owners) and the subscriber can (subscribers). Equip / Unequip send Cosmetic:equip
{slot, key?}; the server checks again and draws it for everyone.

  WardrobeController.open() / close() / isOpen() / fill()
  WardrobeController.wearable() -> { [slot] = { keys } }
  WardrobeController.slotOf(key)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local ClientState = require(script.Parent.Parent.ClientState)
local UI = require(script.Parent.Parent.UI)

local WardrobeController = {}

WardrobeController.SLOTS = { { "theme", "Theme" }, { "trail", "Trail" }, { "tag", "Tag" }, { "can", "Can" } }

local NAMES = {
	trail_petals = "Petal Trail",
	tag_collector = "Collector",
	title_master = "Master Gardener",
	tag_weekly_top100 = "Top 100",
	tag_vip = "VIP Gardener",
	trail_vip_sparkle = "VIP Sparkle",
	can_brass = "Brass Can",
}

local PREFIX = { theme = "theme", trail = "trail", tag = "tag", title = "tag", can = "can" }

local modal

function WardrobeController.slotOf(key)
	local prefix = key:match("^(%a+)_")
	return prefix and PREFIX[prefix]
end

local function nameOf(key)
	local item = Config.Catalog.cosmetics[key]
	return item and item.name or NAMES[key] or key
end

function WardrobeController.wearable()
	local me = Players.LocalPlayer
	local keys = {}
	for key, on in ClientState.get("cosmetics", "owned") or {} do
		if on then
			keys[key] = true
		end
	end
	local grants = ClientState.get("meta", "bundleGrants")
	if grants and me:GetAttribute("Pass_starterBundle") then
		for _, key in grants do
			keys[key] = true
		end
	end
	if me:GetAttribute("Pass_vip") then
		for _, key in Config.Catalog.vipPerks do
			keys[key] = true
		end
	end
	if me:GetAttribute("Subscriber") then
		keys[Config.Catalog.subscriberPerk] = true
	end
	local out = { theme = {}, trail = {}, tag = {}, can = {} }
	for key in keys do
		local slot = WardrobeController.slotOf(key)
		if slot then
			table.insert(out[slot], key)
		end
	end
	for _, list in out do
		table.sort(list)
	end
	return out
end

function WardrobeController.fill()
	modal.clear()
	local equipped = ClientState.get("cosmetics", "equipped") or {}
	local wearable = WardrobeController.wearable()
	for i, s in WardrobeController.SLOTS do
		local slot = s[1]
		local row = UI.frame(modal.body, { Name = "Slot_" .. slot, LayoutOrder = i, Size = UDim2.new(1, 0, 0, 112) })
		UI.label(row, `{s[2]}: {if equipped[slot] then nameOf(equipped[slot]) else "none"}`, {
			Name = "Title",
			Position = UDim2.fromOffset(8, 4),
			Size = UDim2.new(1, -16, 0, 28),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local strip = Instance.new("ScrollingFrame")
		strip.Name = "Items"
		strip.BackgroundTransparency = 1
		strip.Position = UDim2.fromOffset(8, 36)
		strip.Size = UDim2.new(1, -16, 0, 70)
		strip.AutomaticCanvasSize = Enum.AutomaticSize.X
		strip.CanvasSize = UDim2.new()
		strip.Parent = row
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.Padding = UDim.new(0, 6)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = strip
		if #wearable[slot] == 0 then
			UI.label(strip, "Nothing yet", { Name = "Empty", Size = UDim2.fromOffset(200, 60) })
		end
		for j, key in wearable[slot] do
			local on = equipped[slot] == key
			UI.button(strip, (if on then "✓ " else "") .. nameOf(key), function()
				Net.request("Cosmetic", "equip", { slot = slot, key = if on then nil else key })
			end, {
				Name = "Item_" .. key,
				LayoutOrder = j,
				Size = UDim2.fromOffset(150, 60),
				BackgroundColor3 = if on then UI.COLORS.green else UI.COLORS.ink,
			})
		end
	end
end

function WardrobeController.open()
	WardrobeController.fill()
	modal.open()
end

function WardrobeController.close()
	modal.close()
end

function WardrobeController.isOpen()
	return modal.isOpen()
end

function WardrobeController:Start()
	modal = UI.modal("Wardrobe", "Wardrobe")
	modal.card.Size = UDim2.fromOffset(560, 580)
	ClientState.Changed:Connect(function(roots)
		if modal.isOpen() and (roots == nil or roots.cosmetics or roots.meta) then
			WardrobeController.fill()
		end
	end)
	Players.LocalPlayer.AttributeChanged:Connect(function()
		if modal.isOpen() then
			WardrobeController.fill()
		end
	end)
end

return WardrobeController
