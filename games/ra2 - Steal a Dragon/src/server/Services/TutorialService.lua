-- First-time tutorial: 8 short steps with an arrow on the next thing to touch. Progress is read from the
-- game state every quarter second, so it never gets stuck on a missed event. Ends with the first egg.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local TutorialService = {
	Name = "TutorialService",
	Dependencies = { "PlayerDataService", "DragonService", "BaseService", "RoadService", "RewardService" },
}

local data, dragons, baseService, road, reward
local state = {} -- [player] = { step, sent, doneAt, collected }

local function hasNestDragon(profile)
	for _, rec in profile.dragons do
		if rec.slot then
			return true
		end
	end
	return false
end

-- Each step: text, target (instance to point at), done(player, profile, s) -> bool
local STEPS = {
	{
		text = "Grab the FREE dragon! Walk up to it and tap GRAB.",
		target = function()
			return road.freeModel
		end,
		done = function(player, profile)
			return dragons:Carrying(player) ~= nil or #profile.dragons > 0
		end,
	},
	{
		text = "Run to your base! Follow the arrow. 🏠",
		target = function(player)
			local base = baseService:Get(player)
			return base and base.world.laser
		end,
		done = function(_, profile)
			return hasNestDragon(profile)
		end,
	},
	{
		text = "Your dragon makes coins! Step on the GOLD pad to grab them. 💰",
		target = function(player)
			local base = baseService:Get(player)
			return base and base.world.collectPad
		end,
		done = function(_, profile, s)
			return s.collected or profile.earned > 0
		end,
	},
	{
		text = "Step on the RED pad to LOCK your door. Then no one can steal! 🔒",
		target = function(player)
			local base = baseService:Get(player)
			return base and base.world.lockPad
		end,
		done = function(_, profile)
			return profile.stats.locks > 0
		end,
	},
	{
		text = "Now YOU steal! Go to the Practice Base and steal Frosty. 😈",
		target = function()
			return road.practiceModel
		end,
		done = function(_, profile)
			return profile.stats.practice > 0
		end,
	},
	{
		text = "Run home with Frosty! Don't get bonked! 🏃",
		target = function(player)
			local base = baseService:Get(player)
			return base and base.world.laser
		end,
		done = function(player)
			return dragons:Carrying(player) == nil
		end,
	},
	{
		text = "Buy a dragon on the Dragon Road! Puff costs 25 coins.",
		target = function()
			local map = workspace:FindFirstChild("Map")
			local roadModel = map and map:FindFirstChild("DragonRoad")
			return roadModel and roadModel:FindFirstChild("Road")
		end,
		done = function(_, profile)
			return profile.stats.bought > 0
		end,
	},
	{
		text = "Take it home! You're ready: steal, lock your door and get rich! 🐉",
		target = function(player)
			local base = baseService:Get(player)
			return base and base.world.laser
		end,
		done = function(player)
			return dragons:Carrying(player) == nil
		end,
	},
}
TutorialService.STEP_COUNT = #STEPS

function TutorialService:Init(registry)
	data = registry.PlayerDataService
	dragons = registry.DragonService
	baseService = registry.BaseService
	road = registry.RoadService
	reward = registry.RewardService
	Net.on("SkipTutorial", function(player)
		if state[player] then
			self:_finish(player, true)
		end
	end)
	baseService.Collected:Connect(function(player)
		if state[player] then
			state[player].collected = true
		end
	end)
	data.ClientReady:Connect(function(player)
		if state[player] then
			state[player].sent = nil -- resend the current step
		end
	end)
end

function TutorialService:OnPlayerReady(player, profile)
	if profile.tutorialDone then
		return
	end
	-- someone who already has a dragon in a nest skips the first two steps
	state[player] = { step = hasNestDragon(profile) and 3 or 1 }
end

function TutorialService:OnPlayerLeaving(player)
	state[player] = nil
end

function TutorialService:Step(player)
	return state[player] and state[player].step
end

function TutorialService:_finish(player, skipped)
	local profile = data:Get(player)
	state[player] = nil
	if not profile then
		return
	end
	profile.tutorialDone = true
	Net.fire(player, "Tutorial", false)
	reward:GiveEgg(player)
	reward:PushAll(player)
	if not skipped then
		Net.fire(player, "Alert", "Here is a gift EGG! It hatches in 2 HOURS! 🥚", Color3.fromRGB(255, 205, 50))
	end
end

function TutorialService:_tick(player)
	local s = state[player]
	local profile = data:Get(player)
	if not s or not profile then
		return
	end
	local step = STEPS[s.step]
	if step.done(player, profile, s) then
		s.step += 1
		s.sent = nil
		if s.step > #STEPS then
			self:_finish(player, false)
			return
		end
		step = STEPS[s.step]
	end
	if s.sent ~= s.step then
		s.sent = s.step
		Net.fire(player, "Tutorial", { step = s.step, total = #STEPS, text = step.text, target = step.target(player) })
	end
end

function TutorialService:Start()
	while true do
		task.wait(0.25)
		for _, player in Players:GetPlayers() do
			self:_tick(player)
		end
	end
end

return TutorialService
