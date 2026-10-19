--[[
The crops you see and touch (master plan §5, §9). The server owns the tiles (Store "crops"); this draws a plant on
each in one of four stages (seedling, growing, nearly ripe, ready: a bigger, brighter shape with a bob) and
handles the input:

  tap a tile      plant the chosen crop on an empty one, harvest a ripe one
  walk over       a ripe tile under your feet is harvested (phones: no aiming)
  the crop bar    the unlocked crops along the bottom; the chosen one lit; PLANT ALL fills every empty tile

  CropController.refs      bar, buttons, plantAll (tests)
  CropController.tap(id)   as a tap on that tile (tests)
  CropController.plants()  how many plants are drawn
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Crops = require(ReplicatedStorage.Shared.Data.Crops)
local Format = require(ReplicatedStorage.Shared.Format)
local Layout = require(ReplicatedStorage.Shared.World.Layout)
local Net = require(ReplicatedStorage.Shared.Net)
local Shapes = require(ReplicatedStorage.Shared.World.Shapes)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local CropController = { Name = "CropController", Order = 20, WALK_REACH = 2.6 }

local P = Constants.PALETTE
local player = Players.LocalPlayer
local refs = { buttons = {} }
CropController.refs = refs
local folder
local plants = {} -- [tileId] = { model, crop, stage }
local serverOffset = 0 -- os.time() here minus the server's (they're close; the stage is what matters)
local lastWalk = 0
local walked = {} -- [tileId] = when we last asked

local function territoryIndex()
	local t = Store.get("territory")
	return t and t.index
end

-- The plant shapes: one small model a stage, in the crop's colour
local function build(crop, stage, tileCf)
	local c = Crops[crop]
	local m = Instance.new("Model")
	m.Name = "Plant"
	local k = ({ 0.3, 0.6, 0.85, 1 })[stage]
	local leaf = P.leaf
	local function part(size, offset, color, shape)
		local p = Shapes.part(m, size, tileCf * offset, color, { CanQuery = false })
		p.CastShadow = false
		if shape then
			p.Shape = shape
		end
		return p
	end
	if c.shape == "bush" then
		part(Vector3.new(2.6 * k, 1.4 * k, 2.6 * k), CFrame.new(0, 0.9 * k + 0.25, 0), leaf)
		if stage >= 3 then
			for i = 1, stage == 4 and 5 or 2 do
				local a = i * 1.3
				part(
					Vector3.new(0.5, 0.5, 0.5),
					CFrame.new(math.cos(a) * 1.1, 1.2, math.sin(a) * 1.1),
					stage == 4 and c.color or c.color:Lerp(leaf, 0.5),
					Enum.PartType.Ball
				)
			end
		end
	elseif c.shape == "vine" then
		part(Vector3.new(0.3, 3.2 * k, 0.3), CFrame.new(0, 1.6 * k + 0.25, 0), P.woodDark)
		part(Vector3.new(1.8 * k, 2.4 * k, 1.2 * k), CFrame.new(0, 1.6 * k + 0.25, 0), leaf)
		if stage >= 3 then
			for i = 1, stage == 4 and 4 or 2 do
				part(
					Vector3.new(0.7, 0.7, 0.7),
					CFrame.new((i % 2 == 0 and 0.7 or -0.7), 1 + i * 0.5, 0.5),
					stage == 4 and c.color or c.color:Lerp(leaf, 0.5),
					Enum.PartType.Ball
				)
			end
		end
	elseif c.shape == "stalk" then
		for i = -1, 1 do
			for j = -1, 1 do
				part(
					Vector3.new(0.3, 2.8 * k, 0.3),
					CFrame.new(i * 1.1, 1.4 * k + 0.25, j * 1.1),
					stage == 4 and c.color or leaf
				)
				if stage >= 3 then
					part(Vector3.new(0.5, 0.9, 0.5), CFrame.new(i * 1.1, 2.8 * k + 0.5, j * 1.1), c.color)
				end
			end
		end
	elseif c.shape == "tall" then
		for i = -1, 1, 2 do
			part(Vector3.new(0.4, 4.5 * k, 0.4), CFrame.new(i * 0.9, 2.25 * k + 0.25, 0), leaf)
			part(Vector3.new(1.6 * k, 0.3, 0.6), CFrame.new(i * 0.9, 2 * k + 0.6, 0.3) * CFrame.Angles(0, 0, 0.4), leaf)
			if stage >= 3 then
				part(Vector3.new(0.7, 1.4, 0.7), CFrame.new(i * 0.9 + 0.3, 2.6 * k + 0.5, 0.2), c.color)
			end
		end
	elseif c.shape == "gourd" then
		part(Vector3.new(3 * k, 0.5, 3 * k), CFrame.new(0, 0.5, 0), leaf)
		if stage >= 2 then
			local s = ({ 0, 0.8, 1.3, 2 })[stage]
			part(
				Vector3.new(s, s * 0.8, s),
				CFrame.new(0.4, s * 0.4 + 0.3, -0.3),
				stage == 4 and c.color or c.color:Lerp(leaf, 0.5),
				Enum.PartType.Ball
			)
			if stage == 4 then
				part(Vector3.new(0.3, 0.6, 0.3), CFrame.new(0.4, s * 0.8 + 0.5, -0.3), P.woodDark)
			end
		end
	else -- tree
		part(Vector3.new(0.6, 3 * k + 1, 0.6), CFrame.new(0, 1.5 * k + 0.7, 0), P.woodDark)
		part(Vector3.new(3 * k + 0.5, 2.4 * k + 0.5, 3 * k + 0.5), CFrame.new(0, 3 * k + 1.2, 0), leaf)
		if stage >= 3 then
			for i = 1, stage == 4 and 6 or 3 do
				local a = i * 1.05
				part(
					Vector3.new(0.6, 0.6, 0.6),
					CFrame.new(math.cos(a) * 1.4, 3 * k + 1 + math.sin(a * 2) * 0.6, math.sin(a) * 1.4),
					stage == 4 and c.color or c.color:Lerp(leaf, 0.5),
					Enum.PartType.Ball
				)
			end
		end
	end
	if stage == 4 then
		-- a soft ring on the soil: ready
		local ring = part(Vector3.new(4.6, 0.1, 4.6), CFrame.new(0, 0.42, 0), Color3.fromRGB(255, 240, 150))
		ring.Transparency = 0.45
		ring.Name = "Ready"
	end
	m.Parent = folder
	return m
end

local function tileCFrame(id)
	local i = territoryIndex()
	if not i then
		return nil
	end
	local key, n = Layout.parseTile(id)
	if not key then
		return nil
	end
	local x, z = Layout.tilePos(key, n)
	return Layout.cframe(i, x, z, 0)
end

local function stageOf(t, growth)
	local c = Crops[t.crop]
	if not c then
		return 1
	end
	local elapsed = os.time() - serverOffset - t.at
	return Crops.stage(elapsed, c.grow / (growth or 1))
end

local function refresh()
	local crops = Store.get("crops")
	if not crops or not territoryIndex() then
		return
	end
	if crops.serverTime then
		serverOffset = os.time() - crops.serverTime
	end
	local seen = {}
	for id, t in crops.tiles do
		seen[id] = true
		local want = t and { crop = t.crop, stage = stageOf(t, crops.growth) } or nil
		local have = plants[id]
		if want and (not have or have.crop ~= want.crop or have.stage ~= want.stage) then
			if have then
				have.model:Destroy()
			end
			local cf = tileCFrame(id)
			if cf then
				plants[id] = { model = build(want.crop, want.stage, cf), crop = want.crop, stage = want.stage, cf = cf }
			end
		elseif not want and have then
			have.model:Destroy()
			plants[id] = nil
		end
	end
	for id, have in plants do
		if not seen[id] then
			have.model:Destroy()
			plants[id] = nil
		end
	end
end

function CropController.plants()
	local n = 0
	for _ in plants do
		n += 1
	end
	return n
end

function CropController.tap(id)
	local crops = Store.get("crops")
	local t = crops and crops.tiles[id]
	if t == nil then
		return false
	end
	if t == false then
		Net.send("Crop", "plant", id)
	else
		Net.send("Crop", "harvest", id)
	end
	return true
end

local function tapped(pos)
	local cam = workspace.CurrentCamera
	if not cam or not pos then
		return false
	end
	local ray = cam:ViewportPointToRay(pos.X, pos.Y)
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 300)
	if not hit then
		return false
	end
	local part = hit.Instance
	local id = part and part:GetAttribute("Id")
	if id and part.Name == "Tile" then
		return CropController.tap(id)
	end
	-- a plant or the ridge: the nearest tile to the hit
	local best, bestD
	for tid, pl in plants do
		local d = pl.cf.Position - hit.Position
		d = Vector3.new(d.X, 0, d.Z).Magnitude
		if d < 3 and (not bestD or d < bestD) then
			best, bestD = tid, d
		end
	end
	if best then
		return CropController.tap(best)
	end
	-- an empty tile's soil part hit by its edge
	local crops = Store.get("crops")
	if crops then
		for tid, t in crops.tiles do
			if t == false then
				local cf = tileCFrame(tid)
				if cf then
					local d = cf.Position - hit.Position
					if Vector3.new(d.X, 0, d.Z).Magnitude < 2.6 then
						return CropController.tap(tid)
					end
				end
			end
		end
	end
	return false
end

-- Walking over a ripe tile harvests it
local function walk()
	local c = player.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	local t = os.clock()
	if t - lastWalk < 0.25 then
		return
	end
	lastWalk = t
	local pos = hrp.Position
	for id, pl in plants do
		if pl.stage == 4 then
			local d = pl.cf.Position - pos
			if Vector3.new(d.X, 0, d.Z).Magnitude <= CropController.WALK_REACH and t - (walked[id] or 0) > 1.5 then
				walked[id] = t
				Net.send("Crop", "harvest", id)
			end
		end
	end
end

local function paintBar()
	local crops = Store.get("crops")
	if not crops then
		return
	end
	local unlocked = {}
	for _, key in crops.unlocked or {} do
		unlocked[key] = true
	end
	local n = 0
	for _, key in Crops.LIST do
		local b = refs.buttons[key]
		b.Visible = unlocked[key] == true
		if b.Visible then
			n += 1
			b.LayoutOrder = n
		end
		b.BackgroundColor3 = crops.chosen == key and Theme.Color.mustard or Theme.Color.paper
		b.Ring.Visible = crops.chosen == key
	end
	refs.bar.Size = UDim2.fromOffset(n * 64 + 150, 66)
	refs.plantAll.Visible = n > 0
end

function CropController:init()
	folder = Instance.new("Folder")
	folder.Name = "Plants"
	folder.Parent = workspace
	local gui = Theme.screen("Crops", 6, player:WaitForChild("PlayerGui"))
	refs.gui = gui
	-- the crop bar: along the bottom, left of centre
	local bar = Theme.slab({
		Name = "CropBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(214, 66),
		Parent = gui,
	})
	refs.bar = bar
	Theme.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = bar,
	})
	Theme.padding(6).Parent = bar
	for _, key in Crops.LIST do
		local c = Crops[key]
		local b = Theme.button({
			Name = key,
			Text = c.icon,
			Size = UDim2.fromOffset(58, 54),
			BackgroundColor3 = Theme.Color.paper,
			dark = true,
			Visible = false,
			Parent = bar,
		})
		b.TextSize = 28
		b.TextScaled = false
		Theme.new("Frame", {
			Name = "Ring",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 8, 1, 8),
			BackgroundTransparency = 1,
			Visible = false,
			Parent = b,
		}, { Theme.corner(20), Theme.stroke(4, Theme.Color.mustard) })
		Theme.text({
			Name = "Tip",
			Text = `{c.name}\n{Format.cash(c.value)} · {c.grow}s`,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 0, -6),
			Size = UDim2.fromOffset(120, 40),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = Theme.Color.white,
			outline = 2,
			fit = 15,
			Visible = false,
			Parent = b,
		})
		b.MouseEnter:Connect(function()
			b.Tip.Visible = true
		end)
		b.MouseLeave:Connect(function()
			b.Tip.Visible = false
		end)
		b.Activated:Connect(function()
			Net.send("Crop", "choose", key)
		end)
		refs.buttons[key] = b
	end
	refs.plantAll = Theme.button({
		Name = "PlantAll",
		Text = "PLANT ALL",
		Size = UDim2.fromOffset(130, 54),
		LayoutOrder = 99,
		BackgroundColor3 = Theme.Color.good,
		Visible = false,
		Parent = bar,
	})
	refs.plantAll.Activated:Connect(function()
		Net.send("Crop", "plantAll")
	end)
	Theme.compact(bar, 0.85)

	Store.Changed:Connect(function(partial)
		if partial.crops then
			refresh()
			paintBar()
		elseif partial.territory then
			refresh()
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			local pos = input.Position
			tapped(pos and Vector2.new(pos.X, pos.Y))
		end
	end)
	-- the stages move on their own with time; the ready ones bob
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 1 then
			acc = 0
			refresh()
		end
		walk()
	end)
end

return CropController
