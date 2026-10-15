--[[
What lasts (master plan §6): XP and levels, titles, the discovery journal (every island, creature, fish, artifact
and event you've met, with its story), blueprints (found, researched, given), achievements, the colours and flags
the raft can wear, the records the leaderboards compare. Every reward lands the moment it's earned and is in the
profile right away (the save follows).

  XP       Constants.XP: hooking, building, crafting, voyages (more from dangerous waters), discoveries (the
           first time), creatures by size, fish, tiers; a cap a day (Constants.XP.cap) so a session can't be
           farmed flat
  journal  profile.journal[kind][key] = { at, n }: islands, creatures, fish, artifacts, events, notes
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Creatures = require(ReplicatedStorage.Shared.Data.Creatures)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Net = require(ReplicatedStorage.Shared.Net)
local Pieces = require(ReplicatedStorage.Shared.Data.Pieces)
local Progression = require(ReplicatedStorage.Shared.Data.Progression)
local Recipes = require(ReplicatedStorage.Shared.Data.Recipes)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Voyages = require(ReplicatedStorage.Shared.Data.Voyages)

local ProgressService = {
	Name = "ProgressService",
	Dependencies = {
		"PlayerDataService",
		"RaftService",
		"InventoryService",
		"PlayerService",
		"OceanService",
		"CraftService",
		"IslandService",
		"VoyageService",
		"CreatureService",
		"WeatherService",
		"TutorialService",
	},
	LeveledUp = Signal.new("ProgressService.LeveledUp"), -- (player, level)
	Achieved = Signal.new("ProgressService.Achieved"), -- (player, key)
	Discovered = Signal.new("ProgressService.Discovered"), -- (player, kind, key, first)
	Learned = Signal.new("ProgressService.Learned"), -- (player, kind, key, how)
	Rewarded = Signal.new("ProgressService.Rewarded"), -- (player, why) a moment the boards should write
	RecordsChanged = Signal.new("ProgressService.RecordsChanged"), -- (player)
	Trophied = Signal.new("ProgressService.Trophied"), -- (player, key)
}

local data, rafts, registry
local xpSession = {} -- [player] = xp this session

local function today()
	return math.floor(os.time() / 86400)
end

-- Views ------------------------------------------------------------------------------------------------------------------
function ProgressService:View(player)
	local profile = data:Get(player)
	if not profile then
		return nil
	end
	local level, into, need = Formulas.level(profile.xp)
	local titles = {}
	for _, t in Progression.TITLES do
		if profile.titles.owned[t.key] then
			table.insert(titles, t.key)
		end
	end
	local nextResearch
	for i, m in Progression.RESEARCH do
		if not profile.research.claimed[tostring(i)] then
			nextResearch = { points = m.points, name = m.name }
			break
		end
	end
	local journalCount = 0
	for _, kind in profile.journal do
		for _ in kind do
			journalCount += 1
		end
	end
	return {
		level = level,
		xp = profile.xp,
		into = into,
		need = need,
		xpSession = xpSession[player] or 0,
		title = profile.titles.equipped,
		titles = titles,
		flag = profile.flags.equipped,
		flags = profile.flags.owned,
		blueprints = profile.blueprints,
		known = profile.known,
		visited = profile.visited,
		research = { points = profile.research.points, next = nextResearch },
		achievements = profile.achievements,
		colours = profile.colours.owned,
		decks = profile.colours.decks,
		trophies = profile.trophies,
		journalCount = journalCount,
		stats = profile.stats,
		records = profile.records,
		settings = profile.settings,
		permit = profile.permit,
		tutorial = profile.tutorial,
		isNew = profile._isNew == true or nil,
	}
end

function ProgressService:Push(player)
	local view = self:View(player)
	if view then
		Net.fire(player, "Profile", view)
	end
end

function ProgressService:PushJournal(player)
	local profile = data:Get(player)
	if profile then
		Net.fire(player, "Journal", profile.journal)
	end
end

-- Titles: the ones your level and achievements have earned.
local function titleName(key)
	for _, t in Progression.TITLES do
		if t.key == key then
			return t.name
		end
	end
	return "Castaway"
end

function ProgressService:_dress(player, profile)
	local title = titleName(profile.titles.equipped)
	player:SetAttribute("Title", title)
	player:SetAttribute("Level", (Formulas.level(profile.xp)))
end

-- XP ------------------------------------------------------------------------------------------------------------------------
function ProgressService:AddXp(player, amount, reason)
	local profile = data:Get(player)
	if not profile or amount <= 0 then
		return 0
	end
	local day = today()
	if profile.xpToday.day ~= day then
		profile.xpToday.day, profile.xpToday.xp = day, 0
	end
	local room = Constants.XP.cap - profile.xpToday.xp
	amount = math.floor(math.min(amount, math.max(0, room)))
	if amount <= 0 then
		return 0
	end
	local before = Formulas.level(profile.xp)
	profile.xp += amount
	profile.xpToday.xp += amount
	xpSession[player] = (xpSession[player] or 0) + amount
	local after = Formulas.level(profile.xp)
	if after > before then
		for lv = before + 1, after do
			self:_levelUp(player, profile, lv)
		end
	end
	self:Push(player)
	_ = reason
	return amount
end

function ProgressService:_levelUp(player, profile, lv)
	local unlocked = {}
	for _, t in Progression.TITLES do
		if t.level == lv and not profile.titles.owned[t.key] then
			profile.titles.owned[t.key] = true
			table.insert(unlocked, `title: {t.name}`)
		end
	end
	for _, f in Progression.FLAGS do
		if f.level == lv and not profile.flags.owned[f.key] then
			profile.flags.owned[f.key] = true
			table.insert(unlocked, `flag: {f.name}`)
		end
	end
	Net.fire(player, "Unlock", { kind = "level", level = lv, unlocked = unlocked })
	Net.fire(player, "Sfx", "levelup")
	self:_dress(player, profile)
	self.LeveledUp:Fire(player, lv)
end

-- Stats, records, achievements --------------------------------------------------------------------------------------------
function ProgressService:Stat(player, key, delta)
	local profile = data:Get(player)
	if not profile then
		return
	end
	profile.stats[key] = (profile.stats[key] or 0) + (delta or 1)
	self:_checkAchievements(player, profile)
end

function ProgressService:Record(player, key, value, max)
	local profile = data:Get(player)
	if not profile then
		return
	end
	local old = profile.records[key] or 0
	local new = max and math.max(old, value) or value
	if new ~= old then
		profile.records[key] = new
		self.RecordsChanged:Fire(player)
	end
end

function ProgressService:Achieve(player, key)
	local profile = data:Get(player)
	local a = Progression.achievementByKey[key]
	if not profile or not a or profile.achievements[key] then
		return false
	end
	profile.achievements[key] = os.time()
	profile.records.achievementCount = (profile.records.achievementCount or 0) + 1
	for _, t in Progression.TITLES do
		if t.achievement == key then
			profile.titles.owned[t.key] = true
		end
	end
	for _, f in Progression.FLAGS do
		if f.achievement == key then
			profile.flags.owned[f.key] = true
		end
	end
	Net.fire(player, "Unlock", { kind = "achievement", key = key, name = a.name, icon = a.icon, desc = a.desc })
	Net.fire(player, "Sfx", "win")
	self.RecordsChanged:Fire(player)
	self.Achieved:Fire(player, key)
	self:Push(player)
	return true
end

function ProgressService:_checkAchievements(player, profile)
	for _, a in Progression.ACHIEVEMENTS do
		if a.stat and not profile.achievements[a.key] and (profile.stats[a.stat] or 0) >= a.goal then
			self:Achieve(player, a.key)
		end
	end
end

-- The journal ------------------------------------------------------------------------------------------------------------
local function nameOf(kind, key)
	if kind == "islands" then
		local d = Voyages.get(key)
		return d and d.name or key, d and d.icon or "🏝️"
	elseif kind == "creatures" then
		local c = Creatures.get(key)
		return c and c.name or key, c and c.icon or "🐾"
	elseif kind == "fish" then
		local f = Creatures.fishByKey[key]
		return f and f.name or key, f and f.icon or "🐟"
	elseif kind == "artifacts" then
		local it = Items.get(key)
		return it and it.name or key, it and it.icon or "🏺"
	elseif kind == "events" then
		for _, e in Voyages.EVENTS do
			if e.key == key then
				return e.name, e.icon
			end
		end
	end
	return key, "📔"
end

-- Something met: the first time it's a discovery (XP, the journal, the records); after that a small find.
function ProgressService:Discover(player, kind, key, quiet)
	local profile = data:Get(player)
	if not profile or not key then
		return false
	end
	profile.journal[kind] = profile.journal[kind] or {}
	local entry = profile.journal[kind][key]
	local first = entry == nil
	if first then
		profile.journal[kind][key] = { at = os.time(), n = 1 }
		profile.stats.journal += 1
		profile.records.discoveries = (profile.records.discoveries or 0) + 1
		local name, icon = nameOf(kind, key)
		if not quiet then
			Net.fire(player, "Unlock", { kind = "discovery", journal = kind, key = key, name = name, icon = icon })
			Net.fire(player, "Sfx", "discover")
		end
		self:AddXp(player, Constants.XP.discovery, "discovery")
		self.RecordsChanged:Fire(player)
		self:_checkAchievements(player, profile)
		self:PushJournal(player)
	else
		entry.n += 1
		if kind ~= "fish" and kind ~= "creatures" then
			self:AddXp(player, Constants.XP.repeatFind, "find")
		end
	end
	self.Discovered:Fire(player, kind, key, first)
	return first
end

function ProgressService:Note(player, key, text)
	local profile = data:Get(player)
	if not profile then
		return
	end
	if not profile.journal.notes[key] then
		profile.journal.notes[key] = { at = os.time(), n = 1, text = text }
		self:PushJournal(player)
	end
end

-- Blueprints and trophies ---------------------------------------------------------------------------------------------
function ProgressService:LearnBlueprint(player, kind, key, how)
	local profile = data:Get(player)
	if not profile then
		return false
	end
	local def = kind == "piece" and Pieces.get(key) or Recipes.get(key)
	if not def or profile.blueprints[key] then
		return false
	end
	profile.blueprints[key] = true
	local name = def.name or (def.item and Items.get(def.item) and Items.get(def.item).name) or key
	local icon = def.icon or (def.item and Items.get(def.item) and Items.get(def.item).icon) or "📜"
	Net.fire(
		player,
		"Unlock",
		{ kind = "blueprint", key = key, name = name, icon = icon, how = how, piece = kind == "piece" or nil }
	)
	Net.fire(player, "Sfx", "discover")
	self:Push(player)
	self.Learned:Fire(player, kind, key, how)
	return true
end

function ProgressService:Trophy(player, key)
	local profile = data:Get(player)
	if not profile or profile.trophies[key] then
		return false
	end
	profile.trophies[key] = true
	local raft = rafts:RaftOf(player)
	if raft then
		raft.trophies = profile.trophies
		rafts:Recompute(raft)
		rafts:Push(raft)
	end
	self.Trophied:Fire(player, key)
	return true
end

-- Settings, titles, flags -------------------------------------------------------------------------------------------
function ProgressService:Settings(player, key, value)
	local profile = data:Get(player)
	if not profile then
		return false
	end
	if key == "music" or key == "shake" or key == "fx" then
		if type(value) ~= "boolean" then
			return false
		end
		profile.settings[key] = value
	elseif key == "title" then
		if type(value) ~= "string" or not profile.titles.owned[value] then
			return false
		end
		profile.titles.equipped = value
		self:_dress(player, profile)
	elseif key == "flag" then
		if type(value) ~= "string" or not profile.flags.owned[value] then
			return false
		end
		profile.flags.equipped = value
		rafts:Paint(player, "pattern", value)
	else
		return false
	end
	self:Push(player)
	return true
end

-- Wiring ---------------------------------------------------------------------------------------------------------------
function ProgressService:Init(reg)
	registry = reg
	data = reg.PlayerDataService
	rafts = reg.RaftService
	local inventory, ocean, craft, island, voyages, creatures, weather, tutorial =
		reg.InventoryService,
		reg.OceanService,
		reg.CraftService,
		reg.IslandService,
		reg.VoyageService,
		reg.CreatureService,
		reg.WeatherService,
		reg.TutorialService
	Net.on("Settings", function(player, key, value)
		self:Settings(player, key, value)
	end)
	-- the raft
	rafts.Built:Connect(function(player, piece, raft)
		self:AddXp(player, Constants.XP.build, "build")
		local profile = data:Get(player)
		if profile then
			profile.stats.built += 1
			if piece.def.structural then
				profile.stats.tiles = raft.summary.tiles
				self:Record(player, "tiles", raft.summary.tiles, true)
			end
			self:_checkAchievements(player, profile)
		end
	end)
	rafts.TierChanged:Connect(function(player, raft, tier, old)
		if not player or not player.Parent or tier <= old then
			return
		end
		local profile = data:Get(player)
		local t = Pieces.TIERS[tier]
		self:AddXp(player, Constants.XP.tier * tier, "tier")
		if profile then
			profile.stats.tier = math.max(profile.stats.tier, tier)
			self:Record(player, "tier", tier, true)
			self:_checkAchievements(player, profile)
		end
		Net.fire(player, "Unlock", {
			kind = "tier",
			tier = tier,
			name = t and t.name or "",
			icon = t and t.icon or "⛵",
			desc = t and t.desc or "",
		})
		Net.fire(player, "Sfx", "win")
		for _, other in Players:GetPlayers() do
			if other ~= player then
				Net.fire(
					other,
					"Toast",
					`⛵ {player.DisplayName}'s raft is now a {t and t.name or "bigger raft"}!`,
					"info"
				)
			end
		end
		self.Rewarded:Fire(player, "tier")
		_ = raft
	end)
	-- the ocean
	ocean.Hooked:Connect(function(player, d)
		self:AddXp(player, Constants.XP.debris, "debris")
		self:Stat(player, "debris", 1)
		_ = d
	end)
	ocean.Caught:Connect(function(player, fish)
		local rare = fish.rarity ~= "common" and fish.rarity ~= "uncommon"
		self:AddXp(player, rare and Constants.XP.rareFish or Constants.XP.fish, "fish")
		local profile = data:Get(player)
		if profile then
			profile.stats.fish += 1
			self:Record(player, "fish", profile.stats.fish)
			if rare then
				self:Achieve(player, "fish_rare")
			end
			if fish.key == "golden_koi" then
				self:Achieve(player, "koi")
			end
			self:_checkAchievements(player, profile)
		end
		if not fish.junk then
			self:Discover(player, "fish", fish.key)
		end
	end)
	-- crafting and research
	craft.Crafted:Connect(function(player)
		self:AddXp(player, Constants.XP.craft, "craft")
		local profile = data:Get(player)
		if profile then
			self:_checkAchievements(player, profile)
		end
	end)
	craft.Researched:Connect(function(player)
		local profile = data:Get(player)
		if profile then
			self:_checkAchievements(player, profile)
		end
	end)
	inventory.Gained:Connect(function(player, key)
		local item = Items.get(key)
		if item and item.kind == "artifact" then
			self:Discover(player, "artifacts", key)
		end
	end)
	-- islands
	island.Searched:Connect(function(player)
		self:AddXp(player, Constants.XP.repeatFind, "search")
	end)
	island.Looked:Connect(function(player, isl, first)
		if first then
			self:Note(player, isl.dest.key, isl.landmark.text)
			self:AddXp(player, Constants.XP.repeatFind, "landmark")
		end
	end)
	island.Solved:Connect(function(_, isl, here)
		for _, player in here do
			local profile = data:Get(player)
			if profile and not profile.journal.notes["puzzle_" .. isl.dest.key] then
				profile.journal.notes["puzzle_" .. isl.dest.key] =
					{ at = os.time(), n = 1, text = `Solved: {isl.puzzle.kind} at {isl.dest.name}.` }
				self:Stat(player, "puzzles", 1)
				self:AddXp(player, Constants.XP.discovery, "puzzle")
			end
		end
	end)
	-- voyages
	voyages.Arrived:Connect(function(_, dest, here)
		for _, player in here do
			self:Discover(player, "islands", dest.key)
			local profile = data:Get(player)
			if profile then
				if dest.kind == "wreck" then
					self:Stat(player, "wrecks", 1)
				end
				local all = true
				for _, d in Voyages.list do
					if not profile.visited[d.key] then
						all = false
					end
				end
				if all then
					self:Achieve(player, "islands_all")
				end
			end
		end
	end)
	voyages.Event:Connect(function(_, e, here)
		for _, player in here do
			self:Discover(player, "events", e.key, true)
		end
	end)
	voyages.Ended:Connect(function(_, dest, here, danger)
		for _, player in here do
			self:AddXp(player, Constants.XP.voyage + (danger - 1) * 20, "voyage")
			local profile = data:Get(player)
			if profile then
				profile.stats.voyages += 1
				self:Record(player, "voyages", profile.stats.voyages)
				self:_checkAchievements(player, profile)
			end
			self.Rewarded:Fire(player, "voyage")
		end
		_ = dest
	end)
	voyages.Revealed:Connect(function(player)
		self:Push(player)
	end)
	-- creatures
	creatures.Hit:Connect(function(c, _, player)
		if player then
			self:Discover(player, "creatures", c.kind, true)
		end
	end)
	creatures.Killed:Connect(function(c, killer, hits)
		local xp = Constants.XP.creature[c.def.size] or 3
		local stat = c.kind == "shark" and "sharks"
			or c.kind == "sea_serpent" and "serpents"
			or c.kind == "ruin_guardian" and "guardians"
			or c.kind == "leviathan" and "leviathans"
			or nil
		local rewarded = {}
		for player in hits do
			if player.Parent then
				rewarded[player] = true
			end
		end
		if killer and killer.Parent then
			rewarded[killer] = true
		end
		if c.boss then
			for _, p in registry.PlayerService:PlayersOnPlot(c.plot) do
				rewarded[p] = true
			end
		end
		for player in rewarded do
			self:AddXp(player, xp, "kill")
			self:Discover(player, "creatures", c.kind)
			if stat then
				self:Stat(player, stat, 1)
			end
			if c.boss then
				self:Trophy(player, "tooth")
				local profile = data:Get(player)
				if profile then
					self:Record(player, "leviathans", profile.stats.leviathans)
				end
				self.Rewarded:Fire(player, "leviathan")
			end
		end
	end)
	-- the weather
	weather.StormEnded:Connect(function(_, survivors)
		for _, player in survivors do
			self:Stat(player, "storms", 1)
		end
	end)
	-- the guide
	tutorial.StepDone:Connect(function(player, _, key)
		local xp = Constants.XP.guide[key]
		if xp then
			self:AddXp(player, xp, "guide")
		end
	end)
	reg.VisitService.Visited:Connect(function(_, host)
		local profile = data:Get(host)
		if profile then
			self:_checkAchievements(host, profile)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		xpSession[player] = nil
	end)
end

function ProgressService:OnPlayerReady(player, profile)
	xpSession[player] = 0
	self:_dress(player, profile)
	-- a raft loaded from a save might already be past a record
	local raft = rafts:RaftOf(player)
	if raft then
		self:Record(player, "tier", raft.tier, true)
		self:Record(player, "tiles", raft.summary.tiles, true)
	end
	data:WhenClientReady(player, function()
		self:Push(player)
		self:PushJournal(player)
	end)
end

function ProgressService:OnPlayerLeaving(player, profile)
	local joined = profile._joinedAt
	if joined then
		profile.stats.minutes += math.floor((os.time() - joined) / 60)
	end
	xpSession[player] = nil
end

return ProgressService
