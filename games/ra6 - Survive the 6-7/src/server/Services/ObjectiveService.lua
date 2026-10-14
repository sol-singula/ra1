--[[
What to do next (master plan §12: one primary objective at a time, optional ones shown apart; players should never
need to guess where to go). Worked out for each player every second from the state of the run, and sent when it
changes, with compass markers (the camp, the findings you know, downed teammates, a supply drop, Mega Kermy).

  primary   the guide's step (new players), else: survive the night / get back to camp / the camp's next goal
            (workbench and chest -> the Outpost -> walls -> the Fort -> stone walls -> the Stronghold -> the Totem)
  optional  explore (findings found so far), the golden pack, the supply drop, a locked chest for your key,
            the difficulty vote on day 1, the fire when it's low
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Camp = require(ReplicatedStorage.Shared.Data.Camp)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local MapLayout = require(ReplicatedStorage.Shared.World.MapLayout)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local ObjectiveService = {
	Name = "ObjectiveService",
	Dependencies = {
		"PlayerDataService",
		"RunService",
		"SurvivorService",
		"InventoryService",
		"CampService",
		"LootService",
		"MonsterService",
		"BossService",
		"WorldService",
		"TutorialService",
	},
	Completed = Signal.new("ObjectiveService.Completed"), -- (key, players) a team goal was reached
}

local data, runs, survivors, inventory, camp, loot, monsters, boss, world, tutorial
local last = {} -- [player] = encoded view (only changes are sent)
local supply -- the current supply drop container
local goalKey -- the team's current goal (to notice when it's done)

local function now()
	return workspace:GetServerTimeNow()
end

-- The camp's next goal for the team.
function ObjectiveService:CampGoal()
	local tier = camp:Tier()
	local function slotPos(key)
		for _, s in camp:Structures() do
			if s.key == key and s.state == "blueprint" then
				return s.slot.pos + Vector3.new(0, 3, 0)
			end
		end
		return nil
	end
	local board = MapLayout.CAMP_PROPS.board + Vector3.new(0, 4, 0)
	if not camp:IsBuilt("workbench") then
		return { key = "workbench", text = "Build the Workbench at camp 🛠️", target = slotPos("workbench") }
	end
	if not camp:IsBuilt("storage") then
		return { key = "storage", text = "Build the camp's Storage Chest 🧰", target = slotPos("storage") }
	end
	if tier < 2 then
		return { key = "tier2", text = "Upgrade the camp to The Outpost (Camp Board)", target = board }
	end
	local walls = camp:Count("wall")
	if walls < 8 then
		return { key = "walls", text = `Build walls round the camp 🧱 ({walls}/8)`, target = slotPos("wall") }
	end
	if tier < 3 then
		return { key = "tier3", text = "Upgrade the camp to The Fort (Camp Board)", target = board }
	end
	local stone = camp:Count("wall", true)
	if stone < 8 then
		return { key = "stone", text = `Reinforce the walls with stone ⛰️ ({stone}/8)`, target = nil }
	end
	if tier < 4 then
		return { key = "tier4", text = "Upgrade the camp to The Stronghold (Camp Board)", target = board }
	end
	if not camp:TotemBuilt() then
		return { key = "totem", text = "Raise the Totem of the Seventh Night 🗿", target = slotPos("totem") }
	end
	return { key = "ready", text = "Stock up for the 7th night: food, medicine, arrows", target = nil }
end

function ObjectiveService:_primary(player)
	local status = survivors:Status(player)
	local phase = runs:Phase()
	local run = runs:Get()
	if status == "waiting" or runs:IsWaiting(player) then
		local what = phase == "boss" and "the 7th night"
			or (runs:IsNight() and `night {runs:Night()}` or `day {runs:Day()}`)
		return { text = `A run is underway ({what}). You'll be in the next one!` }
	end
	if status == "ghost" then
		return {
			text = runs:IsNight() and "You're out until dawn. Cheer your team on!"
				or "Back on your feet in a moment...",
		}
	end
	if status == "downed" then
		return {
			text = "You're down! A teammate can revive you, or crawl into the campfire's light.",
			target = MapLayout.CAMP_PROPS.fire,
		}
	end
	if phase == "results" then
		return { text = "The run is over. A new one starts in a moment." }
	end
	local tut = tutorial:View(player)
	if tut then
		return { text = tut.text, target = tut.target, guide = true }
	end
	if phase == "boss" then
		local b = boss:Get()
		return {
			text = "Defeat MEGA KERMY! Bait his charge into an Ancient Pine 🌲",
			target = b and b.pos + Vector3.new(0, 14, 0) or nil,
		}
	end
	if phase == "night" then
		local left = runs:TimeLeft() or 0
		return {
			text = `Survive the night! 🌙 ({Formulas.clock(left)} left)`,
			target = MapLayout.CAMP_PROPS.fire + Vector3.new(0, 3, 0),
		}
	end
	if phase == "dusk" then
		return {
			text = "Night is coming! Get back to camp 🔥",
			target = MapLayout.CAMP_PROPS.fire + Vector3.new(0, 3, 0),
		}
	end
	if phase == "dawn" then
		return { text = `You survived night {runs:Night()}! ☀️` }
	end
	local goal = self:CampGoal()
	if run and run.day == 7 then
		return {
			text = "The 7th night is coming. Get ready for Mega Kermy! " .. goal.text,
			target = goal.target,
			key = goal.key,
		}
	end
	return { text = goal.text, target = goal.target, key = goal.key }
end

function ObjectiveService:_optional(player)
	local out = {}
	local phase = runs:Phase()
	local run = runs:Get()
	-- the fire, at night
	if runs:IsNight() then
		local fuel, max = camp:Fuel()
		if fuel < max * 0.3 then
			table.insert(out, {
				text = `Keep the fire burning 🔥 ({math.floor(fuel / max * 100)}%)`,
				target = MapLayout.CAMP_PROPS.fire,
			})
		end
	end
	if phase == "day" and run then
		-- day 1: the difficulty
		if not run.locked and runs:UnlockedMax() > 1 then
			table.insert(out, {
				text = "Vote on the difficulty at the standing stones",
				target = MapLayout.CAMP_PROPS.stones[2] + Vector3.new(0, 4, 0),
			})
		end
		-- the supply drop
		if supply and not supply.opened then
			table.insert(out, { text = "Reach the supply drop 📦", target = supply.pos + Vector3.new(0, 3, 0) })
		end
		-- the golden pack
		local elite = monsters:ElitePack()
		if elite then
			local alive = false
			for _, m in elite.members do
				if m.hp > 0 then
					alive = true
				end
			end
			if alive then
				table.insert(out, { text = `Hunt the golden {elite.members[1].def.name} ✨ (deep forest)` })
			end
		end
		-- a key in your pack
		if inventory:Has(player, "rusty_key") then
			local pos = survivors:Position(player)
			local target
			for _, c in loot:All() do
				if c.kind == "locked_chest" and not c.opened and pos and (c.pos - pos).Magnitude < 90 then
					target = c.pos + Vector3.new(0, 3, 0)
				end
			end
			table.insert(out, { text = "Find a locked chest for your Rusty Key 🗝️", target = target })
		end
		-- exploring
		if #out < 2 then
			local found, total = 0, 0
			for _, f in world:Findings() do
				total += 1
				if f.known then
					found += 1
				end
			end
			if total > 0 and found < total then
				table.insert(out, { text = `Explore the forest: {found}/{total} findings found 🧭` })
			end
		end
	end
	while #out > 2 do
		table.remove(out)
	end
	return out
end

function ObjectiveService:_markers(player)
	local out = { { key = "camp", icon = "🔥", name = "Camp", pos = MapLayout.CAMP_PROPS.fire } }
	for _, m in world:Markers() do
		table.insert(out, { key = m.key, icon = m.icon, name = m.name, pos = m.pos, found = m.found })
	end
	for _, tg in runs:Active() do
		if tg ~= player and survivors:Status(tg) == "downed" then
			local pos = survivors:Position(tg)
			if pos then
				table.insert(out, { key = "downed", icon = "🆘", name = tg.DisplayName, pos = pos, urgent = true })
			end
		end
	end
	if supply and not supply.opened then
		table.insert(out, { key = "supply", icon = "📦", name = "Supply drop", pos = supply.pos })
	end
	local b = boss:Get()
	if b and b.hp > 0 then
		table.insert(out, { key = "boss", icon = "👹", name = "Mega Kermy", pos = b.pos, urgent = true })
	end
	return out
end

local function encode(v)
	local parts = { v.primary.text or "" }
	if v.primary.target then
		local t = v.primary.target
		table.insert(parts, string.format("%d,%d,%d", t.X // 2, t.Y // 2, t.Z // 2))
	end
	for _, o in v.optional do
		table.insert(parts, o.text)
	end
	for _, m in v.markers do
		table.insert(parts, m.key .. (m.pos and string.format("%d,%d", m.pos.X // 4, m.pos.Z // 4) or ""))
	end
	return table.concat(parts, "|")
end

function ObjectiveService:View(player)
	return { primary = self:_primary(player), optional = self:_optional(player), markers = self:_markers(player) }
end

function ObjectiveService:Push(player, force)
	local v = self:View(player)
	local e = encode(v)
	if not force and last[player] == e then
		return
	end
	last[player] = e
	Net.fire(player, "Objective", v)
end

-- When the team's camp goal changes, the old one was done: say so.
function ObjectiveService:_checkGoal()
	if not runs:IsDay() and runs:Phase() ~= "dusk" then
		return
	end
	local goal = self:CampGoal()
	if goalKey and goal.key ~= goalKey then
		local players = runs:Active()
		Net.fireAll("Toast", "✅ Team goal done! Next: " .. goal.text, "good")
		self.Completed:Fire(goalKey, players)
	end
	goalKey = goal.key
end

function ObjectiveService:Init(registry)
	data = registry.PlayerDataService
	runs = registry.RunService
	survivors = registry.SurvivorService
	inventory = registry.InventoryService
	camp = registry.CampService
	loot = registry.LootService
	monsters = registry.MonsterService
	boss = registry.BossService
	world = registry.WorldService
	tutorial = registry.TutorialService
	loot.SupplyDropped:Connect(function(c)
		supply = c
	end)
	runs.Reset:Connect(function()
		supply = nil
		goalKey = nil
	end)
	_ = data
	_ = Camp
end

function ObjectiveService:OnPlayerReady(player)
	data:WhenClientReady(player, function()
		self:Push(player, true)
	end)
end

function ObjectiveService:OnPlayerLeaving(player)
	last[player] = nil
end

function ObjectiveService:Start()
	while true do
		task.wait(1)
		local ok, err = pcall(function()
			self:_checkGoal()
			for _, player in game:GetService("Players"):GetPlayers() do
				if data:Get(player) then
					self:Push(player)
				end
			end
		end)
		if not ok then
			warn("[ObjectiveService] " .. tostring(err))
		end
	end
end

_ = now
return ObjectiveService
