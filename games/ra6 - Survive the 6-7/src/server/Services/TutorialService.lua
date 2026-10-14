--[[
The first five minutes for a new player (master plan §4): no text walls, one clear thing to do at a time, a
glowing arrow to where it is (TutorialController), and the run itself does the teaching.

  1 chop     "Chop a tree for wood" (you start holding a Rusty Axe)                       0:15-0:45
  2 build    "Build the Workbench": put the wood in its blueprint at the camp             0:45-1:30
  3 loot     "Open a crate": there are always a few right by the camp                     1:30-2:30
  4 equip    "Hold what you found": tap it in your hotbar
  5 kermy    after Kermy shows himself (2:30): "Get back to camp before dark!"          2:30-3:30
  6 night    "Survive the night! Dodge his lunge"                                         3:30-5:00
Steps already done by the team are skipped (someone else built the workbench). Works alone or with friends.
Returning players skip it; the SKIP button ends it.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage.Shared.Data.Items)
local MapLayout = require(ReplicatedStorage.Shared.World.MapLayout)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local TutorialService = {
	Name = "TutorialService",
	Dependencies = {
		"PlayerDataService",
		"RunService",
		"SurvivorService",
		"InventoryService",
		"ResourceService",
		"CampService",
		"LootService",
		"MonsterService",
	},
	StepShown = Signal.new("TutorialService.StepShown"), -- (player, step, total, key)
	StepDone = Signal.new("TutorialService.StepDone"), -- (player, step, key, seconds)
	Finished = Signal.new("TutorialService.Finished"), -- (player, skipped)
}

local data, runs, survivors, inventory, resources, camp, loot, monsters
local STEPS = { "chop", "build", "loot", "equip", "kermy", "night" }
TutorialService.STEPS = STEPS
local TEXT = {
	chop = "Chop a tree for wood 🪵",
	build = "Build the Workbench at camp 🛠️",
	loot = "Open a crate 📦",
	equip = "Hold what you found: tap it in your hotbar",
	kermy = "Get back to camp before dark! 🔥",
	night = "Survive the night! Dodge his lunge (Q / the 💨 button)",
}
local active = {} -- [player] = { step, shownAt, wood }

local function now()
	return workspace:GetServerTimeNow()
end

function TutorialService:Active(player)
	return active[player]
end

-- The target of the current step (for the arrow and the compass), or nil.
function TutorialService:Target(player, key)
	local pos = survivors:Position(player)
	if key == "chop" and pos then
		-- the nearest tree an axe can chop; the arrow floats beside its trunk, on your side (not inside the tree)
		for _, t in resources:TreesNear(pos, 140) do
			if resources:CanChop(t) then
				local c = Vector3.new(t.rec.x, t.rec.y, t.rec.z)
				local side = Vector3.new(pos.X - c.X, 0, pos.Z - c.Z)
				side = side.Magnitude > 0.1 and side.Unit or Vector3.new(1, 0, 0)
				return c + side * (t.rec.trunk + 1.8) + Vector3.new(0, 1.2, 0), t.rec.id
			end
		end
		return nil
	elseif key == "build" then
		local s = camp:Structure("workbench_1")
		return s and s.slot.pos + Vector3.new(0, 2, 0) or nil
	elseif key == "loot" and pos then
		local best, bestD
		for _, c in loot:All() do
			if not c.opened and not c.mimic and c.kind == "crate" then
				local d = (c.pos - pos).Magnitude
				if not bestD or d < bestD then
					best, bestD = c, d
				end
			end
		end
		return best and best.pos + Vector3.new(0, 2, 0) or nil
	elseif key == "kermy" or key == "night" then
		return MapLayout.CAMP_PROPS.fire + Vector3.new(0, 3, 0)
	end
	return nil
end

function TutorialService:View(player)
	local a = active[player]
	if not a then
		return false
	end
	local key = STEPS[a.step]
	local text = TEXT[key]
	if key == "chop" then
		text = `{text} ({math.min(a.wood, 5)}/5)`
	end
	local target, tree = self:Target(player, key)
	return { step = a.step, total = #STEPS, key = key, text = text, target = target, tree = tree }
end

function TutorialService:_show(player)
	local a = active[player]
	if not a then
		Net.fire(player, "Tutorial", false)
		return
	end
	-- skip steps the team already did
	while a.step <= #STEPS do
		local key = STEPS[a.step]
		if (key == "build" and camp:IsBuilt("workbench")) or (key == "kermy" and runs:IsNight()) then
			a.step += 1
		else
			break
		end
	end
	if a.step > #STEPS then
		self:Finish(player, false)
		return
	end
	a.shownAt = now()
	Net.fire(player, "Tutorial", self:View(player))
	self.StepShown:Fire(player, a.step, #STEPS, STEPS[a.step])
end

function TutorialService:Advance(player, key)
	local a = active[player]
	if not a or STEPS[a.step] ~= key then
		return
	end
	self.StepDone:Fire(player, a.step, key, now() - (a.shownAt or now()))
	a.step += 1
	local profile = data:Get(player)
	if profile then
		profile.tutorial.step = a.step
	end
	Net.fire(player, "Sfx", "notify")
	self:_show(player)
end

function TutorialService:Finish(player, skipped)
	if not active[player] then
		return
	end
	active[player] = nil
	local profile = data:Get(player)
	if profile then
		profile.tutorial.done = true
	end
	Net.fire(player, "Tutorial", false)
	if not skipped then
		Net.fire(player, "Toast", "You've got the hang of it. Now survive the 6-7!", "good")
	end
	self.Finished:Fire(player, skipped)
end

function TutorialService:Init(registry)
	data = registry.PlayerDataService
	runs = registry.RunService
	survivors = registry.SurvivorService
	inventory = registry.InventoryService
	resources = registry.ResourceService
	camp = registry.CampService
	loot = registry.LootService
	monsters = registry.MonsterService
	Net.on("SkipTutorial", function(player)
		self:Finish(player, true)
	end)
	resources.Gathered:Connect(function(player, item, amount)
		local a = active[player]
		if a and item == "wood" then
			a.wood += amount
			if a.wood >= 5 then
				self:Advance(player, "chop")
			else
				Net.fire(player, "Tutorial", self:View(player))
			end
		end
	end)
	camp.Built:Connect(function(s)
		if s.key == "workbench" then
			for player in active do
				self:Advance(player, "build")
			end
		end
	end)
	loot.Looted:Connect(function(player)
		self:Advance(player, "loot")
	end)
	loot.MimicSprung:Connect(function(player)
		self:Advance(player, "loot")
		self:Advance(player, "equip")
	end)
	inventory.SlotSelected:Connect(function(player, slotId, item)
		if item and slotId ~= "h1" and Items.goesToHotbar(item) then
			self:Advance(player, "equip")
		end
	end)
	monsters.Sighting:Connect(function()
		for player, a in active do
			if
				STEPS[a.step] == "equip"
				or STEPS[a.step] == "loot"
				or STEPS[a.step] == "build"
				or STEPS[a.step] == "chop"
			then
				-- the threat comes whether or not the guide got that far: jump to "get back to camp"
				a.step = 5
				self:_show(player)
			end
		end
	end)
	runs.NightStarted:Connect(function(n)
		if n == 1 then
			for player in active do
				self:Advance(player, "kermy")
			end
		end
	end)
	runs.NightSurvived:Connect(function(n)
		if n == 1 then
			for player in active do
				self:Advance(player, "night")
			end
		end
	end)
	runs.Ended:Connect(function()
		for player in active do
			self:Finish(player, false)
		end
	end)
	runs.Joined:Connect(function(player)
		self:_begin(player)
	end)
end

-- The guide starts with your first run (not while you wait for one).
function TutorialService:_begin(player)
	local profile = data:Get(player)
	if not profile or profile.tutorial.done or active[player] then
		return
	end
	active[player] = { step = 1, wood = 0, shownAt = now() }
	data:WhenClientReady(player, function()
		self:_show(player)
	end)
end

function TutorialService:OnPlayerReady(player)
	if runs:InRun(player) then
		self:_begin(player)
	end
end

function TutorialService:OnPlayerLeaving(player)
	active[player] = nil
end

function TutorialService:Start()
	-- refresh the arrow's target now and then (the nearest tree or crate changes as you move)
	while true do
		task.wait(2)
		for player, a in active do
			local key = STEPS[a.step]
			if key == "chop" or key == "loot" then
				Net.fire(player, "Tutorial", self:View(player))
			end
		end
	end
end

return TutorialService
