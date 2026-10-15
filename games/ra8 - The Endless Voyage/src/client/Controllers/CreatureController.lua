--[[
Creatures on this screen (master plan §9). The server sends a snapshot of every creature on your plot eight times
a second ("Creatures": positions, headings, health, state) and events ("Creature": spawn, tell, hit, surface, dive,
die); here each one gets a rig (World/Rigs) that glides to its latest place, a health bar over its head once it's
hurt, and a red ring on the ground while its tell plays, so you can read the attack coming.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Creatures = require(ReplicatedStorage.Shared.Data.Creatures)
local Net = require(ReplicatedStorage.Shared.Net)
local Rigs = require(ReplicatedStorage.Shared.World.Rigs)
local Theme = require(script.Parent.Parent.UI.Theme)

local CreatureController = { Name = "CreatureController", Order = 30 }

local player = Players.LocalPlayer
local mobs = {} -- [id] = { id, kind, def, pos, yaw, hp, max, state, model, offsets, shown, last, bar, tellUntil }
local folder
local lastSnap = 0

local function ensureFolder()
	if folder and folder.Parent then
		return folder
	end
	folder = workspace:FindFirstChild("Creatures") or Instance.new("Folder")
	folder.Name = "Creatures"
	folder.Parent = workspace
	return folder
end

local function healthBar(m)
	local body = m.model.PrimaryPart
	if not body then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "Health"
	bb.Size = UDim2.fromOffset(90, 12)
	bb.StudsOffset = Vector3.new(0, (m.def.size == "boss" and 8 or m.def.size == "heavy" and 6 or 3), 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 140
	bb.Parent = body
	local frame, fill = Theme.bar({ Size = UDim2.fromScale(1, 1) }, Theme.Color.red)
	frame.Parent = bb
	m.bar = fill
end

local function spawnRig(m)
	local model, offsets = Rigs.build(m.kind, ensureFolder())
	model:SetAttribute("CreatureId", m.id)
	m.model = model
	m.offsets = offsets
	m.shown = m.pos
	healthBar(m)
end

local function remove(id)
	local m = mobs[id]
	if not m then
		return
	end
	mobs[id] = nil
	if m.model then
		m.model:Destroy()
	end
end

-- Reads -----------------------------------------------------------------------------------------------------------
function CreatureController.position(id)
	local m = mobs[id]
	return m and (m.shown or m.pos) or nil
end

function CreatureController.near(pos, radius)
	local out = {}
	for _, m in mobs do
		if m.state ~= "dead" and m.state ~= "dive" and (m.pos - pos).Magnitude <= radius then
			table.insert(out, m)
		end
	end
	return out
end

function CreatureController.get(id)
	return mobs[id]
end

-- Snapshots ---------------------------------------------------------------------------------------------------------
local function onSnapshot(pack)
	if type(pack) ~= "table" or type(pack.list) ~= "table" then
		return
	end
	if pack.t and pack.t < lastSnap then
		return -- (unreliable: an older one)
	end
	lastSnap = pack.t or lastSnap
	local seen = {}
	for _, row in pack.list do
		local id, kind = row[1], row[2]
		seen[id] = true
		local m = mobs[id]
		if not m then
			local def = Creatures.get(kind)
			if not def then
				continue
			end
			m = {
				id = id,
				kind = kind,
				def = def,
				pos = Vector3.new(row[3], row[4], row[5]),
				yaw = row[6] or 0,
				hp = row[7],
				max = row[8],
				state = row[9],
				last = os.clock(),
			}
			mobs[id] = m
			spawnRig(m)
		end
		m.pos = Vector3.new(row[3], row[4], row[5])
		m.yaw = row[6] or m.yaw
		m.hp, m.max, m.state = row[7], row[8], row[9]
		m.last = os.clock()
	end
	for id in mobs do
		if not seen[id] then
			remove(id)
		end
	end
end

local function onEvent(e)
	if type(e) ~= "table" then
		return
	end
	local m = mobs[e.id]
	if e.kind == "die" then
		if m then
			m.state = "dead"
			task.delay(0.6, function()
				remove(e.id)
			end)
		end
	elseif e.kind == "tell" and m then
		m.tellUntil = os.clock() + (e.seconds or 0.6)
	elseif e.kind == "hit" and m then
		m.hitAt = os.clock()
		m.hp = e.hp or m.hp
	elseif e.kind == "flee" then
		task.delay(0.5, function()
			remove(e.id)
		end)
	end
end

local function step(dt)
	local clock = os.clock()
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or Vector3.zero
	for id, m in mobs do
		if not m.model or not m.model.Parent then
			if m.state ~= "dead" then
				spawnRig(m)
			else
				mobs[id] = nil
				continue
			end
		end
		-- glide to the latest place (sea creatures sink out of sight while they dive)
		local target = m.pos
		if m.state == "dive" then
			target = m.pos - Vector3.new(0, 6, 0)
		end
		local k = math.min(1, dt * 10)
		local was = m.shown or target
		m.shown = was:Lerp(target, k)
		local moving = (target - was).Magnitude > 0.05 * dt * 60
		if (m.shown - camPos).Magnitude > 260 then
			continue
		end
		local size = m.def.size == "boss" and 1 or 1
		local cf = CFrame.new(m.shown) * CFrame.Angles(0, m.yaw, 0)
		if m.state == "dead" then
			cf = cf * CFrame.Angles(0, 0, math.rad(70))
		end
		Rigs.place(m.model, m.offsets, cf, m.state, clock, moving)
		-- the health bar once it's hurt
		if m.bar then
			local bb = m.bar.Parent and m.bar.Parent.Parent
			local share = m.max > 0 and m.hp / m.max or 1
			m.bar.Size = UDim2.fromScale(math.clamp(share, 0, 1), 1)
			if bb then
				bb.Enabled = share < 1 and m.state ~= "dead"
			end
		end
		-- a hit flashes the body
		local body = m.model.PrimaryPart
		if body and m.hitAt and clock - m.hitAt < 0.15 then
			body.Color = Color3.fromRGB(255, 255, 255)
		elseif body and m.hitAt and clock - m.hitAt < 0.3 then
			body.Color = m.baseColor or body.Color
		elseif body and not m.baseColor then
			m.baseColor = body.Color
		end
		_ = size
	end
end

function CreatureController:init()
	ensureFolder()
	Net.listen("Creatures", onSnapshot)
	Net.listen("Creature", onEvent)
	RunService.RenderStepped:Connect(step)
	_ = player
end

-- (tests)
CreatureController.mobs = mobs
return CreatureController
