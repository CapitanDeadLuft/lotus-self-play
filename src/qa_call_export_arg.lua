-- qa_call_export_arg.lua — QA control-path helper (FILE ONLY, no runtime use yet).
-- Same remote-thread trick as call_export.lua, but passes ONE integer argument
-- (x64: lpParameter -> RCX) so we can call int-arg exports on the live process:
--   R11_SetDrawMask(bits)  (0=hook-only, 1=state-only, 2=HUD, 3=HUD+MENU, 7=all)
--   R11_SetDrawGuard(ms)
--   R11_DiagDump(void)     (arg ignored)
-- CLI: luajit qa_call_export_arg.lua <pid> <hostDllPath> <exportName> <intArg>
-- Awaiting reviewer/Lead blessing before use in the v4b window.
package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local ffi = require("ffi")
local C = ffi.C
local proc = require("proc")

ffi.cdef[[
  typedef unsigned long DWORD; typedef void* HANDLE;
  void* LoadLibraryExA(const char* path, void* file, DWORD flags);
  int FreeLibrary(void* mod);
  void* GetProcAddress(void* mod, const char* name);
  HANDLE OpenProcess(DWORD access, int inherit, DWORD pid);
  HANDLE CreateRemoteThread(HANDLE h, void* sa, size_t stack, void* start, void* param, DWORD flags, DWORD* tid);
  DWORD WaitForSingleObject(HANDLE h, DWORD ms);
  int CloseHandle(HANDLE h);
  DWORD GetLastError(void);
]]

local DONT_RESOLVE = 0x1
local PROCESS_ALL_ACCESS = 0x001F0FFF
local function isNull(p) return p == nil or ffi.cast("uintptr_t", p) == 0 end

local pid = tonumber(arg[1])
local dllPath = arg[2]
local exportName = arg[3] or "R11_SetDrawMask"
local intArg = tonumber(arg[4] or "0")
if not pid or not dllPath then
  print("usage: luajit qa_call_export_arg.lua <pid> <dll> <export> <intArg>"); os.exit(1)
end

local localMod = C.LoadLibraryExA(dllPath, nil, DONT_RESOLVE)
if isNull(localMod) then print("local load failed err=" .. C.GetLastError()); os.exit(1) end
local localFn = C.GetProcAddress(localMod, exportName)
if isNull(localFn) then print("export not found: " .. exportName); os.exit(1) end
local offset = ffi.cast("uintptr_t", localFn) - ffi.cast("uintptr_t", localMod)
C.FreeLibrary(localMod)

local dllName = dllPath:match("([\\/][^\\/]+)$"):sub(2):lower()
local remote = proc.findModule(pid, dllName)
if not remote then print("dll not loaded in target: " .. dllName); os.exit(1) end
local remoteFn = remote.base + offset
print(string.format("remote %s!%s base=0x%X off=0x%X fn=0x%X arg=%d",
  dllName, exportName, tonumber(remote.base), tonumber(offset), tonumber(remoteFn), intArg))

local h = C.OpenProcess(PROCESS_ALL_ACCESS, 0, pid)
if isNull(h) then print("OpenProcess failed err=" .. C.GetLastError()); os.exit(1) end
local tid = ffi.new("DWORD[1]")
local param = ffi.cast("void*", ffi.cast("uintptr_t", intArg))
local th = C.CreateRemoteThread(h, nil, 0, ffi.cast("void*", remoteFn), param, 0, tid)
if isNull(th) then print("CreateRemoteThread failed err=" .. C.GetLastError()); os.exit(1) end
C.WaitForSingleObject(th, 15000)
C.CloseHandle(th); C.CloseHandle(h)
print("export called OK: " .. exportName .. "(" .. intArg .. ")")