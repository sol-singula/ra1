--[[
Who is an admin, and who is watching unseen. A small module (not a service) so every service can ask without
depending on AdminService.

An admin is a user id in Constants.ADMINS (the username in Constants.ADMIN_NAMES works too, but only in Studio).

A spectating admin is in the server but not in the match: no body, no team, not counted, never hit, never in the
kill feed or the results. They spectate when they join from the server list (teleport data { adminSpectate =
true }) or when they turn it on in the panel. The "Spectating" attribute on the Player says so (true / false);
it's settled the first time anyone asks, so it doesn't matter which service asks first.

  Admins.isAdmin(player)
  Admins.spectating(player)          true while an admin watches unseen (bots and nil: false)
  Admins.setSpectating(player, on)   (AdminService)
  Admins.joinFlag(player)            true if they came in from the server list to spectate
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)

local Admins = {}

function Admins.isAdmin(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return false -- (bots, nil)
	end
	if Constants.ADMINS[player.UserId] == true then
		return true
	end
	return RunService:IsStudio() and Constants.ADMIN_NAMES[player.Name] == true
end

function Admins.joinFlag(player)
	local ok, joinData = pcall(function()
		return player:GetJoinData()
	end)
	local td = ok and type(joinData) == "table" and joinData.TeleportData or nil
	return type(td) == "table" and td.adminSpectate == true
end

-- Out of the match: an admin watching unseen, or anyone sent to the AFK limbo (AfkService). Either way they have
-- no team, aren't counted (bots fill in), can't be hit and aren't in the results.
function Admins.spectating(player)
	if player:GetAttribute("Limbo") == true then
		return true
	end
	if not Admins.isAdmin(player) then
		return false
	end
	local v = player:GetAttribute("Spectating")
	if v == nil then
		v = Admins.joinFlag(player)
		player:SetAttribute("Spectating", v)
	end
	return v == true
end

function Admins.setSpectating(player, on)
	player:SetAttribute("Spectating", on == true and Admins.isAdmin(player))
end

return Admins
