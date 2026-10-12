-- Your blasters: the inventory, the one in your hand (a Tool), selling, Power Up, and the view the panels show.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Blasters = require(ReplicatedStorage.Shared.Data.Blasters)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local BlasterBuilder = require(script.Parent.Parent.World.BlasterBuilder)

local BlasterService = {
	Name = "BlasterService",
	Dependencies = { "PlayerDataService", "EconomyService" },
	Changed = Signal.new("BlasterService.Changed"), -- (player) inventory or equip changed
	Gained = Signal.new("BlasterService.Gained"), -- (player, rec, how) a new blaster: "forge" | "gift" | "raid"
}

local data, economy
local tools = {} -- [player] = the Tool

local function findRec(profile, uid)
	for i, rec in profile.blasters do
		if rec.uid == uid then
			return rec, i
		end
	end
	return nil
end

-- What the client sees for one blaster.
function BlasterService.view(rec)
	return {
		uid = rec.uid,
		name = Formulas.blasterName(rec),
		rarity = rec.rarity,
		planet = rec.planet,
		roll = rec.roll,
		stars = Formulas.rollStars(rec),
		lv = rec.lv or 0,
		damage = Formulas.blasterDamage(rec),
		power = Formulas.blasterPower(rec),
		sell = Formulas.sellValue(rec),
		powerUp = Formulas.powerUpCost(rec),
	}
end

function BlasterService:Push(player)
	local profile = data:Get(player)
	if not profile then
		return
	end
	local list = {}
	for _, rec in profile.blasters do
		table.insert(list, self.view(rec))
	end
	table.sort(list, function(a, b)
		return a.power > b.power
	end)
	data:Push(player, { blasters = list, equipped = profile.equipped, maxBlasters = Constants.MAX_BLASTERS })
end

function BlasterService:Equipped(player)
	local profile = data:Get(player)
	return profile and profile.equipped and findRec(profile, profile.equipped) or nil
end

function BlasterService:Best(player)
	local profile = data:Get(player)
	local best, bestP
	for _, rec in profile and profile.blasters or {} do
		local p = Formulas.blasterPower(rec)
		if not best or p > bestP then
			best, bestP = rec, p
		end
	end
	return best
end

-- Add a rolled blaster to the inventory. Returns the record (with its uid).
function BlasterService:Grant(player, rolled, how)
	local profile = data:Get(player)
	if not profile then
		return nil
	end
	local rec = {
		uid = profile.nextUid,
		rarity = rolled.rarity,
		planet = rolled.planet,
		roll = rolled.roll,
		lv = rolled.lv or 0,
		born = os.time(),
	}
	profile.nextUid += 1
	table.insert(profile.blasters, rec)
	-- a brand-new or better blaster goes straight into your hand
	local current = self:Equipped(player)
	if not current or Formulas.blasterPower(rec) > Formulas.blasterPower(current) then
		self:Equip(player, rec.uid, true)
	end
	self:Push(player)
	self.Gained:Fire(player, rec, how or "forge")
	self.Changed:Fire(player)
	return rec
end

-- The Tool in the player's hand matches the equipped record.
function BlasterService:_rebuildTool(player)
	local old = tools[player]
	if old then
		old:Destroy()
		tools[player] = nil
	end
	local rec = self:Equipped(player)
	if not rec then
		return
	end
	local tool = BlasterBuilder.tool(rec, Formulas.blasterName(rec), Formulas.blasterCooldown(rec))
	tools[player] = tool
	local backpack = player:FindFirstChildOfClass("Backpack")
	tool.Parent = backpack or player
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum:EquipTool(tool)
	end
end

function BlasterService:Equip(player, uid, quiet)
	local profile = data:Get(player)
	local rec = profile and findRec(profile, uid)
	if not rec then
		return false
	end
	profile.equipped = uid
	self:_rebuildTool(player)
	if not quiet then
		Net.fire(player, "Toast", `Holding {Formulas.blasterName(rec)} {Formulas.rollStars(rec)}`, "good")
		Net.fire(player, "Sfx", "equip")
	end
	self:Push(player)
	self.Changed:Fire(player)
	return true
end

function BlasterService:Sell(player, uid)
	local profile = data:Get(player)
	local rec, i = findRec(profile, uid)
	if not rec then
		return
	end
	if #profile.blasters <= 1 then
		Net.fire(player, "Toast", "You need at least one blaster!", "bad")
		return
	end
	local value = Formulas.sellValue(rec)
	table.remove(profile.blasters, i)
	profile.stats.sold += 1
	economy:AddCoins(player, value, false)
	if profile.equipped == uid then
		local best = self:Best(player)
		profile.equipped = best and best.uid or nil
		self:_rebuildTool(player)
	end
	Net.fire(player, "Toast", `Sold for {Format.num(value)} coins`, "good")
	Net.fire(player, "Sfx", "coin")
	self:Push(player)
	self.Changed:Fire(player)
end

function BlasterService:PowerUp(player, uid)
	local profile = data:Get(player)
	local rec = findRec(profile, uid)
	if not rec then
		return
	end
	local cost = Formulas.powerUpCost(rec)
	if not cost then
		Net.fire(player, "Toast", "That blaster is at MAX power! ⭐", "info")
		return
	end
	if not economy:SpendCoins(player, cost) then
		Net.fire(player, "Toast", `You need {Format.num(cost)} coins.`, "bad")
		return
	end
	rec.lv = (rec.lv or 0) + 1
	profile.stats.powerUps += 1
	Net.fire(player, "Toast", `💥 Power {rec.lv}! {Format.num(Formulas.blasterDamage(rec))} damage`, "good")
	Net.fire(player, "Sfx", "levelup")
	if profile.equipped == uid then
		local tool = tools[player]
		if tool then
			tool:SetAttribute("Cooldown", Formulas.blasterCooldown(rec))
		end
	end
	self:Push(player)
	self.Changed:Fire(player)
end

function BlasterService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	Net.on("Equip", function(player, uid)
		if type(uid) == "number" then
			self:Equip(player, uid)
		end
	end)
	Net.on("Sell", function(player, uid)
		if type(uid) == "number" then
			self:Sell(player, uid)
		end
	end)
	Net.on("PowerUp", function(player, uid)
		if type(uid) == "number" then
			self:PowerUp(player, uid)
		end
	end)
	data.ClientReady:Connect(function(player)
		self:Push(player)
	end)
end

function BlasterService:OnPlayerReady(player, profile)
	-- everyone starts with a plain Dust Zapper
	if #profile.blasters == 0 then
		self:Grant(player, {
			rarity = "Common",
			planet = "DUST",
			roll = { dmg = "plain", spd = "plain", luck = "plain", gem = "plain" },
			lv = 0,
		}, "start")
	elseif not self:Equipped(player) then
		local best = self:Best(player)
		profile.equipped = best and best.uid
	end
	local function spawned()
		task.defer(function()
			if player.Parent then
				self:_rebuildTool(player)
			end
		end)
	end
	player.CharacterAdded:Connect(spawned)
	if player.Character then
		spawned()
	end
end

function BlasterService:OnPlayerLeaving(player)
	tools[player] = nil
end

function BlasterService:Rarity(rec)
	return Blasters.byRarity[rec.rarity]
end

return BlasterService
