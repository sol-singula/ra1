-- Duels: two players stand on the DUEL pad in the lobby for a moment and they're off to the duel arena (a small
-- Castle Court of their own) for a 1v1: first to 5 pops wins coins. One duel at a time. A round starting doesn't
-- pull duellers out. If one leaves, the other wins.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local MapBuilder = require(script.Parent.Parent.World.MapBuilder)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local DuelService = {
	Name = "DuelService",
	Dependencies = { "PlayerDataService", "EconomyService", "CombatService" },
	duel = nil, -- { players = { a, b }, score = { [p] = n } }
	map = nil,
	Ended = Signal.new("DuelService.Ended"), -- (winner, loser)
}

local data, economy, combat
local onPadSince = {} -- [player] = os.clock() they stepped on the pad

local function lineText(d)
	local a, b = d.players[1], d.players[2]
	return `⚔️ {a.DisplayName} {d.score[a]} - {d.score[b]} {b.DisplayName}`
end

function DuelService:Start_(a, b)
	if self.duel then
		return false
	end
	self.duel = { players = { a, b }, score = { [a] = 0, [b] = 0 } }
	for _, p in { a, b } do
		combat:Release(p)
		combat.setZone(p, "duel")
		combat:Respawn(p)
	end
	Net.fire(a, "Alert", `⚔️ DUEL vs {b.DisplayName}! First to {Constants.DUEL_TO}`, Color3.fromRGB(255, 120, 120))
	Net.fire(b, "Alert", `⚔️ DUEL vs {a.DisplayName}! First to {Constants.DUEL_TO}`, Color3.fromRGB(255, 120, 120))
	self:_drawPad()
	return true
end

function DuelService:End(winner, loser)
	local d = self.duel
	if not d then
		return
	end
	self.duel = nil
	for _, p in d.players do
		if p.Parent then
			combat:Release(p)
			combat.setZone(p, "lobby")
			local r = combat.root(p)
			if r then
				local pad = WorldBuilder.layout.duelPad.center
				r.CFrame = CFrame.new(pad + Vector3.new(math.random(-6, 6), 3, -10))
			end
		end
	end
	if winner and winner.Parent then
		local profile = data:Get(winner)
		if profile then
			profile.stats.duelWins += 1
		end
		local coins = economy:AddCoins(winner, Constants.DUEL_COINS)
		Net.fire(winner, "Alert", `🏆 You won the duel! +{coins} coins`, Color3.fromRGB(255, 215, 60))
		Net.fire(winner, "Sfx", "win")
	end
	if loser and loser.Parent then
		Net.fire(loser, "Alert", "Good duel! Try again?", Color3.fromRGB(200, 200, 220))
	end
	self.Ended:Fire(winner, loser)
	self:_drawPad()
end

function DuelService:_drawPad()
	local labels = WorldBuilder.layout.duelPad.labels
	if self.duel then
		labels[2].Text = "A duel is on..."
	else
		labels[2].Text = "2 players: first to " .. Constants.DUEL_TO
	end
end

function DuelService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	combat = registry.CombatService
	self.map =
		MapBuilder.build("CASTLE", "small", workspace:FindFirstChild("Map") or workspace, WorldBuilder.DUEL_CENTER)
	self.map.model.Name = "DuelArena"
	local H = self.map.half
	local c = self.map.center
	combat.zones.duel = {
		geometry = function()
			return { self.map.model }
		end,
		spawn = function(f)
			local d = self.duel
			local first = d and d.players[1] == f
			local z = (first and -1 or 1) * (H - 8)
			local p = c + Vector3.new(math.random(-8, 8), 3, z)
			return CFrame.lookAt(p, Vector3.new(c.X, p.Y, c.Z))
		end,
		onPop = function(killer, victim)
			local d = self.duel
			if not d or not killer or killer.robot or not d.score[killer] then
				return
			end
			d.score[killer] += 1
			local text = lineText(d)
			for _, p in d.players do
				Net.fire(p, "Toast", text, "info")
			end
			if d.score[killer] >= Constants.DUEL_TO then
				task.defer(function()
					self:End(killer, victim)
				end)
			end
		end,
		fallY = function()
			return c.Y + Constants.FALL_Y
		end,
	}
	self:_drawPad()
end

function DuelService:Start()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		if self.duel then
			return
		end
		local pad = WorldBuilder.layout.duelPad
		local ready = {}
		local t = os.clock()
		for _, p in Players:GetPlayers() do
			local r = combat.root(p)
			if r and combat.zone(p) == "lobby" and WorldBuilder.onPad(pad, r.Position) then
				onPadSince[p] = onPadSince[p] or t
				if t - onPadSince[p] >= 1.5 then
					table.insert(ready, p)
				end
			else
				onPadSince[p] = nil
			end
		end
		if #ready >= 2 then
			onPadSince[ready[1]] = nil
			onPadSince[ready[2]] = nil
			self:Start_(ready[1], ready[2])
		end
	end)
end

function DuelService:OnPlayerLeaving(player)
	onPadSince[player] = nil
	local d = self.duel
	if d and d.score[player] then
		local other = d.players[1] == player and d.players[2] or d.players[1]
		self:End(other, player)
	end
end

return DuelService
