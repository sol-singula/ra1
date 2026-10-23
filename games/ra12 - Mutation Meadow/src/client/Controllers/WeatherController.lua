--[[
The weather banner (Rain or Golden Hour from a bloom, or your own Welcome Shower): what it is, a countdown, and what
it rolls. While it rains on you, a rain cloud follows the camera.

  WeatherController.current()   { kind, scope, endsAt } or nil
  WeatherController.gui
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Clock = require(ReplicatedStorage.Shared.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local ClientState = require(script.Parent.Parent.ClientState)
local UI = require(script.Parent.Parent.UI)

local WeatherController = {}

local server, shower -- the server event, your shower
local banner, title, timeLabel, rollsLabel
local cloud

local function pct(x)
	return math.floor(x * 100 + 0.5) .. "%"
end

function WeatherController.current()
	return shower or server
end

local function refresh()
	if not banner then
		return
	end
	local w = WeatherController.current()
	banner.Visible = w ~= nil
	if cloud then
		cloud.Rain.Enabled = w ~= nil and w.kind == "rain"
	end
	if not w then
		return
	end
	local m = Config.Mutations
	if w.kind == "rain" then
		title.Text = if w.scope == "ownPlot" then "🌧 Welcome Shower on your plot" else "🌧 Rain! Crops grow 1.5x"
		local chance = if w.scope == "ownPlot" then m.wet.chance.welcomeShower else m.wet.chance.rain
		rollsLabel.Text = `{pct(chance)} chance a crop turns Wet ({m.wet.mult}x)`
	else
		title.Text = "✨ Golden Hour"
		rollsLabel.Text = `{pct(m.golden.chance.goldenHour)} chance a crop turns Golden ({m.golden.mult}x)`
	end
	timeLabel.Text = UI.duration((w.endsAt or 0) - Clock.now())
end

local function onWeather(data)
	if type(data) ~= "table" then
		return
	end
	local w = if data.kind then { kind = data.kind, scope = data.scope, endsAt = data.endsAt } else nil
	if data.scope == "ownPlot" then
		shower = w
	else
		server = w
	end
	refresh()
end

function WeatherController:Start()
	local gui = UI.screen("WeatherBanner")
	WeatherController.gui = gui
	banner = UI.frame(gui, {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 220),
		Size = UDim2.fromOffset(440, 110),
		Visible = false,
	})
	UI.list(banner, 2)
	title = UI.label(banner, "", { Name = "Title", Size = UDim2.new(1, -16, 0, 36) })
	timeLabel = UI.label(banner, "", { Name = "Countdown", Size = UDim2.new(1, -16, 0, 30) })
	rollsLabel = UI.label(banner, "", { Name = "Rolls", Size = UDim2.new(1, -16, 0, 26) })

	cloud = Instance.new("Part")
	cloud.Name = "RainCloud"
	cloud.Anchored = true
	cloud.CanCollide = false
	cloud.Transparency = 1
	cloud.Size = Vector3.new(40, 1, 40)
	local rain = Instance.new("ParticleEmitter")
	rain.Name = "Rain"
	rain.Enabled = false
	rain.Rate = 120
	rain.Speed = NumberRange.new(40, 50)
	rain.Lifetime = NumberRange.new(0.8, 1)
	rain.EmissionDirection = Enum.NormalId.Bottom
	rain.Parent = cloud
	cloud.Parent = workspace

	Net.on("Weather", onWeather)
	ClientState.Changed:Connect(function(roots)
		local extra = ClientState.extra
		if roots == nil and extra and extra.weather then
			local e, s = extra.weather.event, extra.weather.shower
			server = e and { kind = e.kind, scope = "server", endsAt = e.endsAt }
			shower = s and { kind = "rain", scope = "ownPlot", endsAt = s.endsAt }
			refresh()
		end
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if cloud.Rain.Enabled then
			local ok, cf = pcall(function()
				return workspace.CurrentCamera.CFrame
			end)
			if ok and cf then
				cloud.Position = cf.Position + Vector3.new(0, 25, 0)
			end
		end
		if acc >= 0.5 then
			acc = 0
			refresh()
		end
	end)
end

return WeatherController
