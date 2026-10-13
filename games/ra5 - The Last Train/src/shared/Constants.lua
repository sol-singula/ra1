-- Every tunable number in one place. Times are seconds, distances are km (the line) or studs (the world).
local Constants = {}

Constants.GAME = "ra5"
Constants.MAX_PLAYERS = 20 -- one train, one expedition per server
Constants.CABINS = 20 -- 5 cabin cars x 4 compartments

-- The expedition (ExpeditionService). The station counts down once someone is here; then the train runs
-- Traveling -> Arriving -> Scavenging (with a 60 s and a 20 s warning) -> Departing, over and over, until the fuel
-- runs out (Ended), and then it goes back to the station for the next expedition.
Constants.LOBBY_SECONDS = 45 -- boarding at the station
Constants.DOORS_SECONDS = 6 -- "doors closing" before the train moves
Constants.DOORS_SHUT_AT = 4 -- the doors shut this long into departing (anyone still outside is left behind)
Constants.TRAVEL_SECONDS = 36
Constants.ARRIVE_SECONDS = 7 -- brakes; the stop appears for the last ARRIVE_REVEAL seconds
Constants.ARRIVE_REVEAL = 2
Constants.SCAVENGE_SECONDS = 150 -- the doors stay open this long (the Searchlight adds SEARCHLIGHT_BONUS)
Constants.WARNING_AT = 60 -- seconds left: first departure warning
Constants.FINAL_AT = 20 -- seconds left: final warning (horn, red lights)
Constants.END_SECONDS = 14 -- out of fuel: the train coasts, then it's back at the station

-- Distance and fuel. Every trip costs fuel; the cost grows a little every 10 km; the Engine Overhaul lowers it.
Constants.SEGMENT_KM = 2.5
Constants.START_FUEL = 4
Constants.FUEL_COST = { 2, 1.6, 1.3, 1.0 } -- per trip, by Engine Overhaul stage 0..3
Constants.FUEL_COST_GROWTH = 0.15 -- +15% per 10 km travelled
Constants.MILESTONE_KM = 10 -- a crew milestone every 10 km
Constants.MILESTONE_PARTS = 2 -- every crew member aboard gets this many parts at a milestone
Constants.FUEL_CANS_MIN = 3 -- fuel cans at a stop: 3, +1 per 3 players, up to 9
Constants.FUEL_CANS_MAX = 9
Constants.FUEL_PER_CAN = 1

-- Scavenging (ResourceService)
Constants.BAG_BASE = 12 -- items the field bag holds before the cabin crate and locker
Constants.COLLECT_HOLD = 1.1 -- seconds to hold on a pile (the Tool Rack makes it TOOLRACK_HOLD)
Constants.TOOLRACK_HOLD = 0.75
Constants.COLLECT_RANGE = 14 -- studs from the pile the server accepts
Constants.SALVAGE_SCRAP = 3 -- the workbench turns this much scrap into 1 part
Constants.SEARCHLIGHT_BONUS = 15 -- extra seconds at every stop with the Searchlight

-- Being left behind (RecoveryService)
Constants.RECOVERY_FUSES = 3
Constants.RECOVERY_PICKUP_WAIT = 45 -- seconds after the signal before the pickup (the Radio Mast makes it 5)
Constants.RECOVERY_PICKUP_FAST = 5

-- Records (RecordService). A full crew member was aboard for 2 stops or 5 minutes.
Constants.CREW_MIN_STOPS = 2
Constants.CREW_MIN_SECONDS = 300
Constants.HALL_RECORDS = 5
Constants.RECORD_STORE = "LT_Distance_v1" -- OrderedDataStore: expedition id -> distance x 10
Constants.RECORD_DETAILS = "LT_Records_v1" -- DataStore: expedition id -> the record

-- Friends (JoinService)
Constants.FRIEND_RETRY_SECONDS = 15
Constants.FRIEND_RETRY_TRIES = 8

-- Saving
Constants.AUTOSAVE_SECONDS = 120
Constants.PROFILE_STORE = "LT_Profiles_v1"

-- Analytics and the Discord game log (same Supabase pipeline as ra2; rows tagged game = 'ra5')
Constants.GAME_LOG_URL = "https://kvedatksqkcsgivntskb.supabase.co/functions/v1/roblox-game-log"
Constants.GAME_LOG_IN_STUDIO = false
Constants.GAME_LOG_FLUSH_SECONDS = 5
Constants.ANALYTICS_URL = "https://kvedatksqkcsgivntskb.supabase.co/functions/v1/roblox-analytics"
Constants.ANALYTICS_GAME = "ra5"
Constants.ANALYTICS_FLUSH_SECONDS = 10
Constants.ANALYTICS_SNAPSHOT_SECONDS = 30
Constants.ANALYTICS_IDLE_SECONDS = 45

-- "Do you like the game?" (FeedbackService)
Constants.FEEDBACK_AFTER = 600 -- after 10 minutes of play
Constants.FEEDBACK_MAX_ASKS = 2
Constants.FEEDBACK_ASK_EVERY = 3 * 86400
Constants.FEEDBACK_MAX_CHARS = 200
Constants.NOTIFY_AFTER = 1200 -- the update-alerts offer after 20 minutes
Constants.NOTIFY_ASK_EVERY = 3 * 86400
Constants.DISLIKE_REASONS = {
	{ "timer", "😰", "The train leaves too fast" },
	{ "lost", "🧭", "I got lost or left behind" },
	{ "slow", "🐌", "Upgrades take too long" },
	{ "lag", "🐢", "It's laggy" },
	{ "boring", "😴", "Not much to do" },
	{ "confusing", "🤔", "I don't get it" },
}

-- Movement
Constants.WALK_SPEED = 18

-- Admins (by Roblox user id): logged by the anti-cheat but never kicked
Constants.ADMINS = {
	[11787294097] = true, -- xthirtysix
}

-- Anti-cheat (AntiCheatService). Everything that matters is decided on the server already; this is about cheating
-- with your character (speed, teleporting to piles, flying) and spamming requests.
Constants.AC_KICK_STRIKES = 12 -- strikes that get you kicked
Constants.AC_DECAY_SECONDS = 20 -- one strike fades every this many seconds
Constants.AC_WINDOW = 2 -- movement is judged over this many seconds (smooths out lag)
Constants.AC_SPEED_SLACK = 1.6 -- allowed speed = walk speed x this ...
Constants.AC_SPEED_EXTRA = 14 -- ... + this (studs per second)
Constants.AC_AIR_SECONDS = 3 -- hovering high off the ground this long = flying
Constants.AC_AIR_HEIGHT = 24 -- studs above the ground that count as "high" (the tallest stairs are lower)
Constants.AC_SPAM_DROPS = 80 -- dropped (too fast) requests within AC_SPAM_WINDOW seconds = a strike
Constants.AC_SPAM_WINDOW = 10

return Constants
