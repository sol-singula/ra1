--[[
Feedback (master plan §9): a produce burst and a pop when a tile is harvested, coins floating up at the counter
on a sale, a bigger burst on a purchase; the sounds for each (off in Settings).

  EffectsController.bursts()   how many bursts have played (tests)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Crops = require(ReplicatedStorage.Shared.Data.Crops)
local Layout = require(ReplicatedStorage.Shared.World.Layout)
local Net = require(ReplicatedStorage.Shared.Net)
local Shapes = require(ReplicatedStorage.Shared.World.Shapes)
local Store = require(script.Parent.Parent.Store)

local EffectsController = { Name = "EffectsController", Order = 55 }

local folder
local bits = {} -- { part, vel, t0, life }
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
		table.insert(
			bits,
			{
				part = p,
				vel = Vector3.new(math.cos(a) * 6, 9 + (k % 3) * 2, math.sin(a) * 6),
				t0 = os.clock(),
				life = 0.9,
			}
		)
	end
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
			burst(Vector3.new(e.at[1], e.at[2] + 3, e.at[3]), Color3.fromRGB(255, 210, 60), 4, 0.4)
			play("coin")
		end
	end)
	Net.listen("Toast", function(text, kind)
		if kind == "good" and type(text) == "string" and text:find("bought") then
			play("buy")
		end
	end)
	RunService.Heartbeat:Connect(function(dt)
		local t = os.clock()
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
