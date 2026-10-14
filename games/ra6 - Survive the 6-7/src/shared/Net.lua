-- Typed remote layer. The server creates one RemoteEvent per name under ReplicatedStorage.Net (the monster
-- snapshot, sent 8 times a second, goes out as an UnreliableRemoteEvent: a late one is simply replaced by the
-- next). Every client→server event has a per-player rate limit (master plan §14: rate-limit remote events);
-- handlers validate their arguments, and the server decides every result.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

-- Client → server, with the maximum calls per second allowed per player.
Net.ClientEvents = {
	Ready = 1,
	Act = 10, -- (slot, aim: Vector3, mode: "main" | "special") swing, chop, shoot or use what you hold (CombatService)
	Select = 8, -- (slot) hold a hotbar slot (InventoryService)
	Dodge = 3, -- (dir: Vector3) a dodge with i-frames (SurvivorService)
	Sprint = 4, -- (on) sprint while you have stamina
	Move = 8, -- (from, to) move or swap inventory slots ("h1".."h6", "b1".., "armor" | "pack" | "charm")
	Drop = 4, -- (slot, count?) drop on the ground for a teammate
	Use = 4, -- (slot) eat, drink, bandage, read the map
	Craft = 4, -- (recipeId) at a station (CraftService)
	Store = 8, -- ("put", slot, count?) | ("take", itemKey, count?) | ("all") the camp's storage chest (CampService)
	Camp = 4, -- ("upgrade") at the Camp Board | ("fuel", count) feed the fire | ("repair", slotKey, index)
	Vote = 2, -- ("difficulty", n) at the standing stones | ("bell", on) ring the bell to call the night early
	Throw = 4, -- (slot, target: Vector3) a flare, a firecracker, a smelly sandwich
	Place = 3, -- (slot, position: Vector3) set a trap
	Loadout = 2, -- (kitKey) your starting kit for the next run (ProgressService)
	Perk = 2, -- (index, perkKey | false)
	Wear = 3, -- (slot, key) a look or a title
	Emote = 1, -- (key) the 6-7, a wave...
	Ping = 2, -- (key, position?) a quick word for the team (PingService)
	Settings = 2, -- (key, value)
	Mash = 12, -- break out of a goo cocoon from inside (BossService)
	Board = 2, -- (category) the friends-first leaderboards (LeaderboardService)
	Friends = 1, -- ({ { userId, jobId }, ... }) friends online in this game: how is each one's run going?
	JoinFriend = 1, -- (userId) join a friend's server (JoinService)
	FriendAction = 1, -- ("retry" | "cancel" | "private" | "newrun" | "rejoin")
	SkipTutorial = 1,
	Viewed = 2, -- ("inventory" | "craft" | "progress" | "bestiary" | ...) a panel was opened
	Feedback = 1, -- (like, text?, reasons?) the "Do you like the game?" card (FeedbackService)
	Notify = 2, -- ("shown" | "on" | "off" | "status", canAsk?) Experience Notifications opt-in results
	Analytics = 4, -- (kind, data) device info, button taps, frame rate, window focus (AnalyticsService)
}

-- Server → client.
Net.ServerEvents = {
	"Profile", -- partial profile view (level, xp, perks, kits, mastery, collection, achievements, looks, settings)
	"Run", -- the run view (RunService:View): phase, day, ends, difficulty, event, roster, locked, votes...
	"Me", -- this survivor: { status, hp, maxHp, stamina, buffs, armor, stats, downedUntil, ghostUntil }
	"Inv", -- your inventory: { slots = { [slotId] = { key, n, fuel? } }, selected, capacity }
	"Team", -- { { userId, name, hp, maxHp, status, pos }, ... } twice a second
	"Camp", -- the camp: { tier, fuel, fuelMax, structures, board, storage? }
	"Mobs", -- a packed snapshot of every monster (MonsterService.pack): positions, kinds, health, state
	"Mob", -- { kind = "spawn" | "die" | "tell" | "hit" | "stagger" | "say", id, ... } one monster event
	"Boss", -- Mega Kermy's bar: { hp, maxHp, phase, state } or false
	"Objective", -- { primary = { text, progress?, target? }, optional = { ... } }
	"Toast", -- text, kind ("info" | "good" | "bad")
	"Alert", -- big centre message: text, color, seconds?
	"Callout", -- text, kind: "Night is coming!", "Kermy is hunting!"
	"Popup", -- worldPosition, text, color: floating "+3 🪵"
	"Fx", -- kind, data: chop, dust, sparks, projectile, ring, line, trap, flare, heal...
	"Act", -- { by = userId, item, mode }: everyone animates a survivor's swing
	"Hurt", -- { amount, by?, dir? } you were hit (flash, shake, damage number)
	"Knock", -- direction, force: push your own character (knockback)
	"Dash", -- direction, distance, seconds: move your own character (dodge, lunge thrust)
	"Tutorial", -- { step, text, target } or false
	"Unlock", -- { kind = "level" | "achievement" | "mastery" | "discovery" | "trophy" | "page" | "look", ... }
	"Results", -- the end of a run: { won, reason, nights, seconds, team, you, rewards, unlocks }
	"Ping", -- { key, text, icon, position, from }
	"Friends", -- { [userId] = { phase, day, players, max, here } }: friends' runs (JoinService)
	"FriendResult", -- { kind = "teleporting" | "full" | "waiting" | "failed" | "here" | "gone" | "rejoin", ... }
	"Board", -- { category, friends = { rows }, global = { rows }, you }
	"Storage", -- the storage chest's contents (while you're near it)
	"Ask", -- { kind = "feedback" | "thanks" | "notify" }: FeedbackService cards
	"Sfx", -- soundName, worldPosition?: a sound effect (AudioController)
	"Fade", -- seconds, text?: a short black fade
}

-- Sent often and only the newest matters: unreliable (may drop, never queues up behind the others).
local UNRELIABLE = { Mobs = true, Team = true }

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
