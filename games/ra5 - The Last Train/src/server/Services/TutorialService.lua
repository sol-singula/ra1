-- The first-time guide: one short goal at a time, in the place you need it, with an arrow to the thing to touch.
--   1 cabin    find your cabin (the CABIN button takes you there)
--   2 color    pick its colour on the door sign: the first thing you change, and it's free
--   3 collect  at a stop, step outside and collect a pile
--   4 return   get back aboard before the doors close (that banks the bag)
--   5 build    build the bunk in your cabin
--   6 train    give something to the crew's train (the personal-or-team choice, explained)
--   7 friends  how to join or invite friends, and the Hall of Records
-- Progress is read from the game every quarter second, so it can't get stuck on a missed event, and it's saved
-- (profile.tutorial), so a returning player picks up where they left off. Someone who has already done a step (or
-- joins late) just skips it. It never tells you to go outside when the train is about to leave. SKIP ends it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CabinItems = require(ReplicatedStorage.Shared.Data.CabinItems)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Layout = require(ReplicatedStorage.Shared.World.Layout)
local Net = require(ReplicatedStorage.Shared.Net)
local Resources = require(ReplicatedStorage.Shared.Data.Resources)
local Signal = require(ReplicatedStorage.Shared.Signal)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local TutorialService = {
	Name = "TutorialService",
	Dependencies = { "PlayerDataService", "ExpeditionService", "CabinService", "ResourceService", "TrainService", "RecoveryService" },
	StepShown = Signal.new("TutorialService.StepShown"), -- (player, step, total, key, text)
	StepDone = Signal.new("TutorialService.StepDone"), -- (player, step, key, seconds)
	Finished = Signal.new("TutorialService.Finished"), -- (player, skipped)
}

local data, expedition, cabins, resources, train, recovery
local state = {} -- [player] = { sent, shownAt, viewed = {}, lastText }

local function cabinHandle(player)
	local i = cabins:IndexOf(player)
	return i and WorldBuilder.layout.train.cabins[i] or nil
end

local function platePart(player)
	local h = cabinHandle(player)
	local gui = h and h.plate and h.plate.Parent
	return gui and gui.Parent or nil
end

local function buildSpot(player)
	local h = cabinHandle(player)
	return h and h.model:FindFirstChild("BuildSpot") or nil
end

local function inOwnCabin(player)
	local pos = expedition:Position(player)
	local i = cabins:IndexOf(player)
	if not pos or not i then
		return false
	end
	local cabin = Layout.cabins[i]
	local d = pos - cabin.center
	return math.abs(d.X) <= Layout.CABIN_LEN / 2 and d.Z >= -9.5 and d.Z <= 9.5 and math.abs(d.Y) < 10
end

-- The closest pile this player can still take at this stop.
local function nearestPile(player)
	local pos = expedition:Position(player)
	if not pos then
		return nil
	end
	local best, bestD
	for _, node in resources:Nodes() do
		if node.model.Parent and node.kind ~= "blueprint" then
			local d = (node.root.Position - pos).Magnitude
			if not bestD or d < bestD then
				best, bestD = node.root, d
			end
		end
	end
	return best
end

local function nearestDoor(player)
	local pos = expedition:Position(player)
	if not pos then
		return nil
	end
	local best, bestD
	for _, d in WorldBuilder.layout.train.doors do
		local dist = (d.blocker.Position - pos).Magnitude
		if not bestD or dist < bestD then
			best, bestD = d.blocker, dist
		end
	end
	return best
end

local function bunkText(profile)
	local bunk = CabinItems.byKey.bunk
	local parts = {}
	for res, n in bunk.cost do
		table.insert(parts, `{Resources.byKey[res].icon} {math.min(profile.storage[res] or 0, n)}/{n}`)
	end
	table.sort(parts)
	return table.concat(parts, "  ")
end

-- Each step: key, text(player, profile, s) -> string, target(player) -> part?, done(player, profile, s) -> bool.
local STEPS = {
	{
		key = "cabin",
		text = function()
			return "This is your train. Find YOUR cabin: tap CABIN, or follow the arrow. 🚪"
		end,
		target = platePart,
		done = function(player, profile)
			return inOwnCabin(player) or profile.cabin.color ~= nil
		end,
	},
	{
		key = "color",
		text = function()
			return "Make it yours: pick a colour on your door sign. 🎨"
		end,
		target = platePart,
		done = function(_, profile)
			return profile.cabin.color ~= nil
		end,
	},
	{
		key = "collect",
		text = function()
			local phase = expedition:Phase()
			if phase == "scavenging" then
				return "The doors are open! Step outside and hold on a pile to collect it. 🪵"
			elseif phase == "warning" or (phase == "departing" and expedition:IsAtStop()) then
				return "The train is about to leave: stay aboard this time. At the next stop, go collect! 🪵"
			end
			return "The train stops soon. When the doors open, step outside and collect materials. 🪵"
		end,
		target = function(player)
			if expedition:Phase() == "scavenging" then
				return nearestPile(player)
			end
			return nil
		end,
		done = function(_, profile)
			return profile.stats.collected > 0
		end,
	},
	{
		key = "return",
		text = function()
			if expedition:Phase() == "warning" then
				return "Hurry back aboard before the doors close! Your bag is saved the moment you're inside. 🚂"
			end
			return "Get back aboard before the doors close: your bag is saved the moment you're inside. 🚂"
		end,
		target = function(player)
			local pos = expedition:Position(player)
			if pos and not Layout.inTrain(pos) then
				return nearestDoor(player)
			end
			return nil
		end,
		done = function(_, profile)
			return profile.stats.banked > 0
		end,
	},
	{
		key = "build",
		text = function(_, profile)
			local ok = Formulas.canBuild(CabinItems.byKey.bunk, profile.cabin.built, profile.storage, profile.blueprints)
			if ok then
				return "You have enough! Go to your cabin and tap BUILD to make your bunk. 🛏"
			end
			return `Your first upgrade is a real bunk: {bunkText(profile)}. Bring the rest back from the next stop! 🛏`
		end,
		target = function(player)
			local profile = data:Get(player)
			if profile and Formulas.canBuild(CabinItems.byKey.bunk, profile.cabin.built, profile.storage, profile.blueprints) then
				return buildSpot(player)
			end
			return nil
		end,
		done = function(_, profile)
			return profile.cabin.built.bunk == true
		end,
	},
	{
		key = "train",
		text = function()
			if expedition:IsAtStop() and expedition:Fuel() + 1e-6 < expedition:FuelCost() then
				return "The crew needs FUEL to leave! Bring back a ⛽ fuel can, or give materials at the TRAIN board. ⚙️"
			end
			return "Your materials can build your cabin OR help the crew's train go farther. Tap TRAIN and give some. ⚙️"
		end,
		target = function()
			return WorldBuilder.layout.train.upgradeBoardPart
		end,
		done = function(_, profile, s)
			return profile.stats.deposited > 0 or s.viewed.train == true
		end,
	},
	{
		key = "friends",
		text = function()
			return "Trains are better with friends: tap FRIENDS to join or invite them. The best crews are in the station's Hall of Records! 👋"
		end,
		target = function()
			return nil
		end,
		done = function(_, _, s)
			return s.viewed.friends or s.viewed.hall or (s.shownAt and os.clock() - s.shownAt > 25)
		end,
	},
}
TutorialService.STEPS = STEPS
TutorialService.STEP_COUNT = #STEPS

function TutorialService:Step(player)
	local profile = data:Get(player)
	if not profile then
		return nil
	end
	return profile.tutorial.done and #STEPS + 1 or profile.tutorial.step
end

function TutorialService:Done(player)
	local profile = data:Get(player)
	return profile ~= nil and profile.tutorial.done == true
end

function TutorialService:_finish(player, skipped)
	local profile = data:Get(player)
	state[player] = nil
	if not profile or profile.tutorial.done then
		return
	end
	profile.tutorial.done = true
	profile.tutorial.step = #STEPS + 1
	Net.fire(player, "Tutorial", false)
	self.Finished:Fire(player, skipped == true)
	if not skipped then
		Net.fire(player, "Alert", "You're part of the crew! Keep building your cabin, and see how far this train can go. 🚂", Color3.fromRGB(255, 205, 120))
	end
end

function TutorialService:_tick(player)
	local s = state[player]
	local profile = data:Get(player)
	if not s or not profile or profile.tutorial.done then
		return
	end
	local n = profile.tutorial.step
	local step = STEPS[n]
	-- finished steps (and ones already done before) are skipped right away
	local guard = 0
	while step and step.done(player, profile, s) and guard < #STEPS do
		guard += 1
		self.StepDone:Fire(player, n, step.key, s.shownAt and os.clock() - s.shownAt or 0)
		n += 1
		profile.tutorial.step = n
		s.sent, s.shownAt, s.lastText, s.lastTarget = nil, nil, nil, nil
		step = STEPS[n]
	end
	if not step then
		self:_finish(player, false)
		return
	end
	local text = step.text(player, profile, s)
	local target = step.target(player)
	if s.sent ~= n or text ~= s.lastText or target ~= s.lastTarget then
		local first = s.sent ~= n
		s.sent, s.lastText, s.lastTarget = n, text, target
		if first then
			s.shownAt = os.clock()
			self.StepShown:Fire(player, n, #STEPS, step.key, text)
		end
		Net.fire(player, "Tutorial", { step = n, total = #STEPS, key = step.key, text = text, target = target })
	end
end

function TutorialService:Init(registry)
	data = registry.PlayerDataService
	expedition = registry.ExpeditionService
	cabins = registry.CabinService
	resources = registry.ResourceService
	train = registry.TrainService
	recovery = registry.RecoveryService
	Net.on("SkipTutorial", function(player)
		if state[player] then
			self:_finish(player, true)
		end
	end)
	Net.on("Viewed", function(player, what)
		local s = state[player]
		if s and type(what) == "string" then
			s.viewed[string.sub(what, 1, 20)] = true
		end
	end)
	data.ClientReady:Connect(function(player)
		if state[player] then
			state[player].sent = nil -- resend the current step
		end
	end)
	_ = train
	_ = recovery
end

function TutorialService:OnPlayerReady(player, profile)
	if profile.tutorial.done then
		return
	end
	profile.tutorial.step = math.clamp(profile.tutorial.step or 1, 1, #STEPS)
	state[player] = { viewed = {} }
end

function TutorialService:OnPlayerLeaving(player)
	state[player] = nil
end

function TutorialService:Start()
	while true do
		task.wait(0.25)
		for _, player in Players:GetPlayers() do
			if state[player] then
				local ok, err = pcall(self._tick, self, player)
				if not ok then
					warn("[TutorialService] " .. tostring(err))
				end
			end
		end
	end
end

return TutorialService
