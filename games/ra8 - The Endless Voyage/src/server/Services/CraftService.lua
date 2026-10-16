--[[
The stations (master plan §8): stand at one and craft what it makes (Data/Recipes), paying from your bag. The
Research Station turns artifacts into research points, and each milestone (Data/Progression.RESEARCH) unlocks a
blueprint for good. The Decorative Workshop's recipes unlock dyes instead of making items.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Net = require(ReplicatedStorage.Shared.Net)
local Pieces = require(ReplicatedStorage.Shared.Data.Pieces)
local Progression = require(ReplicatedStorage.Shared.Data.Progression)
local Recipes = require(ReplicatedStorage.Shared.Data.Recipes)
local Signal = require(ReplicatedStorage.Shared.Signal)

local CraftService = {
	Name = "CraftService",
	Dependencies = { "PlayerDataService", "RaftService", "InventoryService", "PlayerService" },
	Crafted = Signal.new("CraftService.Crafted"), -- (player, recipe, piece)
	Researched = Signal.new("CraftService.Researched"), -- (player, item, points, total)
	Milestone = Signal.new("CraftService.Milestone"), -- (player, milestone)
}

local data, rafts, inventory, players, registry

-- Not at the station something needs: point the way. With one on the raft they're on (or their own), the guide's
-- arrow goes to it and it glows, and its panel opens when they get there ("Point"); with none yet, say how to get
-- one (it's in BUILD under STATIONS, or it comes with a bigger raft).
function CraftService:ShowStation(player, station, why)
	local info = Recipes.STATIONS[station] or { name = station, icon = "🛠️" }
	local found, onRaft
	for _, raft in { rafts:Aboard(player), rafts:RaftOf(player) } do
		for _, p in raft and raft.pieces or {} do
			if p.def.station == station then
				found, onRaft = p, raft
				break
			end
		end
		if found then
			break
		end
	end
	if found then
		local pos = rafts:PiecePosition(onRaft, found)
		Net.fire(player, "Point", {
			pos = pos,
			piece = found.id,
			title = `{info.icon} {string.upper(info.name)}`,
			text = found.broken and `Your {info.name} is broken: fix it with the hammer, then {why}.`
				or `{why}: walk to your {info.name} (follow the arrow).`,
			open = not found.broken and { "craft", station } or nil,
		})
		Net.fire(player, "Toast", `{info.icon} Go to your {info.name} to {why}.`, "info")
		return
	end
	local def
	for _, p in Pieces.list do
		if p.station == station then
			def = p
			break
		end
	end
	local own = rafts:RaftOf(player)
	local tier = own and rafts:Tier(own) or 1
	local text
	if def and def.tier and tier < def.tier then
		local t = Pieces.TIERS[def.tier]
		text =
			`{info.icon} To {why} you need a {info.name}. It unlocks when your raft becomes a {t and t.name or "bigger raft"}.`
	else
		text = `{info.icon} To {why} you need a {info.name} on your raft: build one (BUILD, then STATIONS).`
	end
	Net.fire(player, "Callout", text, "info")
end

-- Can the player make this now? ok, reason.
function CraftService:CanCraft(player, recipeId)
	local r = Recipes.get(recipeId)
	local profile = data:Get(player)
	if not r or not profile then
		return false, "Unknown recipe."
	end
	local station = rafts:StationNear(player)
	if station ~= r.station then
		return false, `Stand at the {Recipes.STATIONS[r.station].name}.`
	end
	if r.blueprint and not profile.blueprints[r.id] then
		return false, "You need its blueprint first."
	end
	if r.unlock then
		local owned = r.unlock.kind == "color" and profile.colours.owned[r.unlock.key]
			or r.unlock.kind == "deck" and profile.colours.decks[r.unlock.key]
		if owned then
			return false, "You already have that."
		end
	end
	for item, n in r.cost do
		if not inventory:Has(player, item, n) then
			local it = Items.get(item)
			return false, `Needs {n} {it and it.name or item} (you have {inventory:Count(player, item)}).`
		end
	end
	return true
end

function CraftService:Craft(player, recipeId)
	if not players:IsAlive(player) then
		return false
	end
	local ok, reason = self:CanCraft(player, recipeId)
	if not ok then
		local r = Recipes.get(recipeId)
		if r and rafts:StationNear(player) ~= r.station then
			self:ShowStation(player, r.station, "make it")
		else
			Net.fire(player, "Toast", reason, "bad")
		end
		return false, reason
	end
	local r = Recipes.get(recipeId)
	local profile = data:Get(player)
	for item, n in r.cost do
		inventory:Take(player, item, n)
	end
	local _, piece = rafts:StationNear(player)
	local raft = rafts:Aboard(player)
	local pos = piece and raft and rafts:PiecePosition(raft, piece) or players:Position(player)
	local label
	if r.unlock then
		if r.unlock.kind == "color" then
			profile.colours.owned[r.unlock.key] = true
			label = `🎨 {r.name} unlocked: paint your sails, banners and flags.`
		else
			profile.colours.decks[r.unlock.key] = true
			label = `🎨 {r.name} unlocked: paint your deck.`
		end
		Net.fire(player, "Unlock", { kind = "colour", key = r.unlock.key, name = r.name, icon = r.icon })
	else
		inventory:Give(player, r.item, r.count, "craft")
		local item = Items.get(r.item)
		label = `{item.icon} {r.count > 1 and (r.count .. " ") or ""}{item.name}`
	end
	profile.stats.crafted += 1
	Net.fire(player, "Popup", (pos or Vector3.zero) + Vector3.new(0, 4, 0), label, Color3.fromRGB(255, 230, 120))
	Net.fire(player, "Sfx", "craft", pos)
	if raft then
		rafts:Fx(raft, "craft", { pos = pos })
	end
	registry.ProgressService:Push(player)
	self.Crafted:Fire(player, r, piece)
	return true
end

-- Feed an artifact to the Research Station.
function CraftService:Research(player, slotId)
	local profile = data:Get(player)
	local slot, item = inventory:Slot(player, slotId)
	if not profile or not slot or not item then
		return false
	end
	if not item.research then
		Net.fire(player, "Toast", "Only artifacts can be researched.", "bad")
		return false
	end
	if rafts:StationNear(player) ~= "research" then
		self:ShowStation(player, "research", "research it")
		return false
	end
	local points = Constants.RESEARCH_PER_ARTIFACT[item.research] or 10
	inventory:Consume(player, slotId, 1)
	local research = profile.research
	research.points += points
	profile.stats.research += points
	local pos = players:Position(player) or Vector3.zero
	Net.fire(player, "Popup", pos + Vector3.new(0, 4, 0), `📚 +{points} research`, Color3.fromRGB(150, 200, 255))
	Net.fire(player, "Sfx", "craft")
	self.Researched:Fire(player, item, points, research.points)
	for i, m in Progression.RESEARCH do
		local key = tostring(i)
		if research.points >= m.points and not research.claimed[key] then
			research.claimed[key] = true
			registry.ProgressService:LearnBlueprint(player, m.unlock.kind, m.unlock.key, "research")
			self.Milestone:Fire(player, m)
		end
	end
	registry.ProgressService:Push(player)
	return true
end

function CraftService:Init(reg)
	registry = reg
	data = reg.PlayerDataService
	rafts = reg.RaftService
	inventory = reg.InventoryService
	players = reg.PlayerService
	Net.on("Craft", function(player, recipeId)
		if type(recipeId) == "string" then
			self:Craft(player, recipeId)
		end
	end)
	Net.on("Research", function(player, slotId)
		if inventory.validSlot(player, slotId) then
			self:Research(player, slotId)
		end
	end)
end

return CraftService
