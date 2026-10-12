-- The hotbar: real Roblox tools in each player's backpack, so the standard hotbar (keys 1-3, a click or a tap to
-- use) works on every device.
--   1. Bonk Bat (the Mega Hammer with the Mega Bonk pass): click to bonk. In your hand when you spawn.
--   2. Speed Potion: drink one to run faster for a while. New players get a few; more come in a product.
--   3. Dragon Wings (Dragon Wings pass): wings on your back. Click to jump high, then glide. ToolController does
--      the flying, because your character's physics run on your own device.
-- Also caps how far players can zoom the camera out.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local ToolService = {
	Name = "ToolService",
	Dependencies = { "PlayerDataService", "EconomyService", "CombatService" },
	PotionsRequested = Signal.new("ToolService.PotionsRequested"), -- (player) out of potions: offer the product
}

local data, economy, combat

local WOOD = Color3.fromRGB(150, 100, 60)
local GOLD = Color3.fromRGB(255, 205, 50)
local IRON = Color3.fromRGB(120, 125, 140)
local WING = Color3.fromRGB(200, 45, 45)

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		p[k] = v
	end
	return p
end

-- Attach extra pieces to a tool's handle (offsets are from the handle).
local function attach(handle, pieces)
	for _, spec in pieces do
		local p = part(spec.props)
		p.CFrame = handle.CFrame * spec.at
		p.Parent = handle.Parent
		local w = Instance.new("WeldConstraint")
		w.Part0 = handle
		w.Part1 = p
		w.Parent = p
	end
end

local SLOTS = { bonk = 1, potion = 2, wings = 3 } -- hotbar order (HotbarController)

local function newTool(name, kind, tip, icon)
	local tool = Instance.new("Tool")
	tool.Name = name
	tool.ToolTip = tip
	tool.CanBeDropped = false
	tool.TextureId = icon
	tool:SetAttribute("Kind", kind)
	tool:SetAttribute("Slot", SLOTS[kind])
	return tool
end

local function bonker(mega)
	local tool = newTool(
		mega and "Mega Hammer" or "Bonk Bat",
		"bonk",
		"Click to bonk thieves!",
		mega and Constants.TOOL_ICONS.hammer or Constants.TOOL_ICONS.bat
	)
	local handle = part({
		Name = "Handle",
		Size = Vector3.new(0.35, 2.4, 0.35),
		Color = WOOD,
		Material = Enum.Material.Wood,
		Parent = tool,
	})
	if mega then
		attach(handle, {
			{
				props = {
					Name = "HammerHead",
					Size = Vector3.new(1.9, 1.1, 1.1),
					Color = IRON,
					Material = Enum.Material.Metal,
				},
				at = CFrame.new(0, 1.55, 0),
			},
			{
				props = {
					Name = "BandL",
					Size = Vector3.new(0.18, 1.2, 1.2),
					Color = GOLD,
					Material = Enum.Material.Metal,
				},
				at = CFrame.new(-0.6, 1.55, 0),
			},
			{
				props = {
					Name = "BandR",
					Size = Vector3.new(0.18, 1.2, 1.2),
					Color = GOLD,
					Material = Enum.Material.Metal,
				},
				at = CFrame.new(0.6, 1.55, 0),
			},
		})
	else
		attach(handle, {
			{
				props = { Name = "BatHead", Size = Vector3.new(0.75, 1.4, 0.75), Color = GOLD },
				at = CFrame.new(0, 1.7, 0),
			},
			{
				props = { Name = "Grip", Size = Vector3.new(0.42, 0.7, 0.42), Color = Color3.fromRGB(40, 40, 50) },
				at = CFrame.new(0, -0.8, 0),
			},
		})
	end
	tool.Grip = CFrame.new(0, -0.8, 0)
	return tool
end

local function potion()
	local tool = newTool("Speed Potion", "potion", "Drink to run faster for 30 seconds!", Constants.TOOL_ICONS.potion)
	local handle = part({
		Name = "Handle",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.9, 0.9, 0.9),
		Color = Color3.fromRGB(70, 220, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.15,
		Parent = tool,
	})
	attach(handle, {
		{
			props = {
				Name = "Neck",
				Size = Vector3.new(0.32, 0.45, 0.32),
				Color = Color3.fromRGB(200, 240, 255),
				Material = Enum.Material.Glass,
				Transparency = 0.3,
			},
			at = CFrame.new(0, 0.6, 0),
		},
		{
			props = { Name = "Cork", Size = Vector3.new(0.36, 0.2, 0.36), Color = WOOD, Material = Enum.Material.Wood },
			at = CFrame.new(0, 0.9, 0),
		},
		{
			props = {
				Name = "Glow",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.6, 0.6, 0.6),
				Color = Color3.fromRGB(120, 255, 255),
				Material = Enum.Material.Neon,
			},
			at = CFrame.new(),
		},
	})
	tool.Grip = CFrame.new(0, 0.1, 0)
	return tool
end

local function wings()
	local tool = newTool("Dragon Wings", "wings", "Click to jump high, then glide!", Constants.TOOL_ICONS.wings)
	tool.RequiresHandle = false
	return tool
end

-- Wings on the character's back: per side, a hidden root on a Weld (ToolController flaps it by changing C0) and
-- three membrane panels fanned out from it, with a gold bone along the top.
function ToolService.attachWings(character)
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not torso or character:FindFirstChild("WingsModel") then
		return
	end
	local model = Instance.new("Model")
	model.Name = "WingsModel"
	for _, side in { -1, 1 } do
		local root =
			part({ Name = side < 0 and "WingL" or "WingR", Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1 })
		root:SetAttribute("Side", side)
		root.CFrame = torso.CFrame * ToolService.wingC0(side, 0)
		root.Parent = model
		local joint = Instance.new("Weld")
		joint.Name = "Joint"
		joint.Part0 = torso
		joint.Part1 = root
		joint.C0 = ToolService.wingC0(side, 0)
		joint.Parent = root
		local panels = {
			{ len = 3.4, angle = 28, color = WING, h = 0.22 },
			{ len = 3.0, angle = 4, color = WING:Lerp(Color3.new(0, 0, 0), 0.15), h = 0.9 },
			{ len = 2.2, angle = -22, color = WING:Lerp(Color3.new(0, 0, 0), 0.3), h = 0.9 },
		}
		for i, s in panels do
			local p = part({
				Name = i == 1 and "Bone" or "Membrane",
				Size = Vector3.new(s.len, s.h, 0.12),
				Color = i == 1 and GOLD or s.color,
				Material = i == 1 and Enum.Material.Metal or Enum.Material.Fabric,
			})
			p.CFrame = root.CFrame * CFrame.Angles(0, 0, math.rad(s.angle) * side) * CFrame.new(side * s.len / 2, 0, 0)
			p.Parent = model
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = p
			w.Parent = p
		end
	end
	model.Parent = character
end

-- Where a wing's root sits on the torso, with the wing swung back by `flap` radians.
function ToolService.wingC0(side, flap)
	return CFrame.new(side * 0.3, 0.5, 0.65) * CFrame.Angles(0, side * (math.rad(-18) + flap), side * math.rad(12))
end

function ToolService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	combat = registry.CombatService
	economy.PassesChanged:Connect(function(player)
		self:Give(player)
	end)
	-- every swing (a click with the bat, or the Q key) shows in the bonk tool: switch to it and swing it
	combat.Swung:Connect(function(player)
		local tool = self:Equip(player, "bonk")
		if tool then
			local anim = Instance.new("StringValue")
			anim.Name = "toolanim" -- the default Animate script plays its slash animation for this
			anim.Value = "Slash"
			anim.Parent = tool
			task.delay(1, function()
				anim:Destroy()
			end)
		end
	end)
end

function ToolService:OnPlayerReady(player)
	player.CameraMaxZoomDistance = Constants.CAMERA_MAX_ZOOM
	player.CharacterAdded:Connect(function()
		task.wait()
		self:Give(player)
	end)
	self:Give(player)
end

function ToolService:Find(player, kind)
	for _, holder in { player.Character, player:FindFirstChild("Backpack") } do
		if holder then
			for _, t in holder:GetChildren() do
				if t:IsA("Tool") and t:GetAttribute("Kind") == kind then
					return t
				end
			end
		end
	end
	return nil
end

-- Put a tool in the player's hand (if it isn't already). Returns the tool.
function ToolService:Equip(player, kind)
	local tool = self:Find(player, kind)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if tool and hum and tool.Parent ~= player.Character then
		hum:EquipTool(tool)
	end
	return tool
end

-- (Re)build the hotbar. Tools go in in slot order, and the bonk tool starts in your hand.
function ToolService:Give(player)
	local backpack = player:FindFirstChild("Backpack")
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if not backpack or not hum or not data:Get(player) then
		return
	end
	for _, holder in { backpack, character } do
		for _, t in holder:GetChildren() do
			if t:IsA("Tool") then
				t:Destroy()
			end
		end
	end
	local wingsModel = character:FindFirstChild("WingsModel")
	if wingsModel then
		wingsModel:Destroy()
	end

	local bat = bonker(economy:HasPass(player, "MEGABONK"))
	bat.Activated:Connect(function()
		combat:Bonk(player)
	end)
	bat.Parent = backpack

	local flask = potion()
	flask.Activated:Connect(function()
		self:Drink(player)
	end)
	flask.Parent = backpack
	self:_potionLabel(player)

	if economy:HasPass(player, "WINGS") then
		local w = wings()
		w.Equipped:Connect(function()
			if player.Character then
				ToolService.attachWings(player.Character)
			end
		end)
		w.Unequipped:Connect(function()
			local m = player.Character and player.Character:FindFirstChild("WingsModel")
			if m then
				m:Destroy()
			end
		end)
		w.Parent = backpack
	end
	hum:EquipTool(bat)
end

function ToolService:_potionLabel(player)
	local profile = data:Get(player)
	local tool = self:Find(player, "potion")
	if tool and profile then
		tool.Name = "Speed Potion x" .. profile.potions
		tool:SetAttribute("Count", profile.potions) -- the hotbar's count badge
	end
end

function ToolService:Drink(player)
	local profile = data:Get(player)
	if not profile then
		return
	end
	if profile.potions <= 0 then
		self.PotionsRequested:Fire(player)
		return
	end
	if combat:IsBoosted(player) then
		Net.fire(player, "Toast", "Already zooming! Wait for this potion to wear off.", "info")
		return
	end
	profile.potions -= 1
	combat:Boost(player, Constants.POTION_SECONDS)
	self:_potionLabel(player)
	Net.fire(player, "Toast", `⚡ SPEED BOOST! {Constants.POTION_SECONDS}s ({profile.potions} potions left)`, "good")
end

function ToolService:AddPotions(player, count)
	local profile = data:Get(player)
	if not profile then
		return
	end
	profile.potions += count
	self:_potionLabel(player)
	Net.fire(player, "Toast", `🧪 +{count} Speed Potions!`, "good")
end

return ToolService
