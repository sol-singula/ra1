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
	Shoot = 12, -- (origin, direction, shotId) release: an arrow (or the TNT, thrown) from about your head, the way you aim
	Swing = 6, -- (direction) a slash with the blade: the server finds who it reaches
	Reload = 2, -- () a magazine weapon's reload (none has one now)
	Build = 8, -- (structureKey, cx, cz, rot) place a structure in the build phase (BuildService)
	Demolish = 4, -- (structureId) take back one of yours in the build phase (refunded)
	Sprint = 6, -- (on)
	Slide = 3, -- () a slide while running (MoveService checks the cooldown)
	Crouch = 6, -- (on) crouched or not (MoveService: everyone sees you lower; the anti-cheat expects you slower)
	Settings = 2, -- (key, value) flips, sensitivity, equipped cosmetics
	Analytics = 4, -- (kind, data) device info, frame rate (AnalyticsService)
	Buy = 4, -- ("item", key) | ("bundle") | ("robux", productKey | "starter") (ShopService)
	Claim = 6, -- (tier, "f" | "p") a tier of the Turf Pass
	Feedback = 6, -- ("enjoy", true) | ("enjoy", false, { reason keys }) the "Are you liking the game?" card | ("like", "ok" | "later")
	Party = 4, -- ("invite", userId) | ("accept") | ("decline") | ("leave") | ("kick", userId) | ("move", "new" | "fuller")
	Admin = 8, -- (action, target?, value?) the admin panel; refused unless you're an admin (AdminService)
	Tutorial = 6, -- ("step", name, how?) | ("done") | ("skip", where?) | ("replay") the first-minute guide
	Top = 2, -- () the leaderboards, please (LeaderboardService answers with "Leaderboards")
	Active = 1, -- () the player touched a key, the mouse or the screen lately (AfkService: not idle)
	InvitePromo = 4, -- ("sent", recipients) | ("later") the invite-a-friend card (InviteService)
}

-- Server → client.
Net.ServerEvents = {
	"Profile", -- { wins, streak, best, stats, equipped, owned, shards, vip, season, settings } (ProgressService:View)
	"Match", -- { phase, ends, map, mapName, frontline, loseRed, loseBlue, push, red, blue, matchId, next? }
	"Me", -- { team, alive, weapon, ammo, budget, budgetMax, protected }
	"Arrow", -- { id, by, team, weapon, origin, velocity, t } an arrow everyone draws (the shooter's own is predicted)
	"ArrowEnd", -- { id, pos, kind = "player" | "structure" | "world" } where it stopped
	"Bomb", -- { id, by, team, origin, velocity, at, shotId } a TNT thrown: everyone draws its lob (Formulas.lobAt)
	"Blast", -- { id, pos, team, by, ground, radius, core } it went off: the explosion everyone sees and hears
	"Swing", -- { by, hit, pos, dir } someone slashed (their blade swings for everyone: SwingController) | { by, whiff }
	-- (to the swinger: their slash cut no one)
	"Hit", -- { damage, head, kill, victim, melee?, pos? } you hit someone (the hit marker; a blade hit's spot);
	-- { parry, clash, melee, pos, knock } two blades met (no knockout: you're thrown back by knock)
	"Hurt", -- { amount, from, by? } you were hit (from: the shooter's position, for the damage indicator)
	"Threat", -- { from, by } an enemy arrow just passed close to you (from: where it was shot; HitDirectionController)
	"Shield", -- { kind = "on" | "off" | "break", by, pos?, attacker?, seconds?, why? } the comeback shield (CombatService)
	"Kill", -- { killer, victim, killerTeam, weapon, head, push, assist, effect, pos } the kill feed, the kill effect;
	-- killerPos, dist and cam = { origin, velocity, t, impact } (an arrow's flight) for the victim's kill cam
	"Structure", -- { kind = "built" | "damaged" | "destroyed", id, key, team, hp, max }; destroyed adds min, max, rot,
	-- emblem and blast = { pos, power } (what broke it: a TNT 1, an arrow less, nil for lost turf): the debris
	-- (DebrisController)
	"Toast", -- text, kind ("info" | "good" | "bad")
	"Earned", -- { amount, why = "kill" | "headshot" | "match" | ..., total } Shards just paid: the +N that flies to the counter
	"Alert", -- big centre message: text, color, seconds?
	"Announce", -- { text, kind, color?, icon?, seconds? } a banner for everyone or one player (server/Notify.lua)
	"Results", -- { winner, rows = { { userId, name, team, kills, deaths, assists, built } }, mvp, you, next }
	"Unlock", -- { step = { win, kind, name, big }, wins }
	"Sfx", -- soundName, worldPosition?
	"Ask", -- { kind = "enjoy" | "like" } a card for a winner (FeedbackService)
	"Gift", -- { key, kind, name, rarity, count, of } a free cosmetic at the match's end | { nudge = true }
	-- | { offer, key } a first-buy offer | { firstShop = true, shards } the first match's shop instead (GiftService)
	"PartyState", -- { id, leader, max, members = { { userId, name } } } or false: your party (PartyService)
	"PartyInvite", -- { from, name, kind = "invite" | "friend", seconds } or { cancel = true }: the invite card
	"AdminState", -- { players, servers?, map, phase, bots, frozen, spectating, invisible, jobId } (admins only)
	"Tutorial", -- { kind = "start", boost, replay } | { kind = "built" } the first-minute guide (TutorialService)
	"Hook", -- { kind = "step" | "progress" | "stepDone" | "complete" | "welcome", ... } after it (HookService)
	"Leaderboards", -- { boards, server, you, ok, at, every } the top players, all time and here (LeaderboardService)
	"InvitePromo", -- { why, pool = { effect keys } } the invite-a-friend card | { pulse = true } nudge the button
	"InviteReward", -- { key, pool = { effect keys }, friend } a friend joined from your invite: the effect you won
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
		-- (a player in their private practice: TutorialService takes their shots and building, the match never sees them)
		if Net.divert and Net.divert(player, name, ...) then
			return
		end
		local ok, err = xpcall(handler, debug.traceback, player, ...)
		if not ok then
			warn(`[Net {name}] {err}`)
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
