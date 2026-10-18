--[[
The tractor (the "autoharvest" upgrade): it drives itself round the fields, to the nearest ripe (or empty) patch,
harvests and replants a swath there (SWATH studs round it), and on to the next; with nothing to do it parks by the
barn. Its moves are model attributes (From, To, Depart, Arrive, in world space) for every client to animate
(TractorController); the work happens on the server when it gets there. A faster tractor upgrade (a lower `value`)
drives faster, and so do the sheep (the "machine" boost).

Hop on: the tractor's prompt (DRIVE) puts the owner in the seat: the tractor goes where they go (faster than
walking), harvests what's ripe and plants what's empty under it (REACH studs). The prompt again, or Net "Tractor"
("off") from the client's jump, gets them off; it goes back to driving itself.

  TractorService:Model(player)        their tractor model, or nil
  TractorService:Driving(player)      true while they ride it
  TractorService:Drive(player, on)    -> ok
  TractorService:Step(player, dt)     one tick (tests call it)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animals = require(ReplicatedStorage.Shared.Data.Animals)
local Net = require(ReplicatedStorage.Shared.Net)
local PlotLayout = require(ReplicatedStorage.Shared.World.PlotLayout)
local Upgrades = require(ReplicatedStorage.Shared.Data.Upgrades)

local TractorService = {
	Name = "TractorService",
	Dependencies = { "PlayerDataService", "PlotService", "FarmService" },
	SPEED = 14, -- studs a second, driving itself (the first tractor)
	WORK = 0.4, -- seconds it stops at each patch
	SWATH = 8, -- studs round the patch it works
	REACH = 5, -- studs round a driver it works
	DRIVE_SPEED = 26, -- the driver's walk speed on it
	SEAT = 2.6, -- how much higher the driver sits
	TICK = 0.1,
}

local data, plots, farm
local state = {} -- [player] = { pos (local Vector3), target, arrive, driver = bool, walk, hip, full }

local function now()
	return workspace:GetServerTimeNow()
end

function TractorService:Model(player)
	local plot = plots:Plot(player)
	local folder = plot and plot.items:FindFirstChild("tractor")
	return folder and folder:FindFirstChild("Tractor")
end

function TractorService:Driving(player)
	return state[player] ~= nil and state[player].driver == true
end

local function humanoid(player)
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid"), c and c:FindFirstChild("HumanoidRootPart")
end

local function setPrompt(model, driving)
	local prompt = model:FindFirstChild("Drive", true)
	if prompt then
		prompt.ActionText = driving and "Get off" or "Drive"
	end
end

function TractorService:Drive(player, on)
	local model = self:Model(player)
	local s = state[player]
	if not model or not s then
		return false
	end
	local hum = humanoid(player)
	if on and not s.driver then
		if not hum then
			return false
		end
		s.driver = true
		s.walk, s.hip = hum.WalkSpeed, hum.HipHeight
		hum.WalkSpeed = self.DRIVE_SPEED
		hum.HipHeight = s.hip + self.SEAT
		model:SetAttribute("Driver", player.UserId)
		setPrompt(model, true)
		Net.fire(player, "Toast", "Drive over your crops: it harvests and plants as you go! Jump to get off", "good")
		return true
	elseif not on and s.driver then
		s.driver = false
		if hum then
			hum.WalkSpeed = s.walk or 16
			hum.HipHeight = s.hip or 2
		end
		model:SetAttribute("Driver", 0)
		setPrompt(model, false)
		-- (back to driving itself, from where they left it)
		s.arrive = 0
		s.target = nil
		return true
	end
	return false
end

-- Harvest what's ripe and plant what's empty within r of a local spot; how many
local function work(player, at, r)
	local p = data:Get(player)
	local done = 0
	for n in farm:Tiles(player) do
		local t = PlotLayout.soilTile(n)
		if Vector3.new(t.X - at.X, 0, t.Z - at.Z).Magnitude <= r then
			if farm:Ripe(player, n) then
				if farm:Harvest(player, n) then
					done += 1
				end
			end
			if farm:Phase(player, n) == nil and farm:Plant(player, n, nil, true) then
				done += 1
			end
		end
	end
	if done > 0 then
		p.stats.tractored = (p.stats.tractored or 0) + done
		farm:Push(player)
		farm.Changed:Fire(player, "tractor")
	end
	return done
end

-- The patch it goes to next: the nearest ripe one, else the nearest empty one
local function nextPatch(player, from)
	local best, bestD, bestRank
	for n in farm:Tiles(player) do
		local ph = farm:Phase(player, n)
		local rank = ph == 3 and 1 or (ph == nil and 2 or nil)
		if rank then
			local t = PlotLayout.soilTile(n)
			local d = Vector3.new(t.X - from.X, 0, t.Z - from.Z).Magnitude
			if not best or rank < bestRank or (rank == bestRank and d < bestD) then
				best, bestD, bestRank = t, d, rank
			end
		end
	end
	return best
end

local function park()
	return PlotLayout.SPOTS.tractor
end

function TractorService:Step(player, _dt)
	local p = data:Get(player)
	local plot = plots:Plot(player)
	local model = self:Model(player)
	local stat = p and Upgrades.stat(p.owned or {}, "autoharvest", nil)
	if not (p and plot and model and stat) then
		return
	end
	local s = state[player]
	if not s then
		local at = park()
		s = { pos = Vector3.new(at.X, 0, at.Z), arrive = 0 }
		state[player] = s
		model:SetAttribute("Driver", 0)
	end
	local t = now()
	if s.driver then
		local _, root = humanoid(player)
		if not root then
			self:Drive(player, false)
			return
		end
		local l = plot.cf:PointToObjectSpace(root.Position)
		local yaw = plot.cf:VectorToObjectSpace(root.CFrame.LookVector)
		s.pos = Vector3.new(l.X, 0, l.Z)
		local flat = Vector3.new(yaw.X, 0, yaw.Z)
		local cf = CFrame.new(s.pos)
		if flat.Magnitude > 0.01 then
			cf = CFrame.lookAt(s.pos, s.pos + flat.Unit)
		end
		model:PivotTo(plot.cf * cf)
		if farm:Carried(player) >= farm:Carry(player) then
			if not s.full then
				s.full = true
				Net.fire(player, "Toast", "Your basket is full! Sell it at the stand", "info")
			end
		else
			s.full = false
			if work(player, s.pos, self.REACH) > 0 then
				p.stats.driven = (p.stats.driven or 0) + 1
			end
		end
		return
	end
	if t < s.arrive then
		return
	end
	-- arrived: work the swath (unless it's parked), then on to the next patch
	if s.target then
		work(player, s.target, self.SWATH)
		s.pos = s.target
	end
	local quick = (1 + Animals.boost(p, "machine", t)) * (8 / math.max(stat, 1))
	local to = nil
	if farm:Carried(player) < farm:Carry(player) then
		to = nextPatch(player, s.pos)
	end
	local parked = false
	if not to then
		to = park()
		parked = true
	end
	local d = Vector3.new(to.X - s.pos.X, 0, to.Z - s.pos.Z).Magnitude
	if d < 0.5 and parked then
		s.target = nil
		s.arrive = t + 1
		return
	end
	local secs = d / (self.SPEED * quick) + self.WORK
	model:SetAttribute("From", plot.cf * s.pos)
	model:SetAttribute("To", plot.cf * Vector3.new(to.X, 0, to.Z))
	model:SetAttribute("Depart", t)
	model:SetAttribute("Arrive", t + secs - self.WORK)
	-- (the server's own copy sits where it's headed: the clients do the driving)
	local dir = Vector3.new(to.X - s.pos.X, 0, to.Z - s.pos.Z)
	local goal = Vector3.new(to.X, 0, to.Z)
	model:PivotTo(plot.cf * (dir.Magnitude > 0.01 and CFrame.lookAt(goal, goal + dir.Unit) or CFrame.new(goal)))
	s.target = not parked and Vector3.new(to.X, 0, to.Z) or nil
	if parked then
		s.pos = Vector3.new(to.X, 0, to.Z)
	end
	s.arrive = t + secs
end

function TractorService:Init(registry)
	data = registry.PlayerDataService
	plots = registry.PlotService
	farm = registry.FarmService
	-- (the farm's own tractor tick hands over to this)
	farm.tractorDriven = true
	Net.on("Tractor", function(player, what)
		if what == "off" then
			self:Drive(player, false)
		elseif what == "on" then
			self:Drive(player, true)
		end
	end)
	local function forget(player)
		if state[player] and state[player].driver then
			self:Drive(player, false)
		end
		state[player] = nil
	end
	Players.PlayerRemoving:Connect(forget)
	plots.Released:Connect(forget)
end

-- The prompt on a tractor: only its owner drives it
local function hook(self, player)
	local model = self:Model(player)
	if not model or model:FindFirstChild("Drive", true) then
		return
	end
	local body = model:FindFirstChild("TractorBody")
	if not body then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Drive"
	prompt.ActionText = "Drive"
	prompt.ObjectText = "Tractor"
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = body
	prompt.Triggered:Connect(function(who)
		if who ~= player then
			Net.fire(who, "Toast", `That's {player.DisplayName}'s tractor!`, "info")
			return
		end
		self:Drive(player, not self:Driving(player))
	end)
end

function TractorService:Start()
	task.spawn(function()
		while true do
			local dt = task.wait(self.TICK)
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(function()
					hook(self, player)
					self:Step(player, dt)
				end)
				if not ok then
					warn("[TractorService] " .. tostring(err))
				end
			end
		end
	end)
end

return TractorService
