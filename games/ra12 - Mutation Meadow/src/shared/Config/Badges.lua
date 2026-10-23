-- TODO: create badges on Mason's account. desc is the badge description players see.
return {
	welcome = { name = "Welcome to the Meadow", id = 0 },
	first_harvest = { name = "First Harvest", id = 0 },
	first_splash = { name = "First Splash", id = 0 },
	first_golden = { name = "Struck Gold!", desc = "Keep your first Golden crop, worth 20x.", id = 0 },
	first_wetgolden = { name = "40x Legend", desc = "Keep a Wet + Golden crop, worth 40x.", id = 0 },
	master_gardener = { name = "Master Gardener", id = 0 },
	week_of_sprouts = { name = "7-Day Gardener", desc = "Claim 7 days on the daily calendar.", id = 0 },
	full_meadow = { name = "Full Meadow", id = 0 }, -- TODO: desc once the trigger is decided (not in the spec yet)
	moonstruck = { name = "Moonstruck", id = 0 },
	-- TODO: confirm the trigger. Config.BlockParty.sunflowerFriendAt = 10 suggests 10 blooms, not one
	sunflower_friend = { name = "Sunflower Friend", desc = "Help the Block Party sunflower bloom.", id = 0 },
}
