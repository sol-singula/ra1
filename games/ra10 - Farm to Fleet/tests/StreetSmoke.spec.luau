--[[
Phase G2 on the mock engine, server and client together: watching each other (master plan §13.4). The STREET
gantry over the road ranks the farms live (Cash a minute from what they ship, not gifts), the street's biggest
shipment of the day along its bottom; a billboard over each gate; likes (one a day a farm, never your own; the most
liked gets a tag); VISIT to a neighbour's gate and HOME; the FRIENDS panel (a friend here: VISIT; on another
server: their saved summary and JOIN); the Hall of Fame (OrderedDataStores, the gantry and the panel).

  luaurun tests/StreetSmoke.spec.luau
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
Engine.clientEnabled = true
Engine.workspace.CurrentCamera.ViewportSize = Vector2.new(1240, 560)
Engine.runScript(tree.server.Main)
Engine.advance(0.5)

local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Data = service("PlayerDataService")
local Economy = service("EconomyService")
local Street = service("StreetService")
local Boards = service("LeaderboardService")
local Plots = service("PlotService")
local Special = service("SpecialService")
local Constants = Engine.require(tree.shared.Constants)
local PlotLayout = Engine.require(tree.shared.World.PlotLayout)
Special.FIRST = 1e9
Special.DAILY = false

local ava = Engine.addPlayer("Ava", 901)
Engine.Players.LocalPlayer = ava
Engine.localPlayer = ava
Engine.runScript(tree.client.Main)
Engine.advance(1.5)
local ben = Engine.addPlayer("Ben", 902)
Engine.advance(1.5)
local a, b = Data:Get(ava), Data:Get(ben)
local StreetC = Engine.require(tree.client.Controllers.StreetController)
local Bus = Engine.require(tree.client.UI.Bus)

-- The board ---------------------------------------------------------------------------------------------------------
local board = Street.board
check("the STREET gantry stands over the road", board and #board.faces == 2 and board.faces[1].Position.Y > 25)
check(
	"...between the plots",
	math.abs(board.faces[1].Position.X + (PlotLayout.WIDTH + PlotLayout.GAP) / 2) < 2,
	board.faces[1].Position.X
)
Economy:Add(ben, 6000, "order")
Economy:Add(ben, 4000, "pallets")
Economy:Add(ava, 900, "sell")
Economy:Add(ava, 50000, "calendar") -- (a gift: not shipped)
Engine.advance(Street.TICK + 0.5)
local sb, sa = Street:Stats(ben), Street:Stats(ava)
check("Cash a minute from what they ship", sb.cashMin == 10000 and sa.cashMin == 900, `{sb.cashMin} {sa.cashMin}`)
check("...deliveries a minute", sb.delivMin == 2 and sa.delivMin == 1, sb.delivMin)
check("...the best shipment today", sb.best == 6000 and b.street.best == 6000)
local face = board.faces[1].Board
check("the board ranks them: Ben first", face.Row1_2.Text:find("Ben") ~= nil, face.Row1_2.Text)
check("...Ava second", face.Row2_2.Text:find("Ava") ~= nil)
check("...a face toward each end", board.faces[2].Board.Row1_2.Text == face.Row1_2.Text)
check("...the street's biggest today along the bottom", face.Footer.Text:find("Ben") ~= nil, face.Footer.Text)
local anchorB = Plots:World().plots[ben:GetAttribute("Plot")].folder.StreetAnchor
check("a billboard over Ben's gate", anchorB.Street.Enabled and anchorB.Street.Owner.Text:find("Ben") ~= nil)
check("...his numbers on it", anchorB.Street.Line1.Text:find("10K") ~= nil, anchorB.Street.Line1.Text)
local empty = Plots:World().plots[3].folder.StreetAnchor
check("...none over an empty plot", not empty:FindFirstChild("Street") or not empty.Street.Enabled)
Engine.advance(Constants.STREET_WINDOW + Street.TICK + 1)
check("the minute numbers fade after the window", Street:Stats(ben).cashMin == 0)

-- Likes --------------------------------------------------------------------------------------------------------------
local benPlot = ben:GetAttribute("Plot")
local avaPlot = ava:GetAttribute("Plot")
Engine.fireServer(ava, "Street", "like", benPlot)
Engine.advance(0.5)
check("Ava likes Ben's farm", b.street.likes == 1)
Engine.fireServer(ava, "Street", "like", benPlot)
Engine.advance(0.5)
check("...once a day", b.street.likes == 1)
Engine.fireServer(ava, "Street", "like", avaPlot)
Engine.advance(0.5)
check("...never your own", a.street.likes == 0)
check("the most liked gets a tag", anchorB.Street.Tag.Text:find("MOST LIKED") ~= nil, anchorB.Street.Tag.Text)
a.street.liked[tostring(ben.UserId)] -= 1
check("...a new day, a new like", Street:Like(ava, benPlot) and b.street.likes == 2)

-- The panel ----------------------------------------------------------------------------------------------------------
Bus.Panel:Fire("street")
Engine.advance(0.5)
local rows = StreetC.refs.rows
check("the STREET panel lists both", rows[1].frame.Visible and rows[2].frame.Visible and not rows[3].frame.Visible)
local mine
for _, r in rows do
	if r.data and r.data.index == avaPlot then
		mine = r
	end
end
check("...yours marked, no LIKE on it", mine and mine.name.Text:find("you") and not mine.like.Visible)
check("...the likes", rows[1].likes.Text:find("2") ~= nil or rows[2].likes.Text:find("2") ~= nil)

-- Visiting -----------------------------------------------------------------------------------------------------------
local gate = PlotLayout.toWorld(benPlot, 0, -104, 3)
for _, r in rows do
	if r.data and r.data.index == benPlot then
		r.visit.Activated:Fire()
	end
end
Engine.advance(0.5)
local root = ava.Character.HumanoidRootPart
check("VISIT: at Ben's gate", (root.Position - gate).Magnitude < 1, (root.Position - gate).Magnitude)
check("...the panel closes", not StreetC.refs.panel.card.Visible)
Engine.fireServer(ava, "Street", "home")
Engine.advance(0.5)
local home = PlotLayout.toWorld(avaPlot, PlotLayout.SPOTS.spawn.X, PlotLayout.SPOTS.spawn.Z, 3)
check("HOME: back at your own", (root.Position - home).Magnitude < 1)
check("no visit to an empty plot", not Street:Visit(ava, 3) and not Street:Visit(ava, 99))

-- Friends ------------------------------------------------------------------------------------------------------------
Engine.makeFriends(ava, ben)
Engine.friends["901:555"] = true
Engine.dataStores[Constants.SUMMARY_STORE] = Engine.dataStores[Constants.SUMMARY_STORE] or {}
local summaries = Engine.game:GetService("DataStoreService"):GetDataStore(Constants.SUMMARY_STORE)
summaries:SetAsync("555", { name = "Cleo", level = 24, stage = 4, size = 900, cashMin = 4200, franchise = 1 })
Engine.friendsOnline = {
	{ VisitorId = 902, DisplayName = "Ben", PlaceId = Engine.game.PlaceId },
	{ VisitorId = 555, DisplayName = "Cleo", PlaceId = Engine.game.PlaceId },
	{ VisitorId = 777, DisplayName = "Dan", PlaceId = 12345 }, -- (in another game)
}
Engine.friendPlaces[555] = { Engine.game.PlaceId, "job-cleo" }
Bus.Panel:Fire("friends")
Engine.advance(1)
local fr = StreetC.refs.friendRows
check("FRIENDS: the two in this game", fr[1].frame.Visible and fr[2].frame.Visible and not fr[3].frame.Visible)
local cleo, benRow
for _, r in fr do
	if r.data and r.data.userId == 555 then
		cleo = r
	elseif r.data and r.data.userId == 902 then
		benRow = r
	end
end
check("...Cleo's farm from her summary", cleo and cleo.info.Text:find("900") and cleo.name.Text:find("★1"))
check("...JOIN for her, VISIT for Ben (he's here)", cleo.join.Text == "JOIN" and benRow.join.Text == "VISIT")
cleo.join.Activated:Fire()
Engine.advance(0.5)
local tp = Engine.teleports[#Engine.teleports]
check("JOIN: off to her server", tp and tp.options.ServerInstanceId == "job-cleo")
local n = #Engine.teleports
check("no join for a stranger", not Street:Join(ava, 31337) and #Engine.teleports == n)

-- The Hall of Fame ---------------------------------------------------------------------------------------------------
b.stats.biggestShipment = 6000
b.owned.tractor = 1 -- (something built: an Operation Size)
b.stats.earned += 1
Boards:Write(ben)
local inAll = true
for _, key in { "earned", "best", "size" } do
	local st = Engine.orderedStores[string.format(Constants.LEADERBOARD_STORE, key)]
	inAll = inAll and st ~= nil and (st["902"] or 0) > 0
end
check(
	"Ben's records go to the boards",
	inAll,
	(function()
		local out = {}
		for name, st in Engine.orderedStores do
			table.insert(out, name .. "=" .. tostring(st["902"]))
		end
		return table.concat(out, " ")
	end)()
)
check("...only when they grow", #Boards:Write(ben) == 0)
local store = Engine.orderedStores[string.format(Constants.LEADERBOARD_STORE, "earned")]
check("...the OrderedDataStore holds it", store and store["902"] == math.floor(b.stats.earned))
store["4242"] = 1e12 -- (a farm on another server)
Boards:Refresh()
Boards.page = 1
Boards:Paint()
local top = Boards:Top("earned")
check("the top: every server", top[1].userId == 4242 and top[1].name == "User4242")
check("...this server's farms in it", top[2] and (top[2].userId == 902 or top[2].userId == 901))
check(
	"the HALL OF FAME gantry shows it",
	Street.hall.faces[1].Board.Title.Text:find("HALL OF FAME") and Street.hall.faces[1].Board.Row1_2.Text == "User4242"
)
Engine.advance(Street.TICK + 0.5)
check("...and the STREET panel", StreetC.refs.hall.earned.Text:find("User4242") ~= nil, StreetC.refs.hall.earned.Text)

-- Leaving --------------------------------------------------------------------------------------------------------------
Engine.removePlayer(ben)
Engine.advance(1)
local s = Engine.dataStores[Constants.SUMMARY_STORE] and summaries:GetAsync("902")
check(
	"leaving saves the summary friends read",
	type(s) == "table" and s.name == "Ben" and s.size > 0,
	type(s) == "table" and s.size or tostring(s)
)
Engine.advance(Street.TICK + 0.5)
check("...the board drops him", not face.Row2_2.Text:find("Ben") and face.Row1_2.Text:find("Ava") ~= nil)

local bad = {}
for _, w in Engine.warnings do
	if tostring(w):find("failed") then
		table.insert(bad, tostring(w))
	end
end
check("no failed saves or ticks", #bad == 0, bad[1])
if #Engine.errors > 0 then
	for _, e in Engine.errors do
		print("ERROR " .. tostring(e))
	end
	failed += #Engine.errors
end
print(`StreetSmoke: {passed} passed, {failed} failed`)
if failed > 0 then
	error(`{failed} failed`)
end
