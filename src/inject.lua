-- inject.lua — load our host DLL into Dota2 via FFI DLL-injection (Melonity-style:
-- OpenProcess -> VirtualAllocEx -> WriteProcessMemory -> CreateRemoteThread(LoadLibraryA)).
-- CLI: luajit inject.lua <pid> <dllPath>
local ffi = require("ffi")
local C = ffi.C

ffi.cdef[[
  typedef unsigned long DWORD; typedef void* HANDLE; typedef int BOOL;
  HANDLE OpenProcess(DWORD access, BOOL inherit, DWORD pid);
  void* VirtualAllocEx(HANDLE h, void* addr, size_t size, DWORD alloc, DWORD protect);
  BOOL WriteProcessMemory(HANDLE h, void* base, const void* buf, size_t size, size_t* written);
  void* GetModuleHandleA(const char* name);
  void* GetProcAddress(void* mod, const char* name);
  HANDLE CreateRemoteThread(HANDLE h, void* sa, size_t stack, void* start, void* param, DWORD flags, DWORD* tid);
  DWORD WaitForSingleObject(HANDLE h, DWORD ms);
  BOOL CloseHandle(HANDLE h);
  DWORD GetLastError(void);
]]

local PROCESS_ALL_ACCESS = 0x001F0FFF
-- minimal mask for injection: CREATE_THREAD|VM_OPERATION|VM_WRITE|VM_READ|QUERY_INFORMATION
local PROCESS_INJECT = 0x043A
local MEM_COMMIT = 0x1000
local MEM_RESERVE = 0x2000
local PAGE_READWRITE = 0x04

local function isNull(p) return p == nil or ffi.cast("uintptr_t", p) == 0 end

local M = {}

function M.inject(pid, dllPath)
  local h = C.OpenProcess(PROCESS_INJECT, 0, pid)
  if isNull(h) then h = C.OpenProcess(PROCESS_ALL_ACCESS, 0, pid) end
  if isNull(h) then return nil, "OpenProcess failed err=" .. C.GetLastError() end
  local path = dllPath .. "\0"
  local mem = C.VirtualAllocEx(h, nil, #path, bit.bor(MEM_COMMIT, MEM_RESERVE), PAGE_READWRITE)
  if isNull(mem) then C.CloseHandle(h); return nil, "VirtualAllocEx failed err=" .. C.GetLastError() end
  local wr = ffi.new("size_t[1]")
  if C.WriteProcessMemory(h, mem, path, #path, wr) == 0 then
    C.CloseHandle(h); return nil, "WriteProcessMemory failed err=" .. C.GetLastError()
  end
  local k32 = C.GetModuleHandleA("kernel32.dll")
  local loadlib = C.GetProcAddress(k32, "LoadLibraryA")
  local tid = ffi.new("DWORD[1]")
  local th = C.CreateRemoteThread(h, nil, 0, loadlib, mem, 0, tid)
  if isNull(th) then C.CloseHandle(h); return nil, "CreateRemoteThread failed err=" .. C.GetLastError() end
  C.WaitForSingleObject(th, 10000)
  C.CloseHandle(th); C.CloseHandle(h)
  return true
end

-- CLI
if arg and arg[1] and arg[2] then
  io.stdout:setvbuf("no")
  local ok, err = M.inject(tonumber(arg[1]), arg[2])
  if ok then print("injected " .. arg[2] .. " into pid " .. arg[1])
  else print("INJECT FAILED: " .. err); os.exit(1) end
end

return M