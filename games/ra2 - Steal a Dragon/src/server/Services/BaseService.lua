-- Player bases: who owns which base, the door lock, keeping thieves out of locked bases, the coin bank that
-- the nests fill every second, and the collect and lock pads.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
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
	PlateStepped = Signal.new("BaseService.PlateStepped"), -- (player, "auto" | "lock") owner stepped on a plate
	CastleGrew = Signal.new("BaseService.CastleGrew"), -- (player, level)
	FeverStarted = Signal.new("BaseService.FeverStarted"), -- (player) pressed the DISCO FEVER button
}

local data, economy, team
local feverUntil, feverReadyAt = 0, 0 -- DISCO FEVER (server time)
local bases = {} -- [i] = { world, owner, lockUntil, bank }
local byPlayer = {} -- [player] = base
local lastBounceToast = {}
local homeConns = {} -- [player] = CharacterAdded connection
local onPlates = {} -- [player] = { [plateName] = true } plates the player is standing on right now

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
		if feverUntil > now() then
			Net.fire(player, "Event", { kind = "fever", untilTime = feverUntil })
		end
	end)
	-- the DISCO FEVER button in the secret disco
	local button = WorldBuilder.layout.feverButton
	if button then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Prompt_fever"
		prompt.ObjectText = "DISCO FEVER"
		prompt.ActionText = "Start DISCO FEVER!"
		prompt.HoldDuration = 0.6
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = button
		prompt.Triggered:Connect(function(player)
			self:StartFever(player)
		end)
	end
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

-- Free bases are handed out zigzag from the lobby: left, right, left, right... (bases 1-4 are the north row,
-- 5-8 the south row, each from the lobby outward).
local ASSIGN_ORDER = { 1, 5, 2, 6, 3, 7, 4, 8 }

function BaseService:OnPlayerReady(player)
	for _, index in ASSIGN_ORDER do
		local base = bases[index]
		if base and not base.owner then
			base.owner = player
			base.lockUntil = 0
			base.bank = 0
			byPlayer[player] = base
			base.world.signLines[1].Text = string.upper(player.DisplayName) .. "  🏰" .. (base.world.castleLevel or 1)
			base.world.beacon.Transparency = 0.35
			base.world.model:SetAttribute("OwnerUserId", player.UserId)
			player:SetAttribute("BaseIndex", base.index)
			self:PushBase(player)
			-- once the tutorial is done, players spawn (and respawn) right in their own base
			local profile = data:Get(player)
			if profile and profile.tutorialDone then
				self:SendHome(player)
			end
			homeConns[player] = player.CharacterAdded:Connect(function(character)
				character:WaitForChild("HumanoidRootPart", 5)
				task.defer(function()
					local p = data:Get(player)
					if p and p.tutorialDone and character.Parent then
						self:SendHome(player)
					end
				end)
			end)
			return
		end
	end
	warn("[BaseService] no free base for " .. player.Name) -- Max Players should be 8
end

function BaseService:OnPlayerLeaving(player)
	if homeConns[player] then
		homeConns[player]:Disconnect()
		homeConns[player] = nil
	end
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
	base.castleChecked = false
	WorldBuilder.setCastleLevel(base.world, 1)
	base.world.signLines[2].Text = ""
	base.world.collectLines[2].Text = "0"
	base.world.laser.Transparency = 1
	base.world.beacon.Transparency = 0.6
	base.world.model:SetAttribute("OwnerUserId", nil)
	byPlayer[player] = nil
	lastBounceToast[player] = nil
	onPlates[player] = nil
end

-- Put the player just inside their own gate, facing the road.
function BaseService:SendHome(player)
	local base = byPlayer[player]
	local character = player.Character
	if base and character and character:FindFirstChild("HumanoidRootPart") then
		character:PivotTo(base.world.homeCf)
	end
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

-- DISCO FEVER --------------------------------------------------------------------------------------------------

function BaseService:FeverLeft()
	return math.max(0, feverUntil - now())
end

-- Press the disco's button: everyone here earns FEVER_MULT for FEVER_SECONDS; it can be pressed again
-- FEVER_COOLDOWN after the last press.
function BaseService:StartFever(player)
	local t = now()
	if t < feverReadyAt then
		Net.fire(player, "Toast", `🪩 The disco needs to cool down: {Format.time(feverReadyAt - t)}`, "info")
		return false
	end
	feverUntil = t + Constants.FEVER_SECONDS
	feverReadyAt = t + Constants.FEVER_COOLDOWN
	self.FeverStarted:Fire(player)
	Net.fireAll("Event", { kind = "fever", untilTime = feverUntil, by = player.DisplayName })
	Net.fireAll(
		"Alert",
		`🪩 {player.DisplayName} started DISCO FEVER! 1.25x coins for everyone!`,
		Color3.fromRGB(255, 120, 220)
	)
	for _, p in Players:GetPlayers() do
		self:PushIncome(p)
	end
	task.delay(Constants.FEVER_SECONDS + 0.1, function()
		for _, p in Players:GetPlayers() do
			self:PushIncome(p)
		end
	end)
	self:_drawFever()
	return true
end

function BaseService:_drawFever()
	local button = WorldBuilder.layout.feverButton
	local prompt = button and button:FindFirstChild("Prompt_fever")
	if not prompt then
		return
	end
	local t = now()
	if feverUntil > t then
		prompt.ActionText = "FEVER ON " .. Format.time(feverUntil - t)
	elseif feverReadyAt > t then
		prompt.ActionText = "Ready in " .. Format.time(feverReadyAt - t)
	else
		prompt.ActionText = "Start DISCO FEVER!"
	end
end

function BaseService:IsLocked(base)
	return base.lockUntil > now()
end

-- Lock the door. With extraSeconds (the 5-Minute Lock product) that much time is added on top of any lock that
-- is already running; otherwise it locks for the normal time, which also resets a running lock back to full
-- (never shortening a longer lock). Stepping on the lock pad does this, so you never need the L key.
function BaseService:Lock(player, extraSeconds)
	local base = byPlayer[player]
	local profile = data:Get(player)
	if not base or not profile then
		return
	end
	local wasLocked = self:IsLocked(base)
	local t = now()
	if extraSeconds then
		-- the 5-Minute Lock product: always works, on top of whatever is running
		base.lockUntil = math.max(base.lockUntil, t) + extraSeconds
		Net.fire(player, "Toast", `Locked for {Format.time(base.lockUntil - t)}! ⏱️`, "good")
	else
		local length = Formulas.lockSeconds(economy:Passes(player))
		if not wasLocked and base.lockUntil > 0 and t < base.lockUntil + Constants.LOCK_COOLDOWN then
			local wait = base.lockUntil + Constants.LOCK_COOLDOWN - t
			Net.fire(player, "Toast", `🔓 The lock is recharging: {Format.time(wait)}`, "info")
			return
		end
		if not wasLocked then
			base.lockChainStart = t
		elseif t + length - (base.lockChainStart or t) > length * Constants.LOCK_CHAIN_MAX then
			Net.fire(player, "Toast", "🔒 Your lock is at its limit: it opens soon!", "info")
			return
		end
		base.lockUntil = math.max(base.lockUntil, t + length)
	end
	self:_drawLock(base)
	self:PushBase(player)
	Net.fire(player, "Sfx", "lock")
	if not wasLocked then
		profile.stats.locks += 1
		Net.fire(player, "Toast", "Door locked! 🔒", "good")
		self.Locked:Fire(player)
	elseif not extraSeconds then
		Net.fire(player, "Toast", `Lock reset! 🔒 {Format.time(base.lockUntil - now())}`, "good")
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

-- Coins per second of everything in this player's nests, with passes, friend bonus, fever and new-player boost.
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
	if self:FeverLeft() > 0 then
		mult *= Constants.FEVER_MULT
	end
	if (profile.newBoostLeft or 0) > 0 then
		mult *= Constants.NEW_PLAYER_BOOST_MULT -- (PlaytimeService counts it down)
	end
	return sum * mult, mult
end

-- Dragon power: the coins per second of the dragons in a player's nests, before passes and friend bonuses.
function BaseService:DragonPower(player)
	local income, mult = self:Income(player)
	return income / mult
end

-- Castle level for an amount of dragon power (1 .. #CASTLE_LEVEL_POWER).
function BaseService.castleLevelFor(power)
	local level = 1
	for l, need in Constants.CASTLE_LEVEL_POWER do
		if power >= need then
			level = l
		end
	end
	return level
end

-- Grow (or shrink) a base's castle to match its owner's dragon power. The first check after joining is silent.
function BaseService:UpdateCastle(base)
	local player = base.owner
	local level = player and BaseService.castleLevelFor(self:DragonPower(player)) or 1
	if level == base.world.castleLevel then
		return
	end
	local grew = base.world.castleLevel and level > base.world.castleLevel and base.castleChecked
	WorldBuilder.setCastleLevel(base.world, level)
	if player then
		base.world.signLines[1].Text = string.upper(player.DisplayName) .. "  🏰" .. level
		if grew then
			Net.fire(player, "Alert", `🏰 Your castle grew! Castle level {level}`, Color3.fromRGB(255, 205, 50))
			self.CastleGrew:Fire(player, level)
		end
	end
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
	Net.fire(player, "Sfx", "coin")
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
				if onPad(mine.world.collectPad, pos) then
					self:Collect(player)
				end
				-- buy plates fire once each time you step on, not every frame you stand there
				local was = onPlates[player] or {}
				local now2 = {}
				local plates = { auto = mine.world.autoPlate, lock = mine.world.lockPlate }
				plates.lockpad = mine.world.lockPad
				for name, plate in plates do
					if plate and onPad(plate, pos) then
						now2[name] = true
						if not was[name] then
							if name == "lockpad" then
								self:Lock(player) -- locks, or resets a running lock to the full time
							else
								self.PlateStepped:Fire(player, name)
							end
						end
					end
				end
				onPlates[player] = now2
			end
		end
	end
end

-- Every second: fill banks, update signs, track best income.
function BaseService:_tick()
	self:_drawFever()
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
			self:UpdateCastle(base)
			base.castleChecked = true
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
