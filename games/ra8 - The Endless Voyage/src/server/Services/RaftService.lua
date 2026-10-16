--[[
The raft (master plan §5: the centre of everything, personal, persistent, visibly changing). Every player owns a
plot (OceanLayout) and the raft in it: a grid of tiles on two decks, with stations, systems and decoration on the
tiles and railings, nets, spikes and ladders on their edges (Data/Pieces). The owner builds, demolishes and paints;
storms and sea creatures damage pieces (a broken piece stops working and waits for the hammer); the tier
(Formulas.raftTier) is earned by what the raft can do. Saved in the owner's profile, rebuilt when they come back.

  pieces     { id, key, gx, gz, level, rot, hp, maxHp, broken, model, held, heldSince }; rot is the edge a
             railing sits on (0 = +X, 1 = +Z, 2 = -X, 3 = -Z) or the way a chair or the helm faces; held is what a
             net has caught
  building   structural pieces (floor, plank deck, stairs, and the nets: a tile of their own, a frame round open
             water with the net hanging in it and the catch piling up in view) go where there's no tile yet, next
             to one; the second deck needs a floor below and stairs or another second-deck tile beside it;
             everything else needs a floor under it (edge pieces: a free edge; ladders and spikes: an edge facing
             the water). Nothing goes on a net.
  prompts    the helm (the map), the stations (crafting), the bunk (rest), the nets (empty them): ProximityPrompts
             with a "Kind" attribute the client and the server read
]]
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Net = require(ReplicatedStorage.Shared.Net)
local OceanLayout = require(ReplicatedStorage.Shared.World.OceanLayout)
local Pieces = require(ReplicatedStorage.Shared.Data.Pieces)
local Progression = require(ReplicatedStorage.Shared.Data.Progression)
local RaftModels = require(ReplicatedStorage.Shared.World.RaftModels)
local Signal = require(ReplicatedStorage.Shared.Signal)

local RaftService = {
	Name = "RaftService",
	Dependencies = { "PlayerDataService" },
	Assigned = Signal.new("RaftService.Assigned"), -- (player, raft)
	Released = Signal.new("RaftService.Released"), -- (player, raft)
	Built = Signal.new("RaftService.Built"), -- (player, piece, raft)
	Demolished = Signal.new("RaftService.Demolished"), -- (player, piece, raft)
	TierChanged = Signal.new("RaftService.TierChanged"), -- (player, raft, tier, old)
	Damaged = Signal.new("RaftService.Damaged"), -- (raft, piece, amount, source)
	Broken = Signal.new("RaftService.Broken"), -- (raft, piece, source)
	Repaired = Signal.new("RaftService.Repaired"), -- (player, piece, raft)
	Painted = Signal.new("RaftService.Painted"), -- (player, kind, key)
	Rested = Signal.new("RaftService.Rested"), -- (player)
	Prompt = Signal.new("RaftService.Prompt"), -- (player, kind, piece, raft) a raft prompt was used
}

local data, registry
local rafts = {} -- [plot] = raft
local byPlayer = {} -- [player] = raft
local aboard = {} -- [player] = raft they're on (PlayerService keeps this up to date)
local lastToast = {} -- [player] = os.clock()

-- Pieces you can only have one of (their effects count once anyway).
local UNIQUE = {
	workbench = true,
	refinery = true,
	engineering = true,
	research = true,
	cookpot = true,
	decor_shop = true,
	sail = true,
	engine = true,
	nav_table = true,
	crow_nest = true,
	anchor = true,
	aquarium = true,
	trophy_stand = true,
	helm = true,
	bed = true,
}
-- Tall pieces: not under a second deck.
local TALL = { sail = true, roof = true, crow_nest = true, wall = true }
-- Edge pieces that must face the water.
local WATERSIDE = { ladder = true, spikes = true }
-- Pieces drawn with the raft's colours (rebuilt when they change).
local COLOURED = {
	floor = true,
	plank_floor = true,
	stairs = true,
	wall = true,
	sail = true,
	bed = true,
	banner = true,
	flag = true,
	chair = true,
	rug = true,
}
local NEIGHBOURS = { { 1, 0 }, { 0, 1 }, { -1, 0 }, { 0, -1 } } -- by rot: 0 = +X, 1 = +Z, 2 = -X, 3 = -Z

local function tkey(gx, gz)
	return (gx + 500) * 1000 + (gz + 500)
end

-- A net's catch from a save: a clean list of { key, n }.
function RaftService._heldFrom(list)
	local out = {}
	for _, it in type(list) == "table" and list or {} do
		if type(it) == "table" and Items.get(it.key) and type(it.n) == "number" and it.n > 0 then
			table.insert(out, { key = it.key, n = math.floor(it.n) })
		end
	end
	return out
end

-- How far the raft reaches from its centre (studs), so islands rise clear of a big one.
function RaftService:Extent(raft)
	local far = 0
	local c = raft.layout and raft.layout.center or Vector3.zero
	for _, p in raft.pieces do
		if p.def.structural then
			local pos = Formulas.tilePosition(c, p.gx, p.gz, 1)
			far = math.max(far, (Vector3.new(pos.X - c.X, 0, pos.Z - c.Z)).Magnitude + Constants.TILE)
		end
	end
	return far
end

local function toast(player, text, kind)
	local t = os.clock()
	if t - (lastToast[player] or 0) < 0.4 then
		return
	end
	lastToast[player] = t
	Net.fire(player, "Toast", text, kind or "bad")
end

-- Queries --------------------------------------------------------------------------------------------------------
function RaftService:Get(plot)
	return rafts[plot]
end

function RaftService:RaftOf(player)
	return byPlayer[player]
end

function RaftService:PlotOf(player)
	local r = byPlayer[player]
	return r and r.plot or nil
end

function RaftService:All()
	return rafts
end

-- Everyone on the raft's plot (the owner and visitors), for views and effects.
function RaftService:PlayersOn(raft)
	local out = {}
	for player, r in aboard do
		if r == raft and player.Parent then
			table.insert(out, player)
		end
	end
	return out
end

function RaftService:SetAboard(player, raft)
	if aboard[player] == raft then
		return
	end
	aboard[player] = raft
	if raft then
		Net.fire(player, "Raft", self:View(raft))
	end
end

function RaftService:Aboard(player)
	return aboard[player]
end

function RaftService:Tile(raft, gx, gz, level)
	local g = raft.grid[level or 1]
	return g and g[tkey(gx, gz)]
end

function RaftService:OnTile(raft, gx, gz, level)
	local g = raft.onTile[level or 1]
	return g and g[tkey(gx, gz)]
end

function RaftService:Edge(raft, gx, gz, level, rot)
	local g = raft.edges[level or 1]
	return g and g[tkey(gx, gz) * 10 + rot]
end

function RaftService:Piece(raft, id)
	return raft.pieces[id]
end

function RaftService:Count(raft, key, working)
	local n = 0
	for _, p in raft.pieces do
		if p.key == key and not (working and p.broken) then
			n += 1
		end
	end
	return n
end

function RaftService:Has(raft, key, working)
	return self:Count(raft, key, working) > 0
end

function RaftService:Tier(raft)
	return raft.tier
end

function RaftService:Speed(raft)
	return Formulas.raftSpeed(raft.working)
end

function RaftService:Cargo(raft)
	return Formulas.cargo(raft.tier, raft.working)
end

function RaftService:Protect(raft)
	local n = 0
	for _, p in raft.pieces do
		if not p.broken and p.def.effect and p.def.effect.protect then
			n += p.def.effect.protect
		end
	end
	return n
end

function RaftService:Anchors(raft)
	return self:Count(raft, "anchor", true)
end

function RaftService:Center(raft)
	return raft.layout.center + Vector3.new(0, Constants.DECK_Y, 0)
end

function RaftService:TileWorld(raft, gx, gz, level)
	return Formulas.tilePosition(raft.layout.center, gx, gz, level or 1)
end

-- The CFrame a piece is built at (on-tile pieces turn with rot; edge pieces turn in RaftModels).
function RaftService:PieceCF(raft, piece)
	local pos = self:TileWorld(raft, piece.gx, piece.gz, piece.level)
	if piece.def.edge then
		return CFrame.new(pos)
	end
	return CFrame.new(pos) * CFrame.Angles(0, -(piece.rot or 0) * math.pi / 2, 0)
end

function RaftService:PiecePosition(raft, piece)
	if piece.def.edge then
		return RaftModels.edgeCF(self:PieceCF(raft, piece), piece.rot).Position
	end
	return self:PieceCF(raft, piece).Position
end

-- Where you come to when you spawn: the bunk, else the middle of the platform.
function RaftService:SpawnPoint(raft)
	for _, p in raft.pieces do
		if p.key == "bed" then
			return self:PiecePosition(raft, p) + Vector3.new(0, 3.5, 0)
		end
	end
	local s = Constants.START_TILES[1]
	return self:TileWorld(raft, s[1], s[2], 1) + Vector3.new(0, 3.5, 0)
end

-- The tile under a world position, if any (so PlayerService knows you're on the raft).
function RaftService:TileAt(raft, pos)
	local top = Constants.DECK_Y + Constants.DECK_HEIGHT + 12
	if pos.Y < Constants.DECK_Y - 2.5 or pos.Y > top then
		return nil
	end
	local gx, gz, level = Formulas.tileAt(raft.layout.center, pos)
	local tile = self:Tile(raft, gx, gz, level)
	if not tile and level == 2 then
		tile = self:Tile(raft, gx, gz, 1)
	end
	return tile
end

-- Tiles with a free edge toward the water (sea creatures bite there), as { piece, rot }.
function RaftService:EdgeTiles(raft)
	local out = {}
	for _, p in raft.pieces do
		if p.def.structural and p.level == 1 then
			for rot, d in NEIGHBOURS do
				if not self:Tile(raft, p.gx + d[1], p.gz + d[2], 1) then
					table.insert(out, { piece = p, rot = rot - 1 })
				end
			end
		end
	end
	return out
end

-- Empty spots a new tile could go on a level: { { gx, gz }, ... }.
function RaftService:FreeSpots(raft, level)
	local out, seen = {}, {}
	level = level or 1
	for _, p in raft.pieces do
		if p.def.structural and p.level == level then
			for _, d in NEIGHBOURS do
				local gx, gz = p.gx + d[1], p.gz + d[2]
				local k = tkey(gx, gz)
				if
					gx >= Constants.GRID_MIN
					and gz >= Constants.GRID_MIN
					and gx <= Constants.GRID_MAX
					and gz <= Constants.GRID_MAX
					and not seen[k]
					and not self:Tile(raft, gx, gz, level)
				then
					seen[k] = true
					table.insert(out, { gx, gz })
				end
			end
		end
	end
	return out
end

-- Tiles with nothing on them: { piece, ... }.
function RaftService:EmptyTiles(raft, level)
	local out = {}
	for _, p in raft.pieces do
		if
			p.def.structural
			and not p.def.net
			and p.key ~= "stairs"
			and (not level or p.level == level)
			and not self:OnTile(raft, p.gx, p.gz, p.level)
		then
			table.insert(out, p)
		end
	end
	return out
end

-- Edges on tiles facing the water with nothing on them: { { piece, rot }, ... }.
function RaftService:FreeEdges(raft)
	local out = {}
	for _, e in self:EdgeTiles(raft) do
		if not self:Edge(raft, e.piece.gx, e.piece.gz, 1, e.rot) then
			table.insert(out, e)
		end
	end
	return out
end

-- The working nets: { piece, pos }.
function RaftService:Nets(raft)
	local out = {}
	for _, p in raft.pieces do
		if (p.key == "net" or p.key == "salvage_net") and not p.broken then
			local pos = self:PiecePosition(raft, p)
			table.insert(out, { piece = p, pos = Vector3.new(pos.X, Constants.WATER_LEVEL, pos.Z) })
		end
	end
	return out
end

function RaftService:Turrets(raft)
	local out = {}
	for _, p in raft.pieces do
		if p.key == "harpoon_turret" and not p.broken then
			table.insert(out, { piece = p, pos = self:PiecePosition(raft, p) + Vector3.new(0, 3, 0) })
		end
	end
	return out
end

function RaftService:SpikesAt(raft, tile, rot)
	local e = self:Edge(raft, tile.gx, tile.gz, tile.level, rot)
	return e ~= nil and e.key == "spikes" and not e.broken
end

-- The station a player stands beside (within 7 studs, working), or nil.
function RaftService:StationNear(player, range)
	local raft = aboard[player]
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not raft or not root then
		return nil
	end
	local best, bestD
	for _, p in raft.pieces do
		if p.def.station and not p.broken then
			local d = (self:PiecePosition(raft, p) - root.Position).Magnitude
			if d <= (range or 7) and (not bestD or d < bestD) then
				best, bestD = p, d
			end
		end
	end
	return best and best.def.station or nil, best
end

-- The nearest piece of a kind (or any damaged one, key = nil) within range of the player.
function RaftService:NearPiece(player, key, range, damagedOnly)
	local raft = aboard[player]
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not raft or not root then
		return nil
	end
	local best, bestD
	for _, p in raft.pieces do
		if (not key or p.key == key) and (not damagedOnly or p.hp < p.maxHp) then
			local d = (self:PiecePosition(raft, p) - root.Position).Magnitude
			if d <= (range or 8) and (not bestD or d < bestD) then
				best, bestD = p, d
			end
		end
	end
	return best
end

-- What to build next (the QUICK button): the next tier's missing stations you can build, tiles while the tier
-- wants more (stairs first when it wants a second deck), then a few comforts, then room. In the order to try them;
-- the client takes the first its bag can pay for (Formulas.recommended).
function RaftService:Recommend(raft)
	local profile = raft.owner and data:Get(raft.owner)
	local t = Pieces.TIERS[raft.tier + 1]
	local out, seen = {}, {}
	local function add(key, why)
		local def = Pieces.get(key)
		if not def or seen[key] or def.tier > raft.tier then
			return
		end
		if def.blueprint and not (profile and profile.blueprints[key]) then
			return
		end
		if def.decor and def.tier >= 2 and not self:Has(raft, "decor_shop", true) then
			return
		end
		seen[key] = true
		table.insert(out, { key = key, why = why })
	end
	local room = true -- (rafts grow as big as you like)
	if t then
		local why = `so your raft grows into a {t.name}`
		for _, def in Pieces.list do
			local need = t.needs and t.needs[def.key]
			if need and (raft.summary.pieces[def.key] or 0) < need then
				add(def.key, why)
			end
		end
		if t.any then
			local done = false
			for key, n in t.any do
				if (raft.summary.pieces[key] or 0) >= n then
					done = true
				end
			end
			if not done then
				for _, def in Pieces.list do
					if t.any[def.key] then
						add(def.key, why)
					end
				end
			end
		end
		if room and t.tiles and raft.summary.tiles < t.tiles then
			add("floor", `{raft.summary.tiles}/{t.tiles} tiles {why}`)
		end
		if room and t.deck2 and raft.summary.deck2 < t.deck2 then
			if not self:Has(raft, "stairs") then
				add("stairs", `a second deck {why}`)
			end
			add("floor", `{raft.summary.deck2}/{t.deck2} tiles up top {why}`)
		end
	end
	for _, key in { "railing", "bed", "lamp" } do
		if not self:Has(raft, key) then
			add(key, "a comfort")
		end
	end
	if room then
		add("floor", "more room")
	end
	return out
end

-- Views ----------------------------------------------------------------------------------------------------------
function RaftService:View(raft)
	local pieces = {}
	for _, p in raft.pieces do
		table.insert(pieces, {
			id = p.id,
			key = p.key,
			gx = p.gx,
			gz = p.gz,
			level = p.level,
			rot = p.rot,
			hp = math.floor(p.hp),
			max = p.maxHp,
			broken = p.broken or nil,
			held = p.held and #p.held > 0 and #p.held or nil,
		})
	end
	table.sort(pieces, function(a, b)
		return a.id < b.id
	end)
	local needs, nextTier = Formulas.tierNeeds(raft.summary, raft.tier, raft.trophies)
	local t = Pieces.TIERS[raft.tier]
	local stations = {}
	for _, p in raft.pieces do
		if p.def.station and not p.broken then
			stations[p.def.station] = true
		end
	end
	local broken = 0
	for _, p in raft.pieces do
		if p.broken then
			broken += 1
		end
	end
	return {
		owner = raft.owner and raft.owner.UserId or nil,
		ownerName = raft.owner and raft.owner.DisplayName or nil,
		plot = raft.plot,
		tier = raft.tier,
		tierName = t and t.name or "",
		nextTier = nextTier and nextTier.name or nil,
		tiles = raft.summary.tiles,
		deck2 = raft.summary.deck2,
		pieces = pieces,
		colours = raft.colours,
		speed = self:Speed(raft),
		cargo = self:Cargo(raft),
		needs = needs,
		broken = broken,
		stations = stations,
		helm = self:Has(raft, "helm", true),
		recommend = self:Recommend(raft),
	}
end

function RaftService:Push(raft)
	local view = self:View(raft)
	local sent = {}
	for _, player in self:PlayersOn(raft) do
		sent[player] = true
		Net.fire(player, "Raft", view)
	end
	if raft.owner and raft.owner.Parent and not sent[raft.owner] then
		Net.fire(raft.owner, "Raft", view)
	end
end

function RaftService:Fx(raft, kind, d)
	for _, player in self:PlayersOn(raft) do
		Net.fire(player, "Fx", kind, d)
	end
end

function RaftService:Sfx(raft, name, pos)
	for _, player in self:PlayersOn(raft) do
		Net.fire(player, "Sfx", name, pos)
	end
end

-- Models ---------------------------------------------------------------------------------------------------------
local PROMPT = {
	helm = { kind = "helm", text = "Set sail", object = "Helm" },
	bed = { kind = "bed", text = "Rest", object = "Bunk", hold = 0.6 },
	net = { kind = "net", text = "Empty net", object = "Surface Net" },
	salvage_net = { kind = "net", text = "Empty net", object = "Salvage Net" },
}

local function addPrompt(piece)
	local spec = PROMPT[piece.key]
	if piece.def.station then
		spec = { kind = "station", text = "Craft", object = piece.def.name }
	end
	if not spec or not piece.model then
		return
	end
	local part = piece.model:FindFirstChildWhichIsA("BasePart")
	if not part then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Prompt"
	prompt.ActionText = spec.text
	prompt.ObjectText = spec.object
	prompt.HoldDuration = spec.hold or 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Kind", spec.kind)
	prompt:SetAttribute("PieceId", piece.id)
	prompt:SetAttribute("Plot", piece.plot)
	prompt:SetAttribute("Station", piece.def.station or "")
	prompt.Parent = part
	piece.prompt = prompt
end

function RaftService:_model(raft, piece)
	if piece.model then
		piece.model:Destroy()
	end
	local opts = { colours = raft.colours, edge = piece.def.edge and piece.rot or nil, level = piece.level }
	local m = RaftModels.build(piece.key, self:PieceCF(raft, piece), opts, raft.folder)
	m:SetAttribute("PieceId", piece.id)
	m:SetAttribute("Plot", raft.plot)
	m:SetAttribute("Gx", piece.gx)
	m:SetAttribute("Gz", piece.gz)
	m:SetAttribute("Level", piece.level)
	m:SetAttribute("Rot", piece.rot)
	piece.model = m
	addPrompt(piece)
	if piece.def.net then
		self:ShowCatch(nil, piece)
	end
	if piece.hp < piece.maxHp then
		RaftModels.damage(m, piece.hp / piece.maxHp)
	end
	return m
end

local function index(raft, piece, on)
	local k = tkey(piece.gx, piece.gz)
	if piece.def.structural then
		raft.grid[piece.level][k] = on and piece or nil
	elseif piece.def.edge then
		raft.edges[piece.level][k * 10 + piece.rot] = on and piece or nil
	else
		raft.onTile[piece.level][k] = on and piece or nil
	end
end

function RaftService:_add(raft, spec)
	local def = Pieces.get(spec.key)
	if not def then
		return nil
	end
	raft.nextId += 1
	local piece = {
		id = raft.nextId,
		key = spec.key,
		def = def,
		gx = spec.gx,
		gz = spec.gz,
		level = spec.level or 1,
		rot = spec.rot or 0,
		hp = spec.hp or def.hp,
		maxHp = def.hp,
		broken = (spec.hp or def.hp) <= 0 or nil,
		plot = raft.plot,
		held = (spec.key == "net" or spec.key == "salvage_net") and RaftService._heldFrom(spec.held) or nil,
	}
	raft.pieces[piece.id] = piece
	index(raft, piece, true)
	self:_model(raft, piece)
	return piece
end

function RaftService:_remove(raft, piece)
	index(raft, piece, false)
	raft.pieces[piece.id] = nil
	if piece.model then
		piece.model:Destroy()
		piece.model = nil
	end
end

-- Recompute the summary, the working summary (unbroken pieces) and the tier.
function RaftService:Recompute(raft, quiet)
	local all, working = {}, {}
	for _, p in raft.pieces do
		table.insert(all, p)
		if not p.broken then
			table.insert(working, p)
		end
	end
	raft.summary = Formulas.raftSummary(all)
	raft.working = Formulas.raftSummary(working)
	local old = raft.tier
	raft.tier = Formulas.raftTier(raft.summary, raft.trophies)
	if raft.tier ~= old and not quiet then
		self.TierChanged:Fire(raft.owner, raft, raft.tier, old)
	end
	raft.dirty = true
end

-- Plots -----------------------------------------------------------------------------------------------------------
local function freePlot()
	for i = 1, Constants.MAX_PLAYERS do
		if not rafts[i] then
			return i
		end
	end
	return nil
end

function RaftService:Assign(player, profile)
	if byPlayer[player] then
		return byPlayer[player]
	end
	local plot = freePlot()
	if not plot then
		player:Kick("This ocean is full. Try again in a moment.")
		return nil
	end
	local folder = Instance.new("Model")
	folder.Name = "Raft" .. plot
	folder:SetAttribute("Plot", plot)
	folder:SetAttribute("Owner", player.UserId)
	folder.Parent = workspace:FindFirstChild("Rafts") or workspace
	local raft = {
		plot = plot,
		layout = OceanLayout.plot(plot),
		owner = player,
		pieces = {},
		nextId = 0,
		grid = { {}, {} },
		onTile = { {}, {} },
		edges = { {}, {} },
		folder = folder,
		colours = table.clone(profile.raft.colours or {}),
		trophies = profile.trophies or {},
		summary = { tiles = 0, deck2 = 0, pieces = {} },
		working = { tiles = 0, deck2 = 0, pieces = {} },
		tier = 1,
	}
	rafts[plot] = raft
	byPlayer[player] = raft
	local saved = profile.raft.pieces
	if type(saved) == "table" and #saved > 0 then
		-- the nets after the rest: a net saved from before they were tiles of their own sat on a floor, so it moves
		-- to a free spot beside the raft (or, with none, back into the bag with what it held)
		local nets = {}
		for _, s in saved do
			local def = type(s) == "table" and Pieces.get(s.key)
			if def and def.net then
				table.insert(nets, s)
			elseif def then
				self:_add(raft, s)
			end
		end
		for _, s in nets do
			local spec = table.clone(s)
			spec.level = 1
			if self:Tile(raft, spec.gx, spec.gz, 1) then
				local spot = self:FreeSpots(raft, 1)[1]
				spec.gx, spec.gz = spot and spot[1], spot and spot[2]
			end
			if spec.gx then
				self:_add(raft, spec)
			else
				task.delay(3, function()
					local inventory = registry.InventoryService
					if player.Parent and inventory then
						for item, n in Pieces.get(s.key).cost do
							inventory:Give(player, item, n, "demolish")
						end
						for _, it in RaftService._heldFrom(s.held) or {} do
							inventory:Give(player, it.key, it.n, "net")
						end
					end
				end)
			end
		end
	end
	if raft.summary.tiles == 0 and next(raft.pieces) == nil then
		for _, t in Constants.START_TILES do
			self:_add(raft, { key = "floor", gx = t[1], gz = t[2], level = 1 })
		end
	end
	self:Recompute(raft, true)
	-- a tile under every start spot, whatever the save held (a raft with no tiles can't be stood on)
	if raft.summary.tiles == 0 then
		for _, t in Constants.START_TILES do
			self:_add(raft, { key = "floor", gx = t[1], gz = t[2], level = 1 })
		end
		self:Recompute(raft, true)
	end
	folder:SetAttribute("Tier", raft.tier)
	self.Assigned:Fire(player, raft)
	return raft
end

-- Start over: the raft back to the driftwood platform it began as (RESET MY WORLD).
function RaftService:Reset(player)
	local raft = byPlayer[player]
	if not raft then
		return false
	end
	for _, p in raft.pieces do
		self:_remove(raft, p)
	end
	raft.pieces = {}
	raft.grid, raft.onTile, raft.edges = { {}, {} }, { {}, {} }, { {}, {} }
	for _, t in Constants.START_TILES do
		self:_add(raft, { key = "floor", gx = t[1], gz = t[2], level = 1 })
	end
	self:Recompute(raft, true)
	raft.folder:SetAttribute("Tier", raft.tier)
	raft.dirty = true
	local profile = data:Get(player)
	if profile then
		self:Save(raft, profile)
	end
	self:Push(raft)
	return true
end

function RaftService:Save(raft, profile)
	local list = {}
	for _, p in raft.pieces do
		table.insert(list, {
			key = p.key,
			gx = p.gx,
			gz = p.gz,
			level = p.level,
			rot = p.rot,
			hp = math.floor(p.hp),
			held = p.held and #p.held > 0 and p.held or nil,
		})
	end
	table.sort(list, function(a, b)
		if a.level ~= b.level then
			return a.level < b.level
		end
		if a.gx ~= b.gx then
			return a.gx < b.gx
		end
		return a.gz < b.gz
	end)
	profile.raft.pieces = list
	profile.raft.colours = table.clone(raft.colours)
	profile.records.tiles = math.max(profile.records.tiles or 0, raft.summary.tiles)
	profile.records.tier = math.max(profile.records.tier or 1, raft.tier)
	raft.dirty = false
end

function RaftService:Release(player, profile)
	local raft = byPlayer[player]
	if not raft then
		return
	end
	if profile then
		self:Save(raft, profile)
	end
	self.Released:Fire(player, raft)
	rafts[raft.plot] = nil
	byPlayer[player] = nil
	for p, r in aboard do
		if r == raft then
			aboard[p] = nil
		end
	end
	raft.folder:Destroy()
end

-- Building --------------------------------------------------------------------------------------------------------
local function adjacentTile(self, raft, gx, gz, level)
	for _, d in NEIGHBOURS do
		if self:Tile(raft, gx + d[1], gz + d[2], level) then
			return true
		end
	end
	return false
end

local function adjacentStairs(self, raft, gx, gz)
	for _, d in NEIGHBOURS do
		local t = self:Tile(raft, gx + d[1], gz + d[2], 1)
		if t and t.key == "stairs" then
			return true
		end
	end
	return false
end

-- Can this piece go here? ok, reason.
function RaftService:CanBuild(raft, player, key, gx, gz, level, rot)
	local def = Pieces.get(key)
	local profile = data:Get(player)
	if not def or not profile then
		return false, "Unknown piece."
	end
	if def.blueprint and not profile.blueprints[key] then
		return false, "You need its blueprint first."
	end
	if def.tier > raft.tier then
		local needs, nextT = Formulas.tierNeeds(raft.summary, raft.tier, raft.trophies)
		return false, Formulas.lockedText(def, { tier = raft.tier, needs = needs, nextTier = nextT and nextT.name })
	end
	if def.decor and def.tier >= 2 and not self:Has(raft, "decor_shop", true) then
		return false, "Needs the Decorative Workshop."
	end
	if type(gx) ~= "number" or type(gz) ~= "number" or gx ~= gx or gz ~= gz then
		return false, "Pick a spot."
	end
	gx, gz = math.floor(gx), math.floor(gz)
	if gx < Constants.GRID_MIN or gz < Constants.GRID_MIN or gx > Constants.GRID_MAX or gz > Constants.GRID_MAX then
		return false, "That's too far out at sea for one raft."
	end
	level = level == 2 and 2 or 1
	rot = type(rot) == "number" and math.floor(rot) % 4 or 0
	local tile = self:Tile(raft, gx, gz, level)
	if def.structural then
		if tile then
			return false, "There's a tile there already."
		end
		if key == "stairs" and level ~= 1 then
			return false, "Stairs go on the first deck."
		end
		if def.net and level ~= 1 then
			return false, "Nets go down at the water."
		end
		if level == 1 then
			if not adjacentTile(self, raft, gx, gz, 1) then
				return false, "Build next to your raft."
			end
		else
			local below = self:Tile(raft, gx, gz, 1)
			if not below then
				return false, "Needs a tile under it."
			end
			if below.key == "stairs" then
				return false, "Not over the stairs."
			end
			if below.def.net then
				return false, "Not over a net."
			end
			if not adjacentTile(self, raft, gx, gz, 2) and not adjacentStairs(self, raft, gx, gz) then
				return false, "Needs stairs or a second-deck tile beside it."
			end
		end
	else
		if not tile then
			return false, "Build a tile there first."
		end
		if tile.key == "stairs" then
			return false, "Not on the stairs."
		end
		if tile.def.net then
			return false, "Not on a net: build it on a floor."
		end
		if def.deck == 2 and level ~= 2 then
			return false, "Only on the second deck."
		end
		if def.edge then
			if self:Edge(raft, gx, gz, level, rot) then
				return false, "That edge is taken."
			end
			if WATERSIDE[key] then
				local d = NEIGHBOURS[rot + 1]
				if self:Tile(raft, gx + d[1], gz + d[2], level) then
					return false, `The {def.name} must face the water.`
				end
			end
		else
			if self:OnTile(raft, gx, gz, level) then
				return false, "That tile is taken."
			end
			if UNIQUE[key] and self:Has(raft, key) then
				return false, `You already have a {def.name}.`
			end
			if TALL[key] and level == 1 and self:Tile(raft, gx, gz, 2) then
				return false, "No room under the deck above."
			end
		end
	end
	local inventory = registry.InventoryService
	for item, n in def.cost do
		if not inventory:Has(player, item, n) then
			local it = Items.get(item)
			return false, `Needs {n} {it and it.name or item} (you have {inventory:Count(player, item)}).`
		end
	end
	return true, nil, gx, gz, level, rot
end

function RaftService:Build(player, key, gx, gz, level, rot)
	local raft = byPlayer[player]
	if not raft then
		return false
	end
	if aboard[player] ~= raft then
		toast(player, "You can only build on your own raft.")
		return false
	end
	local ok, reason, x, z, lv, r = self:CanBuild(raft, player, key, gx, gz, level, rot)
	if not ok then
		toast(player, reason)
		return false, reason
	end
	local def = Pieces.get(key)
	local inventory = registry.InventoryService
	for item, n in def.cost do
		inventory:Take(player, item, n)
	end
	local piece = self:_add(raft, { key = key, gx = x, gz = z, level = lv, rot = r })
	self:Recompute(raft)
	raft.folder:SetAttribute("Tier", raft.tier)
	local pos = self:PiecePosition(raft, piece)
	self:Fx(raft, "built", { pos = pos, key = key })
	self:Sfx(raft, "built", pos)
	Net.fire(player, "Popup", pos + Vector3.new(0, 3, 0), `{def.icon} {def.name}`, Color3.fromRGB(255, 230, 120))
	self:Push(raft)
	self.Built:Fire(player, piece, raft)
	return true, piece
end

-- Would the first deck stay in one piece without this tile?
local function connectedWithout(self, raft, piece)
	local start, total = nil, 0
	for _, p in raft.pieces do
		if p.def.structural and p.level == 1 and p ~= piece then
			start = start or p
			total += 1
		end
	end
	if not start then
		return false
	end
	local seen, stack, n = { [start] = true }, { start }, 0
	while #stack > 0 do
		local p = table.remove(stack)
		n += 1
		for _, d in NEIGHBOURS do
			local t = self:Tile(raft, p.gx + d[1], p.gz + d[2], 1)
			if t and t ~= piece and not seen[t] then
				seen[t] = true
				table.insert(stack, t)
			end
		end
	end
	return n == total
end

-- Take a piece off your raft and get its whole cost back (and whatever a net had caught). A tile takes the pieces on
-- it and on its edges with it, every one refunded; the raft still can't be split in two, go below its first tiles,
-- or lose the tile under a second deck or the stairs up to one.
function RaftService:Demolish(player, pieceId)
	local raft = byPlayer[player]
	local piece = raft and raft.pieces[pieceId]
	if not piece then
		return false
	end
	if aboard[player] ~= raft then
		toast(player, "You can only change your own raft.")
		return false
	end
	local set = { piece }
	if piece.def.structural then
		if piece.level == 1 and self:Tile(raft, piece.gx, piece.gz, 2) then
			toast(player, "Take the deck above off first.")
			return false
		end
		if piece.key == "stairs" and raft.summary.deck2 > 0 then
			toast(player, "The second deck needs its stairs.")
			return false
		end
		if
			not piece.def.net
			and piece.level == 1
			and raft.summary.tiles - raft.summary.deck2 <= Constants.MIN_TILES
		then
			toast(player, "That's as small as a raft gets.")
			return false
		end
		if piece.level == 1 and not connectedWithout(self, raft, piece) then
			toast(player, "That would split your raft in two.")
			return false
		end
		local on = self:OnTile(raft, piece.gx, piece.gz, piece.level)
		if on then
			table.insert(set, 1, on)
		end
		for rot = 0, 3 do
			local e = self:Edge(raft, piece.gx, piece.gz, piece.level, rot)
			if e then
				table.insert(set, 1, e)
			end
		end
	end
	local back, order = {}, {}
	local function add(item, n)
		if n > 0 then
			if not back[item] then
				table.insert(order, item)
			end
			back[item] = (back[item] or 0) + n
		end
	end
	for _, p in set do
		for item, n in p.def.cost do
			add(item, math.floor(n * Constants.DEMOLISH_REFUND))
		end
		for _, it in p.held or {} do
			add(it.key, it.n)
		end
	end
	local inventory = registry.InventoryService
	for _, item in order do
		inventory:Give(player, item, back[item], "demolish")
	end
	local pos = self:PiecePosition(raft, piece)
	for _, p in set do
		self:_remove(raft, p)
	end
	self:Recompute(raft)
	raft.folder:SetAttribute("Tier", raft.tier)
	self:Fx(raft, "demolish", { pos = pos })
	self:Push(raft)
	-- what came back, over where it was
	local parts = {}
	for _, item in order do
		local it = Items.get(item)
		table.insert(parts, `+{back[item]} {it and it.icon or item}`)
	end
	if #parts > 0 then
		Net.fire(
			player,
			"Popup",
			pos + Vector3.new(0, 3, 0),
			"♻️ " .. table.concat(parts, "  "),
			Color3.fromRGB(150, 230, 160)
		)
	end
	for _, p in set do
		self.Demolished:Fire(player, p, raft)
	end
	return true
end

function RaftService:Paint(player, kind, key)
	local raft = byPlayer[player]
	local profile = data:Get(player)
	if not raft or not profile or type(kind) ~= "string" or type(key) ~= "string" then
		return false
	end
	local owned
	if kind == "sail" or kind == "banner" or kind == "flag" then
		local c = Progression.COLORS[key]
		owned = c and (c.free or profile.colours.owned[key])
	elseif kind == "deck" then
		local d = Progression.DECKS[key]
		owned = d and (d.free or profile.colours.decks[key])
	elseif kind == "pattern" then
		for _, f in Progression.FLAGS do
			if f.key == key then
				owned = f.free or profile.flags.owned[key]
			end
		end
	else
		return false
	end
	if not owned then
		toast(player, "You don't have that colour yet. The Decorative Workshop dyes it.")
		return false
	end
	if raft.colours[kind] == key then
		return true
	end
	raft.colours[kind] = key
	for _, p in raft.pieces do
		if COLOURED[p.key] then
			self:_model(raft, p)
		end
	end
	raft.dirty = true
	self:Push(raft)
	self.Painted:Fire(player, kind, key)
	return true
end

-- Damage and repair -------------------------------------------------------------------------------------------
function RaftService:Damage(raft, piece, amount, source)
	if not piece or piece.broken or amount <= 0 then
		return 0
	end
	amount = math.min(piece.hp, amount)
	piece.hp -= amount
	if piece.model then
		RaftModels.damage(piece.model, piece.hp / piece.maxHp)
	end
	local pos = self:PiecePosition(raft, piece)
	self:Fx(raft, "crack", { pos = pos, amount = amount })
	self.Damaged:Fire(raft, piece, amount, source)
	if piece.hp <= 0 then
		piece.hp = 0
		piece.broken = true
		if piece.model then
			piece.model:SetAttribute("Broken", true)
		end
		self:Recompute(raft)
		if raft.owner and raft.owner.Parent then
			toast(raft.owner, `💥 Your {piece.def.name} broke! Hammer it to repair it.`, "bad")
		end
		self.Broken:Fire(raft, piece, source)
	end
	self:Push(raft)
	return amount
end

-- A storm's or a whirlpool's hit: `hits` random pieces take STORM_TILE_DAMAGE, less with railings and an anchor.
function RaftService:DamageRandom(raft, hits, base, source)
	local candidates = {}
	for _, p in raft.pieces do
		if not p.broken then
			table.insert(candidates, p)
		end
	end
	if #candidates == 0 then
		return 0
	end
	local amount = Formulas.stormDamage(base or Constants.STORM_TILE_DAMAGE, self:Protect(raft), self:Anchors(raft))
	local total = 0
	for _ = 1, hits do
		local p = candidates[math.random(1, #candidates)]
		total += self:Damage(raft, p, amount, source)
	end
	return total
end

function RaftService:Repair(player, pieceId)
	local raft = aboard[player]
	if not raft then
		return false
	end
	local piece = pieceId and raft.pieces[pieceId]
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if piece and root and (self:PiecePosition(raft, piece) - root.Position).Magnitude > 9 then
		piece = nil
	end
	if not piece or piece.hp >= piece.maxHp then
		piece = self:NearPiece(player, nil, 8, true)
	end
	if not piece then
		toast(player, "Nothing to repair here.", "info")
		return false
	end
	local inventory = registry.InventoryService
	if not inventory:Take(player, "wood", 1) then
		toast(player, "Repairs take 1 wood a hit.")
		return false
	end
	piece.hp = math.min(piece.maxHp, piece.hp + Constants.REPAIR_PER_HIT)
	local wasBroken = piece.broken
	if piece.hp > 0 then
		piece.broken = nil
		if piece.model then
			piece.model:SetAttribute("Broken", nil)
		end
	end
	if piece.model then
		RaftModels.damage(piece.model, piece.hp / piece.maxHp)
	end
	if wasBroken then
		self:Recompute(raft)
	else
		raft.dirty = true
	end
	local pos = self:PiecePosition(raft, piece)
	self:Fx(raft, "repair", { pos = pos })
	self:Sfx(raft, "built", pos)
	if piece.hp >= piece.maxHp then
		Net.fire(player, "Popup", pos + Vector3.new(0, 3, 0), "🔨 Fixed!", Color3.fromRGB(140, 230, 140))
	end
	self:Push(raft)
	self.Repaired:Fire(player, piece, raft)
	return true
end

-- The bunk: a rest brings your health back and sets where you wake up.
function RaftService:Rest(player, piece)
	local raft = byPlayer[player]
	if not raft or aboard[player] ~= raft then
		toast(player, "Only your own bunk.", "info")
		return false
	end
	Net.fire(player, "Fade", 1.2, "Resting...")
	registry.PlayerService:Heal(player, Constants.MAX_HP, "rest")
	Net.fire(player, "Toast", "😴 You feel rested. You'll wake up here from now on.", "good")
	self.Rested:Fire(player)
	_ = piece
	return true
end

-- A net's catch goes to whoever empties it.
function RaftService:EmptyNet(player, piece)
	local raft = aboard[player]
	if not raft or not piece or not piece.held or #piece.held == 0 then
		toast(player, "The net is empty.", "info")
		return false
	end
	local inventory = registry.InventoryService
	local list = piece.held
	piece.held = {}
	piece.heldSince = nil
	for _, it in list do
		inventory:Give(player, it.key, it.n, "net")
	end
	self:ShowCatch(raft, piece)
	Net.fire(player, "Sfx", "pickup")
	self:Push(raft)
	return true
end

-- What a net holds, in it where you can see it (RaftModels.showCatch), and in the raft view.
function RaftService:ShowCatch(raft, piece)
	if piece and piece.model and piece.def.net then
		RaftModels.showCatch(piece.model, piece.held)
		if piece.prompt then
			local hold = piece.key == "salvage_net" and Constants.NET_HOLD_SALVAGE or Constants.NET_HOLD
			piece.prompt.ObjectText = `{piece.def.name} ({#(piece.held or {})}/{hold})`
		end
	end
	if raft then
		raft.dirty = true
	end
end

-- Boot ------------------------------------------------------------------------------------------------------------
function RaftService:Init(reg)
	registry = reg
	data = reg.PlayerDataService
	Net.on("Build", function(player, key, gx, gz, level, rot)
		if type(key) == "string" then
			self:Build(player, key, gx, gz, level, rot)
		end
	end)
	Net.on("Demolish", function(player, pieceId)
		if type(pieceId) == "number" then
			self:Demolish(player, pieceId)
		end
	end)
	Net.on("Paint", function(player, kind, key)
		self:Paint(player, kind, key)
	end)
	-- the raft's prompts (the client handles the helm and the stations itself)
	pcall(function()
		ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
			local kind = prompt:GetAttribute("Kind")
			local plot = prompt:GetAttribute("Plot")
			local raft = kind and rafts[plot]
			local piece = raft and raft.pieces[prompt:GetAttribute("PieceId")]
			if not piece then
				return
			end
			if kind == "bed" then
				self:Rest(player, piece)
			elseif kind == "net" then
				self:EmptyNet(player, piece)
			end
			self.Prompt:Fire(player, kind, piece, raft)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		aboard[player] = nil
		lastToast[player] = nil
	end)
end

function RaftService:OnPlayerReady(player, profile)
	local raft = self:Assign(player, profile)
	if raft then
		data:WhenClientReady(player, function()
			Net.fire(player, "Raft", self:View(raft))
		end)
	end
end

function RaftService:OnPlayerLeaving(player, profile)
	self:Release(player, profile)
end

function RaftService:Start()
	-- the raft's save follows the profile's autosave; keep the profile's copy fresh now and then
	while true do
		task.wait(10)
		for _, raft in rafts do
			if raft.dirty and raft.owner and raft.owner.Parent then
				local profile = data:Get(raft.owner)
				if profile then
					self:Save(raft, profile)
				end
			end
		end
	end
end

-- (tests)
RaftService.tkey = tkey
return RaftService
