--[[
The arena in the world (master plan §4): builds the current map (World/ArenaBuilder + its layout), lights it in the
SUPERHOT way (white haze, soft grey shadows, the map's own light), paints the turf for the frontline, and answers
the geometry questions the other services ask:

  ArenaService:Load(mapKey, size?) tear down the old arena, build this one; size: how many are in the match (or a
                                   tier's name), which picks the arena's size (ArenaBuilder.SIZES)
  ArenaService:Current()           the arena table (ArenaBuilder.build's)
  ArenaService:Collide()           every box a body bumps into: the map's (solid or not) and the structures'
  ArenaService.version             goes up whenever the arena or a structure's box changes (the bots re-plan)
  ArenaService:Paint(frontline, team?)   team: who pushed it last (the glowing line's colour)
  ArenaService:Solids()            the map's solid boxes plus every standing structure's
  ArenaService:SpawnFor(team, i)   a spawn CFrame
  ArenaService:LoseLine(team)      where the frontline ends that team
  ArenaService:Inside(pos)         inside the playable box
  ArenaService:ClearTemplate()     (at start) removes a template's Baseplate and SpawnLocation
  ArenaService:AddArena(key, arena) / :RemoveArena(key)   another arena beside the main one (a duel's, far out past
                                   the plaza: World/DuelArena, with its origin): its solids count for every arrow
                                   and slash, its box is inside the world, its decks are safe
]]
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaBuilder = require(ReplicatedStorage.Shared.World.ArenaBuilder)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Signal = require(ReplicatedStorage.Shared.Signal)

local ArenaService = {
	Name = "ArenaService",
	Dependencies = {},
	Loaded = Signal.new("ArenaService.Loaded"), -- (arena)
}

local arena
ArenaService.version = 0
local extra = {} -- [id] = { min, max } the structures' boxes (BuildService keeps them here)
local others = {} -- [key] = an arena beside the main one (a duel's), its boxes already where it stands
local spawnTurn = { red = 0, blue = 0 }

-- Matte, not glowing: a softer sun and less fill light, so the white world reads as white plaster that catches
-- shadow (the bright whites used to burn out on screen), and no shine off the surfaces.
local function light(def)
	local l = def.lighting or {}
	local amb = l.ambient or Color3.fromRGB(170, 170, 172)
	Lighting.Ambient = amb:Lerp(Color3.new(0, 0, 0), 0.32)
	Lighting.OutdoorAmbient = Color3.fromRGB(138, 138, 142)
	Lighting.Brightness = (l.brightness or 2.6) * 0.62
	Lighting.ClockTime = l.clock or 14
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0.35
	Lighting.EnvironmentSpecularScale = 0.04
	Lighting.ExposureCompensation = -0.25
	Lighting.FogColor = Color3.fromRGB(232, 232, 236)
	Lighting.FogEnd = 1200
	pcall(function()
		Lighting.ShadowSoftness = 0.3 -- (crisper shadows: the geometry reads)
	end)
	-- a pale sky: an atmosphere with a light haze
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmo.Density = 0.3
	atmo.Offset = 0.1
	atmo.Color = Color3.fromRGB(236, 236, 240)
	atmo.Decay = Color3.fromRGB(214, 216, 222)
	atmo.Glare = 0
	atmo.Haze = l.haze or 1.2
	atmo.Parent = Lighting
	local cc = Lighting:FindFirstChild("Grade") or Instance.new("ColorCorrectionEffect")
	cc.Name = "Grade"
	cc.Saturation = 0.15 -- (the reds and blues pop; the whites stay white)
	cc.Contrast = 0.12
	cc.Brightness = -0.03
	cc.Parent = Lighting
end

function ArenaService:Load(mapKey, size)
	local def = Maps.get(mapKey) or Maps.list[1]
	if arena and arena.folder then
		arena.folder:Destroy()
	end
	extra = {}
	spawnTurn = { red = 0, blue = 0 }
	arena = ArenaBuilder.build(def, workspace, size)
	self.version += 1
	light(def)
	workspace:SetAttribute("MapKey", def.key)
	workspace:SetAttribute("MapName", def.name)
	workspace:SetAttribute("MapSize", arena.tier)
	self.Loaded:Fire(arena)
	return arena
end

function ArenaService:Current()
	return arena
end

function ArenaService:Paint(frontline, team)
	if arena then
		ArenaBuilder.paint(arena, frontline, team)
	end
end

-- parts: the solid parts inside the box (arrows test those, so they fly through the gaps), or nil for a plain box
function ArenaService:AddBox(id, mn, mx, parts)
	extra[id] = { min = mn, max = mx, id = id, parts = parts }
	self.version += 1
end

function ArenaService:RemoveBox(id)
	if extra[id] then
		extra[id] = nil
		self.version += 1
	end
end

-- Another arena beside the main one (a duel's): its boxes are already where it stands (World/DuelArena moves them)
function ArenaService:AddArena(key, a)
	others[key] = a
	self.version += 1
end

function ArenaService:RemoveArena(key)
	if others[key] then
		others[key] = nil
		self.version += 1
	end
end

-- Every solid box: the map's, the structures' and the other arenas'.
function ArenaService:Solids()
	local out = {}
	for _, s in arena and arena.solids or {} do
		table.insert(out, s)
	end
	for _, s in extra do
		table.insert(out, s)
	end
	for _, a in others do
		for _, s in a.solids do
			table.insert(out, s)
		end
	end
	return out
end

function ArenaService:Collide()
	local out = {}
	for _, s in arena and arena.collide or {} do
		table.insert(out, s)
	end
	for _, s in extra do
		table.insert(out, s)
	end
	for _, a in others do
		for _, s in a.collide do
			table.insert(out, s)
		end
	end
	return out
end

function ArenaService:SpawnFor(team, index)
	local list = arena and arena.spawns[team] or {}
	if #list == 0 then
		return CFrame.new(0, 5, 0)
	end
	if not index then
		spawnTurn[team] = (spawnTurn[team] % #list) + 1
		index = spawnTurn[team]
	end
	return list[(index - 1) % #list + 1]
end

-- Is this player standing on their team's spawn deck (the main arena's, or the deck of the other arena they're in)?
function ArenaService:OnDeck(player, team)
	local c = player.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	if not (r and team) then
		return false
	end
	if arena and arena.room and ArenaBuilder.inRoom(arena, team, r.Position) then
		return true
	end
	for _, a in others do
		local p = r.Position - (a.origin or Vector3.zero)
		if a.room and ArenaBuilder.inRoom(a, team, p) and math.abs(p.Z) <= a.width / 2 then
			return true
		end
	end
	return false
end

function ArenaService:LoseLine(team)
	return arena and ArenaBuilder.loseLine(arena, team) or 0
end

local function within(a, pos)
	local mn, mx = ArenaBuilder.bounds(a)
	local p = pos - (a.origin or Vector3.zero)
	return p.X >= mn.X and p.X <= mx.X and p.Y >= mn.Y and p.Y <= mx.Y and p.Z >= mn.Z and p.Z <= mx.Z
end

function ArenaService:Inside(pos)
	for _, a in others do
		if within(a, pos) then
			return true
		end
	end
	if not arena then
		return true
	end
	return within(arena, pos)
end

-- What a Roblox template leaves in the place (the grey Baseplate with its grid, the default SpawnLocation): the
-- arena is the whole world, so they go.
function ArenaService:ClearTemplate()
	local gone = 0
	for _, d in workspace:GetChildren() do
		if (d:IsA("BasePart") and (d.Name == "Baseplate" or d:IsA("SpawnLocation"))) or d.Name == "Baseplate" then
			d:Destroy()
			gone += 1
		end
	end
	pcall(function()
		workspace.Terrain:Clear()
	end)
	return gone
end

function ArenaService:Init()
	self:ClearTemplate()
end

return ArenaService
