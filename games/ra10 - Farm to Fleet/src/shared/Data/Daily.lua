--[[
Coming back (master plan §8): the 7-day calendar and the weekly Big Contract.

The calendar: one reward a UTC day, bigger every day; day 7 is the big one (Gems and golden seeds). Claimed on
consecutive days it walks 1 -> 7 and round again; miss a day and it steps back one day, not to zero.

  Daily.REWARDS[d]             { cash = x per level, gems, seeds } for day d (1..7)
  Daily.reward(d, level)       -> { cash, gems, seeds }
  Daily.next(calendar, today)  -> the day they'd claim today (1..7), and whether the streak held

Golden seeds: each one makes the next planting golden (FarmService:Plant).

The weekly Big Contract: four parts from the week's play (UTC weeks from Monday), measured from the stats at the
week's start like the daily contracts, scaled to the level; Gems and Cash when all four are done.

  Daily.week(t)                the week number
  Daily.weekly(week, userId, level) -> { { key, stat, n, text } x4 }, the reward { cash, gems }
]]
local Daily = {}

-- stylua: ignore start
Daily.REWARDS = {
	{ cash = 200 },
	{ gems = 5 },
	{ cash = 500, seeds = 3 },
	{ gems = 10 },
	{ cash = 1000, seeds = 5 },
	{ gems = 15, seeds = 5 },
	{ cash = 2500, gems = 30, seeds = 15 },
}

Daily.WEEKLY = {
	{ key = "ship",     stat = "shipments",  n = 40,   text = "Ship %d orders" },
	{ key = "harvest",  stat = "harvested",  n = 2000, text = "Harvest %d crops" },
	{ key = "pack",     stat = "packed",     n = 1000, text = "Pack %d crops" },
	{ key = "special",  stat = "specials",   n = 3,    text = "Fill %d Special Orders" },
	{ key = "contract", stat = "contracts",  n = 9,    text = "Finish %d daily contracts" },
	{ key = "feed",     stat = "fed",        n = 20,   text = "Feed your animals %d times" },
	{ key = "pallets",  stat = "palletsShipped", n = 150, text = "Ship %d pallets" },
}
-- stylua: ignore end
Daily.WEEKLY_GEMS = 50

function Daily.reward(d, level)
	local r = Daily.REWARDS[d] or Daily.REWARDS[1]
	level = math.max(1, level or 1)
	return { cash = (r.cash or 0) * level, gems = r.gems or 0, seeds = r.seeds or 0 }
end

function Daily.day(t)
	return math.floor((t or os.time()) / 86400)
end

-- (the calendar's day for today: the next one after a claim yesterday, the same one again after a miss)
function Daily.next(calendar, today)
	local last, d = calendar.claimedDay or 0, calendar.day or 0
	if last <= 0 or d <= 0 then
		return 1, true
	end
	if today - last == 1 then
		return d % 7 + 1, true
	end
	return math.max(1, d), false
end

function Daily.week(t)
	-- (day 0 was a Thursday: +3 makes the weeks start on Monday)
	return math.floor((Daily.day(t) + 3) / 7)
end

function Daily.weekly(week, userId, level)
	local rng = Random.new(week * 104729 + (userId or 0) % 100003)
	rng:NextNumber()
	local keys = {}
	for i = 1, #Daily.WEEKLY do
		keys[i] = i
	end
	for i = #keys, 2, -1 do
		local j = rng:NextInteger(1, i)
		keys[i], keys[j] = keys[j], keys[i]
	end
	local scale = 1 + math.max(0, (level or 1) - 15) * 0.05
	local parts = {}
	for i = 1, 4 do
		local w = Daily.WEEKLY[keys[i]]
		local n = w.n
		if n >= 50 then
			n = math.floor(n * scale / 50 + 0.5) * 50
		end
		table.insert(parts, { key = w.key, stat = w.stat, n = n, text = string.format(w.text, n) })
	end
	table.sort(parts, function(a, b)
		return a.key < b.key
	end)
	return parts, { cash = math.floor(2000 * (level or 1) / 100 + 0.5) * 100, gems = Daily.WEEKLY_GEMS }
end

return Daily
