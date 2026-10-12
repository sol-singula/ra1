-- The Dragon Road: dragons walk out of a cave every few seconds and anyone can buy one with coins.
-- Also runs the 5-minute Legend event, Server Luck, the FREE dragon stand and the Practice Base.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Dragons = require(ReplicatedStorage.Shared.Data.Dragons)
local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local DragonBuilder = require(script.Parent.Parent.World.DragonBuilder)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local RoadService = {
	Name = "RoadService",
	Dependencies = { "PlayerDataService", "EconomyService", "DragonService", "BaseService" },
	Bought = Signal.new("RoadService.Bought"), -- (player, id)
	BuyNowRequested = Signal.new("RoadService.BuyNowRequested"), -- (player, roadId)
	LuckChanged = Signal.new("RoadService.LuckChanged"),
}

local data, economy, dragons, baseService
local folder
local road = {} -- [roadId] = { id, sp, x, z, model, price }
local nextRoadId = 1
local rng = Random.new(os.time())
local luckUntil = 0
local luckBy = nil
local nextLegendAt = 0
local legendWarned = false

local function now()
	return workspace:GetServerTimeNow()
end

function RoadService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	dragons = registry.DragonService
	baseService = registry.BaseService
	folder = Instance.new("Folder")
	folder.Name = "Road"
	folder.Parent = workspace:FindFirstChild("Dragons") or workspace
	nextLegendAt = now() + Constants.LEGEND_EVENT_EVERY
	self:_buildStands()
	data.ClientReady:Connect(function(player)
		Net.fire(player, "Event", { kind = "legend", at = nextLegendAt })
		if luckUntil > now() then
			Net.fire(player, "Event", { kind = "luck", untilTime = luckUntil, by = luckBy })
		end
	end)
end

function RoadService:IsLucky()
	return luckUntil > now()
end

function RoadService:AddLuck(seconds, byName)
	luckUntil = math.max(luckUntil, now()) + seconds
	luckBy = byName
	Net.fireAll("Event", { kind = "luck", untilTime = luckUntil, by = byName })
	self.LuckChanged:Fire()
end

-- Road dragons -----------------------------------------------------------------------------------------------
-- Is one of the custom dragons walking the road (and still buyable)?
function RoadService:FancyOnRoad()
	for _, e in road do
		if not e.leaving and Dragons.byId[e.id].fancy then
			return true
		end
	end
	return false
end

-- Spawn a road dragon. A custom dragon comes FANCY_CHANCE of the time, and always when none is on the road.
-- `fancy` forces one (true) or a regular dragon (false).
function RoadService:Spawn(minRarity, fancy)
	if fancy == nil then
		fancy = not self:FancyOnRoad() or rng:NextNumber() < Constants.FANCY_CHANCE
	end
	local id, special = Formulas.rollDragon(function()
		return rng:NextNumber()
	end, self:IsLucky(), minRarity, fancy)
	local d = Dragons.byId[id]
	local roadId = nextRoadId
	nextRoadId += 1
	local model = DragonBuilder.build(id, special, 1)
	local price = Formulas.roadPrice(id, special)
	local entry = {
		roadId = roadId,
		id = id,
		sp = special,
		x = Constants.ROAD_START_X,
		z = rng:NextNumber(-3, 3),
		model = model,
		price = price,
	}
	local name = (special and Dragons.Specials[special].name .. " " or "") .. d.name
	DragonBuilder.label(
		model,
		(d.fancy and "✨ " or "") .. name,
		Dragons.RarityColor[d.rarity],
		"💰 " .. Format.num(price)
	)
	model:SetAttribute("RoadId", roadId)
	local buy = dragons.prompt(model.PrimaryPart, "buy", "Buy " .. Format.num(price), name, 0.25, 0)
	buy.Triggered:Connect(function(player)
		self:TryBuy(player, roadId)
	end)
	if Dragons.RarityRank[d.rarity] >= Dragons.RarityRank.Epic then
		local now2 = dragons.prompt(model.PrimaryPart, "buynow", "Buy with Robux", name, 0, 0, Enum.KeyCode.F)
		now2.Triggered:Connect(function(player)
			self.BuyNowRequested:Fire(player, roadId)
		end)
	end
	self:_move(entry, 0)
	model.Parent = folder
	road[roadId] = entry
	if Dragons.RarityRank[d.rarity] >= Dragons.RarityRank.Legend then
		Net.fireAll("Toast", `⭐ A {d.fancy and "✨ " or ""}{d.rarity} dragon is on the road: {name}!`, "good")
	end
	return entry
end

function RoadService:_move(entry, t)
	local bob = math.abs(math.sin(t * 6 + entry.roadId)) * 0.4
	DragonBuilder.place(
		entry.model,
		CFrame.new(entry.x, WorldBuilder.layout.roadY + bob, entry.z) * CFrame.Angles(0, math.rad(-90), 0)
	)
end

function RoadService:Entry(roadId)
	return road[roadId]
end

function RoadService:_remove(roadId)
	local e = road[roadId]
	if e then
		road[roadId] = nil
		e.model:Destroy()
	end
end

-- Checks shared by coin and Robux buys. Returns an error text, or nil if the player can take it.
function RoadService:CanTake(player, entry)
	if not entry or entry.x > Constants.ROAD_END_X then
		return "Too late, it's gone!"
	end
	if dragons:Carrying(player) then
		return "Your hands are full!"
	end
	if not baseService:Get(player) or not dragons:HasRoom(player) then
		return "Your nests are full! Sell a dragon or buy a nest."
	end
	return nil
end

function RoadService:TryBuy(player, roadId)
	local entry = road[roadId]
	local err = self:CanTake(player, entry)
	if err then
		Net.fire(player, "Toast", err, "bad")
		return
	end
	local pos = baseService:Position(player)
	if not pos or (pos - entry.model.PrimaryPart.Position).Magnitude > 16 then
		return
	end
	if not economy:Spend(player, entry.price) then
		Net.fire(player, "Toast", `You need {Format.num(entry.price)} coins!`, "bad")
		return
	end
	self:_give(player, entry)
end

-- Give a road dragon (after coins or Robux were paid).
function RoadService:_give(player, entry)
	self:_remove(entry.roadId)
	local rec = dragons:NewRecord(player, entry.id, entry.sp)
	dragons:StartCarry(player, rec, player, "bought")
	local profile = data:Get(player)
	profile.stats.bought += 1
	Net.fire(player, "Toast", "Got it! Run to your base! 🏠", "good")
	self.Bought:Fire(player, entry.id)
end

-- Robux "Buy Now": returns true if the dragon was still there.
function RoadService:GiveFromRoad(player, roadId)
	local entry = road[roadId]
	if self:CanTake(player, entry) then
		return false
	end
	self:_give(player, entry)
	return true
end

-- FREE dragon and Practice Base ------------------------------------------------------------------------------
function RoadService:_buildStands()
	local layout = WorldBuilder.layout
	local free = DragonBuilder.build("PUFF", nil, 1)
	DragonBuilder.place(free, layout.freeFeet)
	DragonBuilder.label(free, "Puff", Dragons.RarityColor.Common, "FREE")
	local fp = dragons.prompt(free.PrimaryPart, "free", "Grab FREE", "Puff", 0.2, 0)
	fp.Triggered:Connect(function(player)
		local profile = data:Get(player)
		if not profile or profile.tutorialDone or #profile.dragons > 0 or dragons:Carrying(player) then
			Net.fire(player, "Toast", "The free dragon is for new players!", "info")
			return
		end
		local rec = dragons:NewRecord(player, "PUFF", nil)
		dragons:StartCarry(player, rec, player, "free")
		Net.fire(player, "Toast", "Your first dragon! Run to your base! 🏠", "good")
	end)
	free.Parent = folder
	self.freeModel = free

	local practice = DragonBuilder.build("FROSTY", nil, 1)
	DragonBuilder.place(practice, layout.practiceFeet)
	DragonBuilder.label(practice, "Frosty", Dragons.RarityColor.Rare, "Sneaky Sam's dragon")
	local pp = dragons.prompt(practice.PrimaryPart, "practice", "Steal", "Frosty", 1.2, 0)
	pp.Triggered:Connect(function(player)
		local profile = data:Get(player)
		if not profile then
			return
		end
		if profile.tutorialDone or profile.stats.practice > 0 then
			Net.fire(player, "Toast", "Practice is only for new players. Steal from real players!", "info")
			return
		end
		if dragons:Carrying(player) or not dragons:HasRoom(player) then
			Net.fire(player, "Toast", "Your hands are full!", "bad")
			return
		end
		profile.stats.practice += 1
		local rec = dragons:NewRecord(player, "FROSTY", nil)
		dragons:StartCarry(player, rec, player, "practice")
		Net.fire(player, "Toast", "Nice steal! Now run home! 🏠", "good")
	end)
	practice.Parent = folder
	self.practiceModel = practice
end

function RoadService:Start()
	local spawnAcc = Constants.SPAWN_EVERY
	local t = 0
	RunService.Heartbeat:Connect(function(dt)
		t += dt
		spawnAcc += dt
		if spawnAcc >= Constants.SPAWN_EVERY then
			spawnAcc = 0
			if #Players:GetPlayers() > 0 then
				self:Spawn()
			end
		end
		for roadId, entry in road do
			entry.x += Constants.ROAD_SPEED * dt
			if entry.x > Constants.ROAD_EXIT_X then
				self:_remove(roadId) -- deep in the dark tunnel
			else
				if entry.x > Constants.ROAD_END_X and not entry.leaving then
					-- walking into the exit tunnel: no more buying, no floating name tag in the dark
					entry.leaving = true
					for _, child in entry.model.PrimaryPart:GetChildren() do
						if child:IsA("ProximityPrompt") or child.Name == "Tag" then
							child:Destroy()
						end
					end
				end
				self:_move(entry, t)
			end
		end
		-- Legend event
		local n = now()
		if not legendWarned and n >= nextLegendAt - Constants.LEGEND_WARNING then
			legendWarned = true
			Net.fireAll("Event", { kind = "legend", at = nextLegendAt })
		end
		if n >= nextLegendAt then
			legendWarned = false
			nextLegendAt = n + Constants.LEGEND_EVENT_EVERY
			if #Players:GetPlayers() > 0 then
				self:Spawn("Legend")
			end
			Net.fireAll("Event", { kind = "legend", at = nextLegendAt })
		end
	end)
end

return RoadService
