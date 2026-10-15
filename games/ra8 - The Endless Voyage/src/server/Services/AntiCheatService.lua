--[[
Anti-cheat (master plan §14: the server is the authority). The server already decides every hit, every item, every
raft piece and every creature, so nobody can give themselves loot, damage or health; what's left is cheating with
your character. Checked on the server four times a second:
  speed      moving faster than your legs allow (the swift buff included), judged over AC_WINDOW seconds so lag
             bursts don't count: pulled back to where you were, + a strike
  teleport   the same check with a huge jump: + 3 strikes
  flying     hovering high above the ground for AC_AIR_SECONDS: dropped back down, + 2 strikes
  spam       firing requests at auto-clicker rates (AC_SPAM_DROPS dropped in AC_SPAM_WINDOW s): + a strike
Strikes fade (one every AC_DECAY_SECONDS); at AC_KICK_STRIKES you're kicked (admins never are). Flags go to
analytics and the game log. Our own moves (spawning, the rowboat, sailing home) set the "AcGrace" attribute so
they never count. Swimming counts as ground (the water holds you up).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local AntiCheatService = {
	Name = "AntiCheatService",
	Dependencies = { "PlayerDataService", "PlayerService" },
	Flagged = Signal.new("AntiCheatService.Flagged"), -- (player, kind, detail, strikes)
	Kicked = Signal.new("AntiCheatService.Kicked"), -- (player, reason)
}

local SAMPLE = 0.25
local survivors
local state = {} -- [player] = { samples, strikes, lastDecay, air, drops, dropsSince, kicked, warned }

local function st(player)
	local s = state[player]
	if not s then
		s = { samples = {}, strikes = 0, lastDecay = os.clock(), air = 0, drops = 0 }
		state[player] = s
	end
	return s
end

local function rootOf(player)
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart"), c and c:FindFirstChildOfClass("Humanoid")
end

local function clock()
	return workspace:GetServerTimeNow()
end

local function inGrace(player)
	local g = player:GetAttribute("AcGrace")
	return type(g) == "number" and g > clock()
end

-- Studs from a position down to the ground (nil if it can't tell). Tests replace this.
function AntiCheatService.groundDistance(player, pos)
	local ok, result = pcall(function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { player.Character }
		params.RespectCanCollide = true
		return workspace:Raycast(pos, Vector3.new(0, -400, 0), params)
	end)
	if not ok then
		return nil
	end
	return result and (pos.Y - result.Position.Y) or 400
end

function AntiCheatService.maxSpeed(player)
	local _, hum = rootOf(player)
	local allowed = survivors and survivors:MaxSpeed(player) or Constants.WALK_SPEED
	local walk = math.max(hum and hum.WalkSpeed or 0, allowed)
	return walk * Constants.AC_SPEED_SLACK + Constants.AC_SPEED_EXTRA
end

function AntiCheatService:Flag(player, kind, detail, strikes)
	local s = st(player)
	if s.kicked then
		return
	end
	s.strikes += strikes
	self.Flagged:Fire(player, kind, detail, s.strikes)
	if s.strikes >= Constants.AC_KICK_STRIKES and not Constants.ADMINS[player.UserId] then
		s.kicked = true
		self.Kicked:Fire(player, `cheating ({kind})`)
		task.defer(function()
			pcall(player.Kick, player, "Kicked by the anti-cheat. Play fair and your raft's waiting for you! ⛵")
		end)
	elseif s.strikes >= Constants.AC_KICK_STRIKES / 2 and not s.warned then
		s.warned = true
		Net.fire(
			player,
			"Alert",
			"⚠️ The anti-cheat noticed something odd. Keep cheating and you'll be kicked.",
			Color3.fromRGB(255, 110, 90)
		)
	end
end

function AntiCheatService.reset(player)
	local s = st(player)
	s.samples = {}
	s.air = 0
end

function AntiCheatService:_checkMovement(player, s, hrp, now)
	local pos = hrp.Position
	if inGrace(player) then
		s.samples = { { now, pos } }
		s.air = 0
		return
	end
	table.insert(s.samples, { now, pos })
	while #s.samples > 2 and now - s.samples[2][1] >= Constants.AC_WINDOW do
		table.remove(s.samples, 1)
	end
	local first = s.samples[1]
	local dt = now - first[1]
	if dt >= Constants.AC_WINDOW * 0.75 then
		local d = pos - first[2]
		local flat = Vector3.new(d.X, 0, d.Z).Magnitude
		local allowed = AntiCheatService.maxSpeed(player) * dt + 6
		if flat > allowed then
			local teleport = flat > allowed + 60
			player:SetAttribute("AcGrace", clock() + 0.6)
			pcall(function()
				hrp.AssemblyLinearVelocity = Vector3.zero
				hrp.CFrame = CFrame.new(first[2]) * (hrp.CFrame - hrp.CFrame.Position)
			end)
			s.samples = { { now, first[2] } }
			self:Flag(
				player,
				teleport and "teleport" or "speed",
				`{math.floor(flat)} studs in {math.floor(dt * 10) / 10}s (max {math.floor(allowed)})`,
				teleport and 3 or 1
			)
			return
		end
	end
	local ground = AntiCheatService.groundDistance(player, pos)
	if not ground then
		return
	end
	-- the sea holds you up: the water's surface is the ground there
	ground = math.min(ground, math.max(0, pos.Y - Constants.WATER_LEVEL))
	local vy = hrp.AssemblyLinearVelocity.Y
	if ground > Constants.AC_AIR_HEIGHT and math.abs(vy) < 10 then
		s.air += SAMPLE
	else
		s.air = 0
	end
	if s.air >= Constants.AC_AIR_SECONDS then
		s.air = 0
		player:SetAttribute("AcGrace", clock() + 1)
		pcall(function()
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.CFrame = CFrame.new(pos - Vector3.new(0, ground - 3, 0)) * (hrp.CFrame - hrp.CFrame.Position)
		end)
		s.samples = {}
		self:Flag(player, "flying", `{math.floor(ground)} studs up`, 2)
	end
end

function AntiCheatService:_step()
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local s = st(player)
		if now - s.lastDecay >= Constants.AC_DECAY_SECONDS then
			s.lastDecay = now
			s.strikes = math.max(0, s.strikes - 1)
		end
		local hrp, hum = rootOf(player)
		if hrp and hum and hum.Health > 0 then
			self:_checkMovement(player, s, hrp, now)
		else
			s.samples = {}
		end
	end
end

function AntiCheatService:Init(registry)
	survivors = registry.PlayerService
	Net.onDrop(function(player)
		local s = st(player)
		local now = os.clock()
		if now - (s.dropsSince or 0) > Constants.AC_SPAM_WINDOW then
			s.dropsSince, s.drops = now, 0
		end
		s.drops += 1
		if s.drops == Constants.AC_SPAM_DROPS then
			self:Flag(player, "spam", `{s.drops} requests dropped in {Constants.AC_SPAM_WINDOW}s`, 1)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		state[player] = nil
	end)
end

function AntiCheatService:OnPlayerReady(player)
	st(player)
	player:SetAttribute("AcGrace", clock() + 3)
	player.CharacterAdded:Connect(function()
		AntiCheatService.reset(player)
		player:SetAttribute("AcGrace", clock() + 3)
	end)
end

function AntiCheatService:Start()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= SAMPLE then
			acc = 0
			self:_step()
		end
	end)
end

-- (tests)
AntiCheatService.state = state
return AntiCheatService
