--[[
Making things at the castle's stations (master plan §4 step 2: dwarves make armor, weapons, food and potions).
Stand by a built station and pay from your bag:

  Forge         armor (take less damage) and weapon (hit harder) tiers, up to 3 each, this match only
  Kitchen       stew: heals over a few seconds (carry up to 3)
  Potion Table  a potion: a quick heal and a burst of speed (carry up to 3)

Then "Use" eats or drinks one. All of it is for this match and paid with what you mined, never with Robux (§18).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Pieces = require(ReplicatedStorage.Shared.Data.Pieces)
local Signal = require(ReplicatedStorage.Shared.Signal)

local CraftService = {
	Name = "CraftService",
	Dependencies = { "MatchService", "TeamService", "ResourceService", "BuildService", "CombatService" },
	Crafted = Signal.new("CraftService.Crafted"), -- (player, item, tier?)
	Used = Signal.new("CraftService.Used"), -- (player, item)
}

local match, teams, resources, build, combat
local lastUse = {} -- [player] = time

local STATION = { armor = "forge", weapon = "forge", food = "kitchen", potion = "potion" }
local NAMES = { forge = "Forge", kitchen = "Kitchen", potion = "Potion Table" }

local function now()
	return workspace:GetServerTimeNow()
end

-- A built station of this kind in reach.
function CraftService:StationNear(player, kind)
	local pos = teams:Position(player)
	if not pos then
		return nil
	end
	for _, p in build:Near(pos, Constants.CRAFT_RANGE, true) do
		if p.def.station == kind then
			return p
		end
	end
	return nil
end

-- What an item costs right now (gear gets dearer each tier).
function CraftService:Cost(player, item)
	local s = teams:State(player)
	if item == "armor" or item == "weapon" then
		local tier = s and s.gear[item] or 0
		return Constants.GEAR_COST[tier + 1], tier
	elseif item == "food" then
		return Constants.FOOD_COST
	elseif item == "potion" then
		return Constants.POTION_COST
	end
	return nil
end

function CraftService:Craft(player, item)
	local kind = STATION[item]
	if not kind then
		return false, "Nothing to make."
	end
	if teams:Team(player) ~= "dwarf" or not teams:IsAlive(player) or not match:InMatch() then
		return false, "Only dwarves can make things."
	end
	if not self:StationNear(player, kind) then
		return false, `Stand by a {NAMES[kind]} first.`
	end
	local s = teams:State(player)
	local cost, tier = self:Cost(player, item)
	if not cost then
		return false, "That's as good as it gets!"
	end
	if item == "food" and s.food >= Constants.CARRY_MAX then
		return false, "You can't carry more food."
	end
	if item == "potion" and s.potions >= Constants.CARRY_MAX then
		return false, "You can't carry more potions."
	end
	local need = {}
	for k, n in cost do
		if n > 0 then
			need[k] = n
		end
	end
	if not resources:Take(player, need) then
		return false, "You need " .. Pieces.costText(need) .. "."
	end
	if item == "armor" or item == "weapon" then
		s.gear[item] = tier + 1
	elseif item == "food" then
		s.food += 1
	else
		s.potions += 1
	end
	teams:Stat(player, "crafted", 1)
	teams:Push(player)
	local pos = teams:Position(player)
	Net.fireAll("Fx", "craft", { position = pos, item = item, by = player.UserId })
	Net.fire(player, "Sfx", "buy")
	self.Crafted:Fire(player, item, s.gear[item])
	return true
end

function CraftService:Use(player, item)
	if teams:Team(player) ~= "dwarf" or not teams:IsAlive(player) then
		return false
	end
	local s = teams:State(player)
	local t = now()
	if t - (lastUse[player] or 0) < Constants.EAT_COOLDOWN then
		return false
	end
	if item == "food" and s.food > 0 then
		s.food -= 1
		lastUse[player] = t
		local per = Constants.FOOD_HEAL / Constants.FOOD_SECONDS
		task.spawn(function()
			for _ = 1, Constants.FOOD_SECONDS do
				if not teams:IsAlive(player) then
					break
				end
				combat:HealPlayer(player, per, nil)
				task.wait(1)
			end
		end)
	elseif item == "potion" and s.potions > 0 then
		s.potions -= 1
		lastUse[player] = t
		combat:HealPlayer(player, Constants.POTION_HEAL, nil)
		combat:Potion(player, Constants.POTION_SPEED, Constants.POTION_SPEED_SECONDS)
	else
		return false
	end
	teams:Push(player)
	Net.fireAll("Fx", "eat", { by = player.UserId, item = item, position = teams:Position(player) })
	Net.fire(player, "Sfx", "eat")
	self.Used:Fire(player, item)
	return true
end

function CraftService:Init(reg)
	match = reg.MatchService
	teams = reg.TeamService
	resources = reg.ResourceService
	build = reg.BuildService
	combat = reg.CombatService
	Net.on("Craft", function(player, item)
		if type(item) ~= "string" then
			return
		end
		local ok, why = self:Craft(player, item)
		if not ok and why then
			Net.fire(player, "Toast", why, "bad")
		end
	end)
	Net.on("Use", function(player, item)
		if type(item) == "string" then
			self:Use(player, item)
		end
	end)
end

function CraftService:OnPlayerLeaving(player)
	lastUse[player] = nil
end

return CraftService
