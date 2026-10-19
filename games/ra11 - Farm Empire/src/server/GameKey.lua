--[[
The studio's shared key for its game-log and analytics functions (Constants.GAME_LOG_URL, ANALYTICS_URL): a secret
named "discord_log" in the experience's Secrets Store, allowed for the domain kvedatksqkcsgivntskb.supabase.co.

While it's missing it's looked for again every minute, so a secret added while a server runs is picked up without
restarting it. Whatever goes wrong (no secret, HTTP requests off, the domain not allowed, a wrong key) is said in
the server's log (F9, Server) once a minute, with the reason, so a quiet Discord channel can be explained in-game.
It's also reported to the studio without the key: a request with no key (the function turns it away with a 401)
whose address says what went wrong, readable in Supabase (Edge Functions, roblox-game-log, Logs) with no one in
the server's console. If even that never shows up, HTTP requests are off for the place.
]]
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)

local GameKey = {}

local key
local lookedAt = -math.huge
local said = {}
local reported = {}

-- Report a problem to the studio's function without the key (never the key itself, only what went wrong), once a
-- minute per kind of problem: "...roblox-game-log?diag=nosecret&game=ra11&place=...&why=...".
function GameKey.report(kind, why)
	local t = os.clock()
	if reported[kind] and t - reported[kind] < 60 then
		return
	end
	reported[kind] = t
	task.spawn(pcall, function()
		local url = `{Constants.GAME_LOG_URL}?diag={kind}&game={Constants.GAME}&place={game.PlaceId}&v={game.PlaceVersion}`
			.. `&job={string.sub(game.JobId, 1, 8)}&why={HttpService:UrlEncode(string.sub(tostring(why), 1, 160))}`
		HttpService:RequestAsync({
			Url = url,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = "{}",
		})
	end)
end

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
	GameKey.report("nosecret", why)
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
		GameKey.report("senderror", res)
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
