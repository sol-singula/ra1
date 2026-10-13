-- The hotbar: real Roblox tools in each player's backpack, so the standard hotbar (keys 1-3, a click or a tap to
-- use) works on every device.
--   1. Your weapon (Bonk Bat up to Inferno Blade; the Mega Bonk pass gilds it): click to bonk.
--   2. Speed Potion: drink one to run faster for a while. New players get a few; more come in a product.
--   3. Dragon Wings (VIP only): wings on your back; with them in hand you fly (hold jump to rise, hover). ToolController does
--      the flying, because your character's physics run on your own device.
-- Also caps how far players can zoom the camera out.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local DragonBuilder = require(script.Parent.Parent.World.DragonBuilder)

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

-- The weapon in slot 1, by tier (Constants.WEAPONS): bat, spiked club, war hammer, dragon mace, inferno blade.
-- Mega Bonk makes it glow gold.
local function bonker(level, mega)
	local w = Constants.WEAPONS[level] or Constants.WEAPONS[1]
	local tool = newTool(
		w.name,
		"bonk",
		Constants.WEAPONS[level + 1] and "Click to bonk! Better swords: tap SWORDS" or "Click to bonk thieves!",
		Constants.TOOL_ICONS[w.key] or Constants.TOOL_ICONS.bat
	)
	tool:SetAttribute("Weapon", w.key)
	local handle = part({
		Name = "Handle",
		Size = Vector3.new(0.35, w.key == "blade" and 1.2 or 2.4, 0.35),
		Color = w.key == "mace" and GOLD or WOOD,
		Material = w.key == "mace" and Enum.Material.Metal or Enum.Material.Wood,
		Parent = tool,
	})
	local pieces
	if w.key == "club" then
		pieces = {
			{
				props = {
					Name = "ClubHead",
					Size = Vector3.new(0.9, 1.5, 0.9),
					Color = WOOD:Lerp(Color3.new(0, 0, 0), 0.2),
					Material = Enum.Material.Wood,
				},
				at = CFrame.new(0, 1.7, 0),
			},
		}
		for k = 0, 5 do
			local a = k / 6 * math.pi * 2
			table.insert(pieces, {
				props = {
					Name = "Spike",
					Size = Vector3.new(0.18, 0.18, 0.5),
					Color = IRON,
					Material = Enum.Material.Metal,
				},
				at = CFrame.new(0, 1.5 + (k % 2) * 0.45, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 0.6),
			})
		end
	elseif w.key == "hammer" then
		pieces = {
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
		}
	elseif w.key == "mace" then
		pieces = {
			{
				props = {
					Name = "MaceHead",
					Shape = Enum.PartType.Ball,
					Size = Vector3.new(1.3, 1.3, 1.3),
					Color = Color3.fromRGB(45, 42, 55),
					Material = Enum.Material.Metal,
				},
				at = CFrame.new(0, 1.7, 0),
			},
			{
				props = {
					Name = "MaceCore",
					Shape = Enum.PartType.Ball,
					Size = Vector3.new(0.7, 0.7, 0.7),
					Color = Color3.fromRGB(180, 90, 255),
					Material = Enum.Material.Neon,
				},
				at = CFrame.new(0, 1.7, 0),
			},
		}
		for k = 0, 7 do
			local a = k / 8 * math.pi * 2
			table.insert(pieces, {
				props = {
					Name = "Spike",
					Size = Vector3.new(0.2, 0.2, 0.6),
					Color = Color3.fromRGB(70, 66, 80),
					Material = Enum.Material.Metal,
				},
				at = CFrame.new(0, 1.7 + ((k % 2) - 0.5) * 0.5, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 0.75),
			})
		end
	elseif w.key == "blade" then
		pieces = {
			{
				props = {
					Name = "Guard",
					Size = Vector3.new(1.4, 0.25, 0.45),
					Color = GOLD,
					Material = Enum.Material.Foil,
				},
				at = CFrame.new(0, 0.65, 0),
			},
			{
				props = {
					Name = "Blade",
					Size = Vector3.new(0.55, 3.2, 0.15),
					Color = Color3.fromRGB(255, 120, 30),
					Material = Enum.Material.Neon,
				},
				at = CFrame.new(0, 2.35, 0),
			},
			{
				props = {
					Name = "Edge",
					Size = Vector3.new(0.65, 3.0, 0.08),
					Color = Color3.fromRGB(255, 220, 120),
					Material = Enum.Material.Neon,
					Transparency = 0.3,
				},
				at = CFrame.new(0, 2.3, 0),
			},
		}
	else
		pieces = {
			{
				props = { Name = "BatHead", Size = Vector3.new(0.75, 1.4, 0.75), Color = GOLD },
				at = CFrame.new(0, 1.7, 0),
			},
			{
				props = { Name = "Grip", Size = Vector3.new(0.42, 0.7, 0.42), Color = Color3.fromRGB(40, 40, 50) },
				at = CFrame.new(0, -0.8, 0),
			},
		}
	end
	attach(handle, pieces)
	if w.key == "blade" then
		local fire = Instance.new("Fire")
		fire.Size = 2
		fire.Heat = 4
		fire.Parent = tool:FindFirstChild("Blade")
	end
	if mega then
		local glow = Instance.new("PointLight")
		glow.Color = GOLD
		glow.Range = 8
		glow.Brightness = 2
		glow.Parent = handle
		DragonBuilder.twinkle(handle, GOLD, 0.8)
	end
	tool.Grip = CFrame.new(0, w.key == "blade" and -0.2 or -0.8, 0)
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
	local tool = newTool("Dragon Wings", "wings", "Hold jump to fly up, let go to hover!", Constants.TOOL_ICONS.wings)
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
	combat.WeaponChanged:Connect(function(player)
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

	local bat = bonker(data:Get(player).weaponLevel or 1, economy:HasPass(player, "MEGABONK"))
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

	if economy:HasPass(player, "VIP") then -- wings are VIP only
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
	Net.fire(player, "Sfx", "potion")
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
