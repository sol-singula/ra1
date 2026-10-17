--[[
What a profile owns, from every source at once (Data/Cosmetics lists the sources). The server checks equips with it,
the client's locker shows it. Earned things are worked out from the profile each time, bought things are kept in
profile.owned (an admin's gift goes there too, whatever the item's source).

  Locker.owns(profile, key)     true if this cosmetic is theirs
  Locker.every(seasonN)         every cosmetic key there is now
  Locker.how(item)              how it's had, in words ("Win 34", "Shop", "Season 2 Pass", "VIP"...)
]]
local Achievements = require(script.Parent.Achievements)
local Cosmetics = require(script.Parent.Cosmetics)
local Extras = require(script.Parent.Extras)
local Format = require(script.Parent.Parent.Format)
local Ladder = require(script.Parent.Ladder)
local Season = require(script.Parent.Season) -- (and so season items resolve)
local Shop = require(script.Parent.Shop)

local Locker = {}

function Locker.owns(profile, key)
	local it = Cosmetics.get(key)
	if not it or not profile then
		return false
	end
	if type(profile.owned) == "table" and profile.owned[key] == true then
		return true -- (bought, claimed, or given by an admin: whatever its source)
	end
	local src = it.source
	if src == "ladder" then
		return (profile.wins or 0) >= it.win
	elseif src == "extra" then
		return Extras.owns(profile, key)
	elseif src == "goal" or src == "vip" or src == "mvp" then
		return Achievements.earned(profile)[key] == true
	end
	return false -- shop, pass, starter: only in profile.owned
end

-- Every cosmetic there is now: the fixed ones, the ladder's, the extras, and season n's pass items (the admin
-- panel's list, UNLOCK ALL).
function Locker.every(n)
	local out = {}
	for _, it in Cosmetics.list do
		table.insert(out, it.key)
	end
	for _, s in Ladder.steps do
		table.insert(out, s.key)
	end
	for _, e in Extras.list do
		table.insert(out, e.key)
	end
	for tier = 1, Season.TIERS do
		for _, track in { "f", "p" } do
			local r = Season.reward(n, tier, track)
			if r and r.kind == "cosmetic" then
				table.insert(out, r.key)
			end
		end
	end
	return out
end

function Locker.how(it)
	if not it then
		return ""
	end
	local src = it.source
	if src == "ladder" then
		return `Win {it.win}`
	elseif src == "shop" then
		return `◆ {Shop.price(it)} · TAP TO BUY`
	elseif src == "pass" then
		return `Season {it.season} Pass`
	elseif src == "vip" then
		return "VIP only"
	elseif src == "mvp" then
		return `{it.mvps} MVPs`
	elseif src == "starter" then
		return "Starter Pack"
	elseif src == "robux" then
		return `{Format.robux(it.robux or 0)} · TAP TO GET`
	elseif src == "extra" then
		return it.desc or "Special"
	elseif src == "goal" then
		for _, g in Achievements.goals do
			if g.reward == it.key then
				return g.desc
			end
		end
	end
	return ""
end

return Locker
