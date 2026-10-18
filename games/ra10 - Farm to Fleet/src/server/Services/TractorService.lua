--[[
The tractors (the "autoharvest" upgrades: Tractor, Bigger Tractor... level 1-5; "tractors": a second one). Each
drives itself round the field to the nearest patch with work, picks and replants `level` patches at a stop, and
on to the next; with nothing to do it parks by the barn. A bigger tractor is quicker too, and so are the sheep
(the "machine" boost). Its moves are model attributes (From, To, Depart, Arrive, in world space) for every client
to animate (TractorController); the work happens on the server when it gets there.

What it picks first: a crop an open order still needs (OrderService, through FarmService.hold), then whatever's
ripe nearest.

Hop on: the first tractor's prompt (DRIVE) puts the owner in the seat: it goes where they go (faster than walking),
picks what's ripe and plants what's empty under it (REACH studs). The prompt again, or Net "Tractor" ("off") from
the client's jump, gets them off; it goes back to driving itself.

  TractorService:Model(player, i?)    their tractor model (1 or 2), or nil
  TractorService:Level(player)        the tractors' level (1-5)
  TractorService:Driving(player)      true while they ride one
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
	SPEED = 14, -- studs a second, driving itself (level 1; +20% a level)
	WORK = 0.4, -- seconds it stops at each patch
	REACH = 5, -- studs round a driver it works
	DRIVE_SPEED = 26, -- the driver's walk speed on it
	SEAT = 2.6, -- how much higher the driver sits
	TICK = 0.1,
}

local data, plots, farm
local state = {} -- [player] = { [i] = { pos (local Vector3), target, arrive }, driver = bool, walk, hip, full }
local NAMES = { "Tractor", "Tractor2" }
local FOLDERS = { "tractor", "secondTractor" }

local function now()
	return workspace:GetServerTimeNow()
end

function TractorService:Model(player, i)
	local plot = plots:Plot(player)
	local folder = plot and plot.items:FindFirstChild(FOLDERS[i or 1])
	return folder and folder:FindFirstChild(NAMES[i or 1])
end

function TractorService:Level(player)
	local p = data:Get(player)
	return p and Upgrades.stat(p.owned or {}, "autoharvest", 0) or 0
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
	local model = self:Model(player, 1)
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
		Net.fire(player, "Toast", "Drive over your crops: it picks and plants as you go! Jump to get off", "good")
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
		s[1].arrive = 0
		s[1].target = nil
		return true
	end
	return false
end

-- Does this patch have work: ripe (2 if an order wants its crop), empty (1), or none
local function workOf(player, p, n, needs)
	local ph = farm:Phase(player, n)
	if ph == 3 then
		local t = p.soil[tostring(n)]
		return (needs and t and (needs[t.crop] or 0) > 0) and 3 or 2
	elseif ph == nil then
		return 1
	end
	return 0
end

-- Pick what's ripe and plant what's empty within r of a local spot, up to `count` patches; how many
local function work(player, at, r, count)
	local p = data:Get(player)
	local list = {}
	for n in farm:Tiles(player) do
		local t = PlotLayout.soilTile(n)
		local d = Vector3.new(t.X - at.X, 0, t.Z - at.Z).Magnitude
		if d <= r then
			table.insert(list, { n = n, d = d })
		end
	end
	table.sort(list, function(a, b)
		return a.d < b.d
	end)
	local done = 0
	for _, e in list do
		if count and done >= count then
			break
		end
		local did = false
		if farm:Ripe(player, e.n) and farm:Harvest(player, e.n) then
			did = true
		end
		if farm:Phase(player, e.n) == nil and farm:Plant(player, e.n, nil, true) then
			did = true
		end
		if did then
			done += 1
		end
	end
	if done > 0 then
		p.stats.tractored = (p.stats.tractored or 0) + done
		farm:Push(player)
		farm.Changed:Fire(player, "tractor")
	end
	return done
end

-- The patch it goes to next: what an order needs first, then the nearest with work, so it sweeps the field
local function nextPatch(player, p, from, taken)
	local needs = farm.hold and farm.hold(player)
	local best, bestD, bestRank
	for n in farm:Tiles(player) do
		local rank = workOf(player, p, n, needs)
		if rank > 0 and not (taken and taken[n]) then
			local t = PlotLayout.soilTile(n)
			local d = Vector3.new(t.X - from.X, 0, t.Z - from.Z).Magnitude
			if not best or rank > bestRank or (rank == bestRank and d < bestD) then
				best, bestD, bestRank = n, d, rank
			end
		end
	end
	return best and PlotLayout.soilTile(best) or nil, best
end

local function park(i)
	return i == 2 and PlotLayout.SPOTS.tractor2 or PlotLayout.SPOTS.tractor
end

local function stepOne(self, player, p, plot, i, s, t)
	local model = self:Model(player, i)
	if not model then
		return
	end
	local me = s[i]
	if not me then
		local at = park(i)
		me = { pos = Vector3.new(at.X, 0, at.Z), arrive = 0 }
		s[i] = me
		model:SetAttribute("Driver", 0)
	end
	if t < me.arrive then
		return
	end
	local level = math.max(1, self:Level(player))
	-- arrived: work the patches round it (the level says how many), then on to the next
	if me.target then
		work(player, me.target, 4 + level * 1.5, level)
		me.pos = me.target
	end
	local quick = (1 + Animals.boost(p, "machine", t)) * (1 + 0.2 * (level - 1))
	local to, n = nil, nil
	if not farm:Full(player) then
		local taken = {}
		for j, other in ipairs(s) do
			if j ~= i and other.patch then
				taken[other.patch] = true
			end
		end
		to, n = nextPatch(player, p, me.pos, taken)
	end
	local parked = false
	if not to then
		to = park(i)
		parked = true
	end
	me.patch = n
	local d = Vector3.new(to.X - me.pos.X, 0, to.Z - me.pos.Z).Magnitude
	if d < 0.5 and parked then
		me.target = nil
		me.arrive = t + 1
		return
	end
	local secs = d / (self.SPEED * quick) + self.WORK
	model:SetAttribute("From", plot.cf * me.pos)
	model:SetAttribute("To", plot.cf * Vector3.new(to.X, 0, to.Z))
	model:SetAttribute("Depart", t)
	model:SetAttribute("Arrive", t + secs - self.WORK)
	-- (the clients do the driving from these: the server never moves its copy while it drives itself)
	me.target = not parked and Vector3.new(to.X, 0, to.Z) or nil
	if parked then
		me.pos = Vector3.new(to.X, 0, to.Z)
	end
	me.arrive = t + secs
end

function TractorService:Step(player, _dt)
	local p = data:Get(player)
	local plot = plots:Plot(player)
	local model = self:Model(player, 1)
	if not (p and plot and model) or self:Level(player) <= 0 then
		return
	end
	local s = state[player]
	if not s then
		s = {}
		state[player] = s
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
		s[1] = s[1] or { pos = Vector3.new(l.X, 0, l.Z), arrive = 0 }
		s[1].pos = Vector3.new(l.X, 0, l.Z)
		local flat = Vector3.new(yaw.X, 0, yaw.Z)
		local cf = CFrame.new(s[1].pos)
		if flat.Magnitude > 0.01 then
			cf = CFrame.lookAt(s[1].pos, s[1].pos + flat.Unit)
		end
		model:PivotTo(plot.cf * cf)
		if farm:Full(player) then
			if not s.full then
				s.full = true
				Net.fire(player, "Toast", "The barn is full! Sell some crops to make room", "info")
			end
		else
			s.full = false
			if work(player, s[1].pos, self.REACH, nil) > 0 then
				p.stats.driven = (p.stats.driven or 0) + 1
			end
		end
	else
		stepOne(self, player, p, plot, 1, s, t)
	end
	if Upgrades.stat(p.owned or {}, "tractors", 1) >= 2 and self:Model(player, 2) then
		stepOne(self, player, p, plot, 2, s, t)
	end
end

function TractorService:Init(registry)
	data = registry.PlayerDataService
	plots = registry.PlotService
	farm = registry.FarmService
	-- (the farm's own tractor tick hands over to this; the animals' walk speed leaves a driver alone)
	farm.tractorDriven = true
	farm.Driving = function(player)
		return self:Driving(player)
	end
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

-- The prompt on the first tractor: only its owner drives it
local function hook(self, player)
	local model = self:Model(player, 1)
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
