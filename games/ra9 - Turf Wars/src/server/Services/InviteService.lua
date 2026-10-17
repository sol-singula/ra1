--[[
Invite a friend, both get something: the HUD's INVITE button opens Roblox's invite prompt with LaunchData
"i:<your UserId>". When the friend joins from it, the friend gets the Buddy Trail (Data/Extras) and so do you,
each with a card. A share link works too (Roblox's ReferredByPlayerId).

  * The friend is credited once ever (profile.invite.by): rejoining from another invite gives nothing more.
  * You're credited once per friend (profile.invite.friends), and the trail is given once; each new friend still
    gets you a "joined from your invite" card and counts in profile.invite.count.
  * You and they must be Roblox friends (Players:IsFriendsWith) and not the same account.
  * Not in the same server (an invite usually lands them in yours, but not always)? Your credit waits in a
    DataStore and is claimed the next time you join.

The invite card (InviteService:Promote): at a good moment the server shows a big "INVITE A FRIEND, GET A RANDOM
EFFECT" card (InvitePromoController, a slot machine of kill effects). The good moments: the visit's first win, an
MVP, a streak of PROMO.streak knockouts (shown once that fight is over), or after PROMO.play seconds of play. Never
in a visit's first PROMO.minAge seconds, never in a first match still being taught (the tutorial), never mid-fight
(it waits for the results or the build phase), at most once every PROMO.gap seconds and PROMO.max times a visit,
and no more after LATER PROMO.declines times. Between cards the INVITE button just pulses now and then.

The reward (Roblox's rules: nothing for sending an invite, only for a friend who actually comes): each friend who
joins from your invite wins you a random kill effect you don't have yet (the shop's, rarer ones likelier), yours
for good and put on, revealed by the same slot machine landing on it (Net "InviteReward").

  InviteService.Credited (inviter, friendUserId)
  InviteService.PromoShown (player, why) / PromoAnswered (player, "sent" | "later", recipients?)
  InviteService.Rewarded (player, effectKey, friendUserId)
  InviteService:Promote(player, why) -> true if shown;  InviteService:Blocked(player) -> why not, or nil
  InviteService.randomEffect(profile, rng?) -> key | nil
]]
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Locker = require(ReplicatedStorage.Shared.Data.Locker)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local InviteService = {
	Name = "InviteService",
	Modes = { "turf", "ctf", "brawl" }, -- (a match's: never in the lobby)
	Dependencies = { "PlayerDataService", "ProgressService", "MatchService", "TeamService", "CombatService" },
	Credited = Signal.new("InviteService.Credited"), -- (inviter, friendUserId)
	PromoShown = Signal.new("InviteService.PromoShown"), -- (player, why)
	PromoAnswered = Signal.new("InviteService.PromoAnswered"), -- (player, "sent" | "later", recipients?)
	Rewarded = Signal.new("InviteService.Rewarded"), -- (player, effectKey, friendUserId)
}

-- The invite card's timing, in seconds (tests shrink them)
InviteService.PROMO = {
	minAge = 120, -- never in a visit's first two minutes
	gap = 600, -- at most one card every ten minutes
	max = 3, -- and three a visit
	declines = 2, -- LATER twice: no more cards (the button still pulses now and then)
	play = 270, -- no moment of joy yet: a card after this much play anyway
	streak = 3, -- knockouts within streakWindow seconds: a moment of joy
	streakWindow = 8,
	pulseEvery = 240, -- between cards, the INVITE button pulses this often
}
-- How much likelier the rarer effects are as the prize
local PRIZE_WEIGHT = { common = 1, rare = 2, epic = 4, legendary = 6 }

local BUDDY = "extra_buddy"
local STORE_NAME = "TWO_InviteCredits_v1"
local PENDING_MAX = 50
local data, progress, store, match, teams
local promo = {} -- [player] = { since, at, n, declined, pending, played, won, pulsedAt, kills = { times } }
local rng = Random.new()

local function clock()
	return os.clock()
end

-- Who invited this player, from how they joined (nil if nobody).
function InviteService.inviterOf(player)
	local ok, jd = pcall(function()
		return player:GetJoinData()
	end)
	if not ok or type(jd) ~= "table" then
		return nil
	end
	local id = type(jd.LaunchData) == "string" and tonumber(string.match(jd.LaunchData, "^i:(%d+)$")) or nil
	if not id and tonumber(jd.ReferredByPlayerId) and jd.ReferredByPlayerId ~= 0 then
		id = tonumber(jd.ReferredByPlayerId)
	end
	return id
end

local function inviteOf(profile)
	profile.invite = profile.invite or {}
	local inv = profile.invite
	inv.friends = inv.friends or {}
	inv.count = inv.count or 0
	return inv
end

-- The inviter's side: once per friend.
function InviteService:Credit(inviter, friendId, friendName)
	local p = data:Get(inviter)
	if not p then
		return false
	end
	local inv = inviteOf(p)
	local k = tostring(friendId)
	if inv.friends[k] then
		return false
	end
	inv.friends[k] = true
	inv.count += 1
	data:WhenClientReady(inviter, function()
		progress:GrantExtra(inviter, BUDDY, { title = "FRIEND JOINED!", line = `{friendName} came from your invite` })
		self:Reward(inviter, friendId, friendName)
	end)
	self.Credited:Fire(inviter, friendId)
	return true
end

-- The kill effects on offer as the prize: the shop's.
function InviteService.prizePool()
	local list = {}
	for _, it in Cosmetics.list do
		if it.kind == "effect" and it.source == "shop" then
			table.insert(list, it.key)
		end
	end
	return list
end

-- A random kill effect this profile doesn't have yet (rarer ones likelier); nil if they have them all.
function InviteService.randomEffect(profile, r)
	r = r or rng
	local options, total = {}, 0
	for _, key in InviteService.prizePool() do
		if not Locker.owns(profile, key) then
			local w = PRIZE_WEIGHT[Cosmetics.get(key).rarity] or 1
			table.insert(options, { key = key, w = w })
			total += w
		end
	end
	if total <= 0 then
		return nil
	end
	local roll = r:NextNumber() * total
	for _, o in options do
		roll -= o.w
		if roll <= 0 then
			return o.key
		end
	end
	return options[#options].key
end

-- A friend came from your invite: a random effect, yours for good and put on, revealed by the slot machine.
function InviteService:Reward(player, friendId, friendName)
	local p = data:Get(player)
	if not p then
		return nil
	end
	local key = InviteService.randomEffect(p)
	if not key then
		return nil
	end
	p.owned = p.owned or {}
	p.owned[key] = true
	p.equipped = p.equipped or {}
	p.equipped.effect = key
	pcall(progress.Push, progress, player)
	Net.fire(player, "InviteReward", { key = key, pool = InviteService.prizePool(), friend = friendName })
	self.Rewarded:Fire(player, key, friendId)
	return key
end

-- The invite card -------------------------------------------------------------------------------------------
local function stateOf(player)
	local st = promo[player]
	if not st then
		st = { since = clock(), at = -math.huge, n = 0, declined = 0, kills = {}, pulsedAt = clock() }
		promo[player] = st
	end
	return st
end

-- Still being taught their first match (the tutorial's guide is on): no card yet.
local function learning(player)
	local p = data:Get(player)
	local t = p and p.tutorial
	return type(t) == "table" and t.done ~= true and t.skipped ~= true
end

-- Why a card can't go up now (nil: it can).
function InviteService:Blocked(player)
	local st = stateOf(player)
	local P = InviteService.PROMO
	if not player.Parent or not data:Get(player) then
		return "gone"
	elseif clock() - st.since < P.minAge then
		return "new"
	elseif learning(player) then
		return "tutorial"
	elseif st.n >= P.max then
		return "max"
	elseif st.declined >= P.declines then
		return "declined"
	elseif clock() - st.at < P.gap then
		return "gap"
	elseif match:Phase() == "fight" then
		return "fight"
	end
	return nil
end

function InviteService:Promote(player, why)
	if self:Blocked(player) then
		return false
	end
	local st = stateOf(player)
	st.at = clock()
	st.n += 1
	st.pending = nil
	Net.fire(player, "InvitePromo", { why = why, pool = InviteService.prizePool() })
	self.PromoShown:Fire(player, why)
	return true
end

-- The player's answer on the card: "sent" (Roblox's invite prompt closed after sending) or "later"
function InviteService:Answer(player, what, recipients)
	local st = stateOf(player)
	if what == "later" then
		st.declined += 1
	elseif what == "sent" then
		st.declined = 0
	else
		return false
	end
	local n = type(recipients) == "number" and recipients == recipients and math.clamp(math.floor(recipients), 0, 200)
		or nil
	self.PromoAnswered:Fire(player, what, n)
	return true
end

-- Every few seconds: a moment of joy that waited for the fight to end, the play-time card, or a pulse of the button.
function InviteService:_tick()
	local P = InviteService.PROMO
	for _, player in Players:GetPlayers() do
		local st = stateOf(player)
		if st.pending and not self:Blocked(player) then
			self:Promote(player, st.pending)
		elseif not st.played and clock() - st.since >= P.play and not self:Blocked(player) then
			st.played = true
			self:Promote(player, "playtime")
		elseif clock() - st.pulsedAt >= P.pulseEvery and match:Phase() ~= "fight" and not learning(player) then
			st.pulsedAt = clock()
			Net.fire(player, "InvitePromo", { pulse = true })
		end
	end
end

-- Credits that came in while the inviter was somewhere else.
function InviteService:Claim(player)
	if not store then
		return
	end
	local got
	pcall(function()
		store:UpdateAsync(tostring(player.UserId), function(old)
			if type(old) ~= "table" or #old == 0 then
				return nil
			end
			got = old
			return {}
		end)
	end)
	for _, c in got or {} do
		self:Credit(player, c.id, c.name or "A friend")
	end
end

local function queue(inviterId, friendId, friendName)
	if not store then
		return
	end
	pcall(function()
		store:UpdateAsync(tostring(inviterId), function(old)
			old = type(old) == "table" and old or {}
			if #old < PENDING_MAX then
				table.insert(old, { id = friendId, name = friendName })
			end
			return old
		end)
	end)
end

-- The friend's side: once ever.
function InviteService:Joined(player, profile)
	local by = InviteService.inviterOf(player)
	local inv = inviteOf(profile)
	if not by or by == player.UserId or inv.by ~= nil then
		return false
	end
	local okF, friends = pcall(function()
		return player:IsFriendsWith(by)
	end)
	if okF and not friends then
		return false
	end
	inv.by = by
	local inviter = Players:GetPlayerByUserId(by)
	local inviterName = inviter and inviter.DisplayName or "A friend"
	data:WhenClientReady(player, function()
		progress:GrantExtra(
			player,
			BUDDY,
			{ title = "A FRIEND INVITED YOU!", line = `{inviterName} · you both get the Buddy Trail` }
		)
	end)
	if inviter and data:Get(inviter) then
		self:Credit(inviter, player.UserId, player.DisplayName)
	else
		task.spawn(queue, by, player.UserId, player.DisplayName)
	end
	return true
end

function InviteService:Init(registry)
	data = registry.PlayerDataService
	progress = registry.ProgressService
	match = registry.MatchService
	teams = registry.TeamService
	Net.on("InvitePromo", function(player, what, recipients)
		if what == "sent" or what == "later" then
			self:Answer(player, what, recipients)
		end
	end)
	-- moments of joy: the visit's first win, an MVP (shown at the results), a streak (once its fight is over)
	match.Ended:Connect(function(winner, results)
		for _, player in Players:GetPlayers() do
			local st = stateOf(player)
			local won = winner ~= nil and teams:Team(player) == winner
			if results and results.mvpPlayer == player then
				st.pending = "mvp"
			elseif won and not st.won then
				st.pending = "win"
			end
			if won then
				st.won = true
			end
		end
	end)
	registry.CombatService.Killed:Connect(function(_victim, killer)
		if typeof(killer) ~= "Instance" or not killer:IsA("Player") then
			return
		end
		local st = stateOf(killer)
		local t = clock()
		table.insert(st.kills, t)
		while #st.kills > 0 and t - st.kills[1] > InviteService.PROMO.streakWindow do
			table.remove(st.kills, 1)
		end
		if #st.kills >= InviteService.PROMO.streak then
			st.pending = st.pending or "streak"
			st.kills = {}
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		promo[player] = nil
	end)
	local ok, s = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	store = ok and s or nil
end

function InviteService:OnPlayerReady(player, profile)
	stateOf(player)
	self:Joined(player, profile)
	task.spawn(self.Claim, self, player)
end

function InviteService:Start()
	while true do
		task.wait(3)
		pcall(self._tick, self)
	end
end

return InviteService
