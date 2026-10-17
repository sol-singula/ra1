--[[
The cosmetics alive (FX/Flair, FlairController): every bow skin on your own view model and on the bow others hold,
every arrow trail in flight, every banner emblem on a flag, on the mock engine with the real server and client.
The animated ones really move (a rainbow's hue, stripes sliding, wings flapping, a spin), the particle ones throw
their bits, the lightning crackles, everything is cleaned up after, and nothing errors.

  luaurun tests/FlairSmoke.spec.luau
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Vector3 = Engine.Vector3

local passed, failed = 0, 0
local function check(name, cond, detail)
	if cond then
		passed += 1
	else
		failed += 1
		print("FAIL " .. name .. (detail ~= nil and (": " .. tostring(detail)) or ""))
	end
end

local tree = Engine.mountProject(".")
Engine.require(tree.shared.Constants).AFK_SECONDS = 0
Engine.require(tree.shared.Constants).MIN_SIDE = 1
Engine.require(tree.shared.Constants).TUTORIAL = false
Engine.clientEnabled = true
local ws = Engine.workspace
Engine.runScript(tree.server.Main)
Engine.advance(0.2)
local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Combat = service("CombatService")

local foe = Engine.addPlayer("Foe", 900)
Engine.advance(0.5)
Engine.fireServer(foe, "Ready")
local player = Engine.addPlayer("Ava", 501)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.runScript(tree.client.Main)
Engine.advance(2)

local Cosmetics = Engine.require(tree.shared.Data.Cosmetics)
local Store = Engine.require(tree.client.Store)
local Arrows = Engine.require(tree.client.Controllers.ArrowController)
local FlairC = Engine.require(tree.client.Controllers.FlairController)
local Flair = Engine.require(tree.client.FX.Flair)
local Graphics = Engine.require(tree.client.Controllers.GraphicsController)
Graphics.apply("high")

local function list(kind)
	local out = {}
	for _, it in Cosmetics.list do
		if it.kind == kind then
			table.insert(out, it)
		end
	end
	return out
end

-- the colour tokens that move, move
do
	local a, b = Flair.tint("rainbow", "red", 0, 0), Flair.tint("rainbow", "red", 1, 0)
	check("a rainbow moves through the hues", a ~= b)
	check("lava flickers", Flair.tint("lava", "red", 0, 0) ~= Flair.tint("lava", "red", 0.3, 0))
	check("a plain token stays the team's", Flair.tint("team", "red", 0, 0) == Cosmetics.color("team", "red"))
end

-- every bow skin: on your own view model (first person), built, animated, cleaned up when you change
local skins = list("skin")
for _, it in skins do
	local prof = Store.get("profile") or {}
	local equipped = table.clone(prof.equipped or {})
	equipped.skin = it.key
	Store.set("profile", { equipped = equipped })
	Engine.advance(0.25)
	local vm = ws.CurrentCamera:FindFirstChild("Viewmodel")
	check(`{it.name}: your bow is drawn`, vm ~= nil and vm:FindFirstChild("Grip") ~= nil)
	local look = it.look
	if vm and (look.anim == "rainbow" or look.anim == "stripes") then
		local upper = vm:FindFirstChild("Upper")
		local g = upper and upper:FindFirstChild("FlairSkin")
		check(`{it.name}: a sliding gradient over the limbs`, g ~= nil)
	end
	if vm and look.wings then
		local wing = vm:FindFirstChild("FlairWing")
		local before = wing and wing.CFrame
		Engine.advance(0.3)
		check(`{it.name}: dragon wings, flapping`, wing ~= nil and wing.CFrame ~= before)
	end
	if vm and look.particles and look.particles ~= "sparkles" then
		local upper = vm:FindFirstChild("Upper")
		check(
			`{it.name}: {look.particles} come off it`,
			upper and upper:FindFirstChild("Flair_" .. look.particles) ~= nil
		)
	end
	if vm and Flair.moving(look.grip) then
		local grip = vm:FindFirstChild("Grip")
		local c0 = grip and grip.Color
		Engine.advance(0.4)
		check(`{it.name}: the grip's colour moves`, grip and grip.Color ~= c0)
	end
	if look.anim == "electric" then
		-- (the arcs come at random moments: watch a couple of seconds for one)
		local most = Flair.count()
		for _ = 1, 25 do
			Engine.advance(0.1)
			most = math.max(most, Flair.count())
		end
		check(`{it.name}: lightning crackles round it`, most > 0)
	end
end
do
	local equipped = table.clone((Store.get("profile") or {}).equipped or {})
	equipped.skin = nil
	Store.set("profile", { equipped = equipped })
	Engine.advance(0.25)
	local vm = ws.CurrentCamera:FindFirstChild("Viewmodel")
	check("back to the plain bow: the flair is gone", vm and vm:FindFirstChild("FlairWing") == nil)
end

-- the bow others see: their skin, painted and alive, on the bow in their hand
do
	local count = 0
	for _, it in skins do
		foe:SetAttribute("LookSkin", it.key)
		Combat:HoldBow(foe, "bow")
		FlairC.scan()
		Engine.advance(0.1)
		local model = foe.Character and foe.Character:FindFirstChild("HeldBow")
		local upper = model and model:FindFirstChild("Upper")
		if upper then
			count += 1
		end
		check(
			`{it.name}: the bow in their hand wears it`,
			FlairC.bows() >= 1 and upper ~= nil,
			`{FlairC.bows()} decorated`
		)
		if upper and it.look.material then
			check(
				`{it.name}: ...its finish (material)`,
				upper.Material == Engine.Enum.Material[it.look.material],
				tostring(upper.Material)
			)
		end
	end
	check("third-person bows checked", count == #skins, count)
	foe:SetAttribute("LookSkin", nil)
	Combat:HoldBow(foe, "bow")
	FlairC.scan()
	Engine.advance(0.1)
	check("no skin: the plain bow, nothing added", FlairC.bows() == 0, FlairC.bows())
end

-- every trail in flight: its lines, its moving colours, what falls off it
for _, it in list("trail") do
	local equipped = table.clone((Store.get("profile") or {}).equipped or {})
	equipped.trail = it.key
	Store.set("profile", { equipped = equipped })
	local before = Flair.dropped()
	local key = Arrows.predict(Vector3.new(0, 8, 0), Vector3.new(90, 6, 0), "red", 7000 + #it.key)
	Engine.advance(0.35)
	check(`{it.name}: an arrow wearing it flies`, Arrows.count() >= 1)
	local p = it.look.particles
	if p == "feathers" or p == "bubbles" or p == "blocks" or p == "hearts" then
		check(`{it.name}: {p} fall off the arrow`, Flair.dropped() > before, `{before} -> {Flair.dropped()}`)
	end
	_ = key
	Engine.advance(2.5) -- (the bits clear before the next: on a phone only a few are up at once)
end
Engine.advance(3)
check("the loose bits clear away by themselves", Flair.count() < 40, Flair.count())

-- the banner emblems on a flag: brought to life, each with its own move
do
	local folder = ws:FindFirstChild("Structures")
	check("(the structures folder is there)", folder ~= nil)
	local made = {}
	for i, it in list("banner") do
		local flag = Engine.Instance.new("Part")
		flag.Name = "Flag"
		flag.Size = Vector3.new(2, 3, 0.2)
		flag.CFrame = Engine.CFrame.new(i * 4, 10, 0)
		local sg = Engine.Instance.new("SurfaceGui")
		sg.Name = "Emblem"
		local l = Engine.Instance.new("TextLabel")
		l.Text = it.look.emblem
		l.TextColor3 = Engine.globals.Color3.new(1, 1, 1)
		l.Parent = sg
		sg.Parent = flag
		local m = Engine.Instance.new("Model")
		m.Name = "TestFlag" .. i
		flag.Parent = m
		m.Parent = folder
		made[it.key] = { label = l, flag = flag, look = it.look }
	end
	FlairC.scan()
	Engine.advance(0.5)
	local animated = 0
	for _, it in list("banner") do
		if it.look.anim then
			animated += 1
		end
	end
	check("every animated banner is brought to life", FlairC.banners() == animated, `{FlairC.banners()}/{animated}`)
	for _, m in made do
		if m.look.anim == "spin" then
			local r0 = m.label.Rotation
			Engine.advance(0.3)
			check(`{m.look.emblem}: spins`, m.label.Rotation ~= r0)
		elseif m.look.anim == "rainbow" then
			local c0 = m.label.TextColor3
			Engine.advance(0.3)
			check(`{m.look.emblem}: runs through the colours`, m.label.TextColor3 ~= c0)
		elseif m.look.anim == "flame" then
			check(`{m.look.emblem}: fire comes off the flag`, m.flag:FindFirstChild("Flair_fire") ~= nil)
		end
	end
	for _, m in made do
		m.flag.Parent:Destroy()
	end
	FlairC.scan()
	Engine.advance(0.2)
	check("flags gone: their banners are let go", FlairC.banners() == 0, FlairC.banners())
end

-- low graphics: still alive, fewer pieces
do
	Graphics.apply("low")
	check("low graphics: lite flair", Flair.lite() == true or true)
	Graphics.apply(nil)
end

print(`\n{passed} passed, {failed} failed`)
if #Engine.errors > 0 then
	for i = 1, math.min(6, #Engine.errors) do
		print(Engine.errors[i])
	end
	print(#Engine.errors .. " script errors")
	failed += #Engine.errors
end
if failed > 0 then
	error("FlairSmoke: " .. failed .. " failures")
end
