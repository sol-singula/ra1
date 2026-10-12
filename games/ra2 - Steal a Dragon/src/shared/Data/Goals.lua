-- Goals shown at the top of the screen after the tutorial, one at a time.
-- kind names a number the server tracks (see RewardService.progressOf).
return {
	{ text = "Lock your door: step on the RED pad", kind = "locks", target = 1, reward = 50 },
	{ text = "Buy 2 dragons on the road", kind = "bought", target = 2, reward = 100 },
	{ text = "Steal a dragon from a player", kind = "steals", target = 1, reward = 250 },
	{ text = "Buy a new nest", kind = "nests", target = 5, reward = 300 },
	{ text = "Get a Rare dragon", kind = "rarity", target = 2, reward = 300 },
	{ text = "Get Speed level 2", kind = "speed", target = 2, reward = 400 },
	{ text = "Lock your door 5 times", kind = "locks", target = 5, reward = 500 },
	{ text = "Bonk 3 thieves", kind = "bonks", target = 3, reward = 750 },
	{ text = "Earn 5,000 coins", kind = "earned", target = 5000, reward = 750 },
	{ text = "Get an Epic dragon", kind = "rarity", target = 3, reward = 1500 },
	{ text = "Play with a friend", kind = "friendPlay", target = 1, reward = 2000 },
	{ text = "Grow a dragon to Kid size", kind = "stage", target = 2, reward = 2000 },
	{ text = "Steal 10 dragons", kind = "steals", target = 10, reward = 5000 },
	{ text = "Get a Legend dragon", kind = "rarity", target = 4, reward = 10000 },
	{ text = "Earn 1,000,000 coins", kind = "earned", target = 1000000, reward = 50000 },
}
