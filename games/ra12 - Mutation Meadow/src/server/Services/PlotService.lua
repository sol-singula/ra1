--[[
The street's eight plots: who owns which, which tiles show, and the tile state everyone's client draws (§2).

On Loaded the player gets the first free plot (attribute OwnerId) and its active tiles show; on leave the plot is
cleared and freed. Workspace.Street comes from the place; without one, StreetBuilder makes a placeholder.

Each tile part carries what clients need to draw and animate it (the server stays authoritative):
  Active, Seed, Grown, At (server time Grown was true), Rate, GrowSec, Ripe, CanUsed, HarvestsLeft, Mutated,
  Sprinkler. A client shows grown = Grown + (now - At) x Rate.

  PlotService.plotOf(player) / ownerOf(plot)
  PlotService.tilePart(player, tileId) / standPart(player) / signPart(player)
  PlotService.hasExtraRow(player)
  PlotService.refresh(player)              shows the tiles active at the player's level (and the Extra Plot Row)
  PlotService.renderTile(player, tileId, rate)
  PlotService.plots()                      the plot models, in order
  PlotService.Assigned(player, plot) / Released(player, plot)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Clock = require(ReplicatedStorage.Shared.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Tiles = require(ReplicatedStorage.Shared.Tiles)

local DataService = require(script.Parent.DataService)
local Purchase = require(script.Parent.Parent.Purchase)
local StreetBuilder = require(script.Parent.Parent.World.StreetBuilder)

local PlotService = {
	Assigned = Signal.new(),
	Released = Signal.new(),
}

local plotList = {}
local owners = {} -- [plot] = player
local byPlayer = {} -- [player] = plot

local TILE_ATTRS = { "Seed", "Grown", "At", "Rate", "GrowSec", "Ripe", "CanUsed", "HarvestsLeft", "Mutated" }

function PlotService.plots()
	return plotList
end

function PlotService.plotOf(player)
	return byPlayer[player]
end

function PlotService.ownerOf(plot)
	return owners[plot]
end

local function findTile(plot, id)
	if Tiles.isExtra(id) then
		return plot.ExtraRow:FindFirstChild(id)
	end
	return plot.Tiles:FindFirstChild(id)
end

function PlotService.tilePart(player, id)
	local plot = byPlayer[player]
	return plot and findTile(plot, id)
end

function PlotService.standPart(player)
	local plot = byPlayer[player]
	return plot and plot:FindFirstChild("SellStand")
end

function PlotService.signPart(player)
	local plot = byPlayer[player]
	return plot and plot:FindFirstChild("Sign")
end

function PlotService.hasExtraRow(player)
	return Purchase.owns(player, "extraRow")
end

local function show(part, on)
	part:SetAttribute("Active", on)
	part.Transparency = if on then 0 else 1
	part.CanCollide = on
end

function PlotService.refresh(player)
	local plot = byPlayer[player]
	local profile = DataService.get(player)
	if not plot or not profile then
		return
	end
	local extra = PlotService.hasExtraRow(player)
	for _, part in plot.Tiles:GetChildren() do
		show(part, Tiles.isActive(part.Name, profile.plotLevel, extra))
	end
	for _, part in plot.ExtraRow:GetChildren() do
		if part.Name == "Bed" then
			part.Transparency = if extra then 0 else 1
		else
			show(part, extra)
		end
	end
end

function PlotService.renderTile(player, id, rate)
	local profile = DataService.get(player)
	local part = PlotService.tilePart(player, id)
	if not profile or not part then
		return
	end
	part:SetAttribute("Sprinkler", profile.sprinklers.placed[id])
	local tile = profile.tiles[id]
	if not tile then
		for _, attr in TILE_ATTRS do
			part:SetAttribute(attr, nil)
		end
		return
	end
	local growSec = Config.Seeds[tile.seed].growSec
	part:SetAttribute("Seed", tile.seed)
	part:SetAttribute("Grown", tile.grown)
	part:SetAttribute("At", Clock.now())
	part:SetAttribute("Rate", rate)
	part:SetAttribute("GrowSec", growSec)
	part:SetAttribute("Ripe", tile.grown >= growSec)
	part:SetAttribute("CanUsed", tile.canUsed)
	part:SetAttribute("HarvestsLeft", tile.harvestsLeft)
	part:SetAttribute("Mutated", next(tile.muts) ~= nil)
end

local function clear(plot)
	for _, folder in { plot.Tiles, plot.ExtraRow } do
		for _, part in folder:GetChildren() do
			for _, attr in TILE_ATTRS do
				part:SetAttribute(attr, nil)
			end
			if part.Name ~= "Bed" then
				part:SetAttribute("Sprinkler", nil)
				show(part, false)
			else
				part.Transparency = 1
			end
		end
	end
	plot:SetAttribute("OwnerId", nil)
	plot.Mailbox:SetAttribute("GardenName", "")
end

local function release(player)
	local plot = byPlayer[player]
	if not plot then
		return
	end
	clear(plot)
	owners[plot] = nil
	byPlayer[player] = nil
	PlotService.Released:Fire(player, plot)
end

function PlotService:Init()
	local street = workspace:FindFirstChild("Street") or StreetBuilder.build(workspace)
	local list = {}
	for _, plot in street.Plots:GetChildren() do
		local n = tonumber(plot.Name:match("^Plot(%d+)$"))
		if n then
			table.insert(list, { n = n, plot = plot })
		end
	end
	table.sort(list, function(a, b)
		return a.n < b.n
	end)
	for _, entry in list do
		table.insert(plotList, entry.plot)
		clear(entry.plot)
	end
end

function PlotService:Start()
	Players.PlayerRemoving:Connect(release)
end

function PlotService:OnPlayerLoaded(player, profile)
	if byPlayer[player] then
		return
	end
	for _, plot in plotList do
		if not owners[plot] then
			owners[plot] = player
			byPlayer[player] = plot
			plot:SetAttribute("OwnerId", player.UserId)
			plot.Mailbox:SetAttribute("GardenName", profile.settings.gardenName or player.DisplayName)
			PlotService.refresh(player) -- FarmService renders the saved crops and sprinklers next
			PlotService.Assigned:Fire(player, plot)
			return
		end
	end
	warn(`[PlotService] no free plot for {player.UserId} (Players.MaxPlayers should match the plots)`)
end

function PlotService:OnPlayerLeaving(player)
	release(player)
end

return PlotService
