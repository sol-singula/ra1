--[[
The Odds panel's rows, generated from a Config table at runtime (never hand-typed), so the panel always matches the
real numbers.

  Odds.rows(config) -> { { section, text } }
]]
local Odds = {}

local function pct(x)
	local text = string.format("%.1f", x * 100)
	return (text:gsub("%.0$", "")) .. "%"
end

function Odds.rows(config)
	local rows = {}
	local function add(section, text)
		table.insert(rows, { section = section, text = text })
	end
	local restock = config.Restock
	add("Seeds", `New seeds every {restock.intervalSec // 60} minutes`)
	for _, key in restock.order do
		local seed, s = config.Seeds[key], restock.stock[key]
		local text = `{seed.name}: {pct(s.chance)} each restock, {s.qty} in stock`
		if s.eventOnly or seed.gate.eventOnly then
			text ..= " (event weeks only)"
		end
		add("Seeds", text)
	end
	local pick = config.Weather.pick
	add("Weather", `When the sunflower blooms: Rain {pct(pick.rain)}, Golden Hour {pct(pick.goldenHour)}`)
	local m = config.Mutations
	add(
		"Mutations",
		`Wet: {pct(m.wet.chance.rain)} per crop in Rain, {pct(m.wet.chance.welcomeShower)} in the Welcome Shower`
	)
	add("Mutations", `Golden: {pct(m.golden.chance.goldenHour)} per crop in Golden Hour`)
	add("Mutations", `Value: Wet x{m.wet.mult}, Golden x{m.golden.mult}, Wet + Golden x{m.stackMult}`)
	add("Mutations", "Each mutation happens at most once per crop; a Wet crop can still turn Golden")
	add("Mutations", "One roll per tile each Block Party, regrown crops included")
	local shower = config.Weather.welcomeShower
	add(
		"Welcome Shower",
		`{shower.guaranteeWet} guaranteed Wet crop {shower.guaranteeWetAtSec}s into your first shower`
	)
	local bp = config.BlockParty
	add("Block Party", `Goal: max({bp.goalMin}, {bp.goalPerPlayer} x players) waters, set when it opens`)
	add(
		"Block Party",
		`Private servers: max({bp.privateServer.goalMin}, {bp.privateServer.goalPerPlayer} x players), {bp.privateServer.minWaters}+ waters for the reward`
	)
	add("Block Party", `The sunflower always blooms by :{string.format("%02d", bp.windowSec // 60)}, goal or not`)
	add(
		"Block Party",
		`Water {bp.reward.minWaters}+ times for a reward of {bp.reward.coinsPerLevelSq} x your plot level²`
	)
	return rows
end

return Odds
