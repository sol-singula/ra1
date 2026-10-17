--[[
Arrows on screen (master plan §5, §0): every arrow the server announces is drawn along the same curve the server
flies it (Formulas.arrowAt from its origin and velocity, timed by server time), the way the store art draws them: a
white shaft with a sparkle at its tip, a bright white-hot core line and a wide soft glow in its team's colour behind
it that follows the arc, tapering and fading toward the tail (and on better graphics a wider haze, and a Trail for the
softest edge). The shooter's trail (the server sends what they wear) makes it its own (Data/Cosmetics looks): lines
beside the tracer (whole, dashed, dotted, a barcode, crystals, wound round it in a helix, meeting at the tip, waving,
glitching in a colour split), a soft ribbon streaming off it (flat and twisting, rainbow, ink...), a lightning bolt
re-jagged along it, flames off the head, ghostly afterimages in a wisp of smoke, rings of energy, a glow, and what
falls off it (FX/Flair: feathers, bubbles, ink drips, pixels, ice shards, gold glints, hearts...). Your own shots
draw their trail a little bolder, so it reads from right behind the bow; the ribbon fades out where the arrow
lands. Your own arrow is drawn the instant you let go (predicted) and the server's copy of it is
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
local Flair = require(script.Parent.Parent.FX.Flair)
local Store = require(script.Parent.Parent.Store)
local AudioController = require(script.Parent.AudioController)

local ArrowController = { Name = "ArrowController", Order = 20 }

local player = Players.LocalPlayer
local live = {} -- [key] = { shaft, tracer, glow, haze, tip, star, origin, velocity, born, team, ... }
local byServer = {} -- [serverId] = key
local folder
local TRACER = 14 -- studs of tracer behind the head
local DASHES = 5 -- the pieces of a dashed trail line
local BARS = 9 -- ...of a barcode
local HELIX = 8 -- ...of a line wound in a helix
local BOLT = 6 -- the pieces of a lightning trail's bolt
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

-- A trail look's ribbon: { width, token, life (s), taper (the tail's width, 0..1), alpha (the head's), twist }. Your
-- own shots get it a little wider and longer, so it reads from right behind the bow.
local function rainbowSeq(off)
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHSV(off % 1, 0.8, 1)),
		ColorSequenceKeypoint.new(0.33, Color3.fromHSV((off + 0.2) % 1, 0.8, 1)),
		ColorSequenceKeypoint.new(0.66, Color3.fromHSV((off + 0.4) % 1, 0.8, 1)),
		ColorSequenceKeypoint.new(1, Color3.fromHSV((off + 0.6) % 1, 0.8, 1)),
	})
end
local function addRibbon(shaft, spec, team, mine)
	local w = (spec[1] or 0.3) * (mine and 1.25 or 1)
	local a0 = Instance.new("Attachment")
	a0.Name = "RibbonA"
	a0.Position = Vector3.new(w / 2, 0, 0.8)
	a0.Parent = shaft
	local a1 = Instance.new("Attachment")
	a1.Name = "RibbonB"
	a1.Position = Vector3.new(-w / 2, 0, 0.8)
	a1.Parent = shaft
	local r = Instance.new("Trail")
	r.Name = "Ribbon"
	r.Attachment0 = a0
	r.Attachment1 = a1
	local token = spec[2] or "white"
	if token == "rainbow" then
		r.Color = rainbowSeq(0)
	else
		local c = Cosmetics.color(token, team)
		r.Color = ColorSequence.new(c:Lerp(WHITE, 0.35), c)
	end
	r.LightEmission = token == "ink" and 0 or 0.9
	r.LightInfluence = token == "ink" and 1 or 0
	r.FaceCamera = not spec[6]
	r.Lifetime = (spec[3] or 0.25) * (mine and 1.2 or 1)
	r.MinLength = 0.05
	r.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, spec[5] or 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	r.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, spec[4] or 0.1),
	})
	r.Parent = shaft
	return { trail = r, a0 = a0, a1 = a1, w = w, token = token, twist = spec[6], at = 0 }
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
	-- the trail (what the shooter wears): its lines beside the tracer, each a part, or in pieces (dashes, dots, bars,
	-- crystals, or wound round it in a helix)
	local skin = Cosmetics.trailLook(trail) or {}
	local mine = string.sub(key, 1, 2) == "me" or lookName == "replay"
	local lite = crowd or Effects.tier() == "low"
	local wide = mine and 1.5 or 1 -- (your own: a little bolder, so it reads from right behind the bow)
	local twins = {}
	for li, l in skin.lines or {} do
		local n = skin.helix and HELIX or (skin.dash and (skin.bars and BARS or DASHES) or 1)
		local parts = {}
		for i = 1, n do
			local shape = skin.dots and Enum.PartType.Ball or nil
			local line = part(Vector3.new(l[3] * wide, l[3] * wide, 1), Cosmetics.color(l[4], team), true, shape)
			line.Name = skin.dots and "Dot" or (skin.bars and "Bar" or (skin.crystal and "Crystal" or "Twin"))
			line.Transparency = 0.1
			if skin.bars then
				-- (a barcode: bars across the line, of a few widths)
				line.Size = Vector3.new(0.55 * wide, l[3] * wide, 0.05 + ((i * 7 + li) % 4) * 0.05)
			end
			table.insert(parts, line)
		end
		table.insert(twins, {
			parts = parts,
			x = l[1],
			y = l[2],
			w = l[3] * wide,
			part = parts[1],
			token = l[4],
			r = math.sqrt(l[1] * l[1] + l[2] * l[2]),
			a = math.atan2(l[2], l[1]),
			jx = 0,
			jy = 0,
		})
	end
	-- a soft ribbon behind it (a Trail: cheap, and the part of a trail you see best from behind your own shot)
	local ribbon
	if skin.ribbon then
		ribbon = addRibbon(shaft, skin.ribbon, team, mine)
	end
	-- what falls off the arrow as it flies (FX/Flair): an emitter on the shaft, or loose bits dropped behind it
	local drops
	if skin.particles and not crowd then
		if not Flair.emitter(shaft, skin.particles) then
			drops = skin.particles
		end
	end
	if skin.fire and not crowd then
		local e = Flair.emitter(shaft, "fire")
		if e then
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0.1) })
			e.Speed = NumberRange.new(0.5, 1.5)
			e.Acceleration = Vector3.zero
			e.Lifetime = NumberRange.new(0.15, 0.3)
			e.Rate = lite and 18 or 40
		end
	end
	if skin.wisp and not crowd then
		Flair.emitter(shaft, "wisp")
	end
	local light
	if skin.light and not lite then
		light = Instance.new("PointLight")
		light.Name = "TrailLight"
		light.Color = Flair.tint(skin.light, team, 0, 0)
		light.Range = 9
		light.Brightness = 1.6
		light.Shadows = false
		light.Parent = shaft
	end
	local bolt
	if skin.bolt then
		-- (a jagged bolt along the tracer, re-jagged every few frames: its pieces made once, moved after)
		bolt = { parts = {}, off = {}, at = 0 }
		for i = 1, lite and 4 or BOLT do
			local q = part(Vector3.new(0.09, 0.09, 1), Color3.fromRGB(200, 235, 255), true)
			q.Name = "Bolt"
			bolt.parts[i] = q
			bolt.off[i] = Vector2.zero
		end
	end
	local ghosts = {}
	for i = 1, skin.ghost or 0 do
		local g = part(
			Vector3.new(0.16, 0.16, 2.4),
			skin.ghostColor and Cosmetics.color(skin.ghostColor, team) or WHITE,
			skin.ghostColor == "ice"
		)
		g.Name = "Ghost"
		g.Transparency = 0.45 + i * 0.15
		table.insert(ghosts, g)
	end
	local lap = Cosmetics.lap((Cosmetics.get(trail) or {}).name)
	live[key] = {
		ribbon = ribbon,
		light = light,
		bolt = bolt,
		ringAt = 0,
		snapAt = 0,
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
		drops = drops,
		dropAt = 0,
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
	if a.ribbon then
		-- (the ribbon fades out where it is rather than vanishing with the arrow: the shaft hides and goes after)
		local shaft = a.shaft
		shaft.Transparency = 1
		a.ribbon.trail.Enabled = false
		for _, d in shaft:GetChildren() do
			if d:IsA("ParticleEmitter") then
				d.Enabled = false
			elseif d:IsA("PointLight") then
				d:Destroy()
			end
		end
		task.delay(a.ribbon.trail.Lifetime + 0.1, function()
			shaft:Destroy()
		end)
	else
		a.shaft:Destroy()
	end
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
	if a.bolt then
		for _, q in a.bolt.parts do
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

-- How often the loose bits fall off (seconds; slower on a phone)
local DROP_EVERY = { glints = 0.09, ink = 0.06, hearts = 0.06, pixels = 0.045 }

-- The trail's own pieces, this frame (nothing is made here but the loose bits FX/Flair drops)
local function drawTrail(a, p, dir, tail, back, t, clock)
	local look = a.look
	local tcf = a.tracer.CFrame
	local zap = look.anim == "electric"
	local pulse = look.pulse and (1 + 0.6 * math.sin(t * look.pulse)) or 1
	if look.pulse then
		a.tracer.Size = Vector3.new(0.08 * pulse, 0.08 * pulse, back)
	end
	local spinRate = look.spin == true and 14 or (look.spin or 0)
	local spin = (spinRate ~= 0 and not look.helix) and CFrame.Angles(0, 0, t * spinRate) or nil
	if look.rgb and clock >= a.snapAt then
		-- (a glitch: the colour split snaps to a new offset now and then, not every frame)
		a.snapAt = clock + 0.07
		for _, tw in a.twins do
			tw.jx, tw.jy = (math.random() - 0.5) * 0.4, (math.random() - 0.5) * 0.3
		end
	end
	for ti, tw in a.twins do
		local x, y = tw.x + tw.jx, tw.y + tw.jy
		if look.jitter then
			x += (math.random() - 0.5) * 0.16
			y += (math.random() - 0.5) * 0.16
		end
		if look.wobble then
			x += math.cos(t * 7 + ti) * 0.08
			y += math.sin(t * 9 + ti * 2) * 0.16
		end
		-- (a colour that moves: a rainbow running down the line, lightning flickering)
		local moving = Flair.moving(tw.token)
		local n = #tw.parts
		local seg = back / n
		local w = tw.w * pulse
		local shift = look.march and (t * look.march) % seg or 0
		for i, q in tw.parts do
			if look.converge then
				-- (from out wide at the tail to the tip)
				local head = tcf * Vector3.new(0, 0, -back / 2)
				local from = tcf * Vector3.new(x * 2, y * 2, back / 2)
				q.Size = Vector3.new(w, w, (head - from).Magnitude)
				q.CFrame = CFrame.lookAt((head + from) / 2, head)
			elseif n == 1 then
				q.Size = Vector3.new(w, w, back)
				q.CFrame = spin and tcf * spin * CFrame.new(x, y, 0) or tcf * CFrame.new(x, y, 0)
			else
				-- (in pieces: each half its share of the length with the gaps between, sliding back if it marches)
				local along = back / 2 - seg * (i - 0.5) - shift
				if along < -back / 2 then
					along += back
				end
				local px, py = x, y
				if look.helix then
					local ang = tw.a + t * spinRate + (i - 0.5) / n * look.helix * math.pi * 2
					px, py = math.cos(ang) * tw.r, math.sin(ang) * tw.r
				end
				local at = CFrame.new(px, py, -along)
				if look.dots then
					q.Size = Vector3.new(w, w, w)
				elseif look.crystal then
					q.Size = Vector3.new(w, w, seg * 0.35)
					at *= CFrame.Angles(0, 0, math.pi / 4)
				elseif not look.bars then
					q.Size = Vector3.new(w, w, math.max(0.05, look.helix and seg * 0.9 or seg * 0.5))
				end
				q.CFrame = spin and tcf * spin * at or tcf * at
			end
			if moving then
				q.Color = Flair.tint(tw.token, a.team, clock, i * 0.12 + ti * 0.3)
			end
			if look.flicker then
				q.Transparency = math.random() < 0.22 and 0.85 or 0.1
			end
		end
	end
	if zap and math.random() < 0.25 then
		Flair.arc(tail, tail:Lerp(p, math.random()), Color3.fromRGB(170, 220, 255))
	end
	local bolt = a.bolt
	if bolt then
		-- (re-jagged every few frames; laid along the tracer every frame so it keeps up with the arrow)
		local m = #bolt.parts
		if clock >= bolt.at then
			bolt.at = clock + 0.045
			for i = 1, m do
				bolt.off[i] = Vector2.new((math.random() - 0.5) * 0.8, (math.random() - 0.5) * 0.8)
			end
		end
		local prev = tcf * Vector3.new(0, 0, -back / 2)
		for i, q in bolt.parts do
			local o = bolt.off[i]
			local nextP = tcf * Vector3.new(o.X, o.Y, -back / 2 + back * i / m)
			q.Size = Vector3.new(0.09, 0.09, (nextP - prev).Magnitude + 0.05)
			q.CFrame = CFrame.lookAt((prev + nextP) / 2, nextP)
			q.Transparency = math.random() < 0.15 and 0.7 or 0
			prev = nextP
		end
	end
	local ribbon = a.ribbon
	if ribbon then
		if ribbon.twist then
			local ang = t * 9
			local c, s = math.cos(ang) * ribbon.w / 2, math.sin(ang) * ribbon.w / 2
			ribbon.a0.Position = Vector3.new(c, s, 0.8)
			ribbon.a1.Position = Vector3.new(-c, -s, 0.8)
		end
		if Flair.moving(ribbon.token) and clock >= ribbon.at then
			ribbon.at = clock + 0.08
			if ribbon.token == "rainbow" then
				ribbon.trail.Color = rainbowSeq(clock * 0.6)
			else
				local c = Flair.tint(ribbon.token, a.team, clock, 0)
				ribbon.trail.Color = ColorSequence.new(c:Lerp(WHITE, 0.35), c)
			end
		end
	end
	if a.light then
		if Flair.moving(look.light) then
			a.light.Color = Flair.tint(look.light, a.team, clock, 0)
		end
		a.light.Brightness = zap and (math.random() < 0.2 and 3.5 or 1.2) or 1.6 * pulse
	end
	if look.rings and clock >= a.ringAt then
		a.ringAt = clock + look.rings * (Flair.lite() and 2.5 or 1)
		Flair.drop("ring", p - dir * 0.8, a.team, dir)
	end
	if a.drops and clock >= a.dropAt then
		a.dropAt = clock + (DROP_EVERY[a.drops] or 0.035) * (Flair.lite() and 2.3 or 1)
		Flair.drop(a.drops, p - dir * math.min(back, 1.5 + math.random() * 2), a.team)
	end
	local ghosts = a.ghosts
	if #ghosts > 0 then
		local side = dir:Cross(Vector3.yAxis)
		side = side.Magnitude > 0.01 and side.Unit or Vector3.xAxis
		for i, g in ghosts do
			local at = p - dir * (i * 1.6)
			if look.wave then
				-- (ghostly: they drift and sway behind it, flickering)
				at += side * math.sin(t * 6 + i * 1.7) * 0.35 + Vector3.yAxis * math.cos(t * 5 + i) * 0.2
				g.Transparency = 0.4 + i * 0.15 + math.random() * 0.1
			end
			g.CFrame = CFrame.lookAt(at, at + dir)
		end
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
				drawTrail(a, p, dir, tail, back, t, clock)
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
				if not a.assisted then
					return -- (already drawn: the prediction)
				end
				remove(byServer[a.id]) -- (the server's aim help turned it: draw where it really flies)
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

-- What an arrow's trail is drawn with, as a line of text (tests: every trail looks like itself), and its pieces
function ArrowController.describe(key)
	local a = live[key]
	if not a then
		return nil
	end
	local out, pieces = {}, {}
	for _, tw in a.twins do
		table.insert(out, `{tw.part.Name}x{#tw.parts}@{tw.token}/{tw.w}`)
		for _, q in tw.parts do
			table.insert(pieces, q)
		end
	end
	if a.ribbon then
		table.insert(
			out,
			`ribbon:{a.ribbon.token}/{a.ribbon.w}/{a.ribbon.trail.Lifetime}{a.ribbon.twist and "~" or ""}`
		)
	end
	if a.bolt then
		table.insert(out, `bolt{#a.bolt.parts}`)
		for _, q in a.bolt.parts do
			table.insert(pieces, q)
		end
	end
	if #a.ghosts > 0 then
		table.insert(out, `ghosts{#a.ghosts}:{a.look.ghostColor or "white"}`)
	end
	for _, d in a.shaft:GetChildren() do
		if d:IsA("ParticleEmitter") or d:IsA("PointLight") then
			table.insert(out, d.Name)
		end
	end
	table.insert(out, `len{a.length}`)
	for _, k in { "drops", "dash", "dots", "bars", "crystal", "helix", "spin", "converge", "wobble", "flicker" } do
		if a[k] or a.look[k] then
			table.insert(out, k .. tostring(a[k] or a.look[k]))
		end
	end
	for _, k in { "jitter", "rgb", "pulse", "march", "rings", "wave" } do
		if a.look[k] then
			table.insert(out, k .. tostring(a.look[k]))
		end
	end
	return table.concat(out, " "), pieces
end

function ArrowController.glow(key)
	local a = live[key]
	return a and #a.glow + #a.haze or 0
end

return ArrowController
