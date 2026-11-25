-- host_main.lua — runs INSIDE dota2.exe (via host.dll). Milestone: hello + SchemaSystem capture.
local ffi = require("ffi")
local C = ffi.C

local logf = io.open("D:\\hake\\lotus\\host.log", "a")
local function log(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
  logf:write(os.date("%H:%M:%S ") .. table.concat(t, "\t") .. "\n")
  logf:flush()
end

ffi.cdef[[
  unsigned long GetCurrentProcessId(void);
  void* GetModuleHandleA(const char* name);
  void* GetProcAddress(void* mod, const char* name);
  typedef void* (*CreateInterfaceFn)(const char* name, int* ret);
]]

log("=== in-process hello ===")
log("pid =", C.GetCurrentProcessId())

for _, m in ipairs({ "client.dll", "engine2.dll", "schemasystem.dll", "tier0.dll" }) do
  local h = C.GetModuleHandleA(m)
  log(string.format("module %-18s = %p", m, h))
end

local ss = C.GetModuleHandleA("schemasystem.dll")
if ss == nil then log("FATAL: schemasystem.dll not found"); return end

local ci = C.GetProcAddress(ss, "CreateInterface")
log("schemasystem!CreateInterface =", ci)
if ci == nil then log("FATAL: no CreateInterface export"); return end

local CreateInterface = ffi.cast("CreateInterfaceFn", ci)
local ret = ffi.new("int[1]", -1)
local schemaSystem = CreateInterface("SchemaSystem_001", ret)
log("SchemaSystem_001 =", schemaSystem, "ret =", ret[0])

if schemaSystem == nil then
  -- try other versions
  for _, v in ipairs({ "SchemaSystem_002", "SchemaSystem_003" }) do
    schemaSystem = CreateInterface(v, ret)
    log(v, "=", schemaSystem, "ret =", ret[0])
    if schemaSystem ~= nil then break end
  end
end
if schemaSystem == nil then log("FATAL: SchemaSystem interface not captured"); return end

-- dump vtable (first 24 slots) — to identify FindTypeScopeForModule index
local obj = ffi.cast("uintptr_t*", schemaSystem)
local vtbl = ffi.cast("uintptr_t*", obj[0])
log("vtable @", string.format("0x%X", tonumber(ffi.cast("uintptr_t", vtbl))))
local ssBase = ffi.cast("uintptr_t", ss)
for i = 0, 23 do
  local fn = vtbl[i]
  log(string.format("  vtbl[%2d] = 0x%X  (schemasystem+0x%X)", i, tonumber(fn), tonumber(fn - ssBase)))
end

log("=== milestone 1 OK: in-process Lua + SchemaSystem captured ===")