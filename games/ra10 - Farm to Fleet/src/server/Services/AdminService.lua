--[[
The admin panel (Admins.isAdmin: Constants.ADMINS, xthirtysix). Net "AdminState" tells an admin's client it is one;
Net "Admin":
  ("reset", name)   wipes that farmer's save: in the server, their profile goes back to a brand-new one, is saved,
                    and they're sent to rejoin on a fresh farm; not in the server, the save is deleted by name
  ("give", name, cash)  Cash for a farmer in the server (testing)

  AdminService:Reset(target) -> ok, why
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Admins = require(script.Parent.Parent.Admins)
local Net = require(ReplicatedStorage.Shared.Net)

local AdminService = {
	Name = "AdminService",
	Dependencies = { "PlayerDataService", "EconomyService" },
}

local data, economy

local function find(name)
	name = string.lower(name)
	for _, p in Players:GetPlayers() do
		if string.lower(p.Name) == name or string.lower(p.DisplayName) == name then
			return p
		end
	end
	return nil
end

function AdminService:Reset(target)
	if typeof(target) == "Instance" then
		local ok = data:Reset(target)
		if ok then
			task.delay(0.5, function()
				if target.Parent then
					target:Kick("Your farm was reset by an admin. Rejoin to start fresh!")
				end
			end)
		end
		return ok, ok and "online" or "nosave"
	end
	-- (a name of someone not here: their save, by user id)
	local ok, userId = pcall(function()
		return Players:GetUserIdFromNameAsync(target)
	end)
	if not ok or type(userId) ~= "number" then
		return false, "noone"
	end
	return data:Wipe(userId), "offline"
end

function AdminService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	Net.on("Admin", function(player, what, name, amount)
		if not Admins.isAdmin(player) or type(name) ~= "string" or name == "" then
			return
		end
		if what == "reset" then
			local target = find(name)
			local ok, why = self:Reset(target or name)
			Net.fire(
				player,
				"Toast",
				ok and `Reset {name}'s farm ({why})`
					or ({ noone = "No one by that name", nosave = "Couldn't reset: no save" })[why]
					or "Couldn't reset",
				ok and "good" or "bad"
			)
		elseif what == "give" and type(amount) == "number" then
			local target = find(name)
			if target then
				economy:Add(target, math.floor(amount), "admin")
				Net.fire(player, "Toast", `Gave {name} ${math.floor(amount)}`, "good")
			end
		end
	end)
end

function AdminService:OnPlayerReady(player)
	if Admins.isAdmin(player) then
		data:WhenClientReady(player, function()
			Net.fire(player, "AdminState", { admin = true })
		end)
	end
end

return AdminService
