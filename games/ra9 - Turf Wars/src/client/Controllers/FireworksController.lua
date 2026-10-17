--[[
Fireworks when a team wins: for FIREWORKS_SECONDS rockets go up all over the arena in the winners' colour and burst
into shards (the team's colour, a lighter shade, white), SUPERHOT-plain: neon cubes, no textures. Drawn on each
client only (nothing crosses the network but the Winner the match already sends). Phones (touch) get fewer.

  FireworksController.start(team)   (the match's victory starts it; tests call it directly)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Store = require(script.Parent.Parent.Store)

local FireworksController = { Name = "FireworksController", Order = 45 }

local folder
local rockets = {} -- { part, from, to, born, flight, color }
local shards = {} -- { part, vel, born, life }
local showUntil = 0
local team
local nextLaunch = 0
local lastMatch
local GRAVITY = 40

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

local function bounds()
	local m = Store.get("match") or {}
	local lo, hi = (m.loseRed or -80) - 10, (m.loseBlue or 80) + 10
	return lo, hi
end

local function launch()
	local lo, hi = bounds()
	local x = lo + math.random() * (hi - lo)
	local z = (math.random() - 0.5) * 84
	local color = Constants.TEAM_COLOR[team] or Color3.new(1, 1, 1)
	local from = Vector3.new(x, 1, z)
	local to = Vector3.new(x + (math.random() - 0.5) * 8, 30 + math.random() * 34, z + (math.random() - 0.5) * 8)
	local p = part(Vector3.new(0.5, 2.2, 0.5), Color3.new(1, 1, 1))
	table.insert(
		rockets,
		{ part = p, from = from, to = to, born = os.clock(), flight = 0.7 + math.random() * 0.3, color = color }
	)
end

local function burst(at, color)
	local n = UserInputService.TouchEnabled and 18 or 30
	local light = color:Lerp(Color3.new(1, 1, 1), 0.45)
	for i = 1, n do
		local dir = Vector3.new(math.random() - 0.5, math.random() - 0.35, math.random() - 0.5)
		dir = dir.Magnitude > 0.01 and dir.Unit or Vector3.new(0, 1, 0)
		local c = (i % 5 == 0) and Color3.new(1, 1, 1) or ((i % 2 == 0) and light or color)
		local s = part(Vector3.new(1.3, 1.3, 1.3), c)
		s.CFrame = CFrame.new(at)
		table.insert(
			shards,
			{ part = s, vel = dir * (26 + math.random() * 20), born = os.clock(), life = 1.2 + math.random() * 0.6 }
		)
	end
end

function FireworksController.start(winner)
	team = winner
	showUntil = os.clock() + Constants.FIREWORKS_SECONDS
	nextLaunch = 0
end

function FireworksController.active()
	return os.clock() < showUntil
end

function FireworksController.count()
	return #rockets + #shards
end

local function step(dt)
	local t = os.clock()
	if t < showUntil and t >= nextLaunch then
		local every = UserInputService.TouchEnabled and 0.24 or 0.12
		nextLaunch = t + every * (0.6 + math.random() * 0.8)
		launch()
		if math.random() < 0.35 then
			launch() -- (a pair now and then)
		end
	end
	for i = #rockets, 1, -1 do
		local r = rockets[i]
		local f = (t - r.born) / r.flight
		if f >= 1 then
			r.part:Destroy()
			table.remove(rockets, i)
			burst(r.to, r.color)
		else
			local eased = 1 - (1 - f) ^ 2
			local pos = r.from:Lerp(r.to, eased)
			r.part.CFrame = CFrame.lookAt(pos, pos + (r.to - r.from).Unit) * CFrame.Angles(math.rad(90), 0, 0)
		end
	end
	for i = #shards, 1, -1 do
		local s = shards[i]
		local age = t - s.born
		if age >= s.life then
			s.part:Destroy()
			table.remove(shards, i)
		else
			s.vel = s.vel * (1 - math.min(1, dt * 1.4)) + Vector3.new(0, -GRAVITY * dt, 0)
			s.part.CFrame = s.part.CFrame + s.vel * dt
			s.part.Transparency = math.clamp((age / s.life) ^ 2, 0, 1)
			local k = 1 - age / s.life * 0.6
			s.part.Size = Vector3.new(1.3, 1.3, 1.3) * k
		end
	end
end

function FireworksController:init()
	folder = Instance.new("Folder")
	folder.Name = "Fireworks"
	folder.Parent = workspace
	Store.Changed:Connect(function(partial)
		local m = partial.match
		if m and m.phase == "victory" and m.winner and m.matchId ~= lastMatch then
			lastMatch = m.matchId
			FireworksController.start(m.winner)
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return FireworksController
