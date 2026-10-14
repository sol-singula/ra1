-- Every tunable number in one place (master plan §3, §5, §8: design targets we test and change, not final values).
-- Times are seconds, distances are studs, health is hit points.
local Constants = {}

Constants.GAME = "ra6"
Constants.MAX_PLAYERS = 6 -- master plan §8: six first; try four and eight in playtests

-- The run (RunService): day 1 -> dusk -> night 1 -> day 2 -> ... -> night 6 -> day 7 -> dusk -> night 7 (Mega
-- Kermy) -> results -> a new run. "Survive the 6-7": get through night 6, then beat what comes on night 7.
-- About 27 minutes in all (§3: 20-30), shorter if the team rings the camp bell to call the night early.
Constants.DAY_SECONDS = { 210, 100, 95, 95, 95, 95, 100 } -- days 1-7 (day 1: the roster is open, the guide runs)
Constants.DUSK_SECONDS = 12 -- "Night is coming!": the sky turns, the first howls
Constants.NIGHT_SECONDS = { 70, 80, 90, 95, 100, 110 } -- nights 1-6
Constants.DAWN_SECONDS = 6 -- "You survived night 3!" before the next day starts
Constants.BOSS_ENRAGE_AT = 300 -- seconds into night 7: Mega Kermy gets faster
Constants.BOSS_MAX_SECONDS = 600 -- night 7 ends at dawn: not beaten by then counts as a loss
Constants.RESULTS_SECONDS = 25
Constants.FIRST_SIGHTING_AT = 50 -- seconds into day 1: Kermy shows himself at the edge of the camp (the hook is in
-- the first minute: §4 had this at 2:30, the first playtest moved it up)
Constants.FIRST_AMBUSH_AT = 62 -- seconds into day 1: a Snapcap jumps out at someone (fighting, taught by day)
Constants.GUIDE_DUSK_WARNING = 40 -- seconds left in day 1 when the guide says to get back to camp
Constants.BELL_MIN_LEFT = 20 -- the camp bell can't call the night with less than this left in the day
Constants.EMPTY_ABORT = 2 -- seconds with nobody left before an abandoned run is thrown away

-- Survivors (SurvivorService)
Constants.MAX_HP = 100
Constants.WALK_SPEED = 16
Constants.SPRINT_SPEED = 25 -- faster than Kermy's hunt (19) and a Grinwolf's run (21): sprinting escapes
Constants.CRAWL_SPEED = 5
Constants.JUMP_HEIGHT = 7.5
Constants.MAX_SLOPE = 52
Constants.STAMINA_MAX = 100
Constants.SPRINT_COST = 13 -- per second (about 8 seconds of sprint from full)
Constants.STAMINA_REGEN = 28 -- per second, after STAMINA_DELAY
Constants.STAMINA_DELAY = 0.7
Constants.DODGE_COST = 22
Constants.DODGE_COOLDOWN = 0.9
Constants.DODGE_DISTANCE = 13
Constants.DODGE_SECONDS = 0.3
Constants.IFRAME_SECONDS = 0.38 -- no damage this long after a dodge starts
Constants.DODGE_GRACE_MAX = 0.15 -- §5: latency must not make dodges feel random (see CombatService)
Constants.REGEN_DELAY = 6 -- seconds after being hit before the campfire heals you
Constants.FIRE_REGEN = 4 -- HP per second within FIRE_RADIUS of a burning campfire
Constants.SPAWN_PROTECT = 3
Constants.COMBAT_SECONDS = 5
Constants.REVIVE_SECONDS = 3.5 -- a teammate holds the prompt this long (a medkit in hand halves it)
Constants.REVIVE_HP = 35
Constants.FIRE_REVIVE_SECONDS = 6 -- downed and alone? crawl into the campfire's light and get up by yourself
Constants.RESPAWN_KIT = { { "rusty_axe", 1 }, { "torch", 1 } } -- ghosts come back at dawn with this
Constants.LOST_PACK_SECONDS = 600 -- a fallen survivor's pack waits where they fell this long
Constants.ISOLATED_RADIUS = 30 -- nobody else this close: Kermy and the wolves like you

-- Inventory (InventoryService, §6)
Constants.HOTBAR = 6
Constants.BACKPACK = 12 -- more with a pack (Data/Items: slots)
Constants.STACK = 99
Constants.PICKUP_RANGE = 12
Constants.DROP_SECONDS = 300 -- items dropped on the ground vanish after this (lost packs last longer)
Constants.STORAGE_SLOTS = 48 -- the camp's shared chest (resources stack in it)
Constants.USE_RANGE = 14 -- studs from a station, chest, board or blueprint

-- Combat (CombatService)
Constants.MELEE_SLACK = 3 -- extra reach the server allows for lag
Constants.ARC_SLACK = 20 -- degrees
Constants.ARROW_SPEED = 150
Constants.ARROW_GRAVITY = 24
Constants.PROJECTILE_SECONDS = 2.2
Constants.STAGGER_SECONDS = 1.5 -- a club's stagger stops a wind-up and stuns this long
Constants.TRAPS_MAX = 14 -- traps the team can have set at once
Constants.THROW_RANGE = 40
Constants.FRIENDLY_FIRE = false
Constants.HIT_FLASH = 0.25
Constants.SPECIAL_COOLDOWN = 6 -- mastery level 3 alternate moves (Data/Progression)

-- Resources (ResourceService)
Constants.GATHER_RANGE = 9
Constants.TREE_HP = 40 -- an axe hit does its tree power x 10
Constants.TREE_WOOD = 6 -- wood from a felled tree (+ some every hit)
Constants.ROCK_HP = 36
Constants.ROCK_RESPAWN = 120
Constants.BUSH_RESPAWN = 90
Constants.SCRAP_RESPAWN = 150

-- Loot (LootService)
Constants.CRATES = 34 -- loose crates in the forest each run (plus the ones at findings)
Constants.CRATES_NEAR_CAMP = 4 -- the first five minutes: something to open close by (§4)
Constants.MIMICS = { 2, 4 } -- crates that bite (range per run)
Constants.LOCKED_CHESTS = 2 -- need a Rusty Key
Constants.SUPPLY_DROP_DAYS = { 3, 5 } -- a supply crate parachutes into the deep forest these days
Constants.OPEN_SECONDS = 0.6

-- The camp (CampService, §7)
Constants.CAMP_RADIUS = 46
Constants.WALL_RADIUS = 36
Constants.DEPOSIT_PER_SECOND = 8 -- materials moved into a blueprint while you hold the prompt
Constants.FUEL_MAX = { 100, 120, 140, 160 } -- by camp tier
Constants.FUEL_PER_WOOD = 6
Constants.FUEL_BURN = 1 -- per second at night
Constants.STOMP_PER_SECOND = 4 -- monsters stamping on the fire (nobody left to chase) take at most this much a second
Constants.FIRE_LIGHT = { 26, 32, 38, 46 } -- light radius by camp tier (also the warm-up radius)
Constants.DARK_DAMAGE = 1.25 -- the fire is out: monsters hit this much harder
Constants.REPAIR_PER_WOOD = 30
Constants.ANCIENT_PINE_HITS = 2 -- Mega Kermy charges into each Ancient Pine this many times before it breaks

-- Monsters (MonsterService)
Constants.NPC_TICK = 0.1 -- the server moves monsters 10 times a second
Constants.NPC_SEND = 0.125 -- and sends their positions 8 times a second
Constants.NPC_MAX = 26 -- §11: a budget for phones
Constants.NIGHT_BUDGET = { 8, 13, 19, 25, 32, 40 } -- threat points for nights 1-6 (Formulas.nightBudget)
Constants.PLAYER_SCALE = { 0.55, 0.8, 1, 1.2, 1.38, 1.55, 1.7, 1.85 } -- by survivors at the stage boundary (§8)
Constants.WAVE_EVERY = 11
Constants.SPAWN_DISTANCE = { 105, 140 } -- studs from the nearest survivor, out of sight in the trees
Constants.LEASH = 200 -- monsters this far from every survivor walk back toward the camp
Constants.DAY_PACKS = 2 -- packs roaming the deep forest by day (from day 2)
Constants.ELITE_FROM_DAY = 3 -- a golden pack in the deep forest from this day
Constants.KERMY_HUNT_SPEED = 19
Constants.KERMY_LUNGE_RANGE = 14
Constants.KERMY_TELL = 0.9 -- seconds of "SIX... SEVEN!" before the lunge (§5: readable)
Constants.KERMY_BACK_AFTER = 50 -- knocked out on nights 5-6: he's back after this (Six-Seven: 30)
Constants.KERMY_DAY_PEEK_EVERY = 45 -- by day he peeks at someone from the trees this often

-- Mega Kermy (BossService, night 7)
Constants.BOSS_HP = 3200 -- x player scale x difficulty
Constants.BOSS_CHARGE_SPEED = 58
Constants.BOSS_CHARGE_TELL = 1.2
Constants.BOSS_STUN = 5
Constants.BOSS_WEAK_MULT = 2.5 -- damage while he's dizzy
Constants.BOSS_TIRED_MULT = 1.8
Constants.COCOON_HP = 120
Constants.COCOON_SQUEEZE = 3 -- damage per second inside
Constants.COCOON_MASH = 10 -- each press from inside

-- Difficulty (§9): unlocked by clearing the one before. Chosen by vote on day 1, locked when night 1 starts.
Constants.DIFFICULTIES = {
	{ key = "normal", name = "Normal", hp = 1, dmg = 1, count = 1, bleed = 30, fireRevive = true, xp = 1 },
	{ key = "hard", name = "Hard", hp = 1.35, dmg = 1.25, count = 1.25, bleed = 22, fireRevive = true, xp = 1.5 },
	{
		key = "nightmare",
		name = "Nightmare",
		hp = 1.8,
		dmg = 1.5,
		count = 1.5,
		bleed = 16,
		fireRevive = false,
		xp = 2.2,
		elitesNightly = true,
	},
	{
		key = "sixseven",
		name = "Six-Seven",
		hp = 2.3,
		dmg = 1.75,
		count = 1.75,
		bleed = 12,
		fireRevive = false,
		xp = 3,
		elitesNightly = true,
		kermyBack = 30,
	},
}

-- Night events (§3: special events change the battlefield), one random event on some nights from night 3
Constants.EVENT_CHANCE = 0.6
Constants.EVENTS = {
	fog = { name = "Fog Night", text = "A thick fog rolls in... the wolves love it.", nights = { 3, 4, 5, 6 } },
	fireflies = { name = "Firefly Night", text = "Fireflies everywhere! Catch a few jars.", nights = { 3, 4 } },
	bloodmoon = { name = "Blood Moon", text = "The moon turns red. Everything is faster.", nights = { 5, 6 } },
	storm = { name = "Thunderstorm", text = "Lightning! Stay near the camp.", nights = { 4, 5, 6 } },
}

-- Progress (ProgressService, §9)
Constants.LEVEL_XP = 160 -- XP for level 2; each level needs LEVEL_XP_GROWTH more
Constants.LEVEL_XP_GROWTH = 60
Constants.MASTERY_XP = { 0, 60, 150, 280, 450, 680, 960, 1300, 1700, 2200 } -- weapon mastery levels 1-10
Constants.XP = {
	night = 25, -- x the night's number, for everyone still in the run at dawn
	win = 300, -- x the difficulty's xp
	objective = 30,
	discovery = 40, -- the first time you find a finding, an item or a monster; 8 after that
	repeatFind = 8,
	revive = 15,
	kill = { small = 2, medium = 5, heavy = 14, kermy = 60, boss = 250 },
	contribution = 0.25, -- per material put into the camp
	guide = { chop = 10, build = 20, loot = 10, equip = 5, fight = 25, kermy = 5 }, -- each of the guide's firsts
	cap = 2500, -- from one run
}
Constants.MASTERY_GAIN = { hit = 1, kill = 6, use = 4 } -- per hit / kill with that class / support use

-- Leaderboards (LeaderboardService, §9): friends first, then everyone
Constants.BOARD_REFRESH = 300
Constants.BOARD_FRIENDS_MAX = 30
Constants.BOARD_TOP = 10
Constants.PUBLIC_STORE = "S67_Public_v1"
Constants.BOARD_STORE_PREFIX = "S67_Board_v1_"

-- Friends and new runs (JoinService)
Constants.FRIEND_RETRY_SECONDS = 15
Constants.FRIEND_RETRY_TRIES = 8

-- Saving
Constants.AUTOSAVE_SECONDS = 120
Constants.PROFILE_STORE = "S67_Profiles_v1"

-- Analytics and the Discord game log (the studio's Supabase pipeline; rows tagged game = 'ra6')
Constants.GAME_LOG_URL = "https://kvedatksqkcsgivntskb.supabase.co/functions/v1/roblox-game-log"
Constants.GAME_LOG_IN_STUDIO = false
Constants.GAME_LOG_FLUSH_SECONDS = 5
Constants.ANALYTICS_URL = "https://kvedatksqkcsgivntskb.supabase.co/functions/v1/roblox-analytics"
Constants.ANALYTICS_GAME = "ra6"
Constants.ANALYTICS_FLUSH_SECONDS = 10
Constants.ANALYTICS_SNAPSHOT_SECONDS = 30
Constants.ANALYTICS_IDLE_SECONDS = 45

-- "Do you like the game?" (FeedbackService)
Constants.FEEDBACK_AFTER = 1200 -- after 20 minutes (most of a run)
Constants.FEEDBACK_MAX_ASKS = 2
Constants.FEEDBACK_ASK_EVERY = 3 * 86400
Constants.FEEDBACK_MAX_CHARS = 200
Constants.NOTIFY_AFTER = 1700
Constants.NOTIFY_ASK_EVERY = 3 * 86400
Constants.DISLIKE_REASONS = {
	{ "scary", "😱", "Too scary" },
	{ "hard", "💀", "Too hard" },
	{ "long", "🐌", "Runs take too long" },
	{ "lag", "🐢", "It's laggy" },
	{ "boring", "😴", "Not much to do" },
	{ "confusing", "🤔", "I don't get it" },
}

-- Pings (PingService, §12): a quick word for the team
Constants.PING_SECONDS = 8
Constants.PING_COOLDOWN = 2
Constants.PINGS = {
	{ key = "help", text = "Help me!", icon = "🆘" },
	{ key = "loot", text = "Loot here!", icon = "🎁" },
	{ key = "kermy", text = "KERMY!", icon = "🐸" },
	{ key = "camp", text = "Back to camp!", icon = "🔥" },
}

-- Sound (AudioController): the studio's shared effects and Roblox audio library tracks; a recording made for the
-- game can replace any of them by changing the id here.
Constants.SOUNDS = {
	pickup = "rbxassetid://118634876996683",
	craft = "rbxassetid://105104330819150",
	built = "rbxassetid://106516156393061",
	levelup = "rbxassetid://106516156393061",
	chop = "rbxassetid://105444665436909",
	mine = "rbxassetid://105444665436909",
	swing = "rbxassetid://95486565209148",
	hit = "rbxassetid://138148057831879",
	thud = "rbxassetid://105444665436909",
	arrow = "rbxassetid://136556611710738",
	open = "rbxassetid://96391581866585",
	eat = "rbxassetid://83557110540525",
	magic = "rbxassetid://83557110540525",
	horn = "rbxassetid://88832672717864",
	notify = "rbxassetid://115604569854725",
	ping = "rbxassetid://115604569854725",
	roar = "rbxassetid://109983444504089",
	howl = "rbxassetid://109983444504089",
	win = "rbxassetid://119933432712786",
	dodge = "rbxassetid://95486565209148",
	downed = "rbxassetid://88832672717864",
}
Constants.SOUND_VOLUME = { horn = 0.7, chop = 0.45, mine = 0.45, hit = 0.5, roar = 0.8, howl = 0.6, downed = 0.6 }
Constants.SOUND_SPEED = { roar = 0.55, howl = 1.4, thud = 0.8, chop = 1.2, downed = 1.3, dodge = 1.6 }
Constants.MUSIC = {
	day = {
		"rbxassetid://1841594035", -- Mischievous Elves
		"rbxassetid://1848093905", -- Fancytale
	},
	night = {
		"rbxassetid://1841595081", -- Magic and Mayhem
	},
	boss = { "rbxassetid://1837768013" }, -- Rise to the Top
	results = { "rbxassetid://1848093905" },
}
Constants.MUSIC_VOLUME = { day = 0.16, night = 0.22, boss = 0.26, results = 0.18 }

-- Admins (by Roblox user id): logged by the anti-cheat but never kicked
Constants.ADMINS = {
	[11787294097] = true, -- xthirtysix
}

-- Anti-cheat (AntiCheatService): the server decides every hit, item and upgrade already (§14); this is about
-- cheating with your character (speed, teleporting, flying) and spamming requests.
Constants.AC_KICK_STRIKES = 12
Constants.AC_DECAY_SECONDS = 20
Constants.AC_WINDOW = 2
Constants.AC_SPEED_SLACK = 1.5
Constants.AC_SPEED_EXTRA = 18 -- dodges are short bursts
Constants.AC_AIR_SECONDS = 3
Constants.AC_AIR_HEIGHT = 30 -- the ranger tower is 26 studs tall
Constants.AC_SPAM_DROPS = 80
Constants.AC_SPAM_WINDOW = 10

return Constants
