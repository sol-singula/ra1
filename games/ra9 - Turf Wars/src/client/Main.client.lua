-- Client bootstrap: landscape on phones, start the controllers, then tell the server the UI is listening.
--
-- Modes (Constants.MODE): a controller may declare Modes = { "lobby", ... } and runs only in those. In the lobby,
-- one that declares nothing runs only if it's in LOBBY below (the match's HUD, weapons and building stay quiet
-- there); in a match mode everything runs. (A stub until the framework's version lands.)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Store = require(script.Parent.Store)
local Layout = require(script.Parent.UI.Layout)
local Theme = require(script.Parent.UI.Theme)

-- The controllers the lobby runs besides its own: the camera (third person there), graphics and perf, the sound,
-- the banners, the shop panel, the leaderboards
local LOBBY = {
	CameraController = true,
	GraphicsController = true,
	PerfController = true,
	AudioController = true,
	NotifyController = true,
	PanelController = true,
	LeaderboardController = true,
}

Net.init()
Store.init()
Theme.watchScale()
Layout.lobby(Constants.MODE == "lobby")
pcall(function()
	Players.LocalPlayer:WaitForChild("PlayerGui").ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor
end)

local function runsHere(controller)
	if type(controller.Modes) == "table" then
		return table.find(controller.Modes, Constants.MODE) ~= nil
	end
	return Constants.MODE ~= "lobby" or LOBBY[controller.Name] == true
end

local controllers = {}
for _, module in script.Parent.Controllers:GetChildren() do
	if module:IsA("ModuleScript") then
		local controller = require(module)
		if runsHere(controller) then
			table.insert(controllers, controller)
		end
	end
end
table.sort(controllers, function(a, b)
	return (a.Order or 50) < (b.Order or 50)
end)
for _, controller in controllers do
	local ok, err = xpcall(controller.init, debug.traceback, controller)
	if not ok then
		warn(`[Client] {controller.Name} failed to start: {err}`)
	end
end

Net.send("Ready")
