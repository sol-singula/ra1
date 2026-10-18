--[[
The buy-pads (master plan §4): three pads by the stand show the next upgrades on offer (Data/Upgrades: in order,
the level reached), each with its name and price, green when they can pay. Standing on one buys it (once per
visit to the pad). A pad whose next upgrade needs a higher level shows it locked ("LV 3"). Everything bought is
built on the plot (FarmBuilder.upgrade), pays Upgrades.XP_PER_BUY XP, and does its thing: more soil tiles
(FarmService:BuildTiles), the next stage, or a number the farm reads (water, sprinkler, carry, price, golden).

  UpgradeService:Buy(player, key) -> ok, why ("owned" | "order" | "level" | "cash")
  UpgradeService:Offer(player)    -> { upgrade, locked? } x PADS, what the pads show
  UpgradeService:Paint(player)
  UpgradeService:Stations(player) -> { [track] = the warehouse's station pad }   (stage 4: a track's next fix each)
  UpgradeService.Bought (player, upgrade)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local FarmBuilder = require(ReplicatedStorage.Shared.World.FarmBuilder)
local Flow = require(ReplicatedStorage.Shared.Data.Flow)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Upgrades = require(ReplicatedStorage.Shared.Data.Upgrades)

local UpgradeService = {
	Name = "UpgradeService",
	Dependencies = { "PlayerDataService", "EconomyService", "PlotService", "FarmService" },
	Bought = Signal.new("UpgradeService.Bought"),
	Applied = Signal.new("UpgradeService.Applied"), -- (player, upgrade) built on the plot (on a buy, and on a rejoin)
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
			if not p.owned[key] and not seen[key] and not u.track then
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
	self:PaintStations(player)
end

-- The warehouse's station pads (stage 4, master plan §13.2): one per track, each offering that track's next fix
function UpgradeService:Stations(player)
	local plot = plots:Plot(player)
	local folder = plot and plot.items:FindFirstChild("warehouse")
	local out = {}
	if folder then
		for _, d in folder:GetChildren() do
			if d.Name == "StationPad" then
				out[d:GetAttribute("Track")] = d
			end
		end
	end
	return out
end

local STATION_NAME = { grow = "GROW", pack = "PACK", store = "STORE", ship = "SHIP" }
local BOTTLENECK = Color3.fromRGB(240, 70, 60)

function UpgradeService:PaintStations(player)
	local p = data:Get(player)
	local pads = self:Stations(player)
	if not p or not next(pads) then
		return
	end
	local rates = Flow.rates(p, workspace:GetServerTimeNow())
	for track, pad in pads do
		local u = Upgrades.trackNext(p.owned or {}, track)
		local red = rates.bottleneck == track
		pad.Color = red and BOTTLENECK or Color3.fromRGB(250, 250, 248)
		pad:SetAttribute("Item", u and u.key or nil)
		pad:SetAttribute("Bottleneck", red)
		local head = STATION_NAME[track] .. (red and " · BOTTLENECK" or "")
		if not u then
			-- (a track bought out: if it's still the slowest, the farm itself has to grow: crops, animals, levels)
			local hint = (
				{ grow = "Plant pricier crops!", pack = "ALL BUILT", store = "ALL BUILT", ship = "ALL BUILT" }
			)[track]
			FarmBuilder.label(pad, head, red and hint or "ALL BUILT", red and P.sunflower or GREEN)
		elseif u.level > (p.level or 1) then
			FarmBuilder.label(pad, head, `{u.name} · LV {u.level}`, P.steelLight)
		else
			FarmBuilder.label(pad, head, `{u.name} · {Format.num(u.cost)}`, p.cash >= u.cost and GREEN or RED)
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
		if u.replaces and plot.items:FindFirstChild(u.replaces) then
			plot.items[u.replaces]:Destroy() -- (the site sign goes when the building comes)
		end
		FarmBuilder.upgrade(plot, u.key)
	end
	UpgradeService.Applied:Fire(player, u)
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
	if u.track then
		-- (a station pad's: the next in its track, once the warehouse stands)
		offered = p.owned.warehouse ~= nil and Upgrades.trackNext(p.owned, u.track) == u and u.level <= (p.level or 1)
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
	local replaced = {}
	for _, key in Upgrades.LIST do
		if profile.owned[key] and Upgrades[key].replaces then
			replaced[Upgrades[key].replaces] = true
		end
	end
	for _, key in Upgrades.LIST do
		if profile.owned[key] and not replaced[key] then
			FarmBuilder.upgrade(plot, key)
			self.Applied:Fire(player, Upgrades[key])
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
		local pads = table.clone(refs.pads)
		for _, pad in self:Stations(player) do
			table.insert(pads, pad)
		end
		for _, pad in pads do
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
