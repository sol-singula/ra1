-- Every tunable number in one place.
local Constants = {}

-- Look: plastic bricks with studs on top, like most popular Roblox games (false = smooth stone, wood and grass)
Constants.BRICK_STYLE = true

-- Players and bases
Constants.MAX_BASES = 8 -- set Max Players to 8 in Game Settings
Constants.START_NESTS = 4
Constants.MAX_NESTS = 24 -- includes the 4 from the Extra Nests pass
Constants.BUYABLE_NESTS = 20 -- nests 5..20 can be bought with coins
Constants.NEST_PRICES = {
	[5] = 100,
	[6] = 250,
	[7] = 600,
	[8] = 1500,
	[9] = 4000,
	[10] = 10000,
	[11] = 25000,
	[12] = 60000,
	[13] = 150000,
	[14] = 350000,
	[15] = 800000,
	[16] = 2000000,
	[17] = 5000000,
	[18] = 12000000,
	[19] = 30000000,
	[20] = 75000000,
}

-- Castle: a base grows with its owner's dragon power (the coins per second of the dragons in its nests,
-- before passes and friend bonuses). Level 1 is a low wall; each level needs this much power.
Constants.CASTLE_LEVEL_POWER = { 0, 25, 250, 2500, 25000 }
Constants.LEVEL_ALL_PRODUCT_LEVELS = 5 -- the +5 Levels for ALL product

-- Lock
Constants.LOCK_SECONDS = 60
Constants.LOCK_SECONDS_LONG = 120 -- Long Lock pass
Constants.LOCK_VIP_BONUS = 15
Constants.LOCK_BOOST_SECONDS = 300 -- the 5-Minute Lock product (the plate next to the lock pad)

-- Movement
Constants.BASE_WALK_SPEED = 18
Constants.SPEED_PER_LEVEL = 1.5
Constants.MAX_SPEED_LEVEL = 10
Constants.SPEED_PRICE_BASE = 150
Constants.SPEED_PRICE_GROWTH = 2.4
Constants.FAST_FEET_MULT = 1.25 -- while carrying

-- Bonk
Constants.BONK_RANGE = 9
Constants.BONK_COOLDOWN = 1.0
Constants.STUN_SECONDS = 1.5
Constants.STUN_SECONDS_MEGA = 2.5

-- Hotbar tools
Constants.FREE_POTIONS = 3 -- Speed Potions every new player starts with
Constants.POTION_PACK = 5 -- Speed Potions in the 5 Speed Potions product
Constants.POTION_SECONDS = 30
Constants.POTION_SPEED_MULT = 1.5
Constants.WINGS_LAUNCH = 60 -- upward speed of a wing jump (studs per second)
Constants.GLIDE_FALL = 6 -- fastest fall while gliding
Constants.GLIDE_SPEED = 34 -- forward speed while gliding
Constants.CAMERA_MAX_ZOOM = 45
Constants.DROP_GRAB_SECONDS = 8 -- a dropped dragon can be grabbed by anyone, then it flies home

-- Road
Constants.ROAD_START_X = -110
Constants.ROAD_END_X = 110 -- past here a road dragon can't be bought and walks into the exit tunnel
Constants.ROAD_EXIT_X = 132 -- deep in the dark tunnel, where it disappears
Constants.ROAD_SPEED = 7 -- studs per second
Constants.SPAWN_EVERY = 2.5
Constants.LEGEND_EVENT_EVERY = 300 -- a guaranteed Legend (or better) every 5 minutes
Constants.LEGEND_WARNING = 30
Constants.RARITY_WEIGHTS = { Common = 68, Rare = 24, Epic = 6.5, Legend = 1.3, Secret = 0.2 }
Constants.LUCK_RARITY_MULT = { Common = 1, Rare = 1.5, Epic = 3, Legend = 3, Secret = 3 }
Constants.LUCK_SPECIAL_MULT = 2
-- Custom dragons (Data/FancyDragons.lua): the chance a road spawn is one, and how their rarities are picked. If
-- none is walking the road, the next spawn always is one, so there's nearly always one in line.
Constants.FANCY_CHANCE = 0.18
Constants.FANCY_RARITY_WEIGHTS = { Rare = 46, Epic = 34, Legend = 15, Secret = 5 }
Constants.LUCK_SECONDS = 15 * 60

-- Money
Constants.SELL_FRACTION = 0.5
Constants.OFFLINE_RATE = 0.25 -- offline bases earn a quarter speed
Constants.OFFLINE_CAP_SECONDS = 8 * 3600
Constants.OFFLINE_MIN_SECONDS = 120
Constants.FRIEND_BONUS = 0.10 -- per friend in the server
Constants.MAX_FRIEND_BONUS_FRIENDS = 3
Constants.VIP_MULT = 1.5
Constants.DOUBLE_COINS_MULT = 2
Constants.TEAM_STEAL_RANGE = 40 -- a friend this close when you steal gives a bonus
Constants.TEAM_STEAL_BONUS_SECONDS = 60 -- bonus = this many seconds of the stolen dragon's income

-- Levels: a dragon levels up by itself over time (fast at first, then slower: level = 1 + LEVEL_RATE x the square
-- root of its age in minutes), and its owner can buy more levels with coins. Each level adds LEVEL_STEP to its
-- coin multiplier, up to MAX_LEVEL. Its size grows in four steps (Baby, Kid, Big, Giant) at STAGE_LEVELS, then
-- stays Giant: levels keep going, size doesn't.
Constants.MAX_LEVEL = 100
Constants.LEVEL_RATE = 2.25 -- level 8 (Kid) after 10 minutes, 18 (Big) after an hour, 50 (Giant) after 8 hours
Constants.LEVEL_STEP = 0.15 -- coin multiplier = 1 + 0.15 x (level - 1): level 49 makes about 8x
Constants.LEVEL_COST_SECONDS = 60 -- buying a level costs this many seconds of the dragon's base income...
Constants.LEVEL_COST_GROWTH = 1.12 -- ...times this to the power of (level - 1)
Constants.GROW_PRODUCT_LEVELS = 10 -- the +10 Levels product
Constants.STAGE_NAMES = { "Baby", "Kid", "Big", "Giant" }
Constants.STAGE_LEVELS = { 1, 8, 18, 49 }
Constants.STAGE_SCALE = { 1, 1.3, 1.65, 2.1 }

-- Egg and daily gift
Constants.EGG_HATCH_SECONDS = 20 * 3600 -- "hatches tomorrow"
Constants.DAILY_STREAK_BREAK_DAYS = 2

-- Invites (check Roblox's current rules on invite rewards before turning this on in a live game)
Constants.INVITE_REWARDS = true
Constants.MAX_INVITE_REWARDS = 10

-- Saving
Constants.AUTOSAVE_SECONDS = 120
Constants.LEADERBOARD_WRITE_SECONDS = 120
Constants.LEADERBOARD_READ_SECONDS = 60
Constants.LEADERBOARD_SIZE = 10

return Constants
