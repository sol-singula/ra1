--[[
The spectator camera, for an admin watching unseen (the "Spectating" attribute the server sets on you: you have no
body then). Two ways to watch:

  free     fly anywhere: WASD to move, the mouse to look, Shift to go fast, Q / E down / up (on a phone: drag to
           look, hold FLY to go where you look)
  follow   behind a player, a little above (third person); ◀ ▶ (or the arrow keys) for the next one, F to switch

A small bar at the bottom shows who you're following, with the buttons. Leaving spectate gives the camera back.

  SpectateController.active()          true while spectating
  SpectateController.mode()            "free" | "follow"
  SpectateController.follow(userId?)   follow this player (or the next one); nil target: the first there is
  SpectateController.free()            back to the free camera
  SpectateController.next(step)        the next (+1) or last (-1) player
  SpectateController.target()          the player followed, or nil
  SpectateController.step(dt)          (tests: one frame)
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Parent.UI.Theme)
local Device = require(script.Parent.Parent.UI.Device)
local CameraController = require(script.Parent.CameraController)

local SpectateController = { Name = "SpectateController", Order = 52 }

local C = Theme.Color
local player = Players.LocalPlayer
local SPEED, FAST = 40, 120
local LOOK = 0.25 -- degrees per pixel of mouse
local BEHIND, ABOVE = 12, 5

local mode = "free"
local followed -- the Player followed
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

local function label()
	if not refs.name then
		return
	end
	if mode == "follow" and followed then
		refs.name.Text = `WATCHING {string.upper(followed.DisplayName)}`
	elseif mode == "follow" then
		refs.name.Text = "NOBODY TO WATCH"
	else
		refs.name.Text = "FREE CAMERA"
	end
	refs.mode.Label.Text = mode == "follow" and "FREE" or "FOLLOW"
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
	mode = "follow"
	label()
	return followed
end

function SpectateController.follow(userId)
	mode = "follow"
	followed = userId and Players:GetPlayerByUserId(userId) or nil
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
	-- the mouse looks (first person keeps it locked to the centre while no menu is open)
	if not CameraController.mouseFree() then
		local ok, delta = pcall(function()
			return UserInputService:GetMouseDelta()
		end)
		if ok and typeof(delta) == "Vector2" then
			yaw -= delta.X * LOOK
			pitch = math.clamp(pitch - delta.Y * LOOK, -85, 85)
		end
	end
	if mode == "follow" then
		local r = rootOf(followed)
		if not r then
			SpectateController.next(1)
			r = rootOf(followed)
		end
		if r then
			local back = r.CFrame.LookVector
			local eye = r.Position - back * BEHIND + Vector3.new(0, ABOVE, 0)
			cam.CFrame = CFrame.lookAt(eye, r.Position + Vector3.new(0, 2, 0))
			pos = eye
			return
		end
	end
	local rot = lookAt()
	local move = Vector3.zero
	if not CameraController.mouseFree() or Device.isTouch() then
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
		if key(Enum.KeyCode.E) then
			move += Vector3.new(0, 1, 0)
		end
		if key(Enum.KeyCode.Q) then
			move -= Vector3.new(0, 1, 0)
		end
	end
	if move.Magnitude > 0.01 then
		local speed = key(Enum.KeyCode.LeftShift) and FAST or SPEED
		pos += move.Unit * speed * dt
	end
	cam.CFrame = CFrame.new(pos) * rot
end

local function build(gui)
	local bar = Theme.new("Frame", {
		Name = "SpectateBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(420, 44),
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
	refs.mode = button("Mode", "FOLLOW", 320, 94, function()
		if mode == "follow" then
			SpectateController.free()
		else
			SpectateController.follow(nil)
		end
	end)
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

function SpectateController:init()
	local gui = Theme.screen("Spectate", 6, player:WaitForChild("PlayerGui"))
	refs.gui = gui
	build(gui)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not SpectateController.active() then
			return
		end
		if input.KeyCode == Enum.KeyCode.F then
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
