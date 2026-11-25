-- diag_perf.lua — Lead profiling pass: where do the 100+s in-match ticks go?
package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local ffi = require("ffi")
ffi.cdef[[ unsigned long long GetTickCount64(void); void Sleep(unsigned long ms); ]]
local loader = require("loader")
local logf = io.open("D:\\hake\\lotus\\host.log", "a")
local function log(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
  logf:write(os.date("%H:%M:%S ") .. table.concat(t, "\t") .. "\n"); logf:flush()
end
local function now() return tonumber(ffi.C.GetTickCount64()) / 1000.0 end

log("[perfd] === diag_perf start ===")
local t0 = now()
local script, err = loader.load()
log(string.format("[perfd] load=%.2fs ok=%s %s", now() - t0, tostring(script ~= nil), tostring(err)))
if not script then log("[perfd] FAIL load"); return end

-- call counters for the hottest namespaces (cheap wrappers)
local counts = {}
local function wrapNS(ns, names)
  local t = _G[ns]; if not t then return end
  for _, name in ipairs(names) do
    local orig = t[name]
    if type(orig) == "function" then
      local key = ns .. "." .. name
      counts[key] = 0
      t[name] = function(...)
        counts[key] = counts[key] + 1
        return orig(...)
      end
    end
  end
end
wrapNS("Entity", { "GetAbsOrigin", "GetHealth", "IsAlive", "GetIndex", "IsEntity", "GetTeamNum", "IsSameTeam" })
wrapNS("NPC", { "IsHero", "IsCreep", "IsTower", "IsBuilding", "IsVisible", "GetUnitName", "GetAttackRange", "HasModifier", "GetModifiers" })
wrapNS("Players", { "GetAll", "GetLocal" })
wrapNS("Player", { "GetTeamPlayer", "GetTeamData", "GetTotalGold", "GetPlayerID" })
wrapNS("Heroes", { "GetAll", "GetLocal" })
wrapNS("GameRules", { "GetGameTime", "GetGameState" })
wrapNS("GridNav", { "IsTraversable", "BuildPath" })
wrapNS("NPCs", { "GetAll", "InRadius" })
wrapNS("Ability", { "GetLevel", "GetName", "GetCastRange", "IsReady", "GetCooldown" })
wrapNS("Modifier", { "GetName", "GetDieTime", "GetDuration", "GetStackCount" })

local function report(tag)
  local keys = {}
  for k in pairs(counts) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return counts[a] > counts[b] end)
  local parts = {}
  for i = 1, math.min(8, #keys) do parts[#parts + 1] = keys[i] .. "=" .. counts[keys[i]] end
  log("[perfd] " .. tag .. " calls: " .. table.concat(parts, " "))
end

local function reset()
  for k in pairs(counts) do counts[k] = 0 end
end

local function timeCall(tag, fn)
  reset()
  local a = now()
  local ok, e = pcall(fn)
  local dt = now() - a
  log(string.format("[perfd] %s = %.2fs ok=%s %s", tag, dt, tostring(ok), ok and "" or tostring(e)))
  report(tag)
  return dt, ok, e
end

-- two passes: first is warmup, second is representative
for pass = 1, 2 do
  timeCall("pass" .. pass .. ".OnUpdateEx", function() if script.OnUpdateEx then script.OnUpdateEx() end end)
  timeCall("pass" .. pass .. ".OnUpdate", function() if script.OnUpdate then script.OnUpdate() end end)
  timeCall("pass" .. pass .. ".OnDraw", function() if script.OnDraw then script.OnDraw() end end)
end

log("[perfd] === diag_perf done ===")