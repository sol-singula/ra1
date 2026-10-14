--[[
The camp (master plan §7): the team's home base, visual reward and strategic centre. It belongs to the run.

  blueprints   every structure the camp's tier allows stands on its slot as a glowing blueprint. Hold its prompt to
               put materials in (from your backpack first, then the shared chest); when it's full it's built. Who put
               what in is counted (§7: recognise everyone who helps).
  tiers        the Camp Board opens the next tier when its structures are built and the team has the materials
               (Data/Camp.TIERS): Campsite -> Outpost -> Fort -> Stronghold.
  the chest    shared storage: anything in it is safe if you go down, and the stations and the board can use it.
  the fire     burns fuel at night; feed it wood. Its light heals and lets the downed get up (SurvivorService); if it
               goes out, the night gets darker and monsters hit harder.
  defences     walls and gates have health (monsters break them, MonsterService); with a Repair Bench, hold Repair
               to mend them with wood. From the Fort, reinforce wood with stone. Spike traps hurt monsters that walk
               over them. The Totem of the Seventh Night weakens Mega Kermy.
]]
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Camp = require(ReplicatedStorage.Shared.Data.Camp)
local CampModels = require(ReplicatedStorage.Shared.World.CampModels)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Kit = require(ReplicatedStorage.Shared.World.Kit)
local MapLayout = require(ReplicatedStorage.Shared.World.MapLayout)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local CampService = {
	Name = "CampService",
	Dependencies = { "PlayerDataService", "RunService", "InventoryService", "SurvivorService" },
	Built = Signal.new("CampService.Built"), -- (structure, contributors = { [player] = n })
	Upgraded = Signal.new("CampService.Upgraded"), -- (structure, contributors)
	TierUp = Signal.new("CampService.TierUp"), -- (tier, player)
	Deposited = Signal.new("CampService.Deposited"), -- (player, structure, itemKey, n)
	Damaged = Signal.new("CampService.Damaged"), -- (structure, amount)
	Destroyed = Signal.new("CampService.Destroyed"), -- (structure)
	Repaired = Signal.new("CampService.Repaired"), -- (player, structure, hp)
	Stored = Signal.new("CampService.Stored"), -- (player, itemKey, n, put)
	FireChanged = Signal.new("CampService.FireChanged"), -- (lit)
	Fueled = Signal.new("CampService.Fueled"), -- (player, wood)
}

local data, runs, inventory, survivors
local camp -- the run's camp state
local folder -- workspace.Structures
local pushQueued = false

local function now()
	return workspace:GetServerTimeNow()
end

local function ensureFolder()
	if not folder or not folder.Parent then
		folder = workspace:FindFirstChild("Structures") or Instance.new("Folder")
		folder.Name = "Structures"
		folder.Parent = workspace
	end
	return folder
end

local function sid(key, index)
	return key .. "_" .. index
end

-- Queries ----------------------------------------------------------------------------------------------------------------
function CampService:Tier()
	return camp and camp.tier or 1
end

function CampService:Structure(id)
	return camp and camp.structures[id]
end

function CampService:Structures()
	return camp and camp.structures or {}
end

function CampService:Count(key, upgradedOnly)
	local n = 0
	for _, s in self:Structures() do
		if s.key == key and s.state == "built" and (not upgradedOnly or s.upgraded) then
			n += 1
		end
	end
	return n
end

function CampService:IsBuilt(key)
	return self:Count(key) > 0
end

function CampService:FirePosition()
	return MapLayout.CAMP_PROPS.fire
end

function CampService:FireLit()
	return camp == nil or camp.fuel > 0
end

function CampService:FireRadius()
	if not self:FireLit() then
		return 6
	end
	local tier = self:Tier()
	return Constants.FIRE_LIGHT[tier] + self:Count("lamppost") * 2
end

function CampService:Fuel()
	return camp and camp.fuel or 0, Constants.FUEL_MAX[self:Tier()]
end

-- A built station of this kind within reach of pos ("campfire" counts the fire).
function CampService:StationNear(pos, station)
	if not pos then
		return false
	end
	if station == "campfire" then
		return (pos - self:FirePosition()).Magnitude <= Constants.USE_RANGE
	end
	for _, s in self:Structures() do
		local def = Camp.STRUCTURES[s.key]
		if def.station == station and s.state == "built" and (s.slot.pos - pos).Magnitude <= Constants.USE_RANGE then
			return true
		end
	end
	return false
end

function CampService:InCamp(pos)
	return pos ~= nil and Vector3.new(pos.X, 0, pos.Z).Magnitude <= MapLayout.CAMP.radius
end

function CampService:Storage()
	return camp and camp.storage or {}
end

function CampService:StorageCount(key)
	return camp and camp.storage[key] or 0
end

-- Built walls and gates as arcs of the wall ring (monsters can't pass through them: MonsterService).
function CampService:Barriers()
	local out = {}
	for _, s in self:Structures() do
		if (s.key == "wall" or s.key == "gate") and s.state == "built" then
			table.insert(out, s)
		end
	end
	return out
end

function CampService:Spikes()
	local out = {}
	for _, s in self:Structures() do
		if s.key == "spikes" and s.state == "built" then
			table.insert(out, s)
		end
	end
	return out
end

function CampService:Catapults()
	local out = {}
	for _, s in self:Structures() do
		if s.key == "catapult" and s.state == "built" then
			table.insert(out, s)
		end
	end
	return out
end

function CampService:TotemBuilt()
	return self:IsBuilt("totem")
end

-- Materials: your backpack first, then the chest ----------------------------------------------------------------------
function CampService:Available(player, key)
	return inventory:Count(player, key) + self:StorageCount(key)
end

local function takeFrom(player, key, n)
	local own = math.min(inventory:Count(player, key), n)
	if own > 0 then
		inventory:Take(player, key, own)
	end
	local rest = n - own
	if rest > 0 then
		camp.storage[key] = (camp.storage[key] or 0) - rest
		if camp.storage[key] <= 0 then
			camp.storage[key] = nil
		end
	end
end

-- Pay a whole cost or nothing (crafting, the board).
function CampService:Pay(player, cost)
	for key, n in cost do
		if self:Available(player, key) < n then
			return false, key
		end
	end
	for key, n in cost do
		takeFrom(player, key, n)
	end
	self:_queuePush()
	return true
end

-- Views -------------------------------------------------------------------------------------------------------------------
local function costTable(cost)
	return table.clone(cost or {})
end

function CampService:_requirements(tier)
	local def = Camp.TIERS[tier]
	if not def then
		return nil
	end
	local req = {}
	for key, n in def.requires or {} do
		local have
		if key == "stone_wall" then
			have = self:Count("wall", true)
		else
			have = self:Count(key)
		end
		req[key] = { need = n, have = math.min(have, n) }
	end
	return req
end

function CampService:View()
	if not camp then
		return { tier = 1 }
	end
	local structures = {}
	for id, s in camp.structures do
		if s.state ~= "locked" then
			local def = Camp.STRUCTURES[s.key]
			local up = def.upgrade
			structures[id] = {
				key = s.key,
				index = s.index,
				state = s.state,
				have = costTable(s.have),
				cost = costTable(s.cost),
				hp = s.hp and math.ceil(s.hp) or nil,
				maxHp = s.maxHp,
				upgraded = s.upgraded,
				upHave = s.upHave and costTable(s.upHave) or nil,
				upCost = (up and runs and camp.tier >= up.tier and not s.upgraded and s.state == "built")
						and costTable(up.cost)
					or nil,
				pos = s.slot.pos,
			}
		end
	end
	local nextTier = Camp.TIERS[camp.tier + 1]
	local fuel, fuelMax = self:Fuel()
	return {
		tier = camp.tier,
		tierName = Camp.TIERS[camp.tier].name,
		fuel = math.floor(fuel),
		fuelMax = fuelMax,
		lit = self:FireLit(),
		radius = self:FireRadius(),
		structures = structures,
		next = nextTier and {
			tier = nextTier.n,
			name = nextTier.name,
			desc = nextTier.desc,
			cost = costTable(nextTier.cost),
			requires = self:_requirements(nextTier.n),
		} or nil,
		storage = table.clone(camp.storage),
	}
end

function CampService:_queuePush()
	if pushQueued then
		return
	end
	pushQueued = true
	task.delay(0.3, function()
		pushQueued = false
		self:_push()
	end)
end

function CampService:_push()
	if not camp then
		return
	end
	local view = self:View()
	Net.fireAll("Camp", view)
	workspace:SetAttribute("CampTier", camp.tier)
	workspace:SetAttribute("FireLit", self:FireLit())
	workspace:SetAttribute("FireRadius", self:FireRadius())
	self:_updateBoard()
	self:_updateFire()
end

-- Models --------------------------------------------------------------------------------------------------------------------
local function label(parent, text)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Info"
	bb.Size = UDim2.fromOffset(220, 46)
	bb.StudsOffset = Vector3.new(0, 7, 0)
	bb.MaxDistance = 70
	bb.AlwaysOnTop = false
	bb.LightInfluence = 0
	bb.Parent = parent
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.25
	t.TextScaled = true
	t.Font = Enum.Font.FredokaOne
	t.Text = text
	t.Parent = bb
	return t
end

local ICON = { wood = "🪵", stone = "🪨", scrap = "⚙️", fiber = "🧵", glowcap = "🍄", herb = "🌿" }
local function costLine(have, cost)
	local parts = {}
	for _, key in { "wood", "stone", "scrap", "fiber", "glowcap", "herb" } do
		if cost[key] then
			table.insert(parts, `{ICON[key]} {have[key] or 0}/{cost[key]}`)
		end
	end
	return table.concat(parts, "  ")
end

function CampService:_anchor(s)
	-- an invisible part at the slot to hold prompts and labels (the models come and go)
	if s.anchor and s.anchor.Parent then
		return s.anchor
	end
	local a = Kit.box(
		ensureFolder(),
		"Anchor_" .. s.id,
		CFrame.new(s.slot.pos + Vector3.new(0, 3, 0)),
		Vector3.new(1, 1, 1),
		Kit.C.black,
		Kit.M.SmoothPlastic,
		{
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
		}
	)
	a:SetAttribute("Structure", s.id)
	s.anchor = a
	return a
end

function CampService:_prompt(s, name, action, hold)
	local a = self:_anchor(s)
	local p = a:FindFirstChild(name)
	if not p then
		p = Instance.new("ProximityPrompt")
		p.Name = name
		p.RequiresLineOfSight = false
		p.MaxActivationDistance = Constants.USE_RANGE
		p.Parent = a
		p:SetAttribute("Structure", s.id)
		p:SetAttribute("Action", name)
	end
	p.ActionText = action
	p.ObjectText = s.name
	p.HoldDuration = hold or 0
	p.Enabled = true
	return p
end

function CampService:_removePrompt(s, name)
	local a = s.anchor
	local p = a and a:FindFirstChild(name)
	if p then
		p:Destroy()
	end
end

function CampService:_refreshModel(s)
	if s.model then
		s.model:Destroy()
		s.model = nil
	end
	if s.info then
		s.info.Parent:Destroy()
		s.info = nil
	end
	if s.state == "locked" then
		if s.anchor then
			s.anchor:Destroy()
			s.anchor = nil
		end
		return
	end
	local def = Camp.STRUCTURES[s.key]
	local ghost = s.state == "blueprint"
	local cf = s.slot.cf
	if s.key == "catapult" then
		cf = CFrame.new(s.slot.pos) * (s.slot.cf - s.slot.cf.Position)
	end
	s.model = CampModels.build(s.key, cf, {
		parent = ensureFolder(),
		ghost = ghost,
		width = s.slot.width,
		upgraded = s.upgraded,
		name = s.id,
	})
	s.model:SetAttribute("Structure", s.id)
	if ghost then
		s.info = label(self:_anchor(s), `{def.icon} {s.name}\n{costLine(s.have, s.cost)}`)
		self:_prompt(s, "Build", `Build {s.name}`, 30)
		self:_removePrompt(s, "Repair")
		self:_removePrompt(s, "Reinforce")
		self:_removePrompt(s, "Use")
	else
		self:_removePrompt(s, "Build")
		self:_refreshBuiltPrompts(s)
	end
end

-- Prompts on a built structure: use a station / open the chest; repair; reinforce.
function CampService:_refreshBuiltPrompts(s)
	local def = Camp.STRUCTURES[s.key]
	if def.station then
		self:_prompt(s, "Use", `Use {s.name}`, 0)
	elseif s.key == "storage" then
		self:_prompt(s, "Use", "Open chest", 0)
	end
	if s.hp and s.hp < s.maxHp and self:IsBuilt("repair") then
		self:_prompt(s, "Repair", `Repair ({math.ceil(s.hp)}/{s.maxHp})`, 30)
	else
		self:_removePrompt(s, "Repair")
	end
	local up = def.upgrade
	if up and camp.tier >= up.tier and not s.upgraded then
		self:_prompt(s, "Reinforce", `Make it a {up.name}`, 30)
		if not s.info then
			s.info = label(self:_anchor(s), `⬆️ {up.name}\n{costLine(s.upHave, up.cost)}`)
		else
			s.info.Text = `⬆️ {up.name}\n{costLine(s.upHave, up.cost)}`
		end
	else
		self:_removePrompt(s, "Reinforce")
	end
end

function CampService:_updateBoard()
	local board = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Camp")
	board = board and board:FindFirstChild("CampBoard")
	local text = board and board:FindFirstChild("Board") and board.Board:FindFirstChild("Info")
	local lbl = text and text:FindFirstChild("Label")
	if not lbl or not camp then
		return
	end
	local nextTier = Camp.TIERS[camp.tier + 1]
	if not nextTier then
		lbl.Text = `🏰 {Camp.TIERS[camp.tier].name}\nThe camp is as strong as it gets!`
		return
	end
	local lines = { `{Camp.TIERS[camp.tier].name} → {nextTier.name}` }
	local have = {}
	for key in nextTier.cost do
		have[key] = self:StorageCount(key)
	end
	table.insert(lines, costLine(have, nextTier.cost) .. "  (in the chest)")
	for key, r in self:_requirements(nextTier.n) do
		local name = key == "stone_wall" and "Stone walls"
			or (Camp.STRUCTURES[key] and Camp.STRUCTURES[key].name or key)
		table.insert(lines, `{r.have >= r.need and "✅" or "⬜"} {name} {r.have}/{r.need}`)
	end
	lbl.Text = table.concat(lines, "\n")
end

local fireState
function CampService:_updateFire()
	local fire = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Camp")
	fire = fire and fire:FindFirstChild("Campfire")
	if not fire or not camp then
		return
	end
	local key = `{camp.tier}:{self:FireLit()}`
	if fireState == key then
		return
	end
	fireState = key
	local parent = fire.Parent
	local cf = CFrame.new(MapLayout.CAMP_PROPS.fire)
	fire:Destroy()
	local m = CampModels.build("fire", cf, { parent = parent, name = "Campfire", tier = camp.tier })
	if not self:FireLit() then
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and (d.Name == "Flame" or d.Name == "FlameCore" or d.Name == "BeaconFlame") then
				d.Transparency = 1
			elseif d:IsA("Light") or d:IsA("Fire") then
				d.Enabled = false
			end
		end
	end
	self:_firePrompt(m)
end

function CampService:_firePrompt(model)
	local flame = model:FindFirstChild("Embers") or model:FindFirstChildWhichIsA("BasePart")
	if not flame then
		return
	end
	local p = Instance.new("ProximityPrompt")
	p.Name = "Fuel"
	p.ActionText = "Feed the fire (🪵)"
	p.ObjectText = "Campfire"
	p.HoldDuration = 0.4
	p.MaxActivationDistance = Constants.USE_RANGE
	p.RequiresLineOfSight = false
	p.Parent = flame
	p.Triggered:Connect(function(player)
		self:Fuel_(player, 5)
	end)
	local cook = Instance.new("ProximityPrompt")
	cook.Name = "Cook"
	cook.ActionText = "Cook"
	cook.ObjectText = "Campfire"
	cook.HoldDuration = 0
	cook.MaxActivationDistance = Constants.USE_RANGE
	cook.RequiresLineOfSight = false
	cook.UIOffset = Vector2.new(0, 60)
	cook.Parent = flame
	cook:SetAttribute("Station", "campfire")
end

-- Building ------------------------------------------------------------------------------------------------------------------
local function contributors(s)
	local out = {}
	for userId, n in s.by do
		local p = Players:GetPlayerByUserId(userId)
		if p then
			out[p] = n
		end
	end
	return out
end

-- Put one unit of material into a blueprint (or an upgrade). Returns true if something went in.
function CampService:Deposit(player, s, upgrade)
	if not camp or not runs:InRun(player) or not survivors:IsAlive(player) then
		return false
	end
	local have, cost
	if upgrade then
		local up = Camp.STRUCTURES[s.key].upgrade
		if not up or s.upgraded or s.state ~= "built" or camp.tier < up.tier then
			return false
		end
		s.upHave = s.upHave or {}
		have, cost = s.upHave, up.cost
	else
		if s.state ~= "blueprint" then
			return false
		end
		have, cost = s.have, s.cost
	end
	for _, key in { "wood", "stone", "scrap", "fiber", "glowcap", "herb" } do
		local need = (cost[key] or 0) - (have[key] or 0)
		if need > 0 and self:Available(player, key) > 0 then
			takeFrom(player, key, 1)
			have[key] = (have[key] or 0) + 1
			s.by[player.UserId] = (s.by[player.UserId] or 0) + 1
			camp.contrib[player.UserId] = (camp.contrib[player.UserId] or 0) + 1
			self.Deposited:Fire(player, s, key, 1)
			local done = true
			for k, n in cost do
				if (have[k] or 0) < n then
					done = false
				end
			end
			if done then
				if upgrade then
					self:_finishUpgrade(s)
				else
					self:_finish(s)
				end
			elseif s.info then
				s.info.Text = upgrade and `⬆️ {Camp.STRUCTURES[s.key].upgrade.name}\n{costLine(have, cost)}`
					or `{Camp.STRUCTURES[s.key].icon} {s.name}\n{costLine(have, cost)}`
			end
			self:_queuePush()
			return true
		end
	end
	return false
end

function CampService:_finish(s)
	local def = Camp.STRUCTURES[s.key]
	s.state = "built"
	s.hp = def.hp
	s.maxHp = def.hp
	s.uses = def.uses
	s.builtAt = now()
	self:_refreshModel(s)
	Net.fireAll("Fx", "built", { pos = s.slot.pos, key = s.key })
	Net.fireAll("Sfx", "built", s.slot.pos)
	Net.fireAll("Toast", `{def.icon} {s.name} built!`, "good")
	self.Built:Fire(s, contributors(s))
	if s.key == "totem" then
		Net.fireAll("Callout", "🗿 The Totem of the Seventh Night stands. Mega Kermy will be weaker!", "good")
	end
	self:_queuePush()
end

function CampService:_finishUpgrade(s)
	local up = Camp.STRUCTURES[s.key].upgrade
	s.upgraded = true
	s.name = up.name
	if up.hp then
		s.hp, s.maxHp = up.hp, up.hp
	end
	if up.uses then
		s.uses = up.uses
	end
	s.upHave = nil
	self:_refreshModel(s)
	Net.fireAll("Fx", "built", { pos = s.slot.pos, key = s.key })
	Net.fireAll("Sfx", "built", s.slot.pos)
	Net.fireAll("Toast", `⬆️ {up.name}!`, "good")
	self.Upgraded:Fire(s, contributors(s))
	self:_queuePush()
end

-- Holding a Build / Reinforce / Repair prompt: one unit at a time while you hold.
local holds = {} -- [player] = token
function CampService:_hold(player, prompt)
	local id = prompt:GetAttribute("Structure")
	local action = prompt:GetAttribute("Action")
	local s = id and self:Structure(id)
	if not s then
		return
	end
	local token = {}
	holds[player] = token
	local profile = data:Get(player)
	local quick = profile and table.find(profile.perks or {}, "quick_hands") and 1.3 or 1
	local step = 1 / (Constants.DEPOSIT_PER_SECOND * quick)
	task.spawn(function()
		while holds[player] == token and prompt.Parent do
			local pos = survivors:Position(player)
			if not pos or (pos - s.slot.pos).Magnitude > Constants.USE_RANGE + 4 then
				break
			end
			local ok
			if action == "Build" then
				ok = self:Deposit(player, s, false)
			elseif action == "Reinforce" then
				ok = self:Deposit(player, s, true)
			elseif action == "Repair" then
				ok = self:Repair(player, s)
			end
			if not ok then
				if action ~= "Repair" then
					Net.fire(player, "Toast", "You need more materials (in your backpack or the camp chest).", "bad")
				end
				break
			end
			task.wait(step)
		end
		if holds[player] == token then
			holds[player] = nil
		end
	end)
end

function CampService:Repair(player, s)
	if s.state ~= "built" or not s.hp or s.hp >= s.maxHp or not self:IsBuilt("repair") then
		return false
	end
	if self:Available(player, "wood") < 1 then
		Net.fire(player, "Toast", "Repairs take wood.", "bad")
		return false
	end
	takeFrom(player, "wood", 1)
	s.hp = math.min(s.maxHp, s.hp + Constants.REPAIR_PER_WOOD)
	camp.contrib[player.UserId] = (camp.contrib[player.UserId] or 0) + 1
	self.Repaired:Fire(player, s, Constants.REPAIR_PER_WOOD)
	Net.fireAll("Fx", "repair", { pos = s.slot.pos })
	self:_refreshBuiltPrompts(s)
	self:_queuePush()
	return s.hp < s.maxHp
end

-- The board -----------------------------------------------------------------------------------------------------------------
function CampService:CanUpgrade(player)
	local nextTier = Camp.TIERS[camp.tier + 1]
	if not nextTier then
		return false, "The camp is already a Stronghold."
	end
	for key, r in self:_requirements(nextTier.n) do
		if r.have < r.need then
			local name = key == "stone_wall" and "stone walls"
				or (Camp.STRUCTURES[key] and Camp.STRUCTURES[key].name or key)
			return false, `Build {r.need - r.have} more {name} first.`
		end
	end
	for key, n in nextTier.cost do
		if self:Available(player, key) < n then
			return false, `Not enough {Items.get(key).name} (need {n}, the team has {self:Available(player, key)}).`
		end
	end
	return true
end

function CampService:Upgrade(player)
	if not camp or not runs:InRun(player) then
		return false
	end
	local ok, why = self:CanUpgrade(player)
	if not ok then
		Net.fire(player, "Toast", why, "bad")
		return false
	end
	local nextTier = Camp.TIERS[camp.tier + 1]
	self:Pay(player, nextTier.cost)
	for key, n in nextTier.cost do
		camp.contrib[player.UserId] = (camp.contrib[player.UserId] or 0) + n * 0.25
		_ = key
	end
	self:SetTier(nextTier.n)
	Net.fireAll("Alert", `🏕️ THE CAMP IS NOW {string.upper(nextTier.name)}!`, Color3.fromRGB(255, 214, 120), 4)
	Net.fireAll("Sfx", "levelup")
	self.TierUp:Fire(nextTier.n, player)
	return true
end

function CampService:SetTier(tier)
	camp.tier = tier
	camp.fuel = math.max(camp.fuel, Constants.FUEL_MAX[tier] * 0.6)
	for _, s in camp.structures do
		local def = Camp.STRUCTURES[s.key]
		if s.state == "locked" and def.tier <= tier then
			s.state = "blueprint"
			self:_refreshModel(s)
		elseif s.state == "built" then
			self:_refreshBuiltPrompts(s)
		end
	end
	self:_updatePines()
	self:_queuePush()
end

function CampService:_updatePines()
	local MapBuilder = self._mapBuilder
	local pines = MapBuilder and MapBuilder.camp and MapBuilder.camp.pines
	if not pines then
		return
	end
	local glow = self:TotemBuilt()
	for _, p in pines do
		if p.rune and p.rune.Parent then
			p.rune.Transparency = glow and 0 or 0.6
		end
	end
end

-- The chest -------------------------------------------------------------------------------------------------------------------
function CampService:_nearChest(player)
	local pos = survivors:Position(player)
	for _, s in self:Structures() do
		if
			s.key == "storage"
			and s.state == "built"
			and pos
			and (s.slot.pos - pos).Magnitude <= Constants.USE_RANGE + 4
		then
			return true
		end
	end
	return false
end

function CampService:OpenChest(player)
	if not self:_nearChest(player) then
		return false
	end
	Net.fire(player, "Storage", table.clone(camp.storage))
	player:SetAttribute("ChestAt", workspace:GetServerTimeNow()) -- the client opens the chest's panel
	return true
end

local function storageUsed()
	local n = 0
	for key, count in camp.storage do
		n += math.ceil(count / Items.get(key).stack)
	end
	return n
end

function CampService:Put(player, slotId, count)
	if not camp or not runs:InRun(player) or not self:_nearChest(player) then
		return false
	end
	local slot = inventory:Slot(player, slotId)
	if not slot then
		return false
	end
	local item = Items.get(slot.key)
	count = math.clamp(math.floor(tonumber(count) or slot.n), 1, slot.n)
	if not camp.storage[item.key] and storageUsed() >= Constants.STORAGE_SLOTS then
		Net.fire(player, "Toast", "The chest is full.", "bad")
		return false
	end
	inventory:Consume(player, slotId, count)
	camp.storage[item.key] = (camp.storage[item.key] or 0) + count
	self.Stored:Fire(player, item.key, count, true)
	Net.fire(player, "Storage", table.clone(camp.storage))
	self:_queuePush()
	return true
end

-- Put every resource you carry in the chest.
function CampService:PutAll(player)
	if not camp or not runs:InRun(player) or not self:_nearChest(player) then
		return 0
	end
	local moved = 0
	for id, slot in inventory:Contents(player) do
		local item = Items.get(slot.key)
		if item.kind == "resource" and string.sub(id, 1, 1) == "b" then
			moved += slot.n
			self:Put(player, id, slot.n)
		end
	end
	return moved
end

function CampService:Take(player, key, count)
	if not camp or not runs:InRun(player) or not self:_nearChest(player) then
		return false
	end
	local have = camp.storage[key] or 0
	count = math.clamp(math.floor(tonumber(count) or have), 1, math.max(1, have))
	if have < count or have <= 0 then
		return false
	end
	camp.storage[key] = have - count
	if camp.storage[key] <= 0 then
		camp.storage[key] = nil
	end
	local fitted = inventory:Give(player, key, count, "chest", { noDrop = true })
	if fitted < count then
		camp.storage[key] = (camp.storage[key] or 0) + (count - fitted)
	end
	self.Stored:Fire(player, key, fitted, false)
	Net.fire(player, "Storage", table.clone(camp.storage))
	self:_queuePush()
	return fitted > 0
end

-- The fire ------------------------------------------------------------------------------------------------------------------------
function CampService:Fuel_(player, maxWood)
	if not camp or not runs:InRun(player) then
		return 0
	end
	local fuelMax = Constants.FUEL_MAX[camp.tier]
	local room = math.floor((fuelMax - camp.fuel) / Constants.FUEL_PER_WOOD)
	local wood = math.min(maxWood or 5, room, self:Available(player, "wood"))
	if wood <= 0 then
		Net.fire(
			player,
			"Toast",
			room <= 0 and "The fire is roaring already." or "You need wood to feed the fire.",
			"info"
		)
		return 0
	end
	local wasLit = self:FireLit()
	takeFrom(player, "wood", wood)
	camp.fuel = math.min(fuelMax, camp.fuel + wood * Constants.FUEL_PER_WOOD)
	camp.contrib[player.UserId] = (camp.contrib[player.UserId] or 0) + wood
	self.Fueled:Fire(player, wood)
	Net.fire(
		player,
		"Popup",
		self:FirePosition() + Vector3.new(0, 4, 0),
		`🔥 +{wood * Constants.FUEL_PER_WOOD}`,
		Color3.fromRGB(255, 180, 90)
	)
	if not wasLit then
		Net.fireAll("Callout", "🔥 The fire is back!", "good")
		self.FireChanged:Fire(true)
	end
	self:_queuePush()
	return wood
end

function CampService:_burn(dt)
	if not camp or not runs:IsNight() then
		return
	end
	local wasLit = camp.fuel > 0
	local blessing = workspace:GetAttribute("Blessing")
	camp.fuel = math.max(0, camp.fuel - Constants.FUEL_BURN * dt * (blessing == "hearth" and 0.5 or 1))
	if wasLit and camp.fuel <= 0 then
		Net.fireAll("Callout", "🔥 The fire went out! Feed it wood, quick!", "bad")
		self.FireChanged:Fire(false)
		self:_queuePush()
	elseif math.floor(camp.fuel) % 5 == 0 then
		self:_queuePush()
	end
	if wasLit and camp.fuel > 0 and camp.fuel < 20 and not camp.warnedLow then
		camp.warnedLow = true
		Net.fireAll("Callout", "🔥 The fire is getting low! Feed it some wood.", "info")
	elseif camp.fuel >= 20 then
		camp.warnedLow = false
	end
end

-- Damage from monsters ------------------------------------------------------------------------------------------------------------
function CampService:DamageStructure(s, amount)
	if not s or s.state ~= "built" or not s.hp then
		return
	end
	s.hp -= amount
	self.Damaged:Fire(s, amount)
	if s.hp <= 0 then
		s.state = "blueprint"
		s.have = {}
		s.hp = nil
		s.upgraded = false
		s.name = Camp.STRUCTURES[s.key].name
		s.upHave = nil
		self:_refreshModel(s)
		Net.fireAll("Fx", "crumble", { pos = s.slot.pos })
		Net.fireAll("Callout", `💥 A {string.lower(Camp.STRUCTURES[s.key].name)} broke!`, "bad")
		self.Destroyed:Fire(s)
	else
		if math.random() < 0.3 then
			Net.fireAll("Fx", "splinter", { pos = s.slot.pos + Vector3.new(0, 3, 0) })
		end
		self:_refreshBuiltPrompts(s)
	end
	self:_queuePush()
end

-- Monsters at the fire stamp on it (MonsterService): it loses fuel.
function CampService:Stomp(amount)
	if not camp or camp.fuel <= 0 then
		return
	end
	-- a crowd can't put it out in an instant: at most STOMP_PER_SECOND in all
	local t = now()
	if not camp.stompSince or t - camp.stompSince >= 1 then
		camp.stompSince, camp.stomped = t, 0
	end
	amount = math.min(amount, Constants.STOMP_PER_SECOND - camp.stomped)
	if amount <= 0 then
		return
	end
	camp.stomped += amount
	local wasLit = camp.fuel > 0
	camp.fuel = math.max(0, camp.fuel - amount)
	if not camp.stompWarned or now() - camp.stompWarned > 12 then
		camp.stompWarned = now()
		Net.fireAll("Callout", "🔥 Monsters are stamping on the fire! Defend it!", "bad")
	end
	if wasLit and camp.fuel <= 0 then
		Net.fireAll("Callout", "🔥 The fire went out! Feed it wood, quick!", "bad")
		self.FireChanged:Fire(false)
	end
	self:_queuePush()
end

-- A spike trap is stepped on: use it up a little.
function CampService:UseSpike(s)
	if not s or s.state ~= "built" then
		return
	end
	s.uses = (s.uses or 1) - 1
	if s.uses <= 0 then
		s.state = "blueprint"
		s.have = {}
		s.upgraded = false
		s.name = Camp.STRUCTURES[s.key].name
		self:_refreshModel(s)
		self:_queuePush()
	end
end

-- Reset ----------------------------------------------------------------------------------------------------------------------------
function CampService:ResetCamp()
	if camp then
		for _, s in camp.structures do
			if s.model then
				s.model:Destroy()
			end
			if s.anchor then
				s.anchor:Destroy()
			end
		end
	end
	ensureFolder():ClearAllChildren()
	camp = { tier = 1, fuel = Constants.FUEL_MAX[1], structures = {}, storage = {}, contrib = {} }
	for _, slot in MapLayout.campSlots do
		local def = Camp.STRUCTURES[slot.key]
		if def then
			local s = {
				id = sid(slot.key, slot.index),
				key = slot.key,
				index = slot.index,
				slot = slot,
				name = def.name,
				state = def.tier <= 1 and "blueprint" or "locked",
				have = {},
				cost = def.cost,
				by = {},
			}
			camp.structures[s.id] = s
			self:_refreshModel(s)
		end
	end
	fireState = nil
	self:_push()
end

-- Who put in how much this run (the results screen, XP).
function CampService:Contribution(player)
	return camp and camp.contrib[player.UserId] or 0
end

function CampService:Init(registry)
	data = registry.PlayerDataService
	runs = registry.RunService
	inventory = registry.InventoryService
	survivors = registry.SurvivorService
	survivors.setCamp(self)
	local ok, mb = pcall(function()
		return require(script.Parent.Parent.World.MapBuilder)
	end)
	self._mapBuilder = ok and mb or nil
	Net.on("Store", function(player, action, a, b)
		if action == "put" then
			self:Put(player, a, b)
		elseif action == "take" and type(a) == "string" and Items.get(a) then
			self:Take(player, a, b)
		elseif action == "all" then
			self:PutAll(player)
		elseif action == "open" then
			self:OpenChest(player)
		end
	end)
	Net.on("Camp", function(player, action, a, b)
		if action == "upgrade" then
			self:Upgrade(player)
		elseif action == "fuel" then
			self:Fuel_(player, tonumber(a) or 5)
		elseif action == "repair" and type(a) == "string" then
			local s = self:Structure(a)
			if s then
				self:Repair(player, s)
			end
		end
		_ = b
	end)
	runs.Reset:Connect(function()
		self:ResetCamp()
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		local id = prompt:GetAttribute("Structure")
		local action = prompt:GetAttribute("Action")
		local s = id and self:Structure(id)
		if s and action == "Use" then
			if s.key == "storage" then
				self:OpenChest(player)
			end
		end
	end)
	ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt, player)
		local action = prompt:GetAttribute("Action")
		if action == "Build" or action == "Reinforce" or action == "Repair" then
			self:_hold(player, prompt)
		end
	end)
	ProximityPromptService.PromptButtonHoldEnded:Connect(function(_, player)
		holds[player] = nil
	end)
end

function CampService:Start()
	ensureFolder()
	-- the board's prompt
	local map = workspace:FindFirstChild("Map")
	local board = map and map:FindFirstChild("Camp") and map.Camp:FindFirstChild("CampBoard")
	if board and board:FindFirstChild("Board") then
		-- it opens the camp's panel on the player's screen: what the next tier needs, and UPGRADE ("Camp", "upgrade")
		local p = Instance.new("ProximityPrompt")
		p.Name = "Upgrade"
		p.ActionText = "Upgrade the camp"
		p.ObjectText = "Camp Board"
		p.HoldDuration = 0
		p.MaxActivationDistance = Constants.USE_RANGE
		p.RequiresLineOfSight = false
		p.Parent = board.Board
		p.Triggered:Connect(function(player)
			Net.fire(player, "Camp", self:View())
			player:SetAttribute("BoardAt", workspace:GetServerTimeNow())
		end)
	end
	if not camp then
		self:ResetCamp()
	end
	while true do
		task.wait(0.5)
		self:_burn(0.5)
	end
end

function CampService:OnPlayerReady(player)
	data:WhenClientReady(player, function()
		Net.fire(player, "Camp", self:View())
	end)
end

function CampService:OnPlayerLeaving(player)
	holds[player] = nil
end

return CampService
