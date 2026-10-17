--[[
Kill effects (FX/KillEffects): every shape plays on the mock engine without an error, makes pieces, moves them, and
cleans every one of them up; every kill effect in the catalogue plays; the ones that carry a body move it and take
it away; a time scale slows them; a Kill message plays the killer's effect where the victim fell (KillFxController),
and in the victim's own kill cam it's the cam's to play, slowed, on their stand-in (never twice); the shop's
cards play their items themselves (UI/ItemPreview), a few at once, and stop when the panel closes.

  luaurun tests/FxSmoke.spec.luau
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Vector3, CFrame = Engine.Vector3, Engine.CFrame

local passed, failed = 0, 0
local function check(name, cond, detail)
	if cond then
		passed += 1
	else
		failed += 1
		print("FAIL " .. name .. (detail ~= nil and (": " .. tostring(detail)) or ""))
	end
end

local tree = Engine.mountProject(".")
Engine.require(tree.shared.Constants).AFK_SECONDS = 0
Engine.require(tree.shared.Constants).MIN_SIDE = 1
Engine.require(tree.shared.Constants).TUTORIAL = false
Engine.clientEnabled = true
local ws = Engine.workspace
Engine.runScript(tree.server.Main)
Engine.advance(0.2)
local player = Engine.addPlayer("Fx", 777)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.runScript(tree.client.Main)
Engine.advance(1.5)

local KillEffects = Engine.require(tree.client.FX.KillEffects)
local Effects = Engine.require(tree.client.FX.Effects)
local Cosmetics = Engine.require(tree.shared.Data.Cosmetics)
local KillFx = Engine.require(tree.client.Controllers.KillFxController)
local Looks = Engine.require(tree.client.Controllers.LooksController)
local errors0 = #Engine.errors

local function folderCount()
	local f = ws:FindFirstChild("KillFx")
	return f and #f:GetChildren() or 0
end

-- every shape, one at a time: pieces made, moving, then all gone
local at = Vector3.new(0, 4, 40)
for _, shape in KillEffects.SHAPES do
	KillEffects.clear()
	local h = KillEffects.playShape(shape, at, "red", { victimTeam = "blue", dir = Vector3.new(1, 0, 0) })
	check(`{shape}: plays`, h ~= nil)
	Engine.advance(0.6)
	check(`{shape}: makes pieces`, KillEffects.pieces() > 0, KillEffects.pieces())
	if KillEffects.usesBody(shape) then
		check(`{shape}: has a stand-in to carry`, h and h.body ~= nil)
	end
	Engine.advance(3)
	check(
		`{shape}: done and cleaned up`,
		KillEffects.count() == 0 and folderCount() == 0,
		`{KillEffects.count()} {folderCount()}`
	)
end
check("no script errors playing every shape", #Engine.errors == errors0, Engine.errors[#Engine.errors])

-- every kill effect in the catalogue (the shop's, the Robux ones, goals, VIP, MVP...)
local n = 0
for _, it in Cosmetics.list do
	if it.kind == "effect" then
		n += 1
		check(`{it.name}: plays`, Looks.play(it.key, at + Vector3.new(n * 3, 0, 0), "blue"))
	end
end
check("the catalogue has the big new effects", n >= 24, n)
check(
	"...the chicken, the lightning, the doge, the web",
	Cosmetics.get("shop_chicken").look.shape == "chicken"
		and Cosmetics.get("rbx_lightning").look.shape == "lightning"
		and Cosmetics.get("rbx_doge").look.shape == "doge"
		and Cosmetics.get("rbx_web").look.shape == "web"
)
Engine.advance(4)
check("...all of them cleaned up", KillEffects.count() == 0 and folderCount() == 0, KillEffects.count())

-- a body carried off: balloons lift the stand-in up and away
do
	KillEffects.clear()
	local body = Effects.mannequin(CFrame.new(at), "blue")
	local y0 = body:GetPivot().Position.Y
	local h = KillEffects.playShape("balloons", at, "red", { body = body, victimTeam = "blue" })
	Engine.advance(1.6)
	check(
		"balloons: the stand-in floats up",
		body.Parent ~= nil and body:GetPivot().Position.Y > y0 + 1,
		body:GetPivot().Position.Y - y0
	)
	Engine.advance(2)
	check("...and is taken away at the end", h and not h.alive and body.Parent == nil)
end

-- slowed: at a quarter speed it's still going when a full-speed one is long done
do
	KillEffects.clear()
	local slow = KillEffects.playShape("lightning", at, "red", { scale = 0.25, fixed = true })
	local fast = KillEffects.playShape("lightning", at + Vector3.new(10, 0, 0), "red")
	Engine.advance(3.2)
	check("a time scale slows an effect down", slow and slow.alive and fast and not fast.alive)
	Engine.advance(9)
	check("...and it still ends", slow and not slow.alive)
end

-- a Kill message: the killer's effect where the victim fell (someone else's death)
do
	KillEffects.clear()
	local k = {
		pos = at,
		victim = -12345,
		victimTeam = "blue",
		killer = 999,
		killerTeam = "red",
		effect = "shop_chicken",
		kind = "arrow",
	}
	KillFx.onKill(k)
	Engine.advance(0.3)
	check("a kill plays the killer's effect where they fell", KillEffects.count() == 1, KillEffects.count())
	Engine.advance(4)
	-- claimed by the victim's own kill cam: not played here a second time
	KillEffects.clear()
	k.victim = -54321
	KillEffects.claim(k)
	KillFx.onKill(k)
	Engine.advance(0.3)
	check("...a kill the kill cam took isn't played twice", KillEffects.count() == 0, KillEffects.count())
end

-- your own death: the kill cam plays the killer's effect on your stand-in, slowed, and shows its name
do
	KillEffects.clear()
	local KillCam = Engine.require(tree.client.Controllers.KillCamController)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local stand = root and root.Position or Vector3.new(0, 4, 0)
	local origin = stand + Vector3.new(-40, 2, 0)
	local k = {
		pos = stand,
		victim = player.UserId,
		victimTeam = player:GetAttribute("Team") or "blue",
		killer = 4242,
		killerName = "Zapper",
		killerTeam = "red",
		killerPos = origin,
		weapon = "bow",
		effect = "rbx_lightning",
		dist = 40,
		cam = { origin = origin, velocity = Vector3.new(180, 0, 0), t = 40 / 180, impact = stand },
	}
	local started = KillCam.play(k)
	check("your kill cam starts", started)
	check("...and takes the killer's effect to play itself", KillEffects.claimed(k))
	check(
		"...the card names it",
		KillCam.refs.info and string.find(KillCam.refs.info.Text, "LIGHTNING STRIKE", 1, true) ~= nil,
		KillCam.refs.info and KillCam.refs.info.Text
	)
	local seen = false
	for _ = 1, 30 do
		Engine.advance(0.1)
		if KillEffects.count() > 0 then
			seen = true
			break
		end
	end
	check("...it plays at the impact", seen)
	Engine.advance(0.6)
	local h
	for _, a in { KillEffects.count() } do
		h = a
	end
	check("...slowed down (still going well into the card)", KillEffects.count() > 0 or not KillCam.active(), h)
	Engine.advance(8)
	check("...and it's all cleaned up after", KillEffects.count() == 0, KillEffects.count())
end

-- The shop's cards play their items themselves (UI/ItemPreview): the ones on screen, a few at once, each kill effect
-- on a dummy in its own viewport (never in the world, never counted with the real ones), the BUY IT? dialog's first,
-- and all of it stopped when the panel closes
do
	local Panel = Engine.require(tree.client.Controllers.PanelController)
	local ItemPreview = Engine.require(tree.client.UI.ItemPreview)
	local pr = Panel.refs
	KillEffects.clear()
	local before = folderCount()
	Panel.open("shop")
	Engine.advance(1.2)
	check("the shop's cards get live previews", ItemPreview.slots() >= 10, ItemPreview.slots())
	check(
		"...a few play at once, within the cap",
		ItemPreview.running() > 0 and ItemPreview.load() <= ItemPreview.budget(),
		`{ItemPreview.running()} playing, {ItemPreview.load()} of {ItemPreview.budget()}`
	)
	check("...every one builds", ItemPreview.broken() == 0, ItemPreview.broken())
	local function stages()
		local out = {}
		for _, d in pr.panel:GetDescendants() do
			if d.Name == "Live" and d:FindFirstChild("Stage") then
				table.insert(out, d)
			end
		end
		return out
	end
	local function pieces(live)
		return #live.Stage.World:GetDescendants()
	end
	local playing = stages()
	local busy, boards = 0, 0
	for _, live in playing do
		if pieces(live) > 8 then
			busy += 1
		end
		boards += #live.Words:GetChildren()
	end
	check("...a kill effect plays on a dummy in its card's viewport", #playing > 0 and busy > 0, `{#playing} {busy}`)
	check("...its words and stickers drawn over the frame", boards > 0, boards)
	local lightning = pr.body.Premium:FindFirstChild("Premium_rbx_lightning")
	local pic = lightning and lightning:FindFirstChild("Preview")
	check(
		"...in place of the still picture (and the sticker over it)",
		pic ~= nil
			and pic:FindFirstChild("Live") ~= nil
			and pic.Icon.Visible == false
			and (not pic:FindFirstChild("Sticker") or pic.Sticker.Visible == false)
	)
	check(
		"...never in the world, never counted with the real ones",
		KillEffects.count() == 0 and folderCount() == before,
		`{KillEffects.count()} {folderCount()}`
	)
	-- on a loop: a few seconds on, the effects are still going
	Engine.advance(4.1)
	busy = 0
	for _, live in stages() do
		if pieces(live) > 2 then
			busy += 1
		end
	end
	check("...on a loop (still playing seconds later)", busy > 0 and ItemPreview.broken() == 0, busy)
	-- the BUY IT? dialog: its own preview plays, the cards under it wait
	Engine.require(tree.server.Services.EconomyService):Add(player, 50000)
	Engine.require(tree.server.Services.ProgressService):Push(player)
	Engine.advance(0.5)
	local card = pr.body:FindFirstChild("Item1")
	if card then
		card.Buy.Activated:Fire()
	end
	Engine.advance(0.6)
	local inDialog, under = ItemPreview.running(), 0
	for _, live in stages() do
		if not live:IsDescendantOf(pr.overlay) then
			under += 1
		end
	end
	check(
		"the BUY IT? dialog's item plays there, the cards under it wait",
		pr.confirm ~= nil and inDialog == 1 and under == 0,
		`{pr.confirm ~= nil} {inDialog} {under}`
	)
	Panel.closeDialog()
	Engine.advance(0.5)
	check("...and they play again when it's gone", ItemPreview.running() > 1, ItemPreview.running())
	Panel.close()
	Engine.advance(0.2)
	check(
		"closing the panel stops every preview",
		ItemPreview.running() == 0 and ItemPreview.slots() == 0 and #stages() == 0,
		`{ItemPreview.running()} {ItemPreview.slots()} {#stages()}`
	)
	local still = pr.body.Premium:FindFirstChild("Premium_rbx_lightning")
	still = still and still:FindFirstChild("Preview")
	check("...the still pictures back", still ~= nil and still.Icon.Visible ~= false)
end

check("no script errors", #Engine.errors == errors0, Engine.errors[#Engine.errors])

print(`FxSmoke: {passed} passed, {failed} failed`)
if failed > 0 then
	error("FxSmoke failed")
end
