--[[
Controls (master plan §16, phone first): joystick on the left (Roblox's), buttons on the right.

  MAIN     one big button that does the right thing: MINE a node you're next to, BUILD or FIX the piece you're
           next to, otherwise your job's attack (SWING, SHOOT, MEND, CLAW, SPIT...). Hold it to keep going.
  SPECIAL  your job's special move, with its cooldown sweeping around it
  BUILD    (dwarves) build mode: the piece bar and the ghost (BuildController)
  PING     quick pings for your team
Keyboard: click or F = main, Q = special, B = build mode, G = ping, Z = eat, C = potion, H = emote, J = jobs
(monsters at their spawn). Gamepad: R2 = main, L2 = special, Y = build mode, DPad up = ping.
The thing MAIN will act on is outlined in the world. Knockbacks and the Brute's charge move your own character.
]]
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Jobs = require(ReplicatedStorage.Shared.Data.Jobs)
local MapLayout = require(ReplicatedStorage.Shared.World.MapLayout)
local Net = require(ReplicatedStorage.Shared.Net)
local Pieces = require(ReplicatedStorage.Shared.Data.Pieces)
local Bus = require(script.Parent.Parent.UI.Bus)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local InputController = { Name = "InputController", Order = 20 }

local player = Players.LocalPlayer
local C = Theme.Color
local new = Theme.new
local gui
local refs = {}
local context = nil -- { kind = "node" | "piece" | "enemy", id, label, model, pos }
local holding = false
local lastMain = 0
local specialReadyAt = 0
local buildMode = false
local highlight
local dash -- { dir, speed, untilT }

local MAIN_LABEL = {
	hammer = "🔨 HIT",
	pick = "⛏️ HIT",
	smash = "⚔️ SWING",
	shoot = "🏹 SHOOT",
	mend = "💚 MEND",
	claw = "👊 CLAW",
	pound = "🦍 POUND",
	spit = "🟢 SPIT",
	hex = "🔮 HEX",
	ram = "🪵 RAM",
}

local function root()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function job()
	local me = Store.get("me")
	return me and me.job and Jobs.byKey[me.job]
end

-- Pieces in the world, read from their models (attributes the server sets).
local function pieceInfo(model)
	local key = model:GetAttribute("Key")
	local def = key and Pieces.byKey[key]
	local i, j, rot = model:GetAttribute("I"), model:GetAttribute("J"), model:GetAttribute("Rot")
	if not def or not i then
		return nil
	end
	local w, d = Pieces.cells(def, rot)
	local cx, cz = (i + w / 2) * MapLayout.CELL, (j + d / 2) * MapLayout.CELL
	return {
		def = def,
		center = Vector3.new(cx, MapLayout.groundY(cx, cz), cz),
		sx = w * MapLayout.CELL,
		sz = d * MapLayout.CELL,
		built = model:GetAttribute("Built") == true,
		hp = model:GetAttribute("Hp") or 0,
		maxHp = model:GetAttribute("MaxHp") or def.hp,
		upgrading = model:GetAttribute("Upgrading"),
	}
end
InputController.pieceInfo = pieceInfo

local function edgeDistance(info, pos)
	local dx = math.max(0, math.abs(pos.X - info.center.X) - info.sx / 2)
	local dz = math.max(0, math.abs(pos.Z - info.center.Z) - info.sz / 2)
	return math.sqrt(dx * dx + dz * dz)
end

-- What MAIN would act on right now.
function InputController.findContext()
	local r = root()
	local me = Store.get("me")
	if not r or not me or not me.team then
		return nil
	end
	local pos = r.Position
	if me.team == "dwarf" then
		-- a blueprint, a hurt piece or an upgrade right by you
		local bestPiece, bestPD
		local castle = workspace:FindFirstChild("Castle")
		for _, m in castle and castle:GetChildren() or {} do
			if m:IsA("Model") and m:GetAttribute("PieceId") then
				local info = pieceInfo(m)
				if info then
					local wants = (not info.built) or info.upgrading or info.hp < info.maxHp
					local d = edgeDistance(info, pos)
					if wants and d <= Constants.HAMMER_RANGE - 2 and (not bestPD or d < bestPD) then
						bestPiece, bestPD = { model = m, info = info }, d
					end
				end
			end
		end
		-- a node with something left
		local bestNode, bestND
		local nodes = workspace:FindFirstChild("Nodes")
		for _, m in nodes and nodes:GetChildren() or {} do
			local id = m:GetAttribute("NodeId")
			local spec = id and MapLayout.nodes[id]
			if spec and (m:GetAttribute("Amount") or 0) > 0 then
				local d = Vector2.new(pos.X - spec.pos.X, pos.Z - spec.pos.Z).Magnitude
					- MapLayout.NODE_SIZE[spec.kind] / 2
				if
					d <= Constants.MINE_RANGE - 2
					and math.abs(pos.Y - spec.pos.Y) < 14
					and (not bestND or d < bestND)
				then
					bestNode, bestND = { model = m, spec = spec }, d
				end
			end
		end
		if bestPiece and (not bestNode or bestPD <= bestND + 2) then
			local info = bestPiece.info
			local label = not info.built and "🔨 BUILD" or info.upgrading and "⬆️ UPGRADE" or "🔧 FIX"
			return {
				kind = "piece",
				id = bestPiece.model:GetAttribute("PieceId"),
				label = label,
				model = bestPiece.model,
				pos = info.center,
			}
		elseif bestNode then
			local kind = bestNode.spec.kind
			return {
				kind = "node",
				id = bestNode.spec.id,
				label = kind == "wood" and "🪓 CHOP" or "⛏️ MINE",
				model = bestNode.model,
				pos = bestNode.spec.pos,
			}
		end
	end
	return nil
end

-- Where the move goes: the camera's aim, or a target right in front if one is close (aim help on phones).
function InputController.aim()
	local cam = workspace.CurrentCamera
	local r = root()
	local look = cam and cam.CFrame and cam.CFrame.LookVector or Vector3.new(0, 0, -1)
	if UserInputService.MouseEnabled and Theme.inputKind() == "keyboard" and cam then
		local ok, ray = pcall(function()
			local m = UserInputService:GetMouseLocation()
			return cam:ViewportPointToRay(m.X, m.Y)
		end)
		if ok and ray then
			look = ray.Direction.Unit
		end
	end
	if r and context and context.kind == "enemy" and context.pos then
		local d = context.pos - r.Position
		if d.Magnitude > 0.1 then
			look = d.Unit
		end
	end
	return look
end

-- Turn your character to face where you swing (melee feels right).
local function face(dir)
	local r = root()
	if not r then
		return
	end
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude > 0.1 then
		r.CFrame = CFrame.lookAt(r.Position, r.Position + flat.Unit)
	end
end

function InputController.main()
	local me = Store.get("me")
	local j = job()
	if not me or not me.team or not j or not me.alive then
		return
	end
	local now = os.clock()
	if now - lastMain < j.main.cooldown * 0.95 then
		return
	end
	lastMain = now
	local aim = InputController.aim()
	local target
	if context and (context.kind == "node" or context.kind == "piece") then
		target = { [context.kind] = context.id }
		local r = root()
		if r and context.pos then
			face(context.pos - r.Position)
		end
	else
		face(aim)
	end
	Net.send("Act", "main", aim, target)
	refs.mainScale.Scale = 0.9
	Theme.tween(refs.mainScale, 0.15, { Scale = 1 })
end

function InputController.special()
	local me = Store.get("me")
	local j = job()
	if not me or not me.team or not j or not me.alive then
		return
	end
	local now = os.clock()
	if now < specialReadyAt then
		return
	end
	specialReadyAt = now + j.special.cooldown
	local aim = InputController.aim()
	face(aim)
	local target = context and context.kind == "node" and { node = context.id } or nil
	Net.send("Act", "special", aim, target)
	Bus.Tap:Fire("special")
end

function InputController.setBuildMode(on)
	if on and Store.team() ~= "dwarf" then
		on = false
	end
	Bus.BuildMode:Fire(on)
end

function InputController.isBuildMode()
	return buildMode
end

-- The ping wheel: four big buttons, then it closes.
local function openPings()
	if refs.pings and refs.pings.Parent then
		refs.pings:Destroy()
		return
	end
	local frame = new("Frame", {
		Name = "Pings",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -100, 1, -330),
		Size = UDim2.fromOffset(200, 210),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	refs.pings = frame
	for k, p in Constants.PINGS do
		local b = Theme.button({
			Name = p.key,
			Text = p.icon .. " " .. p.text,
			BackgroundColor3 = ({ C.red, C.orange, C.purple, C.sky })[k],
			Size = UDim2.fromOffset(200, 46),
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

-- The buttons ------------------------------------------------------------------------------------------------------
local function buildButtons()
	local main = Theme.button({
		Name = "Main",
		Text = "",
		BackgroundColor3 = C.ketchup,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -150, 1, -96),
		Size = UDim2.fromOffset(124, 124),
		round = true,
		Parent = gui,
	})
	refs.main = main
	refs.mainScale = main:FindFirstChild("Press") or new("UIScale", { Parent = main })
	refs.mainLabel = Theme.title({
		Name = "Label",
		Text = "",
		Size = UDim2.new(1, -10, 0.6, 0),
		Position = UDim2.new(0, 5, 0.2, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = main,
	})
	Theme.keyHint(main, "F", "R2")
	main.MouseButton1Down:Connect(function()
		holding = true
		InputController.main()
	end)
	main.MouseButton1Up:Connect(function()
		holding = false
	end)
	main.MouseLeave:Connect(function()
		holding = false
	end)
	local special = Theme.button({
		Name = "Special",
		Text = "",
		BackgroundColor3 = C.purple,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -40, 1, -196),
		Size = UDim2.fromOffset(88, 88),
		round = true,
		Parent = gui,
	})
	refs.special = special
	refs.specialIcon = Theme.text({
		Name = "Icon",
		Text = "",
		Size = UDim2.new(1, 0, 0.62, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = special,
	})
	refs.specialLabel = Theme.title({
		Name = "Label",
		Text = "",
		Size = UDim2.new(1.2, 0, 0, 20),
		Position = UDim2.new(-0.1, 0, 0.62, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		outline = 2,
		Parent = special,
	})
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
	refs.cooldownText = Theme.title({
		Name = "Seconds",
		Text = "",
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 4,
		Parent = special,
	})
	Theme.keyHint(special, "Q", "L2")
	special.Activated:Connect(InputController.special)
	local mode = Theme.button({
		Name = "Mode",
		Text = "🏗️",
		BackgroundColor3 = C.mustard,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -290, 1, -40),
		Size = UDim2.fromOffset(74, 74),
		round = true,
		Parent = gui,
	})
	refs.mode = mode
	refs.modeLabel = Theme.title({
		Name = "Label",
		Text = "BUILD",
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.new(1.3, 0, 0, 20),
		Position = UDim2.new(0.5, 0, 1, -16),
		TextXAlignment = Enum.TextXAlignment.Center,
		outline = 2,
		Parent = mode,
	})
	Theme.keyHint(mode, "B", "Y")
	mode.Activated:Connect(function()
		Bus.Tap:Fire("build_mode")
		InputController.setBuildMode(not buildMode)
	end)
	local ping = Theme.button({
		Name = "Ping",
		Text = "📢",
		BackgroundColor3 = C.sky,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -40, 1, -296),
		Size = UDim2.fromOffset(60, 60),
		round = true,
		Parent = gui,
	})
	refs.ping = ping
	Theme.keyHint(ping, "G", "↑")
	ping.Activated:Connect(function()
		Bus.Tap:Fire("ping")
		openPings()
	end)
	local jobsBtn = Theme.button({
		Name = "Jobs",
		Text = "🔄 JOB",
		BackgroundColor3 = Color3.fromRGB(150, 230, 70),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -290, 1, -126),
		Size = UDim2.fromOffset(96, 44),
		Visible = false,
		Parent = gui,
	})
	refs.jobs = jobsBtn
	jobsBtn.Activated:Connect(function()
		Bus.Open:Fire("picker")
	end)
end

local function updateButtons()
	local me = Store.get("me") or {}
	local j = job()
	local inMatch = me.team and Store.inMatch()
	refs.main.Visible = inMatch == true
	refs.special.Visible = inMatch == true
	refs.ping.Visible = inMatch == true
	refs.mode.Visible = me.team == "dwarf" and inMatch == true
	if not inMatch or not j then
		if buildMode then
			InputController.setBuildMode(false)
		end
		return
	end
	if me.team ~= "dwarf" and buildMode then
		InputController.setBuildMode(false)
	end
	refs.mainLabel.Text = context and context.label or MAIN_LABEL[j.main.key] or "HIT"
	refs.main.BackgroundColor3 = context and (context.kind == "piece" and C.mustard or C.good)
		or (me.team == "monster" and Color3.fromRGB(150, 230, 70) or C.ketchup)
	refs.specialIcon.Text = j.special.icon
	refs.specialLabel.Text = j.special.name:upper()
	local left = specialReadyAt - os.clock()
	if left > 0 then
		refs.cooldown.Size = UDim2.fromScale(1, math.clamp(left / j.special.cooldown, 0, 1))
		refs.cooldownText.Text = tostring(math.ceil(left))
	else
		refs.cooldown.Size = UDim2.fromScale(1, 0)
		refs.cooldownText.Text = ""
	end
	-- monsters at their spawn can swap jobs
	local r = root()
	local m = Store.get("match")
	if me.team == "monster" and r and m then
		local spawn = MapLayout.monsterSpawnCenter(m.fallen or 0)
		refs.jobs.Visible = (r.Position - spawn).Magnitude <= 30
	else
		refs.jobs.Visible = false
	end
end

local function updateHighlight()
	local target = context and context.model
	if target and target.Parent then
		if not highlight then
			highlight = new("Highlight", {
				Name = "Target",
				FillTransparency = 0.85,
				OutlineTransparency = 0,
				OutlineColor = C.mustard,
				FillColor = C.mustard,
				DepthMode = Enum.HighlightDepthMode.Occluded,
				Parent = gui,
			})
		end
		highlight.Adornee = target
		highlight.Enabled = true
	elseif highlight then
		highlight.Enabled = false
		highlight.Adornee = nil
	end
end

-- Knockback and the charge (your own character) ------------------------------------------------------------------
local function knock(dir, force)
	local r = root()
	if not r or typeof(dir) ~= "Vector3" then
		return
	end
	r.AssemblyLinearVelocity = dir * force * 2.2 + Vector3.new(0, force * 1.1, 0)
	Bus.Shake:Fire(0.4, 0.2)
end

local function startDash(dir, distance, seconds)
	if typeof(dir) ~= "Vector3" or type(distance) ~= "number" or type(seconds) ~= "number" then
		return
	end
	dash = { dir = dir, speed = distance / math.max(0.1, seconds), untilT = os.clock() + seconds }
	face(dir)
	Bus.Shake:Fire(0.5, seconds)
end

function InputController:init()
	gui = Theme.screen("Actions", 6, player:WaitForChild("PlayerGui"))
	buildButtons()
	Net.listen("Knock", knock)
	Net.listen("Dash", startDash)
	Bus.BuildMode:Connect(function(on)
		buildMode = on
		refs.mode.Text = on and "⚔️" or "🏗️"
		refs.modeLabel.Text = on and "FIGHT" or "BUILD"
	end)

	-- keyboard and gamepad
	local function bind(name, fn, ...)
		ContextActionService:BindAction(name, function(_, state)
			if state == Enum.UserInputState.Begin then
				fn()
			end
			return Enum.ContextActionResult.Sink
		end, false, ...)
	end
	bind("HC_Special", InputController.special, Enum.KeyCode.Q, Enum.KeyCode.ButtonL2)
	bind("HC_Build", function()
		InputController.setBuildMode(not buildMode)
	end, Enum.KeyCode.B, Enum.KeyCode.ButtonY)
	bind("HC_Ping", openPings, Enum.KeyCode.G, Enum.KeyCode.DPadUp)
	bind("HC_Food", function()
		Net.send("Use", "food")
	end, Enum.KeyCode.Z)
	bind("HC_Potion", function()
		Net.send("Use", "potion")
	end, Enum.KeyCode.C)
	bind("HC_Emote", function()
		local p = Store.get("profile")
		Net.send("Emote", p and p.looks and p.looks.equipped.emote or "wave")
	end, Enum.KeyCode.H)
	bind("HC_Jobs", function()
		if refs.jobs.Visible then
			Bus.Open:Fire("picker")
		end
	end, Enum.KeyCode.J)
	ContextActionService:BindAction("HC_Main", function(_, state)
		if state == Enum.UserInputState.Begin then
			holding = true
			InputController.main()
		elseif state == Enum.UserInputState.End then
			holding = false
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.F, Enum.KeyCode.ButtonR2)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 and not buildMode then
			holding = true
			InputController.main()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			holding = false
		end
	end)

	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if acc >= 0.15 then
			acc = 0
			context = InputController.findContext()
			updateButtons()
			updateHighlight()
		end
		if holding then
			InputController.main()
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
	-- a fresh character: the special is ready again
	player.CharacterAdded:Connect(function()
		specialReadyAt = 0
		holding = false
	end)
end

-- (tests)
function InputController.context()
	return context
end
InputController.refs = refs

return InputController
