-- entity_chunk.lua — decode the chunked identity list at [engine2+0x62f258].
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
  local ok, s = pcall(ffi.string, p, 80); if not ok then return nil end
  local z = s:find("\0"); if z then s = s:sub(1, z - 1) end
  if #s > 0 and s:match("^[%w_:<>%.%s%-]+$") then return s end
  return nil
end
schema.init()
local eng = C.GetModuleHandleA("engine2.dll")
local esys = ffi.cast("void**", ffi.cast("uintptr_t", eng) + 0x62f258)[0]
log("=== entity CHUNK === esys =", hex(esys))
if esys == nil then return end
local q = ffi.cast("uintptr_t*", esys)
-- chunk array pointer candidates: +0x30 and +0x50
for _, off in ipairs({ 0x30, 0x50, 0x18 }) do
  local chunkArr = ffi.cast("uintptr_t*", q[off / 8])
  if readable(chunkArr, 16) then
    log(string.format("chunkArr@+0x%X = %s, chunk0=%s chunk1=%s", off, hex(chunkArr), hex(chunkArr[0]), hex(chunkArr[1])))
    local chunk0 = ffi.cast("uintptr_t*", chunkArr[0])
    if readable(chunk0, 0x100) then
      -- interp A: inline identities 112 bytes, designerName@0x20
      log("  interp A inline-112 (designer@+0x20):")
      for i = 0, 5 do
        local idn = ffi.cast("uintptr_t", chunk0) + i * 112
        local dn = cstr(ffi.cast("void*", ffi.cast("uintptr_t*", idn)[4]))
        log(string.format("    [%d] designer=%s", i, dn or "?"))
      end
      -- interp B: pointer array, identity->designer@0x20
      log("  interp B ptr-array (identity designer@+0x20):")
      for i = 0, 9 do
        local idn = ffi.cast("void*", chunk0[i])
        local dn = nil
        if readable(idn, 0x28) then dn = cstr(ffi.cast("void*", ffi.cast("uintptr_t*", idn)[4])) end
        log(string.format("    [%d] ptr=%s designer=%s", i, hex(chunk0[i]), dn or "?"))
      end
    end
  end
end
log("=== entity CHUNK done ===")