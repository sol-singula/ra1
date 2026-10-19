--[[
The animal pens on the client: a tag over each pen you own saying how its animals are ("HUNGRY! FEED ME" in red,
"FED 2:10" or "HAPPY x2 0:32" with the boost they give), the feed plate pulsing when there's something to do there,
and the animals moving a little (pecking, turning, a hop when they're happy).

  AnimalController.tags()   [key] = the text on each pen's tag (tests)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Animals = require(ReplicatedStorage.Shared.Data.Animals)
local Shapes = require(ReplicatedStorage.Shared.World.Shapes)
local Store = require(script.Parent.Parent.Store)

local AnimalController = { Name = "AnimalController", Order = 59 }

local tags = {} -- [key] = { part, label }
local texts = {}
local received = 0 -- os.clock() when the last Animals came

function AnimalController.tags()
	return texts
end

local function clock(s)
	s = math.max(0, math.floor(s))
	return string.format("%d:%02d", s // 60, s % 60)
end

local function pens()
	local t = Store.get("territory")
	local model = t and workspace:FindFirstChild("Territories") and workspace.Territories:FindFirstChild("T" .. t.index)
	return model and model:FindFirstChild("Pens")
end

local function tagFor(pen, key)
	local e = tags[key]
	if e and e.part.Parent then
		return e
	end
	local ground = pen:FindFirstChild("PenGround")
	if not ground then
		return nil
	end
	local part =
		Shapes.part(pen, Vector3.new(0.2, 0.2, 0.2), ground.CFrame * CFrame.new(0, 6.5, 0), Color3.new(1, 1, 1))
	part.Name = "StatusTag"
	part.Transparency = 1
	local bb = Shapes.label(part, "", {
		Name = "Status",
		studs = Vector2.new(9, 2.4),
		StudsOffset = Vector3.new(0, 0, 0),
		MaxDistance = 120,
	})
	e = { part = part, label = bb.Text }
	tags[key] = e
	return e
end

local function paint()
	local s = Store.get("animals")
	local folder = pens()
	if not s or not folder then
		return
	end
	local since = os.clock() - received
	for _, pen in folder:GetChildren() do
		local key = pen:GetAttribute("Animal")
		local st = key and s[key]
		if st then
			local a = Animals[key]
			local e = tagFor(pen, key)
			if e then
				local pct = `+{math.floor((st.boost or 0) * 100 + 0.5)}%`
				local text, color
				if not st.fed then
					text, color = `{a.icon} HUNGRY! FEED ME`, Color3.fromRGB(210, 50, 44)
				elseif st.happy then
					text, color =
						`{a.icon} HAPPY x2 {clock(st.happyLeft - since)} · {pct}`, Color3.fromRGB(60, 160, 70)
				elseif (st.petIn - since) <= 0 then
					text, color = `{a.icon} PET ME! (x2) · {pct}`, Color3.fromRGB(230, 150, 30)
				else
					text, color = `{a.icon} FED {clock(st.fedLeft - since)} · {pct}`, Color3.fromRGB(40, 30, 24)
				end
				e.label.Text = text
				e.label.BackgroundColor3 = color
				texts[key] = text
			end
			-- the feed plate glows brighter when there's something to do
			local plate = pen:FindFirstChild("FeedPlate")
			if plate then
				local todo = not st.fed or (st.petIn - since) <= 0
				plate.Color = todo and Color3.fromRGB(255, 220, 80) or Color3.fromRGB(170, 150, 90)
			end
		end
	end
end

function AnimalController:init()
	Store.Changed:Connect(function(partial)
		if partial.animals then
			received = os.clock()
			paint()
		elseif partial.territory then
			paint()
		end
	end)
	local acc, t = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		t += dt
		if acc >= 0.5 then
			acc = 0
			paint()
		end
		-- the animals: a little bob and turn each (their parts move with the Root)
		local folder = pens()
		local s = Store.get("animals") or {}
		if folder then
			for _, pen in folder:GetChildren() do
				local key = pen:GetAttribute("Animal")
				local herd = pen:FindFirstChild("Herd")
				local happy = key and s[key] and s[key].happy
				if herd then
					for n, m in herd:GetChildren() do
						local root = m.PrimaryPart
						if root then
							local base = m:GetAttribute("Base")
							if not base then
								m:SetAttribute("Base", root.CFrame)
								base = root.CFrame
							end
							local phase = t * (happy and 6 or 1.5) + n * 1.7
							local hop = happy and math.max(0, math.sin(phase)) * 0.6 or 0
							local look = math.sin(phase * 0.4) * 0.5
							m:PivotTo(base * CFrame.new(0, hop, 0) * CFrame.Angles(0, look, 0))
						end
					end
				end
			end
		end
	end)
end

return AnimalController
