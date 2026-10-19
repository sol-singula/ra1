-- Typed remote layer. The server creates one RemoteEvent per name under ReplicatedStorage.Net. Every client→server
-- event has a per-player rate limit; handlers validate their arguments, and the server decides every result: a
-- harvest is only a request (which tile); whether it's ripe, what it pays and whether the storage has room are the
-- server's (master plan §14: the server validates every transaction).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

-- Client → server, with the maximum calls per second allowed per player.
Net.ClientEvents = {
	Ready = 1, -- () the client's UI is listening (PlayerDataService)
	Settings = 2, -- (key, value)
	Analytics = 4, -- (kind, data) device info, frame rate, the opening skipped (AnalyticsService)
	Crop = 15, -- ("plant", tileId) | ("harvest", tileId) | ("choose", cropKey) | ("plantAll") (CropService)
	Buy = 6, -- (upgradeKey) buy an upgrade (UpgradeService)
	Task = 4, -- ("skip") | ("seen", key) the guidance's own reports (TaskService)
	Boost = 3, -- ("contribute", amount) | ("open") the town's shared boost meter (BoostService)
	Shop = 4, -- ("open") | ("buy", key) (ShopService)
	Market = 3, -- ("open") | ("deliver", orderId) the town's market board (MarketService)
	Visit = 3, -- ("go", territoryIndex) | ("home") (TerritoryService)
	Admin = 2, -- ("reset", name) | ("give", name, cash) the admin panel (AdminService)
}

-- Server → client.
Net.ServerEvents = {
	"Profile", -- partial profile view (PlayerDataService:Push)
	"Toast", -- (text, kind) a one-line message
	"Earned", -- { amount, why, at = {x,y,z} } cash earned, where (floating coins, the counter)
	"Territory", -- { index, stage, owner, spawn } yours (TerritoryService)
	"Crops", -- the tiles: { chosen, auto, tiles = { [id] = { crop, at } }, fields } (CropService)
	"Harvested", -- { tileId, crop, n, by } a tile cleared (the burst) (CropService)
	"Business", -- { stage, storage, cap, demand, service, sales, queue, dispatch, ... } (BusinessService)
	"Sale", -- { n, cash } customers bought (BusinessService): the client walks them in
	"Truck", -- { n, cash, index } a truck left the dock with a load (BusinessService)
	"Machines", -- { kind, rate, tiles = {...} } the harvester's route (AutomationService)
	"Upgrades", -- { owned, recommended, affordable } (UpgradeService)
	"Task", -- { primary = { key, text, target, kind }, goals = {...}, milestone = {...} } (TaskService)
	"Boost", -- { active, kind, until, meter, cost } the town's boost (BoostService)
	"Shop", -- the products, passes, prices, what's owned (ShopService)
	"Market", -- the board's orders (MarketService)
	"Away", -- { seconds, earned, grown } the welcome-back card (OfflineService)
	"Camera", -- { kind, at, look, seconds } a cinematic cue (CameraService → CameraController)
	"Leaderboards", -- the town's boards (LeaderboardService)
	"Town", -- every territory's numbers (TerritoryService)
	"AdminState", -- { admin = true } this client is an admin (AdminService)
	"Animals", -- [key] = { level, fed, happy, fedLeft, petIn, boost, word } the pens (AnimalService)
	"Golden", -- { tile, cash, x, z } a golden crop was tapped (CropService)
}

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

local function allow(player, name)
	local rate = Net.ClientEvents[name]
	local perPlayer = buckets[player]
	if not perPlayer then
		perPlayer = {}
		buckets[player] = perPlayer
	end
	local b = perPlayer[name]
	local now = os.clock()
	local burst = math.max(rate, 1)
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
		return
	end
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
