-- Robot noobs: they fill a round with fewer than 4 fighters (a brand-new player's first round always has 4), so a
-- 2-player server still has action. They walk between spawn points, and when they see someone they stop, take a
-- moment to aim, and fire (they miss a lot). They're tagged ROBOT, pay few coins, and never count for the
-- leaderboards or the podium.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local RobotBuilder = require(script.Parent.Parent.World.RobotBuilder)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local RobotService = {
	Name = "RobotService",
	Dependencies = { "PlayerDataService", "CombatService", "RoundService" },
	robots = {}, -- list of robot tables
	paused = false, -- (tests) robots stand still and hold fire
}

local data, combat, round
local NAMES = { "NOOB BOT", "BLOX BOT", "BEEP", "BOOP", "ROBO", "BOLTY", "CHIP", "SPROCKET" }
local nextId = 0
local rng = Random.new()

local function folder()
	return workspace:FindFirstChild("Robots") or workspace
end

-- How many fighters a round should have, counting robots.
function RobotService:Wanted()
	if round.state ~= "round" then
		return 0
	end
	local real = 0
	local fresh = false
	for _, p in Players:GetPlayers() do
		if combat.zone(p) == "arena" then
			real += 1
			local profile = data:Get(p)
			if profile and not profile.firstRoundDone then
				fresh = true
			end
		end
	end
	if real == 0 or Constants.ROBOTS_FILL_TO <= 0 then
		return 0 -- robots are off
	end
	local fill = fresh and math.max(Constants.ROBOTS_FILL_TO, Constants.ROBOT_FIRST_ROUND) or Constants.ROBOTS_FILL_TO
	return math.max(0, fill - real)
end

function RobotService:Spawn()
	nextId += 1
	local name = NAMES[(nextId - 1) % #NAMES + 1]
	local model = RobotBuilder.build(name, "bot")
	model:SetAttribute("Zone", "arena")
	model.Parent = folder()
	local robot = {
		robot = true,
		id = nextId,
		name = name,
		model = model,
		root = model.PrimaryPart,
		zone = "arena",
		target = nil,
		seenAt = nil,
		nextShot = 0,
		goal = nil,
	}
	table.insert(self.robots, robot)
	combat:AddRobot(robot)
	round:Score(robot)
	combat:Respawn(robot)
	return robot
end

function RobotService:Remove(robot)
	local i = table.find(self.robots, robot)
	if i then
		table.remove(self.robots, i)
	end
	combat:RemoveRobot(robot)
	round.scores[robot] = nil
	if robot.model then
		robot.model:Destroy()
	end
end

-- Add or remove robots to match how many the round wants.
function RobotService:Balance()
	local want = self:Wanted()
	while #self.robots < want do
		self:Spawn()
	end
	while #self.robots > want do
		self:Remove(self.robots[#self.robots])
	end
end

function RobotService:Clear()
	for _, r in table.clone(self.robots) do
		self:Remove(r)
	end
end

-- Can a robot see a target (nothing of the map in between)?
local function canSee(robot, target)
	local tr = combat.root(target)
	if not tr or not round.map then
		return false
	end
	local from = robot.root.Position + Vector3.new(0, Constants.HEAD_OFFSET, 0)
	local to = tr.Position + Vector3.new(0, 0.5, 0)
	local dir = to - from
	if dir.Magnitude > 220 then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { round.map.model }
	return workspace:Raycast(from, dir, params) == nil
end

local function face(robot, at)
	local pos = robot.root.Position
	local flat = Vector3.new(at.X, pos.Y, at.Z)
	if (flat - pos).Magnitude > 0.1 then
		robot.model:PivotTo(CFrame.lookAt(pos, flat))
	end
end

function RobotService:_think(robot, dt)
	if robot.popped or not round.map then
		return
	end
	local now = os.clock()
	-- keep the current target while it's visible; otherwise look for the nearest visible one
	local target = robot.target
	if target and (combat.isPopped(target) or combat.zone(target) ~= "arena" or not canSee(robot, target)) then
		target = nil
	end
	if not target then
		local best, bestD
		for _, f in combat:Fighters("arena") do
			if f ~= robot and not combat.isPopped(f) and not combat.shielded(f) then
				local r = combat.root(f)
				local d = r and (r.Position - robot.root.Position).Magnitude
				if d and (not bestD or d < bestD) and canSee(robot, f) then
					best, bestD = f, d
				end
			end
		end
		target = best
		robot.seenAt = target and now or nil
	end
	robot.target = target
	if target then
		face(robot, combat.root(target).Position)
		if now - (robot.seenAt or now) >= Constants.ROBOT_REACTION and now >= robot.nextShot then
			robot.nextShot = now + 1.8 + rng:NextNumber() * 1.2
			combat:RobotFire(robot, target, rng:NextNumber() < Constants.ROBOT_ACCURACY)
		end
		return
	end
	-- wander: walk toward a spawn point; pick a new one when there or blocked
	local pos = robot.root.Position
	if not robot.goal or (Vector3.new(robot.goal.X, pos.Y, robot.goal.Z) - pos).Magnitude < 3 then
		local spawns = round.map.spawns
		robot.goal = spawns[rng:NextInteger(1, #spawns)] + Vector3.new(0, 3, 0)
	end
	local flatGoal = Vector3.new(robot.goal.X, pos.Y, robot.goal.Z)
	local dir = (flatGoal - pos)
	local step = math.min(dir.Magnitude, Constants.ROBOT_SPEED * dt)
	if dir.Magnitude > 0.01 then
		dir = dir.Unit
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { round.map.model }
		-- check at knee and chest height so robots walk around cover
		local blocked = workspace:Raycast(pos + Vector3.new(0, -1.5, 0), dir * (step + 1.5), params)
			or workspace:Raycast(pos, dir * (step + 1.5), params)
		if blocked then
			robot.goal = nil
			return
		end
		local nextPos = pos + dir * step
		robot.model:PivotTo(CFrame.lookAt(nextPos, nextPos + dir))
	end
end

function RobotService:Init(registry)
	data = registry.PlayerDataService
	combat = registry.CombatService
	round = registry.RoundService
end

function RobotService:Start()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.1 then
			return
		end
		local step = math.min(acc, 0.3)
		acc = 0
		if self.paused then
			return
		end
		for _, r in table.clone(self.robots) do
			local ok, err = pcall(self._think, self, r, step)
			if not ok then
				warn("[RobotService] " .. tostring(err))
			end
		end
	end)
	_ = WorldBuilder
end

function RobotService:OnPlayerLeaving()
	task.defer(function()
		self:Balance()
	end)
end

return RobotService
