--[[
The market board (Data/Market): the day's orders, delivered out of your stock for a bonus. Each is done once a
day; a new day brings new ones.

  MarketService:Orders(player)         the day's list with done flags
  MarketService:Deliver(player, id)    ok, why
  MarketService:Push(player)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Market = require(ReplicatedStorage.Shared.Data.Market)
local Net = require(ReplicatedStorage.Shared.Net)

local MarketService = {
	Name = "MarketService",
	Dependencies = { "PlayerDataService", "EconomyService", "BusinessService" },
}

local data, economy, analytics

local function state(p)
	p.market = p.market or { day = 0, done = {} }
	local day = Market.day()
	if p.market.day ~= day then
		p.market.day = day
		p.market.done = {}
	end
	return p.market
end

function MarketService:Orders(player)
	local p = data:Get(player)
	if not p then
		return {}
	end
	local m = state(p)
	local list = Market.orders(p, m.day)
	for _, o in list do
		o.done = m.done[o.id] == true
		o.have = p.stock[o.crop] or 0
	end
	return list
end

function MarketService:Deliver(player, id)
	local p = data:Get(player)
	if not p then
		return false, "no profile"
	end
	local m = state(p)
	if m.done[id] then
		return false, "done"
	end
	local order
	for _, o in Market.orders(p, m.day) do
		if o.id == id then
			order = o
		end
	end
	if not order then
		return false, "unknown"
	end
	if (p.stock[order.crop] or 0) < order.n then
		Net.fire(player, "Toast", `Not enough {order.crop} in stock: {p.stock[order.crop] or 0}/{order.n}`, "bad")
		return false, "stock"
	end
	p.stock[order.crop] -= order.n
	if p.stock[order.crop] == 0 then
		p.stock[order.crop] = nil
	end
	m.done[id] = true
	p.stats.orders = (p.stats.orders or 0) + 1
	p.stats.sold = (p.stats.sold or 0) + order.n
	local cash = math.floor(order.pays * economy:Multiplier(player) + 0.5)
	economy:Add(player, cash, "order")
	Net.fire(player, "Toast", `{order.name} delivered: +{Format.cash(cash)}!`, "good")
	if analytics then
		pcall(analytics.event, player, "order", { crop = order.crop, n = order.n, cash = cash })
	end
	self:Push(player)
	return true
end

function MarketService:Push(player)
	Net.fire(player, "Market", { orders = self:Orders(player), day = Market.day() })
end

function MarketService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	analytics = registry.AnalyticsService
	Net.on("Market", function(player, what, id)
		if what == "open" then
			self:Push(player)
		elseif what == "deliver" and type(id) == "string" then
			self:Deliver(player, id)
		end
	end)
	registry.UpgradeService.Applied:Connect(function(player)
		self:Push(player)
	end)
	_ = Players
end

function MarketService:OnPlayerReady(player)
	data:WhenClientReady(player, function()
		self:Push(player)
	end)
end

return MarketService
