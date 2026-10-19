--[[
The visual simulation of the store (master plan §12, layer B): a pool of little customers who walk up from the
avenue, stand in the line, buy and leave with a bag; the line's length follows the server's queue; the workers
behind the counter at the shop stage; the crates in the stock area follow the stock. Representative, not one a
sale: thirty sales a minute look like six or eight people on the path.

  CustomerController.walking()   how many customers are on the path (tests)
  CustomerController.queue()     the line's length drawn
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Layout = require(ReplicatedStorage.Shared.World.Layout)
local Models = require(ReplicatedStorage.Shared.World.Models)
local Net = require(ReplicatedStorage.Shared.Net)
local Shapes = require(ReplicatedStorage.Shared.World.Shapes)
local Store = require(script.Parent.Parent.Store)

local CustomerController = { Name = "CustomerController", Order = 40, MAX = 8, SPEED = 8, STAY = 1.4 }

local folder
local people = {} -- { model, phase ("in" | "queue" | "buy" | "out"), from, to, t0, slot }
local workers = {}
local crates = {}
local nextId = 0
local pendingSales = 0

local function territoryIndex()
	local t = Store.get("territory")
	return t and t.index
end

local function at(x, z, y)
	return Layout.toWorld(territoryIndex(), x, z, y or 0)
end

local function counterSpot(slot)
	local s = Layout.SPOTS.stand
	local stage = Store.get("business") and Store.get("business").stage or "stand"
	local front = stage == "stand" and s.z - 4.2 or s.z - 6
	return at(s.x + 1.5, front - (slot or 0) * 2.4)
end

local function spawnPerson()
	if not territoryIndex() or #people >= CustomerController.MAX then
		return
	end
	nextId += 1
	local m = Models.person(folder, nextId)
	local s = Layout.SPOTS.stand
	local from = at(s.x + 6 + (nextId % 3) * 3, -Layout.DEPTH / 2 - 8)
	local queueLen = 0
	for _, pr in people do
		if pr.phase == "queue" or pr.phase == "buy" then
			queueLen += 1
		end
	end
	local p = { model = m, phase = "in", from = from, to = counterSpot(queueLen), t0 = os.clock(), slot = queueLen }
	Models.place(m, CFrame.lookAt(from, p.to))
	table.insert(people, p)
end

function CustomerController.walking()
	return #people
end

function CustomerController.queue()
	local n = 0
	for _, p in people do
		if p.phase == "queue" or p.phase == "buy" then
			n += 1
		end
	end
	return n
end

local function step()
	if not territoryIndex() then
		return
	end
	local t = os.clock()
	local b = Store.get("business")
	local wantQueue = b and math.min(b.queue or 0, 6) or 0
	-- people arrive while sales come in or the line is meant to be longer than it's drawn
	if pendingSales > 0 or CustomerController.queue() < wantQueue then
		if #people < CustomerController.MAX and (t - (CustomerController._lastSpawn or 0)) > 0.6 then
			CustomerController._lastSpawn = t
			pendingSales = math.max(0, pendingSales - 1)
			spawnPerson()
		end
	end
	-- the slots: whoever is at the front buys
	local slot = 0
	for i = #people, 1, -1 do
		local p = people[i]
		local flat = p.to - p.from
		local secs = math.max(0.1, Vector3.new(flat.X, 0, flat.Z).Magnitude / CustomerController.SPEED)
		local k = (t - p.t0) / secs
		if p.phase == "in" then
			if k >= 1 then
				p.phase, p.t0 = "queue", t
				Models.place(p.model, CFrame.lookAt(p.to, p.to + (p.to - p.from)))
			else
				local pos = p.from:Lerp(p.to, k)
				Models.place(p.model, CFrame.lookAt(pos, pos + (p.to - p.from)), t * 10)
			end
		elseif p.phase == "queue" then
			-- shuffle up: my slot is the number of people ahead of me still in the line
			local ahead = 0
			for j = 1, i - 1 do
				if people[j].phase == "queue" or people[j].phase == "buy" then
					ahead += 1
				end
			end
			local want = counterSpot(ahead)
			local pos = p.to:Lerp(want, 0.15)
			p.to = pos
			Models.place(p.model, CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1) * 0 + (counterSpot(-1) - pos)))
			if ahead == 0 and t - p.t0 > 0.4 then
				p.phase, p.t0 = "buy", t
				Models.bag(p.model)
			end
		elseif p.phase == "buy" then
			if t - p.t0 >= CustomerController.STAY then
				p.phase, p.t0 = "out", t
				p.from, p.to = p.to, p.from
				-- (back out the way they came, a little aside)
				p.to = p.to + Vector3.new(0, 0, 0)
			end
		else
			if k >= 1 then
				p.model:Destroy()
				table.remove(people, i)
			else
				local pos = p.from:Lerp(p.to, k)
				Models.place(p.model, CFrame.lookAt(pos, pos + (p.to - p.from)), t * 10)
			end
		end
		slot += 1
	end
	-- the workers restock: a little walk between the stock area and the counter
	for i, w in workers do
		local phase = (t * 0.6 + i) % 2
		local a, bpos = w.a, w.b
		local pos = phase < 1 and a:Lerp(bpos, phase) or bpos:Lerp(a, phase - 1)
		Models.place(w.model, CFrame.lookAt(pos, pos + (phase < 1 and (bpos - a) or (a - bpos))), t * 8)
	end
end

-- The workers and the crates follow the business
local function rebuild()
	local b = Store.get("business")
	local i = territoryIndex()
	if not b or not i then
		return
	end
	for _, w in workers do
		w.model:Destroy()
	end
	workers = {}
	local s = Layout.SPOTS.stand
	for k = 1, math.min(b.workers or 0, 4) do
		local m = Models.person(folder, 100 + k, Constants.PALETTE.roofGreen)
		table.insert(workers, { model = m, a = at(s.x - 6 + k * 3, s.z + 6), b = at(s.x - 6 + k * 3, s.z + 1) })
	end
	-- crates: one for every 10% of the storage used, up to 9
	for _, c in crates do
		c:Destroy()
	end
	crates = {}
	local n = b.storage > 0 and math.floor(b.stock / b.storage * 9 + 0.5) or 0
	local base = b.stage == "stand" and CFrame.new(at(s.x - 4, s.z + 4.5)) or CFrame.new(at(s.x + 8, s.z + 8))
	for k = 1, n do
		local c = Shapes.part(
			folder,
			Vector3.new(1.6, 1.4, 1.6),
			base * CFrame.new(((k - 1) % 3) * 1.8, 0.7 + ((k - 1) // 3) * 1.4, 0),
			Constants.PALETTE.wood,
			{ CanQuery = false }
		)
		c.Name = "Crate"
		table.insert(crates, c)
	end
end

function CustomerController:init()
	folder = Instance.new("Folder")
	folder.Name = "Customers"
	folder.Parent = workspace
	Net.listen("Sale", function(m)
		if type(m) == "table" then
			pendingSales = math.min(pendingSales + 1, 4)
		end
	end)
	local lastStage, lastCrates
	Store.Changed:Connect(function(partial)
		if partial.business or partial.territory then
			local b = Store.get("business")
			local n = b and b.storage > 0 and math.floor(b.stock / b.storage * 9 + 0.5) or 0
			local key = (b and b.stage or "") .. (b and b.workers or 0)
			if key ~= lastStage or n ~= lastCrates then
				lastStage, lastCrates = key, n
				rebuild()
			end
		end
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 1 / 30 then
			return
		end
		acc = 0
		step()
	end)
	_ = Players
end

return CustomerController
