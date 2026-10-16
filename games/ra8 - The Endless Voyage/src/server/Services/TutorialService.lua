--[[
The first five minutes (master plan §4): one clear thing to do at a time, an arrow to where it is, and the game
itself does the teaching. Returning players skip the steps they've done. There is no SKIP: when the steps end, the
guide keeps going with the NEXT thing to do, forever (Goal below), and it can't be dismissed:
  * at sea: reel in what streams past; on an island: explore, then sail home (and the anchor's clock)
  * hands empty: hold your rod (a HOLD MY ROD button on the card does it, from the bag too)
  * broken pieces: fix them with the hammer (everyone starts with one)
  * no helm yet: build one; then the raft's next piece (RaftService.Recommend): build it with QUICK if you can pay
    for it, else what's missing and where it comes from; when only comforts are left, a new place to sail to
And a player with no rod at all gets a spare one (the rod is the whole loop; your last one can't be dropped).

  1 cast     "Cast at the driftwood": six pieces float within reach the moment you arrive         0:00-0:20
  2 net      "Build a Surface Net next to your raft": a tile of its own that fills up by itself     0:20-0:40
  3 tile     "Build a Floor Tile": BUILD, pick it, tap a spot next to your raft                    0:40-1:00
  4 bench    "Build the Workbench"                                                                 1:00-1:40
  5 crate    a supply crate drifts in right beside the raft, with a beacon on it, and another one
             every few seconds until you have one: "Cast at it, then OPEN it in your bag"          1:40-2:20
             (inside: an axe, a spear and a pile of wood and rope: you're ready for the island)
  6 helm     "Build the Helm and set sail for Palm Key": the first real decision (go now, or build) 2:20-3:00
  7 island   "Land ho! Chop a palm, search the crate, look at the campfire"                        3:00-4:00
  8 home     "Sail home: what you found is safe at your dock"
Each first pays XP (Constants.XP.guide). Steps you've already done are skipped.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Net = require(ReplicatedStorage.Shared.Net)
local Pieces = require(ReplicatedStorage.Shared.Data.Pieces)
local Voyages = require(ReplicatedStorage.Shared.Data.Voyages)
local Signal = require(ReplicatedStorage.Shared.Signal)

local TutorialService = {
	Name = "TutorialService",
	Dependencies = {
		"PlayerDataService",
		"RaftService",
		"InventoryService",
		"PlayerService",
		"OceanService",
		"CraftService",
		"VoyageService",
		"IslandService",
	},
	StepShown = Signal.new("TutorialService.StepShown"), -- (player, step, total, key)
	StepDone = Signal.new("TutorialService.StepDone"), -- (player, step, key, seconds)
	Finished = Signal.new("TutorialService.Finished"), -- (player, skipped)
}

local data, rafts, inventory, players, ocean, voyages, island
local STEPS = { "cast", "net", "tile", "bench", "crate", "helm", "island", "home" }
TutorialService.STEPS = STEPS
local INDEX = {}
for i, k in STEPS do
	INDEX[k] = i
end
local TEXT = {
	cast = "Cast at the driftwood 🎣: aim at a piece, tap ACT, and it reels in",
	tile = "Build a Floor Tile 🟫: hold QUICK looking at the water beside your raft (or open BUILD and pick it)",
	bench = "Build the Workbench 🛠️ on a tile",
	crate = "A supply crate 📦 right next to you! Cast at the glowing one, then OPEN it from your bag",
	net = "Build a Surface Net 🕸️ next to your raft. It catches stuff that floats by, and you can watch it fill up!",
	helm = "Build the Helm ☸️ (a steering wheel with a little sail), then open the MAP and SAIL to Palm Key!",
	island = "Land ho! Chop a palm 🌴, search the crate 📦, and look at the campfire 🔥",
	home = "Leave the island ⛵: open the MAP and tap LEAVE ISLAND. Everything you found is yours to keep",
}
TutorialService.TEXT = TEXT
local active = {} -- [player] = { step, shownAt, hooked, startedAt, crate, crateAt }
local lastGoal = {} -- [player] = the goal view's signature last sent
local STEP_PIECE = { tile = "floor", bench = "workbench", net = "net", helm = "helm" }

local function now()
	return workspace:GetServerTimeNow()
end

function TutorialService:Active(player)
	return active[player]
end

-- The piece the guide's step asks for right now (QUICK builds it first), or nil.
function TutorialService:StepPiece(player)
	local a = active[player]
	return a and STEP_PIECE[STEPS[a.step]] or nil
end

-- Where a player is in the guide, for the analytics and the log: "3/8 tile", "done", or "-" before it starts.
function TutorialService:StepName(player)
	local a = active[player]
	if a then
		return `{a.step}/{#STEPS} {STEPS[a.step] or "?"}`
	end
	local profile = data and data:Get(player)
	return (profile and profile.tutorial and profile.tutorial.done) and "done" or "-"
end

-- The arrow's target for a step, and what to light up.
function TutorialService:Target(player, key)
	local raft = rafts:RaftOf(player)
	local a = active[player]
	if not raft then
		return nil
	end
	local pos = players:Position(player)
	if key == "cast" and pos then
		local best, bestD
		for _, d in ocean:Debris(raft.plot) do
			if not d.hooked and not d.special then
				local dist = (d.pos - pos).Magnitude
				if not bestD or dist < bestD then
					best, bestD = d, dist
				end
			end
		end
		return best and best.pos + Vector3.new(0, 1, 0) or nil, best and { debris = best.id } or nil
	elseif key == "tile" or (key == "net" and not (rafts:Has(raft, "net") or rafts:Has(raft, "salvage_net"))) then
		-- (a net is a tile of its own: it goes where a new floor would)
		local spot = rafts:FreeSpots(raft, 1)[1]
		return spot and rafts:TileWorld(raft, spot[1], spot[2], 1) + Vector3.new(0, 1, 0) or nil,
			spot and { spot = { gx = spot[1], gz = spot[2] } } or nil
	elseif key == "bench" or key == "helm" or key == "net" then
		local piece
		for _, p in raft.pieces do
			if p.key == (key == "bench" and "workbench" or key) then
				piece = p
			end
		end
		if piece then
			return rafts:PiecePosition(raft, piece) + Vector3.new(0, 2, 0), { piece = piece.id }
		end
		local tile = rafts:EmptyTiles(raft, 1)[1]
		return tile and rafts:PiecePosition(raft, tile) + Vector3.new(0, 1, 0) or nil,
			tile and { spot = { gx = tile.gx, gz = tile.gz } } or nil
	elseif key == "crate" then
		local d = a and a.crate and ocean:Get(a.crate)
		if d then
			return d.pos + Vector3.new(0, 1.5, 0), { debris = d.id }
		end
		return nil
	elseif key == "island" then
		local isl = island:Here(raft.plot)
		if isl and isl.landmark and not isl.looked[player] then
			return isl.landmark.pos + Vector3.new(0, 2, 0), { landmark = true }
		end
		for _, c in isl and isl.containers or {} do
			if not c.opened then
				return c.pos + Vector3.new(0, 1.5, 0), { container = c.id }
			end
		end
		return nil
	elseif key == "home" then
		for _, p in raft.pieces do
			if p.key == "helm" then
				return rafts:PiecePosition(raft, p) + Vector3.new(0, 2, 0), { piece = p.id }
			end
		end
	end
	return nil
end

-- The NEXT thing to do once the steps are over (and the rod's rescue during them) ------------------------------------
local function missing(player, cost)
	local out = {}
	for key, n in cost or {} do
		local have = inventory:Count(player, key)
		if have < n then
			local it = Items.get(key)
			table.insert(out, `{n - have} more {it and it.name or key} {it and it.icon or ""}`)
		end
	end
	table.sort(out)
	return out
end

local function pieceOf(raft, key)
	for _, p in raft.pieces do
		if p.key == key then
			return p
		end
	end
	return nil
end

-- Where the stuff for a cost comes from, in a few words.
local WHERE = {
	wood = "cast at the driftwood",
	rope = "cast at the driftwood and barrels",
	cloth = "cast at the barrels and crates",
	metal = "cast at the crates, or pry wrecks",
	scrap = "cast at the crates",
	plank = "make planks at the Workbench",
}

function TutorialService:Goal(player)
	local raft = rafts:RaftOf(player)
	local profile = data:Get(player)
	if not raft or not profile or not players:IsAlive(player) then
		return nil
	end
	local goal = { goal = true, title = "NEXT" }
	local v = voyages:Get(raft.plot)
	local held = select(2, inventory:Selected(player))
	local rods = inventory:CountKind(player, "rod")
	-- hands empty: the rod
	if not held and rods > 0 then
		goal.key, goal.action = "hold", "hold_rod"
		goal.text = "Hold your rod 🎣 so you can reel in what drifts by"
		return goal
	end
	if v.state == "sailing" or v.state == "home" then
		local d = v.dest
		goal.key, goal.title = "cast", "AT SEA"
		goal.text = v.state == "home" and "Leaving the island ⛵: reel in what streams past while you go 🎣"
			or `Sailing to {d and d.name or "the island"} {d and d.icon or ""}: reel in what streams past 🎣`
		return goal
	elseif v.state == "island" then
		local target, glow = self:Target(player, "island")
		goal.key, goal.title = "island", "ASHORE"
		goal.text = target and "Explore: chop palms 🌴, search the crates 📦, look at the landmark"
			or "Done here? Open the MAP 🗺️ and tap LEAVE ISLAND ⛵ (you keep everything you found)"
		if not target then
			local helm = pieceOf(raft, "helm")
			target = helm and rafts:PiecePosition(raft, helm) + Vector3.new(0, 2, 0)
			glow = helm and { piece = helm.id } or nil
			goal.key = "home"
		end
		goal.target = target
		for k, x in glow or {} do
			goal[k] = x
		end
		return goal
	end
	-- (no "show your raft to a friend" step: the guide sticks to what to do next; ModeService asks about friends at
	-- the few moments that are better with one)
	-- broken pieces: the hammer
	local broken
	for _, p in raft.pieces do
		if p.broken then
			broken = broken or p
		end
	end
	if broken and inventory:CountKind(player, "hammer") > 0 then
		goal.key = "repair"
		goal.text = "Something's broken 🔧: hold the Hammer 🔨 and tap it to fix it"
		goal.target, goal.piece = rafts:PiecePosition(raft, broken) + Vector3.new(0, 2, 0), broken.id
		return goal
	end
	-- the raft's next piece: the first thing it needs that you can pay for, else the first thing it needs (and what's
	-- missing for it); more floor just for room only when nothing is needed (the same rule as QUICK)
	local list = rafts:Recommend(raft)
	local rec, firstNeed
	for _, r in list do
		if not r.filler then
			firstNeed = firstNeed or r
			if #missing(player, Pieces.get(r.key).cost) == 0 then
				rec = r
				break
			end
		end
	end
	rec = rec or firstNeed or list[1]
	local filler = not rec or rec.filler == true or string.sub(rec.why or "", 1, 9) == "a comfort"
	if filler and not rafts:Has(raft, "helm") then
		local need = missing(player, Pieces.get("helm").cost)
		goal.key, goal.piece = "helm", nil
		goal.text = #need == 0 and "Build the Helm ☸️ (BUILD): it's how you sail to new places"
			or `For the Helm ☸️ you need {table.concat(need, ", ")}: cast at the debris 🎣`
		if #need > 0 then
			goal.key = "cast"
		end
		return goal
	end
	if filler and v.state == "docked" then
		for _, d in Voyages.list do
			if voyages:CanSail(player, d.key) and not (profile.visited and profile.visited[d.key]) then
				goal.key, goal.dest = "sail", d.key
				goal.text = `Set sail for {d.name} {d.icon}: open the MAP 🗺️ and tap SAIL`
				return goal
			end
		end
	end
	-- the next tier needs something you have no blueprint for: where blueprints come from
	local nextT = Pieces.TIERS[raft.tier + 1]
	if nextT and (not rec or filler or #missing(player, Pieces.get(rec.key).cost) > 0) then
		for key in nextT.needs or {} do
			local def = Pieces.get(key)
			if def.blueprint and not profile.blueprints[key] and not rafts:Has(raft, key) then
				goal.key = "cast"
				goal.text = rafts:Has(raft, "research")
						and `The {nextT.name} needs the {def.name} {def.icon}: research its blueprint 📜 at the Research Table`
					or `The {nextT.name} needs the {def.name} {def.icon}: find its blueprint 📜 in supply crates 📦 and on islands`
				return goal
			end
		end
	end
	if rec then
		local def = Pieces.get(rec.key)
		local need = missing(player, def.cost)
		if #need == 0 then
			goal.key, goal.quick = "quick", rec.key
			goal.text = `Build the {def.name} {def.icon} ({rec.why}): hold QUICK and look where it goes`
		else
			local first = next(def.cost)
			goal.key = "cast"
			goal.text = `For the {def.name} {def.icon} you need {table.concat(need, ", ")}`
				.. `: {WHERE[first] or "cast at the debris"} 🎣`
		end
		return goal
	end
	goal.key = "cast"
	goal.text = "Reel in what drifts by 🎣, and look for charts to new places"
	return goal
end

local function signature(view)
	if not view then
		return "none"
	end
	local t = view.target
	local at = typeof(t) == "Vector3" and `{math.floor(t.X)},{math.floor(t.Z)}` or ""
	return `{view.key}|{view.text}|{view.action or ""}|{at}`
end

function TutorialService:_goal(player)
	if active[player] then
		return
	end
	local view = self:Goal(player)
	local sig = signature(view)
	if lastGoal[player] ~= sig then
		lastGoal[player] = sig
		Net.fire(player, "Tutorial", view or false)
	end
end

-- No rod at all: a spare one (the rod is how you get everything).
function TutorialService:_rescueRod(player)
	if not players:IsAlive(player) or not rafts:RaftOf(player) then
		return
	end
	if inventory:CountKind(player, "rod") > 0 then
		return
	end
	inventory:Give(player, "fishing_rod", 1, "rescue")
	inventory:HoldKind(player, "rod")
	Net.fire(player, "Toast", "🎣 A spare Fishing Rod washed up on your raft. Keep it in your hotbar!", "good")
end

function TutorialService:View(player)
	local a = active[player]
	if not a then
		return false
	end
	local key = STEPS[a.step]
	local text = TEXT[key]
	if key == "cast" then
		text = `{text} ({math.min(a.hooked, Constants.GUIDE_DEBRIS)}/{Constants.GUIDE_DEBRIS})`
	end
	local target, glow = self:Target(player, key)
	local piece = STEP_PIECE[key]
	local profile = data:Get(player)
	local raft = rafts:RaftOf(player)
	if piece and raft and not (key == "helm" and rafts:Has(raft, "helm")) then
		local def = Pieces.get(piece)
		local paper
		for _, slot in inventory:Contents(player) do
			if slot.key == "blueprint" and slot.data and slot.data.key == piece then
				paper = slot
			end
		end
		if def.blueprint and profile and not profile.blueprints[piece] and paper then
			-- the blueprint's in the bag: read it
			return {
				step = a.step,
				total = #STEPS,
				key = key,
				learn = paper.id,
				text = `Read the {def.name}'s blueprint 📜: open your BAG, tap it, then LEARN`,
			}
		end
		if def.blueprint and profile and not profile.blueprints[piece] then
			-- no blueprint yet: get it first (the guide's crate brings the net's)
			local d = a.crate and ocean:Get(a.crate)
			text = `First get the {def.name}'s blueprint 📜: cast at the supply crate 📦, then OPEN it in your bag`
			if inventory:Count(player, "supply_crate") > 0 then
				text = `Open the supply crate 📦 in your BAG: the {def.name}'s blueprint 📜 is inside`
			end
			target, glow = d and d.pos + Vector3.new(0, 1.5, 0) or nil, d and { debris = d.id } or nil
			if not a.crate or not d then
				a.crateWanted = true
			end
			local view = { step = a.step, total = #STEPS, key = "crate", text = text, target = target, forStep = key }
			for k, v in glow or {} do
				view[k] = v
			end
			return view
		end
		local need = missing(player, def.cost)
		if #need > 0 then
			-- can't pay for it yet: what's missing, and the nearest debris to cast at
			local first = next(def.cost)
			text =
				`For the {def.name} {def.icon} you need {table.concat(need, ", ")}: {WHERE[first] or "cast at the debris"} 🎣`
			target, glow = self:Target(player, "cast")
			local view = { step = a.step, total = #STEPS, key = key, text = text, target = target, gather = true }
			for k, v in glow or {} do
				view[k] = v
			end
			return view
		end
	end
	local view = { step = a.step, total = #STEPS, key = key, text = text, target = target }
	if (key == "cast" or key == "crate") and not select(2, inventory:Selected(player)) then
		view.action = "hold_rod"
		view.text = "First, hold your rod 🎣: " .. text
	end
	for k, v in glow or {} do
		view[k] = v
	end
	return view
end

local function skip(player, a)
	local raft = rafts:RaftOf(player)
	local profile = data:Get(player)
	if not raft or not profile then
		return
	end
	local v = voyages:Get(raft.plot)
	while a.step <= #STEPS do
		local key = STEPS[a.step]
		local done = false
		if key == "tile" then
			done = raft.summary.tiles > Constants.MIN_TILES
		elseif key == "bench" then
			done = rafts:Has(raft, "workbench")
		elseif key == "crate" then
			done = a.crateOpened == true or profile.tutorial.crate == true
		elseif key == "net" then
			done = rafts:Has(raft, "net") or rafts:Has(raft, "salvage_net")
		elseif key == "helm" then
			done = v.state ~= "docked"
		elseif key == "island" then
			done = v.state == "home" or (a.looked == true)
		end
		if done then
			a.step += 1
		else
			break
		end
	end
end

function TutorialService:_show(player)
	local a = active[player]
	if not a then
		Net.fire(player, "Tutorial", false)
		return
	end
	skip(player, a)
	if a.step > #STEPS then
		self:Finish(player, false)
		return
	end
	a.shownAt = now()
	local profile = data:Get(player)
	if profile then
		profile.tutorial.step = a.step
	end
	Net.fire(player, "Tutorial", self:View(player))
	self.StepShown:Fire(player, a.step, #STEPS, STEPS[a.step])
end

function TutorialService:Advance(player, key)
	local a = active[player]
	if not a or STEPS[a.step] ~= key then
		return
	end
	self.StepDone:Fire(player, a.step, key, now() - (a.shownAt or now()))
	a.step += 1
	Net.fire(player, "Sfx", "notify")
	self:_show(player)
end

function TutorialService:Finish(player, skipped)
	if not active[player] then
		return
	end
	active[player] = nil
	local profile = data:Get(player)
	if profile then
		profile.tutorial.done = true
	end
	lastGoal[player] = nil
	self:_goal(player)
	if not skipped then
		Net.fire(player, "Toast", "⛵ You've got it. The ocean's yours: build, sail, find what's out there.", "good")
	end
	self.Finished:Fire(player, skipped)
end

function TutorialService:_refresh(player)
	local a = active[player]
	if a then
		Net.fire(player, "Tutorial", self:View(player))
	end
end

-- The guide's crate: right beside the raft, slow, with a beacon on it (and another one the moment it's gone,
-- until you've got one).
function TutorialService:_crate(player, a)
	local raft = rafts:RaftOf(player)
	if not raft then
		return
	end
	local d = ocean:Crate(raft.plot, 1, {
		guide = true,
		distance = Constants.GUIDE_CRATE_DISTANCE,
		spread = 2,
		lifetime = 60, -- (gone once it's past the raft: then the next one comes)
		speed = 0.35,
	})
	if d then
		local first = not a.crate
		a.crate = d.id
		a.crateAt = now()
		a.crateHooked = false
		Net.fire(
			player,
			"Callout",
			first and "📦 A supply crate! It's the glowing one right next to you: cast at it!"
				or "📦 Here's another crate! Cast at the glowing one!",
			"good"
		)
		self:_refresh(player)
	end
end

function TutorialService:Init(registry)
	data = registry.PlayerDataService
	rafts = registry.RaftService
	inventory = registry.InventoryService
	players = registry.PlayerService
	ocean = registry.OceanService
	voyages = registry.VoyageService
	island = registry.IslandService
	Net.on("GuideAction", function(player, what)
		if what == "hold_rod" then
			inventory:HoldKind(player, "rod")
			if active[player] then
				self:_refresh(player)
			else
				self:_goal(player)
			end
		end
	end)
	ocean.Hooked:Connect(function(player, d)
		local a = active[player]
		if not a then
			return
		end
		if d.guide then
			a.crateHooked = true
			a.crateHookedAt = now()
			self:_refresh(player)
			return
		end
		a.hooked += 1
		if STEPS[a.step] == "cast" then
			if a.hooked >= Constants.GUIDE_DEBRIS then
				self:Advance(player, "cast")
			else
				self:_refresh(player)
			end
		end
	end)
	rafts.Built:Connect(function(player, piece)
		local a = active[player]
		if not a then
			return
		end
		if piece.def.net then
			self:Advance(player, "net")
		elseif piece.def.structural then
			self:Advance(player, "tile")
		elseif piece.key == "workbench" then
			self:Advance(player, "bench")
		else
			self:_refresh(player) -- (the helm: the arrow moves onto it)
		end
	end)
	inventory.Used:Connect(function(player, item, d)
		local a = active[player]
		if a and item.key == "supply_crate" then
			a.crateOpened = true
			local profile = data:Get(player)
			if profile then
				profile.tutorial.crate = true
			end
			self:Advance(player, "crate")
			_ = d
		end
	end)
	voyages.Departed:Connect(function(_, _, aboard, home)
		for _, player in aboard do
			if active[player] then
				if home then
					self:_refresh(player)
				else
					self:Advance(player, "helm")
				end
			end
		end
	end)
	voyages.Arrived:Connect(function(_, _, aboard)
		for _, player in aboard do
			local a = active[player]
			if a then
				if a.step < INDEX.island then
					a.step = INDEX.island
					self:_show(player)
				else
					self:_refresh(player)
				end
			end
		end
	end)
	island.Looked:Connect(function(player)
		local a = active[player]
		if a then
			a.looked = true
			self:Advance(player, "island")
		end
	end)
	island.Searched:Connect(function(player)
		self:_refresh(player)
	end)
	voyages.Ended:Connect(function(_, _, aboard)
		for _, player in aboard do
			local a = active[player]
			if a then
				if a.step < INDEX.home then
					a.step = INDEX.home
				end
				self:Advance(player, "home")
			end
		end
	end)
	rafts.Demolished:Connect(function(player)
		self:_refresh(player)
	end)
end

function TutorialService:OnPlayerReady(player, profile)
	if profile.tutorial.done then
		data:WhenClientReady(player, function()
			lastGoal[player] = nil
			self:_goal(player)
		end)
		return
	end
	active[player] = { step = 1, hooked = 0, startedAt = now(), shownAt = now() }
	local raft = rafts:RaftOf(player)
	if raft then
		ocean:SeedNear(raft.plot, Constants.GUIDE_START_DEBRIS)
	end
	data:WhenClientReady(player, function()
		self:_show(player)
	end)
end

function TutorialService:OnPlayerLeaving(player)
	active[player] = nil
	lastGoal[player] = nil
end

function TutorialService:Start()
	while true do
		task.wait(1)
		local t = now()
		for _, player in Players:GetPlayers() do
			if data:Get(player) then
				self:_rescueRod(player)
				self:_goal(player)
			end
		end
		for player, a in active do
			local key = STEPS[a.step]
			-- the crate: the moment the guide asks for it, and again a few seconds after one's gone, until you have one
			if
				not a.crateOpened
				and (key == "crate" or a.crateWanted)
				and inventory:Count(player, "supply_crate") == 0
			then
				local d = a.crate and ocean:Get(a.crate)
				local reeling = a.crateHooked and t - (a.crateHookedAt or 0) < 6
				if not d and not reeling and (not a.crate or t - (a.crateAt or 0) >= Constants.GUIDE_CRATE_RETRY) then
					self:_crate(player, a)
				end
			end
			if key ~= nil then
				self:_refresh(player)
			end
		end
	end
end

return TutorialService
