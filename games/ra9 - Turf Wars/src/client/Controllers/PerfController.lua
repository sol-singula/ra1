--[[
How smoothly the game runs on this device, for the analytics (AnalyticsService "perf", and the fps on the live
snapshots): every PERIOD seconds, the average frames per second over it, the worst single second, and the
graphics tier (GraphicsController). Phones and PCs alike.

  PerfController.sample()   { fps, low, tier } over what's been counted so far (tests)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Net)
local GraphicsController = require(script.Parent.GraphicsController)

local PerfController = { Name = "PerfController", Order = 90 }

local PERIOD = 30
local frames, started = 0, os.clock()
local secFrames, secAt, low = 0, os.clock(), math.huge

function PerfController.sample()
	local dt = math.max(os.clock() - started, 1e-3)
	return {
		fps = math.floor(frames / dt * 10 + 0.5) / 10,
		low = low < math.huge and low or nil,
		tier = GraphicsController.tier(),
	}
end

local function reset()
	frames, started = 0, os.clock()
	secFrames, secAt, low = 0, os.clock(), math.huge
end

function PerfController:init()
	RunService.RenderStepped:Connect(function()
		frames += 1
		secFrames += 1
		local t = os.clock()
		if t - secAt >= 1 then
			low = math.min(low, secFrames / (t - secAt))
			secFrames, secAt = 0, t
		end
	end)
	task.spawn(function()
		task.wait(10) -- (the first report soon after loading in: that's when phones struggle most)
		while true do
			if frames > 0 then
				local s = PerfController.sample()
				s.low = s.low and math.floor(s.low + 0.5) or nil
				pcall(Net.send, "Analytics", "perf", s)
			end
			reset()
			task.wait(PERIOD)
		end
	end)
end

return PerfController
