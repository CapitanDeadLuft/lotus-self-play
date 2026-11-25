-- order_verify.lua — verify PrepareUnitOrders prologue + gather order args (local controller, hero, pos).
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
ffi.cdef[[ void* GetModuleHandleA(const char* name); ]]
local client = C.GetModuleHandleA("client.dll")
local cb = ffi.cast("uintptr_t", client)
log("=== order VERIFY ===")
-- prologue at PrepareUnitOrders RVA 0x1B5F860
local fn = cb + 0x1B5F860
local bytes = {}
for i = 0, 31 do bytes[#bytes+1] = string.format("%02X", ffi.cast("uint8_t*", fn + i)[0]) end
log("PrepareUnitOrders @ " .. hex(fn) .. " prologue: " .. table.concat(bytes, " "))

local ok, err = entity.init(); log("entity.init:", ok, err)
if not ok then return end
local oIsLocal = schema.offsetOf("CBasePlayerController", "m_bIsLocalPlayerController")
local oHeroPID = schema.offsetOf("C_DOTA_BaseNPC_Hero", "m_iPlayerID")
local oCtrlPID = schema.offsetOf("C_DOTAPlayerController", "m_nPlayerID")
local oSceneNode = schema.offsetOf("C_BaseEntity", "m_pGameSceneNode")
local oAbsOrigin = schema.offsetOf("CGameSceneNode", "m_vecAbsOrigin")
log("offsets: isLocal=" .. hex(oIsLocal) .. " sceneNode=" .. hex(oSceneNode) .. " absOrigin=" .. hex(oAbsOrigin))

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
log("local controller instance =", hex(localCtrl), "pid =", tostring(localPID))

local heroInst
for idn in entity.iter() do
  local dn = entity.designerName(idn)
  if dn and dn:find("npc_dota_hero_") and not dn:find("announcer") then
    local inst = entity.instance(idn)
    if ri32(inst, oHeroPID) == localPID then heroInst = inst; log("local hero =", dn, "inst =", hex(inst)); break end
  end
end
if heroInst and oSceneNode and oAbsOrigin then
  local node = rq(heroInst, oSceneNode)
  if node and node > 0x10000 then
    local x, y, z = rf32(node, oAbsOrigin), rf32(node, oAbsOrigin + 4), rf32(node, oAbsOrigin + 8)
    log(string.format("hero position = %.1f %.1f %.1f (node=%s)", x, y, z, hex(node)))
  end
end
log("=== order VERIFY done ===")