--[[
The stock you can see (World/Layout stockSlots): one crate or pallet for every slice of the storage, coloured by
the crops in stock. At the stand the crates stack up behind the counter; in the shop, on the shelves either side
of the back doors; in the warehouse and the centre, on the racks inside (seen through the big back doors and the
skylights) and then, when the racks are full, on pallets out in the pallet yard. A tag over the front says
"STOCK 38 / 40" and turns red and flashes FULL when it's full (the machines wait then).

  StockController.crates()   how many crates or pallets show (tests)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Crops = require(ReplicatedStorage.Shared.Data.Crops)
local Format = require(ReplicatedStorage.Shared.Format)
local Layout = require(ReplicatedStorage.Shared.World.Layout)
local Shapes = require(ReplicatedStorage.Shared.World.Shapes)
local Store = require(script.Parent.Parent.Store)

local StockController = { Name = "StockController", Order = 58 }

local folder, builtFor
local pool = {} -- { parts = { ... }, fruit = part }
local shown = 0
local tag, tagLabel

function StockController.crates()
	return shown
end

-- one slot's model: a crate (the stand, the shop) or a pallet with two boxes on it (the warehouse), hidden
local function slot(i, s, pallet)
	local o = Layout.cframe(i, s.x, s.z, s.y)
	local e = { parts = {} }
	local function add(p)
		p.Transparency = 1
		table.insert(e.parts, p)
		return p
	end
	if pallet then
		add(
			Shapes.part(
				folder,
				Vector3.new(s.size, 0.4, s.size),
				o * CFrame.new(0, 0.2, 0),
				Color3.fromRGB(186, 130, 76)
			)
		)
		local box = add(
			Shapes.part(
				folder,
				Vector3.new(s.size - 0.4, 2.4, s.size - 0.4),
				o * CFrame.new(0, 1.6, 0),
				Color3.fromRGB(200, 160, 110)
			)
		)
		box.Name = "Box"
		e.fruit = add(
			Shapes.part(
				folder,
				Vector3.new(s.size - 0.6, 0.5, s.size - 0.6),
				o * CFrame.new(0, 3.05, 0),
				Color3.new(1, 1, 1)
			)
		)
	else
		local crate = add(
			Shapes.part(
				folder,
				Vector3.new(s.size, s.size * 0.8, s.size),
				o * CFrame.new(0, s.size * 0.4, 0),
				Color3.fromRGB(196, 150, 96)
			)
		)
		crate.Material = Enum.Material.WoodPlanks
		e.fruit = add(
			Shapes.part(
				folder,
				Vector3.new(s.size - 0.3, 0.2, s.size - 0.3),
				o * CFrame.new(0, s.size * 0.8 + 0.05, 0),
				Color3.new(1, 1, 1)
			)
		)
	end
	return e
end

local function build(i, stage)
	if folder then
		folder:Destroy()
	end
	pool = {}
	folder = Shapes.folder(workspace, "Stock")
	local pallet = stage == "warehouse" or stage == "center"
	for _, s in Layout.stockSlots(stage) do
		table.insert(pool, slot(i, s, pallet))
	end
	-- the tag over the front of the building
	local _, cz, B = Layout.building(stage)
	tag =
		Shapes.part(folder, Vector3.new(0.2, 0.2, 0.2), Layout.cframe(i, 0, cz - B.d / 2, B.h + 7), Color3.new(1, 1, 1))
	tag.Name = "StockTag"
	tag.Transparency = 1
	local bb = Shapes.label(tag, "", {
		Name = "Stock",
		studs = Vector2.new(pallet and 16 or 9, pallet and 3.2 or 2.2),
		StudsOffset = Vector3.new(0, 0, 0),
		MaxDistance = 260,
	})
	tagLabel = bb.Text
	builtFor = i .. stage
end

local function paint()
	local t = Store.get("territory")
	local b = Store.get("business")
	if not t or not t.index or not b then
		return
	end
	local stage = b.stage or "stand"
	if builtFor ~= t.index .. stage then
		build(t.index, stage)
	end
	local storage = math.max(1, b.storage or 1)
	local stock = b.stock or 0
	local cap = #pool
	local want = stock > 0 and math.clamp(math.ceil(stock / storage * cap), 1, cap) or 0
	-- the crops' colours, in proportion to the mix
	local colors = {}
	local mix = b.mix or {}
	local total = 0
	for _, n in mix do
		total += n
	end
	for _, key in Crops.LIST do
		local n = mix[key] or 0
		if n > 0 then
			for _ = 1, math.max(1, math.floor(n / math.max(total, 1) * 20 + 0.5)) do
				table.insert(colors, Crops[key].color)
			end
		end
	end
	for k, e in pool do
		local on = k <= want
		for _, p in e.parts do
			p.Transparency = on and 0 or 1
		end
		if on then
			e.fruit.Color = colors[(k * 7) % math.max(#colors, 1) + 1] or Color3.fromRGB(228, 40, 56)
		end
	end
	shown = want
	if tagLabel then
		tagLabel.Text = b.full and `📦 STOCK FULL {Format.num(stock)} / {Format.num(storage)}`
			or `📦 STOCK {Format.num(stock)} / {Format.num(storage)}`
		tagLabel.BackgroundColor3 = b.full and Color3.fromRGB(200, 40, 40) or Color3.fromRGB(40, 30, 24)
	end
end

function StockController:init()
	Store.Changed:Connect(function(partial)
		if partial.business or partial.territory then
			paint()
		end
	end)
	paint()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		local b = Store.get("business")
		if tag and tag:FindFirstChild("Stock") then
			tag.Stock.StudsOffset = b and b.full and Vector3.new(0, math.sin(acc * 6) * 0.5, 0) or Vector3.new(0, 0, 0)
		end
	end)
end

return StockController
