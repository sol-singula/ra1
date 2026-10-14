-- Every tunable number in one place (master plan §5: these are first guesses we test and change, and we write
-- down every change and why). Times are seconds, distances are studs, shrine health is percent.
local Constants = {}

Constants.GAME = "ra7"
Constants.MAX_PLAYERS = 24

-- The match (MatchService): intermission -> build -> plague -> fight (-> laststand) -> ended -> intermission.
Constants.INTERMISSION_SECONDS = 18 -- the hangout between matches (the results show first)
Constants.FIRST_MATCH_DELAY = 4 -- the first player into an empty server doesn't wait in the hangout
-- build time by how many are playing when it starts: fewer players, shorter build (plan §5 says 8 to 10 minutes
-- for a full server; a small server runs out of things to do sooner)
Constants.BUILD_SECONDS =
	{ { players = 1, seconds = 360 }, { players = 5, seconds = 420 }, { players = 9, seconds = 480 } }
Constants.PLAGUE_SECONDS = 8 -- the sky turns, the horn blows, the sick dwarves turn
Constants.FIGHT_SECONDS = 720 -- hold a shrine until this runs out and the dwarves win
Constants.ENDED_SECONDS = 12 -- how long the dwarves held, who did the most, coins and XP
Constants.RETREAT_SECONDS = 8 -- after a shrine falls, monsters wait this long before spawning there

-- The first scare and the scouts (master plan §12: something happens every 15 to 30 seconds)
Constants.FIRST_SCARE_AT = 120 -- seconds into build time: the sky dims, a horn, monsters on the far hill
Constants.SCOUT_FIRST_AT = 170 -- the first scout comes over the hill
Constants.SCOUT_EVERY = 70 -- then another one or two every this many seconds until the plague
Constants.SCOUT_STOP_BEFORE = 45 -- no new scouts this close to the plague

-- The plague (§5, §10): about 1 in 4 dwarves turn. In a small server nobody turns at first: the horde attacks,
-- and the dwarves who die become monsters.
Constants.PLAGUE_SHARE = 0.25
Constants.PLAGUE_MIN_PLAYERS = 4

-- Shrines (ShrineService, §4 step 5)
Constants.SHRINE_RADIUS = 26 -- studs: who counts as "near" the shrine
Constants.SHRINE_DRAIN_PER_EXTRA = 0.8 -- % per second for each monster more than the dwarves near it
Constants.SHRINE_DRAIN_MAX = 4 -- % per second at most
Constants.SHRINE_REGEN = 0.5 -- % per second while no monster is near
Constants.SHRINE_WARD_CUT = 0.2 -- each Shrine Ward built at the shrine cuts the drain by this much
Constants.SHRINE_WARDS_MAX = 2
Constants.STAGE_DRAIN_CUT = { camp = 0, town = 0.1, castle = 0.2 } -- a grander castle drains slower
Constants.SHRINE_FALLING_AT = 50 -- "Shrine 1 is falling!" once it drops below this
Constants.RETREAT_BOOST = 1.3 -- dwarves run this much faster for a few seconds after a shrine falls
Constants.RETREAT_BOOST_SECONDS = 10

-- The castle (BuildService, §7)
Constants.CELL = 4 -- the build grid, studs
Constants.PIECES_MAX = 220 -- pieces standing at once in a match (phones: §7 keep the piece count low)
Constants.BLUEPRINTS_PER_PLAYER = 6 -- unfinished pieces one player can have placed at once
Constants.HAMMER_RANGE = 14 -- studs from a piece's edge
Constants.SHRINE_KEEP_CLEAR = 10 -- nothing but Shrine Wards this close to a shrine
Constants.WARD_RANGE = 14 -- a Shrine Ward goes this close to a shrine
Constants.STAGE_POINTS = { town = 36, castle = 100 } -- castle points around the shrine for each stage
Constants.DEPOSIT_PER_HIT = 2 -- materials one hammer hit puts into a blueprint (from your bag)
Constants.DEPOSIT_BUILDER = 3
Constants.HEALER_AURA = 0.25 -- a Healer close by: hammer hits do this much more work
Constants.FIX_PER_HIT = 0.06 -- a hammer hit fixes this share of a damaged piece (Builders double it)
Constants.REPAIR_DELAY = 2 -- seconds after being hit before a Fix-it Station mends a piece

-- Characters (TeamService, CombatService)
Constants.DWARF_WALK = 17
Constants.MONSTER_WALK = 18
Constants.DWARF_JUMP = 7.2
Constants.MONSTER_JUMP = 5 -- low walls still stop monsters (the Jumper is a later job, §9)
Constants.BUILD_RESPAWN = 3 -- a dwarf who falls before the plague gets up again as a dwarf
Constants.TURN_RESPAWN = 5 -- a dwarf who dies in the fight is a monster this many seconds later
Constants.MONSTER_RESPAWN = 8 -- monsters come back, but not too fast (§9)
Constants.MONSTER_RESPAWN_LATE = 6 -- after 6 minutes of fighting
Constants.JOB_PICK_SECONDS = 8 -- the monster job picker picks Grunt for you after this long
Constants.MONSTER_UNLOCK_AFTER = 240 -- every monster job is open to everyone after this long into the fight
Constants.MONSTER_LEVELS = { 0, 40, 100, 180, 300 } -- monster XP for levels 1-5 (this match only)
Constants.MONSTER_LEVEL_BONUS = 0.08 -- health and damage per monster level above 1
Constants.MONSTER_TIME_BONUS = 0.04 -- health and damage per minute of fighting ...
Constants.MONSTER_TIME_BONUS_MAX = 0.5 -- ... up to this
Constants.MONSTER_XP = { damage = 0.1, pieceDamage = 0.02, kill = 25, piece = 6, shrine = 2 } -- per point / each
Constants.SPAWN_PROTECT = 3 -- seconds of no damage after spawning
Constants.COMBAT_TAG_SECONDS = 8 -- who gets the kill: the last enemy to hit you within this long
Constants.TIRED_AT = 0.3 -- below this share of health dwarves breathe hard (§13)

-- Resources (ResourceService, §7)
Constants.BAG_CAP = 24 -- stone + wood + gold you can carry (the Miner carries MINER_BAG_CAP)
Constants.MINER_BAG_CAP = 36
Constants.MINE_RANGE = 12 -- studs from a node's edge
Constants.NODE_RESPAWN = 40
Constants.GEM_CHANCE = 0.08 -- a Miner's hit can turn up a gem (worth GEM_GOLD gold)
Constants.GEM_GOLD = 3
Constants.HEAVY_AT = 0.6 -- a bag this full looks heavy (§13: carrying heavy stuff and looking heavy)
Constants.START_BAG = { stone = 4, wood = 2, gold = 0 } -- new matches start you with a little

-- Crafting (CraftService): the forge, the kitchen, the potion table. This match only, never bought.
Constants.CRAFT_RANGE = 14
Constants.GEAR_TIERS = 3
Constants.ARMOR_CUT = 0.12 -- damage taken, per armor tier
Constants.WEAPON_BONUS = 0.12 -- damage dealt, per weapon tier
Constants.GEAR_COST = { { gold = 2, stone = 2 }, { gold = 4, stone = 3 }, { gold = 6, stone = 4 } }
Constants.FOOD_COST = { wood = 2, gold = 0 }
Constants.FOOD_HEAL = 45 -- over FOOD_SECONDS
Constants.FOOD_SECONDS = 5
Constants.POTION_COST = { gold = 2, wood = 1 }
Constants.POTION_HEAL = 30
Constants.POTION_SPEED = 1.35
Constants.POTION_SPEED_SECONDS = 5
Constants.CARRY_MAX = 3 -- food and potions you can carry, each
Constants.EAT_COOLDOWN = 2

-- The horde (HordeService). NPC monsters fill the monster side so a small server still gets a fight; NPC dwarves
-- help a small crew build and hold (and when one dies it comes back as a monster, like everyone else).
Constants.NPC_TICK = 0.1 -- the server moves NPCs 10 times a second
Constants.NPC_SEND = 0.125 -- and sends their positions 8 times a second
Constants.NPC_MAX = 28
Constants.NPC_DWARF_FILL = 6 -- NPC dwarves at the start: this many minus the players (none with 6+ players)
Constants.HORDE_BASE = 2 -- NPC monsters wanted: base + per dwarf x (1 + growth x minutes) - per monster player
Constants.HORDE_PER_DWARF = 1.1
Constants.HORDE_GROWTH = 0.12
Constants.HORDE_PER_MONSTER_PLAYER = 1.2
Constants.HORDE_MIN = 2
Constants.WAVE_EVERY = 14 -- seconds between waves
Constants.WAVE_MAX = 6 -- NPCs per wave at most
Constants.NPC_AGGRO = 16 -- studs: an NPC monster leaves its path for a dwarf this close
Constants.NPC_LEASH = 36 -- ... but not farther than this from the path
Constants.HORDE_LATE_HOLD = 1.5 -- after a shrine falls, the next wave waits this many waves

-- Pings (PingService, §19)
Constants.PING_SECONDS = 8
Constants.PING_COOLDOWN = 2.5
Constants.PINGS = {
	{ key = "help", text = "Help here!", icon = "🆘" },
	{ key = "gate", text = "Gate is down!", icon = "🚪" },
	{ key = "coming", text = "Monsters coming!", icon = "👹" },
	{ key = "stone", text = "Need stone!", icon = "🪨" },
}

-- Progress (ProgressService, §17, §20): coins buy looks only, never power.
Constants.LEVEL_XP = 120 -- XP for account level 2; each level needs LEVEL_XP_GROWTH more
Constants.LEVEL_XP_GROWTH = 40
Constants.JOB_LEVEL_XP = 80
Constants.JOB_LEVEL_XP_GROWTH = 30
Constants.REWARDS = {
	base = 20, -- everyone who played the match
	perMinuteHeld = 5, -- dwarf: minutes alive after the plague
	perBeaten = 2, -- monsters beaten as a dwarf / dwarves beaten as a monster x3
	perBuilt = 1, -- pieces you helped build
	perBroken = 1, -- pieces you broke as a monster
	shrine = 15, -- monsters: a shrine taken while you fought
	dwarfWin = 40,
	monsterWin = 25,
	lastDwarf = 20,
	xpPerCoin = 1.5,
	cap = 600, -- coins from one match at most
}
Constants.DAILY_GIFTS = { 30, 40, 50, 60, 80, 100, 150 } -- coins for login days 1-7 in a row (then it repeats)
Constants.DAILY_TASKS = 3
Constants.BEST_STORE = "HC_BestHold_v1" -- OrderedDataStore: user id -> longest hold as a dwarf (seconds)
Constants.LEADERBOARD_SIZE = 10
Constants.LEADERBOARD_REFRESH = 120

-- Friends (JoinService)
Constants.FRIEND_RETRY_SECONDS = 15
Constants.FRIEND_RETRY_TRIES = 8

-- Saving
Constants.AUTOSAVE_SECONDS = 120
Constants.PROFILE_STORE = "HC_Profiles_v1"

-- Analytics and the Discord game log (same Supabase pipeline as ra2; rows tagged game = 'ra7')
Constants.GAME_LOG_URL = "https://kvedatksqkcsgivntskb.supabase.co/functions/v1/roblox-game-log"
Constants.GAME_LOG_IN_STUDIO = false
Constants.GAME_LOG_FLUSH_SECONDS = 5
Constants.ANALYTICS_URL = "https://kvedatksqkcsgivntskb.supabase.co/functions/v1/roblox-analytics"
Constants.ANALYTICS_GAME = "ra7"
Constants.ANALYTICS_FLUSH_SECONDS = 10
Constants.ANALYTICS_SNAPSHOT_SECONDS = 30
Constants.ANALYTICS_IDLE_SECONDS = 45

-- "Do you like the game?" (FeedbackService)
Constants.FEEDBACK_AFTER = 900 -- after 15 minutes of play (most of a match)
Constants.FEEDBACK_MAX_ASKS = 2
Constants.FEEDBACK_ASK_EVERY = 3 * 86400
Constants.FEEDBACK_MAX_CHARS = 200
Constants.NOTIFY_AFTER = 1500 -- the update-alerts offer after 25 minutes
Constants.NOTIFY_ASK_EVERY = 3 * 86400
Constants.DISLIKE_REASONS = {
	{ "doomed", "😩", "Dwarves always lose" },
	{ "weak", "😤", "Monsters are too weak" },
	{ "boring", "😴", "Build time is boring" },
	{ "lag", "🐢", "It's laggy" },
	{ "confusing", "🤔", "I don't get it" },
	{ "unfair", "😠", "The teams feel unfair" },
}

-- Sound (AudioController). The studio's uploaded effects shared with the other games, plus Roblox audio library
-- tracks; castle-specific recordings can replace any of them later by changing the id here.
Constants.SOUNDS = {
	pickup = "rbxassetid://118634876996683",
	coin = "rbxassetid://118634876996683",
	buy = "rbxassetid://105104330819150",
	built = "rbxassetid://106516156393061",
	levelup = "rbxassetid://106516156393061",
	hammer = "rbxassetid://96391581866585",
	mine = "rbxassetid://105444665436909",
	chop = "rbxassetid://105444665436909",
	swing = "rbxassetid://95486565209148",
	hit = "rbxassetid://138148057831879",
	thud = "rbxassetid://105444665436909",
	arrow = "rbxassetid://136556611710738",
	spit = "rbxassetid://83557110540525",
	magic = "rbxassetid://83557110540525",
	horn = "rbxassetid://88832672717864",
	shrineLost = "rbxassetid://88832672717864",
	crumble = "rbxassetid://105444665436909",
	notify = "rbxassetid://115604569854725",
	ping = "rbxassetid://115604569854725",
	roar = "rbxassetid://109983444504089",
	win = "rbxassetid://119933432712786",
	eat = "rbxassetid://83557110540525",
}
Constants.SOUND_VOLUME = { horn = 0.8, shrineLost = 0.85, hammer = 0.45, mine = 0.45, chop = 0.4, hit = 0.5 }
Constants.SOUND_SPEED = { shrineLost = 0.55, crumble = 0.7, roar = 0.6, chop = 1.25, thud = 0.8 }
Constants.MUSIC = {
	build = { -- happy and bouncy (§15)
		"rbxassetid://1839906422", -- Medieval Castle
		"rbxassetid://1841594035", -- Mischievous Elves
		"rbxassetid://1841593944", -- Enchanted Kingdom
		"rbxassetid://1848093905", -- Fancytale
	},
	fight = { -- dark, fast drums
		"rbxassetid://1841595081", -- Magic and Mayhem
		"rbxassetid://1837768013", -- Rise to the Top
	},
	laststand = { "rbxassetid://135990877378159" }, -- played faster (LASTSTAND_MUSIC_SPEED)
	hangout = { "rbxassetid://1848093905" },
}
Constants.MUSIC_VOLUME = 0.22
Constants.LASTSTAND_MUSIC_SPEED = 1.12

-- Admins (by Roblox user id): logged by the anti-cheat but never kicked
Constants.ADMINS = {
	[11787294097] = true, -- xthirtysix
}

-- Anti-cheat (AntiCheatService). Every fight and every piece is decided on the server already (§21); this is
-- about cheating with your character (speed, teleporting, flying, walking through walls) and spamming requests.
Constants.AC_KICK_STRIKES = 12
Constants.AC_DECAY_SECONDS = 20
Constants.AC_WINDOW = 2
Constants.AC_SPEED_SLACK = 1.6
Constants.AC_SPEED_EXTRA = 16
Constants.AC_AIR_SECONDS = 3
Constants.AC_AIR_HEIGHT = 34 -- the towers are 26 studs tall
Constants.AC_SPAM_DROPS = 80
Constants.AC_SPAM_WINDOW = 10

return Constants
