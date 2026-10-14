--[[
Progress between matches (master plan §17, §20) and the end-of-match screen (§4 step 7):

  * Rewards: everyone sees how long the dwarves held on and how many monsters they beat; everyone gets coins and
    XP (Formulas.rewards): time held as a dwarf, monsters beaten, pieces built, dwarves beaten and pieces broken
    as a monster, shrines taken, a win, being the last dwarf standing. XP levels up your account and the jobs you
    played. Coins only buy looks (Data/Looks): nothing you unlock makes you stronger (§17).
  * Titles are earned (Wall Master, Gate Breaker...) and shown over your head.
  * Daily gift (a streak), three daily tasks and a weekly challenge (Data/Tasks).
  * The longest hold as a dwarf goes on a leaderboard in the hangout; the match's best go on the podium.
]]
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Jobs = require(ReplicatedStorage.Shared.Data.Jobs)
local Kit = require(ReplicatedStorage.Shared.World.Kit)
local Looks = require(ReplicatedStorage.Shared.Data.Looks)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Tasks = require(ReplicatedStorage.Shared.Data.Tasks)
local MapBuilder = require(script.Parent.Parent.World.MapBuilder)

local ProgressService = {
	Name = "ProgressService",
	Dependencies = { "PlayerDataService", "MatchService", "TeamService" },
	Rewarded = Signal.new("ProgressService.Rewarded"), -- (player, you, result)
	LeveledUp = Signal.new("ProgressService.LeveledUp"), -- (player, level)
	Bought = Signal.new("ProgressService.Bought"), -- (player, key, price)
	Equipped = Signal.new("ProgressService.Equipped"), -- (player, slot, key)
	TaskDone = Signal.new("ProgressService.TaskDone"), -- (player, key, coins)
	TitleEarned = Signal.new("ProgressService.TitleEarned"), -- (player, key)
	GiftClaimed = Signal.new("ProgressService.GiftClaimed"), -- (player, coins, streak)
}

local data, match, teams
local bestStore
local lastDwarf -- the last player dwarf standing this match
local board = { rows = {}, at = 0 }
local names = {}

local function today()
	return Tasks.day(os.time())
end

-- The profile view the HUD and panels read ("Profile").
function ProgressService:View(player)
	local profile = data:Get(player)
	if not profile then
		return nil
	end
	local level, into, need = Formulas.accountLevel(profile.xp)
	local jobs = {}
	for key, xp in profile.jobXp do
		local l = Formulas.jobLevel(xp)
		jobs[key] = l
	end
	local d = profile.daily
	local tasks = {}
	for _, key in d.tasks do
		local t = Tasks.byKey[key]
		if t then
			table.insert(tasks, {
				key = key,
				line = t.line,
				goal = t.goal,
				progress = math.min(t.goal, d.progress[key] or 0),
				done = d.done[key] == true,
				coins = t.coins,
			})
		end
	end
	local weekly = d.weekly and Tasks.byKey[d.weekly]
	return {
		coins = profile.coins,
		xp = profile.xp,
		level = level,
		levelInto = into,
		levelNeed = need,
		jobLevels = jobs,
		dwarfJob = profile.dwarfJob,
		looks = profile.looks,
		titles = profile.titles,
		stats = profile.stats,
		tasks = tasks,
		weekly = weekly and {
			key = weekly.key,
			line = weekly.line,
			goal = weekly.goal,
			progress = math.min(weekly.goal, d.weeklyProgress or 0),
			done = d.weeklyDone == true,
			coins = weekly.coins,
		} or false,
		gift = {
			ready = d.claimed < today(),
			streak = d.streak,
			-- what the next claim pays: the streak goes on if you claimed yesterday (or today, for tomorrow)
			next = Formulas.dailyGift(d.claimed >= today() - 1 and d.streak + 1 or 1),
		},
		settings = profile.settings,
		tutorial = profile.tutorial,
	}
end

function ProgressService:Push(player)
	local view = self:View(player)
	if view then
		Net.fire(player, "Profile", view)
	end
end

-- Daily tasks -------------------------------------------------------------------------------------------------------
function ProgressService:_refreshTasks(player)
	local profile = data:Get(player)
	if not profile then
		return
	end
	local d = profile.daily
	local day = today()
	if d.day ~= day then
		d.day = day
		d.tasks = Tasks.pickDaily(player.UserId, day)
		d.progress = {}
		d.done = {}
	end
	local week = Tasks.week(os.time())
	if d.week ~= week then
		d.week = week
		d.weekly = Tasks.pickWeekly(player.UserId, week)
		d.weeklyProgress = 0
		d.weeklyDone = false
	end
end

function ProgressService:_count(player, stat, n)
	local profile = data:Get(player)
	if not profile or n <= 0 then
		return
	end
	self:_refreshTasks(player)
	local d = profile.daily
	local changed = false
	for _, key in d.tasks do
		local t = Tasks.byKey[key]
		if t and t.stat == stat and not d.done[key] then
			d.progress[key] = (d.progress[key] or 0) + n
			changed = true
			if d.progress[key] >= t.goal then
				d.done[key] = true
				profile.coins += t.coins
				Net.fire(player, "Toast", `Task done: {t.line}! +{t.coins} coins`, "good")
				Net.fire(player, "Sfx", "coin")
				self.TaskDone:Fire(player, key, t.coins)
			end
		end
	end
	local w = d.weekly and Tasks.byKey[d.weekly]
	if w and w.stat == stat and not d.weeklyDone then
		d.weeklyProgress = (d.weeklyProgress or 0) + n
		changed = true
		if d.weeklyProgress >= w.goal then
			d.weeklyDone = true
			profile.coins += w.coins
			Net.fire(player, "Toast", `Weekly challenge done! +{w.coins} coins`, "good")
			self.TaskDone:Fire(player, w.key, w.coins)
		end
	end
	if changed then
		self:Push(player)
	end
end

-- Titles --------------------------------------------------------------------------------------------------------
function ProgressService:_checkTitles(player)
	local profile = data:Get(player)
	if not profile then
		return
	end
	for _, t in Looks.titles do
		if t.stat and not profile.titles.owned[t.key] and (profile.stats[t.stat] or 0) >= t.goal then
			profile.titles.owned[t.key] = true
			Net.fire(player, "Alert", `New title: {t.name}!`, Kit.C.gold, 3)
			Net.fire(player, "Sfx", "levelup")
			self.TitleEarned:Fire(player, t.key)
		end
	end
end

-- The daily gift --------------------------------------------------------------------------------------------------
function ProgressService:ClaimGift(player)
	local profile = data:Get(player)
	if not profile then
		return false
	end
	local d = profile.daily
	local day = today()
	if d.claimed >= day then
		return false
	end
	d.streak = (d.claimed == day - 1) and d.streak + 1 or 1
	d.claimed = day
	local coins = Formulas.dailyGift(d.streak)
	profile.coins += coins
	Net.fire(player, "Toast", `Daily gift: +{coins} coins (day {d.streak})!`, "good")
	Net.fire(player, "Sfx", "coin")
	self.GiftClaimed:Fire(player, coins, d.streak)
	self:Push(player)
	return true
end

-- Looks ---------------------------------------------------------------------------------------------------------
function ProgressService:Buy(player, key)
	local profile = data:Get(player)
	local item = type(key) == "string" and Looks.byKey[key]
	if not profile or not item then
		return false, "That's not in the shop."
	end
	if profile.looks.owned[key] then
		return false, "You already have it."
	end
	if profile.coins < item.price then
		return false, `You need {item.price - profile.coins} more coins.`
	end
	profile.coins -= item.price
	profile.looks.owned[key] = true
	self.Bought:Fire(player, key, item.price)
	Net.fire(player, "Sfx", "buy")
	self:Equip(player, item.slot, key)
	return true
end

function ProgressService:Equip(player, slot, key)
	local profile = data:Get(player)
	if not profile or type(slot) ~= "string" or type(key) ~= "string" then
		return false
	end
	if slot == "title" then
		if not profile.titles.owned[key] then
			return false
		end
		profile.titles.equipped = key
	else
		local item = Looks.byKey[key]
		if not item or item.slot ~= slot or not profile.looks.owned[key] then
			return false
		end
		profile.looks.equipped[slot] = key
	end
	self.Equipped:Fire(player, slot, key)
	-- wear it right away
	local s = teams:State(player)
	local c = player.Character
	if s and c and (slot == "armor" or slot == "beard" or slot == "skin" or slot == "weapon" or slot == "title") then
		local hum = c:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			if slot == "title" then
				teams:RefreshNameplate(player)
			else
				teams:Dress(player, c, s)
			end
		end
	end
	self:Push(player)
	return true
end

-- Rewards ---------------------------------------------------------------------------------------------------------
local function addStat(profile, key, n)
	profile.stats[key] = (profile.stats[key] or 0) + (n or 0)
end

function ProgressService:_mvps(states)
	local best = {}
	local function consider(slot, player, n)
		if n > 0 and (not best[slot] or n > best[slot].n) then
			best[slot] = { name = player.DisplayName, userId = player.UserId, n = n }
		end
	end
	for player, s in states do
		if player.Parent and s.matchId == match:State().id then
			consider("builder", player, s.stats.built)
			consider("defender", player, s.stats.beaten)
			consider("monster", player, s.stats.dwarvesBeaten * 3 + s.stats.broken)
			consider("healer", player, s.stats.healed)
		end
	end
	if lastDwarf and lastDwarf.Parent then
		best.lastDwarf = { name = lastDwarf.DisplayName, userId = lastDwarf.UserId }
	end
	return best
end

function ProgressService:_onEnded(result)
	local states = teams:_states()
	if result.reason == "empty" then
		return
	end
	-- the last dwarf: the only one left standing when the dwarves won, or the last to fall
	local alive = teams:Players("dwarf")
	if result.winner == "dwarf" and #alive == 1 then
		lastDwarf = alive[1]
	end
	local mvps = self:_mvps(states)
	local podium = {}
	for player, s in states do
		local profile = data:Get(player)
		if profile and player.Parent and s.matchId == result.id then
			local played = s.team ~= nil
			local st = s.stats
			local you = {
				team = s.team,
				won = result.winner == s.team,
				heldSeconds = st.heldSeconds,
				beaten = st.beaten,
				dwarvesBeaten = st.dwarvesBeaten,
				built = st.built,
				broken = st.broken,
				shrines = st.shrines,
				lastDwarf = lastDwarf == player,
			}
			local coins, xp = Formulas.rewards(you)
			if not played then
				coins, xp = 0, 0
			end
			local levelBefore = Formulas.accountLevel(profile.xp)
			profile.coins += coins
			profile.xp += xp
			local levelAfter = Formulas.accountLevel(profile.xp)
			profile.jobXp[s.job] = (profile.jobXp[s.job] or 0) + xp
			if s.team == "monster" and profile.dwarfJob ~= s.job then
				profile.jobXp[profile.dwarfJob] = (profile.jobXp[profile.dwarfJob] or 0) + math.floor(xp / 2)
			end
			addStat(profile, "matches", 1)
			if you.won then
				addStat(profile, s.team == "dwarf" and "dwarfWins" or "monsterWins", 1)
			end
			for _, k in
				{
					"built",
					"walls",
					"traps",
					"beaten",
					"dwarvesBeaten",
					"broken",
					"gates",
					"mined",
					"healed",
					"fixed",
					"crafted",
					"heldSeconds",
					"shrines",
					"deaths",
				}
			do
				addStat(profile, k, st[k])
			end
			if you.lastDwarf then
				addStat(profile, "lastDwarf", 1)
			end
			if st.heldSeconds > (profile.stats.bestHold or 0) then
				profile.stats.bestHold = st.heldSeconds
				self:_saveBest(player, st.heldSeconds)
			end
			self:_count(player, "matches", 1)
			self:_checkTitles(player)
			you.coins = coins
			you.xp = xp
			you.level = levelAfter
			you.leveledUp = levelAfter > levelBefore
			if you.leveledUp then
				self.LeveledUp:Fire(player, levelAfter)
			end
			you.stats = st
			Net.fire(player, "Results", {
				winner = result.winner,
				reason = result.reason,
				held = result.held,
				fallen = result.fallen,
				number = result.number,
				mvps = mvps,
				you = you,
			})
			self.Rewarded:Fire(player, you, result)
			self:Push(player)
			table.insert(podium, {
				player = player,
				score = st.built * 2 + st.beaten * 2 + st.dwarvesBeaten * 4 + st.broken + st.shrines * 5,
			})
		end
	end
	table.sort(podium, function(a, b)
		return a.score > b.score
	end)
	self:_podium(podium)
end

-- The match's best, on the hangout podium.
function ProgressService:_podium(list)
	for k, step in MapBuilder.hangout.podium or {} do
		local old = step:FindFirstChild("Who")
		if old then
			old:Destroy()
		end
		local entry = list[k]
		if entry then
			local bb = Instance.new("BillboardGui")
			bb.Name = "Who"
			bb.Size = UDim2.fromOffset(180, 40)
			bb.StudsOffset = Vector3.new(0, 4, 0)
			bb.MaxDistance = 120
			bb.Parent = step
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, 1)
			label.Font = Enum.Font.LuckiestGuy
			label.TextScaled = true
			label.TextColor3 = ({ Kit.C.gold, Kit.C.steel, Kit.C.autumn })[k]
			label.TextStrokeTransparency = 0.2
			label.Text = entry.player.DisplayName
			label.Parent = bb
		end
	end
end

-- The leaderboard (the longest holds) -----------------------------------------------------------------------------
function ProgressService:_saveBest(player, seconds)
	if not bestStore then
		return
	end
	task.spawn(function()
		pcall(function()
			bestStore:UpdateAsync(tostring(player.UserId), function(old)
				if old and old >= seconds then
					return nil
				end
				return math.floor(seconds)
			end)
		end)
	end)
end

local function nameOf(userId)
	if names[userId] then
		return names[userId]
	end
	local p = Players:GetPlayerByUserId(userId)
	if p then
		names[userId] = p.DisplayName
		return names[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = ok and name or ("Player " .. userId)
	return names[userId]
end

function ProgressService:_refreshBoard()
	if not bestStore then
		return
	end
	local ok, pages = pcall(function()
		return bestStore:GetSortedAsync(false, Constants.LEADERBOARD_SIZE)
	end)
	if not ok or not pages then
		return
	end
	local rows = {}
	local okPage, page = pcall(pages.GetCurrentPage, pages)
	for _, entry in okPage and page or {} do
		local id = tonumber(entry.key)
		if id then
			table.insert(rows, { userId = id, name = nameOf(id), value = entry.value })
		end
	end
	board = { rows = rows, at = os.time() }
	Net.fireAll("Leaderboard", board)
	self:_drawBoard()
end

function ProgressService:_drawBoard()
	local part = MapBuilder.hangout.board
	if not part then
		return
	end
	local gui = part:FindFirstChild("Board")
	if not gui then
		gui = Instance.new("SurfaceGui")
		gui.Name = "Board"
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.LightInfluence = 0.3
		gui.Parent = part
	end
	gui:ClearAllChildren()
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0.16, 0)
	title.Font = Enum.Font.LuckiestGuy
	title.TextScaled = true
	title.TextColor3 = Kit.C.gold
	title.Text = "LONGEST HOLDS"
	title.Parent = gui
	for k = 1, Constants.LEADERBOARD_SIZE do
		local row = board.rows[k]
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.new(0.05, 0, 0.17 + (k - 1) * 0.082, 0)
		label.Size = UDim2.new(0.9, 0, 0.078, 0)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = k <= 3 and Kit.C.cream or Kit.C.white
		label.Text = row and string.format("%d. %s  %s", k, row.name, Formulas.clock(row.value))
			or string.format("%d. ...", k)
		label.Parent = gui
	end
end

-- Requests ------------------------------------------------------------------------------------------------------
function ProgressService:Init(reg)
	data = reg.PlayerDataService
	match = reg.MatchService
	teams = reg.TeamService
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore(Constants.BEST_STORE)
	end)
	bestStore = ok and store or nil

	Net.on("Buy", function(player, key)
		local ok2, why = self:Buy(player, key)
		if not ok2 and why then
			Net.fire(player, "Toast", why, "bad")
		end
	end)
	Net.on("Equip", function(player, slot, key)
		self:Equip(player, slot, key)
	end)
	Net.on("ClaimGift", function(player)
		self:ClaimGift(player)
	end)
	Net.on("Emote", function(player, key)
		local profile = data:Get(player)
		local item = type(key) == "string" and Looks.byKey[key]
		if profile and item and item.slot == "emote" and profile.looks.owned[key] then
			Net.fireAll("Fx", "emote", { by = player.UserId, key = key })
		end
	end)
	Net.on("Settings", function(player, key, value)
		local profile = data:Get(player)
		if profile and (key == "fx" or key == "shake" or key == "music") and type(value) == "boolean" then
			profile.settings[key] = value
			self:Push(player)
		end
	end)

	teams.StatAdded:Connect(function(player, key, n)
		self:_count(player, key, n)
	end)
	teams.Died:Connect(function(_, _, team)
		if team == "dwarf" and match:IsFight() then
			local left = teams:Players("dwarf")
			if #left == 1 then
				lastDwarf = left[1]
				Net.fireAll("Callout", `{left[1].DisplayName} is the LAST DWARF!`, "last")
			end
		end
	end)
	match.Started:Connect(function()
		lastDwarf = nil
	end)
	match.Ended:Connect(function(result)
		self:_onEnded(result)
	end)
	_ = Jobs
end

function ProgressService:Start()
	self:_drawBoard()
	while true do
		self:_refreshBoard()
		task.wait(Constants.LEADERBOARD_REFRESH)
	end
end

function ProgressService:OnPlayerReady(player)
	self:_refreshTasks(player)
	self:Push(player)
	if #board.rows > 0 then
		Net.fire(player, "Leaderboard", board)
	end
end

return ProgressService
