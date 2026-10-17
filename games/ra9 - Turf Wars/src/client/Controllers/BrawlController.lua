--[[
Bot Brawl on screen (Constants.MODE "brawl"; BrawlService sends Net "Brawl"). Only in that mode: elsewhere init
returns at once.

  top       in the HUD's phase slot (its pill and frontline bar are hidden here): the wave pill (BUILD 0:18 / WAVE 3
            · 5 LEFT / NEXT WAVE IN 7), under it the wave's progress bar (bots down, of the wave) in the team's
            colour, and the BOSS bar (its hits left) while a boss stands; the best wave of this server beside it
  the win   each wave cleared ("Brawl" clear): a short burst of the grand fireworks over the human half
            (FireworksController.show, FIREWORKS_SECONDS; no camera tilt, no flash: cheap on a phone). The
            "WAVE N CLEAR!" alert and the Shards flyer come from the server as any alert and any Earned do.
  heads     a name in the team's colour over each teammate (a person on your side; the bots wear their own tags)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)
local Layout = require(script.Parent.Parent.UI.Layout)
local FireworksController = require(script.Parent.FireworksController)
local HudController = require(script.Parent.HudController)

local BrawlController = { Name = "BrawlController", Order = 45 }

local C = Theme.Color
local player = Players.LocalPlayer
local refs = {}
BrawlController.refs = refs
local shows = 0 -- (tests: the wave-clear fireworks shown)

local function now()
	return workspace:GetServerTimeNow()
end

local function clock(seconds)
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function build(gui)
	local top = Theme.new("Frame", {
		Name = "Brawl",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(560, 74),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	refs.top = top
	local pill = Theme.new("Frame", {
		Name = "Wave",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(230, 32),
		BackgroundColor3 = C.ink,
		BorderSizePixel = 0,
		Parent = top,
	}, { Theme.corner(4) })
	refs.pill = pill
	refs.wave = Theme.title({
		Name = "Text",
		Text = "",
		Size = UDim2.new(1, 0, 1, -4),
		Position = UDim2.fromOffset(0, 2),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.white,
		outline = false,
		Parent = pill,
	})
	-- the wave's progress: the bots down, of the wave, in the team's colour
	local bar, fill = Theme.bar({
		Name = "Progress",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 38),
		Size = UDim2.fromOffset(360, 14),
		Parent = top,
	}, Constants.TEAM_COLOR.red)
	refs.bar, refs.fill = bar, fill
	fill.Size = UDim2.fromScale(0, 1)
	refs.best = Theme.text({
		Name = "Best",
		Text = "",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(1, 8, 0, -2),
		Size = UDim2.fromOffset(110, 18),
		TextSize = 12,
		TextColor3 = C.muted,
		Font = Theme.Display,
		Parent = bar,
	})
	-- the boss: a gold bar with its hits left, under the progress
	local boss, bossFill = Theme.bar({
		Name = "Boss",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 56),
		Size = UDim2.fromOffset(300, 14),
		Visible = false,
		Parent = top,
	}, Color3.fromRGB(240, 160, 20))
	refs.boss, refs.bossFill = boss, bossFill
	refs.bossText = Theme.text({
		Name = "Text",
		Text = "👑 BOSS",
		Size = UDim2.fromScale(1, 1),
		TextSize = 11,
		TextColor3 = C.white,
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.Display,
		outline = 1,
		ZIndex = 3,
		Parent = boss,
	})
end

-- A name over a teammate's head, in the team's colour (once a body; a new body gets a new one)
local function tagMate(other)
	local c = other.Character
	if not c or c:FindFirstChild("MateTag") then
		return
	end
	local head = c:FindFirstChild("Head") or c:FindFirstChild("HumanoidRootPart")
	if not head then
		return
	end
	local tag = Instance.new("BillboardGui")
	tag.Name = "MateTag"
	tag.Size = UDim2.fromOffset(160, 20)
	tag.StudsOffset = Vector3.new(0, 2.6, 0)
	tag.MaxDistance = 120
	tag.AlwaysOnTop = true
	tag.LightInfluence = 0
	tag.Adornee = head
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Text = other.DisplayName
	l.TextScaled = true
	l.Font = Enum.Font.GothamBold
	l.TextColor3 = Constants.TEAM_COLOR.red
	l.TextStrokeColor3 = Color3.fromRGB(30, 30, 34)
	l.TextStrokeTransparency = 0.2
	l.Parent = tag
	tag.Parent = c
end

local function tagMates()
	local mine = player:GetAttribute("Team")
	for _, other in Players:GetPlayers() do
		if other ~= player and mine and other:GetAttribute("Team") == mine then
			pcall(tagMate, other)
		end
	end
end

function BrawlController.shows()
	return shows
end

-- A wave down: the short burst of the win show over the human half (the arena's centre is the server's word)
function BrawlController.clear(e)
	shows += 1
	local center = typeof(e.center) == "Vector3" and e.center or Vector3.new(-50, 0, 0)
	pcall(FireworksController.show, center, Constants.TEAM_COLOR.red, {
		seconds = tonumber(e.seconds) or Constants.BRAWL.FIREWORKS_SECONDS,
		radius = 30,
		depth = 20,
		back = Vector3.new(-1, 0, 0), -- (the far shells toward the human deck: away from the fight)
		tilt = false,
		flash = false,
	})
end

local function step()
	local b = Store.get("brawl")
	local m = Store.get("match") or {}
	if not refs.wave then
		return
	end
	local text = ""
	if m.phase == "victory" or (b and b.state == "over") then
		text = "RUN COMPLETE"
	elseif m.phase == "build" then
		text = `BUILD {clock((m.ends or now()) - now())}`
	elseif b and b.state == "wave" then
		text = `WAVE {b.wave} · {b.left or 0} LEFT`
	elseif b and b.state == "breather" then
		text = `NEXT WAVE IN {math.max(0, math.ceil((b.ends or now()) - now()))}`
	elseif b and b.state == "idle" then
		text = "WAITING"
	end
	refs.wave.Text = text
	local total = b and b.total or 0
	local done = b and (total - (b.left or 0)) or 0
	refs.fill.Size = UDim2.fromScale(total > 0 and math.clamp(done / total, 0, 1) or 0, 1)
	refs.best.Text = b and (b.best or 0) > 0 and `BEST {b.best}` or ""
	local boss = b and b.boss
	refs.boss.Visible = boss ~= nil and b.state == "wave"
	if boss then
		refs.bossFill.Size = UDim2.fromScale(math.clamp((boss.hits or 0) / math.max(1, boss.max or 1), 0, 1), 1)
		refs.bossText.Text = `👑 BOSS  {boss.hits or 0}/{boss.max or 0}`
	end
	refs.top.Visible = not Layout.inCinema() and not Layout.focused()
end

function BrawlController:init()
	if Constants.MODE ~= "brawl" then
		return
	end
	local gui = Theme.screen("Brawl", 6, player:WaitForChild("PlayerGui"))
	refs.gui = gui
	build(gui)
	-- (the HUD's own top: the phase pill and the frontline bar mean nothing here)
	local hud = HudController.refs
	if hud.phasePill then
		hud.phasePill.Visible = false
	end
	if hud.bar then
		hud.bar.Visible = false
	end
	Net.listen("Brawl", function(e)
		if type(e) ~= "table" then
			return
		end
		if e.kind == "state" then
			Store.set("brawl", e)
		elseif e.kind == "clear" then
			BrawlController.clear(e)
		end
	end)
	local last = 0
	RunService.RenderStepped:Connect(function()
		step()
		if os.clock() - last >= 1 then
			last = os.clock()
			tagMates()
		end
	end)
end

return BrawlController
