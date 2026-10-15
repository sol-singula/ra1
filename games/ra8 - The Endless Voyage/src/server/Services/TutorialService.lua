--[[
The first five minutes (master plan §4): one clear thing to do at a time, an arrow to where it is, and the game
itself does the teaching. Returning players never see it; SKIP ends it.

  1 cast     "Cast at the driftwood": six pieces float within reach the moment you arrive         0:00-0:30
  2 tile     "Build a Floor Tile": BUILD, pick it, tap a spot next to your raft                    0:30-0:50
  3 bench    "Build the Workbench"                                                                 0:50-1:30
  4 craft    "Craft something at the Workbench" (a hammer, an axe)                                 1:30-2:20
  5 crate    at 2:20 a supply crate drifts by: "Cast at the crate, then OPEN it in your bag"       2:20-3:00
             (inside: the Surface Net's blueprint and an axe)
  6 net      "Build the Surface Net on an edge facing the water"                                   3:00-3:30
  7 helm     "Build the Helm and set sail for Palm Key": the first real decision (go now, or build) 3:30-4:00
  8 island   "Land ho! Chop a palm, search the crate, look at the campfire"                        4:00-5:00
  9 home     "Sail home: what you found is safe at your dock"
Each first pays XP (Constants.XP.guide). Steps you've already done are skipped.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
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
local STEPS = { "cast", "tile", "bench", "craft", "crate", "net", "helm", "island", "home" }
TutorialService.STEPS = STEPS
local INDEX = {}
for i, k in STEPS do
	INDEX[k] = i
end
local TEXT = {
	cast = "Cast at the driftwood 🎣: aim at a piece, tap ACT, and it reels in",
	tile = "Build a Floor Tile 🟫: hold QUICK looking at the water beside your raft (or open BUILD and pick it)",
	bench = "Build the Workbench 🛠️ on a tile",
	craft = "Stand at the Workbench and craft something (a Hammer 🔨 or an Axe 🪓)",
	crate = "A supply crate 📦! Cast at it to reel it in, then OPEN it from your bag",
	net = "Build the Surface Net 🕸️ on an edge facing the water: it collects for you",
	helm = "Build the Helm 🎚️ and set sail for Palm Key, or keep building first. Your call!",
	island = "Land ho! Chop a palm 🌴, search the crate 📦, and look at the campfire 🔥",
	home = "Sail home from the helm ⛵: everything you found is safe at your dock",
}
TutorialService.TEXT = TEXT
local active = {} -- [player] = { step, shownAt, hooked, startedAt, crate, crateAt }

local function now()
	return workspace:GetServerTimeNow()
end

function TutorialService:Active(player)
	return active[player]
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
	elseif key == "tile" then
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
		if key == "net" then
			local e = rafts:FreeEdges(raft)[1]
			if e then
				local cf = rafts:PieceCF(raft, e.piece)
				local d = ({ Vector3.new(1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1) })[e.rot + 1]
				return cf.Position + d * (Constants.TILE / 2) + Vector3.new(0, 1, 0),
					{ edge = { piece = e.piece.id, rot = e.rot } }
			end
			return nil
		end
		local tile = rafts:EmptyTiles(raft, 1)[1]
		return tile and rafts:PiecePosition(raft, tile) + Vector3.new(0, 1, 0) or nil,
			tile and { spot = { gx = tile.gx, gz = tile.gz } } or nil
	elseif key == "craft" then
		for _, p in raft.pieces do
			if p.key == "workbench" then
				return rafts:PiecePosition(raft, p) + Vector3.new(0, 2, 0), { piece = p.id }
			end
		end
		return nil
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
	local view = { step = a.step, total = #STEPS, key = key, text = text, target = target }
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
		elseif key == "craft" then
			done = profile.stats.crafted > 0
		elseif key == "crate" then
			done = a.crateOpened == true or (profile.blueprints.net == true and a.crateHooked ~= false)
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
	Net.fire(player, "Tutorial", false)
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

-- The guide's crate drifts in at GUIDE_CRATE_AT (again if it drifted past).
function TutorialService:_crate(player, a)
	local raft = rafts:RaftOf(player)
	if not raft then
		return
	end
	local d = ocean:Crate(raft.plot, 1, { guide = true, distance = 36, spread = 6, lifetime = 100 })
	if d then
		a.crate = d.id
		a.crateAt = now()
		a.crateHooked = false
		Net.fire(player, "Callout", "📦 A supply crate is drifting by! Hook it.", "good")
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
	local craft = registry.CraftService
	Net.on("SkipTutorial", function(player)
		self:Finish(player, true)
	end)
	ocean.Hooked:Connect(function(player, d)
		local a = active[player]
		if not a then
			return
		end
		if d.guide then
			a.crateHooked = true
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
		if piece.def.structural then
			self:Advance(player, "tile")
		elseif piece.key == "workbench" then
			self:Advance(player, "bench")
		elseif piece.key == "net" or piece.key == "salvage_net" then
			self:Advance(player, "net")
		else
			self:_refresh(player) -- (the helm: the arrow moves onto it)
		end
	end)
	craft.Crafted:Connect(function(player)
		self:Advance(player, "craft")
	end)
	inventory.Used:Connect(function(player, item, d)
		local a = active[player]
		if a and item.key == "supply_crate" then
			a.crateOpened = true
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
end

function TutorialService:Start()
	while true do
		task.wait(2)
		local t = now()
		for player, a in active do
			local key = STEPS[a.step]
			-- the crate: at 2:20, again a minute after it drifted past untouched
			if not a.crateOpened and not a.crateHooked then
				local d = a.crate and ocean:Get(a.crate)
				local due = (not a.crate and t - a.startedAt >= Constants.GUIDE_CRATE_AT)
					or (a.crate and not d and t - (a.crateAt or 0) >= Constants.GUIDE_CRATE_RETRY)
				if due then
					self:_crate(player, a)
				end
			end
			if key == "cast" or key == "crate" or key == "island" or key == "tile" or key == "net" then
				self:_refresh(player)
			end
		end
	end
end

return TutorialService
