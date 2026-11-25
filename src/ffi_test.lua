-- ffi_test.lua — verify LuaJIT FFI can call WinAPI (foundation for reader/injector)
local ffi = require("ffi")
ffi.cdef[[
  unsigned long GetCurrentProcessId(void);
  void* GetModuleHandleA(const char* name);
  void* GetProcAddress(void* mod, const char* name);
  int GetSystemFirmwareTable(unsigned int provider, unsigned int table, void* buf, unsigned long len);
]]
local pid = ffi.C.GetCurrentProcessId()
local k32 = ffi.C.GetModuleHandleA("kernel32.dll")
local lp  = ffi.C.GetProcAddress(k32, "LoadLibraryA")
assert(k32 ~= nil and lp ~= nil, "WinAPI call failed")
print(string.format("FFI OK: pid=%d kernel32=%p LoadLibraryA=%p", pid, k32, lp))