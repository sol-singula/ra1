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
Constants.START_CASH = 0
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

return Constants
