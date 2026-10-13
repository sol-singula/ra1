-- Squads: friends in the same server. Each friend here adds +10% coins (up to +30%), friends spawn a little
-- closer to each other, and two friends popping players within 3 seconds get a DOUBLE TAP.
-- Friendships are looked up once per pair and cached.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Signal = require(ReplicatedStorage.Shared.Signal)

local TeamService = {
	Name = "TeamService",
	Dependencies = { "PlayerDataService" },
	TeamChanged = Signal.new("TeamService.TeamChanged"), -- (player)
}

local data
local friends = {} -- [player] = { [userId] = true }

local function pairKnown(a, b)
	return friends[a] and friends[a][b.UserId]
end

function TeamService:Init(registry)
	data = registry.PlayerDataService
	data.ClientReady:Connect(function(player)
		self:Push(player)
	end)
end

function TeamService:Push(player)
	local ids = {}
	for id in friends[player] or {} do
		table.insert(ids, id)
	end
	data:Push(player, { team = ids, friendsHere = self:FriendsHere(player), squadBonus = self:CoinMult(player) })
end

function TeamService:OnPlayerReady(player)
	friends[player] = friends[player] or {}
	for _, other in Players:GetPlayers() do
		if other ~= player and friends[other] and not pairKnown(player, other) then
			local ok, isFriend = pcall(player.IsFriendsWith, player, other.UserId)
			if ok and isFriend then
				friends[player][other.UserId] = true
				friends[other][player.UserId] = true
				self.TeamChanged:Fire(other)
				self:Push(other)
			end
		end
	end
	self.TeamChanged:Fire(player)
	self:Push(player)
end

function TeamService:OnPlayerLeaving(player)
	friends[player] = nil
	for other, set in friends do
		if set[player.UserId] then
			set[player.UserId] = nil
			self.TeamChanged:Fire(other)
			self:Push(other)
		end
	end
end

function TeamService:AreTeam(a, b)
	if a == b then
		return true
	end
	return friends[a] ~= nil and friends[a][b.UserId] == true
end

function TeamService:FriendsHere(player)
	local n = 0
	for id in friends[player] or {} do
		if Players:GetPlayerByUserId(id) then
			n += 1
		end
	end
	return n
end

function TeamService:Teammates(player)
	local out = {}
	for id in friends[player] or {} do
		local p = Players:GetPlayerByUserId(id)
		if p then
			table.insert(out, p)
		end
	end
	return out
end

-- True when every player in the list is friends with every other (a squad on its own).
function TeamService:AllTeam(list)
	for i = 1, #list do
		for j = i + 1, #list do
			if not self:AreTeam(list[i], list[j]) then
				return false
			end
		end
	end
	return #list > 0
end

-- The squad coin multiplier: 1 + 10% per friend here, up to +30%.
function TeamService:CoinMult(player)
	return 1 + math.min(Constants.SQUAD_COINS_MAX, Constants.SQUAD_COINS_PER_FRIEND * self:FriendsHere(player))
end

return TeamService
