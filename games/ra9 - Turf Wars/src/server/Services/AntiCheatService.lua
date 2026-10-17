--[[
Anti-cheat. The server already decides everything that matters in a fight: arrows fly on the server (CombatService:
the draw is timed here, the shot starts from your head, hits are checked against the server's own hit spheres and
walls), the frontline, the turf rule, building (phase, turf, reach, budget, lanes), the shop and the Robux. So a
cheater can't give themselves kills, Shards or turf. What's left is the body the client owns, and odd patterns:

  speed      faster over the ground than you can go (walk, sprint, crouch, slide and our knockback all allowed for),
             judged over WINDOW seconds so a lag burst doesn't count: pulled back to where you were, + a strike
  teleport   the same, but a huge jump: pulled back, + 3 strikes
  flying     in the air for AIR_SECONDS without coming down (a jump, a flip and a fall off a tower are all far
             shorter): dropped back down, + 2 strikes
  noclip     standing inside a built wall or tower: put back outside, + a strike
  shots      the server refusing your shots again and again (too fast for the bow, from too far off your head, while
             dead or reloading): + a strike per REJECT_LIMIT in REJECT_WINDOW
  spam       remote calls faster than their rate limits (an auto-clicker, a script): + a strike per SPAM_LIMIT drops
  aim        a long run of nearly all headshots or nearly every shot hitting: flagged for a look (logged, never a
             strike: good players exist)

Strikes fade (one every DECAY_SECONDS). At KICK_STRIKES you're removed from the server with a plain message. Our
own teleports and knockbacks set the player's "AcGrace" attribute (an os.clock() time) so they never count. Every
flag is logged (warn, the Flagged signal, and the profile's ac record: flags, kicks, the last few kinds) so repeat
offenders show up across servers. Admins (server/Admins.lua) are never checked or flagged.

  AntiCheatService.Flagged (player, kind, detail, strikes)
  AntiCheatService.Kicked (player, reason)
  AntiCheatService:Strikes(player)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Admins = require(script.Parent.Parent.Admins)

local AntiCheatService = {
	Name = "AntiCheatService",
	Dependencies = { "PlayerDataService", "MoveService", "CombatService", "BuildService" },
	Flagged = Signal.new("AntiCheatService.Flagged"), -- (player, kind, detail, strikes)
	Kicked = Signal.new("AntiCheatService.Kicked"), -- (player, reason)
}

local data, move, combat, build

AntiCheatService.SAMPLE = 0.25 -- seconds between checks
AntiCheatService.WINDOW = 1 -- seconds of movement judged at once
AntiCheatService.SLACK = 1.4 -- x the fastest legal speed, for lag and physics
AntiCheatService.SLACK_STUDS = 6
AntiCheatService.TELEPORT_STUDS = 60 -- more than this beyond the allowance in one window: a teleport
AntiCheatService.AIR_SECONDS = 3
AntiCheatService.AIR_HEIGHT = 7 -- studs above the ground to count as flying
AntiCheatService.REJECT_LIMIT, AntiCheatService.REJECT_WINDOW = 8, 10
AntiCheatService.SPAM_LIMIT, AntiCheatService.SPAM_WINDOW = 15, 10
AntiCheatService.DECAY_SECONDS = 30
AntiCheatService.KICK_STRIKES = 6
AntiCheatService.AIM_MIN_KILLS, AntiCheatService.AIM_HEADSHOTS = 25, 0.85
AntiCheatService.AIM_MIN_SHOTS, AntiCheatService.AIM_ACCURACY = 60, 0.92

local state = {} -- [player] = { samples, strikes, lastDecay, air, rejects, drops, kills, heads, shots, hits, good, flagged }

local function st(player)
	local s = state[player]
	if not s then
		s = {
			samples = {},
			strikes = 0,
			lastDecay = os.clock(),
			airSince = nil,
			rejects = {},
			drops = {},
			kills = 0,
			heads = 0,
			shots = 0,
			hits = 0,
			flagged = {},
		}
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

function AntiCheatService:Strikes(player)
	return st(player).strikes
end

-- Studs from a position down to whatever's under it (or nil if it can't tell). Tests replace this.
function AntiCheatService.groundDistance(player, pos)
	local ok, result = pcall(function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { player.Character }
		return workspace:Raycast(pos, Vector3.new(0, -200, 0), params)
	end)
	if not ok then
		return nil
	end
	return result and (pos.Y - result.Position.Y) or 200
end

-- The fastest this player may go over the ground right now (studs per second).
function AntiCheatService.maxSpeed(player)
	local m = move:State(player)
	local v = Constants.WALK_SPEED
	if m.sprint then
		v = Constants.SPRINT_SPEED
	end
	if move:Sliding(player) then
		v = math.max(v, Constants.SLIDE_SPEED)
	end
	return v
end

local function log(player, kind, detail)
	local p = data:Get(player)
	if p then
		p.ac = p.ac or { flags = 0, kicks = 0, recent = {} }
		p.ac.flags += 1
		table.insert(p.ac.recent, `{kind}:{os.time()}`)
		while #p.ac.recent > 10 do
			table.remove(p.ac.recent, 1)
		end
	end
	warn(`[AntiCheat] {player.Name} ({player.UserId}) {kind}: {detail}`)
end

function AntiCheatService:Flag(player, kind, detail, strikes)
	if typeof(player) ~= "Instance" or Admins.isAdmin(player) then
		return -- (a bot; an admin is never flagged)
	end
	local s = st(player)
	s.strikes += strikes or 0
	log(player, kind, detail)
	self.Flagged:Fire(player, kind, detail, s.strikes)
	if s.strikes >= self.KICK_STRIKES and not s.kicked then
		s.kicked = true
		local p = data:Get(player)
		if p and p.ac then
			p.ac.kicks += 1
		end
		self.Kicked:Fire(player, kind)
		task.defer(function()
			if player.Parent then
				player:Kick("Removed for unusual movement or input. If this was a mistake, just rejoin.")
			end
		end)
	end
end

-- Put them back where they last were legitimately (the start of the window judged, or the last good check).
local function pullBack(player, s, to)
	local r = rootOf(player)
	to = to or s.good
	if r and to then
		r.CFrame = to
		r.AssemblyLinearVelocity = Vector3.zero
		player:SetAttribute("AcGrace", os.clock() + 0.5)
	end
	s.samples = {}
end

local function insideStructure(pos)
	for _, sct in build:All() do
		local mn, mx = sct.boxMin, sct.boxMax
		if mn and mx then
			local inset = 0.6
			if
				pos.X > mn.X + inset
				and pos.X < mx.X - inset
				and pos.Z > mn.Z + inset
				and pos.Z < mx.Z - inset
				and pos.Y > mn.Y + 0.5
				and pos.Y < mx.Y - 0.5
			then
				return sct
			end
		end
	end
	return nil
end

function AntiCheatService:Check(player)
	if Admins.isAdmin(player) then
		return -- (admins teleport, fly and spectate: never checked)
	end
	local r, hum = rootOf(player)
	local s = st(player)
	local t = os.clock()
	-- strikes fade
	if t - s.lastDecay >= self.DECAY_SECONDS then
		s.lastDecay = t
		s.strikes = math.max(0, s.strikes - 1)
	end
	if not r or not hum or hum.Health <= 0 or not combat:Alive(player) then
		s.samples, s.airSince, s.good = {}, nil, nil
		return
	end
	local pos = r.Position
	if inGrace(player) then
		s.samples, s.airSince = { { t = t, pos = pos, cf = r.CFrame } }, nil
		s.good = r.CFrame
		return
	end
	-- speed and teleports, over the window
	table.insert(s.samples, { t = t, pos = pos, cf = r.CFrame })
	while #s.samples > 1 and t - s.samples[1].t > self.WINDOW do
		table.remove(s.samples, 1)
	end
	local first = s.samples[1]
	local dtw = t - first.t
	if dtw > 0.2 then
		local flat = Vector3.new(pos.X - first.pos.X, 0, pos.Z - first.pos.Z).Magnitude
		local allowed = self.maxSpeed(player) * dtw * self.SLACK + self.SLACK_STUDS
		if flat > allowed + self.TELEPORT_STUDS then
			pullBack(player, s, first.cf)
			self:Flag(player, "teleport", string.format("%.0f studs in %.2fs (allowed %.0f)", flat, dtw, allowed), 3)
			return
		elseif flat > allowed then
			pullBack(player, s, first.cf)
			self:Flag(player, "speed", string.format("%.0f studs in %.2fs (allowed %.0f)", flat, dtw, allowed), 1)
			return
		end
	end
	-- flying: high above whatever's under you for too long
	local above = self.groundDistance(player, pos)
	if above and above > self.AIR_HEIGHT then
		s.airSince = s.airSince or t
		if t - s.airSince > self.AIR_SECONDS then
			s.airSince = nil
			pullBack(player, s)
			self:Flag(player, "fly", string.format("%.0f studs up for %.1fs", above, self.AIR_SECONDS), 2)
			return
		end
	else
		s.airSince = nil
	end
	-- inside a wall
	local inside = insideStructure(pos)
	if inside then
		pullBack(player, s)
		self:Flag(player, "noclip", `inside a {inside.key}`, 1)
		return
	end
	s.good = r.CFrame
end

local function windowCount(list, t, window)
	table.insert(list, t)
	while #list > 0 and t - list[1] > window do
		table.remove(list, 1)
	end
	return #list
end

function AntiCheatService:Rejected(player, reason)
	local s = st(player)
	if windowCount(s.rejects, os.clock(), self.REJECT_WINDOW) >= self.REJECT_LIMIT then
		s.rejects = {}
		self:Flag(player, "shots", `{self.REJECT_LIMIT} refused shots in {self.REJECT_WINDOW}s (last: {reason})`, 1)
	end
end

function AntiCheatService:Dropped(player, name)
	local s = st(player)
	if windowCount(s.drops, os.clock(), self.SPAM_WINDOW) >= self.SPAM_LIMIT then
		s.drops = {}
		self:Flag(player, "spam", `{self.SPAM_LIMIT} calls over the limit in {self.SPAM_WINDOW}s ({name})`, 1)
	end
end

-- Aim: only ever a flag (a note in the log), once per kind per session
function AntiCheatService:Aim(player)
	local s = st(player)
	if s.kills >= self.AIM_MIN_KILLS and s.heads / s.kills >= self.AIM_HEADSHOTS and not s.flagged.heads then
		s.flagged.heads = true
		self:Flag(player, "aim", string.format("%d of %d kills headshots", s.heads, s.kills), 0)
	end
	if s.shots >= self.AIM_MIN_SHOTS and s.hits / s.shots >= self.AIM_ACCURACY and not s.flagged.accuracy then
		s.flagged.accuracy = true
		self:Flag(player, "aim", string.format("%d of %d shots hit", s.hits, s.shots), 0)
	end
end

function AntiCheatService:Init(registry)
	data = registry.PlayerDataService
	move = registry.MoveService
	combat = registry.CombatService
	build = registry.BuildService
	combat.Rejected:Connect(function(player, reason)
		self:Rejected(player, reason)
	end)
	combat.Shot:Connect(function(player)
		st(player).shots += 1
	end)
	combat.Damaged:Connect(function(_, _, attacker)
		if attacker then
			st(attacker).hits += 1
		end
	end)
	combat.Killed:Connect(function(_, killer, info)
		if killer then
			local s = st(killer)
			s.kills += 1
			if info and info.head then
				s.heads += 1
			end
			self:Aim(killer)
		end
	end)
	Net.onDrop(function(player, name)
		self:Dropped(player, name)
	end)
	Players.PlayerRemoving:Connect(function(player)
		state[player] = nil
	end)
end

function AntiCheatService:Start()
	while true do
		task.wait(self.SAMPLE)
		for _, p in Players:GetPlayers() do
			local ok, err = pcall(self.Check, self, p)
			if not ok then
				warn("[AntiCheat] " .. tostring(err))
			end
		end
	end
end

return AntiCheatService
