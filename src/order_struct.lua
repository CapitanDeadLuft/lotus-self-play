package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local ffi = require("ffi")
ffi.cdef[[ void Sleep(unsigned long ms); ]]
local entity = require("entity")
local orders = require("orders")
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
log("=== ORDER STRUCT ===")
entity.init(); orders.init()
local ctrl = orders.localController()
local h = entity.getLocalHero()
local base = schema.offsetOf("C_DOTAPlayerController", "m_unitorders") or 0x9A0
log("ctrl", tostring(ctrl), "ordersOff", base)
local function dumpVec(tag)
  local p = ctrl + base
  local a = u64(p, 0)
  local b = u32(p, 8)
  local c = u32(p, 12)
  local d = i32(p, 16)
  local e = u64(p, 8)
  log(string.format("%s raw ptr0=%s u32@8=%s u32@12=%s i32@16=%s ptr8=%s", tag, string.format("0x%X", a or 0), tostring(b), tostring(c), tostring(d), string.format("0x%X", e or 0)))
  local mem = a
  if not mem or mem < 0x10000 then mem = e end
  local size = d
  if size < 0 or size > 8 then size = c end
  if mem and mem > 0x10000 and size and size > 0 and size < 8 then
    local ord = mem + (size - 1) * 0x40
    log(string.format("  last type=%s tgt=%s abil=%s flags=%s seq=%s pos=%.0f,%.0f issuer=%s",
      tostring(i32(ord, 0x2C)), tostring(i32(ord, 0x30)), tostring(i32(ord, 0x34)),
      tostring(i32(ord, 0x38)), tostring(i32(ord, 0x28)), f32(ord, 0x18), f32(ord, 0x1C), tostring(i32(ord, 0x24))))
    -- also units vector at start of order
    log(string.format("  units ptr=%s size=%s", string.format("0x%X", u64(ord, 0) or 0), tostring(i32(ord, 0x10))))
  end
end
dumpVec("before")
local hx, hy, hz = orders.heroPosition(h.instance)
orders.prepare(1, 0, { hx + 300, hy + 100, hz }, 0, h.instance, false, true)
ffi.C.Sleep(50)
dumpVec("after move")
-- enemy
local team = entity.team(h.identity)
local enemy
for idn in entity.iter() do
  local dn = entity.designerName(idn) or ""
  if dn:find("npc_dota_creep") and entity.team(idn) ~= team then
    local inst = entity.instance(idn)
    local x, y, z = orders.heroPosition(inst)
    if x then
      local dist = math.sqrt((x-hx)^2+(y-hy)^2)
      if not enemy or dist < enemy.d then enemy = { idn = idn, x = x, y = y, z = z, d = dist, dn = dn } end
    end
  end
end
if enemy then
  local handle = i32(enemy.idn, 0x10)
  local idx = handle % 0x8000; if idx < 0 then idx = idx + 0x8000 end
  log(string.format("attack %s idx=%d handle=%d dist=%.0f", enemy.dn, idx, handle, enemy.d))
  orders.prepare(4, idx, { enemy.x, enemy.y, enemy.z }, 0, h.instance, false, true)
  ffi.C.Sleep(50)
  dumpVec("after attack idx")
end
log("=== ORDER STRUCT done ===")
