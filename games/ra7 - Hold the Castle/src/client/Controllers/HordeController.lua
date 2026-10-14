--[[
Draws the horde (master plan §13: each monster moves in its own way; a few great animations beat many okay
ones). The server sends a small snapshot of every NPC 8 times a second (HordeService.pack); here each NPC gets a
model built from the shared costumes (Shared/World/Costumes), placed a fifth of a second in the past so it can
glide smoothly between two snapshots, and animated by hand every frame: a walk cycle as it moves (Brutes stomp,
imps scurry, witches float), a wind-up and strike when it attacks, a flinch when hit, a rock on the head when a
dwarf carries one, a cheer when its side wins, and a tumble when it falls. Far-away NPCs animate less often and
very far ones aren't drawn at all, to keep phones fast.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Costumes = require(ReplicatedStorage.Shared.World.Costumes)
local Kit = require(ReplicatedStorage.Shared.World.Kit)
local Looks = require(ReplicatedStorage.Shared.Data.Looks)
local Net = require(ReplicatedStorage.Shared.Net)
local PerformanceController = require(script.Parent.PerformanceController)

local HordeController = { Name = "HordeController", Order = 30 }

local KINDS = { "grunt", "brute", "spitter", "witch", "breaker", "imp", "scout", "dwarf" }
local INTERP = 0.2 -- seconds in the past we draw (two snapshots apart)
local FAR = 320 -- not drawn beyond this (lite mode: 200)
local MID = 130 -- animated less often beyond this (lite mode: 80)
local SPEED_ANIM = { brute = 0.7, imp = 1.8, scout = 1.4, witch = 0.6, dwarf = 1.2 }
local SKINS = { "frost", "toxic", "lava", "ghost", "candy", "shadow" }
local BEARDS = { "brown", "ginger", "black", "gray", "snow" }
local ARMORS = { "iron", "copper", "royal", "golden", "emerald", "rose" }

local folder
local npcs = {} -- [id] = { kind, model, rig, samples = { {t, x, y, z, yaw, hp, flags} }, phase, lastAct, swingAt, hitAt, dieAt, lastSeen }
local lastSnapshot = 0

local function now()
	return workspace:GetServerTimeNow()
end

local function unpack(s)
	local t, pos = string.unpack("<d", s)
	local out = {}
	while pos + 11 <= #s do
		local id, k, x, y, z, yaw, hp, flags
		id, k, x, y, z, yaw, hp, flags, pos = string.unpack("<I2BhhhBBB", s, pos)
		table.insert(out, {
			id = id,
			kind = KINDS[k] or "grunt",
			x = x / 10,
			y = y / 10,
			z = z / 10,
			yaw = yaw / 255 * math.pi * 2,
			hp = hp / 255,
			flags = flags,
		})
	end
	return t, out
end
HordeController.unpack = unpack

-- The attack counter in a snapshot's flags (bits 2 and 3): it ticks over on every attack.
local function actOf(flags)
	return math.floor(flags / 2) % 4
end

-- A look for an NPC, the same every time for the same id: a few elite monsters wear skins, dwarves vary.
local function lookFor(id, kind, elite)
	if kind == "dwarf" then
		return {
			job = ({ "builder", "miner", "fighter", "builder", "archer" })[id % 5 + 1],
			beard = Looks.byKey[BEARDS[id % #BEARDS + 1]],
			armor = Looks.byKey[ARMORS[(id * 7) % #ARMORS + 1]],
			shirt = Costumes.DWARF_SHIRTS[id % #Costumes.DWARF_SHIRTS + 1],
		}
	end
	if elite or id % 9 == 0 then
		return { skin = Looks.byKey[SKINS[id % #SKINS + 1]] }
	end
	return {}
end

local function spawnModel(e)
	local look = lookFor(e.id, e.kind, e.flags >= 64 and e.flags % 128 >= 64)
	local rig = Costumes.npc(e.kind, look, folder)
	rig.model.Name = e.kind .. e.id
	rig.model:SetAttribute("NpcId", e.id)
	rig.model:SetAttribute("Kind", e.kind)
	-- a health bar over its head
	local bb = Instance.new("BillboardGui")
	bb.Name = "Bar"
	bb.Size = UDim2.fromOffset(60, 8)
	bb.StudsOffset = Vector3.new(0, 4 * rig.scale, 0)
	bb.MaxDistance = 70
	bb.LightInfluence = 0
	bb.Enabled = false
	bb.Parent = rig.bones.Head
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	back.BorderSizePixel = 0
	back.Parent = bb
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = e.kind == "dwarf" and Color3.fromRGB(90, 220, 110) or Color3.fromRGB(255, 80, 80)
	fill.BorderSizePixel = 0
	fill.Parent = back
	-- the rock a dwarf carries to the blueprints
	local rock
	if e.kind == "dwarf" then
		rock = Kit.ellipsoid(
			rig.model,
			"CarryRock",
			Vector3.new(),
			Vector3.new(1.6, 1.1, 1.4),
			Kit.C.rock,
			Kit.M.SmoothPlastic,
			{ CanCollide = false, CastShadow = false, Transparency = 1 }
		)
		table.insert(rig.parts, { part = rock, bone = "Head", offset = CFrame.new(0, 1.4, 0) })
	end
	return {
		id = e.id,
		kind = e.kind,
		model = rig.model,
		rig = rig,
		samples = {},
		phase = math.random() * 6,
		lastAct = actOf(e.flags),
		swingAt = -10,
		hitAt = -10,
		bar = bb,
		fill = fill,
		rock = rock,
		visible = true,
	}
end

local function onSnapshot(s)
	if type(s) ~= "string" then
		return
	end
	local t, list = unpack(s)
	if t < lastSnapshot then
		return -- an old one arrived late (unreliable)
	end
	lastSnapshot = t
	local seen = {}
	for _, e in list do
		seen[e.id] = true
		local n = npcs[e.id]
		if n and n.kind ~= e.kind then
			n.model:Destroy()
			n = nil
		end
		if not n then
			n = spawnModel(e)
			npcs[e.id] = n
		end
		n.dieAt = nil
		n.lastSeen = t
		table.insert(n.samples, { t = t, x = e.x, y = e.y, z = e.z, yaw = e.yaw, hp = e.hp, flags = e.flags })
		while #n.samples > 4 do
			table.remove(n.samples, 1)
		end
		local act = actOf(e.flags)
		if act ~= n.lastAct then
			n.lastAct = act
			n.swingAt = os.clock()
		end
		if e.flags % 16 >= 8 then
			n.hitAt = os.clock()
		end
	end
	for id, n in npcs do
		if not seen[id] and not n.dieAt then
			n.dieAt = os.clock()
		end
	end
end

local function sampleAt(n, t)
	local s = n.samples
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

-- Every frame: where each NPC is and how it moves.
local frame = 0
local function step(dt)
	frame += 1
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame and cam.CFrame.Position or Vector3.new()
	local renderT = now() - INTERP
	local parts, cframes = {}, {}
	local far = PerformanceController.lite and 200 or FAR
	local mid = PerformanceController.lite and 80 or MID
	local clock = os.clock()
	for id, n in npcs do
		local a, b, f = sampleAt(n, renderT)
		if a then
			local x = a.x + (b.x - a.x) * f
			local y = a.y + (b.y - a.y) * f
			local z = a.z + (b.z - a.z) * f
			local yaw = lerpAngle(a.yaw, b.yaw, f)
			local pos = Vector3.new(x, y, z)
			local dist = (pos - camPos).Magnitude
			local visible = dist < far
			if visible ~= n.visible then
				n.visible = visible
				n.model.Parent = visible and folder or nil
			end
			-- dead: tumble for a moment, then go
			local fall = 0
			if n.dieAt then
				fall = math.clamp((clock - n.dieAt) / 0.7, 0, 1)
				if clock - n.dieAt > 1.4 then
					n.model:Destroy()
					npcs[id] = nil
					continue
				end
			end
			if visible and (dist < mid or (frame + id) % 3 == 0) then
				local moving = b.flags % 2 == 1 and not n.dieAt
				local speed = SPEED_ANIM[n.kind] or 1
				if moving then
					n.phase += dt * 8 * speed
				end
				local swing = clock - n.swingAt
				local pose = {
					walk = n.phase,
					stride = moving and 1 or 0,
					swing = swing < 0.6 and swing / 0.6 or nil,
					hit = clock - n.hitAt < 0.25 and 1 - (clock - n.hitAt) / 0.25 or 0,
					carry = b.flags % 32 >= 16,
					cheer = b.flags >= 128 and n.cheering and clock or nil,
					fall = fall,
					float = n.kind == "witch" and 0.8 + math.sin(clock * 2 + id) * 0.25 or 0,
				}
				if b.flags % 64 >= 32 then
					pose.hit = 0.6 -- stunned: wobble back
				end
				local rootCF = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
				local ps, cs = Costumes.pose(n.rig, rootCF, pose)
				for k = 1, #ps do
					table.insert(parts, ps[k])
					table.insert(cframes, cs[k])
				end
				if n.rock then
					n.rock.Transparency = pose.carry and 0 or 1
				end
				local hp = b.hp
				n.bar.Enabled = hp < 0.999 and dist < 60 and not n.dieAt
				n.fill.Size = UDim2.fromScale(math.clamp(hp, 0, 1), 1)
			end
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

-- NPCs of a side near a position (InputController's aim help, FxController's gates).
function HordeController.near(pos, radius, kindFilter)
	local out = {}
	local renderT = now() - INTERP
	for _, n in npcs do
		if not n.dieAt and (not kindFilter or kindFilter(n.kind)) then
			local a, b, f = sampleAt(n, renderT)
			if a then
				local p = Vector3.new(a.x + (b.x - a.x) * f, a.y + (b.y - a.y) * f, a.z + (b.z - a.z) * f)
				if (p - pos).Magnitude <= radius then
					table.insert(out, { id = n.id, kind = n.kind, pos = p })
				end
			end
		end
	end
	return out
end

function HordeController.count()
	local n = 0
	for _ in npcs do
		n += 1
	end
	return n
end

function HordeController:init()
	folder = workspace:FindFirstChild("Npcs") or Instance.new("Folder")
	folder.Name = "Npcs"
	folder.Parent = workspace
	Net.listen("Horde", onSnapshot)
	Net.listen("Npc", function(e)
		if type(e) ~= "table" then
			return
		end
		if e.kind == "clear" then
			for id, n in npcs do
				n.model:Destroy()
				npcs[id] = nil
			end
		elseif e.kind == "die" and npcs[e.id] then
			npcs[e.id].dieAt = os.clock()
		elseif e.kind == "hit" and npcs[e.id] then
			npcs[e.id].hitAt = os.clock()
		end
	end)
	Net.listen("Results", function(r)
		for _, n in npcs do
			n.cheering = (r.winner == "dwarf") == (n.kind == "dwarf")
		end
	end)
	RunService.RenderStepped:Connect(step)
end

-- (tests)
HordeController.npcs = npcs

return HordeController
