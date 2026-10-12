-- Where each player is (the Hub or a planet), the GO and HOME pads, unlocking planets, and sending fallers home.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Net)
local Planets = require(ReplicatedStorage.Shared.Data.Planets)
local Signal = require(ReplicatedStorage.Shared.Signal)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local PlanetService = {
	Name = "PlanetService",
	Dependencies = { "PlayerDataService" },
	Arrived = Signal.new("PlanetService.Arrived"), -- (player, planetKey | "HUB")
	PlanetOpened = Signal.new("PlanetService.PlanetOpened"), -- (player, planetKey)
}

local data
local where = {} -- [player] = planetKey or "HUB"
local onPad = {} -- [player] = pad part they're standing on (so a pad fires once per step)
local layout

local function position(player)
	local c = player.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	return hrp and hrp.Position
end

local function onDisc(center, radius, pos)
	return Vector3.new(pos.X - center.X, 0, pos.Z - center.Z).Magnitude <= radius and math.abs(pos.Y - center.Y) < 8
end

-- The highest planet a player may visit: planet n+1 opens when planet n's boss is beaten.
function PlanetService:Unlocked(player)
	local profile = data:Get(player)
	local n = 1
	if profile then
		for i, p in Planets.list do
			if (profile.beaten[p.key] or 0) > 0 then
				n = math.max(n, math.min(i + 1, #Planets.list))
			end
		end
	end
	return n
end

function PlanetService:CanVisit(player, planetKey)
	local i = Planets.indexOf[planetKey]
	return i ~= nil and i <= self:Unlocked(player)
end

function PlanetService:Where(player)
	return where[player] or "HUB"
end

function PlanetService:PushPlanet(player)
	data:Push(player, { planet = self:Where(player), unlocked = self:Unlocked(player) })
end

-- Teleport. target: a planet key or "HUB".
function PlanetService:Travel(player, target)
	local c = player.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false
	end
	local pos
	if target == "HUB" then
		pos = layout.spawn.Position + Vector3.new(0, 3, 0)
	else
		if not self:CanVisit(player, target) then
			local i = Planets.indexOf[target]
			local before = i and Planets.list[i - 1]
			Net.fire(
				player,
				"Toast",
				before and `🔒 Beat the {before.boss} on {before.name} first!` or "🔒 Locked",
				"bad"
			)
			return false
		end
		pos = layout.planets[Planets.indexOf[target]].arrive + Vector3.new(0, 3, 0)
	end
	hrp.CFrame = CFrame.new(pos, pos + (target == "HUB" and Vector3.new(0, 0, -1) or Vector3.new(1, 0, 0)))
	hrp.AssemblyLinearVelocity = Vector3.zero
	where[player] = target
	self:PushPlanet(player)
	self.Arrived:Fire(player, target)
	if target ~= "HUB" then
		local p = Planets.byKey[target]
		Net.fire(player, "Alert", `{p.emoji} {string.upper(p.name)}: blast {p.bug}s!`, p.color)
	end
	return true
end

-- Called by BossService when a boss falls: opens the next planet (and says so).
function PlanetService:BossBeaten(player, planetKey)
	local profile = data:Get(player)
	if not profile then
		return
	end
	local before = self:Unlocked(player)
	profile.beaten[planetKey] = (profile.beaten[planetKey] or 0) + 1
	local after = self:Unlocked(player)
	self:PushPlanet(player)
	if after > before then
		local p = Planets.list[after]
		Net.fire(player, "Alert", `🔓 {p.name} planet is OPEN! Go to the Hub!`, Color3.fromRGB(120, 255, 140))
		self.PlanetOpened:Fire(player, p.key)
	end
end

-- Light up the GO pads a player can use (the pad signs are shared, so the sign shows the general rule, and the
-- pad itself just glows for everyone).
function PlanetService:_step()
	for _, player in Players:GetPlayers() do
		local pos = position(player)
		if pos then
			-- fell off into space: home
			if pos.Y < -40 then
				self:Travel(player, "HUB")
				Net.fire(player, "Toast", "Whoa! Back to the Hub you go. 🏠", "info")
			else
				-- track where they are (teleports set it; walking off a pad keeps it)
				local standing
				for _, gp in layout.hub.goPads do
					if onDisc(gp.center, WorldBuilder.PAD_RADIUS, pos) then
						standing = gp.part
						if onPad[player] ~= gp.part then
							self:Travel(player, gp.planet.key)
						end
					end
				end
				for _, pl in layout.planets do
					if onDisc(pl.homeCenter, WorldBuilder.PAD_RADIUS, pos) then
						standing = pl.homePad
						if onPad[player] ~= pl.homePad then
							self:Travel(player, "HUB")
						end
					end
				end
				onPad[player] = standing
			end
		end
	end
end

function PlanetService:Init(registry)
	data = registry.PlayerDataService
	layout = WorldBuilder.layout
	Net.on("Travel", function(player, target)
		if target == "HUB" or (typeof(target) == "string" and Planets.byKey[target]) then
			self:Travel(player, target)
		end
	end)
	data.ClientReady:Connect(function(player)
		self:PushPlanet(player)
	end)
end

function PlanetService:OnPlayerReady(player)
	where[player] = "HUB"
	local function spawned(character)
		local hum = character:WaitForChild("Humanoid", 5)
		if hum then
			hum.WalkSpeed = WorldBuilder.WALK_SPEED or 18
		end
		-- respawns land in the hub
		where[player] = "HUB"
		self:PushPlanet(player)
	end
	if player.Character then
		spawned(player.Character)
	end
	player.CharacterAdded:Connect(spawned)
end

function PlanetService:OnPlayerLeaving(player)
	where[player] = nil
	onPad[player] = nil
end

function PlanetService:Start()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.15 then
			acc = 0
			self:_step()
		end
	end)
end

return PlanetService
