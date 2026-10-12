-- Blasting. The client picks the nearest bug it's facing and sends Blast(targetId); the server checks the
-- cooldown, the range and the direction, deals the equipped blaster's damage and shows everyone the beam.
-- The Auto Blast pass fires by itself at the nearest target in range.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Blasters = require(ReplicatedStorage.Shared.Data.Blasters)

local CombatService = {
	Name = "CombatService",
	Dependencies = { "PlayerDataService", "EconomyService", "BlasterService", "MobService", "BossService" },
	Blasted = Signal.new("CombatService.Blasted"), -- (player, entry, damage)
}

local data, economy, blasters, mobs, boss
local lastShot = {}

local function parts(player)
	local c = player.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	return c, hrp
end

-- Damage this player's shots do right now.
function CombatService:Damage(player, rec)
	local mult = 1
	if economy:HasPass(player, "VIP") then
		mult *= 1.25
	end
	return Formulas.blasterDamage(rec, mult)
end

function CombatService:Blast(player, targetId)
	local rec = blasters:Equipped(player)
	local _, hrp = parts(player)
	if not rec or not hrp or boss:IsDown(player) then
		return false
	end
	local cd = Formulas.blasterCooldown(rec)
	local t = os.clock()
	if (lastShot[player] or -99) > t - cd * 0.9 then
		return false
	end
	local entry = mobs.targets[targetId]
	if not entry or not entry.model.Parent then
		return false
	end
	local from = hrp.Position
	local to = entry.pos + Vector3.new(0, entry.boss and 5 or 1.3, 0)
	local delta = to - from
	if delta.Magnitude > Constants.BLAST_RANGE + 6 then
		return false
	end
	-- must be roughly facing it (very forgiving: phones aim by walking)
	local flat = Vector3.new(delta.X, 0, delta.Z)
	if flat.Magnitude > 2 and hrp.CFrame.LookVector:Dot(flat.Unit) < -0.2 then
		return false
	end
	lastShot[player] = t
	local damage = self:Damage(player, rec)
	local color = Blasters.byRarity[rec.rarity].color
	Net.fireAll("Beam", from + Vector3.new(0, 1, 0), to, color)
	Net.fireAll("Sfx", "blast", from)
	mobs:Hit(player, targetId, damage)
	local profile = data:Get(player)
	if profile and damage > profile.stats.bestDamage then
		profile.stats.bestDamage = damage
	end
	self.Blasted:Fire(player, entry, damage)
	return true
end

-- The nearest living target within range of a player.
function CombatService:NearestTarget(player)
	local _, hrp = parts(player)
	if not hrp then
		return nil
	end
	local best, bestD
	for id, e in mobs.targets do
		if e.model.Parent then
			local d = (e.pos - hrp.Position).Magnitude
			if d <= Constants.BLAST_RANGE and (not bestD or d < bestD) then
				best, bestD = id, d
			end
		end
	end
	return best
end

function CombatService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	blasters = registry.BlasterService
	mobs = registry.MobService
	boss = registry.BossService
	Net.on("Blast", function(player, targetId)
		if type(targetId) == "number" then
			self:Blast(player, targetId)
		end
	end)
end

function CombatService:OnPlayerLeaving(player)
	lastShot[player] = nil
end

function CombatService:Start()
	-- Auto Blast
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.15 then
			return
		end
		acc = 0
		for _, player in Players:GetPlayers() do
			if economy:HasPass(player, "AUTO") then
				local id = self:NearestTarget(player)
				if id then
					self:Blast(player, id)
				end
			end
		end
	end)
end

return CombatService
