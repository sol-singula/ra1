-- The bonk bat: hit the nearest player in range. A bonked player is stunned and drops the dragon they carry.
-- Also owns walk speed (speed level, carrying slow-down, Fast Feet, stuns) and the VIP name tag.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local CombatService = {
	Name = "CombatService",
	Dependencies = { "PlayerDataService", "EconomyService", "DragonService", "TeamService", "BaseService" },
	Bonked = Signal.new("CombatService.Bonked"), -- (attacker, victim, wasCarrying)
}

local data, economy, dragons, team, baseService
local lastBonk = {}
local stunnedUntil = {}

local function humanoid(player)
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

function CombatService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	dragons = registry.DragonService
	team = registry.TeamService
	baseService = registry.BaseService
	dragons.CarryChanged:Connect(function(player)
		self:RefreshSpeed(player)
		self:_vipTag(player)
	end)
	economy.PassesChanged:Connect(function(player)
		self:RefreshSpeed(player)
		self:_vipTag(player)
	end)
	Net.on("Bonk", function(player)
		self:Bonk(player)
	end)
end

function CombatService:OnPlayerReady(player)
	player.CharacterAdded:Connect(function()
		task.wait()
		self:RefreshSpeed(player)
		self:_vipTag(player)
	end)
	self:RefreshSpeed(player)
	self:_vipTag(player)
end

function CombatService:OnPlayerLeaving(player)
	lastBonk[player] = nil
	stunnedUntil[player] = nil
end

function CombatService:IsStunned(player)
	return (stunnedUntil[player] or 0) > os.clock()
end

function CombatService:RefreshSpeed(player)
	local hum = humanoid(player)
	local profile = data:Get(player)
	if not hum or not profile then
		return
	end
	if self:IsStunned(player) then
		hum.WalkSpeed = 0
		return
	end
	local c = dragons:Carrying(player)
	hum.WalkSpeed = Formulas.walkSpeed(profile.speedLevel, c and c.rec, os.time(), economy:Passes(player))
end

function CombatService:_vipTag(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head or not economy:HasPass(player, "VIP") then
		return
	end
	local existing = head:FindFirstChild("VIPTag")
	if existing then
		-- a carried dragon sits on your head and has its own name tag: hide the VIP tag so they don't overlap
		existing.Enabled = dragons:Carrying(player) == nil
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "VIPTag"
	gui.Size = UDim2.new(2.6, 0, 0.7, 0)
	gui.StudsOffset = Vector3.new(0, 1.6, 0)
	gui.MaxDistance = 40
	gui.Enabled = dragons:Carrying(player) == nil
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Text = "👑 VIP"
	t.Font = Enum.Font.LuckiestGuy
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(255, 205, 50)
	t.TextStrokeTransparency = 0
	t.Parent = gui
	gui.Parent = head
end

-- Nearest valid target in range; players carrying a dragon come first.
function CombatService:_target(attacker, pos)
	local best, bestDist, bestCarry
	for _, other in Players:GetPlayers() do
		if other ~= attacker and not team:AreTeam(attacker, other) then
			local op = baseService:Position(other)
			if op then
				local dist = (op - pos).Magnitude
				local carry = dragons:Carrying(other) ~= nil
				if dist <= Constants.BONK_RANGE then
					if not best or (carry and not bestCarry) or (carry == bestCarry and dist < bestDist) then
						best, bestDist, bestCarry = other, dist, carry
					end
				end
			end
		end
	end
	return best
end

function CombatService:Bonk(attacker)
	if (lastBonk[attacker] or -99) > os.clock() - Constants.BONK_COOLDOWN or self:IsStunned(attacker) then
		return
	end
	local pos = baseService:Position(attacker)
	if not pos then
		return
	end
	lastBonk[attacker] = os.clock()
	Net.fireAll("Swing", attacker)
	local victim = self:_target(attacker, pos)
	if not victim then
		return
	end
	local wasCarrying = dragons:Carrying(victim) ~= nil
	local seconds = economy:HasPass(attacker, "MEGABONK") and Constants.STUN_SECONDS_MEGA or Constants.STUN_SECONDS
	stunnedUntil[victim] = os.clock() + seconds
	self:RefreshSpeed(victim)
	if wasCarrying then
		dragons:Drop(victim)
		local profile = data:Get(attacker)
		if profile then
			profile.stats.bonks += 1
		end
	end
	local vp = baseService:Position(victim)
	local hrp = victim.Character and victim.Character:FindFirstChild("HumanoidRootPart")
	if hrp and vp then
		local push = (vp - pos)
		push = Vector3.new(push.X, 0, push.Z)
		push = push.Magnitude > 0.1 and push.Unit or Vector3.new(0, 0, 1)
		hrp.AssemblyLinearVelocity = push * 45 + Vector3.new(0, 25, 0)
	end
	Net.fire(victim, "Bonked", seconds)
	Net.fireAll("Popup", (vp or pos) + Vector3.new(0, 5, 0), "BONK!", Color3.fromRGB(255, 220, 60))
	if wasCarrying then
		Net.fire(attacker, "Toast", "BONK! They dropped the dragon. Grab it! 🐉", "good")
	end
	task.delay(seconds + 0.05, function()
		if victim.Parent then
			self:RefreshSpeed(victim)
		end
	end)
	self.Bonked:Fire(attacker, victim, wasCarrying)
end

return CombatService
