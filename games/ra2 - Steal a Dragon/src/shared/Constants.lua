-- Every tunable number in one place.
local Constants = {}

-- Look: plastic bricks with studs on top, like most popular Roblox games (false = smooth stone, wood and grass)
Constants.BRICK_STYLE = true

-- Players and bases
Constants.MAX_BASES = 8 -- set Max Players to 8 in Game Settings
Constants.START_NESTS = 4
Constants.MAX_NESTS = 16 -- includes the 4 from the Extra Nests pass
Constants.BUYABLE_NESTS = 12 -- nests 5..12 can be bought with coins
Constants.NEST_PRICES =
	{ [5] = 100, [6] = 250, [7] = 600, [8] = 1500, [9] = 4000, [10] = 10000, [11] = 25000, [12] = 60000 }

-- Lock
Constants.LOCK_SECONDS = 60
Constants.LOCK_SECONDS_LONG = 120 -- Long Lock pass
Constants.LOCK_VIP_BONUS = 15

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
Constants.DROP_GRAB_SECONDS = 8 -- a dropped dragon can be grabbed by anyone, then it flies home

-- Road
Constants.ROAD_START_X = -110
Constants.ROAD_END_X = 110
Constants.ROAD_SPEED = 7 -- studs per second
Constants.SPAWN_EVERY = 2.5
Constants.LEGEND_EVENT_EVERY = 300 -- a guaranteed Legend (or better) every 5 minutes
Constants.LEGEND_WARNING = 30
Constants.RARITY_WEIGHTS = { Common = 68, Rare = 24, Epic = 6.5, Legend = 1.3, Secret = 0.2 }
Constants.LUCK_RARITY_MULT = { Common = 1, Rare = 1.5, Epic = 3, Legend = 3, Secret = 3 }
Constants.LUCK_SPECIAL_MULT = 2
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

-- Growth: seconds of age for each stage (Baby, Kid, Big, Giant), and the coin multiplier
Constants.STAGE_NAMES = { "Baby", "Kid", "Big", "Giant" }
Constants.STAGE_AGES = { 0, 10 * 60, 60 * 60, 8 * 60 * 60 }
Constants.STAGE_MULT = { 1, 2, 4, 8 }
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
