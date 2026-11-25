-- reader.lua — LuaJIT FFI reader prototype (our own loader, Lua-first).
-- In-process (after inject) we can call the game's SchemaSystem => runtime offsets => patch-resilient.
-- External fallback: OpenProcess/ReadProcessMemory with dumped offsets.
local ffi = require("ffi")
local C = ffi.C

ffi.cdef[[
  typedef unsigned long DWORD; typedef void* HANDLE; typedef int BOOL; typedef unsigned long long ULONG_PTR;
  HANDLE OpenProcess(DWORD access, BOOL inherit, DWORD pid);
  BOOL ReadProcessMemory(HANDLE h, const void* base, void* buf, size_t size, size_t* read);
  BOOL CloseHandle(HANDLE h);
  typedef struct { void* BaseAddress; void* AllocationBase; DWORD AllocProtect; size_t RegionSize; DWORD State; DWORD Protect; DWORD Type; } MBI;
  size_t VirtualQueryEx(HANDLE h, const void* addr, MBI* mbi, size_t len);
  void* GetModuleHandleA(const char* name);
  void* GetProcAddress(void* mod, const char* name);
]]

local M = {}
M.PROCESS_VM_READ = 0x0010
M.PROCESS_QUERY_INFORMATION = 0x0400

-- external handle (if not injected)
function M.open(pid) return C.OpenProcess(bit.bor(M.PROCESS_VM_READ, M.PROCESS_QUERY_INFORMATION), false, pid) end

function M.read(h, addr, size)
  local buf = ffi.new("uint8_t[?]", size)
  local rd = ffi.new("size_t[1]")
  if C.ReadProcessMemory(h, ffi.cast("void*", addr), buf, size, rd) then return buf, tonumber(rd[0]) end
  return nil
end

-- In-process schema resolution (when injected): call SchemaSystem_001 via CreateInterface.
-- Schema::OffsetOf(class, field) resolved at runtime => patch-resilient (method from Lotus SDK).
function M.schema_offset(scope, cls, field)
  -- placeholder: walk SchemaSystem type scope -> class -> field offset (FFI vtable calls).
  -- To be implemented against live schemasystem.dll vtable.
  error("schema_offset: implement against live SchemaSystem vtable")
end

-- entity snapshot (fields per SDK strings): C_BaseEntity / C_DOTA_BaseNPC / Hero.
function M.snapshot(h, base, offs)
  -- placeholder: iterate entity list, read fields via M.read + offs (schema-resolved).
  error("snapshot: implement entity-list walk")
end

return M