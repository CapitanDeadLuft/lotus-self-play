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
local function u32(p, o) return tonumber(ffi.cast("uint32_t*", p + o)[0]) end
local function i32(p, o) return tonumber(ffi.cast("int32_t*", p + o)[0]) end
local function u64(p, o) return tonumber(ffi.cast("uintptr_t*", p + o)[0]) end
local function f32(p, o) return tonumber(ffi.cast("float*", p + o)[0]) end
log("=== ABILITY PROBE ===")
entity.init()
local h = entity.getLocalHero()
if not h then log("no hero"); return end
local inst = h.instance
log("hero", h.name, "hp", h.health, "inst", inst)
local ab = schema.offsetOf("C_DOTA_BaseNPC", "m_vecAbilities") or 3368
log("m_vecAbilities", ab)
for off = 0, 20, 4 do
  log(string.format("  +%d u32=%s", off, tostring(u32(inst + ab, off))))
end
log(string.format("  ptr0=%s ptr8=%s", string.format("0x%X", u64(inst + ab, 0) or 0), string.format("0x%X", u64(inst + ab, 8) or 0)))
local function tryVec(tag, ptr, count)
  if not ptr or ptr < 0x10000 or not count or count < 1 or count > 32 then return end
  log(tag, "count", count)
  for i = 0, math.min(count, 16) - 1 do
    local handle = u32(ptr, i * 4)
    local idn = entity.byHandle(handle)
    log(string.format("  [%d] handle=%s %s", i, tostring(handle), idn and (entity.designerName(idn) or "?") or "nil"))
  end
end
tryVec("layoutA", u64(inst + ab, 0), i32(inst + ab, 16))
tryVec("layoutB", u64(inst + ab, 8), i32(inst + ab, 0))
local inv = schema.offsetOf("C_DOTA_BaseNPC", "m_Inventory") or 4544
log("inventory", inv)
for off = 0, 64, 4 do
  local handle = u32(inst + inv, off)
  local idn = entity.byHandle(handle)
  if idn then log(string.format("  inv+%d handle=%s %s", off, tostring(handle), entity.designerName(idn) or "?")) end
end
local pts = schema.offsetOf("C_DOTA_BaseNPC_Hero", "m_iAbilityPoints")
local lvl = schema.offsetOf("C_DOTA_BaseNPC", "m_iCurrentLevel")
log("pointsOff", pts, "value", pts and i32(inst, pts), "levelOff", lvl, "value", lvl and i32(inst, lvl))
local node = u64(inst, schema.offsetOf("C_BaseEntity", "m_pGameSceneNode") or 816)
local ang = schema.offsetOf("CGameSceneNode", "m_angAbsRotation") or 228
if node and node > 0x10000 then
  log(string.format("ang %.1f %.1f %.1f", f32(node, ang), f32(node, ang + 4), f32(node, ang + 8)))
end
-- local controller gold
local orders = require("orders")
local ctrl = orders.localController()
local goldOff = schema.offsetOf("C_DOTAPlayerController", "m_iTotalGold")
log("goldOff", goldOff, "gold", goldOff and ctrl and i32(ctrl, goldOff))
log("ability class", schema.offsetOf("C_DOTABaseAbility", "m_iLevel"), schema.offsetOf("C_DOTABaseAbility", "m_iMaxLevel"), schema.offsetOf("C_DOTABaseAbility", "m_bHidden"))
log("=== ABILITY PROBE done ===")
