--[[
A stand-in for Roblox's humanoid physics, for the tests that need bodies to walk into things (tests/BotNavSmoke).
The mock engine has no physics, so without this a Humanoid:MoveTo isn't modelled at all and BotService steps its
bots through walls by hand. With it installed, Humanoid:MoveTo(goal) walks the body toward the goal at its WalkSpeed
against every collidable part in the workspace (their real, rotated boxes): it slides along walls, steps up ledges
up to STEP_UP studs, falls off edges, lands, and jumps when Humanoid.Jump is set (JumpHeight, the world's gravity).
It is deliberately a little stricter than Roblox (a short step-up, a wide body), so what gets through here gets
through live.

  local Walker = loadModule("tests/mock/Walker.luau")
  Walker.install(Engine)       Humanoid:MoveTo walks from now on
  Walker.STEP_UP, Walker.RADIUS, Walker.GRAVITY
]]
local Walker = {}
Walker.STEP_UP = 1.25 -- studs a body steps up without a jump
Walker.RADIUS = 1.0 -- the body's half width
Walker.GRAVITY = 196.2
local GRID = 8

local function boxOf(props)
	local c, s = props.CFrame, props.Size
	local r, p = c.r, c.p
	local hx, hy, hz = s.X / 2, s.Y / 2, s.Z / 2
	-- the axes are the rotation's columns: right, up, back
	local ax = { r[1], r[4], r[7] }
	local ay = { r[2], r[5], r[8] }
	local az = { r[3], r[6], r[9] }
	local ex = math.abs(r[1]) * hx + math.abs(r[2]) * hy + math.abs(r[3]) * hz
	local ey = math.abs(r[4]) * hx + math.abs(r[5]) * hy + math.abs(r[6]) * hz
	local ez = math.abs(r[7]) * hx + math.abs(r[8]) * hy + math.abs(r[9]) * hz
	return {
		cx = p.X,
		cy = p.Y,
		cz = p.Z,
		axes = { ax, ay, az },
		half = { hx, hy, hz },
		x0 = p.X - ex,
		x1 = p.X + ex,
		y0 = p.Y - ey,
		y1 = p.Y + ey,
		z0 = p.Z - ez,
		z1 = p.Z + ez,
	}
end

-- The heights at which a vertical line through (x, z) is inside the box: lo, hi (nil if it misses)
local function span(b, x, z)
	if x < b.x0 or x > b.x1 or z < b.z0 or z > b.z1 then
		return nil
	end
	local lo, hi = -math.huge, math.huge
	local dx, dz = x - b.cx, z - b.cz
	for i = 1, 3 do
		local a, h = b.axes[i], b.half[i]
		local k = dx * a[1] + dz * a[3]
		local ay = a[2]
		if math.abs(ay) < 1e-6 then
			if k < -h or k > h then
				return nil
			end
		else
			local t1, t2 = (-h - k) / ay, (h - k) / ay
			if t1 > t2 then
				t1, t2 = t2, t1
			end
			lo, hi = math.max(lo, t1), math.min(hi, t2)
			if lo > hi then
				return nil
			end
		end
	end
	return b.cy + lo, b.cy + hi
end

function Walker.install(Engine)
	local workspace = Engine.workspace
	local CFrame = Engine.CFrame
	local RunService = Engine.game:GetService("RunService")
	local walking = {} -- [humanoid] = { goal, vy, grounded, cf }
	local cache = {} -- [part] = { cf, size, box }
	local grid, gridAt = {}, -math.huge

	local function bodyOf(inst)
		local m = rawget(inst, "_props").Parent
		while m and m ~= workspace do
			if rawget(m, "_class") == "Model" and m:FindFirstChildOfClass("Humanoid") then
				return true
			end
			m = rawget(m, "_props").Parent
		end
		return false
	end

	-- every collidable part in a grid of GRID-stud columns (rebuilt twice a second: structures come and go)
	local function index()
		if Engine.now() - gridAt < 0.5 then
			return
		end
		gridAt = Engine.now()
		grid = {}
		local seen = {}
		for _, p in workspace:GetDescendants() do
			local props = rawget(p, "_props")
			if props.CFrame and props.Size and props.CanCollide ~= false and p:IsA("BasePart") then
				local e = cache[p]
				if not e or e.cf ~= props.CFrame or e.size ~= props.Size then
					e = { cf = props.CFrame, size = props.Size, box = boxOf(props), body = bodyOf(p) }
					cache[p] = e
				end
				seen[p] = true
				if not e.body then
					local b = e.box
					for gx = math.floor(b.x0 / GRID), math.floor(b.x1 / GRID) do
						for gz = math.floor(b.z0 / GRID), math.floor(b.z1 / GRID) do
							local key = gx * 4096 + gz
							grid[key] = grid[key] or {}
							table.insert(grid[key], b)
						end
					end
				end
			end
		end
		for p in cache do
			if not seen[p] then
				cache[p] = nil
			end
		end
	end

	local R = Walker.RADIUS
	local SAMPLES = {
		{ 0, 0 },
		{ R, 0 },
		{ -R, 0 },
		{ 0, R },
		{ 0, -R },
		{ R * 0.7, R * 0.7 },
		{ -R * 0.7, R * 0.7 },
		{ R * 0.7, -R * 0.7 },
		{ -R * 0.7, -R * 0.7 },
	}
	local function near(x, z)
		local out, dup = {}, {}
		for gx = math.floor((x - R) / GRID), math.floor((x + R) / GRID) do
			for gz = math.floor((z - R) / GRID), math.floor((z + R) / GRID) do
				for _, b in grid[gx * 4096 + gz] or {} do
					if not dup[b] then
						dup[b] = true
						table.insert(out, b)
					end
				end
			end
		end
		return out
	end
	-- does a body with its feet at `feet` and `height` tall fit at (x, z)? (anything under feet + step is ground)
	local function blocked(x, z, feet, step, height)
		for _, b in near(x, z) do
			for _, s in SAMPLES do
				local lo, hi = span(b, x + s[1], z + s[2])
				if lo and hi > feet + step and lo < feet + height then
					return true
				end
			end
		end
		return false
	end
	-- the highest ground under the body at (x, z) that it can stand on from `feet`
	local function ground(x, z, feet, step)
		local best = -math.huge
		for _, b in near(x, z) do
			for _, s in SAMPLES do
				local lo, hi = span(b, x + s[1], z + s[2])
				if lo and hi <= feet + step + 1e-3 and hi > best then
					best = hi
				end
			end
		end
		return best
	end
	Walker.blocked, Walker.ground, Walker.index = blocked, ground, function()
		gridAt = -math.huge
		index()
	end

	Engine.walker = {
		moveTo = function(hum, goal)
			local w = walking[hum] or { vy = 0, grounded = false }
			w.goal = goal
			walking[hum] = w
		end,
	}

	RunService.Heartbeat:Connect(function(dt)
		index()
		for hum, w in walking do
			local model = rawget(hum, "_props").Parent
			local root = model and model:FindFirstChild("HumanoidRootPart")
			if not model or rawget(model, "_destroyed") or not root or (hum.Health or 0) <= 0 then
				if not model or rawget(model, "_destroyed") then
					walking[hum] = nil
				end
				continue
			end
			local off = (hum.HipHeight or 2) + root.Size.Y / 2
			local height = off + 2.4
			local cfr = root.CFrame
			if w.cf and cfr.p ~= w.cf.p and (cfr.p - w.cf.p).Magnitude > 0.01 then
				w.vy = 0 -- (someone moved it: a teleport, a spawn)
			end
			local pos = cfr.p
			local x, z, feet = pos.X, pos.Z, pos.Y - off
			local step = w.grounded and Walker.STEP_UP or 0.35
			if rawget(hum, "_props").Jump then
				hum.Jump = false
				if w.grounded then
					w.vy = math.sqrt(2 * Walker.GRAVITY * (hum.JumpHeight or 7.2))
					w.grounded = false
					step = 0.35
				end
			end
			-- along the floor toward the goal, sliding along whatever is in the way
			local g = w.goal
			if g then
				local dx, dz = g.X - x, g.Z - z
				local d = math.sqrt(dx * dx + dz * dz)
				if d > 0.1 then
					local s = math.min(d, (hum.WalkSpeed or 16) * dt)
					local mx, mz = dx / d * s, dz / d * s
					-- (already overlapping something, a corner caught or a wall put up beside it: physics pushes a
					-- body out, so it may move)
					local stuckIn = blocked(x, z, feet, step, height)
					if stuckIn or not blocked(x + mx, z + mz, feet, step, height) then
						x, z = x + mx, z + mz
					elseif math.abs(mx) > 1e-4 and not blocked(x + mx, z, feet, step, height) then
						x = x + mx
					elseif math.abs(mz) > 1e-4 and not blocked(x, z + mz, feet, step, height) then
						z = z + mz
					end
				end
			end
			-- up a step, or down with gravity
			local floor = ground(x, z, feet, step)
			w.vy -= Walker.GRAVITY * dt
			local nf = feet + w.vy * dt
			if w.vy <= 0 and nf <= floor then
				nf, w.vy, w.grounded = floor, 0, true
			else
				w.grounded = false
				if w.vy > 0 and blocked(x, z, nf, 0.05, height) then
					nf, w.vy = feet, 0 -- (a head on a ceiling)
				end
			end
			if nf == -math.huge then
				nf = feet - 1
			end
			root.CFrame = CFrame.new(x, nf + off, z) * cfr.Rotation
			w.cf = root.CFrame
		end
	end)
end

return Walker
