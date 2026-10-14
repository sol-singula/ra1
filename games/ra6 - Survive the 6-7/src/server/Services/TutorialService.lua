--[[
The first five minutes for a new player (master plan §4): no text walls, one clear thing to do at a time, a
glowing arrow to where it is and the thing itself lit up (TutorialController), and the run itself does the teaching.

  1 chop     "Chop any tree" (you start holding a Rusty Axe; young trees stand right at the camp)       0:00-0:20
  2 build    "Build the Workbench": hold its blueprint's prompt with the wood you just cut              0:20-0:40
  3 loot     "Open the crate by the fire": always a weapon, a torch and something to eat                0:40-0:55
  4 equip    "Hold your new weapon": tap it in your hotbar
  5 fight    "A Snapcap! Hit it!": one jumps out at ~1:00, right after Kermy shows himself (0:50)       1:00-1:20
  6 explore  "Explore!": the crates and stone are out in the forest (the arrow: the nearest crate)      1:20-2:50
  7 kermy    with 40 s of day left: "Get back to camp before dark!"                                     2:50-3:30
  8 night    "Survive the night! Dodge his lunge"                                                       3:30-5:00
Each first pays XP (Constants.XP.guide). The Snapcap comes whatever step you're on: the guide shows "LOOK OUT!"
until it's dealt with, then goes back to where you were. Steps the team already did are skipped (someone else
built the workbench). Works alone or with friends. Returning players skip it; the SKIP button ends it.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
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
local STEPS = { "chop", "build", "loot", "equip", "fight", "explore", "kermy", "night" }
TutorialService.STEPS = STEPS
local INDEX = {}
for i, k in STEPS do
	INDEX[k] = i
end
local TEXT = {
	chop = "Chop any tree 🌳 for wood",
	build = "Build the Workbench 🛠️: hold its blueprint's prompt",
	loot = "Open the crate by the fire 📦",
	equip = "Hold your new weapon: tap it in your hotbar",
	fight = "A Snapcap! Hit it! 🍄",
	explore = "Explore! Crates 📦 and stone ⛰️ are out in the forest. Back by dark!",
	kermy = "Get back to camp before dark! 🔥",
	night = "Survive the night! Dodge his lunge (Q / the 💨 button)",
}
TutorialService.TEXT = TEXT
local active = {} -- [player] = { step, shownAt, wood, detour, fightMob }
local ambushMob -- the day-1 Snapcap (id) while it lives

local function now()
	return workspace:GetServerTimeNow()
end

function TutorialService:Active(player)
	return active[player]
end

-- The target of a step (for the arrow and the compass), or nil, and what to light up: { tree = id } (the client
-- picks its own nearest tree as you move; this one is its start), { structure = id }, { container = id } or
-- { mob = id }.
function TutorialService:Target(player, key)
	local pos = survivors:Position(player)
	if key == "chop" and pos then
		-- the nearest tree an axe can chop; the arrow floats beside its trunk, on your side (not inside the tree)
		for _, t in resources:TreesNear(pos, 140) do
			if resources:CanChop(t) then
				local c = Vector3.new(t.rec.x, t.rec.y, t.rec.z)
				local side = Vector3.new(pos.X - c.X, 0, pos.Z - c.Z)
				side = side.Magnitude > 0.1 and side.Unit or Vector3.new(1, 0, 0)
				return c + side * (t.rec.trunk + 1.8) + Vector3.new(0, 1.2, 0), { tree = t.rec.id }
			end
		end
		return nil
	elseif key == "build" then
		local s = camp:Structure("workbench_1")
		return s and s.slot.pos + Vector3.new(0, 1, 0) or nil, s and { structure = s.id } or nil
	elseif (key == "loot" or key == "explore") and pos then
		-- the starter crate by the fire first, then the nearest unopened one (exploring: one out in the forest)
		local best, bestD
		for _, c in loot:All() do
			if not c.opened and not c.mimic and c.kind == "crate" and (key == "loot" or not c.starter) then
				local d = (c.pos - pos).Magnitude - (c.starter and 1000 or 0)
				if not bestD or d < bestD then
					best, bestD = c, d
				end
			end
		end
		return best and best.pos + Vector3.new(0, 1, 0) or nil, best and { container = best.id } or nil
	elseif key == "fight" then
		local m = ambushMob and monsters:Get(ambushMob)
		if m and m.hp > 0 then
			return m.pos + Vector3.new(0, 1, 0), { mob = m.id }
		end
		return nil
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
	local key = a.detour or STEPS[a.step]
	local text = TEXT[key]
	if key == "chop" then
		text = `{text} ({math.min(a.wood, 5)}/5)`
	end
	local target, glow = self:Target(player, key)
	local view = { step = a.step, total = #STEPS, key = key, text = text, target = target }
	if a.detour then
		view.title = "LOOK OUT!"
	end
	for k, v in glow or {} do
		view[k] = v
	end
	return view
end

function TutorialService:_show(player)
	local a = active[player]
	if not a then
		Net.fire(player, "Tutorial", false)
		return
	end
	-- skip steps the team already did (or that the run is past)
	while a.step <= #STEPS do
		local key = STEPS[a.step]
		local snap = ambushMob and monsters:Get(ambushMob)
		if
			(key == "build" and camp:IsBuilt("workbench"))
			or (key == "fight" and (a.fought or not (snap and snap.hp > 0)))
			or (key == "kermy" and runs:IsNight())
		then
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
	if not a or STEPS[a.step] ~= key or a.detour then
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
	-- the Snapcap comes whatever step you're on (§4: the first fight by day): "LOOK OUT!" until it's dealt with
	monsters.Ambush:Connect(function(m)
		ambushMob = m.id
		for player, a in active do
			if STEPS[a.step] ~= "fight" then
				-- (before it: the fight comes first; past it: the fight step was skipped while there was nothing
				-- to fight, so it's a detour from exploring)
				a.detour = "fight"
				a.detourAt = now()
			end
			Net.fire(player, "Tutorial", self:View(player))
		end
	end)
	monsters.Killed:Connect(function(m)
		if m.ambush then
			self:_fightOver(true)
		end
	end)
	runs.NightStarted:Connect(function(n)
		if n == 1 then
			-- the night comes whether or not the guide got that far
			for player, a in active do
				if a.step < INDEX.night then
					if STEPS[a.step] == "kermy" then
						self:Advance(player, "kermy")
					else
						a.detour = nil
						a.step = INDEX.night
						self:_show(player)
					end
				end
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

-- The Snapcap is dead (or gone): the fight step is done for everyone, and detours go back to where they were.
function TutorialService:_fightOver(killed)
	ambushMob = nil
	for player, a in active do
		if a.detour == "fight" then
			a.detour = nil
			a.fought = true
			if killed then
				self.StepDone:Fire(player, INDEX.fight, "fight", now() - (a.detourAt or now()))
			end
			self:_show(player)
		elseif STEPS[a.step] == "fight" then
			a.fought = true
			if killed then
				self:Advance(player, "fight")
			else
				a.step += 1
				self:_show(player)
			end
		end
	end
end

function TutorialService:Start()
	while true do
		task.wait(2)
		local snap = ambushMob and monsters:Get(ambushMob)
		if ambushMob and not (snap and snap.hp > 0) then
			self:_fightOver(false)
		end
		local left = runs:TimeLeft()
		local run = runs:Get()
		local duskSoon = run and run.phase == "day" and run.day == 1 and left and left <= Constants.GUIDE_DUSK_WARNING
		for player, a in active do
			local key = a.detour or STEPS[a.step]
			if duskSoon and not a.detour and a.step < INDEX.kermy then
				-- dark is coming whatever step you're on
				a.step = INDEX.kermy
				self:_show(player)
			elseif key == "chop" or key == "loot" or key == "fight" or key == "explore" then
				-- refresh the arrow's target now and then (the nearest tree or crate changes as you move)
				Net.fire(player, "Tutorial", self:View(player))
			end
		end
	end
end

return TutorialService
