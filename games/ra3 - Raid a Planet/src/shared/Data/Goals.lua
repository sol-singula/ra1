-- Goals shown at the top of the screen, one at a time. kind names a number the server tracks (GoalService).
-- reward is coins; gems pays gems instead.
return {
	{ text = "Blast 5 bugs", kind = "bugs", target = 5, reward = 50 },
	{ text = "Forge a blaster: go to the FORGE", kind = "forged", target = 1, reward = 100 },
	{ text = "Beat the Dust King: go through the BOSS GATE", kind = "bosses", target = 1, reward = 300 },
	{ text = "Blast 50 bugs", kind = "bugs", target = 50, reward = 250 },
	{ text = "Get a Rare blaster", kind = "rarity", target = 2, reward = 300 },
	{ text = "Forge 5 blasters", kind = "forged", target = 5, reward = 400 },
	{ text = "Power Up a blaster 5 times", kind = "powerUps", target = 5, reward = 400 },
	{ text = "Beat the Frost Queen on Ice", kind = "bosses", target = 2, reward = 1000 },
	{ text = "Get an Epic blaster", kind = "rarity", target = 3, reward = 1500 },
	{ text = "Blast 500 bugs", kind = "bugs", target = 500, reward = 2000 },
	{ text = "Join a raid", kind = "raids", target = 1, gems = 5 },
	{ text = "Beat 3 planet bosses", kind = "bosses", target = 3, reward = 5000 },
	{ text = "Play with a friend", kind = "friendPlay", target = 1, gems = 5 },
	{ text = "Get a Legend blaster", kind = "rarity", target = 4, gems = 10 },
	{ text = "Beat 5 planet bosses", kind = "bosses", target = 5, reward = 50000 },
	{ text = "Blast 5,000 bugs", kind = "bugs", target = 5000, gems = 10 },
	{ text = "Get a Secret blaster", kind = "rarity", target = 5, gems = 25 },
	{ text = "Beat all 8 planet bosses", kind = "bosses", target = 8, gems = 50 },
}
