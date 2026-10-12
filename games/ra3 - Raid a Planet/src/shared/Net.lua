-- Typed remote layer. The server creates one RemoteEvent per name under
-- ReplicatedStorage.Net. Every client→server event has a per-player rate limit; handlers validate arguments.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

-- Client → server, with the maximum calls per second allowed per player.
Net.ClientEvents = {
	Ready = 1,
	Blast = 10, -- (targetId) fire the equipped blaster at a bug or boss
	Equip = 4, -- (uid) hold this blaster
	Sell = 2, -- (uid) sell a blaster for coins
	PowerUp = 5, -- (uid) level a blaster up with coins
	Forge = 2, -- (tierKey, planetKey) start a forge
	ClaimForge = 3, -- (slot) take the finished blaster out
	FinishNow = 2, -- (slot) open the Finish Forge Now purchase
	Travel = 2, -- (planetKey | "HUB") teleport to a planet you've unlocked (also what the pads do)
	Purchase = 2, -- (kind "pass"|"product", key) the server opens Roblox's purchase prompt
}

-- Server → client.
Net.ServerEvents = {
	"Profile", -- partial profile view
	"Toast", -- text, kind ("info" | "good" | "bad")
	"Alert", -- big centre message: text, color
	"Popup", -- worldPosition, text, color
	"Announce", -- text, color: a banner across the top
	"Sfx", -- soundName, worldPosition?
	"Beam", -- fromPosition, toPosition, color: a blaster shot everyone sees
	"Down", -- seconds: you were hit by a boss ball
	"Event", -- { kind = "raid", at = serverTime } the raid countdown
	"Owned", -- { passKey = true } after a purchase
	"Forged", -- a finished blaster record (the reveal)
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
