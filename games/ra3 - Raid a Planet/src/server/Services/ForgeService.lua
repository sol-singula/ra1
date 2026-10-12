-- The Forge: put a planet's ore in, wait, take a blaster out. Three sizes (Constants.FORGE_TIERS) with their odds
-- shown. One slot, three with the Triple Forge pass. The roll happens when the forge starts (so Finish Now can't
-- be used to re-roll) and is hidden until you take it out. The forge keeps working while you're offline.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Planets = require(ReplicatedStorage.Shared.Data.Planets)
local Shop = require(ReplicatedStorage.Shared.Data.Shop)
local Signal = require(ReplicatedStorage.Shared.Signal)

local ForgeService = {
	Name = "ForgeService",
	Dependencies = { "PlayerDataService", "EconomyService", "BlasterService", "PlanetService" },
	Started = Signal.new("ForgeService.Started"), -- (player, tierKey, planetKey)
	Claimed = Signal.new("ForgeService.Claimed"), -- (player, rec)
	FinishNowRequested = Signal.new("ForgeService.FinishNowRequested"), -- (player, slot, price)
}

local data, economy, blasters, planetService
local rng = Random.new()

function ForgeService:Slots(player)
	return economy:HasPass(player, "TRIPLE") and Constants.FORGE_SLOTS_TRIPLE or Constants.FORGE_SLOTS
end

function ForgeService:Luck(player)
	local profile = data:Get(player)
	return profile and (profile.luckUntil or 0) > os.time() and 1.6 or 1
end

-- The view the panel shows: every slot, what's cooking and how long is left.
function ForgeService:View(player)
	local profile = data:Get(player)
	if not profile then
		return nil
	end
	local now = os.time()
	local slots = {}
	for i = 1, self:Slots(player) do
		local f = profile.forge[i]
		if f then
			local left = math.max(0, f.readyAt - now)
			slots[i] = {
				tier = f.tier,
				planet = f.planet,
				left = left,
				total = f.total,
				ready = left <= 0,
				finishNow = left > 0 and Formulas.finishNowPrice(left, f.total, self.finishSteps()) or nil,
			}
		else
			slots[i] = false
		end
	end
	local tiers = {}
	for _, t in Constants.FORGE_TIERS do
		table.insert(tiers, {
			key = t.key,
			name = t.name,
			ore = t.ore,
			seconds = t.seconds,
			emoji = t.emoji,
			odds = Formulas.oddsLines(t.key),
		})
	end
	return {
		slots = slots,
		tiers = tiers,
		luck = self:Luck(player) > 1,
		luckLeft = math.max(0, (profile.luckUntil or 0) - now),
	}
end

function ForgeService.finishSteps()
	local steps = {}
	for _, p in Shop.FinishNow do
		table.insert(steps, p.price)
	end
	table.sort(steps)
	return steps
end

function ForgeService:Push(player)
	data:Push(player, { forge = self:View(player) })
end

function ForgeService:Start_(player, tierKey, planetKey)
	local profile = data:Get(player)
	local tier = Formulas.forgeTier(tierKey)
	local planet = Planets.byKey[planetKey]
	if not profile or not tier or not planet then
		return false
	end
	if not planetService:CanVisit(player, planetKey) then
		Net.fire(player, "Toast", `🔒 {planet.name} is locked.`, "bad")
		return false
	end
	local slot
	for i = 1, self:Slots(player) do
		if not profile.forge[i] then
			slot = i
			break
		end
	end
	if not slot then
		Net.fire(player, "Toast", "The forge is busy! Take your blaster out first.", "bad")
		return false
	end
	if #profile.blasters >= Constants.MAX_BLASTERS then
		Net.fire(player, "Toast", `Your bag is full ({Constants.MAX_BLASTERS}). Sell some blasters!`, "bad")
		return false
	end
	if not economy:SpendOre(player, planetKey, tier.ore) then
		Net.fire(player, "Toast", `You need {tier.ore} {planet.ore}. Blast {planet.bug}s!`, "bad")
		return false
	end
	local rec = Formulas.rollBlaster(rng, tierKey, planetKey, self:Luck(player))
	profile.forge[slot] =
		{ tier = tierKey, planet = planetKey, readyAt = os.time() + tier.seconds, total = tier.seconds, rec = rec }
	Net.fire(player, "Toast", `{tier.emoji} {tier.name} started: {Format.time(tier.seconds)}`, "good")
	Net.fire(player, "Sfx", "forge")
	self:Push(player)
	self.Started:Fire(player, tierKey, planetKey)
	return true
end

function ForgeService:Claim(player, slot)
	local profile = data:Get(player)
	local f = profile and profile.forge[slot]
	if not f then
		return false
	end
	if f.readyAt > os.time() then
		Net.fire(player, "Toast", `Not ready: {Format.time(f.readyAt - os.time())} left`, "info")
		return false
	end
	profile.forge[slot] = nil
	local rec = blasters:Grant(player, f.rec, "forge")
	profile.stats.forged += 1
	Net.fire(player, "Forged", blasters.view(rec))
	Net.fire(player, "Sfx", rec.rarity == "Common" and "pop" or "win")
	self:Push(player)
	self.Claimed:Fire(player, rec)
	return true
end

-- Finish Now: the ShopService prompts the product; this finishes the slot once it's paid (or free in Studio).
function ForgeService:FinishNow(player, slot)
	local profile = data:Get(player)
	local f = profile and profile.forge[slot]
	if not f or f.readyAt <= os.time() then
		return
	end
	local price = Formulas.finishNowPrice(f.readyAt - os.time(), f.total, self.finishSteps())
	self.FinishNowRequested:Fire(player, slot, price)
end

function ForgeService:CompleteSlot(player, slot)
	local profile = data:Get(player)
	local f = profile and profile.forge[slot]
	if f then
		f.readyAt = os.time()
		self:Push(player)
		Net.fire(player, "Toast", "⚒️ Done! Take your blaster out.", "good")
	end
end

function ForgeService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	blasters = registry.BlasterService
	planetService = registry.PlanetService
	Net.on("Forge", function(player, tierKey, planetKey)
		if type(tierKey) == "string" and type(planetKey) == "string" then
			self:Start_(player, tierKey, planetKey)
		end
	end)
	Net.on("ClaimForge", function(player, slot)
		if type(slot) == "number" then
			self:Claim(player, slot)
		end
	end)
	Net.on("FinishNow", function(player, slot)
		if type(slot) == "number" then
			self:FinishNow(player, slot)
		end
	end)
	data.ClientReady:Connect(function(player)
		self:Push(player)
	end)
	economy.PassesChanged:Connect(function(player)
		self:Push(player)
	end)
end

function ForgeService:Start()
	-- the HUD timer counts down on its own; this just flips "ready" and nudges the player
	while true do
		task.wait(1)
		for _, player in game:GetService("Players"):GetPlayers() do
			local profile = data:Get(player)
			if profile then
				local now = os.time()
				for i, f in profile.forge do
					if f.readyAt == now then
						Net.fire(player, "Toast", "⚒️ Your blaster is READY! Go to the Forge.", "good")
						Net.fire(player, "Sfx", "ready")
						self:Push(player)
					end
					if now - f.readyAt == 1 then
						self:Push(player) -- (if the one above was missed by a tick)
					end
					_ = i
				end
			end
		end
	end
end

return ForgeService
