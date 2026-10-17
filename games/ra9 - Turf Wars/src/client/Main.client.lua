-- Client bootstrap: landscape on phones, start the controllers, then tell the server the UI is listening.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Store = require(script.Parent.Store)
local Theme = require(script.Parent.UI.Theme)

Net.init()
Store.init()
Theme.watchScale()
pcall(function()
	Players.LocalPlayer:WaitForChild("PlayerGui").ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor
end)

local controllers = {}
for _, module in script.Parent.Controllers:GetChildren() do
	if module:IsA("ModuleScript") then
		table.insert(controllers, require(module))
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
