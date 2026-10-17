--[[
The arena in the world (master plan §4): builds the current map (World/ArenaBuilder + its layout), lights it in the
SUPERHOT way (white haze, soft grey shadows, the map's own light), paints the turf for the frontline, and answers
the geometry questions the other services ask:

  ArenaService:Load(mapKey)        tear down the old arena, build this one
  ArenaService:Current()           the arena table (ArenaBuilder.build's)
  ArenaService:Paint(frontline, team?)   team: who pushed it last (the glowing line's colour)
  ArenaService:Solids()            the map's solid boxes plus every standing structure's
  ArenaService:SpawnFor(team, i)   a spawn CFrame
  ArenaService:LoseLine(team)      where the frontline ends that team
  ArenaService:Inside(pos)         inside the playable box
  ArenaService:ClearTemplate()     (at start) removes a template's Baseplate and SpawnLocation
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
local extra = {} -- [id] = { min, max } the structures' boxes (BuildService keeps them here)
local spawnTurn = { red = 0, blue = 0 }

local function light(def)
	local l = def.lighting or {}
	Lighting.Ambient = l.ambient or Color3.fromRGB(170, 170, 172)
	Lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 204)
	Lighting.Brightness = l.brightness or 2.6
	Lighting.ClockTime = l.clock or 14
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.2
	Lighting.FogColor = Color3.fromRGB(245, 245, 247)
	Lighting.FogEnd = 1200
	pcall(function()
		Lighting.ShadowSoftness = 0.6
	end)
	-- a white sky: an atmosphere thick with white haze
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmo.Density = 0.32
	atmo.Offset = 0.1
	atmo.Color = Color3.fromRGB(250, 250, 252)
	atmo.Decay = Color3.fromRGB(235, 236, 240)
	atmo.Glare = 0
	atmo.Haze = l.haze or 1.2
	atmo.Parent = Lighting
	local cc = Lighting:FindFirstChild("Grade") or Instance.new("ColorCorrectionEffect")
	cc.Name = "Grade"
	cc.Saturation = 0.15 -- (the reds and blues pop; the whites stay white)
	cc.Contrast = 0.08
	cc.Brightness = 0.03
	cc.Parent = Lighting
end

function ArenaService:Load(mapKey)
	local def = Maps.get(mapKey) or Maps.list[1]
	if arena and arena.folder then
		arena.folder:Destroy()
	end
	extra = {}
	spawnTurn = { red = 0, blue = 0 }
	arena = ArenaBuilder.build(def, workspace)
	light(def)
	workspace:SetAttribute("MapKey", def.key)
	workspace:SetAttribute("MapName", def.name)
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

function ArenaService:AddBox(id, mn, mx)
	extra[id] = { min = mn, max = mx, id = id }
end

function ArenaService:RemoveBox(id)
	extra[id] = nil
end

-- Every solid box: the map's and the structures'.
function ArenaService:Solids()
	local out = {}
	for _, s in arena and arena.solids or {} do
		table.insert(out, s)
	end
	for _, s in extra do
		table.insert(out, s)
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

function ArenaService:LoseLine(team)
	return arena and ArenaBuilder.loseLine(arena, team) or 0
end

function ArenaService:Inside(pos)
	if not arena then
		return true
	end
	local mn, mx = ArenaBuilder.bounds(arena)
	return pos.X >= mn.X and pos.X <= mx.X and pos.Y >= mn.Y and pos.Y <= mx.Y and pos.Z >= mn.Z and pos.Z <= mx.Z
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
