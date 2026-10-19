--[[
The animals: boosters for the whole farm. Each kind has a pen on the front lawn, bought and levelled on the pen's
pad (an upgrade: Data/Upgrades "chicken", "pig", ...). Every level adds to the boost. They make nothing to sell.

Keeping them going is the thing to do while the money comes in:
  FEED   step on the feed plate at the pen's gate: fed animals give the whole boost for FED_SECONDS, hungry ones
         only HUNGRY of it
  PET    step on the plate again once they're fed: happy animals double the boost for HAPPY_SECONDS (once every
         PET_GAP)

  Animals.LIST                     the keys, in unlock order
  Animals[key]                     { key, name, icon, boost = { kind, per (a level) }, color, word }
  Animals.boost(profile, kind, now)   the farm's total boost of a kind (0.24 = +24%)
     kinds: "grow" (crops grow faster) · "price" (every sale pays more) · "service" (the counter sells faster)
            · "machine" (the harvesters clear faster)
  Animals.fed(state, now) / Animals.happy(state, now)
  Animals.count(level)             animals in the pen at a level (more as it grows, up to 8)
]]
local Animals = {}

Animals.FED_SECONDS = 150
Animals.HUNGRY = 0.4
Animals.HAPPY_SECONDS = 40
Animals.HAPPY_MULT = 2
Animals.PET_GAP = 60

local rgb = Color3.fromRGB
-- stylua: ignore start
local LIST = {
	{ key = "chicken", name = "Chickens", icon = "🐔", boost = { kind = "grow",    per = 0.05 }, color = rgb(250, 250, 245), word = "crops grow faster" },
	{ key = "pig",     name = "Pigs",     icon = "🐷", boost = { kind = "price",   per = 0.05 }, color = rgb(250, 170, 180), word = "every sale pays more" },
	{ key = "cow",     name = "Cows",     icon = "🐮", boost = { kind = "service", per = 0.05 }, color = rgb(250, 250, 250), word = "the counter sells faster" },
	{ key = "sheep",   name = "Sheep",    icon = "🐑", boost = { kind = "machine", per = 0.05 }, color = rgb(240, 238, 230), word = "harvesters work faster" },
}
-- stylua: ignore end

Animals.LIST = {}
for i, a in LIST do
	a.index = i
	Animals[a.key] = a
	table.insert(Animals.LIST, a.key)
end

function Animals.count(level)
	return math.clamp(1 + math.floor(((level or 1) - 1) / 2), 1, 8)
end

function Animals.fed(state, now)
	return state ~= nil and (state.fedAt or 0) > 0 and now - state.fedAt < Animals.FED_SECONDS
end

function Animals.happy(state, now)
	return state ~= nil and (state.pettedAt or 0) > 0 and now - state.pettedAt < Animals.HAPPY_SECONDS
end

-- The share of the boost an animal gives now: 1 fed, HUNGRY hungry, doubled while happy
function Animals.share(state, now)
	return (Animals.fed(state, now) and 1 or Animals.HUNGRY) * (Animals.happy(state, now) and Animals.HAPPY_MULT or 1)
end

function Animals.boost(profile, kind, now)
	local total = 0
	for _, key in Animals.LIST do
		local a = Animals[key]
		local level = profile.owned and profile.owned[key] or 0
		if level > 0 and a.boost.kind == kind then
			local st = profile.animals and profile.animals[key]
			total += a.boost.per * level * Animals.share(st, now)
		end
	end
	return total
end

return Animals
