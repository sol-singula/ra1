-- The Hall of Records' displays (RecordService fills them from the saved records):
--   the top record's stage: a miniature of that crew's train, built the way it was (Searchlight, Radio Mast, engine
--   overhaul), with the crew in front of it as simple statues, each with a name plate and their Roblox headshot
--   (rbxthumb, so nothing yields and an avatar that can't load still leaves the name), and the record plaque
--   the other plaques: one short summary each
-- Statues, not live avatar rigs: the Hall stays cheap however many people a record had.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(ReplicatedStorage.Shared.World.Kit)

local HallBuilder = {}

local C, M = Kit.C, Kit.M
local box = Kit.box
local MAX_STATUES = 8

-- Shirt colours for the statues (picked by user id, so a player always looks the same on the wall).
local SHIRTS = {
	Kit.rgb(176, 64, 52),
	Kit.rgb(52, 110, 160),
	Kit.rgb(70, 130, 80),
	Kit.rgb(196, 150, 60),
	Kit.rgb(120, 76, 150),
	Kit.rgb(60, 140, 140),
	Kit.rgb(170, 90, 120),
	Kit.rgb(90, 96, 110),
}

local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }

function HallBuilder.date(t)
	if type(t) ~= "number" then
		return "—"
	end
	local d = os.date("!*t", t)
	return `{d.day} {MONTHS[d.month]} {d.year}`
end

function HallBuilder.duration(seconds)
	seconds = math.max(0, math.floor(tonumber(seconds) or 0))
	local h, m = math.floor(seconds / 3600), math.floor(seconds % 3600 / 60)
	if h > 0 then
		return `{h}h {m}m`
	end
	return `{m} min`
end

-- One crew statue, standing at `cf` (feet on the stage), facing the hall (-Z).
function HallBuilder.statue(parent, cf, member)
	local model = Kit.model("Statue", parent)
	local shirt = SHIRTS[(tonumber(member.userId) or 0) % #SHIRTS + 1]
	local bronze = Kit.rgb(150, 112, 66)
	-- a small plinth, then a blocky figure in bronze with a coloured sash
	box(model, "Plinth", cf * CFrame.new(0, 0.3, 0), Vector3.new(2.8, 0.6, 2.2), C.woodDark, M.Wood)
	box(
		model,
		"PlinthTrim",
		cf * CFrame.new(0, 0.62, 0),
		Vector3.new(2.9, 0.06, 2.3),
		C.brass,
		M.Metal,
		{ CastShadow = false }
	)
	local base = cf * CFrame.new(0, 0.6, 0)
	box(model, "LegL", base * CFrame.new(-0.42, 1, 0), Vector3.new(0.75, 2, 0.8), bronze, M.Metal)
	box(model, "LegR", base * CFrame.new(0.42, 1, 0), Vector3.new(0.75, 2, 0.8), bronze, M.Metal)
	box(model, "Body", base * CFrame.new(0, 3, 0), Vector3.new(1.9, 2, 1), bronze, M.Metal)
	box(
		model,
		"Sash",
		base * CFrame.new(0, 3.1, -0.52) * CFrame.Angles(0, 0, math.rad(35)),
		Vector3.new(0.45, 2.5, 0.06),
		shirt,
		M.Fabric,
		{ CastShadow = false }
	)
	box(model, "ArmL", base * CFrame.new(-1.3, 3, 0), Vector3.new(0.7, 1.9, 0.8), bronze, M.Metal)
	box(
		model,
		"ArmR",
		base * CFrame.new(1.3, 3.2, 0) * CFrame.Angles(0, 0, math.rad(-20)),
		Vector3.new(0.7, 1.9, 0.8),
		bronze,
		M.Metal
	)
	local head = box(model, "Head", base * CFrame.new(0, 4.75, 0), Vector3.new(1.25, 1.25, 1.25), bronze, M.Metal)
	-- the player's headshot on a little framed portrait above the head
	local frame = box(
		model,
		"Portrait",
		base * CFrame.new(0, 6.5, 0),
		Vector3.new(1.6, 1.6, 0.12),
		C.brass,
		M.Metal,
		{ CastShadow = false }
	)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Headshot"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0.2
	gui.Parent = frame
	local img = Instance.new("ImageLabel")
	img.Name = "Image"
	img.Size = UDim2.new(1, -8, 1, -8)
	img.Position = UDim2.fromOffset(4, 4)
	img.BackgroundColor3 = C.greenDark
	img.BorderSizePixel = 0
	img.Image = `rbxthumb://type=AvatarHeadShot&id={tonumber(member.userId) or 1}&w=150&h=150`
	img.Parent = gui
	-- the name on the plinth's front
	local plate = box(
		model,
		"NamePlate",
		cf * CFrame.new(0, 0.32, -1.12),
		Vector3.new(2.7, 0.5, 0.06),
		C.black,
		M.SmoothPlastic,
		{ CastShadow = false }
	)
	Kit.text(
		plate,
		Enum.NormalId.Front,
		string.upper(tostring(member.display or member.name or "?")),
		{ color = C.brass, ppu = 40 }
	)
	model.PrimaryPart = head
	model:SetAttribute("UserId", tonumber(member.userId) or 0)
	return model
end

-- A miniature of the record's train (about 1/16 scale), front to the right (+X), on a strip of track.
function HallBuilder.miniTrain(parent, cf, train)
	train = train or {}
	local model = Kit.model("MiniTrain", parent)
	local s = 1 / 16
	local lengths = { 60, 64, 68, 68, 68, 68, 68 }
	local total = 0
	for _, l in lengths do
		total += l * s + 0.25
	end
	box(model, "Track", cf * CFrame.new(0, 0.1, 0), Vector3.new(total + 1.5, 0.2, 1.4), C.woodDark, M.Wood)
	for _, z in { -0.45, 0.45 } do
		box(
			model,
			"Rail",
			cf * CFrame.new(0, 0.27, z),
			Vector3.new(total + 1.5, 0.14, 0.12),
			C.steel,
			M.Metal,
			{ CastShadow = false }
		)
	end
	local x = total / 2
	for i, l in lengths do
		local len = l * s
		local cx = x - len / 2
		local carCf = cf * CFrame.new(cx, 0.35, 0)
		local h, w = 1.15, 1.55
		if i == 1 then
			-- the locomotive: boiler, cab, chimney, and its upgrades
			box(
				model,
				"Cab",
				carCf * CFrame.new(-len * 0.28, h * 0.62, 0),
				Vector3.new(len * 0.42, h * 1.15, w),
				C.green,
				M.SmoothPlastic
			)
			box(
				model,
				"CabRoof",
				carCf * CFrame.new(-len * 0.28, h * 1.24, 0),
				Vector3.new(len * 0.48, 0.1, w + 0.15),
				C.roof,
				M.Metal
			)
			Kit.cyl(
				model,
				"Boiler",
				carCf * CFrame.new(len * 0.18, h * 0.55, 0),
				len * 0.56,
				w * 0.82,
				(train.engine or 0) >= 3 and C.brass or C.iron,
				M.Metal
			)
			Kit.cyl(
				model,
				"Chimney",
				carCf * CFrame.new(len * 0.36, h * 1.1, 0) * CFrame.Angles(0, 0, math.rad(90)),
				0.5,
				0.34,
				C.iron,
				M.Metal
			)
			box(model, "Buffer", carCf * CFrame.new(len / 2, h * 0.28, 0), Vector3.new(0.12, 0.3, w), C.wheel, M.Metal)
			if (train.lamp or 0) >= 1 then
				Kit.bulb(
					model,
					"Searchlight",
					(carCf * CFrame.new(len / 2 + 0.05, h * 0.75, 0)).Position,
					0.32,
					Kit.rgb(255, 236, 190),
					6,
					1.2
				)
			end
			if (train.lamp or 0) >= 2 then
				box(
					model,
					"Mast",
					carCf * CFrame.new(-len * 0.28, h * 1.9, 0),
					Vector3.new(0.08, 1.3, 0.08),
					C.steel,
					M.Metal,
					{ CastShadow = false }
				)
				Kit.ball(
					model,
					"MastLamp",
					(carCf * CFrame.new(-len * 0.28, h * 2.6, 0)).Position,
					0.18,
					C.signal,
					M.Neon,
					{ CastShadow = false }
				)
			end
		else
			box(
				model,
				"Car",
				carCf * CFrame.new(0, h * 0.62, 0),
				Vector3.new(len, h, w),
				i == 2 and C.greenDark or C.green,
				M.SmoothPlastic
			)
			box(
				model,
				"Roof",
				carCf * CFrame.new(0, h * 1.17, 0),
				Vector3.new(len + 0.05, 0.12, w + 0.12),
				C.roof,
				M.Metal
			)
			box(
				model,
				"Stripe",
				carCf * CFrame.new(0, h * 0.5, -w / 2 - 0.01),
				Vector3.new(len - 0.1, 0.06, 0.02),
				C.brass,
				M.Metal,
				{ CastShadow = false }
			)
			-- lit windows
			for k = 1, 5 do
				local wx = -len / 2 + k * len / 6
				box(
					model,
					"Window",
					carCf * CFrame.new(wx, h * 0.78, -w / 2 - 0.01),
					Vector3.new(len / 9, 0.32, 0.02),
					C.warm,
					M.Neon,
					{ CastShadow = false }
				)
			end
		end
		-- wheels
		for _, wx in { -len * 0.32, len * 0.32 } do
			for _, wz in { -w / 2, w / 2 } do
				Kit.cyl(
					model,
					"Wheel",
					carCf * CFrame.new(wx, 0.12, wz) * CFrame.Angles(0, math.rad(90), 0),
					0.08,
					0.36,
					C.wheel,
					M.Metal
				)
			end
		end
		x -= len + 0.25
	end
	return model
end

-- Redraw the top record's stage (nil clears it).
function HallBuilder.top(top, record)
	top.crew:ClearAllChildren()
	top.mini:ClearAllChildren()
	if not record then
		top.plaque.Text = "NO RECORD YET\nBe the first crew on this wall."
		return
	end
	-- the miniature at the back of the stage on a low plinth, the statues in a row in front
	box(top.mini, "MiniPlinth", top.cf * CFrame.new(0, 0.35, 3), Vector3.new(32, 0.7, 3.4), C.woodDark, M.Wood)
	HallBuilder.miniTrain(top.mini, top.cf * CFrame.new(0, 0.7, 3), record.train)
	local crew = {}
	for _, m in record.crew or {} do
		if #crew < MAX_STATUES then
			table.insert(crew, m)
		end
	end
	local n = #crew
	local spacing = math.min(3.6, 30 / math.max(1, n))
	for i, m in crew do
		local x = (i - (n + 1) / 2) * spacing
		HallBuilder.statue(top.crew, top.cf * CFrame.new(x, 0, -2.5), m)
	end
	top.plaque.Text = HallBuilder.topText(record)
end

local function names(record, max)
	local list = {}
	for i, m in record.crew or {} do
		if i > max then
			table.insert(list, `+{#record.crew - max} more`)
			break
		end
		table.insert(list, tostring(m.display or m.name))
	end
	return table.concat(list, ", ")
end

function HallBuilder.topText(record)
	local live = record.live and " · STILL ON THE LINE" or ""
	return `THE LONGEST JOURNEY{live}\n{string.format("%.1f", record.km or 0)} KM\nEXPEDITION #{record.code or "?"} · {HallBuilder.date(
		record.endedAt or record.updatedAt
	)}\n{record.stops or 0} STOPS · {HallBuilder.duration(record.seconds)} · {#(record.crew or {})} CREW\n{names(
		record,
		6
	)}`
end

function HallBuilder.plaqueText(rank, record)
	if not record then
		return `#{rank}\n—`
	end
	return `#{rank} · {string.format("%.1f", record.km or 0)} KM\n#{record.code or "?"} · {HallBuilder.date(
		record.endedAt or record.updatedAt
	)}\n{record.stops or 0} stops · {#(record.crew or {})} crew\n{names(record, 3)}`
end

return HallBuilder
