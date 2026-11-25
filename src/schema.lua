-- schema.lua — in-process runtime schema reader (Lotus method), verified on Dota 7.41.
-- Resolves class/field offsets via the game's SchemaSystem (patch-resilient, no hardcoded offsets).
-- Verified layout (see schema_probe2 / schema_dump):
--   CSchemaClassInfoData: +0x08 name, +0x10 module, +0x20 size(u32), +0x24 fieldCount(u16), +0x30 fieldArray
--   SchemaClassFieldData (0x20 bytes): +0x00 name(char*), +0x08 type, +0x10 offset(i32)
--   SchemaSystem vtbl[12] = FindTypeScopeForModule(this, module, out_opt)
--   Scope vtbl[2] = FindDeclaredClass(this, &out, name) -> out = CSchemaClassInfoData*
local ffi = require("ffi")
local C = ffi.C

ffi.cdef[[
  void* GetModuleHandleA(const char* name);
  void* GetProcAddress(void* mod, const char* name);
  typedef void* (*CreateInterfaceFn)(const char* name, int* ret);
]]

local M = {}
local scope, FindClass2
local classCache = {}   -- name -> {size, fields={name->offset}, raw}
local offsetCache = {}  -- "class::field" -> offset

local function cstr(p)
  if p == nil then return nil end
  local ok, s = pcall(ffi.string, p, 128)
  if not ok then return nil end
  local z = s:find("\0"); if z then s = s:sub(1, z - 1) end
  return s
end

function M.init()
  if scope then return true end
  local ss = C.GetModuleHandleA("schemasystem.dll")
  if ss == nil then return nil, "schemasystem.dll not loaded" end
  local ci = ffi.cast("CreateInterfaceFn", C.GetProcAddress(ss, "CreateInterface"))
  local schemaSystem = ci("SchemaSystem_001", nil)
  if schemaSystem == nil then return nil, "SchemaSystem_001 not captured" end
  local ssVt = ffi.cast("uintptr_t*", ffi.cast("uintptr_t*", schemaSystem)[0])
  local FindScope = ffi.cast("void* (*)(void*, const char*, void*)", ssVt[12])
  scope = FindScope(schemaSystem, "client.dll", nil)
  if scope == nil then return nil, "client.dll scope not found" end
  local scVt = ffi.cast("uintptr_t*", ffi.cast("uintptr_t*", scope)[0])
  FindClass2 = ffi.cast("void* (*)(void*, void**, const char*)", scVt[2])
  M.schemaSystem = schemaSystem
  return true
end

function M.getClass(name)
  if classCache[name] then return classCache[name] end
  if not scope then local ok, err = M.init(); if not ok then return nil, err end end
  local out = ffi.new("void*[1]")
  FindClass2(scope, out, name)
  local cls = out[0]
  if cls == nil then return nil, "class not found: " .. name end
  local size = tonumber(ffi.cast("uint32_t*", cls)[8])
  local count = tonumber(ffi.cast("uint16_t*", cls)[18])
  local arr = ffi.cast("uintptr_t*", ffi.cast("uintptr_t*", cls)[6])
  local fields = {}
  for i = 0, count - 1 do
    local e = arr + i * 4
    local nm = cstr(ffi.cast("void*", e[0]))
    local off = tonumber(ffi.cast("int32_t*", e)[4])
    if nm then fields[nm] = off end
  end
  local rec = { name = name, size = size, fields = fields, raw = cls }
  classCache[name] = rec
  return rec
end

-- Schema::OffsetOf("C_DOTA_BaseNPC","m_iHealth")
function M.offsetOf(cls, field)
  if type(cls) ~= "string" or type(field) ~= "string" then
    if not M._nilLogged then
      M._nilLogged = true
      local f = io.open("D:\\hake\\lotus\\host.log", "a")
      if f then f:write(os.date("%H:%M:%S ") .. "offsetOf nil cls=" .. tostring(cls) .. " field=" .. tostring(field) .. "\n" .. debug.traceback() .. "\n"); f:close() end
    end
    return nil
  end
  local key = cls .. "::" .. field
  if offsetCache[key] then return offsetCache[key] end
  local rec, err = M.getClass(cls)
  if not rec then return nil, err end
  local off = rec.fields[field]
  if off == nil then return nil, "field not found: " .. key end
  offsetCache[key] = off
  return off
end

return M