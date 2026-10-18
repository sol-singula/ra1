-- Farm to Fleet (ra10): every tunable number in one place (other/ra10/MASTER_PLAN.md).
local Constants = {}

Constants.GAME = "ra10"
Constants.GAME_NAME = "Farm to Fleet"

-- Server (§10): six plots, two rows of three either side of the shared main road
Constants.MAX_PLAYERS = 6
Constants.PLOTS = 6

-- Saves
Constants.PROFILE_STORE = "FF_Profiles_v1"
Constants.AUTOSAVE_SECONDS = 120

-- Admins
Constants.ADMINS = { [11787294097] = true } -- xthirtysix
Constants.ADMIN_NAMES = { xthirtysix = true }

-- Money (§3): Cash for the farm, Gems for skips and golden seeds
Constants.START_CASH = 15
Constants.START_GEMS = 10

-- The palette (§1): ra9's matte, detailed look, in colour families so six plots read as one world
local rgb = Color3.fromRGB
Constants.PALETTE = {
	-- farm
	barnRed = rgb(186, 52, 44),
	cream = rgb(244, 236, 214),
	fenceWhite = rgb(240, 240, 236),
	grass = rgb(104, 176, 82),
	grassLight = rgb(140, 200, 104),
	grassDark = rgb(70, 138, 62),
	soil = rgb(122, 84, 56), -- (soil and crates only)
	soilWet = rgb(88, 60, 42),
	water = rgb(80, 164, 230),
	sunflower = rgb(255, 204, 40),
	wood = rgb(176, 128, 82), -- (crates and pallets only)
	-- industrial
	concrete = rgb(206, 206, 202),
	concreteDark = rgb(170, 170, 168),
	asphalt = rgb(62, 64, 70),
	steel = rgb(150, 156, 166),
	steelLight = rgb(196, 200, 208),
	safetyYellow = rgb(255, 200, 30),
	safetyBlack = rgb(30, 30, 34),
	rackOrange = rgb(240, 110, 30),
	rackBlue = rgb(40, 90, 180),
	dockGreen = rgb(60, 210, 90),
	dockRed = rgb(230, 50, 50),
	trailerWhite = rgb(238, 240, 244),
	glass = rgb(150, 200, 230),
}
-- each plot's accent (its trailers, banners, roof trim)
Constants.PLOT_COLORS = {
	rgb(235, 64, 52),
	rgb(40, 120, 240),
	rgb(46, 176, 90),
	rgb(156, 90, 240),
	rgb(255, 150, 30),
	rgb(30, 196, 190),
}

-- Analytics and the game log: the studio's shared pipeline (src/server/GameKey: the "discord_log" secret)
Constants.ANALYTICS_URL = "https://kvedatksqkcsgivntskb.supabase.co/functions/v1/roblox-analytics"
Constants.GAME_LOG_URL = "https://kvedatksqkcsgivntskb.supabase.co/functions/v1/roblox-game-log"
Constants.GAME_LOG_IN_STUDIO = false
Constants.ANALYTICS_GAME = "ra10" -- (the game tag on every analytics row: the live dashboard's ?game=ra10)
Constants.ANALYTICS_FLUSH_SECONDS = 10
Constants.ANALYTICS_SNAPSHOT_SECONDS = 30

-- Coming back (§8)
Constants.OFFLINE_HOURS = 4 -- the most time away that earns (12 with the Long Nap pass or perks)
Constants.OFFLINE_PASS_HOURS = 12
Constants.OFFLINE_RATE = 0.5 -- the share of what the operation ships a minute that it earns while you're away
Constants.OFFLINE_MIN_SECONDS = 120 -- shorter than this away and there's no card

-- Watching each other (§13.4) and the all-time boards
Constants.LEADERBOARD_STORE = "FF_Top_%s_v1" -- one OrderedDataStore a board
Constants.LEADERBOARD_REFRESH_SECONDS = 120
Constants.LEADERBOARD_WRITE_SECONDS = 60
Constants.SUMMARY_STORE = "FF_Summary_v1" -- each farm's summary, for friends on other servers
Constants.STREET_WINDOW = 300 -- the seconds the street board's "a minute" numbers average over

-- Robux (§11, Data/Shop): ids are 0 until the products and passes are made on Roblox (an id of 0 is given for free in
-- Studio, so the shop can be tried; on a live server it shows "coming soon")
Constants.PRODUCTS = {
	gems100 = 0,
	gems550 = 0,
	gems1200 = 0,
	starter = 0,
	skipGrow = 0,
}
Constants.PASSES = {
	doubleCash = 0,
	longNap = 0,
	extraOrder = 0,
	vip = 0,
}

return Constants
