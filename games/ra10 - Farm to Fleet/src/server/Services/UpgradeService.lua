--[[
The buy-pads (master plan §4): three pads by the stand show the next upgrades on offer (Data/Upgrades: in order,
the level reached), each with its name and price, green when they can pay. Standing on one buys it (once per
visit to the pad). A pad whose next upgrade needs a higher level shows it locked ("LV 3"). Everything bought is
built on the plot (FarmBuilder.upgrade), pays Upgrades.XP_PER_BUY XP, and does its thing: more soil tiles
(FarmService:BuildTiles), the next stage, or a number the farm reads (water, sprinkler, carry, price, golden).

  UpgradeService:Buy(player, key) -> ok, why ("owned" | "order" | "level" | "cash")
  UpgradeService:Offer(player)    -> { upgrade, locked? } x PADS, what the pads show
  UpgradeService:Paint(player)
  UpgradeService.Bought (player, upgrade)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local FarmBuilder = require(ReplicatedStorage.Shared.World.FarmBuilder)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Upgrades = require(ReplicatedStorage.Shared.Data.Upgrades)

local UpgradeService = {
	Name = "UpgradeService",
	Dependencies = { "PlayerDataService", "EconomyService", "PlotService", "FarmService" },
	Bought = Signal.new("UpgradeService.Bought"),
	REACH = 3.4,
	TICK = 0.2,
}

local data, economy, plots, farm, analytics
local onPad = {} -- [player] = the key on the pad they stand on
local lastCash = {} -- [player] = the Cash the pads were last painted for

local P = Constants.PALETTE
local GREEN = Color3.fromRGB(80, 220, 110)
local RED = Color3.fromRGB(240, 80, 80)

function UpgradeService:Offer(player)
	local p = data:Get(player)
	if not p then
		return {}
	end
	p.owned = p.owned or {}
	local out = {}
	for _, u in Upgrades.next(p.owned, p.level or 1, Upgrades.PADS) do
		table.insert(out, { upgrade = u })
	end
	if #out < Upgrades.PADS then
		-- (the next one locked behind a level: shown, so they know what's coming)
		local seen = {}
		for _, o in out do
			seen[o.upgrade.key] = true
		end
		for _, key in Upgrades.LIST do
			local u = Upgrades[key]
			if not p.owned[key] and not seen[key] then
				table.insert(out, { upgrade = u, locked = u.level > (p.level or 1) })
				break
			end
		end
	end
	return out
end

function UpgradeService:Paint(player)
	local refs = plots:Refs(player)
	local p = data:Get(player)
	if not refs or not p then
		return
	end
	lastCash[player] = math.floor(p.cash)
	local offer = self:Offer(player)
	for slot, pad in refs.pads do
		local o = offer[slot]
		local rim = refs.rims and refs.rims[slot]
		if rim then
			rim.Transparency = o and 0 or 1
		end
		if o then
			local u = o.upgrade
			pad:SetAttribute("Item", u.key)
			pad:SetAttribute("Locked", o.locked == true)
			pad.Transparency = 0
			if o.locked then
				FarmBuilder.label(pad, u.name, `LV {u.level}`, P.steelLight)
			else
				FarmBuilder.label(pad, u.name, `{u.cost} Cash`, p.cash >= u.cost and GREEN or RED)
			end
		else
			pad:SetAttribute("Item", nil)
			pad:SetAttribute("Locked", nil)
			pad.Transparency = 1 -- (nothing left on offer: the pad goes)
			FarmBuilder.label(pad, "", "")
		end
	end
end

local function apply(player, u)
	local p = data:Get(player)
	if u.kind == "soil" then
		farm:BuildTiles(player)
	elseif u.kind == "stage" then
		p.stage = math.max(p.stage or 1, u.value)
		Net.fire(player, "Toast", `STAGE {u.value} UNLOCKED!`, "good")
	end
	local plot = plots:Plot(player)
	if plot then
		FarmBuilder.upgrade(plot, u.key)
	end
end

function UpgradeService:Buy(player, key)
	local p = data:Get(player)
	local u = Upgrades[key]
	if not p or not u then
		return false, "order"
	end
	p.owned = p.owned or {}
	if p.owned[key] then
		return false, "owned"
	end
	local offered = false
	for _, o in self:Offer(player) do
		if o.upgrade.key == key and not o.locked then
			offered = true
		end
	end
	if not offered then
		return false, u.level > (p.level or 1) and "level" or "order"
	end
	if not economy:Spend(player, u.cost) then
		return false, "cash"
	end
	p.owned[key] = 1
	apply(player, u)
	economy:AddXP(player, Upgrades.XP_PER_BUY, "buy")
	Net.fire(player, "Toast", `BUILT: {u.name}!`, "good")
	if analytics then
		pcall(analytics.event, player, "buy", { key = key, cost = u.cost, level = p.level })
	end
	self.Bought:Fire(player, u)
	farm:Push(player)
	self:Paint(player)
	return true
end

function UpgradeService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	plots = registry.PlotService
	farm = registry.FarmService
	analytics = registry.AnalyticsService
	economy.Changed:Connect(function(player)
		local p = data:Get(player)
		if p and lastCash[player] ~= math.floor(p.cash) then
			self:Paint(player)
		end
	end)
	economy.LevelUp:Connect(function(player)
		self:Paint(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		onPad[player] = nil
		lastCash[player] = nil
	end)
end

function UpgradeService:OnPlayerReady(player, profile)
	local plot = plots:Plot(player)
	if not plot then
		return
	end
	profile.owned = profile.owned or {}
	for _, key in Upgrades.LIST do
		if profile.owned[key] then
			FarmBuilder.upgrade(plot, key)
		end
	end
	self:Paint(player)
end

function UpgradeService:_tick()
	for _, player in Players:GetPlayers() do
		local refs = plots:Refs(player)
		if not refs then
			continue
		end
		local on = nil
		for _, pad in refs.pads do
			local key = pad:GetAttribute("Item")
			if key and plots:Near(player, pad, self.REACH) then
				on = key
				if onPad[player] ~= key then
					local ok, why = self:Buy(player, key)
					if ok then
						on = pad:GetAttribute("Item") -- (the pad shows the next one: step off and on to buy it)
					elseif why == "cash" then
						local u = Upgrades[key]
						local short = u.cost - math.floor(economy:Cash(player))
						Net.fire(player, "Toast", `Need {short} more Cash for {u.name}`, "info")
					elseif why == "level" then
						Net.fire(player, "Toast", `Reach Farm Level {Upgrades[key].level} first`, "info")
					end
				end
				break
			end
		end
		onPad[player] = on
	end
end

function UpgradeService:Start()
	while true do
		task.wait(self.TICK)
		local ok, err = pcall(self._tick, self)
		if not ok then
			warn("[UpgradeService] tick failed: " .. tostring(err))
		end
	end
end

return UpgradeService
