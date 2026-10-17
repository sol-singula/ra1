-- Turf Wars (ra9): every tunable number in one place (master plan §1-§8).
local Constants = {}

Constants.GAME = "ra9"
Constants.GAME_NAME = "Turf Wars"

-- Server and teams (§1, §2A)
Constants.MAX_PLAYERS = 40
Constants.TEAMS = { "red", "blue" }
Constants.TEAM_NAME = { red = "RED", blue = "BLUE" }
Constants.TEAM_COLOR = { red = Color3.fromRGB(235, 40, 45), blue = Color3.fromRGB(35, 110, 245) }
-- the turf on the ground: a softer version of the team colour, so players stand out from it
Constants.TURF_COLOR = { red = Color3.fromRGB(240, 120, 118), blue = Color3.fromRGB(120, 165, 245) }
Constants.TEAM_IMBALANCE = 2 -- (between matches the teams are evened to within 1; a joining player always takes the smaller team)

-- Phases (§2): seconds
Constants.BUILD_SECONDS = 20
Constants.AFK_SECONDS = 75 -- no moving, shooting or building this long in a match: off to the limbo room (0 = off)
Constants.AFK_RETURN_STUDS = 4
Constants.AFK_JOIN_GRACE = 120 -- seconds after joining that nobody is ever sent to the AFK room -- walk this far in the limbo room to jump back in
Constants.FIGHT_SECONDS = 120
Constants.STUCK_RESPAWN_SECONDS = 3 -- no body and no respawn coming this long: the server puts them back in
Constants.CHARGE_SECONDS = 20 -- the last this many seconds of a fight: anyone may cross the line, and the blade is out
Constants.VICTORY_SECONDS = 27 -- fireworks, the results, then the countdown to the next game...
Constants.TRANSITION_SECONDS = 3 -- ...and the next map loads: 30 s from the win to the next build phase
Constants.RESULTS_CARD_SECONDS = 12 -- the results card stays this long; the countdown shows after it
Constants.FIREWORKS_SECONDS = 14 -- fireworks in the winners' colour all over the arena
-- A NO on "are you liking the game?" must say why: one or more of these (the analytics keep the keys)
Constants.FEEDBACK_REASONS = {
	{ key = "hard", text = "Too hard / I die too fast", icon = "💀" },
	{ key = "confusing", text = "Didn't know what to do", icon = "❓" },
	{ key = "lag", text = "Laggy / low FPS", icon = "🐢" },
	{ key = "controls", text = "Controls feel bad", icon = "🎮" },
	{ key = "boring", text = "Boring / not much to do", icon = "😴" },
	{ key = "unfair", text = "Unfair teams or bots", icon = "⚖️" },
	{ key = "bugs", text = "Bugs / got stuck", icon = "🐛" },
	{ key = "pay", text = "Too much to buy", icon = "💸" },
}
Constants.FEEDBACK_ASK_DELAY = 6 -- seconds after a win before a winner is asked anything (after the fireworks start)
Constants.MIN_PLAYERS_TO_SCORE = 2 -- with fewer, phases still run (practice) but nobody can win
Constants.WATCHDOG_SECONDS = 45 * 60 -- a match this long is logged as stalled and restarted (never "won")

-- The battlefield (§3): runs along X, red at -X, blue at +X. Cells are the building grid and the turf strips.
Constants.CELL = 4
Constants.PUSH_CELLS_MIN = 1 -- a kill moves the frontline at least this many cells...
Constants.PUSH_CELLS_MAX = 3 -- ...and at most this many (small servers: each kill matters more)
Constants.PUSH_PLAYERS = 16 -- push = clamp(PUSH_PLAYERS / players, MIN, MAX) cells
Constants.TURF_MARGIN = 1 -- studs of grace before standing on enemy turf pushes you back
Constants.SPAWN_PROTECT = 2.5 -- seconds of protection after spawning
Constants.SPAWN_PROTECT_NEW = 4.5 -- (a player still waiting for their first ever knockout: a longer shield)
Constants.RESPAWN_SECONDS = 2 -- (dead time is when people leave: back in fast)
Constants.RESPAWN_SECONDS_NEW = 1.5 -- (no knockout yet in their life: faster still)

-- Health and combat (§5)
Constants.MAX_HEALTH = 100
Constants.AIM_ASSIST_MATCHES = 5 -- a new player (fewer matches than this) gets a whisper of help aiming:
Constants.AIM_ASSIST_CONE = 4 -- a shot already within this many degrees of an enemy...
Constants.AIM_ASSIST_PULL = 0.35 -- ...is turned this share of the way onto them...
Constants.AIM_ASSIST_MAX = 1.2 -- ...but never more than this many degrees (a near miss becomes a hit; a miss stays one)
-- By how they play (the "Device" attribute): a thumb can't aim like a mouse, a stick a little better. { cone degrees,
-- pull share, max degrees }; a keyboard player gets only the new-player whisper above.
Constants.AIM_ASSIST_DEVICE = {
	touch = { cone = 9, pull = 0.6, max = 4.5 },
	gamepad = { cone = 6, pull = 0.45, max = 2.5 },
}
-- The first knockout (CombatService:Novice: no knockout ever yet): a shot anywhere near an enemy in the open is aimed
-- onto them, leading them, and the hit spheres are wider, so it lands within the first half minute or so
Constants.FIRST_KILL_CONE = 35
Constants.FIRST_KILL_RANGE = 170
Constants.FIRST_KILL_RADIUS = 1.6 -- studs added to the body's hit sphere for their arrows
-- Lag: an arrow is also tested against where its target was the shooter's ping ago (capped), and a laggy shooter's
-- arrows are a touch wider (LAG_RADIUS studs per 100 ms over LAG_FREE, up to LAG_RADIUS_MAX)
Constants.LAG_REWIND_MAX = 0.3
Constants.LAG_FREE = 0.1
Constants.LAG_RADIUS = 0.5
Constants.LAG_RADIUS_MAX = 1.0
Constants.GRAVITY = 70 -- studs/s² on arrows (Roblox's 196 would make bows feel like mortars)
Constants.HIT_RADIUS_BODY = 2.3 -- the torso's hit sphere (round the root, +0.6 up)
Constants.HIT_RADIUS_HEAD = 1.1 -- the head's (2.6 above the root)
Constants.HEADSHOT = 1.35 -- damage multiplier
Constants.PARRY_SECONDS = 0.45 -- a blade swing knocks back arrows from the front for this long
Constants.PARRY_DOT = 0.25 -- ...arriving within about 75 degrees of where you swung
Constants.ARROW_LIFETIME = 4
Constants.ARROW_STEP = 1 / 30 -- the server's projectile step
Constants.ORIGIN_SLACK = 7 -- how far from your head a shot may start (latency, the viewmodel)
Constants.KNOCKBACK_CAP = 70 -- studs/s
Constants.ASSIST_WINDOW = 6 -- damage within this many seconds of a kill is an assist
-- TNT (Data/Weapons "tnt"): thrown in a lob, the server flies it like an arrow but heavier, and it blows up on what
-- it touches (or when its fuse runs out)
Constants.TNT_GRAVITY = 95 -- studs/s² (heavier than an arrow: a real lob)
Constants.TNT_LIFT = 0.42 -- the throw leaves this much above where you look (a lob, not a line)
Constants.TNT_FUSE = 1.7 -- seconds: in the air this long, it goes off where it is
Constants.TNT_RADIUS = 9 -- studs: enemy structures this close take the blast (falling off with distance)
Constants.TNT_CORE = 5 -- studs: enemies this close (and in the open from the blast) are knocked out
Constants.TNT_STRUCTURE = { 520, 160 } -- structure damage at the middle of the blast, and at its edge
Constants.TNT_TRY_SECONDS = 3600 -- without the TNT bought: one free throw this often, to try it
Constants.TNT_RED = Color3.fromRGB(200, 34, 30) -- (the sticks, whoever throws them)
Constants.TNT_PUSH = 55 -- studs/s: enemies in the blast but out of the core are thrown back this hard (less further out)

-- Movement (§6)
Constants.WALK_SPEED = 18
Constants.SPRINT_SPEED = 26
Constants.DRAW_SPEED = 13 -- moving while drawing a bow
Constants.SLIDE_SPEED = 42
Constants.SLIDE_SECONDS = 0.55
Constants.SLIDE_COOLDOWN = 1.6
Constants.FLIP_EVERY = 4 -- a front flip on every 4th eligible jump
Constants.CROUCH_SPEED = 10 -- crouched: slower, lower (a smaller target), the bow steadier
Constants.CROUCH_DROP = 1.1 -- studs the body (and the view, and the hit spheres) sink when crouched

-- Bots: only while exactly one person is on (BotService). The second person to join takes over a bot.
Constants.BOTS_OFF_AT = 4 -- this many real people on: no bots at all, the teams evened among the people instead
Constants.MIN_SIDE = 1 -- the fewest on a side: bots only make up the odd person out (alone: one bot to fight), and go when it is even
Constants.BOT_SPEED = 16 -- a little slower than a person walking
Constants.BOT_RANGE = 150 -- studs: how far they look for someone to shoot
Constants.BOT_SPREAD = 2.6 -- degrees of aim error (more at range): beatable, not helpless
Constants.BOT_TNT_RANGE = { 14, 70 } -- studs: a bot throws TNT at someone (or a wall in its way) this far off...
Constants.BOT_TNT_CHANCE = 0.35 -- ...this often when it's ready (else the bow)
Constants.BOT_RETREAT_HP = 35 -- a bot this hurt falls back behind cover
-- the first-match boost (TutorialService): only while a new player is alone with the bot in their first match
Constants.TUTORIAL_BOT_SPREAD = 2.2 -- the bot's aim error, times this
Constants.TUTORIAL_BOT_REACT = 1.8 -- the bot's wait before it draws, times this
Constants.TUTORIAL_PUSH_BONUS = 2 -- extra cells each of the new player's knockouts moves the line
Constants.TUTORIAL_BUILD_SECONDS = 38 -- the first build phase lasts at least this long once their tutorial starts (the intro, then PICK A WALL and PLACE IT)
Constants.TUTORIAL = true -- the first-minute tutorial for new players (tests that aren't about it turn it off)
Constants.BOT_REACT = 0.7 -- seconds before a bot starts drawing on someone new
Constants.BOT_NAMES = { "Ace", "Echo", "Nova", "Blitz", "Rook", "Vex", "Juno", "Kite", "Onyx", "Pike" }

-- Building (§7)
Constants.BUILD_BUDGET = 120 -- points a player gets each build phase
Constants.TEAM_STRUCTURES = 72 -- standing structures a team may have (+2 per player past 10)
Constants.BUILD_REACH = 44 -- studs from you to the structure
Constants.BUILD_MAP_OVERLAP = 1.25 -- studs a piece may poke into the map's shapes on each side (a little overlap is fine)
Constants.BUILD_FRONT_GAP = 0 -- cells kept free on your side of the frontline (0: build right up to it)

-- Rewards (§8)
Constants.QUALIFY_SECONDS = 120 -- in the match at least this long for a win to count
Constants.LADDER = 100
Constants.STREAKS = { 3, 5, 10 }

-- Admins (AdminService): by user id; the username works too, in Studio only
Constants.ADMINS = { [11787294097] = true } -- xthirtysix
Constants.ADMIN_NAMES = { xthirtysix = true }
Constants.ADMIN_HEARTBEAT = 15 -- seconds between each server's line in the server list
Constants.ADMIN_SERVER_TTL = 45 -- a server not heard from for this long drops off the list
Constants.ADMIN_SERVER_MAP = "TW_Servers_v1" -- (the MemoryStore sorted map)
Constants.ADMIN_VIP = { -- the VIP lengths an admin can give: key, seconds (true: for good), label
	{ "1h", 3600, "1 HOUR" },
	{ "1d", 86400, "1 DAY" },
	{ "7d", 7 * 86400, "7 DAYS" },
	{ "30d", 30 * 86400, "30 DAYS" },
	{ "forever", true, "FOREVER" },
}

-- Saves and logs
Constants.PROFILE_STORE = "TW_Profiles_v1"
Constants.AUTOSAVE_SECONDS = 120
Constants.JOIN_INTRO = true -- the tutorial's opening (RED, BLUE, THE LINE, YOUR TURF, into your eyes) on every join...
Constants.JOIN_INTRO_REJOIN_SECONDS = 120 -- ...unless they were here less than this long ago
-- The leaderboards (LeaderboardService): one OrderedDataStore per board, e.g. TW_Top_wins_v1
Constants.LEADERBOARD_STORE = "TW_Top_%s_v1"
Constants.LEADERBOARD_SIZE = 50 -- the top this many of each board
Constants.LEADERBOARD_WRITE_SECONDS = 60 -- a player's numbers are written at most this often
Constants.LEADERBOARD_REFRESH_SECONDS = 90 -- the top of every board is read again this often
Constants.GAME_LOG_URL = "https://kvedatksqkcsgivntskb.supabase.co/functions/v1/roblox-game-log"
Constants.ANALYTICS_URL = "https://kvedatksqkcsgivntskb.supabase.co/functions/v1/roblox-analytics"
Constants.GAME_LOG_IN_STUDIO = false
Constants.GAME_LOG_FLUSH_SECONDS = 5
Constants.ANALYTICS_GAME = "ra9" -- (the game tag on every analytics row: the live dashboard's ?game=ra9)
Constants.ANALYTICS_FLUSH_SECONDS = 10
Constants.ANALYTICS_SNAPSHOT_SECONDS = 30 -- each player's live row (the team's dashboard) this often
Constants.ANALYTICS_IDLE_SECONDS = 45 -- no movement or input this long: idle

-- The look (§0): white world, grey shadows, red and blue
Constants.WHITE = Color3.fromRGB(242, 242, 240)
Constants.LIGHT = Color3.fromRGB(226, 226, 224)
Constants.GREY = Color3.fromRGB(196, 197, 200)
Constants.DARK = Color3.fromRGB(150, 152, 158)
-- What a team builds: every piece in one shade of the team's colour, the Reinforced Wall (the armour) darker
Constants.BUILD_COLOR = { red = Color3.fromRGB(226, 70, 72), blue = Color3.fromRGB(62, 126, 236) }
Constants.ARMOR_COLOR = { red = Color3.fromRGB(128, 26, 32), blue = Color3.fromRGB(24, 56, 140) }

-- Sounds: the raw clips. The studio's uploaded set (shared with the other games) and a few of Roblox's own client
-- sounds (rbxasset://sounds/...). AudioController layers, pitches and shapes these into every cue the game plays
-- (a kill is a punch, a shatter and a rising chime at once); a cue with no recipe there plays its clip as it is.
Constants.SOUNDS = {
	shoot = "rbxassetid://95486565209148", -- (a whoosh)
	hit = "rbxassetid://138148057831879", -- (a short tick)
	kill = "rbxassetid://115604569854725", -- (a bright chime)
	hurt = "rbxassetid://138148057831879",
	horn = "rbxassetid://88832672717864",
	win = "rbxassetid://119933432712786",
	built = "rbxassetid://106516156393061",
	draw = "rbxassetid://96391581866585", -- (a wooden click: the bow's creak)
	tick = "rbxassetid://118634876996683",
	thud = "rbxassetid://105444665436909", -- (a dull knock: impacts, the punch under a kill)
	twang = "rbxassetid://136556611710738", -- (a bowstring)
	headshot = "rbxassetid://137096881472307",
	pop = "rbxassetid://109359226723492",
	whistle = "rbxassetid://109983444504089",
	boom = "rbxasset://sounds/collide.wav", -- (Roblox's own: a heavy thud, played low for the TNT)
	crumble = "rbxasset://sounds/collide.wav", -- (a structure coming down, higher and softer)
	rocket = "rbxasset://sounds/Rocket shot.wav", -- (a hissing launch: the fuse, the blast's tail)
	slash = "rbxasset://sounds/swordslash.wav",
	lunge = "rbxasset://sounds/swordlunge.wav",
	unsheath = "rbxasset://sounds/unsheath.wav", -- (steel on steel: the parry's clang)
	ping = "rbxasset://sounds/electronicpingshort.wav", -- (the chimes: kills, streaks, the last seconds)
	glass = "rbxasset://sounds/glassbreak.wav", -- (the shatter)
	button = "rbxasset://sounds/button.wav",
	click = "rbxasset://sounds/clickfast.wav",
	wind = "rbxasset://sounds/action_falling.mp3", -- (a rush of air: slowed right down, the ambient wind)
	land = "rbxasset://sounds/action_jump_land.mp3",
}
Constants.SOUND_VOLUME = { horn = 0.7, win = 0.8, shoot = 0.5, draw = 0.3, tick = 0.4, boom = 1, crumble = 0.55 }
-- The mix (AudioController's SoundGroups): Master over SFX (World: everything in the arena, ducked under a kill and
-- the kill cam; Stinger: your kills, streaks and phase calls, never ducked), Music (the ambient bed) and UI
Constants.SOUND_GROUPS = { Master = 1, SFX = 1, World = 0.9, Stinger = 1, Music = 0.55, UI = 0.7 }

return Constants
