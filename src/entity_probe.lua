-- entity_probe.lua — validate schema.offsetOf + locate the entity system global (engine2+0x8b3c60).
package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local ffi = require("ffi")
local C = ffi.C
local schema = require("schema")

local logf = io.open("D:\\hake\\lotus\\host.log", "a")
local function log(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
  logf:write(os.date("%H:%M:%S ") .. table.concat(t, "\t") .. "\n")
  logf:flush()
end
local function hex(v) return string.format("0x%X", tonumber(ffi.cast("uintptr_t", v))) end

ffi.cdef[[
  void* GetModuleHandleA(const char* name);
  typedef struct { void* BaseAddress; void* AllocationBase; unsigned long AllocProtect;
                   size_t RegionSize; unsigned long State; unsigned long Protect; unsigned long Type; } MBI;
  size_t VirtualQuery(const void* addr, MBI* mbi, size_t len);
]]
local function readable(p, n)
  if p == nil then return false end
  local a = ffi.cast("uintptr_t", p)
  if a < 0x10000 or a > 0x7FFFFFFFFFFF then return false end
  local mbi = ffi.new("MBI")
  if C.VirtualQuery(p, mbi, ffi.sizeof(mbi)) == 0 then return false end
  if mbi.State ~= 0x1000 then return false end
  local prot = tonumber(mbi.Protect)
  if not (prot == 0x02 or prot == 0x04 or prot == 0x08 or prot == 0x20 or prot == 0x40) then return false end
  return (a + (n or 8)) <= (ffi.cast("uintptr_t", mbi.BaseAddress) + mbi.RegionSize)
end

log("=== entity probe ===")
local ok, err = schema.init()
log("schema.init:", ok, err)
for _, q in ipairs({ {"C_BaseEntity","m_iHealth"}, {"C_BaseEntity","m_iTeamNum"}, {"C_DOTA_BaseNPC","m_iCurrentLevel"}, {"C_DOTA_BaseNPC_Hero","m_iHeroID"} }) do
  local off, e = schema.offsetOf(q[1], q[2])
  log(string.format("OffsetOf %s::%s = %s %s", q[1], q[2], off and ("0x"..string.format("%X",off)) or "nil", e or ""))
end

local eng = C.GetModuleHandleA("engine2.dll")
log("engine2 base =", hex(eng))
local globalAddr = ffi.cast("uintptr_t", eng) + 0x8b3c60
local esys = ffi.cast("void**", globalAddr)[0]
log("entity system global [engine2+0x8b3c60] =", hex(esys))

if esys ~= nil and readable(esys, 0x100) then
  local q = ffi.cast("uintptr_t*", esys)
  log("entity system object dump (first 0x90):")
  for i = 0, 17 do
    log(string.format("  +0x%02X = %s", i*8, hex(q[i])))
  end
  -- counts/arrays seen in vt[20]: +0x50 count, +0x58 array; +0x70 count, +0x78 array
  local c1 = tonumber(ffi.cast("uint32_t*", esys)[20])  -- +0x50
  local a1 = q[11]  -- +0x58
  local c2 = tonumber(ffi.cast("uint32_t*", esys)[28])  -- +0x70
  local a2 = q[15]  -- +0x78
  log(string.format("list1 count=%d array=%s | list2 count=%d array=%s", c1, hex(a1), c2, hex(a2)))
else
  log("entity system not present yet (likely need to be in-game)")
end
log("=== entity probe done ===")