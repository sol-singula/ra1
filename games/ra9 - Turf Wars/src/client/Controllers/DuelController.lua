--[[
The duels on screen (DuelService has the rules), in the SUPERHOT look, phone first (big buttons):

  the chip        under the top bar while you're in a pad's queue: "1v1 · 1/2 ready" (or "STARTING IN 5") and a
                  big CANCEL
  the scoreboard  in the duel, where the frontline bar was (it steps aside): RED 2 — 1 BLUE, the round, FIRST TO 5;
                  the clock is the phase pill's (FIGHT 2:41: the HUD's own, from a fight snapshot in the Store)
  the banners     ROUND 3, RED WINS THE ROUND: the HUD's big alerts (the server sends them)
  the result      VICTORY / DEFEAT / DRAW, the score, your Shards (+20 ◆ DUEL flies in on its own), REMATCH and
                  BACK TO LOBBY

Net "Duel" from the server: queue / start / round / roundEnd / result / rematch / end (DuelService's header).
To the server: Net "Duel" ("cancel") | ("rematch") | ("leave").

  DuelController.state()   { queue?, duel?, result? } (tests)
  DuelController.refs      the pieces on screen
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)
local Layout = require(script.Parent.Parent.UI.Layout)
local HudController = require(script.Parent.HudController)

local DuelController = { Name = "DuelController", Order = 45 }

local C = Theme.Color
local RED, BLUE = Constants.TEAM_COLOR.red, Constants.TEAM_COLOR.blue
local player = Players.LocalPlayer
local refs = {}
DuelController.refs = refs
local state = {} -- queue = { size, n, of, seconds }, duel = { id, size, side, score, round, ... }, result = { ... }
local savedMatch -- (the Store's match before the duel: the lobby's, put back after)
local hidBar -- (whether the frontline bar was showing before the duel hid it)

function DuelController.state()
	return state
end

local function sideName(side)
	return Constants.DUEL_SIDE_NAME[side] or string.upper(tostring(side))
end

-- The chip ---------------------------------------------------------------------------------------------------
local function buildChip(gui)
	local chip = Theme.slab({
		Name = "DuelQueue",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 96),
		Size = UDim2.fromOffset(380, 52),
		Visible = false,
		Parent = gui,
	})
	refs.chip = chip
	refs.chipText = Theme.title({
		Name = "Text",
		Text = "",
		Position = UDim2.fromOffset(14, 6),
		Size = UDim2.new(1, -160, 1, -12),
		TextXAlignment = Enum.TextXAlignment.Left,
		fit = 22,
		Parent = chip,
	})
	refs.cancel = Theme.button({
		Name = "Cancel",
		Text = "CANCEL",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(130, 40),
		BackgroundColor3 = C.ketchup,
		Parent = chip,
	})
	refs.cancel.Activated:Connect(function()
		Net.send("Duel", "cancel")
	end)
end

local function paintChip()
	local q = state.queue
	if not refs.chip then
		return
	end
	refs.chip.Visible = q ~= nil and not Layout.panel()
	if q then
		if q.seconds then
			refs.chipText.Text = `{q.size}v{q.size} · STARTING IN {math.max(0, math.ceil(q.seconds))}`
		else
			refs.chipText.Text = `{q.size}v{q.size} · {q.n}/{q.of} ready`
		end
	end
end

-- The scoreboard ------------------------------------------------------------------------------------------------
local function buildBoard(gui)
	local board = Theme.slab({
		Name = "DuelBoard",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 46),
		Size = UDim2.fromOffset(420, 40),
		Visible = false,
		Parent = gui,
	})
	refs.board = board
	refs.redScore = Theme.title({
		Name = "Red",
		Text = "RED 0",
		Position = UDim2.fromOffset(12, 4),
		Size = UDim2.fromOffset(120, 32),
		TextColor3 = RED,
		TextXAlignment = Enum.TextXAlignment.Left,
		fit = 24,
		Parent = board,
	})
	refs.blueScore = Theme.title({
		Name = "Blue",
		Text = "0 BLUE",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 4),
		Size = UDim2.fromOffset(120, 32),
		TextColor3 = BLUE,
		TextXAlignment = Enum.TextXAlignment.Right,
		fit = 24,
		Parent = board,
	})
	refs.roundText = Theme.title({
		Name = "Round",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 4),
		Size = UDim2.fromOffset(150, 32),
		TextXAlignment = Enum.TextXAlignment.Center,
		fit = 18,
		Parent = board,
	})
end

local function paintBoard()
	local d = state.duel
	if not refs.board then
		return
	end
	refs.board.Visible = d ~= nil and state.result == nil and not Layout.panel()
	-- (the frontline bar steps aside for the duel: a duel has no line; and only ours is put back after)
	local bar = HudController.refs.bar
	if bar and d and not hidBar then
		hidBar = bar.Visible
		bar.Visible = false
	elseif bar and not d and hidBar ~= nil then
		bar.Visible = hidBar
		hidBar = nil
	end
	if d then
		refs.redScore.Text = `RED {d.score.red or 0}`
		refs.blueScore.Text = `{d.score.blue or 0} BLUE`
		refs.roundText.Text = d.round and `ROUND {d.round} · FIRST TO {d.rounds}` or `FIRST TO {d.rounds}`
	end
end

-- The result card --------------------------------------------------------------------------------------------------
local function closeResult()
	if refs.result then
		refs.result:Destroy()
		refs.result = nil
	end
	state.result = nil
	paintBoard()
end

local function showResult(r)
	closeResult()
	state.result = r
	local gui = refs.gui
	local won, draw = r.won == true, r.draw == true
	local color = draw and C.ink or (won and C.good or C.ketchup)
	local card = Theme.card({
		Name = "DuelResult",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(420, 250),
		Parent = gui,
	})
	refs.result = card
	Layout.modal("duel", card)
	Theme.cardHeader(card, draw and "DRAW" or (won and "VICTORY" or "DEFEAT"), 56, color, 30)
	local mine = r.score and (player:GetAttribute("DuelSide") or "red")
	local theirs = mine == "red" and "blue" or "red"
	Theme.title({
		Name = "Score",
		Text = r.score and `{sideName(mine)} {r.score[mine] or 0}  —  {r.score[theirs] or 0} {sideName(theirs)}`
			or "",
		Position = UDim2.fromOffset(16, 66),
		Size = UDim2.new(1, -32, 0, 34),
		TextColor3 = C.ink,
		outline = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		fit = 26,
		Parent = card,
	})
	local line = r.forfeit and "You left the duel: a loss."
		or (won and `+{r.shards or 0} ◆ for the win · {r.kills or 0} knockouts` or `{r.kills or 0} knockouts`)
	Theme.text({
		Name = "Line",
		Text = line,
		Position = UDim2.fromOffset(16, 104),
		Size = UDim2.new(1, -32, 0, 24),
		TextColor3 = C.muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		fit = 16,
		Parent = card,
	})
	refs.rematchText = Theme.text({
		Name = "Rematch",
		Text = "",
		Position = UDim2.fromOffset(16, 128),
		Size = UDim2.new(1, -32, 0, 20),
		TextColor3 = C.muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		fit = 14,
		Parent = card,
	})
	refs.rematch = Theme.button({
		Name = "RematchButton",
		Text = "REMATCH",
		Position = UDim2.fromOffset(16, 160),
		Size = UDim2.new(0.5, -24, 0, 70),
		BackgroundColor3 = C.mustard,
		Parent = card,
	})
	refs.rematch.Visible = not r.forfeit
	refs.rematch.Activated:Connect(function()
		if Theme.busy(refs.rematch, 1) then
			Net.send("Duel", "rematch")
		end
	end)
	refs.back = Theme.button({
		Name = "BackButton",
		Text = "BACK TO LOBBY",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 160),
		Size = UDim2.new(0.5, -24, 0, 70),
		BackgroundColor3 = C.white,
		dark = true,
		Parent = card,
	})
	refs.back.Activated:Connect(function()
		Net.send("Duel", "leave")
		closeResult()
	end)
	refs.back.Modal = true -- (frees the mouse from first person for the card)
	Theme.pop(card)
	paintBoard()
end

-- The duel's start and end: the HUD plays a fight (the clock, the touch controls) from a snapshot of its own
local function begin(d)
	state.duel = {
		id = d.id,
		size = d.size,
		side = d.side,
		map = d.map,
		rounds = d.rounds or Constants.DUEL_ROUNDS,
		score = { red = 0, blue = 0 },
		round = nil,
		sides = d.sides,
	}
	state.queue = nil
	savedMatch = Store.get("match")
	Store.set("match", {
		phase = "fight",
		ends = d.endsAt,
		map = d.map,
		mapName = d.mapName,
		frontline = 0,
		loseRed = -80,
		loseBlue = 80,
		red = d.size,
		blue = d.size,
		matchId = d.id,
		duel = true,
	})
	paintChip()
	paintBoard()
end

local function finish()
	closeResult()
	state.duel = nil
	if savedMatch then
		Store.set("match", savedMatch)
		savedMatch = nil
	else
		Store.set("match", { phase = "lobby", frontline = 0, loseRed = -80, loseBlue = 80 })
	end
	paintBoard()
end

function DuelController:init()
	local gui = Theme.screen("Duel", 7, player:WaitForChild("PlayerGui"))
	refs.gui = gui
	buildChip(gui)
	buildBoard(gui)
	Net.listen("Duel", function(m)
		if type(m) ~= "table" then
			return
		end
		if m.kind == "queue" then
			state.queue = (not m.off) and { size = m.size, n = m.n, of = m.of, seconds = m.seconds } or nil
			paintChip()
		elseif m.kind == "start" then
			begin(m)
		elseif m.kind == "round" and state.duel then
			state.duel.round = m.n
			state.duel.score = m.score or state.duel.score
			paintBoard()
		elseif m.kind == "roundEnd" and state.duel then
			state.duel.score = m.score or state.duel.score
			paintBoard()
		elseif m.kind == "result" then
			showResult(m)
		elseif m.kind == "rematch" and refs.rematchText then
			refs.rematchText.Text = `REMATCH: {m.n or 0}/{m.of or 0} ready`
		elseif m.kind == "end" then
			finish()
		end
	end)
	Layout.onPanel(function()
		paintChip()
		paintBoard()
	end)
	-- (the chip's countdown ticks on its own between the server's words)
	task.spawn(function()
		while true do
			task.wait(0.5)
			local q = state.queue
			if q and q.seconds then
				q.seconds = math.max(0, q.seconds - 0.5)
				paintChip()
			end
		end
	end)
end

return DuelController
