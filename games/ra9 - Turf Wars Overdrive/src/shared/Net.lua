-- Typed remote layer. The server creates one RemoteEvent per name under ReplicatedStorage.Net. Every client→server
-- event has a per-player rate limit; handlers validate their arguments, and the server decides every result: a
-- shot is only a request (where you were, which way you aimed); the arrow, the hit, the damage and the kill are the
-- server's (CombatService).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

-- Client → server, with the maximum calls per second allowed per player.
Net.ClientEvents = {
	Ready = 1,
	Equip = 4, -- (weaponKey) pick a bow (CombatService)
	Draw = 10, -- (on) start / stop drawing the bow (the charge is timed on the server from this)
	Shoot = 12, -- (origin, direction, shotId) release: an arrow from about where your head is, the way you aim
	Reload = 2, -- () the crossbow's magazine
	Build = 8, -- (structureKey, cx, cz, rot) place a structure in the build phase (BuildService)
	Demolish = 4, -- (structureId) take back one of yours in the build phase (refunded)
	Sprint = 6, -- (on)
	Slide = 3, -- () a slide while running (MoveService checks the cooldown)
	Settings = 2, -- (key, value) flips, sensitivity, equipped cosmetics
	Analytics = 4, -- (kind, data) device info, frame rate (AnalyticsService)
	Feedback = 2, -- ("enjoy", yes) the "Are you liking the game?" card | ("like", "ok" | "later") the like card
}

-- Server → client.
Net.ServerEvents = {
	"Profile", -- { wins, streak, best, stats, unlocked, equipped, settings }
	"Match", -- { phase, ends, map, mapName, frontline, loseRed, loseBlue, push, red, blue, matchId, next? }
	"Me", -- { team, alive, weapon, ammo, budget, budgetMax, protected }
	"Arrow", -- { id, by, team, weapon, origin, velocity, t } an arrow everyone draws (the shooter's own is predicted)
	"ArrowEnd", -- { id, pos, kind = "player" | "structure" | "world" } where it stopped
	"Hit", -- { damage, head, kill, victim } you hit someone (the hit marker)
	"Hurt", -- { amount, from } you were hit (from: the shooter's position, for the damage indicator)
	"Kill", -- { killer, victim, killerTeam, weapon, head, push, assist } the kill feed (everyone)
	"Structure", -- { kind = "built" | "damaged" | "destroyed", id, key, team, hp, max }
	"Toast", -- text, kind ("info" | "good" | "bad")
	"Alert", -- big centre message: text, color, seconds?
	"Results", -- { winner, rows = { { userId, name, team, kills, deaths, assists, built } }, mvp, you, next }
	"Unlock", -- { step = { win, kind, name, big }, wins }
	"Sfx", -- soundName, worldPosition?
	"Ask", -- { kind = "enjoy" | "like" } a card for a winner (FeedbackService)
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
