-- entity_debug2.lua — follow controller+0x08 chain; identify vtable; re-check entity list population.
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
log("=== entity DEBUG2 === client =", hex(client))

local lc = rq(cb + 0x6219008, 0)
log("localController =", hex(lc))
if lc then
  local vt = rq(lc, 0)
  log("  controller vtable RVA =", hex(vt - cb))
  local p08 = rq(lc, 0x08)
  log("  controller+0x08 =", hex(p08))
  -- treat +0x08 as identity
  log("    as identity designer =", designerOf(p08) or "?")
  -- treat +0x08 as instance -> m_pEntity@0x10
  local idn10 = rq(p08, 0x10)
  log("    [+0x08]+0x10 =", hex(idn10), "designer =", designerOf(idn10) or "?")
  -- dump +0x08 object first qwords
  if p08 and readable(ffi.cast("void*", p08), 0x30) then
    for i = 0, 5 do
      local v = rq(p08, i*8)
      log(string.format("    p08+0x%02X = %s%s", i*8, hex(v), (v and v>0x10000 and rs(ffi.cast("void*",v))) and (" str="..rs(ffi.cast("void*",v))) or ""))
    end
  end
end

-- entity list: scan a window of client .data around the head for non-null pointers
local el = rq(cb + 0x662FFE8, 0)
log("entityListHead =", hex(el), " (rva " .. hex(el - cb) .. ")")
-- maybe the real list pointer is stored at el (read [el]) OR el is the list and chunks elsewhere
local nonzero = 0
for i = 0, 63 do
  local v = rq(el, i*8)
  if v and v ~= 0 then nonzero = nonzero + 1; if nonzero <= 8 then log(string.format("  el+0x%02X = %s", i*8, hex(v))) end end
end
log("  entityListHead nonzero qwords (first 64) =", nonzero)
log("=== entity DEBUG2 done ===")