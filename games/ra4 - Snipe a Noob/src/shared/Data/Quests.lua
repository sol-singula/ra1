-- The daily quest pool. Three are picked each day (seeded by the day, so every server agrees). kind is a stat
-- counted from the start of the day; coins or keys are the pay.
return {
	{ text = "Pop 15 players", kind = "pops", target = 15, coins = 300 },
	{ text = "Pop 40 players", kind = "pops", target = 40, coins = 700 },
	{ text = "Get 3 headshots", kind = "headshots", target = 3, coins = 300 },
	{ text = "Get 10 headshots", kind = "headshots", target = 10, keys = 1 },
	{ text = "Win a round", kind = "wins", target = 1, coins = 600 },
	{ text = "Finish 3 rounds", kind = "rounds", target = 3, coins = 400 },
	{ text = "Pop the crown", kind = "crowns", target = 1, coins = 400 },
	{ text = "Get on the podium", kind = "podiums", target = 1, coins = 500 },
	{ text = "Get a 5 streak", kind = "streak5", target = 1, keys = 1 },
	{ text = "Win a duel", kind = "duelWins", target = 1, coins = 400 },
	{ text = "Play with a friend", kind = "friendPlay", target = 1, coins = 500 },
}
