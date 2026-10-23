-- Server weather, and the one-time welcome shower over a new player's own plot
return {
	durationSec = 300,
	pick = { rain = 0.8, goldenHour = 0.2 },
	rainGrowthMult = 1.5,
	welcomeShower = {
		atSessionSec = 240,
		deferIfWeatherSec = 10,
		durationSec = 60,
		ownPlotOnly = true,
		guaranteeWet = 1,
		guaranteeWetAtSec = 10,
		calendarAfterShowerSec = 150,
	},
}
