--[[
Stone, wood and gold (master plan §7): rock piles and crystals, trees and giant mushrooms, gold veins at the mine
mouths in the hills on the sides. Hit a node with your main move (CombatService sends it here) and it gives a
little: Miners twice as much, with a chance of a gem. A node runs out and comes back NODE_RESPAWN seconds later.

What you carry is your bag (BAG_CAP, more for Miners): every hammer hit on a blueprint puts some in (BuildService),
the forge, kitchen and potion table take some (CraftService). Bags are for this match only.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Jobs = require(ReplicatedStorage.Shared.Data.Jobs)
local MapLayout = require(ReplicatedStorage.Shared.World.MapLayout)
local Net = require(ReplicatedStorage.Shared.Net)
local Pieces = require(ReplicatedStorage.Shared.Data.Pieces)
local Signal = require(ReplicatedStorage.Shared.Signal)
local MapBuilder = require(script.Parent.Parent.World.MapBuilder)

local ResourceService = {
	Name = "ResourceService",
	Dependencies = { "PlayerDataService", "MatchService", "TeamService" },
	Mined = Signal.new("ResourceService.Mined"), -- (player, kind, amount, nodeId, gem)
	BagFull = Signal.new("ResourceService.BagFull"), -- (player)
	Depleted = Signal.new("ResourceService.Depleted"), -- (nodeId)
}

local match, teams
local nodes = {} -- [id] = { id, kind, pos, amount, max, model, respawnAt, size, starter }
local bags = {} -- [player] = { stone, wood, gold }
local folder

local ICON = {}
for _, m in Pieces.MATERIALS do
	ICON[m.key] = m.icon
end
local SOUND = { stone = "mine", wood = "chop", gold = "mine" }

local function now()
	return workspace:GetServerTimeNow()
end

-- Bags ----------------------------------------------------------------------------------------------------------
function ResourceService:Bag(player)
	local b = bags[player]
	if not b then
		b = { stone = 0, wood = 0, gold = 0 }
		bags[player] = b
	end
	return b
end

function ResourceService:Capacity(player)
	local job = teams:JobData(player)
	return job and job.bag or Constants.BAG_CAP
end

function ResourceService:Count(player)
	local b = self:Bag(player)
	return b.stone + b.wood + b.gold
end

function ResourceService:Space(player)
	return math.max(0, self:Capacity(player) - self:Count(player))
end

function ResourceService:PushBag(player)
	local b = self:Bag(player)
	local cap = self:Capacity(player)
	Net.fire(player, "Bag", { stone = b.stone, wood = b.wood, gold = b.gold, cap = cap })
	-- a full bag looks heavy (the sack on your back)
	local heavy = (b.stone + b.wood + b.gold) >= cap * Constants.HEAVY_AT
	local c = player.Character
	if c then
		for _, name in { "Sack", "SackRock" } do
			local part = c:FindFirstChild(name)
			if part then
				part.Transparency = heavy and 0 or 1
			end
		end
		c:SetAttribute("Heavy", heavy)
	end
end

-- Add to a bag (up to the space left). Returns what fit.
function ResourceService:Give(player, kind, amount)
	if not ICON[kind] or amount <= 0 then
		return 0
	end
	local fit = math.min(amount, self:Space(player))
	if fit > 0 then
		local b = self:Bag(player)
		b[kind] += fit
		self:PushBag(player)
	end
	return fit
end

-- Take exactly `need` ({ kind = n }) if the bag has it all. Returns true if taken.
function ResourceService:Take(player, need)
	local b = self:Bag(player)
	for k, n in need do
		if (b[k] or 0) < n then
			return false
		end
	end
	for k, n in need do
		b[k] -= n
	end
	self:PushBag(player)
	return true
end

-- Take up to `n` of one kind (a hammer hit putting materials into a blueprint). Returns how many.
function ResourceService:TakeUpTo(player, kind, n)
	local b = self:Bag(player)
	local got = math.min(n, b[kind] or 0)
	if got > 0 then
		b[kind] -= got
		self:PushBag(player)
	end
	return got
end

function ResourceService:ResetBag(player, start)
	bags[player] = {
		stone = start and Constants.START_BAG.stone or 0,
		wood = start and Constants.START_BAG.wood or 0,
		gold = start and Constants.START_BAG.gold or 0,
	}
	self:PushBag(player)
end

-- Nodes ----------------------------------------------------------------------------------------------------------
function ResourceService:Node(id)
	return nodes[id]
end

function ResourceService:Nodes()
	return nodes
end

-- The nearest node of a kind with something left (NPC dwarves use this), in the same zone if possible.
function ResourceService:NearestNode(kind, pos)
	local best, bestD
	for _, n in nodes do
		if n.kind == kind and n.amount > 0 then
			local d = (n.pos - pos).Magnitude
			if MapLayout.zoneOf(n.pos.X) ~= MapLayout.zoneOf(pos.X) then
				d += 400
			end
			if not bestD or d < bestD then
				best, bestD = n, d
			end
		end
	end
	return best
end

-- The node in reach of a position (the client's context button asks for this one).
function ResourceService:NodeInReach(pos, id)
	local n = nodes[id]
	if not n or n.amount <= 0 then
		return nil
	end
	local flat = Vector3.new(pos.X - n.pos.X, 0, pos.Z - n.pos.Z).Magnitude
	if flat > Constants.MINE_RANGE + n.size / 2 or math.abs(pos.Y - n.pos.Y) > 14 then
		return nil
	end
	return n
end

local function setVisible(n, visible)
	if n.model then
		n.model.Parent = visible and folder or nil
	end
	if n.stump then
		n.stump.Parent = (not visible) and folder or nil
	end
end

local function refill(n)
	n.amount = n.max
	n.respawnAt = nil
	setVisible(n, true)
	n.model:SetAttribute("Amount", n.amount)
end

-- Mine a node: called by CombatService for a main move on a node in reach. power: units this hit gives.
function ResourceService:Mine(player, id, power, big)
	local pos = teams:Position(player)
	local n = pos and self:NodeInReach(pos, id)
	if not n then
		return false
	end
	local space = self:Space(player)
	if space <= 0 then
		self.BagFull:Fire(player)
		Net.fire(player, "Toast", "Your bag is full! Hammer a blueprint to put it in.", "bad")
		return false
	end
	local job = teams:JobData(player)
	local amount = math.min(power, n.amount, space)
	n.amount -= amount
	n.model:SetAttribute("Amount", n.amount)
	local b = self:Bag(player)
	b[n.kind] += amount
	local gem = false
	if job and job.gems and n.kind ~= "wood" and math.random() < Constants.GEM_CHANCE * (big and 3 or 1) then
		gem = true
		local extra = math.min(Constants.GEM_GOLD, self:Space(player))
		b.gold += extra
	end
	self:PushBag(player)
	teams:Stat(player, "mined", amount)
	Net.fire(
		player,
		"Popup",
		n.pos + Vector3.new(0, 6, 0),
		`+{amount} {ICON[n.kind]}` .. (gem and "  💎 GEM!" or ""),
		gem and "gold" or n.kind
	)
	Net.fireAll("Fx", "mine", { node = id, position = n.pos, kind = n.kind, by = player.UserId })
	Net.fireAll("Sfx", SOUND[n.kind], n.pos)
	self.Mined:Fire(player, n.kind, amount, id, gem)
	if n.amount <= 0 then
		n.respawnAt = now() + (n.starter and 12 or Constants.NODE_RESPAWN)
		setVisible(n, false)
		Net.fireAll("Fx", "deplete", { node = id, position = n.pos, kind = n.kind })
		self.Depleted:Fire(id)
	end
	_ = Jobs
	return true, amount
end

function ResourceService:_build()
	folder = workspace:FindFirstChild("Nodes") or Instance.new("Folder")
	folder.Name = "Nodes"
	folder.Parent = workspace
	for _, spec in MapLayout.nodes do
		local model = MapBuilder.nodeModel(spec, folder)
		local amount = MapLayout.NODE_AMOUNT[spec.kind]
		model:SetAttribute("Amount", amount)
		model:SetAttribute("Max", amount)
		-- what's left when it runs out: a stump, a few pebbles
		local stump = Instance.new("Model")
		stump.Name = "Spent" .. spec.id
		local p = Instance.new("Part")
		p.Name = "Stump"
		p.Anchored = true
		p.CanCollide = false
		p.Size = spec.kind == "wood" and Vector3.new(2.4, 1.2, 2.4) or Vector3.new(3, 0.8, 3)
		p.Shape = spec.kind == "wood" and Enum.PartType.Cylinder or Enum.PartType.Block
		p.CFrame = CFrame.new(spec.pos + Vector3.new(0, 0.5, 0))
			* (spec.kind == "wood" and CFrame.Angles(0, 0, math.rad(90)) or CFrame.new())
		p.Color = spec.kind == "wood" and Color3.fromRGB(150, 98, 60) or Color3.fromRGB(150, 146, 140)
		p.Material = Enum.Material.SmoothPlastic
		p.Parent = stump
		nodes[spec.id] = {
			id = spec.id,
			kind = spec.kind,
			pos = spec.pos,
			amount = amount,
			max = amount,
			model = model,
			stump = stump,
			size = MapLayout.NODE_SIZE[spec.kind],
			starter = spec.starter == true,
		}
	end
end

function ResourceService:Init(reg)
	match = reg.MatchService
	teams = reg.TeamService
	self:_build()
	match.Started:Connect(function()
		for _, n in nodes do
			refill(n)
		end
	end)
	teams.TeamChanged:Connect(function(player, team, why)
		if team == "dwarf" then
			self:ResetBag(player, why == "start" or why == "join")
		else
			self:ResetBag(player, false)
		end
	end)
	teams.JobChanged:Connect(function(player)
		self:PushBag(player)
	end)
	teams.Spawned:Connect(function(player)
		self:PushBag(player)
	end)
end

function ResourceService:Start()
	while true do
		task.wait(1)
		local t = now()
		for _, n in nodes do
			if n.respawnAt and t >= n.respawnAt then
				refill(n)
				Net.fireAll("Fx", "regrow", { node = n.id, position = n.pos, kind = n.kind })
			end
		end
	end
end

function ResourceService:OnPlayerReady(player)
	self:PushBag(player)
end

function ResourceService:OnPlayerLeaving(player)
	bags[player] = nil
end

return ResourceService
