--[[
Helpers for the farming specs: a booted server, players standing where they need to, and remote calls that return
their Result.

  local ctx = Farm.setup(opts?, setup?)    ctx.engine, ctx.Data, ctx.Plot, ctx.FarmS, ctx.Inv, ctx.Social, ctx.Net
  Farm.join(ctx, userId)                   a loaded player standing on their own plot
  Farm.standAt(ctx, player, position)
  Farm.standAtTile(ctx, player, owner, tileId)
  Farm.standAtStand(ctx, player)
  Farm.call(ctx, player, remote, action, payload) -> ok, code   (through the remote, with a reqId)
  Farm.toasts(ctx, player)                 every Toast that player got
  Farm.ripen(ctx, player, tileId)          sets that tile's grown to its growSec
]]
local Server = require("./Server")
local roblox = require("@lune/roblox")

local Farm = {}

function Farm.setup(opts, setup)
	local engine, Data = Server.boot(opts, setup)
	local function service(name)
		return engine:require(engine:module("Server/Services/" .. name))
	end
	return {
		engine = engine,
		Data = Data,
		Plot = service("PlotService"),
		FarmS = service("FarmService"),
		Inv = service("InventoryService"),
		Social = service("SocialService"),
		Net = service("NetService"),
		reqId = 0,
	}
end

function Farm.standAt(ctx, player, position)
	local character = player.Character
	if not character then
		character = ctx.engine.Instance.new("Model")
		local root = ctx.engine.Instance.new("Part", character)
		root.Name = "HumanoidRootPart"
		player.Character = character
	end
	character.HumanoidRootPart.Position = position
end

function Farm.standAtTile(ctx, player, owner, tileId)
	local part = ctx.Plot.tilePart(owner, tileId)
	assert(part, `no tile {tileId}`)
	Farm.standAt(ctx, player, part.Position + roblox.Vector3.new(0, 3, 0))
end

function Farm.standAtStand(ctx, player)
	Farm.standAt(ctx, player, ctx.Plot.standPart(player).Position + roblox.Vector3.new(0, 0, -3))
end

function Farm.join(ctx, userId)
	local player = Server.join(ctx.engine, userId)
	if ctx.Plot.plotOf(player) then
		Farm.standAtTile(ctx, player, player, "1")
	end
	return player
end

function Farm.call(ctx, player, remote, action, payload)
	ctx.reqId += 1
	local id = ctx.reqId
	local body = table.clone(payload or {})
	body.reqId = id
	ctx.engine:fireServer(player, remote, action, body)
	ctx.engine:advance(0.11, 0.11) -- under every rate limit
	for _, args in ctx.engine:clientEvents("Result", player.UserId) do
		if args[1].reqId == id then
			return args[1].ok, args[1].code
		end
	end
	return nil, "no_result"
end

function Farm.toasts(ctx, player)
	local out = {}
	for _, args in ctx.engine:clientEvents("Toast", player.UserId) do
		table.insert(out, args[1])
	end
	return out
end

function Farm.toastTexts(ctx, player)
	local out = {}
	for _, t in Farm.toasts(ctx, player) do
		table.insert(out, t.text)
	end
	return out
end

function Farm.ripen(ctx, player, tileId)
	local profile = ctx.Data.get(player)
	local tile = profile.tiles[tileId]
	tile.grown = ctx.engine:require(ctx.engine:module("Shared/Config")).Seeds[tile.seed].growSec
end

return Farm
