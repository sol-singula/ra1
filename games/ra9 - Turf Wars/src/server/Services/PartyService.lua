--[[
Parties: friends play together, on the same team, and move between servers together.

  * Up to MAX (4) players. Anyone in a party can invite a player in this server (the PARTY panel); the invite card
    waits INVITE_SECONDS (20) for YES or NO. The first YES makes the party (the one who invited leads it).
  * The leader can take someone out (kick). Anyone can leave; when the leader leaves, the next member leads. A party
    of one is over.
  * Same team (TeamService's rules 1 and 3): when a party forms or grows, it goes to the leader's team. In the build
    phase or between matches it happens at once (TeamService:Rebalance, which moves solo players to keep it fair;
    whoever moved in the build phase respawns on their new side). In the fight it waits for the next match start.
  * A friend who joins your server (or follows you in with Roblox's Join) gets a one-tap "Party up with NAME?" card.
  * The leader's FIND A NEW SERVER / JOIN A FULLER SERVER teleports the whole party together
    (TeleportService:TeleportAsync with every member and TeleportOptions). The party rides in the teleport data
    ({ party = { id, leader, members } }) and forms again on arrival, on one team. JOIN A FULLER SERVER uses
    PartyService.findServer(size) -> a JobId with room, if another service sets it (a server list); otherwise both
    go to a public server picked by Roblox, which fills fuller servers first.
  * Every step is a short party banner (server/Notify.lua).

  Client → server: Net "Party" (action, arg): "invite" userId | "accept" | "decline" | "leave" | "kick" userId |
    "move" "new" | "fuller"
  Server → client: Net "PartyState" { id, leader, max, members = { { userId, name } } } or false (no party);
    Net "PartyInvite" { from, name, kind = "invite" | "friend", seconds } or { cancel = true }

  PartyService:Of(player)              the party { id, leader, members, tag } or nil
  PartyService:Invite(from, target)    true | false, why
  PartyService:Answer(target, yes)
  PartyService:Leave(player)  :Kick(leader, target)  :Move(leader, kind)
  PartyService:Offer(player, friend)   the "Party up with NAME?" card
  PartyService.Changed (party)
]]
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Notify = require(script.Parent.Parent.Notify)

local PartyService = {
	Name = "PartyService",
	Dependencies = { "PlayerDataService", "TeamService", "MatchService", "BotService" },
	Changed = Signal.new("PartyService.Changed"), -- (party)
	MAX = 4,
	INVITE_SECONDS = 20,
	MOVE_COOLDOWN = 10,
	findServer = nil, -- fn(size) -> JobId | nil (a server list may set it)
}

local data, teams, match
local parties = {} -- { party }
local partyOf = {} -- [player] = party
local invites = {} -- [target] = { from, kind, token, at }
local arriving = {} -- [player] = the party they came with ({ id, leader, members }) until it forms here
local token = 0

local function teamName(team)
	return Constants.TEAM_NAME[team] or string.upper(tostring(team))
end

local function isPlayer(p)
	return typeof(p) == "Instance" and p:IsA("Player") and p.Parent ~= nil
end

local function tell(party, text, except)
	for _, p in party.members do
		if p ~= except then
			Notify.to(p, text, "party")
		end
	end
end

function PartyService:Of(player)
	return partyOf[player]
end

function PartyService:List()
	return parties
end

-- What a member's client sees.
local function view(party)
	local members = {}
	for _, p in party.members do
		table.insert(members, { userId = p.UserId, name = p.DisplayName })
	end
	return { id = party.id, leader = party.leader.UserId, max = PartyService.MAX, members = members }
end

local function push(party)
	for _, p in party.members do
		p:SetAttribute("Party", party.id)
		Net.fire(p, "PartyState", view(party))
	end
	PartyService.Changed:Fire(party)
end

local function newId()
	local ok, id = pcall(function()
		return HttpService:GenerateGUID(false)
	end)
	token += 1
	return ok and id or ("party-" .. token .. "-" .. os.time())
end

local function create(leader, id)
	local party = { id = id or newId(), leader = leader, members = { leader } }
	table.insert(parties, party)
	partyOf[leader] = party
	return party
end

-- Out of a party (leaving, kicked or gone): the next member leads; one left, the party is over.
local function remove(player, why)
	local party = partyOf[player]
	if not party then
		return
	end
	partyOf[player] = nil
	local i = table.find(party.members, player)
	if i then
		table.remove(party.members, i)
	end
	if player.Parent then
		player:SetAttribute("Party", nil)
		Net.fire(player, "PartyState", false)
	end
	local name = player.DisplayName
	if #party.members <= 1 then
		local last = party.members[1]
		if last then
			partyOf[last] = nil
			last:SetAttribute("Party", nil)
			Net.fire(last, "PartyState", false)
			Notify.to(last, why == "kick" and "Your party has ended." or `{name} left. Your party has ended.`, "party")
		end
		local at = table.find(parties, party)
		if at then
			table.remove(parties, at)
		end
		party.members = {}
		PartyService.Changed:Fire(party)
		return
	end
	if party.leader == player then
		party.leader = party.members[1]
		tell(party, why == "kick" and `{name} was taken out.` or `{name} left the party.`)
		tell(party, `{party.leader.DisplayName} leads the party now.`)
	else
		tell(party, why == "kick" and `{name} was taken out.` or `{name} left the party.`)
	end
	push(party)
end

-- Same team: the party goes to the leader's team (at once in the build phase or between matches, else at the
-- next match start). `joiner` is a new member who hasn't spawned yet: they go straight to the party's team.
function PartyService:Settle(party, joiner)
	-- (a joiner's own team doesn't count: it's the others' team they join)
	local team = (joiner and teams:PartyTeam(joiner)) or teams:Team(party.leader) or teams:PartyTeam(party.leader)
	if not team then
		return
	end
	if joiner and teams:Team(joiner) ~= team and not joiner.Character then
		teams:Set(joiner, team)
		match.SpawnAt[joiner] = nil -- (BotService's takeover spot is on the other side)
	end
	local split = false
	for _, p in party.members do
		if teams:Team(p) ~= team then
			split = true
		end
	end
	local phase = match:Phase()
	if phase == "fight" then
		-- (nobody changes sides mid-fight: the party, and the evening up, wait for the next match)
		if split then
			tell(party, `Your party goes to {teamName(team)} next game.`)
		end
		return
	end
	local moved = teams:Rebalance()
	for _, p in moved do
		if phase == "build" and p.Parent and (p.Character or not isPlayer(p)) then
			match:Spawn(p) -- (on their new side; a bot too)
		end
		if isPlayer(p) and not partyOf[p] then
			Notify.to(p, `Teams were evened. You are on {teamName(teams:Team(p))} now.`, "party")
		end
	end
	if #moved > 0 then
		match:Broadcast()
	end
end

-- Inviting -----------------------------------------------------------------------------------------------------
local function cancelInvite(target)
	if invites[target] then
		invites[target] = nil
		if target.Parent then
			Net.fire(target, "PartyInvite", { cancel = true })
		end
	end
end

local function send(target, from, kind)
	token += 1
	local inv = { from = from, kind = kind, token = token, at = os.clock() }
	invites[target] = inv
	local function show()
		if invites[target] == inv then
			Net.fire(target, "PartyInvite", {
				from = from.UserId,
				name = from.DisplayName,
				kind = kind,
				seconds = PartyService.INVITE_SECONDS,
			})
		end
	end
	if data:Get(target) then
		data:WhenClientReady(target, show)
	else
		show()
	end
	task.delay(PartyService.INVITE_SECONDS, function()
		if invites[target] == inv then
			cancelInvite(target)
			if kind == "invite" and from.Parent then
				Notify.to(from, `{target.DisplayName} did not answer.`, "party")
			end
		end
	end)
	return inv
end

function PartyService:Invite(from, target)
	if not isPlayer(from) or not isPlayer(target) or from == target then
		return false, "nobody"
	end
	local party = partyOf[from]
	if party and table.find(party.members, target) then
		return false, "already"
	end
	if party and #party.members >= self.MAX then
		Notify.to(from, `Your party is full ({self.MAX} max).`, "party")
		return false, "full"
	end
	local pending = invites[target]
	if pending and pending.from == from and pending.kind == "invite" then
		return false, "waiting"
	end
	send(target, from, "invite")
	Notify.to(from, `You asked {target.DisplayName} to join your party.`, "party")
	Notify.to(target, `{from.DisplayName} wants you in their party!`, "party")
	return true
end

-- Put `player` in `host`'s party (made now with the host leading, if the host has none).
function PartyService:Join(player, host)
	if not isPlayer(player) or not isPlayer(host) or player == host then
		return nil
	end
	local party = partyOf[host]
	if party and table.find(party.members, player) then
		return party
	end
	if party and #party.members >= self.MAX then
		Notify.to(player, `{host.DisplayName}'s party is full.`, "party")
		return nil
	end
	if partyOf[player] then
		remove(player, "leave")
	end
	party = partyOf[host] or create(host)
	table.insert(party.members, player)
	partyOf[player] = party
	tell(party, `{player.DisplayName} joined your party!`, player)
	Notify.to(player, `You joined {party.leader.DisplayName}'s party!`, "party")
	push(party)
	return party
end

function PartyService:Answer(target, yes)
	local inv = invites[target]
	if not inv then
		return false
	end
	invites[target] = nil
	local from = inv.from
	if not yes then
		if inv.kind == "invite" and from.Parent then
			Notify.to(from, `{target.DisplayName} said no.`, "party")
		end
		return false
	end
	if not isPlayer(from) then
		Notify.to(target, "They left the server.", "party")
		return false
	end
	local party = self:Join(target, from)
	if not party then
		return false
	end
	self:Settle(party)
	return true
end

function PartyService:Leave(player)
	if not partyOf[player] then
		return false
	end
	remove(player, "leave")
	Notify.to(player, "You left the party.", "party")
	return true
end

function PartyService:Kick(leader, target)
	local party = partyOf[leader]
	if not party or party.leader ~= leader or target == leader or partyOf[target] ~= party then
		return false
	end
	remove(target, "kick")
	Notify.to(target, "You were taken out of the party.", "party")
	return true
end

-- The "Party up with NAME?" card: for a friend who joined (or followed you in).
function PartyService:Offer(player, friend)
	if not isPlayer(player) or not isPlayer(friend) or partyOf[player] or invites[player] then
		return false
	end
	local party = partyOf[friend]
	if party and #party.members >= self.MAX then
		return false
	end
	send(player, friend, "friend")
	return true
end

-- Moving together ------------------------------------------------------------------------------------------------
function PartyService:Move(leader, kind)
	local party = partyOf[leader]
	if not party or party.leader ~= leader then
		return false
	end
	local t = os.clock()
	if party.movedAt and t - party.movedAt < self.MOVE_COOLDOWN then
		return false
	end
	party.movedAt = t
	local ids = {}
	for _, p in party.members do
		table.insert(ids, p.UserId)
	end
	local trip = { party = { id = party.id, leader = leader.UserId, members = ids, from = game.JobId } }
	local members = table.clone(party.members)
	local options = Instance.new("TeleportOptions")
	options:SetTeleportData(trip)
	if kind == "fuller" and self.findServer then
		local ok, jobId = pcall(self.findServer, #members)
		if ok and type(jobId) == "string" and jobId ~= "" and jobId ~= game.JobId then
			options.ServerInstanceId = jobId
		end
	end
	tell(party, kind == "fuller" and "Off to a fuller server, together!" or "Off to a new server, together!")
	task.spawn(function()
		local ok, err = pcall(function()
			return TeleportService:TeleportAsync(game.PlaceId, members, options)
		end)
		if not ok then
			warn("[PartyService] teleport failed: " .. tostring(err))
			if leader.Parent then
				Notify.to(leader, "Could not move. Try again!", "party")
			end
		end
	end)
	return true, trip
end

-- Arriving with a party (teleport data): it forms again here, on one team.
local function joinData(player)
	local ok, jd = pcall(function()
		return player:GetJoinData()
	end)
	return ok and type(jd) == "table" and jd or {}
end

function PartyService:Arrive(player)
	local trip = joinData(player).TeleportData
	local info = type(trip) == "table" and trip.party
	if type(info) ~= "table" or type(info.id) ~= "string" or type(info.members) ~= "table" then
		return nil
	end
	if not table.find(info.members, player.UserId) then
		return nil
	end
	arriving[player] = info
	-- the party is already here (a member came first)
	local host
	for _, party in parties do
		if party.tag == info.id or party.id == info.id then
			host = party.leader
		end
	end
	if not host then
		for p, other in arriving do
			if p ~= player and p.Parent and other.id == info.id and not partyOf[p] then
				host = p
				break
			end
		end
	end
	if not host then
		return nil -- (the first one here: the party forms when the next arrives)
	end
	local party = partyOf[host] or create(host, info.id)
	party.tag = info.id
	if #party.members >= self.MAX then
		return nil
	end
	table.insert(party.members, player)
	partyOf[player] = party
	-- the old leader leads again once they're here
	for _, p in party.members do
		if p.UserId == info.leader then
			party.leader = p
		end
	end
	for _, p in party.members do
		arriving[p] = nil
		data:WhenClientReady(p, function()
			if partyOf[p] == party then
				Notify.to(p, "Your party is back together!", "party")
			end
		end)
	end
	push(party)
	self:Settle(party, player)
	return party
end

-- A friend already here (the one they followed in first).
local function friendHere(player)
	local followed = tonumber(player.FollowUserId)
	local f = followed and followed > 0 and Players:GetPlayerByUserId(followed)
	if f and f ~= player then
		return f
	end
	for _, p in Players:GetPlayers() do
		if p ~= player then
			local ok, yes = pcall(function()
				return player:IsFriendsWith(p.UserId)
			end)
			if ok and yes then
				return p
			end
		end
	end
	return nil
end

-- Client requests ----------------------------------------------------------------------------------------------
local function onRequest(player, action, arg)
	if action == "invite" then
		local target = type(arg) == "number" and Players:GetPlayerByUserId(arg)
		if target then
			PartyService:Invite(player, target)
		end
	elseif action == "accept" or action == "decline" then
		PartyService:Answer(player, action == "accept")
	elseif action == "leave" then
		PartyService:Leave(player)
	elseif action == "kick" then
		local target = type(arg) == "number" and Players:GetPlayerByUserId(arg)
		if target then
			PartyService:Kick(player, target)
		end
	elseif action == "move" and (arg == "new" or arg == "fuller") then
		PartyService:Move(player, arg)
	end
end

function PartyService:Init(registry)
	data = registry.PlayerDataService
	teams = registry.TeamService
	match = registry.MatchService
	teams:SetParties(function()
		return parties
	end)
	Net.on("Party", onRequest)
	-- (after BotService's takeover, so a party member who arrives second still lands on the party's team)
	Players.PlayerAdded:Connect(function(player)
		self:Arrive(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		cancelInvite(player)
		for target, inv in invites do
			if inv.from == player then
				cancelInvite(target)
			end
		end
		arriving[player] = nil
		remove(player, "gone")
	end)
	-- a party moved (by Rebalance at a match start, or at once): tell it where it is, once
	teams.Changed:Connect(function(player, _, old)
		local party = partyOf[player]
		if not party or old == nil or party.noticing then
			return
		end
		party.noticing = true
		task.defer(function()
			party.noticing = nil
			local team = teams:Team(party.leader)
			if team and table.find(parties, party) then
				tell(party, `Your party is on {teamName(team)}!`)
			end
		end)
	end)
	TeleportService.TeleportInitFailed:Connect(function(player)
		if player.Parent and partyOf[player] then
			Notify.to(player, "Could not move. Try again!", "party")
		end
	end)
end

function PartyService:OnPlayerReady(player)
	if partyOf[player] or arriving[player] then
		return
	end
	local friend = friendHere(player)
	if friend then
		self:Offer(player, friend)
	end
end

return PartyService
