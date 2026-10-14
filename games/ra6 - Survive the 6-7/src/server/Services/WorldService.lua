--[[
The random findings (the map is mostly forest, besides the camp and the findings): every run picks a fresh set of
findings (Data/Findings) and scatters them over the forest's clearings (MapLayout.sites), so each run has its own
map to explore (master plan §3). WorldService builds them, fills them (LootService containers, ResourceService
nodes), and runs what makes each one special:

  discovery     walk up to a finding: it's yours (collection, XP) and on everyone's compass
  the map       the Ranger's Map (top of the Old Ranger Tower) shows every finding on the compass
  diary pages   one or two of Kermy's seven diary pages lie at the findings each run (kept forever once read)
  guards        the Bear Cave and the Mushroom Ring wake their guards when you come close by day
  the altar     the Stone Circle: offer a Strange Idol for a blessing on the whole team for the rest of the run
  the hive      the Beehive Tree: honey, and angry bees (hold a torch: bees hate smoke)
  the lair      Kermy naps on his throne by day (MonsterService)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Findings = require(ReplicatedStorage.Shared.Data.Findings)
local FindingModels = require(ReplicatedStorage.Shared.World.FindingModels)
local Kit = require(ReplicatedStorage.Shared.World.Kit)
local MapLayout = require(ReplicatedStorage.Shared.World.MapLayout)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local WorldService = {
	Name = "WorldService",
	Dependencies = {
		"PlayerDataService",
		"RunService",
		"InventoryService",
		"SurvivorService",
		"ResourceService",
		"LootService",
		"MonsterService",
		"CombatService",
	},
	Discovered = Signal.new("WorldService.Discovered"), -- (player, finding) the first time in this run
	PageRead = Signal.new("WorldService.PageRead"), -- (player, pageIndex)
	Blessed = Signal.new("WorldService.Blessed"), -- (player, blessingKey)
	Revealed = Signal.new("WorldService.Revealed"), -- (player?) everything is on the compass
	HoneyTaken = Signal.new("WorldService.HoneyTaken"), -- (player, stung)
	Sneaked = Signal.new("WorldService.Sneaked"), -- (player) looted Kermy's hoard while he slept
}

local data, runs, inventory, survivors, resources, loot, monsters
local placed = {} -- this run's findings: { key, def, site, pos, model, spots, known = bool, visitors = { [player] = true } }
local folder
local revealed = false
local pages = {} -- { index, pos, model, readers = { [player] = true } }
local rng = Random.new(1)

local BLESSINGS = {
	{ key = "strength", name = "Blessing of the Oak", text = "Everyone hits 20% harder for the rest of the run." },
	{ key = "hearth", name = "Blessing of the Hearth", text = "The campfire burns half as fast." },
	{ key = "swift", name = "Blessing of the Wind", text = "Everyone runs 10% faster." },
}

local function now()
	return workspace:GetServerTimeNow()
end

local function ensureFolder()
	if not folder or not folder.Parent then
		folder = workspace:FindFirstChild("Findings") or Instance.new("Folder")
		folder.Name = "Findings"
		folder.Parent = workspace
	end
	return folder
end

function WorldService:Findings()
	return placed
end

-- Compass markers for the client: known findings (found, or revealed by the map).
function WorldService:Markers()
	local out = {}
	for _, f in placed do
		if f.known or revealed then
			table.insert(
				out,
				{ key = f.key, name = f.def.name, icon = f.def.icon, pos = f.pos, found = f.known == true }
			)
		end
	end
	return out
end

-- Building a run's findings ----------------------------------------------------------------------------------------------------
function WorldService:_plan()
	local sites = table.clone(MapLayout.sites)
	-- shuffle the sites (each run differs)
	for i = #sites, 2, -1 do
		local j = rng:NextInteger(1, i)
		sites[i], sites[j] = sites[j], sites[i]
	end
	local plan = {}
	local used = {}
	local function take(def)
		for _, s in sites do
			if not used[s.id] and table.find(def.zone, s.zone) then
				used[s.id] = true
				table.insert(plan, { def = def, site = s })
				return true
			end
		end
		return false
	end
	-- the one-of-a-kind ones first (they have the strictest zones), then the rest
	local order = table.clone(Findings.list)
	table.sort(order, function(a, b)
		return #a.zone < #b.zone or (#a.zone == #b.zone and a.order < b.order)
	end)
	for _, def in order do
		local n = rng:NextInteger(def.count[1], def.count[2])
		for _ = 1, n do
			take(def)
		end
	end
	return plan
end

function WorldService:_build(entry)
	local def, site = entry.def, entry.site
	local pos = Vector3.new(site.x, site.y, site.z)
	-- the front faces the camp, so you see the door as you come from the fire
	local toward = Vector3.new(0, site.y, 0)
	local cf = CFrame.lookAt(pos, toward) * CFrame.Angles(0, math.rad(rng:NextNumber(-25, 25)), 0)
	local model, spots = FindingModels.build(def.key, cf, rng, ensureFolder())
	model:SetAttribute("Finding", def.key)
	site.finding = def.key
	local f =
		{ key = def.key, def = def, site = site, pos = pos, model = model, spots = spots, visitors = {}, known = false }
	-- containers
	for _, l in spots.loot do
		local kind, lcf = l[1], l[2]
		local opts = { zone = site.zone, finding = def.key }
		if kind == "crate" and def.mimicChance and rng:NextNumber() < def.mimicChance then
			opts.mimic = true
		end
		if def.key == "ranger_tower" and kind == "chest" then
			opts.add = { { key = "ranger_map", n = 1 } }
		end
		if kind == "hoard" then
			opts.onOpen = function(player)
				local k = monsters:Kermy()
				if k and k.state == "sleep" then
					self.Sneaked:Fire(player)
				end
			end
		end
		loot:Place(kind, lcf, opts)
	end
	-- nodes
	for _, n in spots.nodes do
		resources:AddNode(n[1], n[2], { once = false })
	end
	-- what monsters walk round: the building's core
	local solid = {
		cabin = 8,
		ranger_tower = 6,
		ice_cream_truck = 7,
		bear_cave = 11,
		witch_hut = 6,
		hollow_log = 7,
		hunter_blind = 5,
		rusty_car = 6,
		beehive_tree = 2.5,
	}
	if solid[def.key] then
		f.obstacle = { x = pos.X, z = pos.Z, r = solid[def.key] }
	end
	-- specials
	if spots.special.throne then
		monsters:SetLair(spots.special.throne)
	end
	if spots.special.altar then
		self:_altar(f, spots.special.altar)
	end
	if spots.special.hive then
		self:_hive(f, spots.special.hive)
	end
	return f
end

function WorldService:_altar(f, cf)
	local anchor = Kit.box(f.model, "AltarPrompt", cf, Vector3.new(1, 1, 1), Kit.C.black, Kit.M.SmoothPlastic, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	local p = Instance.new("ProximityPrompt")
	p.Name = "Offer"
	p.ActionText = "Offer the Strange Idol"
	p.ObjectText = "Stone Circle"
	p.HoldDuration = 1.5
	p.MaxActivationDistance = 12
	p.RequiresLineOfSight = false
	p.Parent = anchor
	p.Triggered:Connect(function(player)
		self:Offer(player)
	end)
end

function WorldService:Offer(player)
	if workspace:GetAttribute("Blessing") then
		Net.fire(player, "Toast", "The stones are quiet. The team is already blessed.", "info")
		return false
	end
	if not inventory:Has(player, "strange_idol") then
		Net.fire(player, "Toast", "The stones want a Strange Idol. Look in deep forest crates.", "info")
		return false
	end
	inventory:Take(player, "strange_idol", 1)
	local b = BLESSINGS[rng:NextInteger(1, #BLESSINGS)]
	workspace:SetAttribute("Blessing", b.key)
	Net.fireAll("Alert", `✨ {string.upper(b.name)}`, Color3.fromRGB(150, 230, 255), 4)
	Net.fireAll("Callout", `{player.DisplayName} offered the idol: {b.text}`, "good")
	Net.fireAll("Sfx", "magic")
	self.Blessed:Fire(player, b.key)
	return true
end

function WorldService:_hive(f, cf)
	local anchor = Kit.box(f.model, "HivePrompt", cf, Vector3.new(1, 1, 1), Kit.C.black, Kit.M.SmoothPlastic, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	local p = Instance.new("ProximityPrompt")
	p.Name = "Honey"
	p.ActionText = "Take honey"
	p.ObjectText = "Beehive"
	p.HoldDuration = 1
	p.MaxActivationDistance = 12
	p.RequiresLineOfSight = false
	p.Parent = anchor
	f.hiveReady = 0
	p.Triggered:Connect(function(player)
		if now() < f.hiveReady then
			Net.fire(player, "Toast", "The bees are still buzzing about. Come back later.", "info")
			return
		end
		f.hiveReady = now() + 120
		inventory:Give(player, "honey", 2, "hive")
		local _, held = inventory:Selected(player)
		local smoke = held and held.key == "torch"
		if not smoke then
			Net.fire(player, "Callout", "🐝 BEES! Run! (A torch would have calmed them.)", "bad")
			Net.fireAll("Fx", "bees", { pos = cf.Position, by = player.UserId, seconds = 5 })
			for k = 1, 5 do
				task.delay(k, function()
					if survivors:IsAlive(player) then
						survivors:Damage(player, 4, { kind = "bees" })
					end
				end)
			end
		else
			Net.fire(player, "Toast", "🔥 The smoke calms the bees. Sweet, sweet honey.", "good")
		end
		self.HoneyTaken:Fire(player, not smoke)
	end)
end

-- Kermy's diary pages: one or two per run, at random findings.
function WorldService:_placePages()
	local count = rng:NextInteger(1, 2)
	local options = {}
	for _, f in placed do
		if f.spots.page then
			table.insert(options, f)
		end
	end
	for _ = 1, math.min(count, #options) do
		local f = table.remove(options, rng:NextInteger(1, #options))
		local index = rng:NextInteger(1, #Findings.PAGES)
		local cf = f.spots.page
		local m = Kit.model("DiaryPage", ensureFolder())
		local sheet = Kit.box(
			m,
			"Page",
			cf * CFrame.Angles(math.rad(-80), 0, 0),
			Vector3.new(1.6, 2, 0.08),
			Kit.C.cream,
			Kit.M.SmoothPlastic,
			{
				CanCollide = false,
			}
		)
		Kit.light(sheet, "PointLight", { Color = Kit.C.cream, Range = 8, Brightness = 1 })
		local glow = Kit.box(
			m,
			"Glow",
			CFrame.new(cf.Position + Vector3.new(0, 4, 0)),
			Vector3.new(0.3, 8, 0.3),
			Kit.C.cream,
			Kit.M.Neon,
			{
				CanCollide = false,
				CanQuery = false,
				CastShadow = false,
				Transparency = 0.6,
			}
		)
		_ = glow
		local p = Instance.new("ProximityPrompt")
		p.Name = "Read"
		p.ActionText = "Read the page"
		p.ObjectText = "Kermy's Diary"
		p.HoldDuration = 0.5
		p.MaxActivationDistance = 10
		p.RequiresLineOfSight = false
		p.Parent = sheet
		local page = { index = index, pos = cf.Position, model = m, readers = {} }
		table.insert(pages, page)
		p.Triggered:Connect(function(player)
			if page.readers[player] then
				return
			end
			page.readers[player] = true
			Net.fire(player, "Alert", `📖 "{Findings.PAGES[index]}"`, Color3.fromRGB(255, 244, 214), 6)
			self.PageRead:Fire(player, index)
		end)
	end
end

function WorldService:Prepare(run)
	rng = Random.new(run.seed + 101)
	self:Clear()
	local plan = self:_plan()
	local obstacles = {}
	for _, entry in plan do
		local f = self:_build(entry)
		table.insert(placed, f)
		if f.obstacle then
			table.insert(obstacles, f.obstacle)
		end
	end
	monsters:SetObstacles("findings", obstacles)
	self:_placePages()
end

function WorldService:Clear()
	for _, f in placed do
		if f.model then
			f.model:Destroy()
		end
		f.site.finding = nil
	end
	table.clear(placed)
	for _, p in pages do
		if p.model then
			p.model:Destroy()
		end
	end
	table.clear(pages)
	revealed = false
	workspace:SetAttribute("Blessing", nil)
	ensureFolder():ClearAllChildren()
end

-- The Ranger's Map: every finding on the compass.
function WorldService:RevealAll(player)
	revealed = true
	Net.fireAll(
		"Callout",
		`🗺️ {player and player.DisplayName or "Someone"} read the Ranger's Map: every finding is on your compass!`,
		"good"
	)
	self.Revealed:Fire(player)
end

function WorldService:Revealed_()
	return revealed
end

-- Discovery: walk up to a finding.
function WorldService:_watch()
	local day = runs:IsDay()
	for _, tg in survivors:Targets() do
		for _, f in placed do
			local d = (Vector3.new(tg.pos.X, 0, tg.pos.Z) - Vector3.new(f.pos.X, 0, f.pos.Z)).Magnitude
			if d < f.def.radius + 10 and not f.visitors[tg.player] then
				f.visitors[tg.player] = true
				if not f.known then
					f.known = true
					Net.fireAll("Toast", `📍 {tg.player.DisplayName} found the {f.def.name}!`, "info")
				end
				self.Discovered:Fire(tg.player, f)
			end
			-- guards wake when someone comes close by day (once a day each)
			if day and f.def.guard and d < 60 and f.guardedDay ~= runs:Day() and runs:Day() >= 2 then
				f.guardedDay = runs:Day()
				local guardPos = f.spots.guard or f.pos
				if f.def.guard == "grinwolf" then
					monsters:SpawnPack("grinwolf", guardPos, 2, { guard = guardPos, day = true })
				else
					for k = 1, 3 do
						monsters:Spawn(
							f.def.guard,
							guardPos + Vector3.new(k * 2, 0, 0),
							{ guard = guardPos, day = true }
						)
					end
				end
			end
		end
	end
end

function WorldService:Init(registry)
	data = registry.PlayerDataService
	runs = registry.RunService
	inventory = registry.InventoryService
	survivors = registry.SurvivorService
	resources = registry.ResourceService
	loot = registry.LootService
	monsters = registry.MonsterService
	registry.CombatService.setWorld(self)
	runs.Reset:Connect(function(run)
		self:Prepare(run)
	end)
	_ = data
end

function WorldService:Start()
	while true do
		task.wait(1)
		local ok, err = pcall(self._watch, self)
		if not ok then
			warn("[WorldService] " .. tostring(err))
		end
	end
end

function WorldService:OnPlayerLeaving(player)
	for _, f in placed do
		f.visitors[player] = nil
	end
	for _, p in pages do
		p.readers[player] = nil
	end
end

_ = Players
return WorldService
