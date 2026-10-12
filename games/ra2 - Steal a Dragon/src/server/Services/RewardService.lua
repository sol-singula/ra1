-- Reasons to come back and keep playing: the daily gift, the 2-hour egg, goals, coins earned while away,
-- the friend bonus goal and invite rewards.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Dragons = require(ReplicatedStorage.Shared.Data.Dragons)
local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Goals = require(ReplicatedStorage.Shared.Data.Goals)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local RewardService = {
	Name = "RewardService",
	Dependencies = {
		"PlayerDataService",
		"EconomyService",
		"DragonService",
		"BaseService",
		"TeamService",
		"RoadService",
	},
	HatchNowRequested = Signal.new("RewardService.HatchNowRequested"), -- (player)
}

local data, economy, dragons, baseService, team, road
local pendingOffline = {} -- [player] = coins waiting to be claimed
local eggModels = {} -- [player] = model on the base's egg stand
local rng = Random.new(os.time())

function RewardService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	dragons = registry.DragonService
	baseService = registry.BaseService
	team = registry.TeamService
	road = registry.RoadService
	data.ClientReady:Connect(function(player)
		self:PushAll(player)
	end)
	Net.on("ClaimDaily", function(player)
		self:ClaimDaily(player)
	end)
	Net.on("ClaimOffline", function(player)
		self:ClaimOffline(player)
	end)
	team.TeamChanged:Connect(function(player)
		local profile = data:Get(player)
		if profile and team:FriendsHere(player) > 0 and profile.stats.friendPlay == 0 then
			profile.stats.friendPlay = 1
		end
	end)
end

-- Offline coins ----------------------------------------------------------------------------------------------
function RewardService:OfflinePending(player)
	return pendingOffline[player]
end

function RewardService:ClaimOffline(player, double)
	local coins = pendingOffline[player]
	if not coins then
		return
	end
	pendingOffline[player] = nil
	economy:Add(player, coins * (double and 2 or 1))
	Net.fire(player, "Toast", `+{Format.num(coins * (double and 2 or 1))} coins from while you were away!`, "good")
end

-- Daily gift -------------------------------------------------------------------------------------------------
-- The gift for a streak day, sized for this player right now (their income and best dragon).
function RewardService:GiftFor(player, streakDay)
	local profile = data:Get(player)
	local today = Formulas.day(os.time())
	return Formulas.dailyGift(
		streakDay,
		baseService:Income(player),
		Formulas.bestSpecies(profile.dragons),
		today + streakDay
	)
end

function RewardService:DailyView(player)
	local profile = data:Get(player)
	local today = Formulas.day(os.time())
	local d = profile.daily
	local canClaim = d.lastDay ~= today
	local nextStreak = (d.lastDay == today - 1) and d.streak + 1 or 1
	if not canClaim then
		nextStreak = d.streak + 1
	end
	-- the whole week, so the gift panel shows what each day gives this player
	local week = {}
	local first = math.floor((nextStreak - 1) / #Formulas.DAILY_GIFTS) * #Formulas.DAILY_GIFTS
	for i = 1, #Formulas.DAILY_GIFTS do
		local g = self:GiftFor(player, first + i)
		week[i] = { kind = g.kind, amount = g.amount, text = g.text }
	end
	return {
		streak = d.streak,
		canClaim = canClaim,
		nextDay = nextStreak,
		gift = self:GiftFor(player, nextStreak).text,
		gifts = week,
		secondsToNext = (today + 1) * 86400 - os.time(),
	}
end

function RewardService:ClaimDaily(player)
	local profile = data:Get(player)
	if not profile then
		return
	end
	local today = Formulas.day(os.time())
	local d = profile.daily
	if d.lastDay == today then
		Net.fire(player, "Toast", "Come back tomorrow for the next gift!", "info")
		return
	end
	local streak = (d.lastDay == today - 1) and d.streak + 1 or 1
	local gift = self:GiftFor(player, streak) -- sized before the streak changes, the same as the panel showed
	d.streak = streak
	d.lastDay = today
	if gift.kind == "coins" then
		economy:Add(player, gift.amount)
	elseif gift.kind == "dragon" then
		dragons:Grant(player, gift.id)
	elseif gift.kind == "luck" then
		road:AddLuck(Constants.LUCK_SECONDS, player.DisplayName)
	end
	Net.fire(player, "Alert", `Day {d.streak} gift: {gift.text}! 🎁`, Color3.fromRGB(255, 205, 50))
	data:Push(player, { daily = self:DailyView(player) })
end

-- Egg --------------------------------------------------------------------------------------------------------
function RewardService:GiveEgg(player)
	local profile = data:Get(player)
	if not profile or profile.egg then
		return
	end
	profile.eggsGiven += 1
	local special = Formulas.pick(Formulas.EGG_SPECIALS, rng:NextNumber())
	profile.egg = {
		id = Formulas.eggDragon(Formulas.bestSpecies(profile.dragons), profile.eggsGiven),
		sp = special,
		readyAt = os.time() + Constants.EGG_HATCH_SECONDS,
	}
	self:_drawEgg(player)
	self:PushEgg(player)
end

-- Keep the egg better than the player's best dragon: if they got a better one while it waited, it upgrades.
function RewardService:_upgradeEgg(player)
	local profile = data:Get(player)
	local egg = profile and profile.egg
	if not egg then
		return
	end
	local best = Formulas.bestSpecies(profile.dragons)
	local d = Dragons.byId[egg.id]
	if d and d.cps * Formulas.specialMult(egg.sp) > best then
		return
	end
	local better = Formulas.eggDragon(best, profile.eggsGiven)
	if better ~= egg.id and Dragons.byId[better].cps > (d and d.cps or 0) then
		egg.id = better
		self:_drawEgg(player)
		self:PushEgg(player)
		Net.fire(player, "Toast", `🥚 Your egg got better: {Dragons.byId[better].name}!`, "good")
	end
end

function RewardService:HatchNow(player)
	local profile = data:Get(player)
	if profile and profile.egg then
		profile.egg.readyAt = os.time()
		self:_drawEgg(player)
		self:PushEgg(player)
	end
end

function RewardService:Hatch(player)
	local profile = data:Get(player)
	local egg = profile and profile.egg
	if not egg or egg.readyAt > os.time() then
		return
	end
	if not dragons:HasRoom(player) then
		Net.fire(player, "Toast", "Make room in a nest first!", "bad")
		return
	end
	profile.egg = nil
	dragons:Grant(player, egg.id, egg.sp)
	local d = Dragons.byId[egg.id]
	local name = (egg.sp and Dragons.Specials[egg.sp].name .. " " or "") .. d.name
	-- an event for the whole server: an alert for everyone and fireworks over the egg stand
	Net.fireAll("Alert", `🐣 EGG HATCH! {player.DisplayName} got {name} ({d.rarity})!`, Dragons.RarityColor[d.rarity])
	local base = baseService:Get(player)
	if base then
		self:_fireworks(base.world.eggStand, d)
		Net.fireAll("Sfx", "hatch", base.world.eggStand.Position)
	end
	-- a new egg starts right away: back in 2 hours for the next one
	self:GiveEgg(player)
end

-- A short burst of coloured sparks and a beam of light over the egg stand.
function RewardService:_fireworks(stand, d)
	local burst = Instance.new("Part")
	burst.Name = "HatchFireworks"
	burst.Anchored = true
	burst.CanCollide = false
	burst.CanQuery = false
	burst.Transparency = 1
	burst.Size = Vector3.new(1, 1, 1)
	burst.CFrame = stand.CFrame * CFrame.new(0, 6, 0)
	for i, color in { d.body, d.wing, d.accent or d.belly, Dragons.RarityColor[d.rarity] } do
		local e = Instance.new("ParticleEmitter")
		e.Name = "Sparks" .. i
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(color)
		e.LightEmission = 1
		e.Size = NumberSequence.new(1.2, 0)
		e.Speed = NumberRange.new(14, 24)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Lifetime = NumberRange.new(1, 1.8)
		e.Acceleration = Vector3.new(0, -12, 0)
		e.Rate = 0
		e.Parent = burst
		e:Emit(40)
	end
	local light = Instance.new("PointLight")
	light.Color = Dragons.RarityColor[d.rarity]
	light.Range = 30
	light.Brightness = 4
	light.Parent = burst
	burst.Parent = stand.Parent
	task.delay(3, function()
		burst:Destroy()
	end)
end

function RewardService:PushEgg(player)
	local profile = data:Get(player)
	local egg = profile and profile.egg
	if egg then
		local d = Dragons.byId[egg.id]
		data:Push(player, {
			egg = {
				id = egg.id,
				name = (egg.sp and Dragons.Specials[egg.sp].name .. " " or "") .. d.name,
				rarity = d.rarity,
				secondsLeft = math.max(0, egg.readyAt - os.time()),
			},
		})
	else
		data:Push(player, { egg = false })
	end
end

function RewardService:_drawEgg(player)
	local old = eggModels[player]
	if old then
		old:Destroy()
		eggModels[player] = nil
	end
	local profile = data:Get(player)
	local base = baseService:Get(player)
	if not profile or not profile.egg or not base then
		return
	end
	local d = Dragons.byId[profile.egg.id]
	local eggData = profile.egg
	local stand = base.world.eggStand
	local egg = Instance.new("Part")
	egg.Name = "Egg"
	egg.Anchored = true
	egg.CanCollide = false
	egg.Size = Vector3.new(2.6, 3.4, 2.6)
	egg.CFrame = stand.CFrame * CFrame.new(0, stand.Size.Y / 2 + 1.7, 0)
	-- the dragon's colour (or its accent, if the dragon is too dark to show)
	local b = d.body
	egg.Color = (b.R * 0.3 + b.G * 0.59 + b.B * 0.11) < 0.2 and (d.accent or d.wing) or b
	egg.Material = Enum.Material.SmoothPlastic
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = egg
	-- it glows in its rarity's colour and sparkles with its special
	local glow = Instance.new("PointLight")
	glow.Color = Dragons.RarityColor[d.rarity]
	glow.Range = 12
	glow.Brightness = 2
	glow.Parent = egg
	if eggData.sp then
		local sp = Instance.new("Sparkles")
		sp.SparkleColor = Dragons.Specials[eggData.sp].color
		sp.Parent = egg
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Tag"
	gui.Size = UDim2.new(9, 0, 2.6, 0)
	gui.StudsOffset = Vector3.new(0, 3.4, 0)
	gui.MaxDistance = 70
	gui.LightInfluence = 0
	gui.Parent = egg
	for i, name in { "Line1", "Line2" } do
		local t = Instance.new("TextLabel")
		t.Name = name
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, 0, 0.5, 0)
		t.Position = UDim2.new(0, 0, (i - 1) * 0.5, 0)
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextStrokeTransparency = 0
		t.TextColor3 = i == 1 and Dragons.RarityColor[d.rarity] or Color3.fromRGB(255, 255, 255)
		t.Text = i == 1 and `🥚 {eggData.sp and Dragons.Specials[eggData.sp].name .. " " or ""}{d.name} egg` or ""
		t.Parent = gui
	end
	local hatch = dragons.prompt(egg, "hatch", "Hatch!", d.name .. " egg", 0.5, player.UserId)
	hatch.Triggered:Connect(function(who)
		if who ~= player then
			return
		end
		local p = data:Get(player)
		if p and p.egg and p.egg.readyAt > os.time() then
			self.HatchNowRequested:Fire(player)
		else
			self:Hatch(player)
		end
	end)
	egg.Parent = base.world.model
	eggModels[player] = egg
	self:_updateEggText(player)
end

function RewardService:_updateEggText(player)
	local egg = eggModels[player]
	local profile = data:Get(player)
	if not egg or not profile or not profile.egg then
		return
	end
	local left = profile.egg.readyAt - os.time()
	egg.Tag.Line2.Text = left > 0 and "Hatches in " .. Format.time(left) or "READY! Hatch it!"
	egg.Prompt_hatch.ActionText = left > 0 and "Hatch Now (Robux)" or "Hatch!"
end

-- Goals ------------------------------------------------------------------------------------------------------
function RewardService:ProgressOf(player, kind)
	local profile = data:Get(player)
	if kind == "coins" then
		return profile.coins
	elseif kind == "bought" or kind == "locks" or kind == "bonks" or kind == "friendPlay" then
		return profile.stats[kind]
	elseif kind == "steals" then
		return profile.steals
	elseif kind == "nests" then
		return profile.nestsBought
	elseif kind == "speed" then
		return profile.speedLevel
	elseif kind == "earned" then
		return profile.earned
	elseif kind == "rarity" or kind == "stage" then
		local best = 0
		for _, rec in profile.dragons do
			local v = kind == "rarity" and Dragons.RarityRank[Dragons.byId[rec.id].rarity]
				or Formulas.stage(rec, os.time())
			best = math.max(best, v)
		end
		return best
	end
	return 0
end

function RewardService:GoalView(player)
	local profile = data:Get(player)
	local goal = Goals[profile.goal]
	if not goal or not profile.tutorialDone then
		return false
	end
	return {
		index = profile.goal,
		total = #Goals,
		text = goal.text,
		progress = math.min(self:ProgressOf(player, goal.kind), goal.target),
		target = goal.target,
		reward = goal.reward,
	}
end

function RewardService:_checkGoal(player)
	local profile = data:Get(player)
	if not profile or not profile.tutorialDone then
		return
	end
	local goal = Goals[profile.goal]
	if goal and self:ProgressOf(player, goal.kind) >= goal.target then
		profile.goal += 1
		economy:Add(player, goal.reward)
		Net.fire(player, "Sfx", "levelup")
		Net.fire(
			player,
			"Alert",
			`Goal done: {goal.text}! +{Format.num(goal.reward)} coins ⭐`,
			Color3.fromRGB(255, 205, 50)
		)
	end
	data:Push(player, { goal = self:GoalView(player) })
end

function RewardService:PushAll(player)
	if not data:Get(player) then
		return
	end
	local profile = data:Get(player)
	data:Push(
		player,
		{ daily = self:DailyView(player), goal = self:GoalView(player), tutorialDone = profile.tutorialDone }
	)
	self:PushEgg(player)
end

-- Lifecycle --------------------------------------------------------------------------------------------------
function RewardService:OnPlayerReady(player, profile)
	-- coins earned while away
	local away = os.time() - (profile.meta.lastSeen or os.time())
	local income = baseService:Income(player)
	local coins = Formulas.offlineCoins(income, away)
	if coins > 0 then
		pendingOffline[player] = coins
		data:WhenClientReady(player, function()
			Net.fire(player, "Offline", { coins = coins, seconds = math.min(away, Constants.OFFLINE_CAP_SECONDS) })
		end)
	end
	-- invite reward: a brand-new player who came from a friend's invite
	if Constants.INVITE_REWARDS and profile._isNew then
		local ok, joinData = pcall(player.GetJoinData, player)
		local launch = ok and joinData and joinData.LaunchData
		local inviterId = type(launch) == "string" and tonumber(launch:match("^invite:(%d+)$"))
		local inviter = inviterId and Players:GetPlayerByUserId(inviterId)
		local inviterProfile = inviter and data:Get(inviter)
		if
			inviterProfile
			and #inviterProfile.invited < Constants.MAX_INVITE_REWARDS
			and not table.find(inviterProfile.invited, player.UserId)
		then
			table.insert(inviterProfile.invited, player.UserId)
			dragons:Grant(inviter, "CORAL")
			Net.fire(
				inviter,
				"Alert",
				`{player.DisplayName} joined from your invite! Free Coral dragon! 🎉`,
				Color3.fromRGB(80, 220, 120)
			)
			economy:Add(player, 200)
			data:WhenClientReady(player, function()
				Net.fire(player, "Toast", `Friend bonus: +200 coins for joining {inviter.DisplayName}!`, "good")
			end)
		end
	end
	self:_drawEgg(player)
	self:PushAll(player)
end

function RewardService:OnPlayerLeaving(player)
	local coins = pendingOffline[player]
	if coins then
		economy:Add(player, coins) -- never lose away-coins, even if the player didn't tap Claim
		pendingOffline[player] = nil
	end
	if eggModels[player] then
		eggModels[player]:Destroy()
		eggModels[player] = nil
	end
end

function RewardService:Start()
	while true do
		task.wait(1)
		for _, player in Players:GetPlayers() do
			if data:Get(player) then
				self:_checkGoal(player)
				self:_upgradeEgg(player)
				self:_updateEggText(player)
			end
		end
	end
end

return RewardService
