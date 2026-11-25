-- entity_raw.lua — raw dump of in-game entity list entries to decode the real structure.
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
log("=== entity RAW === esys =", hex(esys))
local count = tonumber(ffi.cast("uint32_t*", esys)[28])
local arr = ffi.cast("uintptr_t*", ffi.cast("uintptr_t*", esys)[15])
log(string.format("list2 count=%d arr=%s", count, hex(arr)))
local base = ffi.cast("uintptr_t", arr)
-- dump first 40 entries raw: q0, name, q2 ; and if q0 readable, its first 4 qwords + designerName candidates
for i = 0, 39 do
  local e = base + i * 24
  if not readable(ffi.cast("void*", e), 24) then log("entry unreadable at", i); break end
  local q = ffi.cast("uintptr_t*", e)
  local nm = cstr(ffi.cast("void*", q[1]))
  local line = string.format("[%2d] q0=%s name=%-32s q2=%s", i, hex(q[0]), nm or "?", hex(q[2]))
  -- if q0 looks like a pointer, peek
  if readable(ffi.cast("void*", q[0]), 0x28) then
    local p = ffi.cast("uintptr_t*", q[0])
    local dn = cstr(ffi.cast("void*", p[4]))  -- +0x20
    line = line .. string.format(" | q0-> [+0]=%s [+10]=%s [+20]=%s", hex(p[0]), hex(p[2]), dn or hex(p[4]))
  end
  log(line)
end
log("=== entity RAW done ===")