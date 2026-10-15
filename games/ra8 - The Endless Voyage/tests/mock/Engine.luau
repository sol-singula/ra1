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
	elseif k == "VectorToWorldSpace" then
		return function(self, v)
			return rotate(self.r, v)
		end
	elseif k == "VectorToObjectSpace" then
		return function(self, v)
			return rotate(transpose(self.r), v)
		end
	elseif k == "ToObjectSpace" then
		return function(self, other)
			return self:Inverse() * other
		end
	elseif k == "ToWorldSpace" then
		return function(self, other)
			return self * other
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
-- columns: the right (X), up (Y) and back (Z) vectors
function CFrame.fromMatrix(pos, vx, vy, vz)
	vz = vz or vx:Cross(vy)
	return cf(pos, { vx.X, vy.X, vz.X, vx.Y, vy.Y, vz.Y, vx.Z, vy.Z, vz.Z })
end
function CFrame.fromAxisAngle(axis, angle)
	local u = axis.Unit
	local c, sn = math.cos(angle), math.sin(angle)
	local t = 1 - c
	local x, y, z = u.X, u.Y, u.Z
	return cf(v3(), {
		t * x * x + c,
		t * x * y - sn * z,
		t * x * z + sn * y,
		t * x * y + sn * z,
		t * y * y + c,
		t * y * z - sn * x,
		t * x * z - sn * y,
		t * y * z + sn * x,
		t * z * z + c,
	})
end

local Color3 = {}
local C3 = { __type = "Color3" }
C3.__index = function(c, k)
	if k == "Lerp" then
		return function(a, b, t)
			return setmetatable({ R = a.R + (b.R - a.R) * t, G = a.G + (b.G - a.G) * t, B = a.B + (b.B - a.B) * t }, C3)
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

local NumberSequenceKeypoint = {
	new = function(t, v)
		return setmetatable({ Time = t, Value = v }, { __type = "NumberSequenceKeypoint" })
	end,
}
local NumberSequence = {
	new = function(a, b)
		if type(a) == "table" then -- a list of NumberSequenceKeypoints
			return setmetatable({ Keypoints = a }, { __type = "NumberSequence" })
		end
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
local BrickColor = {
	new = function(name)
		return setmetatable({ Name = tostring(name) }, { __type = "BrickColor" })
	end,
}
-- Region3: a box from its min and max corners (terrain voxel reads and writes)
local Region3 = {}
function Region3.new(lo, hi)
	local r = dataType("Region3", {
		Min = lo,
		Max = hi,
		Size = hi - lo,
		CFrame = CFrame.new((lo + hi) / 2),
	})
	r.ExpandToGrid = function(self, res)
		local a, b = self.Min, self.Max
		return Region3.new(
			Vector3.new(math.floor(a.X / res) * res, math.floor(a.Y / res) * res, math.floor(a.Z / res) * res),
			Vector3.new(math.ceil(b.X / res) * res, math.ceil(b.Y / res) * res, math.ceil(b.Z / res) * res)
		)
	end
	return r
end
-- Vector2: the same maths as Vector3 (paths and layouts in (x, z) use it)
local V2 = {}
local function v2(x, y)
	return setmetatable({ X = x or 0, Y = y or 0 }, V2)
end
V2.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y)
		return m > 0 and v2(v.X / m, v.Y / m) or v2(0, 0)
	elseif k == "Dot" then
		return function(a, b)
			return a.X * b.X + a.Y * b.Y
		end
	elseif k == "Cross" then
		return function(a, b)
			return a.X * b.Y - a.Y * b.X
		end
	elseif k == "Lerp" then
		return function(a, b, t)
			return a + (b - a) * t
		end
	end
	return nil
end
V2.__add = function(a, b)
	return v2(a.X + b.X, a.Y + b.Y)
end
V2.__sub = function(a, b)
	return v2(a.X - b.X, a.Y - b.Y)
end
V2.__mul = function(a, b)
	if type(a) == "number" then
		return v2(b.X * a, b.Y * a)
	elseif type(b) == "number" then
		return v2(a.X * b, a.Y * b)
	end
	return v2(a.X * b.X, a.Y * b.Y)
end
V2.__div = function(a, b)
	if type(b) == "number" then
		return v2(a.X / b, a.Y / b)
	end
	return v2(a.X / b.X, a.Y / b.Y)
end
V2.__unm = function(a)
	return v2(-a.X, -a.Y)
end
V2.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y
end
V2.__tostring = function(a)
	return string.format("%.2f, %.2f", a.X, a.Y)
end
V2.__type = "Vector2"
local Vector2 = {
	new = v2,
	zero = v2(0, 0),
	one = v2(1, 1),
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
	TrussPart = { "BasePart", "PVInstance" },
	MeshPart = { "BasePart", "PVInstance" },
	UnreliableRemoteEvent = { "BaseRemoteEvent" },
	RemoteEvent = { "BaseRemoteEvent" },
	PointLight = { "Light" },
	SpotLight = { "Light" },
	SurfaceLight = { "Light" },
	ScreenGui = { "LayerCollector", "GuiBase2d" },
	BillboardGui = { "LayerCollector", "GuiBase2d" },
	SurfaceGui = { "LayerCollector", "GuiBase2d" },
	Terrain = { "BasePart", "PVInstance" },
	Motor6D = { "Motor", "JointInstance" },
	Weld = { "JointInstance" },
	AnimationConstraint = { "Constraint" },
	BallSocketConstraint = { "Constraint" },
}
local SIGNALS = {
	RemoteEvent = { "OnServerEvent", "OnClientEvent" },
	UnreliableRemoteEvent = { "OnServerEvent", "OnClientEvent" },
	Humanoid = { "Died", "HealthChanged", "StateChanged", "Running" },
	ClickDetector = { "MouseClick" },
	ProximityPrompt = { "Triggered" },
	Players = { "PlayerAdded", "PlayerRemoving" },
	Player = { "CharacterAdded", "Chatted" },
	Tool = { "Activated", "Equipped", "Unequipped" },
	Sound = { "Ended" },
	TextButton = {
		"Activated",
		"MouseButton1Click",
		"MouseButton1Down",
		"MouseButton1Up",
		"MouseEnter",
		"MouseLeave",
		"InputBegan",
		"InputChanged",
		"InputEnded",
	},
	ImageButton = { "Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up", "InputBegan", "InputEnded" },
	Frame = { "InputBegan", "InputChanged", "InputEnded" },
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
			AssemblyLinearVelocity = v3(),
		}
	end,
	Attachment = function()
		return { Position = v3(), CFrame = cf(v3()) }
	end,
	Motor6D = function()
		return { C0 = cf(v3()), C1 = cf(v3()), Transform = cf(v3()), Enabled = true }
	end,
	Weld = function()
		return { C0 = cf(v3()), C1 = cf(v3()), Enabled = true }
	end,
	AnimationConstraint = function()
		return { Transform = cf(v3()), IsKinematic = true, Enabled = true }
	end,
	Humanoid = function()
		return {
			WalkSpeed = 16,
			Health = 100,
			MaxHealth = 100,
			JumpHeight = 7.2,
			HipHeight = 2,
			DisplayDistanceType = nil,
		}
	end,
	TrussPart = function()
		return {
			Size = v3(2, 2, 2),
			CFrame = cf(v3()),
			Transparency = 0,
			Anchored = false,
			CanCollide = true,
			CanQuery = true,
			AssemblyLinearVelocity = v3(),
			Shape = Enum.PartType.Block,
		}
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
function methods.TakeDamage(hum, amount)
	if (hum.Health or 0) > 0 then
		hum.Health = hum.Health - amount
	end
end
function methods.ChangeState(hum, state)
	rawset(hum, "_state", state)
end
function methods.GetState(hum)
	return rawget(hum, "_state") or Enum.HumanoidStateType.Running
end
function methods.ApplyDescription(hum, desc)
	rawset(hum, "_desc", desc)
end
function methods.GetAppliedDescription(hum)
	return rawget(hum, "_desc") or Instance.new("HumanoidDescription")
end
function methods.SetAccessories() end
function methods.GetAccessories()
	return {}
end
function methods.ApplyImpulse() end
function methods.SetNetworkOwner() end
function methods.GetNetworkPing()
	return 0.05
end
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
function methods.GetHumanoidDescriptionFromUserId()
	return Instance.new("HumanoidDescription")
end
function methods.IsFriendsWith(inst, id)
	return Engine.friends[rawget(inst, "_props").UserId .. ":" .. id] == true
end
function methods.GetJoinData(inst)
	return { LaunchData = rawget(inst, "_props")._launchData }
end
-- Players:GetFriendsAsync: one page of the friends Engine.makeFriends made (tests can add offline friends to
-- Engine.offlineFriends[userId] = { { Id, Username, DisplayName }, ... })
Engine.offlineFriends = {}
function methods.GetFriendsAsync(inst, userId)
	local list = {}
	for key in Engine.friends do
		local a, b = string.match(key, "^(%-?%d+):(%-?%d+)$")
		if tonumber(a) == userId then
			local id = tonumber(b)
			local p = methods.GetPlayerByUserId(inst, id)
			table.insert(list, {
				Id = id,
				Username = p and p.Name or ("User" .. id),
				DisplayName = p and p.DisplayName or ("User" .. id),
				IsOnline = p ~= nil,
			})
		end
	end
	for _, f in Engine.offlineFriends[userId] or {} do
		table.insert(list, { Id = f.Id, Username = f.Username, DisplayName = f.DisplayName, IsOnline = false })
	end
	table.sort(list, function(x, y)
		return x.Id < y.Id
	end)
	return {
		IsFinished = true,
		GetCurrentPage = function()
			return list
		end,
		AdvanceToNextPageAsync = function() end,
	}
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
		local a = parent
		while a do
			local da = rawget(a, "_descAdded")
			if da then
				da:Fire(inst)
			end
			a = rawget(a, "_props").Parent
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
	elseif k == "DescendantAdded" then
		local s = rawget(inst, "_descAdded") or newSignal()
		rawset(inst, "_descAdded", s)
		return s
	elseif k == "DescendantRemoving" then
		local s = rawget(inst, "_descRemoving") or newSignal()
		rawset(inst, "_descRemoving", s)
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
	if rawget(inst, "_class") == "Folder" or rawget(inst, "_class") == "Model" or isA(inst, "BasePart") then
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
	if k == "Health" and rawget(inst, "_class") == "Humanoid" then
		local props = rawget(inst, "_props")
		local old = props.Health or 0
		local new = math.clamp(v, 0, props.MaxHealth or 100)
		props.Health = new
		if new ~= old then
			rawget(inst, "_signals").HealthChanged:Fire(new)
		end
		if old > 0 and new <= 0 then
			rawget(inst, "_signals").Died:Fire()
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

-- Clone: a deep copy (unparented), with references inside the copy (PrimaryPart, Adornee, Part0...) pointing at
-- the copied instances, like Roblox does.
function methods.Clone(inst)
	local map = {}
	local function copy(src, parent)
		local c = Instance.new(rawget(src, "_class"))
		local cprops = rawget(c, "_props")
		for k, v in rawget(src, "_props") do
			if k ~= "Parent" then
				cprops[k] = v
			end
		end
		for k, v in rawget(src, "_attrs") do
			rawget(c, "_attrs")[k] = v
		end
		map[src] = c
		if parent then
			c.Parent = parent
		end
		for _, child in rawget(src, "_children") do
			copy(child, c)
		end
		return c
	end
	local root = copy(inst, nil)
	for _, c in map do
		local cprops = rawget(c, "_props")
		for k, v in cprops do
			if type(v) == "table" and map[v] then
				cprops[k] = map[v]
			end
		end
	end
	return root
end

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
workspace.CurrentCamera.CFrame = CFrame.lookAt(v3(0, 20, 30), v3(0, 0, 0)) -- (a camera always has one)

-- Terrain (Roblox smooth terrain). Every fill is kept in order in Engine.terrain.ops, so tests can check the land
-- and the render tools can draw it; like Roblox, only terrain materials are accepted. Material colours and the
-- water settings are kept too.
local TERRAIN_MATERIALS = {
	Air = true,
	Water = true,
	Grass = true,
	Slate = true,
	Concrete = true,
	Brick = true,
	Sand = true,
	WoodPlanks = true,
	Rock = true,
	Glacier = true,
	Snow = true,
	Sandstone = true,
	Mud = true,
	Basalt = true,
	Ground = true,
	CrackedLava = true,
	Asphalt = true,
	Cobblestone = true,
	Ice = true,
	LeafyGrass = true,
	Salt = true,
	Limestone = true,
	Pavement = true,
}
Engine.TERRAIN_MATERIALS = TERRAIN_MATERIALS
Engine.terrain = { ops = {}, colors = {} }
local terrainInst = Instance.new("Terrain", workspace)
terrainInst.Name = "Terrain"
local function terrainMaterial(m, what)
	local mt = type(m) == "table" and getmetatable(m)
	local name = mt and mt.__type == "EnumItem" and m.EnumType == "Material" and m.Name or nil
	if not name or not TERRAIN_MATERIALS[name] then
		error(what .. ": " .. tostring(name or m) .. " is not a terrain material", 3)
	end
	return name
end
local function positive(v, what)
	if type(v) == "number" then
		if not (v > 0) then
			error(what .. ": size must be positive", 3)
		end
	elseif v.X <= 0 or v.Y <= 0 or v.Z <= 0 then
		error(what .. ": size must be positive", 3)
	end
end
function methods.FillBlock(_, cframe, size, material)
	positive(size, "FillBlock")
	table.insert(
		Engine.terrain.ops,
		{ op = "block", cf = cframe, size = size, material = terrainMaterial(material, "FillBlock") }
	)
end
function methods.FillWedge(_, cframe, size, material)
	positive(size, "FillWedge")
	table.insert(
		Engine.terrain.ops,
		{ op = "wedge", cf = cframe, size = size, material = terrainMaterial(material, "FillWedge") }
	)
end
function methods.FillBall(_, center, radius, material)
	positive(radius, "FillBall")
	table.insert(
		Engine.terrain.ops,
		{ op = "ball", center = center, radius = radius, material = terrainMaterial(material, "FillBall") }
	)
end
function methods.FillCylinder(_, cframe, height, radius, material)
	positive(height, "FillCylinder")
	positive(radius, "FillCylinder")
	table.insert(Engine.terrain.ops, {
		op = "cylinder",
		cf = cframe,
		height = height,
		radius = radius,
		material = terrainMaterial(material, "FillCylinder"),
	})
end
function methods.SetMaterialColor(_, material, color)
	local name = terrainMaterial(material, "SetMaterialColor")
	if name == "Air" or name == "Water" then
		error("SetMaterialColor: " .. name .. " has no colour", 2)
	end
	Engine.terrain.colors[name] = color
end
function methods.GetMaterialColor(_, material)
	return Engine.terrain.colors[terrainMaterial(material, "GetMaterialColor")]
end
-- Terrain:WriteVoxels(region, 4, materials, occupancy): the arrays are [x][y][z], one per 4-stud voxel of the
-- (grid-aligned) region, like Roblox. Kept as chunks in write order (a later chunk overwrites an earlier one where
-- they overlap), each a buffer of two bytes per voxel (material id, occupancy 0-255), y fastest, then z, then x.
Engine.terrain.voxels = {}
Engine.terrain.palette = { "Air" }
Engine.terrain.version = 0
local paletteId = { Air = 0 }
local materialIds = {}
function methods.WriteVoxels(_, region, resolution, materials, occupancy)
	if resolution ~= 4 then
		error("WriteVoxels: resolution must be 4", 2)
	end
	local lo, size = region.Min, region.Size
	for _, v in { lo.X, lo.Y, lo.Z, size.X, size.Y, size.Z } do
		if v % 4 ~= 0 then
			error("WriteVoxels: the region must be aligned to the voxel grid (Region3:ExpandToGrid(4))", 2)
		end
	end
	local nx, ny, nz = size.X / 4, size.Y / 4, size.Z / 4
	if #materials ~= nx or #occupancy ~= nx then
		error(`WriteVoxels: expected {nx} x-slices, got {#materials} materials and {#occupancy} occupancies`, 2)
	end
	local data = buffer.create(nx * ny * nz * 2)
	for x = 1, nx do
		local mx, ox = materials[x], occupancy[x]
		if #mx ~= ny or #ox ~= ny then
			error(`WriteVoxels: expected {ny} y-rows in x-slice {x}`, 2)
		end
		for y = 1, ny do
			local my, oy = mx[y], ox[y]
			if #my ~= nz or #oy ~= nz then
				error(`WriteVoxels: expected {nz} voxels in row ({x}, {y})`, 2)
			end
			for z = 1, nz do
				local m = my[z]
				local id = materialIds[m]
				if id == nil then
					local name = terrainMaterial(m, "WriteVoxels")
					id = paletteId[name]
					if id == nil then
						table.insert(Engine.terrain.palette, name)
						id = #Engine.terrain.palette - 1
						paletteId[name] = id
					end
					materialIds[m] = id
				end
				local o = oy[z]
				if type(o) ~= "number" or o < 0 or o > 1 then
					error(`WriteVoxels: occupancy must be 0-1, got {o}`, 2)
				end
				local at = (((x - 1) * nz + (z - 1)) * ny + (y - 1)) * 2
				buffer.writeu8(data, at, id)
				buffer.writeu8(data, at + 1, id == 0 and 0 or math.floor(o * 255 + 0.5))
			end
		end
	end
	table.insert(Engine.terrain.voxels, { min = lo, nx = nx, ny = ny, nz = nz, data = data })
	Engine.terrain.version += 1
end
-- The material name and occupancy of the voxel holding a point (the last write that covers it), for tests.
function Engine.terrainVoxelAt(pos)
	local list = Engine.terrain.voxels
	for k = #list, 1, -1 do
		local c = list[k]
		local x = math.floor((pos.X - c.min.X) / 4)
		local y = math.floor((pos.Y - c.min.Y) / 4)
		local z = math.floor((pos.Z - c.min.Z) / 4)
		if x >= 0 and y >= 0 and z >= 0 and x < c.nx and y < c.ny and z < c.nz then
			local at = ((x * c.nz + z) * c.ny + y) * 2
			return Engine.terrain.palette[buffer.readu8(c.data, at) + 1], buffer.readu8(c.data, at + 1) / 255
		end
	end
	return "Air", 0
end
-- The height of the terrain's top surface over (x, z) (nil if there is none), for tests.
function Engine.terrainTop(x, z, fromY)
	local y = math.floor((fromY or 400) / 4) * 4 + 2
	while y > -400 do
		local m, o = Engine.terrainVoxelAt(Vector3.new(x, y, z))
		if m ~= "Air" and m ~= "Water" and o > 0 then
			return y - 2 + 4 * o
		end
		y -= 4
	end
	return nil
end
-- (Terrain:Clear())
function methods.Clear(inst)
	if inst == terrainInst then
		Engine.terrain.ops = {}
		Engine.terrain.voxels = {}
		Engine.terrain.version += 1
	end
end
function methods.BulkMoveTo(_, parts, cframes)
	for i, part in parts do
		rawget(part, "_props").CFrame = cframes[i]
	end
end
function methods.Raycast()
	return nil
end
function methods.GetPartBoundsInRadius()
	return {}
end
local PhysicsService = service("PhysicsService")
Engine.collisionGroups = {}
function methods.RegisterCollisionGroup(_, name)
	Engine.collisionGroups[name] = Engine.collisionGroups[name] or {}
end
function methods.CollisionGroupSetCollidable(_, a, b, on)
	Engine.collisionGroups[a] = Engine.collisionGroups[a] or {}
	Engine.collisionGroups[b] = Engine.collisionGroups[b] or {}
	Engine.collisionGroups[a][b] = on
	Engine.collisionGroups[b][a] = on
end
function methods.IsCollisionGroupRegistered(_, name)
	return Engine.collisionGroups[name] ~= nil
end
_ = PhysicsService
service("Teams", "Teams")
function methods.GetServerTimeNow()
	return clock
end
local Players = service("Players")
playersService = Players
service("ReplicatedStorage", "Folder")
service("ServerScriptService", "Folder")
service("ServerStorage", "Folder")
service("StarterPlayer", "Folder")
service("Lighting")
-- TextService: the filter turns "badword" into hashes, like Roblox's
service("TextService")
function methods.FilterStringAsync(_, text)
	return {
		GetNonChatStringForBroadcastAsync = function()
			return (string.gsub(text, "badword", "#######"))
		end,
	}
end
service("SoundService")

-- RunService
local RunService = service("RunService")
rawset(RunService, "_signals", {
	Heartbeat = newSignal(),
	RenderStepped = newSignal(),
	Stepped = newSignal(),
	PreRender = newSignal(),
	PreAnimation = newSignal(),
	PreSimulation = newSignal(),
	PostSimulation = newSignal(),
})
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

-- ProximityPromptService (tests fire PromptTriggered themselves)
local ProximityPromptService = service("ProximityPromptService")
rawset(ProximityPromptService, "_signals", {
	PromptTriggered = newSignal(),
	PromptButtonHoldBegan = newSignal(),
	PromptButtonHoldEnded = newSignal(),
	PromptShown = newSignal(),
	PromptHidden = newSignal(),
})
_ = ProximityPromptService

-- HttpService (JSON)
local HttpService = service("HttpService")
local guidN = 0
function methods.GenerateGUID()
	guidN += 1
	return string.format("00000000-0000-4000-8000-%012d", guidN)
end
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
-- What a DataStore takes (like Roblox): plain data, and every table either a list (keys 1..n, no gaps) or a
-- dictionary with string keys; no NaN or infinite numbers.
local function storable(x, path)
	if type(x) == "table" then
		if getmetatable(x) then
			error("non-serializable value in save at " .. path)
		end
		local count, numbers, strings = 0, 0, 0
		for k in x do
			count += 1
			if type(k) == "number" then
				numbers += 1
			elseif type(k) == "string" then
				strings += 1
			else
				error("a table key that isn't a string or a number in save at " .. path)
			end
		end
		if numbers > 0 then
			local list = strings == 0
			for k in x do
				if type(k) == "number" and (k ~= math.floor(k) or k < 1 or k > count) then
					list = false
				end
			end
			if not list then
				error("Cannot convert mixed or non-array tables: keys must be strings (save at " .. path .. ")")
			end
		end
		for k, y in x do
			storable(y, path .. "." .. tostring(k))
		end
	elseif type(x) == "number" then
		if x ~= x or x == math.huge or x == -math.huge then
			error("a NaN or infinite number in save at " .. path)
		end
	elseif type(x) == "function" or type(x) == "userdata" or type(x) == "vector" then
		error("non-serializable value in save at " .. path)
	end
end
Engine.storable = storable

function methods.GetDataStore(_, name)
	Engine.dataStores[name] = Engine.dataStores[name] or {}
	local data = Engine.dataStores[name]
	if Engine.dataStoreFails then
		error("Studio access to APIs is not allowed")
	end
	return {
		GetAsync = function(_, key)
			if Engine.dataStoreFails then
				error("Studio access to APIs is not allowed")
			end
			return deepCopy(data[key])
		end,
		SetAsync = function(_, key, value)
			if Engine.dataStoreFails then
				error("Studio access to APIs is not allowed")
			end
			storable(value, key)
			data[key] = deepCopy(value)
		end,
		UpdateAsync = function(_, key, fn)
			if Engine.dataStoreFails then
				error("Studio access to APIs is not allowed")
			end
			local new = fn(deepCopy(data[key]))
			if new ~= nil then
				-- DataStores only take plain data: catch Instances, Color3, sparse lists etc. sneaking into saves
				storable(new, key)
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
function methods.PromptGamePassPurchase(_, player, id)
	table.insert(Engine.prompted, { player = player, kind = "pass", id = id })
end
function methods.PromptProductPurchase(_, player, id)
	table.insert(Engine.prompted, { player = player, kind = "product", id = id })
end
-- TeleportService: tests set Engine.friendPlaces[userId] = { placeId, jobId } and Engine.teleportResult (an
-- Enum.TeleportResult name) to make the next teleport fail; every TeleportAsync call is kept in Engine.teleports
local TeleportService = service("TeleportService")
rawset(TeleportService, "_signals", { TeleportInitFailed = newSignal() })
Engine.friendPlaces = {}
Engine.teleports = {}
function methods.GetPlayerPlaceInstanceAsync(_, userId)
	local place = Engine.friendPlaces[userId]
	if not place then
		error("user is not in a game")
	end
	return false, "", place[1], place[2]
end
function methods.TeleportAsync(_, placeId, players, options)
	table.insert(Engine.teleports, { placeId = placeId, players = players, options = options })
	if Engine.teleportResult then
		local result = Enum.TeleportResult[Engine.teleportResult]
		task.defer(function()
			for _, p in players do
				TeleportService.TeleportInitFailed:Fire(p, result, "mock failure", placeId, options)
			end
		end)
	end
	return {}
end
local reserved = 0
function methods.ReserveServer()
	reserved += 1
	return "access-" .. reserved, "private-" .. reserved
end
function methods.SetTeleportData(inst, value)
	rawset(inst, "_teleportData", value)
end
function methods.GetTeleportData(inst)
	return rawget(inst, "_teleportData")
end
_ = TeleportService
-- MemoryStoreService: sorted maps in memory (Engine.memory[name][key] = value)
local MemoryStoreService = service("MemoryStoreService")
Engine.memory = {}
function methods.GetSortedMap(_, name)
	Engine.memory[name] = Engine.memory[name] or {}
	local m = Engine.memory[name]
	return {
		GetAsync = function(_, key)
			return deepCopy(m[key])
		end,
		SetAsync = function(_, key, value)
			m[key] = deepCopy(value)
			return true
		end,
		RemoveAsync = function(_, key)
			m[key] = nil
		end,
		UpdateAsync = function(_, key, fn)
			local new = fn(deepCopy(m[key]))
			if new ~= nil then
				m[key] = deepCopy(new)
			end
			return new
		end,
		-- items in key order: { { key, value }, ... }
		GetRangeAsync = function(_, direction, count)
			local keys = {}
			for k in m do
				table.insert(keys, k)
			end
			table.sort(keys)
			if direction == Enum.SortDirection.Descending then
				local r = {}
				for i = #keys, 1, -1 do
					table.insert(r, keys[i])
				end
				keys = r
			end
			local out = {}
			for i = 1, math.min(count or 200, #keys) do
				table.insert(out, { key = keys[i], value = deepCopy(m[keys[i]]) })
			end
			return out
		end,
	}
end
_ = MemoryStoreService
local LocalizationService = service("LocalizationService")
function methods.GetCountryRegionForPlayerAsync()
	return "US"
end
_ = LocalizationService
service("ScriptContext")
-- a client's friends online (Player:GetFriendsOnline); tests fill Engine.friendsOnline
Engine.friendsOnline = {}
function methods.GetFriendsOnline()
	return Engine.friendsOnline
end
-- MessagingService: a bus inside this one mock server (Engine.messages keeps every publish)
local MessagingService = service("MessagingService")
Engine.messages = {}
Engine.subscribers = {}
function methods.PublishAsync(_, topic, data)
	table.insert(Engine.messages, { topic = topic, data = data })
	for _, fn in Engine.subscribers[topic] or {} do
		task.defer(fn, { Data = data, Sent = os.time() })
	end
end
function methods.SubscribeAsync(_, topic, fn)
	Engine.subscribers[topic] = Engine.subscribers[topic] or {}
	table.insert(Engine.subscribers[topic], fn)
	return { Disconnect = function() end }
end
_ = MessagingService
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
-- keys held down: tests set Engine.keysDown[Enum.KeyCode.X] = true
Engine.keysDown = {}
function methods.IsKeyDown(_, key)
	return Engine.keysDown[key] == true
end
function methods.GetMouseLocation()
	return Engine.mouseLocation or Vector2.new(0, 0)
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
-- An R15 avatar, joined the way Roblox's rig is: Motor6Ds between the parts (or, with Engine.avatarJoints =
-- "constraint", the AnimationConstraints that Roblox's Avatar Joint Upgrade spawns instead, on rig attachments).
-- Like Roblox, every step: the Animator writes each joint's Transform (Engine.animationPose: an idle sway), the
-- platform puts each Motor6D's C0 back to what its rig attachments say (Engine.platformC0), PreSimulation fires, then
-- the joints are solved (Part1 = Part0 * C0 * Transform * C1:Inverse()) and what's welded on follows. So code that
-- poses an arm through C0, or outside PreSimulation, does nothing here, as it does nothing there.
local R15_PARTS = {
	{ "LowerTorso", v3(2, 0.4, 1), "pants" },
	{ "UpperTorso", v3(2, 1.6, 1), "shirt" },
	{ "Head", v3(1.2, 1.2, 1.2), "skin" },
	{ "RightUpperArm", v3(1, 1.2, 1), "shirt" },
	{ "RightLowerArm", v3(1, 1.1, 1), "skin" },
	{ "RightHand", v3(1, 0.3, 1), "skin" },
	{ "LeftUpperArm", v3(1, 1.2, 1), "shirt" },
	{ "LeftLowerArm", v3(1, 1.1, 1), "skin" },
	{ "LeftHand", v3(1, 0.3, 1), "skin" },
	{ "RightUpperLeg", v3(1, 1.2, 1), "pants" },
	{ "RightLowerLeg", v3(1, 1.2, 1), "pants" },
	{ "RightFoot", v3(1, 0.3, 1), "pants" },
	{ "LeftUpperLeg", v3(1, 1.2, 1), "pants" },
	{ "LeftLowerLeg", v3(1, 1.2, 1), "pants" },
	{ "LeftFoot", v3(1, 0.3, 1), "pants" },
}
-- joint, part1, part0, C0, C1 (parents before children)
local R15_JOINTS = {
	{ "Root", "LowerTorso", "HumanoidRootPart", v3(0, -0.8, 0), v3(0, 0, 0) },
	{ "Waist", "UpperTorso", "LowerTorso", v3(0, 0.2, 0), v3(0, -0.8, 0) },
	{ "Neck", "Head", "UpperTorso", v3(0, 0.8, 0), v3(0, -0.6, 0) },
	{ "RightShoulder", "RightUpperArm", "UpperTorso", v3(1, 0.56, 0), v3(-0.5, 0.4, 0) },
	{ "RightElbow", "RightLowerArm", "RightUpperArm", v3(0, -0.4, 0), v3(0, 0.35, 0) },
	{ "RightWrist", "RightHand", "RightLowerArm", v3(0, -0.5, 0), v3(0, 0.15, 0) },
	{ "LeftShoulder", "LeftUpperArm", "UpperTorso", v3(-1, 0.56, 0), v3(0.5, 0.4, 0) },
	{ "LeftElbow", "LeftLowerArm", "LeftUpperArm", v3(0, -0.4, 0), v3(0, 0.35, 0) },
	{ "LeftWrist", "LeftHand", "LeftLowerArm", v3(0, -0.5, 0), v3(0, 0.15, 0) },
	{ "RightHip", "RightUpperLeg", "LowerTorso", v3(0.5, -0.2, 0), v3(0, 0.45, 0) },
	{ "RightKnee", "RightLowerLeg", "RightUpperLeg", v3(0, -0.45, 0), v3(0, 0.45, 0) },
	{ "RightAnkle", "RightFoot", "RightLowerLeg", v3(0, -0.45, 0), v3(0, 0.05, 0) },
	{ "LeftHip", "LeftUpperLeg", "LowerTorso", v3(-0.5, -0.2, 0), v3(0, 0.45, 0) },
	{ "LeftKnee", "LeftLowerLeg", "LeftUpperLeg", v3(0, -0.45, 0), v3(0, 0.45, 0) },
	{ "LeftAnkle", "LeftFoot", "LeftLowerLeg", v3(0, -0.45, 0), v3(0, 0.05, 0) },
}
-- the face, welded to the head
local FACE = {
	{ "EyeL", v3(0.18, 0.28, 0.05), v3(-0.25, 0.15, -0.61), "ink" },
	{ "EyeR", v3(0.18, 0.28, 0.05), v3(0.25, 0.15, -0.61), "ink" },
	{ "Smile", v3(0.5, 0.1, 0.05), v3(0, -0.22, -0.61), "ink" },
}
local AVATAR_COLORS = {
	skin = { 234, 184, 146 },
	shirt = { 58, 128, 214 },
	pants = { 44, 48, 66 },
	ink = { 27, 29, 43 },
}
Engine.rigs = setmetatable({}, { __mode = "k" }) -- [character] = { hrp, joints = { { name, inst, part0, part1, c0, a0?, a1? } } }
Engine.avatarJoints = "motor6d" -- or "constraint"
Engine.platformC0 = true

-- What the avatar's own animation (Roblox's Animate script: idle, walk) writes to a joint each step.
function Engine.animationPose(name, t)
	if name == "RightShoulder" or name == "LeftShoulder" then
		return CFrame.Angles(math.sin(t * 1.3) * 0.08, 0, 0)
	end
	return cf(v3())
end

local function solveRig(character, rig)
	for _, j in rig.joints do
		if not rawget(j.inst, "_destroyed") and not rawget(j.part1, "_destroyed") then
			local jp = rawget(j.inst, "_props")
			local c0, c1
			if j.a0 then
				c0, c1 = rawget(j.a0, "_props").CFrame, rawget(j.a1, "_props").CFrame
			else
				c0, c1 = jp.C0, jp.C1
			end
			rawget(j.part1, "_props").CFrame = rawget(j.part0, "_props").CFrame * c0 * jp.Transform * c1:Inverse()
		end
	end
	-- what's welded on: Welds (C0, C1), then WeldConstraints (the offset they were made with)
	local all = methods.GetDescendants(character)
	for _, d in all do
		if rawget(d, "_class") == "Weld" and not rawget(d, "_destroyed") then
			local p = rawget(d, "_props")
			if p.Part0 and p.Part1 then
				rawget(p.Part1, "_props").CFrame = rawget(p.Part0, "_props").CFrame * p.C0 * p.C1:Inverse()
			end
		end
	end
	for _, d in all do
		if rawget(d, "_class") == "WeldConstraint" and rawget(d, "_offset") and not rawget(d, "_destroyed") then
			local p = rawget(d, "_props")
			if p.Part0 and p.Part1 then
				rawget(p.Part1, "_props").CFrame = rawget(p.Part0, "_props").CFrame * rawget(d, "_offset")
			end
		end
	end
end
Engine.solveRig = solveRig

function Engine.animateRigs()
	for character, rig in Engine.rigs do
		if rawget(character, "_destroyed") then
			continue
		end
		for _, j in rig.joints do
			local jp = rawget(j.inst, "_props")
			jp.Transform = Engine.animationPose(j.name, clock)
			if not j.a0 and Engine.platformC0 then
				jp.C0 = j.c0
			end
		end
	end
end

function Engine.solveRigs()
	for character, rig in Engine.rigs do
		if not rawget(character, "_destroyed") then
			solveRig(character, rig)
		end
	end
end

function Engine.makeCharacter(player)
	local character = Instance.new("Model")
	character.Name = player.Name
	local hrp = Instance.new("Part", character)
	hrp.Name = "HumanoidRootPart"
	hrp.Size = v3(2, 2, 1)
	hrp.Transparency = 1
	hrp.CFrame = CFrame.new(0, 3, 0)
	local parts = { HumanoidRootPart = hrp }
	for _, spec in R15_PARTS do
		local part = Instance.new("Part", character)
		part.Name = spec[1]
		part.Size = spec[2]
		local c = AVATAR_COLORS[spec[3]]
		part.Color = Color3.fromRGB(c[1], c[2], c[3])
		part.Material = Enum.Material.SmoothPlastic
		parts[spec[1]] = part
	end
	local rig = { hrp = hrp, joints = {} }
	for _, spec in R15_JOINTS do
		local name, part1, part0, c0, c1 =
			spec[1], parts[spec[2]], parts[spec[3]], CFrame.new(spec[4]), CFrame.new(spec[5])
		local j = { name = name, part0 = part0, part1 = part1, c0 = c0 }
		if Engine.avatarJoints == "constraint" then
			local a0 = Instance.new("Attachment")
			a0.Name = name .. "RigAttachment"
			a0.CFrame = c0
			a0.Parent = part0
			local a1 = Instance.new("Attachment")
			a1.Name = name .. "RigAttachment"
			a1.CFrame = c1
			a1.Parent = part1
			local inst = Instance.new("AnimationConstraint")
			inst.Name = name
			inst.Attachment0 = a0
			inst.Attachment1 = a1
			inst.Parent = part1
			j.inst, j.a0, j.a1 = inst, a0, a1
		else
			local inst = Instance.new("Motor6D")
			inst.Name = name
			inst.Part0 = part0
			inst.Part1 = part1
			inst.C0 = c0
			inst.C1 = c1
			inst.Parent = part1
			j.inst = inst
		end
		table.insert(rig.joints, j)
	end
	solveRig(character, rig)
	for _, spec in FACE do
		local part = Instance.new("Part", character)
		part.Name = spec[1]
		part.Size = spec[2]
		part.CFrame = parts.Head.CFrame * CFrame.new(spec[3])
		local c = AVATAR_COLORS[spec[4]]
		part.Color = Color3.fromRGB(c[1], c[2], c[3])
		part.Material = Enum.Material.SmoothPlastic
		local w = Instance.new("WeldConstraint")
		w.Part0 = parts.Head
		w.Part1 = part
		w.Parent = part
	end
	Engine.rigs[character] = rig
	local hum = Instance.new("Humanoid", character)
	hum.Name = "Humanoid"
	character.PrimaryPart = hrp
	character.Parent = workspace
	player.Character = character
	player.CharacterAdded:Fire(character)
	return character
end

-- Player:LoadCharacter(): a fresh character (the old one is removed)
function methods.LoadCharacter(player)
	local old = player.Character
	if old then
		old.Parent = nil
	end
	Engine.makeCharacter(player)
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
	-- a test teleport is like one of the server's own: the anti-cheat lets it pass
	player:SetAttribute("AcGrace", clock + 2.5)
	if lookAt then
		hrp.CFrame = CFrame.lookAt(position, v3(lookAt.X, position.Y, lookAt.Z))
	else
		hrp.CFrame = CFrame.new(position)
	end
	Engine.resolveWelds()
	local rig = Engine.rigs[player.Character]
	if rig then
		solveRig(player.Character, rig)
	end
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
			RunService.PreRender:Fire(step)
			-- the Animator, then PreSimulation (where poses go), then the joints move
			RunService.PreAnimation:Fire(step)
			Engine.animateRigs()
			RunService.Stepped:Fire(clock, step)
			RunService.PreSimulation:Fire(step)
			Engine.solveRigs()
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
	BrickColor = BrickColor,
	Region3 = Region3,
	CFrame = CFrame,
	Color3 = Color3,
	ColorSequence = ColorSequence,
	ColorSequenceKeypoint = ColorSequenceKeypoint,
	NumberSequence = NumberSequence,
	NumberSequenceKeypoint = NumberSequenceKeypoint,
	NumberRange = NumberRange,
	UDim = UDim,
	UDim2 = UDim2,
	TweenInfo = TweenInfo,
	Enum = Enum,
	Random = Random,
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
