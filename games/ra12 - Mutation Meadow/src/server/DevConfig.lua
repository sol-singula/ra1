local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local RunService = game:GetService("RunService")
local DevConfig = {}
function DevConfig.isStudio()
	return RunService:IsStudio()
end
function DevConfig.isAllowed(player)
	return DevConfig.isStudio() or table.find(Config.AdminUserIds, player.UserId) ~= nil
end
return DevConfig
