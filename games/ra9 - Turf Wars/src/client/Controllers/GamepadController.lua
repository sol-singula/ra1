--[[
Everything a gamepad needs that the other controllers don't bind themselves (they already do: R2 draws and lets go
or places, X reloads, Y turns a piece, L3 runs, B crouches, A jumps, the right stick looks):

  L1 / R1, D-pad left / right   the bow before / after (the fight), the piece before / after (the build phase)
  D-pad down                    (the build phase) put the piece away
  Select (the View button)      the shop panel, open / close (not while the tutorial runs: there it skips)
  B                             with the panel open: close it
  A / B                         during a kill cam: skip it
  in a menu or a card           the D-pad moves between its buttons: the first one is picked for you when it opens
                                (the shop panel, the feedback card, the HOOK COMPLETE card), A presses it

A small hint over the hotbar shows the buttons while the last input was a gamepad (LB ◀ ▶ RB · SELECT SHOP).

  GamepadController.press(keyCode)   what a button does (tests call it; the input listener does too)
  GamepadController.hint()           the hint label
]]
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local GamepadController = { Name = "GamepadController", Order = 95 }

local player = Players.LocalPlayer
local C = Theme.Color
local refs = {}
GamepadController.refs = refs

local K = Enum.KeyCode

local function lazy(name)
	local ok, mod = pcall(require, script.Parent[name])
	return ok and mod or nil
end

local function firstButton(root)
	if not root then
		return nil
	end
	local best, bestAt
	for _, d in root:GetDescendants() do
		if d:IsA("GuiButton") and d.Visible ~= false then
			-- (the top-left-most one: reading order)
			local ok, at = pcall(function()
				return d.AbsolutePosition
			end)
			at = (ok and typeof(at) == "Vector2") and at or Vector2.new(0, 0)
			if not best or at.Y < bestAt.Y - 4 or (math.abs(at.Y - bestAt.Y) <= 4 and at.X < bestAt.X) then
				best, bestAt = d, at
			end
		end
	end
	return best
end

local function pickFirst(root)
	local b = firstButton(root)
	if b then
		pcall(function()
			GuiService.SelectedObject = b
		end)
	end
	return b
end

local function panel()
	local Panel = lazy("PanelController")
	return Panel, Panel and Panel.refs and Panel.refs.panel
end

local function tutorialRunning()
	local Tut = lazy("TutorialController")
	local ok, st = pcall(function()
		return Tut and Tut.state()
	end)
	return ok and type(st) == "table" and (st.running or st.intro or st.cinema) and true or false
end

function GamepadController.press(key)
	local phase = Store.phase()
	local Kill = lazy("KillCamController")
	if Kill and Kill.active and Kill.active() and (key == K.ButtonA or key == K.ButtonB) then
		pcall(Kill.skip)
		return "skip"
	end
	local Panel, root = panel()
	local open = Panel and Panel.isOpen and Panel.isOpen()
	if key == K.ButtonSelect then
		if tutorialRunning() then
			return nil -- (the tutorial's own: skip)
		end
		if Panel then
			Panel.toggle("shop")
			if Panel.isOpen() then
				pickFirst(root)
				return "open"
			end
			pcall(function()
				GuiService.SelectedObject = nil
			end)
			return "close"
		end
		return nil
	end
	if open then
		if key == K.ButtonB then
			Panel.close()
			pcall(function()
				GuiService.SelectedObject = nil
			end)
			return "close"
		end
		return nil -- (in the menu the D-pad moves the selection: Roblox does that)
	end
	local step = (key == K.ButtonL1 or key == K.DPadLeft) and -1
		or (key == K.ButtonR1 or key == K.DPadRight) and 1
		or nil
	if step then
		if phase == "build" then
			local Build = lazy("BuildController")
			if Build then
				Build.cycle(step)
				return "piece"
			end
		else
			local Weapon = lazy("WeaponController")
			if Weapon then
				Weapon.cycle(step)
				return "weapon"
			end
		end
	end
	if key == K.DPadDown and phase == "build" then
		local Build = lazy("BuildController")
		if Build and Build.picked() then
			Build.pick(Build.picked()) -- (picking the same one again puts it away)
			return "away"
		end
	end
	return nil
end

function GamepadController.hint()
	return refs.hint
end

-- A card that's just come up (feedback, HOOK COMPLETE): its first button picked, so A answers it
local function watchCards()
	if Theme.inputKind() ~= "gamepad" then
		return
	end
	local selected = GuiService.SelectedObject
	if selected and selected.Parent and selected.Visible ~= false then
		return
	end
	local Feedback = lazy("FeedbackController")
	if Feedback and Feedback.current then
		local ok, kind, fcard = pcall(Feedback.current)
		if ok and kind and fcard and fcard.Visible then
			pickFirst(fcard)
			return
		end
	end
	local Hook = lazy("HookController")
	local done = Hook and Hook.refs and Hook.refs.complete
	if done and done.Parent then
		pickFirst(done)
		return
	end
	local Panel, root = panel()
	if Panel and Panel.isOpen and Panel.isOpen() then
		pickFirst(root)
	end
end

function GamepadController:init()
	local screen = Theme.screen("Gamepad", 12, player:WaitForChild("PlayerGui"))
	refs.hint = Theme.text({
		Name = "PadHint",
		Text = "LB ◀  ▶ RB   ·   SELECT  SHOP",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -100),
		Size = UDim2.fromOffset(260, 18),
		TextSize = 12,
		Font = Theme.Display,
		TextColor3 = C.ink,
		TextXAlignment = Enum.TextXAlignment.Right,
		Visible = false,
		Parent = screen,
	})
	UserInputService.InputBegan:Connect(function(input, processed)
		local t = input.UserInputType
		if t.Name:sub(1, 7) ~= "Gamepad" then
			return
		end
		-- (A and B are taken by a selected button in a menu; everything else isn't)
		if processed and input.KeyCode ~= K.ButtonSelect and input.KeyCode ~= K.ButtonB then
			return
		end
		GamepadController.press(input.KeyCode)
	end)
	local last = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - last < 0.25 then
			return
		end
		last = now
		local pad = Theme.inputKind() == "gamepad"
		local phase = Store.phase()
		refs.hint.Visible = pad and (phase == "build" or phase == "fight")
		refs.hint.Text = phase == "build" and "LB ◀  ▶ RB  PIECE   ·   ▼ PUT AWAY   ·   SELECT  SHOP"
			or "LB ◀  ▶ RB  WEAPON   ·   SELECT  SHOP"
		watchCards()
	end)
end

return GamepadController
