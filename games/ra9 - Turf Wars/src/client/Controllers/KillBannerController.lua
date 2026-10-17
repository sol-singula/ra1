--[[
The kill banners: what a knockout feels like from your side of the screen.

  your knockout   a banner punches in (big, a little overshoot and a tilt that settles): ELIMINATED <name>, coloured
                  by the rarity of the kill effect you wear (the rainbow cycles for the Robux ones), "with <EFFECT>"
                  under it, and a funny line for the funny ones ("bawk bawk"); HEADSHOT! on a head hit; a burst of
                  sparkles (and confetti) flies out of it
  a streak        kills of yours within MULTI_WINDOW seconds stack: DOUBLE! TRIPLE! QUAD! RAMPAGE! UNSTOPPABLE! a
                  bigger banner each time, hotter colours, more sparkles and a screen shake that grows
  knocked out     by an effect that's Robux only and isn't yours: once you're back on your feet, a small card
                  slides in: "Killed by LIGHTNING STRIKE", the price, GET IT (the purchase) and a close; once per
                  effect a session, and never while a menu or a cinematic is up

  KillBannerController.onKill(k)     what Net "Kill" does (tests call it)
  KillBannerController.banner()      the banner on screen (Frame) or nil
  KillBannerController.streak()      kills in the current streak
  KillBannerController.offer()       the "killed by" card on screen (Frame) or nil
  KillBannerController.showOffer(key) puts it up now (tests)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Format = require(ReplicatedStorage.Shared.Format)
local Locker = require(ReplicatedStorage.Shared.Data.Locker)
local Net = require(ReplicatedStorage.Shared.Net)
local Shop = require(ReplicatedStorage.Shared.Data.Shop)
local Store = require(script.Parent.Parent.Store)
local Layout = require(script.Parent.Parent.UI.Layout)
local Theme = require(script.Parent.Parent.UI.Theme)

local KillBannerController = { Name = "KillBannerController", Order = 56 }

local C = Theme.Color
local player = Players.LocalPlayer
local MULTI_WINDOW = 4.5 -- seconds: a kill this soon after the last one adds to the streak
local STREAK = {
	{ n = 2, text = "DOUBLE KILL!", color = Color3.fromRGB(255, 196, 40), shake = 4 },
	{ n = 3, text = "TRIPLE KILL!", color = Color3.fromRGB(255, 120, 20), shake = 7 },
	{ n = 4, text = "QUAD KILL!", color = Color3.fromRGB(240, 40, 60), shake = 10 },
	{ n = 5, text = "RAMPAGE!", color = Color3.fromRGB(200, 40, 220), shake = 13 },
	{ n = 6, text = "UNSTOPPABLE!", color = Color3.fromRGB(60, 220, 255), shake = 16 },
}
local RARITY_COLOR = {
	common = Color3.fromRGB(70, 72, 82),
	rare = Color3.fromRGB(35, 110, 245),
	epic = Color3.fromRGB(150, 90, 240),
	legendary = Color3.fromRGB(240, 160, 20),
}
-- the funny ones' lines, by the effect's shape
local FUNNY = {
	chicken = "bawk bawk 🐔",
	duck = "squeak! 🦆",
	balloons = "bye bye 🎈",
	banana = "watch your step 🍌",
	doge = "wow. such kill. much skill 🐕",
	oof = "OOF 💥",
	bonk = "go to jail 🔨",
	dance = "dance it off 🕺",
}
local EMOJI = {
	feathers = "🪶",
	sparkles = "✨",
	blocks = "🧱",
	firework = "🎆",
	bubbles = "🫧",
	chicken = "🐔",
	duck = "🦆",
	balloons = "🎈",
	banana = "🍌",
	lightning = "⚡",
	doge = "🐕",
	web = "🕸️",
	oof = "💥",
	bonk = "🔨",
	dance = "🕺",
	blackhole = "🕳️",
	heaven = "😇",
}
KillBannerController.EMOJI = EMOJI
KillBannerController.FUNNY = FUNNY

local gui
local current -- { frame, t0, life, shake, rainbow, sparks = { { f, v, spin } } }
local streakN, lastKillAt = 0, -math.huge
local offerCard
local offered = {} -- [effect key] = true: offered this session
local pendingOffer -- an effect key to offer once you're back on your feet

function KillBannerController.banner()
	return current and current.frame or nil
end

function KillBannerController.streak()
	return streakN
end

function KillBannerController.offer()
	return offerCard
end

-- A colour that moves through the hues (the Robux ones' banners)
local function rainbow(t, off)
	return Color3.fromHSV(((t or os.clock()) * 0.6 + (off or 0)) % 1, 0.7, 1)
end

local function text(parent, props)
	props.Parent = parent
	return Theme.text(props)
end

-- Sparkles (and bits of confetti) out of the banner's middle
local function burst(frame, n, colors)
	local sparks = {}
	for i = 1, n do
		local a = math.rad((i / n) * 360 + math.random(-12, 12))
		local speed = math.random(180, 420)
		local s = math.random(6, 14)
		local star = i % 3 ~= 0
		local f = Theme.new(star and "TextLabel" or "Frame", {
			Name = "Spark",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(s * (star and 2 or 1), s * (star and 2 or 1)),
			BackgroundTransparency = star and 1 or 0,
			BackgroundColor3 = colors[(i % #colors) + 1],
			BorderSizePixel = 0,
			ZIndex = 4,
			Parent = frame,
		})
		if star then
			f.Text = i % 2 == 0 and "✦" or "✧"
			f.TextScaled = true
			f.Font = Theme.Display
			f.TextColor3 = colors[(i % #colors) + 1]
		end
		table.insert(
			sparks,
			{ f = f, v = Vector2.new(math.cos(a), math.sin(a)) * speed, spin = math.random(-360, 360) }
		)
	end
	return sparks
end

local function clear()
	if current and current.frame then
		current.frame:Destroy()
	end
	current = nil
end

-- The banner for one of your knockouts (n: the streak so far)
local function show(k, n)
	clear()
	local it = Cosmetics.get(k.effect)
	local look = it and it.look or {}
	local premium = it and it.source == "robux"
	local tier = STREAK[math.min(n, #STREAK + 1) - 1]
	local big = tier ~= nil
	local color = tier and tier.color or (it and RARITY_COLOR[it.rarity]) or C.ink
	local w, h = big and 460 or 380, big and 104 or 84
	local f = Theme.new("Frame", {
		Name = "KillBanner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.26, 0),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = gui,
	}, {
		Theme.corner(10),
		Theme.stroke(3, C.white),
		Theme.new("UIScale", { Name = "Scale", Scale = 2.2 }),
		Theme.new("UIGradient", {
			Name = "Shine",
			Rotation = 20,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
				ColorSequenceKeypoint.new(0.45, Color3.new(1, 1, 1)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 210)),
				ColorSequenceKeypoint.new(0.55, Color3.new(1, 1, 1)),
				ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
			}),
			Offset = Vector2.new(-1, 0),
		}),
	})
	local headline = tier and tier.text or "ELIMINATED"
	text(f, {
		Name = "Headline",
		Text = headline,
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -20, 0, big and 40 or 30),
		fit = big and 36 or 26,
		Font = Theme.Display,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.white,
		outline = true,
	})
	local victim = string.upper(k.victimName or "?")
	text(f, {
		Name = "Victim",
		Text = (big and `ELIMINATED {victim}` or victim) .. (k.head and "  ·  🎯 HEADSHOT!" or ""),
		Position = UDim2.fromOffset(10, big and 46 or 36),
		Size = UDim2.new(1, -20, 0, 22),
		fit = 20,
		Font = Theme.Display,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.white,
	})
	local line = ""
	if it then
		line = `{EMOJI[look.shape] or "✨"} with {string.upper(it.name)}`
		if FUNNY[look.shape] then
			line ..= `  ·  {FUNNY[look.shape]}`
		end
	end
	text(f, {
		Name = "With",
		Text = line,
		Position = UDim2.fromOffset(10, h - 24),
		Size = UDim2.new(1, -20, 0, 18),
		fit = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Color3.fromRGB(255, 250, 220),
	})
	local colors =
		{ C.white, Color3.fromRGB(255, 220, 60), Color3.fromRGB(120, 230, 255), Color3.fromRGB(255, 110, 190) }
	current = {
		frame = f,
		t0 = os.clock(),
		life = big and 2.4 or 1.9,
		shake = tier and tier.shake or (k.head and 3 or 1.5),
		rainbow = premium,
		base = color,
		sparks = burst(f, (big and 26 or 14) + (premium and 10 or 0), colors),
	}
	return f
end

function KillBannerController.onKill(k)
	if type(k) ~= "table" then
		return
	end
	if k.victim == player.UserId then
		streakN = 0
		-- killed with a Robux one you don't have: offer it once you're back up
		local it = Cosmetics.get(k.effect)
		if
			it
			and it.source == "robux"
			and not offered[it.key]
			and not Locker.owns(Store.get("profile") or {}, it.key)
		then
			pendingOffer = it.key
		end
		return
	end
	if k.killer ~= player.UserId then
		return
	end
	local t = os.clock()
	streakN = (t - lastKillAt <= MULTI_WINDOW) and streakN + 1 or 1
	lastKillAt = t
	show(k, streakN)
end

-- "Killed by X": a small card at the bottom left with the price and GET IT
function KillBannerController.showOffer(key)
	local it = Cosmetics.get(key)
	local product = Shop.products[key]
	if not it or not product then
		return nil
	end
	offered[key] = true
	if offerCard then
		offerCard:Destroy()
	end
	local f = Theme.new("Frame", {
		Name = "KilledByOffer",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, -320, 1, -120),
		Size = UDim2.fromOffset(300, 96),
		BackgroundColor3 = C.ink,
		BorderSizePixel = 0,
		Parent = gui,
	}, { Theme.corner(10), Theme.stroke(3, Color3.fromRGB(255, 196, 40)) })
	text(f, {
		Name = "Title",
		Text = `{EMOJI[it.look and it.look.shape] or "✨"} KILLED BY {string.upper(it.name)}`,
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -44, 0, 22),
		fit = 16,
		Font = Theme.Display,
		TextColor3 = C.white,
	})
	text(f, {
		Name = "Line",
		Text = "Want it? Yours for good, on every kill.",
		Position = UDim2.fromOffset(12, 32),
		Size = UDim2.new(1, -24, 0, 16),
		fit = 12,
		TextColor3 = Color3.fromRGB(210, 210, 220),
	})
	local get = Theme.new("TextButton", {
		Name = "GetIt",
		Position = UDim2.fromOffset(12, 54),
		Size = UDim2.new(1, -24, 0, 32),
		BackgroundColor3 = Color3.fromRGB(255, 196, 40),
		Text = "",
		Parent = f,
	}, { Theme.corner(6) })
	text(get, {
		Name = "Label",
		Text = `GET IT  ·  {Format.robux(product.robux)}`,
		Size = UDim2.new(1, -8, 1, -6),
		Position = UDim2.fromOffset(4, 3),
		fit = 16,
		Font = Theme.Display,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.ink,
	})
	get.Activated:Connect(function()
		Net.send("Buy", "robux", key)
		if offerCard == f then
			offerCard = nil
		end
		f:Destroy()
	end)
	local close = Theme.new("TextButton", {
		Name = "Close",
		Position = UDim2.new(1, -30, 0, 6),
		Size = UDim2.fromOffset(24, 24),
		BackgroundTransparency = 1,
		Text = "✕",
		TextColor3 = C.white,
		Font = Theme.Display,
		TextScaled = true,
		Parent = f,
	})
	close.Activated:Connect(function()
		if offerCard == f then
			offerCard = nil
		end
		f:Destroy()
	end)
	offerCard = f
	pcall(function()
		Theme.tween(f, 0.35, { Position = UDim2.new(0, 16, 1, -120) }, Enum.EasingStyle.Back)
	end)
	task.delay(9, function()
		if offerCard == f then
			offerCard = nil
			f:Destroy()
		end
	end)
	return f
end

local function step()
	if current then
		local t = os.clock() - current.t0
		local f = current.frame
		if t >= current.life or not f.Parent then
			clear()
		else
			-- punch in: big to a little past full, back; a tilt that settles; then a fade at the end
			local scale = f:FindFirstChild("Scale")
			local e = math.clamp(t / 0.22, 0, 1)
			local s = t < 0.22 and (2.2 - 1.3 * e) or (0.9 + 0.1 * math.min(1, (t - 0.22) / 0.12))
			if scale then
				scale.Scale = s
			end
			f.Rotation = -6 * math.max(0, 1 - t / 0.35) * math.cos(t * 30)
			local amp = current.shake * math.max(0, 1 - t / 0.6)
			f.Position = UDim2.new(0.5, math.random(-100, 100) / 100 * amp, 0.26, math.random(-100, 100) / 100 * amp)
			if current.rainbow then
				f.BackgroundColor3 = rainbow(t)
			end
			local shine = f:FindFirstChild("Shine")
			if shine then
				shine.Offset = Vector2.new(-1 + (t % 1.2) / 0.6, 0)
			end
			local fade = math.clamp((t - (current.life - 0.35)) / 0.35, 0, 1)
			f.BackgroundTransparency = fade
			for _, d in f:GetDescendants() do
				if d:IsA("TextLabel") and d.Name ~= "Spark" then
					d.TextTransparency = fade
				end
			end
			for _, sp in current.sparks do
				if sp.f.Parent then
					local p = sp.v * t + Vector2.new(0, 260 * t * t)
					sp.f.Position = UDim2.new(0.5, p.X, 0.5, p.Y)
					sp.f.Rotation = sp.spin * t
					local a = math.clamp(t / 0.9, 0, 1)
					if sp.f:IsA("TextLabel") then
						sp.f.TextTransparency = a
					else
						sp.f.BackgroundTransparency = a
					end
				end
			end
		end
	end
	-- the "killed by" card: once you're back on your feet, and the screen is clear
	if pendingOffer then
		local c = player.Character
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		local alive = (Store.get("me") or {}).alive ~= false and hum and hum.Health > 0
		if alive and not Layout.panel() and not Layout.inCinema() then
			local key = pendingOffer
			pendingOffer = nil
			if not offered[key] then
				KillBannerController.showOffer(key)
			end
		end
	end
end

function KillBannerController:init()
	gui = Theme.screen("KillBanners", 14, player:WaitForChild("PlayerGui"))
	Net.listen("Kill", function(k)
		KillBannerController.onKill(k)
	end)
	RunService.RenderStepped:Connect(step)
end

return KillBannerController
