-- Typed remote layer. The server creates one RemoteEvent per name under
-- ReplicatedStorage.Net. Every client→server event has a per-player rate limit; handlers validate arguments.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

-- Client → server, with the maximum calls per second allowed per player.
Net.ClientEvents = {
	Ready = 1,
	Build = 3, -- (itemKey, variant?) build or change a cabin item (CabinService)
	SetColor = 2, -- (colorKey) your cabin colour: door sign, blanket, curtains (CabinService)
	Deposit = 6, -- (upgradeKey, resource, amount) give materials to a train upgrade (TrainService)
	Salvage = 2, -- turn scrap into a part at your workbench (CabinService)
	GoCabin = 1, -- quick-travel to your cabin while aboard (ExpeditionService)
	GoCar = 1, -- (carKey) quick-travel to a car while aboard: "engine" | "crew"
	JoinFriend = 1, -- (userId) join a friend's train (JoinService)
	FriendAction = 1, -- ("retry" | "cancel" | "new") after "Train Full" (JoinService)
	SkipTutorial = 1,
	Viewed = 2, -- ("build" | "train" | "friends" | "hall") a board was opened (tutorial, analytics)
	Feedback = 1, -- (like, text?, reasons?) the "Do you like the game?" card (FeedbackService)
	Notify = 2, -- ("shown" | "on" | "off" | "status", canAsk?) Experience Notifications opt-in results
	Analytics = 4, -- (kind, data) device info, button taps, frame rate, window focus (AnalyticsService)
}

-- Server → client.
Net.ServerEvents = {
	"Profile", -- partial profile view (storage, cabin, blueprints, stats, tutorial...)
	"Expedition", -- the whole expedition state (ExpeditionService:View)
	"Toast", -- text, kind ("info" | "good" | "bad")
	"Announce", -- text, kind ("chime" | "warning" | "final" | "milestone"): the train's announcement
	"Alert", -- big centre message: text, color
	"Popup", -- worldPosition, text, color: floating "+1 🪵"
	"Bag", -- { items = { wood = n, ... }, count, cap } the unbanked field bag
	"Nodes", -- { reset = true } | { taken = { nodeId, ... } }: piles this player already took at this stop
	"Tutorial", -- { step, text, target } or false
	"Summary", -- the late-join card: { stop, phase, timeLeft, distance, nextMilestone, fuel, cost, goal }
	"FriendResult", -- { kind = "teleporting" | "full" | "failed" | "here" | "gone", name, tries?, wait? }
	"Recovery", -- { step, found, need, text } while left behind, or false
	"Fade", -- seconds, text?: a short black fade (teleports, arrivals)
	"Milestone", -- { km }: the crew passed a milestone
	"Ask", -- { kind = "feedback" | "thanks" | "notify" }: FeedbackService cards
	"Sfx", -- soundName, worldPosition?: a sound effect (AudioController)
}

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
			local re = Instance.new("RemoteEvent")
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
