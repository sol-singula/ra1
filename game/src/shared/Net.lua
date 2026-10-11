-- Typed remote layer (GDD §27.7, reduced). The server creates one RemoteEvent per name under
-- ReplicatedStorage.Net. Every client→server event has a per-player rate limit; handlers validate arguments.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

-- Client → server, with the maximum calls per second allowed per player.
Net.ClientEvents = {
	PantryPick = 4,
	ChopTap = 12,
	ChopCancel = 4,
	PourStop = 4,
	Attack = 10,
	Ability = 4,
	AllocateStat = 10,
	SetMenu = 2,
	UpgradeTier = 1,
	ChooseMutation = 1,
	Ready = 1,
	SkipTutorial = 1,
}

-- Server → client.
Net.ServerEvents = {
	"Profile", -- partial profile view
	"Toast", -- text, kind ("info" | "good" | "bad")
	"Tickets", -- list of open order tickets in the player's restaurant
	"Carry", -- list of carried item views
	"PantryOpen", -- list of ingredient ids the player may take
	"ChopStart", -- { startAt, period, taps, ingredientId }
	"ChopProgress", -- tapsDone, lastScore
	"ChopEnd",
	"PourStart", -- { startAt, seconds, recipeId }
	"PourEnd",
	"Projectile", -- from, to, flightSeconds, color
	"Popup", -- worldPosition, text, color
	"Cooldown", -- abilityId, seconds
	"ChooseMutation", -- list of mutation ids
	"KO", -- seconds
	"Served", -- summary of a finished customer
	"Tutorial", -- { step, total, text, target } or false when the tutorial is over
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
			return
		end
		local ok, err = xpcall(handler, debug.traceback, player, ...)
		if not ok then
			warn(`[Net {name}] {err}`)
		end
	end)
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
