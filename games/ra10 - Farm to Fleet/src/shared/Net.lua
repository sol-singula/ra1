-- Typed remote layer. The server creates one RemoteEvent per name under ReplicatedStorage.Net. Every client→server
-- event has a per-player rate limit; handlers validate their arguments, and the server decides every result: a
-- harvest is only a request (which soil tile); whether it's ripe, what it pays and what grows next are the server's.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

-- Client → server, with the maximum calls per second allowed per player.
Net.ClientEvents = {
	Ready = 1, -- () the client's UI is listening (PlayerDataService)
	Settings = 2, -- (key, value)
	Analytics = 4, -- (kind, data) device info, frame rate (AnalyticsService)
	Farm = 12, -- ("plant", plotIndex, cropKey) | ("harvest", plotIndex) | ("water", plotIndex) (FarmService)
	Buy = 6, -- ("pad", key) a buy-pad stepped on is server-side; this is the panel's buy (UpgradeService)
	Sell = 4, -- () sell what you carry at the stand (FarmService)
	Animal = 6, -- ("feed", penKey) | ("upgrade", penKey) | ("collect", penKey) (AnimalService)
	Order = 6, -- ("fill", orderId) | ("refresh") (OrderService)
	Guide = 6, -- ("step", key) | ("skip") the guide's own reports (GuideService)
	Daily = 2, -- ("claim") the day's calendar reward (DailyService)
	Drive = 10, -- ("enter", vehicleId) | ("leave") | ("move", throttle, steer) a forklift you drive (VehicleService)
}

-- Server → client.
Net.ServerEvents = {
	"Profile", -- partial profile view (PlayerDataService:Push)
	"Toast", -- (text, kind) a one-line message
	"Earned", -- { amount, why, total, currency } a payout flying into the counter
	"Farm", -- the plot's state: soil tiles, crops, timers (FarmService)
	"Plot", -- { index, stage, owner } which plot is yours, and the street's (PlotService)
	"Guide", -- { step, text, target, done, of } the next thing to do (GuideService)
	"Animal", -- pens, levels, boosts, hunger (AnimalService)
	"Orders", -- the order board (OrderService)
	"Flow", -- the warehouse's four stations, the bottleneck, the stock (WarehouseService)
	"Vehicles", -- { id, kind, route, t0, seconds } moves for every client to animate (VehicleService)
	"Daily", -- the calendar, the streak, what's ready (DailyService)
	"Away", -- { seconds, earned } the "while you were gone" card (OfflineService)
}

-- Sent often and only the newest matters: unreliable (may drop, never queues up behind the others).
local UNRELIABLE = {}

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
	local burst = math.max(rate, 1) -- (a rate under one a second, like Play's 1 in 2 s, still allows the first call)
	if not b then
		b = { tokens = burst, last = now }
		perPlayer[name] = b
	end
	b.tokens = math.min(burst, b.tokens + (now - b.last) * rate)
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
-- Several services may listen to one event (PlaceService and LobbyService both hear "Play"): the rate limit and
-- the practice's divert are checked once per call, then every handler runs, each on its own (one failing never
-- stops the others).
local handlers = {} -- [name] = { fn, ... }
function Net.on(name, handler)
	assert(Net.ClientEvents[name], `not a client event: {name}`)
	if handlers[name] then
		table.insert(handlers[name], handler)
		return
	end
	handlers[name] = { handler }
	remote(name).OnServerEvent:Connect(function(player, ...)
		if not allow(player, name) then
			if dropHook then
				pcall(dropHook, player, name)
			end
			return
		end
		-- (a player in their private practice: TutorialService takes their shots and building, the match never sees them)
		if Net.divert and Net.divert(player, name, ...) then
			return
		end
		for _, fn in handlers[name] do
			local ok, err = xpcall(fn, debug.traceback, player, ...)
			if not ok then
				warn(`[Net {name}] {err}`)
			end
		end
	end)
end

-- The private practice (TutorialService): while a player is hushed, nothing from the match reaches them (the kill
-- feed, the match's state and music cues, banners, toasts, invites, gift, hook, feedback and shop cards); only what
-- is theirs alone (Net.PRIVATE) and what the tutorial sends through Net.direct.
--   Net.hush(player, on)   Net.hushed(player)   Net.direct(player, name, ...)   Net.divert = fn(player, name, ...) -> took it
Net.PRIVATE = { Tutorial = true, Profile = true, Earned = true, Leaderboards = true, AdminState = true }
local hushed = {} -- [player] = true
local anyHushed = false
Net.divert = nil

function Net.hush(player, on)
	hushed[player] = on == true or nil
	anyHushed = next(hushed) ~= nil
end

function Net.hushed(player)
	return hushed[player] == true
end

function Net.direct(player, name, ...)
	if typeof(player) == "Instance" then
		remote(name):FireClient(player, ...)
	end
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
	if typeof(player) ~= "Instance" then
		return -- (a bot: BotService's stand-ins have no client)
	end
	if hushed[player] and not Net.PRIVATE[name] then
		return -- (in their private practice: Net.hush)
	end
	remote(name):FireClient(player, ...)
end

function Net.fireAll(name, ...)
	if not anyHushed or Net.PRIVATE[name] then
		remote(name):FireAllClients(...)
		return
	end
	local re = remote(name)
	for _, p in game:GetService("Players"):GetPlayers() do
		if not hushed[p] then
			re:FireClient(p, ...)
		end
	end
end

-- Client API -----------------------------------------------------------------------------------------------
function Net.send(name, ...)
	remote(name):FireServer(...)
end

function Net.listen(name, fn)
	return remote(name).OnClientEvent:Connect(fn)
end

return Net
