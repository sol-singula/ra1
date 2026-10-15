--[[
What the creatures look like (master plan §9: readable, a little cute, each one its own shape), built from plain
parts so nothing needs uploading. Rigs.build(kind, parent) -> model (PrimaryPart "Body"; legs, fins and jaws
named for Rigs.animate, which bobs, paddles and snaps them from the creature's state each frame on the client).
]]
local Kit = require(script.Parent.Kit)

local Rigs = {}

local C, M = Kit.C, Kit.M
local V3 = Vector3.new

local function p(m, name, cf, size, color, material, extra)
	local e = { CanCollide = false, CanQuery = false, CanTouch = false, Anchored = true, CastShadow = true }
	for k, v in extra or {} do
		e[k] = v
	end
	return Kit.box(m, name, cf, size, color, material or M.SmoothPlastic, e)
end

local function ball(m, name, pos, d, color, material)
	return Kit.ball(
		m,
		name,
		pos,
		d,
		color,
		material or M.SmoothPlastic,
		{ CanCollide = false, CanQuery = false, CanTouch = false }
	)
end

local function eyes(m, cf, spread, y, z, size, color)
	for _, sx in { -1, 1 } do
		local e = ball(m, "Eye", (cf * CFrame.new(sx * spread, y, z)).Position, size, C.white)
		ball(m, "Pupil", (cf * CFrame.new(sx * spread, y, z - size * 0.35)).Position, size * 0.5, color or C.ink)
		_ = e
	end
end

local build = {}

function build.reef_crab(m)
	local cf = CFrame.new()
	p(m, "Body", cf * CFrame.new(0, 1, 0), V3(3, 1.2, 2.2), Color3.fromRGB(225, 90, 60))
	eyes(m, cf, 0.6, 1.9, -0.8, 0.45)
	for _, sx in { -1, 1 } do
		p(m, "Claw", cf * CFrame.new(sx * 2, 0.9, -1.2), V3(1.1, 0.8, 1.3), Color3.fromRGB(240, 110, 70))
		for k = -1, 1 do
			p(m, "Leg", cf * CFrame.new(sx * 1.9, 0.5, k * 0.7), V3(1.2, 0.3, 0.3), Color3.fromRGB(200, 70, 50))
		end
	end
end

function build.gull(m)
	local cf = CFrame.new()
	p(m, "Body", cf * CFrame.new(0, 2, 0), V3(1.2, 1, 2.2), C.white)
	ball(m, "Head", V3(0, 2.6, -1.2), 0.9, C.white)
	p(m, "Beak", cf * CFrame.new(0, 2.5, -1.8), V3(0.3, 0.25, 0.7), Color3.fromRGB(255, 170, 40))
	for _, sx in { -1, 1 } do
		p(m, "Wing", cf * CFrame.new(sx * 1.4, 2.2, 0), V3(2.4, 0.15, 1.2), Color3.fromRGB(200, 200, 205))
	end
	eyes(m, cf, 0.3, 2.7, -1.5, 0.22)
end

function build.mire_lurker(m)
	local cf = CFrame.new()
	p(m, "Body", cf * CFrame.new(0, 1.3, 0), V3(3.2, 2, 3.6), Color3.fromRGB(70, 110, 60))
	ball(m, "Head", V3(0, 2.4, -1.8), 2, Color3.fromRGB(80, 125, 65))
	eyes(m, cf, 0.6, 3.1, -2.4, 0.6, Color3.fromRGB(240, 200, 40))
	for _, sx in { -1, 1 } do
		p(m, "Leg", cf * CFrame.new(sx * 1.9, 0.7, 0.8), V3(0.8, 1.4, 1.2), Color3.fromRGB(60, 95, 50))
		p(m, "Arm", cf * CFrame.new(sx * 1.9, 1.4, -1), V3(0.6, 1.6, 0.6), Color3.fromRGB(60, 95, 50))
	end
	p(m, "Tongue", cf * CFrame.new(0, 2.1, -2.9), V3(0.3, 0.15, 1), Color3.fromRGB(230, 90, 110))
end

function build.lava_beetle(m)
	local cf = CFrame.new()
	p(m, "Body", cf * CFrame.new(0, 1, 0), V3(2.4, 1.4, 3.2), Color3.fromRGB(50, 40, 40))
	local glow = p(m, "Glow", cf * CFrame.new(0, 1.2, 0.3), V3(1.6, 0.4, 2.2), Color3.fromRGB(255, 120, 40), M.Neon)
	Kit.light(glow, "PointLight", { Name = "Glow", Color = Color3.fromRGB(255, 120, 40), Range = 8, Brightness = 1 })
	for _, sx in { -1, 1 } do
		for k = -1, 1 do
			p(m, "Leg", cf * CFrame.new(sx * 1.5, 0.4, k * 0.9), V3(0.9, 0.25, 0.25), Color3.fromRGB(40, 30, 30))
		end
	end
	p(m, "Horn", cf * CFrame.new(0, 1.9, -1.4), V3(0.3, 0.8, 0.6), Color3.fromRGB(40, 30, 30))
end

function build.frost_wolf(m)
	local cf = CFrame.new()
	p(m, "Body", cf * CFrame.new(0, 2, 0), V3(1.8, 1.6, 4), Color3.fromRGB(215, 225, 235))
	p(m, "Head", cf * CFrame.new(0, 2.6, -2.5), V3(1.3, 1.2, 1.6), Color3.fromRGB(225, 232, 240))
	p(m, "Snout", cf * CFrame.new(0, 2.3, -3.5), V3(0.7, 0.6, 0.8), Color3.fromRGB(190, 200, 210))
	for _, sx in { -1, 1 } do
		p(m, "Ear", cf * CFrame.new(sx * 0.45, 3.4, -2.4), V3(0.3, 0.6, 0.3), Color3.fromRGB(200, 210, 220))
		p(m, "LegF", cf * CFrame.new(sx * 0.6, 0.8, -1.3), V3(0.5, 1.6, 0.5), Color3.fromRGB(200, 210, 220))
		p(m, "LegB", cf * CFrame.new(sx * 0.6, 0.8, 1.3), V3(0.5, 1.6, 0.5), Color3.fromRGB(200, 210, 220))
	end
	p(
		m,
		"Tail",
		cf * CFrame.new(0, 2.4, 2.4) * CFrame.Angles(0.5, 0, 0),
		V3(0.4, 0.4, 1.4),
		Color3.fromRGB(200, 210, 220)
	)
	eyes(m, cf, 0.35, 2.8, -3.2, 0.3, Color3.fromRGB(120, 200, 255))
end

function build.ruin_guardian(m)
	local cf = CFrame.new()
	p(m, "Body", cf * CFrame.new(0, 4, 0), V3(4.4, 4, 2.8), C.rockDark, M.Slate)
	p(m, "Head", cf * CFrame.new(0, 7, 0), V3(2.4, 2, 2.2), C.rock, M.Slate)
	local eye = p(m, "EyeGlow", cf * CFrame.new(0, 7, -1.15), V3(1.6, 0.4, 0.2), Color3.fromRGB(120, 255, 200), M.Neon)
	Kit.light(eye, "PointLight", { Name = "Glow", Color = Color3.fromRGB(120, 255, 200), Range = 10, Brightness = 1 })
	for _, sx in { -1, 1 } do
		p(m, "Arm", cf * CFrame.new(sx * 3.2, 3.8, 0), V3(1.6, 4.4, 1.6), C.rock, M.Slate)
		p(m, "Leg", cf * CFrame.new(sx * 1.2, 1, 0), V3(1.6, 2, 1.8), C.rockDark, M.Slate)
	end
	p(m, "Moss", cf * CFrame.new(0.8, 6.1, -0.2), V3(2, 0.3, 2.2), C.rockMoss, M.Grass)
end

function build.shark(m)
	local cf = CFrame.new()
	p(m, "Body", cf * CFrame.new(0, 0, 0), V3(2.2, 2, 8), Color3.fromRGB(95, 110, 130))
	p(m, "Belly", cf * CFrame.new(0, -0.7, 0), V3(1.8, 0.8, 6), Color3.fromRGB(220, 225, 230))
	p(m, "Fin", cf * CFrame.new(0, 1.9, 0.5), V3(0.3, 1.8, 2.2), Color3.fromRGB(80, 95, 115))
	p(m, "Tail", cf * CFrame.new(0, 0.3, 4.6), V3(0.3, 2.6, 1.6), Color3.fromRGB(80, 95, 115))
	p(m, "Jaw", cf * CFrame.new(0, -0.5, -3.6), V3(1.6, 0.6, 1.4), Color3.fromRGB(220, 225, 230))
	for k = -2, 2 do
		p(m, "Tooth", cf * CFrame.new(k * 0.35, -0.1, -4.2), V3(0.2, 0.4, 0.2), C.white)
	end
	for _, sx in { -1, 1 } do
		p(
			m,
			"Side",
			cf * CFrame.new(sx * 1.5, -0.3, -0.5) * CFrame.Angles(0, 0, sx * 0.4),
			V3(1.6, 0.2, 1.4),
			Color3.fromRGB(80, 95, 115)
		)
	end
	eyes(m, cf, 0.9, 0.5, -3.2, 0.4)
end

function build.sea_serpent(m)
	local cf = CFrame.new()
	p(m, "Body", cf * CFrame.new(0, 0, 0), V3(2.6, 2.6, 5), Color3.fromRGB(40, 120, 110))
	p(m, "Head", cf * CFrame.new(0, 1.5, -3.6), V3(2.4, 2.2, 3), Color3.fromRGB(45, 135, 120))
	p(m, "Jaw", cf * CFrame.new(0, 0.3, -4.4), V3(2, 0.6, 2), Color3.fromRGB(230, 220, 190))
	for i = 1, 4 do
		p(
			m,
			"Coil",
			cf * CFrame.new(0, -0.4 * i, 3 + i * 2.4),
			V3(2.2 - i * 0.3, 2.2 - i * 0.3, 2.4),
			Color3.fromRGB(40, 120 - i * 8, 110)
		)
	end
	for i = 0, 5 do
		p(
			m,
			"Spine",
			cf * CFrame.new(0, 1.6, -1.5 + i * 1.6),
			V3(0.3, 1 + (i % 2) * 0.4, 0.6),
			Color3.fromRGB(230, 150, 60)
		)
	end
	eyes(m, cf, 0.8, 2.2, -4.5, 0.5, Color3.fromRGB(255, 220, 80))
end

function build.leviathan(m)
	local cf = CFrame.new()
	p(m, "Body", cf * CFrame.new(0, 0, 0), V3(8, 7, 20), Color3.fromRGB(30, 50, 70))
	p(m, "Head", cf * CFrame.new(0, 2, -13), V3(7.5, 6, 8), Color3.fromRGB(35, 60, 85))
	p(m, "Jaw", cf * CFrame.new(0, -1.6, -15), V3(6.5, 1.6, 6), Color3.fromRGB(210, 200, 180))
	for k = -3, 3 do
		p(m, "Tooth", cf * CFrame.new(k * 0.9, -0.4, -17.2), V3(0.5, 1.6, 0.5), C.white)
	end
	for i = 0, 7 do
		p(
			m,
			"Spine",
			cf * CFrame.new(0, 4, -8 + i * 2.6),
			V3(0.8, 2.4 + (i % 2) * 1.2, 1.2),
			Color3.fromRGB(230, 170, 60)
		)
	end
	for i = 1, 3 do
		p(
			m,
			"Tail",
			cf * CFrame.new(0, -0.5 * i, 10 + i * 5),
			V3(7 - i * 1.6, 6 - i * 1.4, 5),
			Color3.fromRGB(30, 50 - i * 5, 70)
		)
	end
	for _, sx in { -1, 1 } do
		p(
			m,
			"Fin",
			cf * CFrame.new(sx * 5.5, -1, -3) * CFrame.Angles(0, 0, sx * 0.5),
			V3(5, 0.6, 4),
			Color3.fromRGB(35, 60, 85)
		)
	end
	local glow = p(m, "EyeGlow", cf * CFrame.new(0, 3.5, -16.5), V3(5, 0.8, 0.4), Color3.fromRGB(255, 200, 60), M.Neon)
	Kit.light(glow, "PointLight", { Name = "Glow", Color = Color3.fromRGB(255, 200, 60), Range = 24, Brightness = 1.5 })
	eyes(m, cf, 2.6, 3.6, -16, 1.3, Color3.fromRGB(255, 150, 40))
end

function Rigs.build(kind, parent)
	local m = Instance.new("Model")
	m.Name = kind
	local fn = build[kind]
	if fn then
		fn(m)
	else
		p(m, "Body", CFrame.new(0, 1, 0), V3(2, 2, 2), C.rock)
	end
	-- the body is the pivot; everything else keeps its offset from it
	local body = m:FindFirstChild("Body")
	m.PrimaryPart = body
	local rec = {}
	for _, d in m:GetChildren() do
		if d:IsA("BasePart") then
			rec[d] = body.CFrame:ToObjectSpace(d.CFrame)
		end
	end
	m:SetAttribute("Kind", kind)
	m.Parent = parent
	return m, rec
end

-- Move a rig to a CFrame and animate its parts from the state: legs swing while it moves, jaws open for a tell,
-- fins paddle, wings flap, a surfaced sea creature rears up.
function Rigs.place(model, offsets, cf, state, clock, moving)
	local body = model.PrimaryPart
	if not body then
		return
	end
	local kind = model:GetAttribute("Kind")
	local bob = 0
	if kind == "gull" then
		bob = math.sin(clock * 6) * 0.4 + 3
	elseif kind == "shark" or kind == "sea_serpent" or kind == "leviathan" then
		bob = math.sin(clock * 1.5) * 0.3
	elseif moving then
		bob = math.abs(math.sin(clock * 9)) * 0.25
	end
	local tell = state == "tell" and (0.5 + math.sin(clock * 20) * 0.1) or 0
	local base = cf
		* CFrame.new(0, bob, 0)
		* CFrame.Angles(state == "surface" and -0.35 or (tell > 0 and -0.15 or 0), 0, 0)
	for part, off in offsets do
		if not part.Parent then
			continue
		end
		local name = part.Name
		local extra = CFrame.new()
		if (name == "Leg" or name == "LegF" or name == "LegB") and moving then
			local side = off.Position.X > 0 and 1 or -1
			local front = (name == "LegF" or off.Position.Z < 0) and 1 or -1
			extra = CFrame.Angles(math.sin(clock * 10 + side * front * 1.57) * 0.5, 0, 0)
		elseif name == "Wing" then
			local side = off.Position.X > 0 and 1 or -1
			extra = CFrame.Angles(0, 0, side * math.sin(clock * 12) * 0.6)
		elseif name == "Tail" or name == "Coil" then
			extra = CFrame.new(math.sin(clock * 3 + off.Position.Z * 0.3) * 0.4, 0, 0)
		elseif name == "Jaw" then
			extra = CFrame.new(0, -tell * 1.2, 0)
		elseif name == "Claw" or name == "Arm" then
			extra = CFrame.new(0, tell * 0.8, -tell * 0.6)
		elseif name == "Fin" and kind ~= "leviathan" then
			extra = CFrame.Angles(0, 0, math.sin(clock * 4) * 0.1)
		end
		part.CFrame = base * CFrame.new(off.Position) * extra * off.Rotation
	end
end

Rigs.builders = build
return Rigs
