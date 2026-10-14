-- Typed remote layer. The server creates one RemoteEvent per name under ReplicatedStorage.Net (the Horde
-- snapshot, sent 8 times a second, goes out as an UnreliableRemoteEvent: a late one is simply replaced by the
-- next). Every client→server event has a per-player rate limit; handlers validate arguments.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

-- Client → server, with the maximum calls per second allowed per player.
Net.ClientEvents = {
	Ready = 1,
	Act = 8, -- (slot, aim, target?) "main" | "special": swing, shoot, mine, hammer... (CombatService)
	Place = 3, -- (pieceKey, i, j, rot) put a blueprint on the build grid (BuildService)
	Cancel = 2, -- (pieceId) take back your own unfinished blueprint
	Upgrade = 2, -- (pieceId) start an upgrade on a built piece (thicker wall, iron gate...)
	Job = 2, -- (jobKey) pick a dwarf job (at a job board, before the plague) or a monster job (TeamService)
	Volunteer = 1, -- (on) ask to be one of the monsters when the plague comes
	Craft = 3, -- (item) at a forge, kitchen or potion table: "armor" | "weapon" | "food" | "potion" (CraftService)
	Use = 3, -- (item) eat food or drink a potion
	Ping = 2, -- (key, position) a quick ping for your team (PingService)
	Choice = 1, -- (index) the first choice card: gate, tower or wall (TutorialService)
	Buy = 2, -- (lookKey) buy a look with coins (ProgressService)
	Equip = 3, -- (slot, key) wear a look or a title
	ClaimGift = 1, -- the daily gift
	Emote = 1, -- (key)
	Settings = 2, -- (key, value) effects and screen shake on or off (saved)
	Friends = 1, -- ({ { userId, jobId }, ... }) friends online in this game: how is each one's match doing?
	JoinFriend = 1, -- (userId) join a friend's server (JoinService)
	FriendAction = 1, -- ("retry" | "cancel" | "private") after "Server Full"; or start a private match
	SkipTutorial = 1,
	Viewed = 2, -- ("shop" | "tasks" | "friends" | "jobs" | ...) a panel was opened (tutorial, analytics)
	Feedback = 1, -- (like, text?, reasons?) the "Do you like the game?" card (FeedbackService)
	Notify = 2, -- ("shown" | "on" | "off" | "status", canAsk?) Experience Notifications opt-in results
	Analytics = 4, -- (kind, data) device info, button taps, frame rate, window focus (AnalyticsService)
}

-- Server → client.
Net.ServerEvents = {
	"Profile", -- partial profile view (coins, level, looks, tasks, settings...)
	"Match", -- the match view (MatchService:View): phase, ends, number, shrine, stage, counts...
	"Me", -- this player in this match: { team, job, level, xp, gear, food, potions, volunteer, stats }
	"Bag", -- { stone, wood, gold, cap }
	"Shrines", -- { { health, state, near = { dwarves, monsters }, wards }, ... } 4 times a second
	"Horde", -- a packed snapshot of every NPC (HordeService.pack): positions, kinds, health
	"Npc", -- { kind = "spawn" | "die" | "hit" | "act", id, ... } one NPC event
	"Toast", -- text, kind ("info" | "good" | "bad")
	"Alert", -- big centre message: text, color, seconds?
	"Callout", -- text, kind: "Shrine 1 is falling!", "Gate is down!" (the voice of the match)
	"Popup", -- worldPosition, text, color: floating "+2 🪨"
	"Fx", -- kind, data: dust, sparks, crumble, projectile, goo, bomb, heal, shield... (FxController)
	"Act", -- { by = player or npc id, move, windup, dir }: everyone animates the move
	"Hurt", -- { amount, by?, crit? } you were hit (flash, shake, damage number)
	"Knock", -- direction, force: push your own character (knockback)
	"Dash", -- direction, distance, seconds: the Brute's charge (your own character)
	"Tutorial", -- { step, text, target } or false
	"Choice", -- { options = { ... } } the first choice card, or false
	"Picker", -- { jobs = { ... }, seconds } the monster job picker, or false
	"Results", -- the end of the match: { winner, held, beaten, mvps, rewards, ... }
	"Ping", -- { key, text, icon, position, from }
	"Friends", -- { [userId] = { phase, players, max, shrine, here } }: friends' matches (JoinService)
	"FriendResult", -- { kind = "teleporting" | "full" | "waiting" | "failed" | "here" | "gone", name, ... }
	"Leaderboard", -- { rows = { { name, userId, value } } } the longest holds
	"Ask", -- { kind = "feedback" | "thanks" | "notify" }: FeedbackService cards
	"Sfx", -- soundName, worldPosition?: a sound effect (AudioController)
	"Fade", -- seconds, text?: a short black fade
}

-- Sent often and only the newest matters: unreliable (may drop, never queues up behind the others).
local UNRELIABLE = { Horde = true }

local folder

local function getFolder()
	if folder then
		return folder
	end
	if RunService:IsServer() then
		folder = Instance.new("Folder")
		folder.Name = "Net"
		for name in Net.ClientEvents do
			local re = Instance.new("RemoteEvent")
			re.Name = name
			re.Parent = folder
		end
		for _, name in Net.ServerEvents do
			local re = Instance.new(UNRELIABLE[name] and "UnreliableRemoteEvent" or "RemoteEvent")
			re.Name = name
			re.Parent = folder
		end
		folder.Parent = ReplicatedStorage
	else
		folder = ReplicatedStorage:WaitForChild("Net")
	end
	return folder
end

local function remote(name)
	local re = getFolder():WaitForChild(name, 10)
	assert(re, `unknown remote {name}`)
	return re
end

-- Server API -----------------------------------------------------------------------------------------------
local buckets = {} -- [player][name] = { tokens, last }
local dropHook -- fn(player, name): a client sent an event faster than its rate (the anti-cheat counts these)

local function allow(player, name)
	local rate = Net.ClientEvents[name]
	local perPlayer = buckets[player]
	if not perPlayer then
		perPlayer = {}
		buckets[player] = perPlayer
	end
	local b = perPlayer[name]
	local now = os.clock()
	if not b then
		b = { tokens = rate, last = now }
		perPlayer[name] = b
	end
	b.tokens = math.min(rate, b.tokens + (now - b.last) * rate)
	b.last = now
	if b.tokens < 1 then
		return false
	end
	b.tokens -= 1
	return true
end

function Net.init()
	getFolder()
	if RunService:IsServer() then
		game:GetService("Players").PlayerRemoving:Connect(function(player)
			buckets[player] = nil
		end)
	end
end

-- Register a handler for a client → server event. Errors are caught and logged, never crash the server.
function Net.on(name, handler)
	assert(Net.ClientEvents[name], `not a client event: {name}`)
	remote(name).OnServerEvent:Connect(function(player, ...)
		if not allow(player, name) then
			if dropHook then
				pcall(dropHook, player, name)
			end
			return
		end
		local ok, err = xpcall(handler, debug.traceback, player, ...)
		if not ok then
			warn(`[Net {name}] {err}`)
		end
	end)
end

-- Called for every client event dropped for coming too fast (remote spam).
function Net.onDrop(fn)
	dropHook = fn
end

-- Watch every client → server event (analytics): fn(player, name, ...) runs for each one the client sends,
-- alongside the real handler. Never changes what the handlers do.
function Net.tap(fn)
	for name in Net.ClientEvents do
		remote(name).OnServerEvent:Connect(function(player, ...)
			pcall(fn, player, name, ...)
		end)
	end
end

function Net.fire(player, name, ...)
	remote(name):FireClient(player, ...)
end

function Net.fireAll(name, ...)
	remote(name):FireAllClients(...)
end

-- Client API -----------------------------------------------------------------------------------------------
function Net.send(name, ...)
	remote(name):FireServer(...)
end

function Net.listen(name, fn)
	return remote(name).OnClientEvent:Connect(fn)
end

return Net
