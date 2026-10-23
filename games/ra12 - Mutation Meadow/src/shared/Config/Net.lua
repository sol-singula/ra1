-- Remote rate limits, payload limits and server-side range checks
return {
	bucket = { burst = 20, perSec = 10 },
	plotBucket = { burst = 20, perSec = 20 },
	abuseDrops = 300,
	abuseWindowSec = 60,
	maxKeys = 16,
	maxDepth = 3,
	maxBytes = 1024,
	giftOfferSec = 30,
	tileRangeStuds = 24,
	standRangeStuds = 16,
	gardenNameMax = 20,
	sunflowerRangeStuds = 15,
	patchRangeStuds = 12,
}
