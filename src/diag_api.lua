package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local req = function(n) local ok, m = pcall(require, n); return ok and m or nil end
local api = req("api")
local loader = req("loader")
local logf = io.open("D:\\hake\\lotus\\host.log", "a")
local function log(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
  logf:write(os.date("%H:%M:%S ") .. table.concat(t, "\t") .. "\n"); logf:flush()
end
local function info(name, fn)
  local i = fn and debug.getinfo(fn, "S")
  log(string.format("API %s type=%s src=%s:%s", name, type(fn),
    i and (i.short_src or "?") or "-", i and (i.currentline or "?") or "-"))
end
local P = rawget(_G, "Player") or (api and api.Player)
local N = rawget(_G, "NPC") or (api and api.NPC)
info("Player.GetPlayerNeutralInfo", P and P.GetPlayerNeutralInfo)
info("NPC.GetStatesDuration", N and N.GetStatesDuration)
local ok, res = pcall(P.GetPlayerNeutralInfo, nil)
log("neutralInfo call ok=", tostring(ok), "type=", type(res), "times_crafted=", tostring(type(res) == "table" and tostring(res.times_crafted) or "-"))
local ok2, res2 = pcall(N.GetStatesDuration, nil, {}, true)
log("statesDuration ok=", tostring(ok2), "type=", type(res2), "value=", tostring(res2))
log("DIAG api done")