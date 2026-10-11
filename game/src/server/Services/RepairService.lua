-- Furniture durability, damage states and repairs (GDD §27.8.18, canon C6). Angry customers smash tables
-- and stools; Broken or Destroyed seats can't be used until repaired. Objects are never permanently lost.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)

local RepairService = {
	Name = "RepairService",
	Dependencies = { "EconomyService", "ProgressionService", "MutationService", "RestaurantService" },
}

local economy, progression, mutations, restaurantSvc
local pieces = {} -- [part] = { r, color, prompt }

local function durability(part)
	return part:GetAttribute("Durability") or 100
end

function RepairService:_repairCost(player, missing)
	local discount = math.min(0.002 * progression:Stat(player, "REPAIR"), 0.3)
	return math.ceil(missing * Constants.REPAIR_COST_PER_POINT * (1 - discount))
end

function RepairService:_holdSeconds(player, missing)
	local speed = Formulas.repairMult(progression:Stat(player, "REPAIR")) * (1 + mutations:RepairBonus(player))
	return math.max(0.5, Constants.REPAIR_SECONDS_PER_25 * (missing / 25) / speed)
end

function RepairService:_refresh(part)
	local info = pieces[part]
	if not info then
		return
	end
	local d = durability(part)
	local state = Formulas.damageState(d, Constants.DAMAGE_STATES)
	local darken = ({ Pristine = 0, Scuffed = 0.15, Cracked = 0.3, Broken = 0.5, Destroyed = 0.7 })[state]
	part.Color = info.color:Lerp(Color3.new(0.15, 0.12, 0.1), darken)
	part.Transparency = state == "Destroyed" and 0.45 or 0
	part:SetAttribute("DamageState", state)
	local missing = 100 - d
	info.prompt.Enabled = missing > 0
	if missing > 0 then
		local owner = info.r.owner
		info.prompt.ObjectText = `{part:GetAttribute("FurnitureName")} · {state}`
		info.prompt.ActionText = `Repair ({self:_repairCost(owner, missing)} MB)`
		info.prompt.HoldDuration = self:_holdSeconds(owner, missing)
	end
end

function RepairService:_register(r, part)
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = "Repair"
	pp.KeyboardKeyCode = Enum.KeyCode.R
	pp.GamepadKeyCode = Enum.KeyCode.ButtonY
	pp.MaxActivationDistance = Constants.STATION_RANGE
	pp.RequiresLineOfSight = false
	pp.Enabled = false
	pp.Parent = part
	pieces[part] = { r = r, color = part.Color, prompt = pp }
	pp.Triggered:Connect(function(player)
		if player ~= r.owner then
			Net.fire(player, "Toast", "Only the owner can repair this.", "bad")
			return
		end
		local missing = 100 - durability(part)
		if missing <= 0 then
			return
		end
		local cost = self:_repairCost(player, missing)
		if not economy:Spend(player, "MB", cost, "repair") then
			Net.fire(player, "Toast", `Repairs cost {cost} MB.`, "bad")
			return
		end
		part:SetAttribute("Durability", 100)
		self:_refresh(part)
		progression:AddXp(player, 2)
		Net.fire(player, "Toast", "Good as new!", "good")
	end)
	part.Destroying:Connect(function()
		pieces[part] = nil
	end)
end

function RepairService:Init(registry)
	economy = registry.EconomyService
	progression = registry.ProgressionService
	mutations = registry.MutationService
	restaurantSvc = registry.RestaurantService

	restaurantSvc.Built:Connect(function(_, r)
		for _, part in r.layout.model.Dining:GetChildren() do
			if part:GetAttribute("Durability") then
				self:_register(r, part)
			end
		end
	end)
end

function RepairService:Damage(part, amount)
	if not pieces[part] then
		return
	end
	part:SetAttribute("Durability", math.max(0, durability(part) - amount))
	self:_refresh(part)
end

-- Seats and tables below 26 % (Broken, Destroyed) are unusable.
function RepairService:IsUsable(part)
	return durability(part) >= 26
end

function RepairService:DamagedCount(r)
	local n = 0
	if not r then
		return 0
	end
	for part, info in pieces do
		if info.r == r and durability(part) < 76 then
			n += 1
		end
	end
	return n
end

-- ABL_062 Repair Burst: restore 15 % + 0.1 % × REPAIR to up to 4 damaged pieces within 8 studs, paying the
-- normal repair cost for the amount restored. Returns how many pieces were repaired.
function RepairService:Burst(player, position)
	local spec = Constants.ABILITIES.ABL_062
	local amount = 15 + 0.1 * progression:Stat(player, "REPAIR")
	local done = 0
	for part, info in pieces do
		if done >= spec.targets then
			break
		end
		local d = durability(part)
		if info.r.owner == player and d < 100 and d > 0 and (part.Position - position).Magnitude <= spec.range then
			local restored = math.min(amount, 100 - d)
			if economy:Spend(player, "MB", self:_repairCost(player, restored), "repair_burst") then
				part:SetAttribute("Durability", d + restored)
				self:_refresh(part)
				done += 1
			end
		end
	end
	return done
end

return RepairService
