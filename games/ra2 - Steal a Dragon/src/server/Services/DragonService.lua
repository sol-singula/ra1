-- Dragons: the nest models in each base, carrying a dragon over your head, stealing, selling, dropping
-- (when bonked) and placing a carried dragon into a free nest when you reach your own base.
-- Every dragon record lives in exactly one player's profile. Carrying or dropping only changes where it is;
-- a stolen dragon moves to the thief's profile when the thief puts it in a nest.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Dragons = require(ReplicatedStorage.Shared.Data.Dragons)
local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Skins = require(ReplicatedStorage.Shared.Data.Skins)
local DragonBuilder = require(script.Parent.Parent.World.DragonBuilder)

local DragonService = {
	Name = "DragonService",
	Dependencies = { "PlayerDataService", "EconomyService", "BaseService", "TeamService" },
	CarryChanged = Signal.new("DragonService.CarryChanged"), -- (player)
	Placed = Signal.new("DragonService.Placed"), -- (player, rec, kind, fromPlayer)
	StealStarted = Signal.new("DragonService.StealStarted"), -- (thief, victim, rec)
	GrowRequested = Signal.new("DragonService.GrowRequested"), -- (player, uid) owner tapped "+10 Levels" on a dragon
	DragonsChanged = Signal.new("DragonService.DragonsChanged"), -- (player)
}

local data, economy, baseService, team
local folder
local nestModels = {} -- [player] = { [slot] = model }
local carrying = {} -- [player] = { rec, owner, kind, model }
local dropped = {} -- [model] = { rec, owner, expires }
local inTransit = {} -- [rec] = true while carried or dropped
local lastRoomToast = {}

local function stageOf(rec)
	return Formulas.stage(rec, os.time())
end

local function levelOf(rec)
	return Formulas.level(rec, os.time())
end

-- The skin a player's dragons wear (nil for Classic).
local function skinOf(player)
	local profile = player and data:Get(player)
	local skin = profile and Skins.byKey[profile.skin]
	return skin and skin.key ~= Skins.DEFAULT and skin or nil
end

function DragonService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	baseService = registry.BaseService
	team = registry.TeamService
	folder = Instance.new("Folder")
	folder.Name = "Dragons"
	folder.Parent = workspace
	data.ClientReady:Connect(function(player)
		self:PushCarry(player)
		self:PushWaiting(player)
	end)
	economy.PassesChanged:Connect(function(player)
		self:FillWaiting(player) -- Extra Nests may have added room
		self:_drawLockedNests(player)
	end)
end

-- Records ----------------------------------------------------------------------------------------------------
function DragonService:NewRecord(player, id, special, born)
	local profile = data:Get(player)
	local rec = { uid = profile.nextUid, id = id, sp = special, born = born or os.time() }
	profile.nextUid += 1
	table.insert(profile.dragons, rec)
	return rec
end

local function findRec(profile, uid)
	for i, rec in profile.dragons do
		if rec.uid == uid then
			return rec, i
		end
	end
	return nil
end

local function removeRec(profile, rec)
	local i = table.find(profile.dragons, rec)
	if i then
		table.remove(profile.dragons, i)
	end
end

function DragonService:MaxNests(player)
	local profile = data:Get(player)
	if not profile then
		return 0
	end
	return math.min(Constants.MAX_NESTS, Formulas.maxNests(profile.nestsBought, economy:Passes(player)))
end

function DragonService:FreeSlot(player)
	local profile = data:Get(player)
	if not profile then
		return nil
	end
	local used = {}
	for _, rec in profile.dragons do
		if rec.slot then
			used[rec.slot] = true
		end
	end
	for i = 1, self:MaxNests(player) do
		if not used[i] then
			return i
		end
	end
	return nil
end

-- Room for one more dragon: a free nest, or two nest dragons that can be combined to free one.
function DragonService:HasRoom(player)
	if self:FreeSlot(player) then
		return true
	end
	local profile = data:Get(player)
	local inNests = 0
	for _, rec in profile and profile.dragons or {} do
		if rec.slot then
			inNests += 1
		end
	end
	return inNests >= 2
end

-- Combining ---------------------------------------------------------------------------------------------------
-- Fold one dragon into another: `from` leaves, and `into` gets a boost so it earns what both earned. Returns the
-- dragon that was kept.
function DragonService:Combine(player, into, from)
	local profile = data:Get(player)
	if not profile or into == from then
		return nil
	end
	into.mx = Formulas.combinedBoost(into, from, os.time())
	if from.slot then
		self:_removeNestModel(player, from.slot)
	end
	removeRec(profile, from)
	if into.slot then
		self:_refreshNestModel(player, into, true)
	end
	baseService:PushIncome(player)
	self.DragonsChanged:Fire(player)
	return into
end

local function nestDragonsByIncome(profile)
	local list = {}
	local now = os.time()
	for _, rec in profile.dragons do
		if rec.slot then
			table.insert(list, rec)
		end
	end
	table.sort(list, function(a, b)
		return Formulas.dragonIncome(a, now) > Formulas.dragonIncome(b, now)
	end)
	return list
end

-- The owner's "Combine into best" prompt: this dragon folds into their best nest dragon (income kept).
function DragonService:CombineIntoBest(player, uid)
	local profile = data:Get(player)
	local rec = profile and findRec(profile, uid)
	if not rec or not rec.slot then
		return
	end
	-- the best of the other nest dragons; if this one beats them all, it's the one to combine into
	local best
	for _, other in nestDragonsByIncome(profile) do
		if other ~= rec then
			best = other
			break
		end
	end
	local now = os.time()
	if not best or Formulas.dragonIncome(rec, now) > Formulas.dragonIncome(best, now) then
		Net.fire(player, "Toast", "That's your best dragon: combine the others into it!", "info")
		return
	end
	local fromName = Dragons.byId[rec.id].name
	self:Combine(player, best, rec)
	Net.fire(
		player,
		"Toast",
		`⚡ {fromName} combined into {Dragons.byId[best.id].name}! Same income, one nest free.`,
		"good"
	)
	Net.fire(player, "Sfx", "levelup")
	self:FillWaiting(player)
end

-- Nests full: fold the weakest nest dragon into the best one so a nest frees up (income kept). Returns the slot.
function DragonService:MakeRoom(player)
	local profile = data:Get(player)
	if not profile then
		return nil
	end
	local list = nestDragonsByIncome(profile)
	if #list < 2 then
		return nil
	end
	local weakest, best = list[#list], list[1]
	local name = Dragons.byId[weakest.id].name
	self:Combine(player, best, weakest)
	Net.fire(player, "Toast", `⚡ Nests full: {name} combined into {Dragons.byId[best.id].name} (income kept)`, "info")
	return self:FreeSlot(player)
end

-- Dragons that belong to the player but have no nest yet (gifts, eggs, deals while the base was full).
function DragonService:WaitingCount(player)
	local profile = data:Get(player)
	local n = 0
	for _, rec in profile and profile.dragons or {} do
		if not rec.slot and not inTransit[rec] then
			n += 1
		end
	end
	return n
end

function DragonService:PushWaiting(player)
	data:Push(player, { waiting = self:WaitingCount(player), nests = self:MaxNests(player) })
end

-- Nest models ------------------------------------------------------------------------------------------------
-- Screen offset (pixels) of each prompt kind, so the owner's three prompts (and Buy / Buy with Robux on the road)
-- stack neatly: +10 Levels on top, Level Up in the middle, Sell below.
local PROMPT_OFFSETS = {
	grow = Vector2.new(0, -84),
	levelup = Vector2.zero,
	sell = Vector2.new(0, 84),
	combine = Vector2.new(0, 168),
	buy = Vector2.zero,
	buynow = Vector2.new(0, 84),
}

local function prompt(parent, kind, action, object, hold, ownerId, key)
	local p = Instance.new("ProximityPrompt")
	p.Name = "Prompt_" .. kind
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = hold
	p.MaxActivationDistance = 11
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = key or Enum.KeyCode.E
	-- prompts on the same dragon sit in a column instead of on top of each other
	p.UIOffset = PROMPT_OFFSETS[kind] or Vector2.zero
	p:SetAttribute("Kind", kind)
	p:SetAttribute("OwnerUserId", ownerId)
	p.Parent = parent
	CollectionService:AddTag(p, "DragonPrompt")
	return p
end
DragonService.prompt = prompt

local function tagText(rec)
	local d = Dragons.byId[rec.id]
	local stage = stageOf(rec)
	local name = (rec.sp and Dragons.Specials[rec.sp].name .. " " or "") .. d.name
	local level = levelOf(rec)
	local lv = level >= Constants.MAX_LEVEL and "MAX" or tostring(level)
	local boost = (rec.mx or 1) > 1.005 and string.format(" · ⚡x%.1f", rec.mx) or ""
	return name,
		Dragons.RarityColor[d.rarity],
		`Lv {lv} {Constants.STAGE_NAMES[stage]} · {Format.num(Formulas.dragonIncome(rec, os.time()))}/s{boost}`
end
DragonService.tagText = tagText

local function levelUpText(rec)
	local cost = Formulas.levelUpCost(rec, os.time())
	return cost and "Level Up 💰" .. Format.num(cost) or "MAX LEVEL"
end

function DragonService:_spawnNestModel(player, rec)
	local base = baseService:Get(player)
	if not base or not rec.slot then
		return
	end
	local models = nestModels[player]
	if models[rec.slot] then
		models[rec.slot]:Destroy()
	end
	local stage = stageOf(rec)
	local model = DragonBuilder.build(rec.id, rec.sp, stage, nil, skinOf(player))
	DragonBuilder.place(model, base.world.nests[rec.slot].feet)
	local name, color, line2 = tagText(rec)
	DragonBuilder.label(model, name, color, line2)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("Uid", rec.uid)
	model:SetAttribute("Slot", rec.slot)
	model:SetAttribute("Level", levelOf(rec))
	local root = model.PrimaryPart
	local steal = prompt(root, "steal", "Steal", name, 1.2, player.UserId)
	steal.Triggered:Connect(function(thief)
		self:TrySteal(thief, model)
	end)
	local sell = prompt(
		root,
		"sell",
		"Sell " .. Format.num(Formulas.sellValue(rec, os.time())),
		name,
		0.6,
		player.UserId,
		Enum.KeyCode.F
	)
	sell.Triggered:Connect(function(who)
		self:TrySell(who, model)
	end)
	local levelUp = prompt(root, "levelup", levelUpText(rec), name, 0.3, player.UserId)
	levelUp.Triggered:Connect(function(who)
		self:TryLevelUp(who, model)
	end)
	local combine = prompt(root, "combine", "Combine into best", name, 0.6, player.UserId, Enum.KeyCode.C)
	combine.Triggered:Connect(function(who)
		if who == player then
			self:CombineIntoBest(player, rec.uid)
		end
	end)
	local grow = prompt(root, "grow", "+10 Levels", name, 0, player.UserId, Enum.KeyCode.G)
	grow.Triggered:Connect(function(who)
		if who == player then
			self.GrowRequested:Fire(player, rec.uid)
		end
	end)
	model.Parent = folder
	models[rec.slot] = model
end

-- Refresh a nest dragon after its level changed: a new model when it reached a new size, otherwise just the name
-- tag and prompt texts (so a thief holding Steal isn't interrupted).
function DragonService:_refreshNestModel(player, rec)
	local model = rec.slot and nestModels[player] and nestModels[player][rec.slot]
	if not model then
		return
	end
	if model:GetAttribute("Stage") ~= stageOf(rec) then
		self:_spawnNestModel(player, rec)
		return
	end
	model:SetAttribute("Level", levelOf(rec))
	local name, color, line2 = tagText(rec)
	DragonBuilder.label(model, name, color, line2)
	local root = model.PrimaryPart
	local sell, levelUp = root:FindFirstChild("Prompt_sell"), root:FindFirstChild("Prompt_levelup")
	if sell then
		sell.ActionText = "Sell " .. Format.num(Formulas.sellValue(rec, os.time()))
	end
	if levelUp then
		levelUp.ActionText = levelUpText(rec)
	end
end

function DragonService:_removeNestModel(player, slot)
	local models = nestModels[player]
	if models and models[slot] then
		models[slot]:Destroy()
		models[slot] = nil
	end
end

-- Grey "buy nest" prompts on nests the player hasn't unlocked yet.
function DragonService:_drawLockedNests(player)
	local base = baseService:Get(player)
	local profile = data:Get(player)
	if not base or not profile then
		return
	end
	local max = self:MaxNests(player)
	for i, nest in base.world.nests do
		local open = i <= max
		nest.pad.Color = open and Color3.fromRGB(190, 150, 95) or Color3.fromRGB(120, 120, 130)
		local old = nest.pad:FindFirstChild("Prompt_nest")
		if old then
			old:Destroy()
		end
		-- every locked nest sells the next nest in line, so you can buy from whichever one you stand by
		if i > max and i <= Constants.BUYABLE_NESTS + (economy:HasPass(player, "NESTS") and 4 or 0) then
			local price = Constants.NEST_PRICES[profile.nestsBought + 1]
			if price then
				local p = prompt(nest.pad, "nest", "Buy nest " .. Format.num(price), "New nest", 0.4, player.UserId)
				p.Triggered:Connect(function(who)
					self:TryBuyNest(who)
				end)
			end
		end
	end
end

function DragonService:_clearNests(base)
	for _, nest in base.world.nests do
		nest.pad.Color = Color3.fromRGB(190, 150, 95)
		local old = nest.pad:FindFirstChild("Prompt_nest")
		if old then
			old:Destroy()
		end
	end
end

function DragonService:TryBuyNest(player)
	local profile = data:Get(player)
	if not profile then
		return
	end
	local price = Constants.NEST_PRICES[profile.nestsBought + 1]
	if not price or profile.nestsBought >= Constants.BUYABLE_NESTS then
		Net.fire(player, "Toast", "No more nests to buy!", "info")
		return
	end
	if not economy:Spend(player, price) then
		Net.fire(player, "Toast", "Not enough coins!", "bad")
		return
	end
	profile.nestsBought += 1
	Net.fire(player, "Toast", "New nest! 🪺", "good")
	self:_drawLockedNests(player)
	self:FillWaiting(player)
	self:PushWaiting(player)
	self.DragonsChanged:Fire(player)
end

-- Put a record (already in the player's profile, no slot) into a free nest. Returns true if it fit.
function DragonService:AddToBase(player, rec)
	local slot = self:FreeSlot(player) or self:MakeRoom(player)
	if not slot then
		return false
	end
	rec.slot = slot
	inTransit[rec] = nil
	self:_spawnNestModel(player, rec)
	baseService:PushIncome(player)
	self:PushWaiting(player)
	self.DragonsChanged:Fire(player)
	return true
end

function DragonService:FillWaiting(player)
	local profile = data:Get(player)
	if not profile or not baseService:Get(player) then
		return
	end
	for _, rec in profile.dragons do
		if not rec.slot and not inTransit[rec] then
			if not self:AddToBase(player, rec) then
				break
			end
		end
	end
	self:PushWaiting(player)
end

-- Give a brand-new dragon (gift, egg, deal). It goes to a nest, or waits for room.
function DragonService:Grant(player, id, special, born)
	local rec = self:NewRecord(player, id, special, born)
	if not self:AddToBase(player, rec) then
		Net.fire(player, "Toast", `{Dragons.byId[id].name} is waiting for a free nest!`, "info")
		self:PushWaiting(player)
	end
	return rec
end

-- Carrying ---------------------------------------------------------------------------------------------------
function DragonService:Carrying(player)
	return carrying[player]
end

function DragonService:PushCarry(player)
	local c = carrying[player]
	if c then
		local d = Dragons.byId[c.rec.id]
		data:Push(player, { carrying = { id = c.rec.id, name = d.name, rarity = d.rarity, kind = c.kind } })
	else
		data:Push(player, { carrying = false })
	end
end

-- kind: "bought" | "stolen" | "own" | "practice" | "free"
function DragonService:StartCarry(player, rec, owner, kind)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp or carrying[player] then
		return false
	end
	inTransit[rec] = true
	local model = DragonBuilder.build(rec.id, rec.sp, stageOf(rec), 0.6, skinOf(owner))
	local name, color = tagText(rec)
	DragonBuilder.label(model, name, color, "")
	DragonBuilder.place(model, hrp.CFrame * CFrame.new(0, 2.4, 0.4))
	local root = model.PrimaryPart
	root.Anchored = false
	root.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hrp
	weld.Part1 = root
	weld.Parent = root
	model.Name = "CarriedDragon"
	model.Parent = character
	carrying[player] = { rec = rec, owner = owner, kind = kind, model = model }
	player:SetAttribute("Carrying", rec.id)
	self:PushCarry(player)
	self.CarryChanged:Fire(player)
	return true
end

local function endCarry(player)
	local c = carrying[player]
	if not c then
		return nil
	end
	carrying[player] = nil
	if c.model then
		c.model:Destroy()
	end
	player:SetAttribute("Carrying", nil)
	return c
end

-- Send a record back to its owner's base (or the waiting list).
function DragonService:ReturnHome(rec, owner)
	inTransit[rec] = nil
	if owner and owner.Parent and data:Get(owner) and table.find(data:Get(owner).dragons, rec) then
		if not self:AddToBase(owner, rec) then
			self:PushWaiting(owner)
		end
	end
end

-- Stealing and selling ---------------------------------------------------------------------------------------
local function near(player, part, maxDist)
	local pos = baseService:Position(player)
	return pos ~= nil and (pos - part.Position).Magnitude <= maxDist
end

function DragonService:TrySteal(thief, model)
	local victim = Players:GetPlayerByUserId(model:GetAttribute("OwnerUserId") or 0)
	local victimProfile = victim and data:Get(victim)
	local rec = victimProfile and findRec(victimProfile, model:GetAttribute("Uid"))
	if not rec or not model.Parent then
		return
	end
	local base = baseService:Get(victim)
	if thief == victim then
		return
	end
	if team:AreTeam(thief, victim) then
		Net.fire(thief, "Toast", "That's your friend's dragon!", "info")
		return
	end
	if carrying[thief] then
		Net.fire(thief, "Toast", "Your hands are full!", "bad")
		return
	end
	if base and baseService:IsLocked(base) then
		Net.fire(thief, "Toast", "That base is locked!", "bad")
		return
	end
	if not baseService:Get(thief) or not self:HasRoom(thief) then
		Net.fire(thief, "Toast", "Your nests are full! Sell a dragon or buy a nest.", "bad")
		return
	end
	if not near(thief, model.PrimaryPart, 14) then
		return
	end
	local slot = rec.slot
	rec.slot = nil
	self:_removeNestModel(victim, slot)
	baseService:PushIncome(victim)
	if not self:StartCarry(thief, rec, victim, "stolen") then
		rec.slot = slot
		self:_spawnNestModel(victim, rec)
		return
	end
	local d = Dragons.byId[rec.id]
	Net.fire(
		victim,
		"Alert",
		`🚨 {thief.DisplayName} is stealing your {d.name}! BONK them!`,
		Color3.fromRGB(255, 80, 80),
		thief.Character
	)
	Net.fire(thief, "Toast", "You got it! Run home! 🏠", "good")
	Net.fire(thief, "Sfx", "steal")
	Net.fire(victim, "Sfx", "alarm")
	self.StealStarted:Fire(thief, victim, rec)
end

function DragonService:TrySell(player, model)
	local profile = data:Get(player)
	if not profile or model:GetAttribute("OwnerUserId") ~= player.UserId then
		return
	end
	local rec = findRec(profile, model:GetAttribute("Uid"))
	if not rec or not rec.slot or not near(player, model.PrimaryPart, 14) then
		return
	end
	local value = Formulas.sellValue(rec, os.time())
	self:_removeNestModel(player, rec.slot)
	removeRec(profile, rec)
	economy:Add(player, value, false)
	Net.fire(player, "Toast", `Sold {Dragons.byId[rec.id].name} for {Format.num(value)} coins`, "info")
	baseService:PushIncome(player)
	self:FillWaiting(player)
	self.DragonsChanged:Fire(player)
end

-- Buy one level with coins (the owner's "Level Up" prompt on a nest dragon).
function DragonService:TryLevelUp(player, model)
	local profile = data:Get(player)
	if not profile or model:GetAttribute("OwnerUserId") ~= player.UserId then
		return
	end
	local rec = findRec(profile, model:GetAttribute("Uid"))
	if not rec or not rec.slot or not near(player, model.PrimaryPart, 14) then
		return
	end
	local cost = Formulas.levelUpCost(rec, os.time())
	if not cost then
		Net.fire(player, "Toast", "That dragon is MAX level! ⭐", "info")
		return
	end
	if not economy:Spend(player, cost) then
		Net.fire(player, "Toast", `You need {Format.num(cost)} coins to level up.`, "bad")
		return
	end
	rec.lv = (rec.lv or 0) + 1
	self:_refreshNestModel(player, rec)
	baseService:PushIncome(player)
	Net.fire(player, "Popup", model.PrimaryPart.Position, `Lv {levelOf(rec)}!`, Color3.fromRGB(120, 230, 120))
	Net.fire(player, "Sfx", "levelup")
	self.DragonsChanged:Fire(player)
end

-- Add levels to a dragon (the +10 Levels purchase). Without a valid uid, the best dragon below MAX gets them.
function DragonService:AddLevels(player, uid, count)
	local profile = data:Get(player)
	local rec = profile and findRec(profile, uid)
	if rec and levelOf(rec) >= Constants.MAX_LEVEL then
		rec = nil
	end
	if not rec then
		local best
		for _, r in profile and profile.dragons or {} do
			if
				levelOf(r) < Constants.MAX_LEVEL
				and (not best or Formulas.dragonIncome(r, os.time()) > Formulas.dragonIncome(best, os.time()))
			then
				best = r
			end
		end
		rec = best
	end
	if not rec then
		return false
	end
	rec.lv = (rec.lv or 0) + math.min(count, Constants.MAX_LEVEL - levelOf(rec))
	self:_refreshNestModel(player, rec)
	baseService:PushIncome(player)
	Net.fire(player, "Toast", `{Dragons.byId[rec.id].name} is now level {levelOf(rec)}! ⭐`, "good")
	self.DragonsChanged:Fire(player)
	return true
end

-- Level up every nest dragon with coins (the LEVEL ALL plate): keep buying the cheapest next level until the
-- coins run out. Returns how many levels were bought and the coins spent.
function DragonService:LevelAll(player)
	local profile = data:Get(player)
	if not profile then
		return 0, 0
	end
	local now = os.time()
	local bought, spent, changed = 0, 0, {}
	for _ = 1, 2000 do
		local best, bestCost
		for _, rec in profile.dragons do
			local cost = rec.slot and Formulas.levelUpCost(rec, now)
			if cost and (not bestCost or cost < bestCost) then
				best, bestCost = rec, cost
			end
		end
		if not best or profile.coins < bestCost or not economy:Spend(player, bestCost) then
			break
		end
		best.lv = (best.lv or 0) + 1
		bought += 1
		spent += bestCost
		changed[best] = true
	end
	for rec in changed do
		self:_refreshNestModel(player, rec)
	end
	if bought > 0 then
		baseService:PushIncome(player)
		self.DragonsChanged:Fire(player)
	end
	return bought, spent
end

-- Whether the player has a nest dragon below MAX level.
function DragonService:CanLevelAny(player)
	local profile = data:Get(player)
	for _, rec in profile and profile.dragons or {} do
		if rec.slot and levelOf(rec) < Constants.MAX_LEVEL then
			return true
		end
	end
	return false
end

-- Add levels to every nest dragon (the +5 Levels for ALL purchase). Returns how many dragons got levels.
function DragonService:AddLevelsAll(player, count)
	local profile = data:Get(player)
	local n = 0
	for _, rec in profile and profile.dragons or {} do
		local room = Constants.MAX_LEVEL - levelOf(rec)
		if rec.slot and room > 0 then
			rec.lv = (rec.lv or 0) + math.min(count, room)
			self:_refreshNestModel(player, rec)
			n += 1
		end
	end
	if n > 0 then
		baseService:PushIncome(player)
		Net.fire(player, "Toast", `{n} dragons got +{count} levels! ⭐`, "good")
		self.DragonsChanged:Fire(player)
	end
	return n
end

-- Repaint all of a player's dragons after they changed skin.
function DragonService:RefreshSkin(player)
	local profile = data:Get(player)
	for _, rec in profile and profile.dragons or {} do
		if rec.slot and nestModels[player] and nestModels[player][rec.slot] then
			self:_spawnNestModel(player, rec)
		end
	end
end

-- Dropping (bonked) and grabbing -----------------------------------------------------------------------------
function DragonService:Drop(player)
	local c = endCarry(player)
	if not c then
		return
	end
	self:PushCarry(player)
	self.CarryChanged:Fire(player)
	local pos = baseService:Position(player) or Vector3.new(0, 3, 0)
	local model = DragonBuilder.build(c.rec.id, c.rec.sp, stageOf(c.rec), nil, skinOf(c.owner))
	DragonBuilder.place(model, CFrame.new(pos.X, 0.5, pos.Z))
	local name, color = tagText(c.rec)
	DragonBuilder.label(model, name, color, "GRAB IT!")
	model.Name = "DroppedDragon"
	local grab = prompt(model.PrimaryPart, "grab", "Grab", name, 0.3, 0)
	grab.Triggered:Connect(function(who)
		self:TryGrab(who, model)
	end)
	model.Parent = folder
	dropped[model] = { rec = c.rec, owner = c.owner, expires = os.clock() + Constants.DROP_GRAB_SECONDS }
end

function DragonService:TryGrab(player, model)
	local d = dropped[model]
	if not d or carrying[player] or not near(player, model.PrimaryPart, 14) then
		return
	end
	local isOwner = player == d.owner
	if not isOwner and (not baseService:Get(player) or not self:HasRoom(player)) then
		Net.fire(player, "Toast", "Your nests are full!", "bad")
		return
	end
	if d.owner and d.owner ~= player and team:AreTeam(player, d.owner) then
		Net.fire(player, "Toast", "That's your friend's dragon!", "info")
		return
	end
	dropped[model] = nil
	model:Destroy()
	self:StartCarry(player, d.rec, d.owner, isOwner and "own" or "stolen")
end

-- Placing ----------------------------------------------------------------------------------------------------
function DragonService:_place(player)
	local c = carrying[player]
	local profile = data:Get(player)
	if not c or not profile then
		return
	end
	local slot = self:FreeSlot(player) or self:MakeRoom(player)
	if not slot then
		if (lastRoomToast[player] or -99) < os.clock() - 3 then
			lastRoomToast[player] = os.clock()
			Net.fire(player, "Toast", "No room! Sell a dragon or buy a nest.", "bad")
		end
		return
	end
	endCarry(player)
	local rec = c.rec
	local from = c.owner
	if from and from ~= player then
		-- the steal is complete: move the record to the thief
		local fromProfile = data:Get(from)
		if fromProfile then
			removeRec(fromProfile, rec)
			self.DragonsChanged:Fire(from)
		end
		rec.uid = profile.nextUid
		profile.nextUid += 1
		table.insert(profile.dragons, rec)
	end
	inTransit[rec] = nil
	rec.slot = slot
	self:_spawnNestModel(player, rec)
	baseService:PushIncome(player)
	self:PushCarry(player)
	self:PushWaiting(player)
	self.CarryChanged:Fire(player)
	local d = Dragons.byId[rec.id]
	if c.kind == "stolen" and from and from ~= player then
		profile.steals += 1
		economy:PushCoins(player)
		Net.fire(player, "Alert", `STOLEN! {d.name} is yours! 😎`, Color3.fromRGB(80, 220, 120))
		if from.Parent then
			Net.fire(from, "Alert", `{player.DisplayName} stole your {d.name}! 😭`, Color3.fromRGB(255, 80, 80))
		end
		-- team steal: a friend nearby earns you a bonus
		local pos = baseService:Position(player)
		for _, mate in team:Teammates(player) do
			local mp = baseService:Position(mate)
			if pos and mp and (mp - pos).Magnitude <= Constants.TEAM_STEAL_RANGE then
				local bonus = math.floor(Formulas.dragonIncome(rec, os.time()) * Constants.TEAM_STEAL_BONUS_SECONDS)
				economy:Add(player, bonus)
				economy:Add(mate, bonus)
				Net.fire(player, "Toast", `TEAM STEAL! +{Format.num(bonus)} for you and {mate.DisplayName}!`, "good")
				Net.fire(mate, "Toast", `TEAM STEAL! +{Format.num(bonus)}!`, "good")
				break
			end
		end
	else
		Net.fire(player, "Toast", `{d.name} is in your nest! 🪺`, "good")
	end
	self.Placed:Fire(player, rec, c.kind, from)
	self.DragonsChanged:Fire(player)
end

-- Lifecycle --------------------------------------------------------------------------------------------------
function DragonService:OnPlayerReady(player, profile)
	nestModels[player] = {}
	-- tidy slots: drop duplicates and slots beyond the nest count, then fill
	local seen = {}
	local max = self:MaxNests(player)
	for _, rec in profile.dragons do
		if rec.slot and (seen[rec.slot] or rec.slot > max) then
			rec.slot = nil
		end
		if rec.slot then
			seen[rec.slot] = true
		end
	end
	for _, rec in profile.dragons do
		if rec.slot then
			self:_spawnNestModel(player, rec)
		end
	end
	self:FillWaiting(player)
	self:_drawLockedNests(player)
	baseService:PushIncome(player)
	player.CharacterAdded:Connect(function()
		-- respawned while carrying: the dragon goes home
		local c = endCarry(player)
		if c then
			self:ReturnHome(c.rec, c.owner)
			self:PushCarry(player)
			self.CarryChanged:Fire(player)
		end
	end)
end

function DragonService:OnPlayerLeaving(player, profile)
	-- 1. what the leaving player carries goes home (a stolen one back to its owner)
	local c = endCarry(player)
	if c then
		if c.owner and c.owner ~= player then
			self:ReturnHome(c.rec, c.owner)
		else
			inTransit[c.rec] = nil
		end
	end
	-- 2. someone carrying this player's dragon keeps it
	for other, oc in carrying do
		if oc.owner == player then
			removeRec(profile, oc.rec)
			local otherProfile = data:Get(other)
			if otherProfile then
				oc.rec.uid = otherProfile.nextUid
				otherProfile.nextUid += 1
				table.insert(otherProfile.dragons, oc.rec)
				oc.owner = other
				oc.kind = "own"
				Net.fire(other, "Toast", "They left the game. The dragon is yours!", "good")
			end
		end
	end
	-- 3. this player's dragons lying on the ground stay theirs
	for model, d in dropped do
		if d.owner == player then
			inTransit[d.rec] = nil
			dropped[model] = nil
			model:Destroy()
		end
	end
	for _, model in nestModels[player] or {} do
		model:Destroy()
	end
	nestModels[player] = nil
	local base = baseService:Get(player)
	if base then
		self:_clearNests(base)
	end
	lastRoomToast[player] = nil
end

function DragonService:_tick()
	-- dropped dragons fly home when nobody grabbed them
	for model, d in dropped do
		if os.clock() >= d.expires then
			dropped[model] = nil
			model:Destroy()
			self:ReturnHome(d.rec, d.owner)
		else
			local tag = model.PrimaryPart:FindFirstChild("Tag")
			if tag then
				tag.Line2.Text = "GRAB IT! " .. math.ceil(d.expires - os.clock())
			end
		end
	end
	-- dragons level up over time: new size -> bigger model and a toast, otherwise just new tag text
	for player, models in nestModels do
		local profile = data:Get(player)
		local changed = false
		for _, rec in profile and profile.dragons or {} do
			local model = rec.slot and models[rec.slot]
			if model and model:GetAttribute("Level") ~= levelOf(rec) then
				local grew = model:GetAttribute("Stage") ~= stageOf(rec)
				self:_refreshNestModel(player, rec)
				changed = true
				if grew then
					Net.fire(
						player,
						"Toast",
						`{Dragons.byId[rec.id].name} grew to {Constants.STAGE_NAMES[stageOf(rec)]}! 🌱`,
						"good"
					)
				end
			end
		end
		if changed then
			baseService:PushIncome(player)
		end
	end
end

function DragonService:Start()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.1 then
			return
		end
		acc = 0
		for player in carrying do
			if baseService:InOwnBase(player) then
				self:_place(player)
			end
		end
	end)
	while true do
		task.wait(1)
		self:_tick()
	end
end

return DragonService
