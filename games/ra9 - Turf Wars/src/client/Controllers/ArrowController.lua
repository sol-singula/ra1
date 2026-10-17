--[[
Arrows on screen (master plan §5, §0): every arrow the server announces is drawn along the same curve the server
flies it (Formulas.arrowAt from its origin and velocity, timed by server time), the way the store art draws them: a
white shaft with a sparkle at its tip, a bright white-hot core line and a wide soft glow in its team's colour behind
it that follows the arc, tapering and fading toward the tail (and on better graphics a wider haze, and a Trail for the
softest edge). The shooter's trail (the server sends what they wear) can add to it (Data/Cosmetics looks): lines
beside the tracer in white, black or the team's colours, dashed, spinning round it or glitching, a longer tracer,
afterimages of the shaft. Your own arrow is drawn the instant you let go (predicted) and the server's copy of it is
skipped. Where an arrow stops there's a pop of light, a ring and chips (Effects.impact) and a thunk from that spot;
an enemy arrow passing close by whooshes past you where it is. Fewer glow pieces on phones and low graphics, and when
a lot of arrows are up at once.

  ArrowController.predict(origin, velocity, team, shotId)   your own, right away
  ArrowController.replay(origin, velocity, team, trail)     an arrow you move yourself (the kill cam): -> key
  ArrowController.at(key, t)                                put it t seconds into its flight
  ArrowController.stop(key, pos?)                           take it away (an impact at pos)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Effects = require(script.Parent.Parent.FX.Effects)
local Store = require(script.Parent.Parent.Store)
local AudioController = require(script.Parent.AudioController)

local ArrowController = { Name = "ArrowController", Order = 20 }

local player = Players.LocalPlayer
local live = {} -- [key] = { shaft, tracer, glow, haze, tip, star, origin, velocity, born, team, ... }
local byServer = {} -- [serverId] = key
local folder
local TRACER = 14 -- studs of tracer behind the head
local DASHES = 5 -- the pieces of a dashed trail line
local FLYBY = 8 -- studs: an enemy arrow passing this close whooshes
local CROWD = 24 -- arrows up at once past which new ones get the light version
local WHITE = Color3.fromRGB(250, 250, 250)
local ALONG = CFrame.Angles(0, math.rad(90), 0) -- (a cylinder's X turned to lie along the flight)

-- the glow per graphics tier: { segments, width, transparency } for the glow and the haze, a halo at the tip (star),
-- a Trail
local LOOK = {
	high = { glow = { 9, 0.26, 0.04 }, haze = { 6, 0.6, 0.82 }, star = true, trail = true },
	mid = { glow = { 6, 0.26, 0.05 }, star = true, trail = true },
	low = { glow = { 3, 0.24, 0.05 }, star = false, trail = false },
	-- (the kill cam's replay, seen from a few studs away: slimmer)
	replay = { glow = { 8, 0.2, 0.05 }, haze = { 6, 0.5, 0.86 }, star = false, trail = true },
}

local function part(size, color, neon, shape)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Parent = folder
	return p
end

local function segments(spec, color, name)
	local list = {}
	for _ = 1, spec and spec[1] or 0 do
		-- (round: a cylinder, which runs along its X)
		local q = part(Vector3.new(1, spec[2], spec[2]), color, true, Enum.PartType.Cylinder)
		q.Name = name
		q.Transparency = 1
		table.insert(list, q)
	end
	return list
end

-- the softest edge, for Roblox's own renderer: a Trail off the shaft (the glow parts carry the shape)
local function addTrail(shaft, color)
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailTop"
	a0.Position = Vector3.new(0, 0.3, 0.9)
	a0.Parent = shaft
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailBottom"
	a1.Position = Vector3.new(0, -0.3, 0.9)
	a1.Parent = shaft
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(WHITE, color)
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.FaceCamera = true
	trail.Lifetime = 0.22
	trail.MinLength = 0.05
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.15) })
	trail.Parent = shaft
	return trail
end

local function spawnArrow(key, origin, velocity, team, born, trail, lookName)
	local color = Constants.TEAM_COLOR[team] or Color3.new(1, 1, 1)
	local crowd = ArrowController.count() >= CROWD
	local look = LOOK[lookName or (crowd and "low" or Effects.tier())] or LOOK.low
	local shaft = part(Vector3.new(0.18, 0.18, 2.6), WHITE, false)
	shaft.Name = "Shaft"
	-- the core: a thin white-hot line (the team's colour, mostly white), straight back from the tip
	local tracer = part(Vector3.new(0.08, 0.08, 1), color:Lerp(WHITE, 0.55), true)
	tracer.Name = "Tracer"
	tracer.Transparency = 0.05
	local glow = segments(look.glow, color, "Glow")
	local haze = segments(look.haze, color, "Haze")
	local tip = part(Vector3.new(0.3, 0.3, 0.3), WHITE, true, Enum.PartType.Ball)
	tip.Name = "Tip"
	local star
	if look.star then
		-- (a soft halo round the tip)
		star = part(Vector3.new(0.85, 0.85, 0.85), color:Lerp(WHITE, 0.25), true, Enum.PartType.Ball)
		star.Name = "Halo"
		star.Transparency = 0.62
	end
	if look.trail then
		addTrail(shaft, color)
	end
	-- the trail (what the shooter wears): its lines beside the tracer, each a part (a dashed one, a few short ones)
	local skin = Cosmetics.trailLook(trail) or {}
	local twins = {}
	for _, l in skin.lines or {} do
		local n = skin.dash and DASHES or 1
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
	for i = 1, skin.ghost or 0 do
		local g = part(Vector3.new(0.16, 0.16, 2.4), WHITE, false)
		g.Name = "Ghost"
		g.Transparency = 0.45 + i * 0.15
		table.insert(ghosts, g)
	end
	local lap = Cosmetics.lap((Cosmetics.get(trail) or {}).name)
	live[key] = {
		shaft = shaft,
		tracer = tracer,
		glow = glow,
		haze = haze,
		spec = look,
		tip = tip,
		star = star,
		twins = twins,
		ghosts = ghosts,
		look = skin,
		length = (skin.length or 1) * (1 + (lap - 1) * 0.25),
		origin = origin,
		velocity = velocity,
		born = born,
		team = team,
		mine = string.sub(key, 1, 2) == "me",
	}
	return live[key]
end

function ArrowController.predict(origin, velocity, team, shotId)
	local equipped = (Store.get("profile") or {}).equipped or {}
	return spawnArrow("me" .. tostring(shotId), origin, velocity, team, workspace:GetServerTimeNow(), equipped.trail)
end

local replays = 0
function ArrowController.replay(origin, velocity, team, trail)
	replays += 1
	local key = "replay" .. replays
	local a = spawnArrow(key, origin, velocity, team, 0, trail, "replay")
	a.manual, a.t, a.mine = true, 0, true
	return key
end

function ArrowController.at(key, t)
	local a = live[key]
	if a then
		a.t = t
	end
end

local function remove(key, pos, kind)
	local a = live[key]
	if not a then
		return
	end
	live[key] = nil
	if pos then
		local color = Constants.TEAM_COLOR[a.team] or Color3.new(1, 1, 1)
		local t = a.manual and a.t or (workspace:GetServerTimeNow() - a.born)
		Effects.impact(pos, color, Formulas.arrowVelocity(a.velocity, math.max(0, t)))
		if kind ~= "player" and kind ~= "parry" then
			AudioController.playAt("impact", pos, kind == "structure" and 0.9 or 1)
		end
	end
	a.shaft:Destroy()
	a.tracer:Destroy()
	a.tip:Destroy()
	if a.star then
		a.star:Destroy()
	end
	for _, list in { a.glow, a.haze, a.ghosts } do
		for _, q in list do
			q:Destroy()
		end
	end
	for _, tw in a.twins do
		for _, q in tw.parts do
			q:Destroy()
		end
	end
end

function ArrowController.stop(key, pos)
	remove(key, pos, "player")
end

-- the glow along the arc: segment i runs between the points (i-1)/n and i/n of the way back down the tracer,
-- narrower and fainter toward the tail
local function bend(a, list, spec, t, back, speed)
	local n = #list
	if n == 0 then
		return
	end
	local step = (back / n) / math.max(speed, 1)
	local prev = Formulas.arrowAt(a.origin, a.velocity, t)
	for i, q in list do
		local at = Formulas.arrowAt(a.origin, a.velocity, math.max(0, t - step * i))
		local len = (prev - at).Magnitude
		if len < 0.02 then
			q.Transparency = 1
		else
			local k = (i - 1) / math.max(1, n - 1)
			local w = spec[2] * (1 - 0.5 * k)
			q.Size = Vector3.new(len + w * 1.5, w, w)
			q.CFrame = CFrame.lookAt((prev + at) / 2, prev) * ALONG
			q.Transparency = spec[3] + (1 - spec[3]) * k ^ 1.4
		end
		prev = at
	end
end

local function flyby(a, from, to)
	if a.mine or a.whooshed then
		return
	end
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local eye = cam.CFrame.Position
	local seg = to - from
	local len2 = seg:Dot(seg)
	local k = len2 > 0 and math.clamp((eye - from):Dot(seg) / len2, 0, 1) or 0
	local near = from + seg * k
	if (near - eye).Magnitude < FLYBY then
		a.whooshed = true
		AudioController.playAt("flyby", near)
	end
end

local function step()
	local now = workspace:GetServerTimeNow()
	local clock = os.clock()
	for key, a in live do
		local t = a.manual and a.t or (now - a.born)
		if not a.manual and t > Constants.ARROW_LIFETIME + 0.5 then
			remove(key, nil)
		else
			local p = Formulas.arrowAt(a.origin, a.velocity, t)
			local v = Formulas.arrowVelocity(a.velocity, t)
			local dir = v.Magnitude > 0.01 and v.Unit or Vector3.new(0, 0, -1)
			a.shaft.CFrame = CFrame.lookAt(p, p + dir)
			-- the sparkle at the tip: it flickers, the star turns
			local tipAt = p + dir * 1.3
			local flick = 0.26 + math.abs(math.sin(clock * 41 + a.born)) * 0.16
			a.tip.Size = Vector3.new(flick, flick, flick)
			a.tip.CFrame = CFrame.new(tipAt)
			if a.star then
				local halo = flick * 2.6
				a.star.Size = Vector3.new(halo, halo, halo)
				a.star.CFrame = CFrame.new(tipAt)
			end
			if a.last then
				flyby(a, a.last, p)
			end
			a.last = p
			-- the tracer: from a little behind the head back toward where it came from
			local back = math.min(TRACER * a.length, (p - a.origin).Magnitude)
			if back > 0.2 then
				local tail = p - dir * back
				a.tracer.Size = Vector3.new(0.08, 0.08, back)
				a.tracer.CFrame = CFrame.lookAt((p + tail) / 2, p)
				bend(a, a.glow, a.spec.glow, t, back, v.Magnitude)
				bend(a, a.haze, a.spec.haze, t, back * 0.8, v.Magnitude)
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
		remove(key, e.pos, e.kind)
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

function ArrowController.glow(key)
	local a = live[key]
	return a and #a.glow + #a.haze or 0
end

return ArrowController
