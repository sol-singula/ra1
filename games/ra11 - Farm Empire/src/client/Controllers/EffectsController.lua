--[[
Feedback (master plan §9): a produce burst and a pop when a tile is harvested, coins floating up at the counter
and a "+$n" floating up on a sale, a bigger burst round you on a purchase; the sounds for each (off in Settings).

  EffectsController.bursts()   how many bursts have played (tests)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Crops = require(ReplicatedStorage.Shared.Data.Crops)
local Format = require(ReplicatedStorage.Shared.Format)
local Layout = require(ReplicatedStorage.Shared.World.Layout)
local Net = require(ReplicatedStorage.Shared.Net)
local Shapes = require(ReplicatedStorage.Shared.World.Shapes)
local Store = require(script.Parent.Parent.Store)

local EffectsController = { Name = "EffectsController", Order = 55 }

local folder
local bits = {} -- { part, vel, t0, life }
local pops = {} -- { part, label, t0 }
local count = 0

local SOUNDS = {
	pop = "rbxassetid://6895079853",
	coin = "rbxassetid://4612375233",
	buy = "rbxassetid://6026984224",
}
local sounds = {}

local function play(name)
	local p = Store.get("profile")
	if p and p.sounds == false then
		return
	end
	local s = sounds[name]
	if not s then
		s = Instance.new("Sound")
		s.SoundId = SOUNDS[name]
		s.Volume = 0.5
		s.Parent = SoundService
		sounds[name] = s
	end
	pcall(s.Play, s)
end

function EffectsController.bursts()
	return count
end

local function burst(pos, color, n, size)
	count += 1
	for k = 1, n do
		local a = k / n * math.pi * 2
		local p = Shapes.part(folder, Vector3.new(size, size, size), CFrame.new(pos), color, { CanQuery = false })
		p.CastShadow = false
		if k % 2 == 0 then
			p.Shape = Enum.PartType.Ball
		end
		table.insert(bits, {
			part = p,
			vel = Vector3.new(math.cos(a) * 6, 9 + (k % 3) * 2, math.sin(a) * 6),
			t0 = os.clock(),
			life = 0.9,
		})
	end
end

-- "+$25" floating up from where the money came in
local function cashPop(pos, amount)
	local a =
		Shapes.part(folder, Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos), Color3.new(1, 1, 1), { CanQuery = false })
	a.Name = "CashPop"
	a.Transparency = 1
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(140, 44)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 120
	local l = Instance.new("TextLabel")
	l.Name = "Text"
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.TextColor3 = Color3.fromRGB(120, 235, 110)
	l.TextStrokeColor3 = Color3.fromRGB(30, 60, 20)
	l.TextStrokeTransparency = 0
	l.Text = "+" .. Format.cash(amount)
	l.Parent = bb
	bb.Parent = a
	table.insert(pops, { part = a, label = l, t0 = os.clock(), from = pos })
	while #pops > 12 do
		table.remove(pops, 1).part:Destroy()
	end
end
EffectsController.cashPop = cashPop

function EffectsController.pops()
	return #pops
end

function EffectsController:init()
	folder = Instance.new("Folder")
	folder.Name = "Effects"
	folder.Parent = workspace
	Net.listen("Harvested", function(h)
		local t = Store.get("territory")
		if type(h) ~= "table" or not t then
			return
		end
		local c = Crops[h.crop]
		burst(Layout.toWorld(t.index, h.x, h.z, 1.5), c and c.color or Color3.new(1, 1, 1), 6, 0.5)
		if h.by ~= "machine" then
			play("pop")
		end
	end)
	Net.listen("Earned", function(e)
		if type(e) == "table" and e.at then
			local at = Vector3.new(e.at[1], e.at[2] + 3, e.at[3])
			burst(at, Color3.fromRGB(255, 210, 60), 4, 0.4)
			if (e.amount or 0) > 0 then
				cashPop(at + Vector3.new((math.random() - 0.5) * 2, 1, 0), e.amount)
			end
			play("coin")
		end
	end)
	Net.listen("Toast", function(text, kind)
		if kind == "good" and type(text) == "string" and text:find("bought") then
			play("buy")
			local character = game:GetService("Players").LocalPlayer.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if hrp then
				burst(hrp.Position + Vector3.new(0, 1, 0), Color3.fromRGB(255, 205, 50), 14, 0.6)
				burst(hrp.Position + Vector3.new(0, 2, 0), Color3.fromRGB(120, 230, 110), 10, 0.5)
			end
		end
	end)
	RunService.Heartbeat:Connect(function(dt)
		local t = os.clock()
		for i = #pops, 1, -1 do
			local p = pops[i]
			local age = t - p.t0
			if age >= 1.3 then
				p.part:Destroy()
				table.remove(pops, i)
			else
				p.part.CFrame = CFrame.new(p.from + Vector3.new(0, age * 4, 0))
				local fade = math.max(0, (age - 0.8) / 0.5)
				p.label.TextTransparency = fade
				p.label.TextStrokeTransparency = fade
			end
		end
		for i = #bits, 1, -1 do
			local b = bits[i]
			if t - b.t0 >= b.life then
				b.part:Destroy()
				table.remove(bits, i)
			else
				b.vel = b.vel - Vector3.new(0, 30 * dt, 0)
				b.part.CFrame = b.part.CFrame + b.vel * dt
				b.part.Transparency = (t - b.t0) / b.life
			end
		end
	end)
end

return EffectsController
