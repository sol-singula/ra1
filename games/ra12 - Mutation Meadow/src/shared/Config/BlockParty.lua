-- The block-party sunflower: the server waters it together to make it bloom
return {
	windowSec = 600,
	goalPerPlayer = 10,
	goalMin = 20,
	waterEverySec = 2,
	rangeStuds = 15,
	stages = { perking = 0.33, standing = 0.66, bloom = 1.0 },
	wiltSec = 60,
	reward = { minWaters = 5, coinsPerLevelSq = 100 },
	-- private servers: goal = max(goalMin, goalPerPlayer x players) so 2 or 3 friends can bloom it
	privateServer = { goalMin = 2, goalPerPlayer = 1, minWaters = 1 },
	sunflowerFriendAt = 10,
}
