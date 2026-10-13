-- First-time tutorial: 4 short numbered GOALS with a glowing path to the next thing to touch. Progress is read from the
-- game state every quarter second, so it never gets stuck on a missed event. Ends with the first egg.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local TutorialService = {
	Name = "TutorialService",
	Dependencies = { "PlayerDataService", "DragonService", "BaseService", "RoadService", "RewardService" },
	StepShown = Signal.new("TutorialService.StepShown"), -- (player, step, total, text) a goal appeared
	Finished = Signal.new("TutorialService.Finished"), -- (player, skipped)
}

local data, dragons, baseService, road, reward
local state = {} -- [player] = { step, sent, doneAt, collected, glowing }

-- Light up a part for the current goal (and put out the last one).
local function setGlow(s, part)
	if s.glowing and s.glowing ~= part then
		local old = s.glowing:FindFirstChild("TutorialGlow")
		if old then
			old:Destroy()
		end
		s.glowing.Material = s.glowMaterial or s.glowing.Material
		s.glowing = nil
	end
	if part and not part:FindFirstChild("TutorialGlow") then
		s.glowing, s.glowMaterial = part, part.Material
		part.Material = Enum.Material.Neon
		local h = Instance.new("Highlight")
		h.Name = "TutorialGlow"
		h.FillColor = Color3.fromRGB(255, 220, 80)
		h.FillTransparency = 0.35
		h.OutlineColor = Color3.fromRGB(255, 255, 255)
		h.Parent = part
	end
end

local function hasNestDragon(profile)
	for _, rec in profile.dragons do
		if rec.slot then
			return true
		end
	end
	return false
end

-- Each step is a numbered GOAL: text, target (instance to point at), done(player, profile, s) -> bool, and
-- optionally glow (a part of the player's base that lights up while the goal is open).
local function myBase(player)
	return baseService:Get(player)
end

local STEPS = {
	{
		text = "Grab the FREE dragon! 🐉",
		target = function()
			return road.freeModel
		end,
		done = function(player, profile)
			return dragons:Carrying(player) ~= nil or #profile.dragons > 0
		end,
	},
	{
		text = "Take it to YOUR BASE! Follow the glowing path. 🏠",
		target = function(player)
			local base = myBase(player)
			return base and base.world.laser
		end,
		done = function(_, profile)
			return hasNestDragon(profile)
		end,
	},
	{
		text = "Step on the GLOWING coin pad to collect your coins! 💰",
		target = function(player)
			local base = myBase(player)
			return base and base.world.collectPad
		end,
		glow = function(player)
			local base = myBase(player)
			return base and base.world.collectPad
		end,
		done = function(_, _profile, s)
			return s.collected
		end,
	},
	{
		text = "Buy another dragon on the Dragon Road and bring it home! 🛒",
		target = function()
			local map = workspace:FindFirstChild("Map")
			local roadModel = map and map:FindFirstChild("DragonRoad")
			return roadModel and roadModel:FindFirstChild("Road")
		end,
		done = function(player, profile)
			return profile.stats.bought > 0 and dragons:Carrying(player) == nil
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
	if state[player] then
		setGlow(state[player], nil)
	end
	state[player] = nil
end

function TutorialService:Step(player)
	return state[player] and state[player].step
end

function TutorialService:_finish(player, skipped)
	local profile = data:Get(player)
	if state[player] then
		setGlow(state[player], nil)
	end
	state[player] = nil
	if not profile then
		return
	end
	profile.tutorialDone = true
	self.Finished:Fire(player, skipped == true)
	Net.fire(player, "Tutorial", false)
	reward:GiveEgg(player)
	reward:PushAll(player)
	if not skipped then
		Net.fire(
			player,
			"Alert",
			"You did it! Here's a gift EGG: it hatches in 2 HOURS! 🥚",
			Color3.fromRGB(255, 205, 50)
		)
		Net.fire(player, "Toast", "Tip: step on the RED pad to lock your door, then go steal! 😈", "info")
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
		setGlow(s, step.glow and step.glow(player) or nil)
		Net.fire(player, "Tutorial", { step = s.step, total = #STEPS, text = step.text, target = step.target(player) })
		self.StepShown:Fire(player, s.step, #STEPS, step.text)
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
