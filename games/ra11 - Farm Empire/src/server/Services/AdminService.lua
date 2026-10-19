--[[
The admin panel (Constants.ADMINS): reset a save, give cash. Only an admin's client gets AdminState.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)

local AdminService = { Name = "AdminService", Dependencies = { "PlayerDataService", "EconomyService" } }

local data, economy

local function isAdmin(player)
	if Constants.ADMINS[player.UserId] then
		return true
	end
	return RunService:IsStudio() and Constants.ADMIN_NAMES[player.Name] == true
end

local function find(name)
	for _, p in Players:GetPlayers() do
		if
			string.lower(p.Name) == string.lower(tostring(name))
			or string.lower(p.DisplayName) == string.lower(tostring(name))
		then
			return p
		end
	end
	return nil
end

function AdminService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	Net.on("Admin", function(player, what, name, amount)
		if not isAdmin(player) then
			return
		end
		local target = find(name) or player
		if what == "reset" then
			data:Reset(target)
			if data.Rebuild then
				data.Rebuild(target)
			end
			Net.fire(player, "Toast", `{target.Name}'s farm reset`, "good")
		elseif what == "give" then
			economy:Add(target, math.clamp(tonumber(amount) or 0, 0, 1e9), "admin")
			Net.fire(player, "Toast", `gave {target.Name} ${amount}`, "good")
		end
	end)
end

function AdminService:OnPlayerReady(player)
	if isAdmin(player) then
		data:WhenClientReady(player, function()
			Net.fire(player, "AdminState", { admin = true })
		end)
	end
end

return AdminService
