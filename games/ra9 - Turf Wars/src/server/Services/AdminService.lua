--[[
Admins (server/Admins.lua: Constants.ADMINS by user id). They get a red ADMIN tag (StatusService) and an ADMIN
button that opens the admin panel (AdminController). Everything the panel asks for comes in as Net "Admin" (action,
target, value) and is checked here, on the server: anyone else is refused, every time. Every action an admin takes
fires AdminService.Used (admin, action, detail), so a log service can post it (to Discord, say).

The server list: every server writes a line about itself (players, map, phase, score) to a MemoryStore sorted
map every ADMIN_HEARTBEAT seconds; a line expires after ADMIN_SERVER_TTL, so dead servers drop off on their own.
JOIN teleports the admin there with teleport data { adminSpectate = true }, and they arrive spectating.

Spectating: watching unseen. No body, no team, not counted in the match (MatchService:People, BotService), never
hit, never in the kill feed or the results. The client flies a free camera or follows a player
(SpectateController). Leaving puts them on a team the normal way (or in a bot's place, if a player was alone).

Actions (target: a player's UserId; value: what the action needs):
  state | servers                       the panel's data (AdminState)
  join (jobId)                          spectate another server
  spectate (on) | invisible (on)        yourself
  unlockall                             every cosmetic, for yourself
  tutorial                              play the first-minute tutorial yourself, from the start
  end ("red" | "blue" | "draw")         the match ends now, the normal way
  skip ("fight" | "build") | restart | map (key) | bots (on) | freeze (on) | announce (text)
  team (target, "red" | "blue") | kill | heal (heal, or respawn if down) | kick (target, reason)
  mvp | vip (target, "1h" | "1d" | "7d" | "30d" | "forever" | "remove") | shards (target, n) | tiers (target, n)
  cosmetic (target, key) | resetshop (target: 4 new daily shop items for them) | goto | bring

  AdminService:Do(admin, action, target, value) -> ok, message, extra
  AdminService:Heartbeat()        this server's line in the list
  AdminService:Servers() -> list  every live server's line (yields)
  AdminService.Used (admin, action, detail)
]]
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local TextService = game:GetService("TextService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Locker = require(ReplicatedStorage.Shared.Data.Locker)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Net = require(ReplicatedStorage.Shared.Net)
local Season = require(ReplicatedStorage.Shared.Data.Season)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Admins = require(script.Parent.Parent.Admins)
local Notify = require(script.Parent.Parent.Notify)

local AdminService = {
	Name = "AdminService",
	Dependencies = {
		"PlayerDataService",
		"TeamService",
		"CombatService",
		"MatchService",
		"BotService",
		"EconomyService",
		"SeasonService",
		"ProgressService",
		"StatusService",
		"ShopService",
	},
	Used = Signal.new("AdminService.Used"), -- (admin, action, detail)
}

local data, teams, combat, match, bots, economy, season, progress, status, shop
local registryRef -- (TutorialService is looked up when used: optional, never a dependency)
local serverMap
local jobId = game.JobId ~= "" and game.JobId or "studio"

local VIP = {} -- [key] = { seconds | true, label }
for _, v in Constants.ADMIN_VIP do
	VIP[v[1]] = { v[2], v[3] }
end

local function say(player, text, kind)
	Net.fire(player, "Toast", text, kind or "good")
end

local function find(userId)
	return type(userId) == "number" and Players:GetPlayerByUserId(userId) or nil
end

local function rootOf(player)
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function playing()
	local p = match:Phase()
	return p == "build" or p == "fight"
end

-- Text an admin typed, through Roblox's filter (nil if it's empty or the filter can't be reached)
local function filtered(admin, text)
	if type(text) ~= "string" then
		return nil
	end
	text = string.sub(string.gsub(text, "^%s+", ""), 1, 120)
	text = string.gsub(text, "%s+$", "")
	if text == "" then
		return nil
	end
	local ok, out = pcall(function()
		return TextService:FilterStringAsync(text, admin.UserId):GetNonChatStringForBroadcastAsync()
	end)
	return ok and type(out) == "string" and out or nil
end

local function whole(n, lo, hi)
	return type(n) == "number" and n == n and n >= lo and n <= hi and math.floor(n) == n
end

-- The server list -----------------------------------------------------------------------------------------------
function AdminService:Info()
	local names = {}
	local people = match:People()
	for i, p in people do
		if i <= 40 then
			table.insert(names, p.DisplayName)
		end
	end
	local m = Maps.get(match:MapKey())
	return {
		jobId = jobId,
		players = #people,
		names = names,
		map = m and m.name or "?",
		phase = match:Phase(),
		red = teams:Count("red"),
		blue = teams:Count("blue"),
		frontline = math.floor(match:Frontline()),
		at = os.time(),
	}
end

function AdminService:Heartbeat()
	if not serverMap then
		return false
	end
	local info = self:Info()
	return pcall(function()
		if info.players == 0 then
			serverMap:RemoveAsync(jobId) -- (an empty server isn't worth a visit)
		else
			serverMap:SetAsync(jobId, info, Constants.ADMIN_SERVER_TTL)
		end
	end)
end

function AdminService:Servers()
	local out = {}
	if serverMap then
		local ok, items = pcall(function()
			return serverMap:GetRangeAsync(Enum.SortDirection.Ascending, 100)
		end)
		local oldest = os.time() - Constants.ADMIN_SERVER_TTL
		for _, item in ok and items or {} do
			local v = type(item) == "table" and item.value
			if type(v) == "table" and type(v.jobId) == "string" and (v.at or 0) >= oldest then
				v.here = v.jobId == jobId
				table.insert(out, v)
			end
		end
	end
	table.sort(out, function(a, b)
		return (a.players or 0) > (b.players or 0)
	end)
	return out
end

-- The panel's data, for one admin (servers: the list, when it was asked for; extra: anything else to send)
function AdminService:Push(admin, servers, extra)
	local list = {}
	for _, p in Players:GetPlayers() do
		table.insert(list, {
			id = p.UserId,
			name = p.DisplayName,
			user = p.Name,
			team = teams:Team(p),
			alive = combat:Alive(p),
			admin = Admins.isAdmin(p),
			spectating = Admins.spectating(p),
			vip = p:GetAttribute("VIP") == true,
		})
	end
	local state = {
		jobId = jobId,
		players = list,
		map = match:MapKey(),
		phase = match:Phase(),
		bots = bots:Enabled(),
		frozen = match:Frozen(),
		spectating = Admins.spectating(admin),
		invisible = admin:GetAttribute("Invisible") == true,
		servers = servers,
	}
	for k, v in extra or {} do
		state[k] = v
	end
	Net.fire(admin, "AdminState", state)
end

-- Spectating and invisible ---------------------------------------------------------------------------------------
local function hide(d)
	if d:IsA("BasePart") or d:IsA("Decal") then
		d.Transparency = 1
	elseif d:IsA("BillboardGui") then
		d.Enabled = false
	end
end

local function hideAll(character)
	for _, d in character:GetDescendants() do
		hide(d)
	end
end

function AdminService:SetSpectate(admin, on)
	on = on == true
	if Admins.spectating(admin) == on then
		return false
	end
	Admins.setSpectating(admin, on)
	if on then
		combat:Remove(admin)
		teams:Clear(admin)
		match:Leave(admin)
		local c = admin.Character
		if c then
			admin.Character = nil
			c:Destroy()
		end
	else
		bots:Takeover(admin) -- (alone with bots, another player: they get a bot's place)
		match:Join(admin)
	end
	bots:Ensure()
	return true
end

function AdminService:SetInvisible(admin, on)
	admin:SetAttribute("Invisible", on == true or nil)
	local c = admin.Character
	if on and c then
		hideAll(c)
	elseif not on and c and combat:Alive(admin) and playing() then
		match:Spawn(admin) -- (a fresh body, seen again)
	end
	status:Refresh(admin)
	return true
end

local function watch(player)
	if not Admins.isAdmin(player) then
		return
	end
	player:SetAttribute("Admin", true)
	Admins.spectating(player) -- (settled now: arrived from the server list?)
	player.CharacterAdded:Connect(function(c)
		c.DescendantAdded:Connect(function(d)
			if player:GetAttribute("Invisible") == true then
				hide(d)
			end
		end)
		task.defer(function()
			if player:GetAttribute("Invisible") == true then
				hideAll(c)
			end
		end)
	end)
end

-- The actions ---------------------------------------------------------------------------------------------------
-- Each returns ok, message (what the admin's toast says), detail (for the log), extra (more for the panel).
local ACTIONS = {}

ACTIONS.state = function(self, admin)
	self:Push(admin)
	return true
end

ACTIONS.servers = function(self, admin)
	self:Heartbeat()
	self:Push(admin, self:Servers())
	return true
end

ACTIONS.join = function(_, admin, _, id)
	if type(id) ~= "string" or #id == 0 or #id > 80 then
		return false, "Pick a server."
	end
	if id == jobId then
		return false, "You're on that server."
	end
	local ok, err = pcall(function()
		local options = Instance.new("TeleportOptions")
		options.ServerInstanceId = id
		options:SetTeleportData({ adminSpectate = true })
		TeleportService:TeleportAsync(game.PlaceId, { admin }, options)
	end)
	if not ok then
		warn("[AdminService] teleport failed: " .. tostring(err))
		return false, "Could not go there."
	end
	return true, "Going there...", id
end

ACTIONS.spectate = function(self, admin, _, on)
	if not self:SetSpectate(admin, on == true) then
		return false, on and "You're spectating." or "You're playing."
	end
	return true, on and "Spectating. Nobody can see you." or "You're back in the game!", tostring(on == true)
end

ACTIONS.invisible = function(self, admin, _, on)
	if Admins.spectating(admin) then
		return false, "You're spectating already."
	end
	self:SetInvisible(admin, on == true)
	return true, on and "You're invisible." or "You can be seen again.", tostring(on == true)
end

-- Play the first-minute tutorial yourself (as a new player would see it), from the start
ACTIONS.tutorial = function(_, admin)
	local tutorial = registryRef and registryRef.TutorialService
	if not tutorial or not Constants.TUTORIAL then
		return false, "The tutorial is off in this build."
	end
	if Admins.spectating(admin) then
		return false, "Stop spectating first."
	end
	tutorial:_onClient(admin, "replay")
	return true, "Tutorial started!"
end

ACTIONS.unlockall = function(_, admin)
	local n = 0
	for _, key in Locker.every(Season.at(math.floor(workspace:GetServerTimeNow())).n) do
		if economy:Give(admin, key) then
			n += 1
		end
	end
	progress:Push(admin)
	return true, `Unlocked {n} things!`, tostring(n)
end

-- the match
ACTIONS["end"] = function(_, _, _, winner)
	if winner ~= "red" and winner ~= "blue" and winner ~= "draw" then
		return false, "Pick a winner."
	end
	if not match:Victory(winner) then
		return false, "No match to end right now."
	end
	return true, winner == "draw" and "Ended in a draw." or `{Constants.TEAM_NAME[winner]} wins!`, winner
end

ACTIONS.skip = function(_, _, _, to)
	if not match:SkipTo(to) then
		return false, "Can't skip now."
	end
	return true, `Skipped to {string.upper(to)}.`, to
end

ACTIONS.restart = function()
	match:NewMatch(match:MapKey())
	return true, "New match!"
end

ACTIONS.map = function(_, _, _, key)
	local m = Maps.get(key)
	if not m then
		return false, "No such map."
	end
	match:NewMatch(m.key)
	return true, `New match on {m.name}!`, m.key
end

ACTIONS.bots = function(_, _, _, on)
	bots:SetEnabled(on == true)
	return true, on and "Bots on." or "Bots off.", tostring(on == true)
end

ACTIONS.freeze = function(_, _, _, on)
	if not match:Freeze(on == true) then
		return false, on and "Can't stop the clock now." or "The clock is running."
	end
	return true, on and "Clock stopped." or "Clock running.", tostring(on == true)
end

ACTIONS.announce = function(_, admin, _, text)
	local clean = filtered(admin, text)
	if not clean then
		return false, "Type a message first."
	end
	Notify.all(clean, "admin")
	return true, "Sent!", clean
end

-- one player (target)
local PLAYER_ACTIONS = {}

PLAYER_ACTIONS.team = function(_, _, target, team)
	if team ~= "red" and team ~= "blue" then
		return false, "Pick a team."
	end
	if Admins.spectating(target) then
		return false, "They're spectating."
	end
	teams:Set(target, team)
	if playing() then
		match:Spawn(target) -- (a fresh body on the new side)
	end
	return true, `{target.DisplayName} is on {Constants.TEAM_NAME[team]}.`, team
end

PLAYER_ACTIONS.kill = function(_, _, target)
	if not combat:Alive(target) then
		return false, "They're down already."
	end
	combat:Kill(target, nil, { kind = "admin" })
	return true, `Knocked out {target.DisplayName}.`
end

PLAYER_ACTIONS.heal = function(_, _, target)
	if Admins.spectating(target) then
		return false, "They're spectating."
	end
	if combat:Heal(target) then
		return true, `Healed {target.DisplayName}.`
	end
	if not playing() then
		return false, "They come back next match."
	end
	match:Spawn(target)
	return true, `{target.DisplayName} is back.`
end

PLAYER_ACTIONS.kick = function(_, admin, target, reason)
	if target == admin or Admins.isAdmin(target) then
		return false, "You can't kick an admin."
	end
	local why = filtered(admin, reason)
	target:Kick(why and `An admin removed you: {why}` or "An admin removed you from this server.")
	return true, `Kicked {target.DisplayName}.`, why or ""
end

PLAYER_ACTIONS.mvp = function(_, _, target)
	status:SetMvp(target)
	progress:AddMvp(target)
	Notify.all(`{target.DisplayName} is MVP!`, "status", { icon = "👑" })
	return true, `{target.DisplayName} is MVP.`
end

PLAYER_ACTIONS.vip = function(_, _, target, key)
	if key == "remove" then
		progress:SetVip(target, false)
		return true, `Took VIP from {target.DisplayName}.`, "remove"
	end
	local v = VIP[key]
	if not v then
		return false, "Pick how long."
	end
	progress:SetVip(target, v[1])
	Notify.all(`{target.DisplayName} got VIP!`, "status", { icon = "⭐" })
	return true, `{target.DisplayName} got VIP ({v[2]}).`, key
end

PLAYER_ACTIONS.shards = function(_, _, target, n)
	if not whole(n, 1, 100000) then
		return false, "Pick an amount."
	end
	economy:Add(target, n, "admin")
	progress:Push(target)
	Net.fire(target, "Toast", `+{n} ◆ from an admin!`, "good")
	return true, `Gave {target.DisplayName} {n} ◆.`, tostring(n)
end

PLAYER_ACTIONS.tiers = function(_, _, target, n)
	if not whole(n, 1, Season.TIERS) then
		return false, "Pick how many tiers."
	end
	local got = season:AddTiers(target, n)
	progress:Push(target)
	return true, `Gave {target.DisplayName} {got} pass tiers.`, tostring(got)
end

PLAYER_ACTIONS.cosmetic = function(_, _, target, key)
	local it = Cosmetics.get(key)
	local p = data:Get(target)
	if not it or not p then
		return false, "No such thing."
	end
	economy:Give(target, it.key)
	p.equipped[it.kind] = it.key
	progress.card(target, it.key, "A GIFT!", `{it.name} · {Cosmetics.KIND_NAME[it.kind]}`)
	progress:Push(target)
	return true, `Gave {target.DisplayName} {it.name}.`, it.key
end

PLAYER_ACTIONS.resetshop = function(_, _, target)
	shop:Reroll(target)
	progress:Push(target) -- (an open shop redraws)
	Net.fire(target, "Toast", "New items in your shop!", "good")
	return true, `New shop items for {target.DisplayName}.`
end

PLAYER_ACTIONS["goto"] = function(_, admin, target)
	if Admins.spectating(admin) then
		return true, `Watching {target.DisplayName}.`, nil, { follow = target.UserId } -- (the camera follows them)
	end
	local a, b = rootOf(admin), rootOf(target)
	if not a or not b then
		return false, "No body to move."
	end
	a.CFrame = b.CFrame * CFrame.new(0, 0, 5)
	return true, `Went to {target.DisplayName}.`
end

PLAYER_ACTIONS.bring = function(_, admin, target)
	local a, b = rootOf(admin), rootOf(target)
	if not a or not b then
		return false, "No body to move."
	end
	b.CFrame = a.CFrame * CFrame.new(0, 0, -5)
	target:SetAttribute("AcGrace", os.clock() + 2) -- (our teleport: the anti-cheat lets it go)
	return true, `Brought {target.DisplayName}.`
end

function AdminService:Do(admin, action, target, value)
	if not Admins.isAdmin(admin) or type(action) ~= "string" then
		return false, "Admins only."
	end
	local ok, message, detail, extra
	local fn = ACTIONS[action]
	if fn then
		ok, message, detail, extra = fn(self, admin, target, value)
	elseif PLAYER_ACTIONS[action] then
		local who = find(target)
		if not who then
			return false, "That player left."
		end
		ok, message, detail, extra = PLAYER_ACTIONS[action](self, admin, who, value)
		detail = `{who.Name} ({who.UserId}){detail and detail ~= "" and (" " .. detail) or ""}`
	else
		return false, "Unknown action."
	end
	if ok and action ~= "state" and action ~= "servers" then
		print(`[Admin] {admin.Name} {action} {detail or ""}`)
		self.Used:Fire(admin, action, detail or "")
	end
	return ok, message, extra
end

function AdminService:Init(registry)
	registryRef = registry
	data = registry.PlayerDataService
	teams = registry.TeamService
	combat = registry.CombatService
	match = registry.MatchService
	bots = registry.BotService
	economy = registry.EconomyService
	season = registry.SeasonService
	progress = registry.ProgressService
	status = registry.StatusService
	shop = registry.ShopService
	local ok, m = pcall(function()
		return MemoryStoreService:GetSortedMap(Constants.ADMIN_SERVER_MAP)
	end)
	serverMap = ok and m or nil
	Net.on("Admin", function(player, action, target, value)
		if not Admins.isAdmin(player) then
			return -- (never trust the client: no answer either)
		end
		local done, message, extra = self:Do(player, action, target, value)
		if message then
			say(player, message, done and "good" or "bad")
		end
		if action ~= "state" and action ~= "servers" and player.Parent then
			self:Push(player, nil, extra)
		end
	end)
	pcall(function()
		TeleportService.TeleportInitFailed:Connect(function(player)
			if Admins.isAdmin(player) then
				say(player, "Could not go there. Try again.", "bad")
			end
		end)
	end)
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	pcall(function()
		game:BindToClose(function()
			if serverMap then
				pcall(serverMap.RemoveAsync, serverMap, jobId)
			end
		end)
	end)
end

function AdminService:OnPlayerReady(player)
	if not Admins.isAdmin(player) then
		return
	end
	data:WhenClientReady(player, function()
		self:Push(player)
		if Admins.spectating(player) then
			say(player, "Spectating. Nobody can see you.", "good")
		end
	end)
end

function AdminService:Start()
	local lastVip = os.clock()
	while true do
		self:Heartbeat()
		task.wait(Constants.ADMIN_HEARTBEAT)
		-- (VIP an admin gave for a while runs out: the tag and halo go)
		if os.clock() - lastVip >= 60 then
			lastVip = os.clock()
			for _, p in Players:GetPlayers() do
				local prof = data:Get(p)
				if
					prof
					and p:GetAttribute("VIP") == true
					and (prof.vipUntil or 0) > 0
					and prof.vipUntil <= os.time()
				then
					progress:Push(p)
				end
			end
		end
	end
end

return AdminService
