--[[
Teams (master plan §2A): red and blue, kept together with friends, balanced around them.

  * A joining player always goes to the smaller team. When they're even, to the team losing on turf; only when the
    turf is even too does a friend decide (their team), then a coin flip.
  * Between matches, teams are rebalanced by moving players who have no friend on their team from the bigger side.
  * The look (§0): everyone is a mannequin in their team's colour: body parts tinted, clothes and accessories off,
    so in a white world a player is a red or blue figure you can read at any distance.

  TeamService:Team(player)            "red" | "blue" | nil
  TeamService:Members(team)           { players }
  TeamService:Count(team)
  TeamService:Assign(player)          picks and sets a team
  TeamService:Rebalance()             between matches
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

function TeamService:Assign(player)
	local red, blue = self:Count("red"), self:Count("blue")
	local pick
	if red ~= blue then
		pick = red < blue and "red" or "blue"
	else
		-- (even: help the side that's behind on turf; turf even too: a friend's side, else a coin flip)
		local leader = turfLeader and turfLeader()
		pick = (leader and (leader == "red" and "blue" or "red"))
			or self:FriendTeam(player)
			or (math.random(1, 2) == 1 and "red" or "blue")
	end
	self:Set(player, pick)
	return pick
end

-- Between matches: move players with no friend on their side from the bigger team until it's even (within 1).
function TeamService:Rebalance()
	for _ = 1, Constants.MAX_PLAYERS do
		local red, blue = self:Count("red"), self:Count("blue")
		if math.abs(red - blue) <= 1 then
			return
		end
		local big = red > blue and "red" or "blue"
		local moved = false
		for _, p in self:Members(big) do
			local hasFriend = false
			for _, q in self:Members(big) do
				if q ~= p and friends(p, q) then
					hasFriend = true
					break
				end
			end
			if not hasFriend then
				self:Set(p, big == "red" and "blue" or "red")
				moved = true
				break
			end
		end
		if not moved then
			-- (everyone on the big side has a friend there: move the newest anyway, so teams stay fair)
			local list = self:Members(big)
			self:Set(list[#list], big == "red" and "blue" or "red")
		end
	end
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
