-- Every tunable number in one place (master plan §3, §5, §7: design targets we test and change, not final values).
-- Times are seconds, distances are studs, health is hit points.
local Constants = {}

Constants.GAME = "ra8"
-- Twenty rafts to a server, one shared ocean (everyone sees everyone): the place's Server Size is 20.
Constants.MAX_PLAYERS = 20

-- Saves (PlayerDataService)
Constants.PROFILE_STORE = "EV_Profiles_v1"
Constants.PUBLIC_STORE = "EV_Public_v1"
Constants.BOARD_STORE_PREFIX = "EV_Board_"
Constants.AUTOSAVE_SECONDS = 120

-- The ocean (World/OceanLayout): six plots round the centre, each with a raft and room for the island that comes
-- to it when a voyage arrives
Constants.OCEAN_SIZE = 6000 -- the water, edge to edge (the far islands sit out to its edge)
Constants.WATER_LEVEL = 0
Constants.SEA_FLOOR = -34
Constants.PLOT_RADIUS = 300 -- a plot: the raft in the middle, debris drifting through, the island zone beside it
-- Rafts never meet: neighbouring plots are PLOT_SPACING apart. The biggest raft a grid allows (GRID_MIN..GRID_MAX)
-- reaches about 246 studs from the middle each way, square to the world, so two side by side need 492 along X or Z;
-- at a 45-degree bearing that's 492 x sqrt 2 = 696 apart. Nobody can build into anyone.
Constants.PLOT_SPACING = 720
-- the plots sit on a ring of this radius round the centre (neighbours PLOT_SPACING apart, whatever MAX_PLAYERS is)
Constants.PLOT_RING = math.ceil(Constants.PLOT_SPACING / (2 * math.sin(math.pi / Constants.MAX_PLAYERS)))
Constants.ISLAND_OFFSET = 150 -- the island zone's centre, out from the plot's centre (away from the ring's middle)

-- The raft (RaftService): a grid of tiles on two decks
Constants.TILE = 6 -- a tile is 6 x 6 studs
Constants.GRID = 14 -- the grid's anchor: tile (6.5, 6.5) is the plot's centre (old saves use these numbers)
Constants.GRID_MIN, Constants.GRID_MAX = -34, 47 -- how far a raft may spread: 82 x 82 floors, as big as anyone builds
Constants.DECK_Y = 2 -- the first deck's top surface, above the water
Constants.DECK_HEIGHT = 7.5 -- the second deck sits this much higher
Constants.TILE_HP = 100
Constants.START_TILES = { { 6, 6 }, { 7, 6 }, { 6, 7 }, { 7, 7 } } -- a 2 x 2 driftwood platform in the grid's middle (§5.1)
Constants.MIN_TILES = 4 -- you can't demolish below the platform you started with
Constants.MAX_TILES_BY_TIER = { 12, 24, 40, 60, 100, 196 } -- (no longer a limit: rafts grow as big as you like)
Constants.CARGO_BY_TIER = { 16, 24, 32, 40, 52, 64 } -- inventory slots
Constants.REPAIR_PER_HIT = 25 -- a hammer's hit on a damaged tile (costs 1 wood)
Constants.DEMOLISH_REFUND = 1 -- the share of a piece's cost you get back when you take it off: all of it

-- Survivors (PlayerService)
Constants.HOTBAR = 9
-- the last three are blueprint slots for good (QUICK_SLOTS): always a build shortcut, never an item; CHANGE picks
-- another blueprint for one. Items use the first ITEM_SLOTS.
Constants.QUICK_SLOTS = 3
Constants.ITEM_SLOTS = Constants.HOTBAR - Constants.QUICK_SLOTS
Constants.DEFAULT_PINS = { [7] = "floor", [8] = "net", [9] = "wall" }
Constants.MAX_HP = 100
Constants.REGEN_DELAY = 4 -- seconds after a hit before the raft heals you
Constants.SPAWN_PROTECT = 3
Constants.WALK_SPEED = 16
Constants.SPRINT_BONUS = 9 -- running (hold Shift, click the left stick, or RUN): this much faster than your walk
Constants.SPRINT_FOV = 8 -- ...and the camera widens this many degrees while you run
Constants.JUMP_HEIGHT = 7.5
Constants.HEAL_PER_SECOND_ON_RAFT = 1.5 -- resting on your raft (never on an island or in the water)
Constants.RESPAWN_SECONDS = 4
Constants.DEATH_LOSS = 0.5 -- the share of this voyage's finds that float off as a lost bag where you fell (§6)
Constants.LOST_BAG_SECONDS = 120

-- Collecting (OceanService): debris drifts through every plot
Constants.DEBRIS_MAX = 30 -- afloat round one raft at a time (the far ones included)
Constants.DEBRIS_EVERY = 3.2 -- seconds between new pieces (fewer while the raft is sailing: the lanes bring more)
Constants.DEBRIS_SPEED = 2.4 -- studs a second, with the current
Constants.DEBRIS_FROM = 260 -- spawned this far upstream of the raft's centre (far enough to see it coming)
Constants.DEBRIS_SPREAD = 30 -- across the current
Constants.DEBRIS_LIFETIME = 240
Constants.HOOK_FLIGHT = 0.6 -- seconds from ACT until the piece starts coming in (the cast's wind-up and the bobber's
-- flight: FxController times the bobber to land then), then it pulls in at the hook's speed
Constants.NET_EVERY = 7 -- a net checks for debris this often
Constants.NET_LANE_SHARE = 0.5 -- with nets aboard, this share of the debris drifts down a net's lane
Constants.NET_RANGE = 24 -- a net reaches this far round its tile (big: nothing has to drift exactly into it)
Constants.SWEEP_RADIUS = 10 -- a cast's line catches everything this close to it on the way back in
Constants.NET_HOLD = 6 -- things a net holds before it's full (its prompt, or a storage box on the raft, empties it)
Constants.NET_HOLD_SALVAGE = 10 -- the salvage net holds more
Constants.NET_BOX_EVERY = 45 -- with a storage box, a net empties into your bag when full, or this long after its
-- first catch (till then you can see the catch in it)
Constants.OFFLINE_NET_MAX = 30 -- with a storage box, each net catches this many things at most while you're away
Constants.AWAY_CARD_AFTER = 600 -- away this long (seconds): the welcome-back card says what the nets caught
Constants.OFFLINE_NET_EVERY = 90 -- while you're away, each net catches one thing this often, until it's full
Constants.FISH_BITE = { 3, 8 } -- seconds until a bite
Constants.FISH_WINDOW = 1.1 -- seconds to reel once it bites

-- Voyages (VoyageService): the raft stays in its plot; the island comes to it
Constants.VOYAGE_SECONDS_PER_DISTANCE = 32 -- at speed 1 (a sail doubles it, an engine more)
Constants.VOYAGE_MIN_SECONDS = 14
Constants.ISLAND_STAY_NO_ANCHOR = 150 -- seconds ashore before the current carries an unanchored raft home
Constants.ISLAND_STAY_WARNING = 30 -- the warning this long before it does
Constants.VOYAGE_EVENT_EVERY = { 14, 24 } -- seconds between events while sailing
Constants.HOME_EVENT_SHARE = 0.5 -- the trip home has half as many
Constants.DANGER_BY_TIER = { 1, 1, 2, 3, 5, 5 } -- the most dangerous waters each raft tier may sail to (§5.4: a Floating Fortress can face the Trench; the tooth it brings back makes the Legendary Vessel)
Constants.STORM_SECONDS = 26
Constants.STORM_HIT_EVERY = 5
Constants.STORM_TILE_DAMAGE = 22
Constants.SHARK_BITE = 16 -- to a tile
Constants.SHARK_BITE_EVERY = 6
Constants.SERPENT_BITE = 30
Constants.DEBRIS_LANE_PIECES = 14
Constants.LEVIATHAN_HP = 2400
Constants.LEVIATHAN_ENRAGE = 0.35 -- share of health left when it goes wild

-- Islands (IslandBuilder, IslandService)
Constants.ISLAND_RADIUS = 46
Constants.ISLAND_GAP = 3 -- an island's beach rises this far from the raft's outer edge: a hop ashore, not a swim
Constants.TREE_HP = 30
Constants.ROCK_HP = 40
Constants.CONTAINER_SEARCH = 0.8 -- seconds to hold

-- Combat (CombatService)
Constants.MELEE_SLACK = 3
Constants.ARC_SLACK = 20
Constants.HARPOON_SPEED = 90
Constants.TURRET_RANGE = 40
Constants.TURRET_EVERY = 2.5
Constants.TURRET_DAMAGE = 22
Constants.SPIKE_DAMAGE = 12 -- to a sea creature that bites a spiked tile

-- The day (WeatherService): a calm cycle; storms come with voyages (and now and then at home)
Constants.DAY_SECONDS = 360
Constants.NIGHT_SECONDS = 150
Constants.HOME_STORM_EVERY = { 420, 900 }

-- Visiting (VisitService)
Constants.VISIT_DEFAULT = "friends" -- "friends" | "anyone" | "nobody"
Constants.ROWBOAT_SECONDS = 2.2 -- the fade while the rowboat takes you over

-- Progression (ProgressService)
Constants.LEVEL_XP = 120
Constants.LEVEL_XP_GROWTH = 50
Constants.XP = {
	debris = 1,
	build = 3,
	craft = 4,
	voyage = 30, -- + danger x 20 when you get home
	discovery = 40, -- the first time: an island, a wreck, a creature, a fish, an artifact, an event
	repeatFind = 6,
	creature = { small = 3, medium = 8, heavy = 20, boss = 400 },
	fish = 2,
	rareFish = 10,
	tier = 100, -- x the new tier
	guide = { cast = 10, tile = 15, bench = 20, craft = 10, crate = 15, net = 15, helm = 10, island = 20, home = 30 }, -- the guide's firsts (§4)
	cap = 4000, -- from one session
}
Constants.RESEARCH_PER_ARTIFACT = { common = 10, uncommon = 25, rare = 60, epic = 120, legendary = 300 }

-- Leaderboards (LeaderboardService, friends first)
Constants.BOARD_REFRESH = 300
Constants.BOARD_FRIENDS_MAX = 30
Constants.BOARD_TOP = 10

-- Friends' servers (JoinService)
Constants.FRIEND_RETRY_SECONDS = 20
Constants.FRIEND_RETRY_TRIES = 6

-- The guide (TutorialService, §4)
Constants.EARLY_BOOST = 2 -- a starter raft hauls in this many times as much from every piece (quick first wins)
Constants.EARLY_BOOST_TIER = 1 -- ...while the raft is this tier or lower
Constants.GUIDE_DEBRIS = 3 -- pieces to reel in before the first build (the net comes right after)
Constants.GUIDE_START_DEBRIS = 6 -- pieces floating within reach the moment a new player arrives (§4: 0:00-0:30)
Constants.GUIDE_CRATE_DISTANCE = 16 -- the guide's crate drifts in this close (right beside the raft, slowly)
Constants.GUIDE_CRATE_RETRY = 3 -- seconds: another one the moment it's gone, until you've got one

-- Feedback (FeedbackService): the "Do you like the game?" card
Constants.FEEDBACK_AFTER = 480
-- Server events (EventService): one every SERVER_EVENT_EVERY seconds (the first SERVER_EVENT_FIRST after the server
-- starts), in turn: a supply rain, a golden tide, a bottle bloom
Constants.SERVER_EVENT_EVERY = 900
Constants.SERVER_EVENT_FIRST = 300
Constants.EVENT_CRATES = 3 -- supply crates per raft in a supply rain
Constants.EVENT_BOTTLES = 3 -- bottles per raft in a bottle bloom
-- The weekly board (LeaderboardService "week"): pieces built since Monday 00:00 UTC; last week's top three get
-- supply crates (WEEKLY_PRIZES) the next time they play
Constants.WEEKLY_PRIZES = { 5, 3, 2 }
-- The daily favourite raft (VoteService): asked once a day after this much play, a few rafts at a time
Constants.VOTE_AFTER = 900
Constants.VOTE_CHOICES = 3
Constants.VOTE_STORE = "EV_Vote_"
Constants.VOTE_PRIZE_XP = 500
Constants.FEEDBACK_ASK_EVERY = 3 * 24 * 3600
Constants.FEEDBACK_MAX_ASKS = 3
Constants.FEEDBACK_MAX_CHARS = 140
Constants.DISLIKE_REASONS = {
	{ key = "slow", text = "🐌 Building takes too long" },
	{ key = "lost", text = "🧭 Didn't know what to do" },
	{ key = "empty", text = "😴 Not much to find" },
	{ key = "lag", text = "🐢 Laggy" },
	{ key = "hard", text = "💀 The sea is too dangerous" },
	{ key = "confusing", text = "🤔 Don't get it" },
}
Constants.NOTIFY_AFTER = 900
Constants.NOTIFY_ASK_EVERY = 7 * 24 * 3600

-- Anti-cheat (AntiCheatService)
Constants.AC_WINDOW = 1.5
Constants.AC_SPEED_SLACK = 1.35
Constants.AC_SPEED_EXTRA = 6
Constants.AC_AIR_HEIGHT = 14
Constants.AC_AIR_SECONDS = 4
Constants.AC_DECAY_SECONDS = 45
Constants.AC_KICK_STRIKES = 12
Constants.AC_SPAM_DROPS = 80
Constants.AC_SPAM_WINDOW = 10
Constants.ADMINS = { [11787294097] = true }

-- The game log (GameLogService) and analytics (AnalyticsService): the studio's shared Supabase functions
Constants.GAME_LOG_URL = "https://kvedatksqkcsgivntskb.supabase.co/functions/v1/roblox-game-log"
Constants.GAME_LOG_IN_STUDIO = false
Constants.GAME_LOG_FLUSH_SECONDS = 5
Constants.GAME_LOG_ACTIVITY = true -- every event of every player to the Discord log too, a line each
Constants.GAME_LOG_ACTIVITY_SECONDS = 15 -- how often those lines go (in as few messages as fit)
Constants.ANALYTICS_URL = "https://kvedatksqkcsgivntskb.supabase.co/functions/v1/roblox-analytics"
Constants.ANALYTICS_GAME = "ra8"
Constants.ANALYTICS_FLUSH_SECONDS = 10
Constants.ANALYTICS_SNAPSHOT_SECONDS = 30
Constants.ANALYTICS_IDLE_SECONDS = 45

-- Sound (AudioController): the studio's shared effects (the account's own uploads) and Roblox library tracks; a
-- recording made for the game can replace any of them by changing the id here.
Constants.SOUNDS = {
	pickup = "rbxassetid://118634876996683",
	craft = "rbxassetid://105104330819150",
	built = "rbxassetid://106516156393061",
	levelup = "rbxassetid://106516156393061",
	chop = "rbxassetid://105444665436909",
	mine = "rbxassetid://105444665436909",
	hook = "rbxassetid://95486565209148",
	hit = "rbxassetid://138148057831879",
	splash = "rbxassetid://105444665436909",
	open = "rbxassetid://96391581866585",
	eat = "rbxassetid://83557110540525",
	discover = "rbxassetid://115604569854725",
	notify = "rbxassetid://115604569854725",
	horn = "rbxassetid://88832672717864",
	roar = "rbxassetid://109983444504089",
	bite = "rbxassetid://138148057831879",
	win = "rbxassetid://119933432712786",
	thunder = "rbxassetid://88832672717864",
}
Constants.SOUND_VOLUME = { roar = 0.9, thunder = 0.8, horn = 0.7, win = 0.8, hook = 0.45 }
Constants.SOUND_SPEED = { splash = 0.8, bite = 0.9 }
Constants.MUSIC = {
	day = { "rbxassetid://1837879082", "rbxassetid://1840684208" },
	sailing = { "rbxassetid://1838457617" },
	island = { "rbxassetid://1837879082" },
	storm = { "rbxassetid://1837849285" },
	boss = { "rbxassetid://1837849285" },
	night = { "rbxassetid://1840684208" },
}
Constants.MUSIC_VOLUME = { day = 0.16, sailing = 0.2, island = 0.18, storm = 0.24, boss = 0.28, night = 0.12 }

return Constants
