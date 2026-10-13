-- Personal cabins: every player gets one of the 20 cabins when they join, drawn from their save (Data/CabinItems,
-- World/CabinBuilder). The cabin starts bare (a bedroll, a dim bulb, a cardboard box) and every upgrade makes
-- something appear right away. Nobody else can build in your cabin, but anyone can visit.
--   Build(player, key, variant)  checks Formulas.canBuild, takes the materials (and a blueprint for the map board and
--                                specialist station) and builds it. The finish and the specialist path can be changed
--                                for free once built.
--   SetColor(player, key)        the cabin colour (door sign, blanket, curtains, cushions): free, the first thing
--                                a new player changes
--   Salvage(player)              at your workbench: SALVAGE_SCRAP scrap -> 1 part
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CabinBuilder = require(ReplicatedStorage.Shared.World.CabinBuilder)
local CabinItems = require(ReplicatedStorage.Shared.Data.CabinItems)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Kit = require(ReplicatedStorage.Shared.World.Kit)
local Layout = require(ReplicatedStorage.Shared.World.Layout)
local Net = require(ReplicatedStorage.Shared.Net)
local Resources = require(ReplicatedStorage.Shared.Data.Resources)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Stops = require(ReplicatedStorage.Shared.Data.Stops)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local CabinService = {
	Name = "CabinService",
	Dependencies = { "PlayerDataService", "ExpeditionService" },
	Built = Signal.new("CabinService.Built"), -- (player, key, variant, firstTime)
	ColorSet = Signal.new("CabinService.ColorSet"), -- (player, key)
	Salvaged = Signal.new("CabinService.Salvaged"), -- (player)
}

local data, expedition, registryRef
local owner = {} -- [cabinIndex] = player
local byPlayer = {} -- [player] = cabinIndex
local prompts = {} -- [cabinIndex] = { build, paint }

local function handle(index)
	return WorldBuilder.layout.train.cabins[index]
end

function CabinService:CabinOf(player)
	local i = byPlayer[player]
	return i and Layout.cabins[i] or nil
end

function CabinService:IndexOf(player)
	return byPlayer[player]
end

function CabinService:Owner(index)
	return owner[index]
end

local function colorOf(profile)
	local c = profile and profile.cabin.color and CabinItems.colorByKey[profile.cabin.color]
	return c and c.color or nil
end

-- Redraw one cabin from its owner's save (or bare and vacant).
function CabinService:Draw(index)
	local h = handle(index)
	if not h then
		return
	end
	local player = owner[index]
	local profile = player and data:Get(player)
	h.items:ClearAllChildren()
	local built = profile and profile.cabin.built or {}
	local variants = profile and profile.cabin.variants or {}
	local color = colorOf(profile)
	CabinBuilder.applyFinish(h, built.finish and (variants.finish or "oak") or "bare")
	CabinBuilder.applyColor(h, color)
	for _, item in CabinItems.list do
		if built[item.key] then
			CabinBuilder.item(h.items, h.cf, item.key, { variant = variants[item.key], color = color })
		end
	end
	if built.shelf and profile then
		CabinBuilder.souvenirs(h.items, h.cf, profile.souvenirs)
	end
	-- the bare things go as their upgrades arrive
	for _, p in h.bare:GetChildren() do
		local gone = (p.Name == "Bedroll" or p.Name == "Pillow") and built.bunk
			or (p.Name == "DimBulb" or p.Name == "Wire") and built.ceiling
			or p.Name == "Box" and built.crate
		p.Transparency = gone and 1 or 0
		p.CanCollide = not gone and p.Name ~= "DimBulb" and p.Name ~= "Wire"
		for _, l in p:GetChildren() do
			if l:IsA("Light") then
				l.Enabled = not gone
			end
		end
	end
	-- the work surface turns into the specialist station
	if built.specialist then
		local ws = h.items:FindFirstChild("worksurface")
		if ws then
			for _, p in ws:GetChildren() do
				if p.Name == "Jar" then
					p:Destroy()
				end
			end
		end
	end
	-- the map board shows where you've been
	if built.mapboard and profile then
		local board = h.items:FindFirstChild("mapboard")
		local part = board and board:FindFirstChild("MapBoard")
		if part then
			local seen = {}
			for _, s in Stops.list do
				table.insert(seen, (profile.visited[s.key] and "✔ " or "· ") .. s.name)
			end
			Kit.text(
				part,
				Enum.NormalId.Back,
				`MY JOURNEY\n{table.concat(seen, "\n")}\nBEST: {Formulas.round1(profile.best or 0)} km`,
				{
					color = Kit.C.black,
					ppu = 40,
					font = Enum.Font.Oswald,
				}
			)
		end
	end
	h.plate.Text = player and `{index} · {string.upper(player.DisplayName)}` or `{index} · VACANT`
	local pr = prompts[index]
	if pr then
		pr.build:SetAttribute("OwnerUserId", player and player.UserId or 0)
		pr.paint:SetAttribute("OwnerUserId", player and player.UserId or 0)
		pr.build.Enabled = player ~= nil
		pr.paint.Enabled = player ~= nil
	end
end

function CabinService:Push(player)
	local profile = data:Get(player)
	if profile then
		data:Push(player, {
			cabin = profile.cabin,
			cabinIndex = byPlayer[player],
			storage = profile.storage,
			blueprints = profile.blueprints,
			souvenirs = profile.souvenirs,
			visited = profile.visited,
			best = profile.best,
		})
	end
end

function CabinService:Build(player, key, variant)
	local profile = data:Get(player)
	local item = CabinItems.byKey[key]
	if not profile or not item or not byPlayer[player] then
		return false, "bad"
	end
	local built = profile.cabin.built
	if item.variants and variant ~= nil and not CabinItems.variant(item, variant) then
		return false, "variant"
	end
	-- changing the look of something already built is free
	if built[key] then
		if item.variants and variant and profile.cabin.variants[key] ~= variant then
			profile.cabin.variants[key] = variant
			self:Draw(byPlayer[player])
			self:Push(player)
			self.Built:Fire(player, key, variant, false)
			Net.fire(player, "Sfx", "build")
			return true
		end
		return false, "built"
	end
	local ok, why = Formulas.canBuild(item, built, profile.storage, profile.blueprints)
	if not ok then
		local msg = why == "needs" and `Build the {CabinItems.byKey[item.needs].short} first.`
			or why == "plans" and `You need {Resources.BLUEPRINTS[item.plans].name}. Look for blueprints at the stops' landmarks.`
			or `Not enough materials: it needs {Resources.costText(item.cost)}.`
		Net.fire(player, "Toast", msg, "bad")
		return false, why
	end
	for res, n in item.cost do
		profile.storage[res] -= n
	end
	if item.plans then
		profile.blueprints[item.plans] -= 1
	end
	built[key] = true
	if item.variants then
		profile.cabin.variants[key] = variant or item.variants[1].key
	end
	profile.stats.builds += 1
	self:Draw(byPlayer[player])
	self:Push(player)
	local h = handle(byPlayer[player])
	Net.fire(player, "Popup", h.cf.Position + Vector3.new(0, 7, 0), `🛠 {item.short}!`, Color3.fromRGB(255, 220, 150))
	Net.fire(player, "Toast", `Built: {item.short}. {item.benefit}`, "good")
	Net.fire(player, "Sfx", "build")
	self.Built:Fire(player, key, profile.cabin.variants[key], true)
	-- a bigger bag right away
	if key == "crate" or key == "locker" then
		local resources = registryRef and registryRef.ResourceService
		if resources then
			resources:PushBag(player)
		end
	end
	return true
end

function CabinService:SetColor(player, key)
	local profile = data:Get(player)
	if not profile or not CabinItems.colorByKey[key] or not byPlayer[player] then
		return false
	end
	local first = profile.cabin.color == nil
	profile.cabin.color = key
	self:Draw(byPlayer[player])
	self:Push(player)
	Net.fire(player, "Sfx", "build")
	self.ColorSet:Fire(player, key, first)
	return true
end

function CabinService:Salvage(player)
	local profile = data:Get(player)
	if not profile or not profile.cabin.built.workbench then
		Net.fire(player, "Toast", "Build a workbench first.", "bad")
		return false
	end
	if (profile.storage.scrap or 0) < Constants.SALVAGE_SCRAP then
		Net.fire(player, "Toast", `Salvage needs {Constants.SALVAGE_SCRAP} 🔩 scrap.`, "bad")
		return false
	end
	profile.storage.scrap -= Constants.SALVAGE_SCRAP
	profile.storage.parts += 1
	profile.stats.salvaged += 1
	self:Push(player)
	Net.fire(player, "Toast", `Salvaged {Constants.SALVAGE_SCRAP} 🔩 into 1 ⚙️.`, "good")
	Net.fire(player, "Sfx", "build")
	self.Salvaged:Fire(player)
	return true
end

function CabinService:Init(registry)
	registryRef = registry
	data = registry.PlayerDataService
	expedition = registry.ExpeditionService
	Net.on("Build", function(player, key, variant)
		if type(key) == "string" and (variant == nil or type(variant) == "string") then
			self:Build(player, key, variant)
		end
	end)
	Net.on("SetColor", function(player, key)
		if type(key) == "string" then
			self:SetColor(player, key)
		end
	end)
	Net.on("Salvage", function(player)
		self:Salvage(player)
	end)
	data.ClientReady:Connect(function(player)
		self:Push(player)
	end)
	-- the souvenir shelf and map board change at every stop
	expedition.Arrived:Connect(function()
		for player, index in byPlayer do
			local profile = data:Get(player)
			if profile and (profile.cabin.built.shelf or profile.cabin.built.mapboard) then
				self:Draw(index)
			end
		end
	end)
	-- prompts in every cabin: BUILD (in the middle) and the door sign (colour); only the owner sees them
	for i, cabin in Layout.cabins do
		local h = handle(i)
		if h then
			local spot = Kit.box(
				h.model,
				"BuildSpot",
				cabin.cf * CFrame.new(0, 3.5, 0),
				Vector3.new(1, 1, 1),
				Kit.C.black,
				Kit.M.SmoothPlastic,
				{
					Transparency = 1,
					CanCollide = false,
					CanQuery = false,
					CastShadow = false,
				}
			)
			local build = Instance.new("ProximityPrompt")
			build.Name = "Prompt_build"
			build.ActionText = "Build"
			build.ObjectText = "My cabin"
			build.HoldDuration = 0
			build.MaxActivationDistance = 14
			build.RequiresLineOfSight = false
			build.Enabled = false
			build.Parent = spot
			local plate = h.plate.Parent and h.plate.Parent.Parent
			local paint = Instance.new("ProximityPrompt")
			paint.Name = "Prompt_paint"
			paint.ActionText = "Pick a colour"
			paint.ObjectText = "Door sign"
			paint.HoldDuration = 0
			paint.MaxActivationDistance = 10
			paint.RequiresLineOfSight = false
			paint.Enabled = false
			paint.KeyboardKeyCode = Enum.KeyCode.F
			paint.Parent = plate
			prompts[i] = { build = build, paint = paint }
			self:Draw(i)
		end
	end
end

function CabinService:OnPlayerReady(player, profile)
	-- the first free cabin, front of the train first
	for i = 1, #Layout.cabins do
		if not owner[i] then
			owner[i] = player
			byPlayer[player] = i
			player:SetAttribute("Cabin", i)
			break
		end
	end
	profile.cabin.built = profile.cabin.built or {}
	profile.cabin.variants = profile.cabin.variants or {}
	if byPlayer[player] then
		self:Draw(byPlayer[player])
	end
	self:Push(player)
end

function CabinService:OnPlayerLeaving(player)
	local i = byPlayer[player]
	if i then
		owner[i] = nil
		byPlayer[player] = nil
		self:Draw(i)
	end
end

return CabinService
