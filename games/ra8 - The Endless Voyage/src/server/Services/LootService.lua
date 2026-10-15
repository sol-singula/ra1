--[[
What's inside things (master plan §7.3: rarity, surprise; §9: blueprints, charts, artifacts). Supply crates that
drift by, the containers, lockers and chests on islands and wrecks, bottles with a note: every roll is made the
moment it's opened, for the player opening it (so a blueprint is always one they don't know yet), shifted by the
waters' danger and their luck (Formulas.pickRarity).

  LootService:OpenCrate(player, data)        a supply crate in the bag: resources, often a chart or a blueprint
  LootService:Container(player, dest, kind)  what a container holds: the island's resources, its finds, a chance
                                             of a chart, an artifact or a blueprint
  LootService:Bottle(player)                 a bottle's note: a chart to a place you don't know
  LootService:Blueprint(player, danger)      a blueprint the player can still learn, or nil
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Net = require(ReplicatedStorage.Shared.Net)
local Pieces = require(ReplicatedStorage.Shared.Data.Pieces)
local Recipes = require(ReplicatedStorage.Shared.Data.Recipes)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Voyages = require(ReplicatedStorage.Shared.Data.Voyages)

local LootService = {
	Name = "LootService",
	Dependencies = { "PlayerDataService", "InventoryService" },
	Opened = Signal.new("LootService.Opened"), -- (player, kind, items)
}

local data, inventory, registry
local rng = Random.new()

-- Blueprints by the danger of the waters they turn up in.
local BLUEPRINT_DANGER = {
	net = 1,
	engine = 2,
	long_hook = 2,
	harpoon = 3,
	salvage_net = 3,
	harpoon_turret = 4,
	salvage_claw = 4,
	leviathan_harpoon = 5,
}

local NOTES = {
	"The wolves come in threes. Keep the ice at your back.",
	"We saw the shadow again today. It's bigger than the ship.",
	"If you find this, the beacon on Gull Rock still works.",
	"Three lanterns. Light them all and the hollow gives up its secret.",
	"The totems face the wrong way. Turn them to the sea.",
	"Whatever you do, don't anchor in the Trench.",
}

local function pick(list)
	return list[rng:NextInteger(1, #list)]
end

-- A blueprint the player doesn't know yet, from these waters (or any below), as item data; nil when none is left.
function LootService:Blueprint(player, danger)
	local profile = data:Get(player)
	if not profile then
		return nil
	end
	local pool = {}
	for key, d in BLUEPRINT_DANGER do
		if d <= (danger or 1) + 1 and not profile.blueprints[key] then
			local kind = Pieces.get(key) and "piece" or "recipe"
			if kind == "recipe" and not Recipes.get(key) then
				continue
			end
			table.insert(pool, { kind = kind, key = key, danger = d })
		end
	end
	if #pool == 0 then
		return nil
	end
	table.sort(pool, function(a, b)
		if a.danger ~= b.danger then
			return a.danger < b.danger
		end
		return a.key < b.key
	end)
	-- the easiest ones first, with a little chance of a reach
	local i = rng:NextNumber() < 0.7 and 1 or rng:NextInteger(1, #pool)
	return { kind = pool[i].kind, key = pool[i].key }
end

-- A chart to a destination the player doesn't know, found this way ("crate" | "bottle" | "nest"), or nil.
function LootService:Chart(player, how, maxDanger)
	local voyages = registry.VoyageService
	local dest = voyages and voyages:UnknownDestination(player, how, maxDanger)
	return dest and { dest = dest } or nil
end

local function give(player, key, n, source, dataField)
	local fitted = inventory:Give(player, key, n, source, { data = dataField })
	return { key = key, n = n, data = dataField, fitted = fitted }
end

-- The supply crate (in your bag: Use it on the raft). Always worth opening: a handful of resources, often a
-- chart, and the first few always a blueprint.
function LootService:OpenCrate(player, crate)
	crate = type(crate) == "table" and crate or {}
	local danger = tonumber(crate.danger) or 1
	local luck = registry.PlayerService:Luck(player)
	local items = {}
	table.insert(items, give(player, "wood", rng:NextInteger(3, 6), "crate"))
	table.insert(items, give(player, "rope", rng:NextInteger(2, 4), "crate"))
	local extra = pick({ "cloth", "scrap", "metal", "cloth", "metal" })
	table.insert(items, give(player, extra, rng:NextInteger(2, 3), "crate"))
	local rarity = Formulas.pickRarity(rng, danger, luck)
	if crate.guide then
		-- the guide's crate: the Surface Net's blueprint and a rod (§4: 2:30)
		table.insert(items, give(player, "blueprint", 1, "crate", { kind = "piece", key = "net" }))
		table.insert(items, give(player, "fishing_rod", 1, "crate"))
	else
		local bp = (rarity ~= "common" or rng:NextNumber() < 0.35) and self:Blueprint(player, danger) or nil
		if bp then
			table.insert(items, give(player, "blueprint", 1, "crate", bp))
		elseif rarity == "rare" or rarity == "epic" or rarity == "legendary" then
			table.insert(items, give(player, pick({ "pearl", "gear", "glass" }), 1, "crate"))
		end
		local chart = rng:NextNumber() < 0.45 and self:Chart(player, "crate", danger + 1) or nil
		if chart then
			table.insert(items, give(player, "chart", 1, "crate", chart))
		elseif rng:NextNumber() < 0.4 then
			table.insert(items, give(player, pick({ "coconut", "berries", "cooked_fish" }), 2, "crate"))
		end
	end
	local root = registry.PlayerService:Root(player)
	Net.fire(player, "Fx", "loot", { pos = root and root.Position or nil, items = items })
	Net.fire(player, "Sfx", "open")
	local names = {}
	for _, it in items do
		local item = Items.get(it.key)
		table.insert(names, `{item.icon} {it.n > 1 and (it.n .. " ") or ""}{item.name}`)
	end
	Net.fire(player, "Toast", "📦 " .. table.concat(names, ", "), "good")
	self.Opened:Fire(player, "crate", items)
	return items
end

-- A container on an island or a wreck: the destination's resources and finds.
function LootService:Container(player, destKey, kind)
	local dest = Voyages.get(destKey)
	if not dest then
		return {}
	end
	local luck = registry.PlayerService:Luck(player)
	local items = {}
	local resources = #dest.resources > 0 and dest.resources or { "scrap", "rope", "cloth" }
	for _ = 1, 2 do
		local r = pick(resources)
		local item = Items.get(r)
		if item and item.kind == "resource" then
			table.insert(items, give(player, r, rng:NextInteger(2, 4), "container"))
		elseif item then
			table.insert(items, give(player, r, 1, "container"))
		end
	end
	local rarity = Formulas.pickRarity(rng, dest.danger, luck)
	if kind == "chest" then
		-- a puzzle's reward: a blueprint if there is one, else something rare
		local bp = self:Blueprint(player, dest.danger)
		if bp then
			table.insert(items, give(player, "blueprint", 1, "container", bp))
		else
			table.insert(items, give(player, pick({ "pearl", "gear", "old_tech" }), 2, "container"))
		end
		rarity = "epic"
	end
	local finds = dest.finds or {}
	if #finds > 0 and (rarity ~= "common" or kind == "locker") then
		local f = pick(finds)
		if f == "blueprint" then
			local bp = self:Blueprint(player, dest.danger)
			if bp then
				table.insert(items, give(player, "blueprint", 1, "container", bp))
			end
		elseif f == "chart" then
			local chart = self:Chart(player, "crate", dest.danger + 1)
			if chart then
				table.insert(items, give(player, "chart", 1, "container", chart))
			end
		elseif Items.get(f) then
			table.insert(items, give(player, f, 1, "container"))
		end
	end
	if rarity == "legendary" and dest.danger >= 3 then
		table.insert(items, give(player, "pearl", 1, "container"))
	end
	local root = registry.PlayerService:Root(player)
	Net.fire(player, "Fx", "loot", { pos = root and root.Position or nil, items = items })
	Net.fire(player, "Sfx", "open")
	self.Opened:Fire(player, kind or "container", items)
	return items
end

-- A bottle's note: a chart to a place you don't know (the Frost Shelf is only ever found this way).
function LootService:BottleData(player)
	local voyages = registry.VoyageService
	local dest = voyages and voyages:UnknownDestination(player, "bottle")
	return { dest = dest, note = pick(NOTES) }
end

function LootService:Init(reg)
	registry = reg
	data = reg.PlayerDataService
	inventory = reg.InventoryService
end

-- (tests)
LootService.BLUEPRINT_DANGER = BLUEPRINT_DANGER
return LootService
