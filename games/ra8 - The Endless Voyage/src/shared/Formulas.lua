-- The game's maths in one place (so the tests can check them and the designers can read them).
local Constants = require(script.Parent.Constants)
local Pieces = require(script.Parent.Data.Pieces)

local Formulas = {}

-- Level from total XP: level, XP into it, XP the next needs.
function Formulas.level(xp)
	xp = math.max(0, xp or 0)
	local level, need = 1, Constants.LEVEL_XP
	while xp >= need and level < 200 do
		xp -= need
		level += 1
		need = Constants.LEVEL_XP + Constants.LEVEL_XP_GROWTH * (level - 1)
	end
	return level, xp, need
end

function Formulas.xpForLevel(level)
	local total = 0
	for l = 1, level - 1 do
		total += Constants.LEVEL_XP + Constants.LEVEL_XP_GROWTH * (l - 1)
	end
	return total
end

-- What a raft is made of: { tiles, deck2, pieces = { [key] = n } } from a list of placed pieces.
function Formulas.raftSummary(placed)
	local s = { tiles = 0, deck2 = 0, pieces = {} }
	for _, p in placed do
		local def = Pieces.get(p.key)
		if def then
			if def.structural then
				s.tiles += 1
				if (p.level or 1) == 2 then
					s.deck2 += 1
				end
			end
			s.pieces[p.key] = (s.pieces[p.key] or 0) + 1
		end
	end
	return s
end

-- The raft's tier (master plan §5.4): the highest tier whose every need the raft meets, 1-6. `trophies` is the
-- profile's trophy set (tier 6 wants the Leviathan's tooth).
function Formulas.raftTier(summary, trophies)
	local tier = 1
	for _, t in Pieces.TIERS do
		if t.n > 1 then
			local ok = summary.tiles >= (t.tiles or 0) and summary.deck2 >= (t.deck2 or 0)
			for key, n in t.needs or {} do
				if (summary.pieces[key] or 0) < n then
					ok = false
				end
			end
			if t.any then
				local anyOk = false
				for key, n in t.any do
					if (summary.pieces[key] or 0) >= n then
						anyOk = true
					end
				end
				ok = ok and anyOk
			end
			if t.trophy and not (trophies and trophies[t.trophy]) then
				ok = false
			end
			if ok and tier == t.n - 1 then
				tier = t.n
			end
		end
	end
	return tier
end

-- The next tier's missing needs, for the raft panel: { { text, done }, ... } or nil at the top.
function Formulas.tierNeeds(summary, tier, trophies)
	local t = Pieces.TIERS[tier + 1]
	if not t then
		return nil
	end
	-- each need in words a small kid gets: text ("a Workbench 🛠️"), todo (what's still missing: "3 more floors 🟫")
	local out = {}
	if t.tiles then
		local left = t.tiles - summary.tiles
		table.insert(out, {
			text = `{t.tiles} floors 🟫`,
			todo = left == 1 and "1 more floor 🟫" or `{left} more floors 🟫`,
			have = summary.tiles,
			need = t.tiles,
			done = summary.tiles >= t.tiles,
		})
	end
	if t.deck2 then
		local left = t.deck2 - summary.deck2
		table.insert(out, {
			text = `{t.deck2} floors upstairs 🪜`,
			todo = left == 1 and "1 more floor upstairs 🪜" or `{left} more floors upstairs 🪜`,
			have = summary.deck2,
			need = t.deck2,
			done = summary.deck2 >= t.deck2,
		})
	end
	for key, n in t.needs or {} do
		local def = Pieces.get(key)
		local have = summary.pieces[key] or 0
		local words = n > 1 and `{n} {def.name}es {def.icon}` or `a {def.name} {def.icon}`
		table.insert(out, {
			text = words,
			todo = n - have > 1 and `{n - have} more {def.name}es {def.icon}` or `a {def.name} {def.icon}`,
			have = have,
			need = n,
			done = have >= n,
		})
	end
	if t.any then
		local names, done = {}, false
		for key, n in t.any do
			local def = Pieces.get(key)
			table.insert(names, `a {def.name} {def.icon}`)
			if (summary.pieces[key] or 0) >= n then
				done = true
			end
		end
		table.sort(names)
		local words = table.concat(names, " or ")
		table.insert(out, { text = words, todo = words, have = done and 1 or 0, need = 1, done = done })
	end
	if t.trophy then
		local have = trophies and trophies[t.trophy] and 1 or 0
		table.insert(out, {
			text = "the Leviathan's tooth 🦷 on the trophy stand",
			todo = "the Leviathan's tooth 🦷 on the trophy stand",
			have = have,
			need = 1,
			done = have == 1,
		})
	end
	table.sort(out, function(a, b)
		return a.text < b.text
	end)
	return out, t
end

-- How fast the raft crosses the water: 1 paddling, +1 a sail, +2 an engine (the best of each counts once).
function Formulas.raftSpeed(summary)
	local speed = 1
	if (summary.pieces.sail or 0) > 0 then
		speed += 1
	end
	if (summary.pieces.engine or 0) > 0 then
		speed += 2
	end
	return speed
end

-- The lowest raft tier allowed into waters of a danger (Constants.DANGER_BY_TIER), or nil for none.
function Formulas.tierForDanger(danger)
	for tier, allowed in Constants.DANGER_BY_TIER do
		if allowed >= danger then
			return tier
		end
	end
	return nil
end

-- Seconds at sea to a destination.
function Formulas.voyageSeconds(distance, speed)
	return math.max(
		Constants.VOYAGE_MIN_SECONDS,
		math.floor(distance * Constants.VOYAGE_SECONDS_PER_DISTANCE / speed + 0.5)
	)
end

-- Inventory slots: the tier's cargo plus storage boxes.
function Formulas.cargo(tier, summary)
	return (Constants.CARGO_BY_TIER[tier] or 16) + 8 * (summary.pieces.storage or 0)
end

-- How much a storm hits a tile: railings, walls, a roof and an anchor each take some off.
function Formulas.stormDamage(base, protect, anchors)
	local mult = 1 / (1 + 0.25 * protect)
	if anchors > 0 then
		mult *= 0.5
	end
	return math.max(4, math.floor(base * mult + 0.5))
end

-- Creatures get a little tougher in dangerous waters.
function Formulas.creatureHp(base, danger)
	return math.floor(base * (1 + 0.12 * ((danger or 1) - 1)) + 0.5)
end

function Formulas.creatureDamage(base, danger)
	return math.floor(base * (1 + 0.1 * ((danger or 1) - 1)) + 0.5)
end

-- Loot odds: the rarity a container rolls, shifted by the waters' danger and the player's luck.
function Formulas.pickRarity(rng, danger, luck)
	local roll = rng:NextNumber() - 0.04 * ((danger or 1) - 1) - 0.06 * (luck or 0)
	if roll < 0.02 then
		return "legendary"
	elseif roll < 0.1 then
		return "epic"
	elseif roll < 0.3 then
		return "rare"
	elseif roll < 0.62 then
		return "uncommon"
	end
	return "common"
end

-- The fish a bite brings up: by rarity, the waters, the time; `rareBonus` from the rod and the tea.
function Formulas.pickFish(rng, list, waters, night, rareBonus)
	local weights = { common = 60, uncommon = 26, rare = 9, epic = 3, legendary = 1 }
	local pool, total = {}, 0
	for _, f in list do
		if (not f.where or f.where == waters) and (not f.night or night) then
			local w = weights[f.rarity] or 1
			if f.rarity ~= "common" then
				w *= 1 + (rareBonus or 0)
			end
			table.insert(pool, { f, w })
			total += w
		end
	end
	local r = rng:NextNumber() * total
	for _, e in pool do
		r -= e[2]
		if r <= 0 then
			return e[1]
		end
	end
	return pool[#pool] and pool[#pool][1] or list[1]
end

-- The clock: the day runs 6:00 -> 18:00 over DAY_SECONDS, the night 18:00 -> 6:00 over NIGHT_SECONDS.
function Formulas.clockTime(phase, t)
	if phase == "night" then
		return (18 + 12 * math.clamp(t / Constants.NIGHT_SECONDS, 0, 1)) % 24
	end
	return 6 + 12 * math.clamp(t / Constants.DAY_SECONDS, 0, 1)
end

-- A tile's place in the world from its grid coordinates (and back): the grid is centred on the plot.
function Formulas.tilePosition(center, gx, gz, level)
	local T = Constants.TILE
	return Vector3.new(
		center.X + (gx - (Constants.GRID - 1) / 2) * T,
		Constants.DECK_Y + ((level or 1) - 1) * Constants.DECK_HEIGHT,
		center.Z + (gz - (Constants.GRID - 1) / 2) * T
	)
end

-- How far a raft reaches from its centre along a flat direction: to the outer edge of its farthest first-deck tile
-- that way (studs). pieces: the server's pieces or the client's raft view (anything with key, gx, gz, level).
function Formulas.raftReach(center, pieces, dir)
	local far = Constants.TILE / 2
	for _, p in pieces do
		local def = Pieces.get(p.key)
		if def and def.structural and (p.level or 1) == 1 then
			local pos = Formulas.tilePosition(center, p.gx, p.gz, 1)
			local along = (pos.X - center.X) * dir.X + (pos.Z - center.Z) * dir.Z
			far = math.max(far, along + Constants.TILE / 2)
		end
	end
	return far
end

function Formulas.tileAt(center, position)
	local T = Constants.TILE
	local gx = math.floor((position.X - center.X) / T + (Constants.GRID - 1) / 2 + 0.5)
	local gz = math.floor((position.Z - center.Z) / T + (Constants.GRID - 1) / 2 + 0.5)
	local level = position.Y >= Constants.DECK_Y + Constants.DECK_HEIGHT - 2 and 2 or 1
	return gx, gz, level
end

-- The number the dashboard and the boards show for a raft.
function Formulas.raftScore(summary, tier)
	return tier * 1000 + summary.tiles * 10 + summary.deck2 * 5
end

-- What the raft still needs to grow up, in one short sentence: "a Workbench 🛠️ and a Storage Box 📦" (nil at the top).
function Formulas.growText(needs)
	if not needs then
		return nil
	end
	local left = {}
	for _, n in needs do
		if not n.done then
			table.insert(left, n.todo or n.text)
		end
	end
	if #left == 0 then
		return nil
	elseif #left == 1 then
		return left[1]
	end
	return table.concat(left, ", ", 1, #left - 1) .. " and " .. left[#left]
end

-- Why a piece is locked, like you'd tell a small kid. `raft` has tier, needs (the raft view's) and nextTier.
function Formulas.lockedText(def, raft)
	local tier = raft.tier or 1
	local grow = Formulas.growText(raft.needs)
	if def.tier == tier + 1 and grow then
		return `🔒 Not yet! Build {grow} and your raft grows into a {raft.nextTier or "bigger raft"}. Then you can build this.`
	end
	local nextT = Pieces.TIERS[def.tier]
	return `🔒 Not yet! Your raft has to grow into a {nextT and nextT.name or "bigger raft"} first.`
		.. (grow and ` Start with {grow}.` or "")
end

-- The raft is full, in kid words.
function Formulas.fullText(raft)
	local grow = Formulas.growText(raft.needs)
	local nextMax = Constants.MAX_TILES_BY_TIER[(raft.tier or 1) + 1]
	if not grow or not nextMax then
		return "🟫 Your raft is as big as a raft can be!"
	end
	return `🟫 Your raft is full! Build {grow} and it grows into a {raft.nextTier or "bigger raft"} with room for {nextMax} floors.`
end

-- Can a bag pay a cost? (slots: { key, n } lists, a view's or the server's)
function Formulas.affordable(cost, slots)
	for item, n in cost or {} do
		local have = 0
		for _, s in slots or {} do
			if s.key == item then
				have += s.n
			end
		end
		if have < n then
			return false
		end
	end
	return true
end

-- The piece QUICK builds: the first of the raft's recommendations (RaftService.Recommend, in the raft view) the
-- bag can pay for right now; nil if it can't pay for any (QUICK never offers what you can't build).
function Formulas.recommended(raftView, invView)
	local list = raftView and raftView.recommend
	if type(list) ~= "table" or #list == 0 then
		return nil
	end
	local slots = invView and invView.slots or {}
	for _, r in list do
		local def = Pieces.get(r.key)
		if def and Formulas.affordable(def.cost, slots) then
			return r
		end
	end
	return nil
end

return Formulas
