--[[
The street and its six plots (master plan §10). The server builds the street once (World/FarmBuilder.world);
everyone who joins gets the first free plot, its sign with their name, the plot's base pieces (the shack, the stand,
the pads: FarmBuilder.base), and lands on the track in front of it. Leaving frees the plot and takes its pieces
down; the save keeps everything to rebuild next time.

  PlotService:Plot(player)      the plot table (World/FarmBuilder's), or nil
  PlotService:Refs(player)      the plot's live pieces: { stand pad, pads, tiles }
  PlotService:Owner(index)      who has plot i
  PlotService:World()
  PlotService:Spawn(player)     a body in front of their plot (again after a fall or a reset)
  PlotService:Near(player, part, radius)   their root within radius of a part (on the ground plane)
  PlotService.Claimed (player, plot) · PlotService.Released (player, plot)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FarmBuilder = require(ReplicatedStorage.Shared.World.FarmBuilder)
local Net = require(ReplicatedStorage.Shared.Net)
local PlotLayout = require(ReplicatedStorage.Shared.World.PlotLayout)
local Signal = require(ReplicatedStorage.Shared.Signal)

local PlotService = {
	Name = "PlotService",
	Dependencies = { "PlayerDataService" },
	Claimed = Signal.new("PlotService.Claimed"),
	Released = Signal.new("PlotService.Released"),
	RESPAWN = 2,
}

local data
local world
local owners = {} -- [index] = player
local mine = {} -- [player] = { plot, refs }
local spawning = {}

function PlotService:World()
	return world
end

function PlotService:Plot(player)
	return mine[player] and mine[player].plot
end

function PlotService:Refs(player)
	return mine[player] and mine[player].refs
end

function PlotService:Owner(index)
	return owners[index]
end

local function root(player)
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end
PlotService.root = root

function PlotService:Near(player, part, radius)
	local r = root(player)
	if not r or not part then
		return false
	end
	local a, b = r.Position, part.Position
	local dx, dz = a.X - b.X, a.Z - b.Z
	return dx * dx + dz * dz <= radius * radius and math.abs(a.Y - b.Y) <= 8
end

local function signFor(plot, player)
	FarmBuilder.sign(plot.sign, player and `{string.upper(player.DisplayName)}'S FARM` or "FOR SALE", "", plot.color)
end

local function streetView()
	local list = {}
	for i = 1, #world.plots do
		local p = owners[i]
		list[i] = p and { name = p.DisplayName, userId = p.UserId } or false
	end
	return list
end

function PlotService:Spawn(player)
	if not player.Parent or spawning[player] then
		return
	end
	spawning[player] = true
	local ok = pcall(function()
		player:LoadCharacter()
	end)
	spawning[player] = nil
	if not ok or not player.Parent then
		return
	end
	local c = player.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	local m = mine[player]
	if r and m then
		-- (once the market hall stands where the stand was, beside it instead)
		local p = data:Get(player)
		local s = p and p.owned and p.owned.marketHall and PlotLayout.SPOTS.spawnHub or PlotLayout.SPOTS.spawn
		local at = PlotLayout.toWorld(m.plot.index, s.X, s.Z, s.Y)
		local look =
			PlotLayout.toWorld(m.plot.index, PlotLayout.SPOTS.soil.X, PlotLayout.SPOTS.soil.Z, PlotLayout.SPOTS.spawn.Y)
		r.CFrame = CFrame.lookAt(at, look)
	end
	player:SetAttribute("AcGrace", os.clock() + 2)
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Died:Connect(function()
			task.delay(self.RESPAWN, function()
				if player.Parent and player.Character == c then
					self:Spawn(player)
				end
			end)
		end)
	end
end

local function release(player)
	local m = mine[player]
	if not m then
		return
	end
	mine[player] = nil
	owners[m.plot.index] = nil
	FarmBuilder.clear(m.plot)
	signFor(m.plot, nil)
	PlotService.Released:Fire(player, m.plot)
	Net.fireAll("Plot", { street = streetView() })
end

function PlotService:Init(registry)
	data = registry.PlayerDataService
	for _, d in workspace:GetChildren() do
		if (d:IsA("BasePart") and (d.Name == "Baseplate" or d:IsA("SpawnLocation"))) or d.Name == "Baseplate" then
			d:Destroy()
		end
	end
	FarmBuilder.light()
	world = FarmBuilder.world(workspace)
	Players.PlayerRemoving:Connect(function(player)
		release(player)
		spawning[player] = nil
	end)
end

-- (first of the plot's services: the plot and its base exist before the farm and the pads fill it)
function PlotService:OnPlayerLoaded(player)
	-- (a rebuild keeps their plot: the one they had, if it's still free)
	local had = player:GetAttribute("Plot")
	local order = {}
	if type(had) == "number" and world.plots[had] then
		table.insert(order, had)
	end
	for i = 1, #world.plots do
		table.insert(order, i)
	end
	for _, i in order do
		if not owners[i] then
			owners[i] = player
			local plot = world.plots[i]
			mine[player] = { plot = plot, refs = FarmBuilder.base(plot) }
			player:SetAttribute("Plot", i)
			signFor(plot, player)
			self.Claimed:Fire(player, plot)
			return
		end
	end
	player:Kick("This farm street is full. Please join another server!")
end

function PlotService:OnPlayerReady(player)
	if not mine[player] then
		return
	end
	self:Spawn(player)
	data:WhenClientReady(player, function()
		Net.fire(player, "Plot", { index = mine[player] and mine[player].plot.index, street = streetView() })
		Net.fireAll("Plot", { street = streetView() })
	end)
end

function PlotService:OnPlayerLeaving(player)
	release(player)
end

function PlotService:Start()
	while true do
		task.wait(0.5)
		for player in mine do
			local r = root(player)
			if r and r.Position.Y < -30 then
				self:Spawn(player)
			end
		end
	end
end

return PlotService
