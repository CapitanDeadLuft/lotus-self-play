-- order_call.lua — issue a MOVE_TO_POSITION order to the local hero via PrepareUnitOrders.
package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local ffi = require("ffi")
local C = ffi.C
local entity = require("entity")
local schema = require("schema")
local logf = io.open("D:\\hake\\lotus\\host.log", "a")
local function log(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
  logf:write(os.date("%H:%M:%S ") .. table.concat(t, "\t") .. "\n"); logf:flush()
end
local function hex(v) return string.format("0x%X", tonumber(ffi.cast("uintptr_t", v))) end
ffi.cdef[[
  void* GetModuleHandleA(const char* name);
  typedef bool (*PrepareUnitOrdersFn)(void* player, int orderType, uint32_t targetIndex,
      float* position, uint32_t abilityIndex, int orderIssuer, void* issuer, bool queue, bool showEffects);
]]
local client = C.GetModuleHandleA("client.dll")
local cb = ffi.cast("uintptr_t", client)
local PUO = ffi.cast("PrepareUnitOrdersFn", cb + 0x1B5F860)
log("=== order CALL === PrepareUnitOrders =", hex(PUO))

local ok, err = entity.init(); if not ok then log("init fail", err); return end
local oIsLocal = schema.offsetOf("CBasePlayerController", "m_bIsLocalPlayerController")
local oHeroPID = schema.offsetOf("C_DOTA_BaseNPC_Hero", "m_iPlayerID")
local oCtrlPID = schema.offsetOf("C_DOTAPlayerController", "m_nPlayerID")
local oSceneNode = schema.offsetOf("C_BaseEntity", "m_pGameSceneNode")
local oAbsOrigin = schema.offsetOf("CGameSceneNode", "m_vecAbsOrigin")
local function ri32(p, o) return tonumber(ffi.cast("int32_t*", p + o)[0]) end
local function ru8(p, o) return tonumber(ffi.cast("uint8_t*", p + o)[0]) end
local function rf32(p, o) return tonumber(ffi.cast("float*", p + o)[0]) end
local function rq(p, o) return tonumber(ffi.cast("uintptr_t*", p + o)[0]) end

local localCtrl, localPID
for idn in entity.iter() do
  local dn = entity.designerName(idn)
  if dn and dn:find("player_controller") then
    local inst = entity.instance(idn)
    if ru8(inst, oIsLocal) == 1 then localCtrl = inst; localPID = ri32(inst, oCtrlPID); break end
  end
end
local heroInst, heroName
for idn in entity.iter() do
  local dn = entity.designerName(idn)
  if dn and dn:find("npc_dota_hero_") and not dn:find("announcer") then
    local inst = entity.instance(idn)
    if ri32(inst, oHeroPID) == localPID then heroInst = inst; heroName = dn; break end
  end
end
if not localCtrl or not heroInst then log("missing ctrl/hero"); return end
local node = rq(heroInst, oSceneNode)
local x, y, z = rf32(node, oAbsOrigin), rf32(node, oAbsOrigin + 4), rf32(node, oAbsOrigin + 8)
log(string.format("hero %s at %.1f %.1f %.1f", heroName, x, y, z))

-- move +300 X
local pos = ffi.new("float[3]", x + 300, y, z)
local DOTA_UNIT_ORDER_MOVE_TO_POSITION = 1
local DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY = 3
log(string.format("issuing MOVE to %.1f %.1f %.1f ...", x + 300, y, z))
local ret = PUO(ffi.cast("void*", localCtrl), DOTA_UNIT_ORDER_MOVE_TO_POSITION, 0, pos, 0, DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, ffi.cast("void*", heroInst), false, true)
log("PrepareUnitOrders returned:", ret)
log("=== order CALL done ===")