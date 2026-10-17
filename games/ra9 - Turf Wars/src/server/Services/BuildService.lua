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

  BuildService:Place(player, key, cx, cz, rot) -> ok, why
  BuildService:Refill()                 the budgets, at each build phase
  BuildService:Clear()                  between matches
  BuildService:Budget(player)
  BuildService:All()                    { [id] = structure }
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
	Dependencies = { "TeamService", "ArenaService", "CombatService" },
	Built = Signal.new("BuildService.Built"), -- (player, structure)
	Destroyed = Signal.new("BuildService.Destroyed"), -- (structure, attacker?)
}

local teams, arena, combat
local structures = {} -- [id] = { id, key, team, owner, cx, cz, w, d, rot, hp, max, model, boxMin, boxMax }
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

-- The piece in the world: StructureModel's parts (one shade of the team's colour, the Reinforced Wall darker), the
-- builder's banner emblem on any flag
local function buildModel(s, def)
	local model = Instance.new("Model")
	model.Name = "S" .. s.id
	model:SetAttribute("StructureId", s.id)
	model:SetAttribute("Team", s.team)
	model:SetAttribute("Key", def.key)
	local banner = Cosmetics.get(s.emblemKey)
	for _, spec in StructureModel.parts(def.key, s.team, s.min, s.max) do
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
		p.Parent = model
	end
	model.Parent = folder
	return model
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
	}
	structures[s.id] = s
	for _, cell in cellsOf(x, z, w, d) do
		occupied[cell[1]] = occupied[cell[1]] or {}
		occupied[cell[1]][cell[2]] = s.id
	end
	s.model =
		buildModel({ id = s.id, team = s.team, min = mn, max = mx, emblemKey = player:GetAttribute("LookBanner") }, def)
	local solid = {}
	for _, p in s.model:GetDescendants() do
		if p:IsA("BasePart") and p.CanCollide then
			table.insert(solid, p)
		end
	end
	arena:AddBox(s.id, mn, mx, #solid > 0 and solid or nil)
	budgets[player] = self:Budget(player) - def.cost
	self:Push(player)
	Net.fireAll("Structure", { kind = "built", id = s.id, key = def.key, team = s.team, hp = s.hp, max = s.max })
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
	if refund and s.owner and s.owner.Parent then
		local def = Structures.get(s.key)
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
