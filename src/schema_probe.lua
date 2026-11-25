-- schema_probe.lua — in-process: capture SchemaSystem -> client.dll scope -> C_BaseEntity class,
-- then safely inspect the class structure to map the field-offset layout.
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

-- safe pointer check: is [p, p+n) committed readable memory?
local function readable(p, n)
  if p == nil then return false end
  local a = ffi.cast("uintptr_t", p)
  if a < 0x10000 or a > 0x7FFFFFFFFFFF then return false end
  local mbi = ffi.new("MBI")
  if C.VirtualQuery(p, mbi, ffi.sizeof(mbi)) == 0 then return false end
  if mbi.State ~= 0x1000 then return false end  -- MEM_COMMIT
  local prot = tonumber(mbi.Protect)
  local ok = (prot == 0x02 or prot == 0x04 or prot == 0x08 or prot == 0x20 or prot == 0x40)
  if not ok then return false end
  return (a + (n or 8)) <= (ffi.cast("uintptr_t", mbi.BaseAddress) + mbi.RegionSize)
end

local function cstr(p)
  if not readable(p, 1) then return nil end
  local s = ffi.string(p, 64)  -- bounded
  local z = s:find("\0")
  if z then s = s:sub(1, z - 1) end
  if s:match("^[%w_:<>%.%s%-]+$") and #s > 0 then return s end
  return nil
end

log("=== schema probe ===")
local ss = C.GetModuleHandleA("schemasystem.dll")
local ci = ffi.cast("CreateInterfaceFn", C.GetProcAddress(ss, "CreateInterface"))
local schemaSystem = ci("SchemaSystem_001", nil)
log("SchemaSystem =", hex(schemaSystem))
if schemaSystem == nil then return end

local ssVt = ffi.cast("uintptr_t*", ffi.cast("uintptr_t*", schemaSystem)[0])

-- vtbl[12] = FindTypeScopeForModule(this, const char* module, out_opt)
local FindScope = ffi.cast("void* (*)(void*, const char*, void*)", ssVt[12])
local scope = FindScope(schemaSystem, "client.dll", nil)
log("client.dll scope =", hex(scope))
if scope == nil then log("FATAL: no scope"); return end

local scVt = ffi.cast("uintptr_t*", ffi.cast("uintptr_t*", scope)[0])
log("scope vtbl[2] =", hex(scVt[2]), " vtbl[25] =", hex(scVt[25]))

-- way A: vtbl[2](scope, &out, name) -> returns &out
local out = ffi.new("void*[1]")
local FindClass2 = ffi.cast("void* (*)(void*, void**, const char*)", scVt[2])
local r = FindClass2(scope, out, "C_BaseEntity")
local cls = out[0]
log("way A: ret =", hex(r), " class =", hex(cls))

-- way B (fallback): inner vtbl[25](scope, name)
if cls == nil then
  local FindClass25 = ffi.cast("void* (*)(void*, const char*)", scVt[25])
  cls = FindClass25(scope, "C_BaseEntity")
  log("way B: class =", hex(cls))
end
if cls == nil then log("FATAL: class not found"); return end

-- inspect class object: first 16 qwords; try to read each as pointer-to-string
log("class object dump:")
local cq = ffi.cast("uintptr_t*", cls)
for i = 0, 15 do
  local v = cq[i]
  local s = cstr(ffi.cast("void*", v))
  log(string.format("  +0x%02X = %s%s", i * 8, hex(v), s and ("  -> \"" .. s .. "\"") or ""))
end

-- if +0x00 is a pointer to class_info, dump that too
local info = ffi.cast("void*", cq[0])
if readable(info, 0x40) and info ~= cls then
  log("class_info dump (via +0x00):")
  local iq = ffi.cast("uintptr_t*", info)
  for i = 0, 15 do
    local v = iq[i]
    local s = cstr(ffi.cast("void*", v))
    log(string.format("  +0x%02X = %s%s", i * 8, hex(v), s and ("  -> \"" .. s .. "\"") or ""))
  end
end

log("=== schema probe done ===")