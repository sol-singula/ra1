--[[
Earned only, never sold: goals (a stat to reach or a feat to pull off), and the two statuses, VIP and MVP. Each
comes with cosmetics nobody can buy (Data/Cosmetics, source goal / vip / mvp), so wearing one says what you did.

Everything here is worked out from the profile (its stats, its best streak), so nothing can drift out of step: you
have the reward exactly while the profile says you've done it.

  Achievements.goals                 { key, name, desc, stat, goal, reward }
  Achievements.progress(profile, g)  how far along (0..goal)
  Achievements.done(profile, g)
  Achievements.VIP                   what VIP takes (wins and MVPs: you earn it, it can't be bought)
  Achievements.isVip(profile)        earned (kept for good), or given by an admin (profile.vipUntil, os.time())
  Achievements.vipProgress(profile)  { wins, mvps, needWins, needMvps }
  Achievements.earned(profile)       [cosmeticKey] = true: every goal, VIP and MVP cosmetic this profile has
  Achievements.newly(before, after)  the goals done in `after` that weren't in `before` (the cards to show)
]]
local Achievements = {}

-- stat: a key of profile.stats, or "best" (the best win streak)
Achievements.goals = {
	{
		key = "sharp",
		name = "Sharpshooter",
		desc = "Land 100 headshots",
		stat = "headshots",
		goal = 100,
		reward = "goal_sharp",
	},
	{
		key = "longshot",
		name = "Long Shot",
		desc = "10 kills from 90 studs or more",
		stat = "longshots",
		goal = 10,
		reward = "goal_longshot",
	},
	{
		key = "triple",
		name = "Triple",
		desc = "3 kills within 6 seconds",
		stat = "triples",
		goal = 1,
		reward = "goal_triple",
	},
	{
		key = "headhunter",
		name = "Headhunter",
		desc = "5 headshot kills in one match",
		stat = "hsBest",
		goal = 5,
		reward = "goal_headhunter",
	},
	{
		key = "comeback",
		name = "Comeback Kid",
		desc = "Win after your team was nearly pushed off",
		stat = "comebacks",
		goal = 1,
		reward = "goal_comeback",
	},
	{
		key = "bulldozer",
		name = "Bulldozer",
		desc = "Push the frontline 500 cells",
		stat = "pushed",
		goal = 500,
		reward = "goal_bulldozer",
	},
	{
		key = "architect",
		name = "Architect",
		desc = "Build 1,000 structures",
		stat = "built",
		goal = 1000,
		reward = "goal_architect",
	},
	{
		key = "unbroken",
		name = "Unbroken",
		desc = "Win 10 matches in a row",
		stat = "best",
		goal = 10,
		reward = "goal_unbroken",
	},
	{
		key = "marathon",
		name = "Marathoner",
		desc = "Play for 10 hours",
		stat = "minutes",
		goal = 600,
		reward = "goal_marathon",
	},
	{
		key = "centurion",
		name = "Centurion",
		desc = "1,000 kills",
		stat = "kills",
		goal = 1000,
		reward = "goal_centurion",
	},
}

Achievements.byKey = {}
for _, g in Achievements.goals do
	Achievements.byKey[g.key] = g
end

-- VIP: earned by playing well for a long while (tune here). Kept forever once earned.
Achievements.VIP = {
	wins = 50,
	mvps = 10,
	rewards = { "vip_title", "vip_trail", "vip_effect", "vip_skin" },
	perks = "A VIP tag over your head, a black halo, and four VIP-only cosmetics",
}
-- MVP: the match's MVP wears the MVP crown through the next match; lifetime MVPs unlock these
Achievements.MVP = { { mvps = 10, reward = "mvp_title" }, { mvps = 25, reward = "mvp_effect" } }

local function stat(profile, name)
	if name == "best" then
		return profile.best or 0
	end
	return (profile.stats or {})[name] or 0
end

function Achievements.progress(profile, g)
	return math.min(g.goal, stat(profile, g.stat))
end

function Achievements.done(profile, g)
	return stat(profile, g.stat) >= g.goal
end

function Achievements.isVip(profile)
	if profile.vip then
		return true -- (kept once earned, even if the numbers were ever reset)
	end
	if type(profile.vipUntil) == "number" and profile.vipUntil > os.time() then
		return true -- (given by an admin for a while)
	end
	return (profile.wins or 0) >= Achievements.VIP.wins and stat(profile, "mvps") >= Achievements.VIP.mvps
end

function Achievements.vipProgress(profile)
	return {
		wins = math.min(profile.wins or 0, Achievements.VIP.wins),
		mvps = math.min(stat(profile, "mvps"), Achievements.VIP.mvps),
		needWins = Achievements.VIP.wins,
		needMvps = Achievements.VIP.mvps,
	}
end

function Achievements.earned(profile)
	local out = {}
	for _, g in Achievements.goals do
		if Achievements.done(profile, g) then
			out[g.reward] = true
		end
	end
	if Achievements.isVip(profile) then
		for _, k in Achievements.VIP.rewards do
			out[k] = true
		end
	end
	for _, m in Achievements.MVP do
		if stat(profile, "mvps") >= m.mvps then
			out[m.reward] = true
		end
	end
	return out
end

function Achievements.newly(before, after)
	local out = {}
	for _, g in Achievements.goals do
		if Achievements.done(after, g) and not Achievements.done(before, g) then
			table.insert(out, g)
		end
	end
	return out
end

return Achievements
