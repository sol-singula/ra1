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

local CropModels = require(ReplicatedStorage.Shared.World.CropModels)
local Crops = require(ReplicatedStorage.Shared.Data.Crops)
local Format = require(ReplicatedStorage.Shared.Format)
local Shapes = require(ReplicatedStorage.Shared.World.Shapes)
local Layout = require(ReplicatedStorage.Shared.World.Layout)
local Net = require(ReplicatedStorage.Shared.Net)
local Bus = require(script.Parent.Parent.UI.Bus)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local CropController = { Name = "CropController", Order = 20, WALK_REACH = 2.6 }

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

-- The plants: World/CropModels (one model per crop, four readable stages)
local function build(crop, stage, tileCf)
	return CropModels.build(folder, tileCf * CFrame.new(0, 0.42, 0), crop, stage)
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

-- The golden crop: a gold ring and a spinning star over its tile, a tag with what it pays
local goldenRefs
local function golden()
	local crops = Store.get("crops")
	local id = crops and crops.golden
	if goldenRefs and goldenRefs.id ~= id then
		goldenRefs.folder:Destroy()
		goldenRefs = nil
	end
	if not id or goldenRefs then
		return
	end
	local cf = tileCFrame(id)
	if not cf then
		return
	end
	local f = Shapes.folder(workspace, "GoldenCrop")
	local ring = Shapes.cylinder(
		f,
		Vector3.new(0.2, 5.4, 5.4),
		cf * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(255, 205, 50),
		{ CanQuery = false }
	)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.2
	local star = Shapes.sphere(
		f,
		Vector3.new(1.2, 1.2, 1.2),
		cf * CFrame.new(0, 4, 0),
		Color3.fromRGB(255, 215, 60),
		{ CanQuery = false }
	)
	star.Name = "Star"
	star.Material = Enum.Material.Neon
	Shapes.label(star, `⭐ TAP! +{Format.cash(crops.goldenValue or 0)}`, {
		Name = "GoldenTag",
		studs = Vector2.new(7, 2),
		StudsOffset = Vector3.new(0, 2, 0),
		BackgroundColor3 = Color3.fromRGB(200, 140, 20),
		MaxDistance = 160,
	})
	goldenRefs = { id = id, folder = f, ring = ring, star = star, cf = cf }
end
CropController.golden = function()
	return goldenRefs and goldenRefs.id or nil
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
	-- (a golden crop pays at any stage: a tap on it is a harvest even before it's ripe)
	if t == false and crops.golden ~= id then
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
	-- (walking over the golden crop takes it too, at any stage)
	if goldenRefs then
		local d = goldenRefs.cf.Position - pos
		if Vector3.new(d.X, 0, d.Z).Magnitude <= CropController.WALK_REACH and t - (walked.golden or 0) > 1 then
			walked.golden = t
			Net.send("Crop", "harvest", goldenRefs.id)
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
	-- the guide's PLANT ALL step: the button pulses with a gold ring
	local ring = Theme.new("Frame", {
		Name = "Ring",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 14, 1, 14),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = refs.plantAll,
	}, { Theme.corner(22), Theme.stroke(5, Color3.fromRGB(255, 205, 40)) })
	refs.plantRing = ring
	local wanted = false
	Bus.Highlight:Connect(function(name)
		wanted = name == "plantAll"
	end)
	RunService.Heartbeat:Connect(function()
		ring.Visible = wanted and math.sin(os.clock() * 7) > -0.4
	end)
	Theme.compact(bar, 0.85)

	Store.Changed:Connect(function(partial)
		if partial.crops then
			-- the clock is synced when a message comes in (not on every refresh: the message gets older)
			local crops = Store.get("crops")
			if crops and crops.serverTime then
				serverOffset = os.time() - crops.serverTime
			end
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
		golden()
		if goldenRefs then
			local t = os.clock()
			goldenRefs.star.CFrame = goldenRefs.cf
				* CFrame.new(0, 4 + math.sin(t * 3) * 0.4, 0)
				* CFrame.Angles(0, t * 2, 0)
			goldenRefs.ring.Transparency = 0.2 + (math.sin(t * 6) + 1) * 0.25
		end
		walk()
	end)
end

return CropController
