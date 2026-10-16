-- Who has the screen. A popup card that asks the player something (Do you like the game? A full server?) is modal:
-- while one is up, the guide's NEXT card steps aside, and the passing messages (alerts, callouts) come as toasts on
-- the bottom row instead, so nothing ever lands on top of the question.
--
--   Layout.modal(name, card)   a card is on screen (it counts until it leaves the screen)
--   Layout.modalOpen()         true while any is
local Layout = {}

local open = {} -- [name] = the card

function Layout.modal(name, card)
	open[name] = card
end

function Layout.modalOpen()
	for name, card in open do
		if card.Parent then
			return true
		end
		open[name] = nil
	end
	return false
end

return Layout
