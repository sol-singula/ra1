--[[
Progression (master plan §8): stats, qualifying wins, the 100-win ladder, streaks, MVPs, and what a match pays:
Shards (Data/Shop) and Turf Pass XP (Data/Season). The goals, VIP and MVP rewards (Data/Achievements) come
from the stats, so each match's end is also when a newly reached goal is announced.

At the end of every match MatchService calls Award for each player with how it went. A qualifying win
(Formulas.qualifies: on the winning team, in the match QUALIFY_SECONDS or more, not idle) adds a win, unlocks the
ladder's next step (Data/Ladder: every 10th a big one) and grows the streak (badges at 3, 5 and 10). A loss ends
the streak. Stats add up either way.

  ProgressService:Award(player, info) -> step, earned   info: { won, seconds, active, kills, deaths, assists,
                        built, shots, hits, headshots, pushed, longshots, triples, comeback, mvp }
                        earned: { shards, xp, tiers }
  ProgressService:View(player)          what the client shows (Net "Profile")
  ProgressService:Push(player)          sends it, and puts what they wear on the Player's attributes (StatusService
                                        and every client read those)
  ProgressService:GrantExtra(player, key, card)
  ProgressService:AddMvp(player)        an admin's MVP (counted like a real one)
  ProgressService:SetVip(player, s)     an admin's VIP: seconds | true (for good) | false (taken away)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Achievements = require(ReplicatedStorage.Shared.Data.Achievements)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Extras = require(ReplicatedStorage.Shared.Data.Extras)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Ladder = require(ReplicatedStorage.Shared.Data.Ladder)
local Locker = require(ReplicatedStorage.Shared.Data.Locker)
local Net = require(ReplicatedStorage.Shared.Net)
local Notify = require(script.Parent.Parent.Notify)
local Season = require(ReplicatedStorage.Shared.Data.Season)
local Shop = require(ReplicatedStorage.Shared.Data.Shop)
local Signal = require(ReplicatedStorage.Shared.Signal)

local ProgressService = {
	Name = "ProgressService",
	Dependencies = { "PlayerDataService", "EconomyService", "SeasonService" },
	Unlocked = Signal.new("ProgressService.Unlocked"), -- (player, step)
	Earned = Signal.new("ProgressService.Earned"), -- (player, key) a goal, VIP or MVP reward newly earned
}

local data, economy, season

local LOOK_ATTR =
	{ trail = "LookTrail", skin = "LookSkin", effect = "LookEffect", banner = "LookBanner", title = "LookTitle" }
ProgressService.LOOK_ATTR = LOOK_ATTR

function ProgressService:View(player)
	local p = data:Get(player)
	if not p then
		return nil
	end
	local s = season:State(player)
	local info = Season.at(math.floor(workspace:GetServerTimeNow()))
	return {
		wins = p.wins,
		streak = p.streak,
		best = p.best,
		stats = p.stats,
		equipped = p.equipped,
		extras = p.extras,
		owned = p.owned,
		shards = p.shards or 0,
		vip = Achievements.isVip(p),
		season = {
			n = s.n,
			name = Season.name(s.n),
			endsAt = info.endsAt,
			xp = s.xp,
			tier = Season.tierOf(s.xp),
			premium = s.premium,
			claimed = s.claimed,
		},
		starter = p.starter == true,
		settings = p.settings,
		next = Ladder.at(p.wins + 1),
		ladder = Constants.LADDER,
	}
end

function ProgressService:Push(player)
	local v = self:View(player)
	if v then
		for kind, attr in LOOK_ATTR do
			player:SetAttribute(attr, v.equipped[kind])
		end
		player:SetAttribute("VIP", v.vip)
		Net.fire(player, "Profile", v)
	end
end

-- A reward card in the popup stack (the HUD's Unlock card)
local function card(player, key, title, line)
	local it = Cosmetics.get(key)
	if not it then
		return
	end
	Net.fire(player, "Unlock", {
		extra = true,
		title = title,
		line = line,
		step = { kind = it.kind, key = it.key, name = it.name },
	})
end
ProgressService.card = card

local function snapshot(p)
	return { wins = p.wins, best = p.best, vip = p.vip, vipUntil = p.vipUntil, stats = table.clone(p.stats) }
end

-- An MVP from an admin: counted like a real one (the lifetime MVPs, their rewards' cards). The crown is
-- StatusService's.
function ProgressService:AddMvp(player)
	local p = data:Get(player)
	if not p then
		return false
	end
	local before = snapshot(p)
	p.stats.mvps = (p.stats.mvps or 0) + 1
	self:Celebrate(player, before)
	self:Push(player)
	return true
end

-- VIP from an admin: seconds (for a while), true (for good) or false (taken away: what an admin gave goes; VIP
-- earned from wins and MVPs stays, the numbers still say so).
function ProgressService:SetVip(player, seconds)
	local p = data:Get(player)
	if not p then
		return false
	end
	local had = Achievements.isVip(p)
	if seconds == false then
		p.vip = false
		p.vipUntil = 0
	elseif seconds == true then
		p.vip = true
	elseif type(seconds) == "number" and seconds > 0 then
		p.vipUntil = math.max(p.vipUntil or 0, os.time()) + math.floor(seconds)
	else
		return false
	end
	if Achievements.isVip(p) and not had then
		card(player, "vip_title", "YOU'RE VIP!", "The VIP tag, halo and 4 cosmetics")
		p.equipped.title = "vip_title"
		self.Earned:Fire(player, "vip")
	elseif not Achievements.isVip(p) then
		-- (the VIP cosmetics go with it: wear nothing there instead)
		for _, k in Achievements.VIP.rewards do
			local it = Cosmetics.get(k)
			if it and p.equipped[it.kind] == k and not Locker.owns(p, k) then
				p.equipped[it.kind] = nil
			end
		end
	end
	self:Push(player)
	return true
end

-- Goals, VIP and MVP rewards newly earned between two snapshots: worn at once if they're new, with a card each.
function ProgressService:Celebrate(player, before)
	local p = data:Get(player)
	if not p then
		return
	end
	local had = Achievements.earned(before)
	local now = Achievements.earned(p)
	if Achievements.isVip(p) and not Achievements.isVip(before) then
		p.vip = true -- (kept for good)
		card(player, "vip_title", "YOU'RE VIP!", "Earned, never bought: the VIP tag, halo and 4 cosmetics")
		p.equipped.title = "vip_title"
		Notify.all(`{player.DisplayName} is now VIP!`, "status", { icon = "⭐" })
		self.Earned:Fire(player, "vip")
	end
	for _, g in Achievements.newly(before, p) do
		local it = Cosmetics.get(g.reward)
		card(player, g.reward, `GOAL: {string.upper(g.name)}`, `{it.name} · {Cosmetics.KIND_NAME[it.kind]}`)
		p.equipped[it.kind] = it.key
		self.Earned:Fire(player, g.reward)
	end
	for _, m in Achievements.MVP do
		if now[m.reward] and not had[m.reward] then
			local it = Cosmetics.get(m.reward)
			card(player, m.reward, `{m.mvps} MVPS!`, `{it.name} · {Cosmetics.KIND_NAME[it.kind]}`)
			self.Earned:Fire(player, m.reward)
		end
	end
end

function ProgressService:Award(player, info)
	local p = data:Get(player)
	if not p then
		return nil, nil
	end
	local before = snapshot(p)
	local st = p.stats
	st.matches += 1
	for _, k in
		{ "kills", "deaths", "assists", "built", "shots", "hits", "headshots", "pushed", "longshots", "triples" }
	do
		st[k] = (st[k] or 0) + (info[k] or 0)
	end
	st.hsBest = math.max(st.hsBest or 0, info.headshots or 0)
	st.minutes = (st.minutes or 0) + math.floor((info.seconds or 0) / 60)
	if info.mvp then
		st.mvps += 1
	end
	local step
	local qualified = Formulas.qualifies(info)
	if qualified then
		p.wins += 1
		p.streak += 1
		p.best = math.max(p.best, p.streak)
		if info.comeback then
			st.comebacks = (st.comebacks or 0) + 1
		end
		step = Ladder.at(p.wins)
		local badge = Formulas.streakBadge(p.streak)
		if badge then
			p.badges[tostring(badge)] = true
			Notify.all(`{player.DisplayName} won {p.streak} in a row!`, "status", { icon = "🔥" })
		end
		if step and step.big then
			Notify.all(`{player.DisplayName} unlocked {step.name}!`, "status", { icon = "🏆" })
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
	-- what the match pays: Shards, and pass XP (the day's first match and first win pay more)
	local today = math.floor(workspace:GetServerTimeNow()) // 86400
	if type(p.daily) ~= "table" or p.daily.day ~= today then
		p.daily = { day = today, played = false, won = false }
	end
	local firstWin = qualified and not p.daily.won
	local shards = Shop.shardsFor({
		seconds = info.seconds,
		kills = info.kills,
		won = qualified,
		mvp = info.mvp,
	}, firstWin)
	local xp = Season.xpFor(info)
	if xp > 0 and not p.daily.played then
		xp += Season.DAILY_BONUS
	end
	if (info.seconds or 0) >= 60 then
		p.daily.played = true
	end
	if qualified then
		p.daily.won = true
	end
	economy:Add(player, shards, "match")
	local tiers = season:AddXP(player, xp)
	self:Celebrate(player, before)
	self:Push(player)
	return step, { shards = shards, xp = xp, tiers = tiers, firstWin = firstWin }
end

-- An extra (Data/Extras) for this player: owned and worn at once, with a card (Net "Unlock", extra = true).
-- card = { title, line? }. Returns true if it's new to them; an extra they own already isn't given twice (and the
-- card only shows if it has its own line to say).
function ProgressService:GrantExtra(player, key, c)
	local p = data:Get(player)
	local e = Extras.get(key)
	if not p or not e then
		return false
	end
	local fresh = not Extras.owns(p, key)
	if fresh then
		p.extras = p.extras or {}
		p.extras[e.id] = true
		p.equipped[e.kind] = e.key
	end
	if c and (fresh or c.line) then
		Net.fire(player, "Unlock", {
			extra = true,
			title = c.title,
			line = c.line,
			step = { kind = e.kind, key = e.key, name = e.name, desc = e.desc },
		})
	end
	if fresh then
		self:Push(player)
	end
	return fresh
end

-- Wear something you own (or nothing: key = false). Returns ok.
function ProgressService:Equip(player, kind, key)
	local p = data:Get(player)
	if not p or not LOOK_ATTR[kind] then
		return false
	end
	if key == false or key == "" then
		p.equipped[kind] = nil
		return true
	end
	local it = Cosmetics.get(key)
	if not it or it.kind ~= kind or not Locker.owns(p, key) then
		return false
	end
	p.equipped[kind] = key
	return true
end

function ProgressService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	season = registry.SeasonService
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
		elseif key == "device" and (value == "touch" or value == "gamepad" or value == "keyboard") then
			player:SetAttribute("Device", value) -- (how they play: the anti-cheat and the stats read it)
			return
		elseif key == "equip" and type(value) == "table" and type(value.kind) == "string" then
			-- (only what you own: Data/Locker knows every source)
			local item = value.key
			if item == nil then
				item = false -- (wear nothing)
			end
			self:Equip(player, value.kind, item)
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
