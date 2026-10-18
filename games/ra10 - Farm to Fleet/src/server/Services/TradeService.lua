--[[
Buying from the neighbours. Once the orders start (the packing shed), whenever an open order is short of something and
another farmer on the server has spare (their excess: FarmService:Excess), a pop-up offers it: "Ben has 80
Strawberries: buy them for $1,200?". BUY sends Ben a request; he gets the Cash if he says SELL, and the crops go
straight into the buyer's stock. One offer at a time; a declined or ignored offer for that thing doesn't come back
for COOLDOWN seconds; a request waits ASK_WAIT seconds for an answer.

  price    PREMIUM times what the stand would pay the seller for them
  Net "Trade" to a player: { kind = "offer", id, from, item, name, n, price } | { kind = "request", id, from, item,
           name, n, price } | { kind = "done" | "declined" | "gone", id }
  Net "Trade" from a player: ("buy", id) | ("skip", id) | ("sell", id) | ("no", id)

  TradeService:Scan(player) -> the offer made, or nil
  TradeService:Ask(player, id) -> ok
  TradeService:Answer(player, id, yes) -> ok
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Orders = require(ReplicatedStorage.Shared.Data.Orders)

local TradeService = {
	Name = "TradeService",
	Dependencies = { "PlayerDataService", "EconomyService", "FarmService", "OrderService" },
	TICK = 5,
	COOLDOWN = 60,
	ASK_WAIT = 20,
	PREMIUM = 1.5,
}

local data, economy, farm, orders
local offers = {} -- [buyer] = the offer on their screen { id, seller, item, n, price, at, asked }
local snoozed = {} -- [buyer] = { [item] = until }
local nextId = 0

local function now()
	return workspace:GetServerTimeNow()
end

local function shopOpen(p)
	return p and p.owned and p.owned.shed ~= nil
end

-- What a farmer's open orders are still short of: { [item] = n }
local function short(player)
	local out = {}
	for item, want in orders:Needs(player) do
		local n = want - farm:Have(player, item)
		if n > 0 then
			out[item] = n
		end
	end
	return out
end

function TradeService:Scan(buyer)
	local p = data:Get(buyer)
	if not shopOpen(p) or offers[buyer] then
		return nil
	end
	local t = now()
	local snooze = snoozed[buyer] or {}
	for item, need in short(buyer) do
		if (snooze[item] or 0) <= t then
			for _, seller in Players:GetPlayers() do
				if seller ~= buyer and data:Get(seller) then
					local spare = farm:Excess(seller)[item] or 0
					if spare > 0 then
						local n = math.min(need, spare)
						local price = math.max(1, math.floor(farm:Worth(seller, { [item] = n }) * self.PREMIUM + 0.5))
						if (p.cash or 0) >= price then
							nextId += 1
							local offer = { id = nextId, seller = seller, item = item, n = n, price = price, at = t }
							offers[buyer] = offer
							Net.fire(buyer, "Trade", {
								kind = "offer",
								id = offer.id,
								from = seller.DisplayName,
								item = item,
								name = Orders.itemName(item),
								n = n,
								price = price,
							})
							return offer
						end
					end
				end
			end
		end
	end
	return nil
end

local function snooze(buyer, item)
	snoozed[buyer] = snoozed[buyer] or {}
	snoozed[buyer][item] = now() + TradeService.COOLDOWN
end

function TradeService:Ask(buyer, id)
	local offer = offers[buyer]
	if not offer or offer.id ~= id or offer.asked or not offer.seller.Parent then
		return false
	end
	offer.asked = now()
	Net.fire(offer.seller, "Trade", {
		kind = "request",
		id = offer.id,
		from = buyer.DisplayName,
		item = offer.item,
		name = Orders.itemName(offer.item),
		n = offer.n,
		price = offer.price,
	})
	Net.fire(buyer, "Toast", `Asked {offer.seller.DisplayName}...`, "info")
	return true
end

-- The seller's answer to the request with this id
function TradeService:Answer(seller, id, yes)
	for buyer, offer in offers do
		if offer.id == id and offer.seller == seller and offer.asked then
			offers[buyer] = nil
			if not yes then
				snooze(buyer, offer.item)
				Net.fire(buyer, "Trade", { kind = "declined", id = id })
				Net.fire(buyer, "Toast", `{seller.DisplayName} said no this time`, "info")
				return false
			end
			local bp = data:Get(buyer)
			local spare = farm:Excess(seller)[offer.item] or 0
			if not bp or spare < offer.n or (bp.cash or 0) < offer.price then
				Net.fire(buyer, "Trade", { kind = "gone", id = id })
				Net.fire(seller, "Toast", "The deal fell through: they're gone, or the crops are", "info")
				return false
			end
			farm:Remove(seller, offer.item, offer.n)
			bp.stock = bp.stock or {}
			bp.stock[offer.item] = (bp.stock[offer.item] or 0) + offer.n
			economy:Spend(buyer, offer.price)
			economy:Add(seller, offer.price, "trade")
			local words = `{offer.n} {Orders.itemName(offer.item)} for {Format.cash(offer.price)}`
			Net.fire(buyer, "Trade", { kind = "done", id = id })
			Net.fire(buyer, "Toast", `Bought {words} from {seller.DisplayName}!`, "good")
			Net.fire(seller, "Toast", `Sold {words} to {buyer.DisplayName}!`, "good")
			farm:Push(buyer)
			farm:Push(seller)
			farm.Changed:Fire(buyer, "trade")
			return true
		end
	end
	return false
end

function TradeService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	farm = registry.FarmService
	orders = registry.OrderService
	Net.on("Trade", function(player, what, id)
		if type(id) ~= "number" then
			return
		end
		if what == "buy" then
			self:Ask(player, id)
		elseif what == "skip" then
			local offer = offers[player]
			if offer and offer.id == id then
				offers[player] = nil
				snooze(player, offer.item)
			end
		elseif what == "sell" or what == "no" then
			self:Answer(player, id, what == "sell")
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		offers[player] = nil
		snoozed[player] = nil
		for buyer, offer in offers do
			if offer.seller == player then
				offers[buyer] = nil
				Net.fire(buyer, "Trade", { kind = "gone", id = offer.id })
			end
		end
	end)
end

function TradeService:Start()
	task.spawn(function()
		while true do
			task.wait(self.TICK)
			local t = now()
			for buyer, offer in offers do
				-- (an offer left on screen, or a request left unanswered, goes away)
				if t - offer.at > self.ASK_WAIT * 2 or (offer.asked and t - offer.asked > self.ASK_WAIT) then
					offers[buyer] = nil
					snooze(buyer, offer.item)
					Net.fire(buyer, "Trade", { kind = "gone", id = offer.id })
				end
			end
			for _, player in Players:GetPlayers() do
				pcall(self.Scan, self, player)
			end
		end
	end)
end

return TradeService
