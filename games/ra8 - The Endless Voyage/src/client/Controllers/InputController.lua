--[[
Controls (master plan §4: one button that does what you hold; phone first, PC and gamepad equal). Roblox's
joystick or WASD to move, the raft's and the islands' prompts to interact (the helm, the stations, the bunk, the
nets, containers, lanterns and totems), and on the right:

  ACT     does what you hold: HOOK a piece of debris, CAST a rod (then REEL! on the bite), CHOP a tree, MINE a
          rock, PRY a wreck's salvage, FIX a damaged tile with the hammer, STAB with a spear, THROW a harpoon,
          EAT, OPEN a crate, READ a chart, LEARN a blueprint. Hold to keep going.
  BUILD   the build panel (then tap a spot on the grid: BuildController)
  QUICK   hold it: the piece your raft needs next (the raft view's recommendations, the first the bag can pay for)
          goes where you look, one every half second (BuildController, through Bus.Quick)
Keyboard: click = act, 1-6 = hotbar, Tab or I = the bag, B = build, F (held) = quick build, M = the map, J = the
journal, H = wave. Gamepad: R2 = act, L1/R1 = hotbar, Y = the bag, X = build, DPad down (held) = quick build, DPad
up = the map.
Aim help: on PC, what's under the mouse (a piece of debris, a creature, a tree) if it's in reach; on phones and
gamepads, the best target in front of you. The server picks the same way when nothing is named.
]]
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Net = require(ReplicatedStorage.Shared.Net)
local Pieces = require(ReplicatedStorage.Shared.Data.Pieces)
local CreatureController = require(script.Parent.CreatureController)
local Bus = require(script.Parent.Parent.UI.Bus)
local Icons = require(script.Parent.Parent.UI.Icons)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local InputController = { Name = "InputController", Order = 20 }

local player = Players.LocalPlayer
local C = Theme.Color
local new = Theme.new
local gui
local refs = {}
local holding = false
local holdTouch
local lastAct = 0
local building = false -- BuildController is placing (ACT places instead)
local quickHold = false -- QUICK is held: a tick every QUICK_EVERY seconds
local quickTouch
local quickAt = 0
local quickKey -- the piece the QUICK button shows
local QUICK_EVERY = 0.45

local MODE_LABEL = {
	cast = { "CAST", "🎣", C.sky },
	chop = { "CHOP", "🪓", C.ketchup },
	mine = { "MINE", "⛏️", C.ketchup },
	pry = { "PRY", "🔧", C.orange },
	repair = { "FIX", "🔨", C.good },
	swing = { "STAB", "🔱", C.red },
	throw = { "THROW", "🗡️", C.red },
	eat = { "EAT", "🍽️", C.good },
	use = { "USE", "📦", C.mustard },
	build = { "BUILD", "📌", C.mustard },
}

local function root()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

-- What you hold: slot id, slot, item.
function InputController.held()
	local inv = Store.get("inv") or { slots = {}, selected = 1 }
	local id = "h" .. tostring(inv.selected or 1)
	local slot = inv.slots[id]
	return id, slot, slot and Items.get(slot.key) or nil
end

-- What ACT does with an item (the server's ActionService.modeOf, mirrored).
function InputController.modeOf(item)
	if not item then
		return nil
	end
	local kind = Items.toolKind(item)
	if kind == "rod" then
		return "cast"
	elseif kind == "axe" then
		return "chop"
	elseif kind == "pick" then
		return "mine"
	elseif kind == "pry" then
		return "pry"
	elseif kind == "hammer" then
		return "repair"
	elseif item.weapon then
		return item.weapon.thrown and "throw" or "swing"
	elseif item.food then
		return "eat"
	elseif item.kind == "chart" or item.kind == "blueprint" or item.key == "supply_crate" then
		return "use"
	elseif item.kind == "pin" then
		return "build"
	end
	return nil
end

local function flatUnit(v, fallback)
	local f = Vector3.new(v.X, 0, v.Z)
	return f.Magnitude > 0.01 and f.Unit or fallback
end

local function usingMouse()
	return UserInputService.MouseEnabled and Theme.inputKind() == "keyboard"
end

-- What the mouse points at in the world (PC): the hit position (nil over the sky), the ray's direction and origin.
local function mouseRay()
	local cam = workspace.CurrentCamera
	if not cam or not usingMouse() then
		return nil, nil, nil
	end
	local ok, pos, dir, origin = pcall(function()
		local m = UserInputService:GetMouseLocation()
		local ray = cam:ViewportPointToRay(m.X, m.Y)
		local skip = {}
		if player.Character then
			table.insert(skip, player.Character)
		end
		for _, name in { "Guide", "Fx", "Creatures", "Ghost" } do
			local f = workspace:FindFirstChild(name)
			if f then
				table.insert(skip, f)
			end
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = skip
		local hit = workspace:Raycast(ray.Origin, ray.Direction.Unit * 400, params)
		return hit and hit.Position or nil, ray.Direction.Unit, ray.Origin
	end)
	if not ok then
		return nil, nil, nil
	end
	return pos, dir, origin
end
InputController.mouseRay = mouseRay

-- Candidates for the aim: { pos, id } lists from the world's folders.
local function debrisCandidates(from, range)
	local out = {}
	local f = workspace:FindFirstChild("Debris")
	for _, m in f and f:GetChildren() or {} do
		local id = m:GetAttribute("DebrisId")
		if id then
			local pos = m:GetPivot().Position
			if (pos - from).Magnitude <= range then
				table.insert(out, { pos = pos, id = id, model = m })
			end
		end
	end
	local drops = workspace:FindFirstChild("Drops")
	for _, m in drops and drops:GetChildren() or {} do
		local id = m:GetAttribute("DropId")
		if id then
			local pos = m:GetPivot().Position
			if (pos - from).Magnitude <= range then
				table.insert(out, { pos = pos, id = "drop:" .. id, model = m })
			end
		end
	end
	return out
end

local function nodeCandidates(from, range, tool)
	local out = {}
	local f = workspace:FindFirstChild("Islands")
	for _, island in f and f:GetChildren() or {} do
		for _, m in island:GetChildren() do
			local id = m:GetAttribute("NodeId")
			if id and (not tool or m:GetAttribute("Tool") == tool) then
				local pos = m:GetPivot().Position
				if (pos - from).Magnitude <= range then
					table.insert(out, { pos = pos, id = id, model = m })
				end
			end
		end
	end
	return out
end

local function damagedPieces(from, range)
	local out = {}
	local f = workspace:FindFirstChild("Rafts")
	for _, raft in f and f:GetChildren() or {} do
		for _, m in raft:GetChildren() do
			local id = m:GetAttribute("PieceId")
			local health = m:GetAttribute("Health")
			if id and (health ~= nil and health < 1 or m:GetAttribute("Broken")) then
				local pos = m:GetPivot().Position
				if (pos - from).Magnitude <= range then
					table.insert(out, { pos = pos, id = id, model = m })
				end
			end
		end
	end
	return out
end

local function creatureCandidates(from, range)
	local out = {}
	for _, m in CreatureController.near(from, range) do
		table.insert(out, { pos = m.shown or m.pos, id = m.id })
	end
	return out
end

-- The candidate under the mouse's ray (within a few studs), or the best one in front of you.
local function pick(candidates, from, forward, origin, dir, cone)
	local best, bestScore
	if origin and dir then
		-- the nearest thing the cursor is over (it hides what's behind it); failing that, the one closest to the ray
		for _, c in candidates do
			local rel = c.pos - origin
			local along = rel:Dot(dir)
			if along > 0 then
				local off = (rel - dir * along).Magnitude
				if off < 4 then
					local score = off < 2.5 and along or 1000 + off * 100
					if not bestScore or score < bestScore then
						best, bestScore = c, score
					end
				end
			end
		end
		if best then
			return best, true
		end
	end
	bestScore = nil
	local limit = math.cos(math.rad(cone or 60))
	for _, c in candidates do
		local f = Vector3.new(c.pos.X - from.X, 0, c.pos.Z - from.Z)
		local dist = f.Magnitude
		local dot = dist > 0.5 and f.Unit:Dot(forward) or 1
		if dot >= limit then
			local score = dot * 2 - dist / 60
			if not bestScore or score > bestScore then
				best, bestScore = c, score
			end
		end
	end
	return best, false
end

-- Where ACT goes: the aim direction and what it's at (an id for the server), by what you hold.
function InputController.aim(item)
	local cam = workspace.CurrentCamera
	local r = root()
	local look = cam and cam.CFrame and cam.CFrame.LookVector or Vector3.new(0, 0, -1)
	local facing = r and flatUnit(r.CFrame.LookVector, Vector3.new(0, 0, -1)) or Vector3.new(0, 0, -1)
	local forward = flatUnit(look, facing)
	local hitPos, rayDir, rayOrigin = mouseRay()
	if not r then
		return forward, nil
	end
	if hitPos then
		local d = Vector3.new(hitPos.X - r.Position.X, 0, hitPos.Z - r.Position.Z)
		if d.Magnitude > 1.5 and d.Unit:Dot(forward) > -0.15 then
			forward = d.Unit
		end
	end
	local mode = InputController.modeOf(item)
	local candidates
	if mode == "cast" then
		-- a piece in front and the line lands on it; nothing in front and it is a cast into open water
		candidates = debrisCandidates(r.Position, (item.tool.rod.range or 30) + 4)
	elseif mode == "chop" or mode == "mine" or mode == "pry" then
		local tool = mode == "chop" and "axe" or mode == "mine" and "pick" or "pry"
		candidates = nodeCandidates(r.Position, 10, tool)
		if #candidates == 0 then
			candidates = nodeCandidates(r.Position, 10, nil)
		end
	elseif mode == "repair" then
		candidates = damagedPieces(r.Position, 9)
	elseif mode == "swing" then
		candidates = creatureCandidates(r.Position, (item.weapon.range or 8) + 4)
	elseif mode == "throw" then
		candidates = creatureCandidates(r.Position, (item.weapon.range or 60) + 8)
	end
	if candidates then
		local c = pick(candidates, r.Position, forward, rayOrigin, rayDir, mode == "cast" and 60 or 75)
		if c then
			local f = Vector3.new(c.pos.X - r.Position.X, 0, c.pos.Z - r.Position.Z)
			return f.Magnitude > 0.1 and f.Unit or forward, c.id
		end
	end
	return forward, nil
end

-- Turn your character to face where you act.
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

-- A menu panel is open (a click on it is for the panel, not the world).
local function panelOpen()
	local panels = player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("Panels")
	for _, c in panels and panels:GetChildren() or {} do
		if c:IsA("GuiObject") and c.Visible ~= false and string.sub(c.Name, 1, 6) == "Panel_" then
			return true
		end
	end
	return false
end
InputController.panelOpen = panelOpen

function InputController.act()
	if not Store.alive() then
		return
	end
	if building then
		Bus.Place:Fire("act") -- BuildController places
		return
	end
	local fish = Store.get("fish")
	if fish and (fish.state == "bite" or fish.state == "cast") then
		local now = os.clock()
		if now - lastAct < 0.2 then
			return
		end
		lastAct = now
		Net.send("Reel")
		Bus.Tap:Fire("reel")
		return
	end
	local _, slot, item = InputController.held()
	local mode = InputController.modeOf(item)
	local cd = (item and item.weapon) and item.weapon.cd or 0.45
	local now = os.clock()
	if now - lastAct < cd * 0.95 then
		return
	end
	lastAct = now
	local aim, targetId = InputController.aim(item)
	face(aim)
	Net.send("Act", aim, targetId)
	if mode and mode ~= "eat" and mode ~= "use" then
		Bus.Swing:Fire(slot.key, mode)
	end
	if refs.actScale then
		refs.actScale.Scale = 0.9
		Theme.tween(refs.actScale, 0.15, { Scale = 1 })
	end
end

-- QUICK held: the recommended piece where you look, now and every QUICK_EVERY while held (BuildController).
function InputController.quickBegin(how)
	if not Store.alive() or not Store.onOwnRaft() then
		return
	end
	if building then
		Bus.Place:Fire(false) -- the panel's placing ends; QUICK takes over
	end
	quickHold = true
	quickAt = os.clock()
	Bus.Quick:Fire("start", how)
	Bus.Quick:Fire("place")
	Bus.Tap:Fire("quick")
	if refs.quickScale then
		refs.quickScale.Scale = 0.9
		Theme.tween(refs.quickScale, 0.15, { Scale = 1 })
	end
end

function InputController.quickEnd()
	if quickHold then
		quickHold = false
		Bus.Quick:Fire("stop")
	end
end

function InputController.select(index)
	local inv = Store.get("inv")
	if inv then
		inv.selected = index
		Store.Changed:Fire({ inv = inv })
	end
	Net.send("Select", index)
	Bus.Tap:Fire("slot")
end

-- Buttons --------------------------------------------------------------------------------------------------------------
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
	local act, actIcon, actLabel = roundButton("Act", "🎣", C.sky, 128, UDim2.new(1, -40, 1, -40), "Click", "R2")
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
	act.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			holdTouch = input
		end
	end)
	local build, _, buildLabel = roundButton("Build", "🔨", C.mustard, 80, UDim2.new(1, -184, 1, -36), "B", "X")
	buildLabel.Text = "BUILD"
	refs.build = build
	build.Activated:Connect(function()
		Bus.Tap:Fire("build")
		if building then
			Bus.Place:Fire(false)
		else
			Bus.Open:Fire("build")
		end
	end)
	-- QUICK: the recommended piece (a little model of it), held
	local quick, quickIcon, quickLabel =
		roundButton("Quick", "", C.good, 80, UDim2.new(1, -276, 1, -36), "F", "DPadDown")
	quickLabel.Text = "QUICK"
	quickLabel.Size = UDim2.new(1.4, 0, 0, 20)
	refs.quick, refs.quickIcon = quick, quickIcon
	refs.quickPiece = new("Frame", {
		Name = "Piece",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -14, 0.62, 0),
		Position = UDim2.fromOffset(7, 3),
		Parent = quick,
	})
	refs.quickScale = new("UIScale", { Parent = quick })
	quick.Visible = false
	quick.MouseButton1Down:Connect(function()
		InputController.quickBegin("look")
	end)
	quick.MouseButton1Up:Connect(InputController.quickEnd)
	quick.MouseLeave:Connect(InputController.quickEnd)
	quick.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			quickTouch = input
		end
	end)
end

-- The QUICK button shows the piece it would build (and says which, for the guide's finger).
local function updateQuick(alive)
	local raft = Store.get("raft")
	local rec = alive and Store.onOwnRaft() and Formulas.recommended(raft, Store.get("inv")) or nil
	refs.quick.Visible = rec ~= nil
	if not rec then
		if quickHold then
			InputController.quickEnd()
		end
		return
	end
	if rec.key ~= quickKey then
		quickKey = rec.key
		refs.quick:SetAttribute("Piece", rec.key)
		local def = Pieces.get(rec.key)
		local drawn = Icons.piece(refs.quickPiece, rec.key, { colours = raft and raft.colours, inset = 1 })
		refs.quickIcon.Text = drawn and "" or (def and def.icon or "🔨")
	end
end

local function updateButtons()
	local alive = Store.alive()
	refs.act.Visible = alive
	refs.build.Visible = alive and Store.onOwnRaft()
	updateQuick(alive)
	local fish = Store.get("fish")
	local _, _, item = InputController.held()
	local mode = InputController.modeOf(item)
	if building then
		refs.actIcon.Text = "🔨"
		refs.actLabel.Text = "PLACE"
		refs.act.BackgroundColor3 = C.mustard
		refs.build.BackgroundColor3 = C.red
		refs.build.Label.Text = "DONE"
		return
	end
	refs.build.BackgroundColor3 = C.mustard
	refs.build.Label.Text = "BUILD"
	if fish and fish.state == "bite" then
		refs.actIcon.Text = "🐟"
		refs.actLabel.Text = "REEL!"
		refs.act.BackgroundColor3 = C.good
		refs.actScale.Scale = 1 + math.sin(os.clock() * 20) * 0.06
		return
	elseif fish and fish.state == "cast" then
		refs.actIcon.Text = "🎣"
		refs.actLabel.Text = "WAIT..."
		refs.act.BackgroundColor3 = C.slate
		return
	elseif player.Character and player.Character:GetAttribute("Pose") == "reel" and mode == "cast" then
		refs.actIcon.Text = "🎣"
		refs.actLabel.Text = "REELING"
		refs.act.BackgroundColor3 = C.sky
		return
	end
	local spec = MODE_LABEL[mode]
	if spec then
		refs.actIcon.Text = item.icon
		refs.actLabel.Text = spec[1]
		refs.act.BackgroundColor3 = spec[3]
	else
		refs.actIcon.Text = "✋"
		refs.actLabel.Text = "HOLD A TOOL"
		refs.act.BackgroundColor3 = C.muted
	end
end

function InputController:init()
	gui = Theme.screen("Actions", 6, player:WaitForChild("PlayerGui"))
	buildButtons()
	Bus.Place:Connect(function(key)
		if key == "act" then
			return
		end
		building = key ~= false and key ~= nil
	end)
	local function bind(name, fn, ...)
		ContextActionService:BindAction(name, function(_, state)
			if state == Enum.UserInputState.Begin then
				fn()
			end
			return Enum.ContextActionResult.Sink
		end, false, ...)
	end
	bind("EV_Bag", function()
		Bus.Open:Fire("inventory")
	end, Enum.KeyCode.Tab, Enum.KeyCode.I, Enum.KeyCode.ButtonY)
	bind("EV_Build", function()
		if building then
			Bus.Place:Fire(false)
		else
			Bus.Open:Fire("build")
		end
	end, Enum.KeyCode.B, Enum.KeyCode.ButtonX)
	bind("EV_Map", function()
		Bus.Open:Fire("map")
	end, Enum.KeyCode.M, Enum.KeyCode.DPadUp)
	bind("EV_Book", function()
		Bus.Open:Fire("book")
	end, Enum.KeyCode.J)
	bind("EV_Emote", function()
		Net.send("Emote", "wave")
		Bus.Tap:Fire("emote_wave")
	end, Enum.KeyCode.H)
	bind("EV_Next", function()
		local inv = Store.get("inv")
		InputController.select((inv.selected or 1) % Constants.HOTBAR + 1)
	end, Enum.KeyCode.ButtonR1)
	bind("EV_Prev", function()
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
		bind("EV_Slot" .. i, function()
			InputController.select(i)
		end, key)
	end
	ContextActionService:BindAction("EV_Act", function(_, state)
		if state == Enum.UserInputState.Begin then
			holding = true
			InputController.act()
		elseif state == Enum.UserInputState.End then
			holding = false
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.ButtonR2)
	ContextActionService:BindAction("EV_Quick", function(_, state, input)
		if state == Enum.UserInputState.Begin then
			InputController.quickBegin(input.KeyCode == Enum.KeyCode.F and "key" or "look")
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			InputController.quickEnd()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.F, Enum.KeyCode.DPadDown)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 and not panelOpen() then
			holding = true
			InputController.act()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or (holdTouch and input == holdTouch) then
			holding = false
			holdTouch = nil
		end
		if quickTouch and input == quickTouch then
			quickTouch = nil
			InputController.quickEnd()
		end
	end)
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if acc >= 0.12 then
			acc = 0
			updateButtons()
		end
		if holding and not building then
			InputController.act()
		end
		if quickHold and os.clock() - quickAt >= QUICK_EVERY then
			quickAt = os.clock()
			Bus.Quick:Fire("place")
		end
	end)
	-- no Reset Character in the menu (going down is the game's: the lost bag, the respawn on your raft), and no
	-- Roblox player list on Tab (Tab is the bag; FRIENDS and TOP show who's here)
	task.spawn(function()
		local ok, StarterGui = pcall(game.GetService, game, "StarterGui")
		if ok and StarterGui then
			pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList, false)
		end
		for _ = 1, 30 do
			if ok and StarterGui and pcall(StarterGui.SetCore, StarterGui, "ResetButtonCallback", false) then
				break
			end
			task.wait(1)
		end
	end)
end

-- (tests)
InputController.refs = refs
function InputController.isBuilding()
	return building
end
function InputController.isQuick()
	return quickHold
end

return InputController
