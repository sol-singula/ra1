--[[
Pedestals: the picker (slots, which item each shows, Remove, or pick an item for a free slot) from tapping one of your
pedestals, and the world look of every plot's pedestals: the item on top with its mutation sparkles and a floating
label (crop, mutation, finder).

  PedestalController.open(slot?) / close() / isOpen()
  PedestalController.displayItem(guid)   puts an item on the first free unlocked pedestal (or opens the picker)
  PedestalController.unlocked()          how many of your pedestals are unlocked
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local MutationMath = require(ReplicatedStorage.Shared.MutationMath)
local Net = require(ReplicatedStorage.Shared.Net)
local ClientState = require(script.Parent.Parent.ClientState)
local UI = require(script.Parent.Parent.UI)
local Visuals = require(ReplicatedStorage.Shared.Visuals)

local PedestalController = {}

local controllers
local modal
local chosen -- the slot picking an item
local shown = {} -- [pedestal part] = { model, key }
local connected = {}

local DRAW_EVERY = 0.5

local function ownPlot()
	return controllers.TileController.ownPlot()
end

function PedestalController.unlocked()
	local plot = ownPlot()
	local n = 0
	if plot then
		for i = 1, Config.Inventory.pedestalMax do
			local p = plot.Pedestals:FindFirstChild("P" .. i)
			if p and p:GetAttribute("Unlocked") then
				n += 1
			end
		end
	end
	return n
end

local function itemName(item)
	return MutationMath.label(item.muts) .. " " .. Config.Seeds[item.seed].name
end

function PedestalController.fill()
	modal.clear()
	local profile = ClientState.profile
	if not profile then
		return
	end
	local unlocked = PedestalController.unlocked()
	if chosen then
		UI.label(modal.body, `Choose an item for pedestal {chosen}`, { Name = "Choose" })
		local any = false
		for guid, item in profile.items do
			if not item.locked then
				any = true
				UI.button(modal.body, itemName(item), function()
					Net.request("Inventory", "display", { id = guid, pedestal = chosen })
					chosen = nil
					modal.close()
				end, { Name = "Pick_" .. guid })
			end
		end
		if not any then
			UI.label(modal.body, "No free items. Keep a mutated crop!", { Name = "NoItems" })
		end
		UI.button(modal.body, "Back", function()
			chosen = nil
			PedestalController.fill()
		end, { Name = "Back", BackgroundColor3 = UI.COLORS.grey })
		return
	end
	for i = 1, Config.Inventory.pedestalMax do
		local guid = profile.pedestals[tostring(i)]
		local item = guid and profile.items[guid]
		local row = Instance.new("Frame")
		row.Name = "Slot" .. i
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, 46)
		row.Parent = modal.body
		local text = if i > unlocked then "Locked" elseif item then itemName(item) else "Empty"
		UI.label(
			row,
			`P{i}: {text}`,
			{ Name = "Label", Size = UDim2.new(0.62, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left }
		)
		if i <= unlocked then
			if item then
				UI.button(row, "Remove", function()
					Net.request("Inventory", "undisplay", { pedestal = i })
				end, {
					Name = "Remove",
					Position = UDim2.new(0.64, 0, 0, 0),
					Size = UDim2.new(0.36, 0, 1, 0),
					BackgroundColor3 = UI.COLORS.red,
				})
			else
				UI.button(row, "Choose", function()
					chosen = i
					PedestalController.fill()
				end, { Name = "Choose", Position = UDim2.new(0.64, 0, 0, 0), Size = UDim2.new(0.36, 0, 1, 0) })
			end
		end
	end
end

function PedestalController.open(slot)
	chosen = slot
	PedestalController.fill()
	modal.open()
end

function PedestalController.close()
	chosen = nil
	modal.close()
end

function PedestalController.isOpen()
	return modal.isOpen()
end

function PedestalController.displayItem(guid)
	local profile = ClientState.profile
	if not profile then
		return
	end
	for i = 1, PedestalController.unlocked() do
		if not profile.pedestals[tostring(i)] then
			Net.request("Inventory", "display", { id = guid, pedestal = i })
			return i
		end
	end
	PedestalController.open()
	return nil
end

local function drawPedestal(part)
	local seed = part:GetAttribute("ItemSeed")
	local key = part:GetAttribute("ItemMuts")
	local entry = shown[part]
	if not seed then
		if entry then
			entry.model:Destroy()
			shown[part] = nil
		end
		return
	end
	if entry and entry.key == seed .. (key or "") then
		return
	end
	if entry then
		entry.model:Destroy()
	end
	local model = Instance.new("Part")
	model.Name = "ShownItem"
	model.Anchored = true
	model.CanCollide = false
	model.Size = Vector3.new(1.6, 1.6, 1.6)
	model.Position = part.Position + Vector3.new(0, part.Size.Y / 2 + 1.2, 0)
	model.Color = Visuals.SEED[seed] or Visuals.LEAF
	model.Material = Enum.Material.Neon
	Visuals.mutationFx(model, key)
	local board = Instance.new("BillboardGui")
	board.Name = "Label"
	board.Size = UDim2.fromOffset(180, 50)
	board.StudsOffset = Vector3.new(0, 2, 0)
	board.AlwaysOnTop = true
	board.MaxDistance = 60
	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.TextScaled = true
	text.Font = Enum.Font.GothamBold
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.4
	text.Text = part:GetAttribute("ItemLabel") or ""
	text.Parent = board
	board.Parent = model
	model.Parent = workspace:FindFirstChild("ClientCrops") or workspace
	shown[part] = { model = model, key = seed .. (key or "") }
end

local function draw()
	local street = workspace:FindFirstChild("Street")
	if not street then
		return
	end
	for _, plot in street.Plots:GetChildren() do
		for _, part in plot.Pedestals:GetChildren() do
			drawPedestal(part)
			local click = part:FindFirstChild("Click")
			if click and not connected[click] then
				connected[click] = true
				click.MouseClick:Connect(function()
					if plot:GetAttribute("OwnerId") == Players.LocalPlayer.UserId then
						local slot = tonumber(part.Name:match("^P(%d+)$"))
						local profile = ClientState.profile
						local free = profile
							and not profile.pedestals[tostring(slot)]
							and slot <= PedestalController.unlocked()
						PedestalController.open(if free then slot else nil)
					end
				end)
			end
		end
	end
end

function PedestalController:Init(all)
	controllers = all
end

function PedestalController:Start()
	modal = UI.modal("Pedestals", "Pedestals")
	ClientState.Changed:Connect(function()
		if modal.isOpen() then
			PedestalController.fill()
		end
	end)
	draw()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= DRAW_EVERY then
			acc = 0
			draw()
		end
	end)
end

PedestalController.draw = draw

return PedestalController
