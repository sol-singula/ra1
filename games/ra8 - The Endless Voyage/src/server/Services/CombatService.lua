--[[
Fighting (master plan §9: creatures you can beat with the right tool). Spears stab what's in front of you (an arc,
with some slack for latency); harpoons fly at what's in the water and come back. Every hit is the server's
(CreatureService.Damage); the client only animates.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local CombatService = {
	Name = "CombatService",
	Dependencies = { "PlayerDataService", "PlayerService", "CreatureService" },
	Hit = Signal.new("CombatService.Hit"), -- (player, creature, dmg, item)
	Missed = Signal.new("CombatService.Missed"), -- (player, item)
}

local players, creatures
local cooldown = {} -- [player] = t

local function now()
	return workspace:GetServerTimeNow()
end

local function aimDir(root, aim)
	if typeof(aim) == "Vector3" and aim.Magnitude > 0.01 then
		local f = Vector3.new(aim.X, 0, aim.Z)
		if f.Magnitude > 0.01 then
			return f.Unit
		end
	end
	local look = root.CFrame.LookVector
	return Vector3.new(look.X, 0, look.Z).Unit
end

-- The creature named by the client (if it's in reach), else the best one in front within range.
local function target(player, root, aim, targetId, range, arc)
	local plot = players:Here(player)
	if type(targetId) == "number" then
		local c = creatures:Get(targetId)
		if c and creatures:Hittable(c) and (c.pos - root.Position).Magnitude <= range + Constants.MELEE_SLACK then
			return c
		end
	end
	local dir = aimDir(root, aim)
	local best, bestScore
	for _, c in creatures:Near(root.Position, range + Constants.MELEE_SLACK, plot) do
		if creatures:Hittable(c) then
			local to = Vector3.new(c.pos.X - root.Position.X, 0, c.pos.Z - root.Position.Z)
			local dist = to.Magnitude
			local dot = dist > 0.5 and to.Unit:Dot(dir) or 1
			local limit = math.cos(math.rad(((arc or 100) + Constants.ARC_SLACK) / 2))
			if dot >= limit then
				local score = dot - dist / (range + Constants.MELEE_SLACK)
				if not bestScore or score > bestScore then
					best, bestScore = c, score
				end
			end
		end
	end
	return best
end

function CombatService:Swing(player, item, aim, targetId)
	local w = item and item.weapon
	local root = players:Root(player)
	if not w or not root or not players:IsAlive(player) then
		return false
	end
	local t = now()
	if t < (cooldown[player] or 0) then
		return false
	end
	cooldown[player] = t + w.cd
	local c = target(player, root, aim, targetId, w.range, w.arc)
	if not c then
		self.Missed:Fire(player, item)
		return true
	end
	Net.fire(player, "Sfx", "hit", c.pos)
	creatures:Damage(c.id, w.dmg, player, "spear")
	self.Hit:Fire(player, c, w.dmg, item)
	-- a second one right beside it
	for _, other in creatures:Near(c.pos, 3, c.plot) do
		if other ~= c and creatures:Hittable(other) then
			creatures:Damage(other.id, math.floor(w.dmg * 0.5), player, "spear")
			break
		end
	end
	return true
end

function CombatService:Throw(player, item, aim, targetId)
	local w = item and item.weapon
	local root = players:Root(player)
	if not w or not root or not players:IsAlive(player) then
		return false
	end
	local t = now()
	if t < (cooldown[player] or 0) then
		return false
	end
	cooldown[player] = t + w.cd
	local c = target(player, root, aim, targetId, w.range, 60)
	local to = c and c.pos or (root.Position + aimDir(root, aim) * math.min(w.range, 30))
	local plot = players:Here(player)
	for _, p in players:PlayersOnPlot(plot or 0) do
		Net.fire(p, "Fx", "harpoon", { from = root.Position + Vector3.new(0, 1.5, 0), to = to, by = player.UserId })
	end
	Net.fire(player, "Sfx", "hook", root.Position)
	if not c then
		self.Missed:Fire(player, item)
		return true
	end
	local flight = (to - root.Position).Magnitude / Constants.HARPOON_SPEED
	task.delay(flight, function()
		local still = creatures:Get(c.id)
		if still and creatures:Hittable(still) and (still.pos - to).Magnitude <= 12 and player.Parent then
			Net.fire(player, "Sfx", "bite", still.pos)
			creatures:Damage(still.id, w.dmg, player, "harpoon")
			self.Hit:Fire(player, still, w.dmg, item)
		end
	end)
	return true
end

function CombatService:Init(reg)
	players = reg.PlayerService
	creatures = reg.CreatureService
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		cooldown[player] = nil
	end)
end

return CombatService
