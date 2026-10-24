-- Who may run DevCommands: Studio only. Config.AdminUserIds grants nothing on a live server.
local RunService = game:GetService("RunService")
local DevConfig = {}
function DevConfig.isStudio()
	return RunService:IsStudio()
end
function DevConfig.isAllowed(_player)
	return DevConfig.isStudio()
end
return DevConfig
