--[[
The customers at the stand (Data/Customers): once the barn stands they come at Customers.rate a minute and each
buys up to a basket of crops out of it, paying the stand's price. (Before the barn you carry your crops to SELL.) That's the farm's main way to sell, and
the one bottleneck: a full barn means they can't keep up, and the next shop upgrade brings more of them.

Net "Customer" to the owner: { who, n, cash, crop } for every sale (CustomerController walks a little figure up to
the stand with it). Net "Customers": { rate, basket, perMin, stock, cap } whenever the numbers change.

  CustomerService:Rate(player)     customers a minute
  CustomerService:Serve(player)    one customer buys now; how many crops
  CustomerService:Push(player)
  CustomerService.Changed (player, what)   "sale"
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Crops = require(ReplicatedStorage.Shared.Data.Crops)
local Customers = require(ReplicatedStorage.Shared.Data.Customers)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local CustomerService = {
	Name = "CustomerService",
	Dependencies = { "PlayerDataService", "EconomyService", "FarmService" },
	Changed = Signal.new("CustomerService.Changed"),
	TICK = 0.5,
	MAX_STEP = 5,
}

local data, economy, farm, analytics
local due = {} -- [player] = customers owed (the rate x time, less the ones served)
local lastAt = {}
local sold = {} -- [player] = { t, n } sales in the last while (the HUD's "sold a minute")

local function now()
	return workspace:GetServerTimeNow()
end

function CustomerService:Rate(player)
	local p = data:Get(player)
	return p and Customers.rate(p, now()) or 0
end

-- The crops a customer takes: the dearest first (they buy the good stuff), up to the basket
local function pick(player, p, basket)
	local have = farm:Stock(player)
	local keys = {}
	for key, n in have do
		if n > 0 and Crops[string.gsub(key, "^%*", "")] then
			table.insert(keys, key)
		end
	end
	table.sort(keys, function(a, b)
		local ca, cb = Crops[string.gsub(a, "^%*", "")], Crops[string.gsub(b, "^%*", "")]
		return ca.value > cb.value
	end)
	local bag, n = {}, 0
	for _, key in keys do
		local k = math.min(basket - n, have[key])
		if k > 0 then
			bag[key] = k
			n += k
		end
		if n >= basket then
			break
		end
	end
	return bag, n
end

function CustomerService:Serve(player)
	local p = data:Get(player)
	if not p then
		return 0
	end
	local bag, n = pick(player, p, Customers.basket(p.owned))
	if n == 0 then
		return 0
	end
	local cash = farm:Worth(player, bag)
	local crop
	for key, k in bag do
		farm:RemoveStock(player, key, k)
		crop = crop or key
	end
	p.stats.sold = (p.stats.sold or 0) + n
	p.stats.customers = (p.stats.customers or 0) + 1
	economy:Add(player, cash, "sell")
	economy:AddXP(player, math.max(1, math.floor(n / 2)), "sell")
	local who = Customers.NAMES[(p.stats.customers - 1) % #Customers.NAMES + 1]
	Net.fire(player, "Customer", { who = who, n = n, cash = cash, crop = string.gsub(crop, "^%*", "") })
	local list = sold[player] or {}
	sold[player] = list
	table.insert(list, { now(), n })
	if analytics and p.stats.customers == 1 then
		pcall(analytics.event, player, "first_customer", { cash = cash })
	end
	farm:Push(player)
	self.Changed:Fire(player, "sale")
	return n
end

-- Crops sold a minute, over the last minute
function CustomerService:SoldPerMinute(player)
	local list = sold[player]
	if not list then
		return 0
	end
	local t, n = now(), 0
	for i = #list, 1, -1 do
		if t - list[i][1] > 60 then
			table.remove(list, i)
		else
			n += list[i][2]
		end
	end
	return n
end

function CustomerService:Push(player)
	local p = data:Get(player)
	if not p then
		return
	end
	local stock = 0
	for _, n in farm:Stock(player) do
		stock += n
	end
	Net.fire(player, "Customers", {
		rate = Customers.rate(p, now()),
		basket = Customers.basket(p.owned),
		perMin = Customers.sellRate(p, now()),
		sold = self:SoldPerMinute(player),
		stock = stock,
		cap = farm:Keeps(player),
	})
end

function CustomerService:Step(player, dt)
	local p = data:Get(player)
	if not p then
		return
	end
	due[player] = math.min((due[player] or 0) + Customers.rate(p, now()) / 60 * dt, 6)
	local served = 0
	while due[player] >= 1 and served < 6 do
		due[player] -= 1
		if self:Serve(player) == 0 then
			due[player] = 0 -- (nothing to buy: they go away; no queue builds up)
			break
		end
		served += 1
	end
end

function CustomerService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	farm = registry.FarmService
	analytics = registry.AnalyticsService
	local function forget(player)
		due[player] = nil
		lastAt[player] = nil
		sold[player] = nil
	end
	Players.PlayerRemoving:Connect(forget)
	farm.Changed:Connect(function(player, what)
		if what == "harvest" or what == "sell" or what == "tractor" then
			self:Push(player)
		end
	end)
	registry.UpgradeService.Applied:Connect(function(player)
		self:Push(player)
	end)
end

function CustomerService:OnPlayerReady(player)
	data:WhenClientReady(player, function()
		self:Push(player)
	end)
end

function CustomerService:_tick()
	local t = now()
	for _, player in Players:GetPlayers() do
		local dt = math.clamp(t - (lastAt[player] or t), 0, self.MAX_STEP)
		lastAt[player] = t
		local ok, err = pcall(self.Step, self, player, dt)
		if not ok then
			warn("[CustomerService] " .. tostring(err))
		end
	end
end

function CustomerService:Start()
	task.spawn(function()
		while true do
			task.wait(self.TICK)
			self:_tick()
		end
	end)
	-- (the numbers on screen, every few seconds: sold a minute moves on its own)
	task.spawn(function()
		while true do
			task.wait(3)
			for _, player in Players:GetPlayers() do
				pcall(self.Push, self, player)
			end
		end
	end)
end

return CustomerService
