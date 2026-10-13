-- Typed remote layer. The server creates one RemoteEvent per name under
-- ReplicatedStorage.Net. Every client→server event has a per-player rate limit; handlers validate arguments.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

-- Client → server, with the maximum calls per second allowed per player.
Net.ClientEvents = {
	Ready = 1,
	Fire = 8, -- (origin, direction, clientServerTime) a shot; the server decides if it popped anyone
	Play = 2, -- jump into the round that's on
	Leave = 2, -- back to the lobby (your round score stays)
	Vote = 3, -- (mapKey) vote for the next map in the lobby
	EquipRifle = 3, -- (rifleKey)
	BuyRifle = 2, -- (rifleKey) with coins, once you're the level for it
	SwapRifle = 3, -- swap to your second rifle mid-round (Extra Loadout pass)
	EquipSkin = 4, -- (rifleKey, skinUid | nil)
	EquipStyle = 4, -- (kind "effect"|"emote"|"crosshair"|"nameColor", id)
	BuyShop = 3, -- (index) an item in today's Daily Shop
	BuyStyle = 3, -- (kind "crosshair"|"nameColor", id)
	OpenCrate = 2, -- (crateKey)
	ClaimDaily = 1, -- the daily gift
	RerollQuest = 1, -- (index) swap a daily quest for coins
	ClaimSeason = 4, -- (tier, track "free"|"pass")
	Purchase = 2, -- (kind "pass"|"product", key) the server opens Roblox's purchase prompt
	ListStall = 2, -- (stallIndex, skinUid, coins) put a skin on a Trade Plaza stall
	Unlist = 2, -- (stallIndex)
	BuyStall = 2, -- (stallIndex)
}

-- Server → client.
Net.ServerEvents = {
	"Profile", -- partial profile view
	"Toast", -- text, kind ("info" | "good" | "bad")
	"Alert", -- big centre message: text, color
	"Announce", -- text, color: a banner across the top
	"Sfx", -- soundName, worldPosition?
	"Shot", -- from, to, color, shooterUserId, tracer: a shot everyone sees
	"Pop", -- position, effectId: someone popped into bits here
	"Hit", -- headshot: your shot popped someone (hit marker)
	"Popped", -- { by, userId, level, rifle, skin, effect, streak, at = serverTime back } you were popped
	"Round", -- { state, endsAt, map, size, mode, minPlayers } the round loop
	"Score", -- { { userId, name, pops, deaths, robot } ... } sorted, the current round
	"Feed", -- { killer, victim, headshot, killerColor, victimColor, skin, tag } one kill feed line
	"Streak", -- name, text, color: someone hit a streak
	"Podium", -- { { name, userId, pops } x3 } the round's top 3
	"Crate", -- { crate, skin } a crate opened (the reveal)
	"Owned", -- { passKey = true } after a purchase
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
