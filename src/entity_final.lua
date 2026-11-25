-- entity_final.lua — read client.dll globals (dwEntityList / dwLocalPlayerController) from dota2-offset-dumper.
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
local client = C.GetModuleHandleA("client.dll")
local cb = ffi.cast("uintptr_t", client)
log("=== entity FINAL === client.dll =", hex(client))

local oEntityList = 0x662FFE8
local oLocalCtrl  = 0x6219008

local elAddr = cb + oEntityList
local elPtr = ffi.cast("void**", elAddr)[0]
log(string.format("dwEntityList [client+0x%X] = %s", oEntityList, hex(elPtr)))

local lcAddr = cb + oLocalCtrl
local lcPtr = ffi.cast("void**", lcAddr)[0]
log(string.format("dwLocalPlayerController [client+0x%X] = %s", oLocalCtrl, hex(lcPtr)))

-- local player controller: CEntityInstance m_pEntity@0x10 -> identity designerName@0x20
if lcPtr ~= nil and readable(lcPtr, 0x20) then
  local idn = ffi.cast("void*", ffi.cast("uintptr_t*", lcPtr)[2])
  local dn = cstr(ffi.cast("void*", ffi.cast("uintptr_t*", idn)[4]))
  log("local controller designerName =", dn or "?")
end

-- entity list: explore structure. elPtr may be chunk-array head.
if elPtr ~= nil and readable(elPtr, 0x40) then
  local q = ffi.cast("uintptr_t*", elPtr)
  log("entityList object first qwords:")
  for i = 0, 7 do log(string.format("  +0x%02X = %s", i*8, hex(q[i]))) end
  -- try: elPtr is array of chunk pointers; chunk0 -> identities (ptr array)
  local chunk0 = ffi.cast("uintptr_t*", q[0])
  if readable(chunk0, 0x40) then
    log("chunk0 first entries as identity ptrs (designer@+0x20):")
    local found = 0
    for i = 0, 63 do
      local idn = ffi.cast("void*", chunk0[i])
      if readable(idn, 0x28) then
        local dn = cstr(ffi.cast("void*", ffi.cast("uintptr_t*", idn)[4]))
        if dn then
          found = found + 1
          if found <= 20 then log(string.format("  [%d] identity=%s designer=%s", i, hex(idn), dn)) end
        end
      end
    end
    log("chunk0 identities found =", found)
  end
end
log("=== entity FINAL done ===")