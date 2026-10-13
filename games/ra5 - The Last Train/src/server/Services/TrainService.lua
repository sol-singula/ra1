-- The shared train: its doors, its fuel gauge, and the crew's upgrades (Data/TrainUpgrades).
--   Doors("open" | "closing" | "closed")  the outside doors (lamps, beacons, the invisible blocker in the gap)
--   Deposit(player, key, resource, amount) give materials (or a blueprint: resource "plans") from your storage to the
--                                          current stage of an upgrade. The server checks everything: you can only give
--                                          what you have, and only what the stage still needs. When a stage has
--                                          everything, it finishes by itself, everyone is told what changed, and the
--                                          train changes (engine room pipes and boiler, the searchlight, the radio mast).
-- Upgrades belong to the expedition: a new expedition starts with a fresh train. Nobody's giving is ranked against
-- anyone else's; the record keeps a simple crew summary.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Layout = require(ReplicatedStorage.Shared.World.Layout)
local Net = require(ReplicatedStorage.Shared.Net)
local Resources = require(ReplicatedStorage.Shared.Data.Resources)
local Signal = require(ReplicatedStorage.Shared.Signal)
local TrainUpgrades = require(ReplicatedStorage.Shared.Data.TrainUpgrades)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local TrainService = {
	Name = "TrainService",
	Dependencies = { "PlayerDataService", "ExpeditionService" },
	Deposited = Signal.new("TrainService.Deposited"), -- (player, key, resource, amount)
	Upgraded = Signal.new("TrainService.Upgraded"), -- (key, stage, player who finished it)
}

local data, expedition
local stages = {} -- [key] = stages finished this expedition
local given = {} -- [key] = { resource = amount, plans = true } toward the current stage
local doorState = "open"

-- Show or hide a model (remembering each part's own transparency and collision).
local function show(model, on)
	if not model then
		return
	end
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			if p:GetAttribute("ShownT") == nil then
				p:SetAttribute("ShownT", p.Transparency)
				p:SetAttribute("ShownC", p.CanCollide)
			end
			p.Transparency = on and p:GetAttribute("ShownT") or 1
			p.CanCollide = on and p:GetAttribute("ShownC") or false
		elseif p:IsA("Light") then
			p.Enabled = on
		end
	end
end

function TrainService:Stage(key)
	return stages[key] or 0
end

function TrainService:Stages()
	return { engine = stages.engine or 0, lamp = stages.lamp or 0 }
end

function TrainService:Given(key)
	return given[key] or {}
end

-- The crew's current objective (shown on the HUD and the crew board).
function TrainService:Goal()
	local fuel, cost = expedition:Fuel(), expedition:FuelCost()
	if expedition:IsAtStop() and fuel + 1e-6 < cost then
		return { key = "fuel", text = `Find fuel cans! Fuel {fuel} · next trip needs {cost}`, progress = cost > 0 and fuel / cost or 0 }
	end
	for _, u in TrainUpgrades.list do
		local n = stages[u.key] or 0
		local stage = u.stages[n + 1]
		if stage then
			local parts = {}
			for _, key in Resources.MATERIALS do
				local need = stage.cost[key]
				if need then
					table.insert(parts, `{math.min(need, (given[u.key] or {})[key] or 0)}/{need} {Resources.byKey[key].icon}`)
				end
			end
			if stage.plans then
				table.insert(parts, ((given[u.key] or {}).plans and "1" or "0") .. "/1 📜")
			end
			return {
				key = u.key,
				stage = n + 1,
				text = `{stage.name}: {table.concat(parts, " ")}`,
				name = stage.name,
				progress = Formulas.stageProgress(stage, given[u.key]),
			}
		end
	end
	return nil
end

-- Everything the TRAIN board needs.
function TrainService:View()
	local out = {}
	for _, u in TrainUpgrades.list do
		local n = stages[u.key] or 0
		table.insert(out, {
			key = u.key,
			stage = n,
			total = #u.stages,
			given = given[u.key] or {},
			missing = u.stages[n + 1] and Formulas.stageMissing(u.stages[n + 1], given[u.key]) or nil,
		})
	end
	return out
end

function TrainService:Push(player)
	local view = { upgrades = self:View(), fuel = expedition:Fuel(), cost = expedition:FuelCost() }
	if player then
		data:Push(player, { train = view })
	else
		for _, p in Players:GetPlayers() do
			data:Push(p, { train = view })
		end
	end
end

-- Doors ----------------------------------------------------------------------------------------------------------------
function TrainService:Doors(state)
	doorState = state
	workspace:SetAttribute("Doors", state)
	local layout = WorldBuilder.layout
	for _, d in layout.train.doors do
		local open = state ~= "closed"
		for _, leaf in d.leaves do
			leaf.part.CFrame = open and leaf.open or leaf.closed
		end
		d.blocker.CanCollide = not open
		d.lamp.Color = state == "closing" and Color3.fromRGB(255, 70, 60) or Color3.fromRGB(90, 255, 120)
		d.lamp.Material = state == "closed" and Enum.Material.SmoothPlastic or Enum.Material.Neon
		d.lampLight.Brightness = state == "closed" and 0 or 1.5
		d.lampLight.Color = d.lamp.Color
		d.beaconLight.Brightness = state == "closing" and 2 or 0
	end
end

function TrainService:DoorState()
	return doorState
end

-- Visuals --------------------------------------------------------------------------------------------------------------
function TrainService:_visuals()
	local t = WorldBuilder.layout.train
	for i, m in t.engineStages do
		show(m, (stages.engine or 0) >= i)
	end
	for i, m in t.lampStages do
		show(m, (stages.lamp or 0) >= i)
	end
	-- the furnace burns hotter and bluer with the overhaul
	if t.furnaceLight then
		local e = stages.engine or 0
		t.furnaceLight.Brightness = 2.2 + e * 0.5
		t.furnaceLight.Color = e >= 3 and Color3.fromRGB(120, 180, 255) or Color3.fromRGB(255, 130, 60)
	end
	-- the navigation table lights up with the Searchlight
	if t.navLamp then
		for _, l in t.navLamp:GetChildren() do
			if l:IsA("Light") then
				l.Brightness = (stages.lamp or 0) >= 1 and 1.6 or 0
			end
		end
	end
	self:_gauge()
	self:_board()
end

function TrainService:_gauge()
	local t = WorldBuilder.layout.train
	local fuel, cost = expedition:Fuel(), expedition:FuelCost()
	if t.fuelBar then
		local h = math.clamp(fuel / 10, 0.02, 1) * 8
		t.fuelBar.Size = Vector3.new(1.1, h, 0.4)
		t.fuelBar.CFrame = CFrame.new(t.fuelBase + Vector3.new(0, h / 2, 0))
		t.fuelBar.Color = fuel + 1e-6 < cost and Color3.fromRGB(255, 120, 40) or Color3.fromRGB(206, 48, 40)
	end
	if t.fuelText then
		t.fuelText.Text = `FUEL {fuel} · TRIP {cost}`
	end
end

function TrainService:_board()
	local t = WorldBuilder.layout.train
	if not t.upgradeBoard then
		return
	end
	local lines = { "TRAIN UPGRADES" }
	for _, u in TrainUpgrades.list do
		local n = stages[u.key] or 0
		local stage = u.stages[n + 1]
		if stage then
			table.insert(lines, `{u.icon} {u.name}: next {stage.name} ({math.floor(Formulas.stageProgress(stage, given[u.key]) * 100)}%)`)
		else
			table.insert(lines, `{u.icon} {u.name}: COMPLETE`)
		end
	end
	table.insert(lines, "Hold E here, or tap TRAIN, to give materials")
	t.upgradeBoard.Text = table.concat(lines, "\n")
end

-- Giving -----------------------------------------------------------------------------------------------------------------
local function announce(text)
	Net.fireAll("Announce", text, "milestone")
end

function TrainService:Deposit(player, key, resource, amount)
	local u = TrainUpgrades.byKey[key]
	local profile = data:Get(player)
	if not u or not profile or type(resource) ~= "string" then
		return false, "bad"
	end
	local pos = expedition:Position(player)
	if expedition:InRecovery(player) or (pos and not Layout.inTrain(pos) and expedition:Phase() ~= "lobby") then
		Net.fire(player, "Toast", "Get back on the train to give materials.", "bad")
		return false, "away"
	end
	local n = stages[key] or 0
	local stage = u.stages[n + 1]
	if not stage then
		return false, "done"
	end
	given[key] = given[key] or {}
	local g = given[key]
	local gave
	if resource == "plans" then
		if not stage.plans or g.plans then
			return false, "notneeded"
		end
		if (profile.blueprints[stage.plans] or 0) < 1 then
			Net.fire(player, "Toast", `You need {Resources.BLUEPRINTS[stage.plans].name}: find them at a stop's landmark.`, "bad")
			return false, "noplans"
		end
		profile.blueprints[stage.plans] -= 1
		g.plans = true
		gave = 1
		expedition:Note(player, "blueprints", 1)
	else
		if not Resources.isMaterial(resource) or not stage.cost[resource] then
			return false, "notneeded"
		end
		local need = stage.cost[resource] - (g[resource] or 0)
		amount = math.floor(tonumber(amount) or 0)
		local n2 = math.min(amount, need, profile.storage[resource] or 0)
		if n2 <= 0 then
			if need > 0 then
				Net.fire(player, "Toast", `You don't have any {Resources.byKey[resource].name} yet.`, "bad")
			end
			return false, "none"
		end
		profile.storage[resource] -= n2
		g[resource] = (g[resource] or 0) + n2
		profile.stats.deposited += n2
		gave = n2
		expedition:Note(player, "materials", n2)
	end
	data:Push(player, { storage = profile.storage, blueprints = profile.blueprints })
	self.Deposited:Fire(player, key, resource, gave)
	Net.fire(player, "Sfx", "deposit")
	if Formulas.stageDone(stage, g) then
		stages[key] = n + 1
		given[key] = {}
		announce(`{u.icon} {stage.name} is done! {stage.effect}`)
		Net.fireAll("Sfx", "upgrade")
		self.Upgraded:Fire(key, n + 1, player)
	end
	self:_visuals()
	self:Push()
	expedition:PushAll()
	return true, gave
end

function TrainService:Reset()
	stages = {}
	given = {}
	self:_visuals()
	self:Push()
end

function TrainService:Init(registry)
	data = registry.PlayerDataService
	expedition = registry.ExpeditionService
	Net.on("Deposit", function(player, key, resource, amount)
		self:Deposit(player, key, resource, amount)
	end)
	expedition.Started:Connect(function()
		self:Reset()
	end)
	expedition.FuelAdded:Connect(function()
		self:_gauge()
		self:Push()
	end)
	expedition.PhaseChanged:Connect(function()
		self:_gauge()
		self:_board()
	end)
	data.ClientReady:Connect(function(player)
		self:Push(player)
	end)
	-- the upgrades board in the engine room opens the TRAIN panel (PromptController); a prompt so it's findable
	local board = WorldBuilder.layout.train.upgradeBoardPart
	if board then
		local p = Instance.new("ProximityPrompt")
		p.Name = "Prompt_train"
		p.ActionText = "Give materials"
		p.ObjectText = "Train upgrades"
		p.HoldDuration = 0
		p.MaxActivationDistance = 12
		p.RequiresLineOfSight = false
		p.Parent = board
	end
	self:_visuals()
end

function TrainService:OnPlayerReady(player)
	self:Push(player)
end

return TrainService
