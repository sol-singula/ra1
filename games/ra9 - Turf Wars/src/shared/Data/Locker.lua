--[[
What a profile owns, from every source at once (Data/Cosmetics lists the sources). The server checks equips with it,
the client's locker shows it. Earned things are worked out from the profile each time, bought things are kept in
profile.owned.

  Locker.owns(profile, key)     true if this cosmetic is theirs
  Locker.how(item)              how it's had, in words ("Win 34", "Shop", "Season 2 Pass", "VIP"...)
]]
local Achievements = require(script.Parent.Achievements)
local Cosmetics = require(script.Parent.Cosmetics)
local Extras = require(script.Parent.Extras)
require(script.Parent.Season) -- (so season items resolve)

local Locker = {}

function Locker.owns(profile, key)
	local it = Cosmetics.get(key)
	if not it or not profile then
		return false
	end
	local src = it.source
	if src == "ladder" then
		return (profile.wins or 0) >= it.win
	elseif src == "extra" then
		return Extras.owns(profile, key)
	elseif src == "goal" or src == "vip" or src == "mvp" then
		return Achievements.earned(profile)[key] == true
	end
	return type(profile.owned) == "table" and profile.owned[key] == true -- shop, pass, starter
end

function Locker.how(it)
	if not it then
		return ""
	end
	local src = it.source
	if src == "ladder" then
		return `Win {it.win}`
	elseif src == "shop" then
		return "Shop"
	elseif src == "pass" then
		return `Season {it.season} Pass`
	elseif src == "vip" then
		return "VIP only"
	elseif src == "mvp" then
		return `{it.mvps} MVPs`
	elseif src == "starter" then
		return "Starter Pack"
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
