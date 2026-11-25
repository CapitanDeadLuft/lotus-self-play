-- globals2.lua — inspect forwarded singletons [0x5be350] and [0x62f250]; hunt identity list.
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
log("=== globals2 === engine2 =", hex(eng))

-- designer name of a known class to recognize identities
local function peekIdentity(p)
  -- CEntityIdentity: m_name@0x18, m_designerName@0x20
  if not readable(p, 0x60) then return nil end
  local q = ffi.cast("uintptr_t*", p)
  return cstr(ffi.cast("void*", q[4]))  -- +0x20 designerName
end

local function inspect(tag, obj, nmem)
  if not readable(obj, 0x40) then log(tag, "unreadable", hex(obj)); return end
  local q = ffi.cast("uintptr_t*", obj)
  log(string.format("%s obj=%s vtbl=%s", tag, hex(obj), hex(q[0])))
  for i = 1, nmem do
    local v = q[i]
    local line = string.format("   +0x%02X=%s", i*8, hex(v))
    if readable(ffi.cast("void*", v), 0x20) then
      local dn = peekIdentity(ffi.cast("void*", v))
      if dn then line = line .. "  IDENTITY.designer=" .. dn
      elseif v > 0x10000000000 then
        local t = ffi.cast("uintptr_t*", v)
        line = line .. string.format(" ->[%s,%s,%s]", hex(t[0]), hex(t[1]), hex(t[2]))
      end
    end
    log(line)
  end
end

for _, g in ipairs({ 0x5be350, 0x62f250, 0x62f258 }) do
  local ptr = ffi.cast("void**", eb + g)[0]
  log(string.format("[engine2+0x%X] = %s", g, hex(ptr)))
  if ptr ~= nil then inspect(string.format("g%X", g), ptr, 24) end
end
log("=== globals2 done ===")