-- local_hero.lua — find local player controller (m_bIsLocalPlayerController) -> match hero by playerID.
package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local ffi = require("ffi")
local entity = require("entity")
local schema = require("schema")
local logf = io.open("D:\\hake\\lotus\\host.log", "a")
local function log(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
  logf:write(os.date("%H:%M:%S ") .. table.concat(t, "\t") .. "\n"); logf:flush()
end
local function hex(v) return string.format("0x%X", tonumber(ffi.cast("uintptr_t", v))) end
local function ru8(inst, off)
  if not inst then return nil end
  local a = inst + off
  if a < 0x10000 or a > 0x7FFFFFFFFFFF then return nil end
  return tonumber(ffi.cast("uint8_t*", a)[0])
end
local function ri32(inst, off)
  if not inst then return nil end
  local a = inst + off
  if a < 0x10000 or a > 0x7FFFFFFFFFFF then return nil end
  return tonumber(ffi.cast("int32_t*", a)[0])
end
log("=== local HERO ===")
local ok, err = entity.init(); log("init:", ok, err)
if not ok then return end

local oIsLocal = schema.offsetOf("CBasePlayerController", "m_bIsLocalPlayerController") or 0x778
local oCtrlPID = schema.offsetOf("C_DOTAPlayerController", "m_nPlayerID") or 0x910
local oHeroPID = schema.offsetOf("C_DOTA_BaseNPC_Hero", "m_iPlayerID") or 0x1b68

local localPID = nil
local controllers = 0
for idn in entity.iter() do
  local dn = entity.designerName(idn)
  if dn and dn:find("player_controller") then
    controllers = controllers + 1
    local inst = entity.instance(idn)
    local isLocal = ru8(inst, oIsLocal)
    local pid = ri32(inst, oCtrlPID)
    log(string.format("  controller %s pid=%s isLocal=%s", dn, tostring(pid), tostring(isLocal)))
    if isLocal == 1 then localPID = pid end
  end
end
log("controllers =", controllers, "localPID =", tostring(localPID))

if localPID then
  for idn in entity.iter() do
    local dn = entity.designerName(idn)
    if dn and dn:find("npc_dota_hero_") and not dn:find("announcer") then
      local inst = entity.instance(idn)
      local hpid = ri32(inst, oHeroPID)
      if hpid == localPID then
        log(string.format("  LOCAL HERO = %s hp=%s team=%s playerID=%s inst=%s",
          dn, tostring(entity.health(idn)), tostring(entity.team(idn)), tostring(hpid), hex(inst)))
      end
    end
  end
end
log("=== local HERO done ===")