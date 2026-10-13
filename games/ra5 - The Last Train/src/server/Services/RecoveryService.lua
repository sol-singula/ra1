-- Left behind: when the doors shut with you outside, the train doesn't come back for you, but you're not out of the
-- game either. You lose what was in your field bag (never anything in your cabin or storage) and wake up at an
-- emergency signal hut in the woods (World/RecoveryBuilder). Find RECOVERY_FUSES fuses in the grass, fit them in the
-- fuse box, pull the signal lever: a flare goes up and a maintenance trolley brings you back to the train
-- (RECOVERY_PICKUP_WAIT seconds later, or right away with the Radio Mast). If the expedition ends first, you're
-- brought back to the station with everyone else. All of it is server-owned state.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Kit = require(ReplicatedStorage.Shared.World.Kit)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local RecoveryService = {
	Name = "RecoveryService",
	Dependencies = { "PlayerDataService", "ExpeditionService", "ResourceService", "TrainService" },
	Stranded = Signal.new("RecoveryService.Stranded"), -- (player, itemsLost)
	Step = Signal.new("RecoveryService.Step"), -- (player, step)
	Recovered = Signal.new("RecoveryService.Recovered"), -- (player, seconds)
}

local data, expedition, resources, train
local stranded = {} -- [player] = { step = "fuses" | "box" | "lever" | "waiting", found = { [i] = true }, at, pickupAt }
local fuses = {} -- [i] = part

local TEXT = {
	fuses = "The train left without you! Find 3 fuses in the grass around the hut.",
	box = "Fit the fuses in the fuse box inside the hut.",
	lever = "Pull the signal lever!",
	waiting = "Signal sent! A maintenance trolley is on its way...",
}

local function now()
	return workspace:GetServerTimeNow()
end

function RecoveryService:IsStranded(player)
	return stranded[player] ~= nil
end

function RecoveryService:State(player)
	return stranded[player]
end

function RecoveryService:SpawnCf()
	return WorldBuilder.layout.recovery.spawn
end

function RecoveryService:_push(player)
	local s = stranded[player]
	if not s then
		Net.fire(player, "Recovery", false)
		return
	end
	local found, list = 0, {}
	for i in s.found do
		found += 1
		table.insert(list, i)
	end
	Net.fire(player, "Recovery", {
		step = s.step,
		found = found,
		need = Constants.RECOVERY_FUSES,
		taken = list,
		text = s.step == "fuses" and `{TEXT.fuses} ({found}/{Constants.RECOVERY_FUSES})` or TEXT[s.step],
		pickupAt = s.pickupAt,
	})
end

function RecoveryService:Strand(player)
	if stranded[player] then
		return
	end
	local lost = resources:LoseBag(player)
	stranded[player] = { step = "fuses", found = {}, at = now(), pickupAt = nil }
	local profile = data:Get(player)
	if profile then
		profile.stats.stranded += 1
	end
	Net.fire(player, "Fade", 1.2, "The train left without you...")
	task.delay(0.6, function()
		if stranded[player] then
			expedition:Teleport(player, self:SpawnCf())
		end
	end)
	if lost > 0 then
		Net.fire(player, "Toast", `You lost the {lost} things in your bag. Your cabin and storage are safe.`, "bad")
	end
	self:_push(player)
	self.Stranded:Fire(player, lost)
end

local function near(player, part, range)
	local c = player.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	return hrp ~= nil and (hrp.Position - part.Position).Magnitude <= (range or 12)
end

function RecoveryService:TakeFuse(player, i)
	local s = stranded[player]
	local fuse = fuses[i]
	if not s or s.step ~= "fuses" or not fuse or s.found[i] or not near(player, fuse) then
		return false
	end
	s.found[i] = true
	local n = 0
	for _ in s.found do
		n += 1
	end
	if n >= Constants.RECOVERY_FUSES then
		s.step = "box"
		self.Step:Fire(player, "box")
	end
	Net.fire(player, "Sfx", "pickup")
	self:_push(player)
	return true
end

function RecoveryService:FitFuses(player)
	local s = stranded[player]
	local rec = WorldBuilder.layout.recovery
	if not s or s.step ~= "box" or not near(player, rec.fuseBox) then
		return false
	end
	s.step = "lever"
	Net.fire(player, "Sfx", "build")
	self.Step:Fire(player, "lever")
	self:_push(player)
	return true
end

function RecoveryService:PullLever(player)
	local s = stranded[player]
	local rec = WorldBuilder.layout.recovery
	if not s or s.step ~= "lever" or not near(player, rec.lever) then
		return false
	end
	s.step = "waiting"
	local fast = train:Stage("lamp") >= 2
	s.pickupAt = now() + (fast and Constants.RECOVERY_PICKUP_FAST or Constants.RECOVERY_PICKUP_WAIT)
	Net.fire(player, "Sfx", "flare", rec.flare.Position)
	Net.fire(
		player,
		"Popup",
		rec.flare.Position + Vector3.new(0, 6, 0),
		"🚨 SIGNAL SENT",
		Color3.fromRGB(255, 90, 70)
	)
	self.Step:Fire(player, "waiting")
	self:_push(player)
	return true
end

-- Back aboard (or back at the station if the expedition is over).
function RecoveryService:Return(player)
	local s = stranded[player]
	if not s then
		return
	end
	stranded[player] = nil
	local profile = data:Get(player)
	if profile then
		profile.stats.recovered += 1
	end
	expedition:Note(player, "recovered", 1) -- found their way back (crew recognition)
	Net.fire(player, "Fade", 1.2, "Back on the train!")
	task.delay(0.6, function()
		if player.Parent then
			expedition:Teleport(player, expedition:SpawnCf(player))
		end
	end)
	self:_push(player)
	self.Recovered:Fire(player, now() - s.at)
end

function RecoveryService:Init(registry)
	data = registry.PlayerDataService
	expedition = registry.ExpeditionService
	resources = registry.ResourceService
	train = registry.TrainService
	local rec = WorldBuilder.layout.recovery
	-- the fuses: glowing yellow cartridges in the grass (each stranded player takes their own)
	for i, cf in rec.fuseSpots do
		local fuse = Kit.box(
			rec.model,
			"Fuse",
			cf * CFrame.new(0, 0.5, 0),
			Vector3.new(0.8, 1, 0.8),
			Color3.fromRGB(255, 210, 60),
			Kit.M.Neon,
			{
				CastShadow = false,
				CanCollide = false,
			}
		)
		Kit.light(fuse, "PointLight", { Range = 10, Brightness = 1.4, Color = Color3.fromRGB(255, 210, 80) })
		fuse:SetAttribute("Fuse", i)
		local p = Instance.new("ProximityPrompt")
		p.Name = "Prompt_fuse"
		p.ActionText = "Pick up"
		p.ObjectText = "Fuse"
		p.HoldDuration = 0.5
		p.MaxActivationDistance = 10
		p.RequiresLineOfSight = false
		p.Parent = fuse
		p.Triggered:Connect(function(player)
			self:TakeFuse(player, i)
		end)
		fuses[i] = fuse
	end
	local boxPrompt = Instance.new("ProximityPrompt")
	boxPrompt.Name = "Prompt_fusebox"
	boxPrompt.ActionText = "Fit the fuses"
	boxPrompt.ObjectText = "Fuse box"
	boxPrompt.HoldDuration = 1
	boxPrompt.MaxActivationDistance = 10
	boxPrompt.RequiresLineOfSight = false
	boxPrompt.Parent = rec.fuseBox
	boxPrompt.Triggered:Connect(function(player)
		self:FitFuses(player)
	end)
	local leverPrompt = Instance.new("ProximityPrompt")
	leverPrompt.Name = "Prompt_lever"
	leverPrompt.ActionText = "Pull"
	leverPrompt.ObjectText = "Signal lever"
	leverPrompt.HoldDuration = 1
	leverPrompt.MaxActivationDistance = 10
	leverPrompt.RequiresLineOfSight = false
	leverPrompt.Parent = rec.lever
	leverPrompt.Triggered:Connect(function(player)
		self:PullLever(player)
	end)
	-- a new expedition: everyone still out here comes back to the station
	expedition.Started:Connect(function()
		for player in stranded do
			self:Return(player)
		end
	end)
	data.ClientReady:Connect(function(player)
		self:_push(player)
	end)
end

function RecoveryService:OnPlayerLeaving(player)
	stranded[player] = nil
end

function RecoveryService:Start()
	while true do
		task.wait(0.5)
		local t = now()
		for player, s in stranded do
			if s.step == "waiting" and s.pickupAt and t >= s.pickupAt then
				self:Return(player)
			end
		end
	end
end

return RecoveryService
