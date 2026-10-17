--[[
Client smoke test: the real server AND the real client together on the mock engine, as a phone-sized touch
screen, so everything the client shows comes from what the server sends. A player joins: the HUD (phase, clock,
the frontline bar, the objective), the build tray and a structure placed through the client's own preview and
PLACE button, the hotbar (bow, TNT, blade; switching, the TNT's cooldown), the TNT thrown (the bundle in your hands,
the wind-up, the lob, the explosion and its clean-up), structures shattering into debris, the fight with the FIRE button (a predicted arrow, a hit
marker, the kill feed, the line moving on the bar), the camera and movement (the slide, the flip on the 4th jump),
and the results screen, the hit-direction markers and the comeback shield's pops. Fails on any script error.

  luaurun tests/ClientSmoke.spec.luau
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Vector3, CFrame = Engine.Vector3, Engine.CFrame
local Vector2 = Engine.globals.Vector2
local Enum = Engine.Enum

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
Engine.require(tree.shared.Constants).AFK_SECONDS = 0 -- (test players stand still: tests/ServerSmoke checks the AFK limbo on its own)
Engine.require(tree.shared.Constants).MIN_SIDE = 1 -- (the old minimum: these checks count the bots themselves; BotSmoke checks 2 v 2)
Engine.require(tree.shared.Constants).TUTORIAL = false -- (the players here know the game: tests/TutorialSmoke is the tutorial's)
Engine.require(tree.shared.Constants).BUILD_SECONDS = 60 -- (these checks were written around a long build phase; the game uses 20 s)
Engine.clientEnabled = true
local ws = Engine.workspace
ws.CurrentCamera.ViewportSize = Vector2.new(844, 390)
local UIS = Engine.game:GetService("UserInputService")
UIS.TouchEnabled = true
UIS.KeyboardEnabled = false
Engine.runScript(tree.server.Main)
-- (the first-knockout help is tests/FeelSmoke's: here every new test player plays as anyone would)
Engine.require(tree.server.Services.CombatService).firstKillHelp = false
Engine.advance(0.2)
local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Teams = service("TeamService")
local Combat = service("CombatService")
local Build = service("BuildService")
local Match = service("MatchService")
local Constants = Engine.require(tree.shared.Constants)
local Formulas = Engine.require(tree.shared.Formulas)

-- an opponent first (a server-side player), then the local player with the real client
local foe = Engine.addPlayer("Foe", 900)
Engine.advance(0.5)
Engine.fireServer(foe, "Ready")
local player = Engine.addPlayer("Ava", 501)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.runScript(tree.client.Main)
Engine.advance(1.5)
check("client sent Ready", Engine.lastClientEvent("Ready") ~= nil)
check("teams split one each", Teams:Team(player) ~= nil and Teams:Team(player) ~= Teams:Team(foe))

local gui = player.PlayerGui
local hud = gui:FindFirstChild("Hud")
local Hud = Engine.require(tree.client.Controllers.HudController)
local Weapon = Engine.require(tree.client.Controllers.WeaponController)
local BuildC = Engine.require(tree.client.Controllers.BuildController)
local Move = Engine.require(tree.client.Controllers.MoveController)
local Arrows = Engine.require(tree.client.Controllers.ArrowController)
local Store = Engine.require(tree.client.Store)
local Shop = Engine.require(tree.shared.Data.Shop)
local Data = service("PlayerDataService")
local refs = Hud.refs
local team = Teams:Team(player)
local s = team == "red" and -1 or 1

-- The HUD ------------------------------------------------------------------------------------------------------
check("a HUD exists", hud ~= nil)
check(
	"the phase and clock show BUILD",
	refs.phase and refs.phase.Text:find("BUILD") ~= nil,
	refs.phase and refs.phase.Text
)
check("the frontline bar starts half and half", refs.redFill and math.abs(refs.redFill.Size.X.Scale - 0.5) < 0.01)
check(
	"the objective is on screen at once",
	refs.objective and refs.objective.Visible ~= false and refs.objective.Text:find("pushes the line") ~= nil
)
check(
	"you know your team",
	refs.team and refs.team.Text:find(Constants.TEAM_NAME[team]) ~= nil,
	refs.team and refs.team.Text
)
check("first person: the camera is locked", player.CameraMode == Engine.Enum.CameraMode.LockFirstPerson)
check("the build tray is up in the build phase", refs.tray and refs.tray.Visible)
check("...with all seven pieces", refs.trayButtons and refs.trayButtons.tower ~= nil and refs.trayButtons.banner ~= nil)
check("touch: PLACE hides until a piece is picked", refs.touch and not refs.touch.place.Visible)

-- Building through the client's own preview ----------------------------------------------------------------------
Engine.moveTo(player, Vector3.new(s * 40, 3, -28), Vector3.new(s * 50, 3, -28))
local cam = ws.CurrentCamera
cam.CFrame = CFrame.lookAt(Vector3.new(s * 40, 5, -28), Vector3.new(s * 48, 0, -28))
Engine.advance(0.2)
refs.trayButtons.wall.Activated:Fire()
Engine.advance(0.1)
check("tapping a piece picks it", BuildC.picked() == "wall")
check("touch: PLACE and TURN appear", refs.touch.place.Visible and refs.touch.rotate.Visible)
-- the hotbar: numbered pieces, and the mouse wheel steps through them
local function wheel(z)
	UIS.InputChanged:Fire({ UserInputType = Enum.UserInputType.MouseWheel, Position = Vector3.new(0, 0, z) }, false)
	Engine.advance(0.2)
end
check(
	"the tray's pieces are numbered 1-7",
	refs.trayButtons.barricade.Key.Num.Text == "1" and refs.trayButtons.banner.Key.Num.Text == "7"
)
check(
	"...the name says just the name",
	refs.trayButtons.wall.Label.Text == "CASTLE WALL",
	refs.trayButtons.wall.Label.Text
)
wheel(-1)
check("wheel down: the next piece", BuildC.picked() == "reinforced", BuildC.picked())
wheel(1)
wheel(1)
check("wheel up: the one before", BuildC.picked() == "barricade", BuildC.picked())
wheel(1)
check("...round the end", BuildC.picked() == "banner", BuildC.picked())
BuildC.pick(nil)
wheel(-1)
check("...from nothing, the first", BuildC.picked() == "barricade", BuildC.picked())
do
	-- turning a piece: a right click (the wheel picks pieces) or R
	local r0 = BuildC.rotation()
	Engine.actions.TW_Rotate(
		"TW_Rotate",
		Enum.UserInputState.Begin,
		{ UserInputType = Enum.UserInputType.MouseButton2 }
	)
	check("a right click turns the piece", BuildC.rotation() ~= r0, BuildC.rotation())
	Engine.actions.TW_Rotate("TW_Rotate", Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.R })
	check("...and R turns it back", BuildC.rotation() == r0)
end
BuildC.pick("wall")
Engine.advance(0.1)
check(
	"the picked piece's badge turns white",
	refs.trayButtons.wall.Key.BackgroundColor3 ~= refs.trayButtons.cover.Key.BackgroundColor3
)
check(
	"...and the slot lifts, with a ring and its cost pill in the team's colour",
	refs.trayButtons.wall.Glow.Visible
		and refs.trayButtons.wall.Edge.Color == Constants.TEAM_COLOR[team]
		and refs.trayButtons.wall.CostPill.BackgroundColor3 == Constants.TEAM_COLOR[team]
		and refs.trayButtons.wall.Position.Y.Offset < refs.trayButtons.cover.Position.Y.Offset
		and not refs.trayButtons.cover.Glow.Visible
)
local spot = BuildC.spot()
check("a preview snaps to a cell where you look", spot ~= nil and spot.cx ~= nil, spot and spot.why)
check("...and it's a valid spot", spot and spot.ok, spot and spot.why)
check("...the hint says what the piece is for", refs.buildHint.Text:find("CASTLE WALL") ~= nil, refs.buildHint.Text)
refs.touch.place.Activated:Fire()
Engine.advance(0.3)
local built = 0
for _, st in Build:All() do
	if st.team == team then
		built += 1
	end
end
check("PLACE builds it (on the server)", built == 1, built)
check(
	"the points went down on the HUD",
	refs.budget.Text:find(tostring(Constants.BUILD_BUDGET - 10)) ~= nil,
	refs.budget.Text
)
cam.CFrame = CFrame.lookAt(Vector3.new(s * 40, 5, -28), Vector3.new(-s * 20, 0, -28))
Engine.advance(0.1)
check("aiming across the line turns the preview red", BuildC.spot() and not BuildC.spot().ok)
check("...and says why", refs.buildHint.Text:find("turf") ~= nil, refs.buildHint.Text)

-- The fight -----------------------------------------------------------------------------------------------------
Engine.advance(Constants.BUILD_SECONDS + 0.5)
check("FIGHT on the clock", refs.phase.Text:find("FIGHT") ~= nil, refs.phase.Text)
check("the tray goes away", not refs.tray.Visible)
check("touch: FIRE is up", refs.touch.fire.Visible)
do
	local keys = {}
	for k in refs.bows do
		table.insert(keys, k)
	end
	table.sort(keys)
	check(
		"the hotbar: the bow, the TNT and the blade, nothing else (no crossbow, no heavy bow)",
		#keys == 3 and refs.bows.bow and refs.bows.tnt and refs.bows.blade,
		table.concat(keys, " ")
	)
end
-- the TNT before it's bought: on the hotbar under a lock and its price; 2 keeps the bow in hand (and offers the
-- purchase: in Studio, with no pass id yet, that gives it free)
do
	Engine.advance(0.2)
	local lock = refs.bows.tnt.lock
	local price = lock and lock:FindFirstChild("Price", true)
	check(
		"TNT not bought: its slot is locked, with the price",
		lock ~= nil and lock.Visible and price ~= nil and price.Text ~= "",
		`{lock and lock.Visible} {price and price.Text}`
	)
	UIS.InputBegan:Fire({ KeyCode = Enum.KeyCode.Two, UserInputType = Enum.UserInputType.Keyboard }, false)
	Engine.advance(0.2)
	check("...2 leaves the bow in hand", Combat:Weapon(player) ~= "tnt", Combat:Weapon(player))
	Engine.require(tree.server.Services.ShopService):GrantTNT(player)
	Engine.advance(0.2)
	check("bought: the lock comes off", lock ~= nil and not lock.Visible)
end
UIS.InputBegan:Fire({ KeyCode = Enum.KeyCode.Two, UserInputType = Enum.UserInputType.Keyboard }, false)
Engine.advance(0.2)
check("2 picks the TNT", Store.get("me").weapon == "tnt" and Combat:Weapon(player) == "tnt")
check(
	"the slots are numbered 1, 2, 3",
	refs.bows.bow.key.Num.Text == "1" and refs.bows.tnt.key.Num.Text == "2" and refs.bows.blade.key.Num.Text == "3"
)
check("...the names say just the name", refs.bows.tnt.button.Label.Text == "TNT", refs.bows.tnt.button.Label.Text)
check("...the one in hand: its badge white", refs.bows.tnt.key.BackgroundColor3 ~= refs.bows.bow.key.BackgroundColor3)
-- the hotbar's look: a 3D picture in every slot, the one in hand lifted with a ring in the team's colour, the slots
-- side by side inside the bar
do
	local function pictured(button)
		local icon = button:FindFirstChild("Icon")
		local parts = 0
		for _, d in icon and icon:GetDescendants() or {} do
			if d:IsA("BasePart") then
				parts += 1
			end
		end
		return icon ~= nil and icon.ClassName == "ViewportFrame" and icon.CurrentCamera ~= nil and parts >= 3
	end
	local all = true
	for _, b in refs.bows do
		all = all and pictured(b.button)
	end
	for _, b in refs.trayButtons do
		all = all and pictured(b)
	end
	check("every weapon and every piece has its 3D picture (a ViewportFrame with a model and a camera)", all)
	local on, off = refs.bows.tnt.button, refs.bows.bow.button
	local teamC = Constants.TEAM_COLOR[team]
	check(
		"...the one in hand: a ring and a glow in the team's colour, lifted, dark",
		on.Edge.Color == teamC
			and on.Glow.Visible
			and not off.Glow.Visible
			and off.Edge.Color ~= teamC
			and on.Position.Y.Offset < off.Position.Y.Offset
			and on.BackgroundColor3 ~= off.BackgroundColor3
	)
	check(
		"...a red TNT bundle in its picture",
		(function()
			local red = 0
			for _, d in refs.bows.tnt.icon:GetDescendants() do
				if d:IsA("BasePart") and d.Color == Constants.TNT_RED then
					red += 1
				end
			end
			return red >= 3
		end)()
	)
	local function inside(frame, buttons)
		local bad = {}
		local list = {}
		for _, b in buttons do
			table.insert(list, b)
			local x, y = b.Position.X.Offset, b.Position.Y.Offset
			if
				x < 0
				or y < 0
				or x + b.Size.X.Offset > frame.Size.X.Offset
				or y + b.Size.Y.Offset > frame.Size.Y.Offset
			then
				table.insert(bad, b.Name .. " sticks out")
			end
		end
		for i = 1, #list do
			for j = i + 1, #list do
				local a, c = list[i], list[j]
				if
					a.Position.X.Offset < c.Position.X.Offset + c.Size.X.Offset
					and c.Position.X.Offset < a.Position.X.Offset + a.Size.X.Offset
				then
					table.insert(bad, a.Name .. " x " .. c.Name)
				end
			end
		end
		return bad
	end
	local buttons = {}
	for _, b in refs.bows do
		table.insert(buttons, b.button)
	end
	local bad = inside(refs.bowsFrame, buttons)
	check("...the slots side by side inside the bar", #bad == 0, table.concat(bad, ", "))
	bad = inside(refs.tray, refs.trayButtons)
	check("...and the tray's", #bad == 0, table.concat(bad, ", "))
end
check("no blade slot outside the CHARGE", refs.bows.blade.button.Visible == false)
wheel(-1)
check(
	"wheel down: round the end (past the blade: not out yet)",
	Store.get("me").weapon == "bow",
	Store.get("me").weapon
)
wheel(-1)
check("...the next: the TNT", Store.get("me").weapon == "tnt", Store.get("me").weapon)
wheel(1)
wheel(1)
check(
	"wheel up: the one before, round the end (past the blade)",
	Store.get("me").weapon == "tnt",
	Store.get("me").weapon
)
-- the shop's first-time tour: the first time the shop opens, 3 steps (your Shards, today's items, the pass),
-- skippable, remembered in the profile, never shown again
do
	local PanelC = Engine.require(tree.client.Controllers.PanelController)
	local pr = PanelC.refs
	check("no tour seen yet", Data:Get(player).settings.shopTour ~= true)
	PanelC.open("shop")
	Engine.advance(0)
	check("the shop opens with its tour", pr.tour ~= nil and pr.tour:GetAttribute("Step") == 1 and pr.overlay.Visible)
	check(
		"...step 1 rings your Shards",
		pr.tourRing.Visible and pr.tourRing.Position.X.Offset == pr.shards.Position.X.Offset - 4,
		pr.tourRing.Position
	)
	pr.tour.Next.Activated:Fire()
	check(
		"...NEXT: step 2, today's items",
		pr.tour and pr.tour:GetAttribute("Step") == 2 and pr.tour.Title.Text == "TODAY'S ITEMS"
	)
	pr.tour.Next.Activated:Fire()
	check(
		"...step 3: the Turf Pass, GOT IT!",
		pr.tour and pr.tour:GetAttribute("Step") == 3 and pr.tour.Next.Label.Text == "GOT IT!" and pr.tour.Skip ~= nil
	)
	pr.tour.Skip.Activated:Fire()
	Engine.advance(0)
	check("...SKIP ends it", pr.tour == nil and not pr.overlay.Visible and not pr.tourRing.Visible)
	check("...remembered in the profile", Data:Get(player).settings.shopTour == true)
	PanelC.close()
	PanelC.open("shop")
	Engine.advance(0)
	check("...and not shown again", pr.tour == nil and not pr.overlay.Visible)
	PanelC.close()
	Engine.advance(0)
end
-- a menu in the fight: the mouse shows and comes free, the bow doesn't fire
do
	local Layout = Engine.require(tree.client.UI.Layout)
	local CamC = Engine.require(tree.client.Controllers.CameraController)
	local BusM = Engine.require(tree.client.UI.Bus)
	check("in play the mouse is hidden", UIS.MouseIconEnabled == false)
	Layout.setPanel(true)
	Engine.advance(0.1)
	check("a menu open: the mouse shows", UIS.MouseIconEnabled == true and CamC.mouseFree())
	check("...and is free to move", UIS.MouseBehavior == Enum.MouseBehavior.Default)
	BusM.Fire:Fire(true)
	Engine.advance(0.3)
	check("...a click doesn't draw the bow", not Weapon.drawing())
	BusM.Fire:Fire(false)
	wheel(-1)
	check("...the wheel doesn't switch weapons (it scrolls the menu)", Store.get("me").weapon == "tnt")
	Layout.setPanel(false)
	Engine.advance(0.1)
	check("menu closed: the mouse hides again", UIS.MouseIconEnabled == false and not CamC.mouseFree())
	-- the shop panel for real: once closed its Modal ✕ lets go, and the cursor stays hidden even if Roblox shows it
	local PanelC = Engine.require(tree.client.Controllers.PanelController)
	PanelC.open()
	Engine.advance(0.5)
	local x = PanelC.refs and PanelC.refs.close
	check("the shop open: the mouse shows", UIS.MouseIconEnabled == true and (x == nil or x.Modal == true))
	PanelC.close()
	Engine.advance(0.5)
	check(
		"...closed: its Modal button lets go",
		x == nil or (x.Modal == false and CamC.parked()[x] == true),
		x and `{x.Modal} {CamC.parked()[x]} {x.Visible} {x.Parent and x.Parent.Name} {x:IsA("GuiButton")}`
	)
	UIS.MouseIconEnabled = true
	UIS.MouseBehavior = Enum.MouseBehavior.Default
	Engine.advance(0.1)
	check(
		"...and the cursor is put away again",
		UIS.MouseIconEnabled == false and UIS.MouseBehavior == Enum.MouseBehavior.LockCenter
	)
	PanelC.open()
	Engine.advance(0.5)
	check("...open again: Modal again", x == nil or x.Modal == true)
	PanelC.close()
	Engine.advance(0.5)
end
-- Alt frees the mouse any time (the chat, the admin panel, any button), Alt again goes back to aiming
do
	local CamC = Engine.require(tree.client.Controllers.CameraController)
	local Dev = Engine.require(tree.client.UI.Device)
	local was = Dev.kind()
	Dev.set("keyboard")
	Engine.advance(0.2)
	check("no mouse hint on screen (Tab opens the menu for the mouse)", Hud.refs.mouseHint == nil)
	UIS.InputBegan:Fire({ KeyCode = Enum.KeyCode.LeftAlt, UserInputType = Enum.UserInputType.Keyboard }, false)
	Engine.advance(0.1)
	check(
		"Alt: the mouse is free",
		CamC.cursorMode() and UIS.MouseIconEnabled == true and UIS.MouseBehavior == Enum.MouseBehavior.Default
	)
	local BusFire = Engine.require(tree.client.UI.Bus)
	BusFire.Fire:Fire(true)
	Engine.advance(0.3)
	check("...a click doesn't shoot", not Weapon.drawing())
	BusFire.Fire:Fire(false)
	UIS.InputBegan:Fire({ KeyCode = Enum.KeyCode.LeftAlt, UserInputType = Enum.UserInputType.Keyboard }, false)
	Engine.advance(0.1)
	check("Alt again: back to aiming", not CamC.cursorMode() and UIS.MouseIconEnabled == false)
	Dev.set(was)
	Engine.advance(0.2)
end
-- Tab: the menu on its PLAYERS tab (everyone on the server, INVITE to party up), Tab again closes it
do
	local PanelC = Engine.require(tree.client.Controllers.PanelController)
	UIS.InputBegan:Fire({ KeyCode = Enum.KeyCode.Tab, UserInputType = Enum.UserInputType.Keyboard }, false)
	Engine.advance(0.2)
	check("Tab opens the menu on PLAYERS", PanelC.isOpen() and PanelC.tab() == "players", PanelC.tab())
	local body = PanelC.refs.body
	local rows = 0
	for _, c in body:GetChildren() do
		if string.sub(c.Name, 1, 6) == "Player" then
			rows += 1
		end
	end
	check("...a row for everyone here", rows == #Engine.game:GetService("Players"):GetPlayers(), rows)
	check("...the count on top", body:FindFirstChild("Count") and string.find(body.Count.Text, "ONLINE") ~= nil)
	check("...the mouse is free", UIS.MouseIconEnabled == true)
	UIS.InputBegan:Fire({ KeyCode = Enum.KeyCode.Tab, UserInputType = Enum.UserInputType.Keyboard }, false)
	Engine.advance(0.2)
	check("Tab again closes it", not PanelC.isOpen())
end
-- someone joins: a small chip at the left (not the banner), gone after a few seconds
do
	local NotifyC = Engine.require(tree.client.Controllers.NotifyController)
	NotifyC.show({ text = "Zed joined your team!", kind = "join", ally = true, icon = "🎉" })
	NotifyC.show({ text = "Kai joined BLUE: new enemy!", kind = "join", ally = false, icon = "⚔️" })
	Engine.advance(0.3)
	check("join chips: small, at the left", #NotifyC.chips() == 2 and NotifyC.chips()[1].frame.Size.X.Offset <= 260)
	check("...not the big banner", NotifyC.current() == nil or NotifyC.current().kind ~= "join")
	Engine.advance(5)
	check("...gone after a few seconds", #NotifyC.chips() == 0)
end
-- graphics: more on a PC that can take it, nothing added on a phone
do
	local Gfx = Engine.require(tree.client.Controllers.GraphicsController)
	local Dev = Engine.require(tree.client.UI.Device)
	local L = Engine.game:GetService("Lighting")
	local was = Dev.kind()
	Dev.set("touch")
	check("a phone: nothing added", Gfx.tier() == "low" and not L:FindFirstChild("TW_Bloom"), Gfx.tier())
	Dev.set("keyboard")
	check("a PC: the high tier", Gfx.tier() == "high", Gfx.tier())
	check(
		"...bloom, sun rays, far haze",
		L:FindFirstChild("TW_Bloom") and L:FindFirstChild("TW_Rays") and L:FindFirstChild("TW_Depth")
	)
	check("...the bloom only catches the neon", L.TW_Bloom.Threshold >= 2.5)
	Gfx.apply("mid")
	check(
		"mid: a lighter bloom, no rays",
		L:FindFirstChild("TW_Bloom") and not L:FindFirstChild("TW_Rays") and not L:FindFirstChild("TW_Depth")
	)
	Gfx.apply("low")
	check("low: nothing added", not L:FindFirstChild("TW_Bloom") and not L:FindFirstChild("TW_Rays"))
	Gfx.apply(nil)
	check("...back to the device's own", Gfx.tier() == "high")
	Dev.set(was)
end
-- banners: a server message slides in under the top bar, one at a time
do
	local NotifyC = Engine.require(tree.client.Controllers.NotifyController)
	NotifyC.show({ text = "Red team wins!", kind = "win" })
	NotifyC.show({ text = "Ava is MVP!", kind = "status" })
	Engine.advance(0.1)
	local cur = NotifyC.current()
	check("a banner shows", cur and cur.text == "Red team wins!" and NotifyC.refs.strip.Visible == true)
	check("...the next waits its turn", NotifyC.queued() == 1)
	Engine.advance(4)
	check("...then the next one", NotifyC.current() and NotifyC.current().text == "Ava is MVP!")
	Engine.advance(4)
	-- in the AFK room nothing piles up: coming back, no backlog of what you missed
	player:SetAttribute("Limbo", true)
	Engine.advance(0.1)
	NotifyC.show({ text = "You're AFK", kind = "info", always = true })
	for i = 1, 4 do
		NotifyC.show({ text = "Missed " .. i, kind = "info" })
	end
	check("AFK: only the AFK banner, nothing kept for later", NotifyC.queued() <= 1)
	player:SetAttribute("Limbo", nil)
	Engine.advance(0.1)
	check("...back: no backlog", NotifyC.queued() == 0)
	Engine.advance(4)
	-- old news: a banner that waited too long (a menu was open) is dropped
	local Layout = Engine.require(tree.client.UI.Layout)
	Layout.setPanel(true)
	NotifyC.show({ text = "Old news", kind = "info" })
	Engine.advance(12)
	Layout.setPanel(false)
	Engine.advance(0.1)
	check(
		"a banner that waited too long is dropped",
		NotifyC.queued() == 0 and (NotifyC.current() == nil or NotifyC.current().text ~= "Old news")
	)
end
-- the blade: only in the CHARGE (the fight's last seconds); then 3 picks it, a click slashes
do
	UIS.InputBegan:Fire({ KeyCode = Enum.KeyCode.Three, UserInputType = Enum.UserInputType.Keyboard }, false)
	Engine.advance(0.3)
	check("3 does nothing before the CHARGE", Store.get("me").weapon ~= "blade")
	Constants.CHARGE_SECONDS = 1e6 -- (the whole fight is the CHARGE for this block)
	Engine.advance(0.5)
	check("the CHARGE: the blade's slot shows", refs.bows.blade.button.Visible == true)
	UIS.InputBegan:Fire({ KeyCode = Enum.KeyCode.Three, UserInputType = Enum.UserInputType.Keyboard }, false)
	Engine.advance(0.3)
	check("3 picks the blade", Store.get("me").weapon == "blade" and Combat:Weapon(player) == "blade")
	check("...numbered 3 on the hotbar", refs.bows.blade and refs.bows.blade.key.Num.Text == "3")
	local vm = ws.CurrentCamera:FindFirstChild("Viewmodel")
	check("...a blade in your hand", vm and vm:FindFirstChild("Edge") ~= nil and vm:FindFirstChild("String") == nil)
	check(
		"...solid steel, never see-through or glowing (bow skins are for bows)",
		vm
			and vm.Edge.Material ~= Enum.Material.Neon
			and vm.Edge.Material ~= Enum.Material.Metal -- (Metal came out black under the matte light)
			and vm.Edge.Color.R > 0.75
			and vm:FindFirstChild("Bevel") ~= nil
			and vm.Edge.Transparency == 0
			and vm.Grip.Material ~= Enum.Material.ForceField
			and vm.Grip.Material ~= Enum.Material.Glass
	)
	Engine.advance(0.5)
	local edge = vm and vm:FindFirstChild("Edge")
	local rest = edge and edge.Position
	local BusB = Engine.require(tree.client.UI.Bus)
	local before = Engine.lastClientEvent("Swing")
	BusB.Fire:Fire(true)
	Engine.advance(0.1)
	BusB.Fire:Fire(false)
	check("a click slashes (the server is asked)", Engine.lastClientEvent("Swing") ~= before)
	check("...and the blade sweeps across", edge and (edge.Position - rest).Magnitude > 0.1)
	local SwingC = Engine.require(tree.client.Controllers.SwingController)
	check("...with a streak through the air", SwingC.streaks() > 0)
	check("someone else's slash shows on their body", SwingC.slashOf(foe.Character, Vector3.new(1, 0, 0)))
	check("...no charge ring for a blade", not refs.charge.Visible)
	Engine.advance(0.4)
	local AudioS = Engine.require(tree.client.Controllers.AudioController)
	check("a slash that cut no one: you hear the whiff", AudioS.count("whiff") > 0, AudioS.count("whiff"))
	-- the soft lock-on and the lunge: a slash turns onto the enemy in front (40 degrees off where you look) and
	-- carries you at them, stopping short
	do
		local myRoot = player.Character.HumanoidRootPart
		local at = myRoot.Position
		local look = Vector3.new(0, 0, -1)
		local off = Vector3.new(math.sin(math.rad(40)), 0, -math.cos(math.rad(40)))
		Engine.moveTo(player, at, at + look)
		Engine.moveTo(foe, at + off * 9, at)
		local dir, lock = SwingC.aim(look)
		check("the lock-on finds the enemy in front", lock == foe.Character.HumanoidRootPart)
		check("...and turns the slash onto them", dir:Dot(off) > 0.99, dir)
		check("...a lunge at them", SwingC.lunge(dir, lock) and SwingC.lunging())
		Engine.advance(1 / 60)
		local v = myRoot.AssemblyLinearVelocity
		check(
			"...carries you their way, fast",
			Vector3.new(v.X, 0, v.Z):Dot(off) > Constants.BLADE_LUNGE / Constants.BLADE_LUNGE_TIME * 0.9,
			v
		)
		Engine.advance(Constants.BLADE_LUNGE_TIME + 0.1)
		check("...for a moment only", not SwingC.lunging())
		Engine.moveTo(foe, at - look * 30, at)
		local dir2, lock2 = SwingC.aim(look)
		check("no one in front: no lock, the slash goes where you look", lock2 == nil and dir2:Dot(look) > 0.99)
		Engine.moveTo(foe, at + look * 2.5, at)
		check("already on them: no lunge (you'd run through)", not SwingC.lunge(look, foe.Character.HumanoidRootPart))
	end
	Engine.advance(0.6)
	Constants.CHARGE_SECONDS = 20
	Engine.advance(0.5)
	check(
		"the CHARGE over: the blade goes away",
		Store.get("me").weapon ~= "blade" and refs.bows.blade.button.Visible == false
	)
end
Weapon.equip("bow")
Engine.advance(0.2)
-- stand facing the foe across the line and shoot with the FIRE button
Engine.advance(Constants.SPAWN_PROTECT)
Engine.moveTo(player, Vector3.new(s * 8, 3, -27), Vector3.new(-s * 8, 3, -27))
Engine.moveTo(foe, Vector3.new(-s * 8, 3, -27), Vector3.new(s * 8, 3, -27))
cam.CFrame = CFrame.lookAt(Vector3.new(s * 8, 4.6, -27), Vector3.new(-s * 8, 3.3, -27))
Engine.advance(0.2)
local Bus = Engine.require(tree.client.UI.Bus)
Bus.Fire:Fire(true)
Engine.advance(1.0)
check("drawing shows the charge", refs.charge.Visible)
Bus.Fire:Fire(false)
check("letting go draws your arrow at once (predicted)", Arrows.count() >= 1)
Engine.advance(0.6)
check("the shot went to the server", Engine.lastClientEvent("Shoot") ~= nil)
check("a full draw kills the foe", not Combat:Alive(foe), Combat:Health(foe))
check("a hit marker (red: a kill)", refs.hit and refs.hitLines[1].BackgroundColor3 == Constants.TEAM_COLOR.red)
check("the kill feed shows it", #refs.feed:GetChildren() >= 2)
check(
	"the bar moved toward them",
	(team == "red" and refs.redFill.Size.X.Scale > 0.5) or (team == "blue" and refs.redFill.Size.X.Scale < 0.5),
	refs.redFill.Size.X.Scale
)

-- Movement -------------------------------------------------------------------------------------------------------
check("slide: a burst forward", Move.slide() and Move.sliding())
check("...on a cooldown", not Move.slide())
local flips = 0
for _ = 1, Constants.FLIP_EVERY do
	if Move.jumped() then
		flips += 1
	end
end
check("the 4th jump flips", flips == 1 and Move.flipping())
do
	local cam = Engine.game:GetService("Workspace").CurrentCamera
	local CamC = Engine.require(tree.client.Controllers.CameraController)
	local fov0 = CamC.targetFov()
	local still = true
	for _ = 1, 8 do
		local before = cam.CFrame.LookVector
		Engine.advance(0.05)
		if (cam.CFrame.LookVector - before).Magnitude > 0.001 or CamC.targetFov() ~= fov0 then
			still = false
		end
	end
	check("...and the camera stays exactly as it is (no spin, dip or zoom)", still)
end

-- Crouch ---------------------------------------------------------------------------------------------------------
Engine.advance(2)
local hum0 = player.Character:FindFirstChildOfClass("Humanoid")
local hip0 = hum0.HipHeight
Move.setSprint(false)
Engine.advance(0.7)
Move.setCrouch(true)
Engine.advance(0.7)
check("crouch: lower", hum0.HipHeight < hip0 - 0.5, `{hum0.HipHeight} vs {hip0}`)
check("...and slower", hum0.WalkSpeed == Constants.CROUCH_SPEED, hum0.WalkSpeed)
check("...and the server knows (it lowers you for everyone)", service("MoveService"):State(player).crouch == true)
Move.setCrouch(false)
Engine.advance(0.7)
check("standing back up", math.abs(hum0.HipHeight - hip0) < 0.01 and hum0.WalkSpeed == Constants.WALK_SPEED)

-- The bow in your hands -------------------------------------------------------------------------------------------
do
	local vm = ws.CurrentCamera:FindFirstChild("Viewmodel")
	check(
		"the viewmodel has arms and hands",
		vm and vm:FindFirstChild("ArmL") and vm:FindFirstChild("ArmR") and vm:FindFirstChild("HandR") ~= nil
	)
	check("...and a string in two halves", vm and vm:FindFirstChild("String") and vm:FindFirstChild("StringL") ~= nil)
	local function rel(name)
		local p = ws.CurrentCamera:FindFirstChild("Viewmodel"):FindFirstChild(name)
		return ws.CurrentCamera.CFrame:PointToObjectSpace(p.Position)
	end
	Engine.advance(1)
	Weapon.equip("bow")
	Engine.advance(0.03)
	local early = rel("Grip")
	Engine.advance(0.8)
	local late = rel("Grip")
	check("equipping: the bow comes up from below", early.Y < late.Y - 0.2, `{early.Y} -> {late.Y}`)
	local restHand = rel("HandR")
	local restGrip = rel("Grip")
	Bus.Fire:Fire(true)
	Engine.advance(1.6)
	local drawnHand = rel("HandR")
	local drawnGrip = rel("Grip")
	check(
		"drawing: your hand pulls the string back",
		(drawnHand - drawnGrip).Magnitude > (restHand - restGrip).Magnitude + 0.6,
		`{(restHand - restGrip).Magnitude} -> {(drawnHand - drawnGrip).Magnitude}`
	)
	check("...and the bow comes across to the left (clear of the crosshair)", drawnGrip.X < restGrip.X - 0.2)
	Bus.Fire:Fire(false)
	Engine.advance(0.02)
	check("release: the bow kicks", Weapon.anim().kick.v ~= 0 or Weapon.anim().kick.p ~= 0)
	Engine.advance(1)
	-- the TNT: a red bundle in your right hand; winding up draws it back over your shoulder, its fuse sparking; let go
	-- and it's thrown (drawn flying at once), your hand empty through the cooldown (counted on the hotbar), then a
	-- fresh bundle comes up
	local Explosion = Engine.require(tree.client.Controllers.ExplosionController)
	local tnt = Engine.require(tree.shared.Data.Weapons).get("tnt")
	Weapon.equip("tnt")
	Engine.advance(0.6)
	local tvm = ws.CurrentCamera:FindFirstChild("Viewmodel")
	local sticks = 0
	for _, q in tvm:GetChildren() do
		if q.Name == "Stick" and q.Color == Constants.TNT_RED and q.Transparency == 0 then
			sticks += 1
		end
	end
	check("the TNT in your hand: three red sticks, a fuse", sticks == 3 and tvm:FindFirstChild("Fuse") ~= nil, sticks)
	check("...and no bow (no string)", tvm:FindFirstChild("String") == nil)
	local restBand = rel("Band")
	Bus.Fire:Fire(true)
	Engine.advance(0.9)
	local woundBand = rel("Band")
	check(
		"winding up: the bundle goes back and up, over your shoulder",
		woundBand.Z > restBand.Z + 0.15 and woundBand.Y > restBand.Y + 0.1,
		`{restBand} -> {woundBand}`
	)
	check("...the fuse sparks", tvm.Spark.Material == Enum.Material.Neon and tvm.Spark.Transparency == 0)
	check("...and the ring shows how far it'll go", refs.charge.Visible)
	local before = Engine.lastClientEvent("Shoot")
	local bombs0 = Explosion.bombs()
	Bus.Fire:Fire(false)
	Engine.advance(0.1)
	check("let go: it's thrown (the server is asked)", Engine.lastClientEvent("Shoot") ~= before)
	check("...and drawn flying at once", Explosion.bombs() >= bombs0 + 1 or Explosion.effects() > 0, Explosion.bombs())
	check("...your hand is empty", tvm.Stick.Transparency == 1)
	check(
		"...the cooldown on the hotbar",
		tonumber(refs.bows.tnt.ammo.Text) ~= nil and tonumber(refs.bows.tnt.ammo.Text) > 1,
		refs.bows.tnt.ammo.Text
	)
	Bus.Fire:Fire(true)
	Engine.advance(0.1)
	check("...no winding up again during it", not Weapon.drawing())
	Bus.Fire:Fire(false)
	Weapon.equip("bow")
	Engine.advance(0.2)
	Bus.Fire:Fire(true)
	Engine.advance(0.1)
	check("...but the bow is ready at once (the TNT has its own cooldown)", Weapon.drawing())
	Bus.Fire:Fire(false)
	-- (it goes off where it lands, within the fuse: watch for the explosion's pieces)
	local seen = {}
	for _ = 1, math.ceil((Constants.TNT_FUSE + 0.3) / 0.05) do
		Engine.advance(0.05)
		for _, kind in { "grow", "ring", "smoke", "spark", "light" } do
			seen[kind] = seen[kind] or Explosion.effects(kind) > 0
		end
	end
	check(
		"it goes off: a flash and a fireball, a shockwave, smoke, sparks, a light",
		seen.grow and seen.ring and seen.smoke and seen.spark and seen.light
	)
	Weapon.equip("tnt")
	Engine.advance(tnt.cooldown)
	check(
		"...and after the cooldown a fresh bundle is in your hand",
		ws.CurrentCamera.Viewmodel.Stick.Transparency == 0
	)
	check("...the hotbar's count gone", refs.bows.tnt.ammo.Text == "", refs.bows.tnt.ammo.Text)
	Engine.advance(3.5)
	check("the explosion cleans itself up", Explosion.effects() == 0 and Explosion.bombs() == 0, Explosion.effects())
	Weapon.equip("bow")
	Engine.advance(0.3)
	local held = foe.Character and foe.Character:FindFirstChild("HeldBow")
	local mine = player.Character:FindFirstChild("HeldBow")
	check("everyone holds a bow others can see", held ~= nil or mine ~= nil)
	local hidden = mine and mine:FindFirstChildWhichIsA("BasePart").LocalTransparencyModifier == 1
	check("...yours hidden from you (you see your arms)", hidden == true)
end

-- Your hands, and the middle of the screen kept clear --------------------------------------------------------------
do
	local camera = ws.CurrentCamera
	-- the parts of the viewmodel that land in the middle of the screen (the middle 16% of its width and height), at
	-- a field of view and a screen shape: points through each part (corners, edges and inside), projected
	local function inMiddle(fov, aspect)
		local vm = camera:FindFirstChild("Viewmodel")
		local tanV = math.tan(math.rad(fov / 2))
		local bad = {}
		for _, p in vm:GetChildren() do
			if p:IsA("BasePart") and p.Transparency < 1 then
				local n = {}
				for k, s in { p.Size.X, p.Size.Y, p.Size.Z } do
					n[k] = math.clamp(math.ceil(s / 0.04), 1, 16)
				end
				local hit = false
				for i = 0, n[1] do
					for j = 0, n[2] do
						for k = 0, n[3] do
							local q = p.CFrame
								* Vector3.new(
									(i / n[1] - 0.5) * p.Size.X,
									(j / n[2] - 0.5) * p.Size.Y,
									(k / n[3] - 0.5) * p.Size.Z
								)
							local c = camera.CFrame:PointToObjectSpace(q)
							if c.Z < -0.01 then
								local sx = c.X / (-c.Z * tanV * aspect)
								local sy = c.Y / (-c.Z * tanV)
								if math.abs(sx) < 0.16 and math.abs(sy) < 0.16 then
									hit = true
								end
							end
						end
					end
				end
				if hit then
					table.insert(bad, p.Name)
				end
			end
		end
		return bad
	end
	-- clear for `seconds` (every frame of 1/20 s through it; 0: just now)
	local function clear(what, seconds)
		local bad = {}
		local t = 0
		repeat
			for _, fov in { 80, 70, 86 } do -- (the view's own, drawn (it tightens by up to 10), and a phone's wider one)
				for _, aspect in { 16 / 9, 844 / 390 } do -- (a monitor, a wide phone)
					for _, name in inMiddle(fov, aspect) do
						bad[name] = true
					end
				end
			end
			if (seconds or 0) > 0 then
				Engine.advance(0.05)
			end
			t += 0.05
		until t > (seconds or 0)
		local names = {}
		for name in bad do
			table.insert(names, name)
		end
		check(what .. ": nothing in the middle of the screen", #names == 0, table.concat(names, ", "))
	end
	local function hands(key)
		local vm = camera:FindFirstChild("Viewmodel")
		local ok, why = true, ""
		for _, side in { "L", "R" } do
			local palm = vm:FindFirstChild("Hand" .. side)
			local fingers, thumbs = 0, 0
			for _, p in vm:GetChildren() do
				if p.Name == "Hand" .. side .. "Finger" then
					fingers += 1
				elseif p.Name == "Hand" .. side .. "Thumb" then
					thumbs += 1
				end
			end
			local sizes = palm and { palm.Size.X, palm.Size.Y, palm.Size.Z } or { 0, 0, 0 }
			table.sort(sizes)
			-- a real palm (not a stick: its two big sides over 0.18 studs), four fingers in two bones, a thumb
			if not palm or sizes[2] < 0.18 or fingers < 8 or thumbs < 2 or palm.Transparency ~= 0 then
				ok = false
				why ..= `{side}: palm {sizes[2]} fingers {fingers} thumbs {thumbs} `
			end
			local sleeve = vm:FindFirstChild("Arm" .. side)
			if not sleeve or sleeve.Size.Y < 0.15 or sleeve.Color ~= Constants.TEAM_COLOR[team] then
				ok = false
				why ..= `{side}: no sleeve in the team's colour `
			end
		end
		check(key .. ": both hands, a palm, fingers and a thumb each, sleeves in the team's colour", ok, why)
		local light = true
		for _, p in vm:GetChildren() do
			if p:IsA("BasePart") and (p.CastShadow or p.CanCollide or p.CanQuery or p.CanTouch) then
				light = false
			end
		end
		check("...light: no shadows, nothing to bump into or hit", light)
	end
	local BusH = Engine.require(tree.client.UI.Bus)
	for _, key in { "bow", "tnt", "blade" } do
		Weapon.equip(key)
		Engine.advance(1)
		hands(key)
		clear(key .. " at rest")
		if key == "bow" then
			BusH.Fire:Fire(true)
			clear(key .. " drawing", 0.8)
			Engine.advance(1.6)
			clear(key .. " at full draw (shaking)", 0.5)
			BusH.Fire:Fire(false)
			clear(key .. " after the shot (the kick, back down)", 1)
		elseif key == "tnt" then
			BusH.Fire:Fire(true)
			clear(key .. " winding up", 0.8)
			BusH.Fire:Fire(false)
			clear(
				key .. " thrown (the cooldown, a fresh bundle coming up)",
				Engine.require(tree.shared.Data.Weapons).get("tnt").cooldown + 0.2
			)
		end
	end
	Weapon.equip("bow")
	Engine.advance(0.3)
end

-- Structures: castle stone, wood and iron with the team's colour on the trim; when one comes down it shatters ---
do
	local Debris = Engine.require(tree.client.Controllers.DebrisController)
	local Gfx = Engine.require(tree.client.Controllers.GraphicsController)
	local StructureModel = Engine.require(tree.shared.StructureModel)
	-- (the same colour: the mock's Color3 has no value equality)
	local function same(a, b)
		return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) < 1e-3
	end
	local shade = Constants.BUILD_COLOR[team]
	local wall
	for _, st in Build:All() do
		if st.team == team and st.key == "wall" then
			wall = st
		end
	end
	-- every toned part: is it in its tone's colour, round anywhere, and is the team's own shade there?
	local function colours(container)
		local n, right, round, teamed = 0, true, 0, false
		for _, d in container:GetDescendants() do
			local tone = d:IsA("BasePart") and d:GetAttribute("Tone")
			if tone then
				n += 1
				right = right and same(d.Color, StructureModel.color(tone, team))
				teamed = teamed or same(d.Color, shade)
				if d.Shape == Enum.PartType.Ball or d.Shape == Enum.PartType.Cylinder then
					round += 1
				end
			end
		end
		return n, right, round, teamed
	end
	local n, right, round, teamed = colours(wall.model)
	check("your Castle Wall: many parts, each in its tone, your team's colour on it", n >= 8 and right and teamed, n)
	check("...nothing round in it", round == 0, round)
	local _, kRight, kRound = colours(refs.trayButtons.reinforced.Icon)
	local dark = false
	for _, d in refs.trayButtons.reinforced.Icon:GetDescendants() do
		dark = dark or (d:IsA("BasePart") and same(d.Color, StructureModel.color("stoneDark", team)))
	end
	check("the tray's Keep Wall: its dark stone, nothing round", dark and kRight and kRound == 0)
	local tn, tRight, tRound, tTeamed = colours(refs.trayButtons.tower.Icon)
	check("...the Watchtower: square, the team's colour on top", tn > 0 and tRight and tRound == 0 and tTeamed)
	check(
		"...the tray's names are the castle's",
		refs.trayButtons.bridge.Label.Text == "RAMPART" and refs.trayButtons.banner.Label.Text == "RALLY BANNER",
		refs.trayButtons.bridge.Label.Text
	)
	-- an arrow breaks it: the client throws its pieces from where the arrow hit
	Gfx.apply("high")
	local hitAt = (wall.boxMin + wall.boxMax) / 2 + Vector3.new(0, 2, 0)
	Build:Remove(wall.id, foe, false, { pos = hitAt, power = 0.35, team = Teams:Team(foe) })
	Engine.advance(0.05)
	check("the wall comes down: its model gone", wall.model.Parent == nil)
	local flying = Debris.count()
	check("...it shatters into chunks", flying >= 20, flying)
	local folder = ws:FindFirstChild("DebrisFx")
	local quiet = true
	for _, d in folder and folder:GetDescendants() or {} do
		if d:IsA("BasePart") and (d.CanCollide or d.CanQuery or d.CanTouch) then
			quiet = false
		end
	end
	check("...nothing anyone can bump into or hit", quiet)
	check("...with dust", Debris.dust() > 0)
	local before = {}
	for _, d in folder:GetChildren() do
		if d.Name == "Chunk" then
			before[d] = d.Position
		end
	end
	Engine.advance(0.4)
	local moved, under = 0, 0
	for d, p0 in before do
		if d.Parent and (d.Position - p0).Magnitude > 0.5 then
			moved += 1
		end
		if d.Parent and d.Position.Y < wall.boxMin.Y - 0.01 then
			under += 1
		end
	end
	check("...flying apart", moved >= flying * 0.6, moved)
	check("...never through the floor", under == 0, under)
	Engine.advance(3.2)
	check(
		"...and all gone again after about 3 s",
		Debris.count() == 0 and Debris.dust() == 0 and #folder:GetChildren() == 0,
		Debris.count()
	)
	-- the TNT's is much bigger; a phone gets far fewer; a cap on how many are made each frame
	local box0, box1 = Vector3.new(40, 0, 40), Vector3.new(48, 10, 44)
	local tntInfo = {
		key = "wall",
		team = team,
		min = box0,
		max = box1,
		blast = { pos = Vector3.new(44, 1, 46), power = 1, tnt = true },
	}
	local arrowInfo =
		{ key = "wall", team = team, min = box0, max = box1, blast = { pos = Vector3.new(44, 5, 46), power = 0.35 } }
	local big = Debris.shatter(tntInfo)
	local small = Debris.shatter(arrowInfo)
	check("a TNT shatters it into far more pieces than an arrow", big > small * 1.5, `{big} {small}`)
	check("...made a few each frame, not all at once", Debris.queued() > 0)
	Engine.advance(3.5)
	Gfx.apply("low")
	local phone = Debris.shatter(tntInfo)
	check("...far fewer on a phone (low graphics)", phone < big * 0.5, `{phone} {big}`)
	Engine.advance(3.5)
	check("...and cleaned up", Debris.count() == 0)
	Gfx.apply(nil)
end

-- The results ----------------------------------------------------------------------------------------------------
Match:Victory(team)
Engine.advance(0.5)
check("the results card shows", refs.results ~= nil and refs.results.Parent ~= nil)
check(
	"...and you stay in play: no cursor",
	UIS.MouseIconEnabled == false and UIS.MouseBehavior == Enum.MouseBehavior.LockCenter
)
check(
	"...naming the winner",
	refs.results and refs.results:FindFirstChildWhichIsA("TextLabel").Text:find("WINS") ~= nil
)
local Fireworks = Engine.require(tree.client.Controllers.FireworksController)
Engine.advance(1)
check("fireworks go off in the winners' colour", Fireworks.active() and Fireworks.count() > 0, Fireworks.count())
check("the top shows the countdown", refs.phase.Text:find("NEXT GAME") ~= nil, refs.phase.Text)
Engine.advance(Constants.FEEDBACK_ASK_DELAY)
local Feedback = Engine.require(tree.client.Controllers.FeedbackController)
local kind, card = Feedback.current()
check("the winner is asked if they like the game", kind == "enjoy" and card ~= nil)
check(
	"...with buttons the mouse can reach in first person",
	card and card:FindFirstChild("Yes") and card.Yes.Modal == true
)
card.Yes.Activated:Fire()
Engine.advance(0.2)
check("YES goes to the server", Engine.lastClientEvent("Feedback") ~= nil and Feedback.current() == nil)
local popups = Hud.popups()
local thanksCard = popups[#popups]
check(
	"...and a THANK YOU card comes up in the popup stack",
	thanksCard and thanksCard.Name == "Thanks" and thanksCard.Head.Text == "THANK YOU!",
	thanksCard and thanksCard.Name
)
check("...showing the trail", thanksCard and thanksCard:FindFirstChild("Preview") ~= nil)
check(
	"...worn straight away (the profile says so)",
	((Store.get("profile") or {}).equipped or {}).trail == "extra_thanks"
)
local twins0 = Arrows.twins()
Arrows.predict(Vector3.new(0, 5, 0), Vector3.new(80, 0, 0), team, 4242)
check("your arrows draw the Thank-You Trail", Arrows.twins() == twins0 + 1)
Engine.advance(Constants.RESULTS_CARD_SECONDS)
check(
	"after the results, a big countdown",
	refs.countdown.Visible and refs.countdown.Text:find("NEXT GAME IN") ~= nil,
	refs.countdown.Text
)
Engine.advance(Constants.VICTORY_SECONDS + Constants.TRANSITION_SECONDS + 1)
check("the next match: BUILD again", refs.phase.Text:find("BUILD") ~= nil, refs.phase.Text)
check("...the results close", refs.results == nil)

-- Invite a friend -------------------------------------------------------------------------------------------------
do
	local before = Engine.invites
	refs.invite.Activated:Fire()
	check("INVITE opens Roblox's invite prompt", Engine.invites == before + 1)
	UIS.InputBegan:Fire({ KeyCode = Enum.KeyCode.I, UserInputType = Enum.UserInputType.Keyboard }, false)
	check("...and so does I", Engine.invites == before + 2)
	check("...saying what you both get", refs.invite.Line.Text:find("Buddy Trail") ~= nil)
	local twins0 = Arrows.twins()
	Store.set("profile", { equipped = { trail = "extra_buddy" } })
	Arrows.predict(Vector3.new(0, 5, 0), Vector3.new(80, 0, 0), team, 4343)
	check("the Buddy Trail draws a line each side of the tracer", Arrows.twins() == twins0 + 2)
end

-- Parties ------------------------------------------------------------------------------------------------------
local PartyC = Engine.require(tree.client.Controllers.PartyController)
local pref = PartyC.refs
local TopC = Engine.require(tree.client.Controllers.LeaderboardController)
local tref = TopC.refs
do
	local PartySvc = service("PartyService")
	local Layout = Engine.require(tree.client.UI.Layout)
	check("a PARTY button beside INVITE", pref.button ~= nil and pref.button.Parent ~= nil)
	UIS.InputBegan:Fire({ KeyCode = Enum.KeyCode.P, UserInputType = Enum.UserInputType.Keyboard }, false)
	Engine.advance(0.1)
	check("P opens the party panel", PartyC.isOpen() and Layout.panel())
	check("...with the mouse free (a Modal button)", pref.close.Modal == true)
	local inv = pref.players:FindFirstChild("Invite_" .. foe.UserId)
	check("...listing the players here with INVITE", inv ~= nil)
	if inv then
		inv.Activated:Fire()
	end
	Engine.advance(0.3)
	PartySvc:Answer(foe, true)
	Engine.advance(0.3)
	check("INVITE, and a YES: a party, you lead", PartySvc:Of(player) ~= nil and PartySvc:Of(player).leader == player)
	check("...both on your team", Teams:Team(foe) == Teams:Team(player))
	check(
		"...the panel shows KICK and the server buttons",
		pref.members:FindFirstChild("Kick2") ~= nil and pref.newServer.Visible
	)
	check("...the corner list shows you both", pref.list.Visible and pref.list:FindFirstChild("Member2") ~= nil)
	check("...the PARTY button says so", pref.buttonLine.Text:find("2/4") ~= nil, pref.buttonLine.Text)
	local mark = PartyC.marks()[foe.UserId]
	check(
		"...a 👥 over Foe, drawn only on your screen",
		mark and mark.Parent == player.PlayerGui and mark.Adornee ~= nil
	)
	UIS.InputBegan:Fire({ KeyCode = Enum.KeyCode.P, UserInputType = Enum.UserInputType.Keyboard }, false)
	Engine.advance(0.1)
	check("P closes it", not PartyC.isOpen() and not Layout.panel())
	-- an invite card: N says no, and it goes
	Engine.remote("PartyInvite").OnClientEvent:Fire({ from = 900, name = "Foe", kind = "friend", seconds = 20 })
	local card = PartyC.card()
	check("an invite card", card ~= nil and card.Title.Text:find("PARTY UP WITH FOE") ~= nil)
	UIS.InputBegan:Fire({ KeyCode = Enum.KeyCode.N, UserInputType = Enum.UserInputType.Keyboard }, false)
	check("...N answers it", PartyC.card() == nil)
	Engine.remote("PartyInvite").OnClientEvent:Fire({ from = 900, name = "Foe", kind = "invite", seconds = 20 })
	Engine.advance(21)
	check("...it goes by itself after 20 s", PartyC.card() == nil)
	PartySvc:Leave(foe)
	Engine.advance(0.3)
	check("the party ends: the list and the marker go", not pref.list.Visible and next(PartyC.marks()) == nil)
	-- (a full party of four in the corner list, for the layout checks below)
	Engine.remote("PartyState").OnClientEvent:Fire({
		id = "x",
		leader = player.UserId,
		max = 4,
		members = {
			{ userId = player.UserId, name = "Ava" },
			{ userId = 7, name = "SomeoneWithALongName" },
			{ userId = 8, name = "Ben" },
			{ userId = 9, name = "Cy" },
		},
	})
end

-- Nothing on screen overlaps ------------------------------------------------------------------------------------
-- (the mock draws nothing, so each piece's rectangle is worked out from its Position, Size and AnchorPoint on the
-- smallest canvas the screens get, 1240 x 560, the way Roblox lays them out)
do
	local Theme = Engine.require(tree.client.UI.Theme)
	local W, H = Theme.MIN_WIDTH, Theme.DESIGN.Y
	-- (a phone's "Phone" UIScale grows a piece round its anchor, and the offsets of everything inside it)
	local function rect(o)
		local p = o.Parent
		local px, py, pw, ph, ps = 0, 0, W, H, 1
		if p and not p:IsA("ScreenGui") then
			px, py, pw, ph, ps = table.unpack(rect(p))
		end
		local phone = o:FindFirstChild("Phone")
		local grow = (phone and phone:IsA("UIScale")) and phone.Scale or 1
		local ap = o.AnchorPoint or Vector2.new(0, 0)
		local w = (o.Size.X.Scale * pw + o.Size.X.Offset * ps) * grow
		local h = (o.Size.Y.Scale * ph + o.Size.Y.Offset * ps) * grow
		local x = px + o.Position.X.Scale * pw + o.Position.X.Offset * ps - ap.X * w
		local y = py + o.Position.Y.Scale * ph + o.Position.Y.Offset * ps - ap.Y * h
		return { x, y, w, h, ps * grow }
	end
	local function shown(o)
		local x = o
		while x and not x:IsA("ScreenGui") do
			if x.Visible == false then
				return false
			end
			x = x.Parent
		end
		return o.Parent ~= nil
	end
	local function hits(a, b)
		local ra, rb = rect(a), rect(b)
		return ra[1] < rb[1] + rb[3] and rb[1] < ra[1] + ra[3] and ra[2] < rb[2] + rb[4] and rb[2] < ra[2] + ra[4]
	end
	local function onScreen(o)
		local r = rect(o)
		return r[1] >= 0 and r[2] >= 0 and r[1] + r[3] <= W and r[2] + r[4] <= H
	end
	-- every pair of the pieces showing is apart, and each is on the screen
	local function apart(what, list)
		local bad = {}
		local live = {}
		for name, o in list do
			if o and shown(o) then
				table.insert(live, { name, o })
				if not onScreen(o) then
					table.insert(bad, name .. " off screen")
				end
			end
		end
		for i = 1, #live do
			for j = i + 1, #live do
				if hits(live[i][2], live[j][2]) then
					table.insert(bad, live[i][1] .. " x " .. live[j][1])
				end
			end
		end
		check(what .. ": nothing overlaps", #bad == 0, table.concat(bad, ", "))
		return #live
	end
	-- inside a card: every text and button within its card, none on another
	local function tidy(what, card)
		local bad = {}
		local kids = {}
		local cr = rect(card)
		for _, k in card:GetChildren() do
			if k:IsA("TextLabel") or k:IsA("TextButton") or (k:IsA("Frame") and k.Name == "Preview") then
				table.insert(kids, k)
				local r = rect(k)
				if r[1] < cr[1] or r[2] < cr[2] or r[1] + r[3] > cr[1] + cr[3] or r[2] + r[4] > cr[2] + cr[4] then
					table.insert(bad, (k.Text or k.Name) .. " sticks out")
				end
			end
		end
		for i = 1, #kids do
			for j = i + 1, #kids do
				if hits(kids[i], kids[j]) then
					table.insert(bad, `{kids[i].Text or kids[i].Name} x {kids[j].Text or kids[j].Name}`)
				end
			end
		end
		check(what .. ": its words and buttons don't overlap", #bad == 0, table.concat(bad, ", "))
	end
	local function fit(what, card)
		local bad = {}
		for _, k in card:GetDescendants() do
			if k:IsA("TextLabel") and k.TextScaled ~= true then
				table.insert(bad, k.Text)
			end
		end
		check(what .. ": its words shrink to fit", #bad == 0, table.concat(bad, " | "))
	end

	-- first the desktop layout (the touch buttons are hidden); the touch layout is checked after
	local Device = Engine.require(tree.client.UI.Device)
	Device.set("keyboard")
	Engine.advance(0.05)
	local t = refs.touch
	local function corners()
		return {
			Top = hud.Top,
			Invite = refs.invite,
			ShopButton = refs.shop,
			PartyButton = pref.button,
			PartyList = pref.list,
			TopButton = tref.button,
			Feed = refs.feed,
			Health = hud.Health,
			Team = refs.team,
			Bows = hud.Bows,
			Fire = t.fire,
			Jump = t.jump,
			Crouch = t.crouch,
			Sprint = t.sprint,
			Slide = t.slide,
			Swap = t.swap,
			Reload = t.reload,
			Place = t.place,
			Rotate = t.rotate,
			Toast = refs.toast,
		}
	end
	for i = 1, 5 do
		Hud.addFeed({ killerName = "SomeoneWithALongName" .. i, victimName = "AnotherLongName", weapon = "bow" })
	end
	Hud.toast("A toast that says something")

	-- the build phase: the tray, its hint, the alert, the objective
	Engine.advance(0.1)
	local L = corners()
	L.Tray = refs.tray
	L.Hint = refs.buildHint
	L.Alert = refs.alert
	L.Objective = refs.objective
	L.Fire, L.Sprint = nil, nil -- (PLACE and TURN take their places, and only once a piece is picked)
	refs.alert.Visible, refs.objective.Visible = true, true
	apart("the build phase", L)

	-- the fight: the bows, the touch buttons, the alert, respawning
	Engine.advance(Constants.BUILD_SECONDS + 0.5)
	Hud.toast("Another toast")
	Engine.advance(0.1)
	L = corners()
	L.Alert = refs.alert
	L.Objective = refs.objective
	L.Respawn = refs.respawn
	L.PartyAsk = PartyC.showInvite({ from = 900, name = "SomeoneWithALongName", kind = "invite", seconds = 20 })
	refs.alert.Visible, refs.objective.Visible, refs.respawn.Visible = true, true, true
	apart("the fight", L)
	tidy("the party card", L.PartyAsk)
	fit("the party card", L.PartyAsk)
	PartyC.answer(false)
	refs.alert.Visible, refs.respawn.Visible = false, false

	-- a win, with everything at once: a full results table, the question, three unlocks (two show, one waits), a
	-- toast
	local rows = {}
	for i = 1, 12 do
		table.insert(rows, {
			userId = i,
			name = "PlayerNumber" .. i,
			team = i % 2 == 0 and "red" or "blue",
			kills = 10,
			deaths = 3,
			assists = 2,
			built = 120,
		})
	end
	rows[11].userId = player.UserId
	Hud.showResults({
		winner = "red",
		rows = rows,
		mvp = 1,
		you = { won = true, qualified = true, step = { win = 12, name = "Long Streak II" } },
		next = { name = "Castle Clash", tagline = "Arches, columns and gate towers; balanced lanes" },
	})
	local ask = Feedback.show("like")
	for i = 1, 3 do
		Hud.showUnlock({
			step = { kind = "trail", key = "trail_" .. i, name = "Long Streak III" },
			wins = 90 + i,
			badge = 10,
		})
	end
	Hud.toast("A toast during the results")
	Engine.advance(0.1)
	local stack, waiting = Hud.popups()
	check("the popups stack, two at a time, the rest waiting", #stack == 2 and #waiting >= 1, `{#stack} {#waiting}`)
	check("the toast steps up out of the question card's way", refs.toast.Position.Y.Offset == -Hud.toastSlot())
	L = corners()
	L.Results = refs.results
	L.Ask = ask
	L.Popup1 = stack[1]
	L.Popup2 = stack[2]
	L.Countdown = refs.countdown
	check(
		"...the results show your row",
		(function()
			for _, k in refs.results:GetChildren() do
				if k:IsA("TextLabel") and k.Text:find("PlayerNumber11") then
					return true
				end
			end
			return false
		end)()
	)
	apart("a win, everything at once", L)
	tidy("the results", refs.results)
	tidy("the like card", ask)
	fit("the like card", ask)
	tidy("an unlock card", stack[1])
	tidy("the invite button", refs.invite)
	fit("the invite button", refs.invite)
	fit("an unlock card", stack[1])
	local enjoy = Feedback.show("enjoy")
	tidy("the question card", enjoy)
	fit("the question card", enjoy)
	-- a NO must say why: the reasons card, SEND only once one is ticked
	Feedback.answer(false)
	check(
		"NO opens WHAT WAS WRONG? (not sent yet)",
		Feedback.current() == "why" and enjoy:FindFirstChild("Send") ~= nil
	)
	tidy("the reasons card", enjoy)
	fit("the reasons card", enjoy)
	check(
		"...a chip for every reason",
		enjoy:FindFirstChild("Reason_hard") ~= nil and enjoy:FindFirstChild("Reason_pay") ~= nil
	)
	check("...SEND does nothing with none ticked", not Feedback.send() and Feedback.current() == "why")
	Feedback.toggle("lag")
	Feedback.toggle("controls")
	Feedback.toggle("controls")
	check("...ticked reasons show", enjoy.Reason_lag.TextColor3 ~= enjoy.Reason_hard.TextColor3 and enjoy.Send.Active)
	check("...SEND sends the NO with its reasons", Feedback.send() and Feedback.current() == nil)
	local sent = Engine.lastClientEvent("Feedback")
	check(
		"...as ('enjoy', false, { 'lag' })",
		sent
			and sent.args[2] == false
			and type(sent.args[3]) == "table"
			and sent.args[3][1] == "lag"
			and #sent.args[3] == 1,
		sent and tostring(sent.args[1])
	)
	Engine.advance(Constants.RESULTS_CARD_SECONDS + 7)
	refs.countdown.Visible = true
	L = corners()
	L.Countdown = refs.countdown
	L.Popups = Hud.popups()[1]
	apart("the countdown", L)
	check("the waiting popups come up as the first ones go", #Hud.popups() >= 1 or #select(2, Hud.popups()) == 0)

	-- The touch layout: a phone, every button showing, in each phase ------------------------------------------------
	Device.set("touch")
	local realMatch = Store.get("match")
	local realMe = Store.get("me")
	local function phaseAs(ph)
		Store.merge("match", { phase = ph })
		Engine.advance(0.05)
	end
	Store.merge("me", { weapon = "bow", alive = false })
	phaseAs("fight")
	check(
		"on a phone: FIRE, JUMP, CROUCH, RUN and SLIDE show (RELOAD only for a magazine: no weapon has one)",
		t.fire.Visible
			and t.jump.Visible
			and t.crouch.Visible
			and t.sprint.Visible
			and t.slide.Visible
			and not t.reload.Visible
	)
	check(
		"...the bows move to the bottom middle, health to the top left",
		refs.bowsFrame.AnchorPoint.X == 0.5 and refs.health.Position.Y.Scale == 0
	)
	check("...and one popup at a time", select(1, Hud.popups()) and true)
	refs.alert.Visible, refs.objective.Visible, refs.respawn.Visible = true, true, true
	Hud.toast("A toast on a phone")
	for i = 1, 3 do
		Hud.showUnlock({ step = { kind = "trail", key = "trail_" .. i, name = "Long Streak" }, wins = i })
	end
	Engine.advance(0.05)
	L = corners()
	L.Alert, L.Objective, L.Respawn, L.Popups = refs.alert, refs.objective, refs.respawn, Hud.popups()[1]
	L.PartyAsk = PartyC.showInvite({ from = 900, name = "Foe", kind = "friend", seconds = 20 })
	apart("a phone in the fight", L)
	PartyC.answer(false)
	check("...one popup showing, the rest waiting", #Hud.popups() == 1, #Hud.popups())
	refs.alert.Visible, refs.respawn.Visible = false, false
	phaseAs("build")
	BuildC.pick("wall")
	Engine.advance(0.05)
	check("on a phone building: PLACE and TURN", t.place.Visible and t.rotate.Visible and not t.fire.Visible)
	L = corners()
	L.Tray, L.Hint, L.Popups = refs.tray, refs.buildHint, Hud.popups()[1]
	apart("a phone building", L)
	BuildC.pick(nil)
	phaseAs("victory")
	Hud.showResults({ winner = "red", rows = rows, mvp = 1, you = { won = true } })
	local askT = Feedback.show("enjoy")
	Engine.advance(0.05)
	L = corners()
	L.Results, L.Ask, L.Popups = refs.results, askT, Hud.popups()[1]
	apart("a phone at the win", L)
	Feedback.answer(true)
	-- a jump on the phone's own button
	local jumped = false
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Jump = false
		phaseAs("fight")
		t.jump.Activated:Fire()
		jumped = hum.Jump == true
	end
	check("JUMP jumps", jumped)

	-- A phone (this test's screen is 844 x 390): a bigger HUD, big buttons, a wider view, aiming on FIRE ----------
	local CamC = Engine.require(tree.client.Controllers.CameraController)
	local Weapons = Engine.require(tree.shared.Data.Weapons)
	check("an 844 x 390 touch screen is a phone", Device.isPhone())
	check(
		"on a phone: the crosshair and the hotbar are bigger",
		refs.cross.Phone.Scale > 1.1 and refs.bowsFrame.Phone.Scale > 1.2 and refs.health.Phone.Scale > 1.1
	)
	Store.merge("me", { weapon = "bow", alive = true })
	Engine.advance(0.05)
	check("...SWAP shows in the fight (the TNT is yours)", t.swap.Visible, Weapons.locked("tnt", player))
	local small = {}
	for name, b in t do
		if name ~= "reload" and b.Size.X.Offset * Theme.scaleFactor() < 70 then
			table.insert(small, `{name} {b.Size.X.Offset * Theme.scaleFactor()}`)
		end
	end
	check("...every button at least 70 points across at the phone's scale", #small == 0, table.concat(small, ", "))
	t.swap.Visible = true
	L = corners()
	L.Alert, L.Objective, L.Respawn, L.Popups = refs.alert, refs.objective, refs.respawn, Hud.popups()[1]
	L.Cross, L.Charge = refs.cross, refs.charge
	refs.alert.Visible, refs.objective.Visible, refs.respawn.Visible, refs.charge.Visible = true, true, true, true
	Hud.toast("A toast on a phone")
	apart("a phone in the fight, every button showing", L)
	refs.alert.Visible, refs.respawn.Visible, refs.charge.Visible = false, false, false
	-- the view: wider on a phone, and the draw zooms in further (to the same tight aim as a monitor)
	local phoneFov = CamC.targetFov()
	Device.set("keyboard")
	local deskFov = CamC.targetFov()
	Device.set("touch")
	Engine.advance(0.05)
	check("the view is wider on a phone", phoneFov == deskFov + CamC.PHONE_FOV, `{phoneFov} vs {deskFov}`)
	-- SWAP: the next weapon (the FIRE button says what it does)
	Engine.advance(1)
	t.swap.Activated:Fire()
	Engine.advance(0.05)
	check("SWAP: the TNT", (Store.get("me") or {}).weapon == "tnt", (Store.get("me") or {}).weapon)
	check("...FIRE says THROW", t.fire.Label.Text == "THROW", t.fire.Label.Text)
	t.swap.Activated:Fire()
	Engine.advance(0.05)
	check("...and back to the bow", (Store.get("me") or {}).weapon == "bow" and t.fire.Label.Text == "SHOOT")
	-- FIRE: a thumb down draws, dragged turns the view, let go (off the button) shoots
	Engine.advance(1.5)
	local touchIn = { UserInputType = Enum.UserInputType.Touch, Position = Vector3.new(1000, 300, 0) }
	t.fire.InputBegan:Fire(touchIn)
	Engine.advance(1.6)
	check("a thumb on FIRE draws", Weapon.drawing())
	check("...and zooms in further than on a monitor", CamC.targetFov() <= phoneFov - 15, CamC.targetFov())
	local look0 = ws.CurrentCamera.CFrame.LookVector
	touchIn.Position = Vector3.new(1040, 290, 0)
	UIS.InputChanged:Fire(touchIn)
	local look1 = ws.CurrentCamera.CFrame.LookVector
	local right = look0:Cross(Vector3.new(0, 1, 0))
	local turnedBy = math.deg(math.acos(math.clamp(look0:Dot(look1), -1, 1)))
	check(
		"...dragged right, the view turns right (a fair way, not a spin)",
		(look1 - look0):Dot(right) > 0 and turnedBy > 5 and turnedBy < 20,
		turnedBy
	)
	check("...and up a little", look1.Y > look0.Y)
	local shot0 = Engine.lastClientEvent("Shoot")
	UIS.InputEnded:Fire(touchIn)
	Engine.advance(0.05)
	check(
		"...let go off the button: the arrow flies",
		not Weapon.drawing() and Engine.lastClientEvent("Shoot") ~= shot0
	)
	-- auto-run: the thumbstick pushed all the way forward runs; easing off a bit keeps it; letting go stops it
	Move.setSprint(false)
	check("auto-run: the stick pushed all the way", Move.autoRunFrom(Vector3.new(0, 0, -1)) and Move.sprinting())
	check("...still running eased off a little", Move.autoRunFrom(Vector3.new(0.1, 0, -0.7)))
	check("...stopped once let go", not Move.autoRunFrom(Vector3.new(0, 0, -0.2)) and not Move.sprinting())
	check("...not pushed sideways", not Move.autoRunFrom(Vector3.new(1, 0, 0)))
	Store.set("match", realMatch)
	Store.set("me", realMe)
	Device.set("keyboard")
	Engine.advance(0.05)
	check("back on a keyboard: the touch buttons go", not t.fire.Visible and not t.jump.Visible)

	-- The panel: the shop, the pass, the locker, the goals --------------------------------------------------------
	local Panel = Engine.require(tree.client.Controllers.PanelController)
	local Layout = Engine.require(tree.client.UI.Layout)
	local Economy = service("EconomyService")
	local Cosmetics = Engine.require(tree.shared.Data.Cosmetics)
	local pr = Panel.refs
	tidy("the shop button", refs.shop)
	fit("the shop button", refs.shop)
	UIS.InputBegan:Fire({ KeyCode = Enum.KeyCode.B, UserInputType = Enum.UserInputType.Keyboard }, false)
	Engine.advance(0.1)
	check("B opens the panel", Panel.isOpen() and pr.panel.Visible == true and Layout.panel())
	check("...with the mouse free (a Modal button)", pr.close.Modal == true)
	-- inside a container: its pieces apart and inside it (a scrolling body: inside across, any height; a track
	-- scrolling sideways: inside top to bottom, any length). A picture (Art: a gem, an X, a 3D preview) is one
	-- thing; a layer on top on purpose (Layer: the dialogs' layer, a sticker, confetti) is checked on its own.
	local function walk(what, container, depth)
		local kids = {}
		for _, k in container:GetChildren() do
			if (k:IsA("GuiObject")) and k.Visible ~= false and not k:GetAttribute("Layer") then
				table.insert(kids, k)
			end
		end
		local bad = {}
		local cr = rect(container)
		local scroll = container:IsA("ScrollingFrame")
		local sideways = scroll and container.ScrollingDirection == Enum.ScrollingDirection.X
		for i, a in kids do
			local r = rect(a)
			local inside = r[1] >= cr[1] - 0.5 and r[1] + r[3] <= cr[1] + cr[3] + 0.5
			if sideways then
				inside = r[1] >= cr[1] - 0.5 and r[2] >= cr[2] - 0.5 and r[2] + r[4] <= cr[2] + cr[4] + 0.5
			elseif not scroll then
				inside = inside and r[2] >= cr[2] - 0.5 and r[2] + r[4] <= cr[2] + cr[4] + 0.5
			else
				inside = inside and r[2] >= cr[2] - 0.5
			end
			if not inside then
				table.insert(bad, (a.Name or "?") .. " sticks out of " .. container.Name)
			end
			for j = i + 1, #kids do
				if hits(a, kids[j]) then
					table.insert(bad, a.Name .. " x " .. kids[j].Name)
				end
			end
		end
		for _, k in kids do
			-- (a preview's bars and a progress bar's fill sit on each other on purpose)
			if
				k.Name ~= "Preview"
				and k.Name ~= "Progress"
				and k.Name ~= "VipBar"
				and k.Name ~= "Bar"
				and not k:GetAttribute("Art")
				and depth < 7
			then
				for _, b in walk(what, k, depth + 1) do
					table.insert(bad, b)
				end
			end
		end
		return bad
	end
	local Season = Engine.require(tree.shared.Data.Season)
	-- a card's picture: a Preview holding a 3D model (a ViewportFrame) or vector art, both named Icon
	local function hasPicture(card)
		local pv = card:FindFirstChild("Preview", true)
		return pv ~= nil and pv:FindFirstChild("Icon", true) ~= nil
	end
	local function panelTidy(tab)
		local bad = walk(tab, pr.panel, 0)
		check(`the panel's {tab} tab: nothing overlaps, nothing sticks out`, #bad == 0, table.concat(bad, ", "))
		local unfit = {}
		for _, d in pr.panel:GetDescendants() do
			if d:IsA("TextLabel") and d.TextScaled ~= true then
				table.insert(unfit, d.Text)
			end
		end
		check(`the panel's {tab} tab: its words shrink to fit`, #unfit == 0, table.concat(unfit, " | "))
	end
	Economy:Add(player, 5000)
	service("ProgressService"):Push(player) -- (the client sees its real profile again, after the made-up one above)
	Engine.advance(0.7)
	for _, tab in { "shop", "pass", "locker", "goals" } do
		Panel.open(tab)
		Engine.advance(0.1)
		check(`the {tab} tab builds`, #pr.body:GetChildren() > 3, #pr.body:GetChildren())
		panelTidy(tab)
	end
	-- the shop: a picture on every card, Robux prices with Roblox's Robux icon, never "R$" or a "◆" glyph
	local FormatM = Engine.require(tree.shared.Format)
	Panel.open("shop")
	Engine.advance(0.1)
	check("the shop says hello", pr.body.Welcome.Hello.Text == "Pick something fun!")
	check(
		"...a FEATURED card",
		pr.body:FindFirstChild("Featured") and pr.body.Featured.Ribbon.Words.Text:find("FEATURED") ~= nil
	)
	local cards, bare = 0, {}
	for _, c in pr.body:GetChildren() do
		local n = c.Name
		if
			n:match("^Item%d$")
			or n:match("^Pack%d$")
			or n == "Featured"
			or n == "PassCard"
			or n == "TierCard"
			or n == "Starter"
		then
			cards += 1
			if not hasPicture(c) then
				table.insert(bare, n)
			end
		end
	end
	check(
		"every shop card has a picture",
		cards >= 12 and #bare == 0,
		`{cards} cards; bare: {table.concat(bare, ", ")}`
	)
	local packPics = {}
	for i = 1, 4 do
		local vf = pr.body["Pack" .. i].Preview:FindFirstChild("Icon")
		local n = 0
		for _, d in vf and vf:GetDescendants() or {} do
			if d:IsA("BasePart") then
				n += 1
			end
		end
		packPics[i] = n
	end
	check(
		"...a bigger pile of gems for a bigger pack",
		packPics[1] < packPics[2] and packPics[2] < packPics[3] and packPics[3] < packPics[4],
		table.concat(packPics, " ")
	)
	local R = FormatM.ROBUX
	check(
		"Robux prices wear the Robux icon",
		R == utf8.char(0xE002)
			and pr.body.Pack1.BuyPack.Label.Text == FormatM.robux(Shop.PACKS[1].robux)
			and pr.body.Starter.BuyStarter.Label.Text:find(R, 1, true) ~= nil
			and pr.body.PassCard.GetPass.Label.Text:find(R, 1, true) ~= nil
			and pr.body.TierCard.AddTier.Label.Text:find(R, 1, true) ~= nil
	)
	local function glyphs()
		local found = {}
		for _, d in pr.panel:GetDescendants() do
			if
				(d:IsA("TextLabel") or d:IsA("TextButton"))
				and d.Name ~= "Emblem"
				and (d.Text:find("R$", 1, true) or d.Text:find("◆", 1, true))
			then
				table.insert(found, d.Text)
			end
		end
		return found
	end
	local g = glyphs()
	check('...no "R$" and no "◆" glyph anywhere in the shop', #g == 0, table.concat(g, " | "))
	check(
		"your Shards up top: the gem, the number, a +",
		pr.shards.Price:FindFirstChild("Shard")
			and pr.shards.Price.Amount.Text == FormatM.commas(Data:Get(player).shards)
			and pr.addShards ~= nil,
		`{pr.shards.Price.Amount.Text} vs {Data:Get(player).shards} store {(Store.get("profile") or {}).shards}`
	)
	-- the pass: what it is, where you are, the track with both rows
	Panel.open("pass")
	Engine.advance(0.1)
	local pb = pr.body
	check(
		"the pass says what it is in plain words",
		pb.Intro.How.Text:find("Play matches to earn XP") ~= nil and pb.Intro.How.Text:find("Turf Pass") ~= nil
	)
	check("...and how XP comes", pb.Intro.Xp.Text:find("First match of the day") ~= nil)
	check("...the season's time left", pb.Intro.Ends.Text:find("LEFT") ~= nil)
	local tr = pb:FindFirstChild("Track")
	check(
		"...the tiers as a track you scroll across",
		tr
			and tr.ScrollingDirection == Enum.ScrollingDirection.X
			and tr:FindFirstChild("Tier1")
			and tr:FindFirstChild("Tier30")
	)
	check(
		"...a FREE row and a gold PASS row",
		pb.Rows.FreeTag.Words.Text == "FREE"
			and pb.Rows.PassTag.Words.Text == "PASS"
			and tr.Tier3:FindFirstChild("Free")
			and tr.Tier3:FindFirstChild("Prem")
	)
	local st = Store.get("profile").season
	local tierNow = Season.tierOf(st.xp)
	check(
		"...YOU ARE HERE on your tier",
		pr.here and pr.here.Parent == tr["Tier" .. tierNow] and pr.here.Words.Text == "YOU ARE HERE",
		tierNow
	)
	check(
		"...XP to the next tier in numbers",
		pb.You.XpText.Text
			== `{FormatM.commas(st.xp - tierNow * Season.XP_PER_TIER)} / {FormatM.commas(Season.XP_PER_TIER)} XP  to tier {tierNow + 1}`,
		pb.You.XpText.Text
	)
	check(
		"...GET THE PASS and +1 TIER in Robux, +1 TIER explained",
		pb.GetPass.Label.Text:find(R, 1, true)
			and pb.AddTier.Label.Text:find(R, 1, true)
			and pb.AddTier.Sub.Text == "Skip ahead one tier now"
	)
	local locked = tr.Tier3.Prem
	check(
		"...a pass reward without the pass: a lock and GET PASS",
		locked:FindFirstChild("Lock") and locked:FindFirstChild("GetPass")
	)
	-- reach tier 2: its free reward glows with CLAIM
	service("SeasonService"):AddXP(player, Season.XP_PER_TIER * 2)
	service("ProgressService"):Push(player)
	Engine.advance(0.3)
	tr = pr.body.Track
	local claim = tr.Tier2.Free:FindFirstChild("Claim")
	check(
		"a reached reward: CLAIM, glowing",
		claim and tr.Tier2.Free:FindFirstChildOfClass("UIStroke").Color == Engine.require(tree.client.UI.Icons).GOLD
	)
	check(
		"...YOU ARE HERE moves up",
		pr.here and pr.here.Parent == tr["Tier" .. Season.tierOf(Store.get("profile").season.xp)]
	)
	local before = Data:Get(player).shards
	if claim then
		claim.Activated:Fire()
		Engine.advance(0.6)
	end
	check("...CLAIM gives it", Data:Get(player).shards > before and pr.body.Track.Tier2.Free:FindFirstChild("Tick"))
	panelTidy("pass (tier 2)")
	-- every panel's close button is the one helper's X (two crossed bars in a round button), red under the mouse
	for name, x in { shop = pr.close, party = pref.close, top = tref.close } do
		local bars = x and x:FindFirstChild("Glyph")
		check(
			`the {name} panel's close button is an X`,
			x
				and x:GetAttribute("CloseButton") == true
				and bars
				and bars.Bar1.Rotation == 45
				and bars.Bar2.Rotation == -45
				and x.Text == ""
		)
		x.MouseEnter:Fire()
		check(`...red under the mouse ({name})`, x.BackgroundColor3 == Engine.require(tree.client.UI.Theme).Color.red)
		x.MouseLeave:Fire()
	end
	-- the panel among the HUD's pieces: the corners stay clear of it, the middle steps aside
	Panel.open("shop")
	Hud.showResults({ winner = "red", rows = rows, mvp = 1, you = { won = true } })
	Hud.toast("A toast while the panel is up")
	Engine.advance(0.1)
	L = corners()
	L.Panel = pr.panel
	L.Popups = Hud.popups()[1]
	apart("the panel open", L)
	check("...the results card steps aside", refs.results == nil or refs.results.Visible == false)
	check("...toasts go to the panel's own line", pr.status.Text:find("A toast while") ~= nil, pr.status.Text)
	-- the party panel: one panel at a time, its pieces apart, among the HUD's
	PartyC.open()
	Engine.advance(0.1)
	check("the party panel closes the shop panel", PartyC.isOpen() and not Panel.isOpen() and Layout.panel())
	L = corners()
	L.PartyPanel = pref.panel
	apart("the party panel open", L)
	local pbad = walk("party", pref.panel, 0)
	check("the party panel: nothing overlaps, nothing sticks out", #pbad == 0, table.concat(pbad, ", "))
	for _, box in { pref.members, pref.players } do
		pbad = walk("party", box, 0)
		check(`the party panel's {box.Name}: nothing overlaps`, #pbad == 0, table.concat(pbad, ", "))
	end
	PartyC.close()
	check("...closed, the mouse goes back", not Layout.panel())
	-- the leaderboards panel: one panel at a time, its pieces apart, among the HUD's
	tidy("the TOP button", tref.button)
	fit("the TOP button", tref.button)
	PartyC.open()
	TopC.open("kills", "server")
	Engine.advance(0.6)
	check("the leaderboards close the party panel", TopC.isOpen() and not PartyC.isOpen() and Layout.panel())
	check("...with rows from the server", #tref.list:GetChildren() >= 1, #tref.list:GetChildren())
	L = corners()
	L.TopPanel = tref.panel
	apart("the leaderboards open", L)
	local tbad = walk("top", tref.panel, 0)
	check("the leaderboards panel: nothing overlaps, nothing sticks out", #tbad == 0, table.concat(tbad, ", "))
	Panel.open("shop")
	check("...the shop panel closes it", Panel.isOpen() and not TopC.isOpen() and Layout.panel())
	Panel.close()
	TopC.open()
	TopC.close()
	check("...closed, the mouse goes back", not Layout.panel() and not Layout.modalOpen())
	Panel.open("shop")
	-- buying from the shop tab
	local p = Data:Get(player)
	local item1 = pr.body:FindFirstChild("Item1")
	local key1 = Shop.daily(Shop.dayOf(service("ShopService").now()))[1]
	local shardsBefore = p.shards
	local Format = Engine.require(tree.shared.Format)
	check(
		"the price shows the Shard gem and the number",
		item1.Buy:FindFirstChild("Price")
			and item1.Buy.Price:FindFirstChild("Shard")
			and item1.Buy.Price.Amount.Text == Format.commas(Shop.price(Cosmetics.get(key1)))
	)
	item1.Buy.Activated:Fire()
	Engine.advance(0.6)
	local cf = pr.confirm
	check(
		"a price tapped: it asks first",
		cf ~= nil and cf.Name == "Confirm" and pr.overlay.Visible and p.owned[key1] ~= true
	)
	check(
		'..."Buy NAME for" the price, YES / NO',
		cf
			and cf.Question.Text == `Buy {Cosmetics.get(key1).name} for`
			and cf.Price.Amount.Text == Format.commas(Shop.price(Cosmetics.get(key1)))
			and cf:FindFirstChild("Yes")
			and cf:FindFirstChild("No")
	)
	check("...with its picture", cf and hasPicture(cf))
	local cbad = cf and walk("confirm", cf, 0) or { "no dialog" }
	check("...the dialog: nothing overlaps, nothing sticks out", #cbad == 0, table.concat(cbad, ", "))
	cf.No.Activated:Fire()
	Engine.advance(0.6)
	check(
		"NO: nothing bought, the dialog goes",
		p.owned[key1] ~= true and p.shards == shardsBefore and not pr.overlay.Visible
	)
	pr.body.Item1.Buy.Activated:Fire()
	pr.confirm.Yes.Activated:Fire()
	Engine.advance(0.6)
	check("BUY in the shop: bought and worn", p.owned[key1] == true and p.shards < shardsBefore)
	check("...the card says so", pr.body.Item1.Buy.Label.Text == "WORN", pr.body.Item1.Buy.Label.Text)
	local cel = pr.celebrate
	check(
		"...a celebration: NEW!, its picture, confetti",
		cel ~= nil and cel:FindFirstChild("New") and cel:FindFirstChild("Confetti") and cel:FindFirstChild("Preview")
	)
	check(
		"...worn already: no EQUIP NOW",
		cel and cel:FindFirstChild("Equip") == nil and cel:FindFirstChild("Ok") ~= nil
	)
	cbad = cel and walk("celebrate", cel, 0) or { "no card" }
	check("...the card: nothing overlaps", #cbad == 0, table.concat(cbad, ", "))
	cel.Ok.Activated:Fire()
	check("...OK closes it", not pr.overlay.Visible)
	-- the bundle: bought, then EQUIP NOW (a bundle isn't worn by itself)
	local bundle = Shop.weekly(Shop.weekOf(service("ShopService").now()))
	pr.body.Featured.BuyBundle.Activated:Fire()
	check("the bundle asks first too", pr.confirm and pr.confirm.Question.Text:find("bundle") ~= nil)
	pr.confirm.Yes.Activated:Fire()
	Engine.advance(0.6)
	check("...bought", p.owned[bundle.keys[1]] == true and p.owned[bundle.keys[3]] == true)
	cel = pr.celebrate
	check("...EQUIP NOW after buying", cel and cel:FindFirstChild("Equip") and cel.Equip.Label.Text == "EQUIP NOW")
	if cel and cel:FindFirstChild("Equip") then
		cel.Equip.Activated:Fire()
		Engine.advance(0.6)
		local last = Cosmetics.get(bundle.keys[3])
		check(
			"...EQUIP NOW wears it",
			p.equipped[last.kind] == last.key and not pr.overlay.Visible,
			`{tostring(p.equipped[last.kind])} {last.key} {pr.overlay.Visible}`
		)
	end
	-- not enough Shards: how many more, and the packs
	local saved = p.shards
	p.shards = 10
	service("ProgressService"):Push(player)
	Engine.advance(0.3)
	local unowned
	for i = 1, 4 do
		local c = pr.body:FindFirstChild("Item" .. i)
		if c and c.Buy:FindFirstChild("Price") then
			unowned = c
		end
	end
	if unowned then
		unowned.Buy.Activated:Fire()
		local ne = pr.confirm
		check(
			"not enough: it says how many more",
			ne and ne.Name == "NotEnough" and ne.Question.Text:find("more Shards: get some%?") ~= nil,
			ne and ne.Question.Text
		)
		ne.GetShards.Activated:Fire()
		check(
			"...GET SHARDS goes to the packs",
			not pr.overlay.Visible and math.abs(pr.body.CanvasPosition.Y - (pr.packsY - 6)) < 1
		)
	end
	p.shards = saved
	service("ProgressService"):Push(player)
	Engine.advance(0.3)
	pr.addShards.Activated:Fire()
	check(
		"the + by your Shards goes to the packs",
		Panel.tab() == "shop" and math.abs(pr.body.CanvasPosition.Y - (pr.packsY - 6)) < 1
	)
	pr.body.CanvasPosition = Vector2.zero
	-- the locker: wear something else
	Panel.open("locker")
	Engine.advance(0.1)
	pr.body.Item1.Activated:Fire() -- (NONE: wear no trail)
	Engine.advance(0.6)
	check("the locker: wear nothing", p.equipped.trail == nil, p.equipped.trail)
	local lockedShown = false
	for _, c in pr.body:GetChildren() do
		if c:FindFirstChild("Line") and c.Line.Text:find("🔒") then
			lockedShown = true
		end
	end
	check("...what you don't have says how to get it", lockedShown)
	UIS.InputBegan:Fire({ KeyCode = Enum.KeyCode.B, UserInputType = Enum.UserInputType.Keyboard }, false)
	Engine.advance(0.1)
	check("B closes it", not Panel.isOpen() and not Layout.panel())
	check("...and the results come back", refs.results == nil or refs.results.Visible == true)
	-- looks in play
	local Looks = Engine.require(tree.client.Controllers.LooksController)
	check(
		"a kill effect plays where someone fell",
		Looks.play("shop_ink", Vector3.new(0, 3, 0), "red") and Looks.count() > 0
	)
	p.owned.shop_hologram = true
	Engine.advance(0.6)
	Engine.fireServer(player, "Settings", "equip", { kind = "skin", key = "vip_skin" })
	Engine.advance(0.6)
	check("a skin you haven't earned isn't worn", p.equipped.skin ~= "vip_skin")
	Engine.fireServer(player, "Settings", "equip", { kind = "skin", key = "shop_hologram" })
	Engine.advance(0.6)
	local vm = ws.CurrentCamera:FindFirstChild("Viewmodel")
	local grip = vm and vm:FindFirstChild("Grip")
	check(
		"your bow wears its finish",
		grip and grip.Material == Enum.Material.ForceField,
		grip and tostring(grip.Material)
	)
	_ = Cosmetics
end

-- The kill cam, the kill shatter and the sound ---------------------------------------------------------------------
do
	local KillCam = Engine.require(tree.client.Controllers.KillCamController)
	local KillFx = Engine.require(tree.client.Controllers.KillFxController)
	local Audio = Engine.require(tree.client.Controllers.AudioController)
	local CamC = Engine.require(tree.client.Controllers.CameraController)
	local Graphics = Engine.require(tree.client.Controllers.GraphicsController)
	local Explosion = Engine.require(tree.client.Controllers.ExplosionController)
	local Effects = Engine.require(tree.client.FX.Effects)
	local Device = Engine.require(tree.client.UI.Device)
	local Layout = Engine.require(tree.client.UI.Layout)
	local Bus = Engine.require(tree.client.UI.Bus)
	local cam = ws.CurrentCamera
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local here = root and root.Position or Vector3.new(0, 3, 0)
	local origin = here + Vector3.new(-60, 2, 0)
	local function kill(extra)
		local k = {
			killer = foe.UserId,
			killerName = "Foe",
			killerTeam = Teams:Team(foe),
			victim = player.UserId,
			victimTeam = team,
			weapon = "bow",
			head = true,
			kind = "arrow",
			pos = here,
			killerPos = origin - Vector3.new(0, 1.5, 0),
			dist = 60,
			cam = { origin = origin, velocity = Vector3.new(180, 6, 0), t = 60 / 180, impact = here },
		}
		for key, v in extra or {} do
			k[key] = v
		end
		return k
	end
	local mouse0, type0 = UIS.MouseBehavior, cam.CameraType
	Engine.remote("Kill"):FireAllClients(kill())
	Engine.advance(0.05)
	check("your knockout starts the kill cam", KillCam.active() and CamC.takenOver())
	check("...it has the camera", cam.CameraType == Enum.CameraType.Scriptable, tostring(cam.CameraType))
	check("...the letterbox slides in", KillCam.refs.barTop.Size.Y.Scale > 0)
	check("...the card names the killer", KillCam.refs.name.Text == "FOE", KillCam.refs.name.Text)
	check("...with the distance", KillCam.refs.info.Text:find("60 STUDS") ~= nil, KillCam.refs.info.Text)
	check("...the HUD steps aside and the arena goes muffled", Layout.inCinema() and Audio.muffled())
	check("...the mouse stays as CameraController keeps it", UIS.MouseBehavior == mouse0)
	do
		local fx = ws:FindFirstChild("Effects")
		local look = fx and fx:FindFirstChild("Lookalike")
		check(
			"...you stand there as yourself (a copy of your own character, not a mannequin)",
			look ~= nil and look:FindFirstChild("HumanoidRootPart") ~= nil and fx:FindFirstChild("Mannequin") == nil
		)
	end
	-- the flight: real speed off the bow, slower and slower right before it hits
	do
		local curve, dur = KillCam.flight(60 / 180)
		local early = KillCam.flightAt(curve, 0.1) / 0.1
		local late = (KillCam.flightAt(curve, dur) - KillCam.flightAt(curve, dur - 0.1)) / 0.1
		check("...the arrow flies near real speed first", early > 0.6, early)
		check("...then slows right down before it hits", late < early * 0.25, `{early} {late}`)
		check("...and lands at the end of the flight", math.abs(KillCam.flightAt(curve, dur) - 60 / 180) < 1e-6)
		local total = 0.2 + dur + 0.15 + 0.45 + 0.18 -- (intro, flight, freeze, card, fade)
		check("...all of it inside the respawn wait", total <= Constants.RESPAWN_SECONDS + 0.05, total)
	end
	Engine.advance(0.3)
	check("...then the arrow is replayed", KillCam.stage() == "flight" and Arrows.count() >= 1, KillCam.stage())
	Engine.advance(0.95)
	local st = KillCam.stage()
	check("...a freeze frame, then the card", st == "freeze" or st == "card", st)
	Engine.advance(2.5)
	check("not back yet: the last shot holds (no standing about dead in the floor)", KillCam.active())
	Engine.require(tree.server.Services.MatchService):Spawn(player)
	Engine.advance(0.3)
	check("respawned: it ends at once, on the new body", not CamC.takenOver() and KillCam.stage() == nil)
	Engine.advance(0.5)
	check("...and the fade is gone", not KillCam.active())
	check("...and gives the camera back", not CamC.takenOver() and cam.CameraType == Enum.CameraType.Custom)
	check("...first person again", player.CameraMode == Enum.CameraMode.LockFirstPerson)
	check("...the mouse lock as it was", UIS.MouseBehavior == mouse0, tostring(UIS.MouseBehavior))
	check(
		"...the HUD, the sound and time back",
		not Layout.inCinema() and not Audio.muffled() and Effects.timeScale == 1
	)
	_ = type0
	-- skipping: not in the first half second, then Space ends it
	local space = { KeyCode = Enum.KeyCode.Space, UserInputType = Enum.UserInputType.Keyboard }
	check("it plays again for the next knockout", KillCam.play(kill()))
	Engine.advance(0.2)
	UIS.InputBegan:Fire(space, false)
	Engine.advance(0.1)
	check(
		"...Space in the first half second doesn't skip",
		CamC.takenOver() and (KillCam.stage() == "intro" or KillCam.stage() == "flight"),
		KillCam.stage()
	)
	Engine.advance(0.4)
	UIS.InputBegan:Fire(space, false)
	Engine.advance(0.5)
	check("...after that it skips", not CamC.takenOver() and cam.CameraType == Enum.CameraType.Custom)
	Engine.advance(0.5)
	check("...and the overlay is gone", not KillCam.active() and KillCam.refs.gui.Enabled == false)
	-- a tap skips too; a blade's knockout is an orbit round the killer
	check("a blade's knockout: an orbit", KillCam.play(kill({ weapon = "blade", kind = "melee", cam = false })))
	Engine.advance(0.3)
	check("...round the killer", KillCam.stage() == "orbit", KillCam.stage())
	Engine.advance(0.4)
	UIS.InputBegan:Fire({ UserInputType = Enum.UserInputType.Touch }, false)
	Engine.advance(1)
	check("...a tap skips it", not KillCam.active() and not CamC.takenOver())
	-- never over another cinematic, never while spectating, never for a fall
	CamC.takeover(function() end)
	check("never during another cinematic (the tutorial's)", not KillCam.play(kill()))
	CamC.release()
	player:SetAttribute("Spectating", true)
	check("never while an admin spectates", not KillCam.play(kill()))
	player:SetAttribute("Spectating", nil)
	check("no kill cam without a killer", not KillCam.play(kill({ killer = false, kind = "fall" })))
	Engine.advance(0.5)

	-- the sound: the mix, your kill, the bow, the blade, a flyby, the TNT, building
	local groups = Audio.groups()
	check(
		"the mix: Master, SFX, Music, UI",
		groups.Master and groups.SFX and groups.Music and groups.UI and groups.World.Parent == groups.SFX
	)
	local n = Audio.count("kill")
	Engine.remote("Hit"):FireClient(player, { damage = 100, kill = true, victim = foe.UserId })
	Engine.advance(0.05)
	check("your kill plays the kill sound", Audio.count("kill") == n + 1)
	local layers = 0
	for _, s in Engine.game:GetService("SoundService"):GetChildren() do
		if s:IsA("Sound") and s.Name == "kill" then
			layers += 1
		end
	end
	check("...layered (a punch, a shatter, the chimes)", layers >= 5, layers)
	check("...and the arena dips under it", groups.World.Volume < Constants.SOUND_GROUPS.World)
	n = Audio.count("headshot")
	Engine.remote("Hit"):FireClient(player, { damage = 100, kill = true, head = true, victim = foe.UserId })
	Engine.advance(0.05)
	check("a headshot has its own", Audio.count("headshot") == n + 1)
	local s0 = Audio.count("streak2")
	Engine.remote("Kill")
		:FireAllClients(kill({ killer = player.UserId, victim = foe.UserId, victimTeam = Teams:Team(foe) }))
	Engine.remote("Kill")
		:FireAllClients(kill({ killer = player.UserId, victim = foe.UserId, victimTeam = Teams:Team(foe) }))
	Engine.advance(0.5)
	check("two in a row: a streak stinger", Audio.count("streak2") == s0 + 1)
	n = Audio.count("release")
	Bus.Fired:Fire("bow", 1)
	Engine.advance(0.05)
	check("letting an arrow go: the twang and whoosh", Audio.count("release") == n + 1)
	n = Audio.count("swing")
	Bus.Fired:Fire("blade", 1)
	Engine.advance(0.05)
	check("a blade swing whooshes", Audio.count("swing") == n + 1)
	n = Audio.count("place")
	Bus.Tap:Fire("build_wall")
	Engine.advance(0.05)
	check("placing a piece clunks", Audio.count("place") == n + 1)
	n = Audio.count("boom")
	Explosion.blast({ pos = here + Vector3.new(30, 0, 0), radius = 10, team = Teams:Team(foe) })
	Engine.advance(0.05)
	check("a TNT booms", Audio.count("boom") == n + 1)
	-- an enemy arrow passing close by whooshes, from where it is
	n = Audio.count("flyby")
	local eye = cam.CFrame.Position
	Engine.remote("Arrow"):FireAllClients({
		id = 987654,
		by = foe.UserId,
		team = Teams:Team(foe),
		weapon = "bow",
		origin = eye + Vector3.new(-40, 1.5, 2),
		velocity = Vector3.new(200, 0, 0),
		at = ws:GetServerTimeNow(),
	})
	Engine.advance(0.5)
	check("an arrow passing close whooshes by", Audio.count("flyby") == n + 1)
	local positional = false
	for _, d in ws.Terrain:GetChildren() do
		if d.Name == "Sfx_flyby" and d:FindFirstChildOfClass("Sound") then
			positional = true
		end
	end
	check("...from where it passed (3D)", positional)

	-- the kill shatter: capped, pooled, and lighter on a phone
	Device.set("keyboard")
	Graphics.apply("high")
	Engine.advance(3)
	local made = 0
	for i = 1, 20 do
		made += KillFx.shatter({
			pos = Vector3.new(i * 4, 5, 60),
			victim = -999,
			victimTeam = "red",
			kind = "arrow",
			cam = { velocity = Vector3.new(1, 0, 0) },
		})
	end
	check("twenty knockouts at once stay under the cap", Effects.count() <= Effects.cap().live, Effects.count())
	check("...and still burst", made > 0 and Effects.count() > 0)
	Engine.advance(3)
	check("...the pieces go back to the pool", Effects.count() == 0 and Effects.pooled() > 0, Effects.pooled())
	local big = KillFx.shatter({ pos = Vector3.new(0, 5, 60), victim = -999, victimTeam = "blue", kind = "arrow" })
	Engine.advance(3)
	Device.set("touch")
	check("a phone gets the light version", Effects.tier() == "low")
	local small = KillFx.shatter({ pos = Vector3.new(0, 5, 60), victim = -999, victimTeam = "blue", kind = "arrow" })
	check("...fewer pieces", small < big and small > 0, `{small} vs {big}`)
	Graphics.apply(nil)
	Engine.advance(3)
end

-- The premium row, the kill banners and the "killed by" card -------------------------------------------------------
do
	local Panel = Engine.require(tree.client.Controllers.PanelController)
	local KillBanner = Engine.require(tree.client.Controllers.KillBannerController)
	local ShopData = Engine.require(tree.shared.Data.Shop)
	local Economy = service("EconomyService")
	local pr = Panel.refs
	Panel.open("shop")
	Engine.advance(0.2)
	local row = pr.body:FindFirstChild("Premium")
	check("the shop has a LEGENDARY FX row", row ~= nil and row:IsA("ScrollingFrame"))
	local missing = {}
	for _, prod in ShopData.PREMIUM do
		if not (row and row:FindFirstChild("Premium_" .. prod.key)) then
			table.insert(missing, prod.key)
		end
	end
	check(
		"...a card for every Robux-only item",
		#ShopData.PREMIUM >= 10 and #missing == 0,
		`{#ShopData.PREMIUM} items, missing {table.concat(missing, " ")}`
	)
	local lightning = row and row:FindFirstChild("Premium_rbx_lightning")
	check(
		"...each with its name, a line and a Robux price",
		lightning ~= nil
			and lightning:FindFirstChild("Name").Text == "Lightning Strike"
			and lightning.Tagline.Text ~= ""
			and lightning.Buy.Label.Text:find("199") ~= nil
	)
	-- (the edges turn, the shine sweeps: the cards move while the panel's open)
	local hue = lightning and lightning:FindFirstChildOfClass("UIStroke"):FindFirstChild("Rainbow")
	local r0 = hue and hue.Rotation
	Engine.advance(0.5)
	check("...and they're alive (the rainbow edge turns)", hue ~= nil and hue.Rotation ~= r0, r0)
	-- a tap buys it: the server opens Roblox's purchase for that product
	local before = #Engine.prompted
	lightning.Buy.Activated:Fire()
	Engine.advance(0.3)
	local last = Engine.prompted[#Engine.prompted]
	check(
		"tapping its price opens the purchase for that product",
		#Engine.prompted == before + 1 and last.id == ShopData.PREMIUM_IDS.rbx_lightning,
		last and last.id
	)
	-- once it's yours: WEAR, then WORN, no price
	Economy:Give(player, "rbx_doge")
	service("ProgressService"):Push(player)
	Engine.advance(0.5)
	Panel.open("shop")
	Engine.advance(0.2)
	local doge = pr.body.Premium:FindFirstChild("Premium_rbx_doge")
	check(
		"owned: the card says WEAR, not a price",
		doge and doge.Buy.Label.Text == "WEAR",
		doge and doge.Buy.Label.Text
	)
	-- the locker: a Robux one you haven't got shows its price, and a tap buys it
	Panel.open("locker")
	Engine.advance(0.1)
	pr.body.Chip_effect.Activated:Fire()
	Engine.advance(0.1)
	local locked
	for _, c in pr.body:GetChildren() do
		if c:GetAttribute("Key") == "rbx_lightning" then
			locked = c
		end
	end
	check(
		"the locker: a Robux one shows its price, TAP TO GET",
		locked ~= nil and locked.Line.Text:find("TAP TO GET") ~= nil,
		locked and locked.Line.Text
	)
	local m = #Engine.prompted
	if locked then
		locked.Activated:Fire()
	end
	Engine.advance(0.3)
	check("...and a tap opens the purchase", #Engine.prompted == m + 1)
	Panel.close()
	Engine.advance(0.2)

	-- your knockout: the banner, with your effect's name and its funny line
	local data = service("PlayerDataService"):Get(player)
	KillBanner.onKill({ killer = player.UserId, victim = -50, victimName = "Bob", effect = "shop_chicken" })
	Engine.advance(0.05)
	local b = KillBanner.banner()
	check("a knockout of yours: a banner punches in", b ~= nil and b.Headline.Text == "ELIMINATED")
	check(
		"...with your kill effect and its funny line",
		b and b.With.Text:find("CHICKEN") ~= nil and b.With.Text:find("bawk") ~= nil,
		b and b.With.Text
	)
	check("...and sparkles fly out of it", b and #b:GetChildren() > 8)
	KillBanner.onKill({ killer = player.UserId, victim = -51, victimName = "Cal", effect = "shop_chicken", head = true })
	Engine.advance(0.05)
	check("two quick ones: DOUBLE KILL!", KillBanner.banner() and KillBanner.banner().Headline.Text == "DOUBLE KILL!")
	KillBanner.onKill({ killer = player.UserId, victim = -52, victimName = "Dee", effect = "rbx_lightning" })
	Engine.advance(0.05)
	check(
		"three: TRIPLE KILL!, the streak counted",
		KillBanner.banner() and KillBanner.banner().Headline.Text == "TRIPLE KILL!" and KillBanner.streak() == 3
	)
	Engine.advance(3)
	check("...and it goes", KillBanner.banner() == nil)
	-- knocked out by a Robux one that isn't yours: once you're up, "Killed by" with GET IT
	data.owned = data.owned or {}
	data.owned.rbx_lightning = nil
	local card = KillBanner.showOffer("rbx_lightning")
	check(
		"killed by a Robux effect: a card offers it",
		card ~= nil and card.Title.Text:find("LIGHTNING STRIKE") ~= nil and card.GetIt.Label.Text:find("199") ~= nil
	)
	local n = #Engine.prompted
	card.GetIt.Activated:Fire()
	Engine.advance(0.3)
	check(
		"...GET IT opens the purchase",
		#Engine.prompted == n + 1 and Engine.prompted[#Engine.prompted].id == ShopData.PREMIUM_IDS.rbx_lightning
	)
	-- the same effect again this session: no card (not spammy)
	KillBanner.onKill({ killer = -60, victim = player.UserId, killerName = "Eve", effect = "rbx_lightning" })
	Engine.advance(1)
	check("...only once a session", KillBanner.offer() == nil)
	-- a different one: offered once you're on your feet
	KillBanner.onKill({ killer = -61, victim = player.UserId, killerName = "Fay", effect = "rbx_bonk" })
	Engine.advance(1)
	check("...a new one is offered once you're up", KillBanner.offer() ~= nil, KillBanner.offer())
end

-- Where it came from, and the comeback shield ---------------------------------------------------------------------
do
	local HitDir = Engine.require(tree.client.Controllers.HitDirectionController)
	local ShieldC = Engine.require(tree.client.Controllers.ShieldController)
	local AudioC = Engine.require(tree.client.Controllers.AudioController)
	Engine.advance(2) -- (whatever was on screen has gone)
	local cam = ws.CurrentCamera
	local cf = cam.CFrame
	local right = Vector3.new(-cf.LookVector.Z, 0, cf.LookVector.X).Unit
	local flatLook = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z).Unit
	-- an arrow just missed you from off to your right: a near miss
	Engine.remote("Threat"):FireClient(player, { from = cf.Position + right * 40, by = 900 })
	local marks = HitDir.markers()
	local m = marks[1]
	check("a near miss: a marker on screen", #marks == 1 and m.Parent ~= nil and m.Parent.Name == "HitDirection")
	check(
		"...on the right of the ring, pointing right",
		m and m.Position.X.Scale > 0.7 and math.abs(m.Position.Y.Scale - 0.5) < 0.08 and math.abs(m.Rotation - 90) < 5,
		m and `{m.Position} {m.Rotation}`
	)
	check(
		"...drawn above the HUD, so no thumb button covers it",
		m and m.Parent.DisplayOrder > hud.DisplayOrder,
		m and m.Parent.DisplayOrder
	)
	check("...inside the screen", m and m.Position.X.Scale < 0.95 and m.Position.Y.Scale > 0.05)
	Engine.remote("Threat"):FireClient(player, { from = cf.Position + right * 40, by = 900 })
	check("the same shooter again: still one marker", #HitDir.markers() == 1)
	-- a hit from behind (the knockout too): a bigger, solid marker at the bottom
	Engine.remote("Hurt"):FireClient(player, { amount = 100, from = cf.Position - flatLook * 40, by = 901 })
	marks = HitDir.markers()
	local hit = marks[2]
	check(
		"a hit from behind: a second, bigger marker at the bottom",
		#marks == 2
			and hit:GetAttribute("Kind") == "hit"
			and hit.Position.Y.Scale > 0.75
			and hit.Size.X.Offset > m.Size.X.Offset,
		hit and `{hit.Position} {hit.Size}`
	)
	check(
		"...it points at where the shooter is, whichever way you face",
		math.abs(HitDir.angleTo(cf.Position + flatLook * 40)) < 1
			and math.abs(HitDir.angleTo(cf.Position + right * 40) - 90) < 1
	)
	Engine.advance(Constants.HIT_MARKER_SECONDS + 0.3)
	check("...gone after a moment and a half", #HitDir.markers() == 0)
	-- the comeback shield
	Engine.remote("Shield"):FireClient(player, { kind = "on", by = player.UserId, seconds = 60 })
	check(
		"your comeback shield goes up: COMEBACK SHIELD, blocks 1 hit",
		ShieldC.pop() ~= nil and ShieldC.pop().Text == "COMEBACK SHIELD" and ShieldC.pop().Sub.Text:find("1 HIT") ~= nil
	)
	local heard = AudioC.count("shield")
	Engine.remote("Shield"):FireClient(player, { kind = "break", by = player.UserId, pos = cf.Position })
	check("it breaks: a big SHIELD! pop", ShieldC.pop() ~= nil and ShieldC.pop().Text == "SHIELD!")
	check("...and its sound", AudioC.count("shield") == heard + 1)
	Engine.remote("Shield"):FireClient(player, { kind = "break", by = 900, pos = cf.Position + flatLook * 20 })
	local w = ShieldC.lastWorld()
	check("someone else's breaks: SHIELD! where they stand", w ~= nil and w.Text.Text == "SHIELD!")
	check("...heard there", AudioC.count("shield") == heard + 2)
	Engine.advance(1.5)
	check("...and the pops go", ShieldC.pop() == nil and ShieldC.lastWorld() == nil)
end

print(`\n{passed} passed, {failed} failed`)
if #Engine.errors > 0 then
	for i = 1, math.min(6, #Engine.errors) do
		print(Engine.errors[i])
	end
	print(#Engine.errors .. " script errors")
	failed += #Engine.errors
end
if failed > 0 then
	error("ClientSmoke: " .. failed .. " failures")
end
