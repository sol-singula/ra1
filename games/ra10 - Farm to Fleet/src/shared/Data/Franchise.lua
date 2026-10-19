--[[
Prestige: life after the hub (master plan §13.5). Once the Market Hall stands, FRANCHISE the company: sell it for
Franchise Stars (from what this run earned) and start a new farm in the next region. Cash, buildings, the stage,
the soil, the warehouse and the orders on the board reset; Gems, golden seeds, the farm level, animals' levels,
the calendar, likes and every stat stay. Stars buy permanent perks, and every Star ever earned lifts all income a
little; each region pays more for what it ships.

  Franchise.stars(earnedThisRun)    the Stars a sale brings: sqrt(earned / STAR_CASH), at least 1
  Franchise.open(profile)           can they franchise now (the Market Hall stands)?
  Franchise.REGIONS[i]              { key, name, mult, ground, trees } (the region of franchise level i - 1)
  Franchise.region(level)           the region a franchise level farms in
  Franchise.PERKS[key]              { key, name, text, step, max, cost(level) }
  Franchise.bonus(profile, key)     what a perk gives them (its level x its step)
  Franchise.incomeMult(profile)     the region's mult x (1 + STAR_BONUS per Star ever earned)
]]
local Franchise = {}

Franchise.STAR_CASH = 1e6 -- (100M this run: 10 Stars)
Franchise.STAR_BONUS = 0.02 -- every Star ever earned: +2% to everything shipped
Franchise.OPEN_AT = "marketHall"

-- stylua: ignore start
Franchise.REGIONS = {
	{ key = "orchard",  name = "Orchard Valley", mult = 1,   ground = Color3.fromRGB(110, 175, 80),  trees = "orchard" },
	{ key = "tropical", name = "Tropical Coast", mult = 1.6, ground = Color3.fromRGB(150, 190, 90),  trees = "palm" },
	{ key = "dairy",    name = "Northern Dairy", mult = 2.4, ground = Color3.fromRGB(120, 160, 120), trees = "pine" },
	{ key = "port",     name = "Mega Port",      mult = 3.5, ground = Color3.fromRGB(150, 160, 150), trees = "crane" },
}

Franchise.ORDER = { "growth", "carry", "headStart", "fleet", "regulars", "nap" }
Franchise.PERKS = {
	growth    = { key = "growth",    name = "Green Thumb",   text = "+10% growth speed a level",       step = 0.1,  max = 5, base = 1 },
	carry     = { key = "carry",     name = "Big Baskets",   text = "+40 basket space a level",        step = 40,   max = 5, base = 1 },
	headStart = { key = "headStart", name = "Head Start",    text = "start each farm with more Cash",  step = 1,    max = 4, base = 2 },
	fleet     = { key = "fleet",     name = "Quick Fleet",   text = "trucks 8% quicker a level",       step = 0.08, max = 4, base = 2 },
	regulars  = { key = "regulars",  name = "Regulars",      text = "+2 customers a minute a level",    step = 2,    max = 5, base = 3 },
	nap       = { key = "nap",       name = "Long Lunch",    text = "+2 h of earnings while away",     step = 1,    max = 4, base = 2 },
}
-- stylua: ignore end
Franchise.HEAD_START = { 0, 2000, 20000, 150000, 1000000 } -- the Cash a new farm starts with, by Head Start level

function Franchise.cost(key, level)
	local perk = Franchise.PERKS[key]
	return perk.base * (level + 1)
end

function Franchise.stars(earned)
	return math.max(1, math.floor(math.sqrt(math.max(0, earned or 0) / Franchise.STAR_CASH)))
end

function Franchise.open(p)
	return p.owned ~= nil and p.owned[Franchise.OPEN_AT] ~= nil
end

function Franchise.region(level)
	return Franchise.REGIONS[math.clamp((level or 0) + 1, 1, #Franchise.REGIONS)]
end

local function state(p)
	return p.franchise or { level = 0, perks = {}, total = 0 }
end

function Franchise.bonus(p, key)
	local perk = Franchise.PERKS[key]
	local f = state(p)
	return perk and (f.perks and f.perks[key] or 0) * perk.step or 0
end

function Franchise.incomeMult(p)
	local f = state(p)
	return Franchise.region(f.level).mult * (1 + Franchise.STAR_BONUS * (f.total or 0))
end

return Franchise
