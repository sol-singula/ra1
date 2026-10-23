--[[
  TableUtil.deepCopy(t)             a full copy (tables only; other values are shared)
  TableUtil.reconcile(t, template, skip?)   fills every key missing from t with a copy of template's value, recursing
                                    into tables that exist on both sides; never overwrites a value that is there.
                                    skip[key] = true fills that key only when it's missing entirely (no recursion),
                                    for maps whose template holds starting entries (seeds = { carrot = 3 })
  TableUtil.replaceContents(t, src) makes t hold exactly src's keys (in place: references to t stay valid)
  TableUtil.deepFreeze(t)           freezes t and every table inside it; returns t
]]
local TableUtil = {}

function TableUtil.deepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local out = {}
	for k, v in t do
		out[k] = TableUtil.deepCopy(v)
	end
	return out
end

function TableUtil.reconcile(t, template, skip)
	for k, v in template do
		if t[k] == nil then
			t[k] = TableUtil.deepCopy(v)
		elseif type(v) == "table" and type(t[k]) == "table" and not (skip and skip[k]) then
			TableUtil.reconcile(t[k], v)
		end
	end
	return t
end

function TableUtil.replaceContents(t, src)
	table.clear(t)
	for k, v in src do
		t[k] = v
	end
	return t
end

function TableUtil.deepFreeze(t)
	for _, v in t do
		if type(v) == "table" and not table.isfrozen(v) then
			TableUtil.deepFreeze(v)
		end
	end
	if not table.isfrozen(t) then
		table.freeze(t)
	end
	return t
end

return TableUtil
