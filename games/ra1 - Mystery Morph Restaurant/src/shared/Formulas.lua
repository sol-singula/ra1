-- Pure game formulas from the GDD canon. No Roblox APIs here, so tests/Formulas.spec.luau can run them
-- outside the engine. The server uses these for outcomes; the client only for previews.
local Formulas = {}

local function clamp(x, lo, hi)
	return math.max(lo, math.min(hi, x))
end
Formulas.clamp = clamp

local function round(x)
	return math.floor(x + 0.5)
end
Formulas.round = round

-- [C5.1] XP needed to go from level L to L+1.
function Formulas.xpReq(level)
	return round((180 + 30 * level) * 1.045 ^ (level - 1))
end

-- [C5] Player HP.
function Formulas.maxHp(level, bonus)
	return 100 + 2 * (level - 1) + (bonus or 0)
end

-- [C5] Effective stat with its cap applied.
function Formulas.capped(value, cap)
	return math.min(value, cap)
end

-- [C5] Stat effects.
function Formulas.cookTimeMult(cookSpd)
	return 1 / (1 + 0.006 * cookSpd)
end
function Formulas.perfectWindowMult(cookQlt)
	return 1 + 0.005 * cookQlt
end
function Formulas.burnDelayMult(cookQlt)
	return 1 + 0.004 * cookQlt
end
function Formulas.damageMult(str)
	return 1 + 0.008 * str
end
function Formulas.damageTakenMult(def)
	return 100 / (100 + def)
end
function Formulas.repairMult(repair)
	return 1 + 0.01 * repair
end
function Formulas.walkSpeed(move)
	return 16 * (1 + 0.003 * move)
end
function Formulas.patienceMult(charm)
	return 1 + 0.004 * charm
end
function Formulas.escalationMult(charm)
	return 100 / (100 + charm)
end
function Formulas.ingredientCostMult(efficiency)
	return 1 - 0.0015 * efficiency
end

-- [C8] Heat timing grade for a component that has been cooking `elapsed` seconds.
-- Returns grade name, score, and whether the station has caught fire.
function Formulas.heatGrade(elapsed, tReady, window, burnAfter, fireAfter)
	if elapsed < tReady then
		return "UNDERCOOKED", 0.35, false
	elseif elapsed <= tReady + window then
		return "PERFECT", 1.0, false
	elseif elapsed <= tReady + burnAfter then
		return "GOOD", 0.8, false
	elseif elapsed <= tReady + burnAfter + fireAfter then
		return "BURNED", 0.15, false
	end
	return "RUINED", 0.0, true
end

-- [C8] One chop tap judged by where the timing ring is in its sweep (phase 0..1, green zone centred on 0.5).
function Formulas.chopTapScore(phase)
	local d = math.abs(phase - 0.5)
	if d <= 0.1 then
		return 1.0
	elseif d <= 0.25 then
		return 0.8
	end
	return 0.6
end

-- MVP pour grade: stop the fill between 85 % and 100 % for Perfect.
function Formulas.pourGrade(fill)
	if fill > 1.0 then
		return "SPILLED", 0.35
	elseif fill >= 0.85 then
		return "PERFECT", 1.0
	elseif fill >= 0.7 then
		return "GOOD", 0.8
	elseif fill >= 0.5 then
		return "OK", 0.6
	end
	return "UNDERFILLED", 0.35
end

local function mean(list)
	if #list == 0 then
		return 1
	end
	local sum = 0
	for _, v in list do
		sum += v
	end
	return sum / #list
end
Formulas.mean = mean

-- [C11.2] Patience in seconds for an order.
function Formulas.patience(items, sumDifficulty, personalityMult, charm)
	return (70 + 20 * (items - 1) + 5 * sumDifficulty) * personalityMult * Formulas.patienceMult(charm)
end

-- [C11.3] W: 1.0 if served within 50 % of patience, linear to 0 at 100 %.
function Formulas.waitFactor(waited, patience)
	if patience <= 0 then
		return 0
	end
	local r = waited / patience
	if r <= 0.5 then
		return 1
	end
	return clamp(1 - (r - 0.5) / 0.5, 0, 1)
end

-- [C11.3] Satisfaction. f = { A, Q, C, W, K, M } each 0..1; p = personality row; bonus = mutation/event terms.
function Formulas.satisfaction(f, p, bonus)
	local base = 100 * (0.25 * f.A + 0.2 * f.Q + 0.15 * f.C + 0.2 * f.W + 0.1 * f.K + 0.1 * f.M)
	return clamp(base * p.pMult + p.pOffset + (bonus or 0), 0, 100)
end

-- [C11.3] Mood label using the personality's thresholds.
function Formulas.mood(s, thresholds)
	if s >= thresholds[1] then
		return "Delighted"
	elseif s >= thresholds[2] then
		return "Happy"
	elseif s >= thresholds[3] then
		return "Meh"
	elseif s >= thresholds[4] then
		return "Unhappy"
	end
	return "Furious"
end

-- [C11.4] PayFactor and TipRate.
function Formulas.payFactor(s)
	if s >= 50 then
		return 1.0
	elseif s >= 30 then
		return 0.8
	end
	return 0.6
end

function Formulas.tipRate(s)
	if s >= 98 then
		return 0.25
	elseif s >= 90 then
		return 0.18
	elseif s >= 80 then
		return 0.1
	elseif s >= 70 then
		return 0.05
	end
	return 0
end

-- [C11.4] Payment for a served order. `roll` is a 0..1 random number for the Jackpot Tip.
-- Returns pay, tip, jackpot (bool). Values are whole MB.
function Formulas.payment(priceSum, s, tipMult, luck, roll, tierIndex)
	local pay = round(priceSum * Formulas.payFactor(s))
	local tip = priceSum * Formulas.tipRate(s) * tipMult
	local jackpot = false
	if s >= 90 and roll < (0.005 + 0.001 * luck) then
		jackpot = true
		tip = math.min(tip * 5, tierIndex <= 4 and 500 or 5000)
	end
	return pay, round(tip), jackpot
end

-- [C11.4] Reputation stars after one customer.
function Formulas.updateStars(stars, s)
	return clamp(stars + 0.02 * (s / 20 - stars), 1, 5)
end
function Formulas.repMult(stars)
	return 0.5 + 0.25 * stars
end
function Formulas.decorMult(atmosphere)
	return 0.9 + 0.003 * atmosphere
end

-- [C6] Online customers per hour.
function Formulas.demandPerHour(baseDemand, stars, atmosphere)
	return baseDemand * Formulas.repMult(stars) * Formulas.decorMult(atmosphere)
end

-- [C11.5] Anger level 0..6 from the 0..100 meter.
function Formulas.angerLevel(anger, floors)
	local level = 0
	for i, floor in floors do
		if anger >= floor then
			level = i - 1
		end
	end
	return level
end

-- [C11.5] Chance that a customer escalates into anger level 3, 4 or 5.
function Formulas.escalationChance(angerP, charm)
	return angerP * Formulas.escalationMult(charm)
end

-- [36.6 ABL_006] Anger removed by Calm Down!
function Formulas.calmAmount(charm)
	return math.min(20 + 0.1 * charm, 35)
end

-- [C12] Damage dealt to a customer and to a player.
function Formulas.damageToCustomer(base, str, customerDef)
	return base * Formulas.damageMult(str) * Formulas.damageTakenMult(customerDef)
end
function Formulas.damageToPlayer(base, personalityDmg, playerDef)
	return base * personalityDmg * Formulas.damageTakenMult(playerDef)
end

-- [C6] Furniture damage state name from durability 0..100.
function Formulas.damageState(durability, states)
	for _, st in states do
		if durability >= st.min then
			return st.name
		end
	end
	return states[#states].name
end

--[[
Recipe matching. `contents` maps "ING_X|STATE" -> count. A dish matches a recipe when every present key
is one of the recipe's parts with exactly the required count, and every core ingredient is present.
Missing non-core parts are "omitted". Returns ok, omittedIngredientIds (sorted).
]]
function Formulas.matchRecipe(recipe, contents)
	if recipe.drink then
		return false, {}
	end
	local need = {}
	for _, part in recipe.parts do
		need[part[1] .. "|" .. part[3]] = part[2]
	end
	for key, count in contents do
		if need[key] ~= count then
			return false, {}
		end
	end
	local omitted = {}
	for _, part in recipe.parts do
		if not contents[part[1] .. "|" .. part[3]] then
			if table.find(recipe.core, part[1]) then
				return false, {}
			end
			table.insert(omitted, part[1])
		end
	end
	table.sort(omitted)
	return true, omitted
end

-- Best-matching recipe among `recipes` (fewest omissions, then list order). Returns recipe, omitted.
function Formulas.bestMatch(recipes, contents)
	local best, bestOmitted
	for _, recipe in recipes do
		local ok, omitted = Formulas.matchRecipe(recipe, contents)
		if ok and (best == nil or #omitted < #bestOmitted) then
			best, bestOmitted = recipe, omitted
		end
	end
	return best, bestOmitted
end

-- Order accuracy A for one item: 1 when the omissions are exactly what was asked for, −0.25 per mismatch.
function Formulas.accuracy(omittedByDish, omittedRequested)
	local mismatches = 0
	local want = {}
	for _, id in omittedRequested do
		want[id] = true
	end
	local got = {}
	for _, id in omittedByDish do
		got[id] = true
		if not want[id] then
			mismatches += 1
		end
	end
	for id in want do
		if not got[id] then
			mismatches += 1
		end
	end
	return clamp(1 - 0.25 * mismatches, 0, 1)
end

return Formulas
