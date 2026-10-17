--[[
How bots find their way across the arena (BotService): a walking grid over the floor, SQ studs a square, worked out
from every box a body bumps into (the map's shapes and the standing structures). Each square is

  FREE   nothing in the way (or only a step a body walks up)
  LOW    something a jump gets over (a crate, a bench, a low wall)
  WALL   too tall to pass (walls, towers, piers, a structure's wall)

and a path is the cheapest way through FREE and LOW squares (8 ways, never cutting a corner), kept on the bot's own
side of the frontline. The lane rule guarantees every row across the field keeps open cells, so a way across always
exists unless a bot is boxed in by structures (then it gets the nearest reachable spot). Goals inside a solid are
moved to the nearest free square, and a bot that starts on top of something walks off to the nearest free one.

  local nav = BotNav.new(arena, boxes)        boxes: { { min, max } } everything solid to a body
  nav:Free(pos)                               the nearest FREE square's centre (pos itself if it's free)
  nav:Path(from, to, side)                    a list of points from `from` to `to` (or near it), or nil; side:
                                              { line, fwd } keeps it on that side of the line
  nav:Clear(a, b)                             a straight walk from a to b crosses only FREE squares
  nav:ClassAt(pos)                            FREE | LOW | WALL (nil off the grid)
  nav:Block(pos, untilT)                      treat that square as a WALL until then (a bot stuck there)
  nav:Reach(pos, dest, side, reach)           the nearest spot to pos from which dest can be reached at all
  nav:Low(pos)                                the square there is one a jump gets over
]]
local BotNav = {}
BotNav.__index = BotNav

local SQ = 2 -- studs a square
local R = 1 -- a body's half width: boxes are grown by this much
local STEP = 1.2 -- a ledge this high is walked up
local HOP = 4.6 -- this high, a jump gets over it
local HEAD = 5.6 -- a box starting this high passes over a head
BotNav.FREE, BotNav.LOW, BotNav.WALL = 0, 1, 2
local FREE, LOW, WALL = 0, 1, 2
BotNav.SQ = SQ

function BotNav.new(arena, boxes)
	local self = setmetatable({}, BotNav)
	self.x0, self.z0 = -arena.half, -arena.width / 2
	self.nx, self.nz = math.ceil(arena.length / SQ), math.ceil(arena.width / SQ)
	self.temp = {} -- [i] = until (squares a stuck bot marked)
	local top, under = {}, {}
	for _, b in boxes do
		local mn, mx = b.min, b.max
		-- (the floor itself, and anything high over a head, are not in the way)
		if mx.Y > 0.3 and mn.Y < HEAD then
			local i0 = math.max(0, math.floor((mn.X - R - self.x0) / SQ))
			local i1 = math.min(self.nx - 1, math.floor((mx.X + R - self.x0) / SQ))
			local k0 = math.max(0, math.floor((mn.Z - R - self.z0) / SQ))
			local k1 = math.min(self.nz - 1, math.floor((mx.Z + R - self.z0) / SQ))
			for i = i0, i1 do
				for k = k0, k1 do
					local id = k * self.nx + i
					top[id] = math.max(top[id] or 0, mx.Y)
					-- (a box hanging over the floor, too low to walk under: a body can't step onto it either)
					if mn.Y > STEP then
						under[id] = true
					end
				end
			end
		end
	end
	local class = {}
	for k = 0, self.nz - 1 do
		for i = 0, self.nx - 1 do
			local id = k * self.nx + i
			local h = top[id] or 0
			-- (the outermost ring is the arena's walls)
			local edge = i == 0 or k == 0 or i == self.nx - 1 or k == self.nz - 1
			if not edge and not under[id] and h <= STEP then
				class[id] = FREE
			elseif not edge and not under[id] and h <= HOP then
				class[id] = LOW
			else
				class[id] = WALL
			end
		end
	end
	self.class = class
	-- the open areas: squares that join up (4 ways) share a number, so "can it get there at all" is one look
	local comp, n = {}, 0
	for id0 = 0, self.nx * self.nz - 1 do
		if class[id0] ~= WALL and not comp[id0] then
			n += 1
			comp[id0] = n
			local stack = { id0 }
			while #stack > 0 do
				local id = table.remove(stack)
				local i, k = id % self.nx, id // self.nx
				for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
					local ii, kk = i + d[1], k + d[2]
					local nid = kk * self.nx + ii
					if
						ii >= 0
						and kk >= 0
						and ii < self.nx
						and kk < self.nz
						and class[nid] ~= WALL
						and not comp[nid]
					then
						comp[nid] = n
						table.insert(stack, nid)
					end
				end
			end
		end
	end
	self.comp = comp
	return self
end

function BotNav:_square(x, z)
	local i, k = math.floor((x - self.x0) / SQ), math.floor((z - self.z0) / SQ)
	if i < 0 or k < 0 or i >= self.nx or k >= self.nz then
		return nil
	end
	return i, k
end

function BotNav:_centre(i, k, y)
	return Vector3.new(self.x0 + (i + 0.5) * SQ, y, self.z0 + (k + 0.5) * SQ)
end

function BotNav:_class(i, k, now)
	local id = k * self.nx + i
	local c = self.class[id]
	local t = self.temp[id]
	if t and now and now < t then
		return WALL
	end
	return c
end

function BotNav:ClassAt(pos)
	local i, k = self:_square(pos.X, pos.Z)
	if not i then
		return nil
	end
	return self:_class(i, k, os.clock())
end

function BotNav:Block(pos, untilT)
	local i, k = self:_square(pos.X, pos.Z)
	if i then
		self.temp[k * self.nx + i] = untilT
	end
end

-- a square a path may use: FREE (or LOW), and on the right side of the line
local function allowed(self, i, k, side, now, lowOk)
	local c = self:_class(i, k, now)
	if c == WALL or (c == LOW and not lowOk) then
		return false
	end
	if side then
		local x = self.x0 + (i + 0.5) * SQ
		if (x - side.line) * side.fwd > -1.5 then
			return false
		end
	end
	return true
end

-- the nearest allowed square to (i, k), searching rings outward (nil if none within `reach` squares)
local function nearest(self, i, k, side, now, reach)
	if i and allowed(self, i, k, side, now, false) then
		return i, k
	end
	for r = 1, reach or 14 do
		local best, bi, bk
		for di = -r, r do
			for dk = -r, r do
				if math.max(math.abs(di), math.abs(dk)) == r then
					local ii, kk = i + di, k + dk
					if
						ii >= 0
						and kk >= 0
						and ii < self.nx
						and kk < self.nz
						and allowed(self, ii, kk, side, now, false)
					then
						local d = di * di + dk * dk
						if not best or d < best then
							best, bi, bk = d, ii, kk
						end
					end
				end
			end
		end
		if best then
			return bi, bk
		end
	end
	return nil
end

function BotNav:Free(pos, side)
	local i, k = self:_square(pos.X, pos.Z)
	if not i then
		i = math.clamp(math.floor((pos.X - self.x0) / SQ), 0, self.nx - 1)
		k = math.clamp(math.floor((pos.Z - self.z0) / SQ), 0, self.nz - 1)
	end
	local fi, fk = nearest(self, i, k, side, os.clock())
	if not fi then
		return nil
	end
	if fi == i and fk == k and self:_square(pos.X, pos.Z) then
		return pos
	end
	return self:_centre(fi, fk, pos.Y)
end

-- a straight walk from a to b over FREE squares only (sampled every half square)
function BotNav:Clear(a, b, side)
	local d = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local n = math.max(1, math.ceil(d.Magnitude / (SQ * 0.4)))
	local now = os.clock()
	for s = 0, n do
		local p = a + d * (s / n)
		local i, k = self:_square(p.X, p.Z)
		if not i or not allowed(self, i, k, side, now, false) then
			return false
		end
	end
	return true
end

-- A* over the squares (a small binary heap)
local function push(heap, node, f)
	table.insert(heap, { node, f })
	local c = #heap
	while c > 1 do
		local p = c // 2
		if heap[p][2] <= heap[c][2] then
			break
		end
		heap[p], heap[c] = heap[c], heap[p]
		c = p
	end
end
local function pop(heap)
	local top = heap[1]
	local last = table.remove(heap)
	if #heap > 0 then
		heap[1] = last
		local c = 1
		while true do
			local l, r, m = c * 2, c * 2 + 1, c
			if heap[l] and heap[l][2] < heap[m][2] then
				m = l
			end
			if heap[r] and heap[r][2] < heap[m][2] then
				m = r
			end
			if m == c then
				break
			end
			heap[m], heap[c] = heap[c], heap[m]
			c = m
		end
	end
	return top[1]
end

local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }

function BotNav:Path(from, to, side)
	local now = os.clock()
	local si, sk = self:_square(from.X, from.Z)
	if not si then
		return nil
	end
	local lead = {}
	-- (standing on something, or in a marked square: first to the nearest free square)
	if not allowed(self, si, sk, nil, now, true) then
		local fi, fk = nearest(self, si, sk, nil, now, 8)
		if not fi then
			return nil
		end
		si, sk = fi, fk
		table.insert(lead, self:_centre(si, sk, from.Y))
	end
	local gi, gk = self:_square(to.X, to.Z)
	gi, gk = nearest(self, gi or si, gk or sk, side, now, 14)
	if not gi then
		return nil
	end
	local nx = self.nx
	local start, goal = sk * nx + si, gk * nx + gi
	local g, came, closed = { [start] = 0 }, {}, {}
	local heap = {}
	local function h(i, k)
		local dx, dz = math.abs(i - gi), math.abs(k - gk)
		return math.max(dx, dz) + 0.41 * math.min(dx, dz)
	end
	push(heap, start, h(si, sk))
	local found = false
	local budget = 9000
	while #heap > 0 and budget > 0 do
		budget -= 1
		local cur = pop(heap)
		if cur == goal then
			found = true
			break
		end
		if not closed[cur] then
			closed[cur] = true
			local ci, ck = cur % nx, cur // nx
			for _, d in DIRS do
				local ii, kk = ci + d[1], ck + d[2]
				if ii >= 0 and kk >= 0 and ii < nx and kk < self.nz then
					local id = kk * nx + ii
					if not closed[id] and allowed(self, ii, kk, side, now, true) then
						local diag = d[1] ~= 0 and d[2] ~= 0
						if
							not diag
							or (
								allowed(self, ci + d[1], ck, side, now, true)
								and allowed(self, ci, ck + d[2], side, now, true)
							)
						then
							local cost = (diag and 1.41 or 1) * (self:_class(ii, kk, now) == LOW and 6 or 1)
							local ng = g[cur] + cost
							if not g[id] or ng < g[id] then
								g[id] = ng
								came[id] = cur
								push(heap, id, ng + h(ii, kk))
							end
						end
					end
				end
			end
		end
	end
	if not found then
		return nil
	end
	local out = {}
	local node = goal
	while node and node ~= start do
		table.insert(out, 1, self:_centre(node % nx, node // nx, from.Y))
		node = came[node]
	end
	for i = #lead, 1, -1 do
		table.insert(out, 1, lead[i])
	end
	-- (the last point: the goal itself when it's in the goal square, else that square's centre)
	local ti, tk = self:_square(to.X, to.Z)
	if ti == gi and tk == gk and #out > 0 then
		out[#out] = Vector3.new(to.X, from.Y, to.Z)
	elseif #out == 0 then
		table.insert(out, self:_centre(gi, gk, from.Y))
	end
	return out
end

-- Somewhere near pos from which dest can be reached at all (a bot shut in by structures, or wedged inside one): the
-- nearest square in the same open area as dest's nearest free square, within `reach` studs (nil if none)
function BotNav:Reach(pos, dest, side, reach)
	local di, dk = self:_square(dest.X, dest.Z)
	if not di then
		return nil
	end
	local now = os.clock()
	local gi, gk = nearest(self, di, dk, side, now, 14)
	if not gi then
		return nil
	end
	local want = self.comp[gk * self.nx + gi]
	local si, sk = self:_square(pos.X, pos.Z)
	if not si then
		return nil
	end
	if self.comp[sk * self.nx + si] == want and self.class[sk * self.nx + si] == FREE then
		return pos
	end
	for r = 1, math.ceil((reach or 16) / SQ) do
		local best, bi, bk
		for i = -r, r do
			for k = -r, r do
				if math.max(math.abs(i), math.abs(k)) == r then
					local ii, kk = si + i, sk + k
					local id = kk * self.nx + ii
					if
						ii >= 0
						and kk >= 0
						and ii < self.nx
						and kk < self.nz
						and self.class[id] == FREE
						and self.comp[id] == want
					then
						local d = i * i + k * k
						if not best or d < best then
							best, bi, bk = d, ii, kk
						end
					end
				end
			end
		end
		if best then
			return self:_centre(bi, bk, pos.Y)
		end
	end
	return nil
end

-- Is the square under pos one a jump gets over (for the bot to jump as it reaches it)?
function BotNav:Low(pos)
	return self:ClassAt(pos) == LOW
end

return BotNav
