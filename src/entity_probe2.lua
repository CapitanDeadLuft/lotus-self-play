-- entity_probe2.lua — decode the entity identity list entries (list2 @ esys+0x78).
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
log("=== entity probe 2 === esys =", hex(esys))
if esys == nil then return end

local count = tonumber(ffi.cast("uint32_t*", esys)[28])  -- +0x70
local arr = ffi.cast("uintptr_t*", ffi.cast("uintptr_t*", esys)[15])  -- +0x78
log(string.format("list2 count=%d arr=%s", count, hex(arr)))

-- Interpretation A: array of CEntityIdentity* (8-byte stride); identity m_designerName@+0x20
log("interp A (ptr array, identity->designerName@0x20):")
for i = 0, 7 do
  local idn = ffi.cast("void*", arr[i])
  if readable(idn, 0x70) then
    local dn = cstr(ffi.cast("void*", ffi.cast("uintptr_t*", idn)[4]))  -- +0x20
    local nm = cstr(ffi.cast("void*", ffi.cast("uintptr_t*", idn)[3]))  -- +0x18
    log(string.format("  [%d] identity=%s name=%s designer=%s", i, hex(idn), nm or "?", dn or "?"))
  else
    log(string.format("  [%d] %s (not readable ptr)", i, hex(arr[i])))
  end
end

-- Interpretation B: 24-byte entries {q0, name@+8, q2}
log("interp B (24-byte entries, name@+8):")
local base = ffi.cast("uintptr_t", arr)
for i = 0, 7 do
  local e = base + i * 24
  if readable(ffi.cast("void*", e), 24) then
    local q = ffi.cast("uintptr_t*", e)
    local nm = cstr(ffi.cast("void*", q[1]))
    log(string.format("  [%d] q0=%s name=%s q2=%s", i, hex(q[0]), nm or "?", hex(q[2])))
  end
end
log("=== entity probe 2 done ===")