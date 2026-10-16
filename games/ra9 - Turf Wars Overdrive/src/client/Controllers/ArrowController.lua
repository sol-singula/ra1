--[[
Arrows on screen (master plan §5, §0): every arrow the server announces is drawn along the same curve the server
flies it (Formulas.arrowAt from its origin and velocity, timed by server time), as a white shaft with a long thin
tracer in its team's colour behind it: the SUPERHOT red line. The shooter's trail (the server sends what they wear)
can add to it (Data/Cosmetics looks): lines beside the tracer in white, black or the team's colours, dashed,
spinning round it or glitching, a longer tracer, afterimages of the shaft. Your own arrow is drawn the instant you let go
(predicted) and the server's copy of it is skipped. Where an arrow stops, a few white shards burst out.

  ArrowController.predict(origin, velocity, team, shotId)   your own, right away
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Store = require(script.Parent.Parent.Store)

local ArrowController = { Name = "ArrowController", Order = 20 }

local player = Players.LocalPlayer
local live = {} -- [key] = { shaft, tracer, origin, velocity, born, team, stopAt? }
local byServer = {} -- [serverId] = key
local folder
local TRACER = 14 -- studs of tracer behind the head
local DASHES = 5 -- the pieces of a dashed trail line
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

local function spawnArrow(key, origin, velocity, team, born, trail)
	local color = Constants.TEAM_COLOR[team] or Color3.new(1, 1, 1)
	local shaft = part(Vector3.new(0.18, 0.18, 2.6), Color3.fromRGB(250, 250, 250), false)
	local tracer = part(Vector3.new(0.1, 0.1, 1), color, true)
	tracer.Transparency = 0.15
	-- the trail (what the shooter wears): its lines beside the tracer, each a part (a dashed one, a few short ones)
	local look = Cosmetics.trailLook(trail) or {}
	local twins = {}
	for _, l in look.lines or {} do
		local n = look.dash and DASHES or 1
		local parts = {}
		for _ = 1, n do
			local line = part(Vector3.new(l[3], l[3], 1), Cosmetics.color(l[4], team), true)
			line.Name = "Twin"
			line.Transparency = 0.1
			table.insert(parts, line)
		end
		table.insert(twins, { parts = parts, x = l[1], y = l[2], w = l[3], part = parts[1] })
	end
	local ghosts = {}
	for i = 1, look.ghost or 0 do
		local g = part(Vector3.new(0.16, 0.16, 2.4), Color3.fromRGB(250, 250, 250), false)
		g.Name = "Ghost"
		g.Transparency = 0.45 + i * 0.15
		table.insert(ghosts, g)
	end
	local lap = Cosmetics.lap((Cosmetics.get(trail) or {}).name)
	live[key] = {
		shaft = shaft,
		tracer = tracer,
		twins = twins,
		ghosts = ghosts,
		look = look,
		length = (look.length or 1) * (1 + (lap - 1) * 0.25),
		origin = origin,
		velocity = velocity,
		born = born,
		team = team,
	}
	return live[key]
end

function ArrowController.predict(origin, velocity, team, shotId)
	local equipped = (Store.get("profile") or {}).equipped or {}
	return spawnArrow("me" .. tostring(shotId), origin, velocity, team, workspace:GetServerTimeNow(), equipped.trail)
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
	for _, t in a.twins do
		for _, q in t.parts do
			q:Destroy()
		end
	end
	for _, g in a.ghosts do
		g:Destroy()
	end
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
			local back = math.min(TRACER * a.length, (p - a.origin).Magnitude)
			if back > 0.2 then
				local tail = p - dir * back
				a.tracer.Size = Vector3.new(0.1, 0.1, back)
				a.tracer.CFrame = CFrame.lookAt((p + tail) / 2, p)
				local spin = a.look.spin and CFrame.Angles(0, 0, t * 14) or CFrame.new()
				for _, tw in a.twins do
					local x, y = tw.x, tw.y
					if a.look.jitter then
						x += (math.random() - 0.5) * 0.16
						y += (math.random() - 0.5) * 0.16
					end
					local n = #tw.parts
					local seg = back / n
					for i, q in tw.parts do
						-- (dashed: each piece half its share of the length, the gaps between)
						local len = n > 1 and seg * 0.5 or back
						local along = n > 1 and (back / 2 - seg * (i - 0.5)) or 0
						q.Size = Vector3.new(tw.w, tw.w, math.max(0.05, len))
						q.CFrame = a.tracer.CFrame * spin * CFrame.new(x, y, -along)
					end
				end
				for i, g in a.ghosts do
					local at = p - dir * (i * 1.6)
					g.CFrame = CFrame.lookAt(at, at + dir)
				end
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
		spawnArrow(byServer[a.id], a.origin, a.velocity, a.team, a.at or workspace:GetServerTimeNow(), a.trail)
	end)
	Net.listen("ArrowEnd", function(e)
		local key = byServer[e.id] or ("s" .. e.id)
		byServer[e.id] = nil
		remove(key, e.pos)
	end)
	RunService.RenderStepped:Connect(step)
end

-- (tests)
function ArrowController.twins()
	local n = 0
	for _, a in live do
		n += #a.twins + #a.ghosts
	end
	return n
end

function ArrowController.count()
	local n = 0
	for _ in live do
		n += 1
	end
	return n
end

return ArrowController
