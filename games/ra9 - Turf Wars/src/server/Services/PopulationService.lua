--[[
How many people are playing each mode, across every server of the universe (Data/Modes), so the lobby can show
"TURF WARS · 23 playing" and send someone who just presses PLAY where the people are.

Every server writes its own line to one MemoryStore sorted map (POPULATION_MAP): key its JobId, value { mode, n,
at }, gone after TTL seconds; every PUBLISH_SECONDS and whenever someone joins or leaves. n is real people only
(Players:GetPlayers(): the bots are BotService's stand-ins, never Players). Every READ_SECONDS it reads every line
back and sums them by mode; the sums are cached (Counts never yields). Without a MemoryStore (Studio offline, the
mock engine, an outage: every call is a pcall) it knows only this server, and says so.

  PopulationService:Here()        real people in this server
  PopulationService:Counts()      { turf = n, ctf = n, brawl = n, lobby = n } summed across servers (cached)
  PopulationService:Best()        the mode with the most players (a tie: turf, then ctf, then brawl)
  PopulationService:View()        what the clients get: { counts, best, here, open = Modes.multiPlace() }
  PopulationService:Publish()     this server's line, now (yields)
  PopulationService:Refresh()     read every line again, now (yields); fires Changed when the sums moved
  PopulationService.Changed       (counts, best)

  Server → client: Net "Population" (View) on join and whenever the sums change.
]]
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Modes = require(ReplicatedStorage.Shared.Data.Modes)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local PopulationService = {
	Name = "PopulationService",
	Dependencies = { "PlayerDataService" },
	Changed = Signal.new("PopulationService.Changed"), -- (counts, best)
	MAP = "TW_Population_v1",
	PUBLISH_SECONDS = 20,
	READ_SECONDS = 20,
	TTL = 60,
	ORDER = { "turf", "ctf", "brawl" }, -- (a tie between modes: the first of these)
}

local data
local sortedMap -- (nil without a MemoryStore)
local jobId = game.JobId ~= "" and game.JobId or "studio"
local counts = {} -- [mode] = n, the last sums
local best = "turf"

local function fresh()
	local c = { lobby = 0 }
	for _, key in Modes.LIST do
		c[key] = 0
	end
	return c
end

local function same(a, b)
	for k, v in a do
		if b[k] ~= v then
			return false
		end
	end
	for k, v in b do
		if a[k] ~= v then
			return false
		end
	end
	return true
end

function PopulationService:Here()
	return #Players:GetPlayers()
end

function PopulationService:Counts()
	return table.clone(counts)
end

-- The mode with the most players: a tie goes to the first of ORDER (turf before ctf before brawl)
function PopulationService.bestOf(c)
	local top, n = "turf", -1
	for _, key in PopulationService.ORDER do
		if Modes.get(key) and (c[key] or 0) > n then
			top, n = key, c[key] or 0
		end
	end
	return top
end

function PopulationService:Best()
	return best
end

function PopulationService:View()
	return { counts = self:Counts(), best = best, here = self:Here(), open = Modes.multiPlace() }
end

-- This server's own line: its mode and its real people
local function line()
	return { mode = Constants.MODE, n = PopulationService:Here(), at = os.time() }
end

function PopulationService:Publish()
	if not sortedMap then
		return false
	end
	local info = line()
	return pcall(function()
		if info.n == 0 then
			sortedMap:RemoveAsync(jobId) -- (an empty server counts for nothing)
		else
			sortedMap:SetAsync(jobId, info, self.TTL)
		end
	end)
end

-- Every server's line, summed by mode; this server's own count is always live (its line may be seconds old)
local function sum()
	local c = fresh()
	if sortedMap then
		local ok, items = pcall(function()
			return sortedMap:GetRangeAsync(Enum.SortDirection.Ascending, 200)
		end)
		local oldest = os.time() - PopulationService.TTL
		for _, item in ok and items or {} do
			local v = type(item) == "table" and item.value
			if
				type(v) == "table"
				and type(v.mode) == "string"
				and c[v.mode] ~= nil
				and item.key ~= jobId
				and (v.at or 0) >= oldest
			then
				c[v.mode] += math.max(0, math.floor(tonumber(v.n) or 0))
			end
		end
	end
	c[Constants.MODE] = (c[Constants.MODE] or 0) + PopulationService:Here()
	return c
end

local function push(player)
	Net.fire(player, "Population", PopulationService:View())
end

local function pushAll()
	Net.fireAll("Population", PopulationService:View())
end

function PopulationService:Refresh()
	local c = sum()
	local b = PopulationService.bestOf(c)
	if same(c, counts) and b == best then
		return false
	end
	counts, best = c, b
	self.Changed:Fire(self:Counts(), best)
	pushAll()
	return true
end

function PopulationService:Init(registry)
	data = registry.PlayerDataService
	counts = fresh()
	local ok, m = pcall(function()
		return MemoryStoreService:GetSortedMap(self.MAP)
	end)
	sortedMap = ok and m or nil
	local function moved()
		task.spawn(function()
			self:Publish()
			self:Refresh()
		end)
	end
	Players.PlayerAdded:Connect(moved)
	Players.PlayerRemoving:Connect(function()
		task.defer(moved) -- (after they've gone from GetPlayers)
	end)
	pcall(function()
		game:BindToClose(function()
			if sortedMap then
				pcall(sortedMap.RemoveAsync, sortedMap, jobId)
			end
		end)
	end)
end

function PopulationService:Start()
	self:Refresh()
	local lastPublish, lastRead = os.clock(), os.clock()
	while true do
		task.wait(1)
		local t = os.clock()
		if t - lastPublish >= self.PUBLISH_SECONDS then
			lastPublish = t
			self:Publish()
		end
		if t - lastRead >= self.READ_SECONDS then
			lastRead = t
			self:Refresh()
		end
	end
end

function PopulationService:OnPlayerReady(player)
	data:WhenClientReady(player, function()
		push(player)
	end)
end

return PopulationService
