-- Every tunable number in one place.
local Constants = {}

-- Look: plastic bricks with studs on top, like most popular Roblox games (false = smooth stone, wood and grass)
Constants.BRICK_STYLE = true

-- Players and bases
Constants.MAX_BASES = 8 -- set Max Players to 8 in Game Settings
Constants.START_NESTS = 4
Constants.START_COINS = 100
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
Constants.CASTLE_LEVEL_POWER = { 0, 25, 250, 2500, 25000, 250000, 2500000, 25000000 }
Constants.LEVEL_ALL_PRODUCT_LEVELS = 5 -- the +5 Levels for ALL product

-- Lock
Constants.LOCK_SECONDS = 60
Constants.LOCK_SECONDS_LONG = 120 -- Long Lock pass
-- Resetting a running lock (stepping on the pad again) can keep a door shut for at most this many lock lengths in a
-- row; then it opens and can't lock again for LOCK_COOLDOWN, so thieves always get a chance.
Constants.LOCK_CHAIN_MAX = 3
Constants.LOCK_COOLDOWN = 20
Constants.LOCK_VIP_BONUS = 15
Constants.LOCK_BOOST_SECONDS = 1800 -- the 30-Minute Lock product (the plate next to the lock pad); no recharge after it

-- Movement
Constants.BASE_WALK_SPEED = 18
Constants.SPEED_PER_LEVEL = 1.5
Constants.MAX_SPEED_LEVEL = 10
Constants.SPEED_PRICE_BASE = 150
Constants.SPEED_PRICE_GROWTH = 2.4
Constants.FAST_FEET_MULT = 1.25 -- while carrying

-- Bonk
Constants.BONK_RANGE = 9
Constants.BONK_COOLDOWN = 2.0 -- seconds between swings (no spamming)
Constants.BONK_IMMUNE_SECONDS = 3 -- after a stun wears off, nobody can bonk you again for this long (no stunlock)
Constants.STUN_SECONDS = 1.5
Constants.STUN_SECONDS_MEGA = 2.5 -- (no longer used directly: Mega Bonk adds MEGA_STUN_BONUS to any weapon)

-- Weapons, bought with coins (the SPEED panel): each tier reaches further, stuns longer and knocks harder.
Constants.WEAPONS = {
	{ key = "bat", name = "Bonk Bat", price = 0, range = 9, stun = 1.5, knock = 45 },
	{ key = "club", name = "Spiked Club", price = 2500, range = 10, stun = 1.8, knock = 55 },
	{ key = "hammer", name = "War Hammer", price = 40000, range = 11, stun = 2.1, knock = 65 },
	{ key = "mace", name = "Dragon Mace", price = 750000, range = 12.5, stun = 2.5, knock = 80 },
	{ key = "blade", name = "Inferno Blade", price = 20000000, range = 14, stun = 3, knock = 95 },
}
Constants.MEGA_STUN_BONUS = 1 -- Mega Bonk pass: bonked players stay stunned this much longer
Constants.HOME_DEFENSE_STUN = 1.5 -- bonks inside your own base stun this much longer...
Constants.HOME_DEFENSE_RANGE = 2 -- ...and reach this much further
Constants.BOUNTY_SECONDS = 60 -- bonking a thief pays this many seconds of the stolen dragon's income
Constants.BOUNTY_MIN = 100
Constants.STREAK_WINDOW = 40 -- seconds between hits to keep a bonk streak going
Constants.STREAK_ANNOUNCE = { [3] = true, [5] = true, [10] = true, [20] = true }
-- First minutes: brand-new players earn double for their first 10 minutes of play
Constants.NEW_PLAYER_BOOST_SECONDS = 10 * 60
Constants.NEW_PLAYER_BOOST_MULT = 2
-- NPC raiders (NpcService): goblins from the exit tunnel that keep quiet servers busy. They walk the road and
-- raid bases; bonk one carrying a dragon for the bounty, or it gets away (the dragon flies home, minus its coins).
Constants.NPC_FILL_TO = 5 -- with fewer players than this, raiders make up the difference
Constants.NPC_MAX = 3
Constants.NPC_SPEED = 13 -- slower than players (BASE_WALK_SPEED), so they can be caught
Constants.NPC_CARRY_SPEED = 10
Constants.NPC_RAID_EVERY = { 25, 55 } -- seconds between one raider's raids
Constants.NPC_VICTIM_COOLDOWN = 90 -- a player is not raided again this soon
Constants.NPC_STEAL_SECONDS = 1.5
Constants.NPC_IN_STUDIO = true
Constants.NPC_NAMES = { "Goblin Gus", "Sneaky Sid", "Grub", "Nibbles", "Snatch", "Zig", "Grizzle", "Pockets" }
Constants.NPC_COLORS = {
	Color3.fromRGB(120, 190, 80),
	Color3.fromRGB(95, 165, 120),
	Color3.fromRGB(150, 185, 70),
	Color3.fromRGB(110, 150, 190),
}

-- Hotbar tools
Constants.FREE_POTIONS = 3 -- Speed Potions every new player starts with
Constants.POTION_PACK = 5 -- Speed Potions in the 5 Speed Potions product
Constants.POTION_SECONDS = 30
Constants.POTION_SPEED_MULT = 1.5
Constants.WINGS_LAUNCH = 60 -- upward speed of a wing jump (studs per second)
Constants.GLIDE_FALL = 6 -- fastest fall while gliding
Constants.GLIDE_SPEED = 34 -- forward speed while gliding
Constants.CAMERA_MAX_ZOOM = 70
-- Discord game log (GameLogService): joins, and leaves with session stats
-- Robux offers the world shows (plates, Buy Now, +10 Levels, Hatch Now, potions): never during the tutorial or a
-- new player's first minutes, and the same offer at most once a minute (the Shop always works)
Constants.OFFER_NEW_PLAYER_SECONDS = 300
Constants.OFFER_COOLDOWN = 60
Constants.GAME_LOG_URL = "https://kvedatksqkcsgivntskb.supabase.co/functions/v1/roblox-game-log"
Constants.GAME_LOG_IN_STUDIO = false
Constants.GAME_LOG_FLUSH_SECONDS = 5 -- events and chat go out together this often
-- Analytics (AnalyticsService): every session and everything players do, into the roblox_sessions and
-- roblox_events tables (Supabase), to see why people leave and what keeps the ones who stay
Constants.ANALYTICS_URL = "https://kvedatksqkcsgivntskb.supabase.co/functions/v1/roblox-analytics"
Constants.ANALYTICS_GAME = "ra2"
Constants.ANALYTICS_FLUSH_SECONDS = 10
Constants.ANALYTICS_SNAPSHOT_SECONDS = 30 -- a progress snapshot of every player this often (and the live dashboard)
Constants.ANALYTICS_IDLE_SECONDS = 45 -- no moving and no input for this long counts as idle
-- Audio. Sound effects are our own uploads (files in other/ra2/audio/); the music is Roblox's licensed APM
-- library, free to use in any experience.
Constants.SOUNDS = {
	coin = "rbxassetid://118634876996683",
	buy = "rbxassetid://105104330819150",
	levelup = "rbxassetid://106516156393061",
	notify = "rbxassetid://115604569854725",
	potion = "rbxassetid://83557110540525",
	wings = "rbxassetid://109983444504089",
	steal = "rbxassetid://87517281723734",
	lock = "rbxassetid://96391581866585",
	swing = "rbxassetid://95486565209148",
	bonk = "rbxassetid://105444665436909",
	alarm = "rbxassetid://88832672717864",
	hatch = "rbxassetid://119933432712786",
}
Constants.SOUND_VOLUME = { swing = 0.35, coin = 0.55, notify = 0.45, alarm = 0.7 } -- the rest play at 0.6
Constants.MUSIC = { -- whimsical fantasy adventure, played in turn
	"rbxassetid://1841593944", -- Enchanted Kingdom
	"rbxassetid://1841594035", -- Mischievous Elves
	"rbxassetid://1848093905", -- Fancytale
	"rbxassetid://1839906422", -- Medieval Castle
	"rbxassetid://1841595081", -- Magic and Mayhem
}
Constants.DISCO_MUSIC = {
	"rbxassetid://9038367768", -- Funky Disco Beats
	"rbxassetid://1843468464", -- Celebrate
	"rbxassetid://1846063338", -- Fun Pop
}
Constants.MUSIC_VOLUME = 0.28
Constants.DISCO_MUSIC_VOLUME = 0.55

-- DISCO FEVER (the button in the secret disco): more coins for everyone in the server for a while
Constants.FEVER_MULT = 1.25
Constants.FEVER_SECONDS = 15 * 60
Constants.FEVER_COOLDOWN = 30 * 60 -- from when it was pressed
-- hotbar pictures (uploaded Images; the files are in other/ra2/icon/tools/)
Constants.TOOL_ICONS = {
	bat = "rbxassetid://124721099262846",
	hammer = "rbxassetid://90101203047877",
	potion = "rbxassetid://123480021870564",
	wings = "rbxassetid://80479736534280",
	club = "rbxassetid://101157335646275",
	mace = "rbxassetid://101917213176970",
	blade = "rbxassetid://134761226317836",
}
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
Constants.STAGE_SCALE = { 1, 1.12, 1.25, 1.4 } -- kept modest: a base full of giants hid everything

-- Egg and daily gift
Constants.EGG_HATCH_SECONDS = 2 * 3600 -- a new egg every 2 hours
Constants.DAILY_STREAK_BREAK_DAYS = 2

-- Invites (check Roblox's current rules on invite rewards before turning this on in a live game)
Constants.INVITE_REWARDS = true
Constants.MAX_INVITE_REWARDS = 10

-- Saving
Constants.AUTOSAVE_SECONDS = 120
Constants.LEADERBOARD_WRITE_SECONDS = 120
Constants.LEADERBOARD_READ_SECONDS = 60
Constants.LEADERBOARD_SIZE = 10
Constants.LEADERBOARD_LIVE_SECONDS = 2 -- how often the boards redraw with this server's live numbers
Constants.DAILY_RESET_HOUR_ET = 19 -- the daily TOP EARNERS board resets at 7pm US Eastern

-- Robux offer cards (ShopService:OfferCard): shown at the moment a player wants something
Constants.OFFER_ROBBED_COOLDOWN = 300 -- "Lock for 30 min?" after you get robbed, at most every 5 minutes
Constants.STARTER_AFTER_SECONDS = 480 -- the Starter Pack card shows once a session, after 8 minutes of play
Constants.STARTER_COINS_SECONDS = 600 -- Starter Pack coins: 10 minutes of income (at least STARTER_COINS_MIN)
Constants.STARTER_COINS_MIN = 5000

-- Asking players (FeedbackService)
Constants.FEEDBACK_AFTER = 420 -- "Do you like the game?" after 7 minutes of play (tutorial done)
Constants.FEEDBACK_MAX_ASKS = 2 -- at most twice (closed without answering), never again once answered
Constants.FEEDBACK_MAX_CHARS = 200 -- the "What should we add?" box
Constants.NOTIFY_AFTER = 900 -- the notifications offer after 15 minutes (also on the thank-you card)
Constants.NOTIFY_ASK_EVERY = 3 * 86400 -- and at most every 3 days
Constants.VOTE_NUDGE_AFTER = 1500 -- "Tap 👍 on the game page!" after 25 minutes (or right after a 👍 answer)
Constants.VOTE_NUDGE_EVERY = 3 * 86400

return Constants
