-- Anti-cheat. The server already decides everything that matters (coins, steals, bonks, buying, reach), so a
-- cheater can't give themselves coins or dragons; what's left is cheating with your character. Checked here, on
-- the server, a few times a second:
--   speed      moving faster than you possibly can (speed level, potion, wings), judged over AC_WINDOW seconds so
--              lag bursts don't count: pulled back to where you were, + a strike
--   teleport   the same check, but a huge jump: + 3 strikes
--   flying     hovering high above the ground for AC_AIR_SECONDS without the VIP wings (or far above the sky
--              ceiling with them): dropped back to the ground, + 2 strikes
--   noclip     standing inside someone's locked base (walls and the red laser are solid, and flyers are bounced
--              before they land): BaseService bounces you out, + 2 strikes
--   spam       firing server requests far faster than the game ever does: + a strike per AC_SPAM_DROPS
-- Strikes fade (one every AC_DECAY_SECONDS); at AC_KICK_STRIKES you're kicked. Every flag goes to the Discord game
-- log and analytics (Flagged / Kicked). Our own teleports and knockbacks set the player's "AcGrace" attribute (an
-- os.clock() time) so they never count. Admins are logged but never kicked.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local AntiCheatService = {
	Name = "AntiCheatService",
	Dependencies = { "PlayerDataService", "BaseService", "EconomyService", "TeamService" },
	Flagged = Signal.new("AntiCheatService.Flagged"), -- (player, kind, detail, strikes)
	Kicked = Signal.new("AntiCheatService.Kicked"), -- (player, reason)
}

local baseService, economy, team

local SAMPLE = 0.25 -- seconds between checks

local state = {} -- [player] = { samples = { {t, pos} }, strikes, lastDecay, air, drops, kicked }

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

local function inGrace(player)
	local g = player:GetAttribute("AcGrace")
	return type(g) == "number" and g > os.clock()
end

local function hasWings(player)
	return economy:HasPass(player, "VIP")
end

-- Studs from a position down to the ground (or nil if it can't tell). Tests replace this.
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

-- The fastest this player can legitimately move along the ground or through the air (studs per second).
function AntiCheatService.maxSpeed(player)
	local _, hum = rootOf(player)
	local walk = math.max(hum and hum.WalkSpeed or 0, Constants.BASE_WALK_SPEED)
	if hum and hum.WalkSpeed < Constants.BASE_WALK_SPEED * Constants.POTION_SPEED_MULT then
		-- a speed potion may start between two checks
		walk = math.max(walk, hum.WalkSpeed * Constants.POTION_SPEED_MULT)
	end
	if hasWings(player) then
		walk = math.max(walk, Constants.FLY_SPEED, Constants.GLIDE_SPEED)
	end
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
		local reason = `cheating ({kind})`
		self.Kicked:Fire(player, reason)
		task.defer(function()
			pcall(player.Kick, player, "Kicked by the anti-cheat. Play fair and you're welcome back! 🐉")
		end)
	elseif s.strikes >= Constants.AC_KICK_STRIKES / 2 and not s.warned then
		s.warned = true
		Net.fire(player, "Alert", "⚠️ The anti-cheat noticed something odd. Keep cheating and you'll be kicked.")
	end
end

-- Forget where they were (a new character, or after we moved them).
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
	-- keep a little more than one window of samples
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
			-- pull them back to where they were
			player:SetAttribute("AcGrace", os.clock() + 0.6)
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
	-- flying: high above the ground and not falling, for too long
	local ground = AntiCheatService.groundDistance(player, pos)
	if not ground then
		return
	end
	local vy = hrp.AssemblyLinearVelocity.Y
	local wings = hasWings(player)
	local limit = wings and (Constants.FLY_MAX_HEIGHT + 30) or Constants.AC_AIR_HEIGHT
	if ground > limit and (wings or math.abs(vy) < 10) then
		s.air += SAMPLE
	else
		s.air = 0
	end
	if s.air >= Constants.AC_AIR_SECONDS then
		s.air = 0
		player:SetAttribute("AcGrace", os.clock() + 1)
		pcall(function()
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.CFrame = CFrame.new(pos - Vector3.new(0, ground - 3, 0)) * (hrp.CFrame - hrp.CFrame.Position)
		end)
		s.samples = {}
		self:Flag(player, "flying", `{math.floor(ground)} studs up{wings and " (above the sky limit)" or ""}`, 2)
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
		end
	end
end

function AntiCheatService:Init(registry)
	baseService = registry.BaseService
	economy = registry.EconomyService
	team = registry.TeamService
	-- inside a locked base at ground level, after it had been locked a while (so not someone caught inside when
	-- it locked, and not a flyer: they're bounced while still above the walls)
	baseService.Intruded:Connect(function(player, base)
		local pos = baseService:Position(player)
		if not pos or not base.owner or team:AreTeam(player, base.owner) then
			return
		end
		local lockedFor = base.lockedAt and (workspace:GetServerTimeNow() - base.lockedAt) or 0
		local low = base.world.cf:PointToObjectSpace(pos).Y < 8
		if lockedFor > 3 and low and baseService:IsInside(base, pos) then
			self:Flag(player, "noclip", `inside {base.owner.Name}'s locked base`, 2)
		end
	end)
	Net.onDrop(function(player)
		local s = st(player)
		s.drops += 1
		if s.drops % Constants.AC_SPAM_DROPS == 0 then
			self:Flag(player, "spam", `{s.drops} requests dropped`, 1)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		state[player] = nil
	end)
end

function AntiCheatService:OnPlayerReady(player)
	st(player)
	player.CharacterAdded:Connect(function()
		AntiCheatService.reset(player)
		player:SetAttribute("AcGrace", os.clock() + 2)
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
