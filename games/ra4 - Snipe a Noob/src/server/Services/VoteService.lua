-- The map vote in the lobby countdown: a card on screen shows three maps (three of the four, never the one just
-- played). Tap one to vote. The map with the most votes is next; a tie or no votes picks at random among the three.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Net = require(ReplicatedStorage.Shared.Net)

local VoteService = {
	Name = "VoteService",
	Dependencies = { "PlayerDataService" },
	options = {}, -- the three map keys
	votes = {}, -- [player] = map key
	open = false,
}

local lastPlayed

function VoteService:Open()
	local pool = {}
	for _, m in Maps.list do
		if m.key ~= lastPlayed then
			table.insert(pool, m.key)
		end
	end
	self.options = {}
	while #self.options < 3 and #pool > 0 do
		table.insert(self.options, table.remove(pool, math.random(1, #pool)))
	end
	self.votes = {}
	self.open = true
	self:Push()
end

function VoteService:Counts()
	local counts = {}
	for _, key in self.options do
		counts[key] = 0
	end
	for p, key in self.votes do
		if p.Parent and counts[key] then
			counts[key] += 1
		end
	end
	return counts
end

function VoteService:Vote(player, key)
	if not self.open or not table.find(self.options, key) then
		return false
	end
	if self.votes[player] == key then
		return true
	end
	self.votes[player] = key
	self:Push()
	return true
end

-- The winning map (and closes the vote).
function VoteService:Winner()
	if #self.options == 0 then
		return nil
	end
	local counts = self:Counts()
	local best, bestN = {}, -1
	for _, key in self.options do
		local n = counts[key]
		if n > bestN then
			best, bestN = { key }, n
		elseif n == bestN then
			table.insert(best, key)
		end
	end
	local pick = best[math.random(1, #best)]
	self.open = false
	lastPlayed = pick
	self:Push()
	return pick
end

function VoteService:View()
	local counts = self:Counts()
	local list = {}
	for _, key in self.options do
		local m = Maps.byKey[key]
		table.insert(list, { key = key, name = m.name, emoji = m.emoji, votes = counts[key], color = m.accent })
	end
	return { open = self.open, options = list }
end

function VoteService:Push()
	Net.fireAll("Profile", { vote = self:View() })
end

function VoteService:Init()
	Net.on("Vote", function(player, key)
		if type(key) == "string" then
			self:Vote(player, key)
		end
	end)
end

function VoteService:OnPlayerLeaving(player)
	if self.votes[player] then
		self.votes[player] = nil
		self:Push()
	end
end

return VoteService
