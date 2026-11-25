-- entity_debug4.lua — locate CEntitySystem object by vtable scan in client .data; dump identity list.
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
local esysVt = cb + 0x48ACB80
log("=== entity DEBUG4 === client =", hex(client), "CEntitySystem vtbl =", hex(esysVt))

-- read client PE .data section range
local dos = ffi.cast("uint8_t*", client)
local peOff = ffi.cast("uint32_t*", dos + 0x3C)[0]
local pe = dos + peOff
local nsec = ffi.cast("uint16_t*", pe + 6)[0]
local optSize = ffi.cast("uint16_t*", pe + 20)[0]
local secOff = peOff + 24 + optSize
local dataStart, dataEnd = nil, nil
for i = 0, nsec - 1 do
  local s = dos + secOff + i * 40
  local name = ffi.string(s, 8):gsub("%z", "")
  local vs = ffi.cast("uint32_t*", s + 8)[0]
  local va = ffi.cast("uint32_t*", s + 12)[0]
  if name == ".data" then dataStart = cb + va; dataEnd = cb + va + vs end
end
log(".data range:", hex(dataStart), "-", hex(dataEnd))

-- scan .data for CEntitySystem vtable pointer
local hits = {}
if dataStart then
  local p = dataStart
  while p < dataEnd - 8 do
    if readable(ffi.cast("void*", p), 8) then
      local v = tonumber(ffi.cast("uintptr_t*", p)[0])
      if v == esysVt then hits[#hits+1] = p end
    end
    p = p + 8
  end
end
log("CEntitySystem object hits =", #hits)
for i = 1, math.min(#hits, 4) do
  local obj = hits[i]
  log(string.format("CEntitySystem obj[%d] = %s (rva %s)", i, hex(obj), hex(obj - cb)))
  -- dump members 0x00..0x80, look for chunk array (heap ptr) and identities
  for off = 0, 0x80, 8 do
    local v = rq(obj, off)
    local tag = ""
    if v and v > 0x10000000000 and v < 0x7FF000000000 then
      -- candidate chunk array: check first entries for identities
      local dn0 = designerOf(rq(v, 0))
      local dn1 = designerOf(rq(v, 8))
      tag = string.format("  HEAP-> id0=%s id1=%s", dn0 or "?", dn1 or "?")
    end
    log(string.format("   +0x%02X = %s%s", off, hex(v), tag))
  end
end
log("=== entity DEBUG4 done ===")