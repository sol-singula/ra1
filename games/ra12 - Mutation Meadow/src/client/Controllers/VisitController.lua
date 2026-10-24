--[[
Visiting and likes: "Visit" lists your friends (here first, then online in another server of this game) with Visit
(Social:visit {friendId}), and every other farm in this server with Like (Social:like {ownerId}, once per farm a
day; already liked today shows Liked). Visiting is look-only.

  VisitController.open() / close() / isOpen() / fill()
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local ClientState = require(script.Parent.Parent.ClientState)
local UI = require(script.Parent.Parent.UI)

local VisitController = {}

local modal

local function likedToday(userId)
	return (ClientState.get("social", "liked", tostring(userId)) or 0) >= Config.Social.likesPerFarmPerDay
end

local function row(order, name, buttons)
	local r = UI.frame(modal.body, { Name = name, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 60) })
	for i, b in buttons do
		local props = b[3] or {}
		props.Name = b[1]
		props.AnchorPoint = Vector2.new(1, 0.5)
		props.Position = UDim2.new(1, -8 - (i - 1) * 118, 0.5, 0)
		props.Size = UDim2.fromOffset(110, UI.MIN_TAP)
		if props.label then
			props.label = nil
			UI.label(r, b[2], props)
		else
			UI.button(r, b[2], b[4], props)
		end
	end
	return r
end

function VisitController.fill()
	modal.clear()
	local me = Players.LocalPlayer
	local order = 0
	local seen = {}
	for _, p in Players:GetPlayers() do
		if p ~= me then
			order += 1
			seen[p.UserId] = true
			local friend = false
			pcall(function()
				friend = me:IsFriendsWith(p.UserId)
			end)
			local buttons = {}
			if likedToday(p.UserId) then
				table.insert(buttons, { "Liked", "♥ Liked", { label = true, TextColor3 = UI.COLORS.green } })
			else
				table.insert(buttons, {
					"Like",
					"♥ Like",
					{},
					function()
						Net.request("Social", "like", { ownerId = p.UserId })
					end,
				})
			end
			if friend then
				table.insert(buttons, {
					"Visit",
					"Visit",
					{ BackgroundColor3 = UI.COLORS.ink },
					function()
						Net.request("Social", "visit", { friendId = p.UserId })
						modal.close()
					end,
				})
			end
			local r = row(order, "Farm_" .. p.UserId, buttons)
			UI.label(r, p.DisplayName .. (if friend then " (friend)" else ""), {
				Name = "Who",
				Position = UDim2.fromOffset(10, 6),
				Size = UDim2.new(1, -260, 1, -12),
				TextXAlignment = Enum.TextXAlignment.Left,
			})
		end
	end
	local ok, online = pcall(function()
		return me:GetFriendsOnline()
	end)
	if ok then
		for _, f in online do
			if not seen[f.VisitorId] and f.PlaceId == game.PlaceId then
				order += 1
				local r = row(order, "Away_" .. f.VisitorId, {
					{
						"Visit",
						"Visit",
						{ BackgroundColor3 = UI.COLORS.ink },
						function()
							Net.request("Social", "visit", { friendId = f.VisitorId })
						end,
					},
				})
				UI.label(r, (f.DisplayName or f.UserName or "Friend") .. " (another server)", {
					Name = "Who",
					Position = UDim2.fromOffset(10, 6),
					Size = UDim2.new(1, -140, 1, -12),
					TextXAlignment = Enum.TextXAlignment.Left,
				})
			end
		end
	end
	if order == 0 then
		UI.label(modal.body, "Nobody else is here yet.", { Name = "Nobody" })
	end
end

function VisitController.open()
	VisitController.fill()
	modal.open()
end

function VisitController.close()
	modal.close()
end

function VisitController.isOpen()
	return modal.isOpen()
end

function VisitController:Start()
	modal = UI.modal("Visit", "Visit & Like")
	modal.card.Size = UDim2.fromOffset(520, 520)
	ClientState.Changed:Connect(function(roots)
		if modal.isOpen() and (roots == nil or roots.social) then
			VisitController.fill()
		end
	end)
end

return VisitController
