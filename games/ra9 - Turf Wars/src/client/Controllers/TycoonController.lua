--[[
Castle Tycoon on screen (Modes = { "tycoon" }: only in that place; TycoonService runs it, Net "Tycoon"). Phone first:
big buttons, the SUPERHOT look (white cards, black type, gold for Gold).

  top left       🛒 SHOP (the panel: PanelController) and your Shards under it
  top centre     your Gold, big, and "+N/s · vault N" under it; the tier bar (FORT · 3/6) under that
  bottom left    ◀ LOBBY (Net "ToLobby")
  bottom right   ⚔ HIT while a raider is close (Net "Tycoon" "hit"; a click or E does it too on a PC)
  middle         the toasts; "RAID!" when one starts; the REBIRTH card when they stand on its pad (YES sends
                 Net "Tycoon" "rebirth")

In the world: a gold cube drops out of every mine's spout now and then and flies into the COLLECT pad (looks only,
on this client), and every tower shot or hit is a beam (Net "Tycoon" zap). The camera is Roblox's own third person.

  TycoonController.state()    the last Net "Tycoon" state
  TycoonController.refs       the screen's pieces (tests)
  TycoonController.hit()      what the HIT button does
  TycoonController.near()     a raider within reach of the HIT button
  TycoonController.cubes()    the gold cubes in flight
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Tycoon = require(ReplicatedStorage.Shared.Data.Tycoon)
local Layout = require(script.Parent.Parent.UI.Layout)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)
local AudioController = require(script.Parent.AudioController)
local PanelController = require(script.Parent.PanelController)

local TycoonController = { Name = "TycoonController", Order = 40, Modes = { "tycoon" } }

local C = Theme.Color
local GOLD = Constants.GOLD
local player = Players.LocalPlayer

local refs = {}
TycoonController.refs = refs
TycoonController.CUBE_EVERY = 2.5 -- seconds between a mine's cubes
TycoonController.CUBE_SECONDS = 1.1 -- a cube's flight
TycoonController.CUBE_MAX = 40
TycoonController.SEE = 160 -- studs: the cubes only for plots this close

local state = {}
local cubes = {} -- { part, from, to, t0 }
local beams = {} -- { part, t0 }
local toastToken, bannerToken
local nextCube = {} -- [spout] = os.clock()

function TycoonController.state()
	return state
end

function TycoonController.cubes()
	return cubes
end

local function play(cue)
	pcall(AudioController.play, cue)
end

local function toast(text, kind)
	local t = refs.toast
	if not t then
		return
	end
	if Layout.panel() and Layout.statusSink and Layout.statusSink(text, kind) then
		return
	end
	t.Text = string.gsub(text, " ?◆", " Shards")
	t.TextColor3 = kind == "bad" and C.red or (kind == "good" and C.good or C.ink)
	t.Visible = true
	local token = {}
	toastToken = token
	task.delay(3.5, function()
		if toastToken == token then
			t.Visible = false
		end
	end)
end
TycoonController.toast = toast

local function banner(text, color)
	local b = refs.banner
	if not b then
		return
	end
	b.Text = text
	b.TextColor3 = color or C.white
	b.Visible = true
	local token = {}
	bannerToken = token
	task.delay(2.5, function()
		if bannerToken == token then
			b.Visible = false
		end
	end)
end

local function root()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

-- A raider within reach of HIT
function TycoonController.near()
	local r = root()
	local folder = workspace:FindFirstChild("Tycoon")
	if not r or not folder then
		return nil
	end
	for _, m in folder:GetChildren() do
		if m.Name == "Raider" and m:GetAttribute("Raider") then
			local body = m.PrimaryPart or m:FindFirstChild("Body")
			if body and (body.Position - r.Position).Magnitude <= Tycoon.HIT_RANGE then
				return m
			end
		end
	end
	return nil
end

function TycoonController.hit()
	if not TycoonController.near() then
		return false
	end
	Net.send("Tycoon", "hit")
	play("hit")
	return true
end

-- The screen -------------------------------------------------------------------------------------------------------
local function paint()
	if not refs.gold then
		return
	end
	refs.gold.Text = Theme.commas(state.cash or 0)
	refs.rate.Text = `+{Format.num(state.income or 0)}/s · vault {Format.num(state.bank or 0)}`
	if state.complete then
		refs.tierText.Text = "CASTLE COMPLETE · REBIRTH!"
		refs.tierFill.Size = UDim2.fromScale(1, 1)
	elseif state.tierName then
		refs.tierText.Text = `{state.tierName} · {state.done or 0}/{state.of or 0}`
		local k = (state.of or 0) > 0 and (state.done or 0) / state.of or 0
		refs.tierFill.Size = UDim2.fromScale(math.clamp(k, 0.04, 1), 1)
	end
	if refs.reborn then
		refs.reborn.Text = (state.rebirths or 0) > 0 and `★ {state.rebirths}` or ""
	end
end

local function paintShards()
	local p = Store.get("profile")
	if refs.shards and p then
		refs.shards.Text = Theme.commas(p.shards or 0)
	end
end

local function buildTop(gui)
	local shop = Theme.button({
		Name = "Shop",
		Text = "🛒 SHOP",
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(130, 44),
		BackgroundColor3 = C.white,
		dark = true,
		Parent = gui,
	})
	shop.Modal = true
	shop.Activated:Connect(function()
		PanelController.open("shop", "tycoon_button")
	end)
	refs.shop = shop
	local slab = Theme.slab({
		Name = "Shards",
		Position = UDim2.fromOffset(12, 62), -- (under SHOP: the PARTY chip has the spot beside it)
		Size = UDim2.fromOffset(130, 40),
		Parent = gui,
	})
	Theme.gem(slab, 22, { Name = "Gem", Position = UDim2.fromOffset(10, 11) })
	refs.shards = Theme.text({
		Name = "Amount",
		Text = "0",
		Position = UDim2.fromOffset(40, 6),
		Size = UDim2.new(1, -48, 1, -12),
		Font = Theme.Display,
		TextColor3 = C.white,
		fit = 22,
		Parent = slab,
	})

	-- the Gold, top centre
	local money = Theme.slab({
		Name = "Gold",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(280, 64),
		Parent = gui,
	})
	Theme.new("Frame", {
		Name = "Coin",
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = GOLD,
		BorderSizePixel = 0,
		Parent = money,
	}, { Theme.corner("round"), Theme.stroke(2) })
	refs.gold = Theme.text({
		Name = "Amount",
		Text = "0",
		Position = UDim2.fromOffset(48, 4),
		Size = UDim2.new(1, -96, 0, 38),
		Font = Theme.Display,
		TextColor3 = GOLD,
		fit = 32,
		Parent = money,
	})
	refs.reborn = Theme.text({
		Name = "Reborn",
		Text = "",
		Position = UDim2.new(1, -52, 0, 8),
		Size = UDim2.fromOffset(44, 26),
		Font = Theme.Display,
		TextColor3 = GOLD,
		TextXAlignment = Enum.TextXAlignment.Right,
		fit = 18,
		Parent = money,
	})
	refs.rate = Theme.text({
		Name = "Rate",
		Text = "+0/s",
		Position = UDim2.fromOffset(12, 42),
		Size = UDim2.new(1, -24, 0, 18),
		TextColor3 = C.white,
		TextXAlignment = Enum.TextXAlignment.Center,
		fit = 15,
		Parent = money,
	})
	refs.money = money
	local bar, fill = Theme.bar({
		Name = "Tier",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 80),
		Size = UDim2.fromOffset(280, 24),
		Parent = gui,
	}, GOLD)
	refs.tierBar, refs.tierFill = bar, fill
	refs.tierText = Theme.text({
		Name = "Words",
		Text = "CAMP · 0/6",
		Position = UDim2.fromOffset(8, 2),
		Size = UDim2.new(1, -16, 1, -4),
		Font = Theme.Display,
		TextColor3 = C.white,
		TextXAlignment = Enum.TextXAlignment.Center,
		fit = 16,
		outline = 2,
		ZIndex = 3,
		Parent = bar,
	})
	refs.toast = Theme.text({
		Name = "Toast",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 112),
		Size = UDim2.fromOffset(520, 32),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.Display,
		fit = 17,
		outline = 2,
		TextColor3 = C.ink,
		Visible = false,
		Parent = gui,
	})
	refs.banner = Theme.title({
		Name = "Banner",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(520, 70),
		TextXAlignment = Enum.TextXAlignment.Center,
		fit = 56,
		Visible = false,
		Parent = gui,
	})
end

local function buildBottom(gui)
	local lobby = Theme.button({
		Name = "Lobby",
		Text = "◀ LOBBY",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.fromOffset(130, 48),
		BackgroundColor3 = C.white,
		dark = true,
		Parent = gui,
	})
	lobby.Modal = true
	lobby.Activated:Connect(function()
		Net.send("ToLobby")
		toast("Back to the lobby...", "info")
	end)
	refs.lobby = lobby
	local hit = Theme.button({
		Name = "Hit",
		Text = "⚔ HIT",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -150),
		Size = UDim2.fromOffset(120, 120),
		BackgroundColor3 = C.red,
		round = true,
		Visible = false,
		Parent = gui,
	})
	hit.Modal = true
	hit.Activated:Connect(function()
		TycoonController.hit()
	end)
	refs.hit = hit
end

local function buildRebirth(gui)
	local card = Theme.card({
		Name = "Rebirth",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(420, 220),
		Visible = false,
		Parent = gui,
	})
	Theme.text({
		Name = "Title",
		Text = "REBIRTH ★",
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(1, -32, 0, 44),
		Font = Theme.Display,
		TextXAlignment = Enum.TextXAlignment.Center,
		fit = 34,
		Parent = card,
	})
	refs.rebirthLine = Theme.text({
		Name = "Line",
		Text = "",
		Position = UDim2.fromOffset(20, 60),
		Size = UDim2.new(1, -40, 0, 70),
		TextXAlignment = Enum.TextXAlignment.Center,
		fit = 17,
		Parent = card,
	})
	local yes = Theme.button({
		Name = "Yes",
		Text = "REBIRTH!",
		Position = UDim2.new(0.5, 6, 1, -72),
		Size = UDim2.new(0.5, -22, 0, 56),
		BackgroundColor3 = GOLD,
		Parent = card,
	})
	local no = Theme.button({
		Name = "No",
		Text = "NOT YET",
		Position = UDim2.new(0, 16, 1, -72),
		Size = UDim2.new(0.5, -22, 0, 56),
		BackgroundColor3 = C.white,
		dark = true,
		Parent = card,
	})
	yes.Modal = true
	no.Modal = true
	yes.Activated:Connect(function()
		card.Visible = false
		Net.send("Tycoon", "rebirth")
	end)
	no.Activated:Connect(function()
		card.Visible = false
	end)
	refs.rebirth, refs.yes, refs.no = card, yes, no
end

-- The world: gold cubes and beams ----------------------------------------------------------------------------------
local function cubeFor(spout, collector)
	if #cubes >= TycoonController.CUBE_MAX then
		return
	end
	local p = Instance.new("Part")
	p.Name = "GoldCube"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = Vector3.new(0.9, 0.9, 0.9)
	local gem = spout:GetAttribute("Gem")
	p.Color = typeof(gem) == "Color3" and gem or GOLD
	p.Material = Enum.Material.Neon
	p.CFrame = spout.CFrame
	p.Parent = workspace
	table.insert(
		cubes,
		{ part = p, from = spout.Position, to = collector.Position + Vector3.new(0, 1, 0), t0 = os.clock() }
	)
end

local function beam(from, to, color)
	if typeof(to) ~= "Vector3" then
		return
	end
	from = typeof(from) == "Vector3" and from or (to + Vector3.new(0, 6, 0))
	local d = (to - from).Magnitude
	if d < 0.1 then
		return
	end
	local p = Instance.new("Part")
	p.Name = "Beam"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = Vector3.new(0.3, 0.3, d)
	p.CFrame = CFrame.lookAt((from + to) / 2, to)
	p.Parent = workspace
	table.insert(beams, { part = p, t0 = os.clock() })
end

local function step()
	local now = os.clock()
	local r = root()
	-- each mine near enough drops a cube now and then
	local folder = workspace:FindFirstChild("Tycoon")
	if folder and r then
		for _, plot in folder:GetChildren() do
			local items = plot:FindFirstChild("Items")
			local collector = items and items:FindFirstChild("Collector", true)
			if collector and (collector.Position - r.Position).Magnitude <= TycoonController.SEE then
				for _, d in items:GetDescendants() do
					if d.Name == "Spout" then
						if not nextCube[d] then
							nextCube[d] = now + math.random() * TycoonController.CUBE_EVERY
						elseif now >= nextCube[d] then
							nextCube[d] = now + TycoonController.CUBE_EVERY
							cubeFor(d, collector)
						end
					end
				end
			end
		end
	end
	for i = #cubes, 1, -1 do
		local c = cubes[i]
		local k = (now - c.t0) / TycoonController.CUBE_SECONDS
		if k >= 1 or not c.part.Parent then
			c.part:Destroy()
			table.remove(cubes, i)
		else
			local pos = c.from:Lerp(c.to, k) + Vector3.new(0, math.sin(k * math.pi) * 6, 0)
			c.part.CFrame = CFrame.new(pos) * CFrame.Angles(k * 6, k * 4, 0)
		end
	end
	for i = #beams, 1, -1 do
		local b = beams[i]
		local k = (now - b.t0) / 0.25
		if k >= 1 then
			b.part:Destroy()
			table.remove(beams, i)
		else
			b.part.Transparency = k
		end
	end
	-- the HIT button shows while a raider is close
	if refs.hit then
		refs.hit.Visible = TycoonController.near() ~= nil
	end
	for spout in nextCube do
		if not spout.Parent then
			nextCube[spout] = nil
		end
	end
end

-- The camera: Roblox's own third person, the mouse free
local function camera()
	Layout.lobby(true)
	pcall(function()
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMinZoomDistance = 6
		player.CameraMaxZoomDistance = 30
	end)
	pcall(function()
		UserInputService.MouseIconEnabled = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end)
end

function TycoonController:init()
	local gui = Theme.screen("Tycoon", 6, player:WaitForChild("PlayerGui"))
	refs.gui = gui
	camera()
	buildTop(gui)
	buildBottom(gui)
	buildRebirth(gui)
	paint()
	paintShards()
	Store.Changed:Connect(function(partial)
		if partial.profile then
			paintShards()
		end
	end)
	Net.listen("Tycoon", function(m)
		if type(m) ~= "table" then
			return
		end
		if m.kind == "state" then
			state = m
			paint()
		elseif m.kind == "bought" then
			play("built")
			toast(`BUILT: {m.name or ""}`, "good")
		elseif m.kind == "collect" then
			play("tick")
			toast(`+{Format.num(m.amount or 0)} Gold`, "good")
		elseif m.kind == "tier" then
			play("win")
			banner(`{m.name or ""} COMPLETE!`, GOLD)
		elseif m.kind == "raid" then
			play("horn")
			banner("RAID!", C.red)
		elseif m.kind == "raidOver" then
			if (m.bonus or 0) > 0 then
				banner("RAID BEATEN!", C.good)
			end
		elseif m.kind == "stolen" then
			toast(`A raider took {Format.num(m.amount or 0)} Gold from your vault!`, "bad")
		elseif m.kind == "rebirthAsk" then
			refs.rebirthLine.Text =
				`Start your castle again with +{math.floor(Tycoon.REBIRTH_INCOME * 100)}% income forever and +{m.shards or 0} Shards now. Your Gold and pieces reset.`
			refs.rebirth.Visible = true
		elseif m.kind == "rebirth" then
			play("win")
			banner(`REBIRTH {m.rebirths or ""}!`, GOLD)
		elseif m.kind == "zap" then
			beam(m.from, m.to, m.hit and C.white or (m.down and GOLD or Color3.fromRGB(140, 120, 255)))
			if m.down then
				play("kill")
			end
		end
	end)
	Net.listen("Toast", toast)
	Net.listen("Earned", function(e)
		if refs.shards and type(e) == "table" and e.total then
			refs.shards.Text = Theme.commas(e.total)
		end
	end)
	-- a PC: a click (not on the screen's buttons) or E hits
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.E then
			TycoonController.hit()
		end
	end)
	RunService.Heartbeat:Connect(step)
end

return TycoonController
