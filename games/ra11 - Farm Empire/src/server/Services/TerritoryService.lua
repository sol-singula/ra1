--[[
Territories (master plan §4): twelve round the town, one a player, permanent for the session. Builds the town once
and each farm from its profile when the player arrives (World/TerritoryBuilder), rebuilds the parts that change
(fields, buildings, the preview) when an upgrade lands, and spawns the character at the farm's gate. Visiting:
a walk to another farm or a teleport from the town; the camera and the HUD stay yours.

  TerritoryService:Territory(player)     { index, model }
  TerritoryService:Spot(player, name)    a world Vector3 of a named spot on their farm (Layout.SPOTS)
  TerritoryService:Refresh(player, what) "fields" | "buildings" | "preview" | "all"
  TerritoryService:OwnerOf(index)
]]
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Business = require(ReplicatedStorage.Shared.Data.Business)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Layout = require(ReplicatedStorage.Shared.World.Layout)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local TerritoryBuilder = require(ReplicatedStorage.Shared.World.TerritoryBuilder)
local TownBuilder = require(ReplicatedStorage.Shared.World.TownBuilder)
local Upgrades = require(ReplicatedStorage.Shared.Data.Upgrades)

local TerritoryService = {
	Name = "TerritoryService",
	Dependencies = { "PlayerDataService", "CropService", "BusinessService", "UpgradeService" },
	Changed = Signal.new("TerritoryService.Changed"),
}

local data, crops, upgrades
local byPlayer = {} -- [player] = { index, model }
local byIndex = {} -- [index] = player
local folder, town
local spawning = {}

local function view(player)
	local p = data:Get(player)
	local nxt = Business.next(p.stage)
	local fieldCosts = {}
	for _, key in { "field2", "field3", "field4" } do
		fieldCosts[key] = Upgrades.cost(key, 0)
	end
	return {
		stage = p.stage,
		owned = p.owned,
		tiles = crops:Tiles(player),
		name = player.DisplayName or player.Name,
		docks = 1 + Upgrades.stat(p.owned, "docks", 0),
		machine = Upgrades.machine(p.owned),
		paint = p.cosmetics
				and p.cosmetics.paint
				and Color3.fromRGB(p.cosmetics.paint[1], p.cosmetics.paint[2], p.cosmetics.paint[3])
			or nil,
		next = nxt and { key = nxt.key, name = nxt.name, cost = nxt.cost }
			or (p.stage == "center" and { key = "region", name = "a New Region", cost = Upgrades.region.cost } or nil),
		fieldCosts = fieldCosts,
	}
end

function TerritoryService:Territory(player)
	return byPlayer[player]
end

function TerritoryService:OwnerOf(index)
	return byIndex[index]
end

function TerritoryService:Spot(player, name)
	local t = byPlayer[player]
	local s = Layout.SPOTS[name]
	if not t or not s then
		return nil
	end
	return Layout.toWorld(t.index, s.x, s.z, 0)
end

function TerritoryService:Refresh(player, what)
	local t = byPlayer[player]
	if not t then
		return
	end
	local v = view(player)
	if what == "fields" or what == "all" then
		TerritoryBuilder.fields(t.model, t.index, v)
	end
	if what == "buildings" or what == "all" then
		TerritoryBuilder.buildings(t.model, t.index, v)
	end
	if what == "preview" or what == "all" then
		TerritoryBuilder.preview(t.model, t.index, v)
	end
	self.Changed:Fire(player, what)
end

local function freeIndex()
	-- the free territory nearest the town (so a quiet server's farms are neighbours)
	local order = { 3, 4, 2, 5, 9, 10, 1, 6, 8, 11, 7, 12 }
	for _, i in order do
		if not byIndex[i] then
			return i
		end
	end
	return nil
end

function TerritoryService:Spawn(player)
	local t = byPlayer[player]
	if not t or not player.Parent or spawning[player] then
		return
	end
	spawning[player] = true
	local ok = pcall(function()
		player:LoadCharacter()
	end)
	spawning[player] = nil
	if not ok then
		return
	end
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if hrp then
		local s = Layout.SPOTS.spawn
		local st = Layout.SPOTS.stand
		hrp.CFrame = CFrame.lookAt(Layout.toWorld(t.index, s.x, s.z, 3.5), Layout.toWorld(t.index, st.x, st.z, 3.5))
	end
end

function TerritoryService:Push(player)
	local t = byPlayer[player]
	if not t then
		return
	end
	local spawn = self:Spot(player, "spawn")
	Net.fire(player, "Territory", {
		index = t.index,
		stage = data:Get(player).stage,
		spawn = spawn and { spawn.X, spawn.Y, spawn.Z } or nil,
		rotation = Layout.territory(t.index).rotation,
	})
end

-- Every farm's numbers for the town and the visitors' HUD
function TerritoryService:PushTown()
	local list = {}
	for i = 1, Constants.TERRITORIES do
		local owner = byIndex[i]
		local p = owner and data:Get(owner)
		list[i] = p
				and {
					name = owner.DisplayName or owner.Name,
					userId = owner.UserId,
					stage = p.stage,
					earned = math.floor(p.stats.earned or 0),
				}
			or false
	end
	Net.fireAll("Town", list)
end

function TerritoryService:OnPlayerLoaded(player, profile)
	local i = freeIndex()
	if not i then
		player:Kick("This server is full. Please try another.")
		return
	end
	byIndex[i] = player
	local old = folder:FindFirstChild("T" .. i)
	if old then
		old:Destroy()
	end
	local t = { index = i }
	byPlayer[player] = t
	t.model = TerritoryBuilder.build(folder, i, view(player))
	_ = profile
	self:Spawn(player)
	player.CharacterAdded:Connect(function()
		-- (a respawn after a fall: back at the gate)
		task.defer(function()
			local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if hrp and byPlayer[player] and not spawning[player] then
				local s = Layout.SPOTS.spawn
				hrp.CFrame = CFrame.new(Layout.toWorld(byPlayer[player].index, s.x, s.z, 3.5))
			end
		end)
	end)
	self:PushTown()
end

function TerritoryService:OnPlayerReady(player)
	data:WhenClientReady(player, function()
		self:Push(player)
		self:PushTown()
		-- a brand-new player's opening (once, ever)
		local p = data:Get(player)
		if p and not p.opening then
			p.opening = true
			task.delay(0.5, function()
				if player.Parent then
					Net.fire(player, "Camera", { kind = "opening" })
				end
			end)
		end
	end)
end

function TerritoryService:OnPlayerLeaving(player)
	local t = byPlayer[player]
	if t then
		byIndex[t.index] = nil
		byPlayer[player] = nil
		if t.model then
			t.model:Destroy()
			TerritoryBuilder.empty(folder, t.index)
		end
	end
	task.defer(function()
		self:PushTown()
	end)
end

function TerritoryService:Init(registry)
	data = registry.PlayerDataService
	crops = registry.CropService
	upgrades = registry.UpgradeService
	folder = Instance.new("Folder")
	folder.Name = "Territories"
	folder.Parent = workspace
	town = TownBuilder.build(workspace)
	for i = 1, Constants.TERRITORIES do
		TerritoryBuilder.empty(folder, i)
	end
	-- an upgrade changes the world: fields, buildings, the preview
	upgrades.Applied:Connect(function(player, key)
		local u = Upgrades[key]
		local e = u.effect
		if e.tiles or e.field then
			self:Refresh(player, "fields")
		end
		if e.business or e.machine or e.docks then
			self:Refresh(player, "buildings")
			self:Refresh(player, "preview")
		end
		if e.business then
			self:Push(player)
			self:PushTown()
			Net.fire(player, "Camera", { kind = "reveal", key = e.business })
		elseif e.machine == 1 then
			Net.fire(player, "Camera", { kind = "machine" })
		elseif e.crop then
			Net.fire(player, "Camera", { kind = "crop", crop = e.crop })
		end
	end)
	-- the previews' prompts: Build
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt.Name == "Build" and prompt:GetAttribute("Upgrade") then
			local t = byPlayer[player]
			if t and prompt:IsDescendantOf(t.model) then
				upgrades:Buy(player, prompt:GetAttribute("Upgrade"))
			end
		end
	end)
	-- visiting: a teleport to a farm's gate or the town, or home
	Net.on("Visit", function(player, what, index)
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not hrp then
			return
		end
		if what == "home" then
			local t = byPlayer[player]
			if t then
				local s = Layout.SPOTS.spawn
				hrp.CFrame = CFrame.new(Layout.toWorld(t.index, s.x, s.z, 3.5))
			end
		elseif what == "town" then
			hrp.CFrame = CFrame.new(0, 3.5, -Layout.TOWN / 2 + 12)
		elseif what == "go" and type(index) == "number" and byIndex[index] then
			local g = Layout.SPOTS.gate
			hrp.CFrame = CFrame.new(Layout.toWorld(index, g.x - 8, g.z + 5, 3.5))
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		spawning[player] = nil
	end)
	_ = town
end

return TerritoryService
