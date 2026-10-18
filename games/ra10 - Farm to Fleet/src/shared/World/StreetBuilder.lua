--[[
What the street shows everyone (master plan §13.4): two big gantries over the road between the plots, and a
billboard over each plot's gate.

  the STREET board      (between plots 1|2 and 4|5) every operation on this server ranked live: Size, Cash a minute,
                        deliveries a minute, the biggest shipment today; along the bottom the street's biggest
                        shipment of the day
  the HALL OF FAME      (between plots 2|3 and 5|6) the top farms of every server: all-time Cash, the biggest
                        shipment ever, the franchise level (LeaderboardService)
  plot billboards       the owner's name and their numbers, likes, "MOST LIKED", the franchise stars

  StreetBuilder.gantry(parent, x, name, color) -> { faces = { Part, Part } }  a board facing each way along the road
  StreetBuilder.fill(gantry, title, header, rows, footer)   rows = { { "1", "Ava", "1.2K", ... }, ... } (up to 6)
  StreetBuilder.billboard(part, name, lines, color, tag?)   the BillboardGui over a gate
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Shapes = require(script.Parent.Shapes)

local StreetBuilder = {}

local P = Constants.PALETTE
local INK = Color3.fromRGB(28, 30, 36)
local WHITE = Color3.fromRGB(250, 250, 248)
local STEEL = Color3.fromRGB(120, 126, 136)
StreetBuilder.HEIGHT = 26 -- the board's underside (semis pass under)
StreetBuilder.ROWS = 6
StreetBuilder.COLUMNS = { 0.06, 0.34, 0.1, 0.14, 0.14, 0.22 } -- rank, name, size, cash/min, deliveries/min, best

function StreetBuilder.gantry(parent, x, name, color)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	local s = Shapes.new(folder, CFrame.new(x, 0, 0))
	local H = StreetBuilder.HEIGHT
	-- two lattice towers on the verges (in the gap between the plots), a truss across the road
	for _, z in { -21.5, 21.5 } do
		s:block(0, z, 2.6, 2.6, 0.6, { color = P.concrete or STEEL, name = "Footing" }, 0)
		s:box(0, (H + 14) / 2, z, 1.4, H + 14, 1.4, { color = STEEL, name = "Tower" })
		for y = 4, H + 8, 6 do
			s:box(0, y, z, 1.8, 0.4, 1.8, { color = STEEL, name = "Ring" })
		end
	end
	s:box(0, H + 13, 0, 1.6, 1.6, 46, { color = STEEL, name = "Truss" })
	s:box(0, H - 0.8, 0, 1.2, 1.2, 46, { color = STEEL, name = "Truss" })
	local faces = {}
	for i, dir in { 1, -1 } do
		-- the board: a dark panel with a coloured frame, one face toward each end of the road
		local board = s:box(dir * 1.2, H + 6, 0, 0.6, 12, 36, { color = INK, name = "Board" })
		s:box(dir * 1.4, H + 12.4, 0, 0.4, 0.8, 37, Shapes.deco({ color = color, name = "Frame" }))
		s:box(dir * 1.4, H - 0.4, 0, 0.4, 0.8, 37, Shapes.deco({ color = color, name = "Frame" }))
		board.Name = "Face" .. i
		board:SetAttribute("Board", name)
		board:SetAttribute("Side", dir)
		faces[i] = board
	end
	-- (the board's lights along the truss)
	for z = -15, 15, 10 do
		s:box(
			0,
			H + 12.6,
			z,
			2.4,
			0.5,
			1.2,
			Shapes.deco({ color = WHITE, material = Enum.Material.Neon, name = "Lamp" })
		)
	end
	return { folder = folder, faces = faces }
end

local function label(gui, name, text, x, y, w, h, color, cap, align)
	local l = gui:FindFirstChild(name) or Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromScale(x, y)
	l.Size = UDim2.fromScale(w, h)
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.TextColor3 = color
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.Text = text
	l.Parent = gui
	local k = l:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
	k.MaxTextSize = cap
	k.Parent = l
	return l
end

function StreetBuilder.fill(gantry, title, header, rows, footer, color)
	for _, face in gantry.faces do
		local gui = face:FindFirstChild("Board") or Instance.new("SurfaceGui")
		gui.Name = "Board"
		-- (the board stands across the road: its wide faces are Left and Right)
		gui.Face = face:GetAttribute("Side") == 1 and Enum.NormalId.Right or Enum.NormalId.Left
		gui.LightInfluence = 0
		gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		gui.CanvasSize = Vector2.new(1800, 600)
		label(gui, "Title", title, 0.03, 0.02, 0.94, 0.16, color or P.sunflower, 90, Enum.TextXAlignment.Center)
		local function row(prefix, cells, y, c, cap)
			local x = 0.03
			for i, w in StreetBuilder.COLUMNS do
				label(gui, prefix .. i, cells[i] or "", x, y, w * 0.94 - 0.005, 0.1, c, cap)
				x += w * 0.94
			end
		end
		row("Head", header, 0.2, Color3.fromRGB(170, 176, 190), 40)
		for r = 1, StreetBuilder.ROWS do
			row("Row" .. r .. "_", rows[r] or {}, 0.2 + r * 0.105, r == 1 and P.sunflower or WHITE, 52)
		end
		label(gui, "Footer", footer or "", 0.03, 0.9, 0.94, 0.08, color or P.sunflower, 44, Enum.TextXAlignment.Center)
		gui.Parent = face
	end
end

function StreetBuilder.billboard(part, name, lines, color, tag)
	local bb = part:FindFirstChild("Street") or Instance.new("BillboardGui")
	bb.Name = "Street"
	bb.Size = UDim2.new(22, 0, 8, 0) -- (in studs)
	bb.StudsOffset = Vector3.new(0, 4, 0)
	bb.MaxDistance = 320
	bb.LightInfluence = 0
	bb.AlwaysOnTop = false
	local function text(key, t, y, h, c, cap)
		local l = bb:FindFirstChild(key) or Instance.new("TextLabel")
		l.Name = key
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromScale(0, y)
		l.Size = UDim2.fromScale(1, h)
		l.Font = Enum.Font.GothamBlack
		l.TextScaled = true
		l.TextColor3 = c
		l.TextStrokeTransparency = 0.1
		l.TextStrokeColor3 = INK
		l.Text = t
		l.Parent = bb
		local k = l:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
		k.MaxTextSize = cap
		k.Parent = l
	end
	text("Tag", tag or "", 0, 0.16, Color3.fromRGB(255, 120, 150), 30)
	text("Owner", name, 0.16, 0.3, color or WHITE, 48)
	text("Line1", lines[1] or "", 0.48, 0.26, P.sunflower, 38)
	text("Line2", lines[2] or "", 0.74, 0.24, WHITE, 32)
	bb.Parent = part
	return bb
end

return StreetBuilder
