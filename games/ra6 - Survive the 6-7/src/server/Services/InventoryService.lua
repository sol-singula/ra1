--[[
Inventory, hotbar and items on the ground (master plan §6). The server owns every item: the client asks to move,
drop or use, and the server checks and answers (§14: validate all inventory transactions).

  slots      h1..h6 the hotbar (§6: six slots, any item in any slot), b1..bN the backpack (12, more with a
             pack), armor / pack / charm the equipment
  stacks     resources and consumables stack (Data/Items: stack)
  rules      (§6 "Inventory rules"; told to players in the inventory and the guide)
             * everything you carry belongs to this run: it's gone when the run ends
             * go down and bleed out: your hotbar and backpack drop where you fell as a lost pack anyone can take
               (your equipment stays on you)
             * leave the server mid-run: everything you carried is left by the campfire for your team
             * your permanent collection (every item you've ever found) is saved the moment you find it
             * drop anything for a teammate (it stays on the ground for 5 minutes)
  held       the selected hotbar item is in your character's hand (a light lights up around you)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local ItemModels = require(ReplicatedStorage.Shared.World.ItemModels)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Kit = require(ReplicatedStorage.Shared.World.Kit)
local MapLayout = require(ReplicatedStorage.Shared.World.MapLayout)
local Net = require(ReplicatedStorage.Shared.Net)
local Progression = require(ReplicatedStorage.Shared.Data.Progression)
local Signal = require(ReplicatedStorage.Shared.Signal)

local InventoryService = {
	Name = "InventoryService",
	Dependencies = { "PlayerDataService", "RunService" },
	Changed = Signal.new("InventoryService.Changed"), -- (player)
	Gained = Signal.new("InventoryService.Gained"), -- (player, key, n, source)
	SlotSelected = Signal.new("InventoryService.SlotSelected"), -- (player, slotId, item?)
	Dropped = Signal.new("InventoryService.Dropped"), -- (player, key, n)
	Equipped = Signal.new("InventoryService.Equipped"), -- (player, item)
	PickedUp = Signal.new("InventoryService.PickedUp"), -- (player, drop)
}

local data, runs
local inv = {} -- [player] = { slots = { [id] = { key, n, fuel? } }, selected = 1, gear = cache }
local drops = {} -- [id] = { id, model, items = { { key, n } }, expires, lost, owner }
local nextDrop = 0
local EQUIP = { armor = true, pack = true, charm = true }

local function now()
	return workspace:GetServerTimeNow()
end

local function state(player)
	local s = inv[player]
	if not s then
		s = { slots = {}, selected = 1 }
		inv[player] = s
	end
	return s
end

-- Slot ids -------------------------------------------------------------------------------------------------------
function InventoryService:Capacity(player)
	local s = state(player)
	local pack = s.slots.pack and Items.get(s.slots.pack.key)
	return Constants.BACKPACK + (pack and pack.slots or 0)
end

local function validSlot(player, id)
	if type(id) ~= "string" then
		return false
	end
	if EQUIP[id] then
		return true
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

-- Views ----------------------------------------------------------------------------------------------------------
function InventoryService:View(player)
	local s = state(player)
	local slots = {}
	for id, slot in s.slots do
		slots[id] = { key = slot.key, n = slot.n, fuel = slot.fuel and math.floor(slot.fuel) or nil }
	end
	return { slots = slots, selected = s.selected, capacity = self:Capacity(player), hotbar = Constants.HOTBAR }
end

function InventoryService:Push(player)
	local s = state(player)
	s.gear = nil
	Net.fire(player, "Inv", self:View(player))
	self.Changed:Fire(player)
end

-- Equipment stats, cached until the inventory changes.
function InventoryService:Gear(player)
	local s = state(player)
	if s.gear then
		return s.gear
	end
	local g = {
		armor = 0,
		speed = 1,
		staminaMax = 1,
		staminaRegen = 1,
		sprintCost = 1,
		dodgeCd = 1,
		luck = 1,
		goggles = false,
		kermyTell = 1,
	}
	for _, id in { "armor", "pack", "charm" } do
		local slot = s.slots[id]
		local item = slot and Items.get(slot.key)
		if item then
			g.armor += item.armor or 0
			g.speed *= item.speed or 1
			g.staminaMax *= item.staminaMax or 1
			g.staminaRegen *= item.staminaRegen or 1
			g.sprintCost *= item.sprintCost or 1
			g.dodgeCd *= item.dodgeCd or 1
			g.luck *= item.luck or 1
			g.goggles = g.goggles or item.goggles == true
			g.kermyTell *= item.kermyTell or 1
		end
	end
	s.gear = g
	return g
end

-- Queries ----------------------------------------------------------------------------------------------------------
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
	return state(player).slots[id]
end

-- The held hotbar slot: id, item definition, slot (or nil when that slot is empty).
function InventoryService:Selected(player)
	local s = state(player)
	local id = "h" .. s.selected
	local slot = s.slots[id]
	return id, slot and Items.get(slot.key), slot
end

function InventoryService:Contents(player)
	return table.clone(state(player).slots)
end

-- Changing items ---------------------------------------------------------------------------------------------------
-- Add items: onto existing stacks, then empty slots (things you hold go to the hotbar first). Whatever doesn't fit
-- is dropped at your feet (unless opts.noDrop). Returns how many fitted.
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
	for _, id in ids do
		local slot = s.slots[id]
		if left > 0 and slot and slot.key == key and slot.n < item.stack then
			local add = math.min(item.stack - slot.n, left)
			slot.n += add
			left -= add
		end
	end
	local function fill(prefix)
		for _, id in ids do
			if left <= 0 then
				return
			end
			if string.sub(id, 1, 1) == prefix and not s.slots[id] then
				local add = math.min(item.stack, left)
				s.slots[id] = { key = key, n = add, fuel = item.burn }
				left -= add
			end
		end
	end
	if Items.goesToHotbar(item) then
		fill("h")
		fill("b")
	else
		fill("b")
		fill("h")
	end
	local fitted = n - left
	if left > 0 and not opts.noDrop then
		self:SpawnDrop(self:FeetOf(player), { { key = key, n = left } })
	end
	self:Push(player)
	self:_refreshHeld(player)
	self.Gained:Fire(player, key, n, source)
	return fitted
end

-- Remove items (all or nothing unless opts.partial). Takes from the backpack first.
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

-- Use up `n` from one slot (eating, throwing, setting a trap).
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

-- Move or swap two slots (stacks of the same item merge). Equipment slots take only their own kind.
function InventoryService:Move(player, from, to)
	if from == to or not validSlot(player, from) or not validSlot(player, to) then
		return false
	end
	local s = state(player)
	local a, b = s.slots[from], s.slots[to]
	if not a then
		return false
	end
	local itemA, itemB = Items.get(a.key), b and Items.get(b.key)
	if EQUIP[to] and itemA.kind ~= to then
		Net.fire(player, "Toast", `That doesn't go in the {to} slot.`, "bad")
		return false
	end
	if EQUIP[from] and b and itemB.kind ~= from then
		return false
	end
	-- a pack change must leave every backpack item inside the new capacity
	if from == "pack" or to == "pack" then
		local packItem = to == "pack" and itemA or itemB
		local newCap = Constants.BACKPACK + (packItem and packItem.slots or 0)
		local after = table.clone(s.slots)
		after[from], after[to] = b, a
		for sid in after do
			local bn = tonumber(string.match(sid, "^b(%d+)$"))
			if bn and bn > newCap then
				Net.fire(player, "Toast", "Empty the pack's extra slots first.", "bad")
				return false
			end
		end
	end
	if b and b.key == a.key and itemA.stack > 1 then
		local add = math.min(itemA.stack - b.n, a.n)
		b.n += add
		a.n -= add
		if a.n <= 0 then
			s.slots[from] = nil
		end
	else
		s.slots[from], s.slots[to] = b, a
	end
	if EQUIP[to] or EQUIP[from] then
		self.Equipped:Fire(player, EQUIP[to] and itemA or itemB)
	end
	self:Push(player)
	self:_refreshHeld(player)
	return true
end

-- Put a piece of equipment on (from any slot), or take it off into the backpack.
function InventoryService:ToggleEquip(player, id)
	local s = state(player)
	local slot = s.slots[id]
	if not slot then
		return false
	end
	local item = Items.get(slot.key)
	if EQUIP[id] then
		for _, bid in order(player) do
			if string.sub(bid, 1, 1) == "b" and not s.slots[bid] then
				return self:Move(player, id, bid)
			end
		end
		Net.fire(player, "Toast", "Your backpack is full.", "bad")
		return false
	end
	if not Items.isEquipment(item) then
		return false
	end
	return self:Move(player, id, item.kind)
end

-- Ground drops -----------------------------------------------------------------------------------------------------
function InventoryService:FeetOf(player)
	local c = player.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	if hrp then
		local pos = hrp.Position + hrp.CFrame.LookVector * 3
		return Vector3.new(pos.X, MapLayout.groundY(pos.X, pos.Z), pos.Z)
	end
	return MapLayout.CAMP_PROPS.fire + Vector3.new(6, 0, 0)
end

-- Items on the ground (one model per drop; a lost pack shows as a backpack with its owner's name).
function InventoryService:SpawnDrop(pos, items, opts)
	opts = opts or {}
	local list = {}
	for _, it in items do
		if Items.get(it.key) and (it.n or 0) > 0 then
			table.insert(list, { key = it.key, n = it.n, fuel = it.fuel })
		end
	end
	if #list == 0 then
		return nil
	end
	nextDrop += 1
	local id = nextDrop
	local parent = workspace:FindFirstChild("Drops") or workspace
	local model, grip
	if opts.lost then
		model = Kit.model("LostPack", parent)
		grip = Kit.box(
			model,
			"Pack",
			CFrame.new(pos + Vector3.new(0, 0.9, 0)),
			Vector3.new(1.8, 1.8, 1.2),
			Kit.C.canvasGreen,
			Kit.M.Fabric,
			{
				CanCollide = false,
			}
		)
		Kit.box(
			model,
			"Beam",
			CFrame.new(pos + Vector3.new(0, 10, 0)),
			Vector3.new(0.6, 20, 0.6),
			Kit.C.blueprint,
			Kit.M.Neon,
			{
				CanCollide = false,
				CanQuery = false,
				CastShadow = false,
				Transparency = 0.5,
			}
		)
		local bb = Instance.new("BillboardGui")
		bb.Name = "Label"
		bb.Size = UDim2.fromOffset(200, 30)
		bb.StudsOffset = Vector3.new(0, 3, 0)
		bb.MaxDistance = 120
		bb.AlwaysOnTop = true
		bb.Parent = grip
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Text = `🎒 {opts.owner or "Someone"}'s pack`
		t.TextColor3 = Color3.new(1, 1, 1)
		t.TextStrokeTransparency = 0.3
		t.TextScaled = true
		t.Font = Enum.Font.FredokaOne
		t.Parent = bb
	else
		local first = Items.get(list[1].key)
		model, grip = ItemModels.dropped(first, CFrame.new(pos + Vector3.new(0, 0.6, 0)), parent)
	end
	model.Name = opts.lost and "LostPack" or ("Drop_" .. list[1].key)
	model:SetAttribute("DropId", id)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Pickup"
	prompt.ActionText = opts.lost and "Take items" or "Pick up"
	local first = Items.get(list[1].key)
	prompt.ObjectText = opts.lost and `{opts.owner or "Someone"}'s pack`
		or (#list > 1 and `{first.name} +{#list - 1}` or `{first.name}{list[1].n > 1 and (" x" .. list[1].n) or ""}`)
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Constants.PICKUP_RANGE
	prompt.RequiresLineOfSight = false
	prompt.Parent = grip
	local d = {
		id = id,
		model = model,
		pos = pos,
		items = list,
		lost = opts.lost == true,
		owner = opts.owner,
		expires = now() + (opts.lost and Constants.LOST_PACK_SECONDS or Constants.DROP_SECONDS),
	}
	drops[id] = d
	prompt.Triggered:Connect(function(player)
		self:Pickup(player, id)
	end)
	return d
end

function InventoryService:Pickup(player, id)
	local d = drops[id]
	if not d or not runs:InRun(player) then
		return false
	end
	local remaining = {}
	for _, it in d.items do
		local got = self:Give(player, it.key, it.n, d.lost and "pack" or "ground", { noDrop = true })
		if got < it.n then
			table.insert(remaining, { key = it.key, n = it.n - got })
		end
	end
	Net.fire(player, "Sfx", "pickup")
	self.PickedUp:Fire(player, d)
	if #remaining == 0 then
		drops[id] = nil
		d.model:Destroy()
	else
		d.items = remaining
		Net.fire(player, "Toast", "Your backpack is full.", "bad")
	end
	return true
end

-- Drop a slot (all of it, or n) at your feet.
function InventoryService:Drop(player, id, n)
	if not validSlot(player, id) or not runs:InRun(player) then
		return false
	end
	local s = state(player)
	local slot = s.slots[id]
	if not slot then
		return false
	end
	n = math.clamp(math.floor(tonumber(n) or slot.n), 1, slot.n)
	local key, fuel = slot.key, slot.fuel
	slot.n -= n
	if slot.n <= 0 then
		s.slots[id] = nil
	end
	self:SpawnDrop(self:FeetOf(player), { { key = key, n = n, fuel = fuel } })
	self:Push(player)
	self:_refreshHeld(player)
	self.Dropped:Fire(player, key, n)
	return true
end

-- Everything in the hotbar and backpack, dropped as one lost pack (equipment stays on).
function InventoryService:DropAll(player, pos, label)
	local s = state(player)
	local items = {}
	for id, slot in s.slots do
		if not EQUIP[id] then
			table.insert(items, { key = slot.key, n = slot.n, fuel = slot.fuel })
			s.slots[id] = nil
		end
	end
	if #items > 0 then
		self:SpawnDrop(pos, items, { lost = true, owner = label or player.DisplayName })
	end
	self:Push(player)
	self:_refreshHeld(player)
	return #items
end

function InventoryService:Clear(player)
	local s = state(player)
	s.slots = {}
	s.selected = 1
	self:Push(player)
	self:_refreshHeld(player)
end

function InventoryService:ClearDrops()
	for id, d in drops do
		drops[id] = nil
		if d.model then
			d.model:Destroy()
		end
	end
end

function InventoryService:Drops()
	return drops
end

-- Kits ---------------------------------------------------------------------------------------------------------------
function InventoryService:GiveKit(player, items)
	for _, it in items do
		self:Give(player, it[1], it[2], "kit", { noDrop = true })
	end
end

-- The kit you picked (if your level allows it), plus perk extras.
function InventoryService:StartingKit(player)
	local profile = data:Get(player)
	local level = profile and Formulas.level(profile.xp) or 1
	local kit = profile and Progression.kitByKey[profile.kit]
	if not kit or kit.level > level then
		kit = Progression.kitByKey.woodsman
	end
	local items = table.clone(kit.items)
	if profile and table.find(profile.perks or {}, "trapper") then
		table.insert(items, { "snare", 1 })
	end
	return items
end

-- The thing in your hand ----------------------------------------------------------------------------------------------
function InventoryService:_refreshHeld(player)
	local c = player.Character
	if not c then
		return
	end
	local s = state(player)
	local _, item, slot = self:Selected(player)
	local key = item and item.key or nil
	if s.heldKey == key and s.heldModel and s.heldModel.Parent then
		return
	end
	if s.heldModel then
		s.heldModel:Destroy()
		s.heldModel = nil
	end
	s.heldKey = key
	if not item or item.kind == "resource" or item.kind == "armor" or item.kind == "pack" or item.kind == "charm" then
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
	_ = slot
end

-- Torches burn while you hold them.
function InventoryService:_burn(dt)
	for player, s in inv do
		local id, item, slot = self:Selected(player)
		if item and item.burn and slot then
			slot.fuel = (slot.fuel or item.burn) - dt
			if slot.fuel <= 0 then
				slot.n -= 1
				slot.fuel = item.burn
				if slot.n <= 0 then
					s.slots[id] = nil
				end
				Net.fire(player, "Toast", "🔥 Your torch burned out.", "info")
				self:Push(player)
				self:_refreshHeld(player)
			end
		end
	end
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

function InventoryService:Init(registry)
	data = registry.PlayerDataService
	runs = registry.RunService
	Net.on("Select", function(player, index)
		self:Select(player, index)
	end)
	Net.on("Move", function(player, from, to)
		if runs:InRun(player) then
			if to == "equip" then
				self:ToggleEquip(player, from)
			else
				self:Move(player, from, to)
			end
		end
	end)
	Net.on("Drop", function(player, id, n)
		self:Drop(player, id, n)
	end)
	runs.Reset:Connect(function()
		for player in inv do
			inv[player] = { slots = {}, selected = 1 }
			if player.Parent then
				self:Push(player)
				self:_refreshHeld(player)
			end
		end
		self:ClearDrops()
	end)
	runs.Joined:Connect(function(player, run)
		local s = state(player)
		if next(s.slots) == nil then
			-- back in a run you dropped out of: your things are in your pack by the fire, so just the basics
			local entry = run and run.roster[player.UserId]
			local rejoin = entry and (entry.rejoins or 0) > 0
			self:GiveKit(player, rejoin and Constants.RESPAWN_KIT or self:StartingKit(player))
			self:Select(player, 1)
		end
		self:Push(player)
	end)
	-- (after OnPlayerLeaving, which still needs the inventory: it leaves your things by the fire)
	Players.PlayerRemoving:Connect(function(player)
		task.defer(function()
			inv[player] = nil
		end)
	end)
end

function InventoryService:OnPlayerReady(player)
	state(player)
	player.CharacterAdded:Connect(function()
		local s = state(player)
		s.heldKey = nil
		s.heldModel = nil
		task.defer(self._refreshHeld, self, player)
	end)
	data:WhenClientReady(player, function()
		self:Push(player)
	end)
end

-- Leaving mid-run: your things wait by the campfire for the team.
function InventoryService:OnPlayerLeaving(player)
	if runs:InRun(player) then
		local spot = MapLayout.polar(math.random(0, 359), 7)
		self:DropAll(player, Vector3.new(spot.X, MapLayout.CAMP.y, spot.Z), player.DisplayName)
	end
	inv[player] = nil
end

function InventoryService:Start()
	while true do
		task.wait(1)
		self:_burn(1)
	end
end

return InventoryService
