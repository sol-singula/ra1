-- Daily tasks and the weekly challenge (master plan §20). Three dailies a day and one weekly, picked the same way
-- on every server for the same player and day, so rejoining never rerolls them. `stat` is a match stat
-- (ProgressService counts it as it happens).
local Tasks = {}

Tasks.daily = {
	{ key = "build10", line = "Help build 10 pieces", stat = "built", goal = 10, coins = 40 },
	{ key = "beat15", line = "Beat 15 monsters", stat = "beaten", goal = 15, coins = 40 },
	{ key = "mine60", line = "Mine 60 stone, wood or gold", stat = "mined", goal = 60, coins = 30 },
	{ key = "dwarves3", line = "Beat 3 dwarves as a monster", stat = "dwarvesBeaten", goal = 3, coins = 45 },
	{ key = "break5", line = "Break 5 castle pieces as a monster", stat = "broken", goal = 5, coins = 40 },
	{ key = "matches2", line = "Play 2 matches", stat = "matches", goal = 2, coins = 40 },
	{ key = "hold5", line = "Stay a dwarf for 5 minutes of the fight", stat = "heldSeconds", goal = 300, coins = 50 },
	{ key = "traps3", line = "Build 3 traps", stat = "traps", goal = 3, coins = 30 },
	{ key = "heal200", line = "Heal 200 health", stat = "healed", goal = 200, coins = 35 },
	{ key = "fix300", line = "Fix 300 damage on the castle", stat = "fixed", goal = 300, coins = 35 },
	{
		key = "craft2",
		line = "Make 2 things at a forge, kitchen or potion table",
		stat = "crafted",
		goal = 2,
		coins = 30,
	},
}

Tasks.weekly = {
	{ key = "w_beat200", line = "Beat 200 monsters this week", stat = "beaten", goal = 200, coins = 300 },
	{ key = "w_build80", line = "Help build 80 pieces this week", stat = "built", goal = 80, coins = 300 },
	{ key = "w_matches12", line = "Play 12 matches this week", stat = "matches", goal = 12, coins = 300 },
}

Tasks.byKey = {}
for _, t in Tasks.daily do
	Tasks.byKey[t.key] = t
end
for _, t in Tasks.weekly do
	t.weekly = true
	Tasks.byKey[t.key] = t
end

-- The day (UTC) and week numbers a timestamp falls in.
function Tasks.day(t)
	return math.floor(t / 86400)
end
function Tasks.week(t)
	return math.floor((t / 86400 + 3) / 7) -- weeks start on Monday
end

-- A small deterministic shuffle (same seed, same order) so every server picks the same tasks.
local function seeded(seed, n)
	local order = {}
	for i = 1, n do
		order[i] = i
	end
	local state = (seed % 2147483646) + 1
	for i = n, 2, -1 do
		state = (state * 48271) % 2147483647
		local j = state % i + 1
		order[i], order[j] = order[j], order[i]
	end
	return order
end

-- The daily task keys for this player today.
function Tasks.pickDaily(userId, day)
	local order = seeded(day * 7919 + (userId % 100000), #Tasks.daily)
	local keys = {}
	for i = 1, 3 do
		table.insert(keys, Tasks.daily[order[i]].key)
	end
	return keys
end

function Tasks.pickWeekly(userId, week)
	local order = seeded(week * 104729 + (userId % 100000), #Tasks.weekly)
	return Tasks.weekly[order[1]].key
end

return Tasks
