-- entity_list1.lua — decode list1 (esys+0x50/+0x58): likely the gameplay identity list.
package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local ffi = require("ffi")
local C = ffi.C
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
local function cstr(p)
  if not readable(p, 1) then return nil end
  local ok, s = pcall(ffi.string, p, 96); if not ok then return nil end
  local z = s:find("\0"); if z then s = s:sub(1, z - 1) end
  if #s > 0 and s:match("^[%w_:<>%.%s%-]+$") then return s end
  return nil
end
schema.init()
local eng = C.GetModuleHandleA("engine2.dll")
local esys = ffi.cast("void**", ffi.cast("uintptr_t", eng) + 0x8b3c60)[0]
log("=== entity LIST1 === esys =", hex(esys))
local count = tonumber(ffi.cast("uint32_t*", esys)[20])  -- +0x50
local arr = ffi.cast("uintptr_t*", ffi.cast("uintptr_t*", esys)[11])  -- +0x58
log(string.format("list1 count=%d arr=%s", count, hex(arr)))

-- dump esys object 0x40..0x90 for context
local eq = ffi.cast("uintptr_t*", esys)
for i = 8, 18 do log(string.format("  esys+0x%02X = %s", i*8, hex(eq[i]))) end

-- Interpretation 1: array of CEntityIdentity* (8-byte stride)
log("interp ptr-array (identity designerName@0x20, m_pNext@0x58):")
for i = 0, math.min(count, 16) - 1 do
  local idn = ffi.cast("void*", arr[i])
  if readable(idn, 0x70) then
    local q = ffi.cast("uintptr_t*", idn)
    local nm = cstr(ffi.cast("void*", q[3]))     -- +0x18 m_name
    local dn = cstr(ffi.cast("void*", q[4]))     -- +0x20 m_designerName
    log(string.format("  [%d] identity=%s name=%s designer=%s next=%s", i, hex(idn), nm or "?", dn or "?", hex(q[11])))
  else
    log(string.format("  [%d] %s (not ptr)", i, hex(arr[i])))
  end
end
-- Interpretation 2: 24-byte entries
log("interp 24-byte (name@+8):")
local base = ffi.cast("uintptr_t", arr)
for i = 0, math.min(count, 16) - 1 do
  local e = base + i * 24
  if not readable(ffi.cast("void*", e), 24) then break end
  local q = ffi.cast("uintptr_t*", e)
  log(string.format("  [%d] q0=%s name=%s q2=%s", i, hex(q[0]), cstr(ffi.cast("void*", q[1])) or "?", hex(q[2])))
end
log("=== entity LIST1 done ===")