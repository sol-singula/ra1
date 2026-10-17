--[[
Mission control: the admins' room, high above the arena (an admin's GO TO MISSION CONTROL; AfkService takes them
out of the match while they're here, like the AFK room). The same white as everything else (a plinth, pilasters,
a frieze and a stepped crown molding, a coffered ceiling), with what a launch control room has:

  the front wall   a huge screen: this server live from above (the turf split at the line, every player and bot a
                   dot in their team's colour, the map, the phase and its clock, the score), the MISSION CONTROL sign
                   over it, and four screens round it: the biggest servers of the game (AdminService's list: their
                   map, phase, players, sides)
  the floor        three stepped rows of consoles, five monitors each, every one showing a live number (people
                   on, servers, kills, the turf, the clock...) with a little graph of the last minute
  the side wall    a clock (UTC) and the match clock

It's built the first time an admin comes up (nobody else ever needs it), and its screens only update while someone
is standing in it.

  MissionControlService:Build()      the room (once)
  MissionControlService.ROOM         its floor centre (a CFrame)
  MissionControlService.SPOT         where an admin arrives (at the back, looking at the big screen)
  MissionControlService:Refresh(all) every screen now (all: the server list too; yields for it)
  MissionControlService:Occupied()   someone is standing in the room
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)

local MissionControlService = {
	Name = "MissionControlService",
	Modes = { "turf", "ctf", "brawl" }, -- (a match's: never in the lobby)
	Dependencies = { "MatchService", "TeamService", "ArenaService", "AdminService" },
}

local ROOM = CFrame.new(0, 1000, 0)
MissionControlService.ROOM = ROOM
MissionControlService.SPOT = ROOM * CFrame.new(0, 10.5, 30)
local W, D, H = 96, 72, 40 -- the room: X across, Z deep (the big screen at -Z), height
local INK = Color3.fromRGB(26, 28, 34)
local SCREEN = Color3.fromRGB(12, 16, 24)
local GLOW = Color3.fromRGB(120, 200, 255)

local match, teams, arena, admin
local folder
local screens = {} -- the live pieces: { main = {...}, servers = { ... }, monitors = { ... }, clock = TextLabel }
local history = {} -- [monitor key] = { recent values } (the little graphs)
local servers = {} -- the last list read
local serversAt = 0

-- Building ---------------------------------------------------------------------------------------------------
local function block(size, offset, color, opts)
	opts = opts or {}
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = ROOM * CFrame.new(offset) * (opts.turn or CFrame.identity)
	p.Color = color or Constants.WHITE
	p.Material = opts.material or Enum.Material.SmoothPlastic
	p.CastShadow = opts.shadow ~= false
	if opts.collide == false then
		p.CanCollide = false
		p.CanQuery = false
	end
	if opts.shape then
		p.Shape = opts.shape
	end
	p.Name = opts.name or "Part"
	p.Parent = folder
	return p
end

local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextColor3 = props.color or Color3.fromRGB(230, 238, 248)
	l.Font = props.font or Enum.Font.GothamBold
	l.TextScaled = true
	l.TextXAlignment = props.align or Enum.TextXAlignment.Left
	l.Text = props.text or ""
	l.Size = props.size
	l.Position = props.pos or UDim2.new()
	l.Name = props.name or "Label"
	l.ZIndex = props.z or 2
	l.Parent = parent
	return l
end

local function frame(parent, props)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = props.color or SCREEN
	f.BackgroundTransparency = props.transparency or 0
	f.BorderSizePixel = 0
	f.Size = props.size
	f.Position = props.pos or UDim2.new()
	f.Name = props.name or "Frame"
	f.ZIndex = props.z or 1
	f.Parent = parent
	return f
end

-- A screen: a dark bezel, the glass, a glowing SurfaceGui on its front (facing +Z, toward the room)
local function screen(name, size, offset, canvas, turn)
	local bezel =
		block(Vector3.new(size.X + 0.8, size.Y + 0.8, 0.5), offset, INK, { turn = turn, name = name .. "Bezel" })
	local glass = block(Vector3.new(size.X, size.Y, 0.2), Vector3.zero, SCREEN, { name = name, shadow = false })
	glass.CFrame = bezel.CFrame * CFrame.new(0, 0, 0.3) -- (in front of the bezel, toward the room)
	glass.Material = Enum.Material.Glass
	glass.Reflectance = 0.05
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Screen"
	gui.Face = Enum.NormalId.Back
	gui.CanvasSize = canvas
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	gui.Parent = glass
	frame(gui, { size = UDim2.fromScale(1, 1), color = SCREEN, name = "Back" })
	return gui, glass
end

local function buildShell()
	-- the floor, aisle runners, the walls with their plinth, rail, pilasters, frieze and crown molding
	block(Vector3.new(W, 1, D), Vector3.new(0, -0.5, 0), Constants.LIGHT, { name = "MCFloor" })
	block(Vector3.new(6, 0.06, D - 6), Vector3.new(0, 0.03, 0), Constants.GREY)
	for _, axis in { "x", "z" } do
		for _, side in { -1, 1 } do
			local len = axis == "z" and W or D
			local function band(h, depth, y, color, inset)
				local d = (axis == "z" and D or W) / 2 - inset
				local size = axis == "z" and Vector3.new(len, h, depth) or Vector3.new(depth, h, len)
				local at = axis == "z" and Vector3.new(0, y, side * d) or Vector3.new(side * d, y, 0)
				return block(size, at, color)
			end
			band(H, 1, H / 2, Constants.LIGHT, 0)
			band(1, 1.2, 0.5, Constants.GREY, 0.8)
			band(0.4, 1.4, 1.2, Constants.WHITE, 0.9)
			band(0.5, 0.6, 4.2, Constants.WHITE, 0.7)
			band(1.4, 0.8, H - 4.6, Constants.WHITE, 0.6)
			band(1.6, 0.5, H - 3.1, Constants.GREY, 0.5)
			for i, step in { { 0.5, 1.2 }, { 0.5, 1.8 }, { 0.6, 2.5 }, { 0.6, 3.2 } } do
				band(step[1], step[2], H - 2.2 + i * 0.52, Constants.WHITE, step[2] / 2 - 0.5)
			end
			-- pilasters (the front wall's sit outside the screens)
			local spots = axis == "x" and { -24, -12, 0, 12, 24 }
				or (side < 0 and { -44, 44 } or { -36, -24, -12, 12, 24, 36 })
			for _, t in spots do
				local inner = (axis == "z" and D or W) / 2 - 0.9
				local at = axis == "z" and Vector3.new(t, (H - 5) / 2, side * inner)
					or Vector3.new(side * inner, (H - 5) / 2, t)
				local size = axis == "z" and Vector3.new(2.4, H - 5, 0.9) or Vector3.new(0.9, H - 5, 2.4)
				block(size, at, Constants.WHITE)
			end
		end
	end
	-- the coffered ceiling: a slab, a grid of beams, light panels in the coffers
	block(Vector3.new(W, 1, D), Vector3.new(0, H + 0.5, 0), Constants.WHITE, { name = "MCCeiling" })
	for x = -W / 2 + 12, W / 2 - 12, 12 do
		block(Vector3.new(1.2, 1.4, D), Vector3.new(x, H - 0.7, 0), Constants.WHITE)
	end
	for z = -D / 2 + 12, D / 2 - 12, 12 do
		block(Vector3.new(W, 1.4, 1.2), Vector3.new(0, H - 0.7, z), Constants.WHITE)
	end
	for x = -W / 2 + 18, W / 2 - 18, 24 do
		for z = -D / 2 + 18, D / 2 - 18, 24 do
			local panel = block(Vector3.new(8, 0.2, 8), Vector3.new(x, H - 0.15, z), Color3.fromRGB(235, 245, 255), {
				material = Enum.Material.Neon,
				shadow = false,
				collide = false,
			})
			local l = Instance.new("SurfaceLight")
			l.Face = Enum.NormalId.Bottom
			l.Range = 24
			l.Brightness = 0.7
			l.Angle = 120
			l.Parent = panel
		end
	end
end

local function buildFront()
	local z = -D / 2 + 1.2
	-- the big screen: this server, live
	local gui = screen("MainScreen", Vector3.new(48, 20, 0.5), Vector3.new(0, 21.5, z), Vector2.new(1600, 660))
	local main = { gui = gui, dots = {} }
	main.title = label(
		gui,
		{ text = "", size = UDim2.new(0.7, 0, 0, 64), pos = UDim2.fromOffset(28, 16), font = Enum.Font.GothamBlack }
	)
	main.clock = label(gui, {
		text = "",
		size = UDim2.new(0.3, -28, 0, 64),
		pos = UDim2.new(0.7, 0, 0, 16),
		font = Enum.Font.GothamBlack,
		align = Enum.TextXAlignment.Right,
	})
	main.sub = label(gui, { text = "", size = UDim2.new(1, -56, 0, 34), pos = UDim2.fromOffset(28, 84), color = GLOW })
	local field = frame(gui, {
		size = UDim2.new(1, -56, 1, -150),
		pos = UDim2.fromOffset(28, 130),
		color = Color3.fromRGB(30, 34, 44),
		name = "Field",
	})
	main.field = field
	main.red = frame(
		field,
		{ size = UDim2.fromScale(0.5, 1), color = Constants.TEAM_COLOR.red, transparency = 0.55, name = "Red" }
	)
	main.blue = frame(field, {
		size = UDim2.fromScale(0.5, 1),
		pos = UDim2.fromScale(0.5, 0),
		color = Constants.TEAM_COLOR.blue,
		transparency = 0.55,
		name = "Blue",
	})
	main.line = frame(field, { size = UDim2.new(0, 6, 1, 0), color = Color3.new(1, 1, 1), name = "Line", z = 3 })
	main.dotLayer = frame(field, { size = UDim2.fromScale(1, 1), transparency = 1, name = "Dots", z = 4 })
	screens.main = main
	-- the sign over it
	local sign =
		block(Vector3.new(40, 3.4, 0.6), Vector3.new(0, H - 6.6, z + 0.1), Constants.WHITE, { name = "MCSign" })
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Back
	sg.Parent = sign
	label(sg, {
		text = "MISSION CONTROL",
		size = UDim2.fromScale(1, 1),
		font = Enum.Font.GothamBlack,
		color = INK,
		align = Enum.TextXAlignment.Center,
	})
	-- four screens round it: the biggest servers
	screens.servers = {}
	for i, at in
		{
			Vector3.new(-36, 26, z + 0.6),
			Vector3.new(36, 26, z + 0.6),
			Vector3.new(-36, 15.5, z + 0.6),
			Vector3.new(36, 15.5, z + 0.6),
		}
	do
		local turn = CFrame.Angles(0, math.rad(at.X < 0 and 12 or -12), 0)
		local g = screen("ServerScreen" .. i, Vector3.new(19, 8.4, 0.5), at, Vector2.new(760, 336), turn)
		local s = { gui = g }
		s.title = label(
			g,
			{ text = "", size = UDim2.new(1, -32, 0, 48), pos = UDim2.fromOffset(16, 12), font = Enum.Font.GothamBlack }
		)
		s.sub = label(g, { text = "", size = UDim2.new(1, -32, 0, 32), pos = UDim2.fromOffset(16, 64), color = GLOW })
		local bar = frame(g, {
			size = UDim2.new(1, -32, 0, 26),
			pos = UDim2.fromOffset(16, 108),
			color = Color3.fromRGB(40, 44, 56),
			name = "Bar",
		})
		s.barRed = frame(bar, { size = UDim2.fromScale(0.5, 1), color = Constants.TEAM_COLOR.red, name = "Red" })
		s.barBlue = frame(bar, {
			size = UDim2.fromScale(0.5, 1),
			pos = UDim2.fromScale(0.5, 0),
			color = Constants.TEAM_COLOR.blue,
			name = "Blue",
		})
		s.names = label(
			g,
			{ text = "", size = UDim2.new(1, -32, 0, 150), pos = UDim2.fromOffset(16, 150), font = Enum.Font.Gotham }
		)
		s.names.TextYAlignment = Enum.TextYAlignment.Top
		s.names.TextWrapped = true
		screens.servers[i] = s
	end
end

-- The consoles: three stepped rows of desks, five monitors each
local MONITORS = {
	{
		"PEOPLE IN THIS SERVER",
		function()
			return #match:People()
		end,
	},
	{
		"PEOPLE IN EVERY SERVER",
		function()
			local n = 0
			for _, s in servers do
				n += s.players or 0
			end
			return math.max(n, #match:People())
		end,
	},
	{
		"LIVE SERVERS",
		function()
			return math.max(#servers, 1)
		end,
	},
	{
		`{Constants.TEAM_NAME.red} ON THE FIELD`, -- (the side's name in this mode: Data/Modes)
		function()
			return teams:Count("red")
		end,
	},
	{
		`{Constants.TEAM_NAME.blue} ON THE FIELD`,
		function()
			return teams:Count("blue")
		end,
	},
	{
		"THE LINE (X)",
		function()
			return math.floor(match:Frontline())
		end,
	},
	{
		"SECONDS LEFT IN PHASE",
		function()
			return math.max(0, math.floor((workspace:GetAttribute("PhaseEnds") or 0) - workspace:GetServerTimeNow()))
		end,
	},
	{
		"BOTS PLAYING",
		function()
			return #match:Everyone() - #match:People()
		end,
	},
}

local function buildConsoles()
	screens.monitors = {}
	local rows = { { z = -14, y = 0 }, { z = -2, y = 1.2 }, { z = 10, y = 2.4 } }
	local n = 0
	for _, row in rows do
		if row.y > 0 then
			block(Vector3.new(W - 10, row.y, 12), Vector3.new(0, row.y / 2, row.z + 1), Constants.WHITE) -- the step
			block(Vector3.new(W - 10, 0.3, 0.4), Vector3.new(0, row.y + 0.15, row.z - 5), Constants.GREY) -- its nosing
		end
		local base = row.y
		-- the desk: a long white body with a dark top
		block(Vector3.new(60, 2.6, 2.4), Vector3.new(0, base + 1.3, row.z - 2), Constants.WHITE)
		block(Vector3.new(60.6, 0.3, 3), Vector3.new(0, base + 2.75, row.z - 2), INK)
		for i = 1, 5 do
			n += 1
			local x = (i - 3) * 12
			local tilt = CFrame.Angles(math.rad(-12), 0, 0)
			local g = screen(
				"Monitor" .. n,
				Vector3.new(7, 4, 0.3),
				Vector3.new(x, base + 5.1, row.z - 2.8),
				Vector2.new(420, 240),
				tilt
			)
			block(Vector3.new(0.5, 1.6, 0.5), Vector3.new(x, base + 3.6, row.z - 2.6), INK) -- the stand
			local spec = MONITORS[(n - 1) % #MONITORS + 1]
			local m = { key = n, spec = spec, bars = {} }
			label(g, { text = spec[1], size = UDim2.new(1, -24, 0, 30), pos = UDim2.fromOffset(12, 10), color = GLOW })
			m.value = label(g, {
				text = "–",
				size = UDim2.new(1, -24, 0, 92),
				pos = UDim2.fromOffset(12, 44),
				font = Enum.Font.GothamBlack,
			})
			local graph = frame(g, {
				size = UDim2.new(1, -24, 0, 70),
				pos = UDim2.fromOffset(12, 156),
				color = Color3.fromRGB(24, 30, 42),
				name = "Graph",
			})
			for b = 1, 24 do
				m.bars[b] = frame(graph, {
					size = UDim2.new(1 / 24, -2, 0, 2),
					pos = UDim2.new((b - 1) / 24, 1, 1, -2),
					color = GLOW,
					name = "Bar" .. b,
				})
			end
			screens.monitors[n] = m
			-- a chair
			block(Vector3.new(2.6, 0.5, 2.6), Vector3.new(x, base + 1.6, row.z + 1.6), Constants.GREY)
			block(Vector3.new(2.6, 2.6, 0.4), Vector3.new(x, base + 3, row.z + 2.9), Constants.GREY)
			block(Vector3.new(0.4, 1.4, 0.4), Vector3.new(x, base + 0.7, row.z + 1.6), INK)
		end
	end
	-- the admins' landing at the back, a step up, with a rail
	block(Vector3.new(30, 7, 10), Vector3.new(0, 3.5, 30.5), Constants.WHITE)
	block(Vector3.new(30.4, 0.4, 0.6), Vector3.new(0, 7.1, 25.4), Constants.GREY) -- (its nosing)
	block(Vector3.new(30, 0.4, 0.4), Vector3.new(0, 10, 25.8), Constants.GREY)
	for _, x in { -14, -7, 0, 7, 14 } do
		block(Vector3.new(0.4, 3, 0.4), Vector3.new(x, 8.5, 25.8), Constants.WHITE)
	end
	-- stairs up to it, at both ends
	for _, sx in { -1, 1 } do
		for i = 1, 6 do
			block(Vector3.new(4, i * 1.15, 1.6), Vector3.new(sx * 17, i * 0.575, 24 + i * 1.5), Constants.WHITE)
		end
	end
end

local function buildClock()
	local g = screen(
		"ClockScreen",
		Vector3.new(14, 5, 0.3),
		Vector3.new(W / 2 - 1.4, 20, 0),
		Vector2.new(560, 200),
		CFrame.Angles(0, math.rad(-90), 0)
	)
	screens.clock = label(g, {
		text = "",
		size = UDim2.new(1, -32, 0, 110),
		pos = UDim2.fromOffset(16, 14),
		font = Enum.Font.GothamBlack,
		align = Enum.TextXAlignment.Center,
	})
	screens.clockSub = label(g, {
		text = "UTC",
		size = UDim2.new(1, -32, 0, 44),
		pos = UDim2.fromOffset(16, 130),
		color = GLOW,
		align = Enum.TextXAlignment.Center,
	})
end

function MissionControlService:Build()
	if folder and folder.Parent then
		return folder
	end
	folder = Instance.new("Folder")
	folder.Name = "MissionControl"
	buildShell()
	buildFront()
	buildConsoles()
	buildClock()
	folder.Parent = workspace
	self:Refresh(false)
	return folder
end

-- Updating -----------------------------------------------------------------------------------------------------
function MissionControlService:Occupied()
	if not folder then
		return false
	end
	for _, p in Players:GetPlayers() do
		local c = p.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if r and (r.Position - ROOM.Position).Magnitude < 90 then
			return true
		end
	end
	return false
end

local function clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function updateMain()
	local main = screens.main
	local a = arena:Current()
	if not main or not a then
		return
	end
	local def = Maps.get(match:MapKey())
	local phase = match:Phase()
	main.title.Text = `THIS SERVER · {string.upper(def and def.name or "?")}`
	main.clock.Text =
		`{string.upper(phase)} {clock((workspace:GetAttribute("PhaseEnds") or 0) - workspace:GetServerTimeNow())}`
	main.sub.Text =
		`{#match:People()} PEOPLE · {#match:Everyone() - #match:People()} BOTS · RED {teams:Count("red")} · BLUE {teams:Count(
			"blue"
		)}{workspace:GetAttribute("Charge") and " · CHARGE!" or ""}`
	local half, width = a.half, a.width
	local f = math.clamp((match:Frontline() + half) / (2 * half), 0, 1)
	main.red.Size = UDim2.fromScale(f, 1)
	main.blue.Position = UDim2.fromScale(f, 0)
	main.blue.Size = UDim2.fromScale(1 - f, 1)
	main.line.Position = UDim2.new(f, -3, 0, 0)
	local seen = {}
	for _, who in match:Everyone() do
		local c = who.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		local team = teams:Team(who)
		if r and team then
			seen[who] = true
			local dot = main.dots[who]
			if not dot then
				dot = frame(
					main.dotLayer,
					{ size = UDim2.fromOffset(18, 18), color = Constants.TEAM_COLOR[team], name = "Dot", z = 5 }
				)
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(1, 0)
				corner.Parent = dot
				local stroke = Instance.new("UIStroke")
				stroke.Color = Color3.new(1, 1, 1)
				stroke.Thickness = 2
				stroke.Parent = dot
				label(dot, {
					text = who.DisplayName,
					size = UDim2.fromOffset(160, 20),
					pos = UDim2.fromOffset(-71, -22),
					align = Enum.TextXAlignment.Center,
					z = 6,
				})
				main.dots[who] = dot
			end
			dot.BackgroundColor3 = Constants.TEAM_COLOR[team]
			local x = math.clamp((r.Position.X + half) / (2 * half), 0, 1)
			local y = math.clamp((r.Position.Z + width / 2) / width, 0, 1)
			dot.Position = UDim2.new(x, -9, y, -9)
		end
	end
	for who, dot in main.dots do
		if not seen[who] then
			dot:Destroy()
			main.dots[who] = nil
		end
	end
end

local function updateServers()
	local list = {}
	for _, s in servers do
		table.insert(list, s)
	end
	if #list == 0 then
		local ok, info = pcall(admin.Info, admin)
		if ok and info then
			info.here = true
			table.insert(list, info)
		end
	end
	for i, sc in screens.servers or {} do
		local s = list[i]
		if s then
			sc.title.Text = `{s.here and "THIS SERVER" or ("SERVER " .. i)} · {s.players or 0} ON`
			sc.sub.Text = `{string.upper(s.map or "?")} · {string.upper(s.phase or "?")}`
			local red, blue = s.red or 0, s.blue or 0
			local share = (red + blue) > 0 and red / (red + blue) or 0.5
			sc.barRed.Size = UDim2.fromScale(share, 1)
			sc.barBlue.Position = UDim2.fromScale(share, 0)
			sc.barBlue.Size = UDim2.fromScale(1 - share, 1)
			sc.names.Text = table.concat(s.names or {}, "  ·  ")
		else
			sc.title.Text = "NO SIGNAL"
			sc.sub.Text = "no other server is on right now"
			sc.names.Text = ""
		end
	end
end

local function updateMonitors()
	for _, m in screens.monitors or {} do
		local ok, v = pcall(m.spec[2])
		v = ok and tonumber(v) or 0
		m.value.Text = tostring(v)
		local h = history[m.key] or {}
		history[m.key] = h
		table.insert(h, v)
		while #h > #m.bars do
			table.remove(h, 1)
		end
		local top = 1
		for _, x in h do
			top = math.max(top, x)
		end
		for b, bar in m.bars do
			local x = h[b - (#m.bars - #h)]
			local share = x and math.max(0.03, x / top) or 0.03
			bar.Size = UDim2.new(1 / #m.bars, -2, share, 0)
			bar.Position = UDim2.new((b - 1) / #m.bars, 1, 1 - share, 0)
		end
	end
	if screens.clock then
		screens.clock.Text = os.date("!%H:%M:%S")
		screens.clockSub.Text = `UTC · MATCH {workspace:GetAttribute("MatchId") or "?"}`
	end
end

function MissionControlService:Refresh(all)
	if not folder then
		return false
	end
	if all then
		local ok, list = pcall(admin.Servers, admin)
		if ok and type(list) == "table" then
			servers = list
			serversAt = os.clock()
		end
	end
	pcall(updateMain)
	pcall(updateServers)
	pcall(updateMonitors)
	return true
end

function MissionControlService:Init(registry)
	match = registry.MatchService
	teams = registry.TeamService
	arena = registry.ArenaService
	admin = registry.AdminService
end

function MissionControlService:Start()
	local slow, fast = 0, 0
	RunService.Heartbeat:Connect(function()
		if not folder or not self:Occupied() then
			return
		end
		local t = os.clock()
		if t - fast >= 0.25 then
			fast = t
			pcall(updateMain)
		end
		if t - slow >= 1 then
			slow = t
			pcall(updateMonitors)
			if t - serversAt >= 15 then
				serversAt = t
				task.spawn(function()
					self:Refresh(true)
				end)
			end
		end
	end)
end

return MissionControlService
