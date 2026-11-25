-- schema_dump.lua — dump full field maps of key classes to schema_dump.json (runtime-resolved).
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
  local s = ffi.string(p, 128)
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

local function jsonStr(s)
  return '"' .. s:gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
end

local function dumpClass(name)
  local cls = getClass(name)
  if cls == nil then log("MISSING class:", name); return nil end
  local size = tonumber(ffi.cast("uint32_t*", cls)[8])
  local count = tonumber(ffi.cast("uint16_t*", cls)[18])
  local arr = ffi.cast("uintptr_t*", ffi.cast("uintptr_t*", cls)[6])
  local fields = {}
  if readable(arr, 0x20) and count > 0 and count < 8192 then
    for i = 0, count - 1 do
      local e = arr + i * 4
      if not readable(e, 0x20) then break end
      local nm = cstr(ffi.cast("void*", e[0]))
      local off = tonumber(ffi.cast("int32_t*", e)[4])
      if nm then fields[#fields+1] = { name = nm, offset = off } end
    end
  end
  log(string.format("class %-28s size=%-6d fields=%d", name, size, #fields))
  return { name = name, size = size, fields = fields }
end

log("=== schema dump ===")
local classNames = {
  "CEntityInstance", "CEntityIdentity", "CEntitySystem",
  "C_BaseEntity", "C_BaseModelEntity", "C_BaseAnimating",
  "C_DOTA_BaseNPC", "C_DOTA_BaseNPC_Hero", "C_DOTA_BaseNPC_Creep",
  "C_DOTAPlayerController", "CBasePlayerController", "C_DOTA_PlayerResource",
  "C_DOTA_Ability", "C_DOTA_Item", "C_DOTAGamerules", "C_DOTAGamerulesProxy",
  "CGameSceneNode", "CBodyComponent", "CDOTAGameManager",
}
local parts = {}
for _, cn in ipairs(classNames) do
  local d = dumpClass(cn)
  if d then
    local fj = {}
    for _, f in ipairs(d.fields) do fj[#fj+1] = string.format('{"name":%s,"offset":%d}', jsonStr(f.name), f.offset) end
    parts[#parts+1] = string.format('{"name":%s,"size":%d,"fields":[%s]}', jsonStr(d.name), d.size, table.concat(fj, ","))
  end
end
local out = io.open("D:\\hake\\lotus\\schema_dump.json", "w")
out:write("[\n" .. table.concat(parts, ",\n") .. "\n]\n")
out:close()
log("schema_dump.json written:", #parts, "classes")

-- also capture Source2EngineToClient001 vtable (for GetEntitySystem identification)
local client = C.GetModuleHandleA("client.dll")
local ci2 = ffi.cast("CreateInterfaceFn", C.GetProcAddress(client, "CreateInterface"))
local e2c = ci2("Source2EngineToClient001", nil)
log("Source2EngineToClient001 (client.dll) =", hex(e2c))
if e2c == nil then
  local eng = C.GetModuleHandleA("engine2.dll")
  local ci3 = ffi.cast("CreateInterfaceFn", C.GetProcAddress(eng, "CreateInterface"))
  e2c = ci3("Source2EngineToClient001", nil)
  log("Source2EngineToClient001 (engine2.dll) =", hex(e2c))
end
if e2c ~= nil then
  local vt = ffi.cast("uintptr_t*", ffi.cast("uintptr_t*", e2c)[0])
  local base = ffi.cast("uintptr_t", e2c) -- vtable may live in client or engine2; log raw + relative to client
  local cb = ffi.cast("uintptr_t", client)
  for i = 0, 39 do
    log(string.format("  e2c vt[%2d] = %s (client+0x%X)", i, hex(vt[i]), tonumber(vt[i] - cb)))
  end
end
log("=== schema dump done ===")