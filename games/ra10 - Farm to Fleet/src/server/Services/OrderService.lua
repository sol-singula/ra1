--[[
Orders and daily contracts (master plan §3, §7, §8; Data/Orders). They open with the packing shed. The order board
holds Upgrades.stat "orders" slots, and each slot cycles through these states:

  open      a customer wants crops (items) by `ends`; packing moves matching crops from the basket into its boxes
  ready     all packed: waiting for a vehicle
  shipping  on the road: the buyer's pickup, or one of the plot's vans; pays when the trip ends (at + length)
  wait      empty until `at` (Orders.REFRESH after it shipped, ran out, or was skipped), then a new customer

  pack      standing on the shed's PackPad (the hub's front hall's, later) packs the basket into the open orders (first slot first); the box line
            (Upgrades "autopack") does it every few seconds by itself
  the conveyor  once the shed stands, the conveyor leaves in the basket what the open orders still need
            (FarmService.hold)
  skip      Net "Order" ("skip", slot): an open order goes, its boxes back into the basket, the next one comes
  trips     a van (Upgrades "van": its seconds, "vans": how many) or else the pickup (Orders.PICKUP_TRIP, one at a
            time), cut by Upgrades "tripCut". The vehicle in the world gets TripStart, TripLength and Trip, and every
            client drives it (World/Trips). The time a trip takes passes while they're away too: back on, it pays.
  contracts three a day (Orders.daily), measured from the stats at the day's start; each pays when it's reached,
            and all three add Orders.ALL_GEMS

profile.orders = { done, id, live = { [slot] = { id, who, items, packed, value, big?, state, ends?, at?, length?,
vehicle? } }, daily = { day, base = { [stat] = n }, done = { ["1".."3"] = true } (string keys: a DataStore can't
save a sparse array), all? } }
Net "Orders" to the owner: { slots = { ... with reward, xp }, now, open (the shed's built), vans, contracts =
{ { text, have, n, done, cash } }, dayLeft }

  OrderService:Slots(player)           the live slots (the profile's)
  OrderService:Pack(player, quiet?) -> how many crops went into boxes
  OrderService:Skip(player, slot) -> ok
  OrderService:Needs(player) -> { [crop] = n }   what the open orders (and a Special Order) still need
  OrderService.packFirst(player) / .extraNeeds(player)   (set by SpecialService) the special packs first
  OrderService:Contracts(player) -> the day's three, with progress
  OrderService:Push(player)
  OrderService.Changed (player, what)   "pack" | "ready" | "ship" | "paid" | "new" | "contract"
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animals = require(ReplicatedStorage.Shared.Data.Animals)
local Franchise = require(ReplicatedStorage.Shared.Data.Franchise)
local FarmBuilder = require(ReplicatedStorage.Shared.World.FarmBuilder)
local Net = require(ReplicatedStorage.Shared.Net)
local Orders = require(ReplicatedStorage.Shared.Data.Orders)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Trips = require(ReplicatedStorage.Shared.World.Trips)
local Upgrades = require(ReplicatedStorage.Shared.Data.Upgrades)

local OrderService = {
	Name = "OrderService",
	Dependencies = { "PlayerDataService", "EconomyService", "PlotService", "FarmService", "UpgradeService" },
	Changed = Signal.new("OrderService.Changed"),
	REACH = 3.6,
	TICK = 0.5,
}

local data, economy, plots, farm, upgrades, analytics
local onPad = {} -- [player] = true while they stand on the pack pad (one pack per visit)
local packAt = {} -- [player] = when the box line last packed
local board = {} -- [player] = { [slot] = the words on it }, so the board is only repainted when they change
local pickups = {} -- [player] = { [slot] = the pickup's Model }
local boardParts = {} -- [player] = the order board's slot parts

local function now()
	return workspace:GetServerTimeNow()
end

local function ordersOf(p)
	p.orders = p.orders or {}
	local o = p.orders
	o.done = o.done or 0
	o.id = o.id or 0
	o.live = o.live or {}
	o.daily = o.daily or { day = 0, done = {} }
	o.daily.done = o.daily.done or {}
	return o
end

local function opened(p)
	return p.owned and p.owned.shed ~= nil
end

local function slotCount(p)
	return opened(p)
			and Upgrades.stat(p.owned, "orders", 0) + Franchise.bonus(p, "orderSlot") + (p.passes and p.passes.extraOrder and 1 or 0)
		or 0
end

local function bonus(p)
	return Upgrades.stat(p.owned or {}, "orderPrice", 0) + Animals.boost(p, "orders", now())
end

local function products(p)
	local out = {}
	for _, key in Animals.LIST do
		local a = Animals[key]
		if a.product and p.animals and p.animals[key] then
			table.insert(out, a.product)
		end
	end
	return out
end

local function newOrder(player, p)
	local o = ordersOf(p)
	o.id += 1
	local rng = Random.new(o.id * 131 + player.UserId % 1000)
	local made = Orders.make(p.level or 1, rng, products(p))
	return {
		id = o.id,
		who = made.who,
		items = made.items,
		packed = {},
		value = made.value,
		big = made.big,
		state = "open",
		ends = now() + Orders.TIME * (made.big and 2 or 1),
	}
end

function OrderService:Slots(player)
	local p = data:Get(player)
	return p and ordersOf(p).live or {}
end

local function left(order, key)
	return order.items[key] - (order.packed[key] or 0)
end

local function full(order)
	for key in order.items do
		if left(order, key) > 0 then
			return false
		end
	end
	return true
end

function OrderService:Needs(player)
	local out = self.extraNeeds and table.clone(self.extraNeeds(player)) or {}
	for _, order in self:Slots(player) do
		if order.state == "open" then
			for key in order.items do
				local n = left(order, key)
				if n > 0 then
					out[key] = (out[key] or 0) + n
				end
			end
		end
	end
	return out
end

-- Pack the basket into the open orders: each crop the orders still want, first slot first
function OrderService:Pack(player, quiet)
	local p = data:Get(player)
	if not p or not opened(p) then
		return 0
	end
	local storage = p.storage or {}
	-- (a Special Order first: SpecialService)
	local total, readied = self.packFirst and self.packFirst(player) or 0, {}
	for _, order in ordersOf(p).live do
		if order.state == "open" then
			for key in order.items do
				local n = math.min(left(order, key), storage[key] or 0)
				if n > 0 then
					storage[key] -= n
					if storage[key] <= 0 then
						storage[key] = nil
					end
					order.packed[key] = (order.packed[key] or 0) + n
					total += n
				end
			end
			if full(order) then
				order.state = "ready"
				p.stats.ordersPacked = (p.stats.ordersPacked or 0) + 1
				table.insert(readied, order)
			end
		end
	end
	if total > 0 then
		p.stats.packed = (p.stats.packed or 0) + total
		if not quiet then
			Net.fire(player, "Toast", `Packed {total} into boxes!`, "good")
		end
		for _, order in readied do
			Net.fire(player, "Toast", `{order.who}'s order is packed: it's on its way out!`, "good")
		end
		farm:Push(player)
		self.Changed:Fire(player, #readied > 0 and "ready" or "pack")
		self:Push(player)
	elseif not quiet then
		local wants = {}
		for key in self:Needs(player) do
			table.insert(wants, Orders.itemName(key))
		end
		Net.fire(
			player,
			"Toast",
			#wants > 0 and `Your orders want {table.concat(wants, ", ")}: harvest some first` or "No open orders yet",
			"info"
		)
	end
	return total
end

-- Boxes back into the basket (an order skipped or run out), as many as fit
local function unbox(player, order)
	for key, n in order.packed do
		farm:Stow(player, key, n)
	end
	order.packed = {}
end

function OrderService:Skip(player, slot)
	local p = data:Get(player)
	local order = p and ordersOf(p).live[slot]
	if not order or order.state ~= "open" then
		return false
	end
	unbox(player, order)
	ordersOf(p).live[slot] = { state = "wait", at = now() + Orders.REFRESH }
	farm:Push(player)
	self.Changed:Fire(player, "skip")
	self:Push(player)
	return true
end

-- Trips ----------------------------------------------------------------------------------------------------------
local function vanModels(player)
	local plot = plots:Plot(player)
	local out = {}
	if not plot then
		return out
	end
	for _, key in { "van", "van2" } do
		local folder = plot.items:FindFirstChild(key)
		local model = folder and folder:FindFirstChild("Vehicle")
		if model then
			out[model:GetAttribute("Park") or #out + 1] = model
		end
	end
	return out
end

local function vanCount(p)
	if not (p.owned and p.owned.van) then
		return 0
	end
	return Upgrades.stat(p.owned, "vans", 1)
end

local function tripLength(p, kind)
	local base = kind == "van" and Upgrades.stat(p.owned or {}, "van", nil) or Orders.PICKUP_TRIP
	return base * (1 - Upgrades.stat(p.owned or {}, "tripCut", 0))
end

local PICKUP_COLORS = {
	Color3.fromRGB(200, 60, 50),
	Color3.fromRGB(60, 120, 200),
	Color3.fromRGB(240, 180, 40),
	Color3.fromRGB(90, 160, 90),
	Color3.fromRGB(150, 100, 200),
}

-- The vehicle on the map that shows a trip: the van it's using, or the buyer's pickup (made for the trip)
local function showTrip(player, slot, order)
	local plot = plots:Plot(player)
	if not plot then
		return
	end
	local model
	if order.vehicle and order.vehicle ~= "pickup" then
		model = vanModels(player)[order.vehicle]
	else
		pickups[player] = pickups[player] or {}
		model = pickups[player][slot]
		if not model or not model.Parent then
			local cf = Trips.at(plot.index, "pickup", 0)
			model = FarmBuilder.vehicle(plot.items, "pickup", PICKUP_COLORS[order.id % #PICKUP_COLORS + 1], cf)
			model.Name = "Vehicle"
			model:SetAttribute("Plot", plot.index)
			pickups[player][slot] = model
		end
	end
	if model then
		model:SetAttribute("Trip", model:GetAttribute("Kind"))
		model:SetAttribute("TripStart", order.at)
		model:SetAttribute("TripLength", order.length)
		model:SetAttribute("Plot", plot.index)
	end
end

local function endTrip(player, slot, order)
	if order.vehicle == "pickup" then
		local m = pickups[player] and pickups[player][slot]
		if m then
			m:Destroy()
			pickups[player][slot] = nil
		end
	else
		local m = vanModels(player)[order.vehicle]
		if m then
			m:SetAttribute("TripStart", nil)
			m:SetAttribute("TripLength", nil)
			m:SetAttribute("Trip", nil)
		end
	end
end

local function dispatch(player, p, slot, order)
	local vans = vanCount(p)
	local busy = {}
	local pickupBusy = false
	for _, o in ordersOf(p).live do
		if o.state == "shipping" then
			if o.vehicle == "pickup" then
				pickupBusy = true
			else
				busy[o.vehicle] = true
			end
		end
	end
	local vehicle
	for n = 1, vans do
		if not busy[n] then
			vehicle = n
			break
		end
	end
	if not vehicle then
		if vans > 0 or pickupBusy then
			return false -- (vans come before the pickup once they own one: wait for one back)
		end
		vehicle = "pickup"
	end
	order.state = "shipping"
	order.vehicle = vehicle
	order.at = now()
	order.length = tripLength(p, vehicle == "pickup" and "pickup" or "van")
	showTrip(player, slot, order)
	OrderService.Changed:Fire(player, "ship")
	return true
end

local function pay(player, p, slot, order)
	local cash, xp = Orders.reward(order, bonus(p))
	economy:Add(player, cash, "order")
	economy:AddXP(player, xp, "order")
	local gems = order.big and Orders.BIG_GEMS or 0
	if gems > 0 then
		economy:AddGems(player, gems, "order")
		p.stats.bigOrders = (p.stats.bigOrders or 0) + 1
	end
	p.stats.shipments = (p.stats.shipments or 0) + 1
	ordersOf(p).done += 1
	endTrip(player, slot, order)
	order.state = "paid"
	Net.fire(player, "Toast", `{order.who} paid {cash} Cash` .. (gems > 0 and ` and {gems} Gems!` or "!"), "good")
	if analytics then
		pcall(analytics.event, player, "order", { cash = cash, big = order.big == true, done = ordersOf(p).done })
	end
	ordersOf(p).live[slot] = { state = "wait", at = now() + Orders.REFRESH }
	OrderService.Changed:Fire(player, "paid")
end

-- Daily contracts ------------------------------------------------------------------------------------------------
local function contractsOf(player, p)
	local o = ordersOf(p)
	local today = Orders.day()
	if o.daily.day ~= today then
		o.daily = { day = today, base = {}, done = {} }
		for _, c in Orders.daily(today, player.UserId, p.level or 1) do
			o.daily.base[c.stat] = p.stats[c.stat] or 0
		end
		o.daily.level = p.level or 1
	end
	local list = Orders.daily(today, player.UserId, o.daily.level or p.level or 1)
	for i, c in list do
		c.have = math.min(c.n, (p.stats[c.stat] or 0) - (o.daily.base[c.stat] or 0))
		c.done = o.daily.done[tostring(i)] == true
	end
	return list, o.daily
end

function OrderService:Contracts(player)
	local p = data:Get(player)
	if not p or not opened(p) then
		return {}
	end
	return (contractsOf(player, p))
end

local function checkContracts(player, p)
	local list, daily = contractsOf(player, p)
	local changed = false
	for i, c in list do
		if not c.done and c.have >= c.n then
			daily.done[tostring(i)] = true
			changed = true
			economy:Add(player, c.cash, "contract")
			economy:AddGems(player, 1, "contract")
			p.stats.contracts = (p.stats.contracts or 0) + 1
			Net.fire(player, "Toast", `CONTRACT DONE: {c.text}! +{c.cash} Cash, +1 Gem`, "good")
		end
	end
	if changed and not daily.all then
		local all = true
		for i in list do
			all = all and daily.done[tostring(i)] == true
		end
		if all then
			daily.all = true
			economy:AddGems(player, Orders.ALL_GEMS, "contracts")
			Net.fire(player, "Toast", `ALL 3 CONTRACTS DONE! +{Orders.ALL_GEMS} Gems. New ones tomorrow`, "good")
		end
	end
	if changed then
		OrderService.Changed:Fire(player, "contract")
	end
	return changed
end

-- The board and the client ------------------------------------------------------------------------------------------
local function itemLines(order)
	local keys = {}
	for key in order.items do
		table.insert(keys, key)
	end
	table.sort(keys)
	local lines = {}
	for _, key in keys do
		table.insert(lines, `{order.packed[key] or 0}/{order.items[key]} {Orders.itemName(key)}`)
	end
	return lines
end

local CREAM = Color3.fromRGB(250, 250, 240)
local GOLD = Color3.fromRGB(255, 210, 60)
local GREEN = Color3.fromRGB(120, 230, 140)
local BLUE = Color3.fromRGB(120, 200, 255)
local GREY = Color3.fromRGB(190, 200, 196)

local function paintBoard(player, p)
	local plot = plots:Plot(player)
	if not plot or not opened(p) then
		return
	end
	board[player] = board[player] or {}
	local slots = slotCount(p)
	local b = bonus(p)
	-- (the board stands by the shed, then hangs on the hub's front hall: looked for after every build)
	if not boardParts[player] then
		boardParts[player] = {}
		for _, d in plot.items:GetDescendants() do
			if d.Name == "BoardSlot" then
				table.insert(boardParts[player], d)
			end
		end
	end
	for _, part in boardParts[player] do
		local slot = part:GetAttribute("Slot")
		if part.Name == "BoardSlot" and slot then
			local order = ordersOf(p).live[slot]
			local title, lines, status, color = "", {}, "", CREAM
			if slot > slots then
				title, lines, status, color = "LOCKED", { "Buy the", "Big Order Board" }, "", GREY
			elseif not order or order.state == "wait" then
				title, status, color = "NEXT", "customer coming", GREY
			else
				title = (order.big and "BIG! " or "") .. order.who
				lines = itemLines(order)
				color = order.big and GOLD or CREAM
				if order.state == "open" then
					status = `PAYS {Orders.reward(order, b)}`
				elseif order.state == "ready" then
					status, color = "PACKED!", GREEN
				else
					status, color = "ON THE ROAD", BLUE
				end
			end
			local words = title .. "|" .. table.concat(lines, ",") .. "|" .. status
			if board[player][slot] ~= words then
				board[player][slot] = words
				FarmBuilder.board(part, title, lines, status, color)
			end
		end
	end
end

function OrderService:Push(player)
	local p = data:Get(player)
	if not p then
		return
	end
	local o = ordersOf(p)
	local out = {}
	local b = bonus(p)
	for slot = 1, slotCount(p) do
		local order = o.live[slot]
		if order then
			local view = table.clone(order)
			if order.items then
				view.reward, view.xp = Orders.reward(order, b)
				view.gems = order.big and Orders.BIG_GEMS or nil
			end
			out[slot] = view
		else
			out[slot] = { state = "wait", at = now() }
		end
	end
	local contracts = opened(p) and select(1, contractsOf(player, p)) or {}
	Net.fire(player, "Orders", {
		open = opened(p),
		slots = out,
		now = now(),
		vans = vanCount(p),
		contracts = contracts,
		dayLeft = (Orders.day() + 1) * 86400 - os.time(),
	})
	paintBoard(player, p)
end

-- Each tick: new customers into empty slots, orders run out, packed ones leave, trips come home and pay, the box
-- line packs, the pack pad packs, contracts are checked
function OrderService:Step(player, p)
	if not opened(p) then
		return
	end
	local o = ordersOf(p)
	local t = now()
	local changed = false
	for slot = 1, slotCount(p) do
		local order = o.live[slot]
		if not order or (order.state == "wait" and t >= (order.at or 0)) then
			o.live[slot] = newOrder(player, p)
			changed = true
			self.Changed:Fire(player, "new")
		elseif order.state == "open" and t >= order.ends then
			unbox(player, order)
			o.live[slot] = { state = "wait", at = t + Orders.REFRESH }
			Net.fire(player, "Toast", `{order.who}'s order ran out of time: a new customer is coming`, "info")
			changed = true
		elseif order.state == "ready" then
			changed = dispatch(player, p, slot, order) or changed
		elseif order.state == "shipping" then
			if t >= order.at + order.length then
				pay(player, p, slot, order)
				changed = true
			end
		end
	end
	-- the box line
	local every = Upgrades.stat(p.owned or {}, "autopack", nil)
	if every and t - (packAt[player] or 0) >= every then
		packAt[player] = t
		self:Pack(player, true)
	end
	if checkContracts(player, p) then
		changed = true
	end
	if changed then
		self:Push(player)
	end
end

function OrderService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	plots = registry.PlotService
	farm = registry.FarmService
	upgrades = registry.UpgradeService
	analytics = registry.AnalyticsService
	-- the conveyor leaves what the orders need
	farm.hold = function(player)
		local p = data:Get(player)
		return p and opened(p) and self:Needs(player) or nil
	end
	Net.on("Order", function(player, what, a)
		if what == "skip" and type(a) == "number" then
			self:Skip(player, a)
		elseif what == "pack" then
			local refs = self:PackPad(player)
			if refs and plots:Near(player, refs, self.REACH + 2) then
				self:Pack(player)
			end
		end
	end)
	upgrades.Applied:Connect(function(player, u)
		if u.key == "shed" or u.kind == "orders" or u.kind == "van" or u.kind == "vans" or u.stage >= 5 then
			local p = data:Get(player)
			if p then
				board[player] = nil
				boardParts[player] = nil
				-- (a trip under way when they left: the van shows it again)
				for slot, order in ordersOf(p).live do
					if order.state == "shipping" then
						showTrip(player, slot, order)
					end
				end
			end
			task.defer(self.Push, self, player)
		end
	end)
	farm.Changed:Connect(function(player)
		local p = data:Get(player)
		if p and opened(p) then
			checkContracts(player, p)
		end
	end)
	-- (forget them when they leave, or when their plot comes down for a rebuild: a franchise)
	local function forget(player)
		onPad[player] = nil
		packAt[player] = nil
		board[player] = nil
		boardParts[player] = nil
		pickups[player] = nil
	end
	Players.PlayerRemoving:Connect(forget)
	registry.PlotService.Released:Connect(forget)
end

function OrderService:PackPad(player)
	local plot = plots:Plot(player)
	return plot and plot.items:FindFirstChild("PackPad", true)
end

function OrderService:OnPlayerReady(player)
	data:WhenClientReady(player, function()
		self:Push(player)
	end)
end

function OrderService:_tick()
	for _, player in Players:GetPlayers() do
		local p = data:Get(player)
		if not p then
			continue
		end
		self:Step(player, p)
		local pad = self:PackPad(player)
		if pad and plots:Near(player, pad, self.REACH) then
			if not onPad[player] then
				onPad[player] = true
				self:Pack(player)
			end
		else
			onPad[player] = nil
		end
	end
end

function OrderService:Start()
	while true do
		task.wait(self.TICK)
		local ok, err = pcall(self._tick, self)
		if not ok then
			warn("[OrderService] tick failed: " .. tostring(err))
		end
	end
end

return OrderService
