-- entity_debug3.lua — scan entityListHead for heap pointers (chunk array); follow to identities.
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
local function rq(p, off)
  local addr = ffi.cast("uintptr_t", p) + (off or 0)
  if not readable(ffi.cast("void*", addr), 8) then return nil end
  return tonumber(ffi.cast("uintptr_t*", addr)[0])
end
local function rs(p)
  if not readable(p, 1) then return nil end
  local ok, s = pcall(ffi.string, p, 80); if not ok then return nil end
  local z = s:find("\0"); if z then s = s:sub(1, z - 1) end
  if #s > 0 and s:match("^[%w_:<>%.%s%-]+$") then return s end
  return nil
end
local function designerOf(idn)
  if not idn then return nil end
  local sp = rq(idn, 0x20); if not sp then return nil end
  return rs(ffi.cast("void*", sp))
end
schema.init()
local client = C.GetModuleHandleA("client.dll")
local cb = ffi.cast("uintptr_t", client)
local el = rq(cb + 0x662FFE8, 0)
log("=== entity DEBUG3 === entityListHead =", hex(el))

-- scan first 0x200 bytes for heap pointers (0x1xx..0x7xx range, not client static)
log("heap-pointer candidates in entityListHead:")
local cands = {}
for i = 0, 63 do
  local v = rq(el, i*8)
  if v and v > 0x10000000000 and v < 0x7FF000000000 then
    cands[#cands+1] = { off = i*8, ptr = v }
    log(string.format("  +0x%02X = %s", i*8, hex(v)))
  end
end
-- for each candidate, check if it's a chunk array of identity pointers
for _, c in ipairs(cands) do
  local arr = c.ptr
  local found = 0
  local sample = {}
  for i = 0, 127 do
    local idn = rq(arr, i*8)
    local dn = designerOf(idn)
    if dn then found = found + 1; if #sample < 6 then sample[#sample+1] = dn end end
  end
  if found > 0 then
    log(string.format("  CAND +0x%02X -> %d identities: %s", c.off, found, table.concat(sample, ", ")))
  end
end
log("=== entity DEBUG3 done ===")