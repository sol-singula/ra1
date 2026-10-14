--[[
Permanent progression (master plan §9) and the end of a run.

  XP and levels    earned as you play (discoveries, kills, revives, team goals, the camp) and at each dawn and a win;
                   saved straight away, so leaving early keeps what you earned (§8). Levels unlock perks, starting kits,
                   titles and looks (choices, not bigger numbers).
  mastery          hits, kills and uses with a class of item (Data/Items.masteryClass) -> levels 1-10: an alternate move
                   at 3, a golden look at 5, a title at 10.
  bestiary         monsters you've seen and beaten, golden ones, the tells you've read (MonsterService.Learned and
                   SurvivorService.Dodged), trophies (a chance on every kill: monster parts for your collection).
  collection       every item you've ever had, every kind of finding visited, Kermy's diary pages.
  achievements     Data/Progression.ACHIEVEMENTS: some count a stat, some are a moment.
  difficulty       winning unlocks the next difficulty.
  records          what the friend leaderboards compare (LeaderboardService).
  results          at the end of a run: what you and the team did, XP, levels, unlocks ("Results").
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Enemies = require(ReplicatedStorage.Shared.Data.Enemies)
local Findings = require(ReplicatedStorage.Shared.Data.Findings)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Looks = require(ReplicatedStorage.Shared.World.Looks)
local Net = require(ReplicatedStorage.Shared.Net)
local Progression = require(ReplicatedStorage.Shared.Data.Progression)
local Signal = require(ReplicatedStorage.Shared.Signal)

local ProgressService = {
	Name = "ProgressService",
	Dependencies = {
		"PlayerDataService",
		"RunService",
		"SurvivorService",
		"InventoryService",
		"ResourceService",
		"CampService",
		"CraftService",
		"LootService",
		"MonsterService",
		"BossService",
		"CombatService",
		"WorldService",
		"ObjectiveService",
	},
	LeveledUp = Signal.new("ProgressService.LeveledUp"), -- (player, level)
	MasteryUp = Signal.new("ProgressService.MasteryUp"), -- (player, class, level)
	Achieved = Signal.new("ProgressService.Achieved"), -- (player, key)
	Discovered = Signal.new("ProgressService.Discovered"), -- (player, kind, key, first)
	Rewarded = Signal.new("ProgressService.Rewarded"), -- (player, result, you)
	RecordsChanged = Signal.new("ProgressService.RecordsChanged"), -- (player)
	Trophy = Signal.new("ProgressService.Trophy"), -- (player, trophyKey)
}

local data, runs, survivors, inventory, resources, camp, craft, loot, monsters, boss, combat, world, objectives
local runStats = {} -- [player] = this run's tally
local lastClass = {} -- [player] = the mastery class of the last thing they hit with
local teamGhosts = 0
local pushQueued = {}

local TROPHY_CHANCE = { small = 0.04, medium = 0.06, heavy = 0.12 }

local function now()
	return workspace:GetServerTimeNow()
end

local function stats(player)
	local r = runStats[player]
	if not r then
		r = {
			xp = 0,
			kills = 0,
			killXp = 0,
			revives = 0,
			firsts = 0,
			repeats = 0,
			objectives = 0,
			contributed = 0,
			loot = 0,
			crafted = 0,
			built = 0,
			bossDamage = 0,
			damageDealt = 0,
			kermyKO = 0,
			found = {},
			levelsGained = 0,
			unlocks = {},
		}
		runStats[player] = r
	end
	return r
end

-- Views ---------------------------------------------------------------------------------------------------------------
function ProgressService:View(player)
	local profile = data:Get(player)
	if not profile then
		return nil
	end
	local level, into, need = Formulas.level(profile.xp)
	local mastery = {}
	for class, xp in profile.mastery do
		local lv, frac = Formulas.mastery(xp)
		mastery[class] = { level = lv, frac = frac, xp = xp }
	end
	local kits = {}
	for _, k in Progression.KITS do
		kits[k.key] = k.level <= level
	end
	local perksOpen = {}
	for _, p in Progression.PERKS do
		perksOpen[p.key] = p.level <= level
	end
	local items, findings, trophies, pages = 0, 0, 0, 0
	for _ in profile.collection.items do
		items += 1
	end
	for _ in profile.collection.findings do
		findings += 1
	end
	for _ in profile.collection.trophies do
		trophies += 1
	end
	for _ in profile.collection.pages do
		pages += 1
	end
	return {
		level = level,
		xp = profile.xp,
		xpInto = into,
		xpNeed = need,
		unlocked = profile.unlocked,
		kit = profile.kit,
		kits = kits,
		perks = table.clone(profile.perks),
		perkSlots = Progression.perkSlots(level),
		perksOpen = perksOpen,
		mastery = mastery,
		bestiary = profile.bestiary,
		collection = profile.collection,
		counts = { items = items, findings = findings, trophies = trophies, pages = pages },
		achievements = profile.achievements,
		titles = profile.titles,
		looks = profile.looks,
		records = profile.records,
		stats = profile.stats,
		settings = profile.settings,
		tutorialDone = profile.tutorial.done == true,
	}
end

function ProgressService:Push(player)
	if pushQueued[player] then
		return
	end
	pushQueued[player] = true
	task.delay(0.25, function()
		pushQueued[player] = nil
		if player.Parent then
			local v = self:View(player)
			if v then
				Net.fire(player, "Profile", v)
			end
		end
	end)
end

local function unlock(player, t)
	table.insert(stats(player).unlocks, t)
	Net.fire(player, "Unlock", t)
end

-- XP and levels ---------------------------------------------------------------------------------------------------------
function ProgressService:AddXp(player, amount, reason, ignoreCap)
	local profile = data:Get(player)
	if not profile or amount <= 0 then
		return 0
	end
	local r = stats(player)
	if not ignoreCap then
		amount = math.min(amount, math.max(0, Constants.XP.cap - r.xp))
	end
	amount = math.floor(amount + 0.5)
	if amount <= 0 then
		return 0
	end
	local before = Formulas.level(profile.xp)
	profile.xp += amount
	r.xp += amount
	local after = Formulas.level(profile.xp)
	if after > before then
		for lv = before + 1, after do
			self:_levelUnlocks(player, profile, lv)
		end
		r.levelsGained += after - before
		self.LeveledUp:Fire(player, after)
		Net.fire(player, "Sfx", "levelup")
	end
	self:Push(player)
	_ = reason
	return amount
end

function ProgressService:_levelUnlocks(player, profile, lv)
	local news = {}
	for _, p in Progression.PERKS do
		if p.level == lv then
			table.insert(news, `{p.icon} Perk: {p.name}`)
		end
	end
	for _, k in Progression.KITS do
		if k.level == lv then
			table.insert(news, `{k.icon} Kit: {k.name}`)
		end
	end
	for _, t in Progression.TITLES do
		if t.level == lv and not profile.titles.owned[t.key] then
			profile.titles.owned[t.key] = true
			table.insert(news, `🏷️ Title: {t.name}`)
		end
	end
	for _, l in Progression.LOOKS do
		if l.level == lv and not profile.looks.owned[l.key] then
			profile.looks.owned[l.key] = true
			table.insert(news, `{l.icon} Look: {l.name}`)
		end
	end
	if lv == 2 or lv == 10 then
		table.insert(news, "A new perk slot!")
	end
	-- (news is one line for the card; lines lists each unlock)
	local line = `⬆️ LEVEL {lv}!`
	if #news > 0 then
		line ..= "  " .. table.concat(news, "  ·  ")
	end
	unlock(player, { kind = "level", level = lv, news = line, lines = news })
end

-- Mastery ------------------------------------------------------------------------------------------------------------------
function ProgressService:AddMastery(player, class, amount)
	local profile = data:Get(player)
	if not profile or not class or not profile.mastery[class] then
		return
	end
	local before = Formulas.mastery(profile.mastery[class])
	profile.mastery[class] += amount
	local after = Formulas.mastery(profile.mastery[class])
	if after > before then
		local total = 0
		for _, xp in profile.mastery do
			total += (Formulas.mastery(xp))
		end
		profile.records.masteryTotal = total
		local reward = Progression.MASTERY_REWARDS[after]
		local news
		if reward == "special" then
			local sp = Progression.SPECIALS[class]
			news = sp and `New move: {sp.name}! {sp.desc}` or nil
		elseif reward == "golden" then
			news = `Your {Items.CLASSES[class].name} gleams gold.`
		elseif reward == "title" then
			for _, t in Progression.TITLES do
				if t.mastery == class then
					profile.titles.owned[t.key] = true
					news = `Title: {t.name}`
				end
			end
			self:Achieve(player, "mastery_10")
		end
		unlock(player, { kind = "mastery", class = class, level = after, news = news })
		self.MasteryUp:Fire(player, class, after)
		self.RecordsChanged:Fire(player)
	end
	self:Push(player)
end

-- The bestiary --------------------------------------------------------------------------------------------------------------
local function entry(profile, key)
	local e = profile.bestiary[key]
	if not e then
		e = { seen = false, defeated = 0, golden = 0, tells = {} }
		profile.bestiary[key] = e
	end
	return e
end

function ProgressService:Seen(player, key, elite)
	local profile = data:Get(player)
	if not profile or not Enemies.get(key) then
		return
	end
	local e = entry(profile, key)
	if not e.seen then
		e.seen = true
		local def = Enemies.get(key)
		unlock(player, { kind = "bestiary", key = key, news = `New in your bestiary: {def.icon} {def.name}` })
		self:AddXp(player, Constants.XP.discovery, "bestiary")
		stats(player).firsts += 1
		self.Discovered:Fire(player, "monster", key, true)
		self:Push(player)
	end
	_ = elite
end

function ProgressService:Learn(player, key, tip)
	local profile = data:Get(player)
	local def = Enemies.get(key)
	if not profile or not def or not def.tips[tip] then
		return
	end
	local e = entry(profile, key)
	local before = e.tells[tip] or 0
	e.tells[tip] = before + 1
	if before == 0 then
		unlock(player, { kind = "tell", key = key, tip = tip, news = `{def.icon} Learned: {def.tips[tip]}` })
		self:_checkBestiary(player, profile)
		self:Push(player)
	end
end

function ProgressService:_checkBestiary(player, profile)
	for _, def in Enemies.list do
		local e = profile.bestiary[def.key]
		if not e then
			return
		end
		for tip in def.tips do
			if not e.tells[tip] then
				return
			end
		end
	end
	self:Achieve(player, "bestiary")
end

function ProgressService:_trophy(player, key)
	local profile = data:Get(player)
	if not profile or not key then
		return
	end
	local first = not profile.collection.trophies[key]
	profile.collection.trophies[key] = (profile.collection.trophies[key] or 0) + 1
	if first then
		profile.records.discoveryScore += 12
		self.RecordsChanged:Fire(player)
	end
	unlock(player, { kind = "trophy", key = key, first = first, news = `🏆 Trophy: {key}` })
	self.Trophy:Fire(player, key)
	self:Push(player)
end

-- Collection --------------------------------------------------------------------------------------------------------------
function ProgressService:FoundItem(player, key)
	local profile = data:Get(player)
	local item = Items.get(key)
	if not profile or not item then
		return
	end
	if item.rarity == "legendary" then
		self:Achieve(player, "legendary")
	end
	if profile.collection.items[key] then
		return
	end
	profile.collection.items[key] = true
	local n = 0
	for _ in profile.collection.items do
		n += 1
	end
	profile.records.discoveryScore += Formulas.discoveryPoints(item.rarity)
	stats(player).firsts += 1
	self:AddXp(player, Constants.XP.discovery * (item.kind == "resource" and 0.25 or 1), "item")
	unlock(player, { kind = "item", key = key, news = `{item.icon} New find: {item.name}` })
	self:_statAchievements(player, profile)
	self.Discovered:Fire(player, "item", key, true)
	self.RecordsChanged:Fire(player)
	self:Push(player)
	_ = n
end

function ProgressService:FoundFinding(player, f)
	local profile = data:Get(player)
	if not profile then
		return
	end
	local key = f.key
	local first = not profile.collection.findings[key]
	profile.collection.findings[key] = (profile.collection.findings[key] or 0) + 1
	local r = stats(player)
	if first then
		r.firsts += 1
		profile.records.discoveryScore += 10
		self:AddXp(player, Constants.XP.discovery, "finding")
		unlock(player, { kind = "finding", key = key, news = `{f.def.icon} Discovered: {f.def.name}` })
		local all = true
		for _, def in Findings.list do
			if not profile.collection.findings[def.key] then
				all = false
			end
		end
		if all then
			self:Achieve(player, "explorer")
		end
		self.RecordsChanged:Fire(player)
	elseif not r.found[key] then
		r.repeats += 1
		self:AddXp(player, Constants.XP.repeatFind, "finding")
	end
	r.found[key] = true
	self.Discovered:Fire(player, "finding", key, first)
	self:Push(player)
end

function ProgressService:FoundPage(player, index)
	local profile = data:Get(player)
	if not profile or profile.collection.pages[index] then
		return
	end
	profile.collection.pages[index] = true
	profile.records.discoveryScore += 15
	stats(player).firsts += 1
	self:AddXp(player, Constants.XP.discovery, "page")
	local n = 0
	for _ in profile.collection.pages do
		n += 1
	end
	unlock(player, { kind = "page", index = index, news = `📖 Kermy's diary: page {index} ({n}/7)` })
	if n >= #Findings.PAGES then
		self:Achieve(player, "pages_7")
	end
	self.Discovered:Fire(player, "page", tostring(index), true)
	self.RecordsChanged:Fire(player)
	self:Push(player)
end

-- Achievements -------------------------------------------------------------------------------------------------------------
function ProgressService:Achieve(player, key)
	local profile = data:Get(player)
	local def = Progression.achievementByKey[key]
	if not profile or not def or profile.achievements[key] then
		return false
	end
	profile.achievements[key] = os.time()
	local n = 0
	for _ in profile.achievements do
		n += 1
	end
	profile.records.achievementCount = n
	local news = {}
	for _, t in Progression.TITLES do
		if t.achievement == key then
			profile.titles.owned[t.key] = true
			table.insert(news, `🏷️ Title: {t.name}`)
		end
	end
	for _, l in Progression.LOOKS do
		if l.achievement == key then
			profile.looks.owned[l.key] = true
			table.insert(news, `{l.icon} Look: {l.name}`)
		end
	end
	unlock(player, { kind = "achievement", key = key, name = def.name, icon = def.icon, desc = def.desc, news = news })
	Net.fireAll("Toast", `🏆 {player.DisplayName}: {def.name}!`, "good")
	self.Achieved:Fire(player, key)
	self.RecordsChanged:Fire(player)
	self:Push(player)
	return true
end

function ProgressService:_statAchievements(player, profile)
	local values = {
		kermyKO = profile.stats.kermyKO,
		monsters = profile.records.monsters,
		rescues = profile.records.rescues,
		dodged = profile.stats.dodged,
		mimics = profile.stats.mimics,
		wood = profile.stats.wood,
		itemsFound = 0,
	}
	for _ in profile.collection.items do
		values.itemsFound += 1
	end
	for _, a in Progression.ACHIEVEMENTS do
		if a.stat and a.goal and (values[a.stat] or 0) >= a.goal then
			self:Achieve(player, a.key)
		end
	end
end

-- Kills --------------------------------------------------------------------------------------------------------------------
function ProgressService:_onKilled(m, killer, assists)
	local def = m.def
	local size = def.size
	local xpTable = Constants.XP.kill
	local xp = m.kind == "kermy" and xpTable.kermy or (xpTable[size] or 2)
	if m.elite then
		xp *= 3
	end
	for player, dmg in assists do
		local profile = data:Get(player)
		if profile then
			local e = entry(profile, m.kind)
			e.seen = true
			e.defeated += 1
			if m.elite then
				e.golden += 1
			end
			profile.records.monsters += 1
			local r = stats(player)
			r.kills += 1
			local share = player == killer and 1 or 0.5
			r.killXp += xp * share
			self:AddXp(player, xp * share, "kill")
			if m.kind == "mimic" then
				profile.stats.mimics += 1
			end
			self:_statAchievements(player, profile)
			self.RecordsChanged:Fire(player)
		end
		_ = dmg
	end
	if killer then
		local class = lastClass[killer]
		if class then
			self:AddMastery(
				killer,
				class,
				Constants.MASTERY_GAIN.kill * (size == "heavy" and 3 or size == "medium" and 2 or 1)
			)
		end
		local chance = m.elite and 0.5 or (TROPHY_CHANCE[size] or 0.05)
		if m.kind ~= "kermy" and math.random() < chance then
			self:_trophy(killer, m.elite and ("golden_" .. def.trophy) or def.trophy)
		end
	end
end

function ProgressService:_onKermyKO(_, killer, assists)
	for player in assists do
		local profile = data:Get(player)
		if profile then
			profile.stats.kermyKO += 1
			stats(player).kermyKO += 1
			self:Achieve(player, "kermy_ko")
			self:_statAchievements(player, profile)
		end
	end
	if killer and math.random() < 0.25 then
		self:_trophy(killer, "kermy_scrap")
	end
end

-- Nights and the end of the run ---------------------------------------------------------------------------------------------------
function ProgressService:_onNightSurvived(n)
	for _, player in runs:Active() do
		local profile = data:Get(player)
		if profile then
			self:AddXp(player, Constants.XP.night * n, "night")
			profile.records.nights += 1
			profile.records.bestNight = math.max(profile.records.bestNight, n)
			if n == 1 then
				self:Achieve(player, "first_night")
			elseif n == 4 then
				self:Achieve(player, "halfway")
			end
			self.RecordsChanged:Fire(player)
		end
	end
end

function ProgressService:_onEnded(result)
	if result.reason == "empty" then
		return
	end
	local d = Formulas.difficulty(result.difficulty)
	local rosterSize = 0
	for _ in result.roster do
		rosterSize += 1
	end
	local team = {}
	for _, player in runs:Active() do
		local r = stats(player)
		local s = survivors:Stats(player)
		table.insert(team, {
			userId = player.UserId,
			name = player.DisplayName,
			kills = r.kills,
			revives = s.revives,
			built = math.floor(camp:Contribution(player)),
			damage = s.damage,
			found = r.firsts + r.repeats,
		})
	end
	-- the stars of the run (§7: recognise every way of helping)
	local mvps = {}
	local function best(field, label)
		local top, topV = nil, 0
		for _, t in team do
			if (t[field] or 0) > topV then
				top, topV = t, t[field]
			end
		end
		if top then
			table.insert(mvps, { label = label, name = top.name, value = topV, userId = top.userId })
		end
	end
	best("kills", "⚔️ Most monsters")
	best("revives", "🤝 Most revives")
	best("built", "🛠️ Built the most")
	best("found", "🧭 Found the most")
	for _, player in runs:Active() do
		local profile = data:Get(player)
		if profile then
			local r = stats(player)
			local s = survivors:Stats(player)
			profile.stats.runs += 1
			profile.records.rescues = profile.records.rescues -- (counted live)
			if result.won then
				profile.stats.wins += 1
				self:AddXp(player, Constants.XP.win * d.xp, "win", true)
				profile.records.bestDifficulty = math.max(profile.records.bestDifficulty, result.difficulty)
				if profile.records.fastestWin == 0 or result.seconds < profile.records.fastestWin then
					profile.records.fastestWin = result.seconds
				end
				local before = profile.unlocked
				profile.unlocked = math.max(profile.unlocked, math.min(#Constants.DIFFICULTIES, result.difficulty + 1))
				if profile.unlocked > before then
					unlock(player, {
						kind = "difficulty",
						news = `💀 New difficulty unlocked: {Constants.DIFFICULTIES[profile.unlocked].name}`,
					})
				end
				self:Achieve(player, "survivor")
				if result.difficulty >= 2 then
					self:Achieve(player, "hard_win")
				end
				if result.difficulty >= 3 then
					self:Achieve(player, "nightmare_win")
				end
				if result.difficulty >= 4 then
					self:Achieve(player, "sixseven_win")
				end
				if rosterSize == 1 then
					self:Achieve(player, "solo_win")
				end
				if teamGhosts == 0 then
					self:Achieve(player, "no_one_left")
				end
				if s.damage < 250 then
					self:Achieve(player, "untouched")
				end
				if result.seconds < 22 * 60 then
					self:Achieve(player, "speedrunner")
				end
			end
			local level, into, need = Formulas.level(profile.xp)
			local you = {
				kills = r.kills,
				revives = s.revives,
				downs = s.downs,
				damage = s.damage,
				found = r.firsts + r.repeats,
				firsts = r.firsts,
				built = math.floor(camp:Contribution(player)),
				xp = r.xp,
				level = level,
				xpInto = into,
				xpNeed = need,
				levelsGained = r.levelsGained,
				unlocks = r.unlocks,
			}
			Net.fire(player, "Results", {
				won = result.won,
				reason = result.reason,
				nights = result.nights,
				seconds = result.seconds,
				difficulty = result.difficulty,
				team = team,
				mvps = mvps,
				you = you,
				nextIn = Constants.RESULTS_SECONDS,
			})
			self.Rewarded:Fire(player, result, you)
			self.RecordsChanged:Fire(player)
			self:Push(player)
		end
	end
	data:SaveAll()
end

-- Choices: kit, perks, looks, titles, settings, emotes ------------------------------------------------------------------------------
function ProgressService:SetKit(player, key)
	local profile = data:Get(player)
	local kit = Progression.kitByKey[key]
	if not profile or not kit or kit.level > Formulas.level(profile.xp) then
		return false
	end
	profile.kit = key
	Net.fire(player, "Toast", `{kit.icon} Next run you start as a {kit.name}.`, "info")
	self:Push(player)
	return true
end

function ProgressService:SetPerk(player, index, key)
	local profile = data:Get(player)
	if not profile then
		return false
	end
	local level = Formulas.level(profile.xp)
	local slots = Progression.perkSlots(level)
	index = math.floor(tonumber(index) or 0)
	if index < 1 or index > slots then
		return false
	end
	if key == false or key == nil then
		profile.perks[index] = nil
	else
		local perk = Progression.perkByKey[key]
		if not perk or perk.level > level then
			return false
		end
		for i, k in profile.perks do
			if k == key and i ~= index then
				profile.perks[i] = nil
			end
		end
		profile.perks[index] = key
	end
	-- keep it a plain list
	local clean = {}
	for i = 1, slots do
		if profile.perks[i] then
			table.insert(clean, profile.perks[i])
		end
	end
	profile.perks = clean
	self:Push(player)
	return true
end

function ProgressService:Wear(player, slot, key)
	local profile = data:Get(player)
	if not profile or type(slot) ~= "string" then
		return false
	end
	if slot == "title" then
		if key and not profile.titles.owned[key] then
			return false
		end
		profile.titles.equipped = key or "camper"
		self:_titleBoard(player)
	else
		local look = key and Progression.lookByKey[key]
		if key and (not look or not profile.looks.owned[key] or look.slot ~= slot) then
			return false
		end
		profile.looks.equipped[slot] = key or nil
		self:_dress(player)
	end
	self:Push(player)
	return true
end

function ProgressService:_dress(player)
	local profile = data:Get(player)
	local c = player.Character
	if not profile or not c then
		return
	end
	for _, child in c:GetChildren() do
		if string.sub(child.Name, 1, 5) == "Look_" then
			child:Destroy()
		end
	end
	for _, key in profile.looks.equipped do
		Looks.wear(c, key)
	end
	self:_titleBoard(player)
end

function ProgressService:_titleBoard(player)
	local profile = data:Get(player)
	local c = player.Character
	local head = c and c:FindFirstChild("Head")
	if not profile or not head then
		return
	end
	local old = head:FindFirstChild("Title")
	if old then
		old:Destroy()
	end
	local t = Progression.titleByKey[profile.titles.equipped]
	if not t or t.key == "camper" then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "Title"
	bb.Size = UDim2.fromOffset(160, 22)
	bb.StudsOffset = Vector3.new(0, 3.1, 0)
	bb.MaxDistance = 60
	bb.LightInfluence = 0
	bb.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = t.name
	label.TextColor3 = Color3.fromRGB(255, 222, 120)
	label.TextStrokeTransparency = 0.3
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.Parent = bb
end

function ProgressService:Settings(player, key, value)
	local profile = data:Get(player)
	if not profile or type(key) ~= "string" or type(value) ~= "boolean" then
		return
	end
	if profile.settings[key] == nil then
		return
	end
	profile.settings[key] = value
	self:Push(player)
end

-- Wiring ---------------------------------------------------------------------------------------------------------------------------------
function ProgressService:Init(registry)
	data = registry.PlayerDataService
	runs = registry.RunService
	survivors = registry.SurvivorService
	inventory = registry.InventoryService
	resources = registry.ResourceService
	camp = registry.CampService
	craft = registry.CraftService
	loot = registry.LootService
	monsters = registry.MonsterService
	boss = registry.BossService
	combat = registry.CombatService
	world = registry.WorldService
	objectives = registry.ObjectiveService

	Net.on("Loadout", function(player, key)
		self:SetKit(player, key)
	end)
	Net.on("Perk", function(player, index, key)
		self:SetPerk(player, index, key)
	end)
	Net.on("Wear", function(player, slot, key)
		self:Wear(player, slot, key)
	end)
	Net.on("Settings", function(player, key, value)
		self:Settings(player, key, value)
	end)
	Net.on("Emote", function(player, key)
		if survivors:IsAlive(player) and (key == "67" or key == "wave" or key == "dance") then
			Net.fireAll("Act", { by = player.UserId, item = "emote", mode = key })
		end
	end)

	inventory.Gained:Connect(function(player, key)
		self:FoundItem(player, key)
	end)
	resources.Gathered:Connect(function(player, item, amount)
		local profile = data:Get(player)
		if profile and item == "wood" then
			profile.stats.wood += amount
			self:_statAchievements(player, profile)
		end
	end)
	camp.Deposited:Connect(function(player, _, _, n)
		local r = stats(player)
		r.contributed += n
		self:AddXp(player, Constants.XP.contribution * n, "camp")
	end)
	camp.Built:Connect(function(s, contributors)
		for player in contributors do
			local profile = data:Get(player)
			if profile then
				profile.stats.built += 1
				stats(player).built += 1
			end
		end
		if s.key == "totem" then
			for _, player in runs:Active() do
				self:Achieve(player, "totem")
			end
		end
	end)
	camp.TierUp:Connect(function(tier)
		for _, player in runs:Active() do
			stats(player).objectives += 1
			self:AddXp(player, Constants.XP.objective, "tier")
			if tier >= 4 then
				self:Achieve(player, "camp_4")
			end
		end
	end)
	objectives.Completed:Connect(function(key, players)
		if key == "tier2" or key == "tier3" or key == "tier4" then
			return -- counted by TierUp
		end
		for _, player in players do
			stats(player).objectives += 1
			self:AddXp(player, Constants.XP.objective, "goal")
		end
	end)
	craft.Crafted:Connect(function(player)
		local profile = data:Get(player)
		if profile then
			profile.stats.crafted += 1
			stats(player).crafted += 1
		end
	end)
	loot.Looted:Connect(function(player)
		local profile = data:Get(player)
		if profile then
			profile.stats.looted += 1
			stats(player).loot += 1
		end
	end)
	combat.Hit:Connect(function(player, targetKind, amount, item)
		local class = Items.masteryClass(item)
		if class then
			lastClass[player] = class
			self:AddMastery(player, class, Constants.MASTERY_GAIN.hit)
		end
		local r = stats(player)
		r.damageDealt += amount
		if targetKind == "mega_kermy" then
			r.bossDamage += amount
		end
	end)
	combat.Used:Connect(function(player, item)
		local class = Items.masteryClass(item)
		if class then
			self:AddMastery(player, class, Constants.MASTERY_GAIN.use)
		end
	end)
	combat.Placed:Connect(function(player)
		self:AddMastery(player, "trap", Constants.MASTERY_GAIN.use)
	end)
	combat.Thrown:Connect(function(player)
		self:AddMastery(player, "trap", Constants.MASTERY_GAIN.use)
	end)
	monsters.Killed:Connect(function(m, killer, assists)
		self:_onKilled(m, killer, assists)
	end)
	monsters.KermyKO:Connect(function(m, killer, assists)
		self:_onKermyKO(m, killer, assists)
	end)
	monsters.Seen:Connect(function(player, key, elite)
		self:Seen(player, key, elite)
	end)
	monsters.Learned:Connect(function(player, key, tip)
		self:Learn(player, key, tip)
	end)
	survivors.Dodged:Connect(function(player, sourceKind)
		local profile = data:Get(player)
		if profile then
			profile.stats.dodged += 1
			self:_statAchievements(player, profile)
		end
		if type(sourceKind) == "string" then
			local key, tip = string.match(sourceKind, "^([%w_]+):([%w_]+)$")
			if key and tip then
				self:Learn(player, key, tip)
			end
		end
	end)
	survivors.Revived:Connect(function(player, by)
		if by then
			local profile = data:Get(by)
			if profile then
				profile.records.rescues += 1
				stats(by).revives += 1
				self:AddXp(by, Constants.XP.revive, "revive")
				self:_statAchievements(by, profile)
				self.RecordsChanged:Fire(by)
			end
		end
		_ = player
	end)
	survivors.Ghosted:Connect(function(player)
		teamGhosts += 1
		local profile = data:Get(player)
		if profile then
			profile.stats.ghosts += 1
		end
	end)
	survivors.Downed:Connect(function(player)
		local profile = data:Get(player)
		if profile then
			profile.stats.downs += 1
		end
	end)
	survivors.Spawned:Connect(function(player)
		self:_dress(player)
	end)
	boss.Defeated:Connect(function(_, killer, assists)
		for player in assists do
			self:AddXp(player, Constants.XP.kill.boss, "boss", true)
			self:_trophy(player, "golden_67")
		end
		_ = killer
	end)
	boss.Defeated:Connect(function(b)
		for player, n in b.pineStuns do
			if n >= 3 and player.Parent then
				self:Achieve(player, "treehugger")
			end
		end
	end)
	boss.Freed:Connect(function(_, by)
		if by then
			local profile = data:Get(by)
			if profile then
				profile.records.rescues += 1
				stats(by).revives += 1
				self:AddXp(by, Constants.XP.revive, "freed")
			end
			self:Achieve(by, "goo_buster")
		end
	end)
	world.Discovered:Connect(function(player, f)
		self:FoundFinding(player, f)
	end)
	world.PageRead:Connect(function(player, index)
		self:FoundPage(player, index)
	end)
	world.Sneaked:Connect(function(player)
		self:Achieve(player, "sneaky")
	end)
	runs.NightSurvived:Connect(function(n)
		self:_onNightSurvived(n)
	end)
	runs.BossStarted:Connect(function()
		for _, player in runs:Active() do
			self:Achieve(player, "seventh_night")
		end
	end)
	runs.Ended:Connect(function(result)
		self:_onEnded(result)
	end)
	runs.Reset:Connect(function()
		table.clear(runStats)
		teamGhosts = 0
	end)
	Players.PlayerRemoving:Connect(function(player)
		task.defer(function() -- after OnPlayerLeaving (the game log and analytics read the run's tally)
			runStats[player] = nil
			lastClass[player] = nil
			pushQueued[player] = nil
		end)
	end)
end

local readyAt = {} -- [player] = os.clock() when they loaded in (minutes played)

function ProgressService:OnPlayerReady(player, profile)
	readyAt[player] = os.clock()
	-- a profile's title and looks must exist (old saves)
	profile.titles.owned.camper = true
	data:WhenClientReady(player, function()
		local v = self:View(player)
		if v then
			Net.fire(player, "Profile", v)
		end
	end)
end

function ProgressService:OnPlayerLeaving(player, profile)
	if profile and readyAt[player] then
		profile.stats.minutes += math.floor((os.clock() - readyAt[player]) / 60)
	end
	readyAt[player] = nil
end

-- (tests)
function ProgressService:RunStats(player)
	return stats(player)
end

_ = now
return ProgressService
