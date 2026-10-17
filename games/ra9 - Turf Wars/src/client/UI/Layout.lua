-- Who has the screen. A popup card that asks the player something (Do you like the game? A full server?) is modal:
-- while one is up, the guide's NEXT card steps aside, and the passing messages (alerts, callouts) come as toasts on
-- the bottom row instead, so nothing ever lands on top of the question.
--
--   Layout.modal(name, card)   a card is on screen (it counts until it leaves the screen or is hidden)
--   Layout.modalOpen()         true while any is
local Layout = {}

local open = {} -- [name] = the card

function Layout.modal(name, card)
	open[name] = card
end

function Layout.modalOpen()
	for name, card in open do
		if not card.Parent then
			open[name] = nil
		elseif card.Visible ~= false then
			return true -- (a hidden one doesn't count: a closed panel, a question waiting behind it)
		end
	end
	return false
end

-- The big panel (shop, pass, locker, goals): while it's open the HUD's middle steps aside (the results, the
-- countdown, alerts, the build tray), a question card waits, and toasts go to the panel's own message line.
--
--   Layout.setPanel(open)      Layout.panel() -> open      Layout.onPanel(fn(open))
--   Layout.statusSink = fn(text, kind)   (the panel's message line, while it's open)
local panelOpen = false
local panelWatchers = {}

function Layout.setPanel(isOpen)
	isOpen = isOpen == true
	if isOpen == panelOpen then
		return
	end
	panelOpen = isOpen
	for _, fn in panelWatchers do
		task.spawn(fn, isOpen)
	end
end

function Layout.panel()
	return panelOpen
end

function Layout.onPanel(fn)
	table.insert(panelWatchers, fn)
end

Layout.statusSink = nil

-- One big panel at a time (the shop's, the admin's): Layout.claimPanel(name, close) closes the other one first.
local owner
function Layout.claimPanel(name, close)
	if owner and owner.name ~= name then
		pcall(owner.close)
	end
	owner = { name = name, close = close }
end

return Layout
