--[[
Where things come from, as steps for where you are right now. "For Palm Fronds: 1 Build a Helm. 2 Open the MAP and
SAIL to Palm Key. 3 Craft an Axe at the Workbench (3 wood, 2 metal). 4 Chop the palms. 5 LEAVE ISLAND to keep them."

  Sources.steps(key, ctx) -> { "step", ... }   (empty when there's nothing to say)
  ctx = {
    have = function(key) -> n,            what you're carrying
    known = { [destKey] = true },         charts you have
    blueprints = { [key] = true },
    pieces = { [pieceKey] = true },       working pieces on your raft
    tier = n,                             your raft's tier
    voyage = { state, dest },             docked | sailing | island | home, and where
  }
Pure data and logic (shared): the crafting panel, the bag and the tests all use it.
]]
local Constants = require(script.Parent.Constants)
local Items = require(script.Parent.Data.Items)
local Pieces = require(script.Parent.Data.Pieces)
local Recipes = require(script.Parent.Data.Recipes)
local Voyages = require(script.Parent.Data.Voyages)

local Sources = {}

-- What floats past the raft (OceanService's debris kinds).
Sources.DRIFT = { wood = true, scrap = true, rope = true, cloth = true, metal = true }

-- What you do on an island to get it, and the tool it takes (an item key), from IslandBuilder's nodes.
Sources.ISLAND = {
	wood = { "chop the trees 🌳", "axe" },
	palm = { "chop the palm trees 🌴", "axe" },
	coconut = { "chop the palm trees 🌴 (coconuts fall out)", "axe" },
	stone = { "mine the grey rocks 🪨", "pickaxe" },
	ore = { "mine the rocks with orange streaks", "pickaxe" },
	heat_crystal = { "mine the glowing red crystals", "pickaxe" },
	frost_crystal = { "mine the glowing blue crystals", "pickaxe" },
	scrap = { "pry open the salvage piles", "crowbar" },
	metal = { "pry open the salvage piles", "crowbar" },
	gear = { "pry open the salvage piles (a gear now and then)", "crowbar" },
	fiber = { "pick the bushes and reeds (no tool needed)" },
	berries = { "pick the bushes (no tool needed)" },
	old_tech = { "search the old machines and lockers" },
}

-- Things that come from somewhere else entirely.
Sources.OTHER = {
	raw_fish = "Hold your rod 🎣, cast at open water (not at debris) and tap REEL when it bites",
	pearl = "Search the lockers on wrecks and the supply crates that drift by 📦 (sharks drop them too)",
	coral = "Search the chests and supply crates 📦",
	supply_crate = "Supply crates drift past with a beacon on them: cast at one 🎣",
	bottle = "Bottles drift past now and then: cast at one 🎣",
}

local function name(key)
	local it = Items.get(key)
	return it and `{it.name} {it.icon or ""}` or key
end

local function an(word)
	return string.find(string.lower(word), "^[aeiou]") and "an" or "a"
end

local function costText(cost)
	local parts = {}
	for k, n in cost or {} do
		local it = Items.get(k)
		table.insert(parts, `{n} {it and string.lower(it.name) or k}`)
	end
	table.sort(parts)
	return table.concat(parts, ", ")
end

local function recipeFor(key)
	for _, r in Recipes.list do
		if r.item == key then
			return r
		end
	end
	return nil
end

-- The steps to have a station (a piece on the raft) to craft at.
local function stationSteps(station, ctx, out)
	if ctx.pieces and ctx.pieces[station] then
		return
	end
	local s = Recipes.STATIONS[station]
	local def = Pieces.get(station)
	local label = s and `{s.name} {s.icon}` or station
	if def and def.blueprint and not (ctx.blueprints and ctx.blueprints[station]) then
		table.insert(out, `Find the {label} blueprint 📜 (supply crates, islands, or research)`)
	end
	table.insert(out, `Build a {label} on your raft (BUILD menu{def and def.cost and `: {costText(def.cost)}` or ""})`)
end

-- The steps to hold a tool (craft it if you don't have one).
local function toolSteps(tool, ctx, out)
	if not tool or (ctx.have and ctx.have(tool) > 0) then
		if tool then
			table.insert(out, `Hold your {name(tool)}`)
		end
		return
	end
	local r = recipeFor(tool)
	if r then
		stationSteps(r.station, ctx, out)
		local s = Recipes.STATIONS[r.station]
		table.insert(
			out,
			`Craft {an(name(tool))} {name(tool)} at the {s and s.name or r.station} ({costText(r.cost)}), and hold it`
		)
	end
end

-- The best place for it: where you are, else a known place you can sail to, else a known one, else any.
local function bestIsland(key, ctx)
	local allowed = Constants.DANGER_BY_TIER[ctx.tier or 1] or 1
	local here = ctx.voyage and ctx.voyage.state == "island" and ctx.voyage.dest
	local best, bestScore
	for _, d in Voyages.list do
		if table.find(d.resources or {}, key) then
			local known = d.known or (ctx.known and ctx.known[d.key])
			local score = (d.key == here and 1000 or 0)
				+ (known and 100 or 0)
				+ (d.danger <= allowed and 50 or 0)
				- d.distance
			if not bestScore or score > bestScore then
				best, bestScore = d, score
			end
		end
	end
	return best
end

-- The steps to get to an island.
local function sailSteps(d, ctx, out)
	local v = ctx.voyage or { state = "docked" }
	if v.state == "island" and v.dest == d.key then
		return true
	end
	if not (d.known or (ctx.known and ctx.known[d.key])) then
		local how = {
			crate = "open supply crates 📦 that drift by",
			bottle = "read messages in bottles 🍾",
			nest = "build a Crow's Nest and look out",
			guide = "look at the campfire on Palm Key",
			logbook = "read the captain's logbook on a wreck",
			idol = "find the carved idol",
		}
		table.insert(out, `Find the chart to {d.name}: {how[d.found] or "keep exploring"}`)
	end
	if v.state == "island" then
		table.insert(out, "Open the MAP 🗺️ and tap LEAVE ISLAND (you keep what you found)")
	elseif v.state == "sailing" or v.state == "home" then
		table.insert(out, "Wait for this trip to end")
	end
	if not (ctx.pieces and ctx.pieces.helm) then
		local helm = Pieces.get("helm")
		table.insert(out, `Build a Helm ☸️ (BUILD menu{helm and helm.cost and `: {costText(helm.cost)}` or ""})`)
	end
	local allowed = Constants.DANGER_BY_TIER[ctx.tier or 1] or 1
	if d.danger > allowed then
		local need = table.find(Constants.DANGER_BY_TIER, d.danger) or 6
		local t = Pieces.TIERS[need]
		table.insert(out, `Grow your raft to a {t and t.name or ("tier " .. need)} (tap RAFT to see what it needs)`)
	end
	if d.distance > 2 and not (ctx.pieces and ctx.pieces.nav_table) then
		table.insert(out, "Build a Navigation Table 🧭 (it's how you reach the far places)")
	end
	table.insert(out, `Open the MAP 🗺️ and tap SAIL for {d.name} {d.icon or ""}`)
	return true
end

function Sources.steps(key, ctx, depth)
	ctx = ctx or {}
	depth = depth or 0
	local out = {}
	if Sources.OTHER[key] then
		table.insert(out, Sources.OTHER[key])
		return out
	end
	local r = recipeFor(key)
	-- floats by: the rod first (the quickest way), then the other ways
	if Sources.DRIFT[key] then
		if ctx.have and (ctx.have("fishing_rod") + ctx.have("iron_rod") + ctx.have("deep_rod")) == 0 then
			table.insert(out, "Craft a Fishing Rod at the Workbench (3 wood, 2 rope)")
		end
		table.insert(out, `Hold your rod 🎣 and cast at the {name(key)} floating past your raft (aim, tap ACT)`)
		table.insert(out, "Build a Surface Net beside the raft: it catches for you")
		if r and depth == 0 and ctx.pieces and ctx.pieces[r.station] then
			local s = Recipes.STATIONS[r.station]
			table.insert(out, `Or make it at the {s.name}: {costText(r.cost)}`)
		end
		return out
	end
	-- from an island (unless it's made at a station and you're not on that island now)
	local node = Sources.ISLAND[key]
	local d = node and bestIsland(key, ctx)
	local onIt = d and ctx.voyage and ctx.voyage.state == "island" and ctx.voyage.dest == d.key
	if d and (not r or onIt) then
		if sailSteps(d, ctx, out) then
			toolSteps(node[2], ctx, out)
			table.insert(out, `On {d.name}, {node[1]}`)
			table.insert(out, "Then LEAVE ISLAND on the MAP and finish the trip home to keep it")
		end
		return out
	end
	-- crafted
	if r then
		local def = Items.get(key)
		if r.blueprint or (def and def.blueprint) then
			if not (ctx.blueprints and ctx.blueprints[key]) then
				table.insert(out, "Find its blueprint 📜 (supply crates, islands, or research)")
			end
		end
		stationSteps(r.station, ctx, out)
		local s = Recipes.STATIONS[r.station]
		table.insert(out, `Craft it at the {s and s.name or r.station}: {costText(r.cost)}`)
		if d then
			table.insert(out, `Or find it on {d.name}: {node[1]}`)
		end
		if depth < 1 then
			for k, n in r.cost do
				if not ctx.have or ctx.have(k) < n then
					local sub = Sources.steps(k, ctx, depth + 1)
					if #sub > 0 then
						table.insert(out, `You need more {name(k)}:`)
						for _, line in sub do
							table.insert(out, "   • " .. line)
						end
					end
				end
			end
		end
		return out
	end
	return out
end

return Sources
