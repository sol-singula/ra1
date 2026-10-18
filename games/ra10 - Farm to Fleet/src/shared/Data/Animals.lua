--[[
The animals (master plan §6): they live in pens outside (never in the warehouse), make a product to sell and give
the whole farm a boost that grows with their level. Fed within FED_SECONDS they give everything; hungry they give
half (never nothing). Feeding takes FEED_CROPS crops from the basket: the farm feeds the animals.

  Animals.LIST        the keys, in unlock order
  Animals[key]        { key, name, pen (the upgrade that builds the pen), product, productName, value (Cash each),
                        every (seconds per product at level 1), boost = { kind, per (a level) }, color }
  Animals.MAX_LEVEL
  Animals.upgradeCost(key, level)   Cash to go from level to level + 1
  Animals.count(level)              animals in the pen at a level (more as it grows)
  Animals.boost(profile, kind, now) the farm's total boost of a kind (a fraction: 0.15 = +15%)
     kinds: "grow" (every crop grows faster) · "fruitGrow" · "vegPrice" · "machine" (tractor and conveyor faster)
            · "golden" (the golden-crop chance) · "orders" · "speed" (walking)
  Animals.fed(state, now) -> true while fed
  Animals.product(key)              { name, value } for a product key (eggs, truffles...), or nil
]]
local Animals = {}

Animals.MAX_LEVEL = 10
Animals.FED_SECONDS = 4 * 3600
Animals.FEED_CROPS = 5
Animals.HUNGRY = 0.5 -- the share of the boost (and of the products) a hungry animal still gives
Animals.READY_CAP = 12 -- products a pen holds before it stops making more

local rgb = Color3.fromRGB
-- stylua: ignore start
local LIST = {
	{ key = "chicken", name = "Chicken", pen = "chickenCoop", product = "egg",     productName = "Eggs",     value = 10,  every = 20, boost = { kind = "grow",      per = 0.03 },  color = rgb(250, 250, 245) },
	{ key = "pig",     name = "Pig",     pen = "pigPen",      product = "truffle", productName = "Truffles", value = 30,  every = 30, boost = { kind = "vegPrice",  per = 0.03 },  color = rgb(250, 170, 180) },
	{ key = "sheep",   name = "Sheep",   pen = "sheepPen",    product = "wool",    productName = "Wool",     value = 60,  every = 40, boost = { kind = "machine",   per = 0.03 },  color = rgb(245, 245, 240) },
	{ key = "cow",     name = "Cow",     pen = "cowBarn",     product = "milk",    productName = "Milk",     value = 110, every = 50, boost = { kind = "fruitGrow", per = 0.03 },  color = rgb(250, 250, 250) },
	{ key = "goat",    name = "Goat",    pen = "goatPen",     product = "cheese",  productName = "Cheese",   value = 220, every = 60, boost = { kind = "orders",    per = 0.02 },  color = rgb(225, 215, 200) },
	{ key = "horse",   name = "Horse",   pen = "stable",      product = nil,       productName = nil,        value = 0,   every = 0,  boost = { kind = "speed",     per = 0.02 },  color = rgb(150, 100, 60) },
}
-- stylua: ignore end
-- (the cow's fruit boost brings a little golden luck with it)
Animals.COW_GOLDEN = 0.002

Animals.LIST = {}
local byProduct = {}
for i, a in LIST do
	a.index = i
	Animals[a.key] = a
	table.insert(Animals.LIST, a.key)
	if a.product then
		byProduct[a.product] = a
	end
end

function Animals.upgradeCost(key, level)
	local a = Animals[key]
	local base = ({ chicken = 400, pig = 1200, sheep = 3000, cow = 7000, goat = 15000, horse = 25000 })[key] or 1000
	_ = a
	return math.floor(base * 1.8 ^ (level - 1) + 0.5)
end

function Animals.count(level)
	return 1 + math.floor((level - 1) / 2)
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
			local k = Animals.fed(st, now) and 1 or Animals.HUNGRY
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

function Animals.product(key)
	local a = byProduct[key]
	return a and { name = a.productName, value = a.value, animal = a.key } or nil
end

return Animals
