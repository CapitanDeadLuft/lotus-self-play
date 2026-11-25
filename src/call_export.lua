-- call_export.lua — re-run the in-process host script without re-injection.
-- Finds hostN.dll base in the target, computes RunHost offset from a local
-- DONT_RESOLVE_DLL_REFERENCES load, calls it via CreateRemoteThread.
-- CLI: luajit call_export.lua <pid> <hostDllPath> [exportName]
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
local function hex(v) return string.format("0x%X", tonumber(ffi.cast("uintptr_t", v))) end

local pid = tonumber(arg[1])
local dllPath = arg[2]
local exportName = arg[3] or "RunHost"
if not pid or not dllPath then print("usage: call_export.lua <pid> <dll> [export]"); os.exit(1) end

-- local load without DllMain (no side effects)
local localMod = C.LoadLibraryExA(dllPath, nil, DONT_RESOLVE)
if isNull(localMod) then print("local load failed err=" .. C.GetLastError()); os.exit(1) end
local localFn = C.GetProcAddress(localMod, exportName)
if isNull(localFn) then print("export not found: " .. exportName); os.exit(1) end
local offset = ffi.cast("uintptr_t", localFn) - ffi.cast("uintptr_t", localMod)
C.FreeLibrary(localMod)

-- remote base
local dllName = dllPath:match("([^\\/]+)$"):lower()
local remote = proc.findModule(pid, dllName)
if not remote then print("dll not loaded in target: " .. dllName); os.exit(1) end
local remoteFn = remote.base + offset
print(string.format("remote %s!%s = %s (base %s + 0x%X)", dllName, exportName, hex(remoteFn), hex(remote.base), tonumber(offset)))

local h = C.OpenProcess(PROCESS_ALL_ACCESS, 0, pid)
if isNull(h) then print("OpenProcess failed err=" .. C.GetLastError()); os.exit(1) end
local tid = ffi.new("DWORD[1]")
local th = C.CreateRemoteThread(h, nil, 0, ffi.cast("void*", remoteFn), nil, 0, tid)
if isNull(th) then print("CreateRemoteThread failed err=" .. C.GetLastError()); os.exit(1) end
C.WaitForSingleObject(th, 15000)
C.CloseHandle(th); C.CloseHandle(h)
print("RunHost called OK")