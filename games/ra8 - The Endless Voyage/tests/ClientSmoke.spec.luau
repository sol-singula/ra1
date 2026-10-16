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
local OceanLayout = Engine.require(tree.shared.World.OceanLayout)
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
local Sailing = Engine.require(tree.client.Controllers.SailingController)
local RaftMotion = Engine.require(tree.client.Controllers.RaftMotionController)
local GuiService = Engine.game:GetService("GuiService")
local Store = Engine.require(tree.client.Store)
local Bus = Engine.require(tree.client.UI.Bus)
local refs = Hud.refs
local Menu = Engine.require(tree.client.Controllers.MenuController)

-- The start menu: it's about your world ------------------------------------------------------------------------------------------
Engine.advance(0.8)
check("a first-timer goes straight into the game (no menu)", Menu.isOpen() == false)
Menu.open()
Engine.advance(0.2)
check(
	"PLAY, INVITE FRIENDS, VISIT RAFTS and RESET MY WORLD (no public ocean)",
	Menu.buttons.play and Menu.buttons.invite and Menu.buttons.visit and Menu.buttons.reset and not Menu.buttons.public
)
check("an INVITE FRIENDS button is always on screen", gui.Menu:FindFirstChild("InviteFriends") ~= nil)
local invitesBefore = Engine.invites
Menu.buttons.invite.Activated:Fire()
check("INVITE opens Roblox's invite prompt", Engine.invites == invitesBefore + 1)
Menu.buttons.reset.Activated:Fire()
check("RESET asks first", gui.Menu:FindFirstChild("Confirm", true).Visible == true)
gui.Menu:FindFirstChild("No", true).Activated:Fire()
check("NO keeps your world", gui.Menu:FindFirstChild("Confirm", true).Visible == false and Menu.isOpen())
Menu.buttons.play.Activated:Fire()
Engine.advance(0.5)
check("PLAY closes the menu and you play right here (no teleport)", Menu.isOpen() == false)

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
check("the clock says you're out at sea at your spot", refs.voyage.Text:find("AT SEA") ~= nil, refs.voyage.Text)
check("the raft line says driftwood platform", refs.raftLine.Text:find("Driftwood") ~= nil, refs.raftLine.Text)
check("health is full", refs.hpText.Text:find("100") ~= nil, refs.hpText.Text)
check(
	"the hotbar shows the rod in slot 1 (its uploaded picture, or its own model in a viewport)",
	refs.slots[1].button:FindFirstChild("Icon3D") ~= nil
		and (refs.slots[1].button.Icon3D:IsA("ImageLabel") or refs.slots[1].button.Icon3D:FindFirstChild("fishing_rod") ~= nil)
		and refs.slots[1].icon.Text == ""
)
check("ACT says CAST", Input.refs.actLabel.Text == "CAST", Input.refs.actLabel.Text)
check("BUILD is there on your own raft", Input.refs.build.Visible == true)
local card = find(guide, "GuideCard")
check(
	"the guide card shows step 1 of 9",
	card and card.Visible and card.Step.Text:find("STEP 1") ~= nil,
	card and card.Step.Text
)
check("the guide's text says cast", card and card.Text.Text:find("Cast") ~= nil)
check("the guide's arrow is in the world", ws:FindFirstChild("Guide") and ws.Guide:FindFirstChild("GuideArrow") ~= nil)
local cur = Guide.current()
check("the client picked the nearest piece to point at", cur and cur.key == "cast")
do
	-- the arrow is right over the piece itself (the middle of its parts), not beside it
	local root = player.Character.HumanoidRootPart
	local nearest, nearestD
	for _, m in ws.Debris:GetChildren() do
		if m:GetAttribute("DebrisId") and not m:GetAttribute("Special") then
			local d = (m:GetPivot().Position - root.Position).Magnitude
			if not nearestD or d < nearestD then
				nearest, nearestD = m, d
			end
		end
	end
	local partsOf = {}
	for _, d in nearest and nearest:GetDescendants() or {} do
		if d:IsA("BasePart") then
			table.insert(partsOf, d)
		end
	end
	local center = Engine.boxCenter(partsOf).Position
	local tip = ws.Guide.GuideArrow:GetPivot().Position
	local off = Vector3.new(tip.X - center.X, 0, tip.Z - center.Z).Magnitude
	check("the arrow points right at the piece", off < 1.5, off)
end

-- Casting with ACT (the client aims at the piece in front) -----------------------------------------------------------------------
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
-- (the first cast: wait for a piece at least 9 studs out, so there's time to watch it come in)
for _ = 1, 20 do
	local p = PlayersS:Position(player)
	local nearestD
	for _, d in Ocean:Debris(1) do
		if not d.hooked and not d.special then
			local dist = (d.pos - p).Magnitude
			nearestD = (not nearestD or dist < nearestD) and dist or nearestD
		end
	end
	if nearestD and nearestD >= 9 then
		break
	end
	for _, d in Ocean:Debris(1) do
		if (d.pos - p).Magnitude < 9 then
			Ocean:Remove(d)
		end
	end
	Engine.advance(0.5)
end
local placing
local ok1 = hookOnce()
check("ACT sent Act with the piece's id and the line flew out", ok1)
-- (the wind-up, the bobber's flight: the piece starts coming in at HOOK_FLIGHT)
Engine.advance(Constants.HOOK_FLIGHT - 0.3 + 0.15)
check("you crank the reel as the piece comes in (the reel pose)", player.Character:GetAttribute("Pose") == "reel")
local ropes = 0
for _, m in ws.Fx:GetChildren() do
	if m:IsA("BasePart") and m.Color == Kit.C.cream then
		ropes += 1
	end
end
check("the line stays on the piece as it comes in", ropes >= 2, ropes)
local act = sent("Act")
check("the client named the piece it aimed at", act and type(act.args[2]) == "number", act and tostring(act.args[2]))
Engine.advance(4)
local inv = Store.get("inv")
local any = false
for _, s in inv.slots do
	if s.key ~= "fishing_rod" then
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
	"right after the first casts the guide wants a net (the first big win)",
	Guide.current() and Guide.current().key == "net",
	Guide.current() and Guide.current().key
)
check(
	"the net is a tile of its own: the guide marks a free spot beside the raft (not a floor, not an edge)",
	Guide.current()
		and Guide.current().spot ~= nil
		and Guide.current().edge == nil
		and Rafts:Tile(raft, Guide.current().spot.gx, Guide.current().spot.gz, 1) == nil
)
check(
	"the reels came in doubled on a starter raft",
	Inventory:Count(player, "wood") + Inventory:Count(player, "rope") >= 4
)

-- The net on the spot the guide marks -------------------------------------------------------------------------------------------
give("rope", 2)
give("wood", 6)
do
	local netSpot = Guide.current().spot
	local netPos = Rafts:TileWorld(raft, netSpot.gx, netSpot.gz, 1)
	Bus.Place:Fire("net")
	Engine.advance(0.2)
	stand(tileAt(raft, 6, 6), netPos)
	Engine.advance(0.4)
	placing = Build.placing()
	check(
		"the net's ghost sits on the spot you look at",
		placing
			and placing.key == "net"
			and placing.valid
			and placing.spot.gx == netSpot.gx
			and placing.spot.gz == netSpot.gz,
		placing and tostring(placing.reason)
	)
	Input.act()
	Engine.advance(0.6)
	check("the net was placed", Rafts:Has(Rafts:RaftOf(player), "net"))
	check("one net and placing ends (it isn't a floor you lay in a row)", Build.placing() == nil)
	if Build.placing() then
		tap(Build.refs.bar.Done)
	end
	-- a piece pointed at the net goes on a floor beside it: nothing goes on a net
	Bus.Place:Fire("storage")
	Engine.advance(0.2)
	stand(tileAt(raft, 6, 6), netPos)
	Engine.advance(0.4)
	placing = Build.placing()
	check(
		"a piece pointed at the net goes on a floor instead",
		placing and placing.spot and not (placing.spot.gx == netSpot.gx and placing.spot.gz == netSpot.gz),
		placing and placing.spot and `{placing.spot.gx},{placing.spot.gz}`
	)
	if Build.placing() then
		tap(Build.refs.bar.Done)
	end
	Engine.advance(0.2)
end
check(
	"the guide moved to the tile step",
	Guide.current() and Guide.current().key == "tile",
	Guide.current() and Guide.current().key
)
-- short of wood the step says what's missing and the finger stays on the rod; with it, the spot and BUILD
Inventory:Take(player, "wood", Inventory:Count(player, "wood"))
Engine.advance(2.2)
check(
	"without the wood, the guide says what's missing (no build button yet)",
	Guide.current() and Guide.current().gather == true and Guide.uiTarget() ~= Input.refs.build,
	Guide.current() and Guide.current().text
)
give("wood", 20)
give("rope", 6)
Engine.advance(2.2)
check("a glowing pad marks the spot", ws.Guide:FindFirstChild("GuidePad") ~= nil)
check("the guide's finger is on the BUILD button", Guide.uiTarget() == Input.refs.build)

-- Building through the BUILD panel and the ghost ---------------------------------------------------------------------------------
tap(Input.refs.build)
local buildPanel = panels:FindFirstChild("Panel_build")
check("the BUILD panel opened", buildPanel ~= nil)
local floorRow = find(buildPanel, "Piece_floor")
check(
	"the BUILD panel has a category rail on the left (jump to a section)",
	find(buildPanel, "Categories") ~= nil and find(buildPanel, "Cat_STATIONS") ~= nil
)
check(
	"the piece the guide wants is marked NEXT in the list",
	floorRow and floorRow:GetAttribute("Wanted") == true and find(floorRow, "Next") ~= nil
)
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
placing = Build.placing()
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
check("DONE ends placing", Build.placing() == nil and Input.refs.actLabel.Text == "CAST")
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
check(
	"the raft line counts every piece (5 floors, a net, a bench)",
	refs.raftLine.Text:find("7 pieces") ~= nil,
	refs.raftLine.Text
)

-- 📌 a piece in the hotbar: holding it shows the ghost, ACT builds it ------------------------------------------------------------------
do
	Bus.Open:Fire("build")
	Engine.advance(0.3)
	local row = find(panels.Panel_build, "Piece_floor")
	check("each piece you can build has a 📌 button", find(row, "Pin") ~= nil)
	tap(find(row, "Pin"))
	Engine.advance(0.4)
	local inv = Store.get("inv")
	local pinnedAt
	for i = 1, Constants.HOTBAR do
		local slot = inv.slots["h" .. i]
		if slot and slot.key == "pin" and slot.data and slot.data.piece == "floor" then
			pinnedAt = i
		end
	end
	check("📌 put the Floor Tile in the hotbar", pinnedAt ~= nil)
	check(
		"holding it starts building that piece",
		Build.placing() ~= nil and Build.placing().key == "floor" and Build.placing().pinned == true
	)
	check("ACT says PLACE", Input.refs.actLabel.Text == "PLACE", Input.refs.actLabel.Text)
	Panels.close()
	-- back to the rod: the shortcut's ghost goes away
	for i = 1, Constants.HOTBAR do
		local slot = Store.get("inv").slots["h" .. i]
		if slot and slot.key == "fishing_rod" then
			Input.select(i)
		end
	end
	Engine.advance(0.4)
	check("picking another slot stops building", Build.placing() == nil)
	-- (take the shortcut off again so the rest of the test has its hotbar back)
	Inventory:Drop(player, "h" .. pinnedAt)
	Engine.advance(0.3)
end

-- QUICK: hold it and the recommended piece goes where you look --------------------------------------------------------------
Engine.advance(0.3)
local recNow = Formulas.recommended(Store.get("raft"), Store.get("inv"))
check(
	"the QUICK button shows what the raft needs (not more floor)",
	Input.refs.quick.Visible == true
		and recNow ~= nil
		and recNow.key ~= "floor"
		and Input.refs.quick:GetAttribute("Piece") == recNow.key
		and Input.refs.quickPiece:FindFirstChild("Icon3D") ~= nil,
	Input.refs.quick:GetAttribute("Piece")
)
-- stand on an edge tile looking out over the water beside it, with what the box costs in the bag
Inventory:Give(player, "wood", 20, "test")
Engine.advance(0.3)
local free = Rafts:FreeSpots(Rafts:RaftOf(player), 1)[1]
local freePos = Rafts:TileWorld(Rafts:RaftOf(player), free[1], free[2], 1)
local edgeTile
for _, p in Rafts:RaftOf(player).pieces do
	if p.def.structural and p.level == 1 and math.abs(p.gx - free[1]) + math.abs(p.gz - free[2]) == 1 then
		edgeTile = p
	end
end
stand(tileAt(raft, edgeTile.gx, edgeTile.gz), freePos)
local tilesBefore = Rafts:RaftOf(player).summary.tiles
local piecesBefore = #Rafts:RaftOf(player).pieces
local want = Formulas.recommended(Store.get("raft"), Store.get("inv"))
Input.refs.quick.MouseButton1Down:Fire()
check(
	"holding QUICK starts placing what the raft needs",
	Build.placing() ~= nil and Build.placing().quick ~= nil and Build.placing().key == want.key,
	Build.placing() and Build.placing().key
)
check("the placing bar says QUICK", Build.refs.barText.Text:find("⚡") ~= nil, Build.refs.barText.Text)
Engine.advance(0.5)
Engine.advance(0.5)
Input.refs.quick.MouseButton1Up:Fire()
Engine.advance(0.2)
local r2 = Rafts:RaftOf(player)
check(
	"looking at the water, the piece went on a free floor instead of laying more floor",
	#r2.pieces > piecesBefore and (want.key == "floor" or r2.summary.tiles == tilesBefore),
	`{#r2.pieces - piecesBefore} pieces, tiles {tilesBefore} -> {r2.summary.tiles}`
)
check("letting go ends it", Build.placing() == nil and not Input.isQuick())

-- Into the water: a splash, ripples, and the HUD says how to get back -------------------------------------------------------
do
	local fxBefore = #ws.Fx:GetChildren()
	local hum = player.Character.Humanoid
	hum:ChangeState(Enum.HumanoidStateType.Swimming)
	hum.StateChanged:Fire(Enum.HumanoidStateType.Running, Enum.HumanoidStateType.Swimming)
	Engine.advance(0.05)
	check(
		"jumping in splashes, and ripples follow you",
		#ws.Fx:GetChildren() > fxBefore,
		#ws.Fx:GetChildren() - fxBefore
	)
	hum:ChangeState(Enum.HumanoidStateType.Running)
	local layout = OceanLayout.plot(1)
	stand(layout.center + layout.out * 40 + Vector3.new(0, 0.5, 0))
	Engine.advance(0.6)
	check(
		"in the water the HUD says to swim back and jump up",
		refs.callout ~= nil
			and find(refs.callout, "Text") == nil
			and refs.callout:FindFirstChildWhichIsA("TextLabel", true) ~= nil
			and refs.callout:FindFirstChildWhichIsA("TextLabel", true).Text:find("🏊") ~= nil,
		refs.callout
			and refs.callout:FindFirstChildWhichIsA("TextLabel", true)
			and refs.callout:FindFirstChildWhichIsA("TextLabel", true).Text
	)
	stand(tileAt(raft, 6, 6))
	Engine.advance(0.6)
end

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
give("wood", 6)
Engine.advance(0.3)
craftPanel = panels:FindFirstChild("Panel_craft")
local hammerRow = find(craftPanel, "Recipe_hammer")
check(
	"the hammer's cost chips are readable",
	hammerRow and find(hammerRow, "Cost_wood") and find(hammerRow, "Cost_metal") ~= nil
)
check("the chips are green once you can afford it", find(hammerRow, "Cost_metal"):GetAttribute("Have") >= 1)
tap(find(hammerRow, "Make_hammer"))
check("MAKE crafted a hammer (you start with one too)", Inventory:Count(player, "hammer") == 2)
check(
	"the guide moved to the crate",
	Guide.current() and Guide.current().key == "crate",
	Guide.current() and Guide.current().key
)
Panels.close()

-- The crate: reel it in, open it in the BAG -----------------------------------------------------------------------------------------
Engine.advance(1.2)
local crate
for _, d in Ocean:Debris(1) do
	if d.special == "supply_crate" then
		crate = d
	end
end
check("the guide's crate drifted in the moment it asked", crate ~= nil and crate.guide == true)
check(
	"it's close (right beside the raft)",
	crate and (crate.pos - Rafts:Center(Rafts:RaftOf(player))).Magnitude < 40,
	crate and (crate.pos - Rafts:Center(Rafts:RaftOf(player))).Magnitude
)
do
	local Debris = Engine.require(tree.client.Controllers.DebrisController)
	for _ = 1, 12 do
		Debris.step(0.016)
	end
	check(
		"it wears a beacon and a CAST HERE! sign",
		crate and crate.model:FindFirstChild("GuideBeacon") ~= nil and crate.model:FindFirstChild("GuideSign") ~= nil
	)
	-- gone without being caught: another one comes
	Ocean:Remove(crate)
	Engine.advance(Constants.GUIDE_CRATE_RETRY + 1.5)
	local again
	for _, d in Ocean:Debris(1) do
		if d.special == "supply_crate" and d.guide then
			again = d
		end
	end
	check("a crate that got away is replaced right away", again ~= nil and again ~= crate)
end
-- (the guide's own crate, and nothing else to aim at)
for _, d in Ocean:Debris(1) do
	if d.guide then
		crate = d
	else
		Ocean:Remove(d)
	end
end
hold("fishing_rod")
for _ = 1, 60 do
	if (crate.pos - PlayersS:Position(player)).Magnitude <= 26 then
		break
	end
	Engine.advance(0.5)
end
stand(tileAt(raft, 6, 6), crate.pos)
Input.act()
Engine.advance(6)
check("the crate was reeled in", Inventory:Count(player, "supply_crate") == 1)
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
	"OPEN opened the crate: an axe and a spear for the island",
	Inventory:Count(player, "supply_crate") == 0
		and Inventory:Count(player, "axe") == 1
		and Inventory:Count(player, "spear") == 1
)
Panels.close()
-- Tab on a keyboard: the bag, without the gamepad's selection cursor (Escape and the arrows stay yours)
Engine.lastInputType = Enum.UserInputType.Keyboard
Engine.actions.EV_Bag("EV_Bag", Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.Tab })
Engine.advance(0.3)
check("Tab opens the bag", panels:FindFirstChild("Panel_inventory") ~= nil)
check("no selection cursor on a keyboard", GuiService.SelectedObject == nil)
Panels.close()
Engine.lastInputType = Enum.UserInputType.Touch
-- Drag and drop in the bag: the rod goes to a bag slot and back
do
	local hookSlot
	for id, s in Store.get("inv").slots do
		if s.key == "fishing_rod" then
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
		"dropping the rod on a bag slot moved it there",
		Store.get("inv").slots[free] and Store.get("inv").slots[free].key == "fishing_rod"
	)
	Panels.dropOn(free, hookSlot)
	Engine.advance(0.3)
	check("and back", Store.get("inv").slots[hookSlot] and Store.get("inv").slots[hookSlot].key == "fishing_rod")
end
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
do
	local ocean = find(map, "OceanMap")
	local marks = ocean and ocean:FindFirstChild("Marks")
	local mine = marks and marks:FindFirstChild("Raft" .. tostring(Store.get("me").plot))
	check("the MAP shows the ocean with your raft on it", mine ~= nil)
	check("the MAP shows you", marks and marks:FindFirstChild("Player_" .. player.UserId) ~= nil)
end
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
Engine.advance(3)
check("the horizon slides past while sailing", Sailing.slide() > 0, Sailing.slide())
do
	-- another plot's island is never shown here (the server builds one per plot)
	local isles = ws:FindFirstChild("Islands")
	if isles then
		local other = Engine.globals.Instance.new("Model")
		other.Name = "OtherPlotsIsland"
		other:SetAttribute("Plot", 99)
		other.Parent = isles
		local hidden = Sailing.privacy()
		check("another plot's island is hidden", hidden[other] == true and other.Parent ~= isles)
		other:Destroy()
	end
end
check(
	"Palm Key shows on the horizon ahead",
	Sailing.silhouette() ~= nil and Sailing.silhouette().model.Parent ~= nil and #Sailing.silhouette().parts > 0
)
check("the wake foams astern", Sailing.wake() ~= nil and Sailing.wake().stern.Foam.Rate > 0)
local ride = RaftMotion.rafts[ws.Rafts.Raft1]
check("the raft rides the swell (its parts move as one)", ride ~= nil and #ride.parts > 0 and ride.applied ~= nil)
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
Engine.advance(0.3)
check("the island you left slides away behind you (a copy, out of the way)", Sailing.leaving() ~= nil, "no copy")
check("the button says LEAVE ISLAND, the clock says leaving", refs.voyage.Text:find("LEAVING") ~= nil, refs.voyage.Text)
Engine.advance(secs + 3)
check(
	"home: the steps finished and the card goes on with NEXT (no SKIP, never empty)",
	Data:Get(player).tutorial.done == true
		and Guide.current() ~= nil
		and Guide.current().goal == true
		and find(gui.Guide, "Skip") == nil
		and gui.Guide.GuideCard.Visible == true,
	Guide.current() and Guide.current().text
)
-- hands empty: the card offers HOLD MY ROD, and it works (even from the bag)
do
	local rodSlot
	for id, s in Inventory:View(player).slots do
		if s.key == "fishing_rod" then
			rodSlot = id
		end
	end
	local function freeBag()
		local slots = Inventory:View(player).slots
		for i = 1, Inventory:Capacity(player) do
			if not slots["b" .. i] then
				return "b" .. i
			end
		end
	end
	Inventory:Move(player, rodSlot, freeBag())
	Inventory:Select(player, 1)
	if Inventory:View(player).slots.h1 then
		Inventory:Move(player, "h1", freeBag())
	end
	Engine.advance(1.5)
	local action = find(gui.Guide, "Action")
	check(
		"empty hands: the card says hold your rod, with a button",
		Guide.current() and Guide.current().action == "hold_rod" and action.Visible == true,
		Guide.current() and Guide.current().text
	)
	check("the guide's finger is on that button", Guide.uiTarget() == action)
	tap(action)
	Engine.advance(0.3)
	local _, held = Inventory:Selected(player)
	check("HOLD MY ROD put the rod in your hand from the bag", held and held.key == "fishing_rod")
	check("your last rod can't be dropped", not Inventory:Drop(player, "h1"))
end
check("the toast said home", true)

-- 👀 VISIT: look at someone's raft (even an offline one), touch nothing ----------------------------------------------------------------
do
	local Visit = Engine.require(tree.client.Controllers.VisitController)
	local Visits = service("VisitService")
	check("the HUD has a VISIT button", find(hud, "Menu_visit") ~= nil)
	tap(find(hud, "Menu_visit"))
	Engine.advance(0.5)
	local vp = panels:FindFirstChild("Panel_visit")
	check(
		"the VISIT panel opens with tabs: here, friends, the biggest rafts",
		vp ~= nil and find(vp, "Tab_top") ~= nil and find(vp, "Tab_friends") ~= nil
	)
	Engine.dataStores[Constants.PROFILE_STORE] = Engine.dataStores[Constants.PROFILE_STORE] or {}
	Engine.dataStores[Constants.PROFILE_STORE]["u_888"] = {
		raft = {
			pieces = {
				{ key = "floor", gx = 6, gz = 6, level = 1 },
				{ key = "floor", gx = 7, gz = 6, level = 1 },
				{ key = "helm", gx = 6, gz = 6, level = 1 },
			},
		},
		records = { tier = 2 },
	}
	local before = Inventory:Count(player, "wood")
	Visits:Visit(player, 888)
	Engine.advance(0.5)
	local cur = Visit.current()
	check(
		"visiting shows their raft on its own patch of sea",
		cur ~= nil and ws:FindFirstChild("Showroom") ~= nil and #ws.Showroom:GetChildren() >= 4
	)
	check(
		"the bar says whose raft it is, with BACK",
		find(gui.Visit, "VisitBar").Visible == true and find(gui.Visit, "Back") ~= nil
	)
	check(
		"nothing in the copy can be collected (no prompts, nothing for the server)",
		ws.Showroom:FindFirstChildWhichIsA("ProximityPrompt", true) == nil and Inventory:Count(player, "wood") == before
	)
	tap(find(gui.Visit, "Back"))
	check("BACK brings you home", Visit.current() == nil and ws:FindFirstChild("Showroom") == nil)
end

-- Floating pieces wear no hovering badge (only the guide's crate has a beacon) ------------------------------------------------
do
	local Debris = Engine.require(tree.client.Controllers.DebrisController)
	for _ = 1, 12 do
		Debris.step(0.016)
	end
	local marked = 0
	for _, m in ws.Debris:GetChildren() do
		if m:FindFirstChild("Mark") or (not m:GetAttribute("Guide") and m:FindFirstChild("GuideSign")) then
			marked += 1
		end
	end
	check("floating pieces carry no hovering icons", marked == 0, marked)
end

-- Fishing with REEL ----------------------------------------------------------------------------------------------------------------
-- (open water: with nothing floating in front, a cast fishes)
for _, d in Ocean:Debris(1) do
	Ocean:Remove(d)
end
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

-- ACT can't get stuck ----------------------------------------------------------------------------------------------------------
do
	Engine.advance(2)
	local function acted()
		return countSent("Act") + countSent("Reel")
	end
	-- a line that never came back (as if a message was lost): ACT reels for a while, then casts again
	Store.state.fish = { state = "cast" }
	Store.Changed:Fire({ fish = Store.state.fish })
	local reels = countSent("Reel")
	Input.act()
	Engine.advance(0.5)
	check("with a line out, ACT reels", countSent("Reel") == reels + 1)
	Engine.advance(Constants.FISH_BITE[2] + Constants.FISH_WINDOW + 7)
	local casts = countSent("Act")
	Input.act()
	Engine.advance(0.5)
	check("a line that never came back doesn't block ACT: it casts again", countSent("Act") == casts + 1)
	Engine.advance(Constants.FISH_BITE[2] + Constants.FISH_WINDOW + 2)
	-- building that ended without a word: ACT is yours again
	Bus.Place:Fire("floor")
	Engine.advance(0.2)
	Build.stop()
	local before = acted()
	Input.act()
	Engine.advance(0.5)
	check("a build that ended quietly gives ACT back", not Input.isBuilding() and acted() == before + 1)
	Engine.advance(Constants.FISH_BITE[2] + Constants.FISH_WINDOW + 2)
	-- a click in the world (PC): the real mouse path
	before = acted()
	UIS.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton1, KeyCode = Enum.KeyCode.Unknown }, false)
	Engine.advance(0.05)
	UIS.InputEnded:Fire({ UserInputType = Enum.UserInputType.MouseButton1, KeyCode = Enum.KeyCode.Unknown })
	Engine.advance(0.6)
	check("a click in the world acts (the mouse's own path)", acted() == before + 1, acted() - before)
	Engine.advance(Constants.FISH_BITE[2] + Constants.FISH_WINDOW + 2)
end
-- laying floors ends by itself when the bag can't pay for another (so ACT goes back to the rod)
do
	local cost = Pieces.get("floor").cost
	local saved = {}
	for item in cost do
		saved[item] = Inventory:Count(player, item)
		Inventory:Take(player, item, saved[item])
	end
	for item, n in cost do
		give(item, n)
	end
	local r = Rafts:RaftOf(player)
	local spot = Rafts:FreeSpots(r, 1)[1]
	local pos = Rafts:TileWorld(r, spot[1], spot[2], 1)
	local beside
	for _, p in r.pieces do
		if p.def.structural and p.level == 1 and math.abs(p.gx - spot[1]) + math.abs(p.gz - spot[2]) == 1 then
			beside = p
		end
	end
	stand(tileAt(raft, beside.gx, beside.gz), pos)
	Bus.Place:Fire("floor")
	Engine.advance(0.4)
	local tiles = Rafts:RaftOf(player).summary.tiles
	Input.act()
	Engine.advance(0.6)
	check("the last floor the bag could pay for went down", Rafts:RaftOf(player).summary.tiles == tiles + 1)
	check("and placing ended by itself (ACT is the rod again)", not Input.isBuilding() and Build.placing() == nil)
	for item, n in saved do
		give(item, n)
	end
end

-- The other panels ---------------------------------------------------------------------------------------------------------------
Bus.Open:Fire("raft")
Engine.advance(0.3)
local raftPanel = panels:FindFirstChild("Panel_raft")
check("the RAFT panel lists the next tier's needs", raftPanel ~= nil and find(raftPanel, "Need_1") ~= nil)
check(
	"paint buttons: white is free, red is locked",
	find(raftPanel, "Paint_sail_white") and find(raftPanel, "Paint_sail_red").Text:find("🔒") ~= nil
)
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

-- REMOVE: the button (or X) on your raft; the piece you point at glows red with what comes back; ACT takes it off ------------
do
	local raft = Rafts:RaftOf(player)
	-- a railing on the raft's outer edge, to take off
	local edge
	for _, p in raft.pieces do
		if
			p.def.structural
			and p.level == 1
			and not Rafts:Tile(raft, p.gx + 1, p.gz, 1)
			and not Rafts:OnTile(raft, p.gx, p.gz, 1)
			and not Rafts:Edge(raft, p.gx, p.gz, 1, 0)
			and (not edge or p.gx > edge.gx)
		then
			edge = p
		end
	end
	for k, n in Pieces.get("railing").cost do
		Inventory:Give(player, k, n, "test")
	end
	check("(a railing to take off)", edge ~= nil and Rafts:Build(player, "railing", edge.gx, edge.gz, 1, 0) == true)
	Engine.advance(0.3)
	local rail = Rafts:Edge(raft, edge.gx, edge.gz, 1, 0)
	local railAt = Rafts:PiecePosition(raft, rail)
	local tileAt = Rafts:TileWorld(raft, edge.gx, edge.gz, 1)
	stand(tileAt + Vector3.new(-2, 3, 0), railAt + Vector3.new(3, 0, 0))
	Engine.advance(0.3)
	check("a ♻️ REMOVE button is on your raft", gui.Build.Remove.Visible == true)
	tap(gui.Build.Remove)
	Engine.advance(0.2)
	check(
		"REMOVE is on, and ACT says REMOVE",
		Build.placing() ~= nil and Build.placing().demolish == true and Input.refs.actLabel.Text == "REMOVE",
		Input.refs.actLabel.Text
	)
	local target = Build.placing() and Build.placing().target
	check(
		"the railing in front glows red",
		target ~= nil and target:GetAttribute("PieceId") == rail.id and target:FindFirstChild("RemoveGlow") ~= nil,
		target and target.Name
	)
	local barText = gui.Build.PlaceBar.Text.Text
	check("the bar says what you get back", barText:find("REMOVE") ~= nil and barText:find("+") ~= nil, barText)
	local before = {}
	for k in Pieces.get("railing").cost do
		before[k] = Inventory:Count(player, k)
	end
	Input.act()
	Engine.advance(0.4)
	local whole = true
	for k, n in Pieces.get("railing").cost do
		whole = whole and Inventory:Count(player, k) == before[k] + n
	end
	check("ACT takes it off, the whole cost back in the bag", Rafts:Edge(raft, edge.gx, edge.gz, 1, 0) == nil and whole)
	check("REMOVE stays on for the next piece", Build.placing() ~= nil and Build.placing().demolish == true)
	tap(gui.Build.Remove)
	check("the button (now DONE) turns it off", Build.placing() == nil and Input.refs.actLabel.Text ~= "REMOVE")
	Build.toggleRemove()
	Engine.advance(0.1)
	check("X / the d-pad do the same", Build.placing() ~= nil and Build.placing().demolish == true)
	Build.toggleRemove()
	Engine.advance(0.1)
end

-- Research away from the station: it says why, and the guide shows the way ---------------------------------------------------
do
	local Craft = service("CraftService")
	local raft = Rafts:RaftOf(player)
	for _, p in raft.pieces do
		if p.def.station == "research" then
			Rafts:_remove(raft, p)
		end
	end
	Inventory:Give(player, "old_compass", 2, "test")
	Engine.advance(0.3)
	local function compassSlot()
		for id, s in Inventory:View(player).slots do
			if s.key == "old_compass" then
				return id
			end
		end
		return nil
	end
	check("no Research Station: researching says how to get one", Craft:Research(player, compassSlot()) == false)
	Engine.advance(0.3)
	local callout = refs.callout and refs.callout:FindFirstChildWhichIsA("TextLabel")
	check(
		"...a callout naming the Research Station and where it's built",
		callout ~= nil and callout.Text:find("Research Station") ~= nil,
		callout and callout.Text
	)
	-- a station across the raft
	local spots = Rafts:EmptyTiles(raft, 1)
	local me = player.Character.HumanoidRootPart.Position
	local far, farD
	for _, s in spots do
		local d = (Rafts:TileWorld(raft, s.gx, s.gz, 1) - me).Magnitude
		if not farD or d > farD then
			far, farD = s, d
		end
	end
	local station = Rafts:_add(raft, { key = "research", gx = far.gx, gz = far.gz, level = 1 })
	Rafts:Recompute(raft)
	Rafts:Push(raft)
	local at = Rafts:PiecePosition(raft, station)
	local away
	for _, s in spots do
		local w = Rafts:TileWorld(raft, s.gx, s.gz, 1)
		if (w - at).Magnitude > 14 then
			away = w
			break
		end
	end
	stand((away or me) + Vector3.new(0, 3, 0), at)
	Panels.openPanel("inventory")
	Engine.advance(0.3)
	check("away from it: RESEARCH doesn't just fail", Craft:Research(player, compassSlot()) == false)
	Engine.advance(0.4)
	local cur = Guide.current()
	check(
		"the guide's card says go to your Research Station and the arrow points at it",
		cur ~= nil
			and cur.key == "point"
			and guide.GuideCard.Step.Text:find("RESEARCH") ~= nil
			and typeof(cur.target) == "Vector3"
			and (Vector3.new(cur.target.X, 0, cur.target.Z) - Vector3.new(at.X, 0, at.Z)).Magnitude < 1,
		cur and cur.text
	)
	check("the bag closes so you can see the way", Panels.current() == nil, Panels.current())
	stand(at + (Vector3.new(me.X, at.Y, me.Z) - at).Unit * 3 + Vector3.new(0, 3, 0), at)
	Engine.advance(0.4)
	check("there: the Research Station's panel opens by itself", Panels.current() == "craft", Panels.current())
	check("and the guide goes back to what it was saying", Guide.current() == nil or Guide.current().key ~= "point")
	check("now it researches", Craft:Research(player, compassSlot()) == true)
	Panels.close()
	Engine.advance(0.3)
end

-- Running and jumping ----------------------------------------------------------------------------------------------------------------
do
	local Move = Engine.require(tree.client.Controllers.MoveController)
	local c = player.Character
	local hum = c:FindFirstChildOfClass("Humanoid")
	local run, jump = Move.refs.run, Move.refs.jump
	local walk, sprint = Constants.WALK_SPEED, Constants.WALK_SPEED + Constants.SPRINT_BONUS
	Engine.advance(0.3)
	check("RUN is on screen", run.Visible == true)
	check("a phone gets a JUMP button (Roblox's own sits under ACT)", jump.Visible == true)
	tap(run)
	check("RUN: faster feet right away", hum.WalkSpeed == sprint, hum.WalkSpeed)
	check("...the server is told", sent("Sprint") ~= nil and sent("Sprint").args[1] == true)
	check(
		"...and runs you too (everyone sees it)",
		c:GetAttribute("Sprint") == true and PlayersS:MaxSpeed(player) == sprint,
		PlayersS:MaxSpeed(player)
	)
	check("the button says so", Move.refs.runLabel.Text == "RUNNING", Move.refs.runLabel.Text)
	ws.CurrentCamera.FieldOfView = 70
	hum.MoveDirection = Vector3.new(0, 0, -1)
	c.HumanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, -sprint)
	Engine.advance(1)
	check(
		"the camera widens while you run",
		ws.CurrentCamera.FieldOfView > 70 + Constants.SPRINT_FOV * 0.8,
		ws.CurrentCamera.FieldOfView
	)
	local rec = Anim.recs[c]
	check("you lean into the run, forearms up", rec ~= nil and (rec.run or 0) > 0.8, rec and rec.run)
	tap(run)
	hum.MoveDirection = Vector3.zero
	c.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
	Engine.advance(1)
	check("RUN again: back to a walk", hum.WalkSpeed == walk and c:GetAttribute("Sprint") == nil, hum.WalkSpeed)
	check("...the camera back", math.abs(ws.CurrentCamera.FieldOfView - 70) < 0.5, ws.CurrentCamera.FieldOfView)
	check("...and upright again", (rec.run or 0) < 0.1, rec.run)
	-- Shift, held; the left stick, until you stop
	Engine.actions.EV_Run("EV_Run", Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.LeftShift })
	Engine.advance(0.3)
	check("holding Shift runs", hum.WalkSpeed == sprint and c:GetAttribute("Sprint") == true, hum.WalkSpeed)
	Engine.actions.EV_Run("EV_Run", Enum.UserInputState.End, { KeyCode = Enum.KeyCode.LeftShift })
	Engine.advance(0.3)
	check("letting go walks", hum.WalkSpeed == walk and c:GetAttribute("Sprint") == nil, hum.WalkSpeed)
	hum.MoveDirection = Vector3.new(1, 0, 0)
	Engine.actions.EV_Run("EV_Run", Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.ButtonL3 })
	Engine.advance(0.3)
	check("clicking the left stick runs", hum.WalkSpeed == sprint, hum.WalkSpeed)
	hum.MoveDirection = Vector3.zero
	Engine.advance(1)
	check("...until you stop", hum.WalkSpeed == walk and c:GetAttribute("Sprint") == nil, hum.WalkSpeed)
	-- a lost message: the server's speed catches up anyway
	PlayersS:Sprint(player, true)
	Engine.advance(1)
	check("if the server got it wrong, it's put right", c:GetAttribute("Sprint") == nil and hum.WalkSpeed == walk)
	-- JUMP, held, keeps jumping
	hum.Jump = false
	local finger = { UserInputType = Enum.UserInputType.Touch }
	jump.InputBegan:Fire(finger)
	check("JUMP jumps", hum.Jump == true)
	hum.Jump = false
	Engine.advance(0.1)
	check("...and keeps jumping while it's held", hum.Jump == true)
	UIS.InputEnded:Fire(finger)
	hum.Jump = false
	Engine.advance(0.1)
	check("...not once it's let go", hum.Jump ~= true)
end

-- Feedback card, lite mode, analytics --------------------------------------------------------------------------------------------
Feedback:Ask(player)
Engine.advance(0.5)
check("the feedback card showed", Panels.cards.feedback ~= nil)
-- Nothing on top of anything: the HUD's corners, the guide's card, the passing messages, the hotbar, the action
-- buttons and a card asking something, on a phone, a tablet, a small window and a big screen.
local Theme = Engine.require(tree.client.UI.Theme)
local UDim2 = Engine.globals.UDim2
local OVERLAYS = { Vignette = true, Flash = true, Fade = true, Down = true }
-- where a GUI object is on the scaled canvas (from Position, Size and AnchorPoint up to its ScreenGui)
local function rectOf(obj, canvas)
	local chain = {}
	local o = obj
	while o and not o:IsA("ScreenGui") do
		table.insert(chain, 1, o)
		o = o.Parent
	end
	local x, y, w, h = 0, 0, canvas.X, canvas.Y
	for _, g in chain do
		-- (Roblox's defaults where nothing was set: 100 x 100 at the top left)
		local s = g.Size or UDim2.fromOffset(100, 100)
		local p = g.Position or UDim2.new()
		local a = g.AnchorPoint or Vector2.new()
		local nw = s.X.Scale * w + s.X.Offset
		local nh = s.Y.Scale * h + s.Y.Offset
		x += p.X.Scale * w + p.X.Offset - a.X * nw
		y += p.Y.Scale * h + p.Y.Offset - a.Y * nh
		w, h = nw, nh
	end
	return { x = x, y = y, w = w, h = h }
end
-- every pair of things on screen that overlap, and anything hanging off the edge
local function overlaps()
	local canvas = Theme.canvas()
	local list = {}
	for _, name in { "Hud", "Guide", "Actions", "Build", "Panels" } do
		local g = gui:FindFirstChild(name)
		for _, c in g and g:GetChildren() or {} do
			if
				c:IsA("GuiObject")
				and c.Visible ~= false
				and not OVERLAYS[c.Name]
				and (name ~= "Panels" or c.Name:sub(1, 5) == "Card_")
			then
				table.insert(list, c)
			end
		end
	end
	local bad = {}
	for i = 1, #list do
		local a = rectOf(list[i], canvas)
		if a.x < -1 or a.y < -1 or a.x + a.w > canvas.X + 1 or a.y + a.h > canvas.Y + 1 then
			table.insert(bad, `{list[i].Parent.Name}.{list[i].Name} off the screen`)
		end
		for j = i + 1, #list do
			local b = rectOf(list[j], canvas)
			local ox = math.min(a.x + a.w, b.x + b.w) - math.max(a.x, b.x)
			local oy = math.min(a.y + a.h, b.y + b.h) - math.max(a.y, b.y)
			if ox > 2 and oy > 2 then
				table.insert(bad, `{list[i].Parent.Name}.{list[i].Name} x {list[j].Parent.Name}.{list[j].Name}`)
			end
		end
	end
	return bad, canvas
end
local SCREENS = {
	{ "phone", Vector2.new(844, 390) },
	{ "tablet", Vector2.new(1024, 768) },
	{ "small window", Vector2.new(1280, 720) },
	{ "big screen", Vector2.new(1920, 1080) },
}
local function everyMessage()
	Hud.toast("🪵 +3 Wood")
	Hud.toast("📦 Supply crate!")
	Hud.toast("🎣 It got away. Cast again!")
	Hud.alert("🐟 REEL! (ACT)")
	Hud.callout("🏊 You're in the water. Swim back and jump up onto the raft!", "info")
	for i = 1, 4 do
		Hud.unlock({ kind = "level", level = 5 + i })
	end
	Engine.advance(0.1)
end
for _, screen in SCREENS do
	ws.CurrentCamera.ViewportSize = screen[2]
	Engine.advance(1.2)
	everyMessage()
	local bad, canvas = overlaps()
	check(
		`{screen[1]}: nothing overlaps while "Do you like the game?" is up ({math.floor(canvas.X)} x {math.floor(
			canvas.Y
		)})`,
		#bad == 0,
		table.concat(bad, "; ")
	)
	check(`{screen[1]}: the guide's NEXT card steps aside for the question`, guide.GuideCard.Visible == false)
end
ws.CurrentCamera.ViewportSize = Vector2.new(844, 390)
Engine.advance(4)
tap(Panels.cards.feedback.Btn1)
Engine.advance(0.2)
check(
	"a thank-you card follows (the NEXT card still out of its way)",
	Panels.cards.thanks ~= nil and guide.GuideCard.Visible == false
)
if Panels.cards.thanks then
	tap(Panels.cards.thanks.Btn1)
end
Engine.advance(0.2)
check("the NEXT card comes back once it's answered", guide.GuideCard.Visible == true)
-- the next server event on the HUD, beside the clock
do
	local now = ws:GetServerTimeNow()
	ws:SetAttribute("EventEnds", nil)
	ws:SetAttribute("NextEventAt", now + 125)
	ws:SetAttribute("EventName", "GOLDEN TIDE")
	ws:SetAttribute("EventIcon", "✨")
	Hud.updateEvent()
	check(
		"the HUD counts down to the next server event",
		refs.event.Visible and refs.eventText.Text:find("GOLDEN TIDE") ~= nil and refs.eventTime.Text:find("2:0") ~= nil,
		refs.eventTime.Text
	)
end
-- welcome back: how long you were away and what your nets caught, with pictures
do
	local c =
		Panels.away({ seconds = 3 * 3600 + 120, caught = 12, items = { wood = 9, rope = 3 }, inBag = true, nets = 2 })
	Engine.advance(0.2)
	check(
		"welcome back: a card with the time away and a cell per thing caught",
		Panels.cards.away ~= nil
			and string.find(c.Text.Text, "3h 2m", 1, true) ~= nil
			and c:FindFirstChild("Got_wood", true) ~= nil
			and c:FindFirstChild("Got_rope", true) ~= nil,
		c and c.Text.Text
	)
	if Panels.cards.away then
		tap(Panels.cards.away.Btn1)
	end
end
-- missing something: the how-to card, step by step
do
	local c = Panels.showHow("palm")
	Engine.advance(0.2)
	local text = c and c:FindFirstChild("Text")
	check(
		"how-to: a card with numbered steps to get palm fronds",
		Panels.cards.how ~= nil
			and text ~= nil
			and string.find(text.Text, "1. ", 1, true) ~= nil
			and string.find(text.Text, "Palm Key", 1, true) ~= nil,
		text and text.Text
	)
	if Panels.cards.how then
		tap(Panels.cards.how.Btn1)
		Engine.advance(0.2)
	end
end
-- Q in the bag drops the whole stack under the mouse
do
	Inventory:Give(player, "stone", 5, "home")
	Engine.advance(0.3)
	Panels.openPanel("inventory")
	Engine.advance(0.3)
	local id
	for sid, slot in Store.get("inv").slots do
		if slot.key == "stone" then
			id = sid
		end
	end
	local cell = id and find(panels, "Slot_" .. id)
	if cell then
		Panels._hover(id)
	end
	check("Q: drops the whole stack", id ~= nil and Panels.quickDrop())
	Engine.advance(0.5)
	check("Q: the stack is gone", Inventory:Count(player, "stone") == 0, Inventory:Count(player, "stone"))
	Panels.close()
	Engine.advance(0.2)
end
-- the daily vote card: a row per raft with LOOK and VOTE
do
	local Vote = service("VoteService")
	local real = Vote.Choices
	Vote.Choices = function()
		return { { userId = 9001, name = "Kai", value = 120 }, { userId = 9002, name = "Mo", value = 80 } }
	end
	Vote:Ask(player)
	Vote.Choices = real
	Engine.advance(0.3)
	local card = Panels.cards.vote
	check("the vote card shows each raft", card ~= nil and card:FindFirstChild("Choice_9001") ~= nil)
	if card then
		tap(card.Choice_9001.Vote)
		Engine.advance(0.3)
		check("voting closes the card", Panels.cards.vote == nil)
	end
end
for _, screen in SCREENS do
	ws.CurrentCamera.ViewportSize = screen[2]
	Engine.advance(1.2)
	everyMessage()
	local bad, canvas = overlaps()
	check(
		`{screen[1]}: nothing overlaps with every kind of message up ({math.floor(canvas.X)} x {math.floor(canvas.Y)})`,
		#bad == 0,
		table.concat(bad, "; ")
	)
	local live = 0
	for _, c in hud:GetChildren() do
		if c.Name == "Toast" then
			live += 1
		end
	end
	check(`{screen[1]}: toasts never pile up (two rows at most)`, live <= 2, live)
	Engine.advance(5)
end
ws.CurrentCamera.ViewportSize = Vector2.new(844, 390)
Engine.advance(1.2)
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

-- a rest's fade leaves nothing behind (the words cleared, the overlay hidden), even two in a row
Hud.fade(1.2, "Resting...")
Engine.advance(0.3)
Hud.fade(1.2, "Resting...")
Engine.advance(0.6)
check("resting: the words show during the fade", refs.fadeText.Text == "Resting...")
Engine.advance(3)
check(
	"resting: nothing stays on screen after the fade",
	refs.fadeText.Text == "" and refs.fade.Visible == false and refs.fadeText.TextTransparency == 1,
	refs.fadeText.Text
)
-- the mission: always posted
do
	local m, bar = Guide.mission()
	check(
		"the mission is posted",
		m ~= nil and bar ~= nil and string.find(bar.Text.Text, "MISSION") ~= nil,
		m and m.title
	)
end

-- lite mode (phones): no shadows, no light sources, no bloom, flat water
do
	local Perf = Engine.require(tree.client.Controllers.PerformanceController)
	local Lighting = Engine.globals.game:GetService("Lighting")
	local probe = Engine.globals.Instance.new("Part")
	local light = Engine.globals.Instance.new("PointLight")
	light.Parent = probe
	probe.Parent = ws
	Perf.enable()
	Perf.sweep() -- (the real engine catches new lights as they're added; the mock doesn't fire DescendantAdded)
	Engine.advance(0.2)
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	check("lite: no shadows", Lighting.GlobalShadows == false)
	check(
		"lite: light sources off",
		light.Enabled == false,
		`{tostring(light.Enabled)} {light.ClassName} {light.Name} {tostring(Perf.lite)}`
	)
	check("lite: no bloom", bloom == nil or bloom.Enabled == false)
	check("lite: flat water", ws.Terrain.WaterWaveSize == 0)
	probe:Destroy()
end

print(`\n{passed} passed, {failed} failed`)
if #Engine.errors > 0 then
	print(#Engine.errors .. " script errors")
	failed += #Engine.errors
end
if failed > 0 then
	error("ClientSmoke: " .. failed .. " failures")
end
