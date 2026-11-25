-- e2c_dump.lua — dump Source2EngineToClient001 object members + wide vtable; peek heap pointers.
package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local ffi = require("ffi")
local C = ffi.C
local logf = io.open("D:\\hake\\lotus\\host.log", "a")
local function log(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
  logf:write(os.date("%H:%M:%S ") .. table.concat(t, "\t") .. "\n"); logf:flush()
end
local function hex(v) return string.format("0x%X", tonumber(ffi.cast("uintptr_t", v))) end
ffi.cdef[[
  void* GetModuleHandleA(const char* name);
  void* GetProcAddress(void* mod, const char* name);
  typedef void* (*CreateInterfaceFn)(const char* name, int* ret);
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
local eng = C.GetModuleHandleA("engine2.dll")
local engBase = ffi.cast("uintptr_t", eng)
local ci = ffi.cast("CreateInterfaceFn", C.GetProcAddress(eng, "CreateInterface"))
local e2c = ci("Source2EngineToClient001", nil)
log("=== e2c dump === e2c =", hex(e2c), "engine2 =", hex(eng))
if e2c == nil then return end

-- vtable entries 0..99 as RVA
local vt = ffi.cast("uintptr_t*", ffi.cast("uintptr_t*", e2c)[0])
log("vtable addr =", hex(vt), "rva =", hex(ffi.cast("uintptr_t", vt) - engBase))
local rvas = {}
for i = 0, 99 do rvas[#rvas+1] = string.format("%d:%X", i, tonumber(vt[i] - engBase)) end
log("vt RVAs " .. table.concat(rvas, " "))

-- object members 0..0x100, peek heap pointers
log("e2c object members:")
local q = ffi.cast("uintptr_t*", e2c)
for i = 0, 31 do
  local v = q[i]
  local line = string.format("  +0x%02X = %s", i*8, hex(v))
  if readable(ffi.cast("void*", v), 0x20) and v > 0x10000000000 then
    local t = ffi.cast("uintptr_t*", v)
    line = line .. string.format("  -> [%s %s %s %s]", hex(t[0]), hex(t[1]), hex(t[2]), hex(t[3]))
  end
  log(line)
end
log("=== e2c dump done ===")