--[[
Deliveries (stage 3, the Delivery Shed): each van takes a load of crops out of the barn, drives off (World/Trips
"van", driven by every client) and pays MULT times the stand's price when it's back. A second way to sell, on top
of the customers, that pays more: the shed's upgrades make the vans carry more (vanLoad), pay more (deliveryPrice)
and go quicker (tripCut).

profile.delivery = { trips = { [n] = { at, length, cash, n } } }   (a trip under way pays when it's done, even if
they were away)

  DeliveryService:Vans(player)   how many vans they have (0 before the shed and the first van)
  DeliveryService:Load(player)   crops a van takes
  DeliveryService:Step(player)   one tick (tests call it)
  DeliveryService.Changed (player, what)   "out" | "paid"
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Crops = require(ReplicatedStorage.Shared.Data.Crops)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Upgrades = require(ReplicatedStorage.Shared.Data.Upgrades)

local DeliveryService = {
	Name = "DeliveryService",
	Dependencies = { "PlayerDataService", "EconomyService", "FarmService", "PlotService" },
	Changed = Signal.new("DeliveryService.Changed"),
	MULT = 3, -- a delivery pays this many times the stand
	LOAD = 40, -- crops a van takes (x "vanLoad")
	WAIT = 30, -- seconds a van waits for a full load before it goes with what there is
	TICK = 1,
}

local data, economy, farm, plots, analytics
local waiting = {} -- [player] = { [n] = since }

local function now()
	return workspace:GetServerTimeNow()
end

local function tripsOf(p)
	p.delivery = p.delivery or { trips = {} }
	p.delivery.trips = p.delivery.trips or {}
	return p.delivery.trips
end

function DeliveryService:Vans(player)
	local p = data:Get(player)
	if not p or not (p.owned and p.owned.shed and p.owned.van) then
		return 0
	end
	return Upgrades.stat(p.owned, "vans", 1)
end

function DeliveryService:Load(player)
	local p = data:Get(player)
	return self.LOAD * Upgrades.stat(p and p.owned or {}, "vanLoad", 1)
end

function DeliveryService:Trip(player)
	local p = data:Get(player)
	local owned = p and p.owned or {}
	return Upgrades.stat(owned, "van", 20) * (1 - Upgrades.stat(owned, "tripCut", 0))
end

local function vanModel(player, n)
	local plot = plots:Plot(player)
	if not plot then
		return nil
	end
	for _, key in { "van", "van2" } do
		local folder = plot.items:FindFirstChild(key)
		local model = folder and folder:FindFirstChild("Vehicle")
		if model and (model:GetAttribute("Park") or 1) == n then
			return model
		end
	end
	return nil
end

local function showTrip(player, n, trip)
	local model = vanModel(player, n)
	local plot = plots:Plot(player)
	if model and plot then
		model:SetAttribute("Trip", "van")
		model:SetAttribute("TripStart", trip and trip.at or nil)
		model:SetAttribute("TripLength", trip and trip.length or nil)
		model:SetAttribute("Plot", plot.index)
		if not trip then
			model:SetAttribute("Trip", nil)
		end
	end
end

-- The dearest crops first, up to the load
local function takeLoad(player, load)
	local have = farm:Excess(player)
	local keys = {}
	for key, k in have do
		if k > 0 and Crops[string.gsub(key, "^%*", "")] then
			table.insert(keys, key)
		end
	end
	table.sort(keys, function(a, b)
		return Crops[string.gsub(a, "^%*", "")].value > Crops[string.gsub(b, "^%*", "")].value
	end)
	local bag, n = {}, 0
	for _, key in keys do
		local k = math.min(load - n, have[key])
		if k > 0 then
			bag[key] = k
			n += k
		end
		if n >= load then
			break
		end
	end
	return bag, n
end

function DeliveryService:Step(player)
	local p = data:Get(player)
	local vans = self:Vans(player)
	if not p or vans == 0 then
		return
	end
	local trips = tripsOf(p)
	local t = now()
	local load = self:Load(player)
	local stock = 0
	for _, k in farm:Excess(player) do
		stock += k
	end
	waiting[player] = waiting[player] or {}
	for n = 1, vans do
		local trip = trips[tostring(n)]
		if trip then
			if t >= trip.at + trip.length then
				trips[tostring(n)] = nil
				economy:Add(player, trip.cash, "delivery")
				economy:AddXP(player, math.max(2, math.floor(trip.n / 4)), "delivery")
				p.stats.deliveries = (p.stats.deliveries or 0) + 1
				p.stats.delivered = (p.stats.delivered or 0) + trip.n
				showTrip(player, n, nil)
				Net.fire(player, "Toast", `Van {n} delivered {trip.n} crops: +{Format.cash(trip.cash)}!`, "good")
				if analytics then
					pcall(analytics.event, player, "delivery", { cash = trip.cash, n = trip.n })
				end
				self.Changed:Fire(player, "paid")
			else
				showTrip(player, n, trip)
			end
		else
			local since = waiting[player][n] or t
			waiting[player][n] = since
			if stock >= load or (stock > 0 and t - since >= self.WAIT) then
				local bag, k = takeLoad(player, load)
				if k > 0 then
					local cash = math.floor(
						farm:Worth(player, bag) * self.MULT * (1 + Upgrades.stat(p.owned, "deliveryPrice", 0)) + 0.5
					)
					for key, c in bag do
						farm:Remove(player, key, c)
					end
					stock -= k
					trips[tostring(n)] = { at = t, length = self:Trip(player), cash = cash, n = k }
					waiting[player][n] = nil
					showTrip(player, n, trips[tostring(n)])
					farm:Push(player)
					self.Changed:Fire(player, "out")
				end
			end
		end
	end
end

function DeliveryService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	farm = registry.FarmService
	plots = registry.PlotService
	analytics = registry.AnalyticsService
	Players.PlayerRemoving:Connect(function(player)
		waiting[player] = nil
	end)
end

function DeliveryService:Start()
	task.spawn(function()
		while true do
			task.wait(self.TICK)
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(self.Step, self, player)
				if not ok then
					warn("[DeliveryService] " .. tostring(err))
				end
			end
		end
	end)
end

return DeliveryService
