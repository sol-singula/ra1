local Assert = require("./mock/Assert")
local Client = require("./mock/Client")
local Farm = require("./mock/Farm")
local Server = require("./mock/Server")

local test, eq = Assert.test, Assert.eq

local SCENES = {
	"street",
	"offline_before",
	"offline_after",
	"golden_reveal",
	"block_party_rain",
	"block_party_golden",
	"pedestals",
	"icon",
}

local function dev()
	local ctx = Farm.setup({ studio = true })
	local p = Farm.join(ctx, 1)
	local function capture(...)
		return Farm.call(ctx, p, "DevCommand", "run", { cmd = "capture", args = { ... } })
	end
	return ctx, p, capture
end

local function stage(ctx)
	return ctx.engine.workspace.Capture.Stage
end

-- every staged crop's mutation key, and whether any rain VFX is staged
local function look(ctx)
	local muts, rain = {}, false
	for _, d in stage(ctx):GetDescendants() do
		if d:GetAttribute("Crop") then
			muts[d:GetAttribute("Muts") or "none"] = (muts[d:GetAttribute("Muts") or "none"] or 0) + 1
		end
		if d.Name == "RainFx" then
			rain = true
		end
	end
	return muts, rain
end

test("every scene id resolves to a camera (1920x1080, the icon 1024x1024)", function()
	local ctx, _, capture = dev()
	for _, scene in SCENES do
		eq(capture(scene), true, scene)
		local cam = ctx.engine.workspace.Capture.Cams:FindFirstChild(scene)
		Assert.truthy(cam, scene .. " camera")
		local square = scene == "icon"
		eq(
			{ cam:GetAttribute("Width"), cam:GetAttribute("Height") },
			if square then { 1024, 1024 } else { 1920, 1080 },
			scene
		)
		eq(ctx.engine.workspace.Capture:GetAttribute("Scene"), scene)
		Assert.truthy(#stage(ctx):GetChildren() > 0, scene .. " staged")
	end
	eq(ctx.engine.errors, {})
end)

test("only the listed args: block_party and junk are unknown_scene", function()
	local _, _, capture = dev()
	for _, args in
		{ { "block_party" }, { "nope" }, { "hud", "maybe" }, { "guides" }, { "street", "extra" }, { "free", "now" } }
	do
		eq({ capture(table.unpack(args)) }, { false, "unknown_scene" }, table.concat(args, " "))
	end
	for _, args in { { "hud", "off" }, { "hud", "on" }, { "guides", "on" }, { "guides", "off" }, { "free" } } do
		eq(capture(table.unpack(args)), true, table.concat(args, " "))
	end
end)

test("a non-dev call outside Studio is a no-op (dev_gate)", function()
	local ctx = Farm.setup()
	local p = Farm.join(ctx, 1)
	eq({ Farm.call(ctx, p, "DevCommand", "run", { cmd = "capture", args = { "street" } }) }, { nil, "no_result" })
	eq(ctx.engine.workspace:FindFirstChild("Capture"), nil)
	eq(ctx.Net.dropStats().byReason.dev_gate, 1)
end)

test("capture never calls SaveQueue or touches a profile", function()
	local ctx, p, capture = dev()
	local SaveQueue = ctx.engine:require(ctx.engine:module("Server/Save/SaveQueue"))
	local calls = 0
	local real = SaveQueue.request
	SaveQueue.request = function(...)
		calls += 1
		return real(...)
	end
	local before = Server.deepCopy(ctx.Data.get(p))
	local writes = #ctx.engine.dataLog
	for _, scene in SCENES do
		capture(scene)
	end
	capture("hud", "off")
	capture("free")
	eq(calls, 0)
	local after = Server.deepCopy(ctx.Data.get(p))
	-- the clock runs while scenes stage: only the played-time counters move
	after.firstSession.playedSec, after.playtime = before.firstSession.playedSec, before.playtime
	eq(after, before)
	eq(#ctx.engine.dataLog, writes)
	eq(ctx.Weather.current(), nil, "the real weather is untouched")
end)

test("block_party_rain: rain lighting and VFX, only Wet crops", function()
	local ctx, _, capture = dev()
	eq(capture("block_party_rain"), true)
	local muts, rain = look(ctx)
	eq(muts, { wet = 18 })
	eq(rain, true)
	eq(ctx.engine.workspace.Capture:GetAttribute("Lighting"), "rain")
	local lighting = ctx.engine.game.Lighting
	eq({ lighting.ClockTime, lighting.FogEnd }, { 15, 400 })
	Assert.truthy(stage(ctx).Sunflower:GetAttribute("Stage") == "bloom", "bloomed")
end)

test("block_party_golden: Golden Hour lighting, only Golden crops, no rain", function()
	local ctx, _, capture = dev()
	eq(capture("block_party_golden"), true)
	local muts, rain = look(ctx)
	eq(muts, { golden = 18 })
	eq(rain, false)
	eq(ctx.engine.workspace.Capture:GetAttribute("Lighting"), "golden")
	eq(ctx.engine.game.Lighting.ClockTime, 17.6)
end)

test("one after the other leaves nothing of the first", function()
	local ctx, _, capture = dev()
	capture("block_party_rain")
	capture("block_party_golden")
	local muts, rain = look(ctx)
	eq({ muts.wet, rain, muts.golden }, { nil, false, 18 })
	eq(ctx.engine.game.Lighting.FogEnd, 100000, "the rain fog is gone")
	capture("block_party_rain")
	muts, rain = look(ctx)
	eq({ muts.golden, rain, muts.wet }, { nil, true, 18 })
	eq(ctx.engine.game.Lighting.ClockTime, 15)
end)

test("pedestals: Wet, Golden, Wet + Golden with x2, x20, x40 badges", function()
	local ctx, _, capture = dev()
	capture("pedestals")
	local badges = {}
	for i = 1, 3 do
		local c = stage(ctx):FindFirstChild("PedestalCrop" .. i)
		table.insert(badges, { c:GetAttribute("Muts"), c.Badge.Text.Text, c:GetAttribute("Mult") })
	end
	eq(badges, { { "wet", "×2", 2 }, { "golden", "×20", 20 }, { "wetgolden", "×40", 40 } })
end)

test("Patch keeps his orange head; gold only on mutated crops; the street has 6 different farmers", function()
	local ctx, _, capture = dev()
	local Capture = ctx.engine:require(ctx.engine:module("Server/Services/CaptureService"))
	local Visuals = ctx.engine:require(ctx.engine:module("Shared/Visuals"))
	for _, scene in SCENES do
		capture(scene)
		for _, d in stage(ctx):GetDescendants() do
			if d:GetAttribute("Patch") then
				eq(d.Color, Capture.PATCH_ORANGE, scene .. ": Patch's head")
				eq(d:FindFirstChild("MutFx"), nil)
			end
			if d.Name == "MutFx" and d:GetAttribute("Key") ~= "wet" then
				Assert.truthy(d.Parent:GetAttribute("Crop"), scene .. ": gold VFX only on crops")
			end
			if d:IsA("Part") and not d:GetAttribute("Crop") then
				Assert.truthy(d.Color ~= Visuals.MUT.golden, scene .. ": " .. d.Name .. " is gold")
			end
		end
	end
	capture("street")
	local outfits = {}
	for _, d in stage(ctx):GetChildren() do
		if d:GetAttribute("Outfit") then
			outfits[d:GetAttribute("Outfit")] = true
		end
	end
	eq(outfits, { overalls = true, sunhat = true, apron = true, rainboots = true, flannel = true, gloves = true })
	capture("icon")
	local hero = stage(ctx).HeroCrop
	eq({ hero:GetAttribute("Seed"), hero:GetAttribute("Muts") }, { "pumpkin", "golden" })
	capture("offline_before")
	eq(ctx.engine.workspace.Capture:GetAttribute("Lighting"), "night")
	capture("offline_after")
	eq(ctx.engine.workspace.Capture:GetAttribute("Lighting"), "day")
end)

test(
	"the client: the camera locks to the scene, hud off/on restores the state, the guides show the safe line",
	function()
		local c = Client.boot()
		local Capture = c.engine:require(c.engine:module("Server/Services/CaptureService"))
		local CaptureController = c.controllers.CaptureController
		c.gui("WelcomeBack").Enabled = false -- was hidden before: must stay hidden after
		c.engine:run(function()
			Capture.run({ "icon" })
		end)
		c.engine:advance(1.2)
		local camera = c.engine.workspace.CurrentCamera
		eq(camera.CameraType, c.engine.Enum.CameraType.Scriptable)
		eq(camera.CFrame, c.engine.workspace.Capture.Cams.icon.CFrame)
		c.engine:run(function()
			Capture.run({ "hud", "off" })
		end)
		for _, g in c.engine.game.Players.LocalPlayer.PlayerGui:GetChildren() do
			if g.ClassName == "ScreenGui" and g.Name ~= "CaptureGuides" then
				eq(g.Enabled, false, g.Name)
			end
		end
		eq(c.engine.coreGui.PlayerList, false)
		c.engine:run(function()
			Capture.run({ "hud", "on" })
		end)
		eq(c.gui("Hud").Enabled, true)
		eq(c.gui("WelcomeBack").Enabled, false)
		eq(c.engine.coreGui.PlayerList, true)
		eq(CaptureController.hidden(), nil)
		c.engine:run(function()
			Capture.run({ "guides", "on" })
		end)
		local guides = c.gui("CaptureGuides")
		eq(guides.Enabled, true)
		Assert.near(guides.Frame.SafeLine.Position.Y.Scale, 0.85, 1e-6)
		eq(guides.Frame.UIAspectRatioConstraint.AspectRatio, 1, "the icon is square")
		c.engine:run(function()
			Capture.run({ "street" })
		end)
		Assert.near(guides.Frame.UIAspectRatioConstraint.AspectRatio, 16 / 9, 1e-6)
		c.engine:run(function()
			Capture.run({ "free" })
		end)
		eq(camera.CameraType, c.engine.Enum.CameraType.Custom)
		eq(c.engine.errors, {})
	end
)
