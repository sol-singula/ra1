--[[
The animals (Data/Animals): boosters for the whole farm, bought and levelled on each pen's pad (Data/Upgrades
"chicken", "pig", "cow", "sheep"). Step on a pen's feed plate: hungry animals are fed (the whole boost for
FED_SECONDS); fed ones are petted and get happy (the boost doubled for HAPPY_SECONDS, once every PET_GAP). The
plates work by where you stand (no Touched), like the build pads.

  AnimalService:Care(player, key)   "fed" | "petted" | nil (nothing to do yet) | false (no pen)
  AnimalService:State(player)       [key] = { level, fed, happy, fedLeft, happyLeft, petIn, boost, word }
  AnimalService:Push(player)        Net "Animals"
  AnimalService.Changed (player, key, what)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animals = require(ReplicatedStorage.Shared.Data.Animals)
local Layout = require(ReplicatedStorage.Shared.World.Layout)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local AnimalService = {
	Name = "AnimalService",
	Dependencies = { "PlayerDataService", "TerritoryService", "UpgradeService" },
	Changed = Signal.new("AnimalService.Changed"),
	TICK = 0.2,
}

local data, territory, analytics
local onPlate = {} -- [player] = the animal key of the plate they stand on (acts once per step on)
local lastSig = {} -- [player] = what was last pushed (a push only on a change, or every few seconds)
local lastPush = {}

local function now()
	return os.time()
end

local function stateOf(p, key)
	p.animals = p.animals or {}
	local st = p.animals[key]
	if not st then
		st = { fedAt = 0, pettedAt = 0 }
		p.animals[key] = st
	end
	return st
end

function AnimalService:Care(player, key)
	local p = data:Get(player)
	if not p or not Animals[key] or (p.owned[key] or 0) == 0 then
		return false
	end
	local a = Animals[key]
	local st = stateOf(p, key)
	local t = now()
	local what
	if not Animals.fed(st, t) then
		st.fedAt = t
		p.stats.fed = (p.stats.fed or 0) + 1
		what = "fed"
		Net.fire(player, "Toast", `{a.icon} {a.name} fed! Full boost: {a.word}`, "good")
	elseif t - (st.pettedAt or 0) >= Animals.PET_GAP then
		st.pettedAt = t
		st.fedAt = t -- (a pat tops up the food too)
		p.stats.petted = (p.stats.petted or 0) + 1
		p.stats.fed = (p.stats.fed or 0) + 1 -- (care of any kind counts for the goals)
		what = "petted"
		Net.fire(player, "Toast", `{a.icon} {a.name} are happy: boost x2 for {Animals.HAPPY_SECONDS}s!`, "good")
	else
		local wait = Animals.PET_GAP - (t - st.pettedAt)
		Net.fire(player, "Toast", `{a.icon} {a.name} are fed. Pet them again in {wait}s`, "info")
		return nil
	end
	if analytics then
		pcall(analytics.event, player, "animal_" .. what, { key = key })
	end
	self.Changed:Fire(player, key, what)
	self:Push(player)
	return what
end

function AnimalService:State(player)
	local p = data:Get(player)
	local out = {}
	if not p then
		return out
	end
	local t = now()
	for _, key in Animals.LIST do
		local level = p.owned[key] or 0
		if level > 0 then
			local a = Animals[key]
			local st = stateOf(p, key)
			out[key] = {
				level = level,
				fed = Animals.fed(st, t),
				happy = Animals.happy(st, t),
				fedLeft = math.max(0, Animals.FED_SECONDS - (t - st.fedAt)),
				happyLeft = math.max(0, Animals.HAPPY_SECONDS - (t - st.pettedAt)),
				petIn = math.max(0, Animals.PET_GAP - (t - st.pettedAt)),
				boost = a.boost.per * level * Animals.share(st, t),
				word = a.word,
			}
		end
	end
	return out
end

function AnimalService:Push(player)
	local s = self:State(player)
	local sig = ""
	for _, key in Animals.LIST do
		local e = s[key]
		if e then
			sig ..= `{key}{e.level}{e.fed}{e.happy}{e.petIn == 0}`
		end
	end
	lastSig[player] = sig
	lastPush[player] = os.clock()
	Net.fire(player, "Animals", s)
end

-- Which feed plate a player stands on (their own farm's)
function AnimalService:Under(player)
	local t = territory:Territory(player)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not t or not hrp or hrp.Position.Y > Layout.GROUND_Y + 8 then
		return nil
	end
	local x, z = Layout.toLocal(t.index, hrp.Position)
	local r = Layout.FEED / 2 + 0.6
	for _, key in Layout.ANIMALS do
		local fp = Layout.PENS[key].feed
		if math.abs(x - fp.x) <= r and math.abs(z - fp.z) <= r then
			return key
		end
	end
	return nil
end

function AnimalService:Step(player)
	local key = self:Under(player)
	if key ~= onPlate[player] then
		onPlate[player] = key
		if key then
			self:Care(player, key)
		end
	end
	-- a push when something changed (got hungry, stopped being happy, can be petted again), or every 5 s
	local s = self:State(player)
	local sig = ""
	for _, k in Animals.LIST do
		local e = s[k]
		if e then
			sig ..= `{k}{e.level}{e.fed}{e.happy}{e.petIn == 0}`
		end
	end
	if sig ~= lastSig[player] or os.clock() - (lastPush[player] or 0) >= 5 then
		self:Push(player)
	end
end

function AnimalService:Init(registry)
	data = registry.PlayerDataService
	territory = registry.TerritoryService
	analytics = registry.AnalyticsService
	registry.UpgradeService.Applied:Connect(function(player, key)
		if Animals[key] then
			local p = data:Get(player)
			if p and (p.owned[key] or 0) == 1 then
				stateOf(p, key).fedAt = now() -- (they arrive fed)
			end
			self:Push(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		onPlate[player], lastSig[player], lastPush[player] = nil, nil, nil
	end)
end

function AnimalService:OnPlayerReady(player)
	data:WhenClientReady(player, function()
		self:Push(player)
	end)
end

function AnimalService:Start()
	while true do
		task.wait(self.TICK)
		for _, player in Players:GetPlayers() do
			local ok, err = pcall(self.Step, self, player)
			if not ok then
				warn("[AnimalService] tick failed: " .. tostring(err))
			end
		end
	end
end

return AnimalService
