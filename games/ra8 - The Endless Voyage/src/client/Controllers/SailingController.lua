--[[
Moving you can feel (master plan §10: travel is an activity you watch). The rafts never move through the world, so
this client moves the world instead, all the time:
  * the far islands always drift past downstream (the way the debris goes), slowly while the raft floats at its
    spot and fast while it sails; they wrap round, and none passes closer than CLEAR to the raft
  * foam streams off the stern and spray off the bow while sailing
  * the place you're sailing to rises upstream ahead and comes in as the trip goes on, until the real island
    appears beside the raft
  * leaving an island, a copy of it slides away behind you and sinks below the horizon
  * every island you land on is your own: other plots' islands are never shown here (a cut to black on arrival,
    then you're there by yourselves, however many rafts on the server sailed to the same place)
The raft travels upstream: "ahead" is against the current.
]]
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Pieces = require(ReplicatedStorage.Shared.Data.Pieces)
local Voyages = require(ReplicatedStorage.Shared.Data.Voyages)
local IslandBuilder = require(ReplicatedStorage.Shared.World.IslandBuilder)
local OceanLayout = require(ReplicatedStorage.Shared.World.OceanLayout)
local OceanModels = require(ReplicatedStorage.Shared.World.OceanModels)
local Store = require(script.Parent.Parent.Store)
local PerformanceController = require(script.Parent.PerformanceController)

local SailingController = { Name = "SailingController", Order = 37 }

local DRIFT_SPEED = 4 -- studs a second the far islands pass while the raft floats at its spot
-- Sailing is a cut scene (VoyageService): the screen goes black and you're there, so nothing here races past, no
-- wake, no island coming in or sliding away. (false brings the watched trip back.)
local CUT_SCENE = true
local RANGE = 1150 -- they wrap round at this distance up and down the current
local CLEAR = 320 -- and never pass closer than this to the raft, sideways

local flow = 0 -- how far the world has moved downstream (studs)
local speed = DRIFT_SPEED
local isles -- { { parts, bases, along, lat, center } } (per plot: rebuilt when the plot changes)
local islesPlot
local wake -- { stern, bow }
local silhouette -- { model, dest, parts, bases }
local leaving -- { model, parts, bases, start, t0 }
local lastState
local isleFrame = 0
local lastIsland -- the island's centre while you're at one (for the copy that sails away)

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

local function move(parts, cframes)
	pcall(function()
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end)
end

local function partsOf(model)
	local parts, bases = {}, {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			table.insert(bases, d.CFrame)
		end
	end
	return parts, bases
end

-- The far islands, measured from your plot: how far up/down the current, and how far to the side.
local function islesFor(layout)
	if isles and islesPlot == layout.index then
		return isles
	end
	local map = workspace:FindFirstChild("Map")
	local f = map and map:FindFirstChild("Horizon")
	if not f then
		return nil
	end
	if isles then
		-- (back where the server put them before measuring from a new plot)
		for _, isle in isles do
			move(isle.parts, isle.bases)
		end
	end
	local side = layout.out
	isles = {}
	for _, m in f:GetChildren() do
		if m:IsA("Model") then
			local parts, bases = partsOf(m)
			if #parts > 0 then
				local c = m:GetPivot().Position
				local rel = Vector3.new(c.X - layout.center.X, 0, c.Z - layout.center.Z)
				local lat = rel:Dot(side)
				if math.abs(lat) < CLEAR then
					lat = (lat >= 0 and 1 or -1) * CLEAR
				end
				table.insert(
					isles,
					{ parts = parts, bases = bases, along = rel:Dot(layout.current), lat = lat, center = c }
				)
			end
		end
	end
	islesPlot = layout.index
	f.ChildAdded:Connect(function()
		isles = nil
	end)
	return isles
end

local function wrap(x)
	return (x + RANGE) % (2 * RANGE) - RANGE
end

local function flowIsles(layout)
	local list = islesFor(layout)
	if not list then
		return
	end
	local parts, cframes = {}, {}
	for _, isle in list do
		local along = wrap(isle.along + flow)
		local at = layout.center + layout.current * along + layout.out * isle.lat
		local shift = Vector3.new(at.X - isle.center.X, 0, at.Z - isle.center.Z)
		for i, p in isle.parts do
			table.insert(parts, p)
			table.insert(cframes, isle.bases[i] + shift)
		end
	end
	move(parts, cframes)
end

-- The raft's stern and bow (from its tiles), along the way it goes: upstream.
local function ends(layout)
	local raft = Store.get("raft") or { pieces = {} }
	local ahead = -layout.current
	local minA, maxA = 0, 0
	local center = layout.center
	for _, p in raft.pieces or {} do
		local def = Pieces.get(p.key)
		if def and def.structural and p.level == 1 then
			local pos = Formulas.tilePosition(center, p.gx, p.gz, 1)
			local a = (pos - center):Dot(ahead)
			minA = math.min(minA, a - Constants.TILE / 2)
			maxA = math.max(maxA, a + Constants.TILE / 2)
		end
	end
	return center + ahead * minA, center + ahead * maxA
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

local function wakeParts()
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
	wake = { stern = stern, bow = bow }
	return wake
end

local function setWake(on, layout)
	local w = wakeParts()
	local back, front = ends(layout)
	local ahead = -layout.current
	local y = Constants.WATER_LEVEL + 0.3
	-- the stern's Front face points astern: foam streams away behind the raft
	w.stern.CFrame = CFrame.lookAt(Vector3.new(back.X, y, back.Z), Vector3.new(back.X, y, back.Z) - ahead)
	w.bow.CFrame = CFrame.lookAt(Vector3.new(front.X, y, front.Z), Vector3.new(front.X, y, front.Z) + ahead)
	w.stern.Foam.Rate = on and 28 or 3
	w.bow.Spray.Rate = on and 14 or 0
end

local function clearSilhouette()
	if silhouette then
		silhouette.model:Destroy()
		silhouette = nil
	end
end

local function isleModel(name, template, seed)
	local kind = KIND_OF_TEMPLATE[template] or "low"
	local model = OceanModels.isle(
		workspace:FindFirstChild("Fx") or workspace,
		name,
		Vector3.new(0, Constants.WATER_LEVEL - 2, 0),
		{ size = kind == "atoll" and 30 or 34, kind = kind, far = 0.6 },
		Random.new(seed or 7)
	)
	return model
end

local function step(dt)
	local layout = myLayout()
	if not layout then
		return
	end
	dt = math.min(dt or 1 / 60, 0.1)
	local v = Store.get("voyage") or { state = "docked" }
	local state = v.state
	-- ease between floating and sailing speed
	-- (sailing is a cut scene now: the world never races past)
	local want = DRIFT_SPEED
	speed += (want - speed) * math.min(1, dt * 0.8)
	flow += speed * dt
	-- (phones: the far islands hold still and are cut down to their big shapes, liteIsles: sliding ~3,200 parts
	-- every few frames was what held phones at ~21 FPS)
	isleFrame = (isleFrame or 0) + 1
	if not PerformanceController.lite then
		flowIsles(layout)
	end
	local island = Store.get("island")
	if type(island) == "table" and island.center then
		lastIsland = { center = island.center, template = island.template or island.key }
	end
	if state ~= lastState then
		local was = lastState
		lastState = state
		setWake(false, layout) -- (sailing is a cut scene: no wake, no spray)
		if state ~= "sailing" then
			clearSilhouette()
		end
		-- leaving an island: a copy of it stays where it was and slides away behind you
		if CUT_SCENE == false and was == "island" and lastIsland then
			if leaving then
				leaving.model:Destroy()
			end
			local model = isleModel("Leaving", lastIsland.template, 11)
			local parts, bases = partsOf(model)
			leaving = { model = model, parts = parts, bases = bases, start = lastIsland.center, flow0 = flow }
			lastIsland = nil
		end
	end
	if leaving then
		local gone = flow - leaving.flow0
		local sink = math.max(0, gone - 300) * 0.06
		local at = leaving.start + layout.current * gone - Vector3.new(0, sink, 0)
		local cframes = table.create(#leaving.parts)
		for i, base in leaving.bases do
			cframes[i] = base + at
		end
		move(leaving.parts, cframes)
		if gone > 900 then
			leaving.model:Destroy()
			leaving = nil
		end
	end
	-- the place you're going: upstream ahead, nearer every second, gone when the real island rises
	if CUT_SCENE == false and state == "sailing" and v.dest then
		if not silhouette or silhouette.dest ~= v.dest then
			clearSilhouette()
			local d = Voyages.get(v.dest)
			local model = isleModel("Destination", d and d.template, 7)
			local parts, bases = partsOf(model)
			silhouette = { model = model, dest = v.dest, parts = parts, bases = bases }
		end
		local t = workspace:GetServerTimeNow()
		local total = (v.ends or t) - (v.started or t)
		local progress = total > 0 and math.clamp((t - (v.started or t)) / total, 0, 1) or 0
		local dist = 720 - 700 * progress
		-- (where the real island will rise: right off the raft's outer side, OceanLayout.islandBeside)
		local raft = Store.get("raft") or { pieces = {} }
		local dd = Voyages.get(v.dest)
		local tpl = dd and IslandBuilder.TEMPLATES[dd.template]
		local reach = Formulas.raftReach(layout.center, raft.pieces or {}, layout.out)
		local landing = OceanLayout.islandBeside(layout.index, reach, tpl and tpl.radius or Constants.ISLAND_RADIUS)
			or layout.center + layout.out * Constants.ISLAND_OFFSET
		local at = landing - layout.current * dist
		local cframes = table.create(#silhouette.parts)
		for i, base in silhouette.bases do
			cframes[i] = base + at
		end
		move(silhouette.parts, cframes)
	end
end

-- Only your own plot's island is shown: the others go into a folder of this client's that's never drawn (and back
-- if your plot changes).
local hidden = {} -- [model] = true
local hideBin
local function privacy()
	local folder = workspace:FindFirstChild("Islands")
	if not folder then
		return
	end
	local me = Store.get("me") or {}
	hideBin = hideBin or Instance.new("Folder")
	hideBin.Name = "OtherIslands"
	for _, m in folder:GetChildren() do
		local plot = m:GetAttribute("Plot")
		if plot ~= nil and plot ~= me.plot then
			hidden[m] = true
			m.Parent = hideBin
		end
	end
	for m in hidden do
		if m:GetAttribute("Plot") == me.plot then
			hidden[m] = nil
			m.Parent = folder
		elseif m.Parent ~= hideBin then
			hidden[m] = nil -- (gone: the server took it down)
		end
	end
end

-- Phones (lite): the far islands keep only their big shapes (nothing under LITE_MIN_SIZE studs: trees' leaves, rocks,
-- huts' planks), on this client only. They're far enough away that the outline is what you see.
local LITE_MIN_SIZE = 12
local litDone = {} -- [model] = true
local function liteIsles()
	if not PerformanceController.lite then
		return 0
	end
	local map = workspace:FindFirstChild("Map")
	local f = map and map:FindFirstChild("Horizon")
	if not f then
		return 0
	end
	local cut = 0
	for _, m in f:GetChildren() do
		if not litDone[m] then
			litDone[m] = true
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					local size = d.Size
					if math.max(size.X, size.Y, size.Z) < LITE_MIN_SIZE then
						d.Parent = nil
						cut += 1
					else
						d.CastShadow = false
					end
				end
			end
		end
	end
	return cut
end

function SailingController:init()
	RunService.RenderStepped:Connect(step)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.25 then
			acc = 0
			privacy()
			liteIsles()
		end
	end)
end

-- (tests)
SailingController.liteIsles = liteIsles
SailingController.LITE_MIN_SIZE = LITE_MIN_SIZE
function SailingController.privacy()
	privacy()
	return hidden
end
function SailingController.slide()
	return flow
end
function SailingController.speed()
	return speed
end
function SailingController.silhouette()
	return silhouette
end
function SailingController.wake()
	return wake
end
function SailingController.leaving()
	return leaving
end

return SailingController
