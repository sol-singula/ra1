--[[
The sword skins and the Crate, the real server and client on the mock engine, in lobby mode:

  * every sword skin (Data/Cosmetics kind "sword") builds everywhere it's drawn: the shop's picture (Icons), the
    blade in everyone else's hand (CombatService:HoldBow in their LookSword, FlairController bringing it alive), your
    own view model, the live preview (ItemPreview: it turns); plain box parts only (nothing round), no browns; the
    locker and the shop list them; an equip goes through the server and the blade shows it; its slash streak takes
    the skin's colour
  * the Crate (Data/Crate, CrateService, CrateController): its pool, the odds over many seeded rolls, no duplicate
    while anything's unowned, a duplicate's refund, a refusal without Shards, the grant and its save, the Robux spin
    (free in Studio while its id is 0), the analytics event, the rack with the whole pool on it, the prompt, the spin
    UI (the reel, the result card, EQUIP, SPIN AGAIN), fireworks for a legendary, everything cleaned up

  luaurun tests/CrateSmoke.spec.luau
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Vector2 = Engine.globals.Vector2

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
local Constants = Engine.require(tree.shared.Constants)
Constants.AFK_SECONDS = 0
Constants.MIN_SIDE = 1
Constants.TUTORIAL = false
Constants.applyMode("lobby")
check("the lobby mode is on", Constants.MODE == "lobby")
Engine.clientEnabled = true
local ws = Engine.workspace
ws.CurrentCamera.ViewportSize = Vector2.new(844, 390)
Engine.runScript(tree.server.Main)
Engine.advance(0.2)
local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Combat = service("CombatService")
local Data = service("PlayerDataService")
local Economy = service("EconomyService")
local Progress = service("ProgressService")
local CrateS = service("CrateService")
local Analytics = service("AnalyticsService")
local sent = {}
Analytics.send = function(payload)
	table.insert(sent, payload)
	return true
end

local foe = Engine.addPlayer("Foe", 920)
Engine.advance(0.5)
Engine.fireServer(foe, "Ready")
local player = Engine.addPlayer("Ava", 521)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.runScript(tree.client.Main)
Engine.advance(2)

local Cosmetics = Engine.require(tree.shared.Data.Cosmetics)
local Crate = Engine.require(tree.shared.Data.Crate)
local Locker = Engine.require(tree.shared.Data.Locker)
local Shop = Engine.require(tree.shared.Data.Shop)
local SwordSkins = Engine.require(tree.shared.SwordSkins)
local Store = Engine.require(tree.client.Store)
local Icons = Engine.require(tree.client.UI.Icons)
local ItemPreview = Engine.require(tree.client.UI.ItemPreview)
local Flair = Engine.require(tree.client.FX.Flair)
local FlairC = Engine.require(tree.client.Controllers.FlairController)
local CrateC = Engine.require(tree.client.Controllers.CrateController)
local Panel = Engine.require(tree.client.Controllers.PanelController)
local Swing = Engine.require(tree.client.Controllers.SwingController)
local Fireworks = Engine.require(tree.client.Controllers.FireworksController)
local Enum = Engine.Enum

local function list(kind)
	local out = {}
	for _, it in Cosmetics.list do
		if it.kind == kind then
			table.insert(out, it)
		end
	end
	return out
end

-- plain boxes only, and nothing brown (a dull orange: the hue of wood and leather, darker than gold or lava)
local function round(p)
	local s = p.Shape
	return s ~= nil and s ~= Enum.PartType.Block
end
local function brown(c)
	local r, g, b = c.R, c.G, c.B
	local mx, mn = math.max(r, g, b), math.min(r, g, b)
	if mx <= 0 or mx - mn < 0.001 then
		return false
	end
	local sat, val = (mx - mn) / mx, mx
	local h
	if mx == r then
		h = ((g - b) / (mx - mn)) % 6
	elseif mx == g then
		h = (b - r) / (mx - mn) + 2
	else
		h = (r - g) / (mx - mn) + 4
	end
	h *= 60
	return h >= 15 and h <= 48 and sat > 0.35 and val < 0.8
end
local function partsOf(root)
	local out = {}
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(out, d)
		end
	end
	return out
end
local function plain(what, root)
	local bad = {}
	for _, p in partsOf(root) do
		if round(p) then
			table.insert(bad, p.Name .. " is round")
		elseif brown(p.Color) then
			table.insert(bad, p.Name .. " is brown")
		end
	end
	check(what .. ": plain boxes, no browns", #bad == 0, table.concat(bad, ", "))
end

-- The sword skins ---------------------------------------------------------------------------------------------
local swords = list("sword")
check("10 to 12 sword skins", #swords >= 10 and #swords <= 12, #swords)
check(
	"SWORD SKIN is a kind of its own",
	table.find(Cosmetics.KINDS, "sword") and Cosmetics.KIND_NAME.sword == "SWORD SKIN"
)
do
	local shop, robux, bad = 0, 0, {}
	for _, it in swords do
		if it.source == "shop" then
			shop += 1
			if not table.find(Shop.pool, it.key) then
				table.insert(bad, it.key .. " not in the shop's pool")
			end
		elseif it.source == "robux" then
			robux += 1
			local prem
			for _, p in Shop.PREMIUM do
				if p.cosmetic == it.key then
					prem = p
				end
			end
			if not prem or prem.id ~= 0 or prem.robux ~= it.robux then
				table.insert(bad, it.key .. " not a premium product at id 0")
			end
		else
			table.insert(bad, it.key .. " from " .. tostring(it.source))
		end
	end
	check(
		"the Shards ones are in the shop's pool, the Robux ones premium products at id 0",
		#bad == 0,
		table.concat(bad, ", ")
	)
	check("2 or 3 Robux legends, the rest for Shards", robux >= 2 and robux <= 3 and shop >= 8, `{robux} {shop}`)
	local shapes = {}
	for _, it in swords do
		shapes[it.look.shape or "sword"] = true
	end
	local n = 0
	for _ in shapes do
		n += 1
	end
	check("they're drawn in several shapes", n >= 5, n)
	check(
		"the plain blade's look is the steel one",
		SwordSkins.lookOf(nil) == SwordSkins.PLAIN and SwordSkins.lookOf("shop_barcode") == SwordSkins.PLAIN
	)
	check("a sword's look is its own", SwordSkins.lookOf("shop_frostedge") == Cosmetics.get("shop_frostedge").look)
end

-- the plain blade in your hand: as it always was (steel, nothing glowing: bow skins are for bows)
Store.merge("me", { weapon = "blade" })
Engine.advance(0.3)
do
	local vm = ws.CurrentCamera:FindFirstChild("Viewmodel")
	local edge = vm and vm:FindFirstChild("Edge")
	check(
		"the plain blade: a steel edge in your hand",
		edge ~= nil and edge.Material == Enum.Material.SmoothPlastic and edge.Color.R > 0.75
	)
	check(
		"...with its grip, guard and gem",
		vm and vm:FindFirstChild("Grip") and vm:FindFirstChild("Guard") and vm:FindFirstChild("Gem")
	)
	check("...and no streak colour of its own", Swing.streakColor(nil, "red", "default") == "default")
end

local seenIcons = {}
for _, it in swords do
	local look = it.look
	-- the shop's picture
	local vf = Icons.cosmetic(it, "red", { Size = Engine.globals.UDim2.fromOffset(120, 80) })
	local model = vf and vf:FindFirstChildWhichIsA("Model")
	local parts = model and partsOf(model) or {}
	check(`{it.name}: its picture is a blade`, #parts >= 6 and model:FindFirstChild("Edge") ~= nil, #parts)
	plain(`{it.name}: picture`, vf)
	local desc = {}
	for _, p in parts do
		table.insert(desc, `{p.Name}:{math.floor(p.Size.Z * 100)}:{p.Material}:{math.floor(p.Color.R * 255)}`)
	end
	desc = table.concat(desc, " ")
	check(`{it.name}: looks like no other skin`, seenIcons[desc] == nil, seenIcons[desc])
	seenIcons[desc] = it.name
	-- the blade in someone else's hand, built by the server in their skin
	foe:SetAttribute("LookSword", it.key)
	Combat:HoldBow(foe, "blade")
	local held = foe.Character and foe.Character:FindFirstChild("HeldBow")
	local specs = SwordSkins.specs(look, foe:GetAttribute("Team"))
	local swordPart = {}
	for _, s in specs do
		swordPart[s.name] = true
	end
	check(
		`{it.name}: the server builds it in their hand`,
		held ~= nil and held:GetAttribute("Weapon") == "blade" and #partsOf(held) == #specs,
		held and #partsOf(held)
	)
	plain(`{it.name}: held`, held)
	if held then
		local edge = held:FindFirstChild("Edge")
		local want
		for _, s in specs do
			if s.name == "Edge" then
				want = s
			end
		end
		local colourOk = want and (want.token == "rainbow" or (edge and edge.Color == want.color))
		check(
			`{it.name}: ...its edge in the skin's colour and finish`,
			edge and want and colourOk and edge.Material == Enum.Material[want.material],
			edge and tostring(edge.Material)
		)
	end
	FlairC.scan()
	Engine.advance(0.15)
	if look.anim or look.particles or look.sticker then
		check(`{it.name}: alive in their hand`, FlairC.swords() >= 1, FlairC.swords())
	end
	if look.sticker then
		local guard = held and held:FindFirstChild("Guard")
		check(`{it.name}: the sticker on the guard`, guard and guard:FindFirstChild("FlairSticker") ~= nil)
	end
	if look.particles then
		local edge = held and held:FindFirstChild("Edge")
		local found = false
		for _, d in edge and edge:GetChildren() or {} do
			found = found or string.sub(d.Name, 1, 6) == "Flair_"
		end
		check(`{it.name}: {look.particles} come off it`, found)
	end
	if look.anim == "electric" then
		local most = 0
		for _ = 1, 20 do
			Engine.advance(0.1)
			most = math.max(most, Flair.count())
		end
		check(`{it.name}: lightning crackles down it`, most > 0)
	end
	-- the live preview: the picture turns
	local screen = Engine.Instance.new("ScreenGui")
	screen.Parent = Engine.Players.LocalPlayer:WaitForChild("PlayerGui")
	local box = Engine.Instance.new("Frame")
	box.Name = "Preview"
	box.Size = Engine.globals.UDim2.fromOffset(120, 80)
	local icon = Icons.cosmetic(it, "red", { Size = Engine.globals.UDim2.fromOffset(120, 80), Parent = box })
	box.Parent = screen
	local before = {}
	for _, p in partsOf(icon) do
		before[p] = p.CFrame
	end
	ItemPreview.attach(box, it)
	Engine.advance(0.5)
	local moved = false
	for p, cf in before do
		moved = moved or p.CFrame ~= cf
	end
	check(
		`{it.name}: its preview turns`,
		ItemPreview.running() >= 1 and moved and ItemPreview.broken() == 0,
		`{ItemPreview.running()} running, {ItemPreview.broken()} broken`
	)
	ItemPreview.stop()
	screen:Destroy()
	-- in your own hand
	local prof = Store.get("profile") or {}
	local equipped = table.clone(prof.equipped or {})
	equipped.sword = it.key
	Store.set("profile", { equipped = equipped })
	Engine.advance(0.25)
	local vm = ws.CurrentCamera:FindFirstChild("Viewmodel")
	check(`{it.name}: in your own hand`, vm and vm:FindFirstChild("Edge") ~= nil and #partsOf(vm) >= #specs)
	-- (the blade's own parts: your arms round it are the game's hands, round where hands are)
	local blade = Engine.Instance.new("Model")
	for _, q in vm and vm:GetChildren() or {} do
		if swordPart[q.Name] then
			local copy = Engine.Instance.new("Part")
			copy.Name, copy.Shape, copy.Color = q.Name, q.Shape, q.Color
			copy.Parent = blade
		end
	end
	check(`{it.name}: ...every piece of it`, #blade:GetChildren() == #specs, #blade:GetChildren())
	plain(`{it.name}: view model`, blade)
	-- its slash streak
	local sc = Swing.streakColor(it.key, "red", "default")
	check(`{it.name}: a streak colour of its own`, (SwordSkins.trailToken(look) == nil) == (sc == "default"))
end
foe:SetAttribute("LookSword", nil)
Combat:HoldBow(foe, "blade")
FlairC.scan()
Engine.advance(0.1)
check("no skin: the plain blade, nothing added", FlairC.swords() == 0, FlairC.swords())

-- an equip through the server: only what you own, and everyone's attribute
do
	local key = "shop_frostedge"
	Engine.fireServer(player, "Settings", "equip", { kind = "sword", key = key })
	Engine.advance(0.2)
	check("a sword skin you don't own can't be worn", Data:Get(player).equipped.sword ~= key)
	Economy:Give(player, key)
	Engine.fireServer(player, "Settings", "equip", { kind = "sword", key = key })
	Engine.advance(0.3)
	check("owned: it's worn", Data:Get(player).equipped.sword == key)
	check("...on the Player for every client", player:GetAttribute("LookSword") == key)
	check("...and in the profile the client shows", ((Store.get("profile") or {}).equipped or {}).sword == key)
	local vm = ws.CurrentCamera:FindFirstChild("Viewmodel")
	local edge = vm and vm:FindFirstChild("Edge")
	check(
		"...the blade in your hand shows it (ice)",
		edge and edge.Material == Enum.Material.Ice,
		edge and tostring(edge.Material)
	)
	Combat:HoldBow(player, "blade")
	local held = player.Character and player.Character:FindFirstChild("HeldBow")
	check("...and the one everyone else sees", held and held.Edge.Material == Enum.Material.Ice)
	check(
		"the locker says how a Robux one is had",
		string.find(Locker.how(Cosmetics.get("rbx_scythe")), "TAP TO GET", 1, true) ~= nil
	)
end

-- the locker and the shop list them
do
	Panel.open("locker")
	local pr = Panel.refs
	local chip = pr.body:FindFirstChild("Chip_sword")
	check("the locker has a SWORD chip", chip ~= nil)
	if chip then
		chip.Activated:Fire()
		Engine.advance(0.2)
	end
	local found = {}
	for _, d in pr.body:GetChildren() do
		local k = d:GetAttribute("Key")
		if k and Cosmetics.get(k) and Cosmetics.get(k).kind == "sword" then
			found[k] = d
		end
	end
	local n = 0
	for _ in found do
		n += 1
	end
	check("the locker lists every sword skin", n == #swords, n)
	local worn = found.shop_frostedge
	check("...the worn one says so", worn and worn.Line.Text == "WEARING", worn and worn.Line.Text)
	Panel.open("shop")
	Engine.advance(0.2)
	local section = pr.body:FindFirstChild("All_sword")
	check(
		"the shop has an ALL SWORD SKINS section",
		section ~= nil and section.Text == "ALL SWORD SKINS",
		section and section.Text
	)
	local cards = 0
	for _, d in pr.body:GetChildren() do
		local k = d:GetAttribute("Key")
		if k and Cosmetics.get(k) and Cosmetics.get(k).kind == "sword" and Cosmetics.get(k).source == "shop" then
			cards += 1
		end
	end
	check("...with a card for each Shards one", cards >= 9, cards)
	local prem = pr.premiumCards and pr.premiumCards.rbx_lightningfang
	check("the Robux ones are on the premium row", prem ~= nil)
	Panel.close()
	Engine.advance(0.2)
end

-- The Crate: the data ----------------------------------------------------------------------------------------------
do
	local bad, kinds = {}, {}
	for _, k in Crate.pool do
		local it = Cosmetics.get(k)
		if not it or it.source ~= "shop" or not table.find(Crate.KINDS, it.kind) then
			table.insert(bad, k)
		else
			kinds[it.kind] = (kinds[it.kind] or 0) + 1
		end
	end
	check(
		"the pool: shop cosmetics of five kinds, never a title or a Robux one",
		#bad == 0 and kinds.sword and kinds.skin and kinds.trail and kinds.effect and kinds.banner and not kinds.title,
		table.concat(bad, ",")
	)
	local n = 0
	for _, it in Cosmetics.list do
		if it.source == "shop" and table.find(Crate.KINDS, it.kind) then
			n += 1
		end
	end
	check("...all of them", #Crate.pool == n and n >= 40, `{#Crate.pool} of {n}`)
	check("the odds add up to 100", Crate.ODDS.common + Crate.ODDS.rare + Crate.ODDS.epic + Crate.ODDS.legendary == 100)
	check(
		"the odds line says them",
		Crate.oddsLine() == "COMMON 55% · RARE 30% · EPIC 12% · LEGENDARY 3%",
		Crate.oddsLine()
	)
	check(
		"a spin costs Shards or Robux",
		Crate.PRICE == 250
			and Crate.PRODUCT.robux == 99
			and Crate.PRODUCT.id == 0
			and Shop.products.crate == Crate.PRODUCT
	)
	-- the odds, over many seeded rolls with nothing owned
	local rng = Engine.globals.Random.new(1234)
	local counts = { common = 0, rare = 0, epic = 0, legendary = 0 }
	local N = 20000
	local dups = 0
	for _ = 1, N do
		local key, dup = Crate.roll(rng, nil)
		counts[Cosmetics.get(key).rarity] += 1
		if dup then
			dups += 1
		end
	end
	local off = {}
	for r, want in Crate.ODDS do
		local got = counts[r] / N * 100
		if math.abs(got - want) > 1.5 then
			table.insert(off, `{r} {got}% (want {want}%)`)
		end
	end
	check("the roll respects the odds over 20,000 rolls", #off == 0, table.concat(off, ", "))
	check("...never a duplicate with nothing owned", dups == 0, dups)
	-- the same seed rolls the same
	local a, b = Engine.globals.Random.new(77), Engine.globals.Random.new(77)
	local same = true
	for _ = 1, 50 do
		same = same and Crate.roll(a, nil) == Crate.roll(b, nil)
	end
	check("a seeded roll is repeatable", same)
	-- no duplicate while anything's unowned; then only duplicates
	local owned = {}
	local function owns(k)
		return owned[k] == true
	end
	local early = 0
	for _ = 1, #Crate.pool do
		local key, dup = Crate.roll(rng, owns)
		if dup or owned[key] then
			early += 1
		end
		owned[key] = true
	end
	local all = true
	for _, k in Crate.pool do
		all = all and owned[k]
	end
	check("no duplicate until the whole pool is yours", early == 0 and all, `{early} early`)
	local _, dup = Crate.roll(rng, owns)
	check("...then a duplicate", dup == true)
	check("a duplicate gives half the Shards back", Crate.refund() == 125, Crate.refund())
end

-- The Crate: the service --------------------------------------------------------------------------------------------
local function crateEvents(since)
	local out = {}
	for i = since + 1, #Engine.clientLog do
		local e = Engine.clientLog[i]
		if e.name == "Crate" and e.player == player then
			table.insert(out, e.args[1])
		end
	end
	return out
end
local function toastsSince(since)
	local out = {}
	for i = since + 1, #Engine.clientLog do
		local e = Engine.clientLog[i]
		if e.name == "Toast" and e.player == player then
			table.insert(out, e.args[1])
		end
	end
	return out
end
do
	CrateS.rng = Engine.globals.Random.new(9)
	local p = Data:Get(player)
	p.shards = 0
	local m = #Engine.clientLog
	local r, why = CrateS:Spin(player, "shards")
	check("no Shards: refused, told why", r == nil and why == "You need 250 more Shards.", why)
	Engine.fireServer(player, "Crate", "spin", "shards")
	Engine.advance(0.2)
	check(
		"...over the wire too: a toast, no roll",
		#crateEvents(m) == 0 and #toastsSince(m) == 1 and p.shards == 0,
		#toastsSince(m)
	)
	Economy:Add(player, 1000, "test")
	m = #Engine.clientLog
	Engine.fireServer(player, "Crate", "spin", "shards")
	Engine.advance(0.3)
	local got = crateEvents(m)
	check("with Shards: one roll, the Shards spent", #got == 1 and p.shards == 750, `{#got} {p.shards}`)
	local key = got[1] and got[1].key
	local it = key and Cosmetics.get(key)
	check(
		"...a pool item, granted",
		it ~= nil
			and table.find(Crate.pool, key) ~= nil
			and p.owned[key] == true
			and got[1].dup == false
			and got[1].paid == "shards"
	)
	check("...the client's profile has it", ((Store.get("profile") or {}).owned or {})[key] == true)
	local saved = Engine.dataStores[Constants.PROFILE_STORE]
		and Engine.dataStores[Constants.PROFILE_STORE]["u_" .. player.UserId]
	check("...and it's saved at once", saved ~= nil and saved.owned and saved.owned[key] == true)
	Analytics.flush()
	local tracked
	for _, payload in sent do
		for _, e in payload.events or {} do
			if e.kind == "crate_spin" and e.user_id == player.UserId then
				tracked = e
			end
		end
	end
	check(
		"analytics: crate_spin { kind, key, rarity, paid }",
		tracked ~= nil
			and tracked.data.key == key
			and tracked.data.kind == it.kind
			and tracked.data.rarity == it.rarity
			and tracked.data.paid == "shards",
		tracked and tracked.data.key
	)
	-- the Robux spin: a developer product, free in Studio while its id is 0
	m = #Engine.clientLog
	Engine.fireServer(player, "Crate", "spin", "robux")
	Engine.advance(0.3)
	got = crateEvents(m)
	check(
		"the Robux spin: a roll, no Shards spent",
		#got == 1 and got[1].paid == "robux" and p.shards == 750 and p.owned[got[1].key] == true,
		#got
	)
	check("...counted", p.stats.crateSpins == 2, p.stats.crateSpins)
end

-- The Crate: the lobby ----------------------------------------------------------------------------------------------
do
	local folder = ws:FindFirstChild("Crate")
	check("the crate stands in the lobby", folder ~= nil and folder:FindFirstChild("CrateBox") ~= nil)
	local body = folder and folder.CrateBox:FindFirstChild("Body")
	check("...on its stand", body and (body.Position - Crate.ANCHOR).Magnitude < 6, body and tostring(body.Position))
	check(
		"...with a sign: the prices and the odds",
		body and body:FindFirstChild("Sign") and body.Sign.Odds.Text == Crate.oddsLine()
	)
	local c0 = body and body.CFrame
	Engine.advance(0.3)
	check("...turning", body and body.CFrame ~= c0)
	local prompts = Engine.prompts(folder)
	check("one prompt on it: SPIN", #prompts == 1 and prompts[1].ActionText == "SPIN", #prompts)
	plain("the crate", folder.CrateBox)
	-- the rack: the whole pool on it
	local rack = CrateC.rack()
	check("the rack holds the whole pool", #rack == #Crate.pool, `{#rack} of {#Crate.pool}`)
	local bad = {}
	local byKind = {}
	for _, e in rack do
		byKind[e.item.kind] = (byKind[e.item.kind] or 0) + 1
		if #e.parts == 0 then
			table.insert(bad, e.key .. " has no parts")
		end
		local lab = e.parts[1] and e.parts[1]:FindFirstChild("Label")
		local nameL = lab and lab:FindFirstChild("Name")
		if not nameL or nameL.Text ~= e.item.name or lab.Rarity.Text ~= string.upper(e.item.rarity) then
			table.insert(bad, e.key .. " unlabelled")
		end
	end
	check("...each one built, with its name and rarity", #bad == 0, table.concat(bad, ", "))
	check("...a shelf a kind", byKind.sword and byKind.skin and byKind.trail and byKind.effect and byKind.banner)
	plain("the rack", folder.Rack)
	local xs = {}
	for _, e in rack do
		local p = e.parts[1]
		if p and e.item.kind == "sword" then
			table.insert(xs, p.Position.X)
		end
	end
	table.sort(xs)
	check(
		"the swords stand in a row you can walk along",
		#xs >= 9 and xs[#xs] - xs[1] > 10,
		xs[#xs] and xs[#xs] - xs[1]
	)
	-- the floating ones turn, the swords are alive
	local burst
	for _, e in rack do
		if e.item.kind == "effect" then
			burst = e.parts[1]
		end
	end
	local b0 = burst and burst.CFrame
	Engine.advance(0.3)
	check("the effects float and turn", burst and burst.CFrame ~= b0)
	local labels = 0
	for _, d in folder:GetDescendants() do
		if d:IsA("BillboardGui") and d.Name == "Label" then
			labels += 1
		end
	end
	check("one label an item (gone past 40 studs)", labels == #Crate.pool, labels)
end

-- The Crate: the spin on screen --------------------------------------------------------------------------------------
do
	local p = Data:Get(player)
	local prompts = Engine.prompts(ws.Crate)
	prompts[1].Triggered:Fire(player)
	Engine.advance(0.2)
	local cr = CrateC.refs
	check("the prompt opens the panel on the offer", CrateC.state() == "offer" and cr.card.Visible == true)
	check("...the odds on it", string.find(cr.odds.Text, "LEGENDARY 3%", 1, true) ~= nil, cr.odds.Text)
	check(
		"...SPIN for Shards and for Robux",
		cr.spinShards.Text == "SPIN  ◆ 250" and string.find(cr.spinRobux.Text, "99", 1, true) ~= nil,
		cr.spinShards.Text
	)
	check("...what you have", string.find(cr.have.Text, "750", 1, true) ~= nil, cr.have.Text)
	-- not enough: told, nothing sent
	local shards = p.shards
	p.shards = 10
	Progress:Push(player)
	Engine.advance(0.1)
	local m = #Engine.clientLog
	cr.spinShards.Activated:Fire()
	Engine.advance(0.2)
	check(
		"short of Shards: told on the card, no roll",
		CrateC.state() == "offer" and string.find(cr.note.Text, "240 more", 1, true) ~= nil and #crateEvents(m) == 0,
		cr.note.Text
	)
	p.shards = shards
	Progress:Push(player)
	Engine.advance(0.1)
	-- a legendary, so the fireworks go: everything but one legendary owned
	local lastLegend
	for _, k in Crate.pool do
		local it = Cosmetics.get(k)
		if it.rarity == "legendary" and not lastLegend then
			lastLegend = k
		else
			p.owned[k] = true
		end
	end
	m = #Engine.clientLog
	cr.spinShards.Activated:Fire()
	check("SPIN: the roll asked for", CrateC.state() == "waiting" or CrateC.state() == "spinning", CrateC.state())
	Engine.advance(0.3)
	check("the roll came back: the reel turns", CrateC.state() == "spinning", CrateC.state())
	local got = crateEvents(m)
	check(
		"...the only unowned one: the legendary",
		#got == 1 and got[1].key == lastLegend and got[1].dup == false,
		got[1] and got[1].key
	)
	local cards = cr.strip:GetChildren()
	check(
		"...24 cards flick past, the win among them",
		#cards == 24 and cr.strip.Card21:FindFirstChild("Name").Text == Cosmetics.get(lastLegend).name,
		#cards
	)
	local x0 = cr.strip.Position.X.Offset
	Engine.advance(1)
	check("...sliding", cr.strip.Position.X.Offset < x0 and CrateC.state() == "spinning")
	local lid = ws.Crate.CrateBox.Lid
	check(
		"...the crate shakes and its lid pops",
		(lid.Position - ws.Crate.CrateBox.Body.Position).Y > 1.4,
		(lid.Position - ws.Crate.CrateBox.Body.Position).Y
	)
	Engine.advance(2.5)
	check("...still turning at 3.8 s", CrateC.state() == "spinning", CrateC.state())
	Engine.advance(1)
	check(
		"4.5 s on: it lands on the win",
		CrateC.state() == "result" and cr.name.Text == Cosmetics.get(lastLegend).name,
		CrateC.state()
	)
	check("...the rarity band", string.find(cr.band.Text, "LEGENDARY", 1, true) ~= nil, cr.band.Text)
	local bc = cr.burst.BackgroundColor3
	check(
		"...a burst in its colour",
		math.floor(bc.R * 255 + 0.5) == 240
			and math.floor(bc.G * 255 + 0.5) == 160
			and cr.burst.BackgroundTransparency < 1,
		cr.burst.BackgroundTransparency
	)
	check("...fireworks over the crate for a legendary", Fireworks.active() == true)
	check("...its live picture", cr.resultPic:FindFirstChild("Icon") ~= nil and ItemPreview.slots() >= 1)
	check(
		"...EQUIP and SPIN AGAIN, and the odds to see",
		cr.equip.Text == "EQUIP"
			and cr.again.Text == "SPIN AGAIN"
			and cr.seeOdds.Visible ~= false
			and cr.odds.Visible ~= false
	)
	local it = Cosmetics.get(lastLegend)
	cr.equip.Activated:Fire()
	Engine.advance(0.3)
	check("EQUIP wears it", p.equipped[it.kind] == lastLegend and cr.equip.Text == "EQUIPPED ✓", p.equipped[it.kind])
	Engine.advance(1)
	check("the burst is gone", cr.burst.BackgroundTransparency == 1)
	-- a duplicate now: everything's owned
	cr.again.Activated:Fire()
	check("SPIN AGAIN: the offer again", CrateC.state() == "offer")
	local before = p.shards
	m = #Engine.clientLog
	cr.spinShards.Activated:Fire()
	Engine.advance(5)
	got = crateEvents(m)
	check(
		"all owned: a duplicate, half the Shards back",
		#got == 1 and got[1].dup == true and got[1].refund == 125 and p.shards == before - 250 + 125,
		`{p.shards} from {before}`
	)
	check(
		"...the card says so",
		CrateC.state() == "result"
			and string.find(cr.resultLine.Text, "DUPLICATE", 1, true) ~= nil
			and cr.equip.Text == "YOURS ALREADY",
		cr.resultLine.Text
	)
	-- close: all cleaned up
	cr.close.Activated:Fire()
	Engine.advance(0.2)
	check(
		"closed: nothing left of the spin",
		CrateC.state() == nil and cr.card.Visible == false and #cr.strip:GetChildren() == 0 and ItemPreview.slots() == 0
	)
	Engine.advance(4)
	check("the loose bits clear", Flair.count() < 30, Flair.count())
	CrateC.clear()
	check("the crate and the rack go when asked", ws:FindFirstChild("Crate") == nil and #CrateC.rack() == 0)
end

print(`\n{passed} passed, {failed} failed`)
if #Engine.errors > 0 then
	for i = 1, math.min(8, #Engine.errors) do
		print(Engine.errors[i])
	end
	print(#Engine.errors .. " script errors")
	failed += #Engine.errors
end
if failed > 0 then
	error("CrateSmoke: " .. failed .. " failures")
end
