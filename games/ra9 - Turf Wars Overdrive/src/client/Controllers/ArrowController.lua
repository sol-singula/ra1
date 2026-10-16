--[[
Arrows on screen (master plan §5, §0): every arrow the server announces is drawn along the same curve the server
flies it (Formulas.arrowAt from its origin and velocity, timed by server time), as a white shaft with a long thin
tracer in its team's colour behind it: the SUPERHOT red line. Your own arrow is drawn the instant you let go
(predicted) and the server's copy of it is skipped. Where an arrow stops, a few white shards burst out.

  ArrowController.predict(origin, velocity, team, shotId)   your own, right away
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)

local ArrowController = { Name = "ArrowController", Order = 20 }

local player = Players.LocalPlayer
local live = {} -- [key] = { shaft, tracer, origin, velocity, born, team, stopAt? }
local byServer = {} -- [serverId] = key
local folder
local TRACER = 14 -- studs of tracer behind the head
local shards = {}

local function part(size, color, neon)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
	p.Parent = folder
	return p
end

local function spawnArrow(key, origin, velocity, team, born)
	local color = Constants.TEAM_COLOR[team] or Color3.new(1, 1, 1)
	local shaft = part(Vector3.new(0.18, 0.18, 2.6), Color3.fromRGB(250, 250, 250), false)
	local tracer = part(Vector3.new(0.1, 0.1, 1), color, true)
	tracer.Transparency = 0.15
	live[key] = { shaft = shaft, tracer = tracer, origin = origin, velocity = velocity, born = born, team = team }
	return live[key]
end

function ArrowController.predict(origin, velocity, team, shotId)
	return spawnArrow("me" .. tostring(shotId), origin, velocity, team, workspace:GetServerTimeNow())
end

local function burst(pos, color)
	for i = 1, 5 do
		local s = part(Vector3.new(0.35, 0.35, 0.35), i == 1 and color or Color3.fromRGB(245, 245, 245), false)
		s.CFrame = CFrame.new(pos)
		table.insert(shards, {
			part = s,
			vel = Vector3.new(math.random() - 0.5, math.random() * 0.8 + 0.2, math.random() - 0.5) * 18,
			die = os.clock() + 0.45,
		})
	end
end

local function remove(key, pos)
	local a = live[key]
	if not a then
		return
	end
	live[key] = nil
	if pos then
		burst(pos, Constants.TEAM_COLOR[a.team] or Color3.new(1, 1, 1))
	end
	a.shaft:Destroy()
	a.tracer:Destroy()
end

local function step(dt)
	local now = workspace:GetServerTimeNow()
	for key, a in live do
		local t = now - a.born
		if t > Constants.ARROW_LIFETIME + 0.5 then
			remove(key, nil)
		else
			local p = Formulas.arrowAt(a.origin, a.velocity, t)
			local v = Formulas.arrowVelocity(a.velocity, t)
			local dir = v.Magnitude > 0.01 and v.Unit or Vector3.new(0, 0, -1)
			a.shaft.CFrame = CFrame.lookAt(p, p + dir)
			-- the tracer: from a little behind the head back toward where it came from
			local back = math.min(TRACER, (p - a.origin).Magnitude)
			if back > 0.2 then
				local tail = p - dir * back
				a.tracer.Size = Vector3.new(0.1, 0.1, back)
				a.tracer.CFrame = CFrame.lookAt((p + tail) / 2, p)
			end
		end
	end
	for i = #shards, 1, -1 do
		local s = shards[i]
		if os.clock() > s.die then
			s.part:Destroy()
			table.remove(shards, i)
		else
			s.vel += Vector3.new(0, -60, 0) * dt
			s.part.CFrame = s.part.CFrame + s.vel * dt
		end
	end
end

function ArrowController:init()
	folder = Instance.new("Folder")
	folder.Name = "Arrows"
	folder.Parent = workspace
	Net.listen("Arrow", function(a)
		if a.by == player.UserId then
			byServer[a.id] = "me" .. tostring(a.shotId)
			if live[byServer[a.id]] then
				return -- (already drawn: the prediction)
			end
		end
		local key = "s" .. a.id
		byServer[a.id] = byServer[a.id] or key
		spawnArrow(byServer[a.id], a.origin, a.velocity, a.team, a.at or workspace:GetServerTimeNow())
	end)
	Net.listen("ArrowEnd", function(e)
		local key = byServer[e.id] or ("s" .. e.id)
		byServer[e.id] = nil
		remove(key, e.pos)
	end)
	RunService.RenderStepped:Connect(step)
end

-- (tests)
function ArrowController.count()
	local n = 0
	for _ in live do
		n += 1
	end
	return n
end

return ArrowController
