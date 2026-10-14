--[[
Loot (master plan §3, §6): crates scattered through the forest, lockers and chests at the findings, a locked chest
for every Rusty Key, a supply drop on days 3 and 5, Kermy's hoard. Open one with its prompt: what's inside goes
straight into your backpack (what doesn't fit drops at your feet). The deeper into the forest, the rarer the loot
(§3: risky choices for better loot). Every run places them afresh.

  Mimics (§10's trickster): a few crates bite back. The crate jumps up, bites, and runs off with its loot on
  tiny legs (MonsterService); catch it when it gets tired.
  Rarity: Common, Uncommon, Rare, Epic, Legendary (§6). Legendaries only come from the deep forest's best
  containers. Luck (Lucky Clover) and the Scavenger perk help.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Kit = require(ReplicatedStorage.Shared.World.Kit)
local MapLayout = require(ReplicatedStorage.Shared.World.MapLayout)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local LootService = {
	Name = "LootService",
	Dependencies = { "PlayerDataService", "RunService", "InventoryService", "SurvivorService", "MonsterService" },
	Looted = Signal.new("LootService.Looted"), -- (player, container, items)
	MimicSprung = Signal.new("LootService.MimicSprung"), -- (player, container)
	SupplyDropped = Signal.new("LootService.SupplyDropped"), -- (container)
}

local data, runs, inventory, survivors, monsters
local C, M = Kit.C, Kit.M
local V3 = Vector3.new
local containers = {} -- [id] = { id, kind, pos, zone, model, opened, mimic, locked, extra }
local nextId = 0
local rng = Random.new(1)

local KINDS = {
	crate = { name = "Crate", rolls = { 2, 3 }, shift = 0, hold = 0.6 },
	locker = { name = "Ranger Locker", rolls = { 2, 3 }, shift = 1, hold = 0.8, gear = true },
	chest = { name = "Chest", rolls = { 3, 4 }, shift = 1, hold = 0.8 },
	cooler = { name = "Cooler", rolls = { 3, 3 }, shift = 0, hold = 0.6, food = true },
	backpack = { name = "Lost Backpack", rolls = { 2, 3 }, shift = 0, hold = 0.6, pack = true },
	cauldron = { name = "Cauldron", rolls = { 2, 3 }, shift = 1, hold = 0.8, brews = true },
	rack = { name = "Weapon Rack", rolls = { 2, 2 }, shift = 1, hold = 0.8, bows = true },
	hoard = { name = "Kermy's Hoard", rolls = { 4, 5 }, shift = 2, hold = 1.2 },
	locked_chest = { name = "Locked Chest", rolls = { 4, 5 }, shift = 2, hold = 1, locked = true },
	supply = { name = "Supply Drop", rolls = { 4, 5 }, shift = 2, hold = 1 },
}
LootService.KINDS = KINDS

-- Chances of each rarity by zone (before the container's shift and luck)
local ZONE_ODDS = {
	camp = { 75, 22, 3, 0, 0 },
	inner = { 68, 26, 6, 0, 0 },
	middle = { 44, 38, 14, 4, 0 },
	deep = { 25, 37, 25, 11, 2 },
}

local function now()
	return workspace:GetServerTimeNow()
end

-- Rolling -------------------------------------------------------------------------------------------------------------
local POOLS = {} -- [rarity] = { item, ... } (things worth finding: no plain resources, no keys)
for _, item in Items.list do
	if item.kind ~= "resource" and item.kind ~= "key" and item.kind ~= "ammo" then
		POOLS[item.rarity] = POOLS[item.rarity] or {}
		table.insert(POOLS[item.rarity], item)
	end
end

local function pickRarity(zone, shift, luck)
	local odds = table.clone(ZONE_ODDS[zone] or ZONE_ODDS.inner)
	for _ = 1, shift do
		-- move a share of each tier up one
		for i = #odds - 1, 1, -1 do
			local moved = odds[i] * 0.35
			odds[i] -= moved
			odds[i + 1] += moved
		end
	end
	if luck and luck > 1 then
		for i = 3, #odds do
			odds[i] *= luck
		end
	end
	local total = 0
	for _, v in odds do
		total += v
	end
	local roll = rng:NextNumber(0, total)
	for i, v in odds do
		roll -= v
		if roll <= 0 then
			return Items.RARITIES[i]
		end
	end
	return "common"
end

local RESOURCE_BUNDLES = {
	inner = { { "wood", 3, 6 }, { "stone", 2, 4 }, { "fiber", 3, 5 }, { "berries", 2, 4 } },
	middle = { { "wood", 4, 7 }, { "stone", 3, 5 }, { "fiber", 3, 6 }, { "scrap", 1, 3 }, { "herb", 1, 2 } },
	deep = { { "scrap", 2, 4 }, { "stone", 4, 6 }, { "herb", 1, 3 }, { "glowcap", 1, 2 } },
}

-- What a container gives: { { key, n }, ... }
function LootService:Roll(kind, zone, luck, opts)
	local spec = KINDS[kind] or KINDS.crate
	opts = opts or {}
	local out = {}
	local n = rng:NextInteger(spec.rolls[1], spec.rolls[2]) + (opts.extra or 0)
	zone = zone == "camp" and "inner" or zone
	for i = 1, n do
		-- the first roll of every container is a thing; the rest mix in resources
		if i > 1 and rng:NextNumber() < 0.45 and not spec.gear then
			local bundles = RESOURCE_BUNDLES[zone] or RESOURCE_BUNDLES.inner
			local b = bundles[rng:NextInteger(1, #bundles)]
			table.insert(out, { key = b[1], n = rng:NextInteger(b[2], b[3]) })
		else
			local rarity = pickRarity(zone, spec.shift, luck)
			if rarity == "legendary" and not (kind == "hoard" or kind == "supply" or kind == "locked_chest") then
				rarity = "epic"
			end
			local pool = POOLS[rarity] or POOLS.common
			-- containers with a theme lean on it
			local candidates = {}
			for _, item in pool do
				local fits = true
				if spec.food then
					fits = item.kind == "food"
				elseif spec.brews then
					fits = item.kind == "support" or item.kind == "food"
				elseif spec.bows then
					fits = item.class == "bow" or item.kind == "trap"
				elseif spec.pack then
					fits = item.kind ~= "weapon" or item.class == "spear"
				end
				if fits then
					table.insert(candidates, item)
				end
			end
			if #candidates == 0 then
				candidates = pool
			end
			local item = candidates[rng:NextInteger(1, #candidates)]
			local count = item.stack > 1 and math.min(item.stack, rng:NextInteger(1, item.kind == "food" and 3 or 2))
				or 1
			table.insert(out, { key = item.key, n = count })
			if item.class == "bow" then
				table.insert(out, { key = "arrows", n = rng:NextInteger(10, 20) })
			end
		end
	end
	if spec.bows and rng:NextNumber() < 0.8 then
		table.insert(out, { key = "arrows", n = rng:NextInteger(12, 24) })
	end
	for _, extra in opts.add or {} do
		table.insert(out, extra)
	end
	return out
end

-- Containers -------------------------------------------------------------------------------------------------------------
local function lid(m, cf, w, d, color, material)
	return Kit.box(m, "Lid", cf, V3(w, 0.5, d), color, material, { CanCollide = false })
end

local function buildModel(kind, cf, parent)
	local m = Kit.model(kind, parent)
	if kind == "crate" then
		Kit.crate(m, cf * CFrame.new(0, 1.4, 0), V3(2.8, 2.8, 2.8))
	elseif kind == "chest" or kind == "locked_chest" or kind == "hoard" then
		Kit.box(m, "Chest", cf * CFrame.new(0, 1, 0), V3(3.6, 2, 2.4), C.wood, M.WoodPlanks)
		lid(m, cf * CFrame.new(0, 2.25, 0), 3.8, 2.6, C.woodDark, M.Wood)
		for _, x in { -1.3, 1.3 } do
			Kit.box(m, "Band", cf * CFrame.new(x, 1.3, 0), V3(0.3, 2.7, 2.6), C.gold, M.Metal, { CastShadow = false })
		end
		if kind == "locked_chest" then
			Kit.box(
				m,
				"Padlock",
				cf * CFrame.new(0, 1.5, -1.3),
				V3(0.8, 0.9, 0.3),
				C.iron,
				M.Metal,
				{ CastShadow = false }
			)
		end
		if kind == "hoard" then
			for k = 1, 9 do
				local a = k / 9 * math.pi * 2
				Kit.disc(
					m,
					"Coin",
					(cf * CFrame.new(math.cos(a) * 3, 0.15 + (k % 3) * 0.2, math.sin(a) * 3)).Position,
					1,
					0.2,
					C.gold,
					M.Metal,
					{ CanCollide = false, CastShadow = false }
				)
			end
			Kit.box(m, "Sandwich", cf * CFrame.new(2.4, 0.4, 1.6), V3(1.4, 0.5, 1), C.woodLight, M.SmoothPlastic, {
				CanCollide = false,
				CastShadow = false,
			})
		end
	elseif kind == "locker" then
		Kit.box(m, "Locker", cf * CFrame.new(0, 2.6, 0), V3(2.4, 5.2, 1.8), C.canvasGreen:Lerp(C.iron, 0.4), M.Metal)
		lid(m, cf * CFrame.new(0, 2.6, -0.95), 2.2, 0.3, C.iron, M.Metal).Size = V3(2.2, 4.8, 0.2)
	elseif kind == "cooler" then
		Kit.box(m, "Cooler", cf * CFrame.new(0, 1, 0), V3(3, 2, 2), C.white, M.SmoothPlastic)
		lid(m, cf * CFrame.new(0, 2.15, 0), 3.1, 2.1, C.blue, M.SmoothPlastic)
	elseif kind == "backpack" then
		Kit.box(m, "Bag", cf * CFrame.new(0, 1, 0), V3(2, 2, 1.3), C.canvasRed, M.Fabric)
		lid(m, cf * CFrame.new(0, 2.1, 0), 2.1, 1.4, C.canvasRed:Lerp(C.black, 0.3), M.Fabric)
	elseif kind == "cauldron" then
		Kit.ball(m, "Pot", cf.Position + V3(0, 1.4, 0), 3.4, C.black, M.Metal)
		lid(m, cf * CFrame.new(0, 2.6, 0), 2.6, 2.6, Color3.fromRGB(120, 240, 120), M.Neon)
	elseif kind == "rack" then
		for _, x in { -1.6, 1.6 } do
			Kit.box(m, "Post", cf * CFrame.new(x, 1.6, 0), V3(0.4, 3.2, 0.4), C.woodDark, M.Wood)
		end
		lid(m, cf * CFrame.new(0, 2.8, 0), 3.6, 0.4, C.wood, M.Wood)
	elseif kind == "supply" then
		Kit.crate(m, cf * CFrame.new(0, 1.6, 0), V3(3.2, 3.2, 3.2), C.canvasGreen)
		lid(m, cf * CFrame.new(0, 3.4, 0), 3.3, 3.3, C.canvasGreen:Lerp(C.black, 0.2), M.Fabric)
		Kit.box(
			m,
			"Chute",
			cf * CFrame.new(1.5, 0.2, 2.6) * CFrame.Angles(0, 0.5, 0),
			V3(5, 0.2, 4),
			C.white,
			M.Fabric,
			{
				CanCollide = false,
				CastShadow = false,
			}
		)
		local flare = Kit.ball(m, "Flare", cf.Position + V3(-2, 0.5, -1.6), 0.8, C.red, M.Neon, { CanCollide = false })
		Kit.light(flare, "PointLight", { Color = C.red, Range = 20, Brightness = 2 })
		Kit.box(m, "Smoke", CFrame.new(cf.Position + V3(-2, 25, -1.6)), V3(1.2, 50, 1.2), C.red, M.Neon, {
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
			Transparency = 0.6,
		})
	end
	return m
end
LootService.buildModel = buildModel

-- Put a container in the world. opts = { zone, mimic, add = { extra items }, extra = rolls, finding = key }
function LootService:Place(kind, cf, opts)
	opts = opts or {}
	nextId += 1
	local parent = workspace:FindFirstChild("Loot") or workspace
	local pos = cf.Position
	local c = {
		id = nextId,
		kind = kind,
		pos = pos,
		cf = cf,
		zone = opts.zone or MapLayout.zoneAt(pos.X, pos.Z),
		mimic = opts.mimic == true,
		locked = KINDS[kind] and KINDS[kind].locked or false,
		add = opts.add,
		extra = opts.extra,
		finding = opts.finding,
		onOpen = opts.onOpen,
		starter = opts.starter == true,
	}
	c.model = buildModel(kind, cf, parent)
	c.model:SetAttribute("ContainerId", c.id)
	c.model:SetAttribute("Kind", kind)
	if c.mimic then
		c.model:SetAttribute("Mimic", true) -- the client makes it breathe (the tell: §10 "readable")
	end
	local anchor = c.model:FindFirstChildWhichIsA("BasePart")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Open"
	prompt.ActionText = c.locked and "Unlock" or "Open"
	prompt.ObjectText = KINDS[kind] and KINDS[kind].name or kind
	prompt.HoldDuration = KINDS[kind] and KINDS[kind].hold or Constants.OPEN_SECONDS
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	prompt.Triggered:Connect(function(player)
		self:Open(player, c.id)
	end)
	c.prompt = prompt
	containers[c.id] = c
	return c
end

function LootService:Get(id)
	return containers[id]
end

function LootService:All()
	return containers
end

function LootService:Open(player, id)
	local c = containers[id]
	if not c or c.opened or not runs:InRun(player) or not survivors:IsAlive(player) then
		return false
	end
	local pos = survivors:Position(player)
	if not pos or (pos - c.pos).Magnitude > 14 then
		return false
	end
	if c.locked then
		if not inventory:Has(player, "rusty_key") then
			Net.fire(player, "Toast", "🔒 Locked. A Rusty Key opens it.", "bad")
			return false
		end
		inventory:Take(player, "rusty_key", 1)
	end
	c.opened = true
	if c.prompt then
		c.prompt:Destroy()
		c.prompt = nil
	end
	if c.mimic then
		self:_spring(player, c)
		return true
	end
	local profile = data:Get(player)
	local luck = inventory:Gear(player).luck
	local extra = c.extra or 0
	if profile and table.find(profile.perks or {}, "scavenger") and rng:NextNumber() < 0.15 then
		extra += 1
	end
	local items = c.items or self:Roll(c.kind, c.zone, luck, { add = c.add, extra = extra })
	for _, it in items do
		inventory:Give(player, it.key, it.n, "loot")
	end
	-- the lid swings open (the client animates "Open" containers it sees)
	local l = c.model:FindFirstChild("Lid")
	if l then
		l.CFrame = l.CFrame * CFrame.new(0, 0.6, 0.9) * CFrame.Angles(math.rad(-70), 0, 0)
	end
	c.model:SetAttribute("Opened", true)
	Net.fireAll("Fx", "loot", { pos = c.pos + V3(0, 2, 0), kind = c.kind })
	Net.fire(player, "Sfx", "open", c.pos)
	local names = {}
	for _, it in items do
		local item = Items.get(it.key)
		table.insert(names, item.icon .. (it.n > 1 and (" " .. it.n) or ""))
	end
	Net.fire(player, "Toast", `{KINDS[c.kind] and KINDS[c.kind].name or "Loot"}: {table.concat(names, "  ")}`, "good")
	self.Looted:Fire(player, c, items)
	if c.onOpen then
		task.spawn(c.onOpen, player, c)
	end
	-- opened containers fade after a while
	task.delay(90, function()
		if containers[c.id] == c and c.model then
			c.model:Destroy()
			containers[c.id] = nil
		end
	end)
	return true
end

-- A mimic: it bites, then runs off with its loot (catch it to get it).
function LootService:_spring(player, c)
	local items = self:Roll("chest", c.zone, 1.3, { extra = 1 })
	if c.model then
		c.model:Destroy()
	end
	containers[c.id] = nil
	Net.fire(player, "Callout", "📦 IT'S A MIMIC! Catch it, it's got loot!", "bad")
	monsters:SpawnMimic(c.pos, items, player)
	self.MimicSprung:Fire(player, c)
end

-- A new run's loose crates: a few right by the camp for the first minutes, the rest spread through the forest.
function LootService:Scatter(run)
	rng = Random.new(run.seed + 17)
	local trees = MapLayout.trees()
	local grid = {}
	for _, t in trees do
		local k = math.floor(t.x / 16) * 1000 + math.floor(t.z / 16)
		grid[k] = grid[k] or {}
		table.insert(grid[k], t)
	end
	local function free(x, z)
		if not MapLayout.walkable(x, z) then
			return false
		end
		for cx = math.floor(x / 16) - 1, math.floor(x / 16) + 1 do
			for cz = math.floor(z / 16) - 1, math.floor(z / 16) + 1 do
				for _, t in grid[cx * 1000 + cz] or {} do
					-- (out from under the crown, so the crate can be seen and the arrow isn't "in a tree")
					local keep = math.max(t.trunk + 4, (t.h or 0) * 0.32)
					if (t.x - x) ^ 2 + (t.z - z) ^ 2 < keep ^ 2 then
						return false
					end
				end
			end
		end
		for _, c in containers do
			if (c.pos.X - x) ^ 2 + (c.pos.Z - z) ^ 2 < 30 ^ 2 then
				return false
			end
		end
		return true
	end
	local function place(minR, maxR, opts)
		for _ = 1, 200 do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = math.sqrt(rng:NextNumber(minR ^ 2, maxR ^ 2))
			local x, z = math.cos(a) * r, math.sin(a) * r
			if (r < 90 or MapLayout.clearOf(x, z, -4)) and free(x, z) then
				local y = MapLayout.floorY(x, z)
				return self:Place(
					opts.kind or "crate",
					CFrame.new(x, y, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
					opts
				)
			end
		end
		return nil
	end
	-- the starter crate, right by the fire: always a real weapon, a torch and something to eat (§4: hold
	-- something exciting in the first minute)
	for _ = 1, 100 do
		local angles = { 100, 215, 255 }
		local a = math.rad(angles[rng:NextInteger(1, #angles)] + rng:NextNumber(-10, 10))
		local r = rng:NextNumber(12, 15)
		local x, z = math.cos(a) * r, math.sin(a) * r
		if free(x, z) then
			self:Place("crate", CFrame.new(x, MapLayout.floorY(x, z), z) * CFrame.Angles(0, a + math.pi, 0), {
				zone = "camp",
				starter = true,
				add = {
					{ key = rng:NextNumber() < 0.5 and "branch_club" or "stone_spear", n = 1 },
					{ key = "torch", n = 1 },
					{ key = "berries", n = 2 },
				},
				extra = -1,
			})
			break
		end
	end
	-- more by the camp: something useful for the first minutes
	local starters = { "stone_spear", "branch_club", "bandage", "sharp_stick" }
	for i = 1, Constants.CRATES_NEAR_CAMP do
		place(58, 105, { zone = "camp", add = { { key = starters[(i - 1) % #starters + 1], n = 1 } }, extra = -1 })
	end
	local mimics = rng:NextInteger(Constants.MIMICS[1], Constants.MIMICS[2])
	for i = 1, Constants.CRATES do
		place(110, MapLayout.WORLD_RADIUS - 20, { mimic = i <= mimics })
	end
	-- locked chests in the middle and deep forest, and a key for each in a crate somewhere
	for _ = 1, Constants.LOCKED_CHESTS do
		place(220, MapLayout.WORLD_RADIUS - 25, { kind = "locked_chest" })
	end
	local plain = {}
	for _, c in containers do
		if c.kind == "crate" and not c.mimic and c.zone ~= "camp" then
			table.insert(plain, c)
		end
	end
	table.sort(plain, function(a, b)
		return a.id < b.id
	end)
	for k = 1, math.min(Constants.LOCKED_CHESTS, #plain) do
		local c = table.remove(plain, rng:NextInteger(1, #plain))
		c.add = c.add or {}
		table.insert(c.add, { key = "rusty_key", n = 1 })
		_ = k
	end
	-- a strange idol in a deep crate (most runs)
	if rng:NextNumber() < 0.65 and #plain > 0 then
		for _, c in plain do
			if c.zone == "deep" then
				c.add = c.add or {}
				table.insert(c.add, { key = "strange_idol", n = 1 })
				break
			end
		end
	end
end

-- Days 3 and 5: a supply crate parachutes into the deep forest (a flare marks it), with a pack nearby.
function LootService:SupplyDrop()
	local sites = MapLayout.sites
	local options = {}
	for _, s in sites do
		if s.zone == "deep" and not s.used and not s.finding then
			table.insert(options, s)
		end
	end
	if #options == 0 then
		return nil
	end
	local s = options[rng:NextInteger(1, #options)]
	s.used = true
	local pos = V3(s.x + rng:NextNumber(-6, 6), s.y, s.z + rng:NextNumber(-6, 6))
	local c = self:Place("supply", CFrame.new(pos), { zone = "deep" })
	Net.fireAll("Callout", "📦 A supply drop is coming down in the deep forest! Follow the red smoke.", "info")
	Net.fireAll(
		"Ping",
		{ key = "supply", text = "Supply drop", icon = "📦", position = pos, from = "", until_ = now() + 90 }
	)
	monsters:SpawnPack("grinwolf", pos + V3(14, 0, 10), 3, { guard = pos })
	self.SupplyDropped:Fire(c)
	return c
end

function LootService:Clear()
	for id, c in containers do
		if c.model then
			c.model:Destroy()
		end
		containers[id] = nil
	end
end

function LootService:Init(registry)
	data = registry.PlayerDataService
	runs = registry.RunService
	inventory = registry.InventoryService
	survivors = registry.SurvivorService
	monsters = registry.MonsterService
	runs.Reset:Connect(function(run)
		self:Clear()
		for _, s in MapLayout.sites do
			s.used = nil
		end
		self:Scatter(run)
	end)
	runs.DayStarted:Connect(function(day)
		if table.find(Constants.SUPPLY_DROP_DAYS, day) then
			task.delay(8, function()
				if runs:Day() == day and runs:IsDay() then
					self:SupplyDrop()
				end
			end)
		end
	end)
end

return LootService
