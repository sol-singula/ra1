--[[
The warehouse at work (master plan §13.1, §13.2; Data/Flow): once it stands, the farm's produce runs through four
stations and the slowest one sets the pace.

  intake   every tick brings the barn's crops in (Intake): they're palletised and the forklifts and trucks sell
           them by the load; it stops while Flow.INBOUND_MAX pallets' worth of crates are waiting
  pack     the lines box the crates at Flow.rates().pack; every Flow.PALLET of boxes is a pallet on the staging
           floor (packing stops while Flow.STAGE_MAX wait there)
  store    each forklift racks a pallet every Flow.cycle seconds, while there's a free slot
  semis    (stage 5) each semi comes in from the shared road for up to Flow.SEMI_CAP pallets (when there are half
           that, or after a while), backs up to its dock (5, 6), and pays when it's gone; every client drives it
  ship     each box truck takes up to Flow.truckCap pallets (when it can fill up, or when pallets have waited a
           while), makes its trip (World/Trips "truck", driven by every client) and pays when it's back:
           PALLET x SHIP_MULT a pallet, more with the sorter and the wrapper

Everything shows: a pallet on a rack slot for every pallet racked, pallets on the staging floor, crates waiting at
the lines, forklifts busy or parked, trucks out and back. The Operations screen out front and Net "Flow" show the
four rates and the bottleneck; buying the bottleneck's fix counts as a fix (stats.fixes).

profile.flow = { inbound (Cash of produce waiting), boxes (Cash boxed toward the next pallet), staged, racked,
fork (a forklift's progress), trucks = { [n] = { at, length, pallets } | false }, back = { [n] = t } }
Net "Flow" to the owner: { open, rates, bottleneck, full, racked, slots, staged, inbound, size, out }

  WarehouseService:Step(player, profile, dt)   the stations, for dt seconds
  WarehouseService:Rates(player) -> Flow.rates for them
  WarehouseService:Bottleneck(player) -> "grow" | "pack" | "store" | "ship" | nil
  WarehouseService:Intake(player) -> true when the warehouse took the basket (or is full and kept it)
  WarehouseService:Push(player)
  WarehouseService.Changed (player, what)  "pallet" | "racked" | "shipped" | "paid" | "fix"
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Flow = require(ReplicatedStorage.Shared.Data.Flow)
local Format = require(ReplicatedStorage.Shared.Format)
local FarmBuilder = require(ReplicatedStorage.Shared.World.FarmBuilder)
local Net = require(ReplicatedStorage.Shared.Net)
local PlotLayout = require(ReplicatedStorage.Shared.World.PlotLayout)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Trips = require(ReplicatedStorage.Shared.World.Trips)
local Upgrades = require(ReplicatedStorage.Shared.Data.Upgrades)

local WarehouseService = {
	Name = "WarehouseService",
	Dependencies = {
		"PlayerDataService",
		"EconomyService",
		"PlotService",
		"FarmService",
		"UpgradeService",
	},
	Changed = Signal.new("WarehouseService.Changed"),
	TICK = 0.5,
	WAIT = 15, -- seconds a truck waits for a full load before it goes with what there is
	SEMI_WAIT = 30, -- ...and a semi, for half a load
	MAX_STEP = 5, -- seconds one tick may catch up (the long gaps are Phase G's offline earnings)
}

local data, economy, plots, farm, upgrades, analytics
local shown = {} -- [player] = { racked, staged, inbound, busy, screen }: what the world shows now
local refs = {} -- [player] = { rack = { pallet models in fill order }, staged = {}, inbound = {}, forklifts = {} }
local lastAt = {} -- [player] = when the stations last ran
local bottleneck = {} -- [player] = the last bottleneck (for counting fixes)
local pushed = {} -- [player] = the last Net "Flow" key
local semis = {} -- [player] = { [n] = the semi on its trip }
local hideSemi

local function now()
	return workspace:GetServerTimeNow()
end

local function opened(p)
	return p.owned and p.owned.warehouse ~= nil
end

local function flowOf(p)
	p.flow = p.flow or {}
	local f = p.flow
	f.inbound = f.inbound or 0
	f.boxes = f.boxes or 0
	f.staged = f.staged or 0
	f.racked = f.racked or 0
	f.fork = f.fork or 0
	f.trucks = f.trucks or {}
	f.back = f.back or {}
	return f
end

function WarehouseService:Rates(player)
	local p = data:Get(player)
	return p and Flow.rates(p, now()) or nil
end

function WarehouseService:Bottleneck(player)
	local p = data:Get(player)
	return p and opened(p) and Flow.rates(p, now()).bottleneck or nil
end

-- The world's pieces -------------------------------------------------------------------------------------------------
local function gather(player)
	local plot = plots:Plot(player)
	if not plot then
		return nil
	end
	local r = { rack = {}, staged = {}, inbound = {}, forklifts = {}, trucks = {} }
	for _, d in plot.items:GetDescendants() do
		if d.Name == "RackPallet" then
			table.insert(r.rack, d)
		elseif d.Name == "Staged" and d:IsA("Model") then
			r.staged[d:GetAttribute("Slot")] = d
		elseif (d.Name == "Inbound" or d.Name == "InboundFruit") and d:IsA("BasePart") then
			table.insert(r.inbound, d)
		elseif d.Name == "Forklift" and d:IsA("Model") then
			table.insert(r.forklifts, d)
		elseif d.Name == "Vehicle" and d:GetAttribute("Kind") == "truck" then
			r.trucks[d:GetAttribute("Park")] = d
		elseif d.Name == "OpsScreen" then
			r.screen = d
		end
	end
	-- (racks fill row by row, bottom level first, along the row)
	table.sort(r.rack, function(a, b)
		local ra, rb = a:GetAttribute("Row"), b:GetAttribute("Row")
		if ra ~= rb then
			return ra < rb
		end
		return a:GetAttribute("Slot") < b:GetAttribute("Slot")
	end)
	refs[player] = r
	shown[player] = {}
	return r
end

local function showModel(m, on)
	for _, part in m:GetDescendants() do
		if part:IsA("BasePart") then
			part.Transparency = on and 0 or 1
		end
	end
end

local function paintWorld(player, p, rates)
	local r = refs[player] or gather(player)
	if not r then
		return
	end
	local f = flowOf(p)
	local s = shown[player]
	if s.racked ~= f.racked then
		local from, to = 1, #r.rack
		if s.racked then
			from, to = math.min(s.racked, f.racked) + 1, math.min(math.max(s.racked, f.racked), #r.rack)
		end
		for i = from, to do
			showModel(r.rack[i], i <= f.racked)
		end
		s.racked = f.racked
	end
	if s.staged ~= f.staged then
		for i, m in r.staged do
			showModel(m, i <= f.staged)
		end
		s.staged = f.staged
	end
	local crates = math.min(8, math.ceil(f.inbound / (Flow.INBOUND_MAX * Flow.PALLET) * 8 - 0.001))
	if s.inbound ~= crates then
		for _, part in r.inbound do
			part.Transparency = (part:GetAttribute("Slot") or 99) <= crates and 0 or 1
		end
		s.inbound = crates
	end
	local busy = f.staged > 0 and f.racked < rates.slots
	if s.busy ~= busy or s.forks ~= #r.forklifts then
		local speed = 1 + Upgrades.stat(p.owned or {}, "forkSpeed", 0)
		for _, m in r.forklifts do
			m:SetAttribute("Busy", busy)
			m:SetAttribute("Speed", speed)
			m:SetAttribute("Rows", Flow.rows(p.owned))
		end
		s.busy, s.forks = busy, #r.forklifts
	end
	-- the Operations screen
	if r.screen then
		local rows = {}
		for _, st in Flow.STATIONS do
			table.insert(rows, {
				name = st.name,
				rate = rates[st.key],
				label = Format.num(rates[st.key]),
				red = rates.bottleneck == st.key,
			})
		end
		local line = rates.full and "RACKS FULL!" or "BOTTLENECK: " .. string.upper(rates.bottleneck)
		local key = line
		for _, row in rows do
			key ..= row.label
		end
		if s.screen ~= key then
			s.screen = key
			FarmBuilder.opsScreen(r.screen, rows, line)
		end
	end
end

-- Trucks ---------------------------------------------------------------------------------------------------------------
local function truckModel(player, n)
	local r = refs[player] or gather(player)
	local m = r and r.trucks[n]
	if m and not m.Parent then
		r = gather(player)
		m = r and r.trucks[n]
	end
	return m
end

local function startTrip(player, n, trip)
	local m = truckModel(player, n)
	if m then
		m:SetAttribute("Trip", "truck")
		m:SetAttribute("TripStart", trip.at)
		m:SetAttribute("TripLength", trip.length)
	end
end

local function endTrip(player, n)
	local m = truckModel(player, n)
	if m then
		m:SetAttribute("Trip", nil)
		m:SetAttribute("TripStart", nil)
		m:SetAttribute("TripLength", nil)
	end
end

local function pay(player, p, trip)
	local bonus = Upgrades.stat(p.owned or {}, "deliveryPrice", 0)
	local cash = math.floor(trip.pallets * Flow.PALLET * Flow.SHIP_MULT * (1 + bonus) + 0.5)
	economy:Add(player, cash, "pallets")
	economy:AddXP(player, math.max(2, trip.pallets * 4), "pallets")
	p.stats.palletsShipped = (p.stats.palletsShipped or 0) + trip.pallets
	p.stats.truckTrips = (p.stats.truckTrips or 0) + 1
	p.stats.biggestShipment = math.max(p.stats.biggestShipment or 0, cash)
	if analytics then
		pcall(analytics.event, player, "truck", { pallets = trip.pallets, cash = cash })
	end
	WarehouseService.Changed:Fire(player, "paid")
	return cash
end

-- A semi on its trip: made when it sets off (it comes from the road, it doesn't live on the plot), gone when it's done
local function showSemi(player, n, trip)
	local plot = plots:Plot(player)
	if not plot then
		return
	end
	semis[player] = semis[player] or {}
	local m = semis[player][n]
	if not m or not m.Parent then
		local dock = Vector3.new(PlotLayout.SPOTS.docks[4 + n] or PlotLayout.SPOTS.docks[5], 0, 62)
		m = FarmBuilder.vehicle(plot.items, "semi", plot.color, (Trips.at(plot.index, "semi", 0, dock)))
		m:SetAttribute("Plot", plot.index)
		m:SetAttribute("Plan", "semi")
		m:SetAttribute("ParkAt", dock)
		semis[player][n] = m
	end
	m:SetAttribute("Trip", "semi")
	m:SetAttribute("TripStart", trip.at)
	m:SetAttribute("TripLength", trip.length)
end

hideSemi = function(player, n)
	local m = semis[player] and semis[player][n]
	if m then
		m:Destroy()
		semis[player][n] = nil
	end
end

-- The stations ---------------------------------------------------------------------------------------------------------
function WarehouseService:Step(player, p, dt)
	if not opened(p) then
		return false
	end
	local f = flowOf(p)
	local t = now()
	local rates = Flow.rates(p, t)
	local owned = p.owned
	local changed = false
	-- pack: crates into boxes, boxes into pallets on the staging floor
	if f.staged < Flow.STAGE_MAX and f.inbound > 0 then
		local amount = math.min(f.inbound, rates.pack / 60 * dt)
		f.inbound -= amount
		f.boxes += amount
		changed = true
	end
	while f.boxes >= Flow.PALLET and f.staged < Flow.STAGE_MAX do
		f.boxes -= Flow.PALLET
		f.staged += 1
		p.stats.pallets = (p.stats.pallets or 0) + 1
		self.Changed:Fire(player, "pallet")
	end
	-- store: the forklifts rack what's staged
	local forks = Flow.forklifts(owned)
	f.fork = math.min(f.fork + forks * dt / Flow.cycle(owned), forks)
	while f.fork >= 1 and f.staged > 0 and f.racked < rates.slots do
		f.fork -= 1
		f.staged -= 1
		f.racked += 1
		p.stats.racked = (p.stats.racked or 0) + 1
		changed = true
		self.Changed:Fire(player, "racked")
	end
	-- ship: trucks home pay; trucks free take a load
	local cap = Flow.truckCap(owned)
	for n = 1, Flow.trucks(owned) do
		local key = tostring(n)
		local trip = f.trucks[key]
		if trip and t >= trip.at + trip.length then
			pay(player, p, trip)
			f.trucks[key] = false
			f.back[key] = t
			endTrip(player, n)
			trip = nil
			changed = true
		end
		if not trip and f.racked > 0 and (f.racked >= cap or t - (f.back[key] or 0) >= self.WAIT) then
			local take = math.min(cap, f.racked)
			f.racked -= take
			trip = { at = t, length = Flow.trip(owned, p), pallets = take }
			f.trucks[key] = trip
			startTrip(player, n, trip)
			changed = true
			self.Changed:Fire(player, "shipped")
		end
	end
	-- the semis (stage 5): in from the road for a big load, away again; they pay when they're gone
	for n = 1, Flow.semis(owned) do
		local key = "s" .. n
		local trip = f.trucks[key]
		if trip and t >= trip.at + trip.length then
			pay(player, p, trip)
			p.stats.semis = (p.stats.semis or 0) + 1
			f.trucks[key] = false
			f.back[key] = t
			hideSemi(player, n)
			trip = nil
			changed = true
		end
		local half = Flow.SEMI_CAP / 2
		if not trip and f.racked > 0 and (f.racked >= half or t - (f.back[key] or 0) >= self.SEMI_WAIT) then
			local take = math.min(Flow.SEMI_CAP, f.racked)
			f.racked -= take
			trip = { at = t, length = Flow.semiTrip(owned, p), pallets = take }
			f.trucks[key] = trip
			showSemi(player, n, trip)
			changed = true
			self.Changed:Fire(player, "semi")
		end
	end
	-- the bottleneck moved: the station pads repaint
	if bottleneck[player] ~= rates.bottleneck then
		bottleneck[player] = rates.bottleneck
		task.defer(upgrades.Paint, upgrades, player)
	end
	paintWorld(player, p, rates)
	return changed
end

-- Every tick: the barn's crops into the warehouse's crates
function WarehouseService:Intake(player)
	local p = data:Get(player)
	if not p or not opened(p) then
		return false
	end
	local f = flowOf(p)
	if f.inbound >= Flow.INBOUND_MAX * Flow.PALLET then
		return true -- (full: the basket waits, and the bottleneck shows it)
	end
	local bag = farm:Excess(player)
	local value = farm:Worth(player, bag)
	if value <= 0 then
		return true
	end
	for key, n in bag do
		farm:Remove(player, key, n)
	end
	f.inbound += value
	p.stats.intake = (p.stats.intake or 0) + value
	farm:Push(player)
	return true
end

function WarehouseService:Push(player)
	local p = data:Get(player)
	if not p then
		return
	end
	local f = flowOf(p)
	local rates = Flow.rates(p, now())
	local out = 0
	for _, trip in f.trucks do
		if trip then
			out += 1
		end
	end
	local msg = {
		open = opened(p),
		rates = { grow = rates.grow, pack = rates.pack, store = rates.store, ship = rates.ship },
		bottleneck = rates.bottleneck,
		full = rates.full == true,
		racked = f.racked,
		slots = rates.slots,
		staged = f.staged,
		inbound = math.floor(f.inbound / Flow.PALLET * 10) / 10,
		size = Flow.size(p),
		out = out,
	}
	local key = table.concat({
		tostring(msg.open),
		msg.bottleneck,
		msg.racked,
		msg.staged,
		msg.inbound,
		msg.size,
		out,
		rates.grow,
		rates.pack,
		rates.store,
		rates.ship,
	}, "|")
	if pushed[player] == key then
		return
	end
	pushed[player] = key
	Net.fire(player, "Flow", msg)
end

function WarehouseService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	plots = registry.PlotService
	farm = registry.FarmService
	upgrades = registry.UpgradeService
	analytics = registry.AnalyticsService
	upgrades.Applied:Connect(function(player, u)
		if u.stage >= 4 then
			refs[player] = nil
			shown[player] = nil
			local p = data:Get(player)
			if p and opened(p) then
				-- (a truck or a semi out when they left: it shows its trip again)
				for key, trip in flowOf(p).trucks do
					if trip and string.sub(key, 1, 1) == "s" then
						showSemi(player, tonumber(string.sub(key, 2)), trip)
					elseif trip then
						startTrip(player, tonumber(key), trip)
					end
				end
			end
		end
	end)
	upgrades.Bought:Connect(function(player, u)
		local p = data:Get(player)
		if p and u.track and bottleneck[player] == u.track then
			p.stats.fixes = (p.stats.fixes or 0) + 1
			Net.fire(player, "Toast", "BOTTLENECK FIXED! Watch where it moves next", "good")
			self.Changed:Fire(player, "fix")
		end
		if p and u.key == "warehouse" then
			lastAt[player] = now()
		end
	end)
	-- (forget them when they leave, or when their plot comes down for a rebuild: a franchise)
	local function forget(player)
		shown[player], refs[player], lastAt[player], bottleneck[player], pushed[player] = nil, nil, nil, nil, nil
		semis[player] = nil
	end
	Players.PlayerRemoving:Connect(forget)
	registry.PlotService.Released:Connect(forget)
end

function WarehouseService:OnPlayerReady(player)
	lastAt[player] = now()
	data:WhenClientReady(player, function()
		pushed[player] = nil
		self:Push(player)
	end)
end

function WarehouseService:_tick()
	local t = now()
	for _, player in Players:GetPlayers() do
		local p = data:Get(player)
		if p and opened(p) then
			local dt = math.clamp(t - (lastAt[player] or t), 0, self.MAX_STEP)
			lastAt[player] = t
			self:Intake(player)
			self:Step(player, p, dt)
			self:Push(player)
		end
	end
end

function WarehouseService:Start()
	while true do
		task.wait(self.TICK)
		local ok, err = pcall(self._tick, self)
		if not ok then
			warn("[WarehouseService] tick failed: " .. tostring(err))
		end
	end
end

return WarehouseService
