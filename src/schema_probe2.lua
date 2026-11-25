-- schema_probe2.lua — map CSchemaClassInfoData field array; validate OffsetOf on known fields.
local ffi = require("ffi")
local C = ffi.C

local logf = io.open("D:\\hake\\lotus\\host.log", "a")
local function log(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
  logf:write(os.date("%H:%M:%S ") .. table.concat(t, "\t") .. "\n")
  logf:flush()
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
local function cstr(p)
  if not readable(p, 1) then return nil end
  local s = ffi.string(p, 96)
  local z = s:find("\0"); if z then s = s:sub(1, z - 1) end
  if #s > 0 and s:match("^[%w_:<>%.%s%-]+$") then return s end
  return nil
end

local ss = C.GetModuleHandleA("schemasystem.dll")
local ci = ffi.cast("CreateInterfaceFn", C.GetProcAddress(ss, "CreateInterface"))
local schemaSystem = ci("SchemaSystem_001", nil)
local ssVt = ffi.cast("uintptr_t*", ffi.cast("uintptr_t*", schemaSystem)[0])
local FindScope = ffi.cast("void* (*)(void*, const char*, void*)", ssVt[12])
local scope = FindScope(schemaSystem, "client.dll", nil)
local scVt = ffi.cast("uintptr_t*", ffi.cast("uintptr_t*", scope)[0])
local FindClass2 = ffi.cast("void* (*)(void*, void**, const char*)", scVt[2])

local function getClass(name)
  local out = ffi.new("void*[1]")
  FindClass2(scope, out, name)
  return out[0]
end

-- field entry hypothesis: { char* name @0, void* type @8, int32 offset @0x10, ... } size 0x20
local function dumpFields(cls, label)
  if cls == nil then log(label, ": class nil"); return end
  local cq = ffi.cast("uintptr_t*", cls)
  local size = tonumber(ffi.cast("uint32_t*", cls)[8])       -- +0x20 low32
  local count = tonumber(ffi.cast("uint16_t*", cls)[18])     -- +0x24
  log(string.format("%s: size=%d(0x%X) count@0x24=%d  +0x20raw=%s", label, size, size, count, hex(cq[4])))
  for _, slot in ipairs({ 6, 7 }) do  -- +0x30, +0x38
    local arr = ffi.cast("uintptr_t*", cq[slot])
    if readable(arr, 0x20) then
      log(string.format("  array@+0x%02X = %s, first entries:", slot * 8, hex(arr)))
      for i = 0, 4 do
        local e = arr + i * 4  -- 0x20 bytes = 4 qwords
        if not readable(e, 0x20) then break end
        local nm = cstr(ffi.cast("void*", e[0]))
        local off = tonumber(ffi.cast("int32_t*", e)[4])  -- +0x10
        log(string.format("    [%d] name=%s type=%s offset=%d", i, nm or "?", hex(e[1]), off))
      end
    end
  end
end

log("=== schema probe 2 ===")
local cls = getClass("C_BaseEntity")
log("C_BaseEntity =", hex(cls))
dumpFields(cls, "C_BaseEntity")

-- scan the +0x30 array for known fields (entry size 0x20, count from +0x24)
if cls ~= nil then
  local cq = ffi.cast("uintptr_t*", cls)
  local count = tonumber(ffi.cast("uint16_t*", cls)[18])
  local arr = ffi.cast("uintptr_t*", cq[6])
  local want = { m_iHealth = true, m_iMaxHealth = true, m_iTeamNum = true, m_lifeState = true, m_hOwnerEntity = true, m_vecAbsOrigin = true }
  if readable(arr, 0x20) and count > 0 and count < 4096 then
    log("scan " .. count .. " fields @+0x30:")
    local found = 0
    for i = 0, count - 1 do
      local e = arr + i * 4
      if not readable(e, 0x20) then break end
      local nm = cstr(ffi.cast("void*", e[0]))
      if nm and want[nm] then
        local off = tonumber(ffi.cast("int32_t*", e)[4])
        log(string.format("  FOUND %s = 0x%X (%d)", nm, off, off))
        found = found + 1
      end
    end
    log("found " .. found .. " known fields")
  end
end

local npc = getClass("C_DOTA_BaseNPC")
log("C_DOTA_BaseNPC =", hex(npc))
dumpFields(npc, "C_DOTA_BaseNPC")

log("=== schema probe 2 done ===")