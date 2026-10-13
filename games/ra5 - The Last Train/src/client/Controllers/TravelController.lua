-- The journey, on this screen. The train never really moves (World/Layout): the world goes past it.
--   * Between stops: a forest streams past both sides of the train (pines, oaks, hills, telegraph poles, sleepers),
--     built once on this device in chunks that are recycled from the back of the train to the front.
--   * Departing: the doors shut, the train jolts, the platform starts to slide away, and a short fade cuts to the
--     line. Arriving: the trees slow down, a fade, and the stop slides in and comes to rest beside the doors.
--   * A gentle rumble in the camera at speed and a jolt on starting and braking (none with Reduced Motion), and the
--     door beacons blink while the doors are closing.
-- Everything here is decoration: what matters (the phase, the distance, who's aboard) is the server's.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Kit = require(ReplicatedStorage.Shared.World.Kit)
local Layout = require(ReplicatedStorage.Shared.World.Layout)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local player = Players.LocalPlayer
local C, M = Kit.C, Kit.M

local TravelController = { Name = "TravelController", Order = 45 }

local CRUISE = 70 -- studs per second at full speed
local CHUNK = 200 -- studs per scenery chunk
local CHUNKS = 7 -- covers the train with room to spare at both ends
local SPAN = CHUNK * CHUNKS

local folder -- workspace.TravelScenery (this device only)
local chunks = {} -- { model, parts = { {part, local cf} }, x }
local speed = 0 -- studs per second right now
local shown = false
local slide -- { model, parts, from, to, t0, duration, accel } a stop or the station sliding
local shake = 0 -- extra camera shake (decays)
local lastPhase

-- Scenery ------------------------------------------------------------------------------------------------------
local function chunkModel(seed)
	local rng = Random.new(seed)
	-- phones and low graphics get a lighter forest (PerformanceController)
	local lite = require(script.Parent.PerformanceController).lite == true
	local trees, low, hillTrees = lite and 5 or 9, lite and 3 or 6, lite and 1 or 3
	local model = Kit.model("Chunk" .. seed, folder)
	local function side(sign)
		-- telegraph poles with two wires' insulators, every 50 studs, on the doors side only
		if sign > 0 then
			for x = -CHUNK / 2 + 25, CHUNK / 2, 50 do
				local base = Vector3.new(x, 0, 30)
				Kit.box(
					model,
					"Pole",
					CFrame.new(base + Vector3.new(0, 13, 0)),
					Vector3.new(0.9, 26, 0.9),
					C.woodDark,
					M.Wood,
					{ CastShadow = false }
				)
				Kit.box(
					model,
					"Crossbar",
					CFrame.new(base + Vector3.new(0, 24, 0)),
					Vector3.new(0.6, 0.6, 7),
					C.woodDark,
					M.Wood,
					{ CastShadow = false }
				)
				for _, z in { -3, 3 } do
					Kit.box(
						model,
						"Insulator",
						CFrame.new(base + Vector3.new(0, 24.6, z)),
						Vector3.new(0.5, 0.7, 0.5),
						C.glass,
						M.Glass,
						{ CastShadow = false }
					)
				end
			end
		end
		-- low stuff near the line
		for _ = 1, low do
			local p = Vector3.new(rng:NextNumber(-CHUNK / 2, CHUNK / 2), 0, sign * rng:NextNumber(22, 50))
			if rng:NextNumber() < 0.5 then
				Kit.bush(model, p, rng:NextNumber(3, 6), rng)
			else
				Kit.rock(model, p, rng:NextNumber(2, 5), rng)
			end
		end
		-- the forest
		for _ = 1, trees do
			local p = Vector3.new(rng:NextNumber(-CHUNK / 2, CHUNK / 2), 0, sign * rng:NextNumber(55, 150))
			if rng:NextNumber() < 0.7 then
				Kit.pine(model, p, rng:NextNumber(28, 46), rng)
			else
				Kit.oak(model, p, rng:NextNumber(20, 30), rng)
			end
		end
		-- far hills and a darker treeline on them
		for _ = 1, 2 do
			local p = Vector3.new(rng:NextNumber(-CHUNK / 2, CHUNK / 2), -8, sign * rng:NextNumber(200, 280))
			Kit.ellipsoid(
				model,
				"Hill",
				p,
				Vector3.new(rng:NextNumber(160, 240), rng:NextNumber(50, 80), rng:NextNumber(90, 130)),
				C.grassDark,
				M.Grass,
				{ CastShadow = false }
			)
			for _ = 1, hillTrees do
				local q = p + Vector3.new(rng:NextNumber(-60, 60), 22, rng:NextNumber(-20, 20))
				Kit.pine(model, q, rng:NextNumber(30, 40), rng, C.pineDark)
			end
		end
	end
	side(1)
	side(-1)
	-- the sleepers under the train (the rails don't need to move: they look the same everywhere)
	for x = -CHUNK / 2, CHUNK / 2 - 1, 3 do
		Kit.box(
			model,
			"Sleeper",
			CFrame.new(x, 0.25, 0),
			Vector3.new(1.2, 0.5, 9),
			C.woodDark,
			M.Wood,
			{ CastShadow = false }
		)
	end
	-- no shadows and nothing to bump into: it's all far away or under the floor
	local parts = {}
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			table.insert(parts, { p, p.CFrame })
		end
	end
	return { model = model, parts = parts, x = 0 }
end

local function build()
	if folder then
		return
	end
	folder = Kit.folder("TravelScenery", workspace)
	-- the ground both sides and the track bed, standing still (they look the same as they go by)
	local length = SPAN + 400
	Kit.box(
		folder,
		"Bed",
		CFrame.new(0, -0.5, 0),
		Vector3.new(length, 1, 26),
		C.gravel,
		M.Pebble,
		{ CastShadow = false }
	)
	for _, z in { -2.4, 2.4 } do
		Kit.box(
			folder,
			"Rail",
			CFrame.new(0, 0.7, z),
			Vector3.new(length, 0.4, 0.35),
			C.steel,
			M.Metal,
			{ CastShadow = false }
		)
	end
	for _, sign in { 1, -1 } do
		Kit.box(
			folder,
			"Grass",
			CFrame.new(0, -0.6, sign * 180),
			Vector3.new(length, 1, 334),
			C.grass,
			M.Grass,
			{ CastShadow = false }
		)
	end
	for i = 1, CHUNKS do
		local c = chunkModel(1000 + i * 17)
		c.x = Layout.FRONT_X + 300 - (i - 1) * CHUNK
		table.insert(chunks, c)
	end
	TravelController.place()
end

-- Put every chunk where it belongs right now (BulkMoveTo when the engine has it).
function TravelController.place()
	local list, cfs = {}, {}
	for _, c in chunks do
		local offset = CFrame.new(c.x, 0, 0)
		for _, entry in c.parts do
			table.insert(list, entry[1])
			table.insert(cfs, offset * entry[2])
		end
	end
	local ok = pcall(function()
		workspace:BulkMoveTo(list, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end)
	if not ok then
		for i, p in list do
			p.CFrame = cfs[i]
		end
	end
end

local function setShown(on)
	if on == shown then
		return
	end
	shown = on
	if on then
		build()
	end
	if folder then
		folder.Parent = on and workspace or nil
	end
end

local function advance(dt)
	if speed <= 0 or not shown then
		return
	end
	local back = Layout.BACK_X - 300
	for _, c in chunks do
		c.x -= speed * dt
	end
	-- recycle the chunk that fell off the back to the front
	for _, c in chunks do
		if c.x < back then
			local front = -math.huge
			for _, o in chunks do
				front = math.max(front, o.x)
			end
			c.x = front + CHUNK
		end
	end
	TravelController.place()
end

-- A stop (or the station) sliding along the train: arriving to rest, or leaving.
local function startSlide(model, fromX, toX, duration, accel)
	if not model then
		return
	end
	local parts = {}
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			table.insert(parts, { p, p.CFrame })
		end
	end
	slide =
		{ model = model, parts = parts, from = fromX, to = toX, t0 = os.clock(), duration = duration, accel = accel }
end

local function stepSlide()
	if not slide then
		return
	end
	local t = math.clamp((os.clock() - slide.t0) / slide.duration, 0, 1)
	-- arriving: decelerate into place; leaving: accelerate away
	local e = slide.accel and t * t or 1 - (1 - t) * (1 - t)
	local x = slide.from + (slide.to - slide.from) * e
	local list, cfs = {}, {}
	local offset = CFrame.new(x, 0, 0)
	for _, entry in slide.parts do
		if entry[1].Parent then
			table.insert(list, entry[1])
			table.insert(cfs, offset * entry[2])
		end
	end
	local ok = pcall(function()
		workspace:BulkMoveTo(list, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end)
	if not ok then
		for i, p in list do
			p.CFrame = cfs[i]
		end
	end
	if t >= 1 or not slide.model.Parent then
		slide = nil
	end
end

local function fade(seconds, text)
	local hud = require(script.Parent.HudController)
	if hud.fade then
		hud.fade(seconds, text)
	end
end

-- The phases, on this screen --------------------------------------------------------------------------------------
local function onPhase(phase)
	if phase == lastPhase then
		return
	end
	local previous = lastPhase
	lastPhase = phase
	if phase == "traveling" then
		-- the cut to the line
		if previous == "departing" then
			fade(0.9)
		end
		setShown(true)
		shake = 1
	elseif phase == "ended" then
		setShown(true)
	elseif phase == "lobby" or phase == "scavenging" then
		setShown(false)
		speed = 0
	end
end

local function targetSpeed()
	local phase = Store.phase()
	local left = Store.timeLeft() or 0
	if phase == "traveling" then
		return CRUISE
	elseif phase == "arriving" then
		-- braking: from cruise to a crawl as the stop comes up
		return CRUISE * math.clamp(left / Constants.ARRIVE_SECONDS, 0.05, 1)
	elseif phase == "ended" then
		return CRUISE * math.clamp(left / Constants.END_SECONDS, 0, 1) * 0.6
	end
	return 0
end

-- When the stop appears (arriving) it slides in the last few studs; when the doors shut it starts to slide away.
local function watchScenery()
	local scenery = workspace:WaitForChild("Scenery", 10)
	if not scenery then
		return
	end
	scenery.ChildAdded:Connect(function(model)
		local phase = Store.phase()
		if phase == "arriving" or phase == "scavenging" then
			fade(0.8)
			setShown(false)
			task.delay(0.25, function()
				if model.Parent then
					local reveal = Constants.ARRIVE_REVEAL
					startSlide(model, CRUISE * 0.05 * reveal * 6, 0, reveal, false)
				end
			end)
			shake = 0.8
		elseif model.Name == "Station" then
			fade(1, "Back at the station")
		end
	end)
	workspace:GetAttributeChangedSignal("Doors"):Connect(function()
		local doors = workspace:GetAttribute("Doors")
		if doors == "closed" and Store.phase() == "departing" then
			shake = 1.4
			local placed
			for _, m in scenery:GetChildren() do
				placed = m
			end
			if placed then
				local left = math.max(0.5, Store.timeLeft() or 2)
				startSlide(placed, 0, -CRUISE * left * 0.5, left, true)
			end
		end
	end)
end

-- The camera: rumble at speed, jolts on starting and braking.
local function cameraShake(dt)
	shake = math.max(0, shake - dt * 1.5)
	if Theme.reducedMotion() then
		return
	end
	local c = player.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	if not hrp or not Layout.inTrain(hrp.Position) then
		return
	end
	local amount = (speed / CRUISE) * 0.025 + shake * 0.08
	if amount < 0.002 then
		return
	end
	local cam = workspace.CurrentCamera
	if cam then
		local t = os.clock()
		local offset = Vector3.new(math.noise(t * 9, 1.3) * amount, math.noise(t * 11, 7.1) * amount, 0)
		cam.CFrame = cam.CFrame * CFrame.new(offset)
	end
end

-- The door beacons blink while the doors are closing.
local beacons
local function blink()
	if not beacons then
		local train = workspace:FindFirstChild("Train")
		if not train then
			return
		end
		beacons = {}
		for _, d in train:GetDescendants() do
			if d:IsA("BasePart") and d:GetAttribute("Beacon") then
				table.insert(beacons, d)
			end
		end
	end
	local closing = workspace:GetAttribute("Doors") == "closing"
		or (Store.phase() == "warning" and workspace:GetAttribute("Final") == true)
	local on = not closing or (math.floor(os.clock() * 3) % 2 == 0)
	for _, b in beacons do
		b.Transparency = closing and (on and 0 or 0.8) or 0
		local l = b:FindFirstChildOfClass("PointLight")
		if l and closing then
			l.Brightness = on and 2.5 or 0
		end
	end
end

function TravelController:init()
	task.spawn(watchScenery)
	RunService.RenderStepped:Connect(function(dt)
		onPhase(Store.phase())
		-- ease toward the speed the phase wants
		local target = targetSpeed()
		speed += (target - speed) * math.clamp(dt * 1.6, 0, 1)
		if math.abs(speed - target) < 0.05 then
			speed = target
		end
		advance(dt)
		stepSlide()
		blink()
	end)
	pcall(function()
		RunService:BindToRenderStep("LT_Shake", Enum.RenderPriority.Camera.Value + 1, cameraShake)
	end)
end

-- (tests)
function TravelController.state()
	return { speed = speed, shown = shown, chunks = #chunks, slide = slide ~= nil }
end

return TravelController
