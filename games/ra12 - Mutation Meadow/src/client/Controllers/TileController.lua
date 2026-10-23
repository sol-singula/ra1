--[[
Tiles on the client: draws every plot's crops from the tile attributes (growing smoothly between server updates),
and the tile popup when you tap one.

Popup: your empty tile -> pick a seed you own (or pick up its sprinkler); growing -> seed, time left, boosts and the
can; ripe -> Harvest (a full basket offers selling that one); someone else's growing crop -> Help water.
Place mode (from Upgrades): the next tap on one of your empty tiles places that sprinkler.

  TileController.open(plot, tileId) / close() / isOpen()
  TileController.startPlacing(kind) / placing()
  TileController.ownPlot()
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Clock = require(ReplicatedStorage.Shared.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Tiles = require(ReplicatedStorage.Shared.Tiles)
local MutationMath = require(ReplicatedStorage.Shared.MutationMath)
local ClientState = require(script.Parent.Parent.ClientState)
local UI = require(script.Parent.Parent.UI)
local Visuals = require(script.Parent.Parent.Visuals)

local TileController = {}

local controllers
local popup, banner
local placingKind
local cropFolder
local crops = {} -- [tile part] = crop part
local connected = {} -- [ClickDetector] = true
local current -- { plot, id }

local DRAW_EVERY = 0.2

local function plots()
	local street = workspace:FindFirstChild("Street")
	return street and street:FindFirstChild("Plots") and street.Plots:GetChildren() or {}
end

function TileController.ownPlot()
	for _, plot in plots() do
		if plot:GetAttribute("OwnerId") == Players.LocalPlayer.UserId then
			return plot
		end
	end
	return nil
end

local function tilePart(plot, id)
	if Tiles.isExtra(id) then
		return plot.ExtraRow:FindFirstChild(id)
	end
	return plot.Tiles:FindFirstChild(id)
end

local function toastResult(result)
	local handled = result.code == "basket_full" or result.code == "backpack_full"
	if not result.ok and result.code and not handled and controllers.HudController then
		controllers.HudController.toast("Can't do that: " .. result.code)
	end
end

local function send(remote, action, payload, after)
	Net.request(remote, action, payload):andThen(function(result)
		toastResult(result)
		if after then
			after(result)
		end
	end)
	TileController.close()
end

local function boostsText(part)
	local rate = part:GetAttribute("Rate") or 1
	if rate <= 1 then
		return "No boosts"
	end
	return string.format("Growing x%.2f", rate)
end

local function fill(plot, id)
	popup.clear()
	local part = tilePart(plot, id)
	local mine = plot:GetAttribute("OwnerId") == Players.LocalPlayer.UserId
	local seed = part:GetAttribute("Seed")
	local profile = ClientState.profile or { seeds = {} }
	if not seed then
		if not mine then
			UI.label(popup.body, "An empty tile")
			return
		end
		if part:GetAttribute("Sprinkler") then
			UI.label(popup.body, "A sprinkler")
			UI.button(popup.body, "Pick up", function()
				send("Plot", "pickup", { tile = id })
			end, { Name = "Pickup" })
			return
		end
		UI.label(popup.body, "Plant a seed")
		local any = false
		for _, key in Config.Restock.order do
			local n = profile.seeds[key]
			if n and n > 0 then
				any = true
				UI.button(popup.body, `{Config.Seeds[key].name} x{n}`, function()
					send("Plot", "plant", { tile = id, seed = key })
				end, { Name = "Seed_" .. key })
			end
		end
		if not any then
			UI.label(popup.body, "No seeds. Visit Patch's shop!", { Name = "NoSeeds" })
		end
		return
	end
	local name = Config.Seeds[seed].name
	local mut = MutationMath.label(part:GetAttribute("Muts"))
	if mut ~= "" then
		name = mut .. " " .. name
	end
	if part:GetAttribute("Ripe") then
		UI.label(popup.body, name .. " is ripe!")
		if mine then
			UI.button(popup.body, "Harvest", function()
				send("Plot", "harvest", { tile = id }, function(result)
					if result.code == "basket_full" then
						TileController.offerSell(plot, id)
					elseif result.code == "backpack_full" then
						controllers.BackpackController.fullPrompt(plot, id)
					end
				end)
			end, { Name = "Harvest" })
		end
		return
	end
	local grown = Visuals.grownNow(part, Clock.now()) or 0
	local left = (part:GetAttribute("GrowSec") - grown) / (part:GetAttribute("Rate") or 1)
	UI.label(popup.body, name, { Name = "Seed" })
	UI.label(popup.body, "Ready in " .. UI.duration(left), { Name = "TimeLeft" })
	UI.label(popup.body, boostsText(part), { Name = "Boosts" })
	if mine then
		if not part:GetAttribute("CanUsed") then
			UI.button(popup.body, "Water (" .. profile.can .. " can)", function()
				send("Plot", "water", { tile = id })
			end, { Name = "Water" })
		end
	else
		UI.button(popup.body, "Help water", function()
			send("Plot", "water", { tile = id, ownerId = plot:GetAttribute("OwnerId") })
		end, { Name = "Help" })
	end
end

function TileController.offerSell(plot, id)
	TileController.open(plot, id)
	popup.clear()
	UI.label(popup.body, "Basket full! Sell at the stand.")
	UI.button(popup.body, "Sell this one now", function()
		send("Plot", "harvest", { tile = id, onFull = "sell" })
	end, { Name = "SellOne" })
end

function TileController.open(plot, id)
	current = { plot = plot, id = id }
	fill(plot, id)
	popup.open()
end

function TileController.close()
	if popup then
		popup.close()
	end
	current = nil
end

function TileController.isOpen()
	return popup ~= nil and popup.isOpen()
end

function TileController.startPlacing(kind)
	placingKind = kind
	banner.Visible = true
	banner.Label.Text = `Tap an empty tile to place a {kind} sprinkler`
end

function TileController.placing()
	return placingKind
end

local function stopPlacing()
	placingKind = nil
	if banner then
		banner.Visible = false
	end
end

local function tapped(plot, part)
	local id = part.Name
	if not part:GetAttribute("Active") then
		return
	end
	if placingKind then
		if plot:GetAttribute("OwnerId") == Players.LocalPlayer.UserId and Tiles.rc(id) then
			local kind = placingKind
			stopPlacing()
			send("Plot", "sprinkler", { kind = kind, tile = id })
		end
		return
	end
	TileController.open(plot, id)
end

local function connectClicks()
	for _, plot in plots() do
		for _, folder in { plot.Tiles, plot.ExtraRow } do
			for _, part in folder:GetChildren() do
				local click = part:FindFirstChild("Click")
				if click and not connected[click] then
					connected[click] = true
					click.MouseClick:Connect(function()
						tapped(plot, part)
					end)
				end
			end
		end
	end
end

local function draw()
	local now = Clock.now()
	local seen = {}
	for _, plot in plots() do
		for _, folder in { plot.Tiles, plot.ExtraRow } do
			for _, part in folder:GetChildren() do
				local seed = part:GetAttribute("Seed")
				if seed then
					seen[part] = true
					local crop = crops[part]
					if not crop then
						crop = Instance.new("Part")
						crop.Name = plot.Name .. "_" .. part.Name
						crop.Anchored = true
						crop.CanCollide = false
						crop.Parent = cropFolder
						crops[part] = crop
					end
					local growSec = part:GetAttribute("GrowSec") or 1
					local progress = math.clamp((Visuals.grownNow(part, now) or 0) / growSec, 0.1, 1)
					local ripe = part:GetAttribute("Ripe") == true
					local size = 0.6 + 2.2 * progress
					crop.Size = Vector3.new(size, size, size)
					crop.Position = part.Position + Vector3.new(0, 0.5 + size / 2, 0)
					crop.Color = if ripe
						then Visuals.SEED[seed] or Visuals.LEAF
						else Visuals.LEAF:Lerp(Visuals.SEED[seed] or Visuals.LEAF, progress)
					crop.Material = if ripe then Enum.Material.Neon else Enum.Material.SmoothPlastic
					Visuals.mutationFx(crop, part:GetAttribute("Muts"))
				end
			end
		end
	end
	for part, crop in crops do
		if not seen[part] then
			crop:Destroy()
			crops[part] = nil
		end
	end
	if current and popup.isOpen() then
		local part = tilePart(current.plot, current.id)
		local label = popup.body:FindFirstChild("TimeLeft")
		if label and part and part:GetAttribute("GrowSec") then
			local grown = Visuals.grownNow(part, now) or 0
			label.Text = "Ready in "
				.. UI.duration((part:GetAttribute("GrowSec") - grown) / (part:GetAttribute("Rate") or 1))
		end
	end
end

function TileController:Init(all)
	controllers = all
end

function TileController:Start()
	popup = UI.modal("TilePopup", "Tile")
	popup.card.Size = UDim2.fromOffset(420, 420)
	local gui = UI.screen("PlaceBanner")
	banner = UI.frame(gui, {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(520, 64),
		Visible = false,
	})
	UI.label(banner, "", { Name = "Label", Size = UDim2.new(1, -140, 1, 0), Position = UDim2.fromOffset(12, 0) })
	UI.button(banner, "Cancel", stopPlacing, {
		Name = "Cancel",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(110, 48),
		BackgroundColor3 = UI.COLORS.red,
	})
	cropFolder = Instance.new("Folder")
	cropFolder.Name = "ClientCrops"
	cropFolder.Parent = workspace
	connectClicks()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= DRAW_EVERY then
			acc = 0
			connectClicks()
			draw()
		end
	end)
end

-- for tests: tap a tile as if its ClickDetector fired
function TileController.tap(plot, id)
	tapped(plot, tilePart(plot, id))
end

return TileController
