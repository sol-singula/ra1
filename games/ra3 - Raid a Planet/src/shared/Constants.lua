-- Every number in the game. Change the game here, not in the code.
local Constants = {}

Constants.AUTOSAVE_SECONDS = 120
Constants.START_COINS = 0
Constants.START_GEMS = 0
Constants.MAX_PLAYERS = 30

-- Blasting -------------------------------------------------------------------------------------------------
Constants.BLAST_RANGE = 42 -- studs; the hub forge, pads and the boss gate are all closer than this
Constants.BLAST_COOLDOWN = 0.3 -- seconds between shots (a shiny Speed roll shortens it)
Constants.BLAST_CONE = 0.35 -- how far off straight-ahead a target may be (dot product); 0 = 90 degrees
Constants.WALK_SPEED = 18

-- Bugs: how many walk around a planet while someone is on it, and how fast they come at you
Constants.BUGS_PER_PLANET = 6
Constants.BUG_RESPAWN_SECONDS = 3
Constants.BUG_SPEED = 7
Constants.BUG_STOP_DISTANCE = 6 -- they stop this close and buzz at you (no damage: a kids' game)
-- bug and boss health scale with the people near: 1 player = 1x, each extra player +60%
Constants.SCALE_PER_PLAYER = 0.6
Constants.NEAR_RADIUS = 60

-- Bosses ---------------------------------------------------------------------------------------------------
Constants.BOSS_HEALTH_MULT = 45 -- a boss has this many bugs' worth of health
Constants.BOSS_RESET_SECONDS = 25 -- nobody near for this long: the boss heals up and waits again
Constants.BOSS_SPEED = 4
Constants.BOSS_RAGE_AT = 0.5 -- below half health it fires slow glowing balls
Constants.BOSS_BALL_EVERY = 2.5
Constants.BOSS_BALL_SPEED = 14
Constants.BOSS_DOWN_SECONDS = 4 -- hit by a ball: you're down this long (no death, no respawn walk)
Constants.BOSS_LOOT_ORE_MULT = 12 -- a boss drops this many bugs' worth of ore
Constants.BOSS_GEMS = 1

-- The Forge ------------------------------------------------------------------------------------------------
-- Three sizes of forge. Bigger forges eat more ore, take longer, and roll better blasters.
Constants.FORGE_TIERS = {
	{ key = "small", name = "Small Forge", ore = 10, seconds = 15, emoji = "🔥" },
	{ key = "big", name = "Big Forge", ore = 50, seconds = 180, emoji = "🔥🔥" },
	{ key = "mega", name = "Mega Forge", ore = 250, seconds = 1800, emoji = "🔥🔥🔥" },
}
-- which blaster rarity each forge rolls, in percent (shown on the Odds page; must add to 100)
Constants.FORGE_ODDS = {
	small = { { "Common", 70 }, { "Rare", 25 }, { "Epic", 4.5 }, { "Legend", 0.5 } },
	big = { { "Common", 30 }, { "Rare", 45 }, { "Epic", 20 }, { "Legend", 4.5 }, { "Secret", 0.5 } },
	mega = { { "Rare", 30 }, { "Epic", 45 }, { "Legend", 20 }, { "Secret", 5 } },
}
-- each stat on a new blaster rolls a grade (percent, adds to 100)
Constants.ROLL_ODDS = { { "plain", 89.9 }, { "shiny", 10 }, { "god", 0.1 } }
Constants.ROLL_MULT = { plain = 1, shiny = 1.5, god = 3 }
Constants.ROLL_STATS = { "dmg", "spd", "luck", "gem" } -- Damage, Speed, Luck, Gem Find
Constants.FORGE_SLOTS = 1
Constants.FORGE_SLOTS_TRIPLE = 3 -- with the Triple Forge pass
-- Finish Forge Now: the price falls as the timer runs down (Robux, through a developer product per step)
Constants.FINISH_NOW_MAX = 149
Constants.FINISH_NOW_MIN = 9

-- Blasters -------------------------------------------------------------------------------------------------
Constants.MAX_BLASTERS = 30 -- inventory size (more with a pass later)
Constants.POWER_UP_LEVELS = 50 -- coins level a blaster up: +4% damage each
Constants.POWER_UP_PERCENT = 0.04

-- Playtime and the first minutes ---------------------------------------------------------------------------
Constants.NEW_PLAYER_BOOST_SECONDS = 10 * 60
Constants.NEW_PLAYER_BOOST_MULT = 2
Constants.PLAYTIME_GIFTS = {
	{ at = 60, kind = "coins", amount = 100 },
	{ at = 180, kind = "ore", amount = 15 },
	{ at = 300, kind = "blaster", tier = "big" },
	{ at = 600, kind = "coins", amount = 500 },
	{ at = 900, kind = "gems", amount = 3 },
	{ at = 1200, kind = "ore", amount = 60 },
	{ at = 1800, kind = "blaster", tier = "mega" },
	{ at = 2700, kind = "gems", amount = 5 },
	{ at = 3600, kind = "blaster", tier = "mega" },
}

-- Raids (step 3; the countdown already runs so the hub never feels still) --------------------------------------
Constants.RAID_EVERY = 15 * 60

-- Rebirth: after all 8 bosses, start over with a star: +25% damage for ever, and Nightmare planets (10x)
Constants.REBIRTH_DAMAGE = 0.25
Constants.NIGHTMARE_MULT = 10

-- Squads: friends in the server give each other damage
Constants.SQUAD_DAMAGE_PER_FRIEND = 0.1
Constants.SQUAD_DAMAGE_MAX = 0.3
Constants.SQUAD_ORE_MULT = 2 -- a friend on your planet: bosses drop double ore for both of you

-- Sound ----------------------------------------------------------------------------------------------------
Constants.SOUNDS = {
	blast = "rbxassetid://95486565209148",
	pop = "rbxassetid://105444665436909",
	hit = "rbxassetid://105444665436909",
	coin = "rbxassetid://118634876996683",
	buy = "rbxassetid://105104330819150",
	levelup = "rbxassetid://106516156393061",
	goal = "rbxassetid://106516156393061",
	notify = "rbxassetid://115604569854725",
	ready = "rbxassetid://115604569854725",
	equip = "rbxassetid://83557110540525",
	forge = "rbxassetid://96391581866585",
	win = "rbxassetid://119933432712786",
	gift = "rbxassetid://105104330819150",
	boss = "rbxassetid://88832672717864",
	portal = "rbxassetid://109983444504089",
	hatch = "rbxassetid://119933432712786",
}
Constants.SOUND_VOLUME = { blast = 0.25, pop = 0.4, hit = 0.5, coin = 0.5, notify = 0.45, boss = 0.6 }
Constants.MUSIC = { -- space adventure, played in turn
	"rbxassetid://74189412399190", -- Space Adventure
	"rbxassetid://137158553055103", -- Out Of Orbit
	"rbxassetid://73341720345819", -- Satellite Flyby
	"rbxassetid://1844643755", -- Space Adventures
}
Constants.RAID_MUSIC = {
	"rbxassetid://135990877378159", -- Space Boss Fight
	"rbxassetid://1837768013", -- Rise to the Top
}
Constants.MUSIC_VOLUME = 0.28
Constants.RAID_MUSIC_VOLUME = 0.45

Constants.CAMERA_MAX_ZOOM = 60

return Constants
