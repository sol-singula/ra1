-- The map vote in the lobby: three glowing pads by the PLAY pad each show a map (three of the four, never the one
-- just played). Stand on a pad (or tap its name on screen) to vote. The map with the most votes is next; a tie
-- or no votes picks at random among the three.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Net = require(ReplicatedStorage.Shared.Net)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local VoteService = {
	Name = "VoteService",
	Dependencies = { "PlayerDataService", "CombatService", "RoundService" },
	options = {}, -- map keys on the three pads
	votes = {}, -- [player] = map key
	open = false,
}

local combat, round
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
	self:_draw()
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
	self:_draw()
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
	self:_draw()
	self:Push()
	return pick
end

function VoteService:_draw()
	local counts = self:Counts()
	for i, padInfo in WorldBuilder.layout.votePads do
		local key = self.options[i]
		local m = key and Maps.byKey[key]
		local sign = padInfo.part:FindFirstChild("Sign")
		if sign then
			sign.Enabled = self.open and m ~= nil
		end
		if m then
			padInfo.labels[1].Text = `{m.emoji} {string.upper(m.name)}`
			padInfo.labels[1].TextColor3 = m.accent
			local n = counts[key] or 0
			padInfo.labels[2].Text = `{n} vote{n == 1 and "" or "s"}`
		end
	end
end

function VoteService:View()
	local counts = self:Counts()
	local list = {}
	for _, key in self.options do
		local m = Maps.byKey[key]
		table.insert(list, { key = key, name = m.name, emoji = m.emoji, votes = counts[key] })
	end
	return { open = self.open, options = list }
end

function VoteService:Push()
	Net.fireAll("Profile", { vote = self:View() })
end

function VoteService:Init(registry)
	combat = registry.CombatService
	round = registry.RoundService
	Net.on("Vote", function(player, key)
		if type(key) == "string" then
			self:Vote(player, key)
		end
	end)
	self:_draw()
end

function VoteService:Start()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.3 or not self.open then
			return
		end
		acc = 0
		for _, p in Players:GetPlayers() do
			local r = combat.root(p)
			if r and combat.zone(p) == "lobby" then
				for i, padInfo in WorldBuilder.layout.votePads do
					if self.options[i] and WorldBuilder.onPad(padInfo, r.Position) then
						self:Vote(p, self.options[i])
					end
				end
			end
		end
	end)
	_ = round
end

function VoteService:OnPlayerLeaving(player)
	if self.votes[player] then
		self.votes[player] = nil
		self:_draw()
	end
end

return VoteService
