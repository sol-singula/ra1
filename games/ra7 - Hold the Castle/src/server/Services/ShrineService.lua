--[[
The three shrines (master plan §4 step 5, §6). Only the shrine the monsters are after can fall. Four times a
second during the fight it counts who is near it (inside the glowing ring): if monsters outnumber dwarves it
drains (faster for every extra monster, slower with Shrine Wards and a grander castle); with no monster near it
slowly heals; a contested shrine with enough dwarves holds. The bar is on screen for everyone.

When a shrine falls: a flash and a sad horn for everyone, the wall of magic to the next zone opens, the monsters
spawn at the fallen shrine (after a short head start for the dwarves running back), and the dwarves get a burst
of speed. When the last one falls the monsters win.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Kit = require(ReplicatedStorage.Shared.World.Kit)
local MapLayout = require(ReplicatedStorage.Shared.World.MapLayout)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local MapBuilder = require(script.Parent.Parent.World.MapBuilder)

local ShrineService = {
	Name = "ShrineService",
	Dependencies = { "MatchService", "TeamService", "HordeService", "BuildService" },
	Fell = Signal.new("ShrineService.Fell"), -- (index)
	Draining = Signal.new("ShrineService.Draining"), -- (index, health) crossed a warning line
}

local match, teams, horde, build
local registry
local shrines = {} -- [i] = { health, state, dwarves, monsters, rate, warned = { [75] = true ... } }

local WARN_AT = { 75, Constants.SHRINE_FALLING_AT, 25 }

local function reset()
	for i = 1, #MapLayout.shrines do
		shrines[i] = { health = 100, state = "safe", dwarves = 0, monsters = 0, rate = 0, warned = {} }
	end
	for i, b in MapBuilder.barriers do
		local veil = b:FindFirstChild("Veil")
		if veil then
			veil.CanCollide = true
			veil.Transparency = 0.55
		end
		b:SetAttribute("Open", false)
		_ = i
	end
	for i, sh in MapBuilder.shrines do
		sh.crystal.Color = Kit.C.shrine
		sh.crystal.Transparency = 0
		sh.core.Transparency = 0
		local glow = sh.crystal:FindFirstChild("Glow")
		if glow then
			glow.Color = Kit.C.shrine
			glow.Brightness = 2.4
		end
		sh.fill.Size = UDim2.fromScale(1, 1)
		sh.fill.BackgroundColor3 = Kit.C.shrine
		sh.model:SetAttribute("Health", 100)
		sh.model:SetAttribute("State", "safe")
		for _, tile in sh.ring do
			tile.Color = Kit.C.shrine
		end
		_ = i
	end
end

function ShrineService:State(i)
	return shrines[i]
end

function ShrineService:Health(i)
	return shrines[i] and shrines[i].health or 0
end

function ShrineService:View()
	local out = {}
	for i, s in shrines do
		out[i] = {
			health = math.floor(s.health * 10) / 10,
			state = s.state,
			dwarves = s.dwarves,
			monsters = s.monsters,
			rate = math.floor(s.rate * 100) / 100,
			wards = build:Wards(i),
			stage = build:Stage(i),
		}
	end
	return out
end

-- Who is near a shrine: players by team (inside the ring, about level with it) and NPCs.
function ShrineService:CountNear(i)
	local s = MapLayout.shrines[i]
	local R = Constants.SHRINE_RADIUS
	local d, m = 0, 0
	for _, p in teams:Players("dwarf") do
		local pos = teams:Position(p)
		if pos and Vector2.new(pos.X - s.pos.X, pos.Z - s.pos.Z).Magnitude <= R and math.abs(pos.Y - s.pos.Y) < 16 then
			d += 1
		end
	end
	for _, p in teams:Players("monster") do
		local pos = teams:Position(p)
		if pos and Vector2.new(pos.X - s.pos.X, pos.Z - s.pos.Z).Magnitude <= R and math.abs(pos.Y - s.pos.Y) < 16 then
			m += 1
		end
	end
	local nd, nm = horde:CountNear(s.pos, R)
	return d + nd, m + nm
end

local function paint(i)
	local s = shrines[i]
	local sh = MapBuilder.shrines[i]
	if not sh then
		return
	end
	local frac = math.clamp(s.health / 100, 0, 1)
	local color = s.state == "fallen" and Kit.rgb(70, 64, 80)
		or Kit.C.plague:Lerp(Kit.C.shrine, frac):Lerp(Kit.C.red, (1 - frac) * 0.6)
	sh.crystal.Color = color
	local glow = sh.crystal:FindFirstChild("Glow")
	if glow then
		glow.Color = color
		glow.Brightness = s.state == "fallen" and 0 or 1 + frac * 1.6
	end
	sh.fill.Size = UDim2.fromScale(frac, 1)
	sh.fill.BackgroundColor3 = color
	sh.model:SetAttribute("Health", s.health)
	sh.model:SetAttribute("State", s.state)
	if s.state == "fallen" then
		sh.core.Transparency = 1
		for _, tile in sh.ring do
			tile.Color = Kit.rgb(90, 80, 100)
		end
	end
end

function ShrineService:_fall(i)
	local s = shrines[i]
	s.state = "fallen"
	s.health = 0
	paint(i)
	local pos = MapLayout.shrines[i].pos
	Net.fireAll("Fx", "shrineFall", { index = i, position = pos })
	Net.fireAll("Sfx", "shrineLost")
	-- the way on opens (for the monsters, too)
	local b = MapBuilder.barriers[i]
	if b then
		local veil = b:FindFirstChild("Veil")
		if veil then
			veil.CanCollide = false
			veil.Transparency = 1
		end
		b:SetAttribute("Open", true)
	end
	if i < 3 then
		Net.fireAll("Callout", `Shrine {i} has fallen! Run to Shrine {i + 1}!`, "fallen")
		local combat = registry.CombatService
		for _, p in teams:Players("dwarf") do
			if combat then
				combat:Boost(p, Constants.RETREAT_BOOST, Constants.RETREAT_BOOST_SECONDS)
			end
		end
		-- the monsters who took it get the credit
		for _, p in teams:Players("monster") do
			local pp = teams:Position(p)
			if pp and (pp - pos).Magnitude <= Constants.SHRINE_RADIUS * 2.5 then
				teams:Stat(p, "shrines", 1)
				teams:AddMonsterXp(p, 30)
			end
		end
		shrines[i + 1].state = "active"
		paint(i + 1)
	else
		Net.fireAll("Callout", "The last shrine has fallen!", "fallen")
	end
	self.Fell:Fire(i)
	match:ShrineFall(i)
end

function ShrineService:_tick(dt)
	if not (match:Phase() == "fight" or match:Phase() == "laststand") then
		return
	end
	local active = match:ActiveShrine()
	for i, s in shrines do
		if i < active then
			if s.state ~= "fallen" then
				s.state = "fallen"
				paint(i)
			end
		elseif i == active then
			s.state = "active"
			local d, m = self:CountNear(i)
			s.dwarves, s.monsters = d, m
			s.rate = Formulas.shrineRate(d, m, build:Wards(i), build:Stage(i))
			local before = s.health
			s.health = math.clamp(s.health + s.rate * dt, 0, 100)
			if s.health < before then
				for _, line in WARN_AT do
					if before >= line and s.health < line and not s.warned[line] then
						s.warned[line] = true
						Net.fireAll("Callout", `Shrine {i} is falling! {math.floor(line)}% left!`, "falling")
						Net.fireAll("Sfx", "horn")
						self.Draining:Fire(i, s.health)
					end
				end
			elseif s.health > 80 then
				s.warned = {}
			end
			paint(i)
			if s.health <= 0 then
				self:_fall(i)
				return
			end
		else
			s.state = "safe"
			s.dwarves, s.monsters = 0, 0
		end
	end
end

function ShrineService:Init(reg)
	registry = reg
	match = reg.MatchService
	teams = reg.TeamService
	horde = reg.HordeService
	build = reg.BuildService
	reset()
	match.Started:Connect(reset)
	match.Reset:Connect(reset)
	match.FightStarted:Connect(function()
		shrines[match:ActiveShrine()].state = "active"
		paint(match:ActiveShrine())
	end)
end

function ShrineService:Start()
	local acc = 0
	while true do
		task.wait(0.25)
		local ok, err = pcall(self._tick, self, 0.25)
		if not ok then
			warn("[ShrineService] " .. tostring(err))
		end
		acc += 1
		if acc >= 1 then
			acc = 0
			Net.fireAll("Shrines", self:View())
		end
	end
end

function ShrineService:OnPlayerReady(player)
	Net.fire(player, "Shrines", self:View())
end

return ShrineService
