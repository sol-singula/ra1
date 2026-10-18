--[[
Farming with one thumb (master plan §3, phone first). A big round button at the bottom right says what it will do
for the soil you're standing by (Net "Farm" "act"; the server does all of it that's in reach): HARVEST when
something there is ripe, PLANT when there's empty soil, WATER (once you have the well) when something's growing
dry, TEND for a growing crop not tended yet (once a crop: it grows 40% faster and pays half its price there and
then). It hides when there's nothing to do. With it, along the bottom of the screen, the crop picker: one chip per
crop you've unlocked, in rows of five (Net "Farm" "crop"). Walk up to the soil and every crop near you shows its
timer above it (0:04, READY!). On a PC, E (or a click away from the buttons) does the same as the button.

  FarmController.action()   -> "harvest" | "plant" | "water" | "tend" | nil, what the button shows now
  FarmController.press()    what the button does
  FarmController.refs
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Crops = require(ReplicatedStorage.Shared.Data.Crops)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Store = require(script.Parent.Parent.Store)
local Bus = require(script.Parent.Parent.UI.Bus)
local Theme = require(script.Parent.Parent.UI.Theme)

local FarmController = { Name = "FarmController", Order = 20, REACH = 11, TIMER_REACH = 18 }

local C = Theme.Color
local player = Players.LocalPlayer
local refs = {}
FarmController.refs = refs

local LOOK = {
	harvest = { "HARVEST", Color3.fromRGB(240, 70, 70) },
	plant = { "PLANT", Color3.fromRGB(70, 190, 90) },
	water = { "WATER", Color3.fromRGB(60, 150, 235) },
	tend = { "TEND", Color3.fromRGB(245, 165, 40) },
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
	local ripe, empty, dry, growing = false, false, false, false
	for n, tile in tiles() do
		local d = tile.Position - r.Position
		if Vector3.new(d.X, 0, d.Z).Magnitude <= FarmController.REACH then
			local t = f.tiles and f.tiles[n]
			if not t then
				empty = true
			elseif now - t.at >= t.need then
				ripe = true
			elseif not t.tended then
				growing = true
			elseif f.well and not t.watered then
				dry = true
			end
		end
	end
	if ripe then
		return "harvest"
	elseif empty then
		return "plant"
	elseif growing then
		return "tend"
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
	refs.many = #list >= 2
	refs.picker.Visible = refs.many and refs.act ~= nil and refs.act.Visible
	if not refs.many then
		return
	end
	local ROW = 5 -- (chips in rows of five, along the bottom of the screen)
	for i, key in list do
		local c = Crops[key]
		local col, rowN = (i - 1) % ROW, (i - 1) // ROW
		local chip = Theme.button({
			Name = "Chip_" .. key,
			Text = c.name,
			Position = UDim2.fromOffset(col * 110, rowN * 40),
			Size = UDim2.fromOffset(104, 34),
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
	refs.picker.Size = UDim2.fromOffset(math.min(#list, ROW) * 110 - 6, math.ceil(#list / ROW) * 40)
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
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
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
	-- (the guide's step needs this button: it pulses, a gold ring round it)
	local ring = Theme.new("Frame", {
		Name = "Ring",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 24, 1, 24),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = b,
	}, { Theme.corner("round"), Theme.stroke(6, Color3.fromRGB(255, 205, 40)) })
	refs.ring = ring
	local wanted = false
	Bus.Highlight:Connect(function(name)
		wanted = name == "act"
	end)
	-- the timers over the crops near you
	local timers = {}
	refs.timers = timers
	local function timerFor(n, tile)
		local t = timers[n]
		if t and t.gui.Adornee == tile then
			return t
		end
		if t then
			t.gui:Destroy()
		end
		local bb = Instance.new("BillboardGui")
		bb.Name = "CropTimer" .. n
		bb.Size = UDim2.fromOffset(84, 40)
		bb.StudsOffset = Vector3.new(0, 3.6, 0)
		bb.AlwaysOnTop = true
		bb.MaxDistance = FarmController.TIMER_REACH + 6
		bb.Adornee = tile
		bb.Enabled = false
		local label = Theme.new("TextLabel", {
			Name = "Time",
			Size = UDim2.new(1, 0, 0, 24),
			BackgroundColor3 = Color3.fromRGB(30, 34, 44),
			BackgroundTransparency = 0.2,
			Font = Theme.Display,
			TextSize = 18,
			TextColor3 = Color3.new(1, 1, 1),
			Parent = bb,
		}, { Theme.corner("round"), Theme.stroke(2, Color3.fromRGB(255, 255, 255)) })
		local bar = Theme.new("Frame", {
			Name = "Bar",
			Position = UDim2.new(0.1, 0, 0, 28),
			Size = UDim2.new(0.8, 0, 0, 7),
			BackgroundColor3 = Color3.fromRGB(30, 34, 44),
			BackgroundTransparency = 0.25,
			Parent = bb,
		}, { Theme.corner("round") })
		local fill = Theme.new("Frame", {
			Name = "Fill",
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = Color3.fromRGB(110, 210, 90),
			Parent = bar,
		}, { Theme.corner("round") })
		bb.Parent = gui.Parent
		t = { gui = bb, label = label, bar = bar, fill = fill }
		timers[n] = t
		return t
	end
	local nextTimers = 0
	local function paintTimers()
		local f = Store.get("farm")
		local r = root()
		local now = workspace:GetServerTimeNow()
		local seen = {}
		for n, tile in tiles() do
			local s = f and f.tiles and f.tiles[n]
			local d = r and (tile.Position - r.Position)
			if s and d and Vector3.new(d.X, 0, d.Z).Magnitude <= FarmController.TIMER_REACH then
				seen[n] = true
				local t = timerFor(n, tile)
				local left = s.need - (now - s.at)
				t.gui.Enabled = true
				if left <= 0 then
					t.label.Text = s.golden and "★ READY!" or "READY!"
					t.label.BackgroundColor3 = Color3.fromRGB(70, 180, 70)
					t.bar.Visible = false
				else
					t.label.Text = (s.golden and "★ " or "") .. Format.time(math.ceil(left))
					t.label.BackgroundColor3 = Color3.fromRGB(30, 34, 44)
					t.bar.Visible = true
					t.fill.Size = UDim2.fromScale(math.clamp(1 - left / math.max(s.need, 0.1), 0, 1), 1)
				end
			end
		end
		for n, t in timers do
			if not seen[n] then
				t.gui.Enabled = false
			end
		end
	end
	FarmController.paintTimers = paintTimers
	local shown
	RunService.Heartbeat:Connect(function()
		if os.clock() >= nextTimers then
			nextTimers = os.clock() + 0.1
			paintTimers()
		end
		local press = b:FindFirstChild("Press")
		ring.Visible = wanted and b.Visible
		if ring.Visible then
			local k = math.abs(math.sin(os.clock() * 4))
			ring.Size = UDim2.new(1, 18 + 14 * k, 1, 18 + 14 * k)
			if press then
				press.Scale = 1 + 0.06 * k
			end
		end
		local a = FarmController.action()
		if a ~= shown then
			shown = a
			b.Visible = a ~= nil
			refs.picker.Visible = refs.many == true and a ~= nil -- (the crops to plant, by the soil only)
			if a then
				b.Text = LOOK[a][1]
				b.BackgroundColor3 = LOOK[a][2]
			end
		end
	end)
end

return FarmController
