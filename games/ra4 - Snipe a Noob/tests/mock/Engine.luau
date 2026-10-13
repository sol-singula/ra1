--[[
A small mock of the Roblox engine, enough to boot this game's scripts outside Studio and drive them from a test
(tests/ServerSmoke.spec.luau, tests/ClientSmoke.spec.luau). It is NOT a faithful engine: physics, rendering,
replication and most properties are absent. Members that the game reads but the mock does not model raise an
error, so typos such as `part.Szie` fail loudly here instead of in Studio.

Needs the luaurun helpers readFile / isDir / listDir / loadChunk (see other/ra2/README.md).
]]
local Engine = { errors = {}, clientLog = {}, side = "server" }

-- Virtual clock and scheduler -------------------------------------------------------------------------------
local clock = 0
local queue = {}

local function report(co, err)
	local msg = debug.traceback(co, tostring(err))
	table.insert(Engine.errors, msg)
	print("ERROR in thread: " .. msg)
end

local function resume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		report(co, err)
	end
end

local function push(at, co, args)
	table.insert(queue, { at = at, co = co, args = args })
end

local task = {}
function task.spawn(f, ...)
	local co = type(f) == "thread" and f or coroutine.create(f)
	resume(co, ...)
	return co
end
function task.defer(f, ...)
	local co = type(f) == "thread" and f or coroutine.create(f)
	push(clock, co, table.pack(...))
	return co
end
function task.delay(t, f, ...)
	local co = coroutine.create(f)
	push(clock + (t or 0), co, table.pack(...))
	return co
end
function task.wait(t)
	local co = coroutine.running()
	push(clock + math.max(t or 0, 1 / 60), co, { n = 0 })
	coroutine.yield()
	return t or 0
end
function task.cancel() end

Engine.task = task

-- Signals -----------------------------------------------------------------------------------------------------
local function newSignal()
	local s = { _conns = {} }
	function s:Connect(fn)
		local c = { Connected = true, fn = fn }
		function c:Disconnect()
			c.Connected = false
		end
		table.insert(s._conns, c)
		return c
	end
	function s:Once(fn)
		local c
		c = s:Connect(function(...)
			c:Disconnect()
			fn(...)
		end)
		return c
	end
	function s:Fire(...)
		for _, c in table.clone(s._conns) do
			if c.Connected then
				task.spawn(c.fn, ...)
			end
		end
	end
	return s
end
Engine.newSignal = newSignal

-- Datatypes ---------------------------------------------------------------------------------------------------
local Vector3 = {}
local V3 = {}
local function v3(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3)
end
V3.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return m > 0 and v3(v.X / m, v.Y / m, v.Z / m) or v3(0, 0, 0)
	elseif k == "Dot" then
		return function(a, b)
			return a.X * b.X + a.Y * b.Y + a.Z * b.Z
		end
	elseif k == "Cross" then
		return function(a, b)
			return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
		end
	elseif k == "Lerp" then
		return function(a, b, t)
			return a + (b - a) * t
		end
	end
	error("Vector3 has no member " .. tostring(k), 2)
end
V3.__add = function(a, b)
	return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3.__sub = function(a, b)
	return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3.__mul = function(a, b)
	if type(a) == "number" then
		return v3(b.X * a, b.Y * a, b.Z * a)
	elseif type(b) == "number" then
		return v3(a.X * b, a.Y * b, a.Z * b)
	end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b)
	if type(b) == "number" then
		return v3(a.X / b, a.Y / b, a.Z / b)
	end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3.__unm = function(a)
	return v3(-a.X, -a.Y, -a.Z)
end
V3.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
V3.__tostring = function(a)
	return string.format("%.2f, %.2f, %.2f", a.X, a.Y, a.Z)
end
V3.__type = "Vector3"
Vector3.new = v3
Vector3.zero = v3(0, 0, 0)
Vector3.one = v3(1, 1, 1)
Vector3.xAxis = v3(1, 0, 0)
Vector3.yAxis = v3(0, 1, 0)
Vector3.zAxis = v3(0, 0, 1)

-- CFrame: rotation rows r (3x3, row-major) + position p
local CF = {}
local CFrame = {}
local function cf(p, r)
	return setmetatable({ p = p, r = r or { 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, CF)
end
local function rotate(r, v)
	return v3(
		r[1] * v.X + r[2] * v.Y + r[3] * v.Z,
		r[4] * v.X + r[5] * v.Y + r[6] * v.Z,
		r[7] * v.X + r[8] * v.Y + r[9] * v.Z
	)
end
local function matmul(a, b)
	local o = {}
	for i = 0, 2 do
		for j = 0, 2 do
			o[i * 3 + j + 1] = a[i * 3 + 1] * b[j + 1] + a[i * 3 + 2] * b[3 + j + 1] + a[i * 3 + 3] * b[6 + j + 1]
		end
	end
	return o
end
local function transpose(r)
	return { r[1], r[4], r[7], r[2], r[5], r[8], r[3], r[6], r[9] }
end
CF.__index = function(c, k)
	if k == "Position" then
		return c.p
	elseif k == "X" then
		return c.p.X
	elseif k == "Y" then
		return c.p.Y
	elseif k == "Z" then
		return c.p.Z
	elseif k == "LookVector" then
		return v3(-c.r[3], -c.r[6], -c.r[9])
	elseif k == "RightVector" then
		return v3(c.r[1], c.r[4], c.r[7])
	elseif k == "UpVector" then
		return v3(c.r[2], c.r[5], c.r[8])
	elseif k == "Rotation" then
		return cf(v3(), c.r)
	elseif k == "Inverse" then
		return function(self)
			local rt = transpose(self.r)
			return cf(-rotate(rt, self.p), rt)
		end
	elseif k == "PointToObjectSpace" then
		return function(self, v)
			return rotate(transpose(self.r), v - self.p)
		end
	elseif k == "PointToWorldSpace" then
		return function(self, v)
			return self * v
		end
	elseif k == "ToObjectSpace" then
		return function(self, other)
			return self:Inverse() * other
		end
	elseif k == "Lerp" then
		return function(self, other, t)
			return cf(self.p + (other.p - self.p) * t, t < 0.5 and self.r or other.r)
		end
	end
	error("CFrame has no member " .. tostring(k), 2)
end
CF.__mul = function(a, b)
	if getmetatable(b) == CF then
		return cf(a.p + rotate(a.r, b.p), matmul(a.r, b.r))
	end
	return a.p + rotate(a.r, b)
end
CF.__add = function(a, v)
	return cf(a.p + v, a.r)
end
CF.__sub = function(a, v)
	return cf(a.p - v, a.r)
end
CF.__type = "CFrame"
function CFrame.new(x, y, z, ...)
	if x == nil then
		return cf(v3())
	elseif type(x) == "table" then
		if y then -- legacy CFrame.new(pos, lookAt)
			return CFrame.lookAt(x, y)
		end
		return cf(x)
	end
	return cf(v3(x, y, z))
end
function CFrame.lookAt(at, target, up)
	up = up or v3(0, 1, 0)
	local f = (target - at).Unit
	if f.Magnitude < 1e-6 then
		return cf(at)
	end
	local right = f:Cross(up).Unit
	if right.Magnitude < 1e-6 then
		right = v3(1, 0, 0)
	end
	local u = right:Cross(f)
	-- columns: right, up, back (-forward)
	return cf(at, { right.X, u.X, -f.X, right.Y, u.Y, -f.Y, right.Z, u.Z, -f.Z })
end
local function rx(a)
	local c, s = math.cos(a), math.sin(a)
	return { 1, 0, 0, 0, c, -s, 0, s, c }
end
local function ry(a)
	local c, s = math.cos(a), math.sin(a)
	return { c, 0, s, 0, 1, 0, -s, 0, c }
end
local function rz(a)
	local c, s = math.cos(a), math.sin(a)
	return { c, -s, 0, s, c, 0, 0, 0, 1 }
end
function CFrame.Angles(a, b, c)
	return cf(v3(), matmul(matmul(rx(a), ry(b)), rz(c)))
end
CFrame.fromEulerAnglesXYZ = CFrame.Angles
CFrame.identity = cf(v3())

local Color3 = {}
local C3 = { __type = "Color3" }
C3.__index = function(c, k)
	if k == "Lerp" then
		return function(a, b, t)
			return setmetatable({ R = a.R + (b.R - a.R) * t, G = a.G + (b.G - a.G) * t, B = a.B + (b.B - a.B) * t }, C3)
		end
	end
	if k == "ToHex" then
		return function(a)
			return string.format(
				"%02X%02X%02X",
				math.floor(a.R * 255 + 0.5),
				math.floor(a.G * 255 + 0.5),
				math.floor(a.B * 255 + 0.5)
			)
		end
	end
	error("Color3 has no member " .. tostring(k), 2)
end
function Color3.new(r, g, b)
	return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3)
end
function Color3.fromHSV(h, sat, v)
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - sat), v * (1 - f * sat), v * (1 - (1 - f) * sat)
	local m = i % 6
	local r, g, b
	if m == 0 then
		r, g, b = v, t, p
	elseif m == 1 then
		r, g, b = q, v, p
	elseif m == 2 then
		r, g, b = p, v, t
	elseif m == 3 then
		r, g, b = p, q, v
	elseif m == 4 then
		r, g, b = t, p, v
	else
		r, g, b = v, p, q
	end
	return Color3.new(r, g, b)
end
function Color3.fromRGB(r, g, b)
	return Color3.new(r / 255, g / 255, b / 255)
end

local ColorSequence = {}
function ColorSequence.new(a, b)
	local keypoints
	if type(a) == "table" and rawget(a, 1) then
		keypoints = a
	else
		keypoints = { { Time = 0, Value = a }, { Time = 1, Value = b or a } }
	end
	return setmetatable({ Keypoints = keypoints }, { __type = "ColorSequence" })
end
local ColorSequenceKeypoint = {
	new = function(t, c)
		return { Time = t, Value = c }
	end,
}

local NumberSequence = {
	new = function(a, b)
		return setmetatable({ Keypoints = { { Time = 0, Value = a }, { Time = 1, Value = b or a } } }, {
			__type = "NumberSequence",
		})
	end,
}
local NumberRange = {
	new = function(a, b)
		return setmetatable({ Min = a, Max = b or a }, { __type = "NumberRange" })
	end,
}

local function dataType(name, fields)
	return setmetatable(fields, { __type = name })
end
local UDim = {
	new = function(s, o)
		return dataType("UDim", { Scale = s, Offset = o })
	end,
}
local UDim2 = {}
function UDim2.new(xs, xo, ys, yo)
	return dataType("UDim2", { X = UDim.new(xs or 0, xo or 0), Y = UDim.new(ys or 0, yo or 0) })
end
function UDim2.fromScale(x, y)
	return UDim2.new(x, 0, y, 0)
end
function UDim2.fromOffset(x, y)
	return UDim2.new(0, x, 0, y)
end
local Vector2 = {
	new = function(x, y)
		return dataType("Vector2", { X = x or 0, Y = y or 0 })
	end,
}
local TweenInfo = {
	new = function(...)
		return dataType("TweenInfo", { args = { ... } })
	end,
}

local enumCache = {}
local Enum = setmetatable({}, {
	__index = function(_, enumType)
		enumCache[enumType] = enumCache[enumType]
			or setmetatable({}, {
				__index = function(t, name)
					local item = setmetatable(
						{ Name = name, EnumType = enumType, Value = name == "High" and 2000 or 0 },
						{ __type = "EnumItem" }
					)
					rawset(t, name, item)
					return item
				end,
			})
		return enumCache[enumType]
	end,
})

local Random = {}
function Random.new(seed)
	local state = math.floor(seed or 1) % 2147483647
	if state <= 0 then
		state = 1
	end
	local r = {}
	local function nxt()
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
	function r:NextNumber(a, b)
		local x = nxt()
		if a then
			return a + (b - a) * x
		end
		return x
	end
	function r:NextInteger(a, b)
		return a + math.floor(nxt() * (b - a + 1))
	end
	return r
end

-- Instances -------------------------------------------------------------------------------------------------
local INST = {}
local ISA = {
	Part = { "BasePart", "PVInstance" },
	WedgePart = { "BasePart", "PVInstance" },
	Model = { "PVInstance" },
	Workspace = { "Model", "PVInstance" },
	Script = { "BaseScript", "LuaSourceContainer" },
	LocalScript = { "Script", "BaseScript", "LuaSourceContainer" },
	ModuleScript = { "LuaSourceContainer" },
	TextLabel = { "GuiObject", "GuiBase2d" },
	TextButton = { "GuiButton", "GuiObject", "GuiBase2d" },
	Frame = { "GuiObject", "GuiBase2d" },
	ScrollingFrame = { "GuiObject", "GuiBase2d" },
	ImageLabel = { "GuiObject", "GuiBase2d" },
	ImageButton = { "GuiButton", "GuiObject", "GuiBase2d" },
	SpawnLocation = { "Part", "BasePart", "PVInstance" },
	ScreenGui = { "LayerCollector", "GuiBase2d" },
	BillboardGui = { "LayerCollector", "GuiBase2d" },
	SurfaceGui = { "LayerCollector", "GuiBase2d" },
}
local SIGNALS = {
	RemoteEvent = { "OnServerEvent", "OnClientEvent" },
	ProximityPrompt = { "Triggered" },
	Players = { "PlayerAdded", "PlayerRemoving" },
	Player = { "CharacterAdded", "Chatted" },
	Tool = { "Activated", "Equipped", "Unequipped" },
	Sound = { "Ended" },
	TextButton = { "Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up", "MouseEnter", "MouseLeave" },
}
local DEFAULTS = {
	Part = function()
		return {
			Size = v3(4, 1, 2),
			CFrame = cf(v3()),
			Transparency = 0,
			Anchored = false,
			CanCollide = true,
			CanQuery = true,
			AssemblyLinearVelocity = v3(),
			Shape = Enum.PartType.Block,
		}
	end,
	SpawnLocation = function()
		return {
			Size = v3(12, 1, 12),
			CFrame = cf(v3()),
			Transparency = 0,
			Anchored = true,
			CanCollide = true,
			CanQuery = true,
			AssemblyLinearVelocity = v3(),
			Shape = Enum.PartType.Block,
		}
	end,
	WedgePart = function()
		return {
			Size = v3(4, 1, 2),
			CFrame = cf(v3()),
			Transparency = 0,
			Anchored = false,
			CanCollide = true,
			CanQuery = true,
			AssemblyLinearVelocity = v3(),
		}
	end,
	Attachment = function()
		return { Position = v3() }
	end,
	Humanoid = function()
		return { WalkSpeed = 16, Health = 100, MaxHealth = 100, JumpPower = 50 }
	end,
	Camera = function()
		return { CFrame = cf(v3(0, 10, 10)), FieldOfView = 70, ViewportSize = Vector2.new(1000, 560) }
	end,
	ProximityPrompt = function()
		return { Enabled = true, ActionText = "Interact", ObjectText = "", HoldDuration = 0 }
	end,
}

local function isInstance(v)
	return type(v) == "table" and getmetatable(v) == INST
end
Engine.isInstance = isInstance

local function isA(inst, cls)
	local c = rawget(inst, "_class")
	if c == cls or cls == "Instance" then
		return true
	end
	for _, parent in ISA[c] or {} do
		if parent == cls then
			return true
		end
	end
	return false
end

local methods = {}
local function children(inst)
	return rawget(inst, "_children")
end

function methods.GetChildren(inst)
	return table.clone(children(inst))
end
function methods.GetDescendants(inst)
	local out = {}
	local function walk(i)
		for _, c in children(i) do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(inst)
	return out
end
function methods.FindFirstChild(inst, name, recursive)
	for _, c in children(inst) do
		if rawget(c, "_props").Name == name then
			return c
		end
	end
	if recursive then
		for _, c in children(inst) do
			local f = methods.FindFirstChild(c, name, true)
			if f then
				return f
			end
		end
	end
	return nil
end
function methods.FindFirstChildOfClass(inst, cls)
	for _, c in children(inst) do
		if rawget(c, "_class") == cls then
			return c
		end
	end
	return nil
end
function methods.FindFirstChildWhichIsA(inst, cls)
	for _, c in children(inst) do
		if isA(c, cls) then
			return c
		end
	end
	return nil
end
function methods.WaitForChild(inst, name, timeout)
	local c = methods.FindFirstChild(inst, name)
	if not c and not timeout then
		error("Infinite yield possible on WaitForChild(" .. name .. ") under " .. rawget(inst, "_props").Name, 2)
	end
	return c
end
function methods.IsA(inst, cls)
	return isA(inst, cls)
end
function methods.IsDescendantOf(inst, ancestor)
	local p = rawget(inst, "_props").Parent
	while p do
		if p == ancestor then
			return true
		end
		p = rawget(p, "_props").Parent
	end
	return false
end
function methods.SetAttribute(inst, k, v)
	rawget(inst, "_attrs")[k] = v
	rawget(inst, "_attrChanged"):Fire(k)
end
function methods.GetAttribute(inst, k)
	return rawget(inst, "_attrs")[k]
end
function methods.GetAttributeChangedSignal(inst, name)
	local sig = newSignal()
	rawget(inst, "_attrChanged"):Connect(function(k)
		if k == name then
			sig:Fire()
		end
	end)
	return sig
end
function methods.GetAttributes(inst)
	return table.clone(rawget(inst, "_attrs"))
end
function methods.Destroy(inst)
	if rawget(inst, "_destroyed") then
		return
	end
	rawset(inst, "_destroyed", true)
	rawget(inst, "_destroying"):Fire()
	for _, c in table.clone(children(inst)) do
		methods.Destroy(c)
	end
	inst.Parent = nil
	Engine.untagAll(inst)
end
function methods.ClearAllChildren(inst)
	for _, c in table.clone(children(inst)) do
		methods.Destroy(c)
	end
end
function methods.GetFullName(inst)
	local names = {}
	local i = inst
	while i do
		table.insert(names, 1, rawget(i, "_props").Name)
		i = rawget(i, "_props").Parent
	end
	return table.concat(names, ".")
end
-- PVInstance
local function parts(inst)
	local out = {}
	if isA(inst, "BasePart") then
		table.insert(out, inst)
	end
	for _, d in methods.GetDescendants(inst) do
		if isA(d, "BasePart") then
			table.insert(out, d)
		end
	end
	return out
end
function methods.GetPivot(inst)
	if isA(inst, "BasePart") then
		return inst.CFrame
	end
	local pp = rawget(inst, "_props").PrimaryPart
	if pp then
		return pp.CFrame
	end
	local list = parts(inst)
	return list[1] and list[1].CFrame or cf(v3())
end
-- Exact inverse of a CFrame (general 3x3 inverse, so tiny rounding in a rotation never grows frame to frame).
local function exactInverse(c)
	local m = c.r
	local a, b, cc, d, e, f, g, h, i = m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9]
	local det = a * (e * i - f * h) - b * (d * i - f * g) + cc * (d * h - e * g)
	local inv = {
		(e * i - f * h) / det,
		(cc * h - b * i) / det,
		(b * f - cc * e) / det,
		(f * g - d * i) / det,
		(a * i - cc * g) / det,
		(cc * d - a * f) / det,
		(d * h - e * g) / det,
		(b * g - a * h) / det,
		(a * e - b * d) / det,
	}
	return cf(-rotate(inv, c.p), inv)
end
function methods.PivotTo(inst, target)
	local pivot = methods.GetPivot(inst)
	local delta = target * exactInverse(pivot)
	local primary = not isA(inst, "BasePart") and rawget(inst, "_props").PrimaryPart
	for _, p in parts(inst) do
		if p == primary or p == inst then
			rawget(p, "_props").CFrame = target -- Roblox puts the pivot exactly where you ask
		else
			rawget(p, "_props").CFrame = delta * rawget(p, "_props").CFrame
		end
	end
end
function methods.ScaleTo() end
function methods.TweenPosition() end
-- Humanoid
function methods.SetStateEnabled() end
-- Player
-- Tools: equipping moves the tool into the character, unequipping back to the Backpack.
local playersService -- set once the Players service exists (below)
function methods.EquipTool(hum, tool)
	local character = hum.Parent
	for _, t in methods.GetChildren(character) do
		if t.ClassName == "Tool" and t ~= tool then
			methods.UnequipTools(hum)
			break
		end
	end
	if tool.Parent ~= character then
		tool.Parent = character
		tool.Equipped:Fire()
	end
end
function methods.UnequipTools(hum)
	local character = hum.Parent
	local owner
	for _, p in methods.GetChildren(playersService) do
		if p.Character == character then
			owner = p
		end
	end
	for _, t in methods.GetChildren(character) do
		if t.ClassName == "Tool" then
			t.Parent = owner and owner:FindFirstChild("Backpack") or nil
			t.Unequipped:Fire()
		end
	end
end
function methods.GetPlayerFromCharacter(_, character)
	for _, p in methods.GetChildren(playersService) do
		if p.Character == character then
			return p
		end
	end
	return nil
end
function methods.Emit() end
function methods.Play(inst)
	inst.IsPlaying = true
	Engine.soundsPlayed = Engine.soundsPlayed or {}
	table.insert(Engine.soundsPlayed, inst.SoundId)
end
function methods.Stop(inst)
	inst.IsPlaying = false
end
function methods.Kick(inst, msg)
	rawset(inst, "_kicked", msg or true)
	print("KICK " .. rawget(inst, "_props").Name .. ": " .. tostring(msg))
end
-- RemoteEvent
function methods.FireClient(inst, player, ...)
	table.insert(
		Engine.clientLog,
		{ at = clock, player = player, name = rawget(inst, "_props").Name, args = table.pack(...) }
	)
	-- only the local player's client is running: events for other players go nowhere
	if
		(Engine.side == "client" or Engine.clientEnabled)
		and (Engine.localPlayer == nil or player == Engine.localPlayer)
	then
		rawget(inst, "_signals").OnClientEvent:Fire(...)
	end
end
function methods.FireAllClients(inst, ...)
	table.insert(
		Engine.clientLog,
		{ at = clock, player = "all", name = rawget(inst, "_props").Name, args = table.pack(...) }
	)
	if Engine.side == "client" or Engine.clientEnabled then
		rawget(inst, "_signals").OnClientEvent:Fire(...)
	end
end
function methods.FireServer(inst, ...)
	table.insert(Engine.clientLog, { player = "server", name = rawget(inst, "_props").Name, args = table.pack(...) })
	rawget(inst, "_signals").OnServerEvent:Fire(Engine.localPlayer, ...)
end
-- Players
Engine.friends = {} -- ["a:b"] = true (both orders)
function methods.GetPlayerByUserId(inst, id)
	for _, c in children(inst) do
		if rawget(c, "_class") == "Player" and rawget(c, "_props").UserId == id then
			return c
		end
	end
	return nil
end
function methods.GetNameFromUserIdAsync(_, id)
	return "User" .. tostring(id)
end
function methods.IsFriendsWith(inst, id)
	return Engine.friends[rawget(inst, "_props").UserId .. ":" .. id] == true
end
function methods.GetJoinData(inst)
	return { LaunchData = rawget(inst, "_props")._launchData }
end
function Engine.makeFriends(a, b)
	Engine.friends[a.UserId .. ":" .. b.UserId] = true
	Engine.friends[b.UserId .. ":" .. a.UserId] = true
end
function methods.GetPlayers(inst)
	local out = {}
	for _, c in children(inst) do
		if rawget(c, "_class") == "Player" then
			table.insert(out, c)
		end
	end
	return out
end

local function setParent(inst, parent)
	local props = rawget(inst, "_props")
	local old = props.Parent
	if old == parent then
		return
	end
	if rawget(inst, "_destroyed") and parent ~= nil then
		error("The Parent property of " .. props.Name .. " is locked (destroyed)", 3)
	end
	if old then
		local list = children(old)
		local i = table.find(list, inst)
		if i then
			table.remove(list, i)
		end
		local cr = rawget(old, "_childRemoved")
		if cr then
			cr:Fire(inst)
		end
	end
	props.Parent = parent
	if parent then
		table.insert(children(parent), inst)
		local ca = rawget(parent, "_childAdded")
		if ca then
			ca:Fire(inst)
		end
	end
end

INST.__index = function(inst, k)
	local m = methods[k]
	if m then
		return m
	end
	local props = rawget(inst, "_props")
	local v = props[k]
	if v ~= nil then
		return v
	end
	local sig = rawget(inst, "_signals")[k]
	if sig then
		return sig
	end
	if k == "Position" and props.CFrame then
		return props.CFrame.Position
	elseif k == "WorldCFrame" and rawget(inst, "_class") == "Attachment" then
		return props.Parent.CFrame * CFrame.new(props.Position)
	elseif k == "WorldPosition" and rawget(inst, "_class") == "Attachment" then
		return (props.Parent.CFrame * CFrame.new(props.Position)).Position
	elseif k == "Destroying" then
		return rawget(inst, "_destroying")
	elseif k == "AttributeChanged" then
		return rawget(inst, "_attrChanged")
	elseif k == "ChildAdded" then
		local s = rawget(inst, "_childAdded") or newSignal()
		rawset(inst, "_childAdded", s)
		return s
	elseif k == "ChildRemoved" then
		local s = rawget(inst, "_childRemoved") or newSignal()
		rawset(inst, "_childRemoved", s)
		return s
	elseif k == "ClassName" then
		return rawget(inst, "_class")
	elseif k == "Parent" or k == "PrimaryPart" or k == "Character" or k == "Adornee" then
		return nil
	end
	local child = methods.FindFirstChild(inst, k)
	if child then
		return child
	end
	-- real Roblox errors on any name that isn't a property or child; Roblox properties are PascalCase, so a
	-- lowercase name (like a Lua table field: f.robot, f.zone) is never valid on an Instance
	local first = string.sub(tostring(k), 1, 1)
	if
		first ~= string.upper(first)
		or rawget(inst, "_class") == "Folder"
		or rawget(inst, "_class") == "Model"
		or isA(inst, "BasePart")
	then
		error(k .. " is not a valid member of " .. rawget(inst, "_class") .. ' "' .. props.Name .. '"', 2)
	end
	return nil -- GUI and misc classes: unset properties read as nil in the mock
end
INST.__newindex = function(inst, k, v)
	if (k == "Part0" or k == "Part1") and rawget(inst, "_class") == "WeldConstraint" then
		local props = rawget(inst, "_props")
		props[k] = v
		-- a WeldConstraint keeps the parts' relative offset from the moment both are set
		if props.Part0 and props.Part1 and not rawget(inst, "_offset") then
			rawset(inst, "_offset", props.Part0.CFrame:Inverse() * props.Part1.CFrame)
			table.insert(Engine.welds, inst)
		end
		return
	end
	if k == "Parent" then
		setParent(inst, v)
	elseif k == "Position" and rawget(inst, "_props").CFrame and rawget(inst, "_class") ~= "Attachment" then
		local props = rawget(inst, "_props")
		props.CFrame = cf(v, props.CFrame.r)
	else
		rawget(inst, "_props")[k] = v
	end
end
INST.__tostring = function(inst)
	return rawget(inst, "_props").Name
end

local Instance = {}
function Instance.new(className, parent)
	local props = DEFAULTS[className] and DEFAULTS[className]() or {}
	props.Name = className
	local signals = {}
	for _, s in SIGNALS[className] or {} do
		signals[s] = newSignal()
	end
	local inst = setmetatable({
		_class = className,
		_props = props,
		_children = {},
		_attrs = {},
		_attrChanged = newSignal(),
		_destroying = newSignal(),
		_signals = signals,
	}, INST)
	if parent then
		inst.Parent = parent
	end
	return inst
end
Engine.Instance = Instance

-- Services ----------------------------------------------------------------------------------------------------
local game = Instance.new("DataModel")
game.Name = "Game"
game.JobId = ""
local services = {}
local closeHandlers = {}
function methods.GetService(_, name)
	return services[name]
end
function methods.BindToClose(_, fn)
	table.insert(closeHandlers, fn)
end
Engine.closeHandlers = closeHandlers

local function service(name, className)
	local s = Instance.new(className or name)
	s.Name = name
	s.Parent = game
	services[name] = s
	return s
end
local workspace = service("Workspace")
workspace.CurrentCamera = Instance.new("Camera", workspace)
function methods.GetServerTimeNow()
	return clock
end

-- Raycasting: a ray against every queryable Part (oriented box) and Ball (sphere) under the workspace, with
-- RaycastParams filters (Exclude by default, or Include). Returns { Instance, Position, Normal, Distance } or nil.
local RaycastParams = {}
function RaycastParams.new()
	return setmetatable(
		{ FilterDescendantsInstances = {}, FilterType = Enum.RaycastFilterType.Exclude, IgnoreWater = true },
		{ __type = "RaycastParams" }
	)
end
Engine.RaycastParams = RaycastParams
local function underAny(inst, list)
	for _, root in list do
		if inst == root or methods.IsDescendantOf(inst, root) then
			return true
		end
	end
	return false
end
local function rayBox(part, origin, dir)
	local c = part.CFrame
	local o = c:PointToObjectSpace(origin)
	local d = c:PointToObjectSpace(origin + dir) - o
	local h = part.Size * 0.5
	local tmin, tmax = 0, 1
	local nAxis, nSign = nil, 0
	for _, axis in { "X", "Y", "Z" } do
		local oa, da, ha = o[axis], d[axis], h[axis]
		if math.abs(da) < 1e-9 then
			if oa < -ha or oa > ha then
				return nil
			end
		else
			local t1, t2 = (-ha - oa) / da, (ha - oa) / da
			local s = -1
			if t1 > t2 then
				t1, t2 = t2, t1
				s = 1
			end
			if t1 > tmin then
				tmin, nAxis, nSign = t1, axis, s
			end
			tmax = math.min(tmax, t2)
			if tmin > tmax then
				return nil
			end
		end
	end
	local local_n = v3(nAxis == "X" and nSign or 0, nAxis == "Y" and nSign or 0, nAxis == "Z" and nSign or 0)
	return tmin, (c * local_n) - c.p
end
local function raySphere(center, radius, origin, dir)
	local m = origin - center
	local a = dir:Dot(dir)
	local b = m:Dot(dir)
	local cc = m:Dot(m) - radius * radius
	if cc > 0 and b > 0 then
		return nil
	end
	local disc = b * b - a * cc
	if disc < 0 then
		return nil
	end
	local t = math.max(0, (-b - math.sqrt(disc)) / a)
	if t > 1 then
		return nil
	end
	return t, ((origin + dir * t) - center).Unit
end
function methods.Raycast(ws, origin, dir, params)
	params = params or RaycastParams.new()
	local include = params.FilterType == Enum.RaycastFilterType.Include
	local list = params.FilterDescendantsInstances or {}
	local best, bestT, bestN
	for _, inst in methods.GetDescendants(ws) do
		local props = rawget(inst, "_props")
		if isA(inst, "BasePart") and props.CanQuery ~= false and props.Size and props.CFrame then
			local keep = underAny(inst, list)
			if include == keep then
				local t, n
				if props.Shape == Enum.PartType.Ball then
					t, n = raySphere(inst.CFrame.p, math.min(inst.Size.X, inst.Size.Y, inst.Size.Z) / 2, origin, dir)
				else
					t, n = rayBox(inst, origin, dir)
				end
				if t and (not bestT or t < bestT) then
					best, bestT, bestN = inst, t, n
				end
			end
		end
	end
	if not best then
		return nil
	end
	return { Instance = best, Position = origin + dir * bestT, Normal = bestN, Distance = dir.Magnitude * bestT }
end
local Players = service("Players")
playersService = Players
service("ReplicatedStorage", "Folder")
service("ServerScriptService", "Folder")
service("ServerStorage", "Folder")
service("StarterPlayer", "Folder")
service("Lighting")
service("SoundService")

-- RunService
local RunService = service("RunService")
rawset(RunService, "_signals", { Heartbeat = newSignal(), RenderStepped = newSignal(), Stepped = newSignal() })
function methods.IsServer()
	return Engine.side == "server"
end
function methods.IsClient()
	return Engine.side == "client"
end
function methods.IsStudio()
	return true
end

-- CollectionService
local CollectionService = service("CollectionService")
local tags, added, removed = {}, {}, {}
local function tagSignal(map, tag)
	map[tag] = map[tag] or newSignal()
	return map[tag]
end
function methods.AddTag(_, inst, tag)
	tags[tag] = tags[tag] or {}
	if not table.find(tags[tag], inst) then
		table.insert(tags[tag], inst)
		tagSignal(added, tag):Fire(inst)
	end
end
function methods.GetTagged(_, tag)
	return table.clone(tags[tag] or {})
end
function methods.GetInstanceAddedSignal(_, tag)
	return tagSignal(added, tag)
end
function methods.GetInstanceRemovedSignal(_, tag)
	return tagSignal(removed, tag)
end
function Engine.untagAll(inst)
	for tag, list in tags do
		local i = table.find(list, inst)
		if i then
			table.remove(list, i)
			tagSignal(removed, tag):Fire(inst)
		end
	end
end
_ = CollectionService

-- HttpService (JSON)
local HttpService = service("HttpService")
local function encode(v)
	local t = type(v)
	if t == "nil" then
		return "null"
	elseif t == "boolean" or t == "number" then
		return tostring(v)
	elseif t == "string" then
		return '"' .. v:gsub('[%c"\\]', function(c)
			return string.format("\\u%04x", string.byte(c))
		end) .. '"'
	elseif t == "table" then
		if #v > 0 or next(v) == nil then
			local out = {}
			for _, x in ipairs(v) do
				table.insert(out, encode(x))
			end
			return "[" .. table.concat(out, ",") .. "]"
		end
		local out = {}
		for k, x in v do
			table.insert(out, encode(tostring(k)) .. ":" .. encode(x))
		end
		return "{" .. table.concat(out, ",") .. "}"
	end
	error("cannot JSON-encode " .. t)
end
local function decode(s)
	local i = 1
	local function ws()
		i = s:find("[^%s]", i) or #s + 1
	end
	local value
	local function str()
		local out = {}
		i += 1
		while true do
			local c = s:sub(i, i)
			if c == '"' then
				i += 1
				return table.concat(out)
			elseif c == "\\" then
				local n = s:sub(i + 1, i + 1)
				if n == "u" then
					table.insert(out, utf8.char(tonumber(s:sub(i + 2, i + 5), 16)))
					i += 6
				else
					table.insert(out, ({ n = "\n", t = "\t", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" })[n] or n)
					i += 2
				end
			else
				table.insert(out, c)
				i += 1
			end
		end
	end
	function value()
		ws()
		local c = s:sub(i, i)
		if c == "{" then
			local o = {}
			i += 1
			ws()
			if s:sub(i, i) == "}" then
				i += 1
				return o
			end
			while true do
				ws()
				local k = str()
				ws()
				i += 1 -- :
				o[k] = value()
				ws()
				local d = s:sub(i, i)
				i += 1
				if d == "}" then
					return o
				end
			end
		elseif c == "[" then
			local a = {}
			i += 1
			ws()
			if s:sub(i, i) == "]" then
				i += 1
				return a
			end
			while true do
				table.insert(a, value())
				ws()
				local d = s:sub(i, i)
				i += 1
				if d == "]" then
					return a
				end
			end
		elseif c == '"' then
			return str()
		elseif s:sub(i, i + 3) == "true" then
			i += 4
			return true
		elseif s:sub(i, i + 4) == "false" then
			i += 5
			return false
		elseif s:sub(i, i + 3) == "null" then
			i += 4
			return nil
		end
		local num = s:match("^-?[%d%.eE+-]+", i)
		i += #num
		return tonumber(num)
	end
	return value()
end
function methods.JSONEncode(_, v)
	return encode(v)
end
function methods.JSONDecode(_, s)
	return decode(s)
end
_ = HttpService

-- DataStoreService (in memory)
local DataStoreService = service("DataStoreService")
Engine.dataStores = {}
local function deepCopy(v)
	if type(v) ~= "table" then
		return v
	end
	local o = {}
	for k, x in v do
		o[k] = deepCopy(x)
	end
	return o
end
function methods.GetDataStore(_, name)
	Engine.dataStores[name] = Engine.dataStores[name] or {}
	local data = Engine.dataStores[name]
	if Engine.dataStoreFails then
		error("Studio access to APIs is not allowed")
	end
	return {
		UpdateAsync = function(_, key, fn)
			if Engine.dataStoreFails then
				error("Studio access to APIs is not allowed")
			end
			local new = fn(deepCopy(data[key]))
			if new ~= nil then
				-- DataStores only take plain data: catch Instances, Color3 etc. sneaking into saves
				local function check(x, path)
					if type(x) == "table" then
						if getmetatable(x) then
							error("non-serializable value in save at " .. path)
						end
						for k, y in x do
							check(y, path .. "." .. tostring(k))
						end
					elseif type(x) == "function" or type(x) == "userdata" then
						error("non-serializable value in save at " .. path)
					end
				end
				check(new, key)
				data[key] = deepCopy(new)
			end
			return new
		end,
	}
end
Engine.orderedStores = {}
function methods.GetOrderedDataStore(_, name)
	if Engine.dataStoreFails then
		error("Studio access to APIs is not allowed")
	end
	Engine.orderedStores[name] = Engine.orderedStores[name] or {}
	local data = Engine.orderedStores[name]
	return {
		SetAsync = function(_, key, value)
			assert(type(value) == "number" and value == math.floor(value), "OrderedDataStore needs integers")
			data[key] = value
		end,
		GetSortedAsync = function(_, ascending, pageSize)
			local list = {}
			for k, v in data do
				table.insert(list, { key = k, value = v })
			end
			table.sort(list, function(a, b)
				if ascending then
					return a.value < b.value
				end
				return a.value > b.value
			end)
			local page = {}
			for i = 1, math.min(pageSize, #list) do
				page[i] = list[i]
			end
			return {
				GetCurrentPage = function()
					return page
				end,
			}
		end,
	}
end
_ = DataStoreService

-- MarketplaceService
local MarketplaceService = service("MarketplaceService")
rawset(MarketplaceService, "_signals", { PromptGamePassPurchaseFinished = newSignal() })
Engine.prompted = {}
function methods.UserOwnsGamePassAsync(_, userId, passId)
	return Engine.ownedPasses ~= nil and Engine.ownedPasses[userId .. ":" .. passId] == true
end
-- With autoBuy on (the default), every prompt is bought at once, like a player pressing Buy.
Engine.autoBuy = true
local receiptCount = 0
function methods.PromptGamePassPurchase(self, player, id)
	table.insert(Engine.prompted, { player = player, kind = "pass", id = id })
	if Engine.autoBuy then
		Engine.ownedPasses = Engine.ownedPasses or {}
		Engine.ownedPasses[player.UserId .. ":" .. id] = true
		rawget(self, "_signals").PromptGamePassPurchaseFinished:Fire(player, id, true)
	end
end
function methods.PromptProductPurchase(self, player, id)
	table.insert(Engine.prompted, { player = player, kind = "product", id = id })
	local process = self.ProcessReceipt
	if Engine.autoBuy and process then
		receiptCount += 1
		process({ PlayerId = player.UserId, ProductId = id, PurchaseId = "R" .. receiptCount, CurrencySpent = 0 })
	end
end
function methods.PromptPurchase(_, player, assetId)
	table.insert(Engine.prompted, { player = player, kind = "asset", id = assetId })
end
-- product info for booth items: tests set Engine.assets[id] = { Name, AssetTypeId, PriceInRobux, Creator = { Id } }
Engine.assets = {}
function methods.GetProductInfo(_, assetId)
	local info = Engine.assets[assetId]
	if not info then
		error("asset not found")
	end
	return info
end
local PolicyService = service("PolicyService")
Engine.policy = { IsPaidItemTradingAllowed = true, ArePaidRandomItemsRestricted = false }
function methods.GetPolicyInfoForPlayerAsync(_, _player)
	return Engine.policy
end
_ = PolicyService
local TextService = service("TextService")
function methods.FilterStringAsync(_, text)
	return {
		GetNonChatStringForBroadcastAsync = function()
			return (string.gsub(text, "badword", "####"))
		end,
	}
end
_ = TextService
local SocialService = service("SocialService")
Engine.invites = 0
function methods.PromptGameInvite()
	Engine.invites += 1
end
function methods.CanSendGameInviteAsync()
	return true
end
_ = SocialService
local StarterGui = service("StarterGui")
function methods.SetCore() end
function methods.SetCoreGuiEnabled() end
_ = StarterGui

-- Client-only services
local TweenService = service("TweenService")
function methods.Create()
	return { Play = function() end, Cancel = function() end, Completed = newSignal() }
end
_ = TweenService
local ContextActionService = service("ContextActionService")
Engine.actions = {}
function methods.BindAction(_, name, fn)
	Engine.actions[name] = fn
end
function methods.BindActionAtPriority(_, name, fn)
	Engine.actions[name] = fn
end
function methods.UnbindAction(_, name)
	Engine.actions[name] = nil
end
_ = ContextActionService
local UserInputService = service("UserInputService")
rawset(
	UserInputService,
	"_signals",
	{ InputBegan = newSignal(), InputEnded = newSignal(), LastInputTypeChanged = newSignal() }
)
Engine.lastInputType = Enum.UserInputType.Touch
function methods.GetLastInputType()
	return Engine.lastInputType
end
-- switch the player's input (fires LastInputTypeChanged like Roblox does)
function Engine.setInput(inputType)
	Engine.lastInputType = inputType
	UserInputService.LastInputTypeChanged:Fire(inputType)
end
-- GuiService: the player's accessibility settings and gamepad selection
local GuiService = service("GuiService")
GuiService.ReducedMotionEnabled = false
GuiService.PreferredTransparency = 1
GuiService.PreferredTextSize = Enum.PreferredTextSize.Medium
local propSignals = setmetatable({}, { __mode = "k" })
function methods.GetPropertyChangedSignal(inst, prop)
	propSignals[inst] = propSignals[inst] or {}
	propSignals[inst][prop] = propSignals[inst][prop] or newSignal()
	return propSignals[inst][prop]
end
-- change a property and fire its GetPropertyChangedSignal (the mock doesn't do this on plain assignment)
function Engine.setProperty(inst, prop, value)
	inst[prop] = value
	local sig = propSignals[inst] and propSignals[inst][prop]
	if sig then
		sig:Fire()
	end
end

-- Players helpers ---------------------------------------------------------------------------------------------
local nextUserId = 1000
-- A blocky stand-in avatar (Roblox would load the player's own avatar). Body parts are welded to the root.
local AVATAR = {
	{ "Head", v3(1.25, 1.25, 1.25), v3(0, 1.65, 0), "skin" },
	{ "UpperTorso", v3(2, 2, 1), v3(0, 0, 0), "shirt" },
	{ "LeftUpperArm", v3(1, 1.6, 1), v3(-1.5, 0.2, 0), "shirt" },
	{ "RightUpperArm", v3(1, 1.6, 1), v3(1.5, 0.2, 0), "shirt" },
	{ "LeftHand", v3(0.9, 0.5, 0.9), v3(-1.5, -0.85, 0), "skin" },
	{ "RightHand", v3(0.9, 0.5, 0.9), v3(1.5, -0.85, 0), "skin" },
	{ "LeftUpperLeg", v3(0.95, 2, 1), v3(-0.5, -2, 0), "pants" },
	{ "RightUpperLeg", v3(0.95, 2, 1), v3(0.5, -2, 0), "pants" },
	{ "EyeL", v3(0.18, 0.28, 0.05), v3(-0.25, 1.75, -0.64), "ink" },
	{ "EyeR", v3(0.18, 0.28, 0.05), v3(0.25, 1.75, -0.64), "ink" },
	{ "Smile", v3(0.5, 0.1, 0.05), v3(0, 1.38, -0.64), "ink" },
}
local AVATAR_COLORS = {
	skin = { 234, 184, 146 },
	shirt = { 58, 128, 214 },
	pants = { 44, 48, 66 },
	ink = { 27, 29, 43 },
}

function Engine.makeCharacter(player)
	local character = Instance.new("Model")
	character.Name = player.Name
	local hrp = Instance.new("Part", character)
	hrp.Name = "HumanoidRootPart"
	hrp.Size = v3(2, 2, 1)
	hrp.Transparency = 1
	hrp.CFrame = CFrame.new(0, 3, 0)
	for _, spec in AVATAR do
		local part = Instance.new("Part", character)
		part.Name = spec[1]
		part.Size = spec[2]
		part.CFrame = hrp.CFrame * CFrame.new(spec[3])
		local c = AVATAR_COLORS[spec[4]]
		part.Color = Color3.fromRGB(c[1], c[2], c[3])
		part.Material = Enum.Material.SmoothPlastic
		local w = Instance.new("WeldConstraint")
		w.Part0 = hrp
		w.Part1 = part
		w.Parent = part
	end
	local hum = Instance.new("Humanoid", character)
	hum.Name = "Humanoid"
	character.PrimaryPart = hrp
	character.Parent = workspace
	player.Character = character
	player.CharacterAdded:Fire(character)
	return character
end

-- Players:CreateHumanoidModelFromUserId: a stand-in avatar (the same blocky body), not parented
function methods.CreateHumanoidModelFromUserId(_, userId)
	local character = Instance.new("Model")
	character.Name = "Avatar" .. tostring(userId)
	local hrp = Instance.new("Part", character)
	hrp.Name = "HumanoidRootPart"
	hrp.Size = v3(2, 2, 1)
	hrp.Transparency = 1
	hrp.CFrame = CFrame.new(0, 3, 0)
	for _, spec in AVATAR do
		local part = Instance.new("Part", character)
		part.Name = spec[1]
		part.Size = spec[2]
		part.CFrame = hrp.CFrame * CFrame.new(spec[3])
		local c = AVATAR_COLORS[spec[4]]
		part.Color = Color3.fromRGB(c[1], c[2], c[3])
		part.Material = Enum.Material.SmoothPlastic
		local w = Instance.new("WeldConstraint")
		w.Part0 = hrp
		w.Part1 = part
		w.Parent = part
	end
	local hum = Instance.new("Humanoid", character)
	hum.Name = "Humanoid"
	hum.HipHeight = 2
	character.PrimaryPart = hrp
	return character
end

function Engine.addPlayer(name, userId, launchData)
	nextUserId += 1
	local p = Instance.new("Player")
	p.Name = name
	p.DisplayName = name
	p.UserId = userId or nextUserId
	p._launchData = launchData
	local pg = Instance.new("Folder", p)
	pg.Name = "PlayerGui"
	local backpack = Instance.new("Backpack", p)
	backpack.Name = "Backpack"
	p.Parent = Players
	Players.PlayerAdded:Fire(p)
	return p
end

function Engine.removePlayer(p)
	Players.PlayerRemoving:Fire(p)
	p.Parent = nil
end

function Engine.moveTo(player, position, lookAt)
	local hrp = player.Character.HumanoidRootPart
	if lookAt then
		hrp.CFrame = CFrame.lookAt(position, v3(lookAt.X, position.Y, lookAt.Z))
	else
		hrp.CFrame = CFrame.new(position)
	end
	Engine.resolveWelds()
end

-- Move every welded part to keep its offset from Part0 (what the physics engine does in Roblox).
Engine.welds = {}
function Engine.resolveWelds()
	local keep = {}
	for _, w in Engine.welds do
		local p0, p1 = rawget(w, "_props").Part0, rawget(w, "_props").Part1
		if not rawget(w, "_destroyed") and not rawget(p1, "_destroyed") and not rawget(p0, "_destroyed") then
			rawget(p1, "_props").CFrame = p0.CFrame * rawget(w, "_offset")
			table.insert(keep, w)
		end
	end
	Engine.welds = keep
end

-- Time --------------------------------------------------------------------------------------------------------
function Engine.now()
	return clock
end

function Engine.advance(seconds, step)
	step = step or 1 / 30
	local target = clock + seconds
	while clock < target - 1e-9 do
		clock = math.min(target, clock + step)
		RunService.Heartbeat:Fire(step)
		if Engine.side == "client" or Engine.clientEnabled then
			RunService.RenderStepped:Fire(step)
		end
		local guard = 0
		while true do
			table.sort(queue, function(a, b)
				return a.at < b.at
			end)
			local item = queue[1]
			if not item or item.at > clock then
				break
			end
			table.remove(queue, 1)
			if coroutine.status(item.co) == "suspended" then
				resume(item.co, table.unpack(item.args, 1, item.args.n))
			end
			guard += 1
			if guard > 100000 then
				error("scheduler runaway")
			end
		end
	end
end

-- Globals and require -------------------------------------------------------------------------------------
local osMock = setmetatable({
	clock = function()
		return clock
	end,
	time = function()
		return 1700000000 + math.floor(clock)
	end,
}, { __index = os })

local function typeofMock(v)
	if isInstance(v) then
		return "Instance"
	end
	local mt = getmetatable(v)
	if type(mt) == "table" and mt.__type then
		return mt.__type
	end
	return type(v)
end

local cache = {}
local globals
local function requireMock(target)
	if type(target) == "string" then
		error("require by path is not supported in the mock: " .. target)
	end
	local key = target
	if cache[key] ~= nil then
		return cache[key]
	end
	local path = rawget(target, "_source")
	assert(path, "require of a non-module: " .. tostring(target))
	local env = setmetatable({ script = target }, { __index = globals })
	local fn = loadChunk(readFile(path), path, env)
	local result = fn()
	cache[key] = result
	return result
end

globals = setmetatable({
	game = game,
	workspace = workspace,
	Instance = Instance,
	Vector3 = Vector3,
	Vector2 = Vector2,
	CFrame = CFrame,
	Color3 = Color3,
	ColorSequence = ColorSequence,
	ColorSequenceKeypoint = ColorSequenceKeypoint,
	NumberSequence = NumberSequence,
	NumberRange = NumberRange,
	UDim = UDim,
	UDim2 = UDim2,
	TweenInfo = TweenInfo,
	Enum = Enum,
	Random = Random,
	RaycastParams = RaycastParams,
	task = task,
	typeof = typeofMock,
	warn = function(...)
		local parts = {}
		for i = 1, select("#", ...) do
			parts[i] = tostring((select(i, ...)))
		end
		local msg = table.concat(parts, " ")
		print("WARN " .. msg)
		table.insert(Engine.warnings, msg)
	end,
	tick = function()
		return clock
	end,
	os = osMock,
	require = requireMock,
}, { __index = _G })
Engine.warnings = {}
Engine.globals = globals
Engine.game = game
Engine.workspace = workspace
Engine.Players = Players
Engine.Vector3 = Vector3
Engine.CFrame = CFrame
Engine.require = requireMock
Engine.Enum = Enum

function Engine.clearRequireCache()
	table.clear(cache)
end

-- Build the DataModel from the Rojo project folders.
local function mount(dir, parent)
	for _, name in listDir(dir) do
		local path = dir .. "/" .. name
		if isDir(path) then
			local folder = Instance.new("Folder", parent)
			folder.Name = name
			mount(path, folder)
		elseif name:sub(-4) == ".lua" or name:sub(-5) == ".luau" then
			local base = name:gsub("%.luau?$", "")
			local cls = "ModuleScript"
			if base:sub(-7) == ".server" then
				cls, base = "Script", base:sub(1, -8)
			elseif base:sub(-7) == ".client" then
				cls, base = "LocalScript", base:sub(1, -8)
			end
			local inst = Instance.new(cls, parent)
			inst.Name = base
			rawset(inst, "_source", path)
		end
	end
end

function Engine.mountProject(root)
	local rs = services.ReplicatedStorage
	local shared = Instance.new("Folder", rs)
	shared.Name = "Shared"
	mount(root .. "/src/shared", shared)
	local sss = services.ServerScriptService
	local server = Instance.new("Folder", sss)
	server.Name = "Server"
	mount(root .. "/src/server", server)
	local sps = Instance.new("Folder", services.StarterPlayer)
	sps.Name = "StarterPlayerScripts"
	local client = Instance.new("Folder", sps)
	client.Name = "Client"
	mount(root .. "/src/client", client)
	return { shared = shared, server = server, client = client }
end

function Engine.runScript(scriptInst)
	local env = setmetatable({ script = scriptInst }, { __index = globals })
	local fn = loadChunk(readFile(rawget(scriptInst, "_source")), rawget(scriptInst, "_source"), env)
	task.spawn(fn)
end

-- Helpers for tests ---------------------------------------------------------------------------------------------
function Engine.lastClientEvent(name, player)
	for i = #Engine.clientLog, 1, -1 do
		local e = Engine.clientLog[i]
		if e.name == name and (player == nil or e.player == player or e.player == "all") then
			return e
		end
	end
	return nil
end

function Engine.countClientEvents(name)
	local n = 0
	for _, e in Engine.clientLog do
		if e.name == name then
			n += 1
		end
	end
	return n
end

function Engine.remote(name)
	return services.ReplicatedStorage:FindFirstChild("Net"):FindFirstChild(name)
end

function Engine.fireServer(player, name, ...)
	Engine.remote(name).OnServerEvent:Fire(player, ...)
end

function Engine.prompts(inst)
	local out = {}
	for _, d in methods.GetDescendants(inst) do
		if rawget(d, "_class") == "ProximityPrompt" then
			table.insert(out, d)
		end
	end
	return out
end

return Engine
