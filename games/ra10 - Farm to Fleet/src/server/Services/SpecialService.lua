--[[
Special Orders at work (master plan §13.3, Data/Specials). Once the packing shed stands, a Special Order comes every
Specials.EVERY_MIN..EVERY_MAX minutes of play (the first Specials.FIRST after the shed), and one is waiting on the
first visit of each UTC day. Its express truck pulls up on the road in front of the plot (World/Trips "expressIn")
where the whole street sees it; everyone on the server hears about it.

  packing   the PACK ORDERS pad (and the box line) packs the special first (OrderService.packFirst); the conveyor
            and the warehouse leave what it needs in the basket (OrderService.extraNeeds); golden crops ("*crop")
            only count for a Golden Harvest
  shipping  packed: the express truck drives off (Trips "expressOut") and it pays when it's gone: Cash (many times a
            normal order, more with the sorter, wrapper and tower), XP and Gems
  too late  past its time it's gone, the boxes back in the basket, and the next one is on its way

profile.orders.special = { id, kind, name, who, items, packed, value, mult, gems, ends, state ("open" | "shipping"),
at?, length? } or nil; profile.orders.specialIn = seconds of play till the next; profile.orders.specialDay
Net "Special" to the owner: the special (with now, reward, xp), or { none = true, next = seconds }

  SpecialService:Current(player) -> the special, or nil
  SpecialService:Spawn(player) -> the new special (for a daily one, or tests)
  SpecialService:Pack(player) -> how many went into its boxes
  SpecialService:Needs(player) -> { [item] = n }
  SpecialService.Changed (player, what)   "new" | "pack" | "ship" | "paid" | "missed"
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FarmBuilder = require(ReplicatedStorage.Shared.World.FarmBuilder)
local Net = require(ReplicatedStorage.Shared.Net)
local Orders = require(ReplicatedStorage.Shared.Data.Orders)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Specials = require(ReplicatedStorage.Shared.Data.Specials)
local Trips = require(ReplicatedStorage.Shared.World.Trips)
local Upgrades = require(ReplicatedStorage.Shared.Data.Upgrades)

local SpecialService = {
	Name = "SpecialService",
	Dependencies = { "PlayerDataService", "EconomyService", "PlotService", "FarmService", "OrderService" },
	Changed = Signal.new("SpecialService.Changed"),
	TICK = 1,
	ARRIVE = 8, -- seconds the express truck takes to pull up
	FIRST = Specials.FIRST, -- seconds of play after the shed before the first one
	DAILY = true, -- the day's first visit brings one
}

local data, economy, plots, farm, orders, analytics
local trucks = {} -- [player] = the express truck's Model
local rng = Random.new()

local function now()
	return workspace:GetServerTimeNow()
end

local function ordersOf(p)
	p.orders = p.orders or {}
	return p.orders
end

local function eligible(p)
	return p.owned and p.owned.shed ~= nil
end

local function bonus(p)
	return Upgrades.stat(p.owned or {}, "orderPrice", 0)
end

function SpecialService:Current(player)
	local p = data:Get(player)
	return p and ordersOf(p).special or nil
end

-- The express truck, pulled up on the road (or driving off)
local function truck(player, trip, plan)
	local plot = plots:Plot(player)
	if not plot then
		return nil
	end
	local m = trucks[player]
	if not m or not m.Parent then
		m = FarmBuilder.vehicle(plot.items, "express", Color3.new(1, 0.8, 0.2), (Trips.at(plot.index, "expressIn", 0)))
		m:SetAttribute("Plot", plot.index)
		trucks[player] = m
	end
	m:SetAttribute("Plan", plan)
	m:SetAttribute("Trip", plan)
	m:SetAttribute("TripStart", trip.at)
	m:SetAttribute("TripLength", trip.length)
	return m
end

local function dropTruck(player)
	if trucks[player] then
		trucks[player]:Destroy()
		trucks[player] = nil
	end
end

function SpecialService:Push(player)
	local p = data:Get(player)
	if not p then
		return
	end
	local s = ordersOf(p).special
	if s then
		local view = table.clone(s)
		view.reward, view.xp = Specials.reward(s, bonus(p))
		view.now = now()
		Net.fire(player, "Special", view)
	else
		Net.fire(player, "Special", { none = true, next = ordersOf(p).specialIn })
	end
end

function SpecialService:Spawn(player)
	local p = data:Get(player)
	if not p or not eligible(p) then
		return nil
	end
	local o = ordersOf(p)
	if o.special then
		return o.special
	end
	o.id = (o.id or 0) + 1
	local made = Specials.make(p.level or 1, rng, os.time())
	local s = {
		id = o.id,
		kind = made.kind,
		name = made.name,
		who = made.who,
		items = made.items,
		packed = {},
		value = made.value,
		mult = made.mult,
		gems = made.gems,
		ends = now() + made.time,
		state = "open",
	}
	o.special = s
	truck(player, { at = now(), length = self.ARRIVE }, "expressIn")
	local cash = Specials.reward(s, bonus(p))
	Net.fire(player, "Toast", `SPECIAL ORDER! {s.name} for {s.who}: {cash} Cash + {s.gems} Gems`, "good")
	for _, other in Players:GetPlayers() do
		if other ~= player then
			Net.fire(other, "Toast", `{player.DisplayName} got a SPECIAL ORDER: {s.name}!`, "info")
		end
	end
	if analytics then
		pcall(analytics.event, player, "special", { kind = s.kind, value = s.value })
	end
	self.Changed:Fire(player, "new")
	self:Push(player)
	return s
end

local function left(s, key)
	return s.items[key] - (s.packed[key] or 0)
end

function SpecialService:Needs(player)
	local s = self:Current(player)
	local out = {}
	if s and s.state == "open" then
		for key in s.items do
			if left(s, key) > 0 then
				out[key] = left(s, key)
			end
		end
	end
	return out
end

local function done(s)
	for key in s.items do
		if left(s, key) > 0 then
			return false
		end
	end
	return true
end

function SpecialService:Pack(player)
	local p = data:Get(player)
	local s = p and ordersOf(p).special
	if not s or s.state ~= "open" then
		return 0
	end
	local storage = p.storage or {}
	local total = 0
	for key in s.items do
		local n = math.min(left(s, key), storage[key] or 0)
		if n > 0 then
			storage[key] -= n
			if storage[key] <= 0 then
				storage[key] = nil
			end
			s.packed[key] = (s.packed[key] or 0) + n
			total += n
		end
	end
	if total > 0 then
		p.stats.packed = (p.stats.packed or 0) + total
		if done(s) then
			s.state, s.at, s.length = "shipping", now(), Specials.EXPRESS
			truck(player, { at = s.at, length = s.length }, "expressOut")
			Net.fire(player, "Toast", `{s.name} packed: the express truck is on its way!`, "good")
			self.Changed:Fire(player, "ship")
		else
			self.Changed:Fire(player, "pack")
		end
		self:Push(player)
	end
	return total
end

local function pay(player, p, s)
	local cash, xp = Specials.reward(s, bonus(p))
	economy:Add(player, cash, "special")
	economy:AddXP(player, xp, "special")
	economy:AddGems(player, s.gems, "special")
	p.stats.specials = (p.stats.specials or 0) + 1
	p.stats.biggestShipment = math.max(p.stats.biggestShipment or 0, cash)
	Net.fire(player, "Toast", `{s.who} paid {cash} Cash and {s.gems} Gems!`, "good")
	if analytics then
		pcall(analytics.event, player, "specialPaid", { kind = s.kind, cash = cash })
	end
end

local function nextIn()
	return rng:NextInteger(Specials.EVERY_MIN, Specials.EVERY_MAX)
end

function SpecialService:Step(player, p, dt)
	if not eligible(p) then
		return
	end
	local o = ordersOf(p)
	local s = o.special
	local t = now()
	if not s then
		o.specialIn = (o.specialIn or self.FIRST) - dt
		if o.specialIn <= 0 then
			o.specialIn = nextIn()
			self:Spawn(player)
		end
		return
	end
	if s.state == "open" and t >= s.ends then
		for key, n in s.packed do
			farm:Stow(player, key, n)
		end
		o.special = nil
		o.specialIn = nextIn()
		dropTruck(player)
		Net.fire(player, "Toast", `{s.name} ran out of time: another will come`, "info")
		self.Changed:Fire(player, "missed")
		self:Push(player)
	elseif s.state == "shipping" and t >= s.at + s.length then
		pay(player, p, s)
		o.special = nil
		o.specialIn = nextIn()
		dropTruck(player)
		self.Changed:Fire(player, "paid")
		self:Push(player)
	end
end

function SpecialService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	plots = registry.PlotService
	farm = registry.FarmService
	orders = registry.OrderService
	analytics = registry.AnalyticsService
	orders.packFirst = function(player)
		return self:Pack(player)
	end
	orders.extraNeeds = function(player)
		return self:Needs(player)
	end
	-- (forget them when they leave, or when their plot comes down for a rebuild: a franchise)
	local function forget(player)
		trucks[player] = nil
	end
	Players.PlayerRemoving:Connect(forget)
	registry.PlotService.Released:Connect(forget)
end

function SpecialService:OnPlayerReady(player)
	local p = data:Get(player)
	if not p then
		return
	end
	local o = ordersOf(p)
	-- a special under way when they left: its truck again (still waiting, or driving off)
	local s = o.special
	if s then
		if s.state == "shipping" then
			truck(player, { at = s.at, length = s.length }, "expressOut")
		else
			truck(player, { at = now() - self.ARRIVE, length = self.ARRIVE }, "expressIn")
		end
	end
	-- the day's first visit: a special is waiting
	local today = Orders.day()
	if self.DAILY and eligible(p) and o.specialDay ~= today then
		o.specialDay = today
		self:Spawn(player)
	end
	data:WhenClientReady(player, function()
		self:Push(player)
	end)
end

function SpecialService:_tick()
	for _, player in Players:GetPlayers() do
		local p = data:Get(player)
		if p then
			self:Step(player, p, self.TICK)
		end
	end
end

function SpecialService:Start()
	while true do
		task.wait(self.TICK)
		local ok, err = pcall(self._tick, self)
		if not ok then
			warn("[SpecialService] tick failed: " .. tostring(err))
		end
	end
end

return SpecialService
