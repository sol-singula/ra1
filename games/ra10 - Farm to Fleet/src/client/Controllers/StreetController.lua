--[[
The STREET and FRIENDS panels (Net "Street", StreetService; master plan §13.4).

  STREET    every farm on this server ranked live (Size, Cash/min, deliveries/min, the best shipment today, likes),
            VISIT to stand at its gate, LIKE once a day, HOME to go back; the Hall of Fame's top three of each
            board along the bottom
  FRIENDS   your friends online in Farm to Fleet (GetFriendsOnline, here on the client) with their farm's numbers
            from their saved summary; VISIT if they're on this street, JOIN to go to theirs

  StreetController.refs   the panels' pieces (tests)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Bus = require(script.Parent.Parent.UI.Bus)
local Panel = require(script.Parent.Parent.UI.Panel)
local Theme = require(script.Parent.Parent.UI.Theme)

local StreetController = { Name = "StreetController", Order = 49 }

local C = Theme.Color
local player = Players.LocalPlayer
local refs = { rows = {}, friendRows = {}, hall = {} }
StreetController.refs = refs
local BLUE = Color3.fromRGB(70, 150, 230)
local PURPLE = Color3.fromRGB(150, 100, 220)
local ROW = 40
local last = { rows = {} }

local function cell(parent, name, x, w, align)
	return Theme.text({
		Name = name,
		Text = "",
		Position = UDim2.new(x, 4, 0, 4),
		Size = UDim2.new(w, -8, 1, -8),
		TextXAlignment = align or Enum.TextXAlignment.Left,
		fit = 16,
		Parent = parent,
	})
end

local function smallButton(parent, name, text, x, color, fn)
	local b = Theme.button({
		Name = name,
		Text = text,
		BackgroundColor3 = color,
		Position = UDim2.new(x, 0, 0, 4),
		Size = UDim2.new(0.11, -4, 1, -8),
		Parent = parent,
	})
	b.Activated:Connect(fn)
	return b
end

local function paintStreet()
	local myPlot = player:GetAttribute("Plot")
	for i, row in refs.rows do
		local r = last.rows[i]
		row.frame.Visible = r ~= nil
		if r then
			row.data = r
			row.rank.Text = `#{r.rank}`
			row.name.Text = (r.franchise and r.franchise > 0 and `★{r.franchise} ` or "")
				.. r.name
				.. (r.index == myPlot and " (you)" or "")
				.. (r.mostLiked and " ❤" or "")
			row.size.Text = Format.num(r.size or 0)
			row.cash.Text = Format.num(r.cashMin or 0) .. "/min"
			row.deliv.Text = tostring(r.delivMin or 0)
			row.best.Text = Format.num(r.best or 0)
			row.likes.Text = `❤ {r.likes or 0}`
			row.like.Visible = r.index ~= myPlot
			row.frame.BackgroundColor3 = r.index == myPlot and Color3.fromRGB(255, 240, 190) or C.paper
		end
	end
	local best = last.best
	refs.best.Text = best and `🏆 Biggest shipment today: {best.name} · {Format.num(best.cash)} Cash`
		or "🏆 Nobody's shipped big today yet: be the first!"
	local hall = last.hall or {}
	for key, label in refs.hall do
		local lines = {}
		for i, r in hall[key] or {} do
			if i <= 3 then
				table.insert(lines, `{i}. {r.name} {Format.num(r.value)}`)
			end
		end
		label.Text = #lines > 0 and table.concat(lines, "\n") or "-"
	end
end

local function paintFriends(list)
	refs.friendsEmpty.Visible = #list == 0
	for i, row in refs.friendRows do
		local f = list[i]
		row.frame.Visible = f ~= nil
		if f then
			row.data = f
			row.name.Text = (f.franchise and f.franchise > 0 and `★{f.franchise} ` or "") .. f.name
			row.info.Text = f.size
					and `Level {f.level or 1} · Size {Format.num(f.size)} · {Format.num(f.cashMin or 0)}/min`
				or "No farm yet"
			row.join.Text = f.here and "VISIT" or "JOIN"
			row.join.BackgroundColor3 = f.here and BLUE or C.good
		end
	end
end

local function loadFriends()
	refs.friendsEmpty.Text = "Looking for your friends..."
	refs.friendsEmpty.Visible = true
	task.spawn(function()
		local ok, list = pcall(function()
			return player:GetFriendsOnline(50)
		end)
		local ask = {}
		for _, f in ok and list or {} do
			if f.PlaceId == game.PlaceId or (f.GameId and f.GameId == game.JobId) then
				table.insert(ask, { userId = f.VisitorId, name = f.DisplayName or f.UserName })
			end
		end
		refs.friendsEmpty.Text = "None of your friends are farming right now. Invite them!"
		Net.send("Street", "friends", ask)
	end)
end

function StreetController:init()
	-- STREET -------------------------------------------------------------------------------------------------------
	local panel = Panel.new("street", "THE STREET", BLUE, Vector2.new(760, 440))
	refs.panel = panel
	local body = panel.body
	local head = Theme.new("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 22),
		Parent = body,
	})
	for _, h in
		{
			{ "#", 0, 0.06 },
			{ "FARM", 0.06, 0.26 },
			{ "SIZE", 0.32, 0.08 },
			{ "CASH", 0.4, 0.12 },
			{ "DELIV/MIN", 0.52, 0.1 },
			{ "BEST TODAY", 0.62, 0.1 },
		}
	do
		local l = cell(head, h[1], h[2], h[3])
		l.Text = h[1]
		l.TextColor3 = Color3.fromRGB(110, 110, 120)
	end
	for i = 1, 6 do
		local frame = Theme.card({
			Name = "Row" .. i,
			Position = UDim2.fromOffset(0, 24 + (i - 1) * (ROW + 4)),
			Size = UDim2.new(1, 0, 0, ROW),
			Visible = false,
			Parent = body,
		})
		local row = { frame = frame }
		row.rank = cell(frame, "Rank", 0, 0.06)
		row.name = cell(frame, "Name", 0.06, 0.26)
		row.size = cell(frame, "Size", 0.32, 0.08)
		row.cash = cell(frame, "Cash", 0.4, 0.12)
		row.deliv = cell(frame, "Deliv", 0.52, 0.1)
		row.best = cell(frame, "Best", 0.62, 0.1)
		row.likes = cell(frame, "Likes", 0.72, 0.06)
		row.visit = smallButton(frame, "Visit", "VISIT", 0.78, BLUE, function()
			if row.data then
				Bus.Tap:Fire("street_visit")
				Net.send("Street", "visit", row.data.index)
				Bus.Panel:Fire(nil)
			end
		end)
		row.like = smallButton(frame, "Like", "❤ LIKE", 0.89, Color3.fromRGB(235, 90, 120), function()
			if row.data then
				Bus.Tap:Fire("street_like")
				Net.send("Street", "like", row.data.index)
			end
		end)
		refs.rows[i] = row
	end
	refs.best = Theme.text({
		Name = "Best",
		Text = "",
		Font = Theme.Display,
		Position = UDim2.fromOffset(0, 290),
		Size = UDim2.new(1, -130, 0, 24),
		fit = 17,
		Parent = body,
	})
	refs.home = Theme.button({
		Name = "Home",
		Text = "🏠 HOME",
		BackgroundColor3 = C.good,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 286),
		Size = UDim2.fromOffset(120, 32),
		Parent = body,
	})
	refs.home.Activated:Connect(function()
		Bus.Tap:Fire("street_home")
		Net.send("Street", "home")
		Bus.Panel:Fire(nil)
	end)
	for i, h in { { "earned", "MOST CASH EVER" }, { "best", "BIGGEST SHIPMENT" }, { "size", "BIGGEST OPERATION" } } do
		local x = (i - 1) / 3
		Theme.text({
			Name = "HallTitle" .. i,
			Text = "🏆 " .. h[2],
			Font = Theme.Display,
			Position = UDim2.new(x, 0, 0, 322),
			Size = UDim2.new(1 / 3, -8, 0, 18),
			TextColor3 = Color3.fromRGB(190, 130, 20),
			fit = 14,
			Parent = body,
		})
		refs.hall[h[1]] = Theme.text({
			Name = "Hall" .. i,
			Text = "-",
			Position = UDim2.new(x, 0, 0, 340),
			Size = UDim2.new(1 / 3, -8, 0, 44),
			TextYAlignment = Enum.TextYAlignment.Top,
			fit = 13,
			Parent = body,
		})
	end
	panel.onOpen = function()
		Net.send("Street", "open")
	end

	-- FRIENDS ------------------------------------------------------------------------------------------------------
	local fpanel = Panel.new("friends", "FRIENDS", PURPLE, Vector2.new(620, 420))
	refs.friends = fpanel
	refs.friendsEmpty = Theme.text({
		Name = "Empty",
		Text = "",
		Position = UDim2.fromOffset(0, 100),
		Size = UDim2.new(1, 0, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Center,
		fit = 18,
		Parent = fpanel.body,
	})
	for i = 1, 7 do
		local frame = Theme.card({
			Name = "Friend" .. i,
			Position = UDim2.fromOffset(0, (i - 1) * 48),
			Size = UDim2.new(1, 0, 0, 44),
			Visible = false,
			Parent = fpanel.body,
		})
		local row = { frame = frame }
		row.name = cell(frame, "Name", 0, 0.32)
		row.name.Font = Theme.Display
		row.info = cell(frame, "Info", 0.32, 0.5)
		row.join = Theme.button({
			Name = "Join",
			Text = "JOIN",
			BackgroundColor3 = C.good,
			Position = UDim2.new(0.83, 0, 0, 5),
			Size = UDim2.new(0.17, -6, 1, -10),
			Parent = frame,
		})
		row.join.Activated:Connect(function()
			if row.data then
				Bus.Tap:Fire("friends_join")
				Net.send("Street", "join", row.data.userId)
				Bus.Panel:Fire(nil)
			end
		end)
		refs.friendRows[i] = row
	end
	fpanel.onOpen = loadFriends

	Net.listen("Street", function(m)
		if type(m) ~= "table" then
			return
		end
		if m.friends then
			paintFriends(m.friends)
			return
		end
		last = m
		last.rows = last.rows or {}
		paintStreet()
	end)
end

return StreetController
