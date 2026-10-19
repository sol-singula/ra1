--[[
The customers you can see (CustomerService, Net "Customer"): for every sale a little blocky shopper walks up from
the road to the stand, a bubble over their head saying what they bought and what they paid, and walks back. Up to
MAX at once; the rest are just the Cash. Client-only: nothing of this is on the server.

  CustomerController.walking()  how many shoppers are on the path right now (tests)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Crops = require(ReplicatedStorage.Shared.Data.Crops)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local PlotLayout = require(ReplicatedStorage.Shared.World.PlotLayout)
local Store = require(script.Parent.Parent.Store)

local CustomerController = { Name = "CustomerController", Order = 47, MAX = 5, SPEED = 9, STAY = 1.2 }

local player = Players.LocalPlayer
local shoppers = {} -- { model, from, to, t0, phase ("in" | "stay" | "out"), at }
local folder

local SHIRTS = {
	Color3.fromRGB(240, 90, 90),
	Color3.fromRGB(80, 150, 240),
	Color3.fromRGB(90, 190, 110),
	Color3.fromRGB(250, 200, 60),
	Color3.fromRGB(190, 110, 230),
	Color3.fromRGB(255, 140, 60),
}

local function part(parent, size, color, name)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = color
	p.Size = size
	p.Parent = parent
	return p
end

local function figure(i, text)
	local m = Instance.new("Model")
	m.Name = "Shopper"
	local skin = Color3.fromRGB(235, 200, 160)
	local body = part(m, Vector3.new(1.6, 2, 0.9), SHIRTS[i % #SHIRTS + 1], "Body")
	part(m, Vector3.new(1.2, 1.2, 1.2), skin, "Head")
	part(m, Vector3.new(0.6, 1.4, 0.6), Color3.fromRGB(60, 70, 110), "LegL")
	part(m, Vector3.new(0.6, 1.4, 0.6), Color3.fromRGB(60, 70, 110), "LegR")
	part(m, Vector3.new(1.1, 0.8, 0.9), Color3.fromRGB(150, 100, 60), "Bag")
	m.PrimaryPart = body
	local bb = Instance.new("BillboardGui")
	bb.Name = "Bubble"
	bb.Size = UDim2.fromOffset(150, 34)
	bb.StudsOffset = Vector3.new(0, 3.4, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 90
	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.fromRGB(255, 252, 240)
	label.BackgroundTransparency = 0.05
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(58, 38, 28)
	label.Text = text
	label.Parent = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label
	bb.Parent = body
	m.Parent = folder
	return m
end

local function place(m, pos, look)
	local cf = CFrame.lookAt(pos, pos + look)
	m.PrimaryPart.CFrame = cf * CFrame.new(0, 2.4, 0)
	m.Head.CFrame = cf * CFrame.new(0, 4, 0)
	m.LegL.CFrame = cf * CFrame.new(-0.45, 0.7, 0)
	m.LegR.CFrame = cf * CFrame.new(0.45, 0.7, 0)
	m.Bag.CFrame = cf * CFrame.new(1.2, 1.6, 0)
end

function CustomerController.walking()
	return #shoppers
end

local function spawnShopper(msg)
	local plot = Store.get("plot")
	if not plot or not plot.index or #shoppers >= CustomerController.MAX then
		return
	end
	local i = plot.index
	local st = PlotLayout.SPOTS.stand
	local from = PlotLayout.toWorld(i, st.X + 4 + (#shoppers % 3) * 2, -112)
	local to = PlotLayout.toWorld(i, st.X + 4 + (#shoppers % 3) * 2, st.Z - 11)
	local c = Crops[msg.crop]
	local text = `{c and c.name or "crops"} x{msg.n}  {Format.cash(msg.cash)}`
	local m = figure(#shoppers + math.floor(os.clock()), text)
	place(m, from, to - from)
	table.insert(shoppers, { model = m, from = from, to = to, t0 = os.clock(), phase = "in" })
end

local function step()
	local t = os.clock()
	for i = #shoppers, 1, -1 do
		local s = shoppers[i]
		local len = (s.to - s.from).Magnitude
		local secs = len / CustomerController.SPEED
		local k = (t - s.t0) / secs
		if s.phase == "in" then
			if k >= 1 then
				s.phase, s.t0 = "stay", t
				place(s.model, s.to, s.to - s.from)
			else
				local pos = s.from:Lerp(s.to, k)
				pos += Vector3.new(0, math.abs(math.sin(t * 10)) * 0.25, 0)
				place(s.model, pos, s.to - s.from)
			end
		elseif s.phase == "stay" then
			if t - s.t0 >= CustomerController.STAY then
				s.phase, s.t0 = "out", t
			end
		else
			if k >= 1 then
				s.model:Destroy()
				table.remove(shoppers, i)
			else
				local pos = s.to:Lerp(s.from, k)
				pos += Vector3.new(0, math.abs(math.sin(t * 10)) * 0.25, 0)
				place(s.model, pos, s.from - s.to)
			end
		end
	end
end

function CustomerController:init()
	folder = Instance.new("Folder")
	folder.Name = "Shoppers"
	folder.Parent = workspace
	Net.listen("Customer", function(m)
		if type(m) == "table" then
			spawnShopper(m)
		end
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 1 / 30 then
			return
		end
		acc = 0
		step()
	end)
	_ = player
end

return CustomerController
