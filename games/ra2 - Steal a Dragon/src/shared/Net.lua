-- Typed remote layer. The server creates one RemoteEvent per name under
-- ReplicatedStorage.Net. Every client→server event has a per-player rate limit; handlers validate arguments.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

-- Client → server, with the maximum calls per second allowed per player.
Net.ClientEvents = {
	Ready = 1,
	Bonk = 4,
	Lock = 2,
	BuySpeed = 4,
	BuyWeapon = 2,
	ClaimDaily = 1,
	ClaimOffline = 1,
	SkipTutorial = 1,
	Purchase = 2, -- (kind "pass"|"product", key, target?) the server opens Roblox's purchase prompt
	BuySkin = 2, -- (skinKey) coin skins are bought, Robux skins open their purchase prompt
	EquipSkin = 2, -- (skinKey)
	BuyCastleSkin = 2, -- (key) buy (Robux) or wear an owned castle skin
	EquipCastleSkin = 2, -- (key | "NONE")
	Admin = 5, -- (action, a?, b?) admin panel (AdminService checks the player is an admin)
	Feedback = 1, -- (like: boolean, text?: string) the "Do you like the game?" card (FeedbackService)
	Notify = 2, -- ("shown" | "on" | "off" | "status", canAsk?) Experience Notifications opt-in results
	Analytics = 4, -- (kind, data) device info, button taps, frame rate, window focus (AnalyticsService)
}

-- Server → client.
Net.ServerEvents = {
	"Profile", -- partial profile view
	"Toast", -- text, kind ("info" | "good" | "bad")
	"Alert", -- big centre message: text, color, targetInstance?
	"Popup", -- worldPosition, text, color
	"Bonked", -- stunSeconds
	"Event", -- { kind = "legend", at = serverTime } | { kind = "luck", untilTime, by }
	"Offline", -- { coins, seconds } welcome-back gift
	"Tutorial", -- { step, total, text, target } or false
	"Owned", -- { passKey = true } after a purchase
	"Announce", -- text, color: a banner across the top (someone joined, someone took a top-3 spot)
	"Ask", -- { kind = "feedback" | "thanks" | "vote" | "notify", like? }: FeedbackService cards
	"Offer", -- { key, title, text, icon, price, target? }: a Robux offer card (Buy / No thanks)
	"ArenaKO", -- { by = name, respawn = seconds } you got bonked in the Bonk Arena
	"Swing", -- attacker: play their bonk swing (BonkController)
	"Sfx", -- soundName, worldPosition?: a sound effect (AudioController); with a position it plays there in 3D
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
