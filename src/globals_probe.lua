-- globals_probe.lua — inspect engine2 singleton globals forwarded by e2c vtable; find entity system.
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
  local ok, s = pcall(ffi.string, p, 64); if not ok then return nil end
  local z = s:find("\0"); if z then s = s:sub(1, z - 1) end
  if #s > 0 and s:match("^[%w_:<>%.%s%-]+$") then return s end
  return nil
end
schema.init()
local eng = C.GetModuleHandleA("engine2.dll")
local eb = ffi.cast("uintptr_t", eng)
log("=== globals probe === engine2 =", hex(eng))

local function inspectObj(tag, obj)
  if not readable(obj, 0x40) then log(tag, "unreadable"); return end
  local q = ffi.cast("uintptr_t*", obj)
  log(string.format("%s obj=%s vtbl=%s", tag, hex(obj), hex(q[0])))
  -- dump members, peek heap pointers for identity-list-like data
  for i = 1, 12 do
    local v = q[i]
    local line = string.format("   +0x%02X=%s", i*8, hex(v))
    if readable(ffi.cast("void*", v), 0x20) and v > 0x10000000000 then
      local t = ffi.cast("uintptr_t*", v)
      local s0 = cstr(ffi.cast("void*", t[0]))
      line = line .. string.format(" ->[%s,%s,%s]%s", hex(t[0]), hex(t[1]), hex(t[2]), s0 and (" str="..s0) or "")
    end
    log(line)
  end
end

for _, g in ipairs({ 0x5ba2b0, 0x62f5a0, 0x8bf4a8, 0x8bf4b0 }) do
  local ptr = ffi.cast("void**", eb + g)[0]
  log(string.format("global [engine2+0x%X] = %s", g, hex(ptr)))
  if ptr ~= nil and readable(ptr, 0x40) then inspectObj(string.format("g0x%X", g), ptr) end
end
log("=== globals probe done ===")