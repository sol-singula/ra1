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
  4. Mice split between the sides (SpreadDevices, between matches, after rule 3): most players are on phones, and a
     side with all the keyboard-and-mouse players is no fun for the other. While one side has DEVICE_SPREAD or more
     keyboard players than the other (the "Device" each client reports), a solo keyboard player there with no friend
     on that side trades places with a solo touch or pad player (no friend there either) on the other side; the
     sizes stay as they were. Rule 3's evening moves a keyboard player first when their side has more of them, and a
     solo joiner on even teams with the turf even too goes where there are fewer mice (a friend still comes first).
     Parties and friends are never split for it.
  5. The look: players wear their own avatar (at a standard size), with their team on it: neon bands on both upper
     arms and the waist and a team-coloured outline, so red and blue read at any distance. Bots are mannequins in
     their team's colour.

  TeamService:Team(player)            "red" | "blue" | nil
  TeamService:Members(team)           { players }
  TeamService:Count(team)             TeamService:People(team) (the same without bots)
  TeamService:Assign(player)          picks and sets a team (rule 1, else rule 2)
  TeamService:PartyTeam(player)       the team the player's party is on, or nil
  TeamService:Rebalance()             rule 3; returns the players it moved
  TeamService:SpreadDevices()         rule 4; returns the players it moved
  TeamService:Keyboards(team)         keyboard players on the team (real people)
  TeamService:SetParties(fn)          fn() -> { { leader = player, members = { players } } } (PartyService)
  TeamService:Set(player, team)       TeamService:Clear(player)   (no team: a spectating admin)
  TeamService:Dress(character, team)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Signal = require(ReplicatedStorage.Shared.Signal)

local TeamService = {
	Name = "TeamService",
	Modes = { "turf", "ctf", "brawl" }, -- (a match's: never in the lobby)
	Dependencies = {},
	Changed = Signal.new("TeamService.Changed"), -- (player, team, old)
}

local teams = {} -- [player] = "red" | "blue"
local left = {} -- [userId] = { team, match }: the side someone left from, kept for that match (a rejoin goes back)
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

-- (real people only: bots fill in for a missing side, so a newcomer goes where the bots are)
function TeamService:People(team)
	local n = 0
	for _, p in self:Members(team) do
		if not p.IsBot then
			n += 1
		end
	end
	return n
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

-- How a real person plays, as their client reported it ("touch" | "gamepad" | "keyboard"), or nil (a bot, not yet)
local function deviceOf(p)
	if p.IsBot then
		return nil
	end
	local d = p:GetAttribute("Device")
	return (d == "touch" or d == "gamepad" or d == "keyboard") and d or nil
end

function TeamService:Keyboards(team)
	local n = 0
	for _, p in self:Members(team) do
		if deviceOf(p) == "keyboard" then
			n += 1
		end
	end
	return n
end

function TeamService:FriendTeam(player)
	-- (a copy first: IsFriendsWith waits on Roblox, and a crowd joining at once changes `teams` meanwhile, which
	-- breaks a loop over it: Assign threw and they were left with no team. Only real people, and a few at most.)
	local list = {}
	for p, t in teams do
		if p ~= player and not p.IsBot and p.Parent then
			table.insert(list, { p, t })
		end
		if #list >= 12 then
			break
		end
	end
	local counts = { red = 0, blue = 0 }
	for _, pt in list do
		if pt[1].Parent and friends(player, pt[1]) then
			counts[pt[2]] += 1
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

------------------------------------------------------------------------------------------------------
-- Off both teams (a spectating admin).
function TeamService:Clear(player)
	local old = teams[player]
	teams[player] = nil
	player:SetAttribute("Team", nil)
	pcall(function()
		player.Team = nil
	end)
	if old then
		self.Changed:Fire(player, nil, old)
	end
end

-- Joining ----------------------------------------------------------------------------------------------------------
-- Back in the same match after leaving (a rejoin, a crash): the side they were on, or nil
function TeamService:Returning(player)
	local was = typeof(player) == "Instance" and left[player.UserId]
	if was and was.match == workspace:GetAttribute("MatchId") then
		return was.team
	end
	return nil
end

-- (always a team: if picking one goes wrong anyhow, the smaller side)
function TeamService:Assign(player)
	local ok, pick = pcall(self._pick, self, player)
	if not ok or (pick ~= "red" and pick ~= "blue") then
		warn("[TeamService] assign fell back: " .. tostring(pick))
		pick = self:Count("red") <= self:Count("blue") and "red" or "blue"
	end
	if teams[player] ~= pick then
		self:Set(player, pick)
	end
	return pick
end

function TeamService:_pick(player)
	-- rule 0: back in the same match, the side they were on
	local back = self:Returning(player)
	if back then
		left[player.UserId] = nil
		self:Set(player, back)
		return back
	end
	-- rule 1: with your party
	local pick = self:PartyTeam(player)
	if pick then
		self:Set(player, pick)
		return pick
	end
	-- rule 2: solo
	local red, blue = self:People("red"), self:People("blue")
	if red ~= blue then
		pick = red < blue and "red" or "blue"
	else
		-- (even: help the side that's behind on turf; turf even too: a friend's side, else a coin flip)
		local leader = turfLeader and turfLeader()
		pick = (leader and other(leader)) or self:FriendTeam(player)
		if not pick and deviceOf(player) == "keyboard" then
			-- (a mouse: the side with fewer of them; rule 4 evens the rest between matches)
			local kr, kb = self:Keyboards("red"), self:Keyboards("blue")
			pick = kr ~= kb and (kr < kb and "red" or "blue") or nil
		end
		pick = pick or (math.random(1, 2) == 1 and "red" or "blue")
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
		-- (with more mice on the big side, one of them goes first; with fewer, anyone but one: rule 4)
		local kbig, ksmall = self:Keyboards(big), self:Keyboards(other(big))
		local function suits(p)
			local kb = deviceOf(p) == "keyboard"
			return (kbig > ksmall and kb) or (kbig < ksmall and not kb) or kbig == ksmall
		end
		-- (a solo player: the last one listed; the first with no friend on this side; each, preferably one that suits)
		local newest, lonely, newestFit, lonelyFit
		for _, p in members do
			if not partyOf(p, list) then
				newest = p
				newestFit = suits(p) and p or newestFit
				local hasFriend = false
				for _, q in members do
					if q ~= p and friends(p, q) then
						hasFriend = true
						break
					end
				end
				if not hasFriend then
					lonely = lonely or p
					lonelyFit = lonelyFit or (suits(p) and p or nil)
				end
			end
		end
		local pick = lonelyFit or lonely or newestFit or newest
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

-- Rule 4: keyboard players split between the sides (between matches, after Rebalance). Only solo players with no
-- friend on their side trade places; the sizes stay as they were (or one more mouse crosses when their side is the
-- bigger one, which keeps the teams within one).
function TeamService:SpreadDevices()
	local moved = {}
	local list = parties()
	local function free(p)
		if p.IsBot or partyOf(p, list) then
			return false
		end
		local team = teams[p]
		for _, q in self:Members(team) do
			if q ~= p and not q.IsBot and friends(p, q) then
				return false
			end
		end
		return true
	end
	local function find(team, wantKeyboard)
		for _, p in self:Members(team) do
			local d = deviceOf(p)
			local fits = wantKeyboard and d == "keyboard" or (not wantKeyboard and (d == "touch" or d == "gamepad"))
			if fits and not table.find(moved, p) and free(p) then
				return p
			end
		end
		return nil
	end
	for _ = 1, Constants.MAX_PLAYERS do
		local kr, kb = self:Keyboards("red"), self:Keyboards("blue")
		if math.abs(kr - kb) < Constants.DEVICE_SPREAD then
			break
		end
		local heavy = kr > kb and "red" or "blue"
		local light = other(heavy)
		local mouse = find(heavy, true)
		if not mouse then
			break
		end
		local thumb = find(light, false)
		if thumb then
			self:Set(mouse, light)
			self:Set(thumb, heavy)
			table.insert(moved, mouse)
			table.insert(moved, thumb)
		elseif self:Count(heavy) > self:Count(light) then
			self:Set(mouse, light)
			table.insert(moved, mouse)
		else
			break
		end
	end
	return moved
end

function TeamService:SetTurfLeader(fn)
	turfLeader = fn
end

-- The look. A player keeps their own avatar (skin, face, clothes, accessories) and wears their team on it: a bright
-- band round each upper arm and the waist and a team-coloured outline, so red and blue read at any distance. A bot
-- is a mannequin in its team's colour (every part tinted, no clothes).
local function band(character, partName, color, size, offset)
	local at = character:FindFirstChild(partName)
	if not at or not at:IsA("BasePart") then
		return
	end
	local p = Instance.new("Part")
	p.Name = "TeamBand"
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.Neon
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.CFrame = at.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = at, p
	weld.Parent = p
	p.Parent = character
end

function TeamService:Dress(character, team)
	local color = Constants.TEAM_COLOR[team] or Constants.WHITE
	character:SetAttribute("Team", team)
	if character:GetAttribute("BotId") ~= nil then
		for _, d in character:GetDescendants() do
			if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
				d.Color = color
				d.Material = Enum.Material.SmoothPlastic
			elseif d:IsA("Accessory") or d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") then
				d:Destroy()
			end
		end
		return
	end
	for _, old in character:GetChildren() do
		if old.Name == "TeamBand" or old.Name == "TeamOutline" then
			old:Destroy()
		end
	end
	for _, d in character:GetDescendants() do
		-- (accessories never block a shot or a build: arrows and slashes go by the body, not the hat)
		if d:IsA("BasePart") and d.Parent and d.Parent:IsA("Accessory") then
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	band(character, "LeftUpperArm", color, Vector3.new(1.08, 0.35, 1.08), CFrame.new(0, 0.15, 0))
	band(character, "RightUpperArm", color, Vector3.new(1.08, 0.35, 1.08), CFrame.new(0, 0.15, 0))
	band(character, "LowerTorso", color, Vector3.new(2.1, 0.3, 1.1), CFrame.new(0, 0.1, 0))
	local outline = Instance.new("Highlight")
	outline.Name = "TeamOutline"
	outline.FillColor = color
	outline.FillTransparency = 0.85
	outline.OutlineColor = color
	outline.OutlineTransparency = 0.1
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Parent = character
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
		-- (remembered for this match: if they come back before it ends, they're on the same side)
		if teams[player] then
			left[player.UserId] = { team = teams[player], match = workspace:GetAttribute("MatchId") }
		end
		teams[player] = nil
	end)
end

return TeamService
