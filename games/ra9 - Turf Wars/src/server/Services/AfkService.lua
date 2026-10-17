--[[
The AFK limbo: nobody can stall a match by standing still. A player who doesn't move, shoot, swing or build for
AFK_SECONDS while a match is on is taken out of it (no team, not counted, never hit: Admins.spectating says so for
the "Limbo" attribute) and moved to a white hall floating high above the arena (columns, crown molding, lamps, and leaderboards), with a banner: "You're AFK.
Walk around to jump back in!". The moment they walk AFK_RETURN_STUDS in there, they're back: a team the normal way
(MatchService:Join), a spawn, "Welcome back!". Bots fill in for them meanwhile (BotService counts people the same way).

  AfkService:Away(player)      -> bool
  AfkService:Send(player)      off to limbo now (tests, an admin)
  AfkService:Return(player)    back into the match now
  AfkService:Send(player, { stay = true })   an admin visiting: walking around doesn't bring them back
  AfkService:RefreshBoards()   the hall's three leaderboards (every 30 s on its own)
  AfkService.ROOM              the limbo room's floor centre (a CFrame)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Notify = require(script.Parent.Parent.Notify)
local Admins = require(script.Parent.Parent.Admins)

local AfkService = {
	Name = "AfkService",
	Dependencies = { "MatchService", "TeamService", "CombatService", "BuildService" },
}

AfkService.ROOM = CFrame.new(0, 600, 0)

local match, teams, combat, build, registryRef
local watch = {} -- [player] = { pos, at, limboAt }

local function now()
	return workspace:GetServerTimeNow()
end

local function root(player)
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function active(player)
	local w = watch[player]
	if w then
		w.at = now()
	end
end

-- The room: a white hall like the arenas' (a plinth, columns with bases and capitals, a wainscot rail, a frieze and a
-- stepped crown molding), lamps, team banners, the AFK banner, and three leaderboards on the far wall
local HALF = 36 -- the floor is 72 x 72
local HIGH = 24 -- the walls
local INK = Color3.fromRGB(30, 30, 34)
local boards = {} -- [board key] = { list = the rows' Frame, title = TextLabel }
AfkService.BOARD_KEYS = { "kills", "wins", "mvps" }

local function buildRoom()
	local folder = Instance.new("Folder")
	folder.Name = "Limbo"
	local function block(size, offset, color, opts)
		opts = opts or {}
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = size
		p.CFrame = AfkService.ROOM * CFrame.new(offset) * (opts.turn or CFrame.identity)
		p.Color = color or Constants.WHITE
		p.Material = opts.material or Enum.Material.SmoothPlastic
		p.Transparency = opts.transparency or 0
		p.CastShadow = opts.shadow ~= false
		if opts.shape then
			p.Shape = opts.shape
		end
		if opts.collide == false then
			p.CanCollide = false
			p.CanQuery = false
		end
		if opts.name then
			p.Name = opts.name
		end
		p.Parent = folder
		return p
	end
	local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- (a cylinder's axis is X: stand it up)

	-- the floor: a slab, a grey inlaid border, a medallion where you arrive
	local floor = block(Vector3.new(HALF * 2, 1, HALF * 2), Vector3.new(0, -0.5, 0))
	floor.Name = "LimboFloor"
	for _, side in { -1, 1 } do
		block(Vector3.new(HALF * 2 - 8, 0.05, 1), Vector3.new(0, 0.02, side * (HALF - 4)), Constants.GREY)
		block(Vector3.new(1, 0.05, HALF * 2 - 8), Vector3.new(side * (HALF - 4), 0.02, 0), Constants.GREY)
	end
	block(
		Vector3.new(0.1, 16, 16),
		Vector3.new(0, 0.03, 0),
		Constants.LIGHT,
		{ turn = UPRIGHT, shape = Enum.PartType.Cylinder }
	)
	block(
		Vector3.new(0.1, 13, 13),
		Vector3.new(0, 0.05, 0),
		Constants.WHITE,
		{ turn = UPRIGHT, shape = Enum.PartType.Cylinder }
	)
	-- a glowing ring on the medallion: walk off it to go back
	local ring = block(Vector3.new(0.1, 10, 10), Vector3.new(0, 0.07, 0), Color3.fromRGB(120, 120, 130), {
		turn = UPRIGHT,
		shape = Enum.PartType.Cylinder,
		material = Enum.Material.Neon,
		transparency = 0.4,
		collide = false,
	})
	ring.Name = "LimboRing"
	block(Vector3.new(0.1, 9, 9), Vector3.new(0, 0.08, 0), Constants.WHITE, {
		turn = UPRIGHT,
		shape = Enum.PartType.Cylinder,
		collide = false,
	})

	-- the walls, each with its plinth, wainscot rail, frieze and crown molding (four steps out)
	for _, axis in { "x", "z" } do
		for _, side in { -1, 1 } do
			local function along(len, h, depth, y, inset)
				local size = axis == "z" and Vector3.new(len, h, depth) or Vector3.new(depth, h, len)
				local d = HALF - inset
				local at = axis == "z" and Vector3.new(0, y, side * d) or Vector3.new(side * d, y, 0)
				return size, at
			end
			local function band(h, depth, y, color, inset)
				local size, at = along(HALF * 2, h, depth, y, inset)
				return block(size, at, color)
			end
			band(HIGH, 1, HIGH / 2, Constants.LIGHT, 0) -- the wall
			band(1, 1.2, 0.5, Constants.GREY, 0.8) -- the plinth
			band(0.4, 1.4, 1.2, Constants.WHITE, 0.9)
			band(0.5, 0.6, 4.2, Constants.WHITE, 0.7) -- the wainscot rail
			band(1.4, 0.8, HIGH - 4.6, Constants.WHITE, 0.6) -- the architrave
			band(1.6, 0.5, HIGH - 3.1, Constants.GREY, 0.5) -- the frieze
			for i, step in { { 0.5, 1.2 }, { 0.5, 1.8 }, { 0.6, 2.5 }, { 0.6, 3.2 } } do
				band(step[1], step[2], HIGH - 2.2 + i * 0.52, Constants.WHITE, step[2] / 2 - 0.5) -- the crown molding
			end
		end
	end

	-- columns along the walls, corner pilasters
	local function column(x, z)
		block(Vector3.new(3.4, 1, 3.4), Vector3.new(x, 0.5, z), Constants.GREY)
		block(
			Vector3.new(0.6, 3, 3),
			Vector3.new(x, 1.3, z),
			Constants.WHITE,
			{ turn = UPRIGHT, shape = Enum.PartType.Cylinder }
		)
		local shaft = HIGH - 7.4
		block(Vector3.new(shaft, 2.2, 2.2), Vector3.new(x, 1.6 + shaft / 2, z), Constants.WHITE, {
			turn = UPRIGHT,
			shape = Enum.PartType.Cylinder,
		})
		block(Vector3.new(0.5, 2.8, 2.8), Vector3.new(x, 1.6 + shaft + 0.25, z), Constants.WHITE, {
			turn = UPRIGHT,
			shape = Enum.PartType.Cylinder,
		})
		block(Vector3.new(3.4, 0.6, 3.4), Vector3.new(x, 1.6 + shaft + 0.8, z), Constants.WHITE)
	end
	local inner = HALF - 2.6
	for _, x in { -24, 24 } do
		column(x, -inner) -- the far wall (the boards fill its middle)
	end
	for _, t in { -24, -12, 0, 12, 24 } do
		column(-inner, t)
		column(inner, t)
		column(t, inner)
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			block(
				Vector3.new(3, HIGH - 5, 3),
				Vector3.new(sx * (HALF - 2), (HIGH - 5) / 2, sz * (HALF - 2)),
				Constants.WHITE
			)
		end
	end

	-- team banners between the side columns, red on the left, blue on the right
	for _, sx in { -1, 1 } do
		local color = sx < 0 and Constants.TEAM_COLOR.red or Constants.TEAM_COLOR.blue
		for _, t in { -18, -6, 6, 18 } do
			block(Vector3.new(0.3, 0.4, 5), Vector3.new(sx * (HALF - 1.2), HIGH - 6.4, t), Constants.GREY)
			block(Vector3.new(0.2, 9, 4.2), Vector3.new(sx * (HALF - 1.1), HIGH - 11.2, t), color)
			block(Vector3.new(0.25, 1.2, 4.2), Vector3.new(sx * (HALF - 1.05), HIGH - 15.4, t), Constants.WHITE)
		end
	end

	-- four lamps round the medallion
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local x, z = sx * 12, sz * 12
			block(Vector3.new(2.2, 0.6, 2.2), Vector3.new(x, 0.3, z), Constants.GREY)
			block(Vector3.new(7, 0.6, 0.6), Vector3.new(x, 4, z), Constants.WHITE, {
				turn = UPRIGHT,
				shape = Enum.PartType.Cylinder,
			})
			local globe = block(Vector3.new(1.8, 1.8, 1.8), Vector3.new(x, 8.2, z), Color3.fromRGB(255, 244, 220), {
				shape = Enum.PartType.Ball,
				material = Enum.Material.Neon,
				shadow = false,
			})
			block(Vector3.new(2.2, 0.3, 2.2), Vector3.new(x, 7.2, z), Constants.GREY)
			local light = Instance.new("PointLight")
			light.Range = 22
			light.Brightness = 0.8
			light.Color = Color3.fromRGB(255, 240, 215)
			light.Parent = globe
		end
	end

	-- the AFK banner, high on the far wall
	local sign = block(
		Vector3.new(44, 4, 0.5),
		Vector3.new(0, HIGH - 7.5, -(HALF - 0.8)),
		Constants.WHITE,
		{ name = "LimboSign" }
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "YOU'RE AFK · WALK AROUND TO JUMP BACK IN!"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = INK
	label.Parent = gui

	-- three leaderboards under it, framed, between the columns
	for i, key in AfkService.BOARD_KEYS do
		local x = (i - 2) * 15
		local z = -(HALF - 0.8)
		block(Vector3.new(12.6, 11.6, 0.6), Vector3.new(x, 8.2, z + 0.1), Constants.GREY) -- the frame
		local board = block(Vector3.new(11.6, 10.6, 0.4), Vector3.new(x, 8.2, z + 0.4), Constants.WHITE, {
			name = "LimboBoard_" .. key,
		})
		block(Vector3.new(13, 0.6, 1.2), Vector3.new(x, 2.3, z + 0.5), Constants.WHITE) -- the sill
		local g = Instance.new("SurfaceGui")
		g.Name = "Board"
		g.Face = Enum.NormalId.Back
		g.CanvasSize = Vector2.new(580, 530)
		g.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		g.Parent = board
		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Size = UDim2.new(1, 0, 0, 70)
		title.BackgroundColor3 = INK
		title.TextColor3 = Constants.WHITE
		title.Font = Enum.Font.GothamBlack
		title.TextScaled = true
		title.Text = string.upper(key)
		title.Parent = g
		local sub = Instance.new("TextLabel")
		sub.Name = "Sub"
		sub.Position = UDim2.new(0, 0, 0, 72)
		sub.Size = UDim2.new(1, 0, 0, 30)
		sub.BackgroundTransparency = 1
		sub.TextColor3 = Constants.DARK
		sub.Font = Enum.Font.GothamBold
		sub.TextScaled = true
		sub.Text = "ALL TIME"
		sub.Parent = g
		local list = Instance.new("Frame")
		list.Name = "Rows"
		list.Position = UDim2.new(0, 16, 0, 108)
		list.Size = UDim2.new(1, -32, 1, -116)
		list.BackgroundTransparency = 1
		list.Parent = g
		boards[key] = { list = list, title = title, sub = sub }
	end
	folder.Parent = workspace
end

local function setRows(b, rows)
	for _, c in b.list:GetChildren() do
		c:Destroy()
	end
	if #rows == 0 then
		local none = Instance.new("TextLabel")
		none.Name = "Empty"
		none.Size = UDim2.new(1, 0, 0, 40)
		none.BackgroundTransparency = 1
		none.TextColor3 = Constants.DARK
		none.Font = Enum.Font.GothamBold
		none.TextScaled = true
		none.Text = "No one yet. Be the first!"
		none.Parent = b.list
		return
	end
	for i = 1, math.min(10, #rows) do
		local r = rows[i]
		local line = Instance.new("TextLabel")
		line.Name = "Row" .. i
		line.Position = UDim2.new(0, 0, 0, (i - 1) * 42)
		line.Size = UDim2.new(1, 0, 0, 38)
		line.ClipsDescendants = true
		line.BackgroundColor3 = i % 2 == 1 and Color3.fromRGB(232, 232, 230) or Constants.WHITE
		line.TextColor3 = i == 1 and Color3.fromRGB(190, 140, 20) or INK
		line.Font = i <= 3 and Enum.Font.GothamBlack or Enum.Font.GothamBold
		line.TextScaled = true
		line.TextXAlignment = Enum.TextXAlignment.Left
		line.Text = `  {i}.  {r.name}`
		line.Parent = b.list
		local value = Instance.new("TextLabel")
		value.Name = "Value"
		value.Size = UDim2.new(0.3, -10, 1, 0)
		value.Position = UDim2.new(0.7, 0, 0, 0)
		value.BackgroundTransparency = 1
		value.TextColor3 = line.TextColor3
		value.Font = Enum.Font.GothamBlack
		value.TextScaled = true
		value.TextXAlignment = Enum.TextXAlignment.Right
		value.Text = tostring(r.value)
		value.Parent = line
	end
end

-- The boards: the all-time top 10 (LeaderboardService), or this server's best while the all-time read is empty
function AfkService:RefreshBoards()
	local lb = registryRef and registryRef.LeaderboardService
	local payload = lb and lb.Payload and lb:Payload(nil)
	for key, b in boards do
		local rows = payload and payload.boards and payload.boards[key] or {}
		local sub = "ALL TIME"
		if #rows == 0 and payload and payload.server then
			rows, sub = payload.server[key] or {}, "THIS SERVER"
		end
		b.sub.Text = sub
		setRows(b, rows)
	end
	return payload ~= nil
end

function AfkService:Away(player)
	return player:GetAttribute("Limbo") == true
end

function AfkService:Send(player, opts)
	if self:Away(player) or not player.Parent then
		return false
	end
	player:SetAttribute("Limbo", true)
	teams:Clear(player)
	match:Leave(player)
	local r = root(player)
	if r then
		local spot = AfkService.ROOM * CFrame.new(0, 3, 0)
		local ok = pcall(function()
			player.Character:PivotTo(spot)
		end)
		if not ok or (r.Position - spot.Position).Magnitude > 5 then
			r.CFrame = spot
		end
		player:SetAttribute("AcGrace", os.clock() + 3) -- (the anti-cheat lets the jump up go; it reads os.clock)
	end
	local w = watch[player] or {}
	watch[player] = w
	w.limboAt = r and flat(AfkService.ROOM.Position) or nil
	w.at = now()
	w.stay = opts and opts.stay or nil -- (an admin visiting: walking doesn't send them back)
	if not w.stay then
		Notify.to(player, "You're AFK. Walk around to jump back in!", "info", { icon = "💤", seconds = 5 })
	end
	return true
end

function AfkService:Return(player)
	if not self:Away(player) then
		return false
	end
	player:SetAttribute("Limbo", nil)
	local w = watch[player]
	if w then
		w.limboAt, w.at, w.pos, w.stay = nil, now(), nil, nil
	end
	match:Join(player) -- (a team the normal way, and a spawn)
	Notify.to(player, "Welcome back!", "start", { icon = "⚔️", seconds = 2.5 })
	return true
end

function AfkService:_check()
	local phase = match:Phase()
	local on = Constants.AFK_SECONDS > 0 and (phase == "build" or phase == "fight")
	for _, player in Players:GetPlayers() do
		local w = watch[player]
		if not w then
			w = { at = now() }
			watch[player] = w
		end
		local r = root(player)
		if self:Away(player) then
			-- in limbo: walking around brings them back
			local from = w.limboAt or (r and flat(r.Position))
			w.limboAt = from
			if not w.stay and r and from and (flat(r.Position) - from).Magnitude >= Constants.AFK_RETURN_STUDS then
				self:Return(player)
			end
		elseif r then
			local p = flat(r.Position)
			if not w.pos or (p - w.pos).Magnitude > 2 then
				w.pos, w.at = p, now()
			end
			-- (a spectating admin is never sent; nor anyone while no match is on)
			if on and not Admins.spectating(player) and now() - w.at >= Constants.AFK_SECONDS then
				self:Send(player)
			end
		else
			w.at = math.max(w.at, now() - Constants.AFK_SECONDS / 2) -- (dead or loading isn't idling)
		end
	end
end

function AfkService:Init(registry)
	match = registry.MatchService
	teams = registry.TeamService
	combat = registry.CombatService
	build = registry.BuildService
	registryRef = registry -- (LeaderboardService, for the boards: looked up when used, never a dependency)
end

function AfkService:Start()
	buildRoom()
	pcall(self.RefreshBoards, self)
	combat.Shot:Connect(active)
	build.Built:Connect(active)
	Players.PlayerRemoving:Connect(function(player)
		watch[player] = nil
	end)
	local ticks = 0
	while true do
		task.wait(1)
		pcall(self._check, self)
		ticks += 1
		if ticks % 30 == 0 then
			pcall(self.RefreshBoards, self)
		end
	end
end

return AfkService
