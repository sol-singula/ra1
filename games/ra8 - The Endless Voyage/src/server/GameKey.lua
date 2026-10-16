--[[
The studio's shared key for its game-log and analytics functions (Constants.GAME_LOG_URL, ANALYTICS_URL): a secret
named "discord_log" in the experience's Secrets Store, allowed for the domain kvedatksqkcsgivntskb.supabase.co.

While it's missing it's looked for again every minute, so a secret added while a server runs is picked up without
restarting it. Whatever goes wrong (no secret, HTTP requests off, the domain not allowed, a wrong key) is said in
the server's log (F9, Server) once a minute, with the reason, so a quiet Discord channel can be explained in-game.
]]
local HttpService = game:GetService("HttpService")

local GameKey = {}

local key
local lookedAt = -math.huge
local said = {}

-- Say a problem in the server's log, once a minute per kind of problem.
function GameKey.warn(kind, text)
	local t = os.clock()
	if said[kind] and t - said[kind] < 60 then
		return
	end
	said[kind] = t
	warn("[GameLog] " .. text)
end

-- The key, or nil while there isn't one.
function GameKey.get()
	if key then
		return key
	end
	if os.clock() - lookedAt < 60 then
		return nil
	end
	lookedAt = os.clock()
	local ok, value = pcall(HttpService.GetSecret, HttpService, "discord_log")
	if ok and value then
		key = value
		return key
	end
	local why = tostring(value)
	GameKey.warn(
		"secret",
		`no "discord_log" secret for this experience (Creator Dashboard, Secrets): logs are off ({why})`
	)
	return nil
end

-- POST a JSON batch with the key. true when it went through; else the reason goes to the server's log.
function GameKey.post(url, payload, kind)
	local k = GameKey.get()
	if not k then
		return false
	end
	local ok, res = pcall(HttpService.RequestAsync, HttpService, {
		Url = url,
		Method = "POST",
		Headers = { ["Content-Type"] = "application/json", ["X-Game-Key"] = k },
		Body = HttpService:JSONEncode(payload),
	})
	if not ok then
		-- (HTTP requests switched off, or the secret not allowed for this domain)
		GameKey.warn(
			kind .. "_error",
			`{kind}: couldn't send ({tostring(res)}). Is "Allow HTTP Requests" on, and is the secret's domain kvedatksqkcsgivntskb.supabase.co?`
		)
		return false
	end
	if not res.Success then
		local why = res.StatusCode == 401 and "the key is wrong (the secret's value isn't the studio's game key)"
			or tostring(res.StatusCode) .. " " .. tostring(res.StatusMessage)
		GameKey.warn(kind .. "_status", `{kind}: the server said no: {why}`)
		return false
	end
	return true
end

return GameKey
