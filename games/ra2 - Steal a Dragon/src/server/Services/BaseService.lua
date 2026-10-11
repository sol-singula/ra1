-- Player bases: who owns which base, the door lock, keeping thieves out of locked bases, the coin bank that
-- the nests fill every second, and the collect and lock pads.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local BaseService = {
	Name = "BaseService",
	Dependencies = { "PlayerDataService", "EconomyService", "TeamService" },
	Locked = Signal.new("BaseService.Locked"), -- (player)
	Collected = Signal.new("BaseService.Collected"), -- (player, amount)
}

local data, economy, team
local bases = {} -- [i] = { world, owner, lockUntil, bank }
local byPlayer = {} -- [player] = base
local lastBounceToast = {}

local function now()
	return workspace:GetServerTimeNow()
end

function BaseService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	team = registry.TeamService
	for i, w in WorldBuilder.layout.bases do
		bases[i] = { index = i, world = w, owner = nil, lockUntil = 0, bank = 0 }
	end
	data.ClientReady:Connect(function(player)
		self:PushBase(player)
	end)
	Net.on("Lock", function(player)
		local base = byPlayer[player]
		if base and self:IsInside(base, self:Position(player)) then
			self:Lock(player)
		else
			Net.fire(player, "Toast", "Go to your base to lock it!", "bad")
		end
	end)
	team.TeamChanged:Connect(function(player)
		self:PushIncome(player)
	end)
end

function BaseService:OnPlayerReady(player)
	for _, base in bases do
		if not base.owner then
			base.owner = player
			base.lockUntil = 0
			base.bank = 0
			byPlayer[player] = base
			base.world.signLines[1].Text = string.upper(player.DisplayName)
			base.world.beacon.Transparency = 0.35
			base.world.model:SetAttribute("OwnerUserId", player.UserId)
			player:SetAttribute("BaseIndex", base.index)
			self:PushBase(player)
			return
		end
	end
	warn("[BaseService] no free base for " .. player.Name) -- Max Players should be 8
end

function BaseService:OnPlayerLeaving(player)
	local base = byPlayer[player]
	if not base then
		return
	end
	if base.bank > 0 then
		economy:Add(player, base.bank)
	end
	base.owner = nil
	base.bank = 0
	base.lockUntil = 0
	base.world.signLines[1].Text = "EMPTY BASE"
	base.world.signLines[2].Text = ""
	base.world.collectLines[2].Text = "0"
	base.world.laser.Transparency = 1
	base.world.beacon.Transparency = 0.6
	base.world.model:SetAttribute("OwnerUserId", nil)
	byPlayer[player] = nil
	lastBounceToast[player] = nil
end

function BaseService:Get(player)
	return byPlayer[player]
end

function BaseService:Bases()
	return bases
end

function BaseService:Owner(baseIndex)
	return bases[baseIndex] and bases[baseIndex].owner
end

function BaseService:Position(player)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	return hrp and hrp.Position
end

function BaseService:IsInside(base, pos)
	if not pos then
		return false
	end
	local half = WorldBuilder.BASE_HALF
	local p = base.world.cf:PointToObjectSpace(pos)
	return math.abs(p.X) <= half.X + 0.5 and math.abs(p.Z) <= half.Z + 0.5 and p.Y < half.Y
end

function BaseService:InOwnBase(player)
	local base = byPlayer[player]
	return base ~= nil and self:IsInside(base, self:Position(player))
end

-- The base a position is in, if any.
function BaseService:BaseAt(pos)
	for _, base in bases do
		if self:IsInside(base, pos) then
			return base
		end
	end
	return nil
end

function BaseService:IsLocked(base)
	return base.lockUntil > now()
end

function BaseService:Lock(player)
	local base = byPlayer[player]
	local profile = data:Get(player)
	if not base or not profile then
		return
	end
	local wasLocked = self:IsLocked(base)
	base.lockUntil = now() + Formulas.lockSeconds(economy:Passes(player))
	self:_drawLock(base)
	self:PushBase(player)
	if not wasLocked then
		profile.stats.locks += 1
		Net.fire(player, "Toast", "Door locked! 🔒", "good")
		self.Locked:Fire(player)
	end
end

function BaseService:_drawLock(base)
	local left = base.lockUntil - now()
	if left > 0 then
		base.world.laser.Transparency = 0.35
		base.world.signLines[2].Text = "🔒 LOCKED " .. Format.time(left)
	elseif base.owner then
		base.world.laser.Transparency = 1
		base.world.signLines[2].Text = "🔓 OPEN"
	end
end

function BaseService:PushBase(player)
	local base = byPlayer[player]
	if not base then
		return
	end
	data:Push(player, { baseIndex = base.index, lockUntil = base.lockUntil, bank = math.floor(base.bank) })
	self:PushIncome(player)
end

-- Coins per second of everything in this player's nests, with passes and friend bonus.
function BaseService:Income(player)
	local profile = data:Get(player)
	if not profile then
		return 0, 1
	end
	local t = os.time()
	local sum = 0
	for _, rec in profile.dragons do
		if rec.slot then
			sum += Formulas.dragonIncome(rec, t)
		end
	end
	local mult = Formulas.playerMult(economy:Passes(player), team:FriendsHere(player))
	return sum * mult, mult
end

function BaseService:PushIncome(player)
	local income, mult = self:Income(player)
	data:Push(player, { cps = income, mult = mult })
end

function BaseService:Collect(player)
	local base = byPlayer[player]
	if not base or base.bank < 1 then
		return
	end
	local amount = math.floor(base.bank)
	base.bank -= amount
	economy:Add(player, amount)
	Net.fire(
		player,
		"Popup",
		base.world.collectPad.Position + Vector3.new(0, 4, 0),
		"+" .. Format.num(amount),
		Color3.fromRGB(255, 215, 60)
	)
	base.world.collectLines[2].Text = Format.num(base.bank)
	data:Push(player, { bank = 0 })
	self.Collected:Fire(player, amount)
end

local function onPad(pad, pos)
	if not pos then
		return false
	end
	local p = pad.CFrame:PointToObjectSpace(pos)
	return math.abs(p.X) <= pad.Size.X / 2 + 0.5 and math.abs(p.Z) <= pad.Size.Z / 2 + 0.5 and p.Y > -1 and p.Y < 6
end

-- Push intruders out of locked bases, and handle the pads.
function BaseService:_step()
	for _, player in Players:GetPlayers() do
		local pos = self:Position(player)
		if pos then
			local mine = byPlayer[player]
			for _, base in bases do
				if base.owner and base ~= mine and self:IsLocked(base) and not team:AreTeam(player, base.owner) then
					if self:IsInside(base, pos) then
						local hrp = player.Character.HumanoidRootPart
						hrp.CFrame = base.world.gateCf * CFrame.new(0, 3, -2) * CFrame.Angles(0, math.pi, 0)
						if (lastBounceToast[player] or -99) < os.clock() - 2 then
							lastBounceToast[player] = os.clock()
							Net.fire(player, "Toast", "That base is LOCKED! Wait for it to open.", "bad")
						end
					end
				end
			end
			if mine then
				if onPad(mine.world.lockPad, pos) and not self:IsLocked(mine) then
					self:Lock(player)
				end
				if onPad(mine.world.collectPad, pos) then
					self:Collect(player)
				end
			end
		end
	end
end

-- Every second: fill banks, update signs, track best income.
function BaseService:_tick()
	for _, base in bases do
		local player = base.owner
		if player then
			local profile = data:Get(player)
			local income = self:Income(player)
			if profile then
				if income > profile.bestIncome then
					profile.bestIncome = income
				end
				if economy:HasPass(player, "AUTO") then
					economy:Add(player, income)
				else
					base.bank += income
					base.world.collectLines[2].Text = Format.num(base.bank)
					data:Push(player, { bank = math.floor(base.bank) })
				end
				data:Push(player, { cps = income })
			end
			local wasLocked = base.world.laser.Transparency < 1
			self:_drawLock(base)
			if wasLocked and not self:IsLocked(base) then
				Net.fire(player, "Toast", "Your door is OPEN! Lock it again! 🔓", "bad")
				data:Push(player, { lockUntil = 0 })
			end
		end
	end
end

function BaseService:Start()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.1 then
			acc = 0
			self:_step()
		end
	end)
	while true do
		task.wait(1)
		self:_tick()
	end
end

return BaseService
