--[[
Kill effects (FX/KillEffects): every shape plays on the mock engine without an error, makes pieces, moves them, and
cleans every one of them up; every kill effect in the catalogue plays; the ones that carry a body move it and take
it away; a time scale slows them; a Kill message plays the killer's effect where the victim fell (KillFxController),
and in the victim's own kill cam it's the cam's to play, slowed, on their stand-in (never twice); the shop's
cards play their items themselves (UI/ItemPreview), a few at once, and stop when the panel closes; the win's
fireworks play all three acts (the giant gold finale too), stay under the cap on low graphics and clean up.

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

-- what an effect shows right now: how many of each kind of piece (class, shape, material) can be seen, as a line
local function makeup(h)
	local n = {}
	for _, p in h.parts do
		local k = p.ClassName
		if p:IsA("BasePart") and p.Transparency >= 0.99 and #p:GetChildren() == 0 then
			continue
		end
		if p:IsA("BasePart") then
			k ..= ":" .. (p.ClassName == "Part" and tostring(p.Shape) or "") .. ":" .. tostring(p.Material)
		end
		for _, d in p:GetChildren() do
			k ..= "+" .. d.ClassName
		end
		n[k] = (n[k] or 0) + 1
	end
	local keys = {}
	for k, c in n do
		table.insert(keys, `{k}x{c}`)
	end
	table.sort(keys)
	return table.concat(keys, " ")
end

-- every shape, one at a time: pieces made, moving, then all gone; each its own length, look and sound
local at = Vector3.new(0, 4, 40)
local looks, sounds = {}, {}
local Lighting = Engine.globals.game:GetService("Lighting")
for _, shape in KillEffects.SHAPES do
	KillEffects.clear()
	local h = KillEffects.playShape(shape, at, "red", { victimTeam = "blue", dir = Vector3.new(1, 0, 0) })
	check(`{shape}: plays`, h ~= nil)
	check(`{shape}: its own length, 1.4 to 3 s`, h and h.life >= 1.4 and h.life <= 3, h and h.life)
	local a = h and makeup(h) or ""
	Engine.advance(0.6)
	check(`{shape}: makes pieces`, KillEffects.pieces() > 0, KillEffects.pieces())
	local b = h and makeup(h) or ""
	local look = a .. " | " .. b
	check(`{shape}: looks like no other effect`, looks[look] == nil, looks[look])
	looks[look] = shape
	if KillEffects.usesBody(shape) then
		check(`{shape}: has a stand-in to carry`, h and h.body ~= nil)
	end
	local lights = 0
	for _, p in h and h.parts or {} do
		if p:FindFirstChildOfClass("PointLight") then
			lights += 1
		end
	end
	check(`{shape}: lights kept to a few`, lights <= 3, lights)
	Engine.advance(1)
	check(`{shape}: still animating (nothing broke its ticks)`, h and (h.tick ~= nil or not h.alive))
	local c = h and makeup(h) or ""
	check(`{shape}: changes as it plays (a wind-up, the hit, what's left)`, not (a == b and b == c), a)
	local heard = h and h.heard or ""
	check(`{shape}: makes a sound`, heard ~= "", heard)
	-- (the first few notes: its own cue, not another effect's)
	local cue = table.concat({ string.match(heard, "^(%S+) (%S+) (%S+)") }, " ")
	check(`{shape}: sounds like no other effect`, sounds[cue] == nil, `{cue} = {sounds[cue]}`)
	sounds[cue] = shape
	Engine.advance(2)
	check(
		`{shape}: done and cleaned up`,
		KillEffects.count() == 0 and folderCount() == 0,
		`{KillEffects.count()} {folderCount()}`
	)
	check(
		`{shape}: the screen's colour is back`,
		Lighting:FindFirstChild("TW_KillFx") == nil and Lighting:FindFirstChild("TW_Lightning") == nil
	)
end
check("no script errors playing every shape", #Engine.errors == errors0, Engine.errors[#Engine.errors])

-- every effect's shape is one there is (nothing in the catalogue falls back to another's)
for _, it in Cosmetics.list do
	if it.kind == "effect" then
		check(`{it.name}: has its own shape`, table.find(KillEffects.SHAPES, it.look.shape) ~= nil, it.look.shape)
	end
end

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

-- your own kill: the banner wears your effect (its colours, its sticker, a flash of its colour round the screen)
-- and you hear its own stinger; every effect has one
do
	local Banner = Engine.require(tree.client.Controllers.KillBannerController)
	local Audio = Engine.require(tree.client.Controllers.AudioController)
	for _, it in Cosmetics.list do
		if it.kind == "effect" then
			check(`{it.name}: a stinger of its own`, Audio.CUES["sig_" .. it.look.shape] ~= nil, it.look.shape)
		end
	end
	for i, key in { "rbx_lightning", "rbx_heaven", "rbx_doge" } do
		local before = Audio.count("sig_" .. Cosmetics.get(key).look.shape)
		Banner.onKill({
			killer = player.UserId,
			victim = 31000 + i,
			victimName = "Target",
			effect = key,
			pos = at,
		})
		local f = Banner.banner()
		check(`{key}: your banner`, f ~= nil)
		local fl = Banner.FLOURISH[Cosmetics.get(key).look.shape]
		check(`{key}: ...in its own colours`, f and fl and f.BackgroundColor3 == fl.bg)
		check(`{key}: ...its sticker at the side`, f and f:FindFirstChild("Sticker") ~= nil)
		check(`{key}: ...a flash round the screen`, f and f.Parent and f.Parent:FindFirstChild("Flourish") ~= nil)
		Engine.advance(0.3)
		local after = Audio.count("sig_" .. Cosmetics.get(key).look.shape)
		check(`{key}: ...and its stinger plays for you`, after > before, `{before} -> {after}`)
		Engine.advance(5)
		check(
			`{key}: ...all gone after`,
			Banner.banner() == nil and not (f and f.Parent and f.Parent:FindFirstChild("Flourish"))
		)
	end
end

-- the win's fireworks (FireworksController): a show in three acts, the volley, the main show with every kind of
-- shell and its crackle, and the finale's barrage ending in the giant gold shell (a flash, the boom, the arena lit);
-- on low graphics fewer of everything and never past the cap; the camera tilts up to watch and back down (not with
-- Reduced Motion); and once it's over every piece, light and the flash are gone
do
	local Fireworks = Engine.require(tree.client.Controllers.FireworksController)
	local Audio = Engine.require(tree.client.Controllers.AudioController)
	local Gfx = Engine.require(tree.client.Controllers.GraphicsController)
	local Constants = Engine.require(tree.shared.Constants)
	local GuiService = Engine.globals.game:GetService("GuiService")
	local cam = ws.CurrentCamera
	local pg = player:FindFirstChild("PlayerGui")
	local function inFolder()
		local f = ws:FindFirstChild("Fireworks")
		return f and #f:GetChildren() or 0
	end
	local function pitch()
		return math.deg(math.asin(cam.CFrame.LookVector.Y))
	end
	local function run(tier)
		Gfx.apply(tier)
		Fireworks.stop()
		cam.CFrame = CFrame.lookAt(Vector3.new(0, 5, 0), Vector3.new(0, 5, -10)) -- (looking level)
		local p0 = pitch()
		local r = { acts = {}, peak = 0, tilt = 0, lit = false, flash = false, sounds = {} }
		local cues = { "fw_launch", "fw_whistle", "fw_burst", "fw_crackle", "fw_finale" }
		local before = {}
		for _, c in cues do
			before[c] = Audio.count(c)
		end
		Fireworks.show(Vector3.new(0, 0, 40), Constants.TEAM_COLOR.blue, { radius = 40 })
		for _ = 1, (Constants.FIREWORKS_SECONDS + 5) * 10 do
			Engine.advance(0.1)
			local a = Fireworks.act()
			if a then
				r.acts[a] = true
			end
			r.peak = math.max(r.peak, Fireworks.count())
			r.tilt = math.max(r.tilt, pitch() - p0)
			local f = ws:FindFirstChild("Fireworks")
			for _, d in f and f:GetChildren() or {} do
				local l = d.Name == "FwLight" and d:FindFirstChildWhichIsA("PointLight")
				r.lit = r.lit or (l and (l.Brightness or 0) > 0) or false
			end
			r.flash = r.flash or (pg and pg:FindFirstChild("FireworksFlash") ~= nil) or false
		end
		for _, c in cues do
			r.sounds[c] = Audio.count(c) - before[c]
		end
		r.stats = Fireworks.stats()
		r.back = math.abs(pitch() - p0)
		r.cap = Fireworks.cap()
		return r
	end

	local hi = run("high")
	local st = hi.stats
	check(
		"fireworks: all three acts play",
		hi.acts.volley and hi.acts.main and hi.acts.finale,
		`{hi.acts.volley} {hi.acts.main} {hi.acts.finale}`
	)
	check("...the opening volley: rockets in waves", st.volley >= 12, st.volley)
	local kinds = 0
	for _ in st.types do
		kinds += 1
	end
	check("...the main show: big shells of every kind", st.main >= 12 and kinds == 5, `{st.main} {kinds}`)
	check("...each with a crackle after", st.crackles >= st.main * 0.8, `{st.crackles} {st.main}`)
	check("...the finale: a barrage", st.barrage >= 15, st.barrage)
	check("...ending in the giant gold shell, with a flash", st.giant and st.flash and hi.flash)
	check("...the arena lit up by the bursts", hi.lit)
	check(
		"...and heard: launches, whistles, bursts, crackles, the finale's boom",
		hi.sounds.fw_launch > 0
			and hi.sounds.fw_whistle > 0
			and hi.sounds.fw_burst > 0
			and hi.sounds.fw_crackle > 0
			and hi.sounds.fw_finale == 1,
		`{hi.sounds.fw_launch} {hi.sounds.fw_whistle} {hi.sounds.fw_burst} {hi.sounds.fw_crackle} {hi.sounds.fw_finale}`
	)
	check("...the sky full (many pieces at once)", hi.peak > 150, hi.peak)
	check("...the camera tilts up to watch", hi.tilt > 6, hi.tilt)
	check("...and back down at the end", hi.back < 4, hi.back) -- (eased back from ~14°: within a few degrees, however the frames fell)
	check(
		"...all cleaned up after",
		not Fireworks.active()
			and Fireworks.count() == 0
			and inFolder() == 0
			and not pg:FindFirstChild("FireworksFlash"),
		`{Fireworks.count()} {inFolder()}`
	)

	local lo = run("low")
	check("fireworks on low graphics: still all three acts and the giant shell", lo.stats.giant and lo.acts.volley)
	check("...never past the cap", lo.peak <= lo.cap.live and lo.stats.peak <= lo.cap.live, `{lo.peak} {lo.cap.live}`)
	check("...far fewer than on high", lo.peak < hi.peak * 0.6, `{lo.peak} {hi.peak}`)
	check("...all cleaned up after", Fireworks.count() == 0 and inFolder() == 0)

	GuiService.ReducedMotionEnabled = true
	local calm = run("high")
	check("with Reduced Motion the camera stays put", calm.tilt < 0.01 and calm.stats.giant, calm.tilt)
	GuiService.ReducedMotionEnabled = false
	Gfx.apply(nil)

	-- the old call (the match's victory) and stopping a show part way (the tutorial's skip)
	Fireworks.start("red")
	Engine.advance(1)
	check("FireworksController.start(team) still plays", Fireworks.active() and Fireworks.count() > 0)
	Fireworks.stop()
	check("...and stop() clears it at once", not Fireworks.active() and Fireworks.count() == 0 and inFolder() == 0)
end

check("no script errors", #Engine.errors == errors0, Engine.errors[#Engine.errors])

print(`FxSmoke: {passed} passed, {failed} failed`)
if failed > 0 then
	error("FxSmoke failed")
end
