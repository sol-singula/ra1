--[[
What you carry (master plan §6: persistent inventory; §7: collecting). The server owns every item: the client asks
to select, move, use or drop, and the server checks and answers.

  slots      h1..h6 the hotbar (tap or 1-6 to hold), b1..bN the bag (N = the raft's cargo: Formulas.cargo, more
             with storage boxes)
  stacks     resources and food stack (Data/Items: stack); a slot may carry `data` (a chart's destination, a
             blueprint's piece or recipe, a crate's waters)
  finds      everything you pick up while your raft is away from its dock counts as this voyage's finds; go down
             away from your raft and half of it floats off as a lost bag where you fell (PlayerService); sail
             home and it's safe (VoyageService clears it)
  drops      things dropped or overflowing float on the water as a bag: cast at it or take it from the deck
  held       the selected hotbar item is in your character's hand (ItemModels)
  saved      in your profile the moment it changes
]]
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local ItemModels = require(ReplicatedStorage.Shared.World.ItemModels)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Net = require(ReplicatedStorage.Shared.Net)
local OceanModels = require(ReplicatedStorage.Shared.World.OceanModels)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Voyages = require(ReplicatedStorage.Shared.Data.Voyages)

local InventoryService = {
	Name = "InventoryService",
	Dependencies = { "PlayerDataService", "RaftService" },
	Changed = Signal.new("InventoryService.Changed"), -- (player)
	Gained = Signal.new("InventoryService.Gained"), -- (player, key, n, source, data?)
	SlotSelected = Signal.new("InventoryService.SlotSelected"), -- (player, slotId, item?)
	Used = Signal.new("InventoryService.Used"), -- (player, item, data?)
	Dropped = Signal.new("InventoryService.Dropped"), -- (player, key, n)
	PickedUp = Signal.new("InventoryService.PickedUp"), -- (player, drop)
	Ate = Signal.new("InventoryService.Ate"), -- (player, item)
}

local data, rafts, registry
local inv = {} -- [player] = { slots = { [id] = { key, n, data? } }, selected, finds = { [key] = n }, heldKey, heldModel }
local drops = {} -- [id] = { id, model, items = { { key, n } }, expires, pos, owner?, lost? }
local nextDrop = 0
local DROP_SECONDS = 180

local function now()
	return workspace:GetServerTimeNow()
end

local function state(player)
	local s = inv[player]
	if not s then
		s = { slots = {}, selected = 1, finds = {} }
		inv[player] = s
	end
	return s
end

-- Slot ids -------------------------------------------------------------------------------------------------------
function InventoryService:Capacity(player)
	local raft = rafts:RaftOf(player)
	return raft and rafts:Cargo(raft) or Constants.CARGO_BY_TIER[1]
end

local function validSlot(player, id)
	if type(id) ~= "string" then
		return false
	end
	local kind, n = string.match(id, "^([hb])(%d+)$")
	n = tonumber(n)
	if not kind or not n or n < 1 then
		return false
	end
	if kind == "h" then
		return n <= Constants.HOTBAR
	end
	return n <= InventoryService:Capacity(player)
end
InventoryService.validSlot = validSlot

local function order(player)
	local ids = {}
	for i = 1, Constants.HOTBAR do
		table.insert(ids, "h" .. i)
	end
	for i = 1, InventoryService:Capacity(player) do
		table.insert(ids, "b" .. i)
	end
	return ids
end

-- Tools, weapons, food and finds go to the hotbar first; resources to the bag.
local function hotbarFirst(item)
	return item.kind ~= "resource" and item.kind ~= "artifact"
end

-- Views ----------------------------------------------------------------------------------------------------------
function InventoryService:View(player)
	local s = state(player)
	local slots = {}
	for id, slot in s.slots do
		slots[id] = { key = slot.key, n = slot.n, data = slot.data }
	end
	local finds = 0
	for _, n in s.finds do
		finds += n
	end
	return {
		slots = slots,
		selected = s.selected,
		capacity = self:Capacity(player),
		hotbar = Constants.HOTBAR,
		finds = finds,
	}
end

function InventoryService:Save(player)
	local profile = data:Get(player)
	local s = inv[player]
	if profile and s then
		local slots = {}
		for id, slot in s.slots do
			slots[id] = { key = slot.key, n = slot.n, data = slot.data }
		end
		profile.inventory.slots = slots
		profile.inventory.selected = s.selected
	end
end

function InventoryService:Push(player)
	Net.fire(player, "Inv", self:View(player))
	self:Save(player)
	self.Changed:Fire(player)
end

-- Reads ----------------------------------------------------------------------------------------------------------
function InventoryService:Count(player, key)
	local n = 0
	for _, slot in state(player).slots do
		if slot.key == key then
			n += slot.n
		end
	end
	return n
end

function InventoryService:Has(player, key, n)
	return self:Count(player, key) >= (n or 1)
end

function InventoryService:Slot(player, id)
	local slot = state(player).slots[id]
	return slot, slot and Items.get(slot.key)
end

-- The selected hotbar slot: id, item, slot.
function InventoryService:Selected(player)
	local s = state(player)
	local id = "h" .. s.selected
	local slot = s.slots[id]
	return id, slot and Items.get(slot.key), slot
end

function InventoryService:Contents(player)
	local out = {}
	for id, slot in state(player).slots do
		table.insert(out, { id = id, key = slot.key, n = slot.n, data = slot.data })
	end
	return out
end

function InventoryService:Finds(player)
	return state(player).finds
end

-- Writes ---------------------------------------------------------------------------------------------------------
local function onVoyage(player)
	local voyages = registry.VoyageService
	local plot = rafts:PlotOf(player)
	return voyages ~= nil and plot ~= nil and voyages:State(plot) ~= "docked"
end

-- Give items. What doesn't fit floats off beside you as a bag (unless opts.noDrop). Returns how many fitted.
function InventoryService:Give(player, key, n, source, opts)
	local item = Items.get(key)
	n = math.floor(n or 1)
	if not item or n <= 0 then
		return 0
	end
	opts = opts or {}
	local s = state(player)
	local left = n
	local ids = order(player)
	if not opts.data then
		for _, id in ids do
			local slot = s.slots[id]
			if left > 0 and slot and slot.key == key and not slot.data and slot.n < item.stack then
				local add = math.min(item.stack - slot.n, left)
				slot.n += add
				left -= add
			end
		end
	end
	local function fill(prefix)
		for _, id in ids do
			if left <= 0 then
				return
			end
			if string.sub(id, 1, 1) == prefix and not s.slots[id] then
				local add = opts.data and 1 or math.min(item.stack, left)
				s.slots[id] = { key = key, n = add, data = opts.data }
				left -= add
			end
		end
	end
	if hotbarFirst(item) then
		fill("h")
		fill("b")
	else
		fill("b")
		fill("h")
	end
	local fitted = n - left
	if left > 0 and not opts.noDrop then
		Net.fire(player, "Toast", "🎒 Your bag is full! The rest floats beside you.", "bad")
		self:SpawnDrop(self:FeetOf(player), { { key = key, n = left, data = opts.data } }, { owner = player })
	end
	if
		fitted > 0
		and source ~= "home"
		and source ~= "demolish"
		and item.kind ~= "tool"
		and item.kind ~= "weapon"
		and onVoyage(player)
	then
		s.finds[key] = (s.finds[key] or 0) + fitted
	end
	self:Push(player)
	self:_refreshHeld(player)
	self.Gained:Fire(player, key, fitted, source, opts.data)
	return fitted
end

-- Remove items (all or nothing unless opts.partial). Takes from the bag first.
function InventoryService:Take(player, key, n, opts)
	n = math.floor(n or 1)
	local have = self:Count(player, key)
	if have < n and not (opts and opts.partial) then
		return false, have
	end
	local s = state(player)
	local left = math.min(n, have)
	local ids = order(player)
	for i = #ids, 1, -1 do
		local id = ids[i]
		local slot = s.slots[id]
		if left > 0 and slot and slot.key == key then
			local take = math.min(slot.n, left)
			slot.n -= take
			left -= take
			if slot.n <= 0 then
				s.slots[id] = nil
			end
		end
	end
	self:Push(player)
	self:_refreshHeld(player)
	return true, math.min(n, have)
end

-- Use up `n` from one slot.
function InventoryService:Consume(player, id, n)
	local s = state(player)
	local slot = s.slots[id]
	n = n or 1
	if not slot or slot.n < n then
		return false
	end
	slot.n -= n
	if slot.n <= 0 then
		s.slots[id] = nil
	end
	self:Push(player)
	self:_refreshHeld(player)
	return true
end

function InventoryService:Select(player, index)
	index = math.floor(tonumber(index) or 0)
	if index < 1 or index > Constants.HOTBAR then
		return false
	end
	local s = state(player)
	if s.selected == index then
		return true
	end
	s.selected = index
	self:Push(player)
	self:_refreshHeld(player)
	local id, item = self:Selected(player)
	self.SlotSelected:Fire(player, id, item)
	return true
end

-- Move or swap two slots (stacks of the same item merge).
function InventoryService:Move(player, from, to)
	if from == to or not validSlot(player, from) or not validSlot(player, to) then
		return false
	end
	local s = state(player)
	local a, b = s.slots[from], s.slots[to]
	if not a then
		return false
	end
	local itemA = Items.get(a.key)
	if b and b.key == a.key and itemA.stack > 1 and not a.data and not b.data then
		local add = math.min(itemA.stack - b.n, a.n)
		b.n += add
		a.n -= add
		if a.n <= 0 then
			s.slots[from] = nil
		end
	else
		s.slots[from], s.slots[to] = b, a
	end
	self:Push(player)
	self:_refreshHeld(player)
	return true
end

-- The voyage's finds: half float off when you go down away from your raft (returns what was taken).
function InventoryService:LoseFinds(player)
	local s = state(player)
	local lost = {}
	for key, n in s.finds do
		local have = self:Count(player, key)
		local take = math.min(have, math.floor(n * Constants.DEATH_LOSS))
		if take > 0 then
			self:Take(player, key, take)
			table.insert(lost, { key = key, n = take })
			s.finds[key] = n - take
		end
	end
	return lost
end

function InventoryService:ClearFinds(player)
	state(player).finds = {}
	self:Push(player)
end

-- Using things -----------------------------------------------------------------------------------------------------
function InventoryService:Use(player, id)
	local slot, item = self:Slot(player, id)
	if not slot or not item then
		return false
	end
	local players = registry.PlayerService
	if item.food then
		if not players:IsAlive(player) then
			return false
		end
		self:Consume(player, id, 1)
		players:Heal(player, item.food.heal, "food")
		if item.food.buff then
			players:Buff(player, item.food.buff.key, item.food.buff.seconds)
		end
		Net.fire(player, "Sfx", "eat")
		local root = players:Root(player)
		if root then
			Net.fire(
				player,
				"Popup",
				root.Position + Vector3.new(0, 4, 0),
				`{item.icon} +{item.food.heal}`,
				Color3.fromRGB(140, 230, 140)
			)
		end
		self.Ate:Fire(player, item)
		self.Used:Fire(player, item, slot.data)
		return true
	elseif item.kind == "chart" then
		local voyages = registry.VoyageService
		local dest = slot.data and slot.data.dest
		if not dest or not Voyages.get(dest) then
			dest = voyages:UnknownDestination(player, item.key == "bottle" and "bottle" or "crate")
		end
		self:Consume(player, id, 1)
		if dest then
			voyages:Reveal(player, dest, item.key)
		else
			Net.fire(player, "Toast", "🗺️ You already know every place on this chart.", "info")
		end
		if item.key == "bottle" and slot.data and slot.data.note then
			Net.fire(player, "Alert", `📜 "{slot.data.note}"`, Color3.fromRGB(240, 220, 160), 5)
		end
		self.Used:Fire(player, item, slot.data)
		return true
	elseif item.kind == "blueprint" then
		local d = slot.data
		if not d or not d.key then
			self:Consume(player, id, 1)
			return false
		end
		local learned = registry.ProgressService:LearnBlueprint(player, d.kind, d.key, "blueprint")
		self:Consume(player, id, 1)
		if not learned then
			Net.fire(player, "Toast", "📜 You already knew that one. The paper's good for scrap.", "info")
			self:Give(player, "scrap", 2, "blueprint")
		end
		self.Used:Fire(player, item, d)
		return true
	elseif item.key == "supply_crate" then
		local loot = registry.LootService
		self:Consume(player, id, 1)
		loot:OpenCrate(player, slot.data)
		self.Used:Fire(player, item, slot.data)
		return true
	elseif item.kind == "artifact" then
		Net.fire(player, "Toast", `{item.icon} {item.name}: {item.desc} Feed it to a Research Station.`, "info")
		return false
	end
	Net.fire(player, "Toast", `{item.icon} {item.name}: {item.desc}`, "info")
	return false
end

-- Drops -------------------------------------------------------------------------------------------------------------
function InventoryService:FeetOf(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		return root.Position + root.CFrame.LookVector * 3
	end
	return Vector3.new(0, Constants.DECK_Y, 0)
end

-- A floating bag: cast at it from the raft, or take it when you stand beside it.
function InventoryService:SpawnDrop(pos, items, opts)
	opts = opts or {}
	nextDrop += 1
	local id = nextDrop
	local folder = workspace:FindFirstChild("Drops") or workspace
	local at = Vector3.new(pos.X, math.max(Constants.WATER_LEVEL + 0.4, math.min(pos.Y, Constants.DECK_Y + 0.4)), pos.Z)
	local model = OceanModels.debris("lost_bag", CFrame.new(at), folder)
	model.Name = opts.lost and "LostBag" or "Bag"
	model:SetAttribute("DropId", id)
	model:SetAttribute("Lost", opts.lost == true)
	if opts.owner then
		model:SetAttribute("Owner", opts.owner.UserId)
	end
	local part = model:FindFirstChildWhichIsA("BasePart")
	if part then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Prompt"
		prompt.ActionText = "Take"
		prompt.ObjectText = opts.lost and "Lost bag" or "Bag"
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("Kind", "drop")
		prompt:SetAttribute("DropId", id)
		prompt.Parent = part
	end
	local d = {
		id = id,
		model = model,
		items = items,
		pos = at,
		expires = now() + (opts.seconds or DROP_SECONDS),
		owner = opts.owner,
		lost = opts.lost,
	}
	drops[id] = d
	return d
end

function InventoryService:Drop(player, id, n)
	local slot, item = self:Slot(player, id)
	if not slot or not item then
		return false
	end
	n = math.clamp(math.floor(tonumber(n) or slot.n), 1, slot.n)
	local items = { { key = slot.key, n = n, data = slot.data } }
	self:Consume(player, id, n)
	self:SpawnDrop(self:FeetOf(player), items, { owner = player })
	Net.fire(player, "Sfx", "splash")
	self.Dropped:Fire(player, slot.key, n)
	return true
end

function InventoryService:DropAt(id)
	return drops[id]
end

function InventoryService:Drops()
	return drops
end

-- Take a bag (from the deck, or reeled in by OceanService).
function InventoryService:Pickup(player, id)
	local d = drops[id]
	if not d then
		return false
	end
	drops[id] = nil
	if d.model then
		d.model:Destroy()
	end
	for _, it in d.items do
		self:Give(player, it.key, it.n, d.lost and "lost_bag" or "drop", { data = it.data })
	end
	Net.fire(player, "Sfx", "pickup")
	if d.lost then
		Net.fire(player, "Toast", "🎒 You got your things back!", "good")
		local profile = data:Get(player)
		if profile then
			profile.stats.bagsFound += 1
		end
	end
	self.PickedUp:Fire(player, d)
	return true
end

function InventoryService:ClearDrops()
	for id, d in drops do
		drops[id] = nil
		if d.model then
			d.model:Destroy()
		end
	end
end

-- The hand ----------------------------------------------------------------------------------------------------------
function InventoryService:_refreshHeld(player)
	local c = player.Character
	if not c then
		return
	end
	local s = state(player)
	local _, item = self:Selected(player)
	local key = item and item.key or nil
	if s.heldKey == key and s.heldModel and s.heldModel.Parent then
		return
	end
	if s.heldModel then
		s.heldModel:Destroy()
		s.heldModel = nil
	end
	s.heldKey = key
	if not item or item.kind == "resource" or item.kind == "artifact" or item.kind == "fish" then
		c:SetAttribute("Held", key or "")
		return
	end
	local hand = c:FindFirstChild("RightHand") or c:FindFirstChild("Right Arm")
	if not hand then
		return
	end
	local model, grip = ItemModels.held(item, c)
	model.Name = "Held"
	local weld = Instance.new("Weld")
	weld.Part0 = hand
	weld.Part1 = grip
	weld.C0 = ItemModels.holdCFrame(item, hand)
	weld.Parent = grip
	s.heldModel = model
	c:SetAttribute("Held", key)
end

function InventoryService:_tick()
	local t = now()
	for id, d in drops do
		if t > d.expires then
			drops[id] = nil
			if d.model then
				d.model:Destroy()
			end
		end
	end
end

-- Boot --------------------------------------------------------------------------------------------------------------
function InventoryService:StartingKit(player)
	self:Give(player, "fishing_rod", 1, "start")
	self:Select(player, 1)
end

function InventoryService:Init(reg)
	registry = reg
	data = reg.PlayerDataService
	rafts = reg.RaftService
	Net.on("Select", function(player, index)
		self:Select(player, index)
	end)
	Net.on("Move", function(player, from, to)
		self:Move(player, from, to)
	end)
	Net.on("Use", function(player, id)
		if validSlot(player, id) then
			self:Use(player, id)
		end
	end)
	Net.on("Drop", function(player, id, n)
		if validSlot(player, id) then
			self:Drop(player, id, n)
		end
	end)
	pcall(function()
		ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
			if prompt:GetAttribute("Kind") == "drop" then
				self:Pickup(player, prompt:GetAttribute("DropId"))
			end
		end)
	end)
	-- more cargo when the raft grows; and slots past the new cargo keep their items until they're moved
	rafts.Built:Connect(function(player)
		self:Push(player)
	end)
	rafts.TierChanged:Connect(function(player)
		if player and player.Parent then
			self:Push(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		task.defer(function()
			inv[player] = nil
		end)
	end)
end

function InventoryService:OnPlayerReady(player, profile)
	local s = state(player)
	s.slots = {}
	local saved = profile.inventory and profile.inventory.slots
	local any = false
	if type(saved) == "table" then
		for id, slot in saved do
			if type(slot) == "table" and Items.get(slot.key) and validSlot(player, id) then
				s.slots[id] = { key = slot.key, n = math.max(1, math.floor(slot.n or 1)), data = slot.data }
				any = true
			end
		end
	end
	s.selected = math.clamp(tonumber(profile.inventory and profile.inventory.selected) or 1, 1, Constants.HOTBAR)
	player.CharacterAdded:Connect(function()
		local st = state(player)
		st.heldKey = nil
		st.heldModel = nil
		task.defer(self._refreshHeld, self, player)
	end)
	if not any then
		self:StartingKit(player)
	end
	data:WhenClientReady(player, function()
		self:Push(player)
	end)
end

function InventoryService:OnPlayerLeaving(player)
	self:Save(player)
end

function InventoryService:Start()
	while true do
		task.wait(2)
		self:_tick()
	end
end

return InventoryService
