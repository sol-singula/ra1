--[[
The invite-a-friend card (InviteService decides when: a moment of joy, never mid-fight, never in the first minutes
or the first match being taught, a few times a visit at most):

  the promo   a big card: INVITE A FRIEND → GET A RANDOM EFFECT over a slot machine of kill effects that spins (the
              emoji, the name and the rarity flicker past, faster then slower) and lands on one, then spins again;
              a rainbow edge that turns, sparkles off it; INVITE (Roblox's own friend invite, as the HUD's button)
              and LATER. Closes itself after PROMO_SECONDS.
  the reward  a friend came from your invite (Net "InviteReward"): the same slot machine, one spin, landing on the
              effect you won (yours for good, already on): FRIEND JOINED! YOU WON <EFFECT>.
  the nudge   { pulse = true }: the HUD's INVITE button throbs for a few seconds.

Answers go back as Net "InvitePromo" ("sent", how many friends) once Roblox's invite prompt closes with someone
picked, or ("later").

  InvitePromoController.show(payload)    the promo (tests)
  InvitePromoController.reward(payload)  the reward reveal (tests)
  InvitePromoController.current()        "promo" | "reward" | nil, and the card
  InvitePromoController.landed()         the effect key the reel shows now (stopped) or nil while it spins
  InvitePromoController.invite() / .later()
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Net = require(ReplicatedStorage.Shared.Net)
local Layout = require(script.Parent.Parent.UI.Layout)
local Theme = require(script.Parent.Parent.UI.Theme)
local HudController = require(script.Parent.HudController)
local KillBanner = require(script.Parent.KillBannerController)

-- (a match's: not in the lobby, which has its own screens)
local InvitePromoController = { Name = "InvitePromoController", Order = 57, Modes = { "turf", "ctf", "brawl" } }

local C = Theme.Color
local player = Players.LocalPlayer
local PROMO_SECONDS = 22 -- the promo closes itself after this
local REWARD_SECONDS = 9
local SPIN = 2.2 -- one spin of the reel: fast, then slowing onto the one it lands on
local PAUSE = 1.6 -- (the promo) how long it rests on one before spinning again
local PULSE = 4 -- seconds the INVITE button throbs
local RARITY = {
	common = Color3.fromRGB(200, 200, 205),
	rare = Color3.fromRGB(70, 150, 255),
	epic = Color3.fromRGB(175, 80, 255),
	legendary = Color3.fromRGB(255, 190, 40),
}

local gui
local card, kind -- the card on screen, "promo" | "reward"
local reel -- { pool, target, startAt, nextAt, shown, stopped, restAt, emoji, name, rarity, glow }
local shownAt
local pulseUntil
local waitingInvite -- (the invite prompt is up from our card: its close says whether they sent it)

local function close()
	if card then
		card:Destroy()
	end
	card, kind, reel = nil, nil, nil
end

local function paintItem(key)
	local it = Cosmetics.get(key)
	if not reel or not it then
		return
	end
	reel.shown = key
	local shape = it.look and it.look.shape
	reel.emoji.Text = (KillBanner.EMOJI and KillBanner.EMOJI[shape]) or "✨"
	reel.name.Text = string.upper(it.name)
	reel.rarity.Text = string.upper(it.rarity or "")
	local col = RARITY[it.rarity] or C.white
	reel.rarity.TextColor3 = col
	reel.glow.Color = col
end

-- Spin the reel onto target (a key from the pool; a random one when nil).
local function spin(target)
	if not reel then
		return
	end
	local pool = reel.pool
	reel.target = target or pool[math.random(1, #pool)]
	reel.startAt = os.clock()
	reel.nextAt = os.clock()
	reel.stopped = false
end

local function build(title, line, buttons)
	close()
	card = Theme.card({
		Name = "InvitePromo",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(460, buttons and 300 or 250),
		BackgroundColor3 = C.white,
		Parent = gui,
	})
	Layout.modal("invitePromo", card)
	local edge = card:FindFirstChildOfClass("UIStroke")
	if edge then
		edge.Thickness = 4
	end
	Theme.title({
		Name = "Head",
		Text = title,
		Size = UDim2.new(1, -24, 0, 34),
		Position = UDim2.fromOffset(12, 12),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.ink,
		outline = false,
		Parent = card,
	})
	Theme.text({
		Name = "Line",
		Text = line,
		Size = UDim2.new(1, -24, 0, 22),
		Position = UDim2.fromOffset(12, 48),
		fit = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.muted,
		Parent = card,
	})
	-- the reel: a dark window, the effect's emoji big, its name and rarity under it
	local window = Theme.new("Frame", {
		Name = "Reel",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 78),
		Size = UDim2.fromOffset(300, 140),
		BackgroundColor3 = C.ink,
		ClipsDescendants = true,
		Parent = card,
	}, { Theme.corner(8) })
	local glow = Theme.stroke(4, C.white)
	glow.Parent = window
	local bump = Theme.new("UIScale", { Name = "Bump", Parent = window })
	local emoji = Theme.text({
		Name = "Emoji",
		Text = "✨",
		Size = UDim2.new(1, 0, 0, 74),
		Position = UDim2.fromOffset(0, 6),
		TextSize = 60,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = window,
	})
	local name = Theme.title({
		Name = "EffectName",
		Text = "",
		Size = UDim2.new(1, -16, 0, 28),
		Position = UDim2.fromOffset(8, 82),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.white,
		outline = false,
		Parent = window,
	})
	local rarity = Theme.text({
		Name = "Rarity",
		Text = "",
		Size = UDim2.new(1, -16, 0, 18),
		Position = UDim2.fromOffset(8, 112),
		TextSize = 13,
		Font = Theme.Display,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.white,
		Parent = window,
	})
	reel = {
		pool = {},
		emoji = emoji,
		name = name,
		rarity = rarity,
		glow = glow,
		bump = bump,
		window = window,
		edge = edge,
		stopped = true,
	}
	if buttons then
		local function button(bname, text, x, dark, fn)
			local b = Theme.new("TextButton", {
				Name = bname,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, x, 0, 234),
				Size = UDim2.fromOffset(dark and 230 or 130, 50),
				BackgroundColor3 = dark and C.ink or C.white,
				Text = text,
				Font = Theme.Display,
				TextSize = dark and 18 or 15,
				TextColor3 = dark and C.white or C.ink,
				AutoButtonColor = true,
				Modal = true,
				Parent = card,
			}, { Theme.corner(6), Theme.stroke(2, C.ink) })
			b.Activated:Connect(fn)
			return b
		end
		button("Invite", "👥 INVITE A FRIEND", -72, true, InvitePromoController.invite)
		button("Later", "LATER", 128, false, InvitePromoController.later)
	end
	Theme.pop(card)
	shownAt = os.clock()
	return card
end

local function poolOf(payload)
	local pool = {}
	for _, k in type(payload) == "table" and type(payload.pool) == "table" and payload.pool or {} do
		if type(k) == "string" and Cosmetics.get(k) then
			table.insert(pool, k)
		end
	end
	if #pool == 0 then
		for _, it in Cosmetics.list do
			if it.kind == "effect" then
				table.insert(pool, it.key)
			end
		end
	end
	return pool
end

function InvitePromoController.show(payload)
	if Layout.focused() then
		return nil -- (the tutorial is guiding: not now)
	end
	build(
		"INVITE A FRIEND → GET A RANDOM EFFECT",
		"When a friend joins from your invite, one of these is yours for good",
		true
	)
	kind = "promo"
	reel.pool = poolOf(payload)
	spin(nil)
	return card
end

function InvitePromoController.reward(payload)
	if type(payload) ~= "table" or not Cosmetics.get(payload.key) then
		return nil
	end
	local who = type(payload.friend) == "string" and payload.friend or "A friend"
	build("FRIEND JOINED! YOU WON...", `{who} came from your invite`, false)
	kind = "reward"
	reel.pool = poolOf(payload)
	spin(payload.key)
	return card
end

function InvitePromoController.current()
	return kind, card
end

function InvitePromoController.landed()
	return reel and reel.stopped and reel.shown or nil
end

function InvitePromoController.invite()
	if kind ~= "promo" then
		return false
	end
	waitingInvite = true
	local ok = HudController.invite()
	close()
	return ok ~= false
end

function InvitePromoController.later()
	if kind ~= "promo" then
		return false
	end
	Net.send("InvitePromo", "later")
	close()
	return true
end

-- The reel and the card's life, each frame
local function step()
	local t = os.clock()
	if pulseUntil and HudController.refs.invite then
		local b = HudController.refs.invite
		local s = b:FindFirstChild("Pulse") or Theme.new("UIScale", { Name = "Pulse", Parent = b })
		if t < pulseUntil then
			s.Scale = 1 + 0.08 * math.abs(math.sin(t * 7))
		else
			s.Scale = 1
			pulseUntil = nil
		end
	end
	if not card or not reel then
		return
	end
	-- the rainbow edge turns
	if reel.edge then
		reel.edge.Color = Cosmetics.rainbow(t)
	end
	if not reel.stopped then
		local e = (t - reel.startAt) / SPIN
		if e >= 1 then
			paintItem(reel.target)
			reel.stopped = true
			reel.restAt = t
			reel.bump.Scale = 1.12 -- (a little bump as it lands)
		elseif t >= reel.nextAt then
			local pool = reel.pool
			local k = pool[math.random(1, #pool)]
			if #pool > 1 and k == reel.shown then
				k = pool[(table.find(pool, k) % #pool) + 1]
			end
			paintItem(k)
			reel.nextAt = t + 0.05 + 0.3 * e * e -- (faster at first, slower as it lands)
		end
	else
		reel.bump.Scale = 1 + (reel.bump.Scale - 1) * 0.8
		if kind == "promo" and reel.restAt and t - reel.restAt >= PAUSE then
			spin(nil)
		end
	end
	local life = kind == "reward" and REWARD_SECONDS or PROMO_SECONDS
	if shownAt and t - shownAt >= life then
		close()
	end
end

function InvitePromoController:init()
	gui = Theme.screen("InvitePromo", 24, player:WaitForChild("PlayerGui"))
	Net.listen("InvitePromo", function(a)
		if type(a) ~= "table" then
			return
		end
		if a.pulse then
			pulseUntil = os.clock() + PULSE
		else
			InvitePromoController.show(a)
		end
	end)
	Net.listen("InviteReward", function(a)
		InvitePromoController.reward(a)
	end)
	pcall(function()
		game:GetService("SocialService").GameInvitePromptClosed:Connect(function(who, recipients)
			if who == player and waitingInvite then
				waitingInvite = false
				local n = type(recipients) == "table" and #recipients or 0
				if n > 0 then
					Net.send("InvitePromo", "sent", n)
				end
			end
		end)
	end)
	RunService.Heartbeat:Connect(step)
end

return InvitePromoController
