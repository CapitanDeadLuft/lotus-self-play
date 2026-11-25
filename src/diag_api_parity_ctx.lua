-- diag_api_parity_ctx.lua -- task-21 loader-context entry for diag_api_parity.lua
-- -----------------------------------------------------------------------
-- WHY: the baseline parity run executed in a BARE script Lua state (run.txt spawns a
-- fresh state), so loader-owned namespaces (Item/Modifier/World/GridNav/FogOfWar/
-- Tower/Bottle/Tree/PowerTreads) were absent and showed up as MISSING/ERROR artifacts.
-- bot_loop.lua:6 bootstraps those namespaces with `local loader = require("loader")`
-- (loader.lua installs the shims via stubNS/define). This entry does the same bootstrap
-- and then runs the shared audit body (`dofile diag_api_parity.lua`) in this state, so
-- the corrected baseline is authoritative for both api-owned and loader-owned surfaces.
-- Writes host.log only; requiring the loader module does not start host threads
-- (it only defines module functions + namespace shims; threads live in host16.dll).
-- -----------------------------------------------------------------------

package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path

local f = io.open("D:\\hake\\lotus\\host.log", "a")
local function log(...)
  if not f then return end
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
  f:write(os.date("%H:%M:%S ") .. table.concat(t, "\t") .. "\n")
  f:flush()
end

local okL, loader = pcall(require, "loader")
log("[parity-ctx] loader bootstrap=", tostring(okL),
  " err=", tostring(okL and "" or loader),
  " tick=", tostring(okL and type(loader and loader.tick)),
  " Item=", tostring(rawget(_G, "Item") ~= nil),
  " Modifier=", tostring(rawget(_G, "Modifier") ~= nil),
  " World=", tostring(rawget(_G, "World") ~= nil),
  " GridNav=", tostring(rawget(_G, "GridNav") ~= nil),
  " Tower=", tostring(rawget(_G, "Tower") ~= nil),
  " Tree=", tostring(rawget(_G, "Tree") ~= nil),
  " Bottle=", tostring(rawget(_G, "Bottle") ~= nil),
  " PowerTreads=", tostring(rawget(_G, "PowerTreads") ~= nil))

-- GLOBALS manifest (task-25 companion): the 16.11 scripts call Umbrella globals that
-- are NOT api namespaces. Report presence + shape so the "not ported" list is explicit.
-- Expected shapes per D:\hake\lotus\umbrella_api\GLOBALS_API.md (table of groups/camps/
-- damage-prediction library/KV library; XHelpers = loader KV helper table).
local function gshape(v)
  if v == nil then return "nil" end
  local t = type(v)
  if t ~= "table" then return t .. "=" .. tostring(v) end
  local n, keys = 0, {}
  for k in pairs(v) do
    n = n + 1
    if #keys < 6 then keys[#keys + 1] = tostring(k) end
  end
  local extra = ""
  for _, sub in ipairs({ "visible_ally", "visible_enemy", "invisible_ally", "invisible_enemy",
    "camps", "groups", "list", "pool", "libraries" }) do
    if type(v[sub]) == "table" then
      local m = 0
      for _ in pairs(v[sub]) do m = m + 1 end
      extra = extra .. string.format(" %s=%d", sub, m)
    end
  end
  return string.format("table keys=%d [%s]%s", n, table.concat(keys, ","), extra)
end
for _, gname in ipairs({ "LaneGroupsManager", "LaneCreepsManager", "JungleCampsManager",
  "LIB_DAMAGE_PREDICTION", "KV_LIB", "XHelpers", "_G.CACHE", "HeroInfoCache" }) do
  log(string.format("[parity-ctx] GLOBAL %-22s = %s", gname, gshape(rawget(_G, gname))))
end
-- orders-nav/loader-events coordination: warm nav's static grid in THIS state (virgin
-- module => statsValid=false/campSites=0/groundZ=128 otherwise) and try one globals
-- update via any loader-side hook before the parity body emits rows.
do
  local before, after, okr = false, false, false
  local function navValid()
    local okn, n = pcall(require, "nav")
    if not okn or not n or not n.stats then return false end
    local okS, s = pcall(n.stats)
    return (okS and type(s) == "table" and s.valid == true)
  end
  before = navValid()
  okr = pcall(function() local n = require("nav"); if n and n.rescan then n.rescan() end end)
  after = navValid()
  log(string.format("[parity-context] rescan ok=%s valid_before=%s valid_after=%s",
    tostring(okr), tostring(before), tostring(after)))
end
pcall(function()
  local okG, g = pcall(require, "globals")
  if okG and g then
    if type(g.update) == "function" then g.update() end
    if type(g.refresh) == "function" then g.refresh() end
    if type(g.tick) == "function" then g.tick() end
  end
end)
pcall(function()
  if loader then
    if type(loader.updateGlobals) == "function" then loader.updateGlobals() end
    if type(loader.tick) == "function" then loader.tick() end
  end
end)
local okD, err = pcall(dofile, "D:\\hake\\lotus\\src\\diag_api_parity.lua")
-- loader-side carrier (loader-events task-23): loader.parityProbe() returns ordered
-- row strings for the loader-owned namespaces (Item/Modifier/World/FogOfWar/GridNav
-- + globals). Appended after the shared api-owned body so one run yields both surfaces.
if okL and loader and type(loader.parityProbe) == "function" then
  local okP, rows = pcall(loader.parityProbe)
  log("[parity-ctx] loader.parityProbe ok=", tostring(okP), " rows=",
    tostring(okP and type(rows) == "table" and #rows or "n/a"))
  if okP and type(rows) == "table" then
    for _, r in ipairs(rows) do log(tostring(r)) end
  elseif not okP then
    log("[parity-ctx] loader.parityProbe raised: ", tostring(rows))
  end
else
  log("[parity-ctx] loader.parityProbe absent (loader-events batch not loaded) -> globals manifest above is authoritative")
end
log("[parity-ctx] parity diag ok=", tostring(okD), " err=", tostring(okD and "" or err))
if f then f:close() end