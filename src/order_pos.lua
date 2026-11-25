-- order_pos.lua — read local hero position (to confirm movement).
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
local ok = entity.init(); if not ok then log("init fail"); return end
local oIsLocal = schema.offsetOf("CBasePlayerController", "m_bIsLocalPlayerController")
local oHeroPID = schema.offsetOf("C_DOTA_BaseNPC_Hero", "m_iPlayerID")
local oCtrlPID = schema.offsetOf("C_DOTAPlayerController", "m_nPlayerID")
local oSceneNode = schema.offsetOf("C_BaseEntity", "m_pGameSceneNode")
local oAbsOrigin = schema.offsetOf("CGameSceneNode", "m_vecAbsOrigin")
local function ri32(p, o) return tonumber(ffi.cast("int32_t*", p + o)[0]) end
local function ru8(p, o) return tonumber(ffi.cast("uint8_t*", p + o)[0]) end
local function rf32(p, o) return tonumber(ffi.cast("float*", p + o)[0]) end
local function rq(p, o) return tonumber(ffi.cast("uintptr_t*", p + o)[0]) end
local localPID
for idn in entity.iter() do
  local dn = entity.designerName(idn)
  if dn and dn:find("player_controller") then
    local inst = entity.instance(idn)
    if ru8(inst, oIsLocal) == 1 then localPID = ri32(inst, oCtrlPID); break end
  end
end
for idn in entity.iter() do
  local dn = entity.designerName(idn)
  if dn and dn:find("npc_dota_hero_") and not dn:find("announcer") then
    local inst = entity.instance(idn)
    if ri32(inst, oHeroPID) == localPID then
      local node = rq(inst, oSceneNode)
      log(string.format("HERO POS %s = %.1f %.1f %.1f", dn, rf32(node, oAbsOrigin), rf32(node, oAbsOrigin+4), rf32(node, oAbsOrigin+8)))
      break
    end
  end
end