--[[
The town's shared boosts (master plan §11): one at a time, ten minutes, for everyone on the server. The meter in
the square fills with Cash anyone chips in; full, it lights the next boost in the rotation (Harvest Rush, Customer
Rush, Golden Market). Robux lights one at once (ShopService). While one is on the meter waits.

  BoostService:Active(key)          true while that boost is on
  BoostService:Activate(key, by)    start it now
  BoostService:Contribute(player, amount)
  BoostService:Push()
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Shop = require(ReplicatedStorage.Shared.Data.Shop)
local Signal = require(ReplicatedStorage.Shared.Signal)

local BoostService = {
	Name = "BoostService",
	Dependencies = { "PlayerDataService", "EconomyService" },
	Changed = Signal.new("BoostService.Changed"),
}

local data, economy
local active = nil -- { key, until, by }
local meter = 0
local nextIndex = 1
local pushDue = false

local function now()
	return workspace:GetServerTimeNow()
end

function BoostService:Active(key)
	if not active then
		return false
	end
	if now() >= active.until_ then
		active = nil
		pushDue = true
		return false
	end
	return active.key == key
end

function BoostService:Current()
	if active and now() < active.until_ then
		return active
	end
	return nil
end

function BoostService:Activate(key, by)
	if not Shop.BOOSTS[key] then
		return false
	end
	active = { key = key, until_ = now() + Constants.BOOST_SECONDS, by = by }
	local who = by and (by.DisplayName or by.Name) or "The town"
	Net.fireAll("Toast", `{who} lit {Shop.BOOSTS[key].name}! 10 minutes for everyone.`, "good")
	self.Changed:Fire(key)
	self:Push()
	return true
end

function BoostService:Contribute(player, amount)
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 or self:Current() then
		return false
	end
	local p = data:Get(player)
	if not p then
		return false
	end
	amount = math.min(amount, p.cash, Constants.BOOST_METER_COST - meter)
	if amount <= 0 or not economy:Spend(player, amount, "boost") then
		return false
	end
	meter += amount
	Net.fireAll(
		"Toast",
		`{player.DisplayName or player.Name} chipped in {Format.cash(amount)} to the server boost`,
		"info"
	)
	if meter >= Constants.BOOST_METER_COST then
		meter = 0
		local key = Shop.BOOST_LIST[nextIndex]
		nextIndex = nextIndex % #Shop.BOOST_LIST + 1
		self:Activate(key, nil)
	else
		self:Push()
	end
	return true
end

function BoostService:Push()
	local a = self:Current()
	Net.fireAll("Boost", {
		active = a and a.key or nil,
		until_ = a and a.until_ or nil,
		seconds = a and math.max(0, a.until_ - now()) or 0,
		meter = meter,
		cost = Constants.BOOST_METER_COST,
		next = Shop.BOOST_LIST[nextIndex],
	})
	pushDue = false
end

function BoostService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	Net.on("Boost", function(player, what, amount)
		if what == "contribute" then
			self:Contribute(player, amount)
		elseif what == "open" then
			self:Push()
		end
	end)
end

function BoostService:OnPlayerReady(player)
	data:WhenClientReady(player, function()
		self:Push()
	end)
end

function BoostService:Start()
	while true do
		task.wait(5)
		if active and now() >= active.until_ then
			active = nil
			Net.fireAll("Toast", "The server boost is over. Fill the meter for the next one!", "info")
			pushDue = true
		end
		if pushDue or active then
			self:Push()
		end
	end
end

_ = Players
return BoostService
