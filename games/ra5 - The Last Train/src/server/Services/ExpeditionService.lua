-- The expedition: the one source of truth for where the train is and what happens next. Server-owned; clients only
-- display it (workspace attributes Phase / PhaseEnds / Final, and the "Expedition" view).
--
--   lobby      at the station; boarding counts down once someone is here (LOBBY_SECONDS)
--   departing  DOORS_SECONDS: warning lamps, the doors shut at DOORS_SHUT_AT, then the train pulls away. At a stop,
--              anyone still outside when the doors shut is left behind (RecoveryService). At the station,
--              everyone is simply brought aboard.
--   traveling  TRAVEL_SECONDS between stops; distance grows smoothly; the next stop is announced half way
--   arriving   ARRIVE_SECONDS of brakes; the stop appears for the last ARRIVE_REVEAL seconds
--   scavenging the doors are open; at WARNING_AT seconds left it becomes...
--   warning    ...the last minute (Final at FINAL_AT seconds left), then departing again
--   ended      the fuel ran out: the train coasts (END_SECONDS), the record is written, and a new expedition
--              starts at the station
--
-- Fuel is the crew's: every trip costs Formulas.fuelCost(engine stage, distance); fuel cans brought back aboard
-- top the tank up (ResourceService -> AddFuel). If there isn't enough fuel to leave a stop, the expedition ends.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Layout = require(ReplicatedStorage.Shared.World.Layout)
local LightingPresets = require(ReplicatedStorage.Shared.World.LightingPresets)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Stops = require(ReplicatedStorage.Shared.Data.Stops)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local ExpeditionService = {
	Name = "ExpeditionService",
	Dependencies = { "PlayerDataService" },
	PhaseChanged = Signal.new("ExpeditionService.PhaseChanged"), -- (phase, previous)
	Started = Signal.new("ExpeditionService.Started"), -- (expedition) a new expedition is boarding at the station
	Arrived = Signal.new("ExpeditionService.Arrived"), -- (stopDef, stopModel) the stop is beside the train
	DoorsShut = Signal.new("ExpeditionService.DoorsShut"), -- (atStop) the doors just shut
	Departed = Signal.new("ExpeditionService.Departed"), -- (stopDef or nil) the train pulled away
	Ended = Signal.new("ExpeditionService.Ended"), -- (expedition) out of fuel (or everyone left)
	Milestone = Signal.new("ExpeditionService.Milestone"), -- (km)
	FuelAdded = Signal.new("ExpeditionService.FuelAdded"), -- (player, amount)
}

local data
local registryRef
local exp -- the current expedition (see newExpedition)
local placed -- the model beside the train right now (the station or a stop clone)
local number = 0 -- expeditions run on this server

local function now()
	return workspace:GetServerTimeNow()
end

local function shortId(id)
	return string.upper(string.sub(string.gsub(id, "-", ""), 1, 4))
end

local function newExpedition()
	number += 1
	local ok, guid = pcall(HttpService.GenerateGUID, HttpService, false)
	local id = ok and guid or `{game.JobId}-{number}-{os.time()}`
	return {
		id = id,
		code = shortId(id),
		number = number,
		phase = "lobby",
		phaseStarted = now(),
		phaseEnds = nil, -- nil while the station waits for someone
		final = false,
		startedAt = nil, -- os.time() when the train first left the station
		endedAt = nil,
		distance = 0, -- km, committed at the end of each trip
		tripFrom = 0, -- distance when the current trip began
		fuel = Constants.START_FUEL,
		stops = 0,
		stop = nil, -- the current stop's definition (Data/Stops)
		lastStopKey = nil,
		nextStop = nil, -- chosen when a trip begins
		announcedNext = false,
		milestones = 0,
		crew = {}, -- [userId] = { name, display, joinedAt, stops, seconds, aboard, fuel, materials, blueprints, recovered }
		route = {}, -- the stops visited, in order
		reason = nil, -- why it ended: "fuel" | "empty"
	}
end

-- Crew ---------------------------------------------------------------------------------------------------------------
function ExpeditionService:CrewMember(player)
	if not exp then
		return nil
	end
	local c = exp.crew[player.UserId]
	if not c then
		c = {
			userId = player.UserId,
			name = player.Name,
			display = player.DisplayName,
			joinedAt = now(),
			stops = 0,
			seconds = 0,
			fuel = 0,
			materials = 0,
			blueprints = 0,
			recovered = 0,
			present = true,
		}
		exp.crew[player.UserId] = c
	end
	return c
end

-- Record what someone did for the crew (fuel brought back, materials given, blueprints found, crew recovered).
function ExpeditionService:Note(player, kind, amount)
	local c = self:CrewMember(player)
	if c and c[kind] ~= nil then
		c[kind] += amount or 1
	end
end

function ExpeditionService:State()
	return exp
end

function ExpeditionService:Phase()
	return exp and exp.phase or "lobby"
end

function ExpeditionService:IsAtStop()
	local p = self:Phase()
	return p == "scavenging" or p == "warning" or (p == "departing" and exp.stop ~= nil and not exp.doorsShut)
end

function ExpeditionService:CurrentStop()
	return exp and exp.stop, placed
end

function ExpeditionService:Placed()
	return placed
end

-- Distance right now (it grows during a trip).
function ExpeditionService:Distance()
	if not exp then
		return 0
	end
	if exp.phase == "traveling" and exp.phaseEnds then
		local t = math.clamp((now() - exp.phaseStarted) / Constants.TRAVEL_SECONDS, 0, 1)
		return exp.tripFrom + Constants.SEGMENT_KM * t
	end
	return exp.distance
end

local function train()
	return registryRef and registryRef.TrainService
end

function ExpeditionService:FuelCost()
	local t = train()
	return Formulas.fuelCost(t and t:Stage("engine") or 0, exp and exp.distance or 0)
end

function ExpeditionService:Fuel()
	return exp and exp.fuel or 0
end

function ExpeditionService:AddFuel(player, amount)
	if not exp or amount <= 0 then
		return
	end
	exp.fuel = Formulas.round1(exp.fuel + amount)
	if player then
		self:Note(player, "fuel", amount)
	end
	self.FuelAdded:Fire(player, amount)
	self:PushAll()
end

-- The view clients display ---------------------------------------------------------------------------------------------
function ExpeditionService:View()
	if not exp then
		return { phase = "lobby" }
	end
	local t = train()
	local lampStage = t and t:Stage("lamp") or 0
	local stopInfo = exp.stop and { key = exp.stop.key, name = exp.stop.name, text = exp.stop.text, landmark = exp.stop.landmark, rich = exp.stop.rich } or nil
	local nextInfo = nil
	if exp.nextStop and (exp.announcedNext or lampStage >= 1) then
		nextInfo = { key = exp.nextStop.key, name = exp.nextStop.name, text = exp.nextStop.text }
		if lampStage >= 1 then
			nextInfo.rich = exp.nextStop.rich
		end
	end
	local crew = 0
	for _, c in exp.crew do
		if c.present then
			crew += 1
		end
	end
	return {
		id = exp.id,
		code = exp.code,
		number = exp.number,
		phase = exp.phase,
		phaseStarted = exp.phaseStarted,
		phaseEnds = exp.phaseEnds,
		final = exp.final,
		distance = exp.phase == "traveling" and exp.tripFrom or exp.distance,
		rate = exp.phase == "traveling" and Constants.SEGMENT_KM / Constants.TRAVEL_SECONDS or 0,
		nextMilestone = Formulas.nextMilestone(self:Distance()),
		fuel = exp.fuel,
		cost = self:FuelCost(),
		stops = exp.stops,
		stop = stopInfo,
		nextStop = nextInfo,
		crew = crew,
		region = Stops.REGION,
		upgrades = t and t:Stages() or {},
		goal = t and t:Goal() or nil,
		doorsShut = exp.doorsShut == true,
	}
end

function ExpeditionService:Push(player)
	Net.fire(player, "Expedition", self:View())
end

function ExpeditionService:PushAll()
	Net.fireAll("Expedition", self:View())
	self:_boards()
end

-- The crew board in the crew car and the station's departure boards.
function ExpeditionService:_boards()
	local layout = WorldBuilder.layout
	if not layout or not exp then
		return
	end
	local t = train()
	local lines = { `EXPEDITION #{exp.code}` }
	local phase = exp.phase
	if phase == "lobby" then
		table.insert(lines, "BOARDING AT THE STATION")
	elseif phase == "traveling" then
		table.insert(lines, exp.nextStop and exp.announcedNext and `NEXT STOP: {string.upper(exp.nextStop.name)}` or "ON THE LINE")
	elseif phase == "arriving" then
		table.insert(lines, `ARRIVING: {string.upper(exp.nextStop and exp.nextStop.name or "")}`)
	elseif phase == "ended" then
		table.insert(lines, "OUT OF FUEL")
	elseif exp.stop then
		table.insert(lines, `AT: {string.upper(exp.stop.name)}`)
	end
	table.insert(lines, `DISTANCE  {Formulas.round1(self:Distance())} km   ·   NEXT MILESTONE {Formulas.nextMilestone(self:Distance())} km`)
	table.insert(lines, `FUEL  {exp.fuel}   ·   NEXT TRIP NEEDS {self:FuelCost()}`)
	local goal = t and t:Goal()
	if goal then
		table.insert(lines, `CREW GOAL: {string.upper(goal.text)}`)
	end
	if layout.train.crewBoard then
		layout.train.crewBoard.Text = table.concat(lines, "\n")
	end
	local station = layout.station
	if station and station.board then
		local left = exp.phaseEnds and math.max(0, exp.phaseEnds - now()) or nil
		if phase == "lobby" then
			station.board.Text = left and `THE LAST TRAIN · {string.upper(Stops.REGION)}\nBOARDING · DEPARTS IN {Format.time(left)}`
				or `THE LAST TRAIN · {string.upper(Stops.REGION)}\nWAITING FOR THE CREW`
			station.board2.Text = left and `DEPARTS IN {Format.time(left)}` or "BOARDING"
		else
			station.board.Text = `THE LAST TRAIN\nEXPEDITION #{exp.code}`
			station.board2.Text = "DEPARTED"
		end
	end
end

-- Placing the station or a stop beside the train ------------------------------------------------------------------------
local function clearPlaced()
	local layout = WorldBuilder.layout
	if placed then
		if placed == layout.station.model then
			placed.Parent = layout.templates -- the station is kept and reused
		else
			placed:Destroy()
		end
		placed = nil
	end
end

function ExpeditionService:_placeStation()
	clearPlaced()
	local layout = WorldBuilder.layout
	layout.station.model.Parent = layout.scenery
	placed = layout.station.model
	self:_light("station")
end

function ExpeditionService:_placeStop(stop)
	clearPlaced()
	local layout = WorldBuilder.layout
	local clone = layout.stops[stop.key]:Clone()
	clone.Parent = layout.scenery
	placed = clone
	self:_light(stop.light)
	return clone
end

function ExpeditionService:_light(preset)
	LightingPresets.apply(preset)
	workspace:SetAttribute("LightPreset", preset)
end

-- Phases ---------------------------------------------------------------------------------------------------------------
function ExpeditionService:_set(phase, seconds)
	local previous = exp.phase
	exp.phase = phase
	exp.phaseStarted = now()
	exp.phaseEnds = seconds and (now() + seconds) or nil
	exp.final = false
	workspace:SetAttribute("Phase", phase)
	workspace:SetAttribute("PhaseStarted", exp.phaseStarted)
	workspace:SetAttribute("PhaseEnds", exp.phaseEnds or 0)
	workspace:SetAttribute("Final", false)
	self.PhaseChanged:Fire(phase, previous)
	self:PushAll()
end

local function announce(text, kind)
	Net.fireAll("Announce", text, kind or "chime")
end
ExpeditionService.announce = announce

function ExpeditionService:_begin()
	exp = newExpedition()
	workspace:SetAttribute("ExpeditionId", exp.id)
	self:_placeStation()
	local t = train()
	if t then
		t:Doors("open")
	end
	for _, p in Players:GetPlayers() do
		if data:Get(p) then
			local c = self:CrewMember(p)
			c.present = true
		end
	end
	self:_set("lobby", nil)
	self.Started:Fire(exp)
	self:_startLobbyTimer()
end

function ExpeditionService:_startLobbyTimer()
	if exp and exp.phase == "lobby" and not exp.phaseEnds then
		for _, p in Players:GetPlayers() do
			if data:Get(p) then
				exp.phaseEnds = now() + Constants.LOBBY_SECONDS
				workspace:SetAttribute("PhaseEnds", exp.phaseEnds)
				self:PushAll()
				return
			end
		end
	end
end

function ExpeditionService:_depart()
	self:_set("departing", Constants.DOORS_SECONDS)
	exp.doorsShut = false
	local t = train()
	if t then
		t:Doors("closing")
	end
	announce(exp.stop and "Doors closing! All aboard!" or "All aboard! The Last Train is leaving the station.", "final")
	Net.fireAll("Sfx", "whistle")
end

-- the doors shut: at a stop, whoever is outside is left behind; at the station, everyone comes aboard
function ExpeditionService:_shutDoors()
	exp.doorsShut = true
	local t = train()
	if t then
		t:Doors("closed")
	end
	local atStop = exp.stop ~= nil
	for _, p in Players:GetPlayers() do
		local pos = self:Position(p)
		if pos and not Layout.inTrain(pos) and not self:InRecovery(p) then
			if atStop then
				local recovery = registryRef.RecoveryService
				if recovery then
					recovery:Strand(p)
				end
			else
				self:SendHome(p, true)
			end
		end
	end
	self.DoorsShut:Fire(atStop)
	self:PushAll()
end

function ExpeditionService:_leave()
	local from = exp.stop
	-- fuel for the trip (the station's first trip is always covered by the starting tank)
	local cost = self:FuelCost()
	if from and exp.fuel + 1e-6 < cost then
		self:_end("fuel")
		return
	end
	exp.fuel = Formulas.round1(math.max(0, exp.fuel - cost))
	if not exp.startedAt then
		exp.startedAt = os.time()
	end
	if from then
		exp.lastStopKey = from.key
	end
	clearPlaced()
	exp.stop = nil
	exp.tripFrom = exp.distance
	exp.nextStop = Formulas.pickStop(exp.distance + Constants.SEGMENT_KM, exp.lastStopKey, math.random())
	exp.announcedNext = false
	self:_light("travel")
	self.Departed:Fire(from)
	self:_set("traveling", Constants.TRAVEL_SECONDS)
	Net.fireAll("Sfx", "depart")
end

function ExpeditionService:_arrive()
	exp.distance = Formulas.round1(exp.tripFrom + Constants.SEGMENT_KM)
	self:_checkMilestones()
	exp.revealed = false
	self:_set("arriving", Constants.ARRIVE_SECONDS)
	announce(`Arriving at {exp.nextStop.name}.`, "chime")
	Net.fireAll("Sfx", "brakes")
end

function ExpeditionService:_reveal()
	exp.revealed = true
	local stop = exp.nextStop
	local model = self:_placeStop(stop)
	exp.stop = stop
	exp.stops += 1
	table.insert(exp.route, stop.key)
	-- everyone aboard counts this stop
	for _, p in Players:GetPlayers() do
		local c = self:CrewMember(p)
		if c and c.present then
			c.stops += 1
		end
		local profile = data:Get(p)
		if profile then
			profile.stats.stops += 1
			profile.visited[stop.key] = true
			profile.souvenirs[stop.key] = (profile.souvenirs[stop.key] or 0) + 1
		end
	end
	self.Arrived:Fire(stop, model)
end

function ExpeditionService:_scavenge()
	local t = train()
	local lampStage = t and t:Stage("lamp") or 0
	self:_set("scavenging", Formulas.scavengeSeconds(lampStage))
	if t then
		t:Doors("open")
	end
	local warnText = exp.fuel + 1e-6 < self:FuelCost() and " Fuel is low: bring back fuel cans!" or ""
	announce(`{exp.stop.name}. The doors are open for {Format.time(exp.phaseEnds - now())}. Be back before they close!{warnText}`, "chime")
	Net.fireAll("Sfx", "doors")
end

function ExpeditionService:_checkMilestones()
	local reached = Formulas.milestones(exp.distance)
	while exp.milestones < reached do
		exp.milestones += 1
		local km = exp.milestones * Constants.MILESTONE_KM
		announce(`Milestone: {km} km! Every crew member gets {Constants.MILESTONE_PARTS} parts.`, "milestone")
		Net.fireAll("Milestone", { km = km })
		for _, p in Players:GetPlayers() do
			local profile = data:Get(p)
			if profile and not self:InRecovery(p) then
				profile.storage.parts += Constants.MILESTONE_PARTS
				data:Push(p, { storage = profile.storage })
			end
		end
		self.Milestone:Fire(km)
	end
end

function ExpeditionService:_end(reason)
	exp.reason = reason
	exp.endedAt = os.time()
	exp.distance = Formulas.round1(self:Distance())
	clearPlaced()
	exp.stop = nil
	self:_light("travel")
	local t = train()
	if t then
		t:Doors("closed")
	end
	self:_set("ended", Constants.END_SECONDS)
	if reason == "fuel" then
		announce(`Out of fuel. The train coasts to a stop after {exp.distance} km. Back to the station...`, "final")
	end
	-- everyone's personal record
	for _, p in Players:GetPlayers() do
		local profile = data:Get(p)
		local c = exp.crew[p.UserId]
		if profile and c and Formulas.crewEligible(c.stops, now() - c.joinedAt) then
			profile.best = math.max(profile.best or 0, exp.distance)
			profile.stats.expeditions += 1
			table.insert(profile.records, 1, exp.id)
			while #profile.records > 10 do
				table.remove(profile.records)
			end
		end
	end
	self.Ended:Fire(exp)
end

function ExpeditionService:_tick()
	if not exp then
		return
	end
	local t = now()
	local phase = exp.phase
	-- crew time aboard
	for _, p in Players:GetPlayers() do
		local c = exp.crew[p.UserId]
		if c and c.present then
			c.seconds = now() - c.joinedAt
		end
	end
	if phase == "lobby" then
		if not exp.phaseEnds then
			self:_startLobbyTimer()
		elseif t >= exp.phaseEnds then
			self:_depart()
		elseif math.floor((exp.phaseEnds - t) * 4) % 4 == 0 then
			self:_boards()
		end
		return
	end
	if phase ~= "ended" and #Players:GetPlayers() == 0 then
		-- everyone left: the expedition ends where it is
		self:_end("empty")
		return
	end
	if phase == "departing" then
		if not exp.doorsShut and t >= exp.phaseStarted + Constants.DOORS_SHUT_AT then
			self:_shutDoors()
		end
		if t >= exp.phaseEnds then
			self:_leave()
		end
	elseif phase == "traveling" then
		if not exp.announcedNext and t >= exp.phaseStarted + Constants.TRAVEL_SECONDS / 2 then
			exp.announcedNext = true
			local t2 = train()
			local extra = ""
			if t2 and t2:Stage("lamp") >= 1 and exp.nextStop.rich then
				extra = " The searchlight shows " .. table.concat(exp.nextStop.rich, " and ") .. " ahead."
			end
			announce(`Next stop: {exp.nextStop.name}. {exp.nextStop.text}{extra}`, "chime")
			self:PushAll()
		end
		-- milestones can pass mid-trip (the crew board ticks)
		if math.floor(t * 2) % 4 == 0 then
			self:_boards()
		end
		if t >= exp.phaseEnds then
			self:_arrive()
		end
	elseif phase == "arriving" then
		if not exp.revealed and t >= exp.phaseEnds - Constants.ARRIVE_REVEAL then
			self:_reveal()
		end
		if t >= exp.phaseEnds then
			self:_scavenge()
		end
	elseif phase == "scavenging" then
		if exp.phaseEnds - t <= Constants.WARNING_AT then
			local ends = exp.phaseEnds
			self:_set("warning", nil)
			exp.phaseEnds = ends
			workspace:SetAttribute("PhaseEnds", ends)
			announce("One minute! Head back to the train.", "warning")
			Net.fireAll("Sfx", "warning")
			self:PushAll()
		end
	elseif phase == "warning" then
		if not exp.final and exp.phaseEnds - t <= Constants.FINAL_AT then
			exp.final = true
			workspace:SetAttribute("Final", true)
			announce("Final call! The doors are closing!", "final")
			Net.fireAll("Sfx", "horn")
			self:PushAll()
		end
		if t >= exp.phaseEnds then
			self:_depart()
		end
	elseif phase == "ended" then
		if t >= exp.phaseEnds then
			self:_begin()
		end
	end
end

-- Moving people ------------------------------------------------------------------------------------------------------
function ExpeditionService:Position(player)
	local c = player.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	return hrp and hrp.Position or nil
end

function ExpeditionService:InRecovery(player)
	local recovery = registryRef and registryRef.RecoveryService
	return recovery ~= nil and recovery:IsStranded(player)
end

local function pivot(player, cf)
	local c = player.Character
	if c and c:FindFirstChild("HumanoidRootPart") then
		c:PivotTo(cf)
		return true
	end
	return false
end

-- Where someone belongs right now: their cabin (if they have a bunk, or if `cabinAlways`), else the entry seats.
function ExpeditionService:HomeCf(player, cabinAlways)
	local cabins = registryRef.CabinService
	local cabin = cabins and cabins:CabinOf(player)
	local profile = data:Get(player)
	if cabin and (cabinAlways or (profile and profile.cabin.built.bunk)) then
		return cabin.insideCf
	end
	return Layout.ENTRY_CF
end

function ExpeditionService:SendHome(player, fade)
	if fade then
		Net.fire(player, "Fade", 0.8, "All aboard!")
	end
	return pivot(player, self:HomeCf(player, true))
end

-- Where a (re)spawning character goes.
function ExpeditionService:SpawnCf(player)
	if self:InRecovery(player) then
		return registryRef.RecoveryService:SpawnCf()
	end
	if self:Phase() == "lobby" and not player:GetAttribute("Boarded") then
		local jitter = Vector3.new(math.random(-12, 12), 0, math.random(-6, 6))
		return Layout.STATION_SPAWN + jitter
	end
	return self:HomeCf(player, false)
end

function ExpeditionService:Init(registry)
	registryRef = registry
	data = registry.PlayerDataService
	Net.on("GoCabin", function(player)
		local pos = self:Position(player)
		if not pos or self:InRecovery(player) then
			return
		end
		if not Layout.inTrain(pos) and not (self:Phase() == "lobby") then
			Net.fire(player, "Toast", "Get back on the train first!", "bad")
			return
		end
		Net.fire(player, "Fade", 0.5)
		pivot(player, self:HomeCf(player, true))
		player:SetAttribute("Boarded", true)
	end)
	Net.on("GoCar", function(player, key)
		local pos = self:Position(player)
		if type(key) ~= "string" or not pos or self:InRecovery(player) then
			return
		end
		if not Layout.inTrain(pos) and self:Phase() ~= "lobby" then
			Net.fire(player, "Toast", "Get back on the train first!", "bad")
			return
		end
		local cf = key == "engine" and Layout.ENGINE_ROOM_CF or key == "crew" and Layout.ENTRY_CF or nil
		if cf then
			Net.fire(player, "Fade", 0.5)
			pivot(player, cf)
			player:SetAttribute("Boarded", true)
		end
	end)
	data.ClientReady:Connect(function(player)
		self:Push(player)
	end)
	-- the train got the crew's view changes (upgrades, goal): refresh boards
	Players.PlayerRemoving:Connect(function(player)
		if exp and exp.crew[player.UserId] then
			exp.crew[player.UserId].present = false
		end
	end)
end

function ExpeditionService:OnPlayerReady(player)
	if not exp then
		return
	end
	local c = self:CrewMember(player)
	c.present = true
	local function place(character)
		task.defer(function()
			local hrp = character:WaitForChild("HumanoidRootPart", 5)
			if hrp and player.Parent then
				character:PivotTo(self:SpawnCf(player))
			end
		end)
	end
	player.CharacterAdded:Connect(place)
	if player.Character then
		place(player.Character)
	end
	if exp.phase == "lobby" then
		self:_startLobbyTimer()
	else
		player:SetAttribute("Boarded", true)
		-- a late joiner: a short summary of where the crew is
		data:WhenClientReady(player, function()
			local view = self:View()
			Net.fire(player, "Summary", {
				code = view.code,
				phase = view.phase,
				stop = view.stop and view.stop.name or nil,
				nextStop = view.nextStop and view.nextStop.name or nil,
				timeLeft = view.phaseEnds and math.max(0, view.phaseEnds - now()) or nil,
				distance = Formulas.round1(self:Distance()),
				nextMilestone = view.nextMilestone,
				fuel = view.fuel,
				cost = view.cost,
				goal = view.goal and view.goal.text or nil,
				crew = view.crew,
			})
		end)
	end
	self:Push(player)
end

function ExpeditionService:OnPlayerLeaving(player)
	if exp and exp.crew[player.UserId] then
		exp.crew[player.UserId].present = false
	end
end

function ExpeditionService:Start()
	self:_begin()
	while true do
		task.wait(0.2)
		local ok, err = pcall(self._tick, self)
		if not ok then
			warn("[ExpeditionService] tick failed: " .. tostring(err))
		end
	end
end

-- (tests) jump to the end of the current phase
function ExpeditionService:Skip()
	if exp then
		exp.phaseEnds = now()
		if exp.phase == "departing" then
			exp.phaseStarted = now() - Constants.DOORS_SECONDS
		elseif exp.phase == "traveling" then
			exp.phaseStarted = now() - Constants.TRAVEL_SECONDS
		end
	end
end

return ExpeditionService
