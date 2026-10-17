--[[
Teams (master plan §2A): red and blue, parties kept together, solo players balanced round them.

The rules, in order:

  1. A party always plays on one team. A player who joins (or arrives with) a party goes straight to the party's
     team: the leader's (or, while the leader has none, any member's).
  2. A solo player who joins goes to the smaller team. When they're even, to the team losing on turf; only when the
     turf is even too does a friend decide (their team), then a coin flip. (The owner's rule: unchanged.)
  3. Rebalance (between matches; and when a party forms or grows in the build phase, PartyService) first puts every
     party on its leader's team, then evens the teams (within 1): it moves solo players from the bigger side (ones
     with no friend there first), and only when no solo is left there, a whole party as one block (the smallest,
     and only if that makes it fairer). A party is never split, even when it is more than half the server
     (fairness comes second). A party that forms in the fight waits: it moves at the next match start.
  4. The look (§0): everyone is a mannequin in their team's colour: body parts tinted, clothes and accessories off,
     so in a white world a player is a red or blue figure you can read at any distance.

  TeamService:Team(player)            "red" | "blue" | nil
  TeamService:Members(team)           { players }
  TeamService:Count(team)
  TeamService:Assign(player)          picks and sets a team (rule 1, else rule 2)
  TeamService:PartyTeam(player)       the team the player's party is on, or nil
  TeamService:Rebalance()             rule 3; returns the players it moved
  TeamService:SetParties(fn)          fn() -> { { leader = player, members = { players } } } (PartyService)
  TeamService:Dress(character, team)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Signal = require(ReplicatedStorage.Shared.Signal)

local TeamService = {
	Name = "TeamService",
	Dependencies = {},
	Changed = Signal.new("TeamService.Changed"), -- (player, team, old)
}

local teams = {} -- [player] = "red" | "blue"
local turfLeader -- fn() -> "red" | "blue" | nil: the team ahead on turf (MatchService sets it)
local partyList -- fn() -> { { leader, members } } (PartyService sets it)

function TeamService:Team(player)
	return teams[player]
end

function TeamService:Members(team)
	local out = {}
	for p, t in teams do
		if t == team and p.Parent then
			table.insert(out, p)
		end
	end
	return out
end

function TeamService:Count(team)
	return #self:Members(team)
end

local function friends(a, b)
	local ok, yes = pcall(function()
		return a:IsFriendsWith(b.UserId)
	end)
	return ok and yes == true
end

local function other(team)
	return team == "red" and "blue" or "red"
end

function TeamService:FriendTeam(player)
	local counts = { red = 0, blue = 0 }
	for p, t in teams do
		if p ~= player and p.Parent and friends(player, p) then
			counts[t] += 1
		end
	end
	if counts.red == 0 and counts.blue == 0 then
		return nil
	end
	return counts.red >= counts.blue and "red" or "blue"
end

function TeamService:Set(player, team)
	local old = teams[player]
	teams[player] = team
	player:SetAttribute("Team", team)
	pcall(function()
		local tf = game:GetService("Teams"):FindFirstChild(Constants.TEAM_NAME[team])
		if tf then
			player.Team = tf
		end
	end)
	if old ~= team then
		self.Changed:Fire(player, team, old)
	end
end

-- Parties --------------------------------------------------------------------------------------------------------
-- The parties right now: only members still in the server (a party of one is no party).
local function parties()
	local out = {}
	for _, party in partyList and partyList() or {} do
		local members = {}
		for _, p in party.members or {} do
			if p.Parent then
				table.insert(members, p)
			end
		end
		if #members >= 2 then
			table.insert(out, { leader = party.leader, members = members })
		end
	end
	return out
end

local function partyOf(player, list)
	for _, party in list or parties() do
		if table.find(party.members, player) then
			return party
		end
	end
	return nil
end

-- The team a party is on: the leader's, else the first member's that has one (leaving out `except`).
local function teamOfParty(party, except)
	if party.leader and party.leader ~= except and teams[party.leader] then
		return teams[party.leader]
	end
	for _, p in party.members do
		if p ~= except and teams[p] then
			return teams[p]
		end
	end
	return nil
end

function TeamService:PartyTeam(player)
	local party = partyOf(player)
	return party and teamOfParty(party, player) or nil
end

function TeamService:SetParties(fn)
	partyList = fn
end

-- Joining ----------------------------------------------------------------------------------------------------------
function TeamService:Assign(player)
	-- rule 1: with your party
	local pick = self:PartyTeam(player)
	if pick then
		self:Set(player, pick)
		return pick
	end
	-- rule 2: solo
	local red, blue = self:Count("red"), self:Count("blue")
	if red ~= blue then
		pick = red < blue and "red" or "blue"
	else
		-- (even: help the side that's behind on turf; turf even too: a friend's side, else a coin flip)
		local leader = turfLeader and turfLeader()
		pick = (leader and other(leader)) or self:FriendTeam(player) or (math.random(1, 2) == 1 and "red" or "blue")
	end
	self:Set(player, pick)
	return pick
end

-- Rule 3: every party on its leader's team, then even teams: solo players first, whole parties last.
function TeamService:Rebalance()
	local moved = {}
	local function move(p, team)
		if teams[p] ~= team then
			self:Set(p, team)
			table.insert(moved, p)
		end
	end
	local list = parties()
	for _, party in list do
		local team = teamOfParty(party)
		if team then
			for _, p in party.members do
				move(p, team)
			end
		end
	end
	for _ = 1, Constants.MAX_PLAYERS * 2 do
		local red, blue = self:Count("red"), self:Count("blue")
		local diff = math.abs(red - blue)
		if diff <= 1 then
			break
		end
		local big = red > blue and "red" or "blue"
		local members = self:Members(big)
		local newest, lonely -- (a solo player: the last one listed; the first with no friend on this side)
		for _, p in members do
			if not partyOf(p, list) then
				newest = p
				local hasFriend = false
				for _, q in members do
					if q ~= p and friends(p, q) then
						hasFriend = true
						break
					end
				end
				if not hasFriend and not lonely then
					lonely = p
				end
			end
		end
		local pick = lonely or newest
		if pick then
			move(pick, other(big))
		else
			-- (only parties left on the big side: move the smallest one whole, if that makes it fairer)
			local best
			for _, party in list do
				local n = #party.members
				if teams[party.members[1]] == big and n < diff and (not best or n < #best.members) then
					best = party
				end
			end
			if not best then
				break
			end
			for _, p in best.members do
				move(p, other(big))
			end
		end
	end
	return moved
end

function TeamService:SetTurfLeader(fn)
	turfLeader = fn
end

-- The mannequin: every body part in the team's colour, smooth, no clothes, no accessories.
function TeamService:Dress(character, team)
	local color = Constants.TEAM_COLOR[team] or Constants.WHITE
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			d.Color = color
			d.Material = Enum.Material.SmoothPlastic
		elseif d:IsA("Accessory") or d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") then
			d:Destroy()
		elseif d:IsA("Decal") and d.Name == "face" then
			d.Transparency = 0.6
		end
	end
	character:SetAttribute("Team", team)
end

function TeamService:Init()
	local Teams = game:GetService("Teams")
	for _, team in Constants.TEAMS do
		pcall(function()
			if not Teams:FindFirstChild(Constants.TEAM_NAME[team]) then
				local t = Instance.new("Team")
				t.Name = Constants.TEAM_NAME[team]
				t.TeamColor = BrickColor.new(Constants.TEAM_COLOR[team])
				t.AutoAssignable = false
				t.Parent = Teams
			end
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		teams[player] = nil
	end)
end

return TeamService
