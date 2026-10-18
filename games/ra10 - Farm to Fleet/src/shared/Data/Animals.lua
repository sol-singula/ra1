--[[
The animals (master plan §6): each pen is a boost for the whole farm, and the boost grows with the animals' level
(no top level: it just costs more each time). Feed them (FEED at their pen, free) and they give the whole boost for
FED_SECONDS; hungry, they give HUNGRY of it. TEND them (a pat) and they're HAPPY: the boost is doubled for
HAPPY_SECONDS, once every TEND_GAP. They make nothing to sell: the crops are the money.

  Animals.LIST        the keys, in unlock order
  Animals[key]        { key, name, pen (the upgrade that builds the pen), boost = { kind, per (a level) }, color,
                        word (what the boost does, said plainly) }
  Animals.upgradeCost(key, level)   Cash to go from level to level + 1
  Animals.count(level)              animals in the pen at a level (more as it grows, up to 8)
  Animals.boost(profile, kind, now) the farm's total boost of a kind (a fraction: 0.15 = +15%)
     kinds: "grow" (every crop grows faster) · "fruitGrow" · "vegPrice" · "machine" (tractor and shop faster)
            · "golden" (the golden-crop chance) · "orders" · "speed" (walking)
  Animals.fed(state, now) -> true while fed
  Animals.happy(state, now) -> true while tended
]]
local Animals = {}

Animals.FED_SECONDS = 4 * 3600
Animals.HUNGRY = 0.5 -- the share of the boost a hungry animal still gives
Animals.HAPPY_SECONDS = 60
Animals.HAPPY_MULT = 2
Animals.TEND_GAP = 120

local rgb = Color3.fromRGB
-- stylua: ignore start
local LIST = {
	{ key = "chicken", name = "Chicken", pen = "chickenCoop", boost = { kind = "grow",      per = 0.04 },  color = rgb(250, 250, 245), word = "crops grow faster" },
	{ key = "pig",     name = "Pig",     pen = "pigPen",      boost = { kind = "vegPrice",  per = 0.04 },  color = rgb(250, 170, 180), word = "vegetables sell for more" },
	{ key = "sheep",   name = "Sheep",   pen = "sheepPen",    boost = { kind = "machine",   per = 0.04 },  color = rgb(245, 245, 240), word = "machines go faster" },
	{ key = "cow",     name = "Cow",     pen = "cowBarn",     boost = { kind = "fruitGrow", per = 0.04 },  color = rgb(250, 250, 250), word = "fruit grows faster" },
	{ key = "goat",    name = "Goat",    pen = "goatPen",     boost = { kind = "orders",    per = 0.02 },  color = rgb(225, 215, 200), word = "orders pay more" },
	{ key = "horse",   name = "Horse",   pen = "stable",      boost = { kind = "speed",     per = 0.02 },  color = rgb(150, 100, 60), word = "you walk faster" },
}
-- stylua: ignore end
-- (the cow's fruit boost brings a little golden luck with it)
Animals.COW_GOLDEN = 0.002

Animals.LIST = {}
for i, a in LIST do
	a.index = i
	Animals[a.key] = a
	table.insert(Animals.LIST, a.key)
end

function Animals.upgradeCost(key, level)
	local a = Animals[key]
	local base = ({ chicken = 400, pig = 1200, sheep = 3000, cow = 7000, goat = 15000, horse = 25000 })[key] or 1000
	_ = a
	return math.floor(base * 1.8 ^ (level - 1) + 0.5)
end

function Animals.count(level)
	return math.min(8, 1 + math.floor((level - 1) / 2))
end

function Animals.happy(state, now)
	return state ~= nil and (state.tendedAt or 0) > 0 and (now - state.tendedAt) < Animals.HAPPY_SECONDS
end

function Animals.fed(state, now)
	-- (fedAt 0: never fed yet)
	return state ~= nil and (state.fedAt or 0) > 0 and (now - state.fedAt) < Animals.FED_SECONDS
end

function Animals.boost(profile, kind, now)
	local total = 0
	for _, key in Animals.LIST do
		local a = Animals[key]
		local st = profile.animals and profile.animals[key]
		if st then
			local k = (Animals.fed(st, now) and 1 or Animals.HUNGRY)
				* (Animals.happy(st, now) and Animals.HAPPY_MULT or 1)
			if a.boost.kind == kind then
				total += a.boost.per * (st.level or 1) * k
			end
			if kind == "golden" and key == "cow" then
				total += Animals.COW_GOLDEN * (st.level or 1) * k
			end
		end
	end
	return total
end

return Animals
