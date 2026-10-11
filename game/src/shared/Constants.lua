-- Global tunables. Values come from the GDD canon (gdd/canon.md, section in brackets) unless marked MVP.
local Constants = {}

Constants.MAX_PLAYERS = 8 -- [C3] one plot per player on Restaurant Row
Constants.CARRY_BASE = 1 -- [C3]
Constants.CARRY_MAX = 3 -- [C3]
Constants.STATION_RANGE = 7 -- [C3] studs; server allows +2 tolerance
Constants.CUSTOMER_RANGE = 10 -- [C3]
Constants.AUTOSAVE_SECONDS = 120 -- [C3]
Constants.START_STARS = 2.5 -- [C3]
Constants.LEVEL_CAP_MVP = 10 -- [34.4] MVP soft cap

-- Heat timing model [C8]
Constants.PERFECT_WINDOW = 2.0
Constants.BURN_AFTER_READY = 6.0
Constants.FIRE_AFTER_BURN = 4.0
Constants.EXTINGUISH_HOLD = 1.5 -- MVP: hold the station prompt to put the fire out

-- Chopping [C8]
Constants.CHOP_TAPS = 4
Constants.CHOP_RING_PERIOD = 0.9 -- seconds per ring sweep, divided by the Cooking Speed multiplier
Constants.CHOP_MIN_TAP_GAP = 0.12

-- Drink pouring (MVP stand-in for the §5 pour minigame)
Constants.POUR_SECONDS = 3.0 -- time to reach 100 %
Constants.POUR_MAX_FILL = 1.15

-- Quality grades [C8]
Constants.GRADE = {
	PERFECT = 1.0,
	GOOD = 0.8,
	OK = 0.6,
	UNDERCOOKED = 0.35,
	BURNED = 0.15,
	RUINED = 0.0,
}

-- Customers [C11]
Constants.ORDER_WAIT_SECONDS = 30 -- [C11.2] × personality patience
Constants.EAT_SECONDS = 6 -- MVP
Constants.ANGER_RISE_PER_SECOND = 4 -- MVP: anger gained per second once patience has run out
Constants.ANGER_WRONG_DISH = 15 -- MVP
Constants.ANGER_HIT_BY_FOOD = 25 -- [C11.5] × sensitivity
Constants.ANGER_LEVEL_FLOORS = { 0, 15, 30, 45, 60, 75, 90 } -- [C11.5] levels 0-6
Constants.STORM_OUT_STARS = 0.03 -- [C11.4]
Constants.RAGE_QUIT_SECONDS = 30 -- MVP: an ignored customer at anger 100 storms out after this long
Constants.WALK_SPEED_NPC = 9 -- MVP studs/s
Constants.CHASE_SPEED_NPC = 12
Constants.NPC_TICK = 1 / 15 -- server proxy update rate (clients interpolate)
Constants.FIRST_CUSTOMER_DELAY = 6 -- MVP
Constants.BEGINNER_PROTECTION_LEVEL = 2 -- MVP: below this level customers never throw food or fight
Constants.DEMAND_SCALE = 1 -- MVP multiplier on canon demand; raise it to test with more customers

-- Combat [C12.1] and the base-kit rows in §36.6
Constants.KO_SECONDS = 4
Constants.KO_RESPAWN_HP = 0.6
Constants.WOOZY_SECONDS = 10
Constants.WOOZY_MOVE = 0.85
Constants.IN_COMBAT_SECONDS = 6
Constants.ABILITIES = {
	ABL_001 = {
		name = "Swipe Combo",
		cooldown = 0.35,
		damage = { 8, 8, 12 },
		range = 4.5,
		arc = 100,
		targets = 3,
		chainReset = 0.8,
	},
	ABL_006 = { name = "Calm Down!", cooldown = 12, range = 10, immune = 20 },
	ABL_012 = { name = "Octo-Flurry", cooldown = 11, damage = 30, range = 5, arc = 180, targets = 3 },
	ABL_017 = { name = "Claw Grab & Toss", cooldown = 11, damage = 24, range = 3.5, arc = 90, targets = 1 },
	ABL_062 = { name = "Repair Burst", cooldown = 30, range = 8, targets = 4 },
}
Constants.THROWN_FOOD_DAMAGE = 6 -- §11.6.1 light prop, low end
Constants.THROWN_FOOD_FLIGHT = 0.9
Constants.THROWN_FOOD_HIT_RADIUS = 3.5
Constants.NPC_MELEE_DAMAGE = 8
Constants.NPC_MELEE_INTERVAL = 1.5
Constants.NPC_THROW_INTERVAL = 3.0
Constants.DIZZY_SECONDS = 3
Constants.APOLOGY_PAYMENT = 0.4 -- [C11.4]

-- Furniture damage states [C6]
Constants.DAMAGE_STATES = {
	{ name = "Pristine", min = 76 },
	{ name = "Scuffed", min = 51 },
	{ name = "Cracked", min = 26 },
	{ name = "Broken", min = 1 },
	{ name = "Destroyed", min = 0 },
}
Constants.SMASH_DAMAGE = 25 -- MVP durability lost per angry smash
Constants.REPAIR_SECONDS_PER_25 = 2.0 -- MVP hold time to restore 25 durability at REPAIR 0
Constants.REPAIR_COST_PER_POINT = 0.2 -- MVP MB per durability point

-- Atmosphere stand-in until decor (§15) exists: greybox furniture score per tier
Constants.BASE_ATMOSPHERE = { TIER_01 = 30, TIER_02 = 36 }

return Constants
