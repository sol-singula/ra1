--[[
Crafting (master plan §3 "collect & craft", §7): the camp's stations make tools, weapons, armor, medicine and food
from materials. Using a station's prompt opens the crafting panel on the client; the server checks you're at a
built station of the right kind, that the camp's tier allows the recipe, and that you (or the camp's chest) have
the materials, then takes them and gives you the item.
]]
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Camp = require(ReplicatedStorage.Shared.Data.Camp)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Net = require(ReplicatedStorage.Shared.Net)
local Recipes = require(ReplicatedStorage.Shared.Data.Recipes)
local Signal = require(ReplicatedStorage.Shared.Signal)

local CraftService = {
	Name = "CraftService",
	Dependencies = { "PlayerDataService", "RunService", "InventoryService", "SurvivorService", "CampService" },
	Crafted = Signal.new("CraftService.Crafted"), -- (player, recipe)
	Opened = Signal.new("CraftService.Opened"), -- (player, station)
}

local runs, inventory, survivors, camp

function CraftService:CanCraft(player, recipe)
	if not recipe then
		return false, "Unknown recipe."
	end
	if not runs:InRun(player) or not survivors:IsAlive(player) then
		return false, "You can't craft right now."
	end
	if camp:Tier() < recipe.tier then
		return false, `Needs the camp at {Camp.TIERS[recipe.tier].name}.`
	end
	if not camp:StationNear(survivors:Position(player), recipe.station) then
		return false, `Go to the {Recipes.STATIONS[recipe.station].name}.`
	end
	for key, n in recipe.cost do
		if camp:Available(player, key) < n then
			return false, `Not enough {Items.get(key).name}.`
		end
	end
	return true
end

function CraftService:Craft(player, id)
	local recipe = Recipes.get(tonumber(id) or -1)
	local ok, why = self:CanCraft(player, recipe)
	if not ok then
		Net.fire(player, "Toast", why, "bad")
		return false
	end
	camp:Pay(player, recipe.cost)
	inventory:Give(player, recipe.item, recipe.count, "craft")
	local item = Items.get(recipe.item)
	Net.fire(player, "Toast", `{item.icon} Made {recipe.count > 1 and (recipe.count .. " ") or ""}{item.name}!`, "good")
	Net.fire(player, "Sfx", "craft")
	self.Crafted:Fire(player, recipe)
	return true
end

function CraftService:Init(registry)
	runs = registry.RunService
	inventory = registry.InventoryService
	survivors = registry.SurvivorService
	camp = registry.CampService
	Net.on("Craft", function(player, id)
		self:Craft(player, id)
	end)
	-- using a station (or the campfire's Cook prompt) tells the client which panel to open
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		local station = prompt:GetAttribute("Station")
		local structureId = prompt:GetAttribute("Structure")
		if not station and structureId and prompt:GetAttribute("Action") == "Use" then
			local s = camp:Structure(structureId)
			station = s and Camp.STRUCTURES[s.key].station
		end
		if station then
			self.Opened:Fire(player, station)
			Net.fire(player, "Storage", camp:Storage())
			player:SetAttribute("Station", station)
			player:SetAttribute("StationAt", workspace:GetServerTimeNow())
		end
	end)
end

return CraftService
