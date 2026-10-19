--[[
The business (master plan §6, §12 layer A: the real economy). The stage (stand, shop, warehouse, centre) sets the
base numbers; the upgrades add to them. Every second, per player:

  the store sells   min(demand, service, stock) units a minute at the counter: the customers' money
  the docks send    dispatch units a minute in bulk at bulkPrice (warehouse and up): the trucks' money
  the queue grows   when demand is more than the counters can serve (the visible line)

and the bottleneck is worked out from the same numbers: the one thing most in the way right now.

  BusinessService:Store(player, crop, n)   put units in stock; false when full
  BusinessService:Stock(player)            units in stock, all crops
  BusinessService:Capacity(player)
  BusinessService:Numbers(player)          { demand, service, dispatch, storage, ... } a minute
  BusinessService:Bottleneck(player)       "harvest" | "service" | "demand" | "production" | "dispatch"
  BusinessService:Full(player)             the stock area is full (the machines wait)
  BusinessService:SetStage(player, key)
  BusinessService:Push(player)
  BusinessService.Changed (player, what)   "sale" | "truck" | "stage"
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animals = require(ReplicatedStorage.Shared.Data.Animals)
local Business = require(ReplicatedStorage.Shared.Data.Business)
local Crops = require(ReplicatedStorage.Shared.Data.Crops)
local Layout = require(ReplicatedStorage.Shared.World.Layout)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Upgrades = require(ReplicatedStorage.Shared.Data.Upgrades)

local BusinessService = {
	Name = "BusinessService",
	Dependencies = { "PlayerDataService", "EconomyService" },
	Changed = Signal.new("BusinessService.Changed"),
	TICK = 1,
	TRUCK_LOAD = 100, -- units a truck takes
	QUEUE_MAX = 12,
}

local data, economy, boosts, crops, analytics, territory, automation
local live = {} -- [player] = { sellAcc, dispAcc, queue, sold = {{t,n}}, lastPush, bottleneck, since }

local function state(player)
	local s = live[player]
	if not s then
		s = { sellAcc = 0, dispAcc = 0, queue = 0, sold = {}, trucks = 0, bottleneck = "none", since = 0 }
		live[player] = s
	end
	return s
end

local function now()
	return workspace:GetServerTimeNow()
end

function BusinessService:Stock(player)
	local p = data:Get(player)
	local n = 0
	for _, k in p and p.stock or {} do
		n += k
	end
	return n
end

function BusinessService:Capacity(player)
	local p = data:Get(player)
	if not p then
		return 0
	end
	return Business[p.stage].storage + Upgrades.stat(p.owned, "storage", 0)
end

function BusinessService:Store(player, crop, n)
	local p = data:Get(player)
	if not p or self:Stock(player) + n > self:Capacity(player) then
		return false
	end
	p.stock[crop] = (p.stock[crop] or 0) + n
	return true
end

-- Take n units out, the crop with the most stock first: returns units taken and their value at the counter
local function take(p, n)
	local taken, value = 0, 0
	local mult = Upgrades.priceMult(p.owned) * (1 + Animals.boost(p, "price", os.time()))
	while taken < n do
		local best, bestN
		for key, k in p.stock do
			if k > 0 and (not bestN or k > bestN) then
				best, bestN = key, k
			end
		end
		if not best then
			break
		end
		local k = math.min(n - taken, bestN)
		p.stock[best] = bestN - k
		if p.stock[best] == 0 then
			p.stock[best] = nil
		end
		taken += k
		value += k * (Crops[best] and Crops[best].value or 1) * mult
	end
	return taken, value
end

function BusinessService:Numbers(player)
	local p = data:Get(player)
	if not p then
		return nil
	end
	local b = Business[p.stage]
	local t = os.time()
	-- customers come as fast as the counter can serve them (no adverts to buy): demand is the service
	local service = (b.service + Upgrades.stat(p.owned, "service", 0)) * (1 + Animals.boost(p, "service", t))
	if boosts and boosts:Active("customerRush") then
		service *= 2
	end
	service = math.floor(service + 0.5)
	local demand = service
	local dispatch = (b.dispatch or 0) + Upgrades.stat(p.owned, "dispatch", 0)
	if p.passes and p.passes.fastMachines then
		dispatch *= 1.25
	end
	local bulkPrice = (b.bulkPrice or 1) + Upgrades.stat(p.owned, "bulkPrice", 0)
	return {
		stage = p.stage,
		demand = demand,
		service = service,
		sell = math.min(demand, service),
		dispatch = dispatch,
		bulkPrice = bulkPrice,
		storage = self:Capacity(player),
		stock = self:Stock(player),
		docks = b.dispatch and b.dispatch > 0 and (1 + Upgrades.stat(p.owned, "docks", 0)) or 0,
		workers = b.workers + (p.owned.checkout or 0),
	}
end

-- Units a customer buys at once: 2 at the stand, up to 12 in a busy shop
function BusinessService:Basket(sell)
	return math.clamp(math.floor((sell or 0) / 8), 2, 12)
end

-- Units sold a minute over the last minute (counter and docks)
function BusinessService:SoldPerMinute(player)
	local s = state(player)
	local t, n = now(), 0
	for i = #s.sold, 1, -1 do
		if t - s.sold[i][1] > 60 then
			table.remove(s.sold, i)
		else
			n += s.sold[i][2]
		end
	end
	return n
end

-- The one thing most in the way (master plan §2), read along the chain field -> harvest -> stock -> sales:
--   stock full      selling is the limit: "dispatch" (the trucks, once there are docks), else "demand" (not enough
--                   customers come) or "service" (the counter can't serve them), whichever is lower
--   ripe piling up  "harvest" (hands or the machine can't keep up)
--   shelves empty   "production" (the field grows less than the store could sell)
--   else            the lower of demand and service
function BusinessService:Bottleneck(player)
	local p = data:Get(player)
	if not p then
		return "none"
	end
	local n = self:Numbers(player)
	local f = crops and crops:Summary(player) or { tiles = 0, ripe = 0, perMinute = 0, planted = 0 }
	local selling = n.sell + n.dispatch
	local function sales()
		return "service"
	end
	if n.stock >= n.storage * 0.9 then
		if n.dispatch > 0 and n.dispatch < f.perMinute then
			return "dispatch"
		end
		return sales()
	end
	local machine = Upgrades.machine(p.owned)
	local clear = machine > 0 and (automation and automation:Rate(player) or 40) or 36
	if f.ripe >= math.max(6, f.tiles * 0.4) and f.perMinute > clear then
		return "harvest"
	end
	if n.stock < n.storage * 0.25 and f.perMinute < selling then
		return "production"
	end
	return sales()
end

-- Is the stock area full (the machines wait)
function BusinessService:Full(player)
	local n = self:Numbers(player)
	return n ~= nil and n.stock >= n.storage
end

function BusinessService:SetStage(player, key)
	local p = data:Get(player)
	if not p or not Business[key] then
		return false
	end
	p.stage = key
	state(player).queue = 0
	self.Changed:Fire(player, "stage")
	self:Push(player)
	return true
end

-- One second of business
function BusinessService:Step(player, dt)
	local p = data:Get(player)
	if not p then
		return
	end
	local n = self:Numbers(player)
	local s = state(player)
	local st = territory and territory:Spot(player, "stand") or nil
	-- the counter: customers buy a basket each (bigger baskets as the business grows), one payment a basket
	s.sellAcc += n.sell / 60 * dt
	local basket = self:Basket(n.sell)
	if s.sellAcc >= basket then
		local want = math.floor(s.sellAcc)
		local taken, value = take(p, want)
		s.sellAcc -= want
		if taken > 0 then
			local cash = math.floor(value * economy:Multiplier(player) + 0.5)
			p.stats.sold = (p.stats.sold or 0) + taken
			economy:Add(player, cash, "sale", st)
			table.insert(s.sold, { now(), taken })
			Net.fire(player, "Sale", { n = taken, cash = cash })
			if analytics and p.stats.sold == taken then
				pcall(analytics.event, player, "first_sale_completed", { cash = cash })
			end
			self.Changed:Fire(player, "sale")
		end
	end
	-- the line: grows when more come than can be served (and nothing to serve them with is a short line too)
	-- (a few waiting while there's stock to sell: more as the counter gets busier)
	local target = n.stock > 0 and math.clamp(n.sell / 12, 1, self.QUEUE_MAX) or 1
	s.queue += (target - s.queue) * math.min(1, dt * 0.3)
	if n.stock >= n.storage and (p.stats.bottleneck or 0) == 0 then
		p.stats.bottleneck = os.time()
		if analytics then
			pcall(analytics.event, player, "store_bottleneck_reached", { stock = n.stock })
		end
	end
	-- the docks: trucks take loads out in bulk
	if n.dispatch > 0 then
		s.dispAcc += n.dispatch / 60 * dt
		if s.dispAcc >= self.TRUCK_LOAD and n.stock > 0 then
			local taken, value = take(p, self.TRUCK_LOAD)
			s.dispAcc = 0
			if taken > 0 then
				local cash = math.floor(value * n.bulkPrice * economy:Multiplier(player) + 0.5)
				p.stats.sold = (p.stats.sold or 0) + taken
				p.stats.trucks = (p.stats.trucks or 0) + 1
				s.trucks += 1
				economy:Add(player, cash, "truck", territory and territory:Spot(player, "dock") or nil)
				table.insert(s.sold, { now(), taken })
				Net.fire(player, "Truck", { n = taken, cash = cash, index = s.trucks })
				if analytics then
					pcall(analytics.event, player, "truck", { n = taken, cash = cash })
				end
				self.Changed:Fire(player, "truck")
			end
		elseif s.dispAcc > self.TRUCK_LOAD then
			s.dispAcc = self.TRUCK_LOAD -- (a truck waits at the dock for stock)
		end
	end
	-- the bottleneck, and the push
	local b = self:Bottleneck(player)
	if b ~= s.bottleneck then
		s.bottleneck, s.since = b, now()
	end
	if now() - (s.lastPush or 0) >= 2 then
		self:Push(player)
	end
end

function BusinessService:Push(player)
	local p = data:Get(player)
	if not p then
		return
	end
	local n = self:Numbers(player)
	local s = state(player)
	s.lastPush = now()
	Net.fire(player, "Business", {
		stage = p.stage,
		demand = n.demand,
		service = n.service,
		sell = n.sell,
		dispatch = n.dispatch,
		docks = n.docks,
		workers = n.workers,
		storage = n.storage,
		stock = n.stock,
		queue = math.floor(s.queue + 0.5),
		soldPerMin = self:SoldPerMinute(player),
		income = math.floor(economy:Income(player)),
		bottleneck = s.bottleneck,
		full = n.stock >= n.storage,
		basket = self:Basket(n.sell),
		perMinute = crops and crops:Summary(player).perMinute or 0,
		harvest = automation and automation:Rate(player) or 0,
		mix = table.clone(p.stock),
		next = Business.next(p.stage) and Business.next(p.stage).key or nil,
	})
end

function BusinessService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	boosts = registry.BoostService
	analytics = registry.AnalyticsService
	crops = registry.CropService -- (they depend on this service; the registry holds them before their Init)
	territory = registry.TerritoryService
	automation = registry.AutomationService
	registry.UpgradeService.Applied:Connect(function(player)
		self:Push(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		live[player] = nil
	end)
end

function BusinessService:OnPlayerReady(player)
	data:WhenClientReady(player, function()
		self:Push(player)
	end)
end

function BusinessService:Start()
	local last = now()
	while true do
		task.wait(self.TICK)
		local t = now()
		local dt = math.clamp(t - last, 0, 5)
		last = t
		for _, player in Players:GetPlayers() do
			local ok, err = pcall(self.Step, self, player, dt)
			if not ok then
				warn("[BusinessService] tick failed: " .. tostring(err))
			end
		end
	end
end

_ = Layout
return BusinessService
