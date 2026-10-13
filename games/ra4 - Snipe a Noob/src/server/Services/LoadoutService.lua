-- What you carry and wear: your rifles (unlock by level, buy with coins), skins (one per rifle), mastery looks
-- (pop 100 / 500 / 2,000 with a rifle), your pop effect, podium emote, crosshair and kill-feed name colour.
-- Also the Daily Shop (6 skins, 2 pop effects, 2 emotes, new every day at 7pm ET) and the Style counter
-- (crosshairs and name colours, always there). Builds the rifle Tool other players see in your hands.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local RifleModel = require(ReplicatedStorage.Shared.RifleModel)
local Rifles = require(ReplicatedStorage.Shared.Data.Rifles)
local Signal = require(ReplicatedStorage.Shared.Signal)

local LoadoutService = {
	Name = "LoadoutService",
	Dependencies = { "PlayerDataService", "EconomyService" },
	SkinGained = Signal.new("LoadoutService.SkinGained"), -- (player, skinId, how)
	Bought = Signal.new("LoadoutService.Bought"), -- (player, kind, id, coins)
	Mastered = Signal.new("LoadoutService.Mastered"), -- (player, rifleKey, tier)
}

local data, economy

local function profileOf(player)
	return data:Get(player)
end

-- Reading -------------------------------------------------------------------------------------------------------
function LoadoutService:Rifle(player)
	local profile = profileOf(player)
	return Rifles.byKey[profile and profile.rifle or "BOLT"] or Rifles.list[1]
end

local function skinRec(profile, uid)
	for _, s in profile.skins do
		if s.uid == uid then
			return s
		end
	end
	return nil
end

-- The skin id on a rifle (or nil).
function LoadoutService:SkinId(player, rifleKey)
	local profile = profileOf(player)
	if not profile then
		return nil
	end
	local uid = profile.skinOn[rifleKey or profile.rifle]
	local rec = uid and skinRec(profile, uid)
	return rec and rec.id or nil
end

function LoadoutService:SkinName(player)
	local id = self:SkinId(player)
	local skin = id and Cosmetics.skinById[id]
	return skin and skin.name or nil
end

function LoadoutService:MasteryTier(player, rifleKey)
	local profile = profileOf(player)
	local pops = profile and profile.mastery[rifleKey or profile.rifle] or 0
	local tier = 0
	for i, need in Constants.MASTERY do
		if pops >= need then
			tier = i
		end
	end
	return tier
end

function LoadoutService:Effect(player)
	local profile = profileOf(player)
	return profile and profile.effect or "BRICKS"
end

function LoadoutService:Emote(player)
	local profile = profileOf(player)
	return profile and Cosmetics.emoteById[profile.emote] or Cosmetics.Emotes[1]
end

function LoadoutService:NameColor(player)
	local profile = profileOf(player)
	local c = profile and Cosmetics.nameColorById[profile.nameColor]
	if economy:HasPass(player, "VIP") and (not profile or profile.nameColor == "WHITE") then
		return Cosmetics.nameColorById.GOLD.color
	end
	return c and c.color or Color3.fromRGB(255, 255, 255)
end

function LoadoutService:TracerColor(player)
	local look = RifleModel.look(self:Rifle(player).key, self:SkinId(player), self:MasteryTier(player))
	return look.accent
end

-- The view the client shows in the Rifles, Style and Shop panels.
function LoadoutService:View(player)
	local profile = profileOf(player)
	local level = economy:Level(player)
	local rifles = {}
	for _, r in Rifles.list do
		table.insert(rifles, {
			key = r.key,
			owned = profile.rifles[r.key] == true,
			locked = level < r.level,
			equipped = profile.rifle == r.key,
			second = profile.rifle2 == r.key,
			mastery = profile.mastery[r.key] or 0,
			tier = self:MasteryTier(player, r.key),
			skin = self:SkinId(player, r.key),
		})
	end
	local skins = {}
	for _, s in profile.skins do
		local on
		for rk, uid in profile.skinOn do
			if uid == s.uid then
				on = rk
			end
		end
		table.insert(skins, { uid = s.uid, id = s.id, on = on })
	end
	local period = Formulas.dailyPeriod(os.time())
	local _, endsAt = Formulas.dailyPeriod(os.time())
	local shop = {}
	local bought = profile.bought[tostring(period)] or {}
	for i, item in Formulas.dailyShop(period) do
		table.insert(shop, { kind = item.kind, id = item.id, price = item.price, bought = bought[tostring(i)] == true })
	end
	return {
		rifles = rifles,
		rifle = profile.rifle,
		rifle2 = profile.rifle2,
		skins = skins,
		effects = table.clone(profile.effects),
		effect = profile.effect,
		emotes = table.clone(profile.emotes),
		emote = profile.emote,
		crosshairs = table.clone(profile.crosshairs),
		crosshair = profile.crosshair,
		nameColors = table.clone(profile.nameColors),
		nameColor = profile.nameColor,
		shop = shop,
		shopEndsAt = endsAt,
	}
end

function LoadoutService:Push(player)
	if profileOf(player) then
		data:Push(player, { loadout = self:View(player) })
	end
end

-- The rifle in your hands ------------------------------------------------------------------------------------
function LoadoutService:GiveTool(player)
	local c = player.Character
	local profile = profileOf(player)
	if not c or not profile then
		return
	end
	for _, holder in { c, player:FindFirstChildOfClass("Backpack") } do
		local old = holder and holder:FindFirstChild("Rifle")
		if old then
			old:Destroy()
		end
	end
	local tool = RifleModel.tool(profile.rifle, self:SkinId(player), self:MasteryTier(player))
	tool.Parent = c
	local hum = c:FindFirstChildOfClass("Humanoid")
	if hum then
		pcall(hum.EquipTool, hum, tool)
	end
end

-- Changing things -----------------------------------------------------------------------------------------------
function LoadoutService:EquipRifle(player, key)
	local profile = profileOf(player)
	if not profile or not profile.rifles[key] then
		return false
	end
	if profile.rifle ~= key then
		if economy:HasPass(player, "LOADOUT") then
			profile.rifle2 = profile.rifle
		end
		profile.rifle = key
	end
	self:GiveTool(player)
	self:Push(player)
	Net.fire(player, "Sfx", "bolt")
	return true
end

-- Extra Loadout: swap to the second rifle (in a round too).
function LoadoutService:SwapRifle(player)
	local profile = profileOf(player)
	if not profile or not economy:HasPass(player, "LOADOUT") then
		return false
	end
	local second = profile.rifle2
	if not second or not profile.rifles[second] or second == profile.rifle then
		return false
	end
	profile.rifle2 = profile.rifle
	profile.rifle = second
	self:GiveTool(player)
	self:Push(player)
	Net.fire(player, "Sfx", "bolt")
	return true
end

function LoadoutService:BuyRifle(player, key)
	local profile = profileOf(player)
	local rifle = Rifles.byKey[key]
	if not profile or not rifle or profile.rifles[key] then
		return false
	end
	if economy:Level(player) < rifle.level then
		Net.fire(player, "Toast", `Reach level {rifle.level} to unlock {rifle.name}.`, "info")
		return false
	end
	if not economy:SpendCoins(player, rifle.price) then
		Net.fire(player, "Toast", `You need {rifle.price} coins.`, "bad")
		return false
	end
	profile.rifles[key] = true
	Net.fire(player, "Alert", `🔫 NEW RIFLE: {rifle.name}!`, Color3.fromRGB(120, 200, 255))
	Net.fire(player, "Sfx", "buy")
	self.Bought:Fire(player, "rifle", key, rifle.price)
	self:EquipRifle(player, key)
	return true
end

function LoadoutService:GrantSkin(player, skinId, how)
	local profile = profileOf(player)
	local skin = Cosmetics.skinById[skinId]
	if not profile or not skin then
		return nil
	end
	local rec = { uid = profile.nextUid, id = skinId }
	profile.nextUid += 1
	table.insert(profile.skins, rec)
	self.SkinGained:Fire(player, skinId, how)
	self:Push(player)
	return rec
end

-- Take a skin out of the bag (trading). Returns the record.
function LoadoutService:TakeSkin(player, uid)
	local profile = profileOf(player)
	if not profile then
		return nil
	end
	for i, s in profile.skins do
		if s.uid == uid then
			table.remove(profile.skins, i)
			for rk, on in table.clone(profile.skinOn) do
				if on == uid then
					profile.skinOn[rk] = nil
					if rk == profile.rifle then
						self:GiveTool(player)
					end
				end
			end
			self:Push(player)
			return s
		end
	end
	return nil
end

function LoadoutService:EquipSkin(player, rifleKey, uid)
	local profile = profileOf(player)
	if not profile or not Rifles.byKey[rifleKey] then
		return false
	end
	if uid == nil then
		profile.skinOn[rifleKey] = nil
	else
		if not skinRec(profile, uid) then
			return false
		end
		-- a skin is on one rifle at a time
		for rk, on in table.clone(profile.skinOn) do
			if on == uid then
				profile.skinOn[rk] = nil
			end
		end
		profile.skinOn[rifleKey] = uid
	end
	if rifleKey == profile.rifle then
		self:GiveTool(player)
	end
	self:Push(player)
	Net.fire(player, "Sfx", "bolt")
	return true
end

local STYLE = {
	effect = { owned = "effects", field = "effect", list = Cosmetics.effectById },
	emote = { owned = "emotes", field = "emote", list = Cosmetics.emoteById },
	crosshair = { owned = "crosshairs", field = "crosshair", list = Cosmetics.crosshairById },
	nameColor = { owned = "nameColors", field = "nameColor", list = Cosmetics.nameColorById },
}

function LoadoutService:EquipStyle(player, kind, id)
	local profile = profileOf(player)
	local s = STYLE[kind]
	if not profile or not s or not profile[s.owned][id] then
		return false
	end
	profile[s.field] = id
	self:Push(player)
	return true
end

function LoadoutService:GrantStyle(player, kind, id)
	local profile = profileOf(player)
	local s = STYLE[kind]
	if not profile or not s or not s.list[id] then
		return false
	end
	profile[s.owned][id] = true
	self:Push(player)
	return true
end

-- Crosshairs and name colours: always on the Style counter.
function LoadoutService:BuyStyle(player, kind, id)
	local profile = profileOf(player)
	local s = STYLE[kind]
	if not profile or (kind ~= "crosshair" and kind ~= "nameColor") then
		return false
	end
	local item = s.list[id]
	if not item or profile[s.owned][id] then
		return false
	end
	if not economy:SpendCoins(player, item.price) then
		Net.fire(player, "Toast", `You need {item.price} coins.`, "bad")
		return false
	end
	profile[s.owned][id] = true
	profile[s.field] = id
	Net.fire(player, "Toast", `{item.name} is yours!`, "good")
	Net.fire(player, "Sfx", "buy")
	self.Bought:Fire(player, kind, id, item.price)
	self:Push(player)
	return true
end

-- Buy item `index` of today's Daily Shop.
function LoadoutService:BuyShop(player, index)
	local profile = profileOf(player)
	if not profile then
		return false
	end
	local period = Formulas.dailyPeriod(os.time())
	local item = Formulas.dailyShop(period)[index]
	if not item then
		return false
	end
	local key = tostring(period)
	profile.bought[key] = profile.bought[key] or {}
	if profile.bought[key][tostring(index)] then
		Net.fire(player, "Toast", "You already bought that today.", "info")
		return false
	end
	if item.kind ~= "skin" then
		local s = STYLE[item.kind]
		if profile[s.owned][item.id] then
			Net.fire(player, "Toast", "You already have that.", "info")
			return false
		end
	end
	if not economy:SpendCoins(player, item.price) then
		Net.fire(player, "Toast", `You need {item.price} coins. Pop more players!`, "bad")
		return false
	end
	profile.bought[key][tostring(index)] = true
	-- keep only the last few days of shop buys
	for k in table.clone(profile.bought) do
		if tonumber(k) and tonumber(k) < period - 3 then
			profile.bought[k] = nil
		end
	end
	if item.kind == "skin" then
		self:GrantSkin(player, item.id, "shop")
		local skin = Cosmetics.skinById[item.id]
		Net.fire(player, "Alert", `✨ {skin.name} skin!`, Cosmetics.RarityColor[skin.rarity])
	else
		self:GrantStyle(player, item.kind, item.id)
		self:EquipStyle(player, item.kind, item.id)
		Net.fire(player, "Toast", "Yours! It's on.", "good")
	end
	Net.fire(player, "Sfx", "buy")
	self.Bought:Fire(player, item.kind, item.id, item.price)
	self:Push(player)
	return true
end

-- A pop with your rifle: mastery goes up; a new look at 100, 500 and 2,000.
function LoadoutService:AddMasteryPop(player)
	local profile = profileOf(player)
	if not profile then
		return
	end
	local key = profile.rifle
	local before = self:MasteryTier(player, key)
	profile.mastery[key] = (profile.mastery[key] or 0) + 1
	local after = self:MasteryTier(player, key)
	if after > before then
		local rifle = Rifles.byKey[key]
		Net.fire(
			player,
			"Alert",
			`🏅 {RifleModel.MASTERY_NAMES[after]} {rifle.name} unlocked!`,
			Color3.fromRGB(255, 215, 60)
		)
		self.Mastered:Fire(player, key, after)
		if not self:SkinId(player, key) then
			self:GiveTool(player)
		end
		self:Push(player)
	end
end

function LoadoutService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	Net.on("EquipRifle", function(player, key)
		if type(key) == "string" then
			self:EquipRifle(player, key)
		end
	end)
	Net.on("BuyRifle", function(player, key)
		if type(key) == "string" then
			self:BuyRifle(player, key)
		end
	end)
	Net.on("SwapRifle", function(player)
		self:SwapRifle(player)
	end)
	Net.on("EquipSkin", function(player, rifleKey, uid)
		if type(rifleKey) == "string" and (uid == nil or type(uid) == "number") then
			self:EquipSkin(player, rifleKey, uid)
		end
	end)
	Net.on("EquipStyle", function(player, kind, id)
		if type(kind) == "string" and type(id) == "string" then
			self:EquipStyle(player, kind, id)
		end
	end)
	Net.on("BuyStyle", function(player, kind, id)
		if type(kind) == "string" and type(id) == "string" then
			self:BuyStyle(player, kind, id)
		end
	end)
	Net.on("BuyShop", function(player, index)
		if type(index) == "number" then
			self:BuyShop(player, math.floor(index))
		end
	end)
	data.ClientReady:Connect(function(player)
		self:Push(player)
	end)
	economy.LevelUp:Connect(function(player, level)
		self:Push(player)
		for _, r in Rifles.list do
			if r.level == level then
				Net.fire(player, "Toast", `🔓 {r.name} unlocked! Get it at the Rifles counter.`, "good")
			end
		end
	end)
	economy.PassesChanged:Connect(function(player)
		self:Push(player)
	end)
end

function LoadoutService:OnPlayerReady(player, profile)
	if not profile.rifles[profile.rifle] then
		profile.rifle = "BOLT"
	end
	local function spawned(character)
		task.defer(function()
			if player.Parent and player.Character == character then
				local hum = character:FindFirstChildOfClass("Humanoid")
				if hum then
					hum.WalkSpeed = Constants.WALK_SPEED
				end
				self:GiveTool(player)
			end
		end)
	end
	player.CharacterAdded:Connect(spawned)
	if player.Character then
		spawned(player.Character)
	end
	_ = Players
end

return LoadoutService
