-- Roblox Experience Notifications (opt in to update alerts), from the player's side.
-- NotifyController.canAsk() says whether Roblox will show the opt-in prompt (false once they're on the list, or
-- when their account can't get notifications). NotifyController.prompt() opens it; when it closes we ask again:
-- if Roblox can no longer ask, they said yes. Every result goes to the server ("Notify"), which logs it, so the
-- dashboard can count how many players are on the list. Once a session the status is reported too, so players
-- who later turn notifications off drop off the count.
local Net = require(game:GetService("ReplicatedStorage").Shared.Net)

local NotifyController = { Name = "NotifyController", Order = 15 }

local service
pcall(function()
	service = game:GetService("ExperienceNotificationService")
end)

function NotifyController.canAsk()
	if not service then
		return false
	end
	local ok, can = pcall(service.CanPromptOptInAsync, service)
	return ok and can == true
end

local waiting = false
function NotifyController.prompt()
	if not service or waiting then
		return
	end
	waiting = true
	local ok = pcall(service.PromptOptIn, service)
	if not ok then
		waiting = false
	end
end

function NotifyController:init()
	if not service then
		return
	end
	pcall(function()
		service.OptInPromptClosed:Connect(function()
			waiting = false
			task.wait(0.5)
			Net.send("Notify", NotifyController.canAsk() and "off" or "on")
		end)
	end)
	task.delay(20, function()
		Net.send("Notify", "status", NotifyController.canAsk())
	end)
end

return NotifyController
