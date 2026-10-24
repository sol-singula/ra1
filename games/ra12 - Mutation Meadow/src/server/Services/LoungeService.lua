--[[
The VIP Lounge (§9.6): a deck behind a satin-brass gate (Config.Brass) (Workspace.Street.Lounge, StreetBuilder.lounge).

Lounge:enter (or the gate's "Enter" prompt) needs VIP Gardener: the character steps onto the deck and lounge_enter
is logged. Every Config.Lounge.checkSec a non-owner inside the Volume is moved back out past the gate, pushStuds
beyond it. A non-owner at the gate gets the VIP card once a session: Toast kind "vipGate" with { key, name, perks,
robux } (the client shows it with Close; no urgency copy).

  LoungeService.enter(player) -> ok, code
  LoungeService.inside(player) -> boolean
  LoungeService.check()        one pass of the push-back (the loop calls it)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local NetService = require(script.Parent.NetService)
local Purchase = require(script.Parent.Parent.Purchase)
local StreetBuilder = require(script.Parent.Parent.World.StreetBuilder)
local Telemetry = require(script.Parent.Parent.Telemetry)

local LoungeService = {}

local lounge
local cardShown = setmetatable({}, { __mode = "k" })

local function rootOf(player)
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end

function LoungeService.inside(player)
	local root = rootOf(player)
	local volume = lounge and lounge:FindFirstChild("Volume")
	if not root or not volume then
		return false
	end
	local d = root.Position - volume.Position
	local half = volume.Size / 2
	return math.abs(d.X) <= half.X and math.abs(d.Y) <= half.Y and math.abs(d.Z) <= half.Z
end

local function showCard(player)
	if cardShown[player] then
		return
	end
	cardShown[player] = true
	local vip = Config.Catalog.passes.vip
	NetService.toast(player, "vipGate", vip.name, {
		key = "vip",
		name = vip.name,
		perks = { "VIP name tag and border", "Brass sparkle trail", "The VIP Lounge" },
		robux = vip.robux,
	})
end

function LoungeService.enter(player)
	if not Purchase.owns(player, "vip") then
		showCard(player)
		return false, "not_vip"
	end
	local root = rootOf(player)
	local deck = lounge and lounge:FindFirstChild("Deck")
	if root and deck then
		player.Character:PivotTo(CFrame.new(deck.Position + Vector3.new(0, 3, 0)))
	end
	Telemetry.log(player, "lounge_enter", {})
	return true
end

function LoungeService.check()
	local gate = lounge and lounge:FindFirstChild("Gate")
	if not gate then
		return
	end
	for _, player in Players:GetPlayers() do
		if LoungeService.inside(player) and not Purchase.owns(player, "vip") then
			local out = gate.Position + Vector3.new(0, 0, Config.Lounge.pushStuds)
			player.Character:PivotTo(CFrame.new(Vector3.new(out.X, rootOf(player).Position.Y, out.Z)))
			showCard(player)
		end
	end
end

function LoungeService:Init()
	local street = workspace:FindFirstChild("Street")
	lounge = street and StreetBuilder.lounge(street)
	NetService.on("Lounge", "enter", nil, LoungeService.enter)
	local gate = lounge and lounge:FindFirstChild("Gate")
	local prompt = gate and gate:FindFirstChild("Enter")
	if prompt then
		prompt.Triggered:Connect(function(player)
			LoungeService.enter(player)
		end)
	end
	if gate then
		gate.Touched:Connect(function(hit)
			local player = hit.Parent and Players:GetPlayerFromCharacter(hit.Parent)
			if player and not Purchase.owns(player, "vip") then
				showCard(player)
			end
		end)
	end
end

function LoungeService:Start()
	while true do
		task.wait(Config.Lounge.checkSec)
		LoungeService.check()
	end
end

return LoungeService
