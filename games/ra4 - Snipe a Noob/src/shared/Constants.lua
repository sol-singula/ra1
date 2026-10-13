-- Every number in the game. Change the game here, not in the code.
local Constants = {}

Constants.AUTOSAVE_SECONDS = 120
Constants.START_COINS = 0
Constants.MAX_PLAYERS = 24
Constants.WALK_SPEED = 18
Constants.JUMP_POWER = 50

-- The round loop ------------------------------------------------------------------------------------------
Constants.MIN_PLAYERS = 2 -- a round starts as soon as this many players are in the server
Constants.LOBBY_SECONDS = 15 -- the countdown in the lobby (map vote) before a round
Constants.ROUND_SECONDS = 300 -- 5 minutes
Constants.PODIUM_SECONDS = 8 -- the top 3 on the podium after a round
Constants.LAST_MINUTE = 60 -- the last minute: faster music, 2x coins
Constants.LAST_MINUTE_MULT = 2
-- which map size fits the crowd (players in the server, robots not counted)
Constants.MAP_SIZES = {
	{ key = "small", maxPlayers = 8, half = 46 },
	{ key = "medium", maxPlayers = 16, half = 64 },
	{ key = "large", maxPlayers = 99, half = 82 },
}

-- Popping and respawning ----------------------------------------------------------------------------------
Constants.RESPAWN_SECONDS = 5
Constants.SHIELD_SECONDS = 2 -- spawn shield (breaks early when you fire)
Constants.FALL_Y = -40 -- below the map floor by this much: back to a spawn, no pop given

-- The shot ------------------------------------------------------------------------------------------------
Constants.MAX_RANGE = 700 -- studs
Constants.LAG_COMP_MAX = 0.3 -- the server rewinds targets at most this many seconds to where the shooter saw them
Constants.HISTORY_SECONDS = 1 -- how much position history the server keeps per target
Constants.ORIGIN_TOLERANCE = 9 -- the shot must start this close to the shooter's head (server's view)
Constants.FIRE_RATE_SLACK = 0.12 -- seconds of slack on the bolt time (network jitter)
-- hit shapes, relative to the HumanoidRootPart: a head ball and a body capsule
Constants.HEAD_OFFSET = 1.6
Constants.HEAD_RADIUS = 0.85
Constants.BODY_TOP = 0.9
Constants.BODY_BOTTOM = -2.6
Constants.BODY_RADIUS = 1.05
Constants.HIP_FOV = 70
Constants.HIP_SPREAD = 3.5 -- degrees of random spread when not scoped
Constants.SCOPE_SETTLE = 0.3 -- seconds after scoping in before the shot is dead steady
Constants.SCOPE_SPREAD = 0.9 -- degrees of spread while the scope is still settling
-- light aim help on phones and gamepads, only while scoped: a shot this close to a target bends onto it
Constants.AIM_ASSIST_DEGREES = 1.6

-- Coins and XP --------------------------------------------------------------------------------------------
Constants.COINS = {
	pop = 10,
	headshot = 20, -- instead of pop
	streak = 5, -- extra per pop while on a streak of 3+
	revenge = 15,
	crown = 50, -- popping the round leader
	doubleTap = 10, -- you and a friend both popped someone within 3 s
	robot = 4, -- popping a robot
	podium = { 100, 60, 30 },
	round = 20, -- for finishing a round
}
Constants.XP = { pop = 25, headshot = 40, robot = 8, round = 60, win = 150, podium = 80 }
Constants.NEW_PLAYER_BOOST_SECONDS = 600
Constants.NEW_PLAYER_BOOST_MULT = 2
Constants.VIP_COIN_MULT = 1.2
Constants.SQUAD_COINS_PER_FRIEND = 0.1
Constants.SQUAD_COINS_MAX = 0.3

-- Levels: XP needed for the next level grows a little each level
Constants.LEVEL_BASE_XP = 300
Constants.LEVEL_STEP_XP = 60
Constants.MAX_LEVEL = 100
Constants.LEVEL_COINS = 100 -- coins for each new level (x level / 10, at least 100)

-- Round fun -----------------------------------------------------------------------------------------------
Constants.STREAKS = {
	{ at = 3, key = "fire", text = "🔥 ON FIRE", color = { 255, 140, 30 } },
	{ at = 5, key = "unstoppable", text = "⚡ UNSTOPPABLE", color = { 255, 215, 60 } },
	{ at = 10, key = "legend", text = "👑 LEGEND", color = { 255, 95, 170 } },
}
Constants.CROWN_REVEAL_EVERY = 15 -- the round leader's crown shows through walls for 2 s every 15 s
Constants.CROWN_REVEAL_SECONDS = 2
Constants.DOUBLE_TAP_WINDOW = 3

-- Robots --------------------------------------------------------------------------------------------------
Constants.ROBOTS_FILL_TO = 4 -- a round with fewer fighters than this gets robots (tagged ROBOT)
Constants.ROBOT_FIRST_ROUND = 4 -- a brand-new player's first round always has this many fighters
Constants.ROBOT_REACTION = 1.6 -- seconds from seeing you to firing
Constants.ROBOT_ACCURACY = 0.35 -- chance a robot's shot hits
Constants.ROBOT_SPEED = 12

-- Duels -----------------------------------------------------------------------------------------------------
Constants.DUEL_TO = 5 -- first to 5 pops
Constants.DUEL_COINS = 60

-- Coins to spend --------------------------------------------------------------------------------------------
Constants.COIN_CRATE_PRICE = 2000
Constants.DAILY_SHOP_SIZE = 10 -- 6 skins, 2 pop effects, 2 emotes
Constants.MASTERY = { 100, 500, 2000 } -- pops with a rifle for its gold, diamond and rainbow looks

-- Daily quests, gifts -------------------------------------------------------------------------------------
Constants.DAILY_QUESTS = 3
Constants.QUEST_REROLL_COINS = 300
Constants.DAILY_GIFTS = { -- the daily gift streak (day 7 repeats)
	{ coins = 200 },
	{ coins = 300 },
	{ keys = 1 },
	{ coins = 600 },
	{ coins = 800 },
	{ keys = 2 },
	{ coins = 1500, keys = 2 },
}
Constants.PLAYTIME_GIFTS = { -- minutes played today -> gift
	{ minutes = 1, coins = 100 },
	{ minutes = 3, coins = 150 },
	{ minutes = 5, coins = 200 },
	{ minutes = 10, keys = 1 },
	{ minutes = 15, coins = 400 },
	{ minutes = 20, coins = 500 },
	{ minutes = 30, keys = 1 },
	{ minutes = 45, coins = 1000 },
	{ minutes = 60, keys = 2 },
}

-- Season (2 weeks) ----------------------------------------------------------------------------------------
Constants.SEASON_DAYS = 14
Constants.SEASON_START = 1760313600 -- 2025-10-13 00:00 UTC: season 1 counts from here, every 14 days
Constants.SEASON_TIERS = 50
Constants.SEASON_TIER_XP = 600

-- Trading -----------------------------------------------------------------------------------------------------
Constants.TRADE_TAX = 0.10
Constants.STALL_PRICES = { 500, 1000, 2500, 5000, 10000, 25000, 50000, 100000 }

-- Sound -----------------------------------------------------------------------------------------------------
Constants.SOUNDS = { -- from the Roblox audio library (public, verified creators)
	shot = "rbxassetid://109306405910383",
	bolt = "rbxassetid://136556611710738",
	hit = "rbxassetid://138148057831879",
	headshot = "rbxassetid://137096881472307",
	pop = "rbxassetid://109359226723492",
	popped = "rbxassetid://115604569854725",
	coin = "rbxassetid://118634876996683",
	buy = "rbxassetid://105104330819150",
	levelup = "rbxassetid://106516156393061",
	notify = "rbxassetid://115604569854725",
	countdown = "rbxassetid://115604569854725",
	start = "rbxassetid://109983444504089",
	win = "rbxassetid://119933432712786",
	streak = "rbxassetid://88832672717864",
	crate = "rbxassetid://96391581866585",
	gift = "rbxassetid://105104330819150",
	scope = "rbxassetid://122464093213516",
}
Constants.SOUND_VOLUME = { shot = 0.5, bolt = 0.35, hit = 0.6, pop = 0.5, coin = 0.4, notify = 0.45, streak = 0.6 }
Constants.MUSIC = { -- the lobby
	"rbxassetid://1837768013",
	"rbxassetid://1844643755",
}
Constants.ROUND_MUSIC = {
	"rbxassetid://135990877378159",
	"rbxassetid://1837768013",
}
Constants.MUSIC_VOLUME = 0.25
Constants.ROUND_MUSIC_VOLUME = 0.3

Constants.CAMERA_MAX_ZOOM = 28 -- in the lobby (rounds are first person)

-- Leaderboards (the lobby) --------------------------------------------------------------------------------------
Constants.LEADERBOARD_SIZE = 10
Constants.LEADERBOARD_LIVE_SECONDS = 2
Constants.LEADERBOARD_READ_SECONDS = 60
Constants.LEADERBOARD_WRITE_SECONDS = 120
Constants.DAILY_RESET_HOUR_ET = 19 -- TODAY'S TOP SNIPERS (and the Daily Shop) reset at 7pm US Eastern

-- The game log (Discord, through the roblox-game-log function; the key is the 'discord_log' secret)
Constants.GAME_LOG_URL = "https://kvedatksqkcsgivntskb.supabase.co/functions/v1/roblox-game-log"
Constants.GAME_LOG_IN_STUDIO = false
Constants.GAME_LOG_FLUSH_SECONDS = 5

return Constants
