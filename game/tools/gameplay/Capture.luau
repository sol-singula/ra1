--[[
Snapshot of what the local player would see at this moment of a mock-engine session: every visible part in the
workspace (server world and client-built visuals), billboards, surface text, the proximity prompts Roblox would
show, and the player's ScreenGuis. tools/gameplay/render.html draws a snapshot with three.js.
]]
local Capture = {}

local function hex(c)
	return string.format(
		"#%02x%02x%02x",
		math.floor(c.R * 255 + 0.5),
		math.floor(c.G * 255 + 0.5),
		math.floor(c.B * 255 + 0.5)
	)
end

local function value(v, Engine)
	local t = Engine.globals.typeof(v)
	if t == "Color3" then
		return hex(v)
	elseif t == "UDim2" then
		return { v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset }
	elseif t == "UDim" then
		return { v.Scale, v.Offset }
	elseif t == "Vector2" or t == "Vector3" then
		return t == "Vector2" and { v.X, v.Y } or { v.X, v.Y, v.Z }
	elseif t == "EnumItem" then
		return v.Name
	elseif t == "number" or t == "string" or t == "boolean" then
		return v
	end
	return nil
end

local GUI_PROPS = {
	"Size",
	"Position",
	"AnchorPoint",
	"BackgroundColor3",
	"BackgroundTransparency",
	"Visible",
	"Text",
	"TextColor3",
	"Font",
	"TextSize",
	"TextScaled",
	"TextWrapped",
	"TextXAlignment",
	"TextYAlignment",
	"TextTransparency",
	"TextStrokeTransparency",
	"TextStrokeColor3",
	"AutomaticSize",
	"ZIndex",
	"LayoutOrder",
	"ClipsDescendants",
	"TextTruncate",
	"Name",
	"Enabled",
	"DisplayOrder",
}
local MOD_PROPS = {
	UICorner = { "CornerRadius" },
	UIStroke = { "Thickness", "Color", "Transparency", "ApplyStrokeMode" },
	UIPadding = { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" },
	UIListLayout = { "FillDirection", "Padding", "HorizontalAlignment", "VerticalAlignment" },
	UIGridLayout = { "CellSize", "CellPadding" },
}

local function guiTree(inst, Engine)
	local props = rawget(inst, "_props")
	local node = { cls = inst.ClassName, props = {}, mods = {}, children = {} }
	for _, k in GUI_PROPS do
		local v = props[k]
		if v ~= nil then
			node.props[k] = value(v, Engine)
		end
	end
	for _, child in inst:GetChildren() do
		local cls = child.ClassName
		if MOD_PROPS[cls] then
			local m = {}
			for _, k in MOD_PROPS[cls] do
				local v = rawget(child, "_props")[k]
				if v ~= nil then
					m[k] = value(v, Engine)
				end
			end
			node.mods[cls] = m
		elseif child:IsA("GuiObject") then
			table.insert(node.children, guiTree(child, Engine))
		end
	end
	return node
end

local function partPosition(inst)
	if inst.ClassName == "Attachment" then
		return inst.WorldPosition
	end
	local cf = rawget(inst, "_props").CFrame
	return cf and cf.Position or nil
end

function Capture.snapshot(Engine, camera)
	Engine.resolveWelds()
	local workspace = Engine.workspace
	local player = Engine.Players.LocalPlayer
	local snap = { camera = camera, parts = {}, fires = {}, signs = {}, billboards = {}, screens = {}, prompts = {} }

	for _, d in workspace:GetDescendants() do
		if d:IsA("BasePart") then
			local p = rawget(d, "_props")
			local transparency = p.Transparency or 0
			if transparency < 0.99 then
				local cf = p.CFrame
				local r = cf.r
				local shape = "Block"
				if d.ClassName == "WedgePart" then
					shape = "Wedge"
				elseif p.Shape then
					shape = p.Shape.Name
				end
				table.insert(snap.parts, {
					s = shape,
					size = { p.Size.X, p.Size.Y, p.Size.Z },
					m = { cf.p.X, cf.p.Y, cf.p.Z, r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9] },
					c = p.Color and hex(p.Color) or "#a3a2a5",
					mat = p.Material and p.Material.Name or "Plastic",
					t = transparency,
					n = p.Name,
				})
				for _, child in d:GetChildren() do
					if child.ClassName == "Fire" then
						table.insert(
							snap.fires,
							{ pos = { cf.p.X, cf.p.Y + p.Size.Y / 2, cf.p.Z }, size = rawget(child, "_props").Size or 5 }
						)
					elseif child.ClassName == "SurfaceGui" then
						local label = child:FindFirstChildWhichIsA("TextLabel")
						if label then
							local lp = rawget(label, "_props")
							table.insert(snap.signs, {
								part = #snap.parts,
								text = lp.Text,
								font = lp.Font and lp.Font.Name or "SourceSans",
								color = lp.TextColor3 and hex(lp.TextColor3) or "#000000",
							})
						end
					end
				end
			end
		end
	end

	local function addBillboard(bb)
		local p = rawget(bb, "_props")
		if p.Enabled == false then
			return
		end
		local adornee = p.Adornee or p.Parent
		local pos = adornee and partPosition(adornee)
		if not pos then
			return
		end
		local tree = guiTree(bb, Engine)
		table.insert(snap.billboards, {
			pos = { pos.X, pos.Y, pos.Z },
			offset = p.StudsOffset and { p.StudsOffset.X, p.StudsOffset.Y, p.StudsOffset.Z } or { 0, 0, 0 },
			size = value(p.Size, Engine),
			maxDistance = p.MaxDistance or 1e9,
			tree = tree,
		})
	end
	for _, d in workspace:GetDescendants() do
		if d.ClassName == "BillboardGui" then
			addBillboard(d)
		end
	end
	local playerGui = player:FindFirstChild("PlayerGui")
	for _, d in playerGui:GetDescendants() do
		if d.ClassName == "BillboardGui" then
			addBillboard(d)
		end
	end
	for _, sg in playerGui:GetChildren() do
		if sg.ClassName == "ScreenGui" and rawget(sg, "_props").Enabled ~= false then
			table.insert(
				snap.screens,
				{ order = rawget(sg, "_props").DisplayOrder or 0, name = sg.Name, tree = guiTree(sg, Engine) }
			)
		end
	end

	-- Prompts: Roblox shows the closest enabled prompt per key within its activation distance.
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if hrp then
		local best = {}
		for _, d in workspace:GetDescendants() do
			if d.ClassName == "ProximityPrompt" then
				local p = rawget(d, "_props")
				local pos = p.Parent and partPosition(p.Parent)
				if p.Enabled ~= false and pos then
					local dist = (pos - hrp.Position).Magnitude
					local key = p.KeyboardKeyCode and p.KeyboardKeyCode.Name or "E"
					if dist <= (p.MaxActivationDistance or 10) and (not best[key] or dist < best[key].dist) then
						best[key] = {
							dist = dist,
							pos = { pos.X, pos.Y, pos.Z },
							action = p.ActionText or "Interact",
							object = p.ObjectText or "",
							key = key,
							hold = (p.HoldDuration or 0) > 0,
						}
					end
				end
			end
		end
		for _, prompt in best do
			table.insert(snap.prompts, prompt)
		end
	end
	return snap
end

return Capture
