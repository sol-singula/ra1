-- Farm Empire (ra11): every tunable number in one place (other/ra11/MASTER_PLAN.md).
local Constants = {}

Constants.GAME = "ra11"
Constants.GAME_NAME = "Farm Empire"

-- Server: twelve territories round a shared town (master plan §4)
Constants.MAX_PLAYERS = 12
Constants.TERRITORIES = 12

-- Saves
Constants.PROFILE_STORE = "FE_Profiles_v1"
Constants.AUTOSAVE_SECONDS = 120

-- Admins
Constants.ADMINS = { [11787294097] = true } -- xthirtysix
Constants.ADMIN_NAMES = { xthirtysix = true }

-- Money (§7): one currency, Cash. The first sale pays within the first minute.
Constants.START_CASH = 0

-- Coming back (§13): crops grow and the store sells while you're away, up to a cap
Constants.OFFLINE_HOURS = 4 -- the most time away that counts (8 with the Night Shift pass)
Constants.OFFLINE_PASS_HOURS = 8
Constants.OFFLINE_RATE = 0.5 -- the share of the live income rate earned while away
Constants.OFFLINE_MIN_SECONDS = 120 -- shorter than this away and there's no welcome-back card

-- The town's shared boosts (§11): coins fill the meter, Robux lights it at once
Constants.BOOST_SECONDS = 600
Constants.BOOST_METER_COST = 2500 -- Cash the whole server contributes to light the meter once

-- Leaderboards in the town
Constants.LEADERBOARD_STORE = "FE_Top_%s_v1"
Constants.LEADERBOARD_REFRESH_SECONDS = 120
Constants.LEADERBOARD_WRITE_SECONDS = 60

-- Analytics and the game log: the studio's shared pipeline (src/server/GameKey: the "discord_log" secret)
Constants.ANALYTICS_URL = "https://kvedatksqkcsgivntskb.supabase.co/functions/v1/roblox-analytics"
Constants.GAME_LOG_URL = "https://kvedatksqkcsgivntskb.supabase.co/functions/v1/roblox-game-log"
Constants.GAME_LOG_IN_STUDIO = false
Constants.ANALYTICS_GAME = "ra11"
Constants.ANALYTICS_FLUSH_SECONDS = 10
Constants.ANALYTICS_SNAPSHOT_SECONDS = 30

-- The palette (§9): rich greens, warm wood and cream, bright accents on machinery and upgrade cues
local rgb = Color3.fromRGB
Constants.PALETTE = {
	grass = rgb(96, 186, 78),
	grassLight = rgb(140, 214, 96),
	grassDark = rgb(66, 150, 70),
	soil = rgb(124, 84, 54),
	soilDark = rgb(92, 60, 40),
	path = rgb(206, 178, 134),
	road = rgb(84, 86, 94),
	roadLine = rgb(238, 220, 120),
	wood = rgb(186, 130, 76),
	woodDark = rgb(122, 80, 46),
	cream = rgb(250, 240, 214),
	white = rgb(250, 250, 246),
	barnRed = rgb(206, 58, 50),
	roofGreen = rgb(60, 132, 86),
	roofBlue = rgb(64, 110, 190),
	awning = rgb(232, 72, 64),
	awningStripe = rgb(250, 246, 236),
	steel = rgb(160, 166, 176),
	steelDark = rgb(96, 100, 110),
	concrete = rgb(204, 204, 198),
	safetyYellow = rgb(255, 200, 36),
	machineRed = rgb(222, 56, 48),
	machineGreen = rgb(56, 150, 70),
	truckWhite = rgb(242, 244, 246),
	glass = rgb(150, 206, 236),
	accent = rgb(255, 170, 40), -- upgrade cues, previews, the recommended upgrade
	preview = rgb(120, 200, 255), -- the ghost of the next building
	leaf = rgb(70, 170, 80),
	water = rgb(70, 170, 240),
}

-- Robux (§11, Data/Shop): ids are 0 until the products and passes are made on Roblox (an id of 0 is given for
-- free in Studio, so the shop can be tried; on a live server it shows "coming soon")
Constants.PRODUCTS = {
	harvestRush = 0,
	customerRush = 0,
	goldenMarket = 0,
	cashSmall = 0,
	cashBig = 0,
}
Constants.PASSES = {
	nightShift = 0, -- 8 hours of offline progress
	fastMachines = 0, -- machines cycle 25% faster
	tractorPaint = 0, -- machine colours
	premiumBundle = 0, -- every cosmetic
}

return Constants
