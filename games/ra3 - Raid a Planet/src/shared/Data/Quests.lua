-- The daily quest pool. Three are picked each day (seeded by the day, so every server agrees). kind is a stat
-- counted from the start of the day; gems is the pay.
return {
	{ text = "Blast 100 bugs", kind = "bugs", target = 100, gems = 3 },
	{ text = "Blast 300 bugs", kind = "bugs", target = 300, gems = 5 },
	{ text = "Forge 3 blasters", kind = "forged", target = 3, gems = 3 },
	{ text = "Forge 8 blasters", kind = "forged", target = 8, gems = 6 },
	{ text = "Beat 2 planet bosses", kind = "bosses", target = 2, gems = 4 },
	{ text = "Beat 5 planet bosses", kind = "bosses", target = 5, gems = 8 },
	{ text = "Join a raid", kind = "raids", target = 1, gems = 5 },
	{ text = "Join 2 raids", kind = "raids", target = 2, gems = 8 },
	{ text = "Power Up 10 times", kind = "powerUps", target = 10, gems = 3 },
	{ text = "Sell 5 blasters", kind = "sold", target = 5, gems = 3 },
	{ text = "Play with a friend", kind = "friendPlay", target = 1, gems = 5 },
}
