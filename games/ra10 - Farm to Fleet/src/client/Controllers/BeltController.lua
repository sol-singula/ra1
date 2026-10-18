--[[
The conveyor on screen: on every plot that has one (its Hopper part), goods ride the belt from the coop, along the
pens and down the farm path to the stand: crates of crops, eggs, milk cans, wool, spaced out and always moving, so
you can see the farm selling itself. Client only (nothing to replicate): the server's conveyor does the selling.

  BeltController.riding()   how many goods are on belts now
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Crops = require(ReplicatedStorage.Shared.Data.Crops)
local PlotLayout = require(ReplicatedStorage.Shared.World.PlotLayout)

local BeltController = { Name = "BeltController", Order = 44, SCAN = 2, SPEED = 7, GAP = 6, Y = 2.3 }

local belts = {} -- [plot index] = { folder, goods = { { model, s } }, length }
local lastScan = -math.huge

function BeltController.riding()
	local n = 0
	for _, b in belts do
		n += #b.goods
	end
	return n
end

-- The route's length, and the spot s studs along it
local function length()
	local total = 0
	local r = PlotLayout.CONVEYOR
	for i = 1, #r - 1 do
		total += (r[i + 1] - r[i]).Magnitude
	end
	return total
end

local function along(s)
	local r = PlotLayout.CONVEYOR
	for i = 1, #r - 1 do
		local seg = (r[i + 1] - r[i]).Magnitude
		if s <= seg then
			return r[i]:Lerp(r[i + 1], s / seg)
		end
		s -= seg
	end
	return r[#r]
end

local LOOKS = {
	function(m, k) -- a crate of crops
		local crate = Instance.new("Part")
		crate.Size = Vector3.new(1.4, 0.9, 1.4)
		crate.Color = Color3.fromRGB(170, 120, 70)
		crate.Material = Enum.Material.Wood
		crate.Name = "Crate"
		crate.Parent = m
		local top = Instance.new("Part")
		top.Shape = Enum.PartType.Ball
		top.Size = Vector3.new(1.1, 0.7, 1.1)
		local key = Crops.LIST[(k % 5) + 1]
		top.Color = Crops[key].color
		top.Name = "Produce"
		top.Parent = m
		return { crate, Vector3.new() }, { top, Vector3.new(0, 0.55, 0) }
	end,
	function(m) -- a tray of eggs
		local tray = Instance.new("Part")
		tray.Size = Vector3.new(1.4, 0.3, 1)
		tray.Color = Color3.fromRGB(200, 170, 120)
		tray.Name = "Tray"
		tray.Parent = m
		local out = { { tray, Vector3.new(0, -0.3, 0) } }
		for i = 0, 2 do
			local egg = Instance.new("Part")
			egg.Shape = Enum.PartType.Ball
			egg.Size = Vector3.new(0.45, 0.55, 0.45)
			egg.Color = Color3.fromRGB(250, 245, 230)
			egg.Name = "Egg"
			egg.Parent = m
			table.insert(out, { egg, Vector3.new(-0.45 + i * 0.45, 0, 0) })
		end
		return table.unpack(out)
	end,
	function(m) -- a milk can
		local can = Instance.new("Part")
		can.Shape = Enum.PartType.Cylinder
		can.Size = Vector3.new(1.2, 0.8, 0.8)
		can.Color = Color3.fromRGB(215, 220, 228)
		can.Material = Enum.Material.Metal
		can.Name = "MilkCan"
		can.Parent = m
		return { can, Vector3.new(0, 0.1, 0), CFrame.Angles(0, 0, math.rad(90)) }
	end,
}

local function good(folder, k)
	local m = Instance.new("Model")
	m.Name = "Good"
	m.Parent = folder
	local parts = { LOOKS[k % #LOOKS + 1](m, k) }
	for _, p in parts do
		p[1].Anchored = true
		p[1].CanCollide = false
		p[1].CanQuery = false
		p[1].CanTouch = false
		p[1].CastShadow = false
		p[1].TopSurface = Enum.SurfaceType.Smooth
		p[1].BottomSurface = Enum.SurfaceType.Smooth
	end
	return { model = m, parts = parts }
end

local function scan()
	local farms = workspace:FindFirstChild("Farms")
	local seen = {}
	for _, plot in farms and farms:GetChildren() or {} do
		local i = tonumber(string.match(plot.Name, "^Plot(%d+)$"))
		if i and plot:FindFirstChild("Hopper", true) then
			seen[i] = true
			if not belts[i] then
				local folder = Instance.new("Folder")
				folder.Name = "BeltGoods" .. i
				folder.Parent = workspace
				local len = length()
				local b = { folder = folder, goods = {}, length = len }
				for k = 0, math.floor(len / BeltController.GAP) - 1 do
					local g = good(folder, k)
					g.s = k * BeltController.GAP
					table.insert(b.goods, g)
				end
				belts[i] = b
			end
		end
	end
	for i, b in belts do
		if not seen[i] then
			b.folder:Destroy()
			belts[i] = nil
		end
	end
end

local function place(i, g)
	local at = along(g.s)
	local cf = PlotLayout.frame(i) * CFrame.new(at.X, BeltController.Y, at.Z)
	for _, p in g.parts do
		p[1].CFrame = cf * CFrame.new(p[2]) * (p[3] or CFrame.new())
	end
end

function BeltController.step(dt)
	for i, b in belts do
		for _, g in b.goods do
			g.s = (g.s + BeltController.SPEED * dt) % b.length
			place(i, g)
		end
	end
end

function BeltController:init()
	RunService.Heartbeat:Connect(function(dt)
		if os.clock() - lastScan >= BeltController.SCAN then
			lastScan = os.clock()
			scan()
		end
		BeltController.step(dt)
	end)
end

return BeltController
