--[[
Controls (master plan §11: mobile first; PC and gamepad equal): Roblox's joystick or WASD to move, the camp's and
the forest's prompts to interact (hold to build, open crates, revive), and on the right:

  ACT       does what you hold: swing an axe, club or spear, shoot a bow, eat, set a trap, throw a flare. With
            nothing to fight, the same swing chops the tree in front of you. Hold to keep going. In goo: MASH.
  DODGE     a quick roll with i-frames (master plan §5): reading a tell and dodging is the core skill
  SPRINT    a toggle on phones; drains stamina (faster than Kermy and the wolves)
  SPECIAL   your weapon class's alternate move at mastery 3 (Whirl Chop, Ground Pound, Lunge Thrust, Triple Shot)
  PING      a quick word for the team
Keyboard: click = act, Q = dodge, hold Shift = sprint, R = special, 1-6 or the mouse wheel = hotbar, Tab = the
inventory, G = ping, H = the 6-7. Gamepad: R2 = act, B = dodge, L3 = sprint, L2 = special, L1/R1 = hotbar, Y = the
inventory, DPad up = ping.
Aim help on phones and gamepads: a swing turns to the nearest monster in front of you, a bow aims at the nearest
one in a cone. Your own swing animates the instant you press; knockbacks and dodges move your own character.
]]
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local MapLayout = require(ReplicatedStorage.Shared.World.MapLayout)
local Net = require(ReplicatedStorage.Shared.Net)
local Progression = require(ReplicatedStorage.Shared.Data.Progression)
local MonsterController = require(script.Parent.MonsterController)
local Bus = require(script.Parent.Parent.UI.Bus)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local InputController = { Name = "InputController", Order = 20 }

local player = Players.LocalPlayer
local C = Theme.Color
local new = Theme.new
local gui
local refs = {}
local holding = false
local lastAct = 0
local specialReadyAt = 0
local dodgeReadyAt = 0
local sprinting = false
local sprintToggle = false
local dash -- { dir, speed, untilT }
local felled = {} -- trees felled this run (for the CHOP label)
local treeGrid

local ACT_LABEL = { axe = "CHOP", club = "SMASH", spear = "STAB", bow = "SHOOT" }

local function root()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function humanoid()
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

-- What's in your hand: slotId, the slot, the item.
function InputController.held()
	local id, slot = Store.held()
	return id, slot, slot and Items.get(slot.key) or nil
end

local function cocooned()
	return player:GetAttribute("Cocooned") == true
end

-- Trees near a point that an axe can chop (from the shared layout; the felled ones are remembered from their falls;
-- the giants of the deep forest are too big to chop).
local function treesNear(pos, radius)
	if not treeGrid then
		treeGrid = {}
		for _, t in MapLayout.trees() do
			local spec = MapLayout.TREE_KINDS[t.kind]
			if t.reachable and not (spec and spec.hp == math.huge) then
				local k = math.floor(t.x / 16) * 4096 + math.floor(t.z / 16)
				treeGrid[k] = treeGrid[k] or {}
				table.insert(treeGrid[k], t)
			end
		end
	end
	local out = {}
	local reach = radius + 8 -- (the widest trunk)
	local c0x, c0z = math.floor((pos.X - reach) / 16), math.floor((pos.Z - reach) / 16)
	local c1x, c1z = math.floor((pos.X + reach) / 16), math.floor((pos.Z + reach) / 16)
	for cx = c0x, c1x do
		for cz = c0z, c1z do
			for _, t in treeGrid[cx * 4096 + cz] or {} do
				if not felled[t.id] and (Vector2.new(t.x - pos.X, t.z - pos.Z)).Magnitude <= radius + t.trunk then
					table.insert(out, t)
				end
			end
		end
	end
	return out
end
InputController.treesNear = treesNear

local function flatUnit(v, fallback)
	local f = Vector3.new(v.X, 0, v.Z)
	return f.Magnitude > 0.01 and f.Unit or fallback
end

local function usingMouse()
	return UserInputService.MouseEnabled and Theme.inputKind() == "keyboard"
end

-- What the mouse points at in the world (PC): the hit position (nil over the sky) and the ray's direction.
local function mouseRay()
	local cam = workspace.CurrentCamera
	if not cam or not usingMouse() then
		return nil, nil
	end
	local ok, pos, dir = pcall(function()
		local m = UserInputService:GetMouseLocation()
		local ray = cam:ViewportPointToRay(m.X, m.Y)
		local skip = {}
		if player.Character then
			table.insert(skip, player.Character)
		end
		local guide = workspace:FindFirstChild("Guide")
		if guide then
			table.insert(skip, guide)
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = skip
		local hit = workspace:Raycast(ray.Origin, ray.Direction.Unit * 400, params)
		return hit and hit.Position or nil, ray.Direction.Unit
	end)
	if not ok then
		return nil, nil
	end
	return pos, dir
end

--[[ Where the move goes. Forward is where the camera looks (what you see in front of you); on PC, toward what's
under the mouse unless that's behind you. Then aim help: a melee swing turns to the nearest monster in front of
you, or with nothing to fight, to the nearest tree in front of you (so walking up to a tree and pressing CHOP always
chops it); a bow aims at the mouse on PC, or at the nearest monster in a cone on phones and gamepads. ]]
function InputController.aim(item)
	local cam = workspace.CurrentCamera
	local r = root()
	local look = cam and cam.CFrame and cam.CFrame.LookVector or Vector3.new(0, 0, -1)
	local facing = r and flatUnit(r.CFrame.LookVector, Vector3.new(0, 0, -1)) or Vector3.new(0, 0, -1)
	local forward = flatUnit(look, facing)
	local bow = item and item.class == "bow"
	local hitPos, rayDir = mouseRay()
	if bow and (hitPos or rayDir) then
		if hitPos and r then
			local d = hitPos - (r.Position + Vector3.new(0, 1.5, 0))
			if d.Magnitude > 4 then
				return d.Unit
			end
		end
		return rayDir or look
	end
	if not r then
		return bow and look or forward
	end
	if hitPos then
		local d = Vector3.new(hitPos.X - r.Position.X, 0, hitPos.Z - r.Position.Z)
		if d.Magnitude > 1.5 and d.Unit:Dot(forward) > -0.15 then
			forward = d.Unit
		end
	end
	local reach = bow and 70 or ((item and item.range or 5) + 4)
	local cone = bow and math.cos(math.rad(25)) or math.cos(math.rad(70))
	for _, m in MonsterController.near(r.Position, reach) do
		local d = m.pos + Vector3.new(0, 2, 0) - r.Position
		local f = Vector3.new(d.X, 0, d.Z)
		if f.Magnitude < 0.1 or f.Unit:Dot(forward) >= cone then
			return bow and d.Unit or (f.Magnitude > 0.1 and f.Unit or forward)
		end
	end
	if bow then
		return look
	end
	-- nothing to fight: the tree or rock most in front of you (the server picks the same way)
	local best, bestScore
	local function consider(x, z, radius)
		local f = Vector3.new(x - r.Position.X, 0, z - r.Position.Z)
		local gap = math.max(0, f.Magnitude - radius)
		if gap > Constants.GATHER_RANGE or f.Magnitude < 0.05 then
			return
		end
		local cos = f.Unit:Dot(forward)
		if cos < math.cos(math.rad(75)) then
			return
		end
		local score = gap + (1 - cos) * 6
		if not bestScore or score < bestScore then
			best, bestScore = f.Unit, score
		end
	end
	for _, t in treesNear(r.Position, Constants.GATHER_RANGE) do
		consider(t.x, t.z, t.trunk)
	end
	local nodes = workspace:FindFirstChild("Nodes")
	for _, m in nodes and nodes:GetChildren() or {} do
		local at = m:GetAttribute("At")
		if typeof(at) == "Vector3" and math.abs(at.X - r.Position.X) < 16 and math.abs(at.Z - r.Position.Z) < 16 then
			consider(at.X, at.Z, m:GetAttribute("Radius") or 1)
		end
	end
	return best or forward
end

-- Turn your character to face where you swing.
local function face(dir)
	local r = root()
	if not r or typeof(dir) ~= "Vector3" then
		return
	end
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude > 0.1 then
		r.CFrame = CFrame.lookAt(r.Position, r.Position + flat.Unit)
	end
end

function InputController.act()
	if cocooned() then
		Net.send("Mash")
		Bus.Tap:Fire("mash")
		return
	end
	if not Store.alive() then
		return
	end
	local id, slot, item = InputController.held()
	local cd = (item and item.kind == "weapon") and item.cd or 0.6
	local now = os.clock()
	if now - lastAct < cd * 0.95 then
		return
	end
	lastAct = now
	local index = type(id) == "string" and tonumber(string.sub(id, 2)) or nil
	local aim = InputController.aim(item)
	if item and item.kind == "throw" then
		local r = root()
		local target
		local cam = workspace.CurrentCamera
		if usingMouse() and cam and r then
			local ok, ray = pcall(function()
				local m = UserInputService:GetMouseLocation()
				return cam:ViewportPointToRay(m.X, m.Y)
			end)
			if ok and ray and ray.Direction.Y < -0.05 then
				local tt = (r.Position.Y - 2 - ray.Origin.Y) / ray.Direction.Y
				target = ray.Origin + ray.Direction * tt
			end
		end
		target = target or (r and r.Position + Vector3.new(aim.X, 0, aim.Z).Unit * 22)
		face(aim)
		Net.send("Throw", id, target)
		Bus.Swing:Fire(slot.key, "throw")
		return
	end
	face(aim)
	Net.send("Act", index, aim, "main")
	if not item or item.kind == "weapon" or item.kind == "light" then
		Bus.Swing:Fire(item and item.kind == "weapon" and slot.key or "hands", "main")
	end
	if refs.actScale then
		refs.actScale.Scale = 0.9
		Theme.tween(refs.actScale, 0.15, { Scale = 1 })
	end
end

-- The special move of what you hold (mastery 3).
function InputController.specialFor(item)
	local profile = Store.get("profile")
	local class = item and Items.masteryClass(item)
	local spec = class and Progression.SPECIALS[class]
	local m = profile and profile.mastery and class and profile.mastery[class]
	if spec and not spec.passive and m and m.level >= 3 then
		return spec, class
	end
	return nil
end

function InputController.special()
	if not Store.alive() then
		return
	end
	local _, slot, item = InputController.held()
	local spec = InputController.specialFor(item)
	if not spec then
		return
	end
	local now = os.clock()
	if now < specialReadyAt then
		return
	end
	specialReadyAt = now + Constants.SPECIAL_COOLDOWN
	local aim = InputController.aim(item)
	face(aim)
	Net.send("Act", nil, aim, "special")
	Bus.Swing:Fire(slot.key, "special")
	Bus.Tap:Fire("special")
end

function InputController.dodge()
	if not Store.alive() or cocooned() then
		return
	end
	local now = os.clock()
	local me = Store.get("me")
	if now < dodgeReadyAt or (me and me.stamina or 0) < Constants.DODGE_COST then
		return
	end
	dodgeReadyAt = now + Constants.DODGE_COOLDOWN * 0.9
	local hum = humanoid()
	local r = root()
	local dir = hum and hum.MoveDirection or Vector3.zero
	if dir.Magnitude < 0.1 and r then
		dir = -r.CFrame.LookVector -- standing still: hop back
	end
	Net.send("Dodge", dir)
	Bus.Tap:Fire("dodge")
end

function InputController.setSprint(on)
	if on == sprinting then
		return
	end
	sprinting = on
	Net.send("Sprint", on)
end

function InputController.select(index)
	if type(index) ~= "number" or index < 1 or index > Constants.HOTBAR then
		return
	end
	local inv = Store.get("inv")
	inv.selected = index -- right away; the server's "Inv" confirms
	Store.Changed:Fire({ inv = inv })
	Net.send("Select", index)
end

-- The ping wheel: four buttons, then it closes.
local function openPings()
	if refs.pings and refs.pings.Parent then
		refs.pings:Destroy()
		return
	end
	local frame = new("Frame", {
		Name = "Pings",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -110, 1, -340),
		Size = UDim2.fromOffset(190, 210),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	refs.pings = frame
	for k, p in Constants.PINGS do
		local b = Theme.button({
			Name = p.key,
			Text = p.icon .. " " .. p.text,
			BackgroundColor3 = ({ C.orange, C.mustard, C.red, C.sky })[k],
			Size = UDim2.fromOffset(190, 46),
			Position = UDim2.fromOffset(0, (k - 1) * 52),
			Parent = frame,
		})
		b.Activated:Connect(function()
			local r = root()
			Net.send("Ping", p.key, r and r.Position or nil)
			Bus.Tap:Fire("ping_" .. p.key)
			frame:Destroy()
		end)
	end
	Theme.pop(frame)
	task.delay(5, function()
		if frame.Parent then
			frame:Destroy()
		end
	end)
end

-- The buttons --------------------------------------------------------------------------------------------------------------------
local function roundButton(name, text, color, size, pos, key, pad)
	local b = Theme.button({
		Name = name,
		Text = "",
		BackgroundColor3 = color,
		AnchorPoint = Vector2.new(1, 1),
		Position = pos,
		Size = UDim2.fromOffset(size, size),
		round = true,
		Parent = gui,
	})
	local icon = Theme.text({
		Name = "Icon",
		Text = text,
		Size = UDim2.new(1, 0, 0.6, 0),
		Position = UDim2.fromScale(0, 0.06),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = b,
	})
	local label = Theme.title({
		Name = "Label",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.new(1.3, 0, 0, 20),
		Position = UDim2.new(0.5, 0, 0.64, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		outline = 2,
		Parent = b,
	})
	Theme.keyHint(b, key, pad)
	return b, icon, label
end

local function buildButtons()
	local act, actIcon, actLabel = roundButton("Act", "🪓", C.ketchup, 128, UDim2.new(1, -40, 1, -40), "Click", "R2")
	refs.act, refs.actIcon, refs.actLabel = act, actIcon, actLabel
	refs.actScale = act:FindFirstChild("Press") or new("UIScale", { Parent = act })
	act.MouseButton1Down:Connect(function()
		holding = true
		InputController.act()
	end)
	act.MouseButton1Up:Connect(function()
		holding = false
	end)
	act.MouseLeave:Connect(function()
		holding = false
	end)
	local dodge, _, dodgeLabel = roundButton("Dodge", "💨", C.sky, 86, UDim2.new(1, -184, 1, -36), "Q", "B")
	dodgeLabel.Text = "DODGE"
	refs.dodge = dodge
	dodge.Activated:Connect(InputController.dodge)
	local sprint, _, sprintLabel = roundButton("Sprint", "🏃", C.good, 72, UDim2.new(1, -70, 1, -184), "Shift", "L3")
	sprintLabel.Text = "SPRINT"
	refs.sprint = sprint
	sprint.Activated:Connect(function()
		sprintToggle = not sprintToggle
		Bus.Tap:Fire("sprint")
	end)
	local special, specialIcon, specialLabel =
		roundButton("Special", "✨", C.purple, 80, UDim2.new(1, -168, 1, -142), "R", "L2")
	refs.special, refs.specialIcon, refs.specialLabel = special, specialIcon, specialLabel
	refs.cooldown = new("Frame", {
		Name = "Cooldown",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = C.ink,
		BackgroundTransparency = 0.35,
		ZIndex = 3,
		Parent = special,
	}, { Theme.corner("round") })
	special.Activated:Connect(InputController.special)
	local ping = roundButton("Ping", "📢", C.mustard, 58, UDim2.new(1, -40, 1, -270), "G", "↑")
	refs.ping = ping
	ping.Activated:Connect(function()
		Bus.Tap:Fire("ping")
		openPings()
	end)
	-- the stamina ring under SPRINT
	refs.staminaBar, refs.staminaFill = Theme.bar({
		Name = "Stamina",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 6),
		Size = UDim2.new(1, 0, 0, 8),
		Parent = sprint,
	}, C.good)
end

local function updateButtons()
	local status = Store.status()
	local alive = status == "alive"
	local inRun = Store.inRun()
	local stuck = cocooned()
	refs.act.Visible = inRun and (alive or stuck)
	refs.dodge.Visible = inRun and alive and not stuck
	refs.sprint.Visible = inRun and alive and Theme.isTouch()
	refs.ping.Visible = inRun and (alive or status == "downed")
	local _, slot, item = InputController.held()
	if stuck then
		refs.actIcon.Text = "🟢"
		refs.actLabel.Text = "MASH!"
		refs.act.BackgroundColor3 = Color3.fromRGB(120, 220, 90)
	elseif item and item.kind == "weapon" then
		refs.actIcon.Text = item.icon
		local r = root()
		local label = ACT_LABEL[item.class] or "SWING"
		if r and item.class ~= "bow" and #MonsterController.near(r.Position, (item.range or 6) + 6) == 0 then
			label = #treesNear(r.Position, Constants.GATHER_RANGE) > 0 and "CHOP"
				or (item.class == "axe" and "SWING" or label)
		end
		refs.actLabel.Text = label
		refs.act.BackgroundColor3 = C.ketchup
	elseif item and (item.kind == "food" or item.kind == "support") then
		refs.actIcon.Text = item.icon
		refs.actLabel.Text = item.kind == "food" and "EAT" or "USE"
		refs.act.BackgroundColor3 = C.good
	elseif item and item.kind == "trap" then
		refs.actIcon.Text = item.icon
		refs.actLabel.Text = "SET"
		refs.act.BackgroundColor3 = C.orange
	elseif item and item.kind == "throw" then
		refs.actIcon.Text = item.icon
		refs.actLabel.Text = "THROW"
		refs.act.BackgroundColor3 = C.orange
	else
		refs.actIcon.Text = "👊"
		refs.actLabel.Text = "PUNCH"
		refs.act.BackgroundColor3 = C.ketchup
	end
	_ = slot
	local spec, class = InputController.specialFor(item)
	refs.special.Visible = inRun and alive and spec ~= nil
	if spec then
		refs.specialIcon.Text = ({ axe = "🌀", club = "💥", spear = "⚡", bow = "🎯" })[class] or "✨"
		refs.specialLabel.Text = string.upper(spec.name)
		local left = specialReadyAt - os.clock()
		refs.cooldown.Size = UDim2.fromScale(1, left > 0 and math.clamp(left / Constants.SPECIAL_COOLDOWN, 0, 1) or 0)
	end
	local me = Store.get("me")
	if me then
		refs.staminaFill.Size =
			UDim2.fromScale(math.clamp((me.stamina or 0) / math.max(1, me.staminaMax or 100), 0, 1), 1)
	end
	refs.sprint.BackgroundColor3 = sprintToggle and C.mustard or C.good
end

-- Knockback and dashes move your own character -------------------------------------------------------------------------
local function knock(dir, force)
	local r = root()
	if not r or typeof(dir) ~= "Vector3" or type(force) ~= "number" then
		return
	end
	r.AssemblyLinearVelocity = dir * force * 2.2 + Vector3.new(0, force * 0.9, 0)
	Bus.Shake:Fire(0.35, 0.2)
end

local function startDash(dir, distance, seconds)
	if typeof(dir) ~= "Vector3" or type(distance) ~= "number" or type(seconds) ~= "number" then
		return
	end
	dash = {
		dir = Vector3.new(dir.X, 0, dir.Z).Unit,
		speed = distance / math.max(0.1, seconds),
		untilT = os.clock() + seconds,
	}
	Bus.Swing:Fire("dodge", "dodge")
end

-- Walking speed: walk, sprint (while you have stamina) or crawl, from the server's numbers.
local function updateSpeed()
	local hum = humanoid()
	local me = Store.get("me")
	if not hum or not me then
		return
	end
	local want = Theme.isTouch() and sprintToggle
		or (
			UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
			or sprintToggle
		)
	local can = me.status == "alive" and (me.stamina or 0) > 1
	InputController.setSprint(want and can)
	local speed
	if me.status == "downed" then
		speed = Constants.CRAWL_SPEED
	elseif player:GetAttribute("Cocooned") then
		speed = 0
	elseif sprinting and hum.MoveDirection.Magnitude > 0.1 then
		speed = me.sprint or Constants.SPRINT_SPEED
	else
		speed = me.walk or Constants.WALK_SPEED
	end
	if math.abs(hum.WalkSpeed - speed) > 0.01 then
		hum.WalkSpeed = speed
	end
end

function InputController:init()
	gui = Theme.screen("Actions", 6, player:WaitForChild("PlayerGui"))
	buildButtons()
	Net.listen("Knock", knock)
	Net.listen("Dash", startDash)
	Net.listen("Fx", function(kind, d)
		if kind == "fell" and type(d) == "table" and d.tree then
			felled[d.tree] = true
		end
	end)
	Net.listen("Run", function(view)
		if type(view) == "table" and view.phase == "day" and view.day == 1 then
			felled = {}
		end
	end)

	local function bind(name, fn, ...)
		ContextActionService:BindAction(name, function(_, state)
			if state == Enum.UserInputState.Begin then
				fn()
			end
			return Enum.ContextActionResult.Sink
		end, false, ...)
	end
	bind("S67_Dodge", InputController.dodge, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)
	bind("S67_Special", InputController.special, Enum.KeyCode.R, Enum.KeyCode.ButtonL2)
	bind("S67_Ping", openPings, Enum.KeyCode.G, Enum.KeyCode.DPadUp)
	bind("S67_Bag", function()
		Bus.Open:Fire("inventory")
	end, Enum.KeyCode.Tab, Enum.KeyCode.ButtonY)
	bind("S67_Emote", function()
		Net.send("Emote", "67")
		Bus.Tap:Fire("emote_67")
	end, Enum.KeyCode.H)
	bind("S67_Sprint", function()
		sprintToggle = not sprintToggle
	end, Enum.KeyCode.ButtonL3)
	bind("S67_Next", function()
		local inv = Store.get("inv")
		InputController.select((inv.selected or 1) % Constants.HOTBAR + 1)
	end, Enum.KeyCode.ButtonR1)
	bind("S67_Prev", function()
		local inv = Store.get("inv")
		InputController.select(((inv.selected or 1) - 2) % Constants.HOTBAR + 1)
	end, Enum.KeyCode.ButtonL1)
	local keys = {
		Enum.KeyCode.One,
		Enum.KeyCode.Two,
		Enum.KeyCode.Three,
		Enum.KeyCode.Four,
		Enum.KeyCode.Five,
		Enum.KeyCode.Six,
	}
	for i, key in keys do
		bind("S67_Slot" .. i, function()
			InputController.select(i)
		end, key)
	end
	ContextActionService:BindAction("S67_Act", function(_, state)
		if state == Enum.UserInputState.Begin then
			holding = true
			InputController.act()
		elseif state == Enum.UserInputState.End then
			holding = false
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.ButtonR2)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			holding = true
			InputController.act()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			holding = false
		end
	end)
	pcall(function()
		UserInputService.InputChanged:Connect(function(input, processed)
			if processed or input.UserInputType ~= Enum.UserInputType.MouseWheel then
				return
			end
			local inv = Store.get("inv")
			local step = input.Position.Z > 0 and -1 or 1
			InputController.select(((inv.selected or 1) - 1 + step) % Constants.HOTBAR + 1)
		end)
	end)

	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if acc >= 0.12 then
			acc = 0
			updateButtons()
			updateSpeed()
		end
		if holding then
			InputController.act()
		end
		if dash then
			local r = root()
			if r and os.clock() < dash.untilT then
				local v = r.AssemblyLinearVelocity
				r.AssemblyLinearVelocity = Vector3.new(dash.dir.X * dash.speed, v.Y, dash.dir.Z * dash.speed)
			else
				dash = nil
			end
		end
	end)
	player.CharacterAdded:Connect(function()
		specialReadyAt = 0
		holding = false
		sprinting = false
	end)
end

-- (tests)
InputController.refs = refs
function InputController.isSprinting()
	return sprinting
end

return InputController
