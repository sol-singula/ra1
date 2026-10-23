-- Crop mutations: each applies at most once per crop; wet and golden together sell for stackMult
return {
	wet = { mult = 2, chance = { rain = 0.25, welcomeShower = 0.25 } },
	golden = { mult = 20, chance = { goldenHour = 0.08 } },
	stackMult = 40,
}
