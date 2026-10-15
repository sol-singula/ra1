--[[
Sailing you can feel (master plan §10: travel is an activity you watch). The rafts never move through the world,
so while yours is at sea this client makes the world move instead: foam streams off the stern and spray flies
off the bow, the far islands slide past, and the place you are sailing to rises on the horizon ahead and grows
until the real island appears beside the raft (then it goes). Sailing home slides everything back.
]]
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Pieces = require(ReplicatedStorage.Shared.Data.Pieces)
local Voyages = require(ReplicatedStorage.Shared.Data.Voyages)
local OceanLayout = require(ReplicatedStorage.Shared.World.OceanLayout)
local OceanModels = require(ReplicatedStorage.Shared.World.OceanModels)
local Store = require(script.Parent.Parent.Store)

local SailingController = { Name = "SailingController", Order = 37 }

local SLIDE_RATE = 5 -- studs a second the horizon slides while you sail
local SLIDE_MAX = 170
local slide = 0 -- how far the horizon has slid (out while sailing, back while sailing home)
local horizon -- { parts, bases, out }
local wake -- { part, stern, bow, out }
local silhouette -- { model, dest }
local lastState

local KIND_OF_TEMPLATE = {
	tropical = "atoll",
	rocky = "peak",
	volcanic = "peak",
	frozen = "peak",
	surface_wreck = "low",
	deep_wreck = "low",
	foggy = "low",
	ruin = "low",
	trench = "low",
}

local function myLayout()
	local me = Store.get("me") or {}
	return me.plot and OceanLayout.plot(me.plot) or nil
end

-- The horizon's parts and where the server put them (they never move otherwise).
local function horizonParts()
	if horizon then
		return horizon
	end
	local map = workspace:FindFirstChild("Map")
	local f = map and map:FindFirstChild("Horizon")
	if not f then
		return nil
	end
	local parts, bases = {}, {}
	for _, d in f:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			table.insert(bases, d.CFrame)
		end
	end
	horizon = { parts = parts, bases = bases }
	f.DescendantAdded:Connect(function()
		horizon = nil
	end)
	return horizon
end

local function slideHorizon(out, dist)
	local h = horizonParts()
	if not h then
		return
	end
	local offset = -out * dist
	local cframes = table.create(#h.parts)
	for i, base in h.bases do
		cframes[i] = base + offset
	end
	pcall(function()
		workspace:BulkMoveTo(h.parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end)
end

-- The raft's stern and bow along the way it sails (from its tiles).
local function ends(layout)
	local raft = Store.get("raft") or { pieces = {} }
	local out = layout.out
	local minA, maxA = 0, 0
	local center = layout.center
	for _, p in raft.pieces or {} do
		local def = Pieces.get(p.key)
		if def and def.structural and p.level == 1 then
			local pos = Formulas.tilePosition(center, p.gx, p.gz, 1)
			local a = (pos - center):Dot(out)
			minA = math.min(minA, a - Constants.TILE / 2)
			maxA = math.max(maxA, a + Constants.TILE / 2)
		end
	end
	return center + out * minA, center + out * maxA
end

local function emitter(parent, name, props)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(235, 245, 255))
	e.LightEmission = 0.2
	e.Rate = 0
	for k, v in props do
		e[k] = v
	end
	e.Parent = parent
	return e
end

local function wakeFor(layout)
	if wake then
		return wake
	end
	local stern = Instance.new("Part")
	stern.Name = "Wake"
	stern.Anchored = true
	stern.CanCollide = false
	stern.CanQuery = false
	stern.CanTouch = false
	stern.Transparency = 1
	stern.Color = Color3.fromRGB(235, 245, 255)
	stern.Size = Vector3.new(8, 1, 1)
	stern.Parent = workspace:FindFirstChild("Fx") or workspace
	emitter(stern, "Foam", {
		Lifetime = NumberRange.new(1.6, 2.6),
		Speed = NumberRange.new(5, 8),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 4.5) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) }),
		SpreadAngle = Vector2.new(12, 4),
		EmissionDirection = Enum.NormalId.Front,
	})
	local bow = stern:Clone()
	bow.Name = "Spray"
	bow.Size = Vector3.new(6, 1, 1)
	bow:ClearAllChildren()
	bow.Parent = stern.Parent
	emitter(bow, "Spray", {
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(8, 12),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 2) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
		SpreadAngle = Vector2.new(40, 20),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, -14, 0),
	})
	wake = { stern = stern, bow = bow, layout = layout }
	return wake
end

local function setWake(on, layout, home)
	local w = wakeFor(layout)
	local back, front = ends(layout)
	local out = home and -layout.out or layout.out
	if home then
		back, front = front, back
	end
	local y = Constants.WATER_LEVEL + 0.3
	-- the stern's Front face points astern: foam streams away behind the raft
	w.stern.CFrame = CFrame.lookAt(Vector3.new(back.X, y, back.Z), Vector3.new(back.X, y, back.Z) - out)
	w.bow.CFrame = CFrame.lookAt(Vector3.new(front.X, y, front.Z), Vector3.new(front.X, y, front.Z) + out)
	w.stern.Foam.Rate = on and 28 or 0
	w.bow.Spray.Rate = on and 14 or 0
end

local function clearSilhouette()
	if silhouette then
		silhouette.model:Destroy()
		silhouette = nil
	end
end

local function step()
	local layout = myLayout()
	local v = Store.get("voyage") or { state = "docked" }
	if not layout then
		return
	end
	local state = v.state
	local dt = 1 / 60
	local sailing = state == "sailing"
	local home = state == "home"
	if sailing then
		slide = math.min(SLIDE_MAX, slide + SLIDE_RATE * dt)
	elseif home then
		slide = math.max(0, slide - SLIDE_RATE * dt)
	elseif state == "docked" then
		slide = math.max(0, slide - 2 * dt)
	end
	slideHorizon(layout.out, slide)
	if state ~= lastState then
		lastState = state
		setWake(sailing or home, layout, home)
		if not sailing then
			clearSilhouette()
		end
	end
	-- the place you're going: on the horizon ahead, nearer every second, gone when the real island rises
	if sailing and v.dest then
		if not silhouette or silhouette.dest ~= v.dest then
			clearSilhouette()
			local d = Voyages.get(v.dest)
			local kind = d and KIND_OF_TEMPLATE[d.template] or "low"
			local folder = workspace:FindFirstChild("Fx") or workspace
			local model = OceanModels.isle(
				folder,
				"Destination",
				Vector3.new(0, Constants.WATER_LEVEL - 2, 0),
				{ size = kind == "atoll" and 30 or 34, kind = kind, far = 0.6 },
				Random.new(7)
			)
			local parts, bases = {}, {}
			for _, p in model:GetDescendants() do
				if p:IsA("BasePart") then
					table.insert(parts, p)
					table.insert(bases, p.CFrame)
				end
			end
			silhouette = { model = model, dest = v.dest, parts = parts, bases = bases }
		end
		local t = workspace:GetServerTimeNow()
		local total = (v.ends or t) - (v.started or t)
		local progress = total > 0 and math.clamp((t - (v.started or t)) / total, 0, 1) or 0
		local dist = 720 - 500 * progress
		local at = layout.center + layout.out * dist
		local cframes = table.create(#silhouette.parts)
		for i, base in silhouette.bases do
			cframes[i] = base + at
		end
		pcall(function()
			workspace:BulkMoveTo(silhouette.parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
		end)
	end
end

function SailingController:init()
	RunService.RenderStepped:Connect(step)
end

-- (tests)
function SailingController.slide()
	return slide
end
function SailingController.silhouette()
	return silhouette
end
function SailingController.wake()
	return wake
end

return SailingController
