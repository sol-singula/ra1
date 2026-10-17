--[[
Construction (master plan §2B, §7): modular structures on the 4-stud grid, in the build phase only.

A placement is checked here, never trusted from the client: the phase; the structure exists; your budget covers it
and your team is under its cap; you're within BUILD_REACH; every cell of its footprint is on your own turf, at least
up to the frontline (BUILD_FRONT_GAP cells back; 0 = the cell touching it too), out of both spawn zones and inside the field; it doesn't overlap
another structure or stand in the map's shapes (poking BUILD_MAP_OVERLAP studs into one at the edges is fine); and if it's a tall piece, every row of cells across the field it stands in still
has an open cell (no wall ever seals the battlefield). Then it's built for everyone in its team's colour.

Structures last the match (they're cleared with the arena) unless arrows or TNT break them: CombatService reports
hits on their boxes (StructureHit, with where the blow came from) and they lose durability; when one comes down
everyone is told where it stood and what hit it, and each client breaks it into flying debris (DebrisController).
How each piece looks is StructureModel's (shared with the hotbar's pictures and the debris). In the build phase you can take back your own (Demolish) for
the full cost.

Pieces touching join up (StructureModel.joins: walls in a row run on as one, corners get a post, a Rampart's deck
reaches the wall beside it): when one goes up or comes down, the same team's pieces on the cells round it are made
again if their joins changed (their parts only; the box each stands in, and so every rule, stays the same).

The Rally Banner (Data/Structures: rally) is a forward spawn: while it stands on its team's turf, that team's players
come back to life beside it instead of in the spawn room (MatchService asks RallySpawn when a respawn is due). One a
team at a time (a second is refused until the first is down or taken back), so it's a team decision, not a carpet of
spawns. The spot is a free cell round it, toward home first: never in a structure or a map shape, inside the field,
at least a cell back from the line, on the deck (a ray down, where the engine has one). Lost turf takes it down
(ClearLost) and RallySpawn ignores one over the line anyway. The team hears when it goes up and when it falls; it
glows a little and wears a small RALLY marker. Spawn protection is the same as anywhere (CombatService:Spawned).

  BuildService:Place(player, key, cx, cz, rot) -> ok, why
  BuildService:Refill()                 the budgets, at each build phase
  BuildService:Clear()                  between matches
  BuildService:Budget(player)
  BuildService:All()                    { [id] = structure }
  BuildService:Rally(team, any?)        the team's standing Rally Banner on its own turf (any: wherever), or nil
  BuildService:RallySpawn(player)       a CFrame beside their team's Rally Banner, or nil (the spawn room)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local StructureModel = require(ReplicatedStorage.Shared.StructureModel)
local Structures = require(ReplicatedStorage.Shared.Data.Structures)

local BuildService = {
	Name = "BuildService",
	Modes = { "turf", "ctf", "brawl" }, -- (a match's: never in the lobby)
	Dependencies = { "TeamService", "ArenaService", "CombatService" },
	Built = Signal.new("BuildService.Built"), -- (player, structure)
	Destroyed = Signal.new("BuildService.Destroyed"), -- (structure, attacker?)
}

local teams, arena, combat
local structures = {} -- [id] = { id, key, team, owner, cx, cz, w, d, rot, hp, max, model, boxMin, boxMax, joins, solid }
local occupied = {} -- [cx][cz] = id
local budgets = {} -- [player] = points left
local nextId = 0
local open = false -- the build phase
local frontlineOf -- fn() -> the frontline's X (MatchService)
local folder
local clearing = false -- (Clear is taking everything down between matches)

local function cellsOf(cx, cz, w, d)
	local out = {}
	for x = cx, cx + w - 1 do
		for z = cz, cz + d - 1 do
			table.insert(out, { x, z })
		end
	end
	return out
end

function BuildService:Budget(player)
	return budgets[player] or Constants.BUILD_BUDGET
end

function BuildService:Push(player)
	Net.fire(player, "Me", { budget = self:Budget(player), budgetMax = Constants.BUILD_BUDGET })
end

function BuildService:SetOpen(on)
	open = on
end

function BuildService:SetFrontline(fn)
	frontlineOf = fn
end

function BuildService:Refill()
	for _, p in Players:GetPlayers() do
		budgets[p] = Constants.BUILD_BUDGET
		self:Push(p)
	end
end

function BuildService:TeamCount(team)
	local n = 0
	for _, s in structures do
		if s.team == team then
			n += 1
		end
	end
	return n
end

function BuildService:TeamCap(team)
	return Constants.TEAM_STRUCTURES + math.max(0, teams:Count(team) - 10) * 2
end

-- Is cell (cx, cz) blocked to walking at ground level (a tall structure or a map shape)?
local function blockedCell(a, cx, cz, extraCells)
	if extraCells and extraCells[cx .. ":" .. cz] then
		return true
	end
	local id = occupied[cx] and occupied[cx][cz]
	if id then
		local s = structures[id]
		local def = s and Structures.get(s.key)
		if def and def.blocks then
			return true
		end
	end
	return a.blocked[cx] and a.blocked[cx][cz] == true
end

-- Checks a placement; returns ok, why (a short reason the client shows).
function BuildService:Check(player, key, cx, cz, rot)
	local def = Structures.get(key)
	if not def then
		return false, "Unknown structure"
	end
	if not open then
		return false, "Building is only in the build phase"
	end
	local team = teams:Team(player)
	if not team then
		return false, "No team"
	end
	if type(cx) ~= "number" or type(cz) ~= "number" or cx ~= cx or cz ~= cz then
		return false, "Bad spot"
	end
	cx, cz = math.floor(cx), math.floor(cz)
	rot = rot == 1 and 1 or 0
	if self:Budget(player) < def.cost then
		return false, "Not enough build points"
	end
	if self:TeamCount(team) >= self:TeamCap(team) then
		return false, "Your team has built all it can"
	end
	if def.rally and self:Rally(team, true) then
		return false, "Your team's Rally Banner is already up"
	end
	local a = arena:Current()
	if not a then
		return false, "No arena"
	end
	local w, d = Structures.footprint(def, rot)
	local mn, mx = Formulas.footprintBox(cx, cz, w, d, 0, def.h)
	-- inside the field, out of the spawn zones, on your own turf, back from the line
	local front = frontlineOf and frontlineOf() or 0
	local edge = a.half - a.spawnDepth
	-- (right up to the long walls and the spawn lines: the cell touching them is yours to build on)
	if mn.X < -edge or mx.X > edge or mn.Z < -a.width / 2 or mx.Z > a.width / 2 then
		return false, "Outside the battlefield"
	end
	local gap = Constants.BUILD_FRONT_GAP * Constants.CELL
	if team == "red" and mx.X > front - gap then
		return false, "Only on your own turf"
	elseif team == "blue" and mn.X < front + gap then
		return false, "Only on your own turf"
	end
	-- reach
	local c = player.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	if r then
		local center = (mn + mx) / 2
		if (Vector3.new(center.X, r.Position.Y, center.Z) - r.Position).Magnitude > Constants.BUILD_REACH then
			return false, "Too far away"
		end
	end
	-- nothing in the way
	for _, cell in cellsOf(cx, cz, w, d) do
		if occupied[cell[1]] and occupied[cell[1]][cell[2]] then
			return false, "Something's already there"
		end
	end
	-- the map: a little overlap at the edges is fine (BUILD_MAP_OVERLAP studs a side), not standing in a shape
	local pad = Vector3.new(Constants.BUILD_MAP_OVERLAP, 0, Constants.BUILD_MAP_OVERLAP)
	for _, s in a.solids do
		if
			s.part ~= a.strips[1] and Formulas.boxesOverlap(mn + pad + Vector3.new(0, 0.6, 0), mx - pad, s.min, s.max)
		then
			return false, "Blocked by the map"
		end
	end
	-- the lane rule: every row (each X column of cells) keeps an open cell across the field
	if def.blocks then
		local extra = {}
		for _, cell in cellsOf(cx, cz, w, d) do
			extra[cell[1] .. ":" .. cell[2]] = true
		end
		local _, z0 = Formulas.cellOf(0, -a.width / 2 + 0.01)
		local _, z1 = Formulas.cellOf(0, a.width / 2 - 0.01)
		for x = cx, cx + w - 1 do
			local free = 0
			for z = z0, z1 do
				if not blockedCell(a, x, z, extra) then
					free += 1
				end
			end
			if free < 2 then
				return false, "That would wall off the whole field"
			end
		end
	end
	return true, nil, def, cx, cz, w, d, rot
end

-- How a piece joins the same team's pieces touching it (StructureModel.joins), from the grid
local function pieceAt(cx, cz)
	local id = occupied[cx] and occupied[cx][cz]
	return id and structures[id]
end

local function joinsOf(s)
	return StructureModel.joins(s, pieceAt)
end

-- The same team's pieces touching this one's sides and ends (its neighbours by the cells round it)
local function neighbours(s)
	local out, seen = {}, {}
	local function look(x, z)
		local n = pieceAt(x, z)
		if n and n ~= s and n.team == s.team and not seen[n] then
			seen[n] = true
			table.insert(out, n)
		end
	end
	for x = s.cx, s.cx + s.w - 1 do
		look(x, s.cz - 1)
		look(x, s.cz + s.d)
	end
	for z = s.cz, s.cz + s.d - 1 do
		look(s.cx - 1, z)
		look(s.cx + s.w, z)
	end
	return out
end

-- The piece's parts in its model: StructureModel's (stone, wood and iron with the team's colour on them, shaped by
-- its joins), the builder's banner emblem on any flag, the Rally Banner's light
local function addParts(model, s, def, joins)
	local banner = Cosmetics.get(s.emblemKey)
	for _, spec in StructureModel.parts(def.key, s.team, s.min, s.max, joins) do
		local p = StructureModel.make(spec, s.team)
		if spec.flag and banner and banner.kind == "banner" then
			-- the emblem of the banner the builder wears (Data/Cosmetics), white on the flag, both faces
			local wide = spec.size.X >= spec.size.Z
			for _, face in
				wide and { Enum.NormalId.Front, Enum.NormalId.Back } or { Enum.NormalId.Left, Enum.NormalId.Right }
			do
				local sg = Instance.new("SurfaceGui")
				sg.Name = "Emblem"
				sg.Face = face
				sg.CanvasSize = Vector2.new(120, 200)
				local l = Instance.new("TextLabel")
				l.BackgroundTransparency = 1
				l.Size = UDim2.fromScale(1, 1)
				l.Text = banner.look.emblem
				l.TextScaled = true
				l.Font = Enum.Font.GothamBlack
				l.TextColor3 = Constants.WHITE
				l.Parent = sg
				sg.Parent = p
			end
		end
		if spec.glow then
			-- (the Rally Banner's marker: a soft light in the team's colour on the glowing square)
			local light = Instance.new("PointLight")
			light.Color = StructureModel.color("team", s.team)
			light.Range = 10
			light.Brightness = 1.2
			light.Shadows = false
			light.Parent = p
		end
		p.Parent = model
	end
end

-- The piece in the world: its parts, and the Rally Banner's tag
local function buildModel(s, def, joins)
	local model = Instance.new("Model")
	model.Name = "S" .. s.id
	model:SetAttribute("StructureId", s.id)
	model:SetAttribute("Team", s.team)
	model:SetAttribute("Key", def.key)
	addParts(model, s, def, joins)
	if def.rally then
		-- a small RALLY tag over it, so a team-mate (and the enemy hunting it) can find it
		local top = model:FindFirstChild("Pole")
		if top then
			local bb = Instance.new("BillboardGui")
			bb.Name = "RallyTag"
			bb.Size = UDim2.fromOffset(84, 22)
			bb.StudsOffset = Vector3.new(0, top.Size.Y / 2 + 2, 0)
			bb.MaxDistance = 160
			bb.LightInfluence = 0
			local l = Instance.new("TextLabel")
			l.BackgroundTransparency = 1
			l.Size = UDim2.fromScale(1, 1)
			l.Text = "⚑ RALLY"
			l.TextScaled = true
			l.Font = Enum.Font.GothamBlack
			l.TextColor3 = StructureModel.color("team", s.team)
			l.TextStrokeColor3 = Constants.WHITE
			l.TextStrokeTransparency = 0.2
			l.Parent = bb
			bb.Parent = top
		end
	end
	model.Parent = folder
	return model
end

local function lookOf(s)
	return { id = s.id, team = s.team, min = s.boxMin, max = s.boxMax, emblemKey = s.emblemKey }
end

-- A neighbour went up or came down: if that changes how this piece joins, its parts are made again (only how it
-- looks: its box, so the building rules, the bots and the arrows' first test, stays the same, and the arrows' list
-- of its solid parts is the same table, refilled)
local function reshape(s)
	local joins = joinsOf(s)
	local key = StructureModel.joinsKey(joins)
	if not s.model or key == (s.joinsKey or "") then
		return
	end
	s.joins, s.joinsKey = joins, key
	for _, p in s.model:GetChildren() do
		if p:IsA("BasePart") then
			p:Destroy()
		end
	end
	addParts(s.model, lookOf(s), Structures.get(s.key), joins)
	table.clear(s.solid)
	for _, p in s.model:GetChildren() do
		if p:IsA("BasePart") then
			if s.hp < s.max then
				p.Transparency = (1 - math.clamp(s.hp / s.max, 0, 1)) * 0.35 -- (as worn as it was: Hit)
			end
			if p.CanCollide then
				table.insert(s.solid, p)
			end
		end
	end
end

-- A message for everyone on a team (a toast under the HUD)
local function tellTeam(team, text, kind)
	for _, p in teams:Members(team) do
		Net.fire(p, "Toast", text, kind)
	end
end

-- Is this structure still on its own team's side of the line?
local function onTurf(s, front)
	if s.team == "red" then
		return s.boxMax.X <= front + 0.01
	end
	return s.boxMin.X >= front - 0.01
end

-- The team's Rally Banner (the newest, if ever there were two), standing on its own turf; any: whatever the line
function BuildService:Rally(team, any)
	local front = frontlineOf and frontlineOf() or 0
	local best
	for _, s in structures do
		local def = Structures.get(s.key)
		if s.team == team and def and def.rally and (any or onTurf(s, front)) and (not best or s.id > best.id) then
			best = s
		end
	end
	return best
end

-- Where someone on that team comes back beside their Rally Banner: a free cell round it (toward home first, then
-- the sides, the front last), or nil when there's none (or no banner): the spawn room then.
function BuildService:RallySpawn(player)
	local team = teams:Team(player)
	local s = team and self:Rally(team)
	local a = arena:Current()
	if not (s and a) then
		return nil
	end
	local front = frontlineOf and frontlineOf() or 0
	local fwd = Formulas.forward(team)
	local cells = {}
	for dx = -2, 2 do
		for dz = -2, 2 do
			if dx ~= 0 or dz ~= 0 then
				table.insert(cells, { s.cx + dx, s.cz + dz, dx * fwd * 10 + math.abs(dz) + math.abs(dx) })
			end
		end
	end
	table.sort(cells, function(p, q)
		return p[3] < q[3]
	end)
	local solids = arena:Solids()
	local edge = Vector3.new(0.4, 0, 0.4)
	for _, cell in cells do
		local x, z = cell[1], cell[2]
		local mn, mx = Formulas.footprintBox(x, z, 1, 1, 0.3, 5.7)
		local mid = (mn + mx) / 2
		local free = not (occupied[x] and occupied[x][z])
			and not (a.blocked[x] and a.blocked[x][z])
			and math.abs(mid.X) <= a.half - 2
			and math.abs(mid.Z) <= a.width / 2 - 2
			and (front - mid.X) * fwd >= Constants.CELL -- (a cell back from the line, at least)
		if free then
			for _, b in solids do
				if b.part ~= a.strips[1] and Formulas.boxesOverlap(mn + edge, mx - edge, b.min, b.max) then
					free = false
					break
				end
			end
		end
		if free then
			-- (the deck under it: a ray down finds the floor, not something on it; where the engine has no rays,
			-- the field's floor covers every cell inside it)
			local ok, hit = pcall(function()
				return workspace:Raycast(Vector3.new(mid.X, 8, mid.Z), Vector3.new(0, -12, 0))
			end)
			if ok and hit and math.abs(hit.Position.Y) > 1 then
				free = false
			end
		end
		if free then
			return CFrame.new(mid.X, 3.5, mid.Z)
		end
	end
	return nil
end

function BuildService:Place(player, key, cx, cz, rot)
	local ok, why, def, x, z, w, d, r = self:Check(player, key, cx, cz, rot)
	if not ok then
		return false, why
	end
	nextId += 1
	local mn, mx = Formulas.footprintBox(x, z, w, d, 0, def.h)
	local s = {
		id = nextId,
		key = def.key,
		team = teams:Team(player),
		owner = player,
		cx = x,
		cz = z,
		w = w,
		d = d,
		rot = r,
		hp = def.hp,
		max = def.hp,
		boxMin = mn,
		boxMax = mx,
		emblemKey = player:GetAttribute("LookBanner"),
	}
	structures[s.id] = s
	for _, cell in cellsOf(x, z, w, d) do
		occupied[cell[1]] = occupied[cell[1]] or {}
		occupied[cell[1]][cell[2]] = s.id
	end
	-- (joined up with the same team's pieces touching it, and they with it)
	s.joins = joinsOf(s)
	s.joinsKey = StructureModel.joinsKey(s.joins)
	s.model = buildModel(lookOf(s), def, s.joins)
	local solid = {}
	for _, p in s.model:GetDescendants() do
		if p:IsA("BasePart") and p.CanCollide then
			table.insert(solid, p)
		end
	end
	s.solid = solid
	arena:AddBox(s.id, mn, mx, #solid > 0 and solid or nil)
	for _, n in neighbours(s) do
		reshape(n)
	end
	budgets[player] = self:Budget(player) - def.cost
	self:Push(player)
	Net.fireAll("Structure", { kind = "built", id = s.id, key = def.key, team = s.team, hp = s.hp, max = s.max })
	if def.rally then
		tellTeam(s.team, "Rally Banner up! Your team respawns there", "good")
	end
	self.Built:Fire(player, s)
	return true, s
end

-- Take a structure down. blast = { pos, power } (what broke it) goes out with the "destroyed" message so every client
-- can throw the debris away from it (DebrisController); a refund (your own, taken back) just goes.
function BuildService:Remove(id, attacker, refund, blast)
	local s = structures[id]
	if not s then
		return false
	end
	structures[id] = nil
	for _, cell in cellsOf(s.cx, s.cz, s.w, s.d) do
		if occupied[cell[1]] then
			occupied[cell[1]][cell[2]] = nil
		end
	end
	arena:RemoveBox(id)
	if s.model then
		s.model:Destroy()
	end
	if not clearing then
		-- (what it was joined to finishes its ends again)
		for _, n in neighbours(s) do
			reshape(n)
		end
	end
	local def = Structures.get(s.key)
	if def and def.rally and not clearing then
		tellTeam(
			s.team,
			refund and "Rally Banner taken down: back to the spawn room"
				or "Your Rally Banner fell! Back to the spawn room",
			refund and "info" or "bad"
		)
	end
	if refund and s.owner and s.owner.Parent then
		budgets[s.owner] = math.min(Constants.BUILD_BUDGET, self:Budget(s.owner) + def.cost)
		self:Push(s.owner)
	end
	Net.fireAll("Structure", {
		kind = "destroyed",
		id = id,
		key = s.key,
		team = s.team,
		min = s.boxMin,
		max = s.boxMax,
		rot = s.rot,
		joins = s.joins, -- (the shape it had: the debris breaks the same parts)
		refund = refund == true or nil,
		quiet = clearing or nil, -- (the arena is being cleared: no debris)
		blast = blast,
	})
	if not refund then
		self.Destroyed:Fire(s, attacker)
	end
	return true
end

function BuildService:Hit(id, damage, attacker, blast)
	local s = structures[id]
	if not s then
		return
	end
	local from = (attacker and teams:Team(attacker)) or (blast and blast.team)
	if from == s.team then
		return -- (your own arrows and TNT don't break your team's walls)
	end
	s.hp -= damage
	if s.hp <= 0 then
		self:Remove(id, attacker, false, blast)
	else
		Net.fireAll("Structure", { kind = "damaged", id = id, key = s.key, team = s.team, hp = s.hp, max = s.max })
		if s.model then
			-- (it fades a little as it breaks)
			local f = math.clamp(s.hp / s.max, 0, 1)
			for _, p in s.model:GetChildren() do
				if p:IsA("BasePart") then
					p.Transparency = (1 - f) * 0.35
				end
			end
		end
	end
end

-- The line moved: whatever a team had built on turf it just lost comes down (any part of it over the line).
-- Returns how many fell.
function BuildService:ClearLost(frontline)
	local gone = 0
	for id, s in structures do
		local lost = (s.team == "red" and s.boxMax and s.boxMax.X > frontline + 0.01)
			or (s.team == "blue" and s.boxMin and s.boxMin.X < frontline - 0.01)
		if lost then
			self:Remove(id, nil, false)
			gone += 1
		end
	end
	return gone
end

function BuildService:Clear()
	clearing = true
	for id in structures do
		self:Remove(id, nil, false)
	end
	clearing = false
	structures, occupied = {}, {}
end

function BuildService:All()
	return structures
end

function BuildService:Init(registry)
	teams = registry.TeamService
	arena = registry.ArenaService
	combat = registry.CombatService
	folder = Instance.new("Folder")
	folder.Name = "Structures"
	folder.Parent = workspace
	Net.on("Build", function(player, key, cx, cz, rot)
		local ok, why = self:Place(player, key, cx, cz, rot)
		if not ok and why then
			Net.fire(player, "Toast", why, "bad")
		end
	end)
	Net.on("Demolish", function(player, id)
		local s = structures[id]
		if open and s and s.owner == player then
			self:Remove(id, nil, true)
		end
	end)
	combat.StructureHit:Connect(function(id, damage, attacker, blast)
		self:Hit(id, damage, attacker, blast)
	end)
	Players.PlayerRemoving:Connect(function(player)
		budgets[player] = nil
	end)
end

return BuildService
