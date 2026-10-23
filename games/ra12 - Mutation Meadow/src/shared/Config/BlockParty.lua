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
	sunflowerFriendAt = 10,
}
