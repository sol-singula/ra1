-- Typed remote layer. The server creates one RemoteEvent per name under ReplicatedStorage.Net (the creature
-- snapshot, sent 8 times a second, goes out as an UnreliableRemoteEvent: a late one is simply replaced by the
-- next). Every client→server event has a per-player rate limit; handlers validate their arguments, and the server
-- decides every result. Prompts on the raft and the islands (the helm, the stations, the bunk, the nets, the
-- containers, the lanterns and the totems) go through ProximityPrompts, not remotes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

-- Client → server, with the maximum calls per second allowed per player.
Net.ClientEvents = {
	Ready = 1,
	Act = 10, -- (aim: Vector3?, targetId?) use what you hold: cast, swing, chop, hammer (ActionService)
	Reel = 10, -- () the fishing rod's bite: reel in
	Select = 8, -- (slot) hold a hotbar slot (InventoryService)
	Move = 8, -- (from, to) move or swap inventory slots ("h1".."h6", "b1"..)
	Use = 4, -- (slot) eat, read a chart, open a supply crate, learn a blueprint
	Drop = 4, -- (slot, count?) drop into the water (it floats a while)
	Build = 6, -- (pieceKey, gx, gz, level, rot?) place a piece on your raft (RaftService); rot: the edge it sits on
	Demolish = 4, -- (pieceId) take a piece off your raft (half the cost back)
	Paint = 3, -- (kind, key) the raft's colours: sails, banners, flags, the deck
	Craft = 4, -- (recipeId) at a station (CraftService)
	Research = 3, -- (slot) feed an artifact to the Research Station (CraftService)
	Sail = 2, -- (destinationKey) set sail from the helm | ("home") sail home (VoyageService)
	Visit = 3, -- (userId) look at someone's raft (VisitService): a copy comes back as "Visiting"
	VisitList = 3, -- ("here" | "friends" | "top") who you can visit
	Emote = 1, -- (key) wave, cheer, dance
	Settings = 2, -- (key, value) music / shake / fx, or title / flag (ProgressService)
	Board = 2, -- (category) the friends-first leaderboards (LeaderboardService)
	Friends = 1, -- ({ { userId, jobId }, ... }) friends online in this game: where is each one?
	JoinFriend = 1, -- (userId) join a friend's server (JoinService)
	FriendAction = 1, -- ("retry" | "cancel" | "private")
	Pin = 2, -- (pieceKey) put a build shortcut for that piece in your hotbar (InventoryService)
	Mode = 1, -- ("world" | "public") the start menu's choice (ModeService)
	GuideAction = 4, -- ("hold_rod") the guide card's button: put the best rod in your hand (TutorialService)
	Viewed = 2, -- ("build" | "craft" | "map" | "journal" | ...) a panel was opened
	Feedback = 1, -- (like, text?, reasons?) the "Do you like the game?" card (FeedbackService)
	Notify = 2, -- ("shown" | "on" | "off" | "status", canAsk?) Experience Notifications opt-in results
	Analytics = 4, -- (kind, data) device info, button taps, frame rate, window focus (AnalyticsService)
}

-- Server → client.
Net.ServerEvents = {
	"Profile", -- partial profile view (level, xp, title, colours, blueprints, research, achievements, journal, settings)
	"Me", -- this player: { hp, maxHp, buffs, where, plot, visiting }
	"Inv", -- your inventory: { slots = { [slotId] = { key, n } }, selected, capacity, tool }
	"Raft", -- the raft you're on: { owner, plot, tier, tiles, pieces = { ... }, colours, speed, cargo, needs, broken }
	"Voyage", -- the plot's voyage: { state = docked | sailing | island | home, dest, started, ends, event }
	"Creatures", -- a packed snapshot of the creatures near you (CreatureService.pack)
	"Creature", -- { kind = "spawn" | "die" | "tell" | "hit" | "surface" | "dive", id, ... } one creature event
	"Island", -- the island beside the plot: { key, name, containers, nodes, puzzle, landmark } or false
	"Fish", -- { state = "cast" | "bite" | "caught" | "away" | "off", fish?, window? } the rod (OceanService)
	"Weather", -- { phase = "day" | "night", storm, ends, clock }
	"Toast", -- text, kind ("info" | "good" | "bad")
	"Alert", -- big centre message: text, color, seconds?
	"Callout", -- text, kind: "Land ho!", "Sharks!"
	"Popup", -- worldPosition, text, color: floating "+1 🌳"
	"Fx", -- kind, data: cast, splash, chop, sparks, built, storm, bite, harpoon, discover...
	"Act", -- { by = userId, item, mode, target? }: everyone animates a player's action
	"Hurt", -- { amount, by?, dir? } you were hit
	"Tutorial", -- { step, text, target, ... } or false
	"Unlock", -- { kind = "level" | "achievement" | "blueprint" | "discovery" | "tier" | "research" | "colour", ... }
	"Journal", -- { entries } the discovery journal's changed page
	"Friends", -- { [userId] = { tier, voyage, players, max, here } }: friends' servers (JoinService)
	"FriendResult", -- { kind = "teleporting" | "full" | "waiting" | "failed" | "here", ... }
	"Board", -- { category, friends = { rows }, global = { rows }, you }
	"Ask", -- { kind = "feedback" | "thanks" | "notify" }: FeedbackService cards
	"Sfx", -- soundName, worldPosition?: a sound effect (AudioController)
	"Fade", -- seconds, text?: a short black fade (the rowboat, waking up)
	"Lost", -- { pos, items }: where your lost bag floats after you went down
	"Visiting", -- { userId, name, tier, tierName, tiles, pieces, colours }: a raft to look at (VisitService)
	"VisitList", -- { kind, rows = { { userId, name, ... } } }: who you can visit
	"Menu", -- { close?, note?, travelling? }: the start menu (ModeService)
}

-- Sent often and only the newest matters: unreliable (may drop, never queues up behind the others).
local UNRELIABLE = { Creatures = true }

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

function Net.onDrop(fn)
	dropHook = fn
end

-- Watch every client → server event (analytics): fn(player, name, ...) runs for each one the client sends.
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
