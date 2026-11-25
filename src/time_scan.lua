package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local ffi = require("ffi")
ffi.cdef[[ void Sleep(unsigned long ms); ]]
local entity = require("entity")
local schema = require("schema")
local logf = io.open("D:\\hake\\lotus\\host.log", "a")
local function log(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
  logf:write(os.date("%H:%M:%S ") .. table.concat(t, "\t") .. "\n"); logf:flush()
end
local function f32(p, o)
  if not p or p < 0x10000 then return nil end
  local ok, v = pcall(function() return tonumber(ffi.cast("float*", p + o)[0]) end)
  if not ok then return nil end
  return v
end
entity.init()
local hero = entity.getLocalHero()
local creep
for idn in entity.iter() do
  local dn = entity.designerName(idn) or ""
  if dn:find("npc_dota_creep_lane") then creep = entity.instance(idn); break end
end
local ctrl
local oIsLocal = schema.offsetOf("CBasePlayerController", "m_bIsLocalPlayerController")
for idn in entity.iter() do
  local dn = entity.designerName(idn) or ""
  if dn:find("player_controller") then
    local inst = entity.instance(idn)
    if inst and tonumber(ffi.cast("uint8_t*", inst + oIsLocal)[0]) == 1 then ctrl = inst; break end
  end
end
local fields = {
  { "hero.sim", hero and hero.instance, schema.offsetOf("C_BaseEntity", "m_flSimulationTime") or 952 },
  { "hero.oldsim", hero and hero.instance, schema.offsetOf("C_BasePlayerPawn", "m_flOldSimulationTime") or 3500 },
  { "hero.cam", hero and hero.instance, schema.offsetOf("C_BasePlayerPawn", "m_flLastCameraSetupTime") or 3476 },
  { "hero.pred", hero and hero.instance, schema.offsetOf("C_BasePlayerPawn", "m_flPredictionErrorTime") or 3428 },
  { "hero.death", hero and hero.instance, schema.offsetOf("C_BasePlayerPawn", "m_flDeathTime") or 3408 },
  { "creep.sim", creep, schema.offsetOf("C_BaseEntity", "m_flSimulationTime") or 952 },
  { "ctrl.orders", ctrl, schema.offsetOf("C_DOTAPlayerController", "m_flUnitOrdersSendTime") or 2368 },
  { "ctrl.lastOrders", ctrl, schema.offsetOf("C_DOTAPlayerController", "m_flLastUnitOrdersSendTime") or 2372 },
  { "ctrl.ping", ctrl, schema.offsetOf("C_DOTAPlayerController", "m_flLastPingTime") or 2380 },
}
log("=== TIME SCAN ===", hero and hero.name or "nohero", "creep", tostring(creep), "ctrl", tostring(ctrl))
local a = {}
for _, f in ipairs(fields) do a[f[1]] = f32(f[2], f[3]) end
ffi.C.Sleep(500)
local moved = {}
for _, f in ipairs(fields) do
  local b = f32(f[2], f[3])
  local d = (a[f[1]] and b) and (b - a[f[1]]) or nil
  log(string.format("%s off=%s a=%s b=%s d=%s", f[1], tostring(f[3]), tostring(a[f[1]]), tostring(b), tostring(d)))
  if d and d > 0.2 and d < 1.2 then moved[#moved+1] = f[1] .. "=" .. string.format("%.3f", b) end
end
log("ticking", #moved > 0 and table.concat(moved, " ") or "NONE")
log("=== TIME SCAN done ===")
