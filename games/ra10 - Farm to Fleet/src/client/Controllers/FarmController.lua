--[[
Farming with one thumb (master plan §3, phone first). A big round button at the bottom right says what it will do
for the soil you're standing by (Net "Farm" "act"; the server does all of it that's in reach): HARVEST when
something there is ripe, PLANT when there's empty soil, WATER (once you have the well) when something's growing
dry. It hides when there's nothing to do. Over it, the crop picker: one chip per crop you've unlocked (Net "Farm"
"crop"). On a PC, E (or a click away from the buttons) does the same as the button.

  FarmController.action()   -> "harvest" | "plant" | "water" | nil, what the button shows now
  FarmController.press()    what the button does
  FarmController.refs
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Crops = require(ReplicatedStorage.Shared.Data.Crops)
local Net = require(ReplicatedStorage.Shared.Net)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local FarmController = { Name = "FarmController", Order = 20, REACH = 11 }

local C = Theme.Color
local player = Players.LocalPlayer
local refs = {}
FarmController.refs = refs

local LOOK = {
	harvest = { "HARVEST", Color3.fromRGB(240, 70, 70) },
	plant = { "PLANT", Color3.fromRGB(70, 190, 90) },
	water = { "WATER", Color3.fromRGB(60, 150, 235) },
}

local function root()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

-- My plot's soil tiles in the world: n -> Part
local function tiles()
	local plot = Store.get("plot")
	local folder = workspace:FindFirstChild("Farms")
	local mine = plot and plot.index and folder and folder:FindFirstChild("Plot" .. plot.index)
	local out = {}
	if mine and mine:FindFirstChild("Items") then
		for _, d in mine.Items:GetChildren() do
			if d.Name == "Soil" and d:GetAttribute("Tile") then
				out[d:GetAttribute("Tile")] = d
			end
		end
	end
	return out
end

function FarmController.action()
	local f = Store.get("farm")
	local r = root()
	if not f or not r then
		return nil
	end
	local now = workspace:GetServerTimeNow()
	local ripe, empty, dry = false, false, false
	for n, tile in tiles() do
		local d = tile.Position - r.Position
		if Vector3.new(d.X, 0, d.Z).Magnitude <= FarmController.REACH then
			local t = f.tiles and f.tiles[n]
			if not t then
				empty = true
			elseif now - t.at >= t.need then
				ripe = true
			elseif f.well and not t.watered then
				dry = true
			end
		end
	end
	if ripe then
		return "harvest"
	elseif empty then
		return "plant"
	elseif dry then
		return "water"
	end
	return nil
end

function FarmController.press()
	local a = FarmController.action()
	if a then
		Net.send("Farm", "act")
	end
	return a
end

local function paintPicker()
	local f = Store.get("farm")
	local list = f and f.crops or { "strawberry" }
	for _, chip in refs.picker:GetChildren() do
		if chip:IsA("GuiButton") then
			chip:Destroy()
		end
	end
	refs.chips = {}
	if #list < 2 then
		refs.picker.Visible = false
		return
	end
	refs.picker.Visible = true
	for i, key in list do
		local c = Crops[key]
		local chip = Theme.button({
			Name = "Chip_" .. key,
			Text = c.name,
			Position = UDim2.fromOffset(0, (i - 1) * 40),
			Size = UDim2.fromOffset(130, 34),
			BackgroundColor3 = f.crop == key and c.color or C.white,
			dark = f.crop ~= key,
			Parent = refs.picker,
		})
		chip.Modal = true
		chip.Activated:Connect(function()
			Net.send("Farm", "crop", key)
		end)
		refs.chips[key] = chip
	end
	refs.picker.Size = UDim2.fromOffset(130, #list * 40)
end

function FarmController:init()
	local gui = Theme.screen("Farm", 6, player:WaitForChild("PlayerGui"))
	refs.gui = gui
	local b = Theme.button({
		Name = "Act",
		Text = "PLANT",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -28, 1, -140),
		Size = UDim2.fromOffset(150, 150),
		BackgroundColor3 = LOOK.plant[2],
		round = true,
		Visible = false,
		Parent = gui,
	})
	b.Modal = true
	b.Activated:Connect(function()
		FarmController.press()
	end)
	refs.act = b
	refs.picker = Theme.new("Frame", {
		Name = "Picker",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -28, 1, -302),
		Size = UDim2.fromOffset(130, 40),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	paintPicker()
	Store.Changed:Connect(function(partial)
		if partial.farm then
			paintPicker()
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.E or input.UserInputType == Enum.UserInputType.MouseButton1 then
			FarmController.press()
		end
	end)
	local shown
	RunService.Heartbeat:Connect(function()
		local a = FarmController.action()
		if a ~= shown then
			shown = a
			b.Visible = a ~= nil
			if a then
				b.Text = LOOK[a][1]
				b.BackgroundColor3 = LOOK[a][2]
			end
		end
	end)
end

return FarmController
