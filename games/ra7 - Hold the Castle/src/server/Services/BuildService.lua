--[[
The castle (master plan §7). Everything is decided here, on the server.

  Place     a dwarf puts a blueprint on the 4-stud grid inside a shrine's build zone (a glowing ghost appears).
            Nothing is paid up front: anyone can help.
  Hammer    every hammer hit on a blueprint puts in what you carry (2 materials, 3 for Builders) and does work
            (1, 2 for Builders, more near a Healer); the work can't run ahead of the materials. The wall rises out
            of the ground as it's built. Many players can add to the same piece; big towers need many hands.
            On a built piece, a hit fixes damage; on a piece being upgraded, it builds the upgrade.
  Damage    monsters (and the horde) break pieces; nothing is unbreakable (§7). Wood burns. Gates break.
            Dwarves never hurt their own castle (§21).
  Traps and stations work by themselves: spikes, pits, oil pots, fix-it and healing stations.
  Stages    the castle points around a shrine make it a Camp, a Town or a Castle; a grander castle (and Shrine
            Wards) make its shrine drain slower.
The castle resets every match (§17): nobody starts with a built castle. The match starts with the camp's plan for
the west wall as blueprints (MapLayout.starter).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Kit = require(ReplicatedStorage.Shared.World.Kit)
local Looks = require(ReplicatedStorage.Shared.Data.Looks)
local MapLayout = require(ReplicatedStorage.Shared.World.MapLayout)
local Net = require(ReplicatedStorage.Shared.Net)
local PieceModels = require(ReplicatedStorage.Shared.World.PieceModels)
local Pieces = require(ReplicatedStorage.Shared.Data.Pieces)
local Signal = require(ReplicatedStorage.Shared.Signal)
local MapBuilder = require(script.Parent.Parent.World.MapBuilder)
local Groups = require(script.Parent.Parent.World.Groups)

local BuildService = {
	Name = "BuildService",
	Dependencies = { "PlayerDataService", "MatchService", "TeamService", "ResourceService" },
	Placed = Signal.new("BuildService.Placed"), -- (piece, player?)
	Helped = Signal.new("BuildService.Helped"), -- (piece, player, kind) kind: "deposit" | "work" | "fix" | "upgrade"
	Built = Signal.new("BuildService.Built"), -- (piece, contributors) a piece (or its upgrade) is finished
	Damaged = Signal.new("BuildService.Damaged"), -- (piece, amount, byPlayer?)
	Destroyed = Signal.new("BuildService.Destroyed"), -- (piece, byPlayer?)
	StageChanged = Signal.new("BuildService.StageChanged"), -- (shrineIndex, stage)
}

local data, match, teams, resources
local registry
local pieces = {} -- [id] = piece
local grid = {} -- ["i,j"] = id (every piece, blueprints too)
local nextId = 1
local stages = { "camp", "camp", "camp" }
local castleFolder
local CELL = Constants.CELL
local stageDecor = {} -- [shrine] = { parts }

local function now()
	return workspace:GetServerTimeNow()
end

local function cellKey(i, j)
	return i .. "," .. j
end

local ICON = {}
for _, m in Pieces.MATERIALS do
	ICON[m.key] = m.icon
end

-- Footprints -------------------------------------------------------------------------------------------------
-- Cells, centre (x, z), size (studs) of a piece at (i, j) turned rot.
local function footprint(def, i, j, rot)
	local w, d = Pieces.cells(def, rot)
	local cells = {}
	for a = 0, w - 1 do
		for b = 0, d - 1 do
			table.insert(cells, { i + a, j + b })
		end
	end
	local cx, cz = (i + w / 2) * CELL, (j + d / 2) * CELL
	return cells, cx, cz, w * CELL, d * CELL, w, d
end
BuildService.footprint = footprint

-- Is (x, z) within `range` of a piece's footprint (its edge, not its centre)?
local function distToPiece(piece, pos)
	local dx = math.max(0, math.abs(pos.X - piece.center.X) - piece.size.X / 2)
	local dz = math.max(0, math.abs(pos.Z - piece.center.Z) - piece.size.Z / 2)
	return math.sqrt(dx * dx + dz * dz), pos.Y - piece.groundY
end

function BuildService:Get(id)
	return pieces[id]
end

function BuildService:All()
	return pieces
end

-- Can this piece go here? Returns ok, reason, { shrine, groundY, cells, ... }.
function BuildService:Check(key, i, j, rot, player, system, instant)
	local def = Pieces.byKey[key]
	if not def then
		return false, "Pick something to build."
	end
	if rot ~= 0 and rot ~= 1 then
		return false, "Bad turn."
	end
	if type(i) ~= "number" or type(j) ~= "number" or i ~= math.floor(i) or j ~= math.floor(j) then
		return false, "Bad spot."
	end
	local cells, cx, cz, sx, sz = footprint(def, i, j, rot)
	local shrine
	for _, c in cells do
		local x, z = MapLayout.cellCenter(c[1], c[2])
		local zone = MapLayout.buildZoneAt(x, z)
		if not zone or (shrine and zone ~= shrine) then
			return false, "You can only build around a shrine."
		end
		shrine = zone
		if grid[cellKey(c[1], c[2])] then
			return false, "Something is already there."
		end
	end
	if not system and shrine <= match:Fallen() then
		return false, "That shrine has fallen. Build at the next one!"
	end
	local s = MapLayout.shrines[shrine]
	local flat = Vector2.new(cx - s.pos.X, cz - s.pos.Z)
	local reach = flat.Magnitude - math.max(sx, sz) / 2
	if def.ward then
		if flat.Magnitude > Constants.WARD_RANGE then
			return false, "Shrine Wards go right by the shrine."
		end
		local wards = 0
		for _, p in pieces do
			if p.def.ward and p.shrine == shrine then
				wards += 1
			end
		end
		if wards >= Constants.SHRINE_WARDS_MAX then
			return false, "This shrine already has two wards."
		end
		if flat.Magnitude < 6 then
			return false, "Too close to the shrine."
		end
	elseif reach < Constants.SHRINE_KEEP_CLEAR then
		return false, "Keep the shrine clear."
	end
	-- the job boards stay free
	for _, jb in MapLayout.jobBoards do
		if math.abs(jb.pos.X - cx) < sx / 2 + 4 and math.abs(jb.pos.Z - cz) < sz / 2 + 4 then
			return false, "Keep the Job Board clear."
		end
	end
	if not system then
		local count = 0
		for _ in pieces do
			count += 1
		end
		if count >= Constants.PIECES_MAX then
			return false, "The castle is as big as it can get!"
		end
		if player then
			local mine = 0
			for _, p in pieces do
				if p.owner == player and p.state == "blueprint" then
					mine += 1
				end
			end
			if mine >= Constants.BLUEPRINTS_PER_PLAYER and not instant then
				return false, "Finish your blueprints first!"
			end
			local pos = teams:Position(player)
			if not pos or (Vector2.new(pos.X - cx, pos.Z - cz)).Magnitude > 60 then
				return false, "Get closer to build there."
			end
		end
	end
	return true,
		nil,
		{ shrine = shrine, cells = cells, cx = cx, cz = cz, sx = sx, sz = sz, groundY = MapLayout.groundY(cx, cz) }
end

-- Models --------------------------------------------------------------------------------------------------------
local BLUEPRINT = Kit.C.blueprint

local function setCollide(model, on)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p.Name ~= "Root" then
			if on then
				local was = p:GetAttribute("Collides")
				if was ~= nil then
					p.CanCollide = was
				end
			else
				if p:GetAttribute("Collides") == nil then
					p:SetAttribute("Collides", p.CanCollide)
				end
				p.CanCollide = false
			end
		end
	end
end

-- Where the solid model sits for a progress (it rises out of the ground).
local function raise(piece)
	if not piece.model then
		return
	end
	local p = piece.state == "built" and 1 or Formulas.progress(piece.need, piece.have, piece.work, piece.done)
	local h = math.max(1, piece.def.height)
	local sink = (1 - p) * (h + 0.2)
	piece.model:PivotTo(piece.cf * CFrame.new(0, -sink, 0))
	piece.progress = p
	piece.model:SetAttribute("Progress", p)
end

local function makeModels(piece)
	if piece.model then
		piece.model:Destroy()
	end
	if piece.ghost then
		piece.ghost:Destroy()
	end
	local m = PieceModels.build(piece.key, piece.cf, {
		upgraded = piece.upgraded,
		flag = piece.flag,
		parent = castleFolder,
	})
	m.Name = "Piece" .. piece.id
	m:SetAttribute("PieceId", piece.id)
	m:SetAttribute("Key", piece.key)
	local blocker = m:FindFirstChild("Blocker")
	if blocker then
		Groups.set(blocker, "Gate")
	end
	piece.model = m
	if piece.state ~= "built" then
		setCollide(m, false)
		local h = math.max(1.2, piece.def.height)
		piece.ghost = Kit.box(
			castleFolder,
			"Blueprint" .. piece.id,
			piece.cf * CFrame.new(0, h / 2, 0),
			Vector3.new(piece.localSize.X, h, piece.localSize.Z),
			BLUEPRINT,
			Kit.M.SmoothPlastic,
			{ Transparency = 0.72, CanCollide = false, CanQuery = true, CastShadow = false }
		)
		piece.ghost:SetAttribute("PieceId", piece.id)
	end
	raise(piece)
end

-- Placing ------------------------------------------------------------------------------------------------------
-- Put a piece down. opts: { system = true (the camp's plan: no owner, no limits), built = true (finished at once) }
function BuildService:Place(player, key, i, j, rot, opts)
	opts = opts or {}
	if not opts.system then
		if not match:InMatch() then
			return nil, "Wait for the match to start."
		end
		if not player or teams:Team(player) ~= "dwarf" or not teams:IsAlive(player) then
			return nil, "Only dwarves can build."
		end
	end
	local ok, reason, info = self:Check(key, i, j, rot, player, opts.system, opts.built)
	if not ok then
		return nil, reason
	end
	local def = Pieces.byKey[key]
	local w, d = Pieces.cells(def, rot)
	local id = nextId
	nextId += 1
	local cf = PieceModels.frame(def, i, j, rot, info.groundY)
	local flagLook
	if player then
		local profile = data:Get(player)
		flagLook = profile and Looks.byKey[profile.looks.equipped.flag]
	end
	local piece = {
		id = id,
		key = key,
		def = def,
		i = i,
		j = j,
		rot = rot,
		w = w,
		d = d,
		cells = info.cells,
		shrine = info.shrine,
		cf = cf,
		groundY = info.groundY,
		center = Vector3.new(info.cx, info.groundY + def.height / 2, info.cz),
		size = Vector3.new(info.sx, def.height, info.sz),
		localSize = Vector3.new(def.size[1] * CELL, def.height, def.size[2] * CELL),
		state = "blueprint",
		need = table.clone(def.need),
		have = {},
		work = def.work,
		done = 0,
		hp = 0,
		maxHp = def.hp,
		owner = player,
		contributors = {},
		upgraded = false,
		shieldUntil = 0,
		curseUntil = 0,
		lastHitAt = 0,
		crackLevel = 0,
		cracks = {},
		flag = flagLook,
		placedAt = now(),
	}
	for k in piece.need do
		piece.have[k] = 0
	end
	for _, c in info.cells do
		grid[cellKey(c[1], c[2])] = id
	end
	pieces[id] = piece
	makeModels(piece)
	if opts.built then
		piece.have = table.clone(piece.need)
		piece.done = piece.work
		self:_complete(piece, true)
	else
		Net.fireAll("Fx", "placed", { id = id, position = piece.center, key = key })
	end
	self.Placed:Fire(piece, player)
	return piece
end

function BuildService:_complete(piece, quiet)
	piece.state = "built"
	piece.hp = piece.maxHp
	piece.builtAt = now()
	if piece.ghost then
		piece.ghost:Destroy()
		piece.ghost = nil
	end
	setCollide(piece.model, true)
	raise(piece)
	piece.model:SetAttribute("Built", true)
	piece.model:SetAttribute("Hp", piece.hp)
	piece.model:SetAttribute("MaxHp", piece.maxHp)
	if not quiet then
		Net.fireAll("Fx", "built", { id = piece.id, position = piece.center, key = piece.key, size = piece.size })
		Net.fireAll("Sfx", "built", piece.center)
	end
	for p in piece.contributors do
		if p.Parent then
			teams:Stat(p, "built", 1)
			if piece.key == "stoneWall" or piece.key == "woodWall" or piece.key == "quickWall" then
				teams:Stat(p, "walls", 1)
			end
			if piece.def.trap then
				teams:Stat(p, "traps", 1)
			end
			Net.fire(
				p,
				"Popup",
				piece.center + Vector3.new(0, piece.size.Y / 2 + 3, 0),
				"You helped build this!",
				"good"
			)
		end
	end
	self.Built:Fire(piece, piece.contributors)
	self:_recount()
end

-- Hammering ----------------------------------------------------------------------------------------------------
local function healerNear(player)
	local pos = teams:Position(player)
	if not pos then
		return false
	end
	for _, other in teams:Players("dwarf") do
		if other ~= player and teams:Job(other) == "healer" then
			local op = teams:Position(other)
			if op and (op - pos).Magnitude <= 16 then
				return true
			end
		end
	end
	return false
end

-- Put materials from a bag into a need/have pair (up to `n` this hit). Returns what went in.
local function deposit(player, need, have, n)
	local put = {}
	local left = n
	for _, m in Pieces.MATERIALS do
		local k = m.key
		local missing = (need[k] or 0) - (have[k] or 0)
		if missing > 0 and left > 0 then
			local got = resources:TakeUpTo(player, k, math.min(missing, left))
			if got > 0 then
				have[k] = (have[k] or 0) + got
				put[k] = got
				left -= got
			end
		end
	end
	return put, n - left
end

local function putText(put)
	local parts = {}
	for k, v in put do
		table.insert(parts, `+{v} {ICON[k]}`)
	end
	return table.concat(parts, " ")
end

-- A hammer hit on a piece (CombatService sends it here). Returns what happened, or nil.
function BuildService:Hammer(player, id)
	local piece = pieces[id]
	if not piece or teams:Team(player) ~= "dwarf" then
		return nil
	end
	local pos = teams:Position(player)
	if not pos then
		return nil
	end
	local dist, dy = distToPiece(piece, pos)
	if dist > Constants.HAMMER_RANGE or dy < -6 or dy > piece.def.height + 14 then
		return nil
	end
	local jobKey = teams:Job(player)
	local power = Formulas.hammerPower(jobKey, healerNear(player))
	local perHit = Formulas.depositPerHit(jobKey)
	if piece.state == "blueprint" then
		local put, n = deposit(player, piece.need, piece.have, perHit)
		local cap = Formulas.workCap(piece.need, piece.have, piece.work)
		local before = piece.done
		piece.done = math.min(cap, piece.done + power)
		local worked = piece.done > before
		if n == 0 and not worked then
			local missing = Formulas.missing(piece.need, piece.have)
			Net.fire(player, "Toast", "It needs " .. Pieces.costText(missing) .. ". Go mine some!", "bad")
			return "needs"
		end
		piece.contributors[player] = true
		raise(piece)
		Net.fireAll("Fx", "hammer", { id = id, position = piece.center, by = player.UserId, progress = piece.progress })
		Net.fireAll("Sfx", "hammer", piece.center)
		if n > 0 then
			Net.fire(player, "Popup", piece.center + Vector3.new(0, piece.size.Y / 2 + 2, 0), putText(put), "info")
			self.Helped:Fire(piece, player, "deposit")
		end
		if worked then
			self.Helped:Fire(piece, player, "work")
		end
		if piece.done >= piece.work and Formulas.progress(piece.need, piece.have, piece.work, piece.done) >= 1 then
			self:_complete(piece)
			return "built"
		end
		return n > 0 and "deposit" or "work"
	end
	-- built: an upgrade in progress?
	local up = piece.upgrade
	if up then
		local put, n = deposit(player, up.need, up.have, perHit)
		local cap = Formulas.workCap(up.need, up.have, up.work)
		local before = up.done
		up.done = math.min(cap, up.done + power)
		if n == 0 and up.done <= before then
			Net.fire(
				player,
				"Toast",
				"The upgrade needs " .. Pieces.costText(Formulas.missing(up.need, up.have)) .. ".",
				"bad"
			)
			return "needs"
		end
		piece.contributors[player] = true
		Net.fireAll(
			"Fx",
			"hammer",
			{ id = id, position = piece.center, by = player.UserId, progress = up.done / up.work }
		)
		Net.fireAll("Sfx", "hammer", piece.center)
		if n > 0 then
			Net.fire(player, "Popup", piece.center + Vector3.new(0, piece.size.Y / 2 + 2, 0), putText(put), "info")
		end
		self.Helped:Fire(piece, player, "upgrade")
		if up.done >= up.work and Formulas.progress(up.need, up.have, up.work, up.done) >= 1 then
			self:_finishUpgrade(piece)
			return "upgraded"
		end
		return "upgrade"
	end
	-- built and hurt: fix it
	if piece.hp < piece.maxHp then
		local job = teams:JobData(player)
		local amount = math.ceil(piece.maxHp * Constants.FIX_PER_HIT * (job and job.fixPower or 1))
		amount = math.min(amount, piece.maxHp - piece.hp)
		piece.hp += amount
		piece.model:SetAttribute("Hp", piece.hp)
		self:_cracks(piece)
		teams:Stat(player, "fixed", amount)
		Net.fireAll("Fx", "fix", { id = id, position = piece.center, by = player.UserId })
		Net.fireAll("Sfx", "hammer", piece.center)
		Net.fire(player, "Popup", piece.center + Vector3.new(0, piece.size.Y / 2 + 2, 0), `+{amount} 🔧`, "good")
		self.Helped:Fire(piece, player, "fix")
		return "fix"
	end
	return "fine"
end

-- NPC dwarves bring materials and hammer too (HordeService).
function BuildService:NpcDeliver(id, kind, amount, work)
	local piece = pieces[id]
	if not piece then
		return false
	end
	if piece.state == "blueprint" then
		local missing = (piece.need[kind] or 0) - (piece.have[kind] or 0)
		if missing > 0 then
			piece.have[kind] += math.min(missing, amount)
		end
		local cap = Formulas.workCap(piece.need, piece.have, piece.work)
		piece.done = math.min(cap, piece.done + (work or 0))
		raise(piece)
		Net.fireAll("Fx", "hammer", { id = id, position = piece.center, progress = piece.progress })
		if piece.done >= piece.work and Formulas.progress(piece.need, piece.have, piece.work, piece.done) >= 1 then
			self:_complete(piece)
		end
		return true
	elseif piece.hp < piece.maxHp then
		piece.hp = math.min(piece.maxHp, piece.hp + piece.maxHp * 0.03 * (work or 1))
		piece.model:SetAttribute("Hp", piece.hp)
		self:_cracks(piece)
		return true
	end
	return false
end

-- The nearest unfinished blueprint (or hurt piece) near a position, for NPC dwarves.
function BuildService:NearestWork(pos, maxDist)
	local best, bestD
	for _, p in pieces do
		if p.state == "blueprint" or p.hp < p.maxHp * 0.7 then
			local d = (p.center - pos).Magnitude
			if d <= (maxDist or 200) and (not bestD or d < bestD) then
				best, bestD = p, d
			end
		end
	end
	return best
end

-- Upgrades ------------------------------------------------------------------------------------------------------
function BuildService:StartUpgrade(player, id, system)
	local piece = pieces[id]
	if not piece or piece.state ~= "built" or piece.upgraded or piece.upgrade then
		return false, "That can't be upgraded right now."
	end
	local up = piece.def.upgrade
	if not up then
		return false, "That piece has no upgrade."
	end
	if not system then
		if teams:Team(player) ~= "dwarf" then
			return false, "Only dwarves can build."
		end
		local pos = teams:Position(player)
		if not pos or distToPiece(piece, pos) > 40 then
			return false, "Get closer first."
		end
	end
	piece.upgrade = { need = table.clone(up.need), have = {}, work = up.work, done = 0, def = up }
	for k in up.need do
		piece.upgrade.have[k] = 0
	end
	piece.model:SetAttribute("Upgrading", up.name)
	Net.fireAll("Fx", "upgradeStart", { id = id, position = piece.center, name = up.name })
	return true
end

function BuildService:_finishUpgrade(piece)
	local up = piece.upgrade.def
	piece.upgrade = nil
	piece.upgraded = true
	piece.maxHp = math.floor(piece.maxHp * up.hpMult)
	piece.hp = piece.maxHp
	makeModels(piece)
	piece.model:SetAttribute("Built", true)
	piece.model:SetAttribute("Hp", piece.hp)
	piece.model:SetAttribute("MaxHp", piece.maxHp)
	piece.model:SetAttribute("Upgraded", up.name)
	Net.fireAll(
		"Fx",
		"built",
		{ id = piece.id, position = piece.center, key = piece.key, size = piece.size, upgrade = up.name }
	)
	Net.fireAll("Sfx", "built", piece.center)
	for p in piece.contributors do
		if p.Parent then
			Net.fire(p, "Popup", piece.center + Vector3.new(0, piece.size.Y / 2 + 3, 0), `{up.name}!`, "good")
		end
	end
	self.Built:Fire(piece, piece.contributors)
	self:_recount()
end

-- Damage --------------------------------------------------------------------------------------------------------
function BuildService:_cracks(piece)
	local frac = piece.hp / piece.maxHp
	local level = frac < 0.25 and 2 or frac < 0.5 and 1 or 0
	if level == piece.crackLevel then
		return
	end
	for _, c in piece.cracks do
		c:Destroy()
	end
	piece.cracks = {}
	piece.crackLevel = level
	if level > 0 and piece.model then
		piece.cracks = PieceModels.cracks(piece.model, piece.cf, piece.def, level)
	end
end

-- Damage a piece. byPlayer: the monster player (or nil for the horde). kind: "fire" burns wood twice as fast.
-- Returns true if it broke.
function BuildService:Damage(id, amount, byPlayer, kind)
	local piece = pieces[id]
	if not piece or amount <= 0 then
		return false
	end
	if byPlayer and teams:Team(byPlayer) ~= "monster" then
		return false -- dwarves never hurt their own castle
	end
	local t = now()
	if piece.shieldUntil > t then
		Net.fireAll("Fx", "shielded", { id = id, position = piece.center })
		return false
	end
	if piece.curseUntil > t then
		amount *= 1 + (piece.curseMult or 0.5)
	end
	if kind == "fire" and piece.def.burns then
		amount *= 2
	end
	if piece.state == "blueprint" then
		-- a half-built piece can be knocked down too (its health grows as it's built)
		piece.hp = piece.hp > 0 and piece.hp or math.max(30, piece.maxHp * (piece.progress or 0))
	end
	piece.hp -= amount
	piece.lastHitAt = t
	if piece.model then
		piece.model:SetAttribute("Hp", math.max(0, piece.hp))
	end
	if byPlayer then
		teams:AddMonsterXp(byPlayer, amount * Constants.MONSTER_XP.pieceDamage)
	end
	self.Damaged:Fire(piece, amount, byPlayer)
	Net.fireAll("Fx", "pieceHit", { id = id, position = piece.center, amount = math.floor(amount), kind = kind })
	if piece.hp <= 0 then
		self:_destroy(piece, byPlayer)
		return true
	end
	if piece.state == "built" then
		self:_cracks(piece)
	end
	return false
end

function BuildService:_destroy(piece, byPlayer)
	if not pieces[piece.id] then
		return
	end
	pieces[piece.id] = nil
	for _, c in piece.cells do
		if grid[cellKey(c[1], c[2])] == piece.id then
			grid[cellKey(c[1], c[2])] = nil
		end
	end
	local wasBuilt = piece.state == "built"
	Net.fireAll("Fx", "crumble", { id = piece.id, position = piece.center, size = piece.size, key = piece.key })
	Net.fireAll("Sfx", "crumble", piece.center)
	if piece.model then
		piece.model:Destroy()
	end
	if piece.ghost then
		piece.ghost:Destroy()
	end
	if byPlayer and wasBuilt then
		teams:Stat(byPlayer, "broken", 1)
		teams:AddMonsterXp(byPlayer, Constants.MONSTER_XP.piece)
		if piece.def.gate then
			teams:Stat(byPlayer, "gates", 1)
		end
	end
	if piece.def.gate and wasBuilt then
		Net.fireAll("Callout", "Gate is down!", "gate")
	end
	self.Destroyed:Fire(piece, byPlayer)
	self:_recount()
end

-- Take back your own unfinished blueprint (what was put in goes back to whoever is placing it).
function BuildService:Cancel(player, id)
	local piece = pieces[id]
	if not piece or piece.state ~= "blueprint" or piece.owner ~= player then
		return false
	end
	for k, n in piece.have do
		if n > 0 then
			resources:Give(player, k, n)
		end
	end
	piece.hp = 0
	self:_destroy(piece, nil)
	return true
end

-- Queries (the horde, combat, shrines) ---------------------------------------------------------------------------
-- The built piece that blocks (x, z), if any. forDwarf: gates let dwarves through.
function BuildService:SolidAt(x, z, forDwarf)
	local i, j = MapLayout.cellOf(x, z)
	local id = grid[cellKey(i, j)]
	local p = id and pieces[id]
	if p and p.state == "built" and p.def.solid and not (forDwarf and p.def.gate) then
		return p
	end
	return nil
end

-- The piece (any state) on a cell.
function BuildService:PieceAtCell(i, j)
	local id = grid[cellKey(i, j)]
	return id and pieces[id]
end

-- Pieces within `radius` of a position (by their footprint's edge).
function BuildService:Near(pos, radius, builtOnly)
	local out = {}
	for _, p in pieces do
		if (not builtOnly or p.state == "built") and distToPiece(p, pos) <= radius then
			table.insert(out, p)
		end
	end
	return out
end

-- Is a piece in hammer reach of this position?
function BuildService:InReach(pos, id, range)
	local p = pieces[id]
	if not p then
		return nil
	end
	local d, dy = distToPiece(p, pos)
	if d <= (range or Constants.HAMMER_RANGE) and dy > -6 and dy < p.def.height + 14 then
		return p
	end
	return nil
end

BuildService.distToPiece = distToPiece

function BuildService:Wards(shrine)
	local n = 0
	for _, p in pieces do
		if p.def.ward and p.shrine == shrine and p.state == "built" then
			n += 1
		end
	end
	return n
end

function BuildService:Stage(shrine)
	return stages[shrine] or "camp"
end

function BuildService:Points(shrine)
	local n = 0
	for _, p in pieces do
		if p.shrine == shrine and p.state == "built" then
			n += p.def.points * (p.upgraded and 1.5 or 1)
		end
	end
	return n
end

-- The castle grows grander around a shrine: banners for a Town, more and a bigger glow for a Castle.
function BuildService:_stageDecor(shrine, stage)
	for _, part in stageDecor[shrine] or {} do
		part:Destroy()
	end
	stageDecor[shrine] = {}
	local sh = MapBuilder.shrines[shrine]
	local s = MapLayout.shrines[shrine]
	if not sh then
		return
	end
	local count = stage == "castle" and 8 or stage == "town" and 4 or 0
	for k = 0, count - 1 do
		local a = k / count * math.pi * 2
		local pos = s.pos + Vector3.new(math.cos(a) * 12, 0, math.sin(a) * 12)
		local m = Kit.banner(
			castleFolder,
			CFrame.lookAt(pos, Vector3.new(s.pos.X, pos.Y, s.pos.Z)),
			stage == "castle" and 12 or 9,
			k % 2 == 0 and Kit.C.roofBlue or Kit.C.cloth,
			Kit.C.gold,
			"StageBanner"
		)
		table.insert(stageDecor[shrine], m)
	end
	sh.crystal.Size = stage == "castle" and Vector3.new(4.8, 10, 4.8)
		or stage == "town" and Vector3.new(4.3, 9, 4.3)
		or Vector3.new(3.8, 8, 3.8)
end

function BuildService:_recount()
	for shrine = 1, #MapLayout.shrines do
		local stage = Formulas.castleStage(self:Points(shrine))
		if stage ~= stages[shrine] then
			local up = (stage == "castle") or (stage == "town" and stages[shrine] == "camp")
			stages[shrine] = stage
			self:_stageDecor(shrine, stage)
			workspace:SetAttribute("Stage" .. shrine, stage)
			if up and match:InMatch() then
				Net.fireAll(
					"Callout",
					stage == "castle" and `It's a CASTLE now! Shrine {shrine} drains slower.`
						or `The camp is a TOWN now! Shrine {shrine} drains slower.`,
					"stage"
				)
				Net.fireAll("Sfx", "win")
			end
			self.StageChanged:Fire(shrine, stage)
		end
	end
end

-- Traps and stations (4 times a second) ---------------------------------------------------------------------------
local function monstersOn(piece, horde)
	local out = {}
	for _, p in teams:Players("monster") do
		local pos = teams:Position(p)
		if
			pos
			and math.abs(pos.X - piece.center.X) <= piece.size.X / 2 + 0.5
			and math.abs(pos.Z - piece.center.Z) <= piece.size.Z / 2 + 0.5
			and pos.Y - piece.groundY < 6
		then
			table.insert(out, { player = p })
		end
	end
	if horde then
		for _, n in horde:Near(piece.center, math.max(piece.size.X, piece.size.Z) / 2 + 0.8, "monster") do
			table.insert(out, { npc = n })
		end
	end
	return out
end

local function monstersNear(pos, radius, horde)
	local out = {}
	for _, p in teams:Players("monster") do
		local pp = teams:Position(p)
		if pp and (pp - pos).Magnitude <= radius then
			table.insert(out, { player = p })
		end
	end
	if horde then
		for _, n in horde:Near(pos, radius, "monster") do
			table.insert(out, { npc = n })
		end
	end
	return out
end

function BuildService:_hurtVictim(v, amount, kind, piece, slow, stun)
	local combat, horde = registry.CombatService, registry.HordeService
	if v.player and combat then
		combat:HurtPlayer(v.player, amount, nil, kind)
		if slow then
			combat:Slow(v.player, slow, 1)
		end
		if stun then
			combat:Stun(v.player, stun)
		end
	elseif v.npc and horde then
		horde:Damage(v.npc.id, amount, nil, kind)
		if slow then
			horde:Slow(v.npc.id, slow, 1)
		end
		if stun then
			horde:Stun(v.npc.id, stun)
		end
	end
	_ = piece
end

function BuildService:_tickTraps(dt)
	if not match:IsFight() and match:Phase() ~= "build" then
		return
	end
	local horde = registry.HordeService
	local t = now()
	for _, p in pieces do
		if p.state == "built" then
			local trap, station = p.def.trap, p.def.station
			if trap == "spikes" then
				local on = monstersOn(p, horde)
				for _, v in on do
					self:_hurtVictim(v, 24 * dt, "spikes", p, 0.6)
				end
				if #on > 0 then
					p.hp -= 2 * #on * dt
					if p.hp <= 0 then
						self:_destroy(p, nil)
					end
				end
			elseif trap == "pit" then
				if (p.rearmAt or 0) <= t then
					local on = monstersOn(p, horde)
					if #on > 0 then
						self:_hurtVictim(on[1], 15, "pit", p, nil, 2)
						p.rearmAt = t + 5
						Net.fireAll("Fx", "trap", { id = p.id, position = p.center, kind = "pit" })
					end
				end
			elseif trap == "oil" then
				if (p.nextPour or 0) <= t then
					local near = monstersNear(p.center, 10, horde)
					if #near > 0 then
						for _, v in near do
							self:_hurtVictim(v, 35, "fire", p)
						end
						p.nextPour = t + 8
						Net.fireAll("Fx", "oil", { id = p.id, position = p.center, radius = 10 })
						Net.fireAll("Sfx", "magic", p.center)
					end
				end
			elseif station == "fix" then
				p.fixAcc = (p.fixAcc or 0) + dt
				if p.fixAcc >= 1 then
					p.fixAcc = 0
					for _, other in self:Near(p.center, 24, true) do
						if other.hp < other.maxHp and t - other.lastHitAt > Constants.REPAIR_DELAY then
							other.hp = math.min(other.maxHp, other.hp + other.maxHp * 0.01)
							other.model:SetAttribute("Hp", other.hp)
							self:_cracks(other)
						end
					end
				end
			elseif station == "heal" then
				p.healAcc = (p.healAcc or 0) + dt
				if p.healAcc >= 1 then
					p.healAcc = 0
					local combat = registry.CombatService
					for _, pl in teams:Players("dwarf") do
						local pos = teams:Position(pl)
						if pos and (pos - p.center).Magnitude <= 14 and combat then
							combat:HealPlayer(pl, 5, nil)
						end
					end
					if horde then
						for _, n in horde:Near(p.center, 14, "dwarf") do
							horde:Heal(n.id, 5)
						end
					end
				end
			end
		end
	end
end

-- Reset ----------------------------------------------------------------------------------------------------------
function BuildService:Reset()
	for _, p in pieces do
		if p.model then
			p.model:Destroy()
		end
		if p.ghost then
			p.ghost:Destroy()
		end
	end
	pieces = {}
	grid = {}
	for shrine = 1, #MapLayout.shrines do
		stages[shrine] = nil
	end
	self:_recount()
end

function BuildService:_starter()
	for _, b in MapLayout.starter do
		self:Place(nil, b.key, b.i, b.j, b.rot, { system = true })
	end
end

-- Requests -------------------------------------------------------------------------------------------------------
function BuildService:Init(reg)
	registry = reg
	data = reg.PlayerDataService
	match = reg.MatchService
	teams = reg.TeamService
	resources = reg.ResourceService
	castleFolder = workspace:FindFirstChild("Castle") or Instance.new("Folder")
	castleFolder.Name = "Castle"
	castleFolder.Parent = workspace
	for shrine = 1, #MapLayout.shrines do
		stages[shrine] = "camp"
	end

	Net.on("Place", function(player, key, i, j, rot)
		if type(key) ~= "string" or type(i) ~= "number" or type(j) ~= "number" or type(rot) ~= "number" then
			return
		end
		local piece, reason = self:Place(player, key, math.floor(i), math.floor(j), math.floor(rot))
		if not piece then
			Net.fire(player, "Toast", reason or "Can't build there.", "bad")
		else
			Net.fire(player, "Sfx", "hammer")
		end
	end)
	Net.on("Cancel", function(player, id)
		if type(id) == "number" then
			self:Cancel(player, id)
		end
	end)
	Net.on("Upgrade", function(player, id)
		if type(id) ~= "number" then
			return
		end
		local ok, why = self:StartUpgrade(player, id)
		if not ok then
			Net.fire(player, "Toast", why, "bad")
		end
	end)

	match.Started:Connect(function()
		self:Reset()
		self:_starter()
	end)
	match.Reset:Connect(function()
		self:Reset()
	end)
	Players.PlayerRemoving:Connect(function(player)
		for _, p in pieces do
			if p.owner == player then
				p.owner = nil
			end
			p.contributors[player] = nil
		end
	end)
end

function BuildService:Start()
	local last = os.clock()
	while true do
		task.wait(0.25)
		local t = os.clock()
		local dt = math.min(0.5, t - last)
		last = t
		local ok, err = pcall(self._tickTraps, self, dt)
		if not ok then
			warn("[BuildService] " .. tostring(err))
		end
	end
end

-- (tests)
function BuildService:_grid()
	return grid
end

return BuildService
