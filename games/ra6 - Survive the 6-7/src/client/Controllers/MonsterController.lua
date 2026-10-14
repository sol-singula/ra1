--[[
Draws the forest's monsters (master plan §10: readable at a glance; §13: a few great animations). The server sends a
small snapshot of every monster 8 times a second ("Mobs": MonsterService.pack, read with Data/MobCodes); each one
gets a rig from World/Rigs, drawn a fifth of a second in the past so it glides between two snapshots, and posed by
hand every frame for what it's doing (walking, the tell before an attack, the attack, a stagger, sleeping, eating,
fleeing, faceplanting). "Mob" events add what a snapshot can't: who a tell is aimed at and how long it lasts, speech
("SIX... SEVEN!"), hits, and the moment one goes down (it tumbles, or Kermy vanishes in a puff).

Health bars show on hurt monsters near you; golden elites get a name tag; Kermy always has his. A grinwolf's eyes
flash red in its tell; Mega Kermy's 67 glows while he's stuck or tired. Far monsters animate less often, and very
far ones aren't drawn at all (shorter distances in lite mode).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Enemies = require(ReplicatedStorage.Shared.Data.Enemies)
local MobCodes = require(ReplicatedStorage.Shared.Data.MobCodes)
local Net = require(ReplicatedStorage.Shared.Net)
local Rigs = require(ReplicatedStorage.Shared.World.Rigs)
local PerformanceController = require(script.Parent.PerformanceController)

local MonsterController = { Name = "MonsterController", Order = 30 }

local INTERP = 0.2
local FAR, MID = 340, 140
local WALK_RATE =
	{ kermy = 1.15, snapcap = 1.6, grinwolf = 1.5, pelter = 1.7, stumpy = 0.7, mimic = 1.8, mega_kermy = 0.55 }
local RED = Color3.fromRGB(255, 60, 50)
local YELLOW = Color3.fromRGB(255, 218, 70)

local folder
local mobs = {} -- [id] = { id, kind, rig, samples, walk, act, hitAt, dieAt, tell, tellAt, tellFor, state, visible, ... }
local lastSnapshot = 0

local function now()
	return workspace:GetServerTimeNow()
end

local function makeBar(m)
	local def = Enemies.get(m.kind)
	if m.kind == "mega_kermy" then
		return -- the HUD has his bar
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "Bar"
	bb.Size = UDim2.fromOffset(84, 30)
	bb.StudsOffsetWorldSpace = Vector3.new(0, (Rigs.HEIGHT[m.kind] or 4) + 0.6, 0)
	bb.MaxDistance = 90
	bb.LightInfluence = 0
	bb.AlwaysOnTop = false
	bb.Adornee = m.rig.model.PrimaryPart
	bb.Parent = m.rig.model
	local name = Instance.new("TextLabel")
	name.Name = "Who"
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0, 16)
	name.Font = Enum.Font.LuckiestGuy
	name.TextScaled = true
	name.TextColor3 = m.elite and YELLOW or Color3.fromRGB(255, 255, 255)
	name.TextStrokeTransparency = 0.2
	name.Text = m.elite and ("✨ GOLDEN " .. string.upper(def and def.name or m.kind))
		or string.upper(def and def.name or m.kind)
	name.Visible = m.elite or m.kind == "kermy"
	name.Parent = bb
	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Position = UDim2.fromOffset(12, 20)
	back.Size = UDim2.new(1, -24, 0, 8)
	back.BackgroundColor3 = Color3.fromRGB(30, 26, 40)
	back.BorderSizePixel = 0
	back.Visible = false
	back.Parent = bb
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = m.elite and YELLOW or Color3.fromRGB(255, 80, 72)
	fill.BorderSizePixel = 0
	fill.Parent = back
	m.bar, m.barBack, m.barFill, m.nameTag = bb, back, fill, name
end

local function spawnMob(e)
	local elite = MobCodes.has(e.flags, MobCodes.ELITE)
	local rig = Rigs.build(e.kind, { elite = elite }, folder)
	rig.model.Name = e.kind .. e.id
	rig.model:SetAttribute("MobId", e.id)
	rig.model:SetAttribute("Kind", e.kind)
	local m = {
		id = e.id,
		kind = e.kind,
		rig = rig,
		elite = elite,
		samples = {},
		walk = math.random() * 6,
		act = MobCodes.has(e.flags, MobCodes.ACT),
		hitAt = -10,
		swingAt = -10,
		visible = true,
		state = e.state,
		stateAt = os.clock(),
	}
	makeBar(m)
	return m
end

local function remove(id)
	local m = mobs[id]
	if m then
		m.rig.model:Destroy()
		mobs[id] = nil
	end
end

local function onSnapshot(s)
	if type(s) ~= "string" then
		return
	end
	local t, list = MobCodes.unpack(s)
	if t < lastSnapshot then
		return -- an old one arrived late (unreliable)
	end
	lastSnapshot = t
	local seen = {}
	for _, e in list do
		seen[e.id] = true
		local m = mobs[e.id]
		if m and m.kind ~= e.kind then
			remove(e.id)
			m = nil
		end
		if not m then
			m = spawnMob(e)
			mobs[e.id] = m
		end
		m.dieAt = nil
		table.insert(m.samples, e)
		e.t = t
		while #m.samples > 4 do
			table.remove(m.samples, 1)
		end
		if e.state ~= m.state then
			m.state = e.state
			m.stateAt = os.clock()
		end
		local act = MobCodes.has(e.flags, MobCodes.ACT)
		if act ~= m.act then
			m.act = act
			m.swingAt = os.clock()
		end
		if MobCodes.has(e.flags, MobCodes.HIT) then
			m.hitAt = math.max(m.hitAt, os.clock() - 0.05)
		end
	end
	for id, m in mobs do
		if not seen[id] and not m.dieAt then
			m.dieAt = os.clock()
		end
	end
end

local function sampleAt(m, t)
	local s = m.samples
	if #s == 0 then
		return nil
	end
	if t <= s[1].t then
		return s[1], s[1], 0
	end
	for k = 1, #s - 1 do
		local a, b = s[k], s[k + 1]
		if t >= a.t and t <= b.t then
			local f = (b.t - a.t) > 1e-3 and (t - a.t) / (b.t - a.t) or 1
			return a, b, f
		end
	end
	return s[#s], s[#s], 1
end

local function lerpAngle(a, b, f)
	local d = (b - a + math.pi) % (math.pi * 2) - math.pi
	return a + d * f
end

-- Where a monster is drawn right now (others use it: aim help, effects).
function MonsterController.position(id)
	local m = mobs[id]
	if not m then
		return nil
	end
	local a, b, f = sampleAt(m, now() - INTERP)
	if not a then
		return nil
	end
	return Vector3.new(a.x + (b.x - a.x) * f, a.y + (b.y - a.y) * f, a.z + (b.z - a.z) * f)
end

local frame = 0
local function step(dt)
	frame += 1
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame and cam.CFrame.Position or Vector3.zero
	local renderT = now() - INTERP
	local far = PerformanceController.lite and 220 or FAR
	local mid = PerformanceController.lite and 90 or MID
	local clock = os.clock()
	local parts, cframes = {}, {}
	for id, m in mobs do
		local a, b, f = sampleAt(m, renderT)
		if not a then
			continue
		end
		local pos = Vector3.new(a.x + (b.x - a.x) * f, a.y + (b.y - a.y) * f, a.z + (b.z - a.z) * f)
		local yaw = lerpAngle(a.yaw, b.yaw, f)
		local dist = (pos - camPos).Magnitude
		local hidden = MobCodes.has(b.flags, MobCodes.HIDDEN)
		local visible = (dist < far or m.kind == "mega_kermy") and not hidden
		if visible ~= m.visible then
			m.visible = visible
			m.rig.model.Parent = visible and folder or nil
		end
		local fall = 0
		if m.dieAt then
			if m.vanish then
				remove(id)
				continue
			end
			fall = math.clamp((clock - m.dieAt) / 0.7, 0, 1)
			if clock - m.dieAt > 1.3 then
				remove(id)
				continue
			end
		end
		if visible and (dist < mid or (frame + id) % 3 == 0 or m.kind == "mega_kermy") then
			local moving = MobCodes.has(b.flags, MobCodes.MOVING) and not m.dieAt
			if moving then
				m.walk += dt * 9 * (WALK_RATE[m.kind] or 1) * (m.kind == "mega_kermy" and 1 or 1)
			end
			local state = b.state
			local tellF
			if state == "tell" and m.tellAt then
				tellF = math.clamp((clock - m.tellAt) / math.max(0.1, m.tellFor or 1), 0, 1)
			end
			local pose = {
				t = clock + id * 0.37,
				walk = m.walk,
				stride = moving and 1 or 0,
				state = state,
				tell = m.tell,
				f = tellF or math.clamp((clock - m.stateAt) / 0.4, 0, 1),
				hit = clock - m.hitAt < 0.25 and 1 - (clock - m.hitAt) / 0.25 or 0,
				fall = fall,
			}
			local root = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
			local ps, cs = Rigs.pose(m.rig, root, pose)
			for k = 1, #ps do
				table.insert(parts, ps[k])
				table.insert(cframes, cs[k])
			end
			if m.kind == "grinwolf" then
				local red = state == "tell" or state == "attack"
				if red ~= m.red then
					m.red = red
					Rigs.setEyes(m.rig, red and RED or YELLOW)
				end
			elseif m.kind == "mega_kermy" then
				Rigs.setWeak(m.rig, state == "faceplant" or state == "tired", clock)
			end
			if m.barBack then
				local hp = b.hp
				m.barBack.Visible = hp < 0.999 and dist < 70 and not m.dieAt
				m.barFill.Size = UDim2.fromScale(math.clamp(hp, 0, 1), 1)
			end
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

-- A speech bubble over a monster's head for a couple of seconds.
local function say(m, text)
	if not m or type(text) ~= "string" then
		return
	end
	local old = m.rig.model:FindFirstChild("Speech")
	if old then
		old:Destroy()
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "Speech"
	bb.Size = UDim2.fromOffset(200, 50)
	bb.StudsOffsetWorldSpace = Vector3.new(0, (Rigs.HEIGHT[m.kind] or 4) + (m.kind == "mega_kermy" and 4 or 2.2), 0)
	bb.MaxDistance = m.kind == "mega_kermy" and 400 or 120
	bb.LightInfluence = 0
	bb.AlwaysOnTop = true
	bb.Adornee = m.rig.model.PrimaryPart
	bb.Parent = m.rig.model
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = (m.kind == "kermy" or m.kind == "mega_kermy") and Color3.fromRGB(190, 255, 110)
		or Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0
	label.Parent = bb
	task.delay(2.4, function()
		if bb.Parent then
			bb:Destroy()
		end
	end)
end

local function onEvent(e)
	if type(e) ~= "table" then
		return
	end
	local m = e.id and mobs[e.id]
	if e.kind == "die" then
		if m then
			m.dieAt = os.clock()
			m.vanish = e.puff == true or e.fled == true
		end
	elseif e.kind == "tell" and m then
		m.tell = e.tell
		m.tellAt = os.clock()
		m.tellFor = e.seconds or 1
	elseif e.kind == "hit" and m then
		m.hitAt = os.clock()
	elseif e.kind == "say" then
		say(m, e.text)
	elseif e.kind == "clear" then
		for id in mobs do
			remove(id)
		end
	end
end

-- Monsters near a position, drawn where they are (aim help on phones, effects).
function MonsterController.near(pos, radius)
	local out = {}
	for id, m in mobs do
		if not m.dieAt and m.visible then
			local p = MonsterController.position(id)
			if p and (p - pos).Magnitude <= radius then
				table.insert(out, { id = id, kind = m.kind, pos = p })
			end
		end
	end
	table.sort(out, function(a, b)
		return (a.pos - pos).Magnitude < (b.pos - pos).Magnitude
	end)
	return out
end

function MonsterController.count()
	local n = 0
	for _ in mobs do
		n += 1
	end
	return n
end

function MonsterController:init()
	folder = workspace:FindFirstChild("Monsters") or Instance.new("Folder")
	folder.Name = "Monsters"
	folder.Parent = workspace
	Net.listen("Mobs", onSnapshot)
	Net.listen("Mob", onEvent)
	RunService.RenderStepped:Connect(step)
end

-- (tests)
MonsterController.mobs = mobs

return MonsterController
