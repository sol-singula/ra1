--[[
The first five minutes (master plan §12): learn by doing, something every 15 to 30 seconds, no walls of words.
Each step is one short line and a sparkle trail to where to go (TutorialController draws it):

  mine     0:10  a glowing rock pile right by you: tap it, get stone, a number pops up
  build    0:30  bring it to a glowing blueprint and hammer it: the wall rises, "You helped build this!"
  choice   1:00  three big buttons: make the gate stronger, build a tower, or make the wall thicker
  job            pick a job at the Job Board
  scare    2:00  the sky dims, a horn, monsters on the far hill: now you know why you're building
  fight    3:00  a scout attacks: swing at it
  shrines        the three shrines and the plague clock: hold them when the plague comes
Players who join in the fight start as monsters and get one line of their own ("smash the castle").
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapLayout = require(ReplicatedStorage.Shared.World.MapLayout)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local TutorialService = {
	Name = "TutorialService",
	Dependencies = {
		"PlayerDataService",
		"MatchService",
		"TeamService",
		"ResourceService",
		"BuildService",
		"CombatService",
		"HordeService",
	},
	StepShown = Signal.new("TutorialService.StepShown"), -- (player, index, total, key)
	StepDone = Signal.new("TutorialService.StepDone"), -- (player, index, key, seconds)
	Finished = Signal.new("TutorialService.Finished"), -- (player, skipped)
	Chosen = Signal.new("TutorialService.Chosen"), -- (player, choice)
}

local data, match, teams, resources, build, combat, horde
local states = {} -- [player] = { index, shownAt, target, waiting, monster }

local STEPS = {
	{ key = "mine", text = "Tap the glowing rocks to dig stone!" },
	{ key = "build", text = "Bring it to a glowing blueprint and hammer it!" },
	{ key = "choice", text = "Your first choice: what should the castle get?" },
	{ key = "job", text = "Pick your job at the Job Board!" },
	{ key = "scare", text = "Look! Monsters on the hill. Get ready!" },
	{ key = "fight", text = "A scout! Swing at it!" },
	{ key = "shrines", text = "When the plague comes, hold the shrines!" },
}
TutorialService.STEPS = STEPS

local CHOICES = {
	{ key = "gate", icon = "🚪", title = "Stronger gate", line = "Iron bands on the gate." },
	{ key = "tower", icon = "🗼", title = "Build a tower", line = "Archers shoot from the top." },
	{ key = "wall", icon = "🧱", title = "Thicker wall", line = "A wall that takes more hits." },
}
TutorialService.CHOICES = CHOICES

local function now()
	return workspace:GetServerTimeNow()
end

local function nearestPiece(pos, filter)
	local best, bestD
	for _, p in build:All() do
		if filter(p) then
			local d = (p.center - pos).Magnitude
			if not bestD or d < bestD then
				best, bestD = p, d
			end
		end
	end
	return best
end

-- Where a step points.
function TutorialService:_target(player, key)
	local pos = teams:Position(player) or MapLayout.shrines[1].pos
	if key == "mine" then
		for _, n in resources:Nodes() do
			if n.starter then
				return n.pos
			end
		end
	elseif key == "build" then
		local found = nearestPiece(pos, function(p)
			return p.state == "blueprint" or p.upgrade ~= nil
		end)
		return found and found.center
	elseif key == "job" then
		return MapLayout.jobBoards[match:ActiveShrine()].pos
	elseif key == "scare" then
		return Vector3.new(-462, 6, 0)
	elseif key == "fight" then
		local best, bestD
		for _, n in horde:All() do
			if n.st.scout then
				local d = (n.pos - pos).Magnitude
				if not bestD or d < bestD then
					best, bestD = n, d
				end
			end
		end
		return best and best.pos
	elseif key == "shrines" or key == "monster" then
		return MapLayout.shrines[match:ActiveShrine()].pos
	end
	return nil
end

function TutorialService:Step(player)
	local s = states[player]
	return s and s.index or nil
end

function TutorialService:_show(player)
	local s = states[player]
	if not s then
		return
	end
	if s.monster then
		Net.fire(player, "Tutorial", {
			step = 1,
			total = 1,
			key = "monster",
			text = "You're a monster! Smash the castle and take the shrine!",
			target = self:_target(player, "monster"),
		})
		return
	end
	local step = STEPS[s.index]
	if not step then
		return
	end
	s.shownAt = now()
	Net.fire(player, "Tutorial", {
		step = s.index,
		total = #STEPS,
		key = step.key,
		text = step.text,
		target = self:_target(player, step.key),
	})
	if step.key == "choice" then
		Net.fire(player, "Choice", { options = CHOICES })
	end
	self.StepShown:Fire(player, s.index, #STEPS, step.key)
end

function TutorialService:_finish(player, skipped)
	local profile = data:Get(player)
	if profile then
		profile.tutorial.done = true
	end
	states[player] = nil
	Net.fire(player, "Tutorial", false)
	Net.fire(player, "Choice", false)
	self.Finished:Fire(player, skipped == true)
end

-- Is the step at this index ready to show now (some wait for the match)?
local function ready(key)
	if key == "scare" then
		return match:State().scared == true or match:IsFight()
	elseif key == "fight" then
		for _, n in horde:All() do
			if n.st.scout then
				return true
			end
		end
		return match:IsFight()
	end
	return true
end

function TutorialService:_advance(player, key)
	local s = states[player]
	if not s or s.monster then
		if s and s.monster and key == "monster" then
			s.monster = nil
			Net.fire(player, "Tutorial", false)
		end
		return
	end
	local step = STEPS[s.index]
	if not step or step.key ~= key then
		return
	end
	self.StepDone:Fire(player, s.index, key, now() - (s.shownAt or now()))
	local profile = data:Get(player)
	s.index += 1
	if profile then
		profile.tutorial.step = s.index
	end
	-- skip steps whose moment has passed (joined late)
	while STEPS[s.index] do
		local k = STEPS[s.index].key
		if (k == "scare" or k == "fight") and match:IsFight() then
			s.index += 1
		else
			break
		end
	end
	if not STEPS[s.index] then
		self:_finish(player, false)
		return
	end
	s.waiting = not ready(STEPS[s.index].key)
	if s.waiting then
		Net.fire(player, "Tutorial", false)
	else
		self:_show(player)
	end
end

-- The first choice: make the gate stronger, build a tower, or make a wall thicker.
function TutorialService:Choose(player, index)
	local choice = CHOICES[index]
	local s = states[player]
	if not choice or not s or STEPS[s.index].key ~= "choice" then
		return false
	end
	local pos = teams:Position(player) or MapLayout.shrines[1].pos
	local target
	if choice.key == "gate" then
		local gate = nearestPiece(pos, function(p)
			return p.def.gate
		end)
		if gate and gate.state == "built" and not gate.upgraded then
			build:StartUpgrade(player, gate.id, true)
		end
		target = gate
	elseif choice.key == "tower" then
		for _, spot in MapLayout.towerSpots do
			local piece = build:Place(nil, spot.key, spot.i, spot.j, spot.rot, { system = true })
			if piece then
				target = piece
				break
			end
		end
		target = target or nearestPiece(pos, function(p)
			return p.def.tower and p.state == "blueprint"
		end)
	else
		local wall = nearestPiece(pos, function(p)
			return p.key == "stoneWall" and p.state == "built" and not p.upgraded and not p.upgrade
		end)
		if wall then
			build:StartUpgrade(player, wall.id, true)
			target = wall
		else
			target = nearestPiece(pos, function(p)
				return p.key == "stoneWall"
			end)
		end
	end
	Net.fire(player, "Choice", false)
	if target then
		Net.fire(player, "Toast", `Good pick! Help build the {choice.title:lower()}.`, "good")
	end
	self.Chosen:Fire(player, choice.key)
	self:_advance(player, "choice")
	return true
end

function TutorialService:Init(reg)
	data = reg.PlayerDataService
	match = reg.MatchService
	teams = reg.TeamService
	resources = reg.ResourceService
	build = reg.BuildService
	combat = reg.CombatService
	horde = reg.HordeService
	Net.on("SkipTutorial", function(player)
		if states[player] then
			self:_finish(player, true)
		end
	end)
	Net.on("Choice", function(player, index)
		if type(index) == "number" then
			self:Choose(player, index)
		end
	end)
	resources.Mined:Connect(function(player)
		self:_advance(player, "mine")
	end)
	build.Helped:Connect(function(_, player, kind)
		if kind == "deposit" or kind == "work" or kind == "upgrade" then
			self:_advance(player, "build")
		end
	end)
	teams.JobPicked:Connect(function(player)
		self:_advance(player, "job")
	end)
	combat.Hit:Connect(function(by, victim)
		if by and (victim.npc or victim.player or victim.piece) then
			self:_advance(by, "fight")
			self:_advance(by, "monster")
		end
	end)
	match.Plague:Connect(function()
		for player in states do
			self:_advance(player, "shrines")
		end
	end)
	teams.TeamChanged:Connect(function(player, team, why)
		local s = states[player]
		if s and team == "monster" and why == "join" then
			s.monster = true
			task.delay(1.5, function()
				self:_show(player)
			end)
		end
	end)
	match.Reset:Connect(function()
		for player in states do
			Net.fire(player, "Tutorial", false)
		end
	end)
	match.Started:Connect(function()
		for player, s in states do
			s.monster = nil
			task.delay(2, function()
				self:_show(player)
			end)
		end
	end)
end

function TutorialService:Start()
	while true do
		task.wait(1)
		local t = now()
		for player, s in states do
			local step = STEPS[s.index]
			if step and not s.monster and match:InMatch() then
				if s.waiting and ready(step.key) then
					s.waiting = false
					self:_show(player)
				elseif not s.waiting and s.shownAt then
					local age = t - s.shownAt
					-- some steps finish by themselves
					if step.key == "scare" and age >= 8 then
						self:_advance(player, "scare")
					elseif step.key == "job" and age >= 45 then
						self:_advance(player, "job")
					elseif step.key == "choice" and age >= 30 then
						Net.fire(player, "Choice", false)
						self:_advance(player, "choice")
					elseif step.key == "shrines" and age >= 25 then
						self:_advance(player, "shrines")
					elseif step.key == "build" or step.key == "fight" or step.key == "mine" then
						-- keep the trail pointing at the right place
						if math.floor(age) % 3 == 0 then
							Net.fire(player, "Tutorial", {
								step = s.index,
								total = #STEPS,
								key = step.key,
								text = step.text,
								target = self:_target(player, step.key),
							})
						end
					end
				end
			end
		end
	end
end

function TutorialService:OnPlayerReady(player, profile)
	if profile.tutorial.done then
		return
	end
	states[player] = { index = 1, waiting = false, monster = teams:Team(player) == "monster" or nil }
	if match:InMatch() then
		task.delay(2, function()
			if states[player] and teams:Team(player) then
				self:_show(player)
			end
		end)
	end
end

function TutorialService:OnPlayerLeaving(player)
	states[player] = nil
end

return TutorialService
