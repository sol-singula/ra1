-- Records: how far every crew got, kept forever, and the best of them in the station's Hall of Records.
--   * The server alone decides a record: the distance it committed (whole trips only), the crew it saw, what each
--     of them did. Nothing comes from a client.
--   * Each expedition has a unique id, and a record is written under that id (an OrderedDataStore for the ranking,
--     a DataStore for the details), so a retry or a second write never makes a duplicate. A record never shrinks.
--   * It's written at every stop once the crew has gone 5 km (so a crash keeps what was safely reached), at the end,
--     and when the server shuts down.
--   * A full crew member was aboard for CREW_MIN_STOPS stops or CREW_MIN_SECONDS (Formulas.crewEligible): they're on
--     the record by name. Everyone else who helped is counted as a helper.
--   * The crew owns the record. Individual recognition is for helping: most fuel brought back, most materials given,
--     blueprints found, and coming back after being left behind. Nobody is ranked against their crewmates.
-- The Hall: the top record's stage (World/HallBuilder) and four plaques, refreshed every few minutes; clients get
-- the list for the HALL panel ("Hall"). If DataStores are off (Studio), this server's own records still show.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Stops = require(ReplicatedStorage.Shared.Data.Stops)
local HallBuilder = require(script.Parent.Parent.World.HallBuilder)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local RecordService = {
	Name = "RecordService",
	Dependencies = { "PlayerDataService", "ExpeditionService", "TrainService" },
	Saved = Signal.new("RecordService.Saved"), -- (record, final)
	NewTop = Signal.new("RecordService.NewTop"), -- (record, rank) a record made the Hall
}

local REFRESH_SECONDS = 300
local RECOGNITION = { "fuel", "materials", "blueprints", "recovered" }
local CHECKPOINT_KM = 5
local SCHEMA = 1

local data, expedition, train
local ranking, details -- the stores (nil when DataStores are off)
local hall = {} -- the top records, best first
local localRecords = {} -- [id] = record: this server's own, so the Hall works without DataStores
local cache = {} -- [id] = record (details read from the store)
local lastRefresh = -math.huge
local loadedOnce = false

local function retry(fn)
	for attempt = 1, 3 do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		if attempt < 3 then
			task.wait(attempt * 2)
		end
	end
	return false
end

-- Build the record of an expedition from what the server saw.
function RecordService:Build(exp, final)
	local now = workspace:GetServerTimeNow()
	local full, helpers = {}, 0
	local best = {} -- [kind] = { userId, name, amount }: who did the most of each kind of helping
	for _, c in exp.crew do
		local seconds = c.seconds or (now - (c.joinedAt or now))
		if Formulas.crewEligible(c.stops or 0, seconds) then
			table.insert(full, {
				userId = c.userId,
				name = c.name,
				display = c.display,
				stops = c.stops,
				fuel = c.fuel,
				materials = c.materials,
				blueprints = c.blueprints,
				recovered = c.recovered,
			})
		elseif (c.fuel or 0) + (c.materials or 0) + (c.blueprints or 0) > 0 or (c.stops or 0) > 0 then
			helpers += 1
		end
		for _, kind in RECOGNITION do
			local v = c[kind] or 0
			if v > 0 and (not best[kind] or v > best[kind].amount) then
				best[kind] = { userId = c.userId, name = c.display or c.name, amount = Formulas.round1(v) }
			end
		end
	end
	-- the longest-serving first (they're the statues on the stage)
	table.sort(full, function(a, b)
		if (a.stops or 0) ~= (b.stops or 0) then
			return (a.stops or 0) > (b.stops or 0)
		end
		return (a.userId or 0) < (b.userId or 0)
	end)
	while #full > Constants.MAX_PLAYERS do
		table.remove(full)
	end
	local stages = train:Stages()
	return {
		schema = SCHEMA,
		id = exp.id,
		code = exp.code,
		km = Formulas.round1(exp.distance), -- committed distance: whole trips only
		stops = exp.stops,
		route = table.clone(exp.route),
		milestones = exp.milestones,
		region = Stops.REGION,
		startedAt = exp.startedAt,
		endedAt = final and (exp.endedAt or os.time()) or nil,
		updatedAt = os.time(),
		seconds = exp.startedAt and (os.time() - exp.startedAt) or 0,
		crew = full,
		helpers = helpers,
		recognition = best,
		train = { engine = stages.engine, lamp = stages.lamp },
		reason = exp.reason,
		live = not final,
		placeVersion = game.PlaceVersion,
	}
end

-- Is this expedition worth a record? At least one trip and someone who was properly part of it.
function RecordService:Eligible(record)
	return record.km >= Constants.SEGMENT_KM - 1e-6 and #record.crew > 0
end

-- Write a record (idempotent: same id, and the stored one is only replaced by a longer or final one).
function RecordService:Save(record)
	localRecords[record.id] = record
	cache[record.id] = record
	local saved = false
	if details and ranking then
		local ok = retry(function()
			details:UpdateAsync(record.id, function(old)
				if old and (old.km or 0) > record.km + 1e-6 then
					return nil -- never shrink a record
				end
				if old and old.live == false and record.live then
					return nil -- a final record stays final
				end
				return record
			end)
		end)
		if ok then
			ok = retry(function()
				ranking:SetAsync(record.id, math.floor(record.km * 10 + 0.5))
			end)
		end
		saved = ok
		if not ok then
			warn("[RecordService] couldn't save record " .. record.id)
		end
	end
	self.Saved:Fire(record, not record.live)
	return saved
end

-- The expedition so far (at a stop, once it's gone CHECKPOINT_KM).
function RecordService:Checkpoint()
	local exp = expedition:State()
	if not exp or exp.distance < CHECKPOINT_KM - 1e-6 then
		return false
	end
	local record = self:Build(exp, false)
	if not self:Eligible(record) then
		return false
	end
	task.spawn(function()
		self:Save(record)
		self:Refresh(true)
	end)
	return true
end

function RecordService:Finish(exp)
	local record = self:Build(exp, true)
	if not self:Eligible(record) then
		return nil
	end
	task.spawn(function()
		self:Save(record)
		self:Refresh(true)
	end)
	return record
end

-- The top records: from the stores (with details cached) merged with this server's own.
function RecordService:_load()
	local list, seen = {}, {}
	if ranking and details then
		local ok, page = retry(function()
			return ranking:GetSortedAsync(false, Constants.HALL_RECORDS):GetCurrentPage()
		end)
		if ok and page then
			for _, entry in page do
				local rec = cache[entry.key]
				if not rec then
					local ok2, value = pcall(details.GetAsync, details, entry.key)
					if ok2 and type(value) == "table" then
						rec = value
						cache[entry.key] = rec
					end
				end
				if rec and not seen[rec.id] then
					seen[rec.id] = true
					table.insert(list, rec)
				end
			end
		end
	end
	for id, rec in localRecords do
		if not seen[id] then
			seen[id] = true
			table.insert(list, rec)
		end
	end
	table.sort(list, function(a, b)
		if (a.km or 0) ~= (b.km or 0) then
			return (a.km or 0) > (b.km or 0)
		end
		return (a.updatedAt or 0) < (b.updatedAt or 0) -- the first crew to get there keeps the place
	end)
	while #list > Constants.HALL_RECORDS do
		table.remove(list)
	end
	-- a record that stopped updating long ago belongs to a server that's gone: it isn't on the line any more
	for _, rec in list do
		if rec.live and os.time() - (rec.updatedAt or 0) > 600 then
			rec.live = false
		end
	end
	return list
end

-- What clients get for the HALL panel (small: names, not the whole crew data).
local function brief(rec, rank)
	local crew = {}
	for i, m in rec.crew or {} do
		if i > 12 then
			break
		end
		table.insert(crew, { userId = m.userId, name = m.display or m.name })
	end
	local rec2 = {}
	for kind, v in rec.recognition or {} do
		if type(v) == "table" then
			rec2[kind] = { name = v.name, amount = v.amount }
		end
	end
	return {
		rank = rank,
		id = rec.id,
		code = rec.code,
		km = rec.km,
		stops = rec.stops,
		seconds = rec.seconds,
		at = rec.endedAt or rec.updatedAt,
		crew = crew,
		crewCount = #(rec.crew or {}),
		helpers = rec.helpers,
		recognition = rec2,
		train = rec.train,
		live = rec.live == true,
		route = rec.route,
	}
end

function RecordService:View()
	local out = {}
	for i, rec in hall do
		table.insert(out, brief(rec, i))
	end
	return out
end

function RecordService:Push(player)
	local view = {
		records = self:View(),
		rule = `Full crew: aboard for {Constants.CREW_MIN_STOPS} stops or {math.floor(Constants.CREW_MIN_SECONDS / 60)} minutes.`,
	}
	if player then
		Net.fire(player, "Hall", view)
	else
		Net.fireAll("Hall", view)
	end
end

-- Redraw the station's Hall from the current top list.
function RecordService:Draw()
	local station = WorldBuilder.layout and WorldBuilder.layout.station
	local h = station and station.hall
	if not h then
		return
	end
	HallBuilder.top(h.top, hall[1])
	for i, label in h.plaques do
		label.Text = HallBuilder.plaqueText(i + 1, hall[i + 1])
	end
end

function RecordService:Refresh(force)
	if not force and os.clock() - lastRefresh < 20 then
		return
	end
	lastRefresh = os.clock()
	local before = {}
	for i, rec in hall do
		before[rec.id] = i
	end
	hall = self:_load()
	-- a record that just made the Hall, or just took first place (not on the first load)
	if loadedOnce then
		for i, rec in hall do
			local was = before[rec.id]
			if was == nil or (i == 1 and was ~= 1) then
				self.NewTop:Fire(rec, i)
			end
		end
	end
	loadedOnce = true
	self:Draw()
	self:Push()
end

function RecordService:Hall()
	return hall
end

function RecordService:Init(registry)
	data = registry.PlayerDataService
	expedition = registry.ExpeditionService
	train = registry.TrainService
	local ok1, r = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, Constants.RECORD_STORE)
	local ok2, d = pcall(DataStoreService.GetDataStore, DataStoreService, Constants.RECORD_DETAILS)
	ranking = ok1 and r or nil
	details = ok2 and d or nil
	expedition.Arrived:Connect(function()
		self:Checkpoint()
	end)
	expedition.Ended:Connect(function(exp)
		local record = self:Finish(exp)
		if record then
			-- a short summary for everyone aboard, and the place it took (if it made the Hall)
			Net.fireAll(
				"Toast",
				`Expedition #{record.code} is in the records: {record.km} km, {record.stops} stops, {#record.crew} crew.`,
				"good"
			)
		end
	end)
	data.ClientReady:Connect(function(player)
		self:Push(player)
	end)
	-- "Inspect" on every plaque opens the HALL panel at that record (PromptController)
	local station = WorldBuilder.layout and WorldBuilder.layout.station
	if station and station.hall then
		local function inspect(label, rank)
			local part = label.Parent and label.Parent.Parent
			if part and part:IsA("BasePart") then
				local p = Instance.new("ProximityPrompt")
				p.Name = "Prompt_record"
				p.ActionText = "Inspect"
				p.ObjectText = rank == 1 and "The longest journey" or `Record #{rank}`
				p.HoldDuration = 0
				p.MaxActivationDistance = 22
				p.RequiresLineOfSight = false
				p:SetAttribute("Rank", rank)
				p.Parent = part
			end
		end
		inspect(station.hall.top.plaque, 1)
		for i, label in station.hall.plaques do
			inspect(label, i + 1)
		end
	end
	-- the server is closing: the expedition so far goes in the records
	pcall(function()
		game:BindToClose(function()
			local exp = expedition:State()
			if exp and exp.phase ~= "lobby" and exp.phase ~= "ended" then
				local record = self:Build(exp, false)
				if self:Eligible(record) then
					self:Save(record)
				end
			end
		end)
	end)
end

function RecordService:Start()
	self:Refresh(true)
	while true do
		task.wait(REFRESH_SECONDS)
		if #Players:GetPlayers() > 0 then
			self:Refresh(true)
		end
	end
end

-- (tests)
function RecordService:_forget()
	localRecords = {}
	cache = {}
	hall = {}
end

return RecordService
