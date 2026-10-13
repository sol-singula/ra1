-- Admins (Constants.ADMINS, by user id): a red "ADMIN" name tag, and an ADMIN button that opens the admin panel
-- (PanelController "Admin"). Everything the panel does is checked here, on the server:
--   giftvip <userId> <seconds>   gift VIP to a player in this server for a while (1 hour .. 30 days)
--   luck                         Server Luck for everyone (15 minutes)
--   legend / secret              put a Legend / Secret dragon on the road right now
--   day / night                  daytime or night-time in this server
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local AdminService = {
	Name = "AdminService",
	Dependencies = { "PlayerDataService", "EconomyService", "RoadService" },
	Used = Signal.new("AdminService.Used"), -- (admin, action, detail)
}

local data, economy, road

function AdminService.isAdmin(player)
	return player ~= nil and Constants.ADMINS[player.UserId] == true
end

local GIFT_TIMES = {}
for _, g in Constants.ADMIN_VIP_TIMES do
	GIFT_TIMES[g[1]] = true
end

local function timeText(seconds)
	if seconds >= 86400 then
		local d = math.floor(seconds / 86400)
		return d == 1 and "1 day" or `{d} days`
	end
	local h = math.floor(seconds / 3600)
	return h == 1 and "1 hour" or `{h} hours`
end

function AdminService:Do(admin, action, a, b)
	if not AdminService.isAdmin(admin) or type(action) ~= "string" then
		return false
	end
	if action == "giftvip" then
		local target = type(a) == "number" and Players:GetPlayerByUserId(a)
		if not target or not GIFT_TIMES[b] then
			return false
		end
		if not economy:GiftVip(target, b) then
			return false
		end
		Net.fireAll(
			"Announce",
			`👑 {target.DisplayName} got VIP for {timeText(b)} from an Admin!`,
			Color3.fromRGB(255, 205, 50)
		)
		Net.fire(
			target,
			"Alert",
			`👑 You got VIP for {timeText(b)}! Wings, +50% coins and more!`,
			Color3.fromRGB(255, 205, 50)
		)
		Net.fire(admin, "Toast", `Gave {target.DisplayName} VIP for {timeText(b)} ✓`, "good")
		self.Used:Fire(admin, action, `{target.Name} {timeText(b)}`)
		return true
	elseif action == "luck" then
		road:AddLuck(Constants.LUCK_SECONDS, admin.DisplayName)
		Net.fireAll("Alert", "🍀 SERVER LUCK from an Admin! Rare dragons for everyone!", Color3.fromRGB(80, 220, 120))
	elseif action == "legend" or action == "secret" then
		local entry = road:Spawn(action == "legend" and "Legend" or "Secret")
		if not entry then
			return false
		end
	elseif action == "day" or action == "night" then
		Lighting.ClockTime = action == "day" and 15.2 or 0.5
		Net.fireAll("Toast", action == "day" and "☀️ It's daytime!" or "🌙 It's night-time!", "info")
	else
		return false
	end
	Net.fire(admin, "Toast", "Done ✓", "good")
	self.Used:Fire(admin, action, nil)
	return true
end

function AdminService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	road = registry.RoadService
	Net.on("Admin", function(player, action, a, b)
		self:Do(player, action, a, b)
	end)
	data.ClientReady:Connect(function(player)
		if AdminService.isAdmin(player) then
			data:Push(player, { admin = true })
		end
	end)
end

function AdminService:OnPlayerReady(player)
	if AdminService.isAdmin(player) then
		data:Push(player, { admin = true })
	end
end

return AdminService
