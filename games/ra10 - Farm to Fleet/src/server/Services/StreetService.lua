--[[
Watching each other (master plan §13.4). Every operation on the street, live:

  Size          Flow.size: how big the whole operation is
  Cash/min      what its sales, orders, pallets and specials paid over the last Constants.STREET_WINDOW seconds
  deliveries/min  how many of those payouts (a stand sale, an order, a truck, a special)
  best today    the biggest single shipment today (UTC)

They show on the STREET board over the road (World/StreetBuilder.gantry, ranked by Cash/min, the street's biggest
shipment of the day along the bottom), on a billboard over each plot's gate, and in the STREET panel (Net
"Street"), where VISIT takes you to any plot's gate and back HOME, and a LIKE (one a day for each farm) counts on
its billboard; the most liked farm on the server gets a tag.

FRIENDS: the client lists its friends online (GetFriendsOnline works only on the client) and the server answers
with each one's saved summary (Constants.SUMMARY_STORE: size, Cash/min, level, franchise; written when they leave
and every LEADERBOARD_REFRESH_SECONDS) and whether they're here; JOIN teleports you to a friend's server.

profile.street = { day, best, likes, liked = { [userId] = day } }

  StreetService:Stats(player) -> { size, cashMin, delivMin, best, likes }
  StreetService:Visit(player, plotIndex) / :Home(player) / :Like(player, plotIndex)
  StreetService:Friends(player, list) -> rows
  StreetService:Join(player, userId) -> ok
  StreetService.board   the STREET gantry (tests)
]]
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Flow = require(ReplicatedStorage.Shared.Data.Flow)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local PlotLayout = require(ReplicatedStorage.Shared.World.PlotLayout)
local Signal = require(ReplicatedStorage.Shared.Signal)
local StreetBuilder = require(ReplicatedStorage.Shared.World.StreetBuilder)

local StreetService = {
	Name = "StreetService",
	Dependencies = { "PlayerDataService", "EconomyService", "PlotService" },
	Liked = Signal.new("StreetService.Liked"), -- (player, owner)
	TICK = 5,
}

local SHIPPED = { sell = true, order = true, pallets = true, special = true }
local CARD_TTL = 120

local data, economy, plots, analytics, registryRef
local samples = {} -- [player] = { { t, n } }
local joinedAt = {}
local bestToday = { day = 0, cash = 0, name = "" }
local summaryStore
local cards = {} -- [userId] = { at, card }
local anchors = {} -- [plotIndex] = the billboard's anchor Part
local lastSummary = {}

local function today()
	return math.floor(os.time() / 86400)
end

local function streetOf(p)
	p.street = p.street or {}
	local s = p.street
	s.likes = s.likes or 0
	s.liked = s.liked or {}
	if s.day ~= today() then
		s.day = today()
		s.best = 0
	end
	return s
end

local function franchiseLevel(p)
	return p.franchise and p.franchise.level or 0
end

function StreetService:Stats(player)
	local p = data:Get(player)
	if not p then
		return nil
	end
	local list = samples[player] or {}
	local t = os.clock()
	local cash, n = 0, 0
	for i = #list, 1, -1 do
		local s = list[i]
		if t - s.t > Constants.STREET_WINDOW then
			table.remove(list, i)
		else
			cash += s.n
			n += 1
		end
	end
	-- (per minute over the window, or over the time they've been here if that's shorter: at least a minute)
	local minutes = math.max(1, math.min(Constants.STREET_WINDOW, t - (joinedAt[player] or t)) / 60)
	local s = streetOf(p)
	return {
		size = Flow.size(p),
		cashMin = math.floor(cash / minutes + 0.5),
		delivMin = math.floor(n / minutes * 10 + 0.5) / 10,
		best = s.best or 0,
		likes = s.likes,
		level = p.level or 1,
		franchise = franchiseLevel(p),
	}
end

-- The whole street: one row a plot with an owner, ranked by Cash/min.
function StreetService:View()
	local rows, mostLiked, likes = {}, nil, 0
	for i = 1, Constants.PLOTS do
		local owner = plots:Owner(i)
		local st = owner and self:Stats(owner)
		if st then
			local row = { index = i, name = owner.DisplayName, userId = owner.UserId }
			for k, v in st do
				row[k] = v
			end
			table.insert(rows, row)
			if st.likes > likes then
				likes, mostLiked = st.likes, i
			end
		end
	end
	table.sort(rows, function(a, b)
		if a.cashMin ~= b.cashMin then
			return a.cashMin > b.cashMin
		end
		return a.size > b.size
	end)
	for rank, row in rows do
		row.rank = rank
		row.mostLiked = row.index == mostLiked or nil
	end
	return { rows = rows, best = bestToday.day == today() and bestToday or nil }
end

local function paint(self)
	local view = self:View()
	local cells = {}
	for _, r in view.rows do
		table.insert(cells, {
			tostring(r.rank),
			(r.franchise > 0 and `★{r.franchise} ` or "") .. r.name,
			Format.num(r.size),
			Format.num(r.cashMin),
			tostring(r.delivMin),
			Format.num(r.best),
		})
	end
	local best = view.best
	StreetBuilder.fill(
		self.board,
		"THE STREET · LIVE",
		{ "#", "FARM", "SIZE", "CASH/MIN", "DELIV/MIN", "BEST TODAY" },
		cells,
		best and `🏆 Biggest shipment today: {best.name} · {Format.num(best.cash)} Cash`
			or "Ship something big today!"
	)
	for i, anchor in anchors do
		local row
		for _, r in view.rows do
			if r.index == i then
				row = r
			end
		end
		if row then
			StreetBuilder.billboard(
				anchor,
				(row.franchise > 0 and string.rep("★", math.min(row.franchise, 5)) .. " " or "") .. row.name,
				{
					`#{row.rank} · {Format.num(row.cashMin)} Cash/min`,
					`Size {Format.num(row.size)} · {row.delivMin} deliveries/min · ❤ {row.likes}`,
				},
				Constants.PLOT_COLORS[i],
				row.mostLiked and "❤ MOST LIKED ON THE STREET" or nil
			)
			anchor.Street.Enabled = true
		elseif anchor:FindFirstChild("Street") then
			anchor.Street.Enabled = false
		end
	end
	return view
end

function StreetService:Push(player)
	local view = self:View()
	local boards = registryRef.LeaderboardService
	if boards then
		view.hall = { earned = boards:Top("earned"), best = boards:Top("best"), size = boards:Top("size") }
	end
	if player then
		Net.fire(player, "Street", view)
	else
		Net.fireAll("Street", view)
	end
end

-- Visiting -------------------------------------------------------------------------------------------------------
local function teleport(player, i, x, z)
	local c = player.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	if not r then
		return false
	end
	local at = PlotLayout.toWorld(i, x, z, 3)
	local look = PlotLayout.toWorld(i, x, z + 20, 3)
	player:SetAttribute("AcGrace", os.clock() + 2.5)
	r.CFrame = CFrame.lookAt(at, look)
	return true
end

function StreetService:Visit(player, i)
	if type(i) ~= "number" or i % 1 ~= 0 or i < 1 or i > Constants.PLOTS or not plots:Owner(i) then
		return false
	end
	if analytics then
		pcall(analytics.event, player, "visit", { plot = i, own = plots:Owner(i) == player })
	end
	-- (the gate, facing in: the drive between the stand and the pads)
	return teleport(player, i, 0, -104)
end

function StreetService:Home(player)
	local plot = plots:Plot(player)
	if not plot then
		return false
	end
	local s = PlotLayout.SPOTS.spawn
	return teleport(player, plot.index, s.X, s.Z)
end

function StreetService:Like(player, i)
	local owner = type(i) == "number" and plots:Owner(i)
	local p = data:Get(player)
	if not owner or owner == player or not p then
		return false
	end
	local mine = streetOf(p)
	local key = tostring(owner.UserId)
	if mine.liked[key] == today() then
		Net.fire(player, "Toast", `You liked {owner.DisplayName}'s farm today already`, "info")
		return false
	end
	local q = data:Get(owner)
	if not q then
		return false
	end
	-- (only today's likes are kept: an old one can go)
	for k, d in mine.liked do
		if d ~= today() then
			mine.liked[k] = nil
		end
	end
	mine.liked[key] = today()
	local theirs = streetOf(q)
	theirs.likes += 1
	Net.fire(player, "Toast", `❤ You liked {owner.DisplayName}'s farm!`, "good")
	Net.fire(owner, "Toast", `❤ {player.DisplayName} likes your farm!`, "good")
	self.Liked:Fire(player, owner)
	if analytics then
		pcall(analytics.event, player, "like", { plot = i })
	end
	paint(self)
	self:Push()
	return true
end

-- Friends ---------------------------------------------------------------------------------------------------------
function StreetService:Summary(player, p)
	local st = self:Stats(player) or {}
	return {
		name = player.DisplayName,
		level = p.level or 1,
		stage = p.stage or 1,
		size = Flow.size(p),
		cashMin = st.cashMin or 0,
		franchise = franchiseLevel(p),
		at = os.time(),
	}
end

local function writeSummary(self, player, p)
	if not summaryStore or not p then
		return
	end
	lastSummary[player] = os.clock()
	pcall(summaryStore.SetAsync, summaryStore, tostring(player.UserId), self:Summary(player, p))
end

local function card(userId)
	local c = cards[userId]
	if c and os.clock() - c.at < CARD_TTL then
		return c.card
	end
	local got
	if summaryStore then
		local ok, v = pcall(summaryStore.GetAsync, summaryStore, tostring(userId))
		got = ok and type(v) == "table" and v or nil
	end
	cards[userId] = { at = os.clock(), card = got }
	return got
end

function StreetService:Friends(player, list)
	local out = {}
	if type(list) ~= "table" then
		return out
	end
	for i, f in list do
		if i > 30 then
			break
		end
		local userId = type(f) == "table" and tonumber(f.userId)
		if userId and userId ~= player.UserId then
			local here = Players:GetPlayerByUserId(userId)
			local row = { userId = userId, name = type(f.name) == "string" and string.sub(f.name, 1, 32) or "Friend" }
			if here then
				row.here = true
				row.plot = here:GetAttribute("Plot")
				local p = data:Get(here)
				if p then
					for k, v in self:Summary(here, p) do
						row[k] = row[k] or v
					end
				end
			else
				local c = card(userId)
				if c then
					row.size, row.cashMin, row.level = tonumber(c.size), tonumber(c.cashMin), tonumber(c.level)
					row.franchise = tonumber(c.franchise)
				end
			end
			table.insert(out, row)
		end
	end
	table.sort(out, function(a, b)
		return (a.size or 0) > (b.size or 0)
	end)
	return out
end

function StreetService:Join(player, userId)
	userId = tonumber(userId)
	if not userId or userId == player.UserId then
		return false
	end
	local here = Players:GetPlayerByUserId(userId)
	if here then
		return self:Visit(player, here:GetAttribute("Plot"))
	end
	local okF, isFriend = pcall(player.IsFriendsWith, player, userId)
	if not okF or not isFriend then
		Net.fire(player, "Toast", "You can only join your friends", "bad")
		return false
	end
	local okP, _, _, placeId, job = pcall(function()
		return TeleportService:GetPlayerPlaceInstanceAsync(userId)
	end)
	if not okP or not job or job == "" or placeId ~= game.PlaceId then
		Net.fire(player, "Toast", "Your friend isn't on a Farm to Fleet server right now", "bad")
		return false
	end
	local ok = pcall(function()
		local options = Instance.new("TeleportOptions")
		options.ServerInstanceId = job
		options:SetTeleportData({ from = "friend", friend = userId })
		Net.fire(player, "Toast", "Off to your friend's street...", "good")
		TeleportService:TeleportAsync(game.PlaceId, { player }, options)
	end)
	if not ok then
		Net.fire(player, "Toast", "Couldn't reach that server. Try again in a moment.", "bad")
	end
	if analytics then
		pcall(analytics.event, player, "join_friend", { ok = ok })
	end
	return ok
end

-- Life -------------------------------------------------------------------------------------------------------------
function StreetService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	plots = registry.PlotService
	analytics = registry.AnalyticsService
	registryRef = registry
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(Constants.SUMMARY_STORE)
	end)
	summaryStore = ok and store or nil
	local world = plots:World()
	self.board = StreetBuilder.gantry(
		world.folder,
		-(PlotLayout.WIDTH + PlotLayout.GAP) / 2,
		"StreetBoard",
		Color3.fromRGB(70, 150, 230)
	)
	self.hall = StreetBuilder.gantry(
		world.folder,
		(PlotLayout.WIDTH + PlotLayout.GAP) / 2,
		"HallOfFame",
		Color3.fromRGB(235, 175, 30)
	)
	for i, plot in world.plots do
		local a = Instance.new("Part")
		a.Name = "StreetAnchor"
		a.Anchored = true
		a.CanCollide = false
		a.CanQuery = false
		a.CanTouch = false
		a.Transparency = 1
		a.Size = Vector3.new(1, 1, 1)
		a.CFrame = plot.cf * CFrame.new(40, 30, -104)
		a.Parent = plot.folder
		anchors[i] = a
	end
	economy.Changed:Connect(function(player, kind, total, n, why)
		_ = total
		if kind ~= "cash" or type(n) ~= "number" or n <= 0 or not SHIPPED[why] then
			return
		end
		samples[player] = samples[player] or {}
		table.insert(samples[player], { t = os.clock(), n = n })
		local p = data:Get(player)
		if p then
			local s = streetOf(p)
			s.best = math.max(s.best or 0, n)
			if bestToday.day ~= today() then
				bestToday = { day = today(), cash = 0, name = "" }
			end
			if n > bestToday.cash then
				local first = bestToday.name ~= player.DisplayName or bestToday.cash == 0
				bestToday = { day = today(), cash = n, name = player.DisplayName }
				-- (a big one: the whole street hears about it)
				if n >= 10000 and first then
					Net.fireAll(
						"Toast",
						`🏆 {player.DisplayName} shipped the street's biggest today: {Format.num(n)}!`,
						"good"
					)
				end
			end
		end
	end)
	Net.on("Street", function(player, what, a)
		if what == "visit" then
			self:Visit(player, a)
		elseif what == "home" then
			self:Home(player)
		elseif what == "like" then
			self:Like(player, a)
		elseif what == "open" then
			self:Push(player)
		elseif what == "friends" then
			Net.fire(player, "Street", { friends = self:Friends(player, a) })
		elseif what == "join" then
			self:Join(player, a)
		end
	end)
end

function StreetService:OnPlayerReady(player)
	joinedAt[player] = os.clock()
	lastSummary[player] = os.clock()
	samples[player] = samples[player] or {}
	data:WhenClientReady(player, function()
		self:Push(player)
	end)
end

function StreetService:OnPlayerLeaving(player, profile)
	writeSummary(self, player, profile)
	samples[player] = nil
	joinedAt[player] = nil
	lastSummary[player] = nil
end

function StreetService:_tick()
	paint(self)
	self:Push()
	for _, player in Players:GetPlayers() do
		if os.clock() - (lastSummary[player] or 0) > Constants.LEADERBOARD_REFRESH_SECONDS then
			local p = data:Get(player)
			if p then
				task.spawn(writeSummary, self, player, p)
			end
		end
	end
end

function StreetService:Start()
	while true do
		local ok, err = pcall(self._tick, self)
		if not ok then
			warn("[StreetService] tick failed: " .. tostring(err))
		end
		task.wait(self.TICK)
	end
end

return StreetService
