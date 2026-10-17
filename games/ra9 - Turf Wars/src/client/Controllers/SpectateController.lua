--[[
The spectator camera, for an admin watching unseen (the "Spectating" attribute the server sets on you: you have no
body then). Two ways to watch:

  free     fly anywhere, on your own: WASD to move, hold the right mouse button (or lock the mouse) to look, Space up,
           Shift down, Ctrl to go fast, the wheel for speed (on a phone: drag to look, hold FLY to go where you look)
  follow   orbit a player: the right mouse button turns round them, the wheel zooms; ◀ ▶ (or the arrow keys) for
           the next one, F to switch

A bar at the bottom shows who you're watching: ◀ ▶, PLAYERS (a list of everyone in the server: pick one to watch
them) and FREE / FOLLOW. Leaving spectate gives the camera back.

  SpectateController.active()          true while spectating
  SpectateController.mode()            "free" | "follow"
  SpectateController.follow(userId?)   follow this player (or the next one); nil target: the first there is
  SpectateController.free()            back to the free camera
  SpectateController.next(step)        the next (+1) or last (-1) player
  SpectateController.target()          the player followed, or nil
  SpectateController.showList(on)      the PLAYERS list (everyone you can watch)
  SpectateController.step(dt)          (tests: one frame)
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Parent.UI.Theme)
local Layout = require(script.Parent.Parent.UI.Layout)
local Device = require(script.Parent.Parent.UI.Device)

local SpectateController = { Name = "SpectateController", Order = 52 }

local C = Theme.Color
local player = Players.LocalPlayer
local SPEED, FAST = 40, 120
local LOOK = 0.25 -- degrees per pixel of mouse
local ABOVE = 5

local mode = "free"
local followed -- the Player followed
local orbitYaw, orbitPitch, zoom = 0, -18, 14 -- (follow: where the camera sits round them)
local speed = SPEED -- (free: the wheel changes it)
local turning = false -- the right mouse button held: the mouse turns the camera
local heli = 0 -- (nobody to watch: the helicopter's angle round the arena)
local smoothFocus, smoothYaw -- (follow: eased, so their steps and turns don't shake the camera)
local pos = Vector3.new(0, 40, 60)
local yaw, pitch = 0, -25
local flying = false -- (the touch FLY button held)
local was = false
local refs = {}
SpectateController.refs = refs

function SpectateController.active()
	return player:GetAttribute("Spectating") == true
end

function SpectateController.mode()
	return mode
end

function SpectateController.target()
	return followed
end

local function rootOf(p)
	local c = p and p.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

-- the players there are to follow: everyone else with a body
local function others()
	local list = {}
	for _, p in Players:GetPlayers() do
		if p ~= player and rootOf(p) then
			table.insert(list, p)
		end
	end
	table.sort(list, function(a, b)
		return a.UserId < b.UserId
	end)
	return list
end

local fillList -- (the PLAYERS list, built below)

local function label()
	if not refs.name then
		return
	end
	if mode == "follow" and followed then
		refs.name.Text = `WATCHING {string.upper(followed.DisplayName)}`
	elseif mode == "follow" then
		refs.name.Text = "HELICOPTER VIEW (NOBODY ON)"
	else
		refs.name.Text = "FREE CAMERA"
	end
	refs.mode.Label.Text = mode == "follow" and "FREE" or "FOLLOW"
	if refs.list and refs.list.Visible and fillList then
		fillList()
	end
end

function SpectateController.next(step)
	local list = others()
	if #list == 0 then
		followed = nil
		label()
		return nil
	end
	local i = table.find(list, followed) or 0
	i = ((i - 1 + (step or 1)) % #list) + 1
	followed = list[i]
	smoothFocus, smoothYaw = nil, nil
	mode = "follow"
	label()
	return followed
end

function SpectateController.follow(userId)
	mode = "follow"
	local before = followed
	followed = userId and Players:GetPlayerByUserId(userId) or nil
	if followed ~= before then
		orbitYaw, orbitPitch = 0, -18 -- (a new player: start from behind them)
		smoothFocus, smoothYaw = nil, nil
	end
	if not followed or not rootOf(followed) then
		followed = nil
		SpectateController.next(1)
	end
	label()
	return followed
end

function SpectateController.free()
	mode = "free"
	local cam = workspace.CurrentCamera
	if cam then
		-- (start from where the camera is: no jump)
		pos = cam.CFrame.Position
		local look = cam.CFrame.LookVector
		yaw = math.deg(math.atan2(-look.X, -look.Z))
		pitch = math.deg(math.asin(math.clamp(look.Y, -1, 1)))
	end
	label()
end

local function key(k)
	local ok, down = pcall(function()
		return UserInputService:IsKeyDown(k)
	end)
	return ok and down == true
end

local function lookAt()
	return CFrame.Angles(0, math.rad(yaw), 0) * CFrame.Angles(math.rad(pitch), 0, 0)
end

function SpectateController.step(dt)
	local on = SpectateController.active()
	if refs.list and not on and refs.list.Visible then
		SpectateController.showList(false)
	end
	if refs.bar then
		refs.bar.Visible = on
		refs.fly.Visible = on and mode == "free" and Device.isTouch()
	end
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	if not on then
		if was then
			-- (back in the game: the normal camera again)
			was = false
			cam.CameraType = Enum.CameraType.Custom
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				cam.CameraSubject = hum
			end
		end
		return
	end
	if not was then
		was = true
		SpectateController.free()
	end
	cam.CameraType = Enum.CameraType.Scriptable
	-- the mouse turns the camera while the right button is held (the cursor stays put), or while it's locked
	local typing = false
	pcall(function()
		typing = UserInputService:GetFocusedTextBox() ~= nil
	end)
	local menu = Layout.panel() or Layout.modalOpen() or typing
	pcall(function()
		if turning and not menu then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		elseif UserInputService.MouseBehavior == Enum.MouseBehavior.LockCurrentPosition then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
	end)
	local looking = not menu and (turning or UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter)
	local dx, dy = 0, 0
	if looking then
		local ok, delta = pcall(function()
			return UserInputService:GetMouseDelta()
		end)
		if ok and typeof(delta) == "Vector2" then
			dx, dy = delta.X, delta.Y
		end
	end
	if mode == "follow" then
		local r = rootOf(followed)
		if not r then
			SpectateController.next(1)
			r = rootOf(followed)
		end
		if r then
			-- orbit round them: the mouse turns, the wheel zooms, it follows where they face until you turn it
			orbitYaw -= dx * LOOK
			orbitPitch = math.clamp(orbitPitch - dy * LOOK, -70, 30)
			-- (eased: where they are and which way they face both glide, so nothing jitters)
			local face = r.CFrame.LookVector
			local base = math.deg(math.atan2(-face.X, -face.Z))
			local k = 1 - math.exp(-(dt or 1 / 60) * 6)
			if not smoothYaw then
				smoothYaw = base
			end
			smoothYaw += (((base - smoothYaw + 180) % 360) - 180) * k
			local target = r.Position + Vector3.new(0, 2, 0)
			if not smoothFocus or (smoothFocus - target).Magnitude > 30 then
				smoothFocus = target
			end
			smoothFocus = smoothFocus:Lerp(target, 1 - math.exp(-(dt or 1 / 60) * 14))
			local rot = CFrame.Angles(0, math.rad(smoothYaw + orbitYaw), 0) * CFrame.Angles(math.rad(orbitPitch), 0, 0)
			local focus = smoothFocus
			local eye = focus - rot.LookVector * zoom + Vector3.new(0, ABOVE * 0.4, 0)
			cam.CFrame = CFrame.lookAt(eye, focus)
			pos = eye
			return
		end
		-- nobody to watch: a slow helicopter circle high over the whole arena
		heli += (dt or 1 / 60) * 0.06
		local lo = workspace:GetAttribute("LoseRed") or -90
		local hi = workspace:GetAttribute("LoseBlue") or 90
		local span = math.max(60, hi - lo)
		local centre = Vector3.new((lo + hi) / 2, 0, 0)
		local eye = centre + Vector3.new(math.cos(heli) * span * 0.6, span * 0.42, math.sin(heli) * span * 0.45)
		cam.CFrame = CFrame.lookAt(eye, centre)
		pos = eye
		return
	end
	yaw -= dx * LOOK
	pitch = math.clamp(pitch - dy * LOOK, -85, 85)
	local rot = lookAt()
	local move = Vector3.zero
	if not menu or Device.isTouch() then
		if key(Enum.KeyCode.W) or flying then
			move += rot.LookVector
		end
		if key(Enum.KeyCode.S) then
			move -= rot.LookVector
		end
		if key(Enum.KeyCode.D) then
			move += rot.RightVector
		end
		if key(Enum.KeyCode.A) then
			move -= rot.RightVector
		end
		if key(Enum.KeyCode.Space) or key(Enum.KeyCode.E) then
			move += Vector3.new(0, 1, 0)
		end
		if key(Enum.KeyCode.LeftShift) or key(Enum.KeyCode.RightShift) or key(Enum.KeyCode.Q) then
			move -= Vector3.new(0, 1, 0)
		end
	end
	if move.Magnitude > 0.01 then
		local v = (key(Enum.KeyCode.LeftControl) or key(Enum.KeyCode.RightControl)) and math.max(FAST, speed * 3)
			or speed
		pos += move.Unit * v * dt
	end
	cam.CFrame = CFrame.new(pos) * rot
end

local function build(gui)
	local bar = Theme.new("Frame", {
		Name = "SpectateBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(530, 44),
		BackgroundColor3 = C.white,
		BorderSizePixel = 0,
		Visible = false,
		Active = true,
		Parent = gui,
	}, { Theme.corner(4), Theme.stroke(2, C.ink) })
	refs.bar = bar
	local function button(name, text, x, w, onClick)
		local b = Theme.new("TextButton", {
			Name = name,
			Position = UDim2.fromOffset(x, 6),
			Size = UDim2.fromOffset(w, 32),
			BackgroundColor3 = C.ink,
			Text = "",
			AutoButtonColor = true,
			Parent = bar,
		}, { Theme.corner(4) })
		Theme.text({
			Name = "Label",
			Text = text,
			Size = UDim2.new(1, -8, 1, -6),
			Position = UDim2.fromOffset(4, 3),
			fit = 14,
			Font = Theme.Display,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = C.white,
			Parent = b,
		})
		b.Activated:Connect(onClick)
		return b
	end
	refs.prev = button("Prev", "◀", 6, 40, function()
		SpectateController.next(-1)
	end)
	refs.name = Theme.text({
		Name = "Watching",
		Text = "FREE CAMERA",
		Position = UDim2.fromOffset(52, 6),
		Size = UDim2.fromOffset(216, 32),
		fit = 14,
		Font = Theme.Display,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.ink,
		Parent = bar,
	})
	refs.next = button("Next", "▶", 274, 40, function()
		SpectateController.next(1)
	end)
	refs.players = button("Players", "PLAYERS ▲", 320, 104, function()
		SpectateController.showList(not refs.list.Visible)
	end)
	refs.mode = button("Mode", "FOLLOW", 430, 94, function()
		if mode == "follow" then
			SpectateController.free()
		else
			SpectateController.follow(nil)
		end
	end)
	-- the PLAYERS list: everyone in the server, pick one to watch them (or fly free)
	local list = Theme.new("ScrollingFrame", {
		Name = "PlayerList",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -66),
		Size = UDim2.fromOffset(530, 260),
		BackgroundColor3 = C.white,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.fromOffset(0, 0),
		Visible = false,
		Active = true,
		Parent = gui,
	}, { Theme.corner(4), Theme.stroke(2, C.ink) })
	refs.list = list
	-- (on a phone: hold to fly where you look)
	local fly = Theme.new("TextButton", {
		Name = "Fly",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -110, 1, -150),
		Size = UDim2.fromOffset(96, 96),
		BackgroundColor3 = C.ink,
		Text = "FLY",
		Font = Theme.Display,
		TextSize = 18,
		TextColor3 = C.white,
		AutoButtonColor = false,
		Visible = false,
		Parent = gui,
	}, { Theme.corner("round"), Theme.stroke(2, C.ink) })
	fly.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			flying = true
		end
	end)
	fly.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			flying = false
		end
	end)
	refs.fly = fly
end

-- The PLAYERS list: a row each, team colour, alive or down; the one you watch is dark
function fillList()
	local list = refs.list
	if not list then
		return
	end
	for _, c in list:GetChildren() do
		if c:IsA("TextButton") then
			c:Destroy()
		end
	end
	local rows = { { free = true } }
	for _, p in Players:GetPlayers() do
		if p ~= player then
			table.insert(rows, { who = p })
		end
	end
	table.sort(rows, function(a, b)
		if a.free or b.free then
			return a.free == true
		end
		return a.who.DisplayName:lower() < b.who.DisplayName:lower()
	end)
	for i, row in rows do
		local p = row.who
		local on = (row.free and mode == "free") or (p and mode == "follow" and followed == p)
		local team = p and p.Team
		local b = Theme.new("TextButton", {
			Name = row.free and "Free" or ("P_" .. p.UserId),
			Position = UDim2.fromOffset(8, 8 + (i - 1) * 38),
			Size = UDim2.new(1, -22, 0, 32),
			BackgroundColor3 = on and C.ink or C.white,
			Text = "",
			AutoButtonColor = true,
			Parent = list,
		}, { Theme.corner(4), Theme.stroke(1, C.ink) })
		if team then
			Theme.new("Frame", {
				Name = "Team",
				Position = UDim2.fromOffset(6, 6),
				Size = UDim2.fromOffset(6, 20),
				BackgroundColor3 = team.TeamColor.Color,
				BorderSizePixel = 0,
				Parent = b,
			})
		end
		local down = p and not rootOf(p)
		Theme.text({
			Name = "Label",
			Text = row.free and "✈  FREE ROAM (fly anywhere)"
				or `{p.DisplayName}  @{p.Name}{down and "  · down" or ""}{p:GetAttribute("Spectating") and "  · spectating" or ""}`,
			Position = UDim2.fromOffset(20, 3),
			Size = UDim2.new(1, -28, 1, -6),
			fit = 14,
			Font = Theme.Display,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = on and C.white or C.ink,
			Parent = b,
		})
		b.Activated:Connect(function()
			if row.free then
				SpectateController.free()
			else
				SpectateController.follow(p.UserId)
			end
			SpectateController.showList(false)
		end)
	end
	list.CanvasSize = UDim2.fromOffset(0, 16 + #rows * 38)
end

function SpectateController.showList(on)
	if not refs.list then
		return
	end
	refs.list.Visible = on == true and SpectateController.active()
	if refs.players then
		refs.players.Label.Text = refs.list.Visible and "PLAYERS ▼" or "PLAYERS ▲"
	end
	if refs.list.Visible then
		fillList()
	end
end

function SpectateController:init()
	local gui = Theme.screen("Spectate", 6, player:WaitForChild("PlayerGui"))
	refs.gui = gui
	build(gui)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not SpectateController.active() then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			turning = true
			return
		end
		if input.KeyCode == Enum.KeyCode.L or input.KeyCode == Enum.KeyCode.P then
			SpectateController.showList(not refs.list.Visible)
		elseif input.KeyCode == Enum.KeyCode.F then
			if mode == "follow" then
				SpectateController.free()
			else
				SpectateController.follow(nil)
			end
		elseif input.KeyCode == Enum.KeyCode.Right then
			SpectateController.next(1)
		elseif input.KeyCode == Enum.KeyCode.Left then
			SpectateController.next(-1)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			turning = false
		end
	end)
	-- the wheel: zoom when following, flying speed when free
	UserInputService.InputChanged:Connect(function(input, processed)
		if processed or not SpectateController.active() or input.UserInputType ~= Enum.UserInputType.MouseWheel then
			return
		end
		local z = input.Position and input.Position.Z or 0
		if mode == "follow" then
			zoom = math.clamp(zoom - z * 2, 4, 60)
		else
			speed = math.clamp(speed * (z > 0 and 1.25 or 0.8), 8, 400)
		end
	end)
	Players.PlayerAdded:Connect(function()
		if refs.list and refs.list.Visible then
			fillList()
		end
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(function()
			if refs.list and refs.list.Visible then
				fillList()
			end
		end)
	end)
	-- (a phone: drag anywhere off the buttons to look)
	UserInputService.InputChanged:Connect(function(input, processed)
		if processed or not SpectateController.active() or input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local d = input.Delta
		if typeof(d) == "Vector3" then
			yaw -= d.X * LOOK
			pitch = math.clamp(pitch - d.Y * LOOK, -85, 85)
		end
	end)
	local ok = pcall(function()
		RunService:BindToRenderStep("TWSpectate", Enum.RenderPriority.Camera.Value + 2, SpectateController.step)
	end)
	if not ok then
		RunService.RenderStepped:Connect(SpectateController.step)
	end
end

return SpectateController
