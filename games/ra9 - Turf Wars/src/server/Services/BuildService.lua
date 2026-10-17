--[[
Construction (master plan §2B, §7): modular structures on the 4-stud grid, in the build phase only.

A placement is checked here, never trusted from the client: the phase; the structure exists; your budget covers it
and your team is under its cap; you're within BUILD_REACH; every cell of its footprint is on your own turf, at least
up to the frontline (BUILD_FRONT_GAP cells back; 0 = the cell touching it too), out of both spawn zones and inside the field; it doesn't overlap the
map's shapes or another structure; and if it's a tall piece, every row of cells across the field it stands in still
has an open cell (no wall ever seals the battlefield). Then it's built for everyone in its team's colour.

Structures last the match (they're cleared with the arena) unless arrows break them: CombatService reports hits on
their boxes (StructureHit) and they lose durability. In the build phase you can take back your own (Demolish) for
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
		if a.blocked[cell[1]] and a.blocked[cell[1]][cell[2]] then
			return false, "Blocked by the map"
		end
	end
	local pad = Vector3.new(0.05, 0, 0.05)
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

local function buildModel(s, def)
	local color = Constants.TEAM_COLOR[s.team]
	local model = Instance.new("Model")
	model.Name = "S" .. s.id
	model:SetAttribute("StructureId", s.id)
	model:SetAttribute("Team", s.team)
	local function part(cf, size, c, solid)
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = size
		p.CFrame = cf
		p.Material = Enum.Material.SmoothPlastic
		p.Color = c
		p.CanCollide = solid ~= false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	local size = s.max - s.min
	local center = (s.min + s.max) / 2
	local white = Constants.WHITE
	local tint = color:Lerp(white, 0.35)
	if def.key == "banner" then
		part(CFrame.new(center.X, def.h / 2, center.Z), Vector3.new(0.6, def.h, 0.6), white)
		local flag = part(CFrame.new(center.X + 1.2, def.h - 2.5, center.Z), Vector3.new(2.4, 4, 0.2), color, false)
		-- the emblem of the banner the builder wears (Data/Cosmetics), white on the flag, both faces
		local banner = Cosmetics.get(s.emblemKey)
		if banner and banner.kind == "banner" then
			for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
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
				l.TextColor3 = white
				l.Parent = sg
				sg.Parent = flag
			end
		end
		part(CFrame.new(center.X, 0.3, center.Z), Vector3.new(2.4, 0.6, 2.4), white)
	elseif def.key == "tower" then
		-- four legs, a platform, a team-coloured rail round the top, a ladder face
		local hx, hz = size.X / 2 - 0.6, size.Z / 2 - 0.6
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				part(CFrame.new(center.X + sx * hx, def.h / 2, center.Z + sz * hz), Vector3.new(1.2, def.h, 1.2), white)
			end
		end
		part(CFrame.new(center.X, def.h - 0.5, center.Z), Vector3.new(size.X, 1, size.Z), tint)
		for _, sz in { -1, 1 } do
			part(
				CFrame.new(center.X, def.h + 1, center.Z + sz * (size.Z / 2 - 0.2)),
				Vector3.new(size.X, 2, 0.4),
				color
			)
		end
		for i = 1, 5 do
			part(CFrame.new(center.X, i * 2, center.Z), Vector3.new(size.X - 2.4, 0.4, 0.4), white)
		end
		part(CFrame.new(center.X, def.h / 2, center.Z), Vector3.new(size.X - 2.4, def.h - 1, size.Z - 2.4), tint, true)
	elseif def.key == "bridge" then
		part(CFrame.new(center.X, def.h - 0.5, center.Z), Vector3.new(size.X, 1, size.Z), tint)
		for _, sz in { -1, 1 } do
			part(
				CFrame.new(center.X, (def.h - 1) / 2, center.Z + sz * (size.Z / 2 - 0.6)),
				Vector3.new(size.X - 0.4, def.h - 1, 1.2),
				white
			)
		end
	else
		-- walls, barricades, cover: a slab in a light tint of the team colour, a white cap, a coloured stripe
		part(CFrame.new(center.X, def.h / 2, center.Z), Vector3.new(size.X, def.h, size.Z), tint)
		part(CFrame.new(center.X, def.h + 0.2, center.Z), Vector3.new(size.X + 0.3, 0.4, size.Z + 0.3), white)
		part(CFrame.new(center.X, def.h * 0.6, center.Z), Vector3.new(size.X + 0.05, 0.5, size.Z + 0.05), color, false)
		if def.key == "reinforced" then
			for _, sx in { -1, 1 } do
				part(
					CFrame.new(center.X + sx * (size.X / 2 - 0.4), def.h / 2, center.Z),
					Vector3.new(0.9, def.h, size.Z + 0.4),
					white
				)
			end
		end
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
	arena:AddBox(s.id, mn, mx)
	budgets[player] = self:Budget(player) - def.cost
	self:Push(player)
	Net.fireAll("Structure", { kind = "built", id = s.id, key = def.key, team = s.team, hp = s.hp, max = s.max })
	self.Built:Fire(player, s)
	return true, s
end

function BuildService:Remove(id, attacker, refund)
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
	Net.fireAll("Structure", { kind = "destroyed", id = id, key = s.key, team = s.team })
	if not refund then
		self.Destroyed:Fire(s, attacker)
	end
	return true
end

function BuildService:Hit(id, damage, attacker)
	local s = structures[id]
	if not s then
		return
	end
	if attacker and teams:Team(attacker) == s.team then
		return -- (your own arrows don't break your team's walls)
	end
	s.hp -= damage
	if s.hp <= 0 then
		self:Remove(id, attacker, false)
	else
		Net.fireAll("Structure", { kind = "damaged", id = id, key = s.key, team = s.team, hp = s.hp, max = s.max })
		if s.model then
			-- (it fades toward white as it breaks)
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
	for id in structures do
		self:Remove(id, nil, false)
	end
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
	combat.StructureHit:Connect(function(id, damage, attacker)
		self:Hit(id, damage, attacker)
	end)
	Players.PlayerRemoving:Connect(function(player)
		budgets[player] = nil
	end)
end

return BuildService
