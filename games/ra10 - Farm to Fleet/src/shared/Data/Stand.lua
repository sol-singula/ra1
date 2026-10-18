--[[
The farm stand grows with the farm level: a cart stand, a produce stall, a farm shop, a country market, each paying
a little more on every sale (`bonus`, on top of the Stand Awning). At stage 5 the market hall takes its place. The
sell pad never moves until then.

  Stand.TIERS[n]     { key, name, level, bonus }
  Stand.tier(level)  the tier a farm level has (1..#TIERS)
  Stand.bonus(level) its sale bonus (0.1 = +10%)
]]
local Stand = {}

-- stylua: ignore start
Stand.TIERS = {
	{ key = "stand",  name = "Farm Stand",     level = 1,  bonus = 0 },
	{ key = "stall",  name = "Produce Stall",  level = 6,  bonus = 0.1 },
	{ key = "shop",   name = "Farm Shop",      level = 12, bonus = 0.2 },
	{ key = "market", name = "Country Market", level = 18, bonus = 0.35 },
}
-- stylua: ignore end

function Stand.tier(level)
	local t = 1
	for i, tier in Stand.TIERS do
		if (level or 1) >= tier.level then
			t = i
		end
	end
	return t
end

function Stand.bonus(level)
	return Stand.TIERS[Stand.tier(level)].bonus
end

return Stand
