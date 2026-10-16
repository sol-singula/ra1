--[[
Progression (master plan §8): stats, qualifying wins, the 100-win ladder, streaks, MVPs.

At the end of every match MatchService calls Award for each player with how it went. A qualifying win
(Formulas.qualifies: on the winning team, in the match QUALIFY_SECONDS or more, not idle) adds a win, unlocks the
ladder's next step (Data/Ladder: every 10th a big one, announced to the server) and grows the streak (badges at 3,
5 and 10). A loss ends the streak. Stats add up either way.

  ProgressService:Award(player, info)   info: { won, seconds, active, kills, deaths, assists, built, shots, hits,
                                                 headshots, pushed, mvp }
  ProgressService:View(player)          what the client shows
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Extras = require(ReplicatedStorage.Shared.Data.Extras)
local Ladder = require(ReplicatedStorage.Shared.Data.Ladder)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local ProgressService = {
	Name = "ProgressService",
	Dependencies = { "PlayerDataService" },
	Unlocked = Signal.new("ProgressService.Unlocked"), -- (player, step)
}

local data

function ProgressService:View(player)
	local p = data:Get(player)
	if not p then
		return nil
	end
	return {
		wins = p.wins,
		streak = p.streak,
		best = p.best,
		stats = p.stats,
		equipped = p.equipped,
		extras = p.extras,
		settings = p.settings,
		next = Ladder.at(p.wins + 1),
		ladder = Constants.LADDER,
	}
end

function ProgressService:Push(player)
	local v = self:View(player)
	if v then
		Net.fire(player, "Profile", v)
	end
end

function ProgressService:Award(player, info)
	local p = data:Get(player)
	if not p then
		return nil
	end
	local st = p.stats
	st.matches += 1
	for _, k in { "kills", "deaths", "assists", "built", "shots", "hits", "headshots", "pushed" } do
		st[k] = (st[k] or 0) + (info[k] or 0)
	end
	st.minutes = (st.minutes or 0) + math.floor((info.seconds or 0) / 60)
	if info.mvp then
		st.mvps += 1
	end
	local step
	if Formulas.qualifies(info) then
		p.wins += 1
		p.streak += 1
		p.best = math.max(p.best, p.streak)
		step = Ladder.at(p.wins)
		local badge = Formulas.streakBadge(p.streak)
		if badge then
			p.badges[tostring(badge)] = true
		end
		if step then
			-- (the newest of each kind is worn straight away: you see what you just won)
			p.equipped[step.kind] = step.key
			Net.fire(player, "Unlock", { step = step, wins = p.wins, streak = p.streak, badge = badge })
			self.Unlocked:Fire(player, step)
		end
	elseif info.won == false then
		st.losses += 1
		p.streak = 0
	end
	self:Push(player)
	return step
end

function ProgressService:Init(registry)
	data = registry.PlayerDataService
	Net.on("Settings", function(player, key, value)
		local p = data:Get(player)
		if not p then
			return
		end
		if key == "flips" and type(value) == "boolean" then
			p.settings.flips = value
		elseif key == "sensitivity" and type(value) == "number" then
			p.settings.sensitivity = math.clamp(value, 0.2, 3)
		elseif key == "shake" and type(value) == "boolean" then
			p.settings.shake = value
		elseif key == "equip" and type(value) == "table" then
			-- (only what you've unlocked, on the ladder or as an extra)
			local k, item = value.kind, value.key
			for _, s in Ladder.unlocked(p.wins) do
				if s.kind == k and s.key == item then
					p.equipped[k] = item
				end
			end
			local e = Extras.get(item)
			if e and e.kind == k and Extras.owns(p, item) then
				p.equipped[k] = item
			end
		end
		self:Push(player)
	end)
end

function ProgressService:OnPlayerReady(player)
	data:WhenClientReady(player, function()
		self:Push(player)
	end)
end

return ProgressService
