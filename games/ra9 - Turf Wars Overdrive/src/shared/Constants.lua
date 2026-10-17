-- Turf Wars: Overdrive (ra9): every tunable number in one place (master plan §1-§8).
local Constants = {}

Constants.GAME = "ra9"
Constants.GAME_NAME = "Turf Wars: Overdrive"

-- Server and teams (§1, §2A)
Constants.MAX_PLAYERS = 40
Constants.TEAMS = { "red", "blue" }
Constants.TEAM_NAME = { red = "RED", blue = "BLUE" }
Constants.TEAM_COLOR = { red = Color3.fromRGB(235, 40, 45), blue = Color3.fromRGB(35, 110, 245) }
-- the turf on the ground: a softer version of the team colour, so players stand out from it
Constants.TURF_COLOR = { red = Color3.fromRGB(240, 120, 118), blue = Color3.fromRGB(120, 165, 245) }
Constants.TEAM_IMBALANCE = 2 -- (between matches the teams are evened to within 1; a joining player always takes the smaller team)

-- Phases (§2): seconds
Constants.BUILD_SECONDS = 60
Constants.FIGHT_SECONDS = 120
Constants.VICTORY_SECONDS = 27 -- fireworks, the results, then the countdown to the next game...
Constants.TRANSITION_SECONDS = 3 -- ...and the next map loads: 30 s from the win to the next build phase
Constants.RESULTS_CARD_SECONDS = 12 -- the results card stays this long; the countdown shows after it
Constants.FIREWORKS_SECONDS = 14 -- fireworks in the winners' colour all over the arena
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
Constants.RESPAWN_SECONDS = 3

-- Health and combat (§5)
Constants.MAX_HEALTH = 100
Constants.GRAVITY = 70 -- studs/s² on arrows (Roblox's 196 would make bows feel like mortars)
Constants.HIT_RADIUS_BODY = 2.3 -- the torso's hit sphere (round the root, +0.6 up)
Constants.HIT_RADIUS_HEAD = 1.1 -- the head's (2.6 above the root)
Constants.HEADSHOT = 1.35 -- damage multiplier
Constants.ARROW_LIFETIME = 4
Constants.ARROW_STEP = 1 / 30 -- the server's projectile step
Constants.ORIGIN_SLACK = 7 -- how far from your head a shot may start (latency, the viewmodel)
Constants.KNOCKBACK_CAP = 70 -- studs/s
Constants.ASSIST_WINDOW = 6 -- damage within this many seconds of a kill is an assist

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
Constants.BOT_ALLIES = 0 -- on your side
Constants.BOT_ENEMIES = 1 -- against you
Constants.BOT_SPEED = 16 -- a little slower than a person walking
Constants.BOT_RANGE = 150 -- studs: how far they look for someone to shoot
Constants.BOT_SPREAD = 2.6 -- degrees of aim error (more at range): beatable, not helpless
Constants.BOT_REACT = 0.7 -- seconds before a bot starts drawing on someone new
Constants.BOT_NAMES = { "Ace", "Echo", "Nova", "Blitz", "Rook", "Vex", "Juno", "Kite", "Onyx", "Pike" }

-- Building (§7)
Constants.BUILD_BUDGET = 100 -- points a player gets each build phase
Constants.TEAM_STRUCTURES = 60 -- standing structures a team may have (+2 per player past 10)
Constants.BUILD_REACH = 44 -- studs from you to the structure
Constants.BUILD_FRONT_GAP = 1 -- cells kept free on your side of the frontline

-- Rewards (§8)
Constants.QUALIFY_SECONDS = 120 -- in the match at least this long for a win to count
Constants.LADDER = 100
Constants.STREAKS = { 3, 5, 10 }

-- Saves and logs
Constants.PROFILE_STORE = "TW_Profiles_v1"
Constants.AUTOSAVE_SECONDS = 120
Constants.GAME_LOG_URL = "https://kvedatksqkcsgivntskb.supabase.co/functions/v1/roblox-game-log"
Constants.ANALYTICS_URL = "https://kvedatksqkcsgivntskb.supabase.co/functions/v1/roblox-analytics"
Constants.GAME_LOG_IN_STUDIO = false
Constants.GAME_LOG_FLUSH_SECONDS = 5

-- The look (§0): white world, grey shadows, red and blue
Constants.WHITE = Color3.fromRGB(242, 242, 240)
Constants.LIGHT = Color3.fromRGB(226, 226, 224)
Constants.GREY = Color3.fromRGB(196, 197, 200)
Constants.DARK = Color3.fromRGB(150, 152, 158)

-- Sounds (the studio's uploaded set, shared with the other games)
Constants.SOUNDS = {
	shoot = "rbxassetid://95486565209148",
	hit = "rbxassetid://138148057831879",
	kill = "rbxassetid://115604569854725",
	hurt = "rbxassetid://138148057831879",
	horn = "rbxassetid://88832672717864",
	win = "rbxassetid://119933432712786",
	built = "rbxassetid://106516156393061",
	draw = "rbxassetid://96391581866585",
	tick = "rbxassetid://118634876996683",
}
Constants.SOUND_VOLUME = { horn = 0.7, win = 0.8, shoot = 0.5, draw = 0.3, tick = 0.4 }

return Constants
