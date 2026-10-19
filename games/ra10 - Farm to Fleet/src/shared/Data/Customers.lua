--[[
The customers: the one bottleneck. Crops pile up in the barn as fast as the field grows them; customers come to the
stand and buy them, a few at a time, at a rate the shop's upgrades set. A full barn means the shop can't keep up:
buy the next shop upgrade (a sign, a bell, a helper, a parking lot...) and more customers come.

  Customers.rate(profile, now)   customers a minute: BASE plus every "customers" upgrade, the goats, the Regulars
                                 perk and the More Customers pass
  Customers.basket(owned)        crops each customer buys (the "basket" upgrades: the helper, a second counter)
  Customers.sellRate(profile, now)  crops a minute the shop can sell
  Customers.NAMES                who they are (a toast and the little figure that walks up)
]]
local Animals = require(script.Parent.Animals)
local Franchise = require(script.Parent.Franchise)
local Upgrades = require(script.Parent.Upgrades)

local Customers = {}

Customers.BASE = 4 -- customers a minute from the first minute
Customers.PASS_BONUS = 5 -- the More Customers pass

Customers.NAMES = {
	"Mia",
	"Leo",
	"Ava",
	"Noah",
	"Zoe",
	"Max",
	"Lily",
	"Sam",
	"Ruby",
	"Jack",
	"Nora",
	"Eli",
	"Grandma Jo",
	"Chef Pat",
	"Mr. Lee",
	"Coach Dan",
}

function Customers.rate(p, now)
	local owned = p and p.owned or {}
	local base = Customers.BASE + Upgrades.stat(owned, "customers", 0)
	if p and p.passes and p.passes.moreCustomers then
		base += Customers.PASS_BONUS
	end
	base += Franchise.bonus(p, "regulars")
	local rush = p and (p.rushUntil or 0) > os.time() and 2 or 1
	return base * (1 + Animals.boost(p, "customers", now or 0)) * rush
end

function Customers.basket(owned)
	return Upgrades.stat(owned or {}, "basket", 1)
end

function Customers.sellRate(p, now)
	return Customers.rate(p, now) * Customers.basket(p and p.owned)
end

return Customers
