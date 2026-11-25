-- entity_debug.lua — raw dump of controller / identity / entity-list head in-game to find real layout.
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
local function dumpObj(tag, p, n)
  if not readable(ffi.cast("void*", p), n*8) then log(tag, "unreadable", hex(p)); return end
  log(tag .. " @ " .. hex(p) .. ":")
  for i = 0, n-1 do
    local v = rq(p, i*8)
    local s = nil
    if v and v > 0x10000 then s = rs(ffi.cast("void*", v)) end
    log(string.format("   +0x%02X = %s%s", i*8, hex(v), s and ("  str=\""..s.."\"") or ""))
  end
end
schema.init()
local client = C.GetModuleHandleA("client.dll")
local cb = ffi.cast("uintptr_t", client)
log("=== entity DEBUG === client =", hex(client))

local lc = rq(cb + 0x6219008, 0)
dumpObj("localController", lc, 6)
if lc then
  local idn = rq(lc, 0x10)
  dumpObj("controller.identity(+0x10)", idn, 14)
end

local el = rq(cb + 0x662FFE8, 0)
dumpObj("entityListHead", el, 8)
if el then
  local el2 = rq(el, 0)   -- one more deref
  dumpObj("[entityListHead] (deref1)", el2, 8)
end
log("=== entity DEBUG done ===")