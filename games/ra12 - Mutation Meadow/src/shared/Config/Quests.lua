-- Starter quests (once each) and daily quests (reward coins scale with level squared)
return {
	starter = {
		{ key = "harvest5", n = 5, reward = { coins = 50 } },
		{ key = "plot2", n = 2, reward = { coins = 100 } },
		{ key = "keepMut", n = 1, reward = { seeds = { tomato = 2 } } },
		{ key = "pedestal", n = 1, reward = { coins = 300 } },
		{ key = "help1", n = 1, reward = { coins = 75 } },
	},
	daily = {
		{ key = "harvest30", n = 30 },
		{ key = "help3", n = 3 },
		{ key = "sunflower5", n = 5 },
	},
	dailyCoinsPerLevelSq = 300,
}
