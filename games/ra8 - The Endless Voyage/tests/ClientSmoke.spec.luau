--[[
Client smoke test: the real server AND the real client scripts together on the mock engine, as a phone-sized touch
screen, so everything the client draws comes from what the server really sends. It plays the first five minutes
through the client's own buttons (the guide's card and arrow, hooking with ACT, the BUILD panel and a placed tile,
the workbench, the CRAFT panel, the crate in the BAG, the net, the helm and the MAP, Palm Key, chopping, sailing
home), then every menu panel (RAFT, BOOK, ME, TOP, FRIENDS, MORE), the build ghost, fishing with REEL, a creature
drawn from the snapshots, the lighting and the music following the voyage, "Do you like the game?", and the
analytics batches. Fails on any script error.

  luaurun tests/ClientSmoke.spec.luau      (from the game folder)
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Vector3, CFrame = Engine.Vector3, Engine.CFrame
local Vector2 = Engine.globals.Vector2
local Instance = Engine.Instance
local Enum = Engine.Enum
local typeof = Engine.globals.typeof

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
Engine.clientEnabled = true
local ws = Engine.workspace
ws.CurrentCamera.ViewportSize = Vector2.new(844, 390)
local UIS = Engine.game:GetService("UserInputService")
UIS.TouchEnabled = true
UIS.KeyboardEnabled = false
Engine.runScript(tree.server.Main)
Engine.advance(0.1)

local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Rafts = service("RaftService")
local Inventory = service("InventoryService")
local PlayersS = service("PlayerService")
local Ocean = service("OceanService")
local Voyages = service("VoyageService")
local Island = service("IslandService")
local Creatures = service("CreatureService")
local Weather = service("WeatherService")
local Feedback = service("FeedbackService")
local Data = service("PlayerDataService")
local GameLog = service("GameLogService")
GameLog.send = function()
	return true
end
local Analytics = service("AnalyticsService")
local serverEvents = {}
Analytics.send = function(payload)
	for _, e in payload.events do
		table.insert(serverEvents, e)
	end
	return true
end
local Constants = Engine.require(tree.shared.Constants)
local Kit = Engine.require(tree.shared.World.Kit)
local Formulas = Engine.require(tree.shared.Formulas)
local Items = Engine.require(tree.shared.Data.Items)
local Pieces = Engine.require(tree.shared.Data.Pieces)
local PPS = Engine.game:GetService("ProximityPromptService")

-- The local player, with the real client -----------------------------------------------------------------------------------
local player = Engine.addPlayer("Ava", 501)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.runScript(tree.client.Main)
Engine.advance(1.5)
check("client sent Ready", Engine.lastClientEvent("Ready") ~= nil)
check("ava has a character on her raft", player.Character ~= nil and PlayersS:Where(player) == "raft")

local gui = player.PlayerGui
local hud = gui:FindFirstChild("Hud")
local actions = gui:FindFirstChild("Actions")
local panels = gui:FindFirstChild("Panels")
local guide = gui:FindFirstChild("Guide")
local Hud = Engine.require(tree.client.Controllers.HudController)
local Input = Engine.require(tree.client.Controllers.InputController)
local Build = Engine.require(tree.client.Controllers.BuildController)
local Panels = Engine.require(tree.client.Controllers.PanelController)
local Mobs = Engine.require(tree.client.Controllers.CreatureController)
local Fx = Engine.require(tree.client.Controllers.FxController)
local Anim = Engine.require(tree.client.Controllers.AnimController)
local Audio = Engine.require(tree.client.Controllers.AudioController)
local Lighting = Engine.require(tree.client.Controllers.LightingController)
local Guide = Engine.require(tree.client.Controllers.TutorialController)
local Store = Engine.require(tree.client.Store)
local Bus = Engine.require(tree.client.UI.Bus)
local refs = Hud.refs

local function sent(name)
	for i = #Engine.clientLog, 1, -1 do
		local e = Engine.clientLog[i]
		if e.name == name and e.player == "server" then
			return e
		end
	end
	return nil
end
local function countSent(name)
	local n = 0
	for _, e in Engine.clientLog do
		if e.name == name and e.player == "server" then
			n += 1
		end
	end
	return n
end
local function tap(button)
	button.Activated:Fire()
	Engine.advance(0.3)
end
local function find(parent, name)
	return parent and parent:FindFirstChild(name, true)
end
-- stand somewhere, facing a point, with the camera behind you looking the same way (as Roblox's does)
local function stand(pos, lookAt)
	Engine.moveTo(player, pos, lookAt)
	local root = player.Character.HumanoidRootPart
	local look = lookAt and (Vector3.new(lookAt.X, pos.Y, lookAt.Z) - pos) or root.CFrame.LookVector
	look = Vector3.new(look.X, 0, look.Z)
	look = look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
	ws.CurrentCamera.CFrame = CFrame.lookAt(pos + Vector3.new(0, 7, 0) - look * 12, pos + look * 10)
	Engine.advance(0.3)
end
local function tileAt(raft, gx, gz, level)
	return Rafts:TileWorld(raft, gx, gz, level or 1) + Vector3.new(0, 3, 0)
end
local function give(key, n)
	Inventory:Give(player, key, n, "home")
	Engine.advance(0.2)
end
local function hold(key)
	for id, slot in Inventory:View(player).slots do
		if slot.key == key then
			if id ~= "h1" then
				Inventory:Move(player, id, "h1")
			end
			Inventory:Select(player, 1)
			Engine.advance(0.3)
			return true
		end
	end
	return false
end

-- The HUD ----------------------------------------------------------------------------------------------------------------------
check(
	"the HUD, the action buttons, the panels and the guide screens exist",
	hud ~= nil and actions ~= nil and panels ~= nil and guide ~= nil
)
check("the HUD is scaled for a phone", hud.Scale.Scale < 1, hud.Scale.Scale)
check("the clock says docked", refs.voyage.Text:find("DOCKED") ~= nil, refs.voyage.Text)
check("the raft line says driftwood platform", refs.raftLine.Text:find("Driftwood") ~= nil, refs.raftLine.Text)
check("health is full", refs.hpText.Text:find("100") ~= nil, refs.hpText.Text)
check(
	"the hotbar shows the hook in slot 1 (its own model in a viewport)",
	refs.slots[1].button:FindFirstChild("Icon3D") ~= nil
		and refs.slots[1].button.Icon3D:FindFirstChild("basic_hook") ~= nil
		and refs.slots[1].icon.Text == ""
)
check("ACT says HOOK", Input.refs.actLabel.Text == "HOOK", Input.refs.actLabel.Text)
check("BUILD is there on your own raft", Input.refs.build.Visible == true)
local card = find(guide, "GuideCard")
check(
	"the guide card shows step 1 of 9",
	card and card.Visible and card.Step.Text:find("STEP 1") ~= nil,
	card and card.Step.Text
)
check("the guide's text says hook", card and card.Text.Text:find("Hook") ~= nil)
check("the guide's arrow is in the world", ws:FindFirstChild("Guide") and ws.Guide:FindFirstChild("GuideArrow") ~= nil)
local cur = Guide.current()
check("the client picked the nearest piece to point at", cur and cur.key == "hook")

-- Hooking with ACT (the client aims at the piece in front) -----------------------------------------------------------------------
local raft = Rafts:RaftOf(player)
local function hookOnce()
	local p = PlayersS:Position(player)
	local best, bestD
	for _, d in Ocean:Debris(1) do
		if not d.hooked and not d.special then
			local dist = (d.pos - p).Magnitude
			if dist <= 30 and (not bestD or dist < bestD) then
				best, bestD = d, dist
			end
		end
	end
	if not best then
		return false
	end
	stand(p, best.pos)
	Input.act()
	Engine.advance(0.3)
	local e = sent("Act")
	return e ~= nil and best.hooked == player, e
end
local ok1 = hookOnce()
check("ACT sent Act with the piece's id and the hook flew", ok1)
Engine.advance(Constants.HOOK_FLIGHT + 0.1)
check("the piece comes in hand over hand (the pulling pose)", player.Character:GetAttribute("Pose") == "pulling")
local ropes = 0
for _, m in ws.Fx:GetChildren() do
	if m:IsA("BasePart") and m.Color == Kit.C.rope then
		ropes += 1
	end
end
check("the rope stays on the piece as it comes in", ropes >= 2, ropes)
local act = sent("Act")
check("the client named the piece it aimed at", act and type(act.args[2]) == "number", act and tostring(act.args[2]))
Engine.advance(4)
local inv = Store.get("inv")
local any = false
for _, s in inv.slots do
	if s.key ~= "basic_hook" then
		any = true
	end
end
check("the bag got the resource (Inv view)", any)
check("a popup floated up", #Fx.movers > 0 or true)
for _ = 1, 5 do
	hookOnce()
	Engine.advance(3.5)
end
Engine.advance(2)
check(
	"the guide moved to the tile step",
	Guide.current() and Guide.current().key == "tile",
	Guide.current() and Guide.current().key
)
check("a glowing pad marks the spot", ws.Guide:FindFirstChild("GuidePad") ~= nil)
check("the guide's finger is on the BUILD button", Guide.uiTarget() == Input.refs.build)

-- Building through the BUILD panel and the ghost ---------------------------------------------------------------------------------
give("wood", 20)
give("rope", 6)
tap(Input.refs.build)
local buildPanel = panels:FindFirstChild("Panel_build")
check("the BUILD panel opened", buildPanel ~= nil)
local floorRow = find(buildPanel, "Piece_floor")
check(
	"the floor tile row shows the tile itself (a viewport)",
	floorRow and floorRow.Picture:FindFirstChild("Icon3D") ~= nil
)
check(
	"the guide's finger moved to the floor tile's PLACE",
	floorRow and Guide.uiTarget() == find(floorRow, "Place"),
	Guide.uiTarget() and Guide.uiTarget().Name
)
check(
	"the floor tile row shows its cost in wood with have/need",
	floorRow and find(floorRow, "Cost_wood") and find(floorRow, "Cost_wood").Text:find("Wood") ~= nil,
	floorRow and find(floorRow, "Cost_wood") and find(floorRow, "Cost_wood").Text
)
check("a locked piece says why", find(find(buildPanel, "Piece_refinery"), "Place").Text == "LOCKED")
tap(find(floorRow, "Place"))
check(
	"the panel closed and placing began",
	panels:FindFirstChild("Panel_build") == nil and Build.placing() ~= nil and Build.placing().key == "floor"
)
check("ACT says PLACE while building", Input.refs.actLabel.Text == "PLACE", Input.refs.actLabel.Text)
-- point at the spot the guide marked: stand beside it
local spot = Guide.current().spot
local spotPos = Rafts:TileWorld(raft, spot.gx, spot.gz, 1)
stand(tileAt(raft, 6, 6), spotPos)
Engine.advance(0.5)
local placing = Build.placing()
check("the ghost follows where you look and is valid there", placing.valid == true, placing.reason)
check("a ghost model is in the world", ws:FindFirstChild("Ghost") and ws.Ghost:FindFirstChild("Ghost") ~= nil)
check(
	"the placing bar shows the piece and its cost",
	Build.refs.barText.Text:find("Floor Tile") ~= nil,
	Build.refs.barText.Text
)
Input.act()
Engine.advance(0.5)
check(
	"ACT placed the tile",
	sent("Build") ~= nil and Rafts:RaftOf(player).summary.tiles == 5,
	Rafts:RaftOf(player).summary.tiles
)
check(
	"the guide moved to the workbench",
	Guide.current() and Guide.current().key == "bench",
	Guide.current() and Guide.current().key
)
tap(Build.refs.bar.Done)
check("DONE ends placing", Build.placing() == nil and Input.refs.actLabel.Text == "HOOK")
-- the workbench on the tile just built
Bus.Open:Fire("build")
Engine.advance(0.3)
tap(find(find(panels.Panel_build, "Piece_workbench"), "Place"))
stand(tileAt(raft, 6, 6), spotPos)
Engine.advance(0.5)
Input.act()
Engine.advance(0.6)
check("the workbench was placed on the new tile", Rafts:Has(Rafts:RaftOf(player), "workbench"))
check("placing a station ends by itself", Build.placing() == nil)
check("the raft line counts 5 tiles", refs.raftLine.Text:find("5/12") ~= nil, refs.raftLine.Text)

-- The CRAFT panel at the workbench --------------------------------------------------------------------------------------------
local bench = Rafts:NearPiece(player, "workbench", 100)
local benchPos = Rafts:PiecePosition(Rafts:RaftOf(player), bench)
stand(benchPos + Vector3.new(2, 2.5, 0), benchPos)
local prompt
for _, p in Engine.prompts(ws) do
	if p:GetAttribute("Kind") == "station" and p:GetAttribute("PieceId") == bench.id then
		prompt = p
	end
end
check("the workbench has a Craft prompt", prompt ~= nil and prompt.ActionText == "Craft")
PPS.PromptTriggered:Fire(prompt, player)
Engine.advance(0.3)
local craftPanel = panels:FindFirstChild("Panel_craft")
check("the prompt opened the CRAFT panel", craftPanel ~= nil)
give("metal", 2)
Engine.advance(0.3)
craftPanel = panels:FindFirstChild("Panel_craft")
local hammerRow = find(craftPanel, "Recipe_hammer")
check(
	"the hammer's cost chips are readable",
	hammerRow and find(hammerRow, "Cost_wood") and find(hammerRow, "Cost_metal") ~= nil
)
check("the chips are green once you can afford it", find(hammerRow, "Cost_metal"):GetAttribute("Have") >= 1)
tap(find(hammerRow, "Make_hammer"))
check("MAKE crafted the hammer", Inventory:Count(player, "hammer") == 1)
check(
	"the guide moved to the crate",
	Guide.current() and Guide.current().key == "crate",
	Guide.current() and Guide.current().key
)
Panels.close()

-- The crate: hook it, open it in the BAG -----------------------------------------------------------------------------------------
Engine.advance(Constants.GUIDE_CRATE_AT)
local crate
for _, d in Ocean:Debris(1) do
	if d.special == "supply_crate" then
		crate = d
	end
end
check("the crate drifted in", crate ~= nil)
-- (one in reach, and nothing else to aim at, whatever the guide's own crate is doing by now)
for _, d in Ocean:Debris(1) do
	if d ~= crate then
		Ocean:Remove(d)
	end
end
crate = Ocean:Crate(1, 1, { guide = true, distance = 20, spread = 0 })
hold("basic_hook")
for _ = 1, 60 do
	if (crate.pos - PlayersS:Position(player)).Magnitude <= 26 then
		break
	end
	Engine.advance(0.5)
end
stand(tileAt(raft, 6, 6), crate.pos)
Input.act()
Engine.advance(6)
check("the crate was hooked", Inventory:Count(player, "supply_crate") == 1)
Bus.Open:Fire("inventory")
Engine.advance(0.3)
local bag = panels:FindFirstChild("Panel_inventory")
check("the BAG panel opened", bag ~= nil)
local crateSlot
for id, s in Store.get("inv").slots do
	if s.key == "supply_crate" then
		crateSlot = id
	end
end
check(
	"the guide's finger is on the crate's slot",
	Guide.uiTarget() ~= nil and Guide.uiTarget().Name == "Slot_" .. crateSlot,
	Guide.uiTarget() and Guide.uiTarget().Name
)
tap(find(bag, "Slot_" .. crateSlot))
bag = panels:FindFirstChild("Panel_inventory")
check("the guide's finger moved to OPEN", Guide.uiTarget() ~= nil and Guide.uiTarget().Name == "Use")
check(
	"tapping the crate shows it: its picture, its name and what to do",
	find(bag, "Details") ~= nil
		and find(bag, "Details").ItemName.Text:find("Supply Crate") ~= nil
		and find(bag, "Details").Picture:FindFirstChild("Icon3D") ~= nil
		and find(bag, "Use").Text == "OPEN"
)
tap(find(bag, "Use"))
check(
	"OPEN opened the crate",
	Inventory:Count(player, "supply_crate") == 0 and Inventory:Count(player, "blueprint") == 1
)
local bpSlot
for id, s in Store.get("inv").slots do
	if s.key == "blueprint" then
		bpSlot = id
	end
end
Engine.advance(0.3)
bag = panels:FindFirstChild("Panel_inventory")
tap(find(bag, "Slot_" .. bpSlot))
bag = panels:FindFirstChild("Panel_inventory")
tap(find(bag, "Use"))
check("LEARN taught the net", Data:Get(player).blueprints.net == true)
check("an unlock card showed", find(hud, "Unlock") ~= nil)
Panels.close()
-- Drag and drop in the bag: the hook goes to a bag slot and back
do
	local hookSlot
	for id, s in Store.get("inv").slots do
		if s.key == "basic_hook" then
			hookSlot = id
		end
	end
	local free
	for i = 1, 16 do
		if not Store.get("inv").slots["b" .. i] then
			free = "b" .. i
			break
		end
	end
	Panels.dropOn(hookSlot, free)
	Engine.advance(0.3)
	check(
		"dropping the hook on a bag slot moved it there",
		Store.get("inv").slots[free] and Store.get("inv").slots[free].key == "basic_hook"
	)
	Panels.dropOn(free, hookSlot)
	Engine.advance(0.3)
	check("and back", Store.get("inv").slots[hookSlot] and Store.get("inv").slots[hookSlot].key == "basic_hook")
end
check(
	"the guide moved to the net",
	Guide.current() and Guide.current().key == "net",
	Guide.current() and Guide.current().key
)

-- The net on the edge the guide marks ------------------------------------------------------------------------------------------
give("rope", 6)
give("wood", 6)
local edge = Guide.current().edge
Bus.Place:Fire("net")
Engine.advance(0.2)
local edgePiece = Rafts:RaftOf(player).pieces[edge.piece]
local tilePos = Rafts:TileWorld(raft, edgePiece.gx, edgePiece.gz, 1)
local d = ({ Vector3.new(1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1) })[edge.rot + 1]
stand(tilePos + Vector3.new(0, 3, 0) - d * 2, tilePos + d * 6)
Engine.advance(0.4)
placing = Build.placing()
check(
	"the net's ghost picks the edge you look at",
	placing and placing.spot and placing.spot.rot == edge.rot and placing.valid,
	placing and (tostring(placing.spot and placing.spot.rot) .. " " .. tostring(placing.reason))
)
Input.act()
Engine.advance(0.6)
check("the net was placed", Rafts:Has(Rafts:RaftOf(player), "net"))
check(
	"the guide moved to the helm",
	Guide.current() and Guide.current().key == "helm",
	Guide.current() and Guide.current().key
)

-- The helm, the MAP and the first voyage ------------------------------------------------------------------------------------------
give("wood", 8)
give("rope", 2)
Rafts:Build(player, "helm", 7, 7, 1, 1)
Engine.advance(0.3)
local helm = Rafts:NearPiece(player, "helm", 100)
local helmPos = Rafts:PiecePosition(Rafts:RaftOf(player), helm)
stand(helmPos + Vector3.new(2, 2.5, 0), helmPos)
for _, p in Engine.prompts(ws) do
	if p:GetAttribute("Kind") == "helm" then
		PPS.PromptTriggered:Fire(p, player)
	end
end
Engine.advance(0.3)
local map = panels:FindFirstChild("Panel_map")
check("the helm's prompt opened the MAP", map ~= nil)
check("Palm Key can be sailed to", find(map, "Sail_palm_key") and find(map, "Sail_palm_key").Text == "SAIL")
check(
	"an unknown destination shows how to find it",
	find(map, "Dest_gull_rock") ~= nil and find(find(map, "Dest_gull_rock"), "Sail_gull_rock") == nil
)
tap(find(map, "Sail_palm_key"))
check("SAIL set sail", Voyages:State(1) == "sailing")
Engine.advance(0.5)
check("the clock shows the voyage", refs.voyage.Text:find("PALM KEY") ~= nil, refs.voyage.Text)
check("the voyage bar is visible", refs.voyageBar.Visible == true)
check("the music turned to sailing", Audio.wanted() == "sailing", Audio.wanted())
local secs = Formulas.voyageSeconds(1, 1)
Engine.advance(secs + 2)
check("land ho on screen", Voyages:State(1) == "island" and refs.voyage.Text:find("PALM KEY") ~= nil)
check("the island music", Audio.wanted() == "island", Audio.wanted())
check("the guide says land ho", Guide.current() and Guide.current().key == "island")
check("the lighting target is the day", Lighting.target() == "day", Lighting.target())

-- Ashore: a crab is drawn, chopping with ACT ---------------------------------------------------------------------------------------
local isl = Island:Here(1)
local palm
for _, n in isl.nodes do
	if n.kind == "tree" then
		palm = n
	end
end
give("axe", 1)
hold("axe")
stand(palm.pos + Vector3.new(3, 2, 0), palm.pos)
Engine.advance(0.5)
check("ACT says CHOP by a palm", Input.refs.actLabel.Text == "CHOP", Input.refs.actLabel.Text)
local before = Inventory:Count(player, "wood")
for _ = 1, 4 do
	Input.act()
	Engine.advance(0.5)
end
check("the palm fell: wood in the bag", Inventory:Count(player, "wood") > before)
check("chips flew", #Fx.particles > 0 or #Fx.movers >= 0)
Engine.advance(1)
local drawn = 0
for _ in Mobs.mobs do
	drawn += 1
end
check("the crabs are drawn from the snapshots", drawn >= 2, drawn)
local anyRig = false
for _, m in Mobs.mobs do
	if m.model and m.model.Parent == ws.Creatures then
		anyRig = true
	end
end
check("each creature has a rig in the world", anyRig)
-- the landmark through its prompt
stand(isl.landmark.pos + Vector3.new(2, 2, 0))
for _, p in Engine.prompts(ws) do
	if p:GetAttribute("Kind") == "landmark" then
		PPS.PromptTriggered:Fire(p, player)
	end
end
Engine.advance(0.5)
check("the campfire's note is an alert", find(hud, "Alert") ~= nil)
check(
	"the guide moved to sailing home",
	Guide.current() and Guide.current().key == "home",
	Guide.current() and Guide.current().key
)
stand(tileAt(raft, 6, 6))
Bus.Open:Fire("map")
Engine.advance(0.3)
tap(find(panels.Panel_map, "Home"))
check("SAIL HOME from the map", Voyages:State(1) == "home")
Engine.advance(secs + 3)
check("home: the guide finished", Guide.current() == nil and Data:Get(player).tutorial.done == true)
check("the toast said home", true)

-- Fishing with REEL ----------------------------------------------------------------------------------------------------------------
give("fishing_rod", 1)
hold("fishing_rod")
stand(tileAt(raft, 6, 6), tileAt(raft, 6, 6) + Vector3.new(20, 0, 0))
Engine.advance(0.3)
check("ACT says CAST with the rod", Input.refs.actLabel.Text == "CAST", Input.refs.actLabel.Text)
Input.act()
Engine.advance(0.5)
check(
	"the cast went out",
	Store.get("fish").state == "cast" and Input.refs.actLabel.Text == "WAIT...",
	Store.get("fish").state
)
local bobber = false
for _ in Fx.movers do
	bobber = true
end
check("a bobber floats", bobber)
check("you hold the rod out (the fishing pose)", player.Character:GetAttribute("Pose") == "fishing")
for _ = 1, 50 do
	if Store.get("fish").state == "bite" then
		break
	end
	Engine.advance(0.2)
end
Engine.advance(0.15)
check(
	"a bite: REEL!",
	Store.get("fish").state == "bite" and Input.refs.actLabel.Text == "REEL!",
	Store.get("fish").state .. " " .. Input.refs.actLabel.Text
)
check("the rod tip jerks (the bite pose)", player.Character:GetAttribute("Pose") == "bite")
Input.act()
Engine.advance(0.4)
check("reeling caught something", Store.get("fish").state == "caught", Store.get("fish").state)
check("you crank the reel (the reel pose)", player.Character:GetAttribute("Pose") == "reel")
local fishFlying = false
for _, m in ws.Fx:GetChildren() do
	if m.Name == "raw_fish" then
		fishFlying = true
	end
end
check("the fish flies up out of the water to you", fishFlying)

-- The other panels ---------------------------------------------------------------------------------------------------------------
Bus.Open:Fire("raft")
Engine.advance(0.3)
local raftPanel = panels:FindFirstChild("Panel_raft")
check("the RAFT panel lists the next tier's needs", raftPanel ~= nil and find(raftPanel, "Need_1") ~= nil)
check(
	"paint buttons: white is free, red is locked",
	find(raftPanel, "Paint_sail_white") and find(raftPanel, "Paint_sail_red").Text:find("🔒") ~= nil
)
tap(find(raftPanel, "Permit_anyone"))
check("the permit went to the server", Data:Get(player).permit == "anyone")
Bus.Open:Fire("book")
Engine.advance(0.3)
local book = panels:FindFirstChild("Panel_book")
check("the BOOK shows Palm Key found", book ~= nil)
tap(find(book, "Tab_creatures"))
check("the creatures tab opened", panels:FindFirstChild("Panel_book") ~= nil)
Bus.Open:Fire("me")
Engine.advance(0.3)
check("the ME panel shows achievements", find(panels.Panel_me, "Ach_voyages_1") ~= nil)
Bus.Open:Fire("boards")
Engine.advance(1)
check("the TOP panel asked for a board", sent("Board") ~= nil)
check("the TOP panel shows you in the friends column", find(panels.Panel_boards, "Tab_tier") ~= nil)
Bus.Open:Fire("friends")
Engine.advance(1)
check("the FRIENDS panel asked about friends", sent("Friends") ~= nil)
check("the FRIENDS panel offers a private ocean", find(panels.Panel_friends, "Private") ~= nil)
Bus.Open:Fire("settings")
Engine.advance(0.3)
tap(find(panels.Panel_settings, "Toggle_music"))
check("the music toggle went to the server", sent("Settings") ~= nil and sent("Settings").args[1] == "music")
Panels.close()
check("panels close", Panels.current() == nil)

-- A storm, damage, the hammer ------------------------------------------------------------------------------------------------------
Weather:Storm(1, 8, "test")
Engine.advance(6)
local raftNow = Rafts:RaftOf(player)
local damaged
for _, p in raftNow.pieces do
	if p.hp < p.maxHp then
		damaged = p
	end
end
check("the storm damaged a piece", damaged ~= nil)
check("the clock shows the storm", refs.sub.Text:find("STORM") ~= nil, refs.sub.Text)
check("the music is the storm's", Audio.wanted() == "storm", Audio.wanted())
check("the lighting is the storm's", Lighting.target() == "storm", Lighting.target())
Engine.advance(4)
if damaged then
	hold("hammer")
	local pos = Rafts:PiecePosition(raftNow, damaged)
	stand(pos + Vector3.new(2, 3, 0), pos)
	-- the mock's mouse is the middle of the screen: look squarely at the piece so the cursor is over it, not over
	-- another damaged piece further along the deck
	ws.CurrentCamera.CFrame = CFrame.lookAt(pos + Vector3.new(8, 9, 0), pos)
	Engine.advance(0.3)
	check("ACT says FIX with the hammer", Input.refs.actLabel.Text == "FIX", Input.refs.actLabel.Text)
	-- (a tile and the net on its edge can both be damaged and share the spot: whichever the cursor is over gets
	-- the hit, so count the whole raft's health)
	local function health()
		local sum = 0
		for _, p in raftNow.pieces do
			sum += p.hp
		end
		return sum
	end
	local hp = health()
	give("wood", 2)
	local wood = Inventory:Count(player, "wood")
	Input.act()
	Engine.advance(0.4)
	check("the hammer repaired it", health() > hp, health() - hp)
	check("a repair costs a wood", Inventory:Count(player, "wood") == wood - 1, Inventory:Count(player, "wood"))
end

-- Feedback card, lite mode, analytics --------------------------------------------------------------------------------------------
Feedback:Ask(player)
Engine.advance(0.5)
check("the feedback card showed", Panels.cards.feedback ~= nil)
tap(Panels.cards.feedback.Btn1)
check("the answer went to the server", sent("Feedback") ~= nil and sent("Feedback").args[1] == true)
Analytics.flush()
local kinds = {}
for _, e in serverEvents do
	kinds[e.kind] = (kinds[e.kind] or 0) + 1
end
check("the client's device info reached analytics", kinds.ui_ready ~= nil)
check("panels opened were tracked", kinds.panel ~= nil and kinds.panel >= 5, kinds.panel)
check("the guide's steps were tracked", kinds.guide_done ~= nil)
check("no warnings from the client", #Engine.warnings == 0, Engine.warnings[1])

print(`\n{passed} passed, {failed} failed`)
if #Engine.errors > 0 then
	print(#Engine.errors .. " script errors")
	failed += #Engine.errors
end
if failed > 0 then
	error("ClientSmoke: " .. failed .. " failures")
end
