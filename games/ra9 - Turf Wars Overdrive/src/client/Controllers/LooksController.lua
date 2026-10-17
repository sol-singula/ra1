--[[
The cosmetics others wear, drawn on this client (Data/Cosmetics looks):

  * kill effects: where someone falls, the killer's effect plays (Net "Kill" carries it): cubes, a ring, shards,
    pixels, a rising column, a spotlight; white, black or the killer's team colours, SUPERHOT-plain neon blocks
  * your own name tag, crown, halo and held bow (StatusService puts them on your character for everyone else) are hidden
    from you: in first person they'd sit in your view

  LooksController.play(effectKey, pos, team)   (tests call it too)
  LooksController.count()                       pieces on screen
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Net = require(ReplicatedStorage.Shared.Net)
require(ReplicatedStorage.Shared.Data.Season) -- (season effects resolve)

local LooksController = { Name = "LooksController", Order = 46 }

local player = Players.LocalPlayer
local folder
local bits = {} -- { part, vel, born, life, grow, spin }

local function part(size, color)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Size = size
	p.Color = color
	p.Parent = folder
	return p
end

local function add(p, vel, life, grow)
	table.insert(bits, { part = p, vel = vel, born = os.clock(), life = life, grow = grow, size = p.Size })
end

function LooksController.play(effectKey, pos, team)
	local it = Cosmetics.get(effectKey)
	if not it or it.kind ~= "effect" or typeof(pos) ~= "Vector3" then
		return false
	end
	local look = it.look
	local color = Cosmetics.color(look.color, team)
	local n = math.min(look.count or 10, UserInputService.TouchEnabled and 12 or 24)
	local at = pos + Vector3.new(0, 1.5, 0)
	if look.shape == "ring" then
		for i = 1, n do
			local a = i / n * math.pi * 2
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			local p = part(Vector3.new(0.5, 0.25, 0.5), color)
			p.CFrame = CFrame.new(at + dir * 0.5)
			add(p, dir * 16, 0.6)
		end
	elseif look.shape == "rise" then
		for i = 1, n do
			local p = part(Vector3.new(0.5, 0.5, 0.5), color)
			p.CFrame = CFrame.new(at + Vector3.new((math.random() - 0.5) * 1.6, i * 0.2, (math.random() - 0.5) * 1.6))
			add(p, Vector3.new(0, 8 + i, 0), 1.0)
		end
	elseif look.shape == "spotlight" then
		local beam = part(Vector3.new(1.4, 30, 1.4), color)
		beam.CFrame = CFrame.new(pos + Vector3.new(0, 15, 0))
		beam.Transparency = 0.4
		add(beam, Vector3.zero, 1.2, -0.5)
		for i = 1, n do
			local a = i / n * math.pi * 2
			local p = part(Vector3.new(0.4, 0.2, 0.4), Cosmetics.color("ink", team))
			p.CFrame = CFrame.new(pos + Vector3.new(math.cos(a) * 2, 0.2, math.sin(a) * 2))
			add(p, Vector3.new(math.cos(a), 0, math.sin(a)) * 4, 1.2)
		end
	else
		-- cubes, shards (thin slivers), pixels (flat squares that float up)
		for i = 1, n do
			local dir = Vector3.new(math.random() - 0.5, math.random() * 0.8 + 0.1, math.random() - 0.5)
			dir = dir.Magnitude > 0.01 and dir.Unit or Vector3.yAxis
			local size = look.shape == "shards" and Vector3.new(0.15, 0.15, 1.1)
				or (look.shape == "pixels" and Vector3.new(0.45, 0.45, 0.08) or Vector3.new(0.6, 0.6, 0.6))
			local c = (i % 4 == 0) and Cosmetics.color("white", team) or color
			local p = part(size, c)
			p.CFrame = CFrame.lookAt(at, at + dir)
			local speed = look.shape == "pixels" and 5 or 18
			add(p, dir * speed + (look.shape == "pixels" and Vector3.new(0, 4, 0) or Vector3.zero), 0.9)
		end
	end
	return true
end

function LooksController.count()
	return #bits
end

local function step(dt)
	local t = os.clock()
	for i = #bits, 1, -1 do
		local b = bits[i]
		local age = t - b.born
		if age >= b.life then
			b.part:Destroy()
			table.remove(bits, i)
		else
			b.vel = b.vel * (1 - math.min(1, dt * 2.2))
			b.part.CFrame = b.part.CFrame + b.vel * dt
			local k = age / b.life
			b.part.Transparency = math.clamp(k * k, 0, 1)
			if b.grow then
				b.part.Size = b.size * math.max(0.05, 1 + b.grow * k)
			end
		end
	end
	-- your own tag, crown and halo: out of your view
	local c = player.Character
	if c then
		local tag = c:FindFirstChild("StatusTag")
		if tag and tag.Enabled ~= false then
			tag.Enabled = false
		end
		for _, d in c:GetChildren() do
			if (d.Name == "MvpCrown" or d.Name == "VipHalo") and d.LocalTransparencyModifier ~= 1 then
				d.LocalTransparencyModifier = 1
			elseif d.Name == "HeldBow" then
				for _, q in d:GetChildren() do
					if q:IsA("BasePart") and q.LocalTransparencyModifier ~= 1 then
						q.LocalTransparencyModifier = 1 -- (you see the viewmodel instead)
					end
				end
			end
		end
	end
end

function LooksController:init()
	folder = Instance.new("Folder")
	folder.Name = "Looks"
	folder.Parent = workspace
	Net.listen("Kill", function(k)
		if type(k) == "table" and k.effect and k.pos then
			LooksController.play(k.effect, k.pos, k.killerTeam)
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return LooksController
