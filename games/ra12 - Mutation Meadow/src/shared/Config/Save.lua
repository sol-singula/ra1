-- Profile and gift DataStores, session locking and write pacing
return {
	profileStore = "MM_Profiles_v1",
	giftStore = "MM_Gifts_v1",
	keyPrefix = "u_",
	schemaVersion = 1,
	autosaveSec = 90,
	lockStaleSec = 300,
	loadRetrySec = { 1, 2, 4, 8, 16 },
	receiptsKeep = 50,
	writeBackoffSec = { 1, 3, 7 },
	writeCooldownSec = 6,
	closeBudgetSec = 25,
	giftsInKeep = 100,
	giftQueueMax = 100,
}
