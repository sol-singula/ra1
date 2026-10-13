-- Analytics from the player's device (the server adds everything else, see AnalyticsService):
--   client_info  once: phone/computer/console, screen size, graphics quality
--   ui           every 20 s: how many times each button was tapped
--   perf         every minute: frames per second and memory
--   focus        when the Roblox window loses or gets focus (tabbed out, phone locked)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local Theme = require(script.Parent.Parent.UI.Theme)

local player = Players.LocalPlayer

local AnalyticsController = { Name = "AnalyticsController", Order = 90 }

local taps = {}
local tapCount = 0
local frames = 0
local hooked = setmetatable({}, { __mode = "k" })

-- A short, stable name for a button: its own name, or its parent's when it has a generic one.
local function buttonName(b)
	local name = b.Name
	if name == "TextButton" or name == "ImageButton" or name == "Button" then
		name = (b.Parent and b.Parent.Name or "?") .. "/" .. name
	end
	return string.sub(name, 1, 40)
end

local function hook(b)
	if hooked[b] or not b:IsA("GuiButton") then
		return
	end
	hooked[b] = true
	b.Activated:Connect(function()
		local name = buttonName(b)
		taps[name] = (taps[name] or 0) + 1
		tapCount += 1
	end)
end

local function send(kind, payload)
	pcall(Net.send, "Analytics", kind, payload)
end

function AnalyticsController:init()
	task.defer(function()
		local cam = workspace.CurrentCamera
		local size = cam and cam.ViewportSize
		local quality
		pcall(function()
			quality = UserSettings().GameSettings.SavedQualityLevel.Value
		end)
		send("client_info", {
			device = Theme.inputKind(),
			screen = size and `{math.floor(size.X)}x{math.floor(size.Y)}` or nil,
			touch = UserInputService.TouchEnabled,
			keyboard = UserInputService.KeyboardEnabled,
			gamepad = UserInputService.GamepadEnabled,
			vr = UserInputService.VREnabled,
			quality = quality,
		})
	end)
	local gui = player:WaitForChild("PlayerGui")
	local function scan()
		for _, d in gui:GetDescendants() do
			hook(d)
		end
	end
	scan()
	if not pcall(function()
		gui.DescendantAdded:Connect(hook)
	end) then
		task.spawn(function() -- (no DescendantAdded: look again now and then)
			while true do
				task.wait(5)
				scan()
			end
		end)
	end
	pcall(function()
		UserInputService.WindowFocusReleased:Connect(function()
			send("focus", { on = false })
		end)
		UserInputService.WindowFocused:Connect(function()
			send("focus", { on = true })
		end)
	end)
	RunService.RenderStepped:Connect(function()
		frames += 1
	end)
	task.spawn(function()
		local t = 0
		local lastFrames, lastClock = 0, os.clock()
		while true do
			task.wait(20)
			t += 20
			if tapCount > 0 then
				send("ui", { taps = taps })
				taps, tapCount = {}, 0
			end
			if t % 60 == 0 then
				local dt = os.clock() - lastClock
				local mem
				pcall(function()
					mem = math.floor(game:GetService("Stats"):GetTotalMemoryUsageMb())
				end)
				send("perf", { fps = dt > 0 and math.floor((frames - lastFrames) / dt) or nil, mem_mb = mem })
				lastFrames, lastClock = frames, os.clock()
			end
		end
	end)
end

return AnalyticsController
