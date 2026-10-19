--[[
The stock yard right of the stand (World/PenBuilder lays it out): crates pile up as stock comes in, one crate for
every slice of the storage, coloured by the crops in stock, so how full the store is shows at a glance. The yard's
sign reads "38 / 40"; a full yard turns the sign red and a FULL tag flashes over it (the machines wait then).

  StockController.crates()   how many crates show (tests)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Crops = require(ReplicatedStorage.Shared.Data.Crops)
local Format = require(ReplicatedStorage.Shared.Format)
local Layout = require(ReplicatedStorage.Shared.World.Layout)
local Shapes = require(ReplicatedStorage.Shared.World.Shapes)
local Store = require(script.Parent.Parent.Store)

local StockController = { Name = "StockController", Order = 58 }

local COLS, ROWS, LAYERS = 4, 8, 3
local CAP = COLS * ROWS * LAYERS
local SIZE = 1.8
local folder, builtFor
local pool = {} -- { crate, lid }
local shown = 0
local tag

function StockController.crates()
	return shown
end

local function build(i)
	if folder then
		folder:Destroy()
	end
	pool = {}
	folder = Shapes.folder(workspace, "StockYard")
	local z = Layout.ZONES.stock
	for layer = 0, LAYERS - 1 do
		for row = 0, ROWS - 1 do
			for col = 0, COLS - 1 do
				local x = z.cx + (col - (COLS - 1) / 2) * 2.1
				local zz = z.cz + 1 + (row - (ROWS - 1) / 2) * 2.1
				local o = Layout.cframe(i, x, zz, 0.3 + SIZE / 2 + layer * SIZE)
				local crate = Shapes.part(folder, Vector3.new(SIZE, SIZE, SIZE), o, Color3.fromRGB(196, 150, 96))
				crate.Name = "Crate"
				crate.Material = Enum.Material.WoodPlanks
				crate.Transparency = 1
				local lid = Shapes.part(
					folder,
					Vector3.new(SIZE - 0.3, 0.12, SIZE - 0.3),
					o * CFrame.new(0, SIZE / 2 + 0.03, 0),
					Color3.new(1, 1, 1)
				)
				lid.Name = "Fruit"
				lid.Transparency = 1
				table.insert(pool, { crate = crate, lid = lid })
			end
		end
	end
	tag = Shapes.part(folder, Vector3.new(0.2, 0.2, 0.2), Layout.cframe(i, z.cx, z.cz, 8), Color3.new(1, 1, 1))
	tag.Name = "FullTag"
	tag.Transparency = 1
	Shapes.label(tag, "📦 FULL!", {
		Name = "Full",
		studs = Vector2.new(7, 2.2),
		StudsOffset = Vector3.new(0, 0, 0),
		BackgroundColor3 = Color3.fromRGB(200, 40, 40),
		MaxDistance = 140,
	}).Enabled =
		false
	builtFor = i
end

local function paint()
	local t = Store.get("territory")
	local b = Store.get("business")
	if not t or not t.index then
		return
	end
	if builtFor ~= t.index then
		build(t.index)
	end
	if not b then
		return
	end
	local storage = math.max(1, b.storage or 1)
	local stock = b.stock or 0
	local want = stock > 0 and math.clamp(math.ceil(stock / storage * CAP), 1, CAP) or 0
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
			for _ = 1, math.max(1, math.floor(n / math.max(total, 1) * want + 0.5)) do
				table.insert(colors, Crops[key].color)
			end
		end
	end
	for k, c in pool do
		local on = k <= want
		c.crate.Transparency = on and 0 or 1
		c.lid.Transparency = on and 0 or 1
		if on then
			c.lid.Color = colors[(k - 1) % math.max(#colors, 1) + 1] or Color3.fromRGB(228, 40, 56)
		end
	end
	shown = want
	-- the sign
	local model = workspace:FindFirstChild("Territories") and workspace.Territories:FindFirstChild("T" .. t.index)
	local board = model and model:FindFirstChild("StockBoard", true)
	if board then
		for _, sg in board:GetChildren() do
			if sg:IsA("SurfaceGui") then
				local line = sg:FindFirstChild("Line")
				if line then
					line.Text = `{Format.num(stock)} / {Format.num(storage)}`
					line.TextColor3 = b.full and Color3.fromRGB(255, 110, 100) or Color3.new(1, 1, 1)
				end
			end
		end
		board.Color = b.full and Color3.fromRGB(150, 36, 32) or Color3.fromRGB(60, 50, 44)
	end
	if tag then
		tag.Full.Enabled = b.full == true
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
		if tag and tag:FindFirstChild("Full") and tag.Full.Enabled then
			tag.Full.StudsOffset = Vector3.new(0, math.sin(acc * 6) * 0.4, 0)
		end
	end)
end

return StockController
