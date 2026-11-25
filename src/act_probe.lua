-- act_probe.lua — resolve local hero, issue one move, then run Self Play ticks.
package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local ffi = require("ffi")
ffi.cdef[[ void Sleep(unsigned long ms); ]]
local loader = require("loader")
local entity = require("entity")
local menu = require("menu")
local orders = require("orders")
local schema = require("schema")
local logf = io.open("D:\\hake\\lotus\\host.log", "a")
local function log(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
  logf:write(os.date("%H:%M:%S ") .. table.concat(t, "\t") .. "\n"); logf:flush()
end
local function ri32(p, o)
  if not p then return nil end
  return tonumber(ffi.cast("int32_t*", p + o)[0])
end

log("=== ACT PROBE ===")
local script, err = loader.load()
if not script then log("LOAD FAIL", err); return end
for _, w in ipairs(menu.widgets) do
  if w.kind == "switch" and w.name and (w.name:find("Enable Self Play") or w.name:find("decision diagnostics")) then
    w.value = true
    log("enabled", w.name, w:Get())
  end
end

local h = entity.getLocalHero()
log("localHero", h and h.name or "NIL", "hp", h and h.health or "-", "pid", h and h.playerID or "-", "team", h and h.team or "-")
local gt, gs = GameRules.GetGameTime(), GameRules.GetGameStartTime()
log("state", GameRules.GetGameState(), "time", string.format("%.2f", gt),
    "start", string.format("%.2f", gs), "clock", string.format("%.2f", gt - gs), "in", tostring(Engine.IsInGame()))
log("Heroes.GetLocal", tostring(Heroes.GetLocal()), "Players.GetLocal", tostring(Players.GetLocal()))

if not h then
  local oIsLocal = schema.offsetOf("CBasePlayerController", "m_bIsLocalPlayerController")
  local oAssigned = schema.offsetOf("C_DOTAPlayerController", "m_hAssignedHero") or 2324
  local oPawn = schema.offsetOf("CBasePlayerController", "m_hPawn") or 1700
  local oPid = schema.offsetOf("C_DOTAPlayerController", "m_nPlayerID")
  local n = 0
  for idn in entity.iter() do
    local dn = entity.designerName(idn) or ""
    if dn:find("player_controller") then
      local inst = entity.instance(idn)
      local isLocal = tonumber(ffi.cast("uint8_t*", inst + oIsLocal)[0])
      if isLocal == 1 then
        n = n + 1
        local ah, pawn, pid = ri32(inst, oAssigned), ri32(inst, oPawn), ri32(inst, oPid)
        local resolved = entity.byHandle(ah)
        log(string.format("local ctrl#%d pid=%s assigned=%s pawn=%s resolved=%s",
          n, tostring(pid), tostring(ah), tostring(pawn), resolved and (entity.designerName(resolved) or "?") or "nil"))
      end
    end
  end
  log("no hero; controllers logged", n)
end

local function posOf(hero)
  if not hero then return nil end
  return orders.heroPosition(hero.instance)
end
local x0, y0, z0 = posOf(h)
log(string.format("start pos %.0f %.0f %.0f", x0 or 0, y0 or 0, z0 or 0))

log("running 1 bot tick")
local t0 = os.clock()
loader.tick()
log(string.format("tick seconds %.1f", os.clock() - t0))
do
  local hh = entity.getLocalHero()
  local x, y = posOf(hh)
  log(string.format("tick 1 pos %.0f %.0f hero %s", x or 0, y or 0, hh and hh.name or "nil"))
end
local h2 = entity.getLocalHero()
local x1, y1 = posOf(h2)
local delta = (x0 and x1) and math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2) or -1
log(string.format("end pos %.0f %.0f delta %.0f", x1 or 0, y1 or 0, delta))
log("=== ACT PROBE done ===")
