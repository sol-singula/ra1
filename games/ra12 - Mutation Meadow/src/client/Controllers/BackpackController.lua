--[[
The Backpack: your kept crops in a grid (icon in its mutation's frame, seed, mutation, value, finder, date), filters
(All, Wet, Golden, Wet + Golden), slots used, and per item Display, Gift (M9) and Sell (with a confirm). Also the
Backpack-full prompt when a mutated harvest has no room: Sell now or Leave on plot.

  BackpackController.open() / close() / isOpen() / setFilter(key)
  BackpackController.confirmSell(guid) / fullPrompt(plot, tileId)
  BackpackController.SELL_TEXT        the confirm copy (string.format with the item name and the coins)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MutationMath = require(ReplicatedStorage.Shared.MutationMath)
local Net = require(ReplicatedStorage.Shared.Net)
local ClientState = require(script.Parent.Parent.ClientState)
local UI = require(script.Parent.Parent.UI)
local Visuals = require(ReplicatedStorage.Shared.Visuals)

local BackpackController = {}

BackpackController.SELL_TEXT = "Sell %s for %s coins? This can't be undone."

local controllers
local modal, confirm, full
local filter = "all"
local names = {}

local FILTERS = { { "all", "All" }, { "wet", "Wet" }, { "golden", "Golden" }, { "wetgolden", "Wet + Golden" } }

local function finder(userId)
	if userId == Players.LocalPlayer.UserId then
		return "you"
	end
	if names[userId] == nil then
		local ok, name = pcall(function()
			return Players:GetNameFromUserIdAsync(userId)
		end)
		names[userId] = if ok then name else "a farmer"
	end
	return names[userId]
end

local function price(profile, item)
	local mult = if profile.passes and profile.passes.doubleCash then Config.Catalog.passes.doubleCash.mult else 1
	return MutationMath.value(item.seed, item.muts) * mult
end

local function itemName(item)
	return MutationMath.label(item.muts) .. " " .. Config.Seeds[item.seed].name
end

local function sorted(profile)
	local list = {}
	for guid, item in profile.items do
		local key = MutationMath.key(item.muts)
		if filter == "all" or key == filter then
			table.insert(list, { guid = guid, item = item })
		end
	end
	table.sort(list, function(a, b)
		local va, vb = price(profile, a.item), price(profile, b.item)
		if va ~= vb then
			return va > vb
		end
		return a.guid < b.guid
	end)
	return list
end

local function card(parent, profile, guid, item)
	local key = MutationMath.key(item.muts)
	local c = UI.frame(parent, { Name = "Item_" .. guid })
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Visuals.MUT[key] or UI.COLORS.grey
	stroke.Parent = c
	local icon = UI.frame(c, {
		Name = "Icon",
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(48, 48),
		BackgroundColor3 = Visuals.SEED[item.seed] or Visuals.LEAF,
	})
	icon:SetAttribute("Mut", key)
	UI.label(c, itemName(item), { Name = "Name", Position = UDim2.fromOffset(62, 6), Size = UDim2.new(1, -68, 0, 24) })
	UI.label(
		c,
		"🪙 " .. UI.money(price(profile, item)),
		{ Name = "Value", Position = UDim2.fromOffset(62, 30), Size = UDim2.new(1, -68, 0, 20) }
	)
	UI.label(c, `Found by {finder(item.foundBy)} · {os.date("%b %d", item.foundAt)}`, {
		Name = "Finder",
		Position = UDim2.fromOffset(8, 60),
		Size = UDim2.new(1, -16, 0, 18),
	})
	local row = Instance.new("Frame")
	row.Name = "Actions"
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(8, 82)
	row.Size = UDim2.new(1, -16, 0, 40)
	row.Parent = c
	local w = UDim2.new(0.32, 0, 1, 0)
	if item.locked then
		UI.label(row, "On display", { Name = "OnDisplay", Size = UDim2.new(1, 0, 1, 0) })
		return c
	end
	UI.button(row, "Display", function()
		controllers.PedestalController.displayItem(guid)
	end, { Name = "Display", Size = w })
	UI.button(row, "Gift", function() end, {
		Name = "Gift",
		Position = UDim2.new(0.34, 0, 0, 0),
		Size = w,
		BackgroundColor3 = UI.COLORS.grey,
		Active = false,
		AutoButtonColor = false,
	})
	UI.button(row, "Sell", function()
		BackpackController.confirmSell(guid)
	end, { Name = "Sell", Position = UDim2.new(0.68, 0, 0, 0), Size = w, BackgroundColor3 = UI.COLORS.gold })
	return c
end

function BackpackController.fill()
	modal.clear()
	local p = ClientState.profile
	if not p then
		return
	end
	local count = 0
	for _ in p.items do
		count += 1
	end
	local list = Config.Inventory.backpackByPlotLevel
	UI.label(
		modal.body,
		`Slots {count}/{list[p.plotLevel] or list[#list]}`,
		{ Name = "Slots", Size = UDim2.new(1, 0, 0, 26) }
	)
	local filters = Instance.new("Frame")
	filters.Name = "Filters"
	filters.BackgroundTransparency = 1
	filters.Size = UDim2.new(1, 0, 0, 40)
	filters.Parent = modal.body
	for i, f in FILTERS do
		UI.button(filters, f[2], function()
			BackpackController.setFilter(f[1])
		end, {
			Name = "Filter_" .. f[1],
			Position = UDim2.new((i - 1) * 0.25, 2, 0, 0),
			Size = UDim2.new(0.25, -4, 1, 0),
			BackgroundColor3 = if filter == f[1] then UI.COLORS.green else UI.COLORS.grey,
		})
	end
	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.new(1, 0, 1, -80)
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.ScrollBarThickness = 6
	grid.Parent = modal.body
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(200, 130)
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	local shown = sorted(p)
	for i, entry in shown do
		card(grid, p, entry.guid, entry.item).LayoutOrder = i
	end
	if #shown == 0 then
		UI.label(grid, "No kept crops yet. Harvest a Wet or Golden one!", { Name = "Empty" })
	end
end

function BackpackController.setFilter(key)
	filter = key
	BackpackController.fill()
end

function BackpackController.confirmSell(guid)
	local p = ClientState.profile
	local item = p and p.items[guid]
	if not item then
		return
	end
	confirm.clear()
	UI.label(confirm.body, string.format(BackpackController.SELL_TEXT, itemName(item), UI.money(price(p, item))), {
		Name = "Text",
		Size = UDim2.new(1, 0, 0, 90),
		TextWrapped = true,
	})
	UI.button(confirm.body, "Confirm", function()
		Net.request("Inventory", "sellItem", { id = guid })
		confirm.close()
	end, { Name = "Confirm", BackgroundColor3 = UI.COLORS.red })
	UI.button(confirm.body, "Cancel", confirm.close, { Name = "Cancel", BackgroundColor3 = UI.COLORS.grey })
	confirm.open()
end

function BackpackController.fullPrompt(plot, id)
	local tile = plot.Tiles:FindFirstChild(id) or plot.ExtraRow:FindFirstChild(id)
	local p = ClientState.profile
	if not tile or not p then
		return
	end
	local muts = {}
	local key = tile:GetAttribute("Muts")
	if key == "wet" or key == "wetgolden" then
		muts.wet = true
	end
	if key == "golden" or key == "wetgolden" then
		muts.golden = true
	end
	local coins = price(p, { seed = tile:GetAttribute("Seed"), muts = muts })
	full.clear()
	UI.label(full.body, "Your Backpack is full!", { Name = "Text" })
	UI.button(full.body, "Sell now (🪙 " .. UI.money(coins) .. ")", function()
		Net.request("Plot", "harvest", { tile = id, onFull = "sell" })
		full.close()
	end, { Name = "SellNow", BackgroundColor3 = UI.COLORS.gold })
	UI.button(full.body, "Leave on plot", function()
		Net.request("Plot", "harvest", { tile = id, onFull = "leave" })
		full.close()
	end, { Name = "Leave", BackgroundColor3 = UI.COLORS.grey })
	full.open()
end

function BackpackController.open()
	BackpackController.fill()
	modal.open()
end

function BackpackController.close()
	modal.close()
end

function BackpackController.isOpen()
	return modal.isOpen()
end

function BackpackController:Init(all)
	controllers = all
end

function BackpackController:Start()
	modal = UI.modal("Backpack", "Backpack")
	modal.card.Size = UDim2.fromOffset(460, 600)
	confirm = UI.modal("SellConfirm", "Sell item")
	confirm.card.Size = UDim2.fromOffset(400, 300)
	full = UI.modal("BackpackFull", "Backpack full")
	full.card.Size = UDim2.fromOffset(400, 280)
	ClientState.Changed:Connect(function(roots)
		if modal.isOpen() and (roots == nil or roots.items or roots.plotLevel) then
			BackpackController.fill()
		end
	end)
end

return BackpackController
