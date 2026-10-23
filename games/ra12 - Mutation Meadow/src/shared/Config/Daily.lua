-- The 7-day login calendar; a missed day pauses the streak. Day 7 gives the trail on the first cycle only.
return {
	resetUtcHour = 0,
	missedDay = "pause",
	days = {
		{ coins = 100 },
		{ seeds = { pumpkin = 1 } },
		{ coins = 500 },
		{ seeds = { corn = 3 } },
		{ coins = 1500 },
		{ seeds = { watermelon = 2 } },
		{ seeds = { pumpkin = 5 }, firstCycle = "trail_petals", repeatCoins = 2500 },
	},
}
